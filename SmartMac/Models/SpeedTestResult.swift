import Foundation

// MARK: - Speed Test Result
struct SpeedTestResult: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let connectionType: String
    let serverInfo: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        downloadMbps: Double,
        uploadMbps: Double,
        pingMs: Double,
        connectionType: String,
        serverInfo: String = "Cloudflare"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.pingMs = pingMs
        self.connectionType = connectionType
        self.serverInfo = serverInfo
    }
    
    var formattedDownload: String {
        String(format: "%.1f", downloadMbps)
    }
    
    var formattedUpload: String {
        String(format: "%.1f", uploadMbps)
    }
    
    var formattedPing: String {
        String(format: "%.0f", pingMs)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var speedRating: SpeedRating {
        if downloadMbps >= 100 {
            return .excellent
        } else if downloadMbps >= 50 {
            return .good
        } else if downloadMbps >= 25 {
            return .fair
        } else {
            return .poor
        }
    }
}

// MARK: - Speed Rating
enum SpeedRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent: return "smartMacSuccess"
        case .good: return "smartMacAccentGreen"
        case .fair: return "smartMacWarning"
        case .poor: return "smartMacDanger"
        }
    }
}

// MARK: - Speed Test Phase
enum SpeedTestPhase: Equatable {
    case idle
    case measuringPing
    case downloading
    case uploading
    case complete
    case error(String)
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .measuringPing: return "Measuring Ping..."
        case .downloading: return "Testing Download..."
        case .uploading: return "Testing Upload..."
        case .complete: return "Complete"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var isRunning: Bool {
        switch self {
        case .measuringPing, .downloading, .uploading:
            return true
        default:
            return false
        }
    }
}

// MARK: - Speed Test History
struct SpeedTestHistory: Codable {
    var results: [SpeedTestResult]
    
    init(results: [SpeedTestResult] = []) {
        self.results = results
    }
    
    mutating func addResult(_ result: SpeedTestResult) {
        results.insert(result, at: 0)
        // Keep only last 50 results
        if results.count > 50 {
            results = Array(results.prefix(50))
        }
    }
    
    var averageDownload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.downloadMbps }.reduce(0, +) / Double(results.count)
    }
    
    var averageUpload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.uploadMbps }.reduce(0, +) / Double(results.count)
    }
    
    var averagePing: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.pingMs }.reduce(0, +) / Double(results.count)
    }
}
