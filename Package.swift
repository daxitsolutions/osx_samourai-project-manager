// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SamouraiProjectManager",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "SamouraiProjectManager",
            targets: ["SamouraiProjectManagerApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SamouraiProjectManagerApp",
            path: "Sources/SamouraiProjectManagerApp"
        )
    ]
)
