import SwiftUI

/// The display's palette (firmware/src/theme.h), so the app and the desk look
/// alike. Corners: 10 for panels, 3 for chips, round for bars.
enum Theme {
    static let background = Color(hex: 0x141413)
    static let panel = Color(hex: 0x1B1A18)
    static let line = Color(hex: 0x343431)
    static let track = Color(hex: 0x2A2926)
    static let text = Color(hex: 0xFAF9F5)
    static let dim = Color(hex: 0xB0AEA5)
    static let faint = Color(hex: 0x8E8C84)   // 5.2:1 on the panel, AA for small text
    static let accent = Color(hex: 0xD97757)
    static let alert = Color(hex: 0xC6613F)
    static let badge = Color(hex: 0xE3DACC)

    /// A usage bar's fill: terracotta, earthier near the limit, as on the display.
    static func bar(_ pct: Int) -> Color { pct >= 80 ? alert : accent }

    static let mono = Font.system(size: 11, design: .monospaced)
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
