import Foundation

/// Service for scanning and cleaning up temporary/cache files
@MainActor
class CleanupScanner: ObservableObject {
    @Published var scanResult: CleanupScanResult = .empty
    @Published var isScanning: Bool = false
    @Published var isDeleting: Bool = false
    @Published var lastDeleteResult: DeleteResult?
    
    private let fileManager = FileManager.default
    private let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    
    // MARK: - Scan Paths
    private var userCachePath: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    private var userLogsPath: URL? {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs")
    }
    
    private var downloadsPath: URL? {
        fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    private var applicationSupportPath: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Public Methods
    func scanAll() async {
        isScanning = true
        defer { isScanning = false }
        
        var categoryResults: [CleanupCategoryResult] = []
        
        // Scan User Cache
        if let cachePath = userCachePath {
            let items = await scanDirectory(cachePath, category: .userCache, maxDepth: 2)
            if !items.isEmpty {
                categoryResults.append(CleanupCategoryResult(category: .userCache, items: items))
            }
        }
        
        // Scan Logs
        if let logsPath = userLogsPath {
            let items = await scanDirectory(logsPath, category: .logs, maxDepth: 2)
            if !items.isEmpty {
                categoryResults.append(CleanupCategoryResult(category: .logs, items: items))
            }
        }
        
        // Scan Old Downloads (files older than 30 days)
        if let downloadsPath = downloadsPath {
            let items = await scanOldDownloads(downloadsPath)
            if !items.isEmpty {
                categoryResults.append(CleanupCategoryResult(category: .downloads, items: items))
            }
        }
        
        // Scan System Cache (/private/var/folders for user-accessible portions)
        let systemCacheItems = await scanSystemCache()
        if !systemCacheItems.isEmpty {
            categoryResults.append(CleanupCategoryResult(category: .systemCache, items: systemCacheItems))
        }
        
        // Sort by total size (largest first)
        categoryResults.sort { $0.totalSize > $1.totalSize }
        
        scanResult = CleanupScanResult(categories: categoryResults, scanDate: Date())
    }
    
    func deleteSelectedItems() async -> DeleteResult {
        isDeleting = true
        defer { isDeleting = false }
        
        var deletedCount = 0
        var freedBytes: Int64 = 0
        var failedItems: [CleanupItem] = []
        
        for category in scanResult.categories {
            for item in category.items where item.isSelected {
                do {
                    try fileManager.removeItem(at: item.path)
                    deletedCount += 1
                    freedBytes += item.sizeBytes
                } catch {
                    failedItems.append(item)
                }
            }
        }
        
        let result = DeleteResult(
            deletedCount: deletedCount,
            freedBytes: freedBytes,
            failedItems: failedItems
        )
        
        lastDeleteResult = result
        
        // Rescan to update the list
        await scanAll()
        
        return result
    }
    
    func toggleItem(_ item: CleanupItem) {
        for i in scanResult.categories.indices {
            if let j = scanResult.categories[i].items.firstIndex(where: { $0.id == item.id }) {
                scanResult.categories[i].items[j].isSelected.toggle()
            }
        }
    }
    
    func toggleCategory(_ category: CleanupCategory, selected: Bool) {
        if let i = scanResult.categories.firstIndex(where: { $0.category == category }) {
            for j in scanResult.categories[i].items.indices {
                scanResult.categories[i].items[j].isSelected = selected
            }
        }
    }
    
    func selectAll(_ selected: Bool) {
        for i in scanResult.categories.indices {
            for j in scanResult.categories[i].items.indices {
                scanResult.categories[i].items[j].isSelected = selected
            }
        }
    }
    
    // MARK: - Private Scanning Methods
    private func scanDirectory(_ url: URL, category: CleanupCategory, maxDepth: Int) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            // Limit depth
            let depth = fileURL.pathComponents.count - url.pathComponents.count
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                
                // Skip directories for listing (but traverse them)
                if resourceValues.isDirectory == true {
                    continue
                }
                
                let size = Int64(resourceValues.fileSize ?? 0)
                // Only include files larger than 1KB
                guard size > 1024 else { continue }
                
                let item = CleanupItem(
                    path: fileURL,
                    name: fileURL.lastPathComponent,
                    sizeBytes: size,
                    category: category,
                    lastModified: resourceValues.contentModificationDate
                )
                items.append(item)
            } catch {
                continue
            }
        }
        
        // Sort by size (largest first) and limit to top 100 per category
        return Array(items.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(100))
    }
    
    private func scanOldDownloads(_ url: URL) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return items
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                
                // Include both files and folders in Downloads
                let isDirectory = resourceValues.isDirectory ?? false
                let size: Int64
                
                if isDirectory {
                    size = calculateDirectorySize(fileURL)
                } else {
                    size = Int64(resourceValues.fileSize ?? 0)
                }
                
                // Check if older than 30 days
                guard let modDate = resourceValues.contentModificationDate,
                      modDate < thirtyDaysAgo else {
                    continue
                }
                
                // Only include items larger than 1MB
                guard size > 1_000_000 else { continue }
                
                let item = CleanupItem(
                    path: fileURL,
                    name: fileURL.lastPathComponent,
                    sizeBytes: size,
                    category: .downloads,
                    lastModified: modDate
                )
                items.append(item)
            } catch {
                continue
            }
        }
        
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }
    
    private func scanSystemCache() async -> [CleanupItem] {
        // Scan user-accessible temporary directories
        var items: [CleanupItem] = []
        
        let tempDir = FileManager.default.temporaryDirectory
        items.append(contentsOf: await scanDirectory(tempDir, category: .systemCache, maxDepth: 2))
        
        return items
    }
    
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}
