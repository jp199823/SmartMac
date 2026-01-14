import SwiftUI

/// Suggestions view with contextual optimization tips
struct SuggestionsView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var relevantSuggestions: [Suggestion] = []
    @State private var showAllTips = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Priority suggestions based on current state
                if !relevantSuggestions.isEmpty {
                    prioritySuggestionsSection
                }
                
                // General tips section
                generalTipsSection
            }
            .padding(32)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            refreshSuggestions()
        }
        .onChange(of: monitor.lastUpdated) { _, _ in
            refreshSuggestions()
        }
    }
    
    private func refreshSuggestions() {
        relevantSuggestions = SuggestionsBank.getRelevantSuggestions(for: monitor, limit: 5)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Suggestions")
                .font(.smartMacTitle)
                .foregroundColor(.smartMacCasaBlanca)
            
            Text("Personalized tips to optimize your Mac's performance")
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Priority Suggestions
    private var prioritySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.smartMacWarning)
                Text("Based on your current system state")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
            }
            
            ForEach(relevantSuggestions) { suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
    }
    
    // MARK: - General Tips
    private var generalTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.smartMacAccentGreen)
                Text("General Optimization Tips")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Button(action: { showAllTips.toggle() }) {
                    Text(showAllTips ? "Show Less" : "Show All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            let tips = generalTips
            let displayedTips = showAllTips ? tips : Array(tips.prefix(4))
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(displayedTips, id: \.title) { tip in
                    GeneralTipCard(tip: tip)
                }
            }
        }
    }
    
    private var generalTips: [(title: String, description: String, icon: String, category: SuggestionCategory)] {
        [
            ("Empty Trash Regularly", "Files in Trash still use disk space. Empty it periodically to free storage.", "trash", .storage),
            ("Manage Startup Items", "Reduce login items for faster boot times. Check System Settings > General > Login Items.", "person.badge.key", .maintenance),
            ("Update macOS", "Keep your system updated for best performance and security.", "arrow.down.circle", .maintenance),
            ("Use Activity Monitor", "Identify resource-heavy apps with Activity Monitor.", "chart.bar.xaxis", .performance),
            ("Clear Browser Data", "Clear browser cache and history for better browsing speed.", "safari", .maintenance),
            ("Optimize Storage", "Enable iCloud storage optimization to automatically manage space.", "icloud.and.arrow.up", .storage),
            ("Restart Periodically", "A weekly restart clears memory and applies updates.", "arrow.clockwise", .maintenance),
            ("Manage Desktop", "Keep your Desktop clean - too many files can slow Finder.", "folder", .maintenance),
            ("Check Battery Health", "Monitor battery cycle count and health for laptops.", "battery.100", .battery),
            ("Reduce Transparency", "Disable transparency effects for better performance on older Macs.", "sparkles", .performance),
            ("Run Disk First Aid", "Periodically check disk health with Disk Utility.", "stethoscope", .maintenance),
            ("Review Extensions", "Browser extensions can slow down browsing and use memory.", "puzzlepiece.extension", .performance)
        ]
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let suggestion: Suggestion
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Priority indicator and icon
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(suggestion.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18))
                        .foregroundColor(suggestion.category.color)
                }
                
                // Priority badge
                Text(suggestion.priority.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(suggestion.priority.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(suggestion.priority.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    Spacer()
                    
                    // Category tag
                    Text(suggestion.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(suggestion.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(suggestion.category.color.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Text(suggestion.description)
                    .font(.system(size: 13))
                    .foregroundColor(.smartMacTextSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionLabel = suggestion.actionLabel {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Text(actionLabel)
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.smartMacAccentGreen)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    suggestion.priority == .critical ? Color.smartMacDanger.opacity(0.3) :
                    suggestion.priority == .high ? Color.smartMacWarning.opacity(0.2) :
                    Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - General Tip Card
struct GeneralTipCard: View {
    let tip: (title: String, description: String, icon: String, category: SuggestionCategory)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: tip.icon)
                    .font(.system(size: 14))
                    .foregroundColor(tip.category.color)
                    .frame(width: 28, height: 28)
                    .background(tip.category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text(tip.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                    .lineLimit(1)
            }
            
            Text(tip.description)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
