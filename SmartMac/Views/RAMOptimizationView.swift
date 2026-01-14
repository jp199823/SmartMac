import SwiftUI

/// RAM Optimization view with analysis, recommendations, and manual instructions
struct RAMOptimizationView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var optimizer = RAMOptimizer()
    
    @State private var selectedRecommendations: Set<UUID> = []
    @State private var showInstructions = false
    @State private var showConfirmation = false
    @State private var showResult = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                memoryOverviewCard
                
                // Toggle between automatic and manual modes
                modeToggle
                
                if showInstructions {
                    instructionsSection
                } else {
                    recommendationsSection
                    
                    if !optimizer.recommendations.isEmpty {
                        optimizeButton
                    }
                }
                
                if let result = optimizer.lastOptimizationResult, showResult {
                    resultCard(result)
                }
            }
            .padding(32)
        }
        .background(Color.smartMacBackground)
        .alert("Optimize RAM?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Optimize", role: .destructive) {
                executeOptimization()
            }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RAM Optimizer")
                .font(.smartMacTitle)
                .foregroundColor(.smartMacCasaBlanca)
            
            Text("Analyze memory usage and free up RAM with one click or follow manual steps")
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Memory Overview Card
    private var memoryOverviewCard: some View {
        HStack(spacing: 24) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color.smartMacTextTertiary.opacity(0.2), lineWidth: 10)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: monitor.memoryMetrics.usagePercentage / 100)
                    .stroke(memoryColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(monitor.memoryMetrics.usagePercentage))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text("Used")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextSecondary)
                }
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 12) {
                MemoryStatRow(label: "Used", value: monitor.memoryMetrics.used.formattedBytesShort, color: .smartMacAccentBlue)
                MemoryStatRow(label: "Available", value: monitor.memoryMetrics.free.formattedBytesShort, color: .smartMacSuccess)
                MemoryStatRow(label: "Total", value: monitor.memoryMetrics.total.formattedBytesShort, color: .smartMacTextSecondary)
            }
            
            Spacer()
            
            // Status indicator
            VStack(spacing: 8) {
                Image(systemName: memoryStatusIcon)
                    .font(.system(size: 28))
                    .foregroundColor(memoryColor)
                
                Text(memoryStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(memoryColor)
            }
            .padding(16)
            .background(memoryColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Mode Toggle
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ModeToggleButton(
                title: "Quick Optimize",
                icon: "bolt.fill",
                isSelected: !showInstructions
            ) {
                showInstructions = false
            }
            
            ModeToggleButton(
                title: "Manual Steps",
                icon: "list.number",
                isSelected: showInstructions
            ) {
                showInstructions = true
            }
        }
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Recommendations Section
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.smartMacAccentBlue)
                Text("Recommendations")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Button(action: {
                    optimizer.analyzeRAMUsage()
                }) {
                    HStack(spacing: 4) {
                        if optimizer.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(optimizer.isAnalyzing ? "Analyzing..." : "Analyze RAM")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smartMacAccentGreen)
                }
                .buttonStyle(.plain)
                .disabled(optimizer.isAnalyzing)
            }
            
            if optimizer.recommendations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.smartMacTextTertiary)
                    
                    Text("Click 'Analyze RAM' to scan running applications")
                        .font(.system(size: 13))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                VStack(spacing: 8) {
                    ForEach(optimizer.recommendations) { rec in
                        RecommendationRow(
                            recommendation: rec,
                            isSelected: selectedRecommendations.contains(rec.id)
                        ) {
                            toggleRecommendation(rec)
                        }
                    }
                }
                
                // Selection summary
                if !selectedRecommendations.isEmpty {
                    HStack {
                        Text("\(selectedRecommendations.count) selected")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                        
                        Spacer()
                        
                        Text("Estimated savings: \(estimatedSavings)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.smartMacAccentGreen)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundColor(.smartMacForestGreen)
                Text("Step-by-Step Instructions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
            }
            
            VStack(spacing: 0) {
                ForEach(optimizer.getManualInstructions()) { instruction in
                    InstructionRow(instruction: instruction)
                    
                    if instruction.step < 6 {
                        Divider()
                            .background(Color.smartMacTextTertiary.opacity(0.2))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Optimize Button
    private var optimizeButton: some View {
        Button(action: { showConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                Text(selectedRecommendations.isEmpty ? "Quick Optimize All" : "Optimize Selected")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.smartMacBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.smartMacAccentGreen)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Result Card
    private func resultCard(_ result: OptimizationResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: result.wasSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.wasSuccessful ? .smartMacSuccess : .smartMacWarning)
                
                Text(result.wasSuccessful ? "Optimization Complete" : "Partial Optimization")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Button(action: { showResult = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Freed")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextSecondary)
                    Text(result.memoryFreedFormatted)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.smartMacSuccess)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps Closed")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextSecondary)
                    Text("\(result.appsClosed.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                }
                
                Spacer()
            }
            
            if !result.appsClosed.isEmpty {
                Text("Closed: \(result.appsClosed.joined(separator: ", "))")
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.smartMacSuccess.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.smartMacSuccess.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Properties
    private var memoryColor: Color {
        let usage = monitor.memoryMetrics.usagePercentage
        if usage > 85 { return .smartMacDanger }
        if usage > 70 { return .smartMacWarning }
        return .smartMacSuccess
    }
    
    private var memoryStatusIcon: String {
        let usage = monitor.memoryMetrics.usagePercentage
        if usage > 85 { return "exclamationmark.triangle.fill" }
        if usage > 70 { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }
    
    private var memoryStatusText: String {
        let usage = monitor.memoryMetrics.usagePercentage
        if usage > 85 { return "High Pressure" }
        if usage > 70 { return "Moderate" }
        return "Healthy"
    }
    
    private var estimatedSavings: String {
        let selected = optimizer.recommendations.filter { selectedRecommendations.contains($0.id) }
        let total = selected.reduce(0) { $0 + $1.potentialSavings }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
    }
    
    private var confirmationMessage: String {
        let appsToClose: [RAMRecommendation]
        if selectedRecommendations.isEmpty {
            appsToClose = optimizer.recommendations
        } else {
            appsToClose = optimizer.recommendations.filter { selectedRecommendations.contains($0.id) }
        }
        
        let appNames = appsToClose.prefix(3).map { $0.appName }.joined(separator: ", ")
        let more = appsToClose.count > 3 ? " and \(appsToClose.count - 3) more" : ""
        
        return "The following apps will be closed: \(appNames)\(more). Make sure to save any work first."
    }
    
    // MARK: - Methods
    private func toggleRecommendation(_ rec: RAMRecommendation) {
        if selectedRecommendations.contains(rec.id) {
            selectedRecommendations.remove(rec.id)
        } else {
            selectedRecommendations.insert(rec.id)
        }
    }
    
    private func executeOptimization() {
        let appsToClose: [RAMRecommendation]
        if selectedRecommendations.isEmpty {
            appsToClose = optimizer.recommendations
        } else {
            appsToClose = optimizer.recommendations.filter { selectedRecommendations.contains($0.id) }
        }
        
        _ = optimizer.executeOptimization(apps: appsToClose)
        selectedRecommendations = []
        showResult = true
    }
}

// MARK: - Supporting Views

struct MemoryStatRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.smartMacCasaBlanca)
        }
    }
}

struct ModeToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .smartMacBackground : .smartMacTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.smartMacForestGreen : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct RecommendationRow: View {
    let recommendation: RAMRecommendation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.smartMacAccentGreen : Color.smartMacTextTertiary, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.smartMacAccentGreen)
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.smartMacBackground)
                    }
                }
                
                // App icon
                if let icon = recommendation.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.smartMacTextTertiary)
                        .frame(width: 28, height: 28)
                }
                
                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.appName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.smartMacCasaBlanca)
                    
                    Text(recommendation.reason)
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Memory savings
                VStack(alignment: .trailing, spacing: 2) {
                    Text(recommendation.savingsFormatted)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.smartMacAccentGreen)
                    
                    Text(recommendation.priority.label)
                        .font(.system(size: 10))
                        .foregroundColor(priorityColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.smartMacAccentGreen.opacity(0.1) : Color.smartMacSecondaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return .smartMacDanger
        case .medium: return .smartMacWarning
        case .low: return .smartMacTextSecondary
        }
    }
}

struct InstructionRow: View {
    let instruction: OptimizationInstruction
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.smartMacForestGreen.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(instruction.step)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.smartMacForestGreen)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: instruction.icon)
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacAccentGreen)
                    
                    Text(instruction.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.smartMacCasaBlanca)
                }
                
                Text(instruction.description)
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
}
