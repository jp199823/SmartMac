import Foundation
import AppKit
import Carbon

/// Service for discovering and managing keyboard shortcuts
@MainActor
class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var shortcuts: [KeyboardShortcutItem] = []
    @Published var categories: [ShortcutCategory] = []
    @Published var conflicts: [ShortcutConflict] = []
    @Published var customShortcuts: [CustomShortcut] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    
    private let fileManager = FileManager.default
    private let userDefaultsKey = "SmartMac.CustomShortcuts"
    
    init() {
        loadCustomShortcuts()
    }
    
    // MARK: - Public Methods
    
    /// Scan for all keyboard shortcuts
    func scanAllShortcuts() async {
        isScanning = true
        scanProgress = 0
        shortcuts = []
        categories = []
        
        defer { 
            isScanning = false 
            scanProgress = 1.0
        }
        
        var allShortcuts: [KeyboardShortcutItem] = []
        
        // 1. Load system shortcuts (30%)
        scanProgress = 0.1
        allShortcuts.append(contentsOf: SystemShortcutsDatabase.shortcuts)
        scanProgress = 0.3
        
        // 2. Scan running applications (60%)
        let runningApps = NSWorkspace.shared.runningApplications.filter { 
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil 
        }
        
        for (index, app) in runningApps.enumerated() {
            if let bundleId = app.bundleIdentifier {
                let appShortcuts = AppShortcutsDatabase.shortcuts(for: bundleId)
                allShortcuts.append(contentsOf: appShortcuts)
                
                // Try to get additional shortcuts from the app's menus
                if let additionalShortcuts = await scanAppMenus(app) {
                    allShortcuts.append(contentsOf: additionalShortcuts)
                }
            }
            scanProgress = 0.3 + (0.5 * Double(index + 1) / Double(runningApps.count))
        }
        
        // 3. Load custom shortcuts (10%)
        scanProgress = 0.9
        let customItems = customShortcuts.map { $0.toShortcutItem() }
        allShortcuts.append(contentsOf: customItems)
        
        // Remove duplicates
        var seen = Set<String>()
        allShortcuts = allShortcuts.filter { shortcut in
            let key = "\(shortcut.displayString)-\(shortcut.action)-\(shortcut.appBundleId ?? "system")"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
        
        shortcuts = allShortcuts
        
        // Build categories
        buildCategories()
        
        // Detect conflicts
        detectConflicts()
        
        scanProgress = 1.0
    }
    
    /// Scan system shortcuts from preferences
    func scanSystemShortcuts() async -> [KeyboardShortcutItem] {
        var shortcuts: [KeyboardShortcutItem] = []
        
        // Read from symbolic hotkeys plist
        let prefsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")
        
        if let plistData = try? Data(contentsOf: prefsPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let hotkeys = plist["AppleSymbolicHotKeys"] as? [String: Any] {
            
            for (key, value) in hotkeys {
                if let hotkeyDict = value as? [String: Any],
                   let enabled = hotkeyDict["enabled"] as? Bool,
                   enabled,
                   let valueDict = hotkeyDict["value"] as? [String: Any],
                   let parameters = valueDict["parameters"] as? [Any],
                   parameters.count >= 3 {
                    
                    // Extract key code and modifiers
                    if let keyCode = parameters[1] as? Int,
                       let modifierFlags = parameters[2] as? Int {
                        
                        let keyString = keyCodeToString(UInt16(keyCode))
                        let modifiers = carbonModifiersToShortcutModifiers(UInt32(modifierFlags))
                        
                        let shortcut = KeyboardShortcutItem(
                            key: keyString,
                            keyCode: UInt16(keyCode),
                            modifiers: modifiers,
                            action: symbolicHotkeyName(for: key),
                            source: .system
                        )
                        shortcuts.append(shortcut)
                    }
                }
            }
        }
        
        return shortcuts
    }
    
    /// Scan app menus for shortcuts (requires Accessibility permissions)
    func scanAppMenus(_ app: NSRunningApplication) async -> [KeyboardShortcutItem]? {
        // This would require Accessibility API access
        // For now, return from the database if available
        guard let bundleId = app.bundleIdentifier else { return nil }
        
        var shortcuts = AppShortcutsDatabase.shortcuts(for: bundleId)
        
        // If we have no pre-defined shortcuts, try to get app name at least
        if shortcuts.isEmpty && AppShortcutsDatabase.knownAppBundleIds.contains(bundleId) == false {
            // Could potentially use AXUIElement here with proper permissions
            // For demonstration, we'll return common shortcuts
            shortcuts = createGenericAppShortcuts(for: app)
        }
        
        return shortcuts.isEmpty ? nil : shortcuts
    }
    
    /// Detect conflicts between shortcuts
    func detectConflicts() {
        var conflictMap: [String: [KeyboardShortcutItem]] = [:]
        
        for shortcut in shortcuts {
            let key = "\(shortcut.modifiers.rawValue)-\(shortcut.key.lowercased())"
            if conflictMap[key] == nil {
                conflictMap[key] = []
            }
            conflictMap[key]?.append(shortcut)
        }
        
        conflicts = conflictMap.values
            .filter { $0.count > 1 }
            .map { ShortcutConflict(shortcuts: $0) }
    }
    
    /// Add a custom shortcut
    func addCustomShortcut(_ shortcut: CustomShortcut) {
        customShortcuts.append(shortcut)
        saveCustomShortcuts()
        
        // Refresh shortcuts list
        let item = shortcut.toShortcutItem()
        shortcuts.append(item)
        buildCategories()
        detectConflicts()
    }
    
    /// Remove a custom shortcut
    func removeCustomShortcut(_ shortcut: CustomShortcut) {
        customShortcuts.removeAll { $0.id == shortcut.id }
        saveCustomShortcuts()
        
        shortcuts.removeAll { $0.id == shortcut.id }
        buildCategories()
        detectConflicts()
    }
    
    /// Update a custom shortcut
    func updateCustomShortcut(_ shortcut: CustomShortcut) {
        if let index = customShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            customShortcuts[index] = shortcut
            saveCustomShortcuts()
            
            if let shortcutIndex = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                shortcuts[shortcutIndex] = shortcut.toShortcutItem()
            }
            buildCategories()
            detectConflicts()
        }
    }
    
    /// Toggle category expansion
    func toggleCategoryExpansion(_ category: ShortcutCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index].isExpanded.toggle()
        }
    }
    
    /// Export shortcuts to file
    func exportShortcuts(to url: URL) throws {
        let export = ShortcutExport(
            version: "1.0",
            exportDate: Date(),
            customShortcuts: customShortcuts
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(export)
        try data.write(to: url)
    }
    
    /// Import shortcuts from file
    func importShortcuts(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let imported = try decoder.decode(ShortcutExport.self, from: data)
        
        // Merge with existing custom shortcuts
        for shortcut in imported.customShortcuts {
            if !customShortcuts.contains(where: { $0.id == shortcut.id }) {
                customShortcuts.append(shortcut)
            }
        }
        
        saveCustomShortcuts()
        
        // Refresh
        Task {
            await scanAllShortcuts()
        }
    }
    
    /// Get shortcuts filtered by option
    func filteredShortcuts(by filter: ShortcutFilterOption) -> [KeyboardShortcutItem] {
        switch filter {
        case .all:
            return shortcuts
        case .system:
            return shortcuts.filter { $0.source == .system }
        case .apps:
            return shortcuts.filter { $0.source == .application }
        case .custom:
            return shortcuts.filter { $0.source == .custom }
        case .conflicts:
            let conflictingIds = Set(conflicts.flatMap { $0.shortcuts.map { $0.id } })
            return shortcuts.filter { conflictingIds.contains($0.id) }
        }
    }
    
    /// Search shortcuts
    func searchShortcuts(_ query: String) -> [KeyboardShortcutItem] {
        guard !query.isEmpty else { return shortcuts }
        
        let lowercaseQuery = query.lowercased()
        return shortcuts.filter { shortcut in
            shortcut.action.lowercased().contains(lowercaseQuery) ||
            shortcut.displayString.lowercased().contains(lowercaseQuery) ||
            (shortcut.appName?.lowercased().contains(lowercaseQuery) ?? false) ||
            shortcut.key.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Private Methods
    
    private func buildCategories() {
        var categoryMap: [String: ShortcutCategory] = [:]
        
        // System category
        let systemShortcuts = shortcuts.filter { $0.source == .system && $0.appBundleId == nil }
        if !systemShortcuts.isEmpty {
            categoryMap["system"] = ShortcutCategory(
                name: "System Shortcuts",
                icon: "gearshape.fill",
                bundleId: nil,
                source: .system,
                shortcuts: systemShortcuts
            )
        }
        
        // App categories
        let appShortcuts = shortcuts.filter { $0.source == .application || ($0.source == .system && $0.appBundleId != nil) }
        let groupedByApp = Dictionary(grouping: appShortcuts, by: { $0.appBundleId ?? "unknown" })
        
        for (bundleId, shortcuts) in groupedByApp {
            let appName = shortcuts.first?.appName ?? bundleId
            categoryMap[bundleId] = ShortcutCategory(
                name: appName,
                icon: nil,
                bundleId: bundleId,
                source: .application,
                shortcuts: shortcuts
            )
        }
        
        // Custom category
        let customShortcuts = shortcuts.filter { $0.source == .custom }
        if !customShortcuts.isEmpty {
            categoryMap["custom"] = ShortcutCategory(
                name: "Custom Shortcuts",
                icon: "star.fill",
                bundleId: nil,
                source: .custom,
                shortcuts: customShortcuts
            )
        }
        
        // Sort categories: System first, then apps alphabetically, then custom
        categories = categoryMap.values.sorted { cat1, cat2 in
            if cat1.source == .system && cat2.source != .system { return true }
            if cat1.source != .system && cat2.source == .system { return false }
            if cat1.source == .custom && cat2.source != .custom { return false }
            if cat1.source != .custom && cat2.source == .custom { return true }
            return cat1.name.localizedCaseInsensitiveCompare(cat2.name) == .orderedAscending
        }
    }
    
    private func createGenericAppShortcuts(for app: NSRunningApplication) -> [KeyboardShortcutItem] {
        guard let name = app.localizedName, let bundleId = app.bundleIdentifier else { return [] }
        
        // Common shortcuts most apps have
        return [
            KeyboardShortcutItem(key: "N", modifiers: .command, action: "New", source: .application, appName: name, appBundleId: bundleId),
            KeyboardShortcutItem(key: "O", modifiers: .command, action: "Open", source: .application, appName: name, appBundleId: bundleId),
            KeyboardShortcutItem(key: "S", modifiers: .command, action: "Save", source: .application, appName: name, appBundleId: bundleId),
            KeyboardShortcutItem(key: "W", modifiers: .command, action: "Close", source: .application, appName: name, appBundleId: bundleId),
            KeyboardShortcutItem(key: ",", modifiers: .command, action: "Preferences", source: .application, appName: name, appBundleId: bundleId),
        ]
    }
    
    private func saveCustomShortcuts() {
        if let encoded = try? JSONEncoder().encode(customShortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadCustomShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CustomShortcut].self, from: data) {
            customShortcuts = decoded
        }
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // Common key codes to string mapping
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            53: "Escape", 55: "Command", 56: "Shift", 57: "CapsLock", 58: "Option",
            59: "Control", 60: "RShift", 61: "ROption", 62: "RControl", 63: "Function",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4",
            119: "F2", 120: "F1", 122: "Home", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
    
    private func carbonModifiersToShortcutModifiers(_ carbonFlags: UInt32) -> ShortcutModifiers {
        var modifiers: ShortcutModifiers = []
        
        if carbonFlags & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        if carbonFlags & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if carbonFlags & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if carbonFlags & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        
        return modifiers
    }
    
    private func symbolicHotkeyName(for key: String) -> String {
        // Map symbolic hotkey IDs to human-readable names
        let hotkeyNames: [String: String] = [
            "27": "Move Focus to Dock",
            "28": "Move Focus to Menu Bar",
            "29": "Move Focus to Window Toolbar",
            "30": "Move Focus to Floating Window",
            "32": "Mission Control",
            "33": "Application Windows",
            "34": "Show Desktop",
            "35": "Move Left a Space",
            "36": "Move Right a Space",
            "60": "Select Previous Input Source",
            "61": "Select Next Input Source",
            "64": "Spotlight",
            "65": "Finder Search Window",
            "118": "Quick Note",
        ]
        
        return hotkeyNames[key] ?? "System Shortcut \(key)"
    }
}
