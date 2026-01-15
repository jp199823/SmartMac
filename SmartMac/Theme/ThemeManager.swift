import SwiftUI

/// Available app themes based on user-provided color palettes
enum AppTheme: String, CaseIterable, Identifiable {
    case casaBlanca = "Casa Blanca"
    case oceanTeal = "Ocean Teal"
    case parchment = "Parchment"
    case burntPeach = "Burnt Peach"
    case lavender = "Lavender"
    case cerulean = "Cerulean"
    
    var id: String { rawValue }
    
    /// Theme color definitions
    var colors: ThemeColors {
        switch self {
        case .casaBlanca:
            return ThemeColors(
                background: Color(hex: "F5F0E6"),
                secondaryBg: Color(hex: "EBE6DC"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "2D5A3D"),
                accentSecondary: Color(hex: "1E3A5F"),
                textPrimary: Color(hex: "1A1A1A"),
                textSecondary: Color(hex: "4A4A4A"),
                textTertiary: Color(hex: "7A7A7A"),
                success: Color(hex: "2D7A4D"),
                warning: Color(hex: "C68A35"),
                danger: Color(hex: "B64A4A"),
                info: Color(hex: "3A7AB6")
            )
        case .oceanTeal:
            return ThemeColors(
                background: Color(hex: "A2BCE0"),
                secondaryBg: Color(hex: "BEB8EB"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "0B5563"),
                accentSecondary: Color(hex: "5299D3"),
                textPrimary: Color(hex: "1A1A1A"),
                textSecondary: Color(hex: "5E5C6C"),
                textTertiary: Color(hex: "7A7A8A"),
                success: Color(hex: "0B5563"),
                warning: Color(hex: "D4A76A"),
                danger: Color(hex: "B64A4A"),
                info: Color(hex: "5299D3")
            )
        case .parchment:
            return ThemeColors(
                background: Color(hex: "F6F0ED"),
                secondaryBg: Color(hex: "E7DFC6"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "28536B"),
                accentSecondary: Color(hex: "7EA8BE"),
                textPrimary: Color(hex: "1A1A1A"),
                textSecondary: Color(hex: "4A4A4A"),
                textTertiary: Color(hex: "7A7A7A"),
                success: Color(hex: "5A8A5F"),
                warning: Color(hex: "C2948A"),
                danger: Color(hex: "B64A4A"),
                info: Color(hex: "7EA8BE")
            )
        case .burntPeach:
            return ThemeColors(
                background: Color(hex: "EAEAEA"),
                secondaryBg: Color(hex: "E8DAB2"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "DD6E42"),
                accentSecondary: Color(hex: "4F6D7A"),
                textPrimary: Color(hex: "1A1A1A"),
                textSecondary: Color(hex: "4F6D7A"),
                textTertiary: Color(hex: "8A8A8A"),
                success: Color(hex: "5A8A5F"),
                warning: Color(hex: "DD6E42"),
                danger: Color(hex: "C04A4A"),
                info: Color(hex: "4F6D7A")
            )
        case .lavender:
            return ThemeColors(
                background: Color(hex: "F9F5FF"),
                secondaryBg: Color(hex: "D4C2FC"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "998FC7"),
                accentSecondary: Color(hex: "14248A"),
                textPrimary: Color(hex: "28262C"),
                textSecondary: Color(hex: "4A4850"),
                textTertiary: Color(hex: "7A7880"),
                success: Color(hex: "5A8A6F"),
                warning: Color(hex: "C49A35"),
                danger: Color(hex: "B64A6A"),
                info: Color(hex: "998FC7")
            )
        case .cerulean:
            return ThemeColors(
                background: Color(hex: "E9F1F7"),
                secondaryBg: Color(hex: "E7DFC6"),
                cardBg: Color(hex: "FFFFFF"),
                accent: Color(hex: "2274A5"),
                accentSecondary: Color(hex: "816C61"),
                textPrimary: Color(hex: "131B23"),
                textSecondary: Color(hex: "3A4A5A"),
                textTertiary: Color(hex: "6A7A8A"),
                success: Color(hex: "3A8A5F"),
                warning: Color(hex: "C68A45"),
                danger: Color(hex: "B64A4A"),
                info: Color(hex: "2274A5")
            )
        }
    }
    
    /// Preview colors for theme picker display
    var previewColors: [Color] {
        [colors.background, colors.secondaryBg, colors.accent, colors.textPrimary]
    }
}

/// Container for all theme colors
struct ThemeColors {
    let background: Color
    let secondaryBg: Color
    let cardBg: Color
    let accent: Color
    let accentSecondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let success: Color
    let warning: Color
    let danger: Color
    let info: Color
}

/// Manages the current app theme with persistence
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.casaBlanca.rawValue
    
    @Published var currentTheme: AppTheme {
        didSet {
            selectedThemeRaw = currentTheme.rawValue
        }
    }
    
    init() {
        self.currentTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.casaBlanca.rawValue) ?? .casaBlanca
    }
    
    /// Current theme colors
    var colors: ThemeColors {
        currentTheme.colors
    }
    
    // MARK: - Quick Accessors
    var background: Color { colors.background }
    var secondaryBg: Color { colors.secondaryBg }
    var cardBg: Color { colors.cardBg }
    var accent: Color { colors.accent }
    var accentSecondary: Color { colors.accentSecondary }
    var textPrimary: Color { colors.textPrimary }
    var textSecondary: Color { colors.textSecondary }
    var textTertiary: Color { colors.textTertiary }
    var success: Color { colors.success }
    var warning: Color { colors.warning }
    var danger: Color { colors.danger }
    var info: Color { colors.info }
}

// MARK: - Environment Key for Theme
private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
