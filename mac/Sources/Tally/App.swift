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
            Image(systemName: "gauge.with.dots.needle.33percent")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuPanel: View {
    var body: some View {
        PopoverView(dashboard: dashboard, linkStatus: link.status, connected: link.isReady,
                    onQuit: { NSApplication.shared.terminate(nil) })
    }
}
