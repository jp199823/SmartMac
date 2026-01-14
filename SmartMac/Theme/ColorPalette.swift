import SwiftUI

/// SmartMac Color Palette
/// Light theme: Casa Blanca background with dark text
extension Color {
    // MARK: - Backgrounds (Light Theme)
    static let smartMacBackground = Color(hex: "F5F0E6")           // Casa Blanca (warm off-white)
    static let smartMacSecondaryBg = Color(hex: "EBE6DC")          // Slightly darker Casa Blanca
    static let smartMacCardBg = Color(hex: "FFFFFF")               // White cards for contrast
    
    // MARK: - Accents
    static let smartMacForestGreen = Color(hex: "2D5A3D")          // Forest Green
    static let smartMacNavyBlue = Color(hex: "1E3A5F")             // Navy Blue
    static let smartMacAccentGreen = Color(hex: "3D7A52")          // Lighter green for highlights
    static let smartMacAccentBlue = Color(hex: "2E5A8F")           // Lighter blue for highlights
    
    // MARK: - Text (Dark on Light)
    static let smartMacCasaBlanca = Color(hex: "1A1A1A")           // Near black for primary text
    static let smartMacTextPrimary = Color(hex: "1A1A1A")          // Alias for primary text
    static let smartMacTextSecondary = Color(hex: "4A4A4A")        // Dark gray
    static let smartMacTextTertiary = Color(hex: "7A7A7A")         // Medium gray
    
    // MARK: - Status Colors
    static let smartMacSuccess = Color(hex: "2D7A4D")              // Darker green for light bg
    static let smartMacWarning = Color(hex: "C68A35")              // Darker amber
    static let smartMacDanger = Color(hex: "B64A4A")               // Darker red
    static let smartMacInfo = Color(hex: "3A7AB6")                 // Darker blue
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
