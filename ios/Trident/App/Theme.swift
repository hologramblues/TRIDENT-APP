import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Palette exacte de la webapp (variables CSS de index.html).
enum Theme {
    static let bg = Color(hex: 0x08090C)
    static let dim = Color(hex: 0x3D4149)
    static let mid = Color(hex: 0x8B9099)
    static let bright = Color(hex: 0xE8E4DA)
    static let ember = Color(hex: 0xB8763D)
    /// Jaune des boutons du mode Notes (accent Apple Notes).
    static let notesYellow = Color(hex: 0xE0A800)

    /// Police principale de la webapp ('Avenir Next').
    static func main(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Avenir Next", size: size).weight(weight)
    }
    /// Police mono de la webapp ('SF Mono'/'Menlo').
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}
