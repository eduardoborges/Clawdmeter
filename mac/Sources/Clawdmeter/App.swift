import SwiftUI

@main
struct ClawdmeterApp: App {
    var body: some Scene {
        MenuBarExtra("Clawdmeter", systemImage: "gauge.with.dots.needle.33percent") {
            Button("Quit Clawdmeter") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
