import SwiftUI
import Charts

struct HistoricalTrendsView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var dataStore = HistoricalDataStore.shared
    @State private var selectedMetric: MetricType = .ram
    @State private var selectedRange: TimeRange = .hour
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Controls
                controlsSection
                
                // Main Chart
                chartCard
                
                // Stats Grid
                statsGrid
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            recordCurrentMetrics()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.smartMacAccentGreen)
                
                Text("Historical Trends")
                    .font(.timesNewRoman(size: 28, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
            }
            
            Text("Visualize RAM, CPU, and Storage usage patterns over time.")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Controls
    private var controlsSection: some View {
        HStack(spacing: 16) {
            // Metric Selector
            HStack(spacing: 0) {
                ForEach(MetricType.allCases) { metric in
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMetric = metric
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 12))
                            Text(metric.rawValue.replacingOccurrences(of: " Usage", with: "").replacingOccurrences(of: " Used", with: ""))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedMetric == metric ? .white : .smartMacTextSecondary)
                        .background(
                            selectedMetric == metric ? metricColor(metric) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.smartMacCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            // Time Range Selector
            HStack(spacing: 0) {
                ForEach(TimeRange.allCases) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedRange == range ? .white : .smartMacTextSecondary)
                            .background(
                                selectedRange == range ? Color.smartMacForestGreen : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.smartMacCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Chart Card
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: selectedMetric.icon)
                    .foregroundColor(metricColor(selectedMetric))
                Text(selectedMetric.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Text(selectedRange.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            // Chart
            let history = dataStore.getHistory(for: selectedMetric)
            let filteredData = history.filtered(for: selectedRange)
            
            if filteredData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(filteredData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [metricColor(selectedMetric), metricColor(selectedMetric).opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [metricColor(selectedMetric).opacity(0.3), metricColor(selectedMetric).opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.smartMacTextTertiary.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Color.smartMacTextTertiary)
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.smartMacTextTertiary.opacity(0.3))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.smartMacTextTertiary)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .animation(.easeInOut(duration: 0.3), value: selectedMetric)
                .animation(.easeInOut(duration: 0.3), value: selectedRange)
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Empty Chart Placeholder
    private var emptyChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.smartMacTextTertiary)
            
            Text("No Data Available")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.smartMacTextSecondary)
            
            Text("Data will appear as SmartMac runs and collects metrics over time.")
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        let stats = dataStore.getStats(for: selectedMetric, range: selectedRange)
        
        return HStack(spacing: 16) {
            statCard(title: "Current", value: stats.formattedCurrent, icon: "circle.fill", color: metricColor(selectedMetric))
            statCard(title: "Average", value: stats.formattedAverage, icon: "minus", color: .smartMacTextSecondary)
            statCard(title: "Minimum", value: stats.formattedMin, icon: "arrow.down", color: .smartMacSuccess)
            statCard(title: "Maximum", value: stats.formattedMax, icon: "arrow.up", color: .smartMacDanger)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.smartMacCasaBlanca)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Helpers
    private func metricColor(_ metric: MetricType) -> Color {
        switch metric {
        case .ram: return .smartMacAccentGreen
        case .cpu: return .smartMacAccentBlue
        case .storage: return .smartMacNavyBlue
        }
    }
    
    private func recordCurrentMetrics() {
        let ram = monitor.memoryMetrics.usagePercentage
        let cpu = monitor.cpuMetrics.usagePercentage
        let storage = 100 - monitor.storageMetrics.freePercentage
        
        dataStore.recordDataPoint(ram: ram, cpu: cpu, storage: storage)
    }
}
