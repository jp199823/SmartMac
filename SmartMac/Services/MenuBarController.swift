import SwiftUI
import AppKit

/// Controller for managing the macOS menu bar status item
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var systemMonitor: SystemMonitor
    private var eventMonitor: Any?
    
    init(monitor: SystemMonitor) {
        self.systemMonitor = monitor
        setupMenuBar()
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    private func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateButtonTitle()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 320)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView(monitor: systemMonitor, closeAction: { [weak self] in
                self?.closePopover()
            })
        )
        
        // Monitor for clicks outside popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
        
        // Update button periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateButtonTitle()
            }
        }
    }
    
    private func updateButtonTitle() {
        guard let button = statusItem?.button else { return }
        
        let ramUsage = Int(systemMonitor.memoryMetrics.usagePercentage)
        let cpuUsage = Int(systemMonitor.cpuMetrics.usagePercentage)
        
        // Create attributed string with icon and metrics
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "SmartMac")
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(attachment: attachment))
        attributedString.append(NSAttributedString(string: " \(ramUsage)% | \(cpuUsage)%"))
        
        button.attributedTitle = attributedString
    }
    
    @objc private func togglePopover() {
        if let popover = popover, let button = statusItem?.button {
            if popover.isShown {
                closePopover()
            } else {
                // Refresh monitor data before showing
                systemMonitor.refreshAllMetrics()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
    }
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @ObservedObject var monitor: SystemMonitor
    let closeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.smartMacAccentGreen)
                
                Text("SmartMac")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.smartMacCasaBlanca)
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(monitor.overallHealth.color)
                    .frame(width: 8, height: 8)
                
                Text(monitor.overallHealth.label)
                    .font(.system(size: 11))
                    .foregroundColor(.smartMacTextSecondary)
            }
            
            Divider()
            
            // Metrics Grid
            HStack(spacing: 16) {
                // RAM
                metricGauge(
                    value: monitor.memoryMetrics.usagePercentage,
                    label: "RAM",
                    color: gaugeColor(monitor.memoryMetrics.usagePercentage, inverted: true)
                )
                
                // CPU
                metricGauge(
                    value: monitor.cpuMetrics.usagePercentage,
                    label: "CPU",
                    color: gaugeColor(monitor.cpuMetrics.usagePercentage, inverted: true)
                )
                
                // Storage
                let storageUsed = 100 - monitor.storageMetrics.freePercentage
                metricGauge(
                    value: storageUsed,
                    label: "Storage",
                    color: gaugeColor(storageUsed, inverted: true)
                )
            }
            
            Divider()
            
            // Quick Stats
            VStack(spacing: 8) {
                quickStatRow(
                    icon: "memorychip",
                    label: "Free RAM",
                    value: monitor.memoryMetrics.free.formattedBytes
                )
                
                quickStatRow(
                    icon: "internaldrive",
                    label: "Free Storage",
                    value: monitor.storageMetrics.free.formattedBytes
                )
                
                if monitor.batteryMetrics.isPresent {
                    quickStatRow(
                        icon: monitor.batteryMetrics.isCharging ? "bolt.fill" : "battery.100",
                        label: "Battery",
                        value: "\(monitor.batteryMetrics.chargePercentage)%"
                    )
                }
            }
            
            Divider()
            
            // Open App Button
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "SmartMac" || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
                closeAction()
            }) {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open SmartMac")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.smartMacForestGreen)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.smartMacBackground)
    }
    
    // MARK: - Metric Gauge
    private func metricGauge(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.smartMacTextTertiary.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: min(value, 100) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: value)
                
                Text("\(Int(value))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.smartMacCasaBlanca)
            }
            .frame(width: 56, height: 56)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.smartMacTextSecondary)
        }
    }
    
    // MARK: - Quick Stat Row
    private func quickStatRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.smartMacTextTertiary)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.smartMacTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.smartMacCasaBlanca)
        }
    }
    
    // MARK: - Color Helper
    private func gaugeColor(_ value: Double, inverted: Bool) -> Color {
        let effectiveValue = inverted ? value : (100 - value)
        if effectiveValue < 50 { return .smartMacSuccess }
        else if effectiveValue < 75 { return .smartMacWarning }
        else { return .smartMacDanger }
    }
}
