import SwiftUI

/// Performance Mode view for closing apps and optimizing system resources
struct PerformanceModeView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var optimizer = PerformanceOptimizer()
    
    @State private var terminableApps: [TerminableApp] = []
    @State private var selectedApps: Set<TerminableApp> = []
    @State private var selectedPreset: PerformanceOptimizer.PerformancePreset?
    @State private var showConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                if optimizer.isPerformanceModeActive {
                    activeModeCard
                } else {
                    presetsSection
                    appsSection
                    activateButton
                }
            }
            .padding(32)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            refreshApps()
        }
        .alert("Activate Performance Mode?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Close Apps", role: .destructive) {
                activateMode()
            }
        } message: {
            Text("This will close \(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") to free up approximately \(estimatedSavings). Make sure to save any work first.")
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Performance Mode")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                if optimizer.isPerformanceModeActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.smartMacSuccess)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.smartMacSuccess)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.smartMacSuccess.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            Text("Close unnecessary apps to free up memory and improve performance")
                .font(.smartMacBody)
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Active Mode Card
    private var activeModeCard: some View {
        VStack(spacing: 20) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.smartMacSuccess.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.smartMacSuccess)
            }
            
            VStack(spacing: 8) {
                Text("Performance Mode Active")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Text("\(optimizer.appsClosedCount) app\(optimizer.appsClosedCount == 1 ? "" : "s") closed • \(optimizer.memoryFreed.formattedBytesShort) freed")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Button(action: {
                optimizer.deactivatePerformanceMode()
                refreshApps()
            }) {
                Text("Exit Performance Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.smartMacCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Presets Section
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.smartMacAccentGreen)
                Text("Quick Presets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
            }
            
            HStack(spacing: 12) {
                ForEach(PerformanceOptimizer.PerformancePreset.allCases, id: \.self) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        selectPreset(preset)
                    }
                }
            }
        }
    }
    
    // MARK: - Apps Section
    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.smartMacAccentBlue)
                Text("Running Applications")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                Button(action: { selectAll() }) {
                    Text(selectedApps.count == terminableApps.count ? "Deselect All" : "Select All")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            if terminableApps.isEmpty {
                Text("No apps to close")
                    .font(.system(size: 14))
                    .foregroundColor(.smartMacTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(terminableApps) { app in
                        AppSelectionCard(
                            app: app,
                            isSelected: selectedApps.contains(app)
                        ) {
                            toggleApp(app)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.smartMacCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Activate Button
    private var activateButton: some View {
        Button(action: { showConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                Text("Activate Performance Mode")
                    .font(.system(size: 14, weight: .semibold))
                
                if !selectedApps.isEmpty {
                    Text("(\(selectedApps.count) apps)")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
            }
            .foregroundColor(selectedApps.isEmpty ? .smartMacTextTertiary : .smartMacBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedApps.isEmpty ? Color.smartMacCardBg : Color.smartMacAccentGreen)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(selectedApps.isEmpty)
    }
    
    // MARK: - Helper Properties & Methods
    private var estimatedSavings: String {
        let total = selectedApps.reduce(0) { $0 + $1.memoryUsage }
        return total.formattedBytesShort
    }
    
    private func refreshApps() {
        terminableApps = optimizer.getTerminableApps()
        selectedApps = []
        selectedPreset = nil
    }
    
    private func selectPreset(_ preset: PerformanceOptimizer.PerformancePreset) {
        selectedPreset = preset
        let appsForPreset = optimizer.getAppsForPreset(preset, from: terminableApps)
        selectedApps = Set(appsForPreset)
    }
    
    private func toggleApp(_ app: TerminableApp) {
        if selectedApps.contains(app) {
            selectedApps.remove(app)
        } else {
            selectedApps.insert(app)
        }
        selectedPreset = nil
    }
    
    private func selectAll() {
        if selectedApps.count == terminableApps.count {
            selectedApps = []
        } else {
            selectedApps = Set(terminableApps)
        }
        selectedPreset = nil
    }
    
    private func activateMode() {
        optimizer.activatePerformanceMode(closing: Array(selectedApps))
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let preset: PerformanceOptimizer.PerformancePreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .smartMacBackground : .smartMacAccentGreen)
                
                Text(preset.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .smartMacBackground : .smartMacCasaBlanca)
                
                Text(preset.description)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .smartMacBackground.opacity(0.8) : .smartMacTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.smartMacAccentGreen : Color.smartMacCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Selection Card
struct AppSelectionCard: View {
    let app: TerminableApp
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
                if let icon = app.icon {
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
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.smartMacCasaBlanca)
                        .lineLimit(1)
                    
                    Text(app.memoryFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.smartMacAccentGreen.opacity(0.1) : Color.smartMacSecondaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.smartMacAccentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
