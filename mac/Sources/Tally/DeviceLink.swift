import CoreBluetooth
import Observation

/// The Bluetooth link to the display. The device pairs as a keyboard, so macOS
/// keeps it connected and it never shows up in a scan. The link asks for the
/// connected peripheral instead: first by the data service, then by the HID
/// service and the name.
@Observable
final class DeviceLink: NSObject {
    static let service = CBUUID(string: "4c41555a-4465-7669-6365-000000000001")
    static let rx = CBUUID(string: "4c41555a-4465-7669-6365-000000000002")
    static let tx = CBUUID(string: "4c41555a-4465-7669-6365-000000000003")
    static let req = CBUUID(string: "4c41555a-4465-7669-6365-000000000004")
    static let hid = CBUUID(string: "1812")
    static let connectTimeout = 20.0

    private(set) var status = "Starting"
    private(set) var isReady = false
    private(set) var takesStats = false
    private(set) var maxWrite = 0

    /// Runs once the data service is ready and TX is read, after every connect.
    @ObservationIgnored var onReady: (() -> Void)?
    /// Runs when the device asks for fresh data (a notify on REQ).
    @ObservationIgnored var onRefresh: (() -> Void)?

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var device: CBPeripheral?
    @ObservationIgnored private var rx: CBCharacteristic?
    @ObservationIgnored private var retryDelay = 1.0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func findDevice() {
        let found = central.retrieveConnectedPeripherals(withServices: [Self.service]).first
            ?? central.retrieveConnectedPeripherals(withServices: [Self.hid]).first { $0.name == "Tally" }
        guard let found else {
            status = "Looking for the display"
            retry()
            return
        }
        device = found
        found.delegate = self
        status = "Connecting"
        central.connect(found)
        // CoreBluetooth waits forever on a half-open link, which once left the
        // Python daemon stuck for 13 hours. Give up and start over instead.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout) { [weak self] in
            guard let self, self.device === found, !self.isReady else { return }
            log("Connect timed out")
            self.central.cancelPeripheralConnection(found)
            self.retry()
        }
    }

    /// Writes one message to RX. macOS reports a 253-byte limit for writes
    /// without response but delivers longer ones: a 485-byte message reached
    /// the 2.16 intact. Like bleak, it doesn't wait for canSendWriteWithoutResponse:
    /// the ready callback never came after a few writes in a row.
    @discardableResult
    func send(_ message: Data) -> Bool {
        guard let device, let rx else { return false }
        device.writeValue(message, for: rx, type: .withoutResponse)
        return true
    }

    private func retry() {
        device = nil
        rx = nil
        isReady = false
        takesStats = false
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 60)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.device == nil, self.central.state == .poweredOn else { return }
            self.findDevice()
        }
    }

    private func ready() {
        guard !isReady else { return }
        isReady = true
        retryDelay = 1
        status = "Connected"
        onReady?()
    }
}

extension DeviceLink: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Bluetooth state \(central.state.rawValue), authorization \(CBManager.authorization.rawValue)")
        if central.state == .poweredOn {
            findDevice()
        } else {
            status = "Bluetooth is off or not allowed"
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected to \(peripheral.name ?? "unnamed")")
        peripheral.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Connect failed: \(error?.localizedDescription ?? "no error")")
        status = "Connect failed"
        retry()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Disconnected: \(error?.localizedDescription ?? "no error")")
        status = "Disconnected"
        retry()
    }
}

extension DeviceLink: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else {
            log("The device has no data service")
            return
        }
        peripheral.discoverCharacteristics([Self.rx, Self.tx, Self.req], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        maxWrite = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let chars = service.characteristics ?? []
        rx = chars.first { $0.uuid == Self.rx }
        if let req = chars.first(where: { $0.uuid == Self.req }) { peripheral.setNotifyValue(true, for: req) }
        if let tx = chars.first(where: { $0.uuid == Self.tx }) {
            peripheral.readValue(for: tx)   // ready() once the value is in
        } else {
            ready()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case Self.tx:
            // Firmware that takes the k messages says "stats":1 here.
            let text = String(decoding: characteristic.value ?? Data(), as: UTF8.self)
            takesStats = text.contains("\"stats\":1")
            log("TX: \(text), max write \(maxWrite)")
            ready()
        case Self.req:
            log("Refresh requested by the device")
            onRefresh?()
        default:
            break
        }
    }
}
