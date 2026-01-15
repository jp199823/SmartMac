import SwiftUI

struct SecurityScannerView: View {
    @StateObject private var securityScanner = SecurityScanner.shared
    @State private var expandedCategory: SecurityCategory?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Score Section
                scoreSection
                
                // Category Summary
                categorySummarySection
                
                // Detailed Checks
                checksSection
                
                // Outdated Apps (if any)
                if !securityScanner.outdatedApps.isEmpty {
                    outdatedAppsSection
                }
            }
            .padding(24)
        }
        .background(Color.smartMacBackground)
        .onAppear {
            if securityScanner.lastScanDate == nil {
                securityScanner.runFullScan()
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Security Scanner")
                    .font(.smartMacTitle)
                    .foregroundColor(.smartMacTextPrimary)
                
                if let lastScan = securityScanner.lastScanDate {
                    Text("Last scan: \(lastScan.formatted(date: .abbreviated, time: .shortened))")
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacTextSecondary)
                } else {
                    Text("Not yet scanned")
                        .font(.smartMacCaption)
                        .foregroundColor(.smartMacTextTertiary)
                }
            }
            
            Spacer()
            
            // Scan Button
            Button(action: { securityScanner.runFullScan() }) {
                HStack(spacing: 8) {
                    if securityScanner.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "shield.checkerboard")
                    }
                    Text(securityScanner.isScanning ? "Scanning..." : "Scan Now")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.smartMacAccentGreen, .smartMacAccentBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(securityScanner.isScanning)
        }
    }
    
    // MARK: - Score Section
    private var scoreSection: some View {
        HStack(spacing: 32) {
            // Main Score Gauge
            ZStack {
                Circle()
                    .stroke(Color.smartMacSecondaryBg, lineWidth: 16)
                
                Circle()
                    .trim(from: 0, to: Double(securityScanner.securityScore.score) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: securityScanner.securityScore.score)
                
                VStack(spacing: 4) {
                    Text("\(securityScanner.securityScore.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.smartMacTextPrimary)
                    Text(securityScanner.securityScore.label)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(scoreColor)
                }
            }
            .frame(width: 180, height: 180)
            
            // Score Breakdown
            VStack(alignment: .leading, spacing: 16) {
                Text("Security Overview")
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                
                ScoreBreakdownRow(
                    icon: "checkmark.circle.fill",
                    color: .smartMacSuccess,
                    label: "Passed",
                    count: securityScanner.securityScore.passedChecks
                )
                
                ScoreBreakdownRow(
                    icon: "exclamationmark.triangle.fill",
                    color: .smartMacWarning,
                    label: "Warnings",
                    count: securityScanner.securityScore.warningChecks
                )
                
                ScoreBreakdownRow(
                    icon: "xmark.circle.fill",
                    color: .smartMacDanger,
                    label: "Failed",
                    count: securityScanner.securityScore.failedChecks
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Color.smartMacCardBg)
        .cornerRadius(20)
    }
    
    private var scoreColor: Color {
        switch securityScanner.securityScore.color {
        case "Success": return .smartMacSuccess
        case "Info": return .smartMacInfo
        case "Warning": return .smartMacWarning
        default: return .smartMacDanger
        }
    }
    
    // MARK: - Category Summary
    private var categorySummarySection: some View {
        HStack(spacing: 16) {
            ForEach(SecurityCategory.allCases, id: \.self) { category in
                CategoryCard(
                    category: category,
                    checks: securityScanner.checksByCategory[category] ?? [],
                    isExpanded: expandedCategory == category,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedCategory = expandedCategory == category ? nil : category
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Checks Section
    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Checks")
                .font(.smartMacHeadline)
                .foregroundColor(.smartMacTextPrimary)
            
            let checksToShow = expandedCategory != nil
                ? securityScanner.checksByCategory[expandedCategory!] ?? []
                : securityScanner.checks
            
            ForEach(checksToShow) { check in
                SecurityCheckRow(check: check) {
                    securityScanner.openSystemPreferences(for: check)
                }
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
    
    // MARK: - Outdated Apps Section
    private var outdatedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.smartMacWarning)
                Text("Outdated Applications")
                    .font(.smartMacHeadline)
                    .foregroundColor(.smartMacTextPrimary)
                
                Spacer()
                
                Text("\(securityScanner.outdatedApps.count) found")
                    .font(.system(size: 12))
                    .foregroundColor(.smartMacTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.smartMacWarning.opacity(0.2))
                    .cornerRadius(8)
            }
            
            ForEach(securityScanner.outdatedApps) { app in
                OutdatedAppRow(app: app)
            }
        }
        .padding(20)
        .background(Color.smartMacCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Score Breakdown Row
struct ScoreBreakdownRow: View {
    let icon: String
    let color: Color
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.smartMacTextSecondary)
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.smartMacTextPrimary)
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: SecurityCategory
    let checks: [SecurityCheck]
    let isExpanded: Bool
    let onTap: () -> Void
    
    private var passedCount: Int {
        checks.filter { $0.status == .passed }.count
    }
    
    private var categoryColor: Color {
        switch category.color {
        case "AccentBlue": return .smartMacAccentBlue
        case "AccentGreen": return .smartMacAccentGreen
        default: return .smartMacWarning
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(categoryColor)
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                
                Text("\(passedCount)/\(checks.count) passed")
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextTertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isExpanded ? categoryColor.opacity(0.2) : Color.smartMacCardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isExpanded ? categoryColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Security Check Row
struct SecurityCheckRow: View {
    let check: SecurityCheck
    let onFix: () -> Void
    
    @State private var isExpanded = false
    
    private var statusColor: Color {
        switch check.status {
        case .passed: return .smartMacSuccess
        case .warning: return .smartMacWarning
        case .failed: return .smartMacDanger
        case .checking: return .smartMacTextTertiary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    if check.status == .checking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: check.status.icon)
                            .font(.system(size: 16))
                            .foregroundColor(statusColor)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smartMacTextPrimary)
                    
                    if let details = check.details {
                        Text(details)
                            .font(.system(size: 12))
                            .foregroundColor(.smartMacTextSecondary)
                    }
                }
                
                Spacer()
                
                // Actions
                if check.actionURL != nil && check.status != .passed {
                    Button(action: onFix) {
                        Text("Fix")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(statusColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Expand Button
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(check.description)
                        .font(.system(size: 12))
                        .foregroundColor(.smartMacTextSecondary)
                    
                    if let recommendation = check.recommendation, check.status != .passed {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.smartMacWarning)
                            Text(recommendation)
                                .font(.system(size: 12))
                                .foregroundColor(.smartMacTextSecondary)
                        }
                        .padding(10)
                        .background(Color.smartMacWarning.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.leading, 48)
            }
        }
        .padding(12)
        .background(Color.smartMacSecondaryBg.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Outdated App Row
struct OutdatedAppRow: View {
    let app: OutdatedAppInfo
    @State private var isUpdating = false
    @State private var updateStatus: UpdateStatus = .idle
    
    enum UpdateStatus {
        case idle
        case updating
        case success
        case failed(String)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            if let icon = NSWorkspace.shared.icon(forFile: app.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacTextPrimary)
                
                HStack(spacing: 12) {
                    Text("v\(app.currentVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                    
                    Text("Last updated: \(app.formattedLastUpdated)")
                        .font(.system(size: 11))
                        .foregroundColor(.smartMacTextTertiary)
                }
            }
            
            Spacer()
            
            // Update Now Button
            Button(action: { updateApp() }) {
                HStack(spacing: 4) {
                    if case .updating = updateStatus {
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if case .success = updateStatus {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                    }
                    Text(updateButtonText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(updateButtonColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isUpdating)
            
            if let days = app.daysSinceUpdate {
                Text("\(days) days ago")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.smartMacWarning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.smartMacWarning.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(10)
        .background(Color.smartMacSecondaryBg.opacity(0.3))
        .cornerRadius(10)
    }
    
    private var updateButtonText: String {
        switch updateStatus {
        case .idle: return "Update"
        case .updating: return "Opening..."
        case .success: return "Opened"
        case .failed: return "Update"
        }
    }
    
    private var updateButtonColor: Color {
        switch updateStatus {
        case .success: return .smartMacSuccess
        case .failed: return .smartMacDanger
        default: return .smartMacAccentBlue
        }
    }
    
    private func updateApp() {
        updateStatus = .updating
        isUpdating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = performUpdate()
            
            DispatchQueue.main.async {
                updateStatus = success ? .success : .failed("Could not open updater")
                isUpdating = false
                
                // Reset status after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    updateStatus = .idle
                }
            }
        }
    }
    
    private func performUpdate() -> Bool {
        // Strategy 1: Check if it's a Mac App Store app
        if isMacAppStoreApp() {
            return openInAppStore()
        }
        
        // Strategy 2: Try to trigger Sparkle updater if available
        if triggerSparkleUpdate() {
            return true
        }
        
        // Strategy 3: Launch the app (many apps check for updates on launch)
        return launchAppForUpdate()
    }
    
    private func isMacAppStoreApp() -> Bool {
        let receiptPath = "\(app.path)/Contents/_MASReceipt/receipt"
        return FileManager.default.fileExists(atPath: receiptPath)
    }
    
    private func openInAppStore() -> Bool {
        // Try to open the app's App Store page using bundle ID
        if !app.bundleIdentifier.isEmpty {
            // Open Mac App Store to the app's page
            if let url = URL(string: "macappstore://showUpdatesPage") {
                NSWorkspace.shared.open(url)
                return true
            }
        }
        return false
    }
    
    private func triggerSparkleUpdate() -> Bool {
        // Check if app uses Sparkle framework
        let sparklePath = "\(app.path)/Contents/Frameworks/Sparkle.framework"
        let sparkle2Path = "\(app.path)/Contents/Frameworks/Sparkle.framework/Versions/B"
        
        if FileManager.default.fileExists(atPath: sparklePath) ||
           FileManager.default.fileExists(atPath: sparkle2Path) {
            // Launch app and send check-for-updates command via AppleScript
            let script = """
            tell application "\(app.name)"
                activate
            end tell
            delay 1
            tell application "System Events"
                tell process "\(app.name)"
                    try
                        click menu item "Check for Updates…" of menu 1 of menu bar item "\(app.name)" of menu bar 1
                    on error
                        try
                            click menu item "Check for Updates" of menu 1 of menu bar item "Help" of menu bar 1
                        end try
                    end try
                end tell
            end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                return error == nil
            }
        }
        return false
    }
    
    private func launchAppForUpdate() -> Bool {
        // Simply launch the app - many apps check for updates on launch
        let url = URL(fileURLWithPath: app.path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            success = error == nil
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 3)
        return success
    }
}

