import AppKit
import SwiftUI
import TallyCore

/// The board to flash, its USB port and the latest release, plus one flash at
/// a time with its progress and esptool's output. Settings and the welcome
/// guide share it.
@MainActor
@Observable
final class Flasher {
    let board = Setting("board", default: "waveshare_amoled_216")
    var ports = Firmware.ports()
    var port = ""
    var release: (version: String, url: URL)?
    var checking = false
    var progress: Double?
    var lines: [String] = []
    var error: String?
    var running = false

    init() { port = ports.first ?? "" }

    var done: Bool { progress == 1 && error == nil && !running }

    func refreshPorts() {
        ports = Firmware.ports()
        if !ports.contains(port) { port = ports.first ?? "" }
    }

    func checkRelease() async {
        checking = true
        release = await Firmware.latestRelease(env: board.value)
        checking = false
    }

    func flashLatest() {
        guard let release else { return }
        Task {
            do {
                run(zip: try await Firmware.download(release.url))
            } catch {
                self.error = error.localizedDescription
                progress = 0
            }
        }
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.message = "Choose a tally-firmware zip"
        guard panel.runModal() == .OK, let zip = panel.url else { return }
        run(zip: zip)
    }

    private func run(zip: URL) {
        running = true
        progress = 0
        lines = []
        error = nil
        Task {
            do {
                try await Firmware.flash(zip: zip, port: port, env: board.value,
                                         progress: { p in Task { @MainActor in self.progress = p } },
                                         output: { line in Task { @MainActor in self.lines.append(line) } })
                lines.append("Done. The display restarts on its own.")
            } catch {
                self.error = error.localizedDescription
            }
            running = false
        }
    }
}

/// The board and USB port pickers.
struct FlashTarget: View {
    let flasher: Flasher

    var body: some View {
        Picker("Board", selection: Bindable(flasher.board).value) {
            ForEach(Firmware.boards, id: \.env) { Text($0.name).tag($0.env) }
        }
        HStack {
            Picker("USB port", selection: Bindable(flasher).port) {
                if flasher.ports.isEmpty { Text("No board on USB").tag("") }
                ForEach(flasher.ports, id: \.self) { Text($0).tag($0) }
            }
            Button { flasher.refreshPorts() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
        }
    }
}

struct FirmwareSettings: View {
    @State private var flasher = Flasher()

    var body: some View {
        Form {
            Section {
                FlashTarget(flasher: flasher)
            } header: {
                Text("Board")
            } footer: {
                Note("Plug the display in with a USB cable. Flashing keeps its Bluetooth pairing and settings.")
            }
            Section("Firmware") {
                LabeledContent("Latest release") {
                    if flasher.checking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(flasher.release?.version ?? "None published yet")
                    }
                }
                HStack {
                    Button("Flash Latest Release") { flasher.flashLatest() }
                        .glassPrimaryAction()
                        .disabled(flasher.release == nil || flasher.port.isEmpty || flasher.running)
                    Button("Flash a File…") { flasher.pickFile() }
                        .glassAction()
                        .disabled(flasher.port.isEmpty || flasher.running)
                    if Firmware.esptool() == nil {
                        Text("Needs `brew install esptool`").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if flasher.progress != nil {
                Section("Progress") {
                    ProgressView(value: flasher.progress ?? 0)
                    if let error = flasher.error {
                        Text(error).foregroundStyle(.red)
                    }
                    Text(flasher.lines.suffix(5).joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .task(id: flasher.board.value) { await flasher.checkRelease() }
    }
}
