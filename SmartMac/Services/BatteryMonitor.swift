import Foundation
import IOKit.ps

/// Battery monitoring using IOKit Power Sources
struct BatteryMonitor {
    
    static func getBatteryMetrics() -> BatteryMetrics {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return .notPresent
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check if it's an internal battery
            guard let type = description[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }
            
            let chargePercentage = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let cycleCount = description["BatteryHealth"] as? Int ?? getCycleCount()
            
            // Calculate health
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let designCapacity = description["DesignCapacity"] as? Int ?? 100
            let healthPercentage = designCapacity > 0 ? (maxCapacity * 100) / designCapacity : 100
            let health = healthPercentage >= 80 ? "Good" : (healthPercentage >= 50 ? "Fair" : "Service Recommended")
            
            // Time remaining
            var timeRemaining: Int? = nil
            if let minutes = description[kIOPSTimeToEmptyKey] as? Int, minutes > 0, !isCharging {
                timeRemaining = minutes
            }
            
            return BatteryMetrics(
                isPresent: true,
                chargePercentage: chargePercentage,
                isCharging: isCharging,
                cycleCount: cycleCount,
                health: health,
                timeRemaining: timeRemaining
            )
        }
        
        return .notPresent
    }
    
    private static func getCycleCount() -> Int {
        // Try to get cycle count from IORegistry
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        
        if let cycleCountRef = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) {
            return (cycleCountRef.takeRetainedValue() as? Int) ?? 0
        }
        
        return 0
    }
}
