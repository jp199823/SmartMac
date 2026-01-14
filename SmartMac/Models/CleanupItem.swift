import Foundation

// MARK: - Cleanup Category
enum CleanupCategory: String, CaseIterable, Identifiable {
    case systemCache = "System Caches"
    case userCache = "User Caches"
    case logs = "System Logs"
    case downloads = "Old Downloads"
    case appLeftovers = "App Leftovers"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .systemCache: return "gearshape.2.fill"
        case .userCache: return "person.fill"
        case .logs: return "doc.text.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .appLeftovers: return "trash.fill"
        }
    }
    
    var description: String {
        switch self {
        case .systemCache: return "Temporary files created by macOS"
        case .userCache: return "App-specific cache files"
        case .logs: return "System and application log files"
        case .downloads: return "Files in Downloads older than 30 days"
        case .appLeftovers: return "Residual files from uninstalled apps"
        }
    }
}

// MARK: - Cleanup Item
struct CleanupItem: Identifiable, Hashable {
    let id = UUID()
    let path: URL
    let name: String
    let sizeBytes: Int64
    let category: CleanupCategory
    let lastModified: Date?
    var isSelected: Bool = true
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = lastModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CleanupItem, rhs: CleanupItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cleanup Category Result
struct CleanupCategoryResult: Identifiable {
    let category: CleanupCategory
    var items: [CleanupItem]
    
    var id: String { category.rawValue }
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
    
    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Cleanup Scan Result
struct CleanupScanResult {
    var categories: [CleanupCategoryResult]
    let scanDate: Date
    
    var totalSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
    }
    
    var selectedSize: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }
    
    var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
    
    var selectedItems: Int {
        categories.reduce(0) { $0 + $1.selectedCount }
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
    
    static let empty = CleanupScanResult(categories: [], scanDate: Date())
}

// MARK: - Delete Result
struct DeleteResult {
    let deletedCount: Int
    let freedBytes: Int64
    let failedItems: [CleanupItem]
    
    var formattedFreedSize: String {
        ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
    }
    
    var hasErrors: Bool {
        !failedItems.isEmpty
    }
}
