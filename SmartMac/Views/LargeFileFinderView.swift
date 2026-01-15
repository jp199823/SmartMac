import SwiftUI


struct LargeFileFinderView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var fileFinder = LargeFileFinder.shared
    @State private var selectedDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var minimumSizeMB: Double = 100
    @State private var sortOption: FileSortOption = .size
    @State private var selectedFileType: FileType? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var fileToDelete: FileItem? = nil
    @State private var showExportMenu: Bool = false
    @State private var viewMode: FileFinderViewMode = .files
    @State private var previewItem: FileItem? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with actions
                headerSection
                
                // Scan controls
                scanControlsSection
                
                // Storage Overview Section (shows immediately)
                if fileFinder.storageOverviewState.isScanning {
                    storageOverviewProgressSection
                } else if fileFinder.storageOverviewState == .complete || !fileFinder.storageByFolder.isEmpty {
                    storageOverviewSection
                }
                
                // Progress or results for large file scan
                if fileFinder.state.isScanning {
                    progressSection
                } else if fileFinder.state == .complete {
                    // Summary cards
                    summarySection
                    
                    // View mode tabs + Export
                    viewModeSelector
                    
                    // Content based on view mode
                    switch viewMode {
                    case .files:
                        // Interactive treemap
                        treemapSection
                        // File list
                        fileListSection
                    case .duplicates:
                        duplicatesSection
                    }
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            // Automatically scan storage overview on appear
            if fileFinder.storageByFolder.isEmpty && !fileFinder.storageOverviewState.isScanning {
                fileFinder.scanStorageOverview(selectedDirectory)
            }
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                if let file = fileToDelete {
                    try? fileFinder.moveToTrash(file)
                }
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to move \"\(file.name)\" to Trash? This will free up \(file.formattedSize).")
            }
        }
        .sheet(item: $previewItem) { item in
            QuickLookPreview(url: URL(fileURLWithPath: item.path))
                .frame(minWidth: 600, minHeight: 400)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Large File Finder")
                    .font(.timesNewRoman(size: 28, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                Text("Find and manage large files taking up disk space")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            // Export button
            if fileFinder.state == .complete && !fileFinder.files.isEmpty {
                Menu {
                    Button(action: exportCSV) {
                        Label("Export as CSV", systemImage: "tablecells")
                    }
                    Button(action: exportText) {
                        Label("Export as Text", systemImage: "doc.text")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.smartMacSecondaryBg)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Scan Controls Section
    private var scanControlsSection: some View {
        VStack(spacing: 16) {
            // Quick locations
            HStack(spacing: 12) {
                Text("Scan:")
                    .font(.system(size: 13))
                    .foregroundColor(.smartMacTextSecondary)
                
                QuickLocationButton(title: "Home", icon: "house.fill") {
                    selectedDirectory = FileManager.default.homeDirectoryForCurrentUser.path
                    startScan()
                }
                
                QuickLocationButton(title: "Downloads", icon: "arrow.down.circle.fill") {
                    if let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                        selectedDirectory = url.path
                        startScan()
                    }
                }
                
                QuickLocationButton(title: "Documents", icon: "doc.fill") {
                    if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        selectedDirectory = url.path
                        startScan()
                    }
                }
                
                QuickLocationButton(title: "Desktop", icon: "menubar.dock.rectangle") {
                    if let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                        selectedDirectory = url.path
                        startScan()
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Minimum size slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minimum Size: \(Int(minimumSizeMB)) MB")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Slider(value: $minimumSizeMB, in: 10...1000, step: 10)
                        .frame(width: 200)
                        .tint(.smartMacAccentGreen)
                }
                
                Spacer()
                
                // Scan/Cancel button
                if fileFinder.state.isScanning {
                    Button(action: { fileFinder.cancelScan() }) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.smartMacBackground)
                            Text("Cancel")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.smartMacDanger)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: startScan) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Scan")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.smartMacAccentGreen)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Storage Overview Progress Section
    private var storageOverviewProgressSection: some View {
        VStack(spacing: 16) {
            if case .scanning(let progress, let filesScanned) = fileFinder.storageOverviewState {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.smartMacAccentBlue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analyzing Storage...")
                            .font(.timesNewRoman(size: 18, weight: .semibold))
                            .foregroundColor(.smartMacCasaBlanca)
                        
                        Text("Scanning all files to show where your storage is allocated")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    
                    Spacer()
                    
                    Text("\(filesScanned) files")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacAccentBlue)
                }
                
                ProgressView(value: progress)
                    .tint(.smartMacAccentBlue)
            }
        }
        .padding(20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Storage Overview Section
    private var storageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.smartMacAccentBlue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Overview")
                        .font(.timesNewRoman(size: 20, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    Text("\(fileFinder.totalScannedFiles) files • \(fileFinder.totalScannedSize.formattedBytes) total")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    fileFinder.scanStorageOverview(selectedDirectory)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // Storage by File Type
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage by File Type")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacTextPrimary)
                
                let typeData = fileFinder.storageByType
                    .filter { $0.value.size > 0 }
                    .sorted { $0.value.size > $1.value.size }
                
                if !typeData.isEmpty {
                    let maxSize = typeData.first?.value.size ?? 1
                    
                    ForEach(Array(typeData.prefix(8)), id: \.key) { type, data in
                        StorageTypeBar(
                            type: type,
                            size: data.size,
                            count: data.count,
                            percentage: Double(data.size) / Double(fileFinder.totalScannedSize),
                            barPercentage: Double(data.size) / Double(maxSize)
                        )
                    }
                }
            }
            
            Divider()
                .background(Color.smartMacTextTertiary.opacity(0.3))
            
            // Storage by Folder
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage by Folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacTextPrimary)
                
                let folders = fileFinder.storageByFolder.prefix(10)
                
                if !folders.isEmpty {
                    let maxSize = folders.first?.size ?? 1
                    
                    ForEach(Array(folders), id: \.path) { folder in
                        StorageFolderBar(
                            name: folder.name,
                            path: folder.path,
                            size: folder.size,
                            percentage: Double(folder.size) / Double(fileFinder.totalScannedSize),
                            barPercentage: Double(folder.size) / Double(maxSize)
                        )
                    }
                }
            }
            
            // Scan Large Files prompt
            if fileFinder.state != .complete {
                Divider()
                    .background(Color.smartMacTextTertiary.opacity(0.3))
                
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.smartMacWarning)
                    
                    Text("Use the scan controls above to find large files (>\(Int(minimumSizeMB))MB) for detailed analysis")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            if case .scanning(let progress, let filesFound) = fileFinder.state {
                ProgressView(value: progress)
                    .tint(.smartMacAccentGreen)
                
                HStack {
                    Text("Scanning for large files...")
                        .font(.system(size: 14))
                        .foregroundColor(.smartMacTextSecondary)
                    Spacer()
                    Text("\(filesFound) large files found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacAccentGreen)
                }
            }
        }
        .padding(20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        HStack(spacing: 16) {
            SummaryCardWithRing(
                title: "Large Files",
                value: "\(fileFinder.files.count)",
                icon: "doc.fill",
                color: .smartMacAccentGreen,
                progress: min(Double(fileFinder.files.count) / 100.0, 1.0)
            )
            
            SummaryCardWithRing(
                title: "Total Size",
                value: totalLargeFilesSize,
                icon: "internaldrive.fill",
                color: .smartMacNavyBlue,
                progress: 0.7
            )
            
            SummaryCardWithRing(
                title: "Duplicates",
                value: "\(fileFinder.duplicateGroups.count) groups",
                subtitle: fileFinder.potentialSavings > 0 ? "Save \(fileFinder.potentialSavings.formattedBytes)" : nil,
                icon: "doc.on.doc.fill",
                color: .smartMacWarning,
                progress: fileFinder.duplicateScanProgress
            )
            
            SummaryCardWithRing(
                title: "Largest",
                value: fileFinder.files.first?.formattedSize ?? "N/A",
                icon: "arrow.up.circle.fill",
                color: .smartMacDanger,
                progress: 1.0
            )
        }
    }
    
    // MARK: - View Mode Selector
    private var viewModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(FileFinderViewMode.allCases, id: \.self) { mode in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                        if mode == .duplicates && fileFinder.duplicateGroups.isEmpty {
                            fileFinder.findDuplicates()
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewMode == mode ? .smartMacBackground : .smartMacTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewMode == mode ? Color.smartMacAccentGreen : Color.smartMacSecondaryBg)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Treemap Section
    private var treemapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage by Category")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            // Interactive tile treemap
            let typeData = fileFinder.summary.byType
                .filter { $0.value.size > 0 }
                .sorted { $0.value.size > $1.value.size }
            
            if !typeData.isEmpty {
                let totalSize = typeData.reduce(0) { $0 + $1.value.size }
                
                // Treemap tiles
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(typeData, id: \.key) { type, data in
                        TreemapTile(
                            type: type,
                            size: data.size,
                            count: data.count,
                            percentage: Double(data.size) / Double(totalSize),
                            isSelected: selectedFileType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFileType = selectedFileType == type ? nil : type
                            }
                        }
                    }
                }
            } else {
                Text("No data available")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - File List Section
    private var fileListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Large Files")
                    .font(.timesNewRoman(size: 18, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                if let filter = selectedFileType {
                    Button(action: { selectedFileType = nil }) {
                        HStack(spacing: 4) {
                            Text(filter.rawValue)
                            Image(systemName: "xmark.circle.fill")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(filter.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(filter.color.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Sort picker
                Picker("Sort by", selection: $sortOption) {
                    ForEach(FileSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            
            if filteredFiles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.smartMacTextTertiary)
                        Text("No files match the current filter")
                            .font(.system(size: 14))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 1) {
                    ForEach(sortedFiles.prefix(50)) { file in
                        LargeFileRow(file: file) { action in
                            handleFileAction(action, for: file)
                        }
                    }
                }
                .background(Color.smartMacBackground)
                .cornerRadius(8)
                
                if sortedFiles.count > 50 {
                    Text("Showing 50 of \(sortedFiles.count) files")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Duplicates Section
    private var duplicatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Duplicate Files")
                    .font(.timesNewRoman(size: 18, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                if fileFinder.duplicateScanProgress < 1.0 && fileFinder.duplicateScanProgress > 0 {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning...")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                } else if fileFinder.potentialSavings > 0 {
                    Text("Potential savings: \(fileFinder.potentialSavings.formattedBytes)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.smartMacAccentGreen)
                }
            }
            
            if fileFinder.duplicateGroups.isEmpty {
                if fileFinder.duplicateScanProgress >= 1.0 {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.smartMacSuccess)
                            Text("No duplicate files found")
                                .font(.system(size: 14))
                                .foregroundColor(.smartMacTextSecondary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                } else {
                    Button(action: { fileFinder.findDuplicates() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                            Text("Find Duplicates")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.smartMacAccentGreen)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(Array(fileFinder.duplicateGroups.enumerated()), id: \.offset) { index, group in
                    DuplicateGroupCard(
                        groupIndex: index + 1,
                        files: group,
                        onDelete: { file in
                            fileToDelete = file
                            showDeleteConfirmation = true
                        },
                        onReveal: { file in
                            fileFinder.revealInFinder(file)
                        },
                        onPreview: { file in
                            previewItem = file
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var totalLargeFilesSize: String {
        let total = fileFinder.files.reduce(0) { $0 + $1.size }
        return total.formattedBytes
    }
    
    private var filteredFiles: [FileItem] {
        if let filter = selectedFileType {
            return fileFinder.files.filter { $0.fileType == filter }
        }
        return fileFinder.files
    }
    
    private var sortedFiles: [FileItem] {
        switch sortOption {
        case .size:
            return filteredFiles.sorted { $0.size > $1.size }
        case .name:
            return filteredFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date:
            return filteredFiles.sorted { $0.modifiedDate > $1.modifiedDate }
        case .type:
            return filteredFiles.sorted { $0.fileType.rawValue < $1.fileType.rawValue }
        }
    }
    
    // MARK: - Helper Methods
    private func startScan() {
        fileFinder.minimumSize = UInt64(minimumSizeMB) * 1024 * 1024
        fileFinder.scanDirectory(selectedDirectory)
    }
    
    private func handleFileAction(_ action: FileRowAction, for file: FileItem) {
        switch action {
        case .reveal:
            fileFinder.revealInFinder(file)
        case .trash:
            fileToDelete = file
            showDeleteConfirmation = true
        case .open:
            fileFinder.openWith(file)
        case .preview:
            previewItem = file
        }
    }
    
    private func exportCSV() {
        if let url = fileFinder.exportToCSV() {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
    
    private func exportText() {
        if let url = fileFinder.exportToText() {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
}

// MARK: - View Mode Enum
enum FileFinderViewMode: String, CaseIterable {
    case files = "Files"
    case duplicates = "Duplicates"
    
    var icon: String {
        switch self {
        case .files: return "doc.fill"
        case .duplicates: return "doc.on.doc.fill"
        }
    }
}

// MARK: - File Row Action
enum FileRowAction {
    case reveal
    case trash
    case open
    case preview
}

// MARK: - Quick Location Button
struct QuickLocationButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13))
            }
            .foregroundColor(.smartMacTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.smartMacAccentGreen.opacity(0.15) : Color.smartMacBackground)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Summary Card with Ring
struct SummaryCardWithRing: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
                
                // Mini progress ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                        .frame(width: 24, height: 24)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            Text(value)
                .font(.timesNewRoman(size: 22, weight: .bold))
                .foregroundColor(.smartMacCasaBlanca)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
}

// MARK: - Treemap Tile
struct TreemapTile: View {
    let type: FileType
    let size: UInt64
    let count: Int
    let percentage: Double
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .smartMacBackground : type.color)
                
                Text(type.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .smartMacBackground : .smartMacTextPrimary)
                
                Text(size.formattedBytes)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(isSelected ? .smartMacBackground.opacity(0.9) : type.color)
                
                Text("\(count) files")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .smartMacBackground.opacity(0.8) : .smartMacTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100 + CGFloat(percentage) * 40)
            .background(isSelected ? type.color : type.color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHovered && !isSelected ? type.color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Storage Type Bar
struct StorageTypeBar: View {
    let type: FileType
    let size: UInt64
    let count: Int
    let percentage: Double
    let barPercentage: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 14))
                .foregroundColor(type.color)
                .frame(width: 20)
            
            // Name
            Text(type.rawValue)
                .font(.system(size: 13))
                .foregroundColor(.smartMacTextPrimary)
                .frame(width: 80, alignment: .leading)
            
            // Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.smartMacBackground)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(type.color)
                        .frame(width: geometry.size.width * CGFloat(barPercentage), height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            // Size and count
            VStack(alignment: .trailing, spacing: 0) {
                Text(size.formattedBytes)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(.smartMacTextPrimary)
                
                Text("\(count) files • \(Int(percentage * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.smartMacTextSecondary)
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Storage Folder Bar
struct StorageFolderBar: View {
    let name: String
    let path: String
    let size: UInt64
    let percentage: Double
    let barPercentage: Double
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacNavyBlue)
                    .frame(width: 20)
                
                // Name
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(.smartMacTextPrimary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
                
                // Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.smartMacBackground)
                            .frame(height: 8)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.smartMacAccentBlue, .smartMacNavyBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * CGFloat(barPercentage), height: 8)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
                
                // Size
                VStack(alignment: .trailing, spacing: 0) {
                    Text(size.formattedBytes)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(.smartMacTextPrimary)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .frame(width: 80, alignment: .trailing)
                
                // Reveal button
                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.smartMacAccentBlue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Large File Row
struct LargeFileRow: View {
    let file: FileItem
    let onAction: (FileRowAction) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                    .lineLimit(1)
                
                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Type badge
            Text(file.fileType.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(file.fileType.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(file.fileType.color.opacity(0.15))
                .cornerRadius(4)
            
            // Date
            Text(file.formattedDate)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
                .frame(width: 80, alignment: .trailing)
            
            // Size
            Text(file.formattedSize)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(.smartMacCasaBlanca)
                .frame(width: 70, alignment: .trailing)
            
            // Actions
            HStack(spacing: 4) {
                ActionButton(icon: "eye", tooltip: "Quick Look") {
                    onAction(.preview)
                }
                ActionButton(icon: "folder", tooltip: "Reveal in Finder") {
                    onAction(.reveal)
                }
                ActionButton(icon: "trash", tooltip: "Move to Trash", isDestructive: true) {
                    onAction(.trash)
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(12)
        .background(isHovered ? Color.smartMacCardBg : Color.smartMacSecondaryBg)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let tooltip: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isDestructive ? .smartMacDanger : .smartMacTextSecondary)
                .frame(width: 28, height: 28)
                .background(isHovered ? Color.smartMacSecondaryBg : Color.smartMacBackground)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Duplicate Group Card
struct DuplicateGroupCard: View {
    let groupIndex: Int
    let files: [FileItem]
    let onDelete: (FileItem) -> Void
    let onReveal: (FileItem) -> Void
    let onPreview: (FileItem) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() }}) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("Group \(groupIndex)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.smartMacTextPrimary)
                    
                    Text("• \(files.count) copies")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Text("• \(files.first?.formattedSize ?? "0 B") each")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Spacer()
                    
                    let wastedSpace = (files.first?.size ?? 0) * UInt64(files.count - 1)
                    Text("Wasted: \(wastedSpace.formattedBytes)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.smartMacWarning)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(files) { file in
                        HStack(spacing: 12) {
                            Image(nsImage: file.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.smartMacTextPrimary)
                                    .lineLimit(1)
                                Text(file.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.smartMacTextTertiary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Button(action: { onPreview(file) }) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .help("Quick Look")
                                
                                Button(action: { onReveal(file) }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                                
                                Button(action: { onDelete(file) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.smartMacDanger)
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                            }
                            .foregroundColor(.smartMacTextSecondary)
                        }
                        .padding(8)
                        .background(Color.smartMacBackground)
                    }
                }
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.smartMacCardBg)
        .cornerRadius(8)
    }
}

// MARK: - Quick Look Preview
struct QuickLookPreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: NSImage? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(url.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.smartMacSecondaryBg)
            
            Divider()
            
            // Content
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading preview...")
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.smartMacWarning)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    Button("Open in Finder") {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.smartMacAccentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = loadedImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 800, maxHeight: 600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Footer with actions
            Divider()
            HStack {
                Text(url.path)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextTertiary)
                    .lineLimit(1)
                
                Spacer()
                
                Button("Open with Default App") {
                    NSWorkspace.shared.open(url)
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(6)
                
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.smartMacSecondaryBg)
                .cornerRadius(6)
            }
            .padding(12)
            .background(Color.smartMacSecondaryBg)
        }
        .frame(width: 700, height: 550)
        .background(Color.smartMacBackground)
        .onAppear {
            loadPreview()
        }
    }
    
    private func loadPreview() {
        if isImageFile {
            // Load image asynchronously to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.loadedImage = image
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not load image preview"
                        self.isLoading = false
                    }
                }
            }
        } else {
            // For non-image files, show file info and offer to open
            errorMessage = "Preview not available for this file type.\nUse the buttons below to open the file."
            isLoading = false
        }
    }
}

