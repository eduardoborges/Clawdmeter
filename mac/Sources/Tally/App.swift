import SwiftUI

// One link, dashboard and daemon for the whole process: SwiftUI may build the
// App struct more than once, and each DeviceLink opens its own Bluetooth central.
private let link = DeviceLink()
@MainActor private let dashboard = Dashboard()
@MainActor private let daemon: Daemon? = {
    // `--send <file>` only writes that file to the device once connected, to
    // try a message by hand.
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--send") else { return Daemon(link: link, dashboard: dashboard) }
    if i + 1 < args.count, let message = FileManager.default.contents(atPath: args[i + 1]) {
        link.onReady = { link.send(message) }
    }
    return nil
}()

struct TallyApp: App {
    init() {
        _ = daemon   // globals start lazily
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView() }
    }
}

/// Whether the menu bar shows the 5-hour usage next to the icon.
@MainActor let menuBarUsage = Setting("menubar_usage", allowed: ["off", "on"], default: "on")

private struct MenuBarLabel: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.shared.image)
            if menuBarUsage.isOn, let usage = dashboard.usage { Text("\(usage.session)%").monospacedDigit() }
        }
    }
}

private struct MenuPanel: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        PopoverView(dashboard: dashboard, linkStatus: link.status, connected: link.isReady,
                    onSettings: {
                        NSApp.activate(ignoringOtherApps: true)   // a menu bar app's windows open behind others
                        openSettings()
                    },
                    onQuit: { NSApplication.shared.terminate(nil) })
            .preferredColorScheme(.dark)   // dark glass, so the display's light text stays readable
    }
}
