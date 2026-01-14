import SwiftUI

struct StartupTimeView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var startupMonitor = StartupMonitor.shared
    @State private var showHighImpactOnly: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // System Info Cards
                systemInfoSection
                
                // Impact Summary
                impactSummarySection
                
                // Login Items List
                startupItemsSection
                
                // Help Section
                helpSection
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Startup Time Tracker")
                    .font(.timesNewRoman(size: 28, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                Text("Manage login items and optimize boot time")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            Button(action: { startupMonitor.refreshItems() }) {
                HStack(spacing: 6) {
                    if startupMonitor.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.smartMacTextSecondary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(startupMonitor.isLoading)
        }
    }
    
    // MARK: - System Info Section
    private var systemInfoSection: some View {
        HStack(spacing: 16) {
            // System Uptime
            SystemInfoCard(
                title: "System Uptime",
                value: startupMonitor.getFormattedUptime(),
                icon: "clock.fill",
                color: .smartMacForestGreen
            )
            
            // Last Boot Time
            if let lastBoot = startupMonitor.bootTimeHistory.latestBootTime {
                SystemInfoCard(
                    title: "Last Boot Time",
                    value: formatBootTime(lastBoot),
                    icon: "power",
                    color: .smartMacNavyBlue
                )
            } else {
                SystemInfoCard(
                    title: "Last Boot Time",
                    value: "N/A",
                    icon: "power",
                    color: .smartMacNavyBlue
                )
            }
            
            // Average Boot Time
            if startupMonitor.bootTimeHistory.averageBootTime > 0 {
                SystemInfoCard(
                    title: "Average Boot",
                    value: formatBootTime(startupMonitor.bootTimeHistory.averageBootTime),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .smartMacAccentGreen
                )
            } else {
                SystemInfoCard(
                    title: "Login Items",
                    value: "\(startupMonitor.allItems.count)",
                    icon: "list.bullet",
                    color: .smartMacAccentGreen
                )
            }
        }
    }
    
    // MARK: - Impact Summary Section
    private var impactSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Startup Impact Summary")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            HStack(spacing: 24) {
                // Estimated impact
                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated Startup Delay")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    Text(startupMonitor.startupImpact.formattedTime)
                        .font(.timesNewRoman(size: 32, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text("from \(startupMonitor.startupImpact.itemCount) active items")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Spacer()
                
                // Impact breakdown
                VStack(alignment: .leading, spacing: 8) {
                    ImpactBadge(
                        level: .high,
                        count: startupMonitor.startupImpact.highImpactCount
                    )
                    ImpactBadge(
                        level: .medium,
                        count: startupMonitor.startupImpact.mediumImpactCount
                    )
                    ImpactBadge(
                        level: .low,
                        count: startupMonitor.startupImpact.lowImpactCount
                    )
                }
            }
        }
        .padding(20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Startup Items Section
    private var startupItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Login Items & Launch Agents")
                    .font(.timesNewRoman(size: 18, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                // Filter toggle
                Toggle(isOn: $showHighImpactOnly) {
                    Text("High Impact Only")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            
            if startupMonitor.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else if filteredItems.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 1) {
                    ForEach(filteredItems) { item in
                        StartupItemRow(item: item)
                    }
                }
                .background(Color.smartMacBackground)
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Help Section
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.smartMacNavyBlue)
                Text("Managing Startup Items")
                    .font(.timesNewRoman(size: 16, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HelpStep(
                    number: 1,
                    text: "Open **System Settings** → **General** → **Login Items**"
                )
                HelpStep(
                    number: 2,
                    text: "Toggle off items you don't need at startup"
                )
                HelpStep(
                    number: 3,
                    text: "For Launch Agents, you can disable them in **~/Library/LaunchAgents**"
                )
            }
            
            Button(action: openLoginItemsSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text("Open Login Items Settings")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacNavyBlue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacNavyBlue.opacity(0.15))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.smartMacSuccess)
                Text(showHighImpactOnly ? "No high-impact items found" : "No startup items detected")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var filteredItems: [StartupItem] {
        if showHighImpactOnly {
            return startupMonitor.allItems.filter { $0.impactLevel == .high }
        }
        return startupMonitor.allItems
    }
    
    // MARK: - Helper Methods
    private func formatBootTime(_ seconds: TimeInterval) -> String {
        if seconds >= 60 {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        } else {
            return String(format: "%.1fs", seconds)
        }
    }
    
    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - System Info Card Component
struct SystemInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.timesNewRoman(size: 24, weight: .bold))
                .foregroundColor(.smartMacCasaBlanca)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
}

// MARK: - Impact Badge Component
struct ImpactBadge: View {
    let level: ImpactLevel
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            
            Text("\(count) \(level.rawValue)")
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextPrimary)
        }
    }
}

// MARK: - Startup Item Row Component
struct StartupItemRow: View {
    let item: StartupItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.smartMacForestGreen.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: item.type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.smartMacForestGreen)
                    )
            }
            
            // Name and type
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                Text(item.type.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            // Impact badge
            Text(item.impactLevel.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(item.impactLevel.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.impactLevel.color.opacity(0.15))
                .cornerRadius(4)
            
            // Status indicator
            Circle()
                .fill(item.isEnabled ? Color.smartMacSuccess : Color.smartMacTextTertiary)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(Color.smartMacSecondaryBg)
    }
}

// MARK: - Help Step Component
struct HelpStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.smartMacNavyBlue)
                .frame(width: 20, height: 20)
                .background(Color.smartMacNavyBlue.opacity(0.2))
                .clipShape(Circle())
            
            Text(LocalizedStringKey(text))
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
}
