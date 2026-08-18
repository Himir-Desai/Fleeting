// swift-tools-version: 6.0

import PackageDescription

/// One target per feature. Note what is absent: no feature depends on Persistence,
/// and no feature depends on another feature. The dependency rule is enforced here.
let package = Package(
    name: "Features",
    platforms: [.iOS("26.0"), .macOS("14.0")],
    products: [
        .library(name: "CaptureFeature", targets: ["CaptureFeature"]),
        .library(name: "InboxFeature", targets: ["InboxFeature"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DesignSystem")
    ],
    targets: [
        .target(name: "CaptureFeature", dependencies: ["Core", "DesignSystem"]),
        .target(name: "InboxFeature", dependencies: ["Core", "DesignSystem"]),
        .testTarget(name: "CaptureFeatureTests", dependencies: ["CaptureFeature", "Core"]),
        .testTarget(name: "InboxFeatureTests", dependencies: ["InboxFeature", "Core"])
    ]
)
