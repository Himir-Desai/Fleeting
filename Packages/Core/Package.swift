// swift-tools-version: 6.2

import PackageDescription

/// The domain layer. This package deliberately declares no dependencies:
/// anything `Core` needs from the outside world is expressed as a protocol
/// and implemented by a package above it.
let package = Package(
    name: "Core",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"])
    ]
)
