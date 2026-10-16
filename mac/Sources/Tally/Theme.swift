import SwiftUI

/// The display's accent colors (firmware/src/theme.h). Everything else uses
/// the system's colors, so the app follows light and dark mode.
enum Theme {
    static let accent = Color(hex: 0xD97757)
    static let alert = Color(hex: 0xC6613F)

    /// A usage bar's fill: terracotta, earthier near the limit, as on the display.
    static func bar(_ pct: Int) -> Color { pct >= 80 ? alert : accent }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255,
                  green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// "now", "12m", "2h 5m", "3d 4h"; done rows add "ago".
func duration(_ minutes: Int, ago: Bool = false) -> String {
    let text: String
    switch minutes {
    case ..<1: return "now"
    case ..<60: text = "\(minutes)m"
    case ..<1440: text = minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    default: text = "\(minutes / 1440)d \(minutes % 1440 / 60)h"
    }
    return ago ? text + " ago" : text
}
