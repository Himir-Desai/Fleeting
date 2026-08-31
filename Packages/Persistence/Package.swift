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
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Core"]),
        // Its own bundle, and so its own process: these tests open containers for *old* schema
        // versions, and SwiftData binds an entity name to one class per process. Sharing a
        // process with the other suites let version 1's entity — which has no `isLive` column —
        // answer their queries, and every archived thought silently came back live.
        .testTarget(name: "SchemaMigrationTests", dependencies: ["Persistence", "Core"])
    ]
)
