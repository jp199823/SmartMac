import Foundation
import Darwin

/// Memory monitoring using Mach host_statistics64 API
struct MemoryMonitor {
    
    static func getMemoryMetrics() -> MemoryMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(hostPort, HOST_VM_INFO64, pointer, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return .empty
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        // Calculate memory values
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
        // Get total physical memory
        let total = ProcessInfo.processInfo.physicalMemory
        
        // Used = Total - Free (where free includes inactive that can be reclaimed)
        let used = total - free - inactive
        
        return MemoryMetrics(
            total: total,
            free: free + inactive,  // Available memory (truly free + reclaimable)
            used: used,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed
        )
    }
}
