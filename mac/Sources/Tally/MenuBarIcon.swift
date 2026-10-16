import AppKit
import Observation

/// The menu bar icon. At rest it is Claude's spark, which the system draws in
/// black or white. While any session works it is Clawd typing on a laptop, held
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
        rest = Self.template(decode(claudeLogoPNG))
        frames = clawdLaptopFramePNGs.compactMap(decode).map(Self.pixelArt)
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

    /// An 18 pt template from an alpha mask, tinted by the system to match the
    /// menu bar.
    private static func template(_ mask: NSImage?) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            mask?.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// One point per pixel, scaled without smoothing so the cells stay sharp.
    private static func pixelArt(_ source: NSImage) -> NSImage {
        let size = source.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? source.size
        return NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .none
            source.draw(in: rect)
            return true
        }
    }
}
