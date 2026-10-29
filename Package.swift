// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUsageBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AIUsageBar", targets: ["AIUsageBar"]),
        .executable(name: "UsageCoreCheck", targets: ["UsageCoreCheck"]),
        .executable(name: "UsageProvidersCheck", targets: ["UsageProvidersCheck"]),
    ],
    targets: [
        // Model, normalization, presentation, settings and alerts: Foundation
        // only, so every rule is checked without the UI.
        .target(
            name: "UsageCore",
            path: "Sources/UsageCore"
        ),
        .target(
            name: "UsageProviders",
            dependencies: ["UsageCore"],
            path: "Sources/UsageProviders",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "AIUsageBar",
            dependencies: ["UsageCore", "UsageProviders"],
            path: "Sources/AIUsageBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .executableTarget(
            name: "UsageCoreCheck",
            dependencies: ["UsageCore"],
            path: "Sources/UsageCoreCheck"
        ),
        .executableTarget(
            name: "UsageProvidersCheck",
            dependencies: ["UsageProviders", "UsageCore"],
            path: "Sources/UsageProvidersCheck"
        ),
    ]
)
