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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Scan controls
                scanControlsSection
                
                // Progress or results
                if fileFinder.state.isScanning {
                    progressSection
                } else if fileFinder.state == .complete {
                    // Summary
                    summarySection
                    
                    // Treemap visualization
                    treemapSection
                    
                    // File list
                    fileListSection
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
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
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Large File Finder")
                .font(.timesNewRoman(size: 28, weight: .bold))
                .foregroundColor(.smartMacCasaBlanca)
            Text("Find and manage large files taking up disk space")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            if case .scanning(let progress, let filesFound) = fileFinder.state {
                ProgressView(value: progress)
                    .tint(.smartMacAccentGreen)
                
                HStack {
                    Text("Scanning...")
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
            SummaryCard(
                title: "Large Files Found",
                value: "\(fileFinder.files.count)",
                icon: "doc.fill",
                color: .smartMacAccentGreen
            )
            
            SummaryCard(
                title: "Total Size",
                value: totalLargeFilesSize,
                icon: "internaldrive.fill",
                color: .smartMacNavyBlue
            )
            
            SummaryCard(
                title: "Largest File",
                value: fileFinder.files.first?.formattedSize ?? "N/A",
                icon: "arrow.up.circle.fill",
                color: .smartMacDanger
            )
        }
    }
    
    // MARK: - Treemap Section
    private var treemapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage by Category")
                .font(.timesNewRoman(size: 18, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            // Horizontal bar chart by file type
            let typeData = fileFinder.summary.byType
                .filter { $0.value.size > 0 }
                .sorted { $0.value.size > $1.value.size }
            
            if !typeData.isEmpty {
                let maxSize = typeData.first?.value.size ?? 1
                
                VStack(spacing: 8) {
                    ForEach(typeData, id: \.key) { type, data in
                        FileTypeBar(
                            type: type,
                            size: data.size,
                            count: data.count,
                            percentage: Double(data.size) / Double(maxSize),
                            isSelected: selectedFileType == type
                        ) {
                            if selectedFileType == type {
                                selectedFileType = nil
                            } else {
                                selectedFileType = type
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
        }
    }
}

// MARK: - File Row Action
enum FileRowAction {
    case reveal
    case trash
    case open
}

// MARK: - Quick Location Button
struct QuickLocationButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
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
            .background(Color.smartMacBackground)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.timesNewRoman(size: 24, weight: .bold))
                .foregroundColor(.smartMacCasaBlanca)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
}

// MARK: - File Type Bar
struct FileTypeBar: View {
    let type: FileType
    let size: UInt64
    let count: Int
    let percentage: Double
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(type.color)
                    .frame(width: 20)
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                    .frame(width: 80, alignment: .leading)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.smartMacBackground)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(type.color.opacity(isSelected ? 1 : 0.7))
                            .frame(width: geometry.size.width * CGFloat(percentage), height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(size.formattedBytes)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(.smartMacTextPrimary)
                    .frame(width: 70, alignment: .trailing)
                
                Text("\(count) files")
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? type.color.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
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
                ActionButton(icon: "eye", tooltip: "Reveal in Finder") {
                    onAction(.reveal)
                }
                ActionButton(icon: "trash", tooltip: "Move to Trash", isDestructive: true) {
                    onAction(.trash)
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(12)
        .background(Color.smartMacSecondaryBg)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let tooltip: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isDestructive ? .smartMacDanger : .smartMacTextSecondary)
                .frame(width: 28, height: 28)
                .background(Color.smartMacBackground)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
