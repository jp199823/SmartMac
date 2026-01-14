import Foundation

/// Service for persisting and retrieving historical metric data
class HistoricalDataStore: ObservableObject {
    static let shared = HistoricalDataStore()
    
    @Published private(set) var ramHistory: MetricHistory
    @Published private(set) var cpuHistory: MetricHistory
    @Published private(set) var storageHistory: MetricHistory
    
    private let storageKey = "SmartMac.HistoricalData"
    private let maxDataPoints = 10080  // 7 days at 1 sample per minute
    private var lastSampleTime: Date?
    private let minSampleInterval: TimeInterval = 30  // Minimum 30 seconds between samples
    
    private init() {
        // Load existing data or create empty
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(StoredHistory.self, from: data) {
            self.ramHistory = stored.ram
            self.cpuHistory = stored.cpu
            self.storageHistory = stored.storage
        } else {
            self.ramHistory = .empty(for: .ram)
            self.cpuHistory = .empty(for: .cpu)
            self.storageHistory = .empty(for: .storage)
        }
    }
    
    // MARK: - Public Methods
    func recordDataPoint(ram: Double, cpu: Double, storage: Double) {
        let now = Date()
        
        // Throttle sampling
        if let lastTime = lastSampleTime, now.timeIntervalSince(lastTime) < minSampleInterval {
            return
        }
        lastSampleTime = now
        
        // Add new data points
        ramHistory.dataPoints.append(MetricDataPoint(timestamp: now, value: ram))
        cpuHistory.dataPoints.append(MetricDataPoint(timestamp: now, value: cpu))
        storageHistory.dataPoints.append(MetricDataPoint(timestamp: now, value: storage))
        
        // Prune old data
        pruneOldData()
        
        // Persist
        save()
    }
    
    func getHistory(for metric: MetricType) -> MetricHistory {
        switch metric {
        case .ram: return ramHistory
        case .cpu: return cpuHistory
        case .storage: return storageHistory
        }
    }
    
    func getStats(for metric: MetricType, range: TimeRange) -> HistoricalStats {
        let history = getHistory(for: metric)
        let filtered = history.filtered(for: range)
        
        guard !filtered.isEmpty else { return .empty }
        
        let values = filtered.map(\.value)
        return HistoricalStats(
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            average: values.reduce(0, +) / Double(values.count),
            current: values.last ?? 0
        )
    }
    
    func clearHistory() {
        ramHistory = .empty(for: .ram)
        cpuHistory = .empty(for: .cpu)
        storageHistory = .empty(for: .storage)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    // MARK: - Private Methods
    private func pruneOldData() {
        let cutoff = Date().addingTimeInterval(-TimeRange.week.seconds)
        
        ramHistory.dataPoints = ramHistory.dataPoints.filter { $0.timestamp >= cutoff }
        cpuHistory.dataPoints = cpuHistory.dataPoints.filter { $0.timestamp >= cutoff }
        storageHistory.dataPoints = storageHistory.dataPoints.filter { $0.timestamp >= cutoff }
        
        // Also limit total count
        if ramHistory.dataPoints.count > maxDataPoints {
            ramHistory.dataPoints = Array(ramHistory.dataPoints.suffix(maxDataPoints))
        }
        if cpuHistory.dataPoints.count > maxDataPoints {
            cpuHistory.dataPoints = Array(cpuHistory.dataPoints.suffix(maxDataPoints))
        }
        if storageHistory.dataPoints.count > maxDataPoints {
            storageHistory.dataPoints = Array(storageHistory.dataPoints.suffix(maxDataPoints))
        }
    }
    
    private func save() {
        let stored = StoredHistory(ram: ramHistory, cpu: cpuHistory, storage: storageHistory)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Storage Model
private struct StoredHistory: Codable {
    let ram: MetricHistory
    let cpu: MetricHistory
    let storage: MetricHistory
}
