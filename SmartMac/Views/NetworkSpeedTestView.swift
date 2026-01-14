import SwiftUI

struct NetworkSpeedTestView: View {
    @ObservedObject var monitor: SystemMonitor
    @StateObject private var speedTest = NetworkSpeedTest.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Speedometer
                speedometerSection
                
                // Results cards (when complete)
                if speedTest.phase == .complete, let result = speedTest.latestResult {
                    resultsSection(result: result)
                }
                
                // Test button
                testButtonSection
                
                // Connection info
                connectionInfoSection
                
                // History
                historySection
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Network Speed Test")
                .font(.timesNewRoman(size: 28, weight: .bold))
                .foregroundColor(.smartMacCasaBlanca)
            Text("Test your internet connection speed")
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Speedometer Section
    private var speedometerSection: some View {
        VStack(spacing: 16) {
            // Circular gauge
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.smartMacSecondaryBg, lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: speedTest.phase.isRunning ? speedTest.progress : (speedTest.phase == .complete ? 1 : 0))
                    .stroke(
                        AngularGradient(
                            colors: [.smartMacForestGreen, .smartMacAccentGreen, .smartMacCasaBlanca],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: speedTest.progress)
                
                // Center content
                VStack(spacing: 4) {
                    if speedTest.phase.isRunning {
                        Text(String(format: "%.1f", speedTest.currentSpeed))
                            .font(.timesNewRoman(size: 42, weight: .bold))
                            .foregroundColor(.smartMacCasaBlanca)
                        Text("Mbps")
                            .font(.system(size: 14))
                            .foregroundColor(.smartMacTextSecondary)
                    } else if let result = speedTest.latestResult, speedTest.phase == .complete {
                        Text(result.formattedDownload)
                            .font(.timesNewRoman(size: 42, weight: .bold))
                            .foregroundColor(.smartMacCasaBlanca)
                        Text("Mbps Download")
                            .font(.system(size: 14))
                            .foregroundColor(.smartMacTextSecondary)
                    } else {
                        Image(systemName: "wifi")
                            .font(.system(size: 36))
                            .foregroundColor(.smartMacForestGreen)
                    }
                }
            }
            
            // Phase indicator
            Text(speedTest.phase.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(speedTest.phase.isRunning ? .smartMacAccentGreen : .smartMacTextSecondary)
            
            // Phase progress indicators
            if speedTest.phase.isRunning || speedTest.phase == .complete {
                HStack(spacing: 24) {
                    PhaseIndicator(
                        title: "Ping",
                        isActive: speedTest.phase == .measuringPing,
                        isComplete: speedTest.phase != .measuringPing && speedTest.phase != .idle
                    )
                    PhaseIndicator(
                        title: "Download",
                        isActive: speedTest.phase == .downloading,
                        isComplete: speedTest.phase == .uploading || speedTest.phase == .complete
                    )
                    PhaseIndicator(
                        title: "Upload",
                        isActive: speedTest.phase == .uploading,
                        isComplete: speedTest.phase == .complete
                    )
                }
            }
        }
        .padding(32)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(16)
    }
    
    // MARK: - Results Section
    private func resultsSection(result: SpeedTestResult) -> some View {
        HStack(spacing: 16) {
            ResultCard(
                title: "Download",
                value: result.formattedDownload,
                unit: "Mbps",
                icon: "arrow.down.circle.fill",
                color: .smartMacAccentGreen
            )
            
            ResultCard(
                title: "Upload",
                value: result.formattedUpload,
                unit: "Mbps",
                icon: "arrow.up.circle.fill",
                color: .smartMacNavyBlue
            )
            
            ResultCard(
                title: "Ping",
                value: result.formattedPing,
                unit: "ms",
                icon: "bolt.circle.fill",
                color: .smartMacCasaBlanca
            )
        }
    }
    
    // MARK: - Test Button Section
    private var testButtonSection: some View {
        Button(action: {
            if speedTest.phase.isRunning {
                speedTest.cancelTest()
            } else {
                speedTest.runSpeedTest()
            }
        }) {
            HStack(spacing: 12) {
                if speedTest.phase.isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.smartMacBackground)
                    Text("Cancel Test")
                } else {
                    Image(systemName: "play.fill")
                    Text("Start Speed Test")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.smartMacBackground)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                speedTest.phase.isRunning ?
                Color.smartMacDanger :
                Color.smartMacAccentGreen
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Connection Info Section
    private var connectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Details")
                .font(.timesNewRoman(size: 16, weight: .semibold))
                .foregroundColor(.smartMacCasaBlanca)
            
            HStack(spacing: 24) {
                ConnectionInfoItem(
                    icon: "wifi",
                    title: "Type",
                    value: monitor.networkMetrics.connectionType
                )
                ConnectionInfoItem(
                    icon: "number",
                    title: "IP Address",
                    value: monitor.networkMetrics.ipAddress
                )
                ConnectionInfoItem(
                    icon: "server.rack",
                    title: "Test Server",
                    value: "Cloudflare"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Test History")
                    .font(.timesNewRoman(size: 18, weight: .semibold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                if !speedTest.history.results.isEmpty {
                    Button(action: { speedTest.clearHistory() }) {
                        Text("Clear")
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if speedTest.history.results.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundColor(.smartMacTextTertiary)
                        Text("No test history yet")
                            .font(.system(size: 14))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(speedTest.history.results.prefix(10)) { result in
                        HistoryRow(result: result)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
}

// MARK: - Phase Indicator Component
struct PhaseIndicator: View {
    let title: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isComplete ? Color.smartMacSuccess : (isActive ? Color.smartMacAccentGreen : Color.smartMacTextTertiary))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(isActive ? Color.smartMacAccentGreen : Color.clear, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .opacity(isActive ? 1 : 0)
                )
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isActive || isComplete ? .smartMacTextPrimary : .smartMacTextTertiary)
        }
    }
}

// MARK: - Result Card Component
struct ResultCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.timesNewRoman(size: 28, weight: .bold))
                        .foregroundColor(.smartMacCasaBlanca)
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                }
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.smartMacSecondaryBg)
        .cornerRadius(12)
    }
}

// MARK: - Connection Info Item Component
struct ConnectionInfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.smartMacForestGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
            }
        }
    }
}

// MARK: - History Row Component
struct HistoryRow: View {
    let result: SpeedTestResult
    
    var body: some View {
        HStack(spacing: 16) {
            Text(result.formattedTimestamp)
                .font(.system(size: 12))
                .foregroundColor(.smartMacTextSecondary)
                .frame(width: 120, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10))
                Text("\(result.formattedDownload) Mbps")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
            .foregroundColor(.smartMacAccentGreen)
            .frame(width: 100, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10))
                Text("\(result.formattedUpload) Mbps")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
            .foregroundColor(.smartMacNavyBlue)
            .frame(width: 100, alignment: .leading)
            
            HStack(spacing: 4) {
                Image(systemName: "bolt")
                    .font(.system(size: 10))
                Text("\(result.formattedPing) ms")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
            .foregroundColor(.smartMacCasaBlanca)
            
            Spacer()
            
            Text(result.connectionType)
                .font(.system(size: 11))
                .foregroundColor(.smartMacTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.smartMacBackground)
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }
}
