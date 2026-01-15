import Foundation
import AppKit

/// Service for discovering installed applications and their associated files
@MainActor
class AppUninstaller: ObservableObject {
    static let shared = AppUninstaller()
    
    @Published var installedApps: [InstalledApp] = []
    @Published var isScanning: Bool = false
    @Published var isUninstalling: Bool = false
    @Published var scanProgress: Double = 0
    @Published var lastUninstallResult: UninstallResult?
    @Published var lastBatchResult: BatchUninstallResult?
    
    private let fileManager = FileManager.default
    
    // Search locations for applications
    private var applicationDirectories: [URL] {
        var dirs: [URL] = []
        // System Applications
        if let sysApps = URL(string: "file:///Applications") {
            dirs.append(sysApps)
        }
        // User Applications
        let userApps = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        dirs.append(userApps)
        return dirs
    }
    
    // MARK: - Public Methods
    
    /// Scan for all installed applications
    func scanInstalledApps() async {
        isScanning = true
        scanProgress = 0
        installedApps = []
        
        defer { 
            isScanning = false 
            scanProgress = 1.0
        }
        
        var apps: [InstalledApp] = []
        var allAppURLs: [URL] = []
        
        // Collect all app bundles
        for directory in applicationDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            let appBundles = contents.filter { $0.pathExtension == "app" }
            allAppURLs.append(contentsOf: appBundles)
        }
        
        let totalApps = Double(allAppURLs.count)
        
        // Process each app
        for (index, appURL) in allAppURLs.enumerated() {
            if let app = await processAppBundle(at: appURL) {
                apps.append(app)
            }
            scanProgress = Double(index + 1) / totalApps
        }
        
        // Sort by size (largest first)
        apps.sort { $0.totalSizeBytes > $1.totalSizeBytes }
        installedApps = apps
    }
    
    /// Find all files related to a specific application
    func findRelatedFiles(for app: InstalledApp) async -> [AppRelatedFile] {
        var files: [AppRelatedFile] = []
        
        guard let bundleId = app.bundleIdentifier else {
            // If no bundle ID, use app name for matching
            files.append(contentsOf: await findFilesByName(app.name, bundlePath: app.bundlePath))
            return files
        }
        
        // Search each category
        for category in AppFileCategory.allCases {
            let categoryFiles = await findFilesForCategory(category, bundleId: bundleId, appName: app.name, bundlePath: app.bundlePath)
            files.append(contentsOf: categoryFiles)
        }
        
        return files
    }
    
    /// Uninstall a single application
    func uninstallApp(_ app: InstalledApp, permanently: Bool = false) async -> UninstallResult {
        isUninstalling = true
        defer { isUninstalling = false }
        
        var deletedCount = 0
        var freedBytes: Int64 = 0
        var failedFiles: [AppRelatedFile] = []
        
        let selectedFiles = app.relatedFiles.filter { $0.isSelected }
        
        for file in selectedFiles {
            do {
                if permanently {
                    try fileManager.removeItem(at: file.path)
                } else {
                    try fileManager.trashItem(at: file.path, resultingItemURL: nil)
                }
                deletedCount += 1
                freedBytes += file.sizeBytes
            } catch {
                failedFiles.append(file)
            }
        }
        
        let result = UninstallResult(
            appName: app.name,
            deletedFiles: deletedCount,
            freedBytes: freedBytes,
            failedFiles: failedFiles,
            movedToTrash: !permanently
        )
        
        lastUninstallResult = result
        
        // Remove from list if successfully uninstalled
        if result.isSuccess {
            installedApps.removeAll { $0.id == app.id }
        }
        
        return result
    }
    
    /// Uninstall multiple applications
    func batchUninstall(_ apps: [InstalledApp], permanently: Bool = false) async -> BatchUninstallResult {
        isUninstalling = true
        defer { isUninstalling = false }
        
        var results: [UninstallResult] = []
        
        for app in apps {
            let result = await uninstallApp(app, permanently: permanently)
            results.append(result)
        }
        
        let batchResult = BatchUninstallResult(results: results)
        lastBatchResult = batchResult
        return batchResult
    }
    
    /// Toggle selection for an app
    func toggleAppSelection(_ app: InstalledApp) {
        if let index = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps[index].isSelected.toggle()
        }
    }
    
    /// Toggle expansion for an app
    func toggleAppExpansion(_ app: InstalledApp) {
        if let index = installedApps.firstIndex(where: { $0.id == app.id }) {
            installedApps[index].isExpanded.toggle()
        }
    }
    
    /// Toggle file selection within an app
    func toggleFileSelection(in app: InstalledApp, file: AppRelatedFile) {
        guard let appIndex = installedApps.firstIndex(where: { $0.id == app.id }),
              let fileIndex = installedApps[appIndex].relatedFiles.firstIndex(where: { $0.id == file.id }) else {
            return
        }
        installedApps[appIndex].relatedFiles[fileIndex].isSelected.toggle()
    }
    
    /// Select all files for an app
    func selectAllFiles(for app: InstalledApp) {
        guard let appIndex = installedApps.firstIndex(where: { $0.id == app.id }) else { return }
        for i in installedApps[appIndex].relatedFiles.indices {
            installedApps[appIndex].relatedFiles[i].isSelected = true
        }
    }
    
    /// Deselect all files for an app
    func deselectAllFiles(for app: InstalledApp) {
        guard let appIndex = installedApps.firstIndex(where: { $0.id == app.id }) else { return }
        for i in installedApps[appIndex].relatedFiles.indices {
            installedApps[appIndex].relatedFiles[i].isSelected = false
        }
    }
    
    /// Get selected apps
    var selectedApps: [InstalledApp] {
        installedApps.filter { $0.isSelected }
    }
    
    /// Total selected size
    var totalSelectedSize: Int64 {
        selectedApps.reduce(0) { $0 + $1.selectedSizeBytes }
    }
    
    /// Formatted total selected size
    var formattedTotalSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    // MARK: - Private Methods
    
    private func processAppBundle(at url: URL) async -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String 
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        let bundleId = bundle.bundleIdentifier
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        
        // Get app icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Get install date from creation date
        var installDate: Date?
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path) {
            installDate = attributes[.creationDate] as? Date
        }
        
        // Get developer from bundle
        let developer = bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        
        // Create initial app without related files
        var app = InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            bundlePath: url,
            icon: icon,
            version: version,
            developer: developer,
            installDate: installDate,
            relatedFiles: []
        )
        
        // Find all related files
        app.relatedFiles = await findRelatedFiles(for: app)
        
        return app
    }
    
    private func findFilesForCategory(_ category: AppFileCategory, bundleId: String, appName: String, bundlePath: URL) async -> [AppRelatedFile] {
        var files: [AppRelatedFile] = []
        
        switch category {
        case .appBundle:
            // The app bundle itself
            if let size = calculateDirectorySize(bundlePath) {
                files.append(AppRelatedFile(
                    path: bundlePath,
                    name: bundlePath.lastPathComponent,
                    category: .appBundle,
                    sizeBytes: size
                ))
            }
            
        case .preferences:
            // Look for plist files matching bundle ID
            if let basePath = category.basePath {
                let prefDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: prefDir, matching: bundleId, category: category))
                files.append(contentsOf: findMatchingFiles(in: prefDir, matching: appName, category: category))
            }
            
        case .applicationSupport:
            if let basePath = category.basePath {
                let supportDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingDirectories(in: supportDir, matching: bundleId, category: category))
                files.append(contentsOf: findMatchingDirectories(in: supportDir, matching: appName, category: category))
            }
            
        case .caches:
            if let basePath = category.basePath {
                let cacheDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingDirectories(in: cacheDir, matching: bundleId, category: category))
                files.append(contentsOf: findMatchingDirectories(in: cacheDir, matching: appName, category: category))
            }
            
        case .containers:
            if let basePath = category.basePath {
                let containerDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingDirectories(in: containerDir, matching: bundleId, category: category))
            }
            
        case .logs:
            if let basePath = category.basePath {
                let logDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: logDir, matching: bundleId, category: category))
                files.append(contentsOf: findMatchingFiles(in: logDir, matching: appName, category: category))
                files.append(contentsOf: findMatchingDirectories(in: logDir, matching: appName, category: category))
            }
            
        case .savedState:
            if let basePath = category.basePath {
                let stateDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingDirectories(in: stateDir, matching: bundleId, category: category))
            }
            
        case .launchAgents:
            if let basePath = category.basePath {
                let agentDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: agentDir, matching: bundleId, category: category))
                files.append(contentsOf: findMatchingFiles(in: agentDir, matching: appName.lowercased(), category: category))
            }
            
        case .cookies:
            if let basePath = category.basePath {
                let cookieDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: cookieDir, matching: bundleId, category: category))
            }
            
        case .crashReports:
            if let basePath = category.basePath {
                let crashDir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: crashDir, matching: appName, category: category))
            }
        }
        
        return files
    }
    
    private func findMatchingFiles(in directory: URL, matching pattern: String, category: AppFileCategory) -> [AppRelatedFile] {
        var files: [AppRelatedFile] = []
        let lowercasePattern = pattern.lowercased()
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return files }
        
        for item in contents {
            let name = item.lastPathComponent.lowercased()
            if name.contains(lowercasePattern) || name.contains(lowercasePattern.replacingOccurrences(of: ".", with: "")) {
                if let size = getFileSize(item) {
                    files.append(AppRelatedFile(
                        path: item,
                        name: item.lastPathComponent,
                        category: category,
                        sizeBytes: size
                    ))
                }
            }
        }
        
        return files
    }
    
    private func findMatchingDirectories(in directory: URL, matching pattern: String, category: AppFileCategory) -> [AppRelatedFile] {
        var files: [AppRelatedFile] = []
        let lowercasePattern = pattern.lowercased()
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return files }
        
        for item in contents {
            let name = item.lastPathComponent.lowercased()
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDir && (name.contains(lowercasePattern) || name.contains(lowercasePattern.components(separatedBy: ".").last ?? "")) {
                if let size = calculateDirectorySize(item) {
                    files.append(AppRelatedFile(
                        path: item,
                        name: item.lastPathComponent,
                        category: category,
                        sizeBytes: size
                    ))
                }
            }
        }
        
        return files
    }
    
    private func findFilesByName(_ appName: String, bundlePath: URL) async -> [AppRelatedFile] {
        var files: [AppRelatedFile] = []
        
        // Add the app bundle itself
        if let size = calculateDirectorySize(bundlePath) {
            files.append(AppRelatedFile(
                path: bundlePath,
                name: bundlePath.lastPathComponent,
                category: .appBundle,
                sizeBytes: size
            ))
        }
        
        // Search other categories by name
        for category in AppFileCategory.allCases where category != .appBundle {
            if let basePath = category.basePath {
                let dir = URL(fileURLWithPath: basePath)
                files.append(contentsOf: findMatchingFiles(in: dir, matching: appName, category: category))
                files.append(contentsOf: findMatchingDirectories(in: dir, matching: appName, category: category))
            }
        }
        
        return files
    }
    
    private func calculateDirectorySize(_ url: URL) -> Int64? {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    private func getFileSize(_ url: URL) -> Int64? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if resourceValues.isDirectory == true {
                return calculateDirectorySize(url)
            }
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return nil
        }
    }
}
