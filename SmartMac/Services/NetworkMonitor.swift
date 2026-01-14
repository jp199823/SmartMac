import Foundation
import SystemConfiguration
import Network

/// Network monitoring
struct NetworkMonitor {
    
    static func getNetworkMetrics() -> NetworkMetrics {
        let ipAddress = getIPAddress() ?? "N/A"
        let connectionType = getConnectionType()
        let isConnected = connectionType != "None" && ipAddress != "N/A"
        
        // Get network stats
        let (bytesReceived, bytesSent) = getNetworkStats()
        
        return NetworkMetrics(
            isConnected: isConnected,
            connectionType: connectionType,
            ipAddress: ipAddress,
            bytesReceived: bytesReceived,
            bytesSent: bytesSent
        )
    }
    
    // MARK: - IP Address
    private static func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Check for IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                
                // Prefer en0 (Wi-Fi) or en1 (Ethernet)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        return address
    }
    
    // MARK: - Connection Type
    private static func getConnectionType() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return "None"
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var hasWiFi = false
        var hasEthernet = false
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            
            // Check if interface is up and running
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            
            if isUp && isRunning {
                if name == "en0" {
                    hasWiFi = true
                } else if name == "en1" || name.hasPrefix("en") {
                    // Check if it might be ethernet
                    if !hasWiFi {
                        hasEthernet = true
                    }
                }
            }
        }
        
        if hasWiFi {
            return "Wi-Fi"
        } else if hasEthernet {
            return "Ethernet"
        }
        
        return "None"
    }
    
    // MARK: - Network Stats
    private static func getNetworkStats() -> (received: UInt64, sent: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Only count link-level addresses (AF_LINK)
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                
                // Only count main interfaces
                if name.hasPrefix("en") || name.hasPrefix("lo") {
                    if let data = interface.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalReceived += UInt64(networkData.ifi_ibytes)
                        totalSent += UInt64(networkData.ifi_obytes)
                    }
                }
            }
        }
        
        return (totalReceived, totalSent)
    }
}
