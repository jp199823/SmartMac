import Foundation
import AppKit

/// Service for RAM analysis and optimization recommendations
class RAMOptimizer: ObservableObject {
    // MARK: - Published Properties
    @Published var recommendations: [RAMRecommendation] = []
    @Published var isAnalyzing = false
    @Published var lastOptimizationResult: OptimizationResult?
    
    // MARK: - Public Methods
    
    /// Analyze current RAM usage and generate recommendations
    func analyzeRAMUsage() {
        isAnalyzing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.getRunningAppsWithMemory() ?? []
            
            // Generate recommendations based on memory usage
            var recs: [RAMRecommendation] = []
            
            for app in apps {
                let recommendation = self?.createRecommendation(for: app)
                if let rec = recommendation {
                    recs.append(rec)
                }
            }
            
            // Sort by potential savings (highest first)
            recs.sort { $0.potentialSavings > $1.potentialSavings }
            
            DispatchQueue.main.async {
                self?.recommendations = recs
                self?.isAnalyzing = false
            }
        }
    }
    
    /// Execute optimization by closing selected apps
    func executeOptimization(apps: [RAMRecommendation]) -> OptimizationResult {
        var totalFreed: UInt64 = 0
        var closedApps: [String] = []
        var failedApps: [String] = []
        
        for recommendation in apps {
            guard let runningApp = recommendation.runningApp else {
                failedApps.append(recommendation.appName)
                continue
            }
            
            let memory = recommendation.potentialSavings
            if runningApp.terminate() {
                totalFreed += memory
                closedApps.append(recommendation.appName)
            } else {
                failedApps.append(recommendation.appName)
            }
        }
        
        let result = OptimizationResult(
            memoryFreed: totalFreed,
            appsClosed: closedApps,
            appsFailed: failedApps
        )
        
        DispatchQueue.main.async {
            self.lastOptimizationResult = result
            // Remove closed apps from recommendations
            self.recommendations.removeAll { rec in
                closedApps.contains(rec.appName)
            }
        }
        
        return result
    }
    
    /// Get manual instructions for RAM optimization
    func getManualInstructions() -> [OptimizationInstruction] {
        return [
            OptimizationInstruction(
                step: 1,
                title: "Check Activity Monitor",
                description: "Open Activity Monitor from Applications > Utilities. Click the 'Memory' tab to see which apps use the most RAM.",
                icon: "chart.bar.xaxis"
            ),
            OptimizationInstruction(
                step: 2,
                title: "Identify Heavy Apps",
                description: "Look for apps using more than 500MB of memory. Sort by 'Memory' column to find the biggest consumers.",
                icon: "magnifyingglass"
            ),
            OptimizationInstruction(
                step: 3,
                title: "Close Unused Apps",
                description: "Right-click apps you're not actively using and select 'Quit'. Save any work first!",
                icon: "xmark.circle"
            ),
            OptimizationInstruction(
                step: 4,
                title: "Close Browser Tabs",
                description: "Each browser tab uses memory. Close tabs you're not using, especially video sites.",
                icon: "safari"
            ),
            OptimizationInstruction(
                step: 5,
                title: "Restart Memory-Heavy Apps",
                description: "Some apps accumulate memory over time. Restarting Slack, Chrome, or Electron apps can help.",
                icon: "arrow.clockwise"
            ),
            OptimizationInstruction(
                step: 6,
                title: "Consider a Restart",
                description: "If memory pressure is still high, a system restart clears all memory and is the most effective solution.",
                icon: "power"
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private func getRunningAppsWithMemory() -> [(app: NSRunningApplication, memory: UInt64)] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let protectedBundleIds: Set<String> = [
            "com.apple.finder",
            "com.apple.dock", 
            "com.apple.SystemUIServer",
            Bundle.main.bundleIdentifier ?? ""
        ]
        
        return runningApps.compactMap { app -> (NSRunningApplication, UInt64)? in
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  !protectedBundleIds.contains(bundleId) else {
                return nil
            }
            
            let memory = getMemoryUsage(for: app.processIdentifier)
            guard memory > 50_000_000 else { return nil } // Only apps using > 50MB
            
            return (app, memory)
        }
    }
    
    private func createRecommendation(for appData: (app: NSRunningApplication, memory: UInt64)) -> RAMRecommendation {
        let (app, memory) = appData
        
        let priority: RecommendationPriority
        let reason: String
        
        if memory > 1_000_000_000 { // > 1GB
            priority = .high
            reason = "Using over 1GB of RAM - significant memory consumer"
        } else if memory > 500_000_000 { // > 500MB
            priority = .medium
            reason = "Using substantial memory that could be freed"
        } else {
            priority = .low
            reason = "Moderate memory usage"
        }
        
        return RAMRecommendation(
            appName: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier ?? "",
            icon: app.icon,
            potentialSavings: memory,
            priority: priority,
            reason: reason,
            runningApp: app
        )
    }
    
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

// MARK: - Supporting Models

struct RAMRecommendation: Identifiable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let icon: NSImage?
    let potentialSavings: UInt64
    let priority: RecommendationPriority
    let reason: String
    let runningApp: NSRunningApplication?
    
    var savingsFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(potentialSavings), countStyle: .memory)
    }
}

enum RecommendationPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    
    static func < (lhs: RecommendationPriority, rhs: RecommendationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "smartMacTextSecondary"
        case .medium: return "smartMacWarning"
        case .high: return "smartMacDanger"
        }
    }
}

struct OptimizationResult {
    let memoryFreed: UInt64
    let appsClosed: [String]
    let appsFailed: [String]
    
    var memoryFreedFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryFreed), countStyle: .memory)
    }
    
    var wasSuccessful: Bool {
        !appsClosed.isEmpty
    }
}

struct OptimizationInstruction: Identifiable {
    let id = UUID()
    let step: Int
    let title: String
    let description: String
    let icon: String
}
