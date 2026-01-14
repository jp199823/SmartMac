import Foundation
import AppKit
import Combine

/// Service for tracking app usage over time with persistent storage
class AppUsageTracker: ObservableObject {
    // MARK: - Published Properties
    @Published var currentApp: String = ""
    @Published var todaySummary: DailyUsageSummary = DailyUsageSummary()
    @Published var isTracking: Bool = false
    
    // MARK: - Private Properties
    private var dataStore: UsageDataStore
    private var currentAppStartTime: Date?
    private var currentBundleID: String?
    private var workspaceObserver: NSObjectProtocol?
    private var saveTimer: Timer?
    
    private let saveInterval: TimeInterval = 30  // Save every 30 seconds
    private let storageURL: URL
    
    // MARK: - Singleton
    static let shared = AppUsageTracker()
    
    // MARK: - Initialization
    init() {
        // Set up storage location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let smartMacDir = appSupport.appendingPathComponent("SmartMac", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: smartMacDir, withIntermediateDirectories: true)
        
        storageURL = smartMacDir.appendingPathComponent("usage_data.json")
        
        // Load existing data
        dataStore = Self.loadData(from: storageURL)
        
        // Load today's summary
        todaySummary = dataStore.getSummary(for: Date())
        
        // Start tracking
        startTracking()
    }
    
    deinit {
        stopTracking()
    }
    
    // MARK: - Public Methods
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        // Observe app activations
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        
        // Record current app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            recordAppSwitch(to: frontApp)
        }
        
        // Set up periodic save
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            self?.updateCurrentAppTime()
            self?.saveData()
        }
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        
        // Final update for current app
        updateCurrentAppTime()
        
        // Remove observer
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        
        // Stop timer
        saveTimer?.invalidate()
        saveTimer = nil
        
        // Save data
        saveData()
    }
    
    func getUsageStats(for period: UsagePeriod) -> [AppUsageEntry] {
        return dataStore.getAggregatedEntries(for: period)
    }
    
    func getDailySummaries(for period: UsagePeriod) -> [DailyUsageSummary] {
        return dataStore.getSummaries(for: period)
    }
    
    func getTotalScreenTime(for period: UsagePeriod) -> TimeInterval {
        return dataStore.getSummaries(for: period)
            .reduce(0) { $0 + $1.totalScreenTime }
    }
    
    func getProductivityScore(for period: UsagePeriod) -> Double {
        let summaries = dataStore.getSummaries(for: period)
        let totalTime = summaries.reduce(0) { $0 + $1.totalScreenTime }
        guard totalTime > 0 else { return 0 }
        
        let productiveTime = summaries.reduce(0.0) { result, summary in
            result + summary.entries.values
                .filter { $0.category == .productivity || $0.category == .development }
                .reduce(0) { $0 + TimeInterval($1.totalSeconds) }
        }
        
        return (productiveTime / totalTime) * 100
    }
    
    func getCategoryBreakdown(for period: UsagePeriod) -> [AppCategory: TimeInterval] {
        var breakdown: [AppCategory: TimeInterval] = [:]
        
        for summary in dataStore.getSummaries(for: period) {
            for (category, time) in summary.categoryBreakdown {
                breakdown[category, default: 0] += time
            }
        }
        
        return breakdown
    }
    
    // MARK: - Private Methods
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Update time for previous app
        updateCurrentAppTime()
        
        // Record new app
        recordAppSwitch(to: app)
    }
    
    private func recordAppSwitch(to app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        
        let bundleID = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? "Unknown App"
        
        currentBundleID = bundleID
        currentAppStartTime = Date()
        currentApp = appName
        
        // Ensure entry exists
        if todaySummary.entries[bundleID] == nil {
            todaySummary.entries[bundleID] = AppUsageEntry(
                bundleIdentifier: bundleID,
                appName: appName,
                icon: app.icon
            )
        }
    }
    
    private func updateCurrentAppTime() {
        guard let bundleID = currentBundleID,
              let startTime = currentAppStartTime else { return }
        
        let elapsed = Int(Date().timeIntervalSince(startTime))
        
        // Check if we've crossed midnight
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if todaySummary.date != today {
            // Save yesterday's data and start fresh
            dataStore.updateSummary(todaySummary)
            todaySummary = dataStore.getSummary(for: Date())
            
            // Re-create entry for current app if needed
            if todaySummary.entries[bundleID] == nil,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                todaySummary.entries[bundleID] = AppUsageEntry(
                    bundleIdentifier: bundleID,
                    appName: app.localizedName ?? "Unknown",
                    icon: app.icon
                )
            }
        }
        
        // Update time
        if var entry = todaySummary.entries[bundleID] {
            entry.totalSeconds += elapsed
            entry.lastUsed = Date()
            todaySummary.entries[bundleID] = entry
        }
        
        // Reset start time
        currentAppStartTime = Date()
        
        // Update data store
        dataStore.updateSummary(todaySummary)
    }
    
    private func saveData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(dataStore)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save usage data: \(error)")
        }
    }
    
    private static func loadData(from url: URL) -> UsageDataStore {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UsageDataStore.self, from: data)
        } catch {
            // Return empty store if file doesn't exist or is corrupted
            return UsageDataStore()
        }
    }
}
