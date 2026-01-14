import SwiftUI

/// Row displaying an application's memory usage
struct AppUsageRow: View {
    let app: RunningApplication
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            Text("\(rank)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.smartMacTextTertiary)
                .frame(width: 20)
            
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.smartMacNavyBlue.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundColor(.smartMacTextSecondary)
                    )
            }
            
            // App name
            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacCasaBlanca)
                .lineLimit(1)
            
            Spacer()
            
            // Memory usage
            Text(formatMemory(app.memoryUsage))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(memoryColor)
        }
        .padding(.vertical, 6)
    }
    
    private var memoryColor: Color {
        let mb = app.memoryUsageMB
        if mb > 1000 {
            return .smartMacWarning
        } else if mb > 500 {
            return .smartMacInfo
        }
        return .smartMacTextSecondary
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
