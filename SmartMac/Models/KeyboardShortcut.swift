import Foundation
import SwiftUI
import Carbon

// MARK: - Shortcut Modifiers
/// Bitwise modifier flags for keyboard shortcuts
struct ShortcutModifiers: OptionSet, Hashable, Codable {
    let rawValue: Int
    
    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)
    static let function = ShortcutModifiers(rawValue: 1 << 4)
    
    /// Display string for the modifiers (e.g., "⌘⇧")
    var displayString: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        if contains(.function) { result += "fn" }
        return result
    }
    
    /// Create from NSEvent modifier flags
    static func from(eventModifiers: NSEvent.ModifierFlags) -> ShortcutModifiers {
        var modifiers: ShortcutModifiers = []
        if eventModifiers.contains(.command) { modifiers.insert(.command) }
        if eventModifiers.contains(.option) { modifiers.insert(.option) }
        if eventModifiers.contains(.control) { modifiers.insert(.control) }
        if eventModifiers.contains(.shift) { modifiers.insert(.shift) }
        if eventModifiers.contains(.function) { modifiers.insert(.function) }
        return modifiers
    }
}

// MARK: - Shortcut Source
/// Where a keyboard shortcut originates from
enum ShortcutSource: String, Codable, CaseIterable {
    case system = "System"
    case application = "Application"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .system: return "gearshape.fill"
        case .application: return "app.fill"
        case .custom: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .system: return .smartMacAccentBlue
        case .application: return .smartMacAccentGreen
        case .custom: return .smartMacWarning
        }
    }
}

// MARK: - Keyboard Shortcut Item
/// Represents a single keyboard shortcut
struct KeyboardShortcutItem: Identifiable, Hashable, Codable {
    let id: UUID
    let key: String
    let keyCode: UInt16?
    let modifiers: ShortcutModifiers
    let action: String
    let source: ShortcutSource
    let appName: String?
    let appBundleId: String?
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        key: String,
        keyCode: UInt16? = nil,
        modifiers: ShortcutModifiers,
        action: String,
        source: ShortcutSource,
        appName: String? = nil,
        appBundleId: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.source = source
        self.appName = appName
        self.appBundleId = appBundleId
        self.isEnabled = isEnabled
    }
    
    /// Full display string (e.g., "⌘⇧T")
    var displayString: String {
        modifiers.displayString + key
    }
    
    /// Check if this shortcut conflicts with another
    func conflictsWith(_ other: KeyboardShortcutItem) -> Bool {
        guard id != other.id else { return false }
        return key.lowercased() == other.key.lowercased() && modifiers == other.modifiers
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: KeyboardShortcutItem, rhs: KeyboardShortcutItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Shortcut Conflict
/// Represents a conflict between two or more shortcuts
struct ShortcutConflict: Identifiable {
    let id = UUID()
    let shortcuts: [KeyboardShortcutItem]
    
    var displayString: String {
        shortcuts.first?.displayString ?? ""
    }
    
    var conflictDescription: String {
        let names = shortcuts.compactMap { $0.appName ?? "System" }
        return names.joined(separator: " ↔ ")
    }
    
    var actions: String {
        shortcuts.map { $0.action }.joined(separator: " vs ")
    }
}

// MARK: - Shortcut Category
/// Groups shortcuts by application or system category
struct ShortcutCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String?
    let bundleId: String?
    let source: ShortcutSource
    var shortcuts: [KeyboardShortcutItem]
    var isExpanded: Bool = false
    
    var shortcutCount: Int {
        shortcuts.count
    }
}

// MARK: - Filter Option
enum ShortcutFilterOption: String, CaseIterable {
    case all = "All"
    case system = "System"
    case apps = "Apps"
    case custom = "Custom"
    case conflicts = "Conflicts"
    
    var icon: String {
        switch self {
        case .all: return "keyboard"
        case .system: return "gearshape.fill"
        case .apps: return "app.fill"
        case .custom: return "star.fill"
        case .conflicts: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Common System Shortcuts Database
/// Pre-populated database of common macOS system shortcuts
struct SystemShortcutsDatabase {
    static let shortcuts: [KeyboardShortcutItem] = [
        // General
        KeyboardShortcutItem(key: "Space", modifiers: .command, action: "Spotlight Search", source: .system),
        KeyboardShortcutItem(key: "Tab", modifiers: .command, action: "Switch Applications", source: .system),
        KeyboardShortcutItem(key: "Tab", modifiers: [.command, .shift], action: "Switch Applications (Reverse)", source: .system),
        KeyboardShortcutItem(key: "`", modifiers: .command, action: "Switch Windows", source: .system),
        KeyboardShortcutItem(key: "Q", modifiers: .command, action: "Quit Application", source: .system),
        KeyboardShortcutItem(key: "W", modifiers: .command, action: "Close Window", source: .system),
        KeyboardShortcutItem(key: "H", modifiers: .command, action: "Hide Application", source: .system),
        KeyboardShortcutItem(key: "M", modifiers: .command, action: "Minimize Window", source: .system),
        KeyboardShortcutItem(key: ",", modifiers: .command, action: "Preferences", source: .system),
        
        // Screenshots
        KeyboardShortcutItem(key: "3", modifiers: [.command, .shift], action: "Screenshot (Full Screen)", source: .system),
        KeyboardShortcutItem(key: "4", modifiers: [.command, .shift], action: "Screenshot (Selection)", source: .system),
        KeyboardShortcutItem(key: "5", modifiers: [.command, .shift], action: "Screenshot Options", source: .system),
        
        // Editing
        KeyboardShortcutItem(key: "C", modifiers: .command, action: "Copy", source: .system),
        KeyboardShortcutItem(key: "V", modifiers: .command, action: "Paste", source: .system),
        KeyboardShortcutItem(key: "X", modifiers: .command, action: "Cut", source: .system),
        KeyboardShortcutItem(key: "Z", modifiers: .command, action: "Undo", source: .system),
        KeyboardShortcutItem(key: "Z", modifiers: [.command, .shift], action: "Redo", source: .system),
        KeyboardShortcutItem(key: "A", modifiers: .command, action: "Select All", source: .system),
        KeyboardShortcutItem(key: "F", modifiers: .command, action: "Find", source: .system),
        KeyboardShortcutItem(key: "S", modifiers: .command, action: "Save", source: .system),
        KeyboardShortcutItem(key: "O", modifiers: .command, action: "Open", source: .system),
        KeyboardShortcutItem(key: "N", modifiers: .command, action: "New", source: .system),
        KeyboardShortcutItem(key: "P", modifiers: .command, action: "Print", source: .system),
        
        // Navigation
        KeyboardShortcutItem(key: "←", modifiers: .command, action: "Beginning of Line", source: .system),
        KeyboardShortcutItem(key: "→", modifiers: .command, action: "End of Line", source: .system),
        KeyboardShortcutItem(key: "↑", modifiers: .command, action: "Beginning of Document", source: .system),
        KeyboardShortcutItem(key: "↓", modifiers: .command, action: "End of Document", source: .system),
        
        // System
        KeyboardShortcutItem(key: "Space", modifiers: [.control, .command], action: "Character Viewer", source: .system),
        KeyboardShortcutItem(key: "Delete", modifiers: [.command, .option], action: "Force Quit", source: .system),
        KeyboardShortcutItem(key: "Escape", modifiers: [.command, .option], action: "Force Quit Applications", source: .system),
        KeyboardShortcutItem(key: "F", modifiers: [.control, .command], action: "Toggle Full Screen", source: .system),
        
        // Mission Control
        KeyboardShortcutItem(key: "↑", modifiers: .control, action: "Mission Control", source: .system),
        KeyboardShortcutItem(key: "↓", modifiers: .control, action: "Application Windows", source: .system),
        KeyboardShortcutItem(key: "←", modifiers: .control, action: "Move Space Left", source: .system),
        KeyboardShortcutItem(key: "→", modifiers: .control, action: "Move Space Right", source: .system),
        
        // Finder
        KeyboardShortcutItem(key: "N", modifiers: [.command, .shift], action: "New Folder", source: .system, appName: "Finder", appBundleId: "com.apple.finder"),
        KeyboardShortcutItem(key: "G", modifiers: [.command, .shift], action: "Go to Folder", source: .system, appName: "Finder", appBundleId: "com.apple.finder"),
        KeyboardShortcutItem(key: "I", modifiers: .command, action: "Get Info", source: .system, appName: "Finder", appBundleId: "com.apple.finder"),
        KeyboardShortcutItem(key: "Delete", modifiers: .command, action: "Move to Trash", source: .system, appName: "Finder", appBundleId: "com.apple.finder"),
    ]
}

// MARK: - Common App Shortcuts Database
/// Pre-populated shortcuts for popular applications
struct AppShortcutsDatabase {
    static func shortcuts(for bundleId: String) -> [KeyboardShortcutItem] {
        switch bundleId {
        case "com.google.Chrome":
            return [
                KeyboardShortcutItem(key: "T", modifiers: .command, action: "New Tab", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "T", modifiers: [.command, .shift], action: "Reopen Closed Tab", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "W", modifiers: .command, action: "Close Tab", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "L", modifiers: .command, action: "Focus Address Bar", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "R", modifiers: .command, action: "Reload Page", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "D", modifiers: .command, action: "Bookmark Page", source: .application, appName: "Google Chrome", appBundleId: bundleId),
                KeyboardShortcutItem(key: "J", modifiers: [.command, .option], action: "Open Downloads", source: .application, appName: "Google Chrome", appBundleId: bundleId),
            ]
            
        case "com.apple.Safari":
            return [
                KeyboardShortcutItem(key: "T", modifiers: .command, action: "New Tab", source: .application, appName: "Safari", appBundleId: bundleId),
                KeyboardShortcutItem(key: "T", modifiers: [.command, .shift], action: "Reopen Closed Tab", source: .application, appName: "Safari", appBundleId: bundleId),
                KeyboardShortcutItem(key: "L", modifiers: .command, action: "Focus Address Bar", source: .application, appName: "Safari", appBundleId: bundleId),
                KeyboardShortcutItem(key: "R", modifiers: .command, action: "Reload Page", source: .application, appName: "Safari", appBundleId: bundleId),
                KeyboardShortcutItem(key: "D", modifiers: .command, action: "Add Bookmark", source: .application, appName: "Safari", appBundleId: bundleId),
            ]
            
        case "com.microsoft.VSCode":
            return [
                KeyboardShortcutItem(key: "P", modifiers: [.command, .shift], action: "Command Palette", source: .application, appName: "VS Code", appBundleId: bundleId),
                KeyboardShortcutItem(key: "P", modifiers: .command, action: "Quick Open", source: .application, appName: "VS Code", appBundleId: bundleId),
                KeyboardShortcutItem(key: "B", modifiers: .command, action: "Toggle Sidebar", source: .application, appName: "VS Code", appBundleId: bundleId),
                KeyboardShortcutItem(key: "`", modifiers: .control, action: "Toggle Terminal", source: .application, appName: "VS Code", appBundleId: bundleId),
                KeyboardShortcutItem(key: "/", modifiers: .command, action: "Toggle Comment", source: .application, appName: "VS Code", appBundleId: bundleId),
                KeyboardShortcutItem(key: "D", modifiers: .command, action: "Add Selection", source: .application, appName: "VS Code", appBundleId: bundleId),
            ]
            
        case "com.apple.Terminal":
            return [
                KeyboardShortcutItem(key: "T", modifiers: .command, action: "New Tab", source: .application, appName: "Terminal", appBundleId: bundleId),
                KeyboardShortcutItem(key: "N", modifiers: .command, action: "New Window", source: .application, appName: "Terminal", appBundleId: bundleId),
                KeyboardShortcutItem(key: "K", modifiers: .command, action: "Clear Screen", source: .application, appName: "Terminal", appBundleId: bundleId),
                KeyboardShortcutItem(key: "C", modifiers: .control, action: "Cancel Command", source: .application, appName: "Terminal", appBundleId: bundleId),
            ]
            
        case "com.spotify.client":
            return [
                KeyboardShortcutItem(key: "Space", modifiers: [], action: "Play/Pause", source: .application, appName: "Spotify", appBundleId: bundleId),
                KeyboardShortcutItem(key: "→", modifiers: [.command], action: "Next Track", source: .application, appName: "Spotify", appBundleId: bundleId),
                KeyboardShortcutItem(key: "←", modifiers: [.command], action: "Previous Track", source: .application, appName: "Spotify", appBundleId: bundleId),
                KeyboardShortcutItem(key: "↑", modifiers: [.command], action: "Volume Up", source: .application, appName: "Spotify", appBundleId: bundleId),
                KeyboardShortcutItem(key: "↓", modifiers: [.command], action: "Volume Down", source: .application, appName: "Spotify", appBundleId: bundleId),
            ]
            
        case "com.tinyspeck.slackmacgap":
            return [
                KeyboardShortcutItem(key: "K", modifiers: .command, action: "Quick Switcher", source: .application, appName: "Slack", appBundleId: bundleId),
                KeyboardShortcutItem(key: "N", modifiers: .command, action: "New Message", source: .application, appName: "Slack", appBundleId: bundleId),
                KeyboardShortcutItem(key: "Return", modifiers: [.command, .shift], action: "Send Message", source: .application, appName: "Slack", appBundleId: bundleId),
                KeyboardShortcutItem(key: "U", modifiers: .command, action: "Upload File", source: .application, appName: "Slack", appBundleId: bundleId),
            ]
            
        default:
            return []
        }
    }
    
    static let knownAppBundleIds = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.microsoft.VSCode",
        "com.apple.Terminal",
        "com.spotify.client",
        "com.tinyspeck.slackmacgap"
    ]
}

// MARK: - Custom Shortcut Configuration
/// User-defined custom shortcut
struct CustomShortcut: Codable, Identifiable {
    let id: UUID
    var key: String
    var modifiers: ShortcutModifiers
    var action: String
    var scriptPath: String?
    var urlToOpen: String?
    var appToLaunch: String?
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        key: String,
        modifiers: ShortcutModifiers,
        action: String,
        scriptPath: String? = nil,
        urlToOpen: String? = nil,
        appToLaunch: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.action = action
        self.scriptPath = scriptPath
        self.urlToOpen = urlToOpen
        self.appToLaunch = appToLaunch
        self.isEnabled = isEnabled
    }
    
    var displayString: String {
        modifiers.displayString + key
    }
    
    func toShortcutItem() -> KeyboardShortcutItem {
        KeyboardShortcutItem(
            id: id,
            key: key,
            modifiers: modifiers,
            action: action,
            source: .custom,
            isEnabled: isEnabled
        )
    }
}

// MARK: - Shortcut Export/Import Format
struct ShortcutExport: Codable {
    let version: String
    let exportDate: Date
    let customShortcuts: [CustomShortcut]
}
