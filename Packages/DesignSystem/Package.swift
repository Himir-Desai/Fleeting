// swift-tools-version: 6.0

import PackageDescription

/// The app's visual vocabulary. Depends on nothing but SwiftUI so that tokens
/// can never encode domain knowledge.
let package = Package(
    name: "DesignSystem",
    platforms: [.iOS("26.0"), .macOS("14.0")],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    targets: [
        .target(name: "DesignSystem"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"])
    ]
)
