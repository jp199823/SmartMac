import SwiftUI

/// Circular gauge component for displaying percentages
struct CircularGauge: View {
    let value: Double          // 0-100
    let label: String
    let valueLabel: String
    let color: Color
    let size: CGFloat
    
    init(value: Double, label: String, valueLabel: String, color: Color, size: CGFloat = 120) {
        self.value = min(max(value, 0), 100)
        self.label = label
        self.valueLabel = valueLabel
        self.color = color
        self.size = size
    }
    
    private var progress: Double {
        value / 100.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track
                Circle()
                    .stroke(
                        Color.smartMacTextTertiary.opacity(0.2),
                        lineWidth: 10
                    )
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content
                VStack(spacing: 2) {
                    Text(valueLabel)
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacCasaBlanca)
                }
            }
            .frame(width: size, height: size)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
}

/// Mini gauge for compact displays
struct MiniGauge: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        CircularGauge(
            value: value,
            label: label,
            valueLabel: "\(Int(value))%",
            color: color,
            size: 80
        )
    }
}
