import SwiftUI

struct AppUninstallerView: View {
    @StateObject private var uninstaller = AppUninstaller.shared
    @State private var searchText = ""
    @State private var sortOption: AppSortOption = .size
    @State private var filterOption: AppFilterOption = .all
    @State private var showConfirmation = false
    @State private var showBatchConfirmation = false
    @State private var appToUninstall: InstalledApp?
    @State private var permanentDelete = false
    @State private var showResult = false
    
    var filteredApps: [InstalledApp] {
        var apps = uninstaller.installedApps
        
        // Apply search filter
        if !searchText.isEmpty {
            apps = apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                (app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply category filter
        switch filterOption {
        case .all:
            break
        case .recentlyInstalled:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            apps = apps.filter { ($0.installDate ?? Date.distantPast) > thirtyDaysAgo }
        case .largeApps:
            apps = apps.filter { $0.totalSizeBytes > 500_000_000 } // > 500MB
        case .unused:
            // Simplified: apps not opened in 90 days would require additional tracking
            // For now, show apps older than 90 days
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            apps = apps.filter { ($0.installDate ?? Date.distantPast) < ninetyDaysAgo }
        }
        
        // Apply sort
        switch sortOption {
        case .name:
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            apps.sort { $0.totalSizeBytes > $1.totalSizeBytes }
        case .installDate:
            apps.sort { ($0.installDate ?? Date.distantPast) > ($1.installDate ?? Date.distantPast) }
        }
        
        return apps
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if uninstaller.isScanning {
                    scanningView
                } else if uninstaller.installedApps.isEmpty {
                    emptyStateView
                } else {
                    statsSection
                    filterBar
                    appListSection
                    
                    if !uninstaller.selectedApps.isEmpty {
                        actionBar
                    }
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            if uninstaller.installedApps.isEmpty && !uninstaller.isScanning {
                Task {
                    await uninstaller.scanInstalledApps()
                }
            }
        }
        .alert("Uninstall App", isPresented: $showConfirmation) {
            Button("Move to Trash", role: .destructive) {
                if let app = appToUninstall {
                    Task {
                        _ = await uninstaller.uninstallApp(app, permanently: false)
                        showResult = true
                    }
                }
            }
            Button("Delete Permanently", role: .destructive) {
                if let app = appToUninstall {
                    Task {
                        _ = await uninstaller.uninstallApp(app, permanently: true)
                        showResult = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let app = appToUninstall {
                Text("This will remove \(app.name) and all associated files (\(app.formattedSelectedSize)).")
            }
        }
        .alert("Batch Uninstall", isPresented: $showBatchConfirmation) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    _ = await uninstaller.batchUninstall(uninstaller.selectedApps, permanently: false)
                    showResult = true
                }
            }
            Button("Delete Permanently", role: .destructive) {
                Task {
                    _ = await uninstaller.batchUninstall(uninstaller.selectedApps, permanently: true)
                    showResult = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove \(uninstaller.selectedApps.count) apps and free up \(uninstaller.formattedTotalSelectedSize).")
        }
        .sheet(isPresented: $showResult) {
            resultSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Uninstaller")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                
                Text("Completely remove apps and all associated files")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextTertiary)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await uninstaller.scanInstalledApps()
                }
            }) {
                HStack(spacing: 8) {
                    if uninstaller.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Rescan")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.smartMacAccentGreen, .smartMacAccentBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(uninstaller.isScanning)
        }
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .smartMacAccentGreen))
            
            Text("Scanning installed applications...")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            ProgressView(value: uninstaller.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .smartMacAccentGreen))
                .frame(width: 300)
            
            Text("\(Int(uninstaller.scanProgress * 100))%")
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
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.smartMacAccentGreen)
            
            Text("No Applications Found")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            Text("Click Rescan to search for installed applications")
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
            UninstallerStatCard(
                icon: "app.fill",
                title: "Total Apps",
                value: "\(uninstaller.installedApps.count)",
                color: .smartMacAccentBlue
            )
            
            UninstallerStatCard(
                icon: "externaldrive.fill",
                title: "Total Size",
                value: ByteCountFormatter.string(
                    fromByteCount: uninstaller.installedApps.reduce(0) { $0 + $1.totalSizeBytes },
                    countStyle: .file
                ),
                color: .smartMacAccentGreen
            )
            
            UninstallerStatCard(
                icon: "checkmark.circle.fill",
                title: "Selected",
                value: "\(uninstaller.selectedApps.count) apps",
                color: .smartMacWarning
            )
            
            UninstallerStatCard(
                icon: "trash.fill",
                title: "To Free",
                value: uninstaller.formattedTotalSelectedSize,
                color: .smartMacDanger
            )
        }
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.smartMacTextTertiary)
                TextField("Search apps...", text: $searchText)
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
            .padding(10)
            .background(Color.smartMacSecondaryBg)
            .cornerRadius(10)
            .frame(maxWidth: 300)
            
            Spacer()
            
            // Filter picker
            Menu {
                ForEach(AppFilterOption.allCases, id: \.self) { option in
                    Button(action: { filterOption = option }) {
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.rawValue)
                            if filterOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filterOption.icon)
                    Text(filterOption.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(8)
            }
            
            // Sort picker
            Menu {
                ForEach(AppSortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort: \(sortOption.rawValue)")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .cornerRadius(12)
    }
    
    // MARK: - App List Section
    private var appListSection: some View {
        VStack(spacing: 8) {
            ForEach(filteredApps) { app in
                AppRow(
                    app: app,
                    onSelect: { uninstaller.toggleAppSelection(app) },
                    onExpand: { uninstaller.toggleAppExpansion(app) },
                    onUninstall: {
                        appToUninstall = app
                        showConfirmation = true
                    },
                    onToggleFile: { file in
                        uninstaller.toggleFileSelection(in: app, file: file)
                    }
                )
            }
        }
    }
    
    // MARK: - Action Bar
    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(uninstaller.selectedApps.count) apps selected")
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                
                Text("Total: \(uninstaller.formattedTotalSelectedSize)")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            Button(action: {
                for app in uninstaller.selectedApps {
                    uninstaller.toggleAppSelection(app)
                }
            }) {
                Text("Clear Selection")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Button(action: { showBatchConfirmation = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Uninstall Selected")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.smartMacDanger)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
    
    // MARK: - Result Sheet
    private var resultSheet: some View {
        VStack(spacing: 24) {
            if let result = uninstaller.lastUninstallResult {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(result.isSuccess ? .smartMacSuccess : .smartMacWarning)
                
                Text(result.isSuccess ? "Uninstall Complete" : "Uninstall Completed with Errors")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                
                VStack(spacing: 8) {
                    Text("\(result.appName)")
                        .font(.smartMacHeadline)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("\(result.deletedFiles) files removed")
                        .font(.smartMacBody)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("\(result.formattedFreedSize) freed")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.smartMacAccentGreen)
                    
                    if result.movedToTrash {
                        Text("Files moved to Trash (recoverable)")
                            .font(.smartMacCaption)
                            .foregroundColor(.smartMacTextTertiary)
                    }
                }
                
                if result.hasErrors {
                    Text("\(result.failedFiles.count) files could not be removed")
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacDanger)
                }
            } else if let batchResult = uninstaller.lastBatchResult {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.smartMacSuccess)
                
                Text("Batch Uninstall Complete")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                
                VStack(spacing: 8) {
                    Text("\(batchResult.successCount) apps removed")
                        .font(.smartMacHeadline)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("\(batchResult.totalDeletedFiles) files removed")
                        .font(.smartMacBody)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("\(batchResult.formattedTotalFreed) freed")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.smartMacAccentGreen)
                }
            }
            
            Button(action: { showResult = false }) {
                Text("Done")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.smartMacAccentGreen)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 400)
        .background(Color.smartMacCardBg)
    }
}

// MARK: - Uninstaller Stat Card
struct UninstallerStatCard: View {
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

// MARK: - App Row
struct AppRow: View {
    let app: InstalledApp
    let onSelect: () -> Void
    let onExpand: () -> Void
    let onUninstall: () -> Void
    let onToggleFile: (AppRelatedFile) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Selection checkbox
                Button(action: onSelect) {
                    Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(app.isSelected ? .smartMacAccentGreen : .smartMacTextTertiary)
                }
                .buttonStyle(.plain)
                
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.smartMacSecondaryBg)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundColor(.smartMacTextTertiary)
                        )
                }
                
                // App info
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.smartMacHeadline)
                        .foregroundColor(.smartMacTextPrimary)
                    
                    HStack(spacing: 8) {
                        if let version = app.version {
                            Text("v\(version)")
                                .font(.smartMacSmall)
                                .foregroundColor(.smartMacTextTertiary)
                        }
                        
                        Text("\(app.categoryCount) locations")
                            .font(.smartMacSmall)
                            .foregroundColor(.smartMacTextTertiary)
                    }
                }
                
                Spacer()
                
                // Size
                VStack(alignment: .trailing, spacing: 4) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.smartMacTextPrimary)
                    
                    Text("\(app.relatedFiles.count) files")
                        .font(.smartMacSmall)
                        .foregroundColor(.smartMacTextTertiary)
                }
                
                // Expand button
                Button(action: onExpand) {
                    Image(systemName: app.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Quick uninstall button
                Button(action: onUninstall) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.smartMacDanger)
                        .frame(width: 32, height: 32)
                        .background(Color.smartMacDanger.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: app.isExpanded ? 0 : 12)
                    .fill(isHovered ? Color.smartMacSecondaryBg : Color.smartMacCardBg)
            )
            .onHover { isHovered = $0 }
            
            // Expanded file list
            if app.isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.smartMacTextTertiary.opacity(0.3))
                    
                    ForEach(AppFileCategory.allCases, id: \.self) { category in
                        if let files = app.filesByCategory[category], !files.isEmpty {
                            FileCategoryRow(
                                category: category,
                                files: files,
                                totalSize: app.formattedSizeForCategory(category),
                                onToggleFile: onToggleFile
                            )
                        }
                    }
                }
                .background(Color.smartMacCardBg)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: app.isExpanded)
    }
}

// MARK: - File Category Row
struct FileCategoryRow: View {
    let category: AppFileCategory
    let files: [AppRelatedFile]
    let totalSize: String
    let onToggleFile: (AppRelatedFile) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(category.color)
                        .frame(width: 24)
                    
                    Text(category.rawValue)
                        .font(.smartMacBody)
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Spacer()
                    
                    Text(totalSize)
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacTextTertiary)
                    
                    Text("\(files.count)")
                        .font(.smartMacSmall)
                        .foregroundColor(.smartMacTextTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(4)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.smartMacTextTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            // Individual files
            if isExpanded {
                ForEach(files) { file in
                    HStack(spacing: 12) {
                        Button(action: { onToggleFile(file) }) {
                            Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                                .foregroundColor(file.isSelected ? .smartMacAccentGreen : .smartMacTextTertiary)
                        }
                        .buttonStyle(.plain)
                        
                        Text(file.name)
                            .font(.smartMacSmall)
                            .foregroundColor(.smartMacTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Text(file.formattedSize)
                            .font(.smartMacSmall)
                            .foregroundColor(.smartMacTextTertiary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 6)
                    .background(Color.smartMacSecondaryBg.opacity(0.3))
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }
}
