import AppKit
import Observation

/// The menu bar icon, drawn by the system in white or black. At rest it is
/// Claude's spark; while any session works it is Clawd typing on a laptop, held
/// still when Reduce Motion is on.
@MainActor
@Observable
final class MenuBarIcon {
    static let shared = MenuBarIcon()
    static let fps = 12.0

    private(set) var image: NSImage

    @ObservationIgnored private let rest: NSImage
    @ObservationIgnored private let frames: [NSImage]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var frame = 0

    private init() {
        let decode = { (png: String) in Data(base64Encoded: png).flatMap(NSImage.init(data:)) }
        rest = Self.icon(decode(claudeLogoPNG), size: NSSize(width: 18, height: 18))
        frames = clawdLaptopFramePNGs.compactMap(decode).map { Self.icon($0, size: Self.pixelSize($0), sharp: true) }
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
            image = frames[frame]
            timer = Timer.scheduledTimer(withTimeInterval: 1 / Self.fps, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.step() }
            }
        }
    }

    private func step() {
        frame = (frame + 1) % frames.count
        image = frames[frame]
    }

    /// Both states share one canvas, so the menu bar items beside the icon stay
    /// put when it switches.
    static let canvas = NSSize(width: 28, height: 18)

    private static func pixelSize(_ image: NSImage) -> NSSize {
        image.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
    }

    /// A template the system draws white or black to match the menu bar, with the
    /// mask centered on the canvas. Pixel art is scaled without smoothing.
    private static func icon(_ mask: NSImage?, size: NSSize, sharp: Bool = false) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { rect in
            if sharp { NSGraphicsContext.current?.imageInterpolation = .none }
            mask?.draw(in: NSRect(x: ((rect.width - size.width) / 2).rounded(), y: ((rect.height - size.height) / 2).rounded(),
                                  width: size.width, height: size.height))
            return true
        }
        image.isTemplate = true
        return image
    }
}
