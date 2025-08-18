// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IndoorNavigation",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "IndoorNavigation",
            targets: ["IndoorNavigation"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IndoorNavigation",
            dependencies: [],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "IndoorNavigationTests",
            dependencies: ["IndoorNavigation"]),
    ]
)