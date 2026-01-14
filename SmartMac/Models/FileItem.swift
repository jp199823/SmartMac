import Foundation
import AppKit
import SwiftUI

// MARK: - File Type
enum FileType: String, CaseIterable {
    case video = "Video"
    case image = "Image"
    case audio = "Audio"
    case document = "Document"
    case application = "Application"
    case archive = "Archive"
    case other = "Other"
    
    var color: Color {
        switch self {
        case .video: return .smartMacDanger
        case .image: return .smartMacAccentGreen
        case .audio: return .smartMacNavyBlue
        case .document: return .smartMacCasaBlanca
        case .application: return .smartMacForestGreen
        case .archive: return .smartMacWarning
        case .other: return .smartMacTextSecondary
        }
    }
    
    var icon: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .image: return "photo.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .application: return "app.fill"
        case .archive: return "archivebox.fill"
        case .other: return "doc.fill"
        }
    }
    
    static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "svg", "raw", "psd"]
    static let audioExtensions: Set<String> = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
    static let documentExtensions: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "key"]
    static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg"]
    
    static func detect(from path: String) -> FileType {
        let ext = (path as NSString).pathExtension.lowercased()
        
        if videoExtensions.contains(ext) { return .video }
        if imageExtensions.contains(ext) { return .image }
        if audioExtensions.contains(ext) { return .audio }
        if documentExtensions.contains(ext) { return .document }
        if archiveExtensions.contains(ext) { return .archive }
        if ext == "app" || path.contains(".app/") { return .application }
        
        return .other
    }
}

// MARK: - File Item
struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let size: UInt64
    let modifiedDate: Date
    let fileType: FileType
    let isDirectory: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: UInt64,
        modifiedDate: Date = Date(),
        fileType: FileType? = nil,
        isDirectory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
        self.fileType = fileType ?? FileType.detect(from: path)
        self.isDirectory = isDirectory
    }
    
    var formattedSize: String {
        size.formattedBytes
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modifiedDate)
    }
    
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Directory Size
struct DirectorySize: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let size: UInt64
    let fileCount: Int
    var children: [DirectorySize]
    
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: UInt64,
        fileCount: Int = 0,
        children: [DirectorySize] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.fileCount = fileCount
        self.children = children
    }
    
    var formattedSize: String {
        size.formattedBytes
    }
}

// MARK: - Scan State
enum ScanState: Equatable {
    case idle
    case scanning(progress: Double, filesFound: Int)
    case complete
    case error(String)
    
    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - File Sort Option
enum FileSortOption: String, CaseIterable {
    case size = "Size"
    case name = "Name"
    case date = "Date"
    case type = "Type"
}

// MARK: - Scan Summary
struct ScanSummary {
    let totalFiles: Int
    let totalSize: UInt64
    let byType: [FileType: (count: Int, size: UInt64)]
    
    var formattedTotalSize: String {
        totalSize.formattedBytes
    }
    
    static let empty = ScanSummary(totalFiles: 0, totalSize: 0, byType: [:])
}
