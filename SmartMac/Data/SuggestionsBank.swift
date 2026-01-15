import Foundation

/// Bank of optimization suggestions with trigger conditions
struct SuggestionsBank {
    
    static let allSuggestions: [Suggestion] = [
        // MARK: - Memory Suggestions
        Suggestion(
            title: "High Memory Usage Detected",
            description: "Your Mac is using more than 85% of available RAM. Consider closing unused applications to free up memory and improve performance.",
            category: .memory,
            priority: .high,
            icon: "memorychip.fill",
            actionLabel: "View Apps"
        ) { monitor in
            monitor.memoryMetrics.usagePercentage > 85
        },
        
        Suggestion(
            title: "Memory Pressure Building",
            description: "RAM usage is above 70%. Your Mac may start using swap memory soon, which can slow things down.",
            category: .memory,
            priority: .medium,
            icon: "memorychip",
            actionLabel: nil
        ) { monitor in
            monitor.memoryMetrics.usagePercentage > 70 && monitor.memoryMetrics.usagePercentage <= 85
        },
        
        Suggestion(
            title: "Heavy Memory Compression",
            description: "Your Mac is compressing a significant amount of memory. This helps but can impact performance during intensive tasks.",
            category: .memory,
            priority: .medium,
            icon: "arrow.down.right.and.arrow.up.left",
            actionLabel: nil
        ) { monitor in
            let compressedRatio = Double(monitor.memoryMetrics.compressed) / Double(max(monitor.memoryMetrics.total, 1))
            return compressedRatio > 0.15
        },
        
        // MARK: - Storage Suggestions
        Suggestion(
            title: "Critical: Low Storage Space",
            description: "Less than 5% storage remaining! Your Mac needs at least 10-15% free space to function properly. Delete files or move them to external storage immediately.",
            category: .storage,
            priority: .critical,
            icon: "externaldrive.badge.exclamationmark",
            actionLabel: "Open Storage"
        ) { monitor in
            monitor.storageMetrics.freePercentage < 5
        },
        
        Suggestion(
            title: "Storage Running Low",
            description: "Less than 10% storage space remaining. Consider clearing cache files, emptying Trash, or removing unused applications.",
            category: .storage,
            priority: .high,
            icon: "internaldrive.fill",
            actionLabel: "Open Storage"
        ) { monitor in
            monitor.storageMetrics.freePercentage >= 5 && monitor.storageMetrics.freePercentage < 10
        },
        
        Suggestion(
            title: "Consider Freeing Storage",
            description: "Storage is below 20% free. For optimal performance, keep at least 15-20% of your drive free.",
            category: .storage,
            priority: .medium,
            icon: "internaldrive",
            actionLabel: nil
        ) { monitor in
            monitor.storageMetrics.freePercentage >= 10 && monitor.storageMetrics.freePercentage < 20
        },
        
        Suggestion(
            title: "Empty Your Trash",
            description: "Regularly emptying your Trash can free up significant storage space. Files in Trash still take up disk space.",
            category: .storage,
            priority: .low,
            icon: "trash",
            actionLabel: nil
        ) { _ in
            // Always show as a general tip when storage is not critical
            true
        },
        
        // MARK: - Performance/CPU Suggestions
        Suggestion(
            title: "Mac Running Hot",
            description: "Your Mac's thermal state is Critical. Reduce intensive tasks, ensure proper ventilation, and consider closing resource-heavy applications.",
            category: .performance,
            priority: .critical,
            icon: "thermometer.sun.fill",
            actionLabel: nil
        ) { monitor in
            monitor.cpuMetrics.thermalState == .critical
        },
        
        Suggestion(
            title: "Elevated Temperature",
            description: "Your Mac is running warmer than usual (Serious thermal state). Consider taking a break from intensive tasks.",
            category: .performance,
            priority: .high,
            icon: "thermometer.medium",
            actionLabel: nil
        ) { monitor in
            monitor.cpuMetrics.thermalState == .serious
        },
        
        Suggestion(
            title: "CPU Under Heavy Load",
            description: "CPU usage is above 80%. This is normal during intensive tasks but may slow down other applications.",
            category: .performance,
            priority: .medium,
            icon: "cpu",
            actionLabel: nil
        ) { monitor in
            monitor.cpuMetrics.usagePercentage > 80
        },
        
        Suggestion(
            title: "Many Applications Running",
            description: "You have many apps open. Closing unused apps can improve overall system responsiveness.",
            category: .performance,
            priority: .low,
            icon: "square.grid.2x2",
            actionLabel: nil
        ) { monitor in
            monitor.topApplications.count >= 5
        },
        
        // MARK: - Battery Suggestions
        Suggestion(
            title: "Battery Critically Low",
            description: "Battery below 10%. Connect to power soon to avoid unexpected shutdown.",
            category: .battery,
            priority: .critical,
            icon: "battery.0",
            actionLabel: nil
        ) { monitor in
            monitor.batteryMetrics.isPresent && 
            !monitor.batteryMetrics.isCharging && 
            monitor.batteryMetrics.chargePercentage < 10
        },
        
        Suggestion(
            title: "Battery Running Low",
            description: "Battery below 20%. Consider connecting to power or reducing screen brightness and closing unused apps.",
            category: .battery,
            priority: .high,
            icon: "battery.25",
            actionLabel: nil
        ) { monitor in
            monitor.batteryMetrics.isPresent && 
            !monitor.batteryMetrics.isCharging && 
            monitor.batteryMetrics.chargePercentage < 20 &&
            monitor.batteryMetrics.chargePercentage >= 10
        },
        
        Suggestion(
            title: "High Battery Cycle Count",
            description: "Your battery has over 500 charge cycles. Consider having the battery health checked if you notice reduced battery life.",
            category: .battery,
            priority: .low,
            icon: "battery.100",
            actionLabel: nil
        ) { monitor in
            monitor.batteryMetrics.isPresent && monitor.batteryMetrics.cycleCount > 500
        },
        
        // MARK: - Maintenance Suggestions
        Suggestion(
            title: "Restart Recommended",
            description: "Regular restarts help clear memory, apply system updates, and resolve minor issues. Consider restarting if you haven't in a while.",
            category: .maintenance,
            priority: .low,
            icon: "arrow.clockwise",
            actionLabel: nil
        ) { _ in
            // Show occasionally as general maintenance tip
            Int.random(in: 0...10) == 0
        },
        
        Suggestion(
            title: "Check for Updates",
            description: "Keeping macOS and apps updated ensures you have the latest performance improvements and security fixes.",
            category: .maintenance,
            priority: .low,
            icon: "arrow.down.circle",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Review Login Items",
            description: "Too many apps launching at startup can slow down your Mac. Review and disable unnecessary login items in System Settings.",
            category: .maintenance,
            priority: .low,
            icon: "person.badge.key",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Clear Browser Cache",
            description: "Web browsers can accumulate large caches over time. Clearing browser data periodically can free up storage and improve browser performance.",
            category: .maintenance,
            priority: .low,
            icon: "safari",
            actionLabel: nil
        ) { _ in
            true
        },
        
        // MARK: - Network Suggestions
        Suggestion(
            title: "No Network Connection",
            description: "Your Mac is not connected to the internet. Check your Wi-Fi or Ethernet connection.",
            category: .network,
            priority: .medium,
            icon: "wifi.slash",
            actionLabel: nil
        ) { monitor in
            !monitor.networkMetrics.isConnected
        },
        
        Suggestion(
            title: "Using Wired Connection",
            description: "You're connected via Ethernet, which typically provides faster and more stable internet than Wi-Fi.",
            category: .network,
            priority: .low,
            icon: "cable.connector",
            actionLabel: nil
        ) { monitor in
            monitor.networkMetrics.connectionType == "Ethernet"
        },
        
        // MARK: - General Optimization Tips
        Suggestion(
            title: "Enable Optimized Storage",
            description: "macOS can automatically store older files in iCloud and remove local copies when space is low. Enable this in System Settings > General > Storage.",
            category: .storage,
            priority: .low,
            icon: "icloud.and.arrow.up",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Use Activity Monitor",
            description: "Activity Monitor shows detailed CPU, memory, energy, disk, and network usage. Use it to identify resource-heavy processes.",
            category: .performance,
            priority: .low,
            icon: "chart.bar.xaxis",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Reduce Visual Effects",
            description: "Disabling transparency and motion effects in System Settings > Accessibility > Display can improve performance on older Macs.",
            category: .performance,
            priority: .low,
            icon: "sparkles",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Manage Desktop Files",
            description: "Too many files on your Desktop can slow down Finder. Consider organizing files into folders or using Stacks.",
            category: .maintenance,
            priority: .low,
            icon: "folder",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Check Energy Settings",
            description: "Adjust energy settings to balance performance and battery life. Higher performance uses more power.",
            category: .battery,
            priority: .low,
            icon: "bolt.circle",
            actionLabel: nil
        ) { monitor in
            monitor.batteryMetrics.isPresent
        },
        
        Suggestion(
            title: "Disk First Aid",
            description: "Run Disk First Aid periodically to check and repair disk errors. Open Disk Utility and select First Aid for your drive.",
            category: .maintenance,
            priority: .low,
            icon: "stethoscope",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Reset SMC if Needed",
            description: "If you experience fan issues, battery problems, or performance anomalies, resetting the SMC might help. Search 'Reset SMC Mac' for instructions.",
            category: .maintenance,
            priority: .low,
            icon: "gearshape.2",
            actionLabel: nil
        ) { _ in
            // Only show occasionally
            Int.random(in: 0...20) == 0
        },
        
        Suggestion(
            title: "Good System Health",
            description: "Your Mac is running well! Keep up the good maintenance habits.",
            category: .performance,
            priority: .low,
            icon: "checkmark.seal.fill",
            actionLabel: nil
        ) { monitor in
            monitor.overallHealth == .excellent
        },
        
        // MARK: - Google Chrome Optimization Tips
        Suggestion(
            title: "Reduce Chrome Memory Usage",
            description: "Chrome uses memory for each open tab. Close unused tabs, use tab suspension extensions like 'The Great Suspender', or enable Chrome's built-in Memory Saver in Settings > Performance.",
            category: .memory,
            priority: .low,
            icon: "globe",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Chrome Battery Optimization",
            description: "Reduce Chrome's battery drain by enabling 'Energy Saver' mode in Settings > Performance, blocking auto-playing videos, and limiting background tabs. Consider using Safari for better battery life.",
            category: .battery,
            priority: .low,
            icon: "bolt.badge.clock",
            actionLabel: nil
        ) { monitor in
            monitor.batteryMetrics.isPresent
        },
        
        Suggestion(
            title: "Disable Chrome Extensions",
            description: "Unused Chrome extensions consume memory and CPU. Review your extensions at chrome://extensions and remove or disable ones you don't actively use.",
            category: .performance,
            priority: .low,
            icon: "puzzlepiece.extension",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Chrome Hardware Acceleration",
            description: "Enable Hardware Acceleration in Chrome Settings > System to offload graphics work to your GPU, reducing CPU usage and improving performance on video-heavy sites.",
            category: .performance,
            priority: .low,
            icon: "cpu",
            actionLabel: nil
        ) { _ in
            true
        },
        
        // MARK: - Finder Optimization Tips
        Suggestion(
            title: "Optimize Finder Performance",
            description: "Speed up Finder by disabling 'Calculate all sizes' in View Options (Cmd+J) for large folders. Also disable 'Show icon preview' for folders with many files.",
            category: .performance,
            priority: .low,
            icon: "folder.badge.gearshape",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Reduce Finder Memory Usage",
            description: "Finder can accumulate memory over time. Force quit and relaunch Finder periodically via Activity Monitor, or use Option+Right-click on Finder icon in Dock and select 'Relaunch'.",
            category: .memory,
            priority: .low,
            icon: "arrow.clockwise.circle",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Clean Up Recent Items",
            description: "Finder tracks recent files and folders which uses resources. Clear recent items in Apple Menu > Recent Items > Clear Menu, or reduce the count in System Settings > Desktop & Dock.",
            category: .maintenance,
            priority: .low,
            icon: "clock.arrow.circlepath",
            actionLabel: nil
        ) { _ in
            true
        },
        
        Suggestion(
            title: "Optimize Finder Sidebar",
            description: "Remove unused locations from Finder's sidebar. Too many smart folders or network locations can slow Finder as it checks their status. Customize via Finder > Settings > Sidebar.",
            category: .performance,
            priority: .low,
            icon: "sidebar.left",
            actionLabel: nil
        ) { _ in
            true
        }
    ]
    
    /// Get relevant suggestions based on current system state
    static func getRelevantSuggestions(for monitor: SystemMonitor, limit: Int = 5) -> [Suggestion] {
        var relevant = allSuggestions.filter { $0.isRelevant(for: monitor) }
        
        // Sort by priority (highest first)
        relevant.sort { $0.priority > $1.priority }
        
        // Remove duplicate categories for lower priority items
        var seenCategories: Set<SuggestionCategory> = []
        var filtered: [Suggestion] = []
        
        for suggestion in relevant {
            // Always include high/critical priority
            if suggestion.priority >= .high {
                filtered.append(suggestion)
                seenCategories.insert(suggestion.category)
            } else if !seenCategories.contains(suggestion.category) {
                // Only one low/medium suggestion per category
                filtered.append(suggestion)
                seenCategories.insert(suggestion.category)
            }
            
            if filtered.count >= limit {
                break
            }
        }
        
        return Array(filtered.prefix(limit))
    }
}
