import SwiftUI

struct ContentView: View {
    @State private var selectedTab: NavigationTab = .dashboard
    @StateObject private var systemMonitor = SystemMonitor()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showThemePicker = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // App Title
                HStack {
                    Image(systemName: "laptopcomputer")
                        .font(.title2)
                        .foregroundColor(.smartMacAccentGreen)
                    Text("SmartMac")
                        .font(.timesNewRoman(size: 22, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.smartMacTextTertiary.opacity(0.3))
                
                // Navigation Items
                VStack(spacing: 4) {
                    ForEach(NavigationTab.allCases, id: \.self) { tab in
                        NavigationButton(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Settings / Theme Button
                Button(action: { showThemePicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 14))
                        Text("Theme")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.smartMacBackground.opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
                
                // System Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(systemMonitor.overallHealth.color)
                        .frame(width: 8, height: 8)
                    Text(systemMonitor.overallHealth.label)
                        .font(.caption)
                        .foregroundColor(.smartMacTextSecondary)
                }
                .padding(.bottom, 20)
            }
            .frame(width: 200)
            .background(Color.smartMacSecondaryBg)
        } detail: {
            // Main Content with smooth transitions
            ZStack {
                ForEach(NavigationTab.allCases, id: \.self) { tab in
                    if selectedTab == tab {
                        viewForTab(tab)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)).animation(.easeOut(duration: 0.2)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.smartMacBackground)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar(.hidden, for: .windowToolbar)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(themeManager: themeManager)
        }
        .id(themeManager.currentTheme) // Force view refresh on theme change
    }
    
    @ViewBuilder
    private func viewForTab(_ tab: NavigationTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(monitor: systemMonitor, selectedTab: $selectedTab)
        case .technicalSpecs:
            TechnicalSpecsView(monitor: systemMonitor)
        case .suggestions:
            SuggestionsView(monitor: systemMonitor)
        case .performanceMode:
            PerformanceModeView(monitor: systemMonitor)
        case .ramOptimizer:
            RAMOptimizationView(monitor: systemMonitor)
        case .appUsage:
            AppUsageAnalyticsView(monitor: systemMonitor)
        case .speedTest:
            NetworkSpeedTestView(monitor: systemMonitor)
        case .startupTime:
            StartupTimeView(monitor: systemMonitor)
        case .largeFiles:
            LargeFileFinderView(monitor: systemMonitor)
        case .cleanup:
            OneClickCleanupView(monitor: systemMonitor)
        case .battery:
            BatteryHealthView(monitor: systemMonitor)
        case .trends:
            HistoricalTrendsView(monitor: systemMonitor)
        case .clipboard:
            ClipboardManagerView()
        case .bandwidth:
            BandwidthMonitorView()
        case .security:
            SecurityScannerView()
        case .uninstaller:
            AppUninstallerView()
        case .shortcuts:
            ShortcutManagerView()
        }
    }
}

// MARK: - Navigation Tab Enum
enum NavigationTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case technicalSpecs = "Tech Specs"
    case suggestions = "Suggestions"
    case performanceMode = "Performance"
    case ramOptimizer = "RAM Optimizer"
    case appUsage = "App Usage"
    case speedTest = "Speed Test"
    case startupTime = "Startup"
    case largeFiles = "Large Files"
    case cleanup = "Cleanup"
    case battery = "Battery"
    case trends = "Trends"
    case clipboard = "Clipboard"
    case bandwidth = "Bandwidth"
    case security = "Security"
    case uninstaller = "Uninstaller"
    case shortcuts = "Shortcuts"
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .technicalSpecs: return "cpu"
        case .suggestions: return "lightbulb"
        case .performanceMode: return "bolt.fill"
        case .ramOptimizer: return "memorychip"
        case .appUsage: return "chart.bar.fill"
        case .speedTest: return "wifi"
        case .startupTime: return "power"
        case .largeFiles: return "externaldrive.fill"
        case .cleanup: return "sparkles"
        case .battery: return "battery.100"
        case .trends: return "chart.xyaxis.line"
        case .clipboard: return "doc.on.clipboard"
        case .bandwidth: return "network"
        case .security: return "shield.checkered"
        case .uninstaller: return "trash.square"
        case .shortcuts: return "keyboard"
        }
    }
}

// MARK: - Navigation Button
struct NavigationButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24)
                Text(tab.rawValue)
                    .font(.timesNewRoman(size: 14, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .smartMacCasaBlanca : .smartMacTextSecondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.smartMacForestGreen.opacity(0.4) : (isHovered ? Color.smartMacForestGreen.opacity(0.15) : Color.clear))
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

