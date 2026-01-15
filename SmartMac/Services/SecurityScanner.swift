import Foundation
import AppKit

/// Security Scanner - System security assessment
class SecurityScanner: ObservableObject {
    static let shared = SecurityScanner()
    
    // MARK: - Published Properties
    @Published var checks: [SecurityCheck] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    @Published var outdatedApps: [OutdatedAppInfo] = []
    
    // MARK: - Computed Properties
    var securityScore: SecurityScore {
        let passed = checks.filter { $0.status == .passed }.count
        let warnings = checks.filter { $0.status == .warning }.count
        let failed = checks.filter { $0.status == .failed }.count
        let total = checks.count
        
        guard total > 0 else {
            return SecurityScore(score: 0, passedChecks: 0, warningChecks: 0, failedChecks: 0, totalChecks: 0)
        }
        
        // Score: passed = 100%, warning = 50%, failed = 0%
        let score = Int((Double(passed * 100 + warnings * 50) / Double(total * 100)) * 100)
        
        return SecurityScore(
            score: score,
            passedChecks: passed,
            warningChecks: warnings,
            failedChecks: failed,
            totalChecks: total
        )
    }
    
    var checksByCategory: [SecurityCategory: [SecurityCheck]] {
        Dictionary(grouping: checks, by: { $0.category })
    }
    
    // MARK: - Initialization
    private init() {
        initializeChecks()
    }
    
    // MARK: - Initialize Checks
    private func initializeChecks() {
        checks = [
            // System Checks
            SecurityCheck(
                name: "FileVault Encryption",
                category: .system,
                description: "Full-disk encryption protects your data if your Mac is lost or stolen.",
                recommendation: "Enable FileVault in System Settings > Privacy & Security.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?FDE")
            ),
            SecurityCheck(
                name: "Firewall",
                category: .system,
                description: "The firewall blocks unwanted incoming network connections.",
                recommendation: "Enable the firewall in System Settings > Network > Firewall.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Firewall")
            ),
            SecurityCheck(
                name: "Gatekeeper",
                category: .system,
                description: "Gatekeeper prevents running apps from unidentified developers.",
                recommendation: "Keep Gatekeeper enabled for maximum security.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?General")
            ),
            SecurityCheck(
                name: "System Integrity Protection",
                category: .system,
                description: "SIP protects critical system files from modification.",
                recommendation: "SIP should always be enabled unless you have a specific need to disable it."
            ),
            SecurityCheck(
                name: "Automatic Updates",
                category: .system,
                description: "Keeping macOS updated ensures you have the latest security patches.",
                recommendation: "Enable automatic updates in System Settings > General > Software Update.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.Software-Update-Preferences.extension")
            ),
            
            // App Checks
            SecurityCheck(
                name: "Outdated Applications",
                category: .apps,
                description: "Applications that haven't been updated recently may contain security vulnerabilities.",
                recommendation: "Update or remove applications that haven't been updated in over a year."
            ),
            SecurityCheck(
                name: "Unsigned Applications",
                category: .apps,
                description: "Unsigned apps may pose security risks as they haven't been verified by Apple.",
                recommendation: "Consider removing unsigned applications or verifying their source."
            ),
            
            // Privacy Checks
            SecurityCheck(
                name: "Screen Recording Access",
                category: .privacy,
                description: "Apps with screen recording access can capture everything on your screen.",
                recommendation: "Review which apps have screen recording permission.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            ),
            SecurityCheck(
                name: "Full Disk Access",
                category: .privacy,
                description: "Apps with full disk access can read all files on your computer.",
                recommendation: "Only grant full disk access to trusted applications.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
            ),
            SecurityCheck(
                name: "Location Services",
                category: .privacy,
                description: "Review which apps can access your location.",
                recommendation: "Disable location access for apps that don't need it.",
                actionURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
            )
        ]
    }
    
    // MARK: - Run Full Scan
    func runFullScan() {
        guard !isScanning else { return }
        
        isScanning = true
        
        // Reset all to checking state
        for i in checks.indices {
            checks[i].status = .checking
        }
        
        // Run checks asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performSystemChecks()
            self?.performAppChecks()
            self?.performPrivacyChecks()
            
            DispatchQueue.main.async {
                self?.isScanning = false
                self?.lastScanDate = Date()
            }
        }
    }
    
    // MARK: - System Checks
    private func performSystemChecks() {
        // FileVault Check
        let fileVaultStatus = runShellCommand("fdesetup status")
        updateCheck(named: "FileVault Encryption") { check in
            if fileVaultStatus.contains("FileVault is On") {
                check.status = .passed
                check.details = "FileVault is enabled"
            } else {
                check.status = .failed
                check.details = "FileVault is disabled"
            }
        }
        
        // Firewall Check
        let firewallStatus = runShellCommand("defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo 0")
        updateCheck(named: "Firewall") { check in
            let state = Int(firewallStatus.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            if state > 0 {
                check.status = .passed
                check.details = "Firewall is enabled"
            } else {
                check.status = .warning
                check.details = "Firewall is disabled"
            }
        }
        
        // Gatekeeper Check
        let gatekeeperStatus = runShellCommand("spctl --status 2>&1")
        updateCheck(named: "Gatekeeper") { check in
            if gatekeeperStatus.contains("enabled") {
                check.status = .passed
                check.details = "Gatekeeper is enabled"
            } else {
                check.status = .failed
                check.details = "Gatekeeper is disabled"
            }
        }
        
        // SIP Check
        let sipStatus = runShellCommand("csrutil status 2>&1")
        updateCheck(named: "System Integrity Protection") { check in
            if sipStatus.contains("enabled") {
                check.status = .passed
                check.details = "SIP is enabled"
            } else {
                check.status = .failed
                check.details = "SIP is disabled"
            }
        }
        
        // Automatic Updates Check
        let autoUpdateStatus = runShellCommand("defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo 0")
        updateCheck(named: "Automatic Updates") { check in
            let enabled = Int(autoUpdateStatus.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            if enabled > 0 {
                check.status = .passed
                check.details = "Automatic updates are enabled"
            } else {
                check.status = .warning
                check.details = "Automatic updates are disabled"
            }
        }
    }
    
    // MARK: - App Checks
    private func performAppChecks() {
        // Scan for outdated apps
        outdatedApps = scanForOutdatedApps()
        
        updateCheck(named: "Outdated Applications") { [self] check in
            if self.outdatedApps.isEmpty {
                check.status = .passed
                check.details = "All applications are up to date"
            } else {
                check.status = .warning
                check.details = "\(self.outdatedApps.count) application(s) may need updates"
            }
        }
        
        // Scan for unsigned apps
        let unsignedCount = countUnsignedApps()
        updateCheck(named: "Unsigned Applications") { check in
            if unsignedCount == 0 {
                check.status = .passed
                check.details = "No unsigned applications found"
            } else if unsignedCount <= 3 {
                check.status = .warning
                check.details = "\(unsignedCount) unsigned application(s) found"
            } else {
                check.status = .failed
                check.details = "\(unsignedCount) unsigned applications found"
            }
        }
    }
    
    // MARK: - Privacy Checks
    private func performPrivacyChecks() {
        // These are informational checks - we can't determine exact app counts without TCC access
        let privacyChecks = ["Screen Recording Access", "Full Disk Access", "Location Services"]
        
        for checkName in privacyChecks {
            updateCheck(named: checkName) { check in
                // Mark as informational - user should review
                check.status = .warning
                check.details = "Review apps with this permission"
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateCheck(named name: String, update: @escaping (inout SecurityCheck) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let index = self?.checks.firstIndex(where: { $0.name == name }) {
                update(&self!.checks[index])
            }
        }
    }
    
    private func runShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func scanForOutdatedApps() -> [OutdatedAppInfo] {
        var outdated: [OutdatedAppInfo] = []
        let fileManager = FileManager.default
        let appsPath = "/Applications"
        
        guard let apps = try? fileManager.contentsOfDirectory(atPath: appsPath) else {
            return outdated
        }
        
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        
        for app in apps where app.hasSuffix(".app") {
            let appPath = "\(appsPath)/\(app)"
            let plistPath = "\(appPath)/Contents/Info.plist"
            
            guard let plistData = fileManager.contents(atPath: plistPath),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                continue
            }
            
            let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
            let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"
            let name = plist["CFBundleName"] as? String ?? app.replacingOccurrences(of: ".app", with: "")
            
            // Check modification date
            if let attrs = try? fileManager.attributesOfItem(atPath: appPath),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < oneYearAgo {
                outdated.append(OutdatedAppInfo(
                    name: name,
                    bundleIdentifier: bundleId,
                    currentVersion: version,
                    lastUpdated: modDate,
                    path: appPath
                ))
            }
        }
        
        return outdated
    }
    
    private func countUnsignedApps() -> Int {
        let fileManager = FileManager.default
        let appsPath = "/Applications"
        var unsignedCount = 0
        
        guard let apps = try? fileManager.contentsOfDirectory(atPath: appsPath) else {
            return 0
        }
        
        for app in apps.prefix(20) where app.hasSuffix(".app") {
            let appPath = "\(appsPath)/\(app)"
            let result = runShellCommand("codesign -v \"\(appPath)\" 2>&1")
            
            if result.contains("not signed") || result.contains("invalid signature") {
                unsignedCount += 1
            }
        }
        
        return unsignedCount
    }
    
    // MARK: - Actions
    func openSystemPreferences(for check: SecurityCheck) {
        guard let url = check.actionURL else { return }
        NSWorkspace.shared.open(url)
    }
}
