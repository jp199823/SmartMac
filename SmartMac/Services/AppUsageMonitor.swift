import Foundation
import AppKit

/// Application usage monitoring using NSWorkspace
struct AppUsageMonitor {
    
    static func getTopApplications(limit: Int = 5) -> [RunningApplication] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // Filter to regular apps (not background agents)
        let regularApps = runningApps.filter { app in
            app.activationPolicy == .regular &&
            app.localizedName != nil
        }
        
        // Get memory usage for each app
        var appsWithMemory: [(app: NSRunningApplication, memory: UInt64)] = []
        
        for app in regularApps {
            let memory = getMemoryUsage(for: app.processIdentifier)
            appsWithMemory.append((app, memory))
        }
        
        // Sort by memory usage (descending)
        appsWithMemory.sort { $0.memory > $1.memory }
        
        // Take top N
        let topApps = appsWithMemory.prefix(limit)
        
        return topApps.map { item in
            RunningApplication(
                name: item.app.localizedName ?? "Unknown",
                bundleIdentifier: item.app.bundleIdentifier,
                memoryUsage: item.memory,
                icon: item.app.icon
            )
        }
    }
    
    private static func getMemoryUsage(for pid: pid_t) -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        var task: mach_port_t = 0
        guard task_for_pid(mach_task_self_, pid, &task) == KERN_SUCCESS else {
            // Can't get task for this process (common for sandboxed apps)
            // Estimate based on proc_pidinfo
            return getResidentMemory(for: pid)
        }
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), pointer, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        
        return getResidentMemory(for: pid)
    }
    
    private static func getResidentMemory(for pid: pid_t) -> UInt64 {
        var rusage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &rusage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rusagePtr in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rusagePtr)
            }
        }
        
        if result == 0 {
            return rusage.ri_phys_footprint
        }
        
        // Last resort: return a placeholder
        return 0
    }
    
    /// Get total running app count
    static func getRunningAppCount() -> Int {
        NSWorkspace.shared.runningApplications.filter { 
            $0.activationPolicy == .regular 
        }.count
    }
    
    /// Get apps that have been running for a long time
    static func getLongRunningApps(threshold: TimeInterval = 3600) -> [NSRunningApplication] {
        // Note: NSRunningApplication doesn't provide launch time directly
        // This would require more complex tracking
        return []
    }
}
