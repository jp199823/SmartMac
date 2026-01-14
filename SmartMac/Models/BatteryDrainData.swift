import Foundation
import AppKit

// MARK: - Battery Drain Entry
struct BatteryDrainEntry: Identifiable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let energyImpact: Double  // 0-100 scale
    let sampleTime: Date
    let icon: NSImage?  // App icon
    
    var impactLevel: ImpactLevel {
        if energyImpact >= 50 { return .high }
        else if energyImpact >= 20 { return .medium }
        else { return .low }
    }
    
    enum ImpactLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: String {
            switch self {
            case .high: return "smartMacDanger"
            case .medium: return "smartMacWarning"
            case .low: return "smartMacSuccess"
            }
        }
    }
}

// MARK: - Battery Health Detail
struct BatteryHealthDetail {
    let healthPercentage: Int
    let cycleCount: Int
    let condition: BatteryCondition
    let temperature: Double?  // Celsius
    let designCapacity: Int   // mAh
    let currentMaxCapacity: Int  // mAh
    let chargePercentage: Int
    let isCharging: Bool
    let timeRemaining: Int?  // minutes
    let powerSource: PowerSource
    
    var healthStatus: String {
        if healthPercentage >= 80 { return "Normal" }
        else if healthPercentage >= 50 { return "Service Recommended" }
        else { return "Service Battery" }
    }
    
    var formattedTimeRemaining: String {
        guard let minutes = timeRemaining, minutes > 0 else {
            return isCharging ? "Calculating..." : "Unknown"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }
    
    static let notPresent = BatteryHealthDetail(
        healthPercentage: 100,
        cycleCount: 0,
        condition: .unknown,
        temperature: nil,
        designCapacity: 0,
        currentMaxCapacity: 0,
        chargePercentage: 0,
        isCharging: false,
        timeRemaining: nil,
        powerSource: .unknown
    )
}

// MARK: - Battery Condition
enum BatteryCondition: String {
    case normal = "Normal"
    case serviceRecommended = "Service Recommended"
    case serviceBattery = "Service Battery"
    case unknown = "Unknown"
    
    init(fromHealth health: Int) {
        if health >= 80 { self = .normal }
        else if health >= 50 { self = .serviceRecommended }
        else { self = .serviceBattery }
    }
}

// MARK: - Power Source
enum PowerSource: String {
    case battery = "Battery"
    case acPower = "Power Adapter"
    case unknown = "Unknown"
}

// MARK: - Battery Drain Summary
struct BatteryDrainSummary {
    let topConsumers: [BatteryDrainEntry]
    let sampleTime: Date
    let averageEnergyImpact: Double
    
    var totalHighImpactApps: Int {
        topConsumers.filter { $0.impactLevel == .high }.count
    }
    
    static let empty = BatteryDrainSummary(
        topConsumers: [],
        sampleTime: Date(),
        averageEnergyImpact: 0
    )
}
