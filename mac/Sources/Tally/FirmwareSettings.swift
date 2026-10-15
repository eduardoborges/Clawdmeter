import AppKit
import SwiftUI
import TallyCore

/// One flash at a time: its progress and esptool's output.
@MainActor
@Observable
final class FlashJob {
    var progress: Double?
    var lines: [String] = []
    var error: String?
    var running = false

    func run(zip: URL, port: String, env: String) {
        running = true
        progress = 0
        lines = []
        error = nil
        Task {
            do {
                try await Firmware.flash(zip: zip, port: port, env: env,
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

struct FirmwareSettings: View {
    @State private var board = Setting("board", default: "waveshare_amoled_216")
    @State private var ports = Firmware.ports()
    @State private var port = Firmware.ports().first ?? ""
    @State private var release: (version: String, url: URL)?
    @State private var checking = false
    @State private var job = FlashJob()

    var body: some View {
        Form {
            Section {
                Picker("Board", selection: $board.value) {
                    ForEach(Firmware.boards, id: \.env) { Text($0.name).tag($0.env) }
                }
                HStack {
                    Picker("USB port", selection: $port) {
                        if ports.isEmpty { Text("No board on USB").tag("") }
                        ForEach(ports, id: \.self) { Text($0).tag($0) }
                    }
                    Button {
                        ports = Firmware.ports()
                        if !ports.contains(port) { port = ports.first ?? "" }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("Board")
            } footer: {
                Note("Plug the display in with a USB cable. Flashing keeps its Bluetooth pairing and settings.")
            }
            Section("Firmware") {
                LabeledContent("Latest release") {
                    if checking { ProgressView().controlSize(.small) } else { Text(release?.version ?? "None published yet") }
                }
                HStack {
                    Button("Flash Latest Release") { flashLatest() }
                        .disabled(release == nil || port.isEmpty || job.running)
                    Button("Flash a File…") { pickFile() }
                        .disabled(port.isEmpty || job.running)
                    if Firmware.esptool() == nil {
                        Text("Needs `brew install esptool`").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if job.progress != nil {
                Section("Progress") {
                    ProgressView(value: job.progress ?? 0)
                    if let error = job.error {
                        Text(error).foregroundStyle(.red)
                    }
                    Text(job.lines.suffix(5).joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .task(id: board.value) {
            checking = true
            release = await Firmware.latestRelease(env: board.value)
            checking = false
        }
    }

    private func flashLatest() {
        guard let release else { return }
        Task {
            do {
                job.run(zip: try await Firmware.download(release.url), port: port, env: board.value)
            } catch {
                job.error = error.localizedDescription
                job.progress = 0
            }
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.message = "Choose a tally-firmware zip"
        guard panel.runModal() == .OK, let zip = panel.url else { return }
        job.run(zip: zip, port: port, env: board.value)
    }
}
