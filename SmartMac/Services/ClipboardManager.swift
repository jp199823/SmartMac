import Foundation
import AppKit
import Combine

/// Clipboard Manager - Monitors pasteboard and maintains history
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    // MARK: - Published Properties
    @Published var items: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var activeFilter: ClipboardFilter = .all
    
    // MARK: - Configuration
    private let maxItems = 100
    private let storageKey = "SmartMac.ClipboardHistory"
    private let favoritesKey = "SmartMac.ClipboardFavorites"
    
    // MARK: - Monitoring
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    // MARK: - Computed Properties
    var filteredItems: [ClipboardItem] {
        var result = items
        
        // Apply type filter
        switch activeFilter {
        case .all:
            break
        case .text:
            result = result.filter { $0.type == .text }
        case .urls:
            result = result.filter { $0.type == .url }
        case .files:
            result = result.filter { $0.type == .filePath }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }
        
        // Apply search
        if !searchQuery.isEmpty {
            result = result.filter { $0.content.localizedCaseInsensitiveContains(searchQuery) }
        }
        
        return result
    }
    
    // MARK: - Initialization
    private init() {
        loadHistory()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // Detect content type and extract
        if let item = extractClipboardItem(from: pasteboard) {
            // Avoid duplicates
            if let existingIndex = items.firstIndex(where: { $0.content == item.content }) {
                // Move existing to top (favorite status is already preserved)
                let existing = items.remove(at: existingIndex)
                items.insert(existing, at: 0)
            } else {
                items.insert(item, at: 0)
                
                // Trim to max items (keep favorites)
                while items.count > maxItems {
                    if let lastNonFavoriteIndex = items.lastIndex(where: { !$0.isFavorite }) {
                        items.remove(at: lastNonFavoriteIndex)
                    } else {
                        break
                    }
                }
            }
            
            saveHistory()
        }
    }
    
    private func extractClipboardItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        // Check for file URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if url.isFileURL {
                return ClipboardItem(content: url.path, type: .filePath)
            } else {
                return ClipboardItem(content: url.absoluteString, type: .url)
            }
        }
        
        // Check for string (could be URL or text)
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Detect if it's a URL
            if let url = URL(string: string), url.scheme != nil, url.host != nil {
                return ClipboardItem(content: string, type: .url)
            }
            
            // Check if it's a file path
            if string.hasPrefix("/") && FileManager.default.fileExists(atPath: string) {
                return ClipboardItem(content: string, type: .filePath)
            }
            
            return ClipboardItem(content: string, type: .text)
        }
        
        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation {
                return ClipboardItem(content: "[Image]", type: .image, imageData: tiffData)
            }
        }
        
        return nil
    }
    
    // MARK: - Actions
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .url:
            if let url = URL(string: item.content) {
                pasteboard.writeObjects([url as NSURL])
            } else {
                pasteboard.setString(item.content, forType: .string)
            }
        case .filePath:
            if let url = URL(string: "file://\(item.content)") {
                pasteboard.writeObjects([url as NSURL])
            }
        default:
            pasteboard.setString(item.content, forType: .string)
        }
        
        // Update change count to avoid re-capturing
        lastChangeCount = pasteboard.changeCount
    }
    
    func toggleFavorite(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            saveHistory()
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearAll(keepFavorites: Bool = true) {
        if keepFavorites {
            items = items.filter { $0.isFavorite }
        } else {
            items.removeAll()
        }
        saveHistory()
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
        }
    }
}
