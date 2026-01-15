import SwiftUI

struct ClipboardManagerView: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @State private var showClearConfirmation = false
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .background(Color.smartMacTextTertiary.opacity(0.3))
            
            // Search and Filters
            searchAndFilterSection
            
            // Content
            if clipboardManager.filteredItems.isEmpty {
                emptyStateView
            } else {
                clipboardListView
            }
        }
        .background(Color.smartMacBackground)
        .alert("Clear Clipboard History?", isPresented: $showClearConfirmation) {
            Button("Keep Favorites", role: .cancel) {
                clipboardManager.clearAll(keepFavorites: true)
            }
            Button("Clear All", role: .destructive) {
                clipboardManager.clearAll(keepFavorites: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all items from your clipboard history.")
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard Manager")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                Text("\(clipboardManager.items.count) items in history")
                    .font(.smartMacCaption)
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Spacer()
            
            // Clear Button
            Button(action: { showClearConfirmation = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.smartMacDanger)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.smartMacDanger.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(clipboardManager.items.isEmpty)
        }
        .padding(24)
    }
    
    // MARK: - Search and Filters
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.smartMacTextTertiary)
                TextField("Search clipboard...", text: $clipboardManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                
                if !clipboardManager.searchQuery.isEmpty {
                    Button(action: { clipboardManager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.smartMacTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.smartMacCardBg)
            .cornerRadius(10)
            
            // Filter Buttons
            HStack(spacing: 8) {
                ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: clipboardManager.activeFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            clipboardManager.activeFilter = filter
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.smartMacSecondaryBg)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.smartMacTextTertiary)
            Text("No clipboard items")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextSecondary)
            Text("Copy something to see it here")
                .font(.smartMacCaption)
                .foregroundColor(.smartMacTextTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Clipboard List
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(clipboardManager.filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        isHovered: hoveredItemId == item.id,
                        onCopy: { clipboardManager.copyToClipboard(item) },
                        onFavorite: { clipboardManager.toggleFavorite(item) },
                        onDelete: { clipboardManager.deleteItem(item) }
                    )
                    .onHover { isHovered in
                        hoveredItemId = isHovered ? item.id : nil
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let filter: ClipboardFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12))
                Text(filter.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .smartMacTextPrimary : .smartMacTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.smartMacAccentGreen.opacity(0.3) : Color.smartMacCardBg)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clipboard Item Row
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onCopy: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(Color.smartMacAccentGreen.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: item.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.smartMacAccentGreen)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayContent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.smartMacSecondaryBg)
                        .cornerRadius(4)
                    
                    Text(item.formattedTimestamp)
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                }
            }
            
            Spacer()
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 8) {
                    ClipboardActionButton(icon: "doc.on.doc", color: .smartMacAccentBlue, action: onCopy)
                    ClipboardActionButton(
                        icon: item.isFavorite ? "star.fill" : "star",
                        color: .smartMacWarning,
                        action: onFavorite
                    )
                    ClipboardActionButton(icon: "trash", color: .smartMacDanger, action: onDelete)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Favorite indicator (always visible if favorited)
            if item.isFavorite && !isHovered {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacWarning)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.smartMacCardBg.opacity(0.8) : Color.smartMacCardBg)
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Clipboard Action Button
struct ClipboardActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(8)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
