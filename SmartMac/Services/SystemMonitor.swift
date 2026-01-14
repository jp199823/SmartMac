import Foundation
import Combine
import AppKit

/// Main system monitoring service that aggregates all metrics
class SystemMonitor: ObservableObject {
    // MARK: - Published Properties
    @Published var memoryMetrics: MemoryMetrics = .empty
    @Published var storageMetrics: StorageMetrics = .empty
    @Published var cpuMetrics: CPUMetrics = .empty
    @Published var batteryMetrics: BatteryMetrics = .notPresent
    @Published var networkMetrics: NetworkMetrics = .disconnected
    @Published var gpuMetrics: GPUMetrics = .empty
    @Published var topApplications: [RunningApplication] = []
    @Published var lastUpdated: Date = Date()
    
    // MARK: - Computed Properties
    var overallHealth: SystemHealth {
        var score = 0
        
        // Memory health (0-25 points)
        if memoryMetrics.usagePercentage < 60 { score += 25 }
        else if memoryMetrics.usagePercentage < 75 { score += 20 }
        else if memoryMetrics.usagePercentage < 85 { score += 10 }
        
        // Storage health (0-25 points)
        if storageMetrics.freePercentage > 20 { score += 25 }
        else if storageMetrics.freePercentage > 10 { score += 15 }
        else if storageMetrics.freePercentage > 5 { score += 5 }
        
        // CPU health (0-25 points)
        switch cpuMetrics.thermalState {
        case .nominal: score += 25
        case .fair: score += 20
        case .serious: score += 10
        case .critical: score += 0
        }
        
        // CPU usage (0-25 points)
        if cpuMetrics.usagePercentage < 50 { score += 25 }
        else if cpuMetrics.usagePercentage < 75 { score += 15 }
        else if cpuMetrics.usagePercentage < 90 { score += 5 }
        
        // Calculate final health
        if score >= 90 { return .excellent }
        else if score >= 70 { return .good }
        else if score >= 50 { return .fair }
        else { return .poor }
    }
    
    // MARK: - Private Properties
    private var timer: Timer?
    private let updateInterval: TimeInterval = 3.0  // Reduced frequency for better performance
    
    // MARK: - Initialization
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        // Initial fetch
        refreshAllMetrics()
        
        // Set up periodic refresh
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.refreshAllMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshAllMetrics() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let memory = MemoryMonitor.getMemoryMetrics()
            let storage = StorageMonitor.getStorageMetrics()
            let cpu = CPUMonitor.getCPUMetrics()
            let battery = BatteryMonitor.getBatteryMetrics()
            let network = NetworkMonitor.getNetworkMetrics()
            let gpu = GPUMonitor.getGPUMetrics()
            let apps = AppUsageMonitor.getTopApplications(limit: 5)
            
            DispatchQueue.main.async {
                self?.memoryMetrics = memory
                self?.storageMetrics = storage
                self?.cpuMetrics = cpu
                self?.batteryMetrics = battery
                self?.networkMetrics = network
                self?.gpuMetrics = gpu
                self?.topApplications = apps
                self?.lastUpdated = Date()
            }
        }
    }
}
