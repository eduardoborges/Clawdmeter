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

/// The welcome guide's window. Before macOS 15 a Window scene would open on
/// every launch, so this is a plain NSWindow.
@MainActor
enum Welcome {
    private static var window: NSWindow?

    static func show() { show(LiveWelcome()) }

    static func show(_ content: some View) {
        if window?.isVisible != true {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        UserDefaults.standard.set(true, forKey: "welcomed")
        NSApp.activate(ignoringOtherApps: true)   // a menu bar app's windows open behind others
        window?.makeKeyAndOrderFront(nil)
    }

    private struct LiveWelcome: View {
        var body: some View {
            WelcomeView(linkStatus: link.status, connected: link.isReady) { Welcome.window?.close() }
        }
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
        .onAppear {
            DispatchQueue.main.async(execute: fitStatusItem)
            if !UserDefaults.standard.bool(forKey: "welcomed") { DispatchQueue.main.async(execute: Welcome.show) }
        }
        .onChange(of: menuBarUsage.isOn) { fitStatusItem() }
    }

    /// MenuBarExtra pads the icon by 9 pt on each side. With 3 pt, the gaps to
    /// the neighboring icons measure 19 to 22 pt, like the gaps between the other
    /// items. It has no API for this, so this reaches the status item through its
    /// window's private statusItem key. The usage text needs a variable width and
    /// keeps the default.
    private func fitStatusItem() {
        let key = "statusItem"
        for window in NSApp.windows where window.className == "NSStatusBarWindow" && window.responds(to: NSSelectorFromString(key)) {
            (window.value(forKey: key) as? NSStatusItem)?.length = menuBarUsage.isOn
                ? NSStatusItem.variableLength : MenuBarIcon.canvas.width + 6
        }
    }
}

private struct MenuPanel: View {
    @Environment(\.openSettings) private var openSettings
    @State private var fit = WindowFit()

    var body: some View {
        PopoverView(dashboard: dashboard, linkStatus: link.status, connected: link.isReady,
                    onSettings: {
                        NSApp.activate(ignoringOtherApps: true)   // a menu bar app's windows open behind others
                        openSettings()
                    },
                    onQuit: { NSApplication.shared.terminate(nil) })
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fit.height = $0 }
            .frame(maxHeight: .infinity, alignment: .top)   // stays pinned to the top while the window catches up
            .background(WindowReader(fit: fit))
    }
}

/// The menu bar window grows with its content but never shrinks, so a shorter
/// tab would sit in empty space. This fits the window to the content in the same
/// layout pass and keeps its top edge under the menu bar.
@MainActor
private final class WindowFit {
    weak var window: NSWindow? { didSet { apply() } }
    var height: CGFloat = 0 { didSet { apply() } }

    private func apply() {
        guard let window, height > 0 else { return }
        let content = window.contentRect(forFrameRect: window.frame)
        guard abs(content.height - height) > 0.5 else { return }
        var frame = window.frameRect(forContentRect: NSRect(x: content.minX, y: content.maxY - height,
                                                            width: content.width, height: height))
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true)
    }
}

private struct WindowReader: NSViewRepresentable {
    let fit: WindowFit

    final class Reader: NSView {
        var fit: WindowFit?
        override func viewDidMoveToWindow() { fit?.window = window }
    }

    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.fit = fit
        return view
    }

    func updateNSView(_ view: Reader, context: Context) {}
}
