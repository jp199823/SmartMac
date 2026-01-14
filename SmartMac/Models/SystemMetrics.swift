import Foundation
import AppKit
import SwiftUI

// MARK: - Memory Metrics
struct MemoryMetrics {
    let total: UInt64           // Total RAM in bytes
    let free: UInt64            // Free RAM in bytes
    let used: UInt64            // Used RAM in bytes
    let active: UInt64          // Active memory
    let inactive: UInt64        // Inactive memory
    let wired: UInt64           // Wired memory (cannot be paged out)
    let compressed: UInt64      // Compressed memory
    
    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    var freePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total) * 100
    }
    
    static let empty = MemoryMetrics(total: 0, free: 0, used: 0, active: 0, inactive: 0, wired: 0, compressed: 0)
}

// MARK: - Storage Metrics
struct StorageMetrics {
    let volumeName: String
    let mountPoint: String
    let total: UInt64           // Total storage in bytes
    let free: UInt64            // Free storage in bytes
    let used: UInt64            // Used storage in bytes
    
    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    var freePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total) * 100
    }
    
    static let empty = StorageMetrics(volumeName: "Macintosh HD", mountPoint: "/", total: 0, free: 0, used: 0)
}

// MARK: - CPU Metrics
struct CPUMetrics {
    let modelName: String
    let physicalCores: Int
    let logicalCores: Int
    let usagePercentage: Double
    let thermalState: ThermalState
    
    static let empty = CPUMetrics(modelName: "Unknown", physicalCores: 0, logicalCores: 0, usagePercentage: 0, thermalState: .nominal)
}

enum ThermalState: String {
    case nominal = "Normal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .nominal: return "smartMacSuccess"
        case .fair: return "smartMacWarning"
        case .serious: return "smartMacWarning"
        case .critical: return "smartMacDanger"
        }
    }
}

// MARK: - Battery Metrics
struct BatteryMetrics {
    let isPresent: Bool
    let chargePercentage: Int
    let isCharging: Bool
    let cycleCount: Int
    let health: String
    let timeRemaining: Int?     // Minutes remaining, nil if on power
    
    static let notPresent = BatteryMetrics(isPresent: false, chargePercentage: 100, isCharging: false, cycleCount: 0, health: "N/A", timeRemaining: nil)
}

// MARK: - Network Metrics
struct NetworkMetrics {
    let isConnected: Bool
    let connectionType: String  // "Wi-Fi", "Ethernet", "None"
    let ipAddress: String
    let bytesReceived: UInt64
    let bytesSent: UInt64
    
    static let disconnected = NetworkMetrics(isConnected: false, connectionType: "None", ipAddress: "N/A", bytesReceived: 0, bytesSent: 0)
}

// MARK: - GPU Metrics
struct GPUMetrics {
    let name: String
    let vendor: String
    let vram: UInt64            // VRAM in bytes (0 for integrated)
    let isIntegrated: Bool
    
    static let empty = GPUMetrics(name: "Unknown", vendor: "Unknown", vram: 0, isIntegrated: true)
}

// MARK: - Running Application
struct RunningApplication: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String?
    let memoryUsage: UInt64     // Memory in bytes
    let icon: NSImage?
    
    var memoryUsageMB: Double {
        Double(memoryUsage) / 1_048_576
    }
}

// MARK: - System Health
enum SystemHealth {
    case excellent
    case good
    case fair
    case poor
    
    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Needs Attention"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .excellent: return .smartMacSuccess
        case .good: return .smartMacAccentGreen
        case .fair: return .smartMacWarning
        case .poor: return .smartMacDanger
        }
    }
}

// MARK: - Byte Formatting Helper
extension UInt64 {
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
    
    var formattedBytesShort: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
}
