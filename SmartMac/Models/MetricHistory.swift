import Foundation

// MARK: - Metric Type
enum MetricType: String, CaseIterable, Identifiable, Codable {
    case ram = "RAM Usage"
    case cpu = "CPU Usage"
    case storage = "Storage Used"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .ram: return "memorychip"
        case .cpu: return "cpu"
        case .storage: return "internaldrive"
        }
    }
    
    var color: String {
        switch self {
        case .ram: return "smartMacAccentGreen"
        case .cpu: return "smartMacAccentBlue"
        case .storage: return "smartMacNavyBlue"
        }
    }
}

// MARK: - Time Range
enum TimeRange: String, CaseIterable, Identifiable {
    case hour = "1H"
    case day = "24H"
    case week = "7D"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hour: return "Last Hour"
        case .day: return "Last 24 Hours"
        case .week: return "Last 7 Days"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        }
    }
    
    var sampleInterval: TimeInterval {
        switch self {
        case .hour: return 60        // Every minute
        case .day: return 300       // Every 5 minutes
        case .week: return 1800     // Every 30 minutes
        }
    }
}

// MARK: - Metric Data Point
struct MetricDataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let value: Double
    
    init(id: UUID = UUID(), timestamp: Date = Date(), value: Double) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - Metric History
struct MetricHistory: Codable {
    let metricType: MetricType
    var dataPoints: [MetricDataPoint]
    
    var latestValue: Double? {
        dataPoints.last?.value
    }
    
    var minValue: Double? {
        dataPoints.map(\.value).min()
    }
    
    var maxValue: Double? {
        dataPoints.map(\.value).max()
    }
    
    var averageValue: Double? {
        guard !dataPoints.isEmpty else { return nil }
        return dataPoints.map(\.value).reduce(0, +) / Double(dataPoints.count)
    }
    
    func filtered(for range: TimeRange) -> [MetricDataPoint] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return dataPoints.filter { $0.timestamp >= cutoff }
    }
    
    static func empty(for type: MetricType) -> MetricHistory {
        MetricHistory(metricType: type, dataPoints: [])
    }
}

// MARK: - Historical Stats
struct HistoricalStats {
    let min: Double
    let max: Double
    let average: Double
    let current: Double
    
    var formattedMin: String { String(format: "%.1f%%", min) }
    var formattedMax: String { String(format: "%.1f%%", max) }
    var formattedAverage: String { String(format: "%.1f%%", average) }
    var formattedCurrent: String { String(format: "%.1f%%", current) }
    
    static let empty = HistoricalStats(min: 0, max: 0, average: 0, current: 0)
}
