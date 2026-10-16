import AppKit
import SwiftUI
import TallyCore

/// First-launch guide, also in Settings. It opens on its own once; closing it
/// early doesn't bring it back.
struct WelcomeView: View {
    let linkStatus: String
    let connected: Bool
    let onDone: () -> Void
    @State private var step: Int
    @State private var flasher = Flasher()
    @State private var hooks = HookInstaller()
    @AppStorage("welcomed") private var welcomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(linkStatus: String, connected: Bool, step: Int = 0, onDone: @escaping () -> Void = {}) {
        self.linkStatus = linkStatus
        self.connected = connected
        self.onDone = onDone
        _step = State(initialValue: step)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Group {
                switch step {
                case 0: welcome
                case 1: flash
                case 2: pair
                case 3: hookStep
                default: allSet
                }
            }
            .frame(maxWidth: 420)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule().fill(i == step ? Theme.accent : Color.secondary.opacity(0.3)).frame(width: i == step ? 24 : 8, height: 8)
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 40)
        .frame(width: 540, height: 460)
        .tint(Theme.accent)
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: step)
        .onAppear { welcomed = true }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Image(nsImage: Data(base64Encoded: clawdIdlePNG).flatMap(NSImage.init(data:)) ?? NSImage())
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
                .frame(width: 120, height: 80)
                .foregroundStyle(Theme.accent)
            header("Welcome to Tally",
                   "Tally feeds the display on your desk with your Claude Code usage, open sessions and what each one is doing. It lives in the menu bar.")
            Button("Get Started") { step += 1 }.primary()
        }
    }

    private var flash: some View {
        VStack(spacing: 20) {
            symbol("cpu")
            header("Flash the display",
                   "Plug the display in with a USB cable and pick its board. Flashing keeps its Bluetooth pairing and settings.")
            Form { FlashTarget(flasher: flasher) }
                .formStyle(.columns)
                .fixedSize()
            flashStatus
            HStack(spacing: 12) {
                if flasher.done {
                    Button("Continue") { step += 1 }.primary()
                } else {
                    Button("Skip") { step += 1 }.secondary()
                    Button(flasher.release.map { "Flash \($0.version)" } ?? "Flash") { flasher.flashLatest() }
                        .primary()
                        .disabled(flasher.release == nil || flasher.port.isEmpty || flasher.running || Firmware.esptool() == nil)
                }
            }
        }
        .task(id: flasher.board.value) { await flasher.checkRelease() }
    }

    @ViewBuilder private var flashStatus: some View {
        if let progress = flasher.progress {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                Text(flasher.error ?? flasher.lines.last ?? " ")
                    .font(.caption)
                    .foregroundStyle(flasher.error == nil ? Color.secondary : Theme.alert)
                    .lineLimit(1)
            }
        } else if Firmware.esptool() == nil {
            note("Flashing needs esptool: brew install esptool")
        } else if !flasher.checking && flasher.release == nil {
            note("No firmware release for this board yet")
        }
    }

    private var pair: some View {
        VStack(spacing: 20) {
            symbol("antenna.radiowaves.left.and.right")
            header("Connect over Bluetooth",
                   "Turn the display on and pair it once: in System Settings → Bluetooth, click Connect next to Tally. macOS asks for Bluetooth access the first time.")
            if connected {
                Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(linkStatus).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Button("Open Bluetooth Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!)
                }
                .secondary()
                Button("Continue") { step += 1 }.primary()
            }
        }
    }

    private var hookStep: some View {
        VStack(spacing: 20) {
            symbol("point.3.connected.trianglepath.dotted")
            header("Claude Code hooks",
                   "Sessions, alerts and the corner Clawd come from Claude Code hooks. Tally adds them to ~/.claude/settings.json and keeps a backup of the old file.")
            if hooks.current {
                Label("Hooks installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if let error = hooks.error {
                Text(error).font(.callout).foregroundStyle(Theme.alert)
            }
            HStack(spacing: 12) {
                if hooks.current || hooks.script == nil {
                    Button("Continue") { step += 1 }.primary()
                } else {
                    Button("Skip") { step += 1 }.secondary()
                    Button("Install Hooks") { hooks.install() }.primary()
                }
            }
        }
    }

    private var allSet: some View {
        VStack(spacing: 20) {
            symbol("checkmark.circle")
            header("All set", "Click Clawd in the menu bar for usage, sessions and today's activity. Settings has the rest.")
            OpenAtLoginToggle()
            Button("Done", action: onDone).primary()
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 44)).foregroundStyle(Theme.accent)
    }

    private func header(_ title: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 26, weight: .semibold))
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
    }
}

private extension View {
    func primary() -> some View {
        buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
    }

    func secondary() -> some View {
        controlSize(.large)
    }
}
