import Foundation
import Darwin

/// CPU monitoring using sysctl and ProcessInfo
struct CPUMonitor {
    
    static func getCPUMetrics() -> CPUMetrics {
        let modelName = getCPUModelName()
        let physicalCores = getPhysicalCoreCount()
        let logicalCores = ProcessInfo.processInfo.processorCount
        let thermalState = getThermalState()
        let usage = getCPUUsage()
        
        return CPUMetrics(
            modelName: modelName,
            physicalCores: physicalCores,
            logicalCores: logicalCores,
            usagePercentage: usage,
            thermalState: thermalState
        )
    }
    
    // MARK: - CPU Model Name
    private static func getCPUModelName() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
            return String(cString: buffer)
        }
        
        // Fallback for Apple Silicon
        var sizeHW: size_t = 0
        sysctlbyname("hw.model", nil, &sizeHW, nil, 0)
        
        if sizeHW > 0 {
            var buffer = [CChar](repeating: 0, count: sizeHW)
            sysctlbyname("hw.model", &buffer, &sizeHW, nil, 0)
            let model = String(cString: buffer)
            
            // Map to friendly names for Apple Silicon
            if model.contains("Mac") {
                return getAppleSiliconChipName() ?? model
            }
            return model
        }
        
        return "Unknown CPU"
    }
    
    private static func getAppleSiliconChipName() -> String? {
        // Try to get chip name for Apple Silicon
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        
        if size == 0 {
            // Apple Silicon doesn't have brand_string, infer from core count
            let cores = ProcessInfo.processInfo.processorCount
            let perf = getPerformanceCoreCount()
            let eff = cores - perf
            
            // Basic inference (not 100% accurate but close)
            if cores <= 8 {
                return "Apple M1"
            } else if cores <= 10 {
                return "Apple M1 Pro"
            } else if cores <= 12 {
                return "Apple M2 Pro"
            } else if cores <= 20 {
                return "Apple M1 Max / M2 Max"
            } else {
                return "Apple Silicon"
            }
        }
        
        return nil
    }
    
    // MARK: - Core Counts
    private static func getPhysicalCoreCount() -> Int {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &count, &size, nil, 0)
        return Int(count)
    }
    
    private static func getPerformanceCoreCount() -> Int {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.perflevel0.physicalcpu", &count, &size, nil, 0)
        return Int(count)
    }
    
    // MARK: - Thermal State
    private static func getThermalState() -> ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .nominal
        }
    }
    
    // MARK: - CPU Usage
    private static func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return 0
        }
        
        var totalUsage: Double = 0
        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCPUs)) { ptr in
            return ptr
        }
        
        for i in 0..<Int(numCPUs) {
            let cpu = cpuLoadInfo[i]
            let user = Double(cpu.cpu_ticks.0)      // CPU_STATE_USER
            let system = Double(cpu.cpu_ticks.1)    // CPU_STATE_SYSTEM
            let idle = Double(cpu.cpu_ticks.2)      // CPU_STATE_IDLE
            let nice = Double(cpu.cpu_ticks.3)      // CPU_STATE_NICE
            
            let total = user + system + idle + nice
            if total > 0 {
                let usage = (user + system + nice) / total * 100
                totalUsage += usage
            }
        }
        
        // Deallocate
        let dataSize = Int(numCPUInfo) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(dataSize))
        
        return totalUsage / Double(numCPUs)
    }
}
