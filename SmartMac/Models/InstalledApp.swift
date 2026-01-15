import Foundation
import AppKit
import SwiftUI

// MARK: - File Category
/// Categories of files associated with an application
enum AppFileCategory: String, CaseIterable, Identifiable {
    case appBundle = "Application"
    case preferences = "Preferences"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case containers = "Containers"
    case logs = "Logs"
    case savedState = "Saved State"
    case launchAgents = "Launch Agents"
    case cookies = "Cookies"
    case crashReports = "Crash Reports"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .appBundle: return "app.fill"
        case .preferences: return "gearshape.fill"
        case .applicationSupport: return "folder.fill"
        case .caches: return "internaldrive.fill"
        case .containers: return "shippingbox.fill"
        case .logs: return "doc.text.fill"
        case .savedState: return "arrow.counterclockwise"
        case .launchAgents: return "play.circle.fill"
        case .cookies: return "circle.grid.2x2.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .appBundle: return .smartMacAccentBlue
        case .preferences: return .smartMacAccentGreen
        case .applicationSupport: return .smartMacWarning
        case .caches: return .smartMacInfo
        case .containers: return .smartMacAccentBlue
        case .logs: return .smartMacTextSecondary
        case .savedState: return .smartMacSuccess
        case .launchAgents: return .smartMacDanger
        case .cookies: return .smartMacWarning
        case .crashReports: return .smartMacDanger
        }
    }
    
    var basePath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .appBundle: return nil // Multiple locations
        case .preferences: return "\(home)/Library/Preferences"
        case .applicationSupport: return "\(home)/Library/Application Support"
        case .caches: return "\(home)/Library/Caches"
        case .containers: return "\(home)/Library/Containers"
        case .logs: return "\(home)/Library/Logs"
        case .savedState: return "\(home)/Library/Saved Application State"
        case .launchAgents: return "\(home)/Library/LaunchAgents"
        case .cookies: return "\(home)/Library/Cookies"
        case .crashReports: return "\(home)/Library/Logs/DiagnosticReports"
        }
    }
}

// MARK: - App Related File
/// Represents a file or folder associated with an installed application
struct AppRelatedFile: Identifiable, Hashable {
    let id = UUID()
    let path: URL
    let name: String
    let category: AppFileCategory
    let sizeBytes: Int64
    var isSelected: Bool = true
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppRelatedFile, rhs: AppRelatedFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Installed App
/// Represents an installed application with all its associated files
struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String?
    let bundlePath: URL
    let icon: NSImage?
    let version: String?
    let developer: String?
    let installDate: Date?
    var relatedFiles: [AppRelatedFile]
    var isSelected: Bool = false
    var isExpanded: Bool = false
    
    /// Total size of the app including all related files
    var totalSizeBytes: Int64 {
        relatedFiles.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Size of selected files only
    var selectedSizeBytes: Int64 {
        relatedFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Formatted total size string
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    /// Formatted selected size string
    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSizeBytes, countStyle: .file)
    }
    
    /// Number of related file categories
    var categoryCount: Int {
        Set(relatedFiles.map { $0.category }).count
    }
    
    /// Get files grouped by category
    var filesByCategory: [AppFileCategory: [AppRelatedFile]] {
        Dictionary(grouping: relatedFiles, by: { $0.category })
    }
    
    /// Size by category for display
    func sizeForCategory(_ category: AppFileCategory) -> Int64 {
        relatedFiles.filter { $0.category == category }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Formatted size for category
    func formattedSizeForCategory(_ category: AppFileCategory) -> String {
        ByteCountFormatter.string(fromByteCount: sizeForCategory(category), countStyle: .file)
    }
}

// MARK: - Uninstall Result
/// Result of an uninstall operation
struct UninstallResult {
    let appName: String
    let deletedFiles: Int
    let freedBytes: Int64
    let failedFiles: [AppRelatedFile]
    let movedToTrash: Bool
    
    var formattedFreedSize: String {
        ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
    }
    
    var hasErrors: Bool {
        !failedFiles.isEmpty
    }
    
    var isSuccess: Bool {
        deletedFiles > 0 && !hasErrors
    }
}

// MARK: - Batch Uninstall Result
/// Result of uninstalling multiple applications
struct BatchUninstallResult {
    let results: [UninstallResult]
    
    var totalDeletedFiles: Int {
        results.reduce(0) { $0 + $1.deletedFiles }
    }
    
    var totalFreedBytes: Int64 {
        results.reduce(0) { $0 + $1.freedBytes }
    }
    
    var formattedTotalFreed: String {
        ByteCountFormatter.string(fromByteCount: totalFreedBytes, countStyle: .file)
    }
    
    var successCount: Int {
        results.filter { $0.isSuccess }.count
    }
    
    var failureCount: Int {
        results.filter { $0.hasErrors }.count
    }
}

// MARK: - App Sort Option
enum AppSortOption: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case installDate = "Install Date"
    
    var icon: String {
        switch self {
        case .name: return "textformat.abc"
        case .size: return "arrow.up.arrow.down.square"
        case .installDate: return "calendar"
        }
    }
}

// MARK: - App Filter Option
enum AppFilterOption: String, CaseIterable {
    case all = "All Apps"
    case recentlyInstalled = "Recently Installed"
    case largeApps = "Large Apps (>500MB)"
    case unused = "Potentially Unused"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .recentlyInstalled: return "clock.arrow.circlepath"
        case .largeApps: return "externaldrive.fill"
        case .unused: return "zzz"
        }
    }
}
