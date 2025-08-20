// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavigationPoC",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NavigationPoC",
            targets: ["NavigationPoC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "NavigationPoC",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "NavigationPoCTests",
            dependencies: ["NavigationPoC"]),
    ]
)