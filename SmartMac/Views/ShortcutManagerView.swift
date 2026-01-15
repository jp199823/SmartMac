import SwiftUI
import AppKit

struct ShortcutManagerView: View {
    @StateObject private var manager = ShortcutManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: ShortcutFilterOption = .all
    @State private var showAddShortcut = false
    @State private var showExportImport = false
    
    var displayedShortcuts: [KeyboardShortcutItem] {
        var shortcuts = manager.filteredShortcuts(by: selectedFilter)
        if !searchText.isEmpty {
            shortcuts = manager.searchShortcuts(searchText).filter { shortcut in
                if selectedFilter == .all { return true }
                if selectedFilter == .system { return shortcut.source == .system }
                if selectedFilter == .apps { return shortcut.source == .application }
                if selectedFilter == .custom { return shortcut.source == .custom }
                if selectedFilter == .conflicts {
                    let conflictingIds = Set(manager.conflicts.flatMap { $0.shortcuts.map { $0.id } })
                    return conflictingIds.contains(shortcut.id)
                }
                return true
            }
        }
        return shortcuts
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if manager.isScanning {
                    scanningView
                } else if manager.shortcuts.isEmpty {
                    emptyStateView
                } else {
                    statsSection
                    filterBar
                    searchBar
                    
                    if selectedFilter == .conflicts && !manager.conflicts.isEmpty {
                        conflictsSection
                    } else {
                        shortcutCategoriesSection
                    }
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            if manager.shortcuts.isEmpty && !manager.isScanning {
                Task {
                    await manager.scanAllShortcuts()
                }
            }
        }
        .sheet(isPresented: $showAddShortcut) {
            AddShortcutSheet(manager: manager, isPresented: $showAddShortcut)
        }
        .sheet(isPresented: $showExportImport) {
            ExportImportSheet(manager: manager, isPresented: $showExportImport)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                
                Text("View, manage, and create keyboard shortcuts")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextTertiary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Export/Import button
                Button(action: { showExportImport = true }) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 14))
                        .foregroundColor(.smartMacTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Add custom shortcut button
                Button(action: { showAddShortcut = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Shortcut")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.smartMacAccentGreen)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // Rescan button
                Button(action: {
                    Task {
                        await manager.scanAllShortcuts()
                    }
                }) {
                    HStack(spacing: 8) {
                        if manager.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Scan Apps")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.smartMacAccentBlue, .smartMacAccentGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(manager.isScanning)
            }
        }
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .smartMacAccentBlue))
            
            Text("Scanning keyboard shortcuts...")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            ProgressView(value: manager.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .smartMacAccentBlue))
                .frame(width: 300)
            
            Text("\(Int(manager.scanProgress * 100))%")
                .font(.smartMacCaption)
                .foregroundColor(.smartMacTextSecondary)
        }
        .padding(60)
        .background(Color.smartMacCardBg)
        .cornerRadius(20)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.smartMacAccentBlue)
            
            Text("No Shortcuts Found")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            Text("Click Scan Apps to discover keyboard shortcuts")
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextSecondary)
        }
        .padding(60)
        .background(Color.smartMacCardBg)
        .cornerRadius(20)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 16) {
            ShortcutStatCard(
                icon: "keyboard",
                title: "Total Shortcuts",
                value: "\(manager.shortcuts.count)",
                color: .smartMacAccentBlue
            )
            
            ShortcutStatCard(
                icon: "gearshape.fill",
                title: "System",
                value: "\(manager.shortcuts.filter { $0.source == .system }.count)",
                color: .smartMacInfo
            )
            
            ShortcutStatCard(
                icon: "app.fill",
                title: "App Shortcuts",
                value: "\(manager.shortcuts.filter { $0.source == .application }.count)",
                color: .smartMacAccentGreen
            )
            
            ShortcutStatCard(
                icon: "exclamationmark.triangle.fill",
                title: "Conflicts",
                value: "\(manager.conflicts.count)",
                color: manager.conflicts.isEmpty ? .smartMacSuccess : .smartMacDanger
            )
            
            ShortcutStatCard(
                icon: "star.fill",
                title: "Custom",
                value: "\(manager.customShortcuts.count)",
                color: .smartMacWarning
            )
        }
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(ShortcutFilterOption.allCases, id: \.self) { option in
                ShortcutFilterButton(
                    option: option,
                    isSelected: selectedFilter == option,
                    count: countForFilter(option)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = option
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .cornerRadius(12)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.smartMacTextTertiary)
            
            TextField("Search shortcuts by key, action, or app...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.smartMacTextPrimary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.smartMacTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(10)
    }
    
    // MARK: - Conflicts Section
    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.smartMacWarning)
                
                Text("Shortcut Conflicts")
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                
                Spacer()
                
                Text("\(manager.conflicts.count) conflicts found")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            ForEach(manager.conflicts) { conflict in
                ConflictCard(conflict: conflict)
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
    
    // MARK: - Categories Section
    private var shortcutCategoriesSection: some View {
        VStack(spacing: 12) {
            ForEach(manager.categories.filter { category in
                if searchText.isEmpty {
                    switch selectedFilter {
                    case .all: return true
                    case .system: return category.source == .system
                    case .apps: return category.source == .application
                    case .custom: return category.source == .custom
                    case .conflicts: return false
                    }
                } else {
                    return !category.shortcuts.filter { shortcut in
                        shortcut.action.localizedCaseInsensitiveContains(searchText) ||
                        shortcut.displayString.localizedCaseInsensitiveContains(searchText)
                    }.isEmpty
                }
            }) { category in
                ShortcutCategoryCard(
                    category: category,
                    searchText: searchText,
                    onToggle: { manager.toggleCategoryExpansion(category) }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func countForFilter(_ filter: ShortcutFilterOption) -> Int {
        switch filter {
        case .all: return manager.shortcuts.count
        case .system: return manager.shortcuts.filter { $0.source == .system }.count
        case .apps: return manager.shortcuts.filter { $0.source == .application }.count
        case .custom: return manager.shortcuts.filter { $0.source == .custom }.count
        case .conflicts: return manager.conflicts.count
        }
    }
}

// MARK: - Shortcut Stat Card
struct ShortcutStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.smartMacTextPrimary)
            
            Text(title)
                .font(.smartMacCaption)
                .foregroundColor(.smartMacTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.smartMacCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Shortcut Filter Button
struct ShortcutFilterButton: View {
    let option: ShortcutFilterOption
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 12))
                Text(option.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Text("\(count)")
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.smartMacSecondaryBg)
                    .cornerRadius(4)
            }
            .foregroundColor(isSelected ? .white : .smartMacTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? option == .conflicts ? Color.smartMacDanger : Color.smartMacAccentBlue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conflict Card
struct ConflictCard: View {
    let conflict: ShortcutConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Shortcut display
                ShortcutKeyBadge(displayString: conflict.displayString)
                
                Text(conflict.conflictDescription)
                    .font(.smartMacBody)
                    .foregroundColor(.smartMacTextPrimary)
                
                Spacer()
            }
            
            // Conflicting actions
            HStack(spacing: 16) {
                ForEach(conflict.shortcuts, id: \.id) { shortcut in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortcut.appName ?? "System")
                            .font(.smartMacSmall)
                            .foregroundColor(.smartMacTextTertiary)
                        Text(shortcut.action)
                            .font(.smartMacCaption)
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    .padding(8)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(Color.smartMacDanger.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.smartMacDanger.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Shortcut Category Card
struct ShortcutCategoryCard: View {
    let category: ShortcutCategory
    let searchText: String
    let onToggle: () -> Void
    
    var filteredShortcuts: [KeyboardShortcutItem] {
        if searchText.isEmpty {
            return category.shortcuts
        }
        return category.shortcuts.filter { shortcut in
            shortcut.action.localizedCaseInsensitiveContains(searchText) ||
            shortcut.displayString.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Icon
                    if let icon = category.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(category.source.color)
                            .frame(width: 32, height: 32)
                            .background(category.source.color.opacity(0.15))
                            .cornerRadius(8)
                    } else if let bundleId = category.bundleId,
                              let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
                              let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 18))
                            .foregroundColor(category.source.color)
                            .frame(width: 32, height: 32)
                            .background(category.source.color.opacity(0.15))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.smartMacHeadline)
                            .foregroundColor(.smartMacTextPrimary)
                        
                        Text("\(filteredShortcuts.count) shortcuts")
                            .font(.smartMacSmall)
                            .foregroundColor(.smartMacTextTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: category.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Shortcuts list
            if category.isExpanded {
                Divider()
                    .background(Color.smartMacTextTertiary.opacity(0.3))
                
                VStack(spacing: 0) {
                    ForEach(filteredShortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut)
                        
                        if shortcut.id != filteredShortcuts.last?.id {
                            Divider()
                                .background(Color.smartMacTextTertiary.opacity(0.2))
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .background(Color.smartMacCardBg)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: category.isExpanded)
    }
}

// MARK: - Shortcut Row
struct ShortcutRow: View {
    let shortcut: KeyboardShortcutItem
    
    var body: some View {
        HStack(spacing: 16) {
            ShortcutKeyBadge(displayString: shortcut.displayString)
            
            Text(shortcut.action)
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextPrimary)
            
            Spacer()
            
            if !shortcut.isEnabled {
                Text("Disabled")
                    .font(.smartMacSmall)
                    .foregroundColor(.smartMacTextTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Shortcut Key Badge
struct ShortcutKeyBadge: View {
    let displayString: String
    
    var body: some View {
        Text(displayString)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(.smartMacTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.smartMacSecondaryBg)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.smartMacTextTertiary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Add Shortcut Sheet
struct AddShortcutSheet: View {
    @ObservedObject var manager: ShortcutManager
    @Binding var isPresented: Bool
    
    @State private var key = ""
    @State private var action = ""
    @State private var useCommand = true
    @State private var useOption = false
    @State private var useControl = false
    @State private var useShift = false
    @State private var actionType = 0 // 0: None, 1: Open URL, 2: Launch App
    @State private var urlToOpen = ""
    @State private var appToLaunch = ""
    
    var modifiers: ShortcutModifiers {
        var mods: ShortcutModifiers = []
        if useCommand { mods.insert(.command) }
        if useOption { mods.insert(.option) }
        if useControl { mods.insert(.control) }
        if useShift { mods.insert(.shift) }
        return mods
    }
    
    var displayString: String {
        modifiers.displayString + key.uppercased()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Add Custom Shortcut")
                .font(.smartMacTitle)
                .foregroundColor(.smartMacTextPrimary)
            
            // Preview
            if !key.isEmpty {
                ShortcutKeyBadge(displayString: displayString)
                    .scaleEffect(1.5)
            }
            
            // Key input
            VStack(alignment: .leading, spacing: 8) {
                Text("Key")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
                
                TextField("Enter a key (e.g., K, 1, F5)", text: $key)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(8)
            }
            
            // Modifiers
            VStack(alignment: .leading, spacing: 8) {
                Text("Modifiers")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
                
                HStack(spacing: 12) {
                    ModifierToggle(label: "⌘ Cmd", isOn: $useCommand)
                    ModifierToggle(label: "⌥ Opt", isOn: $useOption)
                    ModifierToggle(label: "⌃ Ctrl", isOn: $useControl)
                    ModifierToggle(label: "⇧ Shift", isOn: $useShift)
                }
            }
            
            // Action name
            VStack(alignment: .leading, spacing: 8) {
                Text("Action Name")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
                
                TextField("What does this shortcut do?", text: $action)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(8)
            }
            
            // Action type
            VStack(alignment: .leading, spacing: 8) {
                Text("Action Type (Optional)")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
                
                Picker("", selection: $actionType) {
                    Text("None").tag(0)
                    Text("Open URL").tag(1)
                    Text("Launch App").tag(2)
                }
                .pickerStyle(.segmented)
                
                if actionType == 1 {
                    TextField("URL to open", text: $urlToOpen)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(8)
                } else if actionType == 2 {
                    TextField("App bundle ID", text: $appToLaunch)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 16) {
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(.smartMacTextSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: saveShortcut) {
                    Text("Add Shortcut")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(key.isEmpty || action.isEmpty ? Color.gray : Color.smartMacAccentGreen)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(key.isEmpty || action.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 450, height: 550)
        .background(Color.smartMacCardBg)
    }
    
    private func saveShortcut() {
        let shortcut = CustomShortcut(
            key: key.uppercased(),
            modifiers: modifiers,
            action: action,
            urlToOpen: actionType == 1 ? urlToOpen : nil,
            appToLaunch: actionType == 2 ? appToLaunch : nil
        )
        
        manager.addCustomShortcut(shortcut)
        isPresented = false
    }
}

// MARK: - Modifier Toggle
struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .foregroundColor(isOn ? .white : .smartMacTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Color.smartMacAccentBlue : Color.smartMacSecondaryBg)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export/Import Sheet
struct ExportImportSheet: View {
    @ObservedObject var manager: ShortcutManager
    @Binding var isPresented: Bool
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Export / Import Shortcuts")
                .font(.smartMacTitle)
                .foregroundColor(.smartMacTextPrimary)
            
            VStack(spacing: 16) {
                // Export section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Custom Shortcuts")
                        .font(.smartMacHeadline)
                        .foregroundColor(.smartMacTextPrimary)
                    
                    Text("Save your \(manager.customShortcuts.count) custom shortcuts to a file")
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Button(action: exportShortcuts) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export to File")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.smartMacAccentGreen)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(12)
                
                // Import section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Custom Shortcuts")
                        .font(.smartMacHeadline)
                        .foregroundColor(.smartMacTextPrimary)
                    
                    Text("Load shortcuts from a previously exported file")
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Button(action: importShortcuts) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import from File")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.smartMacAccentBlue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(12)
            }
            
            if showExportSuccess {
                Text("✓ Shortcuts exported successfully!")
                    .font(.smartMacBody)
                    .foregroundColor(.smartMacSuccess)
            }
            
            if showImportSuccess {
                Text("✓ Shortcuts imported successfully!")
                    .font(.smartMacBody)
                    .foregroundColor(.smartMacSuccess)
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .font(.smartMacBody)
                    .foregroundColor(.smartMacDanger)
            }
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Text("Done")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(width: 400, height: 450)
        .background(Color.smartMacCardBg)
    }
    
    private func exportShortcuts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "SmartMac-Shortcuts.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try manager.exportShortcuts(to: url)
                showExportSuccess = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func importShortcuts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try manager.importShortcuts(from: url)
                showImportSuccess = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
