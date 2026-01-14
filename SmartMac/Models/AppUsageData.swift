import Foundation
import AppKit

// MARK: - App Category
enum AppCategory: String, Codable, CaseIterable {
    case productivity = "Productivity"
    case entertainment = "Entertainment"
    case social = "Social"
    case utility = "Utility"
    case development = "Development"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .productivity: return "doc.text"
        case .entertainment: return "play.circle"
        case .social: return "message"
        case .utility: return "wrench"
        case .development: return "hammer"
        case .other: return "square.grid.2x2"
        }
    }
    
    var color: String {
        switch self {
        case .productivity: return "smartMacAccentGreen"
        case .entertainment: return "smartMacWarning"
        case .social: return "smartMacNavyBlue"
        case .utility: return "smartMacForestGreen"
        case .development: return "smartMacCasaBlanca"
        case .other: return "smartMacTextSecondary"
        }
    }
    
    /// Auto-categorize based on known bundle identifiers
    static func categorize(bundleIdentifier: String?) -> AppCategory {
        guard let bundleID = bundleIdentifier?.lowercased() else { return .other }
        
        // Development tools
        if bundleID.contains("xcode") || bundleID.contains("vscode") ||
           bundleID.contains("sublime") || bundleID.contains("intellij") ||
           bundleID.contains("android-studio") || bundleID.contains("terminal") ||
           bundleID.contains("iterm") || bundleID.contains("github") ||
           bundleID.contains("tower") || bundleID.contains("sourcetree") {
            return .development
        }
        
        // Productivity
        if bundleID.contains("pages") || bundleID.contains("numbers") ||
           bundleID.contains("keynote") || bundleID.contains("microsoft") ||
           bundleID.contains("notion") || bundleID.contains("obsidian") ||
           bundleID.contains("evernote") || bundleID.contains("notes") ||
           bundleID.contains("reminders") || bundleID.contains("calendar") ||
           bundleID.contains("mail") || bundleID.contains("outlook") ||
           bundleID.contains("slack") || bundleID.contains("zoom") ||
           bundleID.contains("teams") || bundleID.contains("figma") ||
           bundleID.contains("sketch") || bundleID.contains("adobe") {
            return .productivity
        }
        
        // Entertainment
        if bundleID.contains("spotify") || bundleID.contains("music") ||
           bundleID.contains("netflix") || bundleID.contains("youtube") ||
           bundleID.contains("vlc") || bundleID.contains("plex") ||
           bundleID.contains("primevideo") || bundleID.contains("hulu") ||
           bundleID.contains("disney") || bundleID.contains("hbo") ||
           bundleID.contains("twitch") || bundleID.contains("steam") ||
           bundleID.contains("game") || bundleID.contains("tv") {
            return .entertainment
        }
        
        // Social
        if bundleID.contains("messages") || bundleID.contains("telegram") ||
           bundleID.contains("whatsapp") || bundleID.contains("discord") ||
           bundleID.contains("facebook") || bundleID.contains("twitter") ||
           bundleID.contains("instagram") || bundleID.contains("tiktok") ||
           bundleID.contains("snapchat") || bundleID.contains("signal") {
            return .social
        }
        
        // Utility
        if bundleID.contains("finder") || bundleID.contains("preview") ||
           bundleID.contains("safari") || bundleID.contains("chrome") ||
           bundleID.contains("firefox") || bundleID.contains("systempreferences") ||
           bundleID.contains("activitymonitor") || bundleID.contains("utilities") ||
           bundleID.contains("1password") || bundleID.contains("bitwarden") ||
           bundleID.contains("cleanmymac") || bundleID.contains("alfred") {
            return .utility
        }
        
        return .other
    }
}

// MARK: - App Usage Entry
struct AppUsageEntry: Codable, Identifiable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    var totalSeconds: Int
    var lastUsed: Date
    let category: AppCategory
    var iconData: Data?
    
    init(id: UUID = UUID(), bundleIdentifier: String, appName: String, totalSeconds: Int = 0, lastUsed: Date = Date(), category: AppCategory? = nil, icon: NSImage? = nil) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.totalSeconds = totalSeconds
        self.lastUsed = lastUsed
        self.category = category ?? AppCategory.categorize(bundleIdentifier: bundleIdentifier)
        self.iconData = icon?.tiffRepresentation
    }
    
    var icon: NSImage? {
        guard let data = iconData else { return nil }
        return NSImage(data: data)
    }
    
    var formattedTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Daily Usage Summary
struct DailyUsageSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    var entries: [String: AppUsageEntry]  // Keyed by bundleIdentifier
    
    init(id: UUID = UUID(), date: Date = Date(), entries: [String: AppUsageEntry] = [:]) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.entries = entries
    }
    
    var totalScreenTime: TimeInterval {
        entries.values.reduce(0) { $0 + TimeInterval($1.totalSeconds) }
    }
    
    var formattedScreenTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var productivityScore: Double {
        let productiveTime = entries.values
            .filter { $0.category == .productivity || $0.category == .development }
            .reduce(0) { $0 + TimeInterval($1.totalSeconds) }
        
        guard totalScreenTime > 0 else { return 0 }
        return (productiveTime / totalScreenTime) * 100
    }
    
    var sortedEntries: [AppUsageEntry] {
        entries.values.sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var categoryBreakdown: [AppCategory: TimeInterval] {
        var breakdown: [AppCategory: TimeInterval] = [:]
        for entry in entries.values {
            breakdown[entry.category, default: 0] += TimeInterval(entry.totalSeconds)
        }
        return breakdown
    }
}

// MARK: - Usage Data Store
struct UsageDataStore: Codable {
    var dailySummaries: [String: DailyUsageSummary]  // Keyed by date string (yyyy-MM-dd)
    
    init(dailySummaries: [String: DailyUsageSummary] = [:]) {
        self.dailySummaries = dailySummaries
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    mutating func getSummary(for date: Date) -> DailyUsageSummary {
        let key = Self.dateFormatter.string(from: date)
        if let existing = dailySummaries[key] {
            return existing
        }
        let newSummary = DailyUsageSummary(date: date)
        dailySummaries[key] = newSummary
        return newSummary
    }
    
    mutating func updateSummary(_ summary: DailyUsageSummary) {
        let key = Self.dateFormatter.string(from: summary.date)
        dailySummaries[key] = summary
    }
    
    func getSummaries(for period: UsagePeriod) -> [DailyUsageSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let startDate: Date
        switch period {
        case .day:
            startDate = today
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        }
        
        return dailySummaries.values
            .filter { $0.date >= startDate && $0.date <= today }
            .sorted { $0.date < $1.date }
    }
    
    func getAggregatedEntries(for period: UsagePeriod) -> [AppUsageEntry] {
        let summaries = getSummaries(for: period)
        var aggregated: [String: AppUsageEntry] = [:]
        
        for summary in summaries {
            for (bundleID, entry) in summary.entries {
                if var existing = aggregated[bundleID] {
                    existing.totalSeconds += entry.totalSeconds
                    if entry.lastUsed > existing.lastUsed {
                        existing.lastUsed = entry.lastUsed
                    }
                    aggregated[bundleID] = existing
                } else {
                    aggregated[bundleID] = entry
                }
            }
        }
        
        return aggregated.values.sorted { $0.totalSeconds > $1.totalSeconds }
    }
}

// MARK: - Usage Period
enum UsagePeriod: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
}
