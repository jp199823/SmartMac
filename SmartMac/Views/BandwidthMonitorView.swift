import SwiftUI
import Charts

struct BandwidthMonitorView: View {
    @StateObject private var bandwidthMonitor = BandwidthMonitor.shared
    @State private var selectedPeriod: BandwidthPeriod = .today
    @State private var showAlertSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Live Speed Gauges
                liveSpeedSection
                
                // Period Selector
                periodSelector
                
                // Usage Summary Cards
                usageSummarySection
                
                // Usage Chart
                usageChartSection
                
                // Alert Configuration
                alertSection
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bandwidth Monitor")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                Text("Real-time network usage tracking")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            // Reset Button
            Button(action: { bandwidthMonitor.resetStatistics() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.smartMacCardBg)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Live Speed Section
    private var liveSpeedSection: some View {
        HStack(spacing: 20) {
            // Download Speed
            SpeedGaugeCard(
                title: "Download",
                speed: bandwidthMonitor.currentSpeed.downloadMbps,
                formattedSpeed: bandwidthMonitor.currentSpeed.formattedDownload,
                peakSpeed: bandwidthMonitor.peakDownloadSpeed,
                color: .smartMacAccentGreen,
                icon: "arrow.down.circle.fill"
            )
            
            // Upload Speed
            SpeedGaugeCard(
                title: "Upload",
                speed: bandwidthMonitor.currentSpeed.uploadMbps,
                formattedSpeed: bandwidthMonitor.currentSpeed.formattedUpload,
                peakSpeed: bandwidthMonitor.peakUploadSpeed,
                color: .smartMacAccentBlue,
                icon: "arrow.up.circle.fill"
            )
        }
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(BandwidthPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: period.icon)
                            .font(.system(size: 12))
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedPeriod == period ? .smartMacTextPrimary : .smartMacTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedPeriod == period ? Color.smartMacAccentGreen.opacity(0.3) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.smartMacCardBg)
        .cornerRadius(10)
    }
    
    // MARK: - Usage Summary
    private var usageSummarySection: some View {
        HStack(spacing: 16) {
            UsageCard(
                title: "Downloaded",
                value: usageForPeriod.received.formattedBytes,
                icon: "arrow.down.circle.fill",
                color: .smartMacAccentGreen
            )
            
            UsageCard(
                title: "Uploaded",
                value: usageForPeriod.sent.formattedBytes,
                icon: "arrow.up.circle.fill",
                color: .smartMacAccentBlue
            )
            
            UsageCard(
                title: "Total",
                value: (usageForPeriod.received + usageForPeriod.sent).formattedBytes,
                icon: "arrow.up.arrow.down.circle.fill",
                color: .smartMacWarning
            )
            
            UsageCard(
                title: "Peak Download",
                value: String(format: "%.1f Mbps", bandwidthMonitor.peakDownloadSpeed),
                icon: "bolt.fill",
                color: .smartMacInfo
            )
        }
    }
    
    private var usageForPeriod: (received: UInt64, sent: UInt64) {
        switch selectedPeriod {
        case .today:
            return bandwidthMonitor.todayUsage
        case .thisWeek:
            let weekData = bandwidthMonitor.dailyData.suffix(7)
            let received = weekData.reduce(0) { $0 + $1.bytesReceived }
            let sent = weekData.reduce(0) { $0 + $1.bytesSent }
            return (received, sent)
        case .thisMonth:
            let monthData = bandwidthMonitor.dailyData.suffix(30)
            let received = monthData.reduce(0) { $0 + $1.bytesReceived }
            let sent = monthData.reduce(0) { $0 + $1.bytesSent }
            return (received, sent)
        }
    }
    
    // MARK: - Chart Section
    private var usageChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Over Time")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            if selectedPeriod == .today {
                hourlyChart
            } else {
                dailyChart
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
    
    private var hourlyChart: some View {
        Chart(bandwidthMonitor.hourlyData) { data in
            BarMark(
                x: .value("Hour", data.hour, unit: .hour),
                y: .value("Bytes", data.totalBytes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.smartMacAccentGreen, .smartMacAccentBlue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(UInt64.self) {
                        Text(bytes.formattedBytes)
                    }
                }
            }
        }
        .frame(height: 200)
    }
    
    private var dailyChart: some View {
        Chart(bandwidthMonitor.dailyData.suffix(selectedPeriod == .thisWeek ? 7 : 30)) { data in
            BarMark(
                x: .value("Day", data.date, unit: .day),
                y: .value("Bytes", data.totalBytes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.smartMacAccentGreen, .smartMacAccentBlue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(UInt64.self) {
                        Text(bytes.formattedBytes)
                    }
                }
            }
        }
        .frame(height: 200)
    }
    
    // MARK: - Alert Section
    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage Alerts")
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { bandwidthMonitor.alertConfig.isEnabled },
                    set: { bandwidthMonitor.toggleAlerts($0) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.8)
            }
            
            if bandwidthMonitor.alertConfig.isEnabled {
                VStack(spacing: 16) {
                    AlertSlider(
                        title: "Daily Limit",
                        value: Binding(
                            get: { bandwidthMonitor.alertConfig.dailyLimitGB },
                            set: { bandwidthMonitor.setDailyLimit($0) }
                        ),
                        currentUsage: bandwidthMonitor.alertConfig.currentDailyUsageGB,
                        range: 1...50,
                        unit: "GB"
                    )
                    
                    AlertSlider(
                        title: "Monthly Limit",
                        value: Binding(
                            get: { bandwidthMonitor.alertConfig.monthlyLimitGB },
                            set: { bandwidthMonitor.setMonthlyLimit($0) }
                        ),
                        currentUsage: bandwidthMonitor.alertConfig.currentMonthlyUsageGB,
                        range: 10...500,
                        unit: "GB"
                    )
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Speed Gauge Card
struct SpeedGaugeCard: View {
    let title: String
    let speed: Double
    let formattedSpeed: String
    let peakSpeed: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                Spacer()
            }
            
            // Speed Ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: min(speed / max(peakSpeed, 100), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: speed)
                
                VStack(spacing: 4) {
                    Text(formattedSpeed)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacTextPrimary)
                    Text("Current")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                }
            }
            .frame(width: 120, height: 120)
            
            HStack {
                Text("Peak:")
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextTertiary)
                Text(String(format: "%.1f Mbps", peakSpeed))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smartMacTextSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Usage Card
struct UsageCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.smartMacTextPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.smartMacCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Alert Slider
struct AlertSlider: View {
    let title: String
    @Binding var value: Double
    let currentUsage: Double
    let range: ClosedRange<Double>
    let unit: String
    
    private var percentUsed: Double {
        guard value > 0 else { return 0 }
        return min((currentUsage / value) * 100, 100)
    }
    
    private var statusColor: Color {
        if percentUsed >= 90 { return .smartMacDanger }
        if percentUsed >= 75 { return .smartMacWarning }
        return .smartMacSuccess
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                
                Spacer()
                
                Text(String(format: "%.1f / %.0f %@", currentUsage, value, unit))
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.smartMacSecondaryBg)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * (percentUsed / 100))
                }
            }
            .frame(height: 8)
            
            Slider(value: $value, in: range, step: 1)
                .accentColor(.smartMacAccentGreen)
        }
        .padding(12)
        .background(Color.smartMacSecondaryBg.opacity(0.5))
        .cornerRadius(10)
    }
}
