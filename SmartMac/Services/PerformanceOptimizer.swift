import Foundation
import AppKit
import Combine

/// Service to manage Performance Mode - closing apps to free resources
class PerformanceOptimizer: ObservableObject {
    // MARK: - Published Properties
    @Published var isPerformanceModeActive = false
    @Published var memoryFreed: UInt64 = 0
    @Published var appsClosedCount = 0
    
    // Apps that should never be closed
    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemUIServer",
        "com.apple.loginwindow",
        "com.apple.WindowServer",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        Bundle.main.bundleIdentifier ?? ""
    ]
    
    // MARK: - App Categories for Presets
    enum PerformancePreset: String, CaseIterable {
        case gaming = "Gaming"
        case focus = "Focus"
        case maximum = "Maximum"
        
        var description: String {
            switch self {
            case .gaming: return "Close browsers, chat apps, and background utilities"
            case .focus: return "Close social apps and distractions only"
            case .maximum: return "Close all non-essential apps for maximum resources"
            }
        }
        
        var icon: String {
            switch self {
            case .gaming: return "gamecontroller.fill"
            case .focus: return "brain.head.profile"
            case .maximum: return "bolt.fill"
            }
        }
    }
    
    // Bundle identifiers for preset categories
    private let browserBundleIds = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser"]
    private let chatAppBundleIds = ["com.apple.MobileSMS", "com.tinyspeck.slackmacgap", "com.microsoft.teams", "com.hnc.Discord", "us.zoom.xos", "com.skype.skype", "org.whispersystems.signal-desktop"]
    private let socialAppBundleIds = ["com.twitter.twitter-mac", "com.facebook.Facebook", "com.reddit.Reddit"]
    
    // MARK: - Public Methods
    
    /// Get list of running apps that can be safely terminated
    func getTerminableApps() -> [TerminableApp] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        return runningApps.compactMap { app -> TerminableApp? in
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  let name = app.localizedName,
                  !protectedBundleIdentifiers.contains(bundleId) else {
                return nil
            }
            
            let memory = getMemoryUsage(for: app.processIdentifier)
            
            return TerminableApp(
                name: name,
                bundleIdentifier: bundleId,
                icon: app.icon,
                memoryUsage: memory,
                app: app
            )
        }.sorted { $0.memoryUsage > $1.memoryUsage }
    }
    
    /// Get apps recommended for a specific preset
    func getAppsForPreset(_ preset: PerformancePreset, from apps: [TerminableApp]) -> [TerminableApp] {
        switch preset {
        case .gaming:
            return apps.filter { app in
                browserBundleIds.contains(app.bundleIdentifier) ||
                chatAppBundleIds.contains(app.bundleIdentifier) ||
                app.memoryUsage > 500_000_000 // > 500MB
            }
        case .focus:
            return apps.filter { app in
                chatAppBundleIds.contains(app.bundleIdentifier) ||
                socialAppBundleIds.contains(app.bundleIdentifier)
            }
        case .maximum:
            return apps // All terminable apps
        }
    }
    
    /// Activate performance mode by closing specified apps
    func activatePerformanceMode(closing apps: [TerminableApp]) {
        var totalFreed: UInt64 = 0
        var closedCount = 0
        
        for terminableApp in apps {
            let memory = terminableApp.memoryUsage
            if terminableApp.app.terminate() {
                totalFreed += memory
                closedCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.memoryFreed = totalFreed
            self.appsClosedCount = closedCount
            self.isPerformanceModeActive = true
        }
    }
    
    /// Deactivate performance mode
    func deactivatePerformanceMode() {
        isPerformanceModeActive = false
        memoryFreed = 0
        appsClosedCount = 0
    }
    
    // MARK: - Private Methods
    
    private func getMemoryUsage(for pid: pid_t) -> UInt64 {
        var rusage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &rusage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
            }
        }
        
        if result == 0 {
            return rusage.ri_phys_footprint
        }
        return 0
    }
}

// MARK: - TerminableApp Model
struct TerminableApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let icon: NSImage?
    let memoryUsage: UInt64
    let app: NSRunningApplication
    
    var memoryFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
    
    // Hashable conformance (excluding app reference)
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    static func == (lhs: TerminableApp, rhs: TerminableApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
