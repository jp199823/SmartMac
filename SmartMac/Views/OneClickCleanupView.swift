import SwiftUI

struct OneClickCleanupView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var scanner = CleanupScanner()
    @State private var expandedCategories: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showResultAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Scan Button / Results
                if scanner.scanResult.categories.isEmpty && !scanner.isScanning {
                    emptyStateCard
                } else if scanner.isScanning {
                    scanningCard
                } else {
                    // Summary Card
                    summaryCard
                    
                    // Category List
                    ForEach(scanner.scanResult.categories) { categoryResult in
                        categoryCard(categoryResult)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .confirmationDialog(
            "Delete Selected Items?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(scanner.scanResult.selectedItems) Items", role: .destructive) {
                Task {
                    _ = await scanner.deleteSelectedItems()
                    showResultAlert = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(scanner.scanResult.formattedSelectedSize) of data. This action cannot be undone.")
        }
        .alert("Cleanup Complete", isPresented: $showResultAlert) {
            Button("OK") {}
        } message: {
            if let result = scanner.lastDeleteResult {
                Text("Freed \(result.formattedFreedSize). \(result.deletedCount) items deleted.\(result.hasErrors ? " \(result.failedItems.count) items failed." : "")")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.smartMacAccentGreen)
                
                Text("One-Click Cleanup")
                    .font(.timesNewRoman(size: 28, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
            }
            
            Text("Scan and remove cache files, logs, and old downloads to free up disk space.")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.smartMacTextTertiary)
            
            Text("Ready to Scan")
                .font(.timesNewRoman(size: 20, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            Text("Click the button below to find files that can be safely removed.")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task { await scanner.scanAll() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Start Scan")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.smartMacForestGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Scanning Card
    private var scanningCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Scanning for cleanup candidates...")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Total Found
                VStack(spacing: 4) {
                    Text(scanner.scanResult.formattedTotalSize)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text("Total Found")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Selected
                VStack(spacing: 4) {
                    Text(scanner.scanResult.formattedSelectedSize)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacForestGreen)
                    Text("Selected to Remove")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Spacer()
                
                // Quick Actions
                VStack(spacing: 8) {
                    Button("Select All") {
                        scanner.selectAll(true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smartMacAccentBlue)
                    
                    Button("Deselect All") {
                        scanner.selectAll(false)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smartMacTextTertiary)
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Category Card
    private func categoryCard(_ categoryResult: CleanupCategoryResult) -> some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedCategories.contains(categoryResult.id) {
                        expandedCategories.remove(categoryResult.id)
                    } else {
                        expandedCategories.insert(categoryResult.id)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    // Category Icon
                    Image(systemName: categoryResult.category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.smartMacAccentGreen)
                        .frame(width: 32, height: 32)
                        .background(Color.smartMacAccentGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryResult.category.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.smartMacCasaBlanca)
                        
                        Text("\(categoryResult.items.count) items • \(categoryResult.formattedTotalSize)")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Category Toggle
                    let allSelected = categoryResult.items.allSatisfy { $0.isSelected }
                    Button(action: {
                        scanner.toggleCategory(categoryResult.category, selected: !allSelected)
                    }) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(allSelected ? .smartMacForestGreen : .smartMacTextTertiary)
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: expandedCategories.contains(categoryResult.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.smartMacTextTertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Expanded Items
            if expandedCategories.contains(categoryResult.id) {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    ForEach(categoryResult.items) { item in
                        itemRow(item)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Item Row
    private func itemRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                scanner.toggleItem(item)
            }) {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? .smartMacForestGreen : .smartMacTextTertiary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundColor(.smartMacCasaBlanca)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(item.path.path)
                    .font(.system(size: 10))
                    .foregroundColor(.smartMacTextTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(item.formattedDate)
                .font(.system(size: 11))
                .foregroundColor(.smartMacTextTertiary)
            
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.smartMacTextSecondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task { await scanner.scanAll() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Rescan")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.smartMacCasaBlanca)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.smartMacSecondaryBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clean Selected (\(scanner.scanResult.formattedSelectedSize))")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(scanner.scanResult.selectedItems > 0 ? Color.smartMacDanger : Color.smartMacTextTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(scanner.scanResult.selectedItems == 0 || scanner.isDeleting)
        }
        .padding(.top, 8)
    }
}
