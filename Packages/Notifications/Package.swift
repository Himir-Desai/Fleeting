// swift-tools-version: 6.0

import PackageDescription

/// Scheduling and background composition of the app's three permitted notifications.
let package = Package(
    name: "Notifications",
    platforms: [.iOS("26.0"), .macOS("14.0")],
    products: [
        .library(name: "Notifications", targets: ["Notifications"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Intelligence")
    ],
    targets: [
        .target(name: "Notifications", dependencies: ["Core", "Intelligence"]),
        .testTarget(name: "NotificationsTests", dependencies: ["Notifications", "Core"])
    ]
)
