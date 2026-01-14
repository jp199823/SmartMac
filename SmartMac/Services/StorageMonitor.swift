import Foundation

/// Storage monitoring using FileManager
struct StorageMonitor {
    
    static func getStorageMetrics(for path: String = "/") -> StorageMetrics {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            
            let total = (attributes[.systemSize] as? UInt64) ?? 0
            let free = (attributes[.systemFreeSize] as? UInt64) ?? 0
            let used = total - free
            
            // Get volume name
            let volumeName = getVolumeName(for: path)
            
            return StorageMetrics(
                volumeName: volumeName,
                mountPoint: path,
                total: total,
                free: free,
                used: used
            )
        } catch {
            return .empty
        }
    }
    
    static func getAllVolumes() -> [StorageMetrics] {
        var volumes: [StorageMetrics] = []
        
        // Always include root volume
        volumes.append(getStorageMetrics(for: "/"))
        
        // Check for additional mounted volumes
        let volumesPath = "/Volumes"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: volumesPath) {
            for volume in contents {
                let path = "\(volumesPath)/\(volume)"
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    // Skip the main volume symlink
                    if volume != "Macintosh HD" {
                        volumes.append(getStorageMetrics(for: path))
                    }
                }
            }
        }
        
        return volumes
    }
    
    private static func getVolumeName(for path: String) -> String {
        if path == "/" {
            // Get the boot volume name
            if let url = URL(string: "file:///"),
               let values = try? url.resourceValues(forKeys: [.volumeNameKey]),
               let name = values.volumeName {
                return name
            }
            return "Macintosh HD"
        }
        
        // Extract volume name from path
        let components = path.split(separator: "/")
        if components.count >= 2 && components[0] == "Volumes" {
            return String(components[1])
        }
        
        return path
    }
}
