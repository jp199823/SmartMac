import SwiftUI

/// SmartMac Color Palette
/// Dynamic theme-aware colors that respond to ThemeManager changes
extension Color {
    // MARK: - Backgrounds (Dynamic from Theme)
    static var smartMacBackground: Color { ThemeManager.shared.background }
    static var smartMacSecondaryBg: Color { ThemeManager.shared.secondaryBg }
    static var smartMacCardBg: Color { ThemeManager.shared.cardBg }
    
    // MARK: - Accents (Dynamic from Theme)
    static var smartMacForestGreen: Color { ThemeManager.shared.accent }
    static var smartMacNavyBlue: Color { ThemeManager.shared.accentSecondary }
    static var smartMacAccentGreen: Color { ThemeManager.shared.accent }
    static var smartMacAccentBlue: Color { ThemeManager.shared.accentSecondary }
    
    // MARK: - Text (Dynamic from Theme)
    static var smartMacCasaBlanca: Color { ThemeManager.shared.textPrimary }
    static var smartMacTextPrimary: Color { ThemeManager.shared.textPrimary }
    static var smartMacTextSecondary: Color { ThemeManager.shared.textSecondary }
    static var smartMacTextTertiary: Color { ThemeManager.shared.textTertiary }
    
    // MARK: - Status Colors (Dynamic from Theme)
    static var smartMacSuccess: Color { ThemeManager.shared.success }
    static var smartMacWarning: Color { ThemeManager.shared.warning }
    static var smartMacDanger: Color { ThemeManager.shared.danger }
    static var smartMacInfo: Color { ThemeManager.shared.info }
}

// MARK: - Custom Font
extension Font {
    /// Times New Roman font for sleek, classic look
    static func timesNewRoman(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .bold, .semibold, .heavy, .black:
            fontName = "Times New Roman Bold"
        case .light, .ultraLight, .thin:
            fontName = "Times New Roman"
        default:
            fontName = "Times New Roman"
        }
        return .custom(fontName, size: size)
    }
    
    // Convenience methods for common sizes
    static let smartMacTitle = timesNewRoman(size: 28, weight: .bold)
    static let smartMacHeadline = timesNewRoman(size: 18, weight: .semibold)
    static let smartMacBody = timesNewRoman(size: 14)
    static let smartMacCaption = timesNewRoman(size: 12)
    static let smartMacSmall = timesNewRoman(size: 11)
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

