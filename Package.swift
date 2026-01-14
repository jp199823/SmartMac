// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SmartMac", targets: ["SmartMac"])
    ],
    targets: [
        .executableTarget(
            name: "SmartMac",
            path: "SmartMac"
        )
    ]
)
