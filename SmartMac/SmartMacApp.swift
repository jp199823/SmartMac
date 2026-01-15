import SwiftUI

@main
struct SmartMacApp: App {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var menuBarController: MenuBarController?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Initialize menu bar
                    if menuBarController == nil {
                        menuBarController = MenuBarController(monitor: systemMonitor)
                    }
                    // Start recording historical data
                    startHistoricalRecording()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
    
    private func startHistoricalRecording() {
        // Record metrics every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let ram = systemMonitor.memoryMetrics.usagePercentage
            let cpu = systemMonitor.cpuMetrics.usagePercentage
            let storage = 100 - systemMonitor.storageMetrics.freePercentage
            
            HistoricalDataStore.shared.recordDataPoint(ram: ram, cpu: cpu, storage: storage)
        }
    }
}
