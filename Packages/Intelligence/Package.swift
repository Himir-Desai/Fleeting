// swift-tools-version: 6.0

import PackageDescription

/// Everything AI, behind one protocol with several implementations so the app
/// stays fully functional when no model is available.
let package = Package(
    name: "Intelligence",
    platforms: [.iOS("26.0"), .macOS("14.0")],
    products: [
        .library(name: "Intelligence", targets: ["Intelligence"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(name: "Intelligence", dependencies: ["Core"]),
        .testTarget(name: "IntelligenceTests", dependencies: ["Intelligence", "Core"])
    ]
)
