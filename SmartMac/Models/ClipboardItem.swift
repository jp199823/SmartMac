import Foundation
import AppKit

// MARK: - Clipboard Type
enum ClipboardType: String, Codable, CaseIterable {
    case text = "Text"
    case url = "URL"
    case filePath = "File"
    case image = "Image"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .filePath: return "folder"
        case .image: return "photo"
        case .other: return "doc"
        }
    }
}

// MARK: - Clipboard Item
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let type: ClipboardType
    let timestamp: Date
    var isFavorite: Bool
    let previewText: String
    var imageData: Data?
    
    init(content: String, type: ClipboardType, imageData: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isFavorite = false
        self.previewText = String(content.prefix(100))
        self.imageData = imageData
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Formatting Helpers
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var displayContent: String {
        switch type {
        case .filePath:
            return (content as NSString).lastPathComponent
        case .url:
            if let url = URL(string: content) {
                return url.host ?? content
            }
            return content
        default:
            return previewText
        }
    }
}

// MARK: - Clipboard Filter
enum ClipboardFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case urls = "URLs"
    case files = "Files"
    case favorites = "Favorites"
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "doc.text"
        case .urls: return "link"
        case .files: return "folder"
        case .favorites: return "star.fill"
        }
    }
}
