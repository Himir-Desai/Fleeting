// swift-tools-version: 6.0

import PackageDescription

/// Storage. The only package permitted to know that SwiftData and CloudKit exist.
let package = Package(
    name: "Persistence",
    platforms: [.iOS("26.0"), .macOS("14.0")],
    products: [
        .library(name: "Persistence", targets: ["Persistence"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["Core"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Core"])
    ]
)
