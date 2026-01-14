import Foundation
import SwiftUI

// MARK: - Suggestion Model
struct Suggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: SuggestionCategory
    let priority: SuggestionPriority
    let icon: String
    let actionLabel: String?
    let triggerCondition: (SystemMonitor) -> Bool
    
    func isRelevant(for monitor: SystemMonitor) -> Bool {
        triggerCondition(monitor)
    }
}

enum SuggestionCategory: String, CaseIterable {
    case memory = "Memory"
    case storage = "Storage"
    case performance = "Performance"
    case maintenance = "Maintenance"
    case battery = "Battery"
    case network = "Network"
    
    var color: Color {
        switch self {
        case .memory: return .smartMacAccentBlue
        case .storage: return .smartMacForestGreen
        case .performance: return .smartMacWarning
        case .maintenance: return .smartMacInfo
        case .battery: return .smartMacSuccess
        case .network: return .smartMacNavyBlue
        }
    }
    
    var icon: String {
        switch self {
        case .memory: return "memorychip"
        case .storage: return "internaldrive"
        case .performance: return "bolt"
        case .maintenance: return "wrench.and.screwdriver"
        case .battery: return "battery.100"
        case .network: return "wifi"
        }
    }
}

enum SuggestionPriority: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: SuggestionPriority, rhs: SuggestionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .smartMacTextSecondary
        case .medium: return .smartMacInfo
        case .high: return .smartMacWarning
        case .critical: return .smartMacDanger
        }
    }
}
