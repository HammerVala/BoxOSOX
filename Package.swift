// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "BoxOSOX",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "BoxOSOX",
            targets: ["BoxOSOX"]),
    ],
    dependencies: [
        // Core dependencies will be added as needed
    ],
    targets: [
        .target(
            name: "BoxOSOX",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "BoxOSOXTests",
            dependencies: ["BoxOSOX"],
            path: "Tests"),
    ]
) 