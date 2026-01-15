import SwiftUI

/// Reusable metric card component
struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
            }
            
            // Content
            content()
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Clickable metric card with hover effects for navigation
struct ClickableMetricCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 28, height: 28)
                        .background(iconColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    Spacer()
                    
                    // Navigation indicator on hover
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                        .opacity(isHovered ? 1 : 0)
                }
                
                // Content
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.smartMacCardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(iconColor.opacity(isHovered ? 0.4 : 0), lineWidth: 1.5)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .help("Click to view details")
    }
}

/// Simple metric display with label and value
struct SimpleMetric: View {
    let label: String
    let value: String
    let valueColor: Color
    
    init(label: String, value: String, valueColor: Color = .smartMacCasaBlanca) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

/// Metric row with label and value side by side
struct MetricRow: View {
    let label: String
    let value: String
    let valueColor: Color
    
    init(label: String, value: String, valueColor: Color = .smartMacCasaBlanca) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
    }
}
