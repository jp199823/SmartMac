import Foundation

// MARK: - Security Category
enum SecurityCategory: String, CaseIterable, Codable {
    case system = "System"
    case apps = "Apps"
    case privacy = "Privacy"
    
    var icon: String {
        switch self {
        case .system: return "gearshape.fill"
        case .apps: return "app.badge.checkmark.fill"
        case .privacy: return "hand.raised.fill"
        }
    }
    
    var color: String {
        switch self {
        case .system: return "AccentBlue"
        case .apps: return "AccentGreen"
        case .privacy: return "Warning"
        }
    }
}

// MARK: - Security Status
enum SecurityStatus: String, Codable {
    case passed = "Passed"
    case warning = "Warning"
    case failed = "Failed"
    case checking = "Checking"
    
    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .checking: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Security Check
struct SecurityCheck: Identifiable {
    let id: UUID
    let name: String
    let category: SecurityCategory
    var status: SecurityStatus
    let description: String
    var recommendation: String?
    var actionURL: URL?
    var details: String?
    
    init(
        name: String,
        category: SecurityCategory,
        status: SecurityStatus = .checking,
        description: String,
        recommendation: String? = nil,
        actionURL: URL? = nil,
        details: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.status = status
        self.description = description
        self.recommendation = recommendation
        self.actionURL = actionURL
        self.details = details
    }
}

// MARK: - Security Score
struct SecurityScore {
    let score: Int          // 0-100
    let passedChecks: Int
    let warningChecks: Int
    let failedChecks: Int
    let totalChecks: Int
    
    var label: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 50..<75: return "Fair"
        default: return "Poor"
        }
    }
    
    var color: String {
        switch score {
        case 90...100: return "Success"
        case 75..<90: return "Info"
        case 50..<75: return "Warning"
        default: return "Danger"
        }
    }
}

// MARK: - Outdated App Info
struct OutdatedAppInfo: Identifiable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let currentVersion: String
    let lastUpdated: Date?
    let path: String
    
    init(name: String, bundleIdentifier: String, currentVersion: String, lastUpdated: Date?, path: String) {
        self.id = UUID()
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.currentVersion = currentVersion
        self.lastUpdated = lastUpdated
        self.path = path
    }
    
    var formattedLastUpdated: String {
        guard let date = lastUpdated else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var daysSinceUpdate: Int? {
        guard let date = lastUpdated else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}
