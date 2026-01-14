import Foundation
import AppKit
import SwiftUI

// MARK: - Startup Item
struct StartupItem: Identifiable {
    let id: UUID
    let name: String
    let bundleIdentifier: String?
    let path: String?
    let icon: NSImage?
    let isEnabled: Bool
    let impactLevel: ImpactLevel
    let canBeDisabled: Bool
    let type: StartupItemType
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        path: String? = nil,
        icon: NSImage? = nil,
        isEnabled: Bool = true,
        impactLevel: ImpactLevel = .medium,
        canBeDisabled: Bool = true,
        type: StartupItemType = .loginItem
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.isEnabled = isEnabled
        self.impactLevel = impactLevel
        self.canBeDisabled = canBeDisabled
        self.type = type
    }
}

// MARK: - Impact Level
enum ImpactLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .smartMacSuccess
        case .medium: return .smartMacWarning
        case .high: return .smartMacDanger
        }
    }
    
    var estimatedSeconds: Double {
        switch self {
        case .low: return 0.5
        case .medium: return 2.0
        case .high: return 5.0
        }
    }
}

// MARK: - Startup Item Type
enum StartupItemType: String {
    case loginItem = "Login Item"
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case helperTool = "Helper Tool"
    
    var icon: String {
        switch self {
        case .loginItem: return "person.crop.circle"
        case .launchAgent: return "gearshape"
        case .launchDaemon: return "server.rack"
        case .helperTool: return "wrench"
        }
    }
}

// MARK: - Startup Impact Summary
struct StartupImpact {
    let estimatedBootSeconds: Double
    let itemCount: Int
    let highImpactCount: Int
    let mediumImpactCount: Int
    let lowImpactCount: Int
    
    var formattedTime: String {
        if estimatedBootSeconds >= 60 {
            let minutes = Int(estimatedBootSeconds) / 60
            let seconds = Int(estimatedBootSeconds) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return String(format: "%.1fs", estimatedBootSeconds)
        }
    }
    
    static let empty = StartupImpact(
        estimatedBootSeconds: 0,
        itemCount: 0,
        highImpactCount: 0,
        mediumImpactCount: 0,
        lowImpactCount: 0
    )
}

// MARK: - Boot Time Record
struct BootTimeRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let bootTimeSeconds: Double
    
    init(id: UUID = UUID(), timestamp: Date = Date(), bootTimeSeconds: Double) {
        self.id = id
        self.timestamp = timestamp
        self.bootTimeSeconds = bootTimeSeconds
    }
    
    var formattedTime: String {
        if bootTimeSeconds >= 60 {
            let minutes = Int(bootTimeSeconds) / 60
            let seconds = Int(bootTimeSeconds) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return String(format: "%.1fs", bootTimeSeconds)
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Boot Time History
struct BootTimeHistory: Codable {
    var records: [BootTimeRecord]
    
    init(records: [BootTimeRecord] = []) {
        self.records = records
    }
    
    mutating func addRecord(_ record: BootTimeRecord) {
        records.insert(record, at: 0)
        // Keep only last 30 records
        if records.count > 30 {
            records = Array(records.prefix(30))
        }
    }
    
    var averageBootTime: Double {
        guard !records.isEmpty else { return 0 }
        return records.map { $0.bootTimeSeconds }.reduce(0, +) / Double(records.count)
    }
    
    var latestBootTime: Double? {
        records.first?.bootTimeSeconds
    }
}
