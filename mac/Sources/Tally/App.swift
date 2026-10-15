import ServiceManagement
import SwiftUI

// One link and one daemon for the whole process: SwiftUI may build the App
// struct more than once, and each DeviceLink opens its own Bluetooth central.
private let link = DeviceLink()
@MainActor private let daemon: Daemon? = {
    // `--send <file>` only writes that file to the device once connected, to
    // try a message by hand.
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--send") else { return Daemon(link: link) }
    if i + 1 < args.count, let message = FileManager.default.contents(atPath: args[i + 1]) {
        link.onReady = { link.send(message) }
    }
    return nil
}()

struct TallyApp: App {
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        _ = daemon   // globals start lazily
    }

    var body: some Scene {
        MenuBarExtra("Tally", systemImage: "gauge.with.dots.needle.33percent") {
            Text(link.status)
            if let updated = daemon?.lastUpdate {
                Text("Updated at \(updated.formatted(date: .omitted, time: .shortened))")
            }
            Divider()
            Toggle("Open at Login", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, on in
                    do {
                        try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    } catch {
                        log("Open at Login: \(error.localizedDescription)")
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Button("Quit Tally") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
