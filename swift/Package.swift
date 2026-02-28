// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DawnAgent",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // Library — import into your iOS/macOS app
        .library(
            name: "DawnAgentCore",
            targets: ["DawnAgentCore"]
        ),
        // CLI — run on Mac for local testing without a full app
        .executable(
            name: "DawnAgentCLI",
            targets: ["DawnAgentCLI"]
        ),
    ],
    targets: [
        .target(
            name: "DawnAgentCore",
            path: "Sources/DawnAgentCore"
        ),
        .executableTarget(
            name: "DawnAgentCLI",
            dependencies: ["DawnAgentCore"],
            path: "Sources/DawnAgentCLI"
        ),
    ]
)
