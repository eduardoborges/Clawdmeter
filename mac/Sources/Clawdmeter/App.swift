import SwiftUI

// One link for the whole process: SwiftUI may build the App struct more than
// once, and each DeviceLink opens its own Bluetooth central.
private let link: DeviceLink = {
    let link = DeviceLink()
    // `--send <file>` writes that file to the device once connected, to try a
    // message by hand.
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--send"), i + 1 < args.count,
       let message = FileManager.default.contents(atPath: args[i + 1]) {
        link.onReady = { link.send(message) }
    }
    return link
}()

@main
struct ClawdmeterApp: App {
    var body: some Scene {
        MenuBarExtra("Clawdmeter", systemImage: "gauge.with.dots.needle.33percent") {
            Text(link.status)
            if link.maxWrite > 0 {
                Text("Up to \(link.maxWrite) bytes per message")
            }
            Divider()
            Button("Quit Clawdmeter") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
