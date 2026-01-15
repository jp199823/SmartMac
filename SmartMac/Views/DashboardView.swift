import SwiftUI

/// Main dashboard view showing at-a-glance system health
struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var selectedTab: NavigationTab
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Main gauges
                mainGaugesSection
                
                // Details row
                HStack(alignment: .top, spacing: 20) {
                    // Top Applications
                    topAppsCard
                    
                    // Quick Stats
                    quickStatsCard
                }
            }
            .padding(32)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacCasaBlanca)
                
                Text("System overview at a glance")
                    .font(.smartMacBody)
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            // Last updated
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.smartMacSuccess)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.smartMacCardBg)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Main Gauges
    private var mainGaugesSection: some View {
        HStack(spacing: 20) {
            // RAM Gauge - Clickable to RAM Optimizer
            ClickableMetricCard(
                title: "Memory",
                icon: "memorychip",
                iconColor: .smartMacAccentBlue,
                action: { selectedTab = .ramOptimizer }
            ) {
                VStack(spacing: 16) {
                    CircularGauge(
                        value: monitor.memoryMetrics.usagePercentage,
                        label: "Used",
                        valueLabel: "\(Int(monitor.memoryMetrics.usagePercentage))%",
                        color: memoryColor,
                        size: 130
                    )
                    
                    HStack(spacing: 24) {
                        SimpleMetric(
                            label: "Available",
                            value: monitor.memoryMetrics.free.formattedBytesShort,
                            valueColor: .smartMacSuccess
                        )
                        SimpleMetric(
                            label: "Total",
                            value: monitor.memoryMetrics.total.formattedBytesShort
                        )
                    }
                }
            }
            
            // Storage Gauge - Clickable to Large Files
            ClickableMetricCard(
                title: "Storage",
                icon: "internaldrive",
                iconColor: .smartMacForestGreen,
                action: { selectedTab = .largeFiles }
            ) {
                VStack(spacing: 16) {
                    CircularGauge(
                        value: monitor.storageMetrics.usagePercentage,
                        label: "Used",
                        valueLabel: "\(Int(monitor.storageMetrics.usagePercentage))%",
                        color: storageColor,
                        size: 130
                    )
                    
                    HStack(spacing: 24) {
                        SimpleMetric(
                            label: "Free",
                            value: monitor.storageMetrics.free.formattedBytesShort,
                            valueColor: storageColor
                        )
                        SimpleMetric(
                            label: "Total",
                            value: monitor.storageMetrics.total.formattedBytesShort
                        )
                    }
                }
            }
            
            // System Health - Clickable to Technical Specs
            ClickableMetricCard(
                title: "System Health",
                icon: "heart.fill",
                iconColor: monitor.overallHealth.color,
                action: { selectedTab = .technicalSpecs }
            ) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(monitor.overallHealth.color.opacity(0.15))
                            .frame(width: 130, height: 130)
                        
                        VStack(spacing: 4) {
                            Image(systemName: healthIcon)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(monitor.overallHealth.color)
                            
                            Text(monitor.overallHealth.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.smartMacCasaBlanca)
                        }
                    }
                    
                    HStack(spacing: 24) {
                        SimpleMetric(
                            label: "CPU Temp",
                            value: monitor.cpuMetrics.thermalState.rawValue,
                            valueColor: thermalColor
                        )
                        SimpleMetric(
                            label: "CPU Usage",
                            value: "\(Int(monitor.cpuMetrics.usagePercentage))%"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Top Apps Card
    private var topAppsCard: some View {
        MetricCard(title: "Top Applications", icon: "square.grid.2x2", iconColor: .smartMacNavyBlue) {
            VStack(spacing: 0) {
                if monitor.topApplications.isEmpty {
                    Text("Loading...")
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    ForEach(Array(monitor.topApplications.enumerated()), id: \.element.id) { index, app in
                        AppUsageRow(app: app, rank: index + 1)
                        
                        if index < monitor.topApplications.count - 1 {
                            Divider()
                                .background(Color.smartMacTextTertiary.opacity(0.2))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Stats Card
    private var quickStatsCard: some View {
        MetricCard(title: "Quick Stats", icon: "chart.bar", iconColor: .smartMacAccentGreen) {
            VStack(spacing: 12) {
                MetricRow(
                    label: "CPU Model",
                    value: formatCPUName(monitor.cpuMetrics.modelName)
                )
                Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                
                MetricRow(
                    label: "CPU Cores",
                    value: "\(monitor.cpuMetrics.physicalCores) physical / \(monitor.cpuMetrics.logicalCores) logical"
                )
                Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                
                MetricRow(
                    label: "Network",
                    value: monitor.networkMetrics.connectionType,
                    valueColor: monitor.networkMetrics.isConnected ? .smartMacSuccess : .smartMacTextSecondary
                )
                Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                
                MetricRow(
                    label: "IP Address",
                    value: monitor.networkMetrics.ipAddress
                )
                
                if monitor.batteryMetrics.isPresent {
                    Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                    MetricRow(
                        label: "Battery",
                        value: "\(monitor.batteryMetrics.chargePercentage)%\(monitor.batteryMetrics.isCharging ? " ⚡" : "")",
                        valueColor: batteryColor
                    )
                }
            }
        }
        .frame(width: 340)
    }
    
    // MARK: - Helper Properties
    private var memoryColor: Color {
        let usage = monitor.memoryMetrics.usagePercentage
        if usage > 85 { return .smartMacDanger }
        if usage > 70 { return .smartMacWarning }
        return .smartMacAccentBlue
    }
    
    private var storageColor: Color {
        let free = monitor.storageMetrics.freePercentage
        if free < 10 { return .smartMacDanger }
        if free < 20 { return .smartMacWarning }
        return .smartMacForestGreen
    }
    
    private var thermalColor: Color {
        switch monitor.cpuMetrics.thermalState {
        case .nominal: return .smartMacSuccess
        case .fair: return .smartMacInfo
        case .serious: return .smartMacWarning
        case .critical: return .smartMacDanger
        }
    }
    
    private var batteryColor: Color {
        let charge = monitor.batteryMetrics.chargePercentage
        if charge < 20 { return .smartMacDanger }
        if charge < 50 { return .smartMacWarning }
        return .smartMacSuccess
    }
    
    private var healthIcon: String {
        switch monitor.overallHealth {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.octagon.fill"
        }
    }
    
    private func formatCPUName(_ name: String) -> String {
        // Truncate long CPU names
        if name.count > 30 {
            return String(name.prefix(27)) + "..."
        }
        return name
    }
}
