#!/bin/bash

echo "Creating fresh NavigationPoC iOS app..."

# Create the app directory structure
mkdir -p "VNXNavigationApp"
cd "VNXNavigationApp"

# Create Package.swift for a proper iOS app
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VNXNavigationApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "VNXNavigationApp",
            targets: ["VNXNavigationApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "VNXNavigationApp",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "Sources"
        )
    ]
)
EOF

echo "✅ Created Package.swift with dependencies"

# Create source directory structure
mkdir -p Sources/App
mkdir -p Sources/Models  
mkdir -p Sources/Views
mkdir -p Sources/Services
mkdir -p Sources/Config

echo "✅ Created directory structure"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. Choose iOS > App"
echo "4. Name: VNXNavigationApp"
echo "5. Save in this directory"