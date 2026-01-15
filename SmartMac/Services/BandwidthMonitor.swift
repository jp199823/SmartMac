import Foundation
import Combine

/// Bandwidth Monitor - Real-time network usage tracking
class BandwidthMonitor: ObservableObject {
    static let shared = BandwidthMonitor()
    
    // MARK: - Published Properties
    @Published var currentSpeed: SpeedMetrics = SpeedMetrics(downloadSpeed: 0, uploadSpeed: 0)
    @Published var todayUsage: (received: UInt64, sent: UInt64) = (0, 0)
    @Published var hourlyData: [HourlyBandwidthData] = []
    @Published var dailyData: [DailyBandwidthData] = []
    @Published var alertConfig: BandwidthAlert = BandwidthAlert()
    @Published var peakDownloadSpeed: Double = 0
    @Published var peakUploadSpeed: Double = 0
    
    // MARK: - Storage Keys
    private let hourlyKey = "SmartMac.BandwidthHourly"
    private let dailyKey = "SmartMac.BandwidthDaily"
    private let alertKey = "SmartMac.BandwidthAlert"
    private let baselineKey = "SmartMac.BandwidthBaseline"
    
    // MARK: - Monitoring
    private var timer: Timer?
    private var lastSnapshot: BandwidthSnapshot?
    private var sessionStartBytes: (received: UInt64, sent: UInt64)?
    
    // MARK: - Computed Properties
    var totalTodayBytes: UInt64 {
        todayUsage.received + todayUsage.sent
    }
    
    var totalWeekBytes: UInt64 {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return dailyData
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.totalBytes }
    }
    
    var totalMonthBytes: UInt64 {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return dailyData
            .filter { $0.date >= monthAgo }
            .reduce(0) { $0 + $1.totalBytes }
    }
    
    // MARK: - Initialization
    private init() {
        loadData()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        // Get initial baseline
        let stats = NetworkMonitor.getNetworkMetrics()
        sessionStartBytes = (stats.bytesReceived, stats.bytesSent)
        lastSnapshot = BandwidthSnapshot(bytesReceived: stats.bytesReceived, bytesSent: stats.bytesSent)
        
        // Update every second for real-time speed
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Update Metrics
    private func updateMetrics() {
        let stats = NetworkMonitor.getNetworkMetrics()
        let currentReceived = stats.bytesReceived
        let currentSent = stats.bytesSent
        
        // Calculate speed (bytes per second)
        if let last = lastSnapshot {
            let timeDelta = Date().timeIntervalSince(last.timestamp)
            guard timeDelta > 0 else { return }
            
            let receivedDelta = currentReceived > last.bytesReceived ? currentReceived - last.bytesReceived : 0
            let sentDelta = currentSent > last.bytesSent ? currentSent - last.bytesSent : 0
            
            let downloadSpeed = Double(receivedDelta) / timeDelta
            let uploadSpeed = Double(sentDelta) / timeDelta
            
            currentSpeed = SpeedMetrics(downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed)
            
            // Track peak speeds
            if currentSpeed.downloadMbps > peakDownloadSpeed {
                peakDownloadSpeed = currentSpeed.downloadMbps
            }
            if currentSpeed.uploadMbps > peakUploadSpeed {
                peakUploadSpeed = currentSpeed.uploadMbps
            }
            
            // Update today's usage
            if let baseline = sessionStartBytes {
                let receivedToday = currentReceived > baseline.received ? currentReceived - baseline.received : 0
                let sentToday = currentSent > baseline.sent ? currentSent - baseline.sent : 0
                todayUsage = (receivedToday, sentToday)
            }
        }
        
        lastSnapshot = BandwidthSnapshot(bytesReceived: currentReceived, bytesSent: currentSent)
        
        // Update hourly aggregation every minute
        updateHourlyAggregation()
        
        // Update alert status
        updateAlertStatus()
    }
    
    // MARK: - Hourly Aggregation
    private func updateHourlyAggregation() {
        let calendar = Calendar.current
        let currentHour = calendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
        
        // Check if we already have data for this hour
        if let existingIndex = hourlyData.firstIndex(where: { 
            calendar.isDate($0.hour, equalTo: currentHour, toGranularity: .hour)
        }) {
            // Update existing
            hourlyData[existingIndex] = HourlyBandwidthData(
                hour: currentHour,
                bytesReceived: todayUsage.received,
                bytesSent: todayUsage.sent
            )
        } else {
            // Add new hourly entry
            hourlyData.append(HourlyBandwidthData(
                hour: currentHour,
                bytesReceived: todayUsage.received,
                bytesSent: todayUsage.sent
            ))
            
            // Keep only last 24 hours
            let dayAgo = calendar.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            hourlyData = hourlyData.filter { $0.hour >= dayAgo }
        }
        
        // Save periodically
        saveData()
    }
    
    // MARK: - Daily Aggregation
    func recordDailyUsage() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let existingIndex = dailyData.firstIndex(where: {
            calendar.isDate($0.date, equalTo: today, toGranularity: .day)
        }) {
            dailyData[existingIndex] = DailyBandwidthData(
                date: today,
                bytesReceived: todayUsage.received,
                bytesSent: todayUsage.sent
            )
        } else {
            dailyData.append(DailyBandwidthData(
                date: today,
                bytesReceived: todayUsage.received,
                bytesSent: todayUsage.sent
            ))
        }
        
        // Keep only last 30 days
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        dailyData = dailyData.filter { $0.date >= monthAgo }
        
        saveData()
    }
    
    // MARK: - Alerts
    private func updateAlertStatus() {
        let bytesPerGB: Double = 1_073_741_824
        alertConfig.currentDailyUsageGB = Double(totalTodayBytes) / bytesPerGB
        alertConfig.currentMonthlyUsageGB = Double(totalMonthBytes) / bytesPerGB
    }
    
    func setDailyLimit(_ limit: Double) {
        alertConfig.dailyLimitGB = limit
        saveData()
    }
    
    func setMonthlyLimit(_ limit: Double) {
        alertConfig.monthlyLimitGB = limit
        saveData()
    }
    
    func toggleAlerts(_ enabled: Bool) {
        alertConfig.isEnabled = enabled
        saveData()
    }
    
    // MARK: - Persistence
    private func saveData() {
        if let hourlyEncoded = try? JSONEncoder().encode(hourlyData) {
            UserDefaults.standard.set(hourlyEncoded, forKey: hourlyKey)
        }
        if let dailyEncoded = try? JSONEncoder().encode(dailyData) {
            UserDefaults.standard.set(dailyEncoded, forKey: dailyKey)
        }
        if let alertEncoded = try? JSONEncoder().encode(alertConfig) {
            UserDefaults.standard.set(alertEncoded, forKey: alertKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: hourlyKey),
           let decoded = try? JSONDecoder().decode([HourlyBandwidthData].self, from: data) {
            hourlyData = decoded
        }
        if let data = UserDefaults.standard.data(forKey: dailyKey),
           let decoded = try? JSONDecoder().decode([DailyBandwidthData].self, from: data) {
            dailyData = decoded
        }
        if let data = UserDefaults.standard.data(forKey: alertKey),
           let decoded = try? JSONDecoder().decode(BandwidthAlert.self, from: data) {
            alertConfig = decoded
        }
    }
    
    // MARK: - Reset
    func resetStatistics() {
        hourlyData.removeAll()
        dailyData.removeAll()
        peakDownloadSpeed = 0
        peakUploadSpeed = 0
        
        let stats = NetworkMonitor.getNetworkMetrics()
        sessionStartBytes = (stats.bytesReceived, stats.bytesSent)
        todayUsage = (0, 0)
        
        saveData()
    }
}
