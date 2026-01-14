import SwiftUI

struct AppUsageAnalyticsView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var usageTracker = AppUsageTracker.shared
    @State private var selectedPeriod: UsagePeriod = .day
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with period selector
                headerSection
                
                // Stats cards row
                statsCardsSection
                
                // Top Apps section
                topAppsSection
                
                // Category breakdown
                categoryBreakdownSection
                
                // Daily breakdown (for week/month)
                if selectedPeriod != .day {
                    dailyBreakdownSection
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Usage Analytics")
                        .font(.timesNewRoman(size: 28, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text("Track your app usage and productivity")
                        .font(.system(size: 14))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Spacer()
                
                // Tracking indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(usageTracker.isTracking ? Color.smartMacSuccess : Color.smartMacDanger)
                        .frame(width: 8, height: 8)
                    Text(usageTracker.isTracking ? "Tracking" : "Paused")
                        .font(.caption)
                        .foregroundColor(.smartMacTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(16)
            }
            
            // Period selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(UsagePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
        }
    }
    
    // MARK: - Stats Cards Section
    private var statsCardsSection: some View {
        HStack(spacing: 16) {
            // Screen Time Card
            StatCard(
                title: "Screen Time",
                value: formattedScreenTime,
                icon: "clock.fill",
                color: .smartMacNavyBlue
            )
            
            // Productivity Score Card
            StatCard(
                title: "Productivity",
                value: String(format: "%.0f%%", productivityScore),
                icon: "chart.line.uptrend.xyaxis",
                color: productivityScore >= 60 ? .smartMacSuccess : (productivityScore >= 40 ? .smartMacWarning : .smartMacDanger)
            )
            
            // Apps Used Card
            StatCard(
                title: "Apps Used",
                value: "\(usageStats.count)",
                icon: "square.grid.2x2",
                color: .smartMacForestGreen
            )
        }
    }
    
    // MARK: - Top Apps Section
    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Applications")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            VStack(spacing: 8) {
                let topApps = Array(usageStats.prefix(8))
                let maxTime = topApps.first?.totalSeconds ?? 1
                
                ForEach(topApps) { entry in
                    AnalyticsAppRow(entry: entry, maxTime: maxTime)
                }
                
                if usageStats.isEmpty {
                    emptyStateView(message: "No usage data yet. Keep using your Mac!")
                }
            }
            .padding(16)
            .background(Color.smartMacSecondaryBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Category Breakdown Section
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            let categoryData = usageTracker.getCategoryBreakdown(for: selectedPeriod)
            let totalTime = categoryData.values.reduce(0, +)
            
            if totalTime > 0 {
                VStack(spacing: 12) {
                    // Category bars
                    ForEach(AppCategory.allCases, id: \.self) { category in
                        if let time = categoryData[category], time > 0 {
                            CategoryRow(
                                category: category,
                                time: time,
                                percentage: time / totalTime
                            )
                        }
                    }
                }
                .padding(16)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(12)
            } else {
                emptyStateView(message: "No category data available")
                    .padding(16)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Daily Breakdown Section
    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Breakdown")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            let summaries = usageTracker.getDailySummaries(for: selectedPeriod)
            let maxTime = summaries.map { $0.totalScreenTime }.max() ?? 1
            
            if !summaries.isEmpty {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(summaries) { summary in
                        DailyBar(summary: summary, maxTime: maxTime)
                    }
                }
                .padding(16)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(12)
            } else {
                emptyStateView(message: "No daily data available")
                    .padding(16)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Views
    private func emptyStateView(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.smartMacTextTertiary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var usageStats: [AppUsageEntry] {
        usageTracker.getUsageStats(for: selectedPeriod)
    }
    
    private var formattedScreenTime: String {
        let totalSeconds = Int(usageTracker.getTotalScreenTime(for: selectedPeriod))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var productivityScore: Double {
        usageTracker.getProductivityScore(for: selectedPeriod)
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
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
                .font(.timesNewRoman(size: 28, weight: .bold))
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

// MARK: - Analytics App Row Component
struct AnalyticsAppRow: View {
    let entry: AppUsageEntry
    let maxTime: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = entry.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.smartMacForestGreen.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "app")
                            .foregroundColor(.smartMacForestGreen)
                    )
            }
            
            // App name and category
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                Text(entry.category.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
            }
            .frame(width: 120, alignment: .leading)
            
            // Usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.smartMacBackground)
                        .frame(height: 8)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor(for: entry.category))
                        .frame(width: geometry.size.width * CGFloat(entry.totalSeconds) / CGFloat(maxTime), height: 8)
                }
            }
            .frame(height: 8)
            
            // Time
            Text(entry.formattedTime)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.smartMacTextPrimary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func categoryColor(for category: AppCategory) -> Color {
        switch category {
        case .productivity: return .smartMacAccentGreen
        case .entertainment: return .smartMacWarning
        case .social: return .smartMacNavyBlue
        case .utility: return .smartMacForestGreen
        case .development: return .smartMacCasaBlanca
        case .other: return .smartMacTextSecondary
        }
    }
}

// MARK: - Category Row Component
struct CategoryRow: View {
    let category: AppCategory
    let time: TimeInterval
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(categoryColor)
                .frame(width: 24)
            
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.smartMacTextPrimary)
                .frame(width: 100, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.smartMacBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor)
                        .frame(width: geometry.size.width * CGFloat(percentage), height: 8)
                }
            }
            .frame(height: 8)
            
            Text(formattedTime)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.smartMacTextPrimary)
                .frame(width: 60, alignment: .trailing)
            
            Text(String(format: "%.0f%%", percentage * 100))
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private var formattedTime: String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .productivity: return .smartMacAccentGreen
        case .entertainment: return .smartMacWarning
        case .social: return .smartMacNavyBlue
        case .utility: return .smartMacForestGreen
        case .development: return .smartMacCasaBlanca
        case .other: return .smartMacTextSecondary
        }
    }
}

// MARK: - Daily Bar Component
struct DailyBar: View {
    let summary: DailyUsageSummary
    let maxTime: TimeInterval
    
    private let barHeight: CGFloat = 120
    
    var body: some View {
        VStack(spacing: 4) {
            // Bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.smartMacAccentGreen, .smartMacForestGreen],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: barHeight * CGFloat(summary.totalScreenTime / maxTime))
            }
            .frame(height: barHeight)
            
            // Day label
            Text(dayLabel)
                .font(.system(size: 10))
                .foregroundColor(.smartMacTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: summary.date)
    }
}
