// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Demark",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Demark",
            targets: ["Demark"]
        ),
    ],
    dependencies: [
        // No external dependencies - uses only WebKit and Foundation
    ],
    targets: [
        .target(
            name: "Demark",
            dependencies: [],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DemarkTests",
            dependencies: ["Demark"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
