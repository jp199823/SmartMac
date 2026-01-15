import Foundation

// MARK: - Bandwidth Snapshot
struct BandwidthSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let bytesReceived: UInt64
    let bytesSent: UInt64
    
    init(bytesReceived: UInt64, bytesSent: UInt64) {
        self.id = UUID()
        self.timestamp = Date()
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
    }
}

// MARK: - Bandwidth Usage Period
enum BandwidthPeriod: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    
    var icon: String {
        switch self {
        case .today: return "clock"
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.badge.clock"
        }
    }
}

// MARK: - Hourly Bandwidth Data
struct HourlyBandwidthData: Identifiable, Codable {
    let id: UUID
    let hour: Date
    let bytesReceived: UInt64
    let bytesSent: UInt64
    
    init(hour: Date, bytesReceived: UInt64, bytesSent: UInt64) {
        self.id = UUID()
        self.hour = hour
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
    }
    
    var totalBytes: UInt64 {
        bytesReceived + bytesSent
    }
}

// MARK: - Daily Bandwidth Data
struct DailyBandwidthData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let bytesReceived: UInt64
    let bytesSent: UInt64
    
    init(date: Date, bytesReceived: UInt64, bytesSent: UInt64) {
        self.id = UUID()
        self.date = date
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
    }
    
    var totalBytes: UInt64 {
        bytesReceived + bytesSent
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Bandwidth Alert Configuration
struct BandwidthAlert: Codable {
    var isEnabled: Bool
    var dailyLimitGB: Double
    var monthlyLimitGB: Double
    var currentDailyUsageGB: Double
    var currentMonthlyUsageGB: Double
    
    init() {
        self.isEnabled = false
        self.dailyLimitGB = 5.0
        self.monthlyLimitGB = 100.0
        self.currentDailyUsageGB = 0
        self.currentMonthlyUsageGB = 0
    }
    
    var dailyPercentUsed: Double {
        guard dailyLimitGB > 0 else { return 0 }
        return min((currentDailyUsageGB / dailyLimitGB) * 100, 100)
    }
    
    var monthlyPercentUsed: Double {
        guard monthlyLimitGB > 0 else { return 0 }
        return min((currentMonthlyUsageGB / monthlyLimitGB) * 100, 100)
    }
}

// MARK: - Speed Metrics
struct SpeedMetrics {
    let downloadSpeed: Double // bytes per second
    let uploadSpeed: Double   // bytes per second
    
    var downloadMbps: Double {
        (downloadSpeed * 8) / 1_000_000
    }
    
    var uploadMbps: Double {
        (uploadSpeed * 8) / 1_000_000
    }
    
    var formattedDownload: String {
        formatSpeed(downloadMbps)
    }
    
    var formattedUpload: String {
        formatSpeed(uploadMbps)
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1000 {
            return String(format: "%.1f Gbps", mbps / 1000)
        } else if mbps >= 1 {
            return String(format: "%.1f Mbps", mbps)
        } else {
            return String(format: "%.0f Kbps", mbps * 1000)
        }
    }
}
