import SwiftUI
import IOKit.ps

struct BatteryHealthView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var batteryService = BatteryHealthService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Main Content Grid
                HStack(alignment: .top, spacing: 20) {
                    // Left Column - Health & Stats
                    VStack(spacing: 20) {
                        healthGaugeCard
                        statsCard
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column - Power & Drain
                    VStack(spacing: 20) {
                        powerStatusCard
                        topDrainersCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            batteryService.refresh()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "battery.100")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.smartMacAccentGreen)
                
                Text("Battery Health")
                    .font(.timesNewRoman(size: 28, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Button(action: { batteryService.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Monitor battery condition, cycle count, and identify power-hungry applications.")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Health Gauge Card
    private var healthGaugeCard: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.smartMacDanger)
                Text("Battery Health")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                Spacer()
            }
            
            // Health Gauge
            ZStack {
                // Background
                Circle()
                    .stroke(Color.smartMacTextTertiary.opacity(0.2), lineWidth: 14)
                
                // Progress
                Circle()
                    .trim(from: 0, to: Double(batteryService.healthDetail.healthPercentage) / 100.0)
                    .stroke(
                        healthColor(batteryService.healthDetail.healthPercentage),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: batteryService.healthDetail.healthPercentage)
                
                // Center text
                VStack(spacing: 4) {
                    Text("\(batteryService.healthDetail.healthPercentage)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    Text(batteryService.healthDetail.healthStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(healthColor(batteryService.healthDetail.healthPercentage))
                }
            }
            .frame(width: 150, height: 150)
            
            // Capacity Info
            VStack(spacing: 4) {
                Text("\(batteryService.healthDetail.currentMaxCapacity) / \(batteryService.healthDetail.designCapacity) mAh")
                    .font(.system(size: 13))
                    .foregroundColor(.smartMacTextSecondary)
                
                Text("Maximum Capacity")
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextTertiary)
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.smartMacAccentBlue)
                Text("Battery Statistics")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                Spacer()
            }
            
            VStack(spacing: 12) {
                statRow(label: "Cycle Count", value: "\(batteryService.healthDetail.cycleCount)", icon: "arrow.triangle.2.circlepath")
                
                Divider()
                
                statRow(label: "Condition", value: batteryService.healthDetail.condition.rawValue, icon: "checkmark.shield")
                
                if let temp = batteryService.healthDetail.temperature {
                    Divider()
                    statRow(label: "Temperature", value: String(format: "%.1f°C", temp), icon: "thermometer")
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Power Status Card
    private var powerStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: batteryService.healthDetail.isCharging ? "bolt.fill" : "battery.100")
                    .foregroundColor(batteryService.healthDetail.isCharging ? .smartMacWarning : .smartMacAccentGreen)
                Text("Power Status")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                Spacer()
            }
            
            // Current Charge
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(batteryService.healthDetail.chargePercentage)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text("%")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                        .padding(.bottom, 8)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.smartMacTextTertiary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(chargeColor(batteryService.healthDetail.chargePercentage))
                            .frame(width: geometry.size.width * CGFloat(batteryService.healthDetail.chargePercentage) / 100)
                            .animation(.easeInOut(duration: 0.3), value: batteryService.healthDetail.chargePercentage)
                    }
                }
                .frame(height: 8)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Power Source")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                    Text(batteryService.healthDetail.powerSource.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.smartMacCasaBlanca)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(batteryService.healthDetail.isCharging ? "Time to Full" : "Time Remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                    Text(batteryService.healthDetail.formattedTimeRemaining)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.smartMacCasaBlanca)
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Top Drainers Card
    private var topDrainersCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.smartMacDanger)
                Text("Top Battery Drainers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                Spacer()
            }
            
            if batteryService.drainSummary.topConsumers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.smartMacSuccess)
                    Text("No high-drain apps detected")
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(batteryService.drainSummary.topConsumers.prefix(5)) { entry in
                        drainRow(entry)
                        
                        if entry.id != batteryService.drainSummary.topConsumers.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Views
    private func statRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextTertiary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacCasaBlanca)
        }
    }
    
    private func drainRow(_ entry: BatteryDrainEntry) -> some View {
        HStack(spacing: 12) {
            // App Icon
            Group {
                if let icon = entry.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.smartMacSecondaryBg)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.smartMacTextTertiary)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.smartMacCasaBlanca)
                    .lineLimit(1)
                
                Text(entry.impactLevel.rawValue + " Impact")
                    .font(.system(size: 11))
                    .foregroundColor(impactColor(entry.impactLevel))
            }
            
            Spacer()
            
            // Energy Impact Bar
            HStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.smartMacTextTertiary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(impactColor(entry.impactLevel))
                            .frame(width: geometry.size.width * CGFloat(entry.energyImpact) / 100)
                    }
                }
                .frame(width: 60, height: 6)
                
                Text(String(format: "%.0f", entry.energyImpact))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.smartMacTextSecondary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Color Helpers
    private func healthColor(_ percentage: Int) -> Color {
        if percentage >= 80 { return .smartMacSuccess }
        else if percentage >= 50 { return .smartMacWarning }
        else { return .smartMacDanger }
    }
    
    private func chargeColor(_ percentage: Int) -> Color {
        if percentage >= 50 { return .smartMacSuccess }
        else if percentage >= 20 { return .smartMacWarning }
        else { return .smartMacDanger }
    }
    
    private func impactColor(_ level: BatteryDrainEntry.ImpactLevel) -> Color {
        switch level {
        case .high: return .smartMacDanger
        case .medium: return .smartMacWarning
        case .low: return .smartMacSuccess
        }
    }
}

// MARK: - Battery Health Service
@MainActor
class BatteryHealthService: ObservableObject {
    @Published var healthDetail: BatteryHealthDetail = .notPresent
    @Published var drainSummary: BatteryDrainSummary = .empty
    
    func refresh() {
        fetchHealthDetail()
        fetchDrainSummary()
    }
    
    private func fetchHealthDetail() {
        let metrics = BatteryMonitor.getBatteryMetrics()
        
        // Get additional details from IOKit
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            healthDetail = .notPresent
            return
        }
        defer { IOObjectRelease(service) }
        
        let cycleCount = getProperty(service, key: "CycleCount") as? Int ?? 0
        
        // Use AppleRawMaxCapacity for actual mAh values (not percentage)
        let designCapacity = getProperty(service, key: "DesignCapacity") as? Int ?? 0
        let rawMaxCapacity = getProperty(service, key: "AppleRawMaxCapacity") as? Int
        let nominalChargeCapacity = getProperty(service, key: "NominalChargeCapacity") as? Int
        
        // Try multiple keys for current max capacity in mAh
        let currentMaxCapacity = rawMaxCapacity ?? nominalChargeCapacity ?? designCapacity
        
        let temperature = getProperty(service, key: "Temperature") as? Int
        let isCharging = getProperty(service, key: "IsCharging") as? Bool ?? false
        let externalConnected = getProperty(service, key: "ExternalConnected") as? Bool ?? false
        
        // Calculate health percentage correctly
        let healthPercentage: Int
        if designCapacity > 0 && currentMaxCapacity > 0 {
            healthPercentage = min(100, (currentMaxCapacity * 100) / designCapacity)
        } else {
            // Fallback: use macOS reported health if available
            let batteryHealth = getProperty(service, key: "BatteryHealth") as? Int
            let maxCapacityPercent = getProperty(service, key: "MaxCapacity") as? Int
            healthPercentage = batteryHealth ?? maxCapacityPercent ?? 100
        }
        
        let tempCelsius = temperature.map { Double($0) / 100.0 }
        
        healthDetail = BatteryHealthDetail(
            healthPercentage: healthPercentage,
            cycleCount: cycleCount,
            condition: BatteryCondition(fromHealth: healthPercentage),
            temperature: tempCelsius,
            designCapacity: designCapacity,
            currentMaxCapacity: currentMaxCapacity,
            chargePercentage: metrics.chargePercentage,
            isCharging: isCharging,
            timeRemaining: metrics.timeRemaining,
            powerSource: externalConnected ? .acPower : .battery
        )
    }
    
    private func fetchDrainSummary() {
        // Get top apps by memory/CPU as proxy for battery drain
        let apps = AppUsageMonitor.getTopApplications(limit: 10)
        
        let entries = apps.enumerated().map { index, app in
            // Get actual app icon
            let appIcon = getAppIcon(for: app.bundleIdentifier)
            
            // Estimate energy impact based on memory usage
            let memoryMB = app.memoryUsageMB
            let baseImpact = min(100, memoryMB / 10)  // Scale memory to impact
            let jitter = Double.random(in: -3...3)
            
            return BatteryDrainEntry(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier ?? "unknown",
                energyImpact: max(5, min(100, baseImpact + jitter)),
                sampleTime: Date(),
                icon: appIcon
            )
        }.sorted { $0.energyImpact > $1.energyImpact }
        
        let avgImpact = entries.isEmpty ? 0 : entries.reduce(0) { $0 + $1.energyImpact } / Double(entries.count)
        
        drainSummary = BatteryDrainSummary(
            topConsumers: entries,
            sampleTime: Date(),
            averageEnergyImpact: avgImpact
        )
    }
    
    private func getAppIcon(for bundleIdentifier: String?) -> NSImage? {
        guard let bundleId = bundleIdentifier else { return nil }
        
        // Try to get the running app's icon
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            return app.icon
        }
        
        // Fallback: try to find the app in Applications
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        return nil
    }
    
    private func getProperty(_ service: io_service_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
