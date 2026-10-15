import ServiceManagement
import SwiftUI
import TallyCore

/// The settings window. Every option lives in the same config file the Linux
/// daemon reads, so the two stay interchangeable.
struct SettingsView: View {
    @State var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }.tag("general")
            AlertSettings().tabItem { Label("Alerts", systemImage: "bell.badge") }.tag("alerts")
            DisplaySettings().tabItem { Label("Display", systemImage: "display") }.tag("display")
            HookSettings().tabItem { Label("Hooks", systemImage: "point.3.connected.trianglepath.dotted") }.tag("hooks")
            FirmwareSettings().tabItem { Label("Firmware", systemImage: "cpu") }.tag("firmware")
        }
        .frame(width: 520, height: 420)
    }
}

/// One config key, read when the view appears and written on every change.
@MainActor
@Observable
final class Setting {
    let key: String
    var value: String {
        didSet {
            do { try Config.set(key, value) } catch { log("Saving \(key): \(error.localizedDescription)") }
        }
    }

    init(_ key: String, allowed: Set<String>? = nil, default fallback: String) {
        self.key = key
        let config = Config()
        if let allowed {
            value = config.choice(key, allowed, default: fallback)
        } else {
            let raw = key == "config_dirs" ? config.last(key) : config.value(key)
            value = raw.isEmpty ? fallback : raw
        }
    }

    var isOn: Bool {
        get { value == "on" }
        set { value = newValue ? "on" : "off" }
    }
}

private struct GeneralSettings: View {
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var dirs = Setting("config_dirs", default: "~/.claude")

    var body: some View {
        Form {
            Section {
                Toggle("Show 5-hour usage in the menu bar", isOn: Bindable(menuBarUsage).isOn)
                Toggle("Open Tally at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        do {
                            try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        } catch {
                            log("Open at Login: \(error.localizedDescription)")
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            Section {
                TextField("Claude config folders", text: $dirs.value)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Accounts")
            } footer: {
                Note("Comma separated, like `~/.claude, ~/.claude-work`. With more than one, Tally shows the plan you're using.")
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                LabeledContent("Settings file", value: "~/.config/claude-usage-monitor/config")
                Link("github.com/eduardoborges/tally", destination: URL(string: "https://github.com/eduardoborges/tally")!)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AlertSettings: View {
    @State private var beep = Setting("beep", allowed: ["off", "on"], default: "off")
    @State private var doneAfter = Setting("done_after", default: "5")

    var body: some View {
        Form {
            Section {
                Toggle("Beep when a session needs you", isOn: $beep.isOn)
            } footer: {
                Note("Clawd walks onto the display either way. The beep plays on boards with a speaker.")
            }
            Section {
                Stepper(value: Binding(get: { Int(doneAfter.value) ?? 5 }, set: { doneAfter.value = String($0) }),
                        in: 0...120) {
                    LabeledContent("Celebrate tasks longer than",
                                   value: doneAfter.value == "0" ? "Off" : "\(doneAfter.value) min")
                }
            } footer: {
                Note("When a task runs at least this long, Clawd comes back to dance when it finishes. 0 turns it off.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct DisplaySettings: View {
    @State private var chime = Setting("chime", allowed: ["off", "on"], default: "off")
    @State private var clock = Setting("clock", allowed: ["off", "auto", "12", "24"], default: "off")

    var body: some View {
        Form {
            Section {
                Picker("Clock in the title", selection: $clock.value) {
                    Text("Off").tag("off")
                    Text("Automatic").tag("auto")
                    Text("12-hour").tag("12")
                    Text("24-hour").tag("24")
                }
            } footer: {
                Note("Shows the time where the workspace title goes.")
            }
            Section {
                Toggle("Chime when the 5-hour limit resets", isOn: $chime.isOn)
            }
        }
        .formStyle(.grouped)
    }
}

private struct HookSettings: View {
    @State private var installed = Hooks.installed()

    var body: some View {
        Form {
            Section {
                ForEach(Hooks.events, id: \.event) { hook in
                    HStack {
                        Image(systemName: installed.contains(hook.event) ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(installed.contains(hook.event) ? Color.green : Color.secondary)
                        VStack(alignment: .leading) {
                            Text(hook.event)
                            Text(hook.feeds).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Claude Code hooks")
            } footer: {
                HStack {
                    Note("Read from ~/.claude/settings.json. Tally doesn't change it.")
                    Spacer()
                    Link("Setup guide", destination: URL(string: "https://github.com/eduardoborges/tally#claude-code-hooks")!)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { installed = Hooks.installed() }
    }
}

/// A footer note under a settings section, aligned like body text.
struct Note: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
