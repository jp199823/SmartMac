import Foundation
import AppKit
import ServiceManagement

/// Service for monitoring and managing startup items
class StartupMonitor: ObservableObject {
    // MARK: - Published Properties
    @Published var loginItems: [StartupItem] = []
    @Published var launchAgents: [StartupItem] = []
    @Published var isLoading: Bool = false
    @Published var bootTimeHistory: BootTimeHistory
    
    // MARK: - Private Properties
    private let storageURL: URL
    
    // Known high-impact apps (based on typical resource usage)
    private let highImpactApps: Set<String> = [
        "com.adobe.acc.AdobeCreativeCloud",
        "com.microsoft.teams",
        "com.docker.docker",
        "com.spotify.client",
        "com.google.Chrome",
        "com.apple.Safari",
        "com.dropbox.client",
        "com.microsoft.OneDrive",
        "com.valvesoftware.steam",
        "com.parallels.desktop.console"
    ]
    
    private let lowImpactApps: Set<String> = [
        "com.apple.CloudPhotosConfiguration",
        "com.apple.photoanalysisd",
        "com.apple.iCloudHelper",
        "com.apple.bird",
        "com.apple.CallHistoryPluginHelper"
    ]
    
    // MARK: - Singleton
    static let shared = StartupMonitor()
    
    // MARK: - Computed Properties
    var allItems: [StartupItem] {
        loginItems + launchAgents
    }
    
    var startupImpact: StartupImpact {
        let items = allItems.filter { $0.isEnabled }
        let highCount = items.filter { $0.impactLevel == .high }.count
        let mediumCount = items.filter { $0.impactLevel == .medium }.count
        let lowCount = items.filter { $0.impactLevel == .low }.count
        
        let estimatedTime = items.reduce(0.0) { $0 + $1.impactLevel.estimatedSeconds }
        
        return StartupImpact(
            estimatedBootSeconds: estimatedTime,
            itemCount: items.count,
            highImpactCount: highCount,
            mediumImpactCount: mediumCount,
            lowImpactCount: lowCount
        )
    }
    
    // MARK: - Initialization
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let smartMacDir = appSupport.appendingPathComponent("SmartMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: smartMacDir, withIntermediateDirectories: true)
        storageURL = smartMacDir.appendingPathComponent("boot_history.json")
        
        bootTimeHistory = Self.loadHistory(from: storageURL)
        
        // Record current boot time
        recordCurrentBootTime()
        
        // Load items
        refreshItems()
    }
    
    // MARK: - Public Methods
    func refreshItems() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loginItems = self?.getLoginItems() ?? []
            let launchAgents = self?.getLaunchAgents() ?? []
            
            DispatchQueue.main.async {
                self?.loginItems = loginItems
                self?.launchAgents = launchAgents
                self?.isLoading = false
            }
        }
    }
    
    func getLastBootTime() -> TimeInterval? {
        // Try to get system boot time using sysctl
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) != 0 {
            return nil
        }
        
        let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
        return Date().timeIntervalSince(bootDate)
    }
    
    func getFormattedUptime() -> String {
        guard let uptime = getLastBootTime() else { return "Unknown" }
        
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Private Methods
    private func getLoginItems() -> [StartupItem] {
        var items: [StartupItem] = []
        
        // Get running applications that are known to be login items
        // Note: Modern macOS requires special entitlements for comprehensive login item access
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // Check common login item paths
        let loginItemsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm")
        
        // Add apps that are commonly login items
        let commonLoginApps: [(bundleID: String, name: String)] = [
            ("com.apple.iTunesHelper", "iTunes Helper"),
            ("com.spotify.client", "Spotify"),
            ("com.dropbox.client", "Dropbox"),
            ("com.microsoft.OneDrive", "OneDrive"),
            ("com.adobe.acc.AdobeCreativeCloud", "Adobe Creative Cloud"),
            ("com.microsoft.teams", "Microsoft Teams"),
            ("com.docker.docker", "Docker Desktop"),
            ("com.google.Chrome", "Google Chrome Helper"),
            ("com.1password.1password-launcher", "1Password"),
            ("us.zoom.xos", "Zoom"),
        ]
        
        for (bundleID, name) in commonLoginApps {
            if let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
                items.append(StartupItem(
                    name: app.localizedName ?? name,
                    bundleIdentifier: bundleID,
                    path: app.bundleURL?.path,
                    icon: app.icon,
                    isEnabled: true,
                    impactLevel: determineImpactLevel(for: bundleID),
                    canBeDisabled: true,
                    type: .loginItem
                ))
            }
        }
        
        // Add items based on running background apps
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  app.activationPolicy == .accessory || app.activationPolicy == .prohibited,
                  !items.contains(where: { $0.bundleIdentifier == bundleID }) else {
                continue
            }
            
            // Skip system apps
            if bundleID.hasPrefix("com.apple.") {
                continue
            }
            
            items.append(StartupItem(
                name: app.localizedName ?? "Unknown",
                bundleIdentifier: bundleID,
                path: app.bundleURL?.path,
                icon: app.icon,
                isEnabled: true,
                impactLevel: determineImpactLevel(for: bundleID),
                canBeDisabled: true,
                type: .loginItem
            ))
        }
        
        return items
    }
    
    private func getLaunchAgents() -> [StartupItem] {
        var items: [StartupItem] = []
        
        // User Launch Agents
        let userLaunchAgentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: userLaunchAgentsPath.path) {
            for file in contents where file.hasSuffix(".plist") {
                let plistPath = userLaunchAgentsPath.appendingPathComponent(file)
                if let item = parseLaunchAgent(at: plistPath) {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    private func parseLaunchAgent(at url: URL) -> StartupItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let isDisabled = plist["Disabled"] as? Bool ?? false
        
        // Try to extract program info
        let program = plist["Program"] as? String
        let programArgs = plist["ProgramArguments"] as? [String]
        let executablePath = program ?? programArgs?.first
        
        // Get icon from executable if possible
        var icon: NSImage? = nil
        if let path = executablePath {
            icon = NSWorkspace.shared.icon(forFile: path)
        }
        
        return StartupItem(
            name: label,
            bundleIdentifier: label,
            path: url.path,
            icon: icon,
            isEnabled: !isDisabled,
            impactLevel: .medium,
            canBeDisabled: true,
            type: .launchAgent
        )
    }
    
    private func determineImpactLevel(for bundleIdentifier: String) -> ImpactLevel {
        if highImpactApps.contains(bundleIdentifier) {
            return .high
        } else if lowImpactApps.contains(bundleIdentifier) {
            return .low
        }
        return .medium
    }
    
    private func recordCurrentBootTime() {
        // Estimate time since boot (this is a simplified approach)
        // For accurate boot time measurement, system logs would need to be parsed
        guard let uptime = getLastBootTime() else { return }
        
        // Only record if system was recently booted (within last 10 minutes)
        if uptime < 600 {
            let record = BootTimeRecord(bootTimeSeconds: uptime)
            bootTimeHistory.addRecord(record)
            saveHistory()
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bootTimeHistory)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save boot history: \(error)")
        }
    }
    
    private static func loadHistory(from url: URL) -> BootTimeHistory {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BootTimeHistory.self, from: data)
        } catch {
            return BootTimeHistory()
        }
    }
}
