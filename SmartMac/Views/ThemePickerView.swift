import SwiftUI

/// Theme picker view showing all available themes with live preview
struct ThemePickerView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Theme")
                    .font(.timesNewRoman(size: 22, weight: .bold))
                    .foregroundColor(themeManager.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Theme grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.currentTheme = theme
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 480)
        .background(themeManager.background)
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Color preview bars
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.previewColors[index])
                            .frame(height: 60)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
                
                // Theme name
                HStack {
                    Text(theme.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.colors.accent)
                    }
                }
            }
            .padding(12)
            .background(theme.colors.cardBg)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? theme.colors.accent : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

