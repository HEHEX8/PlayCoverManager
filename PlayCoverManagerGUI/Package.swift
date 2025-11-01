// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayCoverManagerGUI",
    platforms: [
        .macOS(.v14) // macOS Sonoma 14.0+
    ],
    products: [
        .executable(
            name: "PlayCoverManagerGUI",
            targets: ["PlayCoverManagerGUI"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "PlayCoverManagerGUI",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources/Scripts")
            ]
        ),
    ]
)
