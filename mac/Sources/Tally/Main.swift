import AppKit
import ServiceManagement
import SwiftUI
import TallyCore

@main
@MainActor
enum Main {
    static func main() {
        // `--dump ss|td|stats|usage` prints messages the way the daemon builds them,
        // to compare the two.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dump") {
            switch i + 1 < args.count ? args[i + 1] : "" {
            case "ss": print(Sessions.message().encoded)
            case "td": print(Today.message().encoded)
            case "stats": Stats.load().forEach { print($0.encoded) }
            case "usage":
                // Polls the API once, like a daemon tick.
                let done = DispatchSemaphore(value: 0)
                Task.detached {
                    let result = await Usage.pollActive(dirs: Credentials.configDirs(), selector: PlanSelector())
                    print(result.payload.map { JSON.object($0).encoded } ?? (result.allDead ? "no token" : "poll failed"))
                    done.signal()
                }
                done.wait()
            default:
                FileHandle.standardError.write(Data("usage: Tally --dump ss|td|stats|usage\n".utf8))
                exit(2)
            }
            return
        }
        // `--login on|off` sets Open at Login for this copy of the app; with no
        // value it prints the current state.
        if let i = args.firstIndex(of: "--login") {
            do {
                if i + 1 < args.count {
                    try args[i + 1] == "on" ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
                print(SMAppService.mainApp.status == .enabled ? "on" : "off (\(SMAppService.mainApp.status.rawValue))")
            } catch {
                print("failed: \(error.localizedDescription)")
            }
            return
        }
        // `--flash <zip> [--port <port>]` flashes a board without the window.
        if let i = args.firstIndex(of: "--flash"), i + 1 < args.count {
            let zip = URL(fileURLWithPath: args[i + 1])
            let port = args.firstIndex(of: "--port").map { args[$0 + 1] } ?? Firmware.ports().first ?? ""
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    try await Firmware.flash(zip: zip, port: port, env: nil, progress: { _ in }, output: { print($0) })
                    print("flashed")
                } catch {
                    print("failed: \(error.localizedDescription)")
                }
                done.signal()
            }
            done.wait()
            return
        }
        // `--preview` shows the panel with made-up data in a floating window at the
        // top left of the screen, where the system draws its real glass.
        if args.contains("--preview") {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let host = NSHostingView(rootView: PopoverView(dashboard: .sample, linkStatus: "Connected", connected: true,
                                                           onSettings: {})
                .background(.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16)))
            host.frame.size = host.fittingSize
            let screen = NSScreen.main!.frame
            let panel = NSPanel(contentRect: NSRect(x: screen.minX + 80, y: screen.maxY - 80 - host.frame.height,
                                                    width: host.frame.width, height: host.frame.height),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.contentView = host
            panel.orderFrontRegardless()
            print(Int(host.frame.width), Int(host.frame.height))
            app.run()
            return
        }
        // `--welcome` opens the welcome guide by itself, without the daemon or
        // Bluetooth, so it can run next to the installed app.
        if args.contains("--welcome") {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            Welcome.show(WelcomeView(linkStatus: "Looking for the display", connected: false) { exit(0) })
            app.run()
            return
        }
        // `--render <png>` draws the panel with made-up data, to work on the
        // design without clicking the menu bar.
        if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
            let what = i + 2 < args.count ? args[i + 2] : "now"
            if what.hasPrefix("settings-") {
                render(SettingsView(tab: String(what.dropFirst("settings-".count))), to: args[i + 1])
            } else if what.hasPrefix("welcome-") {
                render(WelcomeView(linkStatus: "Looking for the display", connected: false,
                                   step: Int(what.dropFirst("welcome-".count)) ?? 0)
                    .background(.windowBackground), to: args[i + 1])
            } else {
                let dashboard = Dashboard.sample
                if what == "loading" { dashboard.usage = nil }   // the panel before the first reading
                render(PopoverView(dashboard: dashboard, linkStatus: what == "loading" ? "Looking for the display" : "Connected",
                                   connected: what != "loading", onSettings: {},
                                   tab: what == "activity" ? .activity : .now)
                    .background(.windowBackground), to: args[i + 1])
            }
            return
        }
        TallyApp.main()
    }
}

@MainActor
func render(_ view: some View, to path: String) {
    // An offscreen window draws AppKit controls too, which ImageRenderer leaves blank.
    _ = NSApplication.shared
    let host = NSHostingView(rootView: view)
    host.frame.size = host.fittingSize
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))   // let charts and tasks settle
    let size = host.bounds.size
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try? png.write(to: URL(fileURLWithPath: path))
}
