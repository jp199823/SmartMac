import Foundation
import AppKit
import CryptoKit

/// Service for finding large files and analyzing disk usage
class LargeFileFinder: ObservableObject {
    // MARK: - Published Properties
    @Published var state: ScanState = .idle
    @Published var files: [FileItem] = []
    @Published var summary: ScanSummary = .empty
    @Published var topDirectories: [DirectorySize] = []
    @Published var duplicateGroups: [[FileItem]] = []
    @Published var duplicateScanProgress: Double = 0
    
    // Storage Overview Properties (no minimum size)
    @Published var storageOverviewState: ScanState = .idle
    @Published var storageByFolder: [DirectorySize] = []
    @Published var storageByType: [FileType: (count: Int, size: UInt64)] = [:]
    @Published var totalScannedSize: UInt64 = 0
    @Published var totalScannedFiles: Int = 0
    
    // MARK: - Private Properties
    private var isCancelled = false
    private var scanTask: Task<Void, Never>?
    private var overviewTask: Task<Void, Never>?
    
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
        duplicateGroups = []
        
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
    
    // MARK: - Storage Overview Scan (No Minimum Size)
    /// Scans storage to show where disk space is allocated, without any minimum file size filter
    func scanStorageOverview(_ path: String) {
        overviewTask?.cancel()
        
        storageByFolder = []
        storageByType = [:]
        totalScannedSize = 0
        totalScannedFiles = 0
        
        overviewTask = Task { @MainActor in
            storageOverviewState = .scanning(progress: 0, filesFound: 0)
            
            let url = URL(fileURLWithPath: path)
            var typeStats: [FileType: (count: Int, size: UInt64)] = [:]
            var folderSizes: [String: UInt64] = [:]
            var scannedCount = 0
            var totalSize: UInt64 = 0
            let totalEstimate = estimateFileCount(at: path)
            
            // Create file enumerator - include hidden files for accurate space accounting
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey],
                options: [.skipsPackageDescendants]
            ) else {
                storageOverviewState = .error("Cannot access directory")
                return
            }
            
            for case let fileURL as URL in enumerator {
                if Task.isCancelled {
                    storageOverviewState = .idle
                    return
                }
                
                scannedCount += 1
                
                // Update progress periodically
                if scannedCount % 200 == 0 {
                    let progress = min(Double(scannedCount) / Double(totalEstimate), 0.99)
                    storageOverviewState = .scanning(progress: progress, filesFound: scannedCount)
                }
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey]) else {
                    continue
                }
                
                // Skip directories
                if resourceValues.isDirectory == true {
                    continue
                }
                
                guard resourceValues.isRegularFile == true,
                      let fileSize = resourceValues.fileSize else {
                    continue
                }
                
                let size = UInt64(fileSize)
                totalSize += size
                
                let filePath = fileURL.path
                
                // Track folder sizes - get top-level folder relative to scan path
                let relativePath = filePath.replacingOccurrences(of: path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let components = relativePath.components(separatedBy: "/")
                let topLevelFolder = components.first ?? "Root"
                folderSizes[topLevelFolder, default: 0] += size
                
                // Track type statistics
                let fileType = FileType.detect(from: filePath)
                var stats = typeStats[fileType, default: (0, 0)]
                stats.count += 1
                stats.size += size
                typeStats[fileType] = stats
            }
            
            // Sort folders by size and take top entries
            let sortedFolders = folderSizes
                .map { DirectorySize(name: $0.key, path: "\(path)/\($0.key)", size: $0.value) }
                .sorted { $0.size > $1.size }
            
            // Update published properties
            storageByFolder = sortedFolders
            storageByType = typeStats
            totalScannedSize = totalSize
            totalScannedFiles = scannedCount
            storageOverviewState = .complete
        }
    }
    
    func cancelStorageOverview() {
        overviewTask?.cancel()
        overviewTask = nil
        storageOverviewState = .idle
    }

    // MARK: - Duplicate Detection
    func findDuplicates() {
        guard !files.isEmpty else { return }
        
        duplicateGroups = []
        duplicateScanProgress = 0
        
        Task { @MainActor in
            // Group files by size first (files must be same size to be duplicates)
            let sizeGroups = Dictionary(grouping: files, by: { $0.size })
            let potentialDuplicates = sizeGroups.filter { $0.value.count > 1 }
            
            var processed = 0
            let total = potentialDuplicates.values.reduce(0) { $0 + $1.count }
            
            var foundDuplicates: [[FileItem]] = []
            
            for (_, group) in potentialDuplicates {
                // For files with same size, compute partial hash to identify duplicates
                var hashGroups: [String: [FileItem]] = [:]
                
                for file in group {
                    if isCancelled { return }
                    
                    processed += 1
                    duplicateScanProgress = Double(processed) / Double(total)
                    
                    if let hash = computePartialHash(for: file.path) {
                        hashGroups[hash, default: []].append(file)
                    }
                }
                
                // Add groups with actual duplicates
                for (_, items) in hashGroups where items.count > 1 {
                    foundDuplicates.append(items.sorted { $0.name < $1.name })
                }
            }
            
            duplicateGroups = foundDuplicates.sorted { 
                ($0.first?.size ?? 0) * UInt64($0.count - 1) > ($1.first?.size ?? 0) * UInt64($1.count - 1)
            }
            duplicateScanProgress = 1.0
        }
    }
    
    private func computePartialHash(for path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fileHandle.close() }
        
        // Read first 64KB for quick hash comparison
        let chunkSize = 64 * 1024
        guard let data = try? fileHandle.read(upToCount: chunkSize), !data.isEmpty else { return nil }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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
        
        // Remove from duplicate groups
        for i in duplicateGroups.indices {
            duplicateGroups[i].removeAll { $0.id == item.id }
        }
        duplicateGroups.removeAll { $0.count < 2 }
    }
    
    func openWith(_ item: FileItem) {
        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Export Functions
    func exportToCSV() -> URL? {
        guard !files.isEmpty else { return nil }
        
        var csv = "Name,Path,Size (bytes),Size (formatted),Type,Modified Date\n"
        
        for file in files {
            let escapedName = file.name.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedPath = file.path.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(escapedName)\",\"\(escapedPath)\",\(file.size),\"\(file.formattedSize)\",\"\(file.fileType.rawValue)\",\"\(file.formattedDate)\"\n"
        }
        
        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("SmartMac_LargeFiles_\(Date().timeIntervalSince1970).csv")
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func exportToText() -> URL? {
        guard !files.isEmpty else { return nil }
        
        var text = "SmartMac Large File Report\n"
        text += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n"
        text += "Files Found: \(files.count)\n"
        text += "Total Size: \(files.reduce(0) { $0 + $1.size }.formattedBytes)\n"
        text += String(repeating: "=", count: 60) + "\n\n"
        
        for (index, file) in files.enumerated() {
            text += "\(index + 1). \(file.name)\n"
            text += "   Size: \(file.formattedSize)\n"
            text += "   Type: \(file.fileType.rawValue)\n"
            text += "   Path: \(file.path)\n"
            text += "   Modified: \(file.formattedDate)\n\n"
        }
        
        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("SmartMac_LargeFiles_\(Date().timeIntervalSince1970).txt")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
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
    
    // MARK: - Potential Savings Calculation
    var potentialSavings: UInt64 {
        // Sum of all duplicate files (keeping one copy)
        duplicateGroups.reduce(0) { total, group in
            guard let firstSize = group.first?.size else { return total }
            return total + firstSize * UInt64(group.count - 1)
        }
    }
}

