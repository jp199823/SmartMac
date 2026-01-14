import Foundation
import Combine

/// Network speed testing service using URLSession
class NetworkSpeedTest: ObservableObject {
    // MARK: - Published Properties
    @Published var phase: SpeedTestPhase = .idle
    @Published var currentSpeed: Double = 0
    @Published var progress: Double = 0
    @Published var latestResult: SpeedTestResult?
    @Published var history: SpeedTestHistory
    
    // MARK: - Private Properties
    private var downloadTask: URLSessionDataTask?
    private var uploadTask: URLSessionDataTask?
    private var pingTask: URLSessionDataTask?
    private var isCancelled = false
    
    private let storageURL: URL
    
    // Test URLs (using Cloudflare's speed test endpoints)
    private let pingURL = URL(string: "https://speed.cloudflare.com/__down?bytes=1")!
    private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")! // 10MB
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    
    // MARK: - Singleton
    static let shared = NetworkSpeedTest()
    
    // MARK: - Initialization
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let smartMacDir = appSupport.appendingPathComponent("SmartMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: smartMacDir, withIntermediateDirectories: true)
        storageURL = smartMacDir.appendingPathComponent("speed_test_history.json")
        
        history = Self.loadHistory(from: storageURL)
    }
    
    // MARK: - Public Methods
    func runSpeedTest() {
        guard !phase.isRunning else { return }
        
        isCancelled = false
        currentSpeed = 0
        progress = 0
        
        Task { @MainActor in
            do {
                // Phase 1: Measure Ping
                phase = .measuringPing
                progress = 0.1
                let ping = try await measurePing()
                
                guard !isCancelled else { return }
                
                // Phase 2: Download Test
                phase = .downloading
                progress = 0.2
                let download = try await measureDownload()
                
                guard !isCancelled else { return }
                
                // Phase 3: Upload Test
                phase = .uploading
                progress = 0.7
                let upload = try await measureUpload()
                
                guard !isCancelled else { return }
                
                // Complete
                progress = 1.0
                
                let result = SpeedTestResult(
                    downloadMbps: download,
                    uploadMbps: upload,
                    pingMs: ping,
                    connectionType: NetworkMonitor.getNetworkMetrics().connectionType
                )
                
                latestResult = result
                history.addResult(result)
                saveHistory()
                
                phase = .complete
                
            } catch {
                if !isCancelled {
                    phase = .error(error.localizedDescription)
                }
            }
        }
    }
    
    func cancelTest() {
        isCancelled = true
        downloadTask?.cancel()
        uploadTask?.cancel()
        pingTask?.cancel()
        
        phase = .idle
        currentSpeed = 0
        progress = 0
    }
    
    func clearHistory() {
        history = SpeedTestHistory()
        saveHistory()
    }
    
    // MARK: - Private Methods
    private func measurePing() async throws -> Double {
        var pings: [Double] = []
        
        // Perform 5 pings and take the median
        for _ in 0..<5 {
            let startTime = Date()
            
            let (_, response) = try await URLSession.shared.data(from: pingURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SpeedTestError.connectionFailed
            }
            
            let elapsed = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
            pings.append(elapsed)
            
            // Small delay between pings
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Return median
        let sorted = pings.sorted()
        return sorted[sorted.count / 2]
    }
    
    private func measureDownload() async throws -> Double {
        let startTime = Date()
        var totalBytes: Int64 = 0
        
        // Use URL directly with a custom session configuration for cache bypass
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        
        let (bytes, response) = try await session.bytes(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpeedTestError.connectionFailed
        }
        
        let expectedLength = httpResponse.expectedContentLength
        
        for try await _ in bytes {
            totalBytes += 1
            
            // Update progress
            if expectedLength > 0 {
                let downloadProgress = Double(totalBytes) / Double(expectedLength)
                await MainActor.run {
                    self.progress = 0.2 + (downloadProgress * 0.5)
                    
                    // Calculate current speed
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > 0 {
                        let bytesPerSecond = Double(totalBytes) / elapsed
                        let mbps = (bytesPerSecond * 8) / 1_000_000
                        self.currentSpeed = mbps
                    }
                }
            }
            
            if isCancelled { throw SpeedTestError.cancelled }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let bytesPerSecond = Double(totalBytes) / elapsed
        let mbps = (bytesPerSecond * 8) / 1_000_000
        
        return mbps
    }
    
    private func measureUpload() async throws -> Double {
        let startTime = Date()
        
        // Generate 5MB of random data for upload
        let dataSize = 5_000_000
        let uploadData = Data(count: dataSize)
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(dataSize)", forHTTPHeaderField: "Content-Length")
        
        let session = URLSession(configuration: .default)
        
        // Use upload task with delegate for progress tracking
        let (_, response) = try await session.upload(for: request, from: uploadData)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SpeedTestError.connectionFailed
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let bytesPerSecond = Double(dataSize) / elapsed
        let mbps = (bytesPerSecond * 8) / 1_000_000
        
        await MainActor.run {
            self.currentSpeed = mbps
            self.progress = 0.95
        }
        
        return mbps
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save speed test history: \(error)")
        }
    }
    
    private static func loadHistory(from url: URL) -> SpeedTestHistory {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SpeedTestHistory.self, from: data)
        } catch {
            return SpeedTestHistory()
        }
    }
}

// MARK: - Speed Test Errors
enum SpeedTestError: LocalizedError {
    case connectionFailed
    case cancelled
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Connection failed"
        case .cancelled: return "Test cancelled"
        case .timeout: return "Test timed out"
        }
    }
}
