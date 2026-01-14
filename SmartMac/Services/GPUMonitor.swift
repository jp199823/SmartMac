import Foundation
import IOKit

/// GPU monitoring using IOKit
struct GPUMonitor {
    
    static func getGPUMetrics() -> GPUMetrics {
        // Try to get GPU info from IOKit
        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return getAppleSiliconGPU()
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            if let properties = getServiceProperties(service) {
                let name = properties["IOGLBundleName"] as? String ?? 
                           properties["CFBundleIdentifier"] as? String ??
                           "GPU"
                
                // Clean up the name
                let cleanName = cleanGPUName(name)
                
                let vram = properties["VRAM,totalMB"] as? UInt64 ?? 0
                let isIntegrated = vram == 0  // Integrated GPUs typically share system memory
                
                return GPUMetrics(
                    name: cleanName,
                    vendor: getVendor(from: name),
                    vram: vram * 1_048_576,  // Convert to bytes
                    isIntegrated: isIntegrated
                )
            }
        }
        
        return getAppleSiliconGPU()
    }
    
    private static func getServiceProperties(_ service: io_object_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return props
    }
    
    private static func getAppleSiliconGPU() -> GPUMetrics {
        // For Apple Silicon, GPU is integrated into the SoC
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = "Apple GPU"
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buffer, &size, nil, 0)
            let hwModel = String(cString: buffer)
            
            // Try to infer GPU from model
            if hwModel.contains("Mac") {
                model = inferAppleGPU()
            }
        }
        
        return GPUMetrics(
            name: model,
            vendor: "Apple",
            vram: 0,  // Shared with system memory
            isIntegrated: true
        )
    }
    
    private static func inferAppleGPU() -> String {
        let cores = ProcessInfo.processInfo.processorCount
        
        // Basic inference based on CPU cores
        if cores <= 8 {
            return "Apple M1 GPU (8-core)"
        } else if cores <= 10 {
            return "Apple M1 Pro/M2 GPU"
        } else if cores <= 12 {
            return "Apple M2 Pro GPU"
        } else if cores <= 20 {
            return "Apple M1 Max/M2 Max GPU"
        } else {
            return "Apple Silicon GPU"
        }
    }
    
    private static func cleanGPUName(_ name: String) -> String {
        // Remove common prefixes/suffixes
        var clean = name
        clean = clean.replacingOccurrences(of: "com.apple.gpu.", with: "")
        clean = clean.replacingOccurrences(of: "AppleIntel", with: "Intel ")
        clean = clean.replacingOccurrences(of: "AppleGPU", with: "Apple GPU")
        clean = clean.replacingOccurrences(of: "AMD", with: "AMD ")
        return clean.trimmingCharacters(in: .whitespaces)
    }
    
    private static func getVendor(from name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("apple") { return "Apple" }
        if lowercased.contains("amd") || lowercased.contains("radeon") { return "AMD" }
        if lowercased.contains("intel") { return "Intel" }
        if lowercased.contains("nvidia") { return "NVIDIA" }
        return "Unknown"
    }
}
