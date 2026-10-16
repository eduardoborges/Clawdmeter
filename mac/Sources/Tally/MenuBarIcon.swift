import AppKit
import Observation

/// The menu bar icon: Claude's spark at rest, drawn by the system in black or
/// white, and the spark's thinking animation in the project's terracotta while
/// any session works. With Reduce Motion on, it holds one tinted frame.
@MainActor
@Observable
final class MenuBarIcon {
    static let shared = MenuBarIcon()
    static let fps = 9.0   // 8 frames, about 0.9 s a loop, as in Claude Status Bar

    private(set) var image: NSImage

    @ObservationIgnored private let rest: NSImage
    @ObservationIgnored private let frames: [NSImage]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var frame = 0

    private init() {
        let decode = { (png: String) in Data(base64Encoded: png).flatMap(NSImage.init(data:)) }
        rest = Self.tint(decode(claudeLogoPNG), color: nil)
        frames = claudeSparkFramePNGs.compactMap(decode).map { Self.tint($0, color: NSColor(Theme.accent)) }
        image = rest
    }

    func setWorking(_ working: Bool) {
        guard working, !frames.isEmpty else {
            timer?.invalidate()
            timer = nil
            image = rest
            return
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            timer?.invalidate()
            timer = nil
            image = frames[0]
        } else if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1 / Self.fps, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.step() }
            }
        }
    }

    private func step() {
        frame = (frame + 1) % frames.count
        image = frames[frame]
    }

    /// An 18 pt icon from an alpha mask: filled with `color`, or a template the
    /// system tints to match the menu bar when `color` is nil.
    private static func tint(_ mask: NSImage?, color: NSColor?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let mask else { return true }
            if let color {
                color.setFill()
                rect.fill()
                mask.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            } else {
                mask.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        image.isTemplate = color == nil
        return image
    }
}
