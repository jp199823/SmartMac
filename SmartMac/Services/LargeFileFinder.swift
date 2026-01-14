import Foundation
import AppKit

/// Service for finding large files and analyzing disk usage
class LargeFileFinder: ObservableObject {
    // MARK: - Published Properties
    @Published var state: ScanState = .idle
    @Published var files: [FileItem] = []
    @Published var summary: ScanSummary = .empty
    @Published var topDirectories: [DirectorySize] = []
    
    // MARK: - Private Properties
    private var isCancelled = false
    private var scanTask: Task<Void, Never>?
    
    // Default minimum size: 100 MB
    var minimumSize: UInt64 = 100 * 1024 * 1024
    
    // MARK: - Singleton
    static let shared = LargeFileFinder()
    
    // MARK: - Public Methods
    func scanDirectory(_ path: String) {
        cancelScan()
        
        isCancelled = false
        files = []
        summary = .empty
        topDirectories = []
        
        scanTask = Task { @MainActor in
            state = .scanning(progress: 0, filesFound: 0)
            
            do {
                let url = URL(fileURLWithPath: path)
                var foundFiles: [FileItem] = []
                var typeStats: [FileType: (count: Int, size: UInt64)] = [:]
                var directorySizes: [String: UInt64] = [:]
                var scannedCount = 0
                let totalEstimate = estimateFileCount(at: path)
                
                // Create file enumerator
                let fileManager = FileManager.default
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    state = .error("Cannot access directory")
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    if isCancelled {
                        state = .idle
                        return
                    }
                    
                    scannedCount += 1
                    
                    // Update progress periodically
                    if scannedCount % 100 == 0 {
                        let progress = min(Double(scannedCount) / Double(totalEstimate), 0.99)
                        state = .scanning(progress: progress, filesFound: foundFiles.count)
                    }
                    
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isRegularFileKey]) else {
                        continue
                    }
                    
                    // Skip directories for file list (but track their sizes)
                    if resourceValues.isDirectory == true {
                        continue
                    }
                    
                    guard resourceValues.isRegularFile == true,
                          let fileSize = resourceValues.fileSize else {
                        continue
                    }
                    
                    let size = UInt64(fileSize)
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    let filePath = fileURL.path
                    
                    // Track directory sizes (for parent directory)
                    let parentPath = (filePath as NSString).deletingLastPathComponent
                    let relativeParent = parentPath.replacingOccurrences(of: path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let topLevelDir = relativeParent.components(separatedBy: "/").first ?? "Root"
                    directorySizes[topLevelDir, default: 0] += size
                    
                    // Track type statistics
                    let fileType = FileType.detect(from: filePath)
                    var stats = typeStats[fileType, default: (0, 0)]
                    stats.count += 1
                    stats.size += size
                    typeStats[fileType] = stats
                    
                    // Only add large files
                    if size >= minimumSize {
                        let item = FileItem(
                            name: fileURL.lastPathComponent,
                            path: filePath,
                            size: size,
                            modifiedDate: modDate,
                            fileType: fileType
                        )
                        foundFiles.append(item)
                    }
                }
                
                // Sort by size descending
                foundFiles.sort { $0.size > $1.size }
                
                // Create summary
                let totalSize = typeStats.values.reduce(0) { $0 + $1.size }
                let totalFiles = typeStats.values.reduce(0) { $0 + $1.count }
                
                // Create top directories list
                let topDirs = directorySizes
                    .map { DirectorySize(name: $0.key, path: "\(path)/\($0.key)", size: $0.value) }
                    .sorted { $0.size > $1.size }
                    .prefix(10)
                
                // Update state
                files = foundFiles
                summary = ScanSummary(totalFiles: totalFiles, totalSize: totalSize, byType: typeStats)
                topDirectories = Array(topDirs)
                state = .complete
                
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    func cancelScan() {
        isCancelled = true
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }
    
    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
    
    func moveToTrash(_ item: FileItem) throws {
        let url = URL(fileURLWithPath: item.path)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        
        // Remove from list
        files.removeAll { $0.id == item.id }
    }
    
    func openWith(_ item: FileItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Private Methods
    private func estimateFileCount(at path: String) -> Int {
        // Quick estimate based on directory count
        // This is a rough heuristic to provide progress feedback
        let fileManager = FileManager.default
        var count = 0
        
        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            for item in contents {
                var isDir: ObjCBool = false
                let fullPath = "\(path)/\(item)"
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        // Estimate ~100 files per directory
                        count += 100
                    } else {
                        count += 1
                    }
                }
            }
        }
        
        return max(count, 1000) // Minimum estimate
    }
    
    // MARK: - Quick Scan Presets
    func scanHome() {
        scanDirectory(FileManager.default.homeDirectoryForCurrentUser.path)
    }
    
    func scanDownloads() {
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            scanDirectory(downloadsURL.path)
        }
    }
    
    func scanDocuments() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            scanDirectory(documentsURL.path)
        }
    }
    
    func scanDesktop() {
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            scanDirectory(desktopURL.path)
        }
    }
}
