import SwiftUI

/// Detailed technical specifications view
struct TechnicalSpecsView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // CPU Section
                cpuSection
                
                // Memory Section
                memorySection
                
                // Storage Section
                storageSection
                
                // GPU Section
                gpuSection
                
                // Network Section
                networkSection
                
                // Battery Section (if present)
                if monitor.batteryMetrics.isPresent {
                    batterySection
                }
            }
            .padding(32)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Technical Specs")
                .font(.smartMacTitle)
                .foregroundColor(.smartMacCasaBlanca)
            
            Text("Detailed system information and performance metrics")
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - CPU Section
    private var cpuSection: some View {
        MetricCard(title: "Processor", icon: "cpu", iconColor: .smartMacAccentBlue) {
            VStack(spacing: 16) {
                // CPU Name
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monitor.cpuMetrics.modelName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.smartMacCasaBlanca)
                        Text("\(monitor.cpuMetrics.physicalCores) performance cores, \(monitor.cpuMetrics.logicalCores) total threads")
                            .font(.system(size: 13))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    Spacer()
                }
                
                Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                
                HStack(spacing: 32) {
                    // Usage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usage")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                        
                        HStack(spacing: 12) {
                            ProgressView(value: monitor.cpuMetrics.usagePercentage / 100)
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(cpuUsageColor)
                                .frame(width: 100)
                            
                            Text("\(Int(monitor.cpuMetrics.usagePercentage))%")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(cpuUsageColor)
                        }
                    }
                    
                    // Thermal State
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Thermal State")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(thermalColor)
                                .frame(width: 8, height: 8)
                            Text(monitor.cpuMetrics.thermalState.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(thermalColor)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Memory Section
    private var memorySection: some View {
        MetricCard(title: "Memory", icon: "memorychip", iconColor: .smartMacForestGreen) {
            VStack(spacing: 16) {
                // Memory bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        // Active
                        Rectangle()
                            .fill(Color.smartMacAccentBlue)
                            .frame(width: geometry.size.width * activeRatio)
                        
                        // Wired
                        Rectangle()
                            .fill(Color.smartMacWarning)
                            .frame(width: geometry.size.width * wiredRatio)
                        
                        // Compressed
                        Rectangle()
                            .fill(Color.smartMacNavyBlue)
                            .frame(width: geometry.size.width * compressedRatio)
                        
                        // Free
                        Rectangle()
                            .fill(Color.smartMacTextTertiary.opacity(0.3))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 12)
                
                // Legend
                HStack(spacing: 24) {
                    MemoryLegendItem(color: .smartMacAccentBlue, label: "Active", value: monitor.memoryMetrics.active.formattedBytesShort)
                    MemoryLegendItem(color: .smartMacWarning, label: "Wired", value: monitor.memoryMetrics.wired.formattedBytesShort)
                    MemoryLegendItem(color: .smartMacNavyBlue, label: "Compressed", value: monitor.memoryMetrics.compressed.formattedBytesShort)
                    MemoryLegendItem(color: .smartMacTextTertiary.opacity(0.3), label: "Free", value: monitor.memoryMetrics.free.formattedBytesShort)
                }
                
                Divider().background(Color.smartMacTextTertiary.opacity(0.2))
                
                HStack(spacing: 40) {
                    SimpleMetric(label: "Total RAM", value: monitor.memoryMetrics.total.formattedBytesShort)
                    SimpleMetric(label: "Used", value: monitor.memoryMetrics.used.formattedBytesShort)
                    SimpleMetric(label: "Available", value: monitor.memoryMetrics.free.formattedBytesShort, valueColor: .smartMacSuccess)
                }
            }
        }
    }
    
    // MARK: - Storage Section
    private var storageSection: some View {
        MetricCard(title: "Storage", icon: "internaldrive", iconColor: .smartMacAccentGreen) {
            VStack(spacing: 16) {
                // Storage bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.smartMacForestGreen)
                            .frame(width: geometry.size.width * (monitor.storageMetrics.usagePercentage / 100))
                        
                        Rectangle()
                            .fill(Color.smartMacTextTertiary.opacity(0.3))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 12)
                
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monitor.storageMetrics.volumeName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.smartMacCasaBlanca)
                        Text(monitor.storageMetrics.mountPoint)
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    
                    Spacer()
                    
                    SimpleMetric(label: "Used", value: monitor.storageMetrics.used.formattedBytesShort)
                    SimpleMetric(label: "Free", value: monitor.storageMetrics.free.formattedBytesShort, valueColor: storageColor)
                    SimpleMetric(label: "Total", value: monitor.storageMetrics.total.formattedBytesShort)
                }
            }
        }
    }
    
    // MARK: - GPU Section
    private var gpuSection: some View {
        MetricCard(title: "Graphics", icon: "rectangle.on.rectangle", iconColor: .smartMacNavyBlue) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.gpuMetrics.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    HStack(spacing: 16) {
                        Text(monitor.gpuMetrics.vendor)
                            .font(.system(size: 13))
                            .foregroundColor(.smartMacTextSecondary)
                        
                        if monitor.gpuMetrics.isIntegrated {
                            Text("Integrated • Shared Memory")
                                .font(.system(size: 12))
                                .foregroundColor(.smartMacTextTertiary)
                        } else if monitor.gpuMetrics.vram > 0 {
                            Text("VRAM: \(monitor.gpuMetrics.vram.formattedBytesShort)")
                                .font(.system(size: 12))
                                .foregroundColor(.smartMacTextTertiary)
                        }
                    }
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Network Section
    private var networkSection: some View {
        MetricCard(title: "Network", icon: "network", iconColor: .smartMacInfo) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.networkMetrics.isConnected ? Color.smartMacSuccess : Color.smartMacDanger)
                            .frame(width: 8, height: 8)
                        Text(monitor.networkMetrics.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.smartMacCasaBlanca)
                    }
                    
                    Text(monitor.networkMetrics.connectionType)
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                SimpleMetric(label: "IP Address", value: monitor.networkMetrics.ipAddress)
                SimpleMetric(label: "Downloaded", value: monitor.networkMetrics.bytesReceived.formattedBytesShort)
                SimpleMetric(label: "Uploaded", value: monitor.networkMetrics.bytesSent.formattedBytesShort)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Battery Section
    private var batterySection: some View {
        MetricCard(title: "Battery", icon: "battery.100", iconColor: .smartMacSuccess) {
            HStack(spacing: 40) {
                // Battery visual
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 24))
                            .foregroundColor(batteryColor)
                        
                        Text("\(monitor.batteryMetrics.chargePercentage)%")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.smartMacCasaBlanca)
                        
                        if monitor.batteryMetrics.isCharging {
                            Text("Charging")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.smartMacSuccess)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.smartMacSuccess.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                SimpleMetric(label: "Health", value: monitor.batteryMetrics.health)
                SimpleMetric(label: "Cycle Count", value: "\(monitor.batteryMetrics.cycleCount)")
                
                if let timeRemaining = monitor.batteryMetrics.timeRemaining {
                    SimpleMetric(label: "Time Remaining", value: formatTime(timeRemaining))
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Properties
    private var cpuUsageColor: Color {
        let usage = monitor.cpuMetrics.usagePercentage
        if usage > 90 { return .smartMacDanger }
        if usage > 70 { return .smartMacWarning }
        return .smartMacAccentBlue
    }
    
    private var thermalColor: Color {
        switch monitor.cpuMetrics.thermalState {
        case .nominal: return .smartMacSuccess
        case .fair: return .smartMacInfo
        case .serious: return .smartMacWarning
        case .critical: return .smartMacDanger
        }
    }
    
    private var storageColor: Color {
        let free = monitor.storageMetrics.freePercentage
        if free < 10 { return .smartMacDanger }
        if free < 20 { return .smartMacWarning }
        return .smartMacSuccess
    }
    
    private var batteryColor: Color {
        let charge = monitor.batteryMetrics.chargePercentage
        if charge < 20 { return .smartMacDanger }
        if charge < 50 { return .smartMacWarning }
        return .smartMacSuccess
    }
    
    private var batteryIcon: String {
        let charge = monitor.batteryMetrics.chargePercentage
        if monitor.batteryMetrics.isCharging {
            return "battery.100.bolt"
        }
        if charge > 75 { return "battery.100" }
        if charge > 50 { return "battery.75" }
        if charge > 25 { return "battery.50" }
        return "battery.25"
    }
    
    // Memory ratios
    private var activeRatio: Double {
        guard monitor.memoryMetrics.total > 0 else { return 0 }
        return Double(monitor.memoryMetrics.active) / Double(monitor.memoryMetrics.total)
    }
    
    private var wiredRatio: Double {
        guard monitor.memoryMetrics.total > 0 else { return 0 }
        return Double(monitor.memoryMetrics.wired) / Double(monitor.memoryMetrics.total)
    }
    
    private var compressedRatio: Double {
        guard monitor.memoryMetrics.total > 0 else { return 0 }
        return Double(monitor.memoryMetrics.compressed) / Double(monitor.memoryMetrics.total)
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Memory Legend Item
struct MemoryLegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smartMacCasaBlanca)
            }
        }
    }
}
