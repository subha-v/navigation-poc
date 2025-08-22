#!/bin/bash

echo "Creating iOS App Project for NavigationPoC..."

# Create a simple iOS app project structure
cd "/Users/subha/Downloads/VALUENEX/Navigation PoC"

# Create new app directory
mkdir -p NavigationPoCApp
cd NavigationPoCApp

# Create basic iOS app with SwiftUI
cat > NavigationPoCApp.swift << 'EOF'
import SwiftUI

@main
struct NavigationPoCAppWrapper: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct MainView: View {
    var body: some View {
        Text("App will load NavigationPoC package here")
            .padding()
    }
}
EOF

# Create simple Package.swift for the app
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavigationPoCApp",
    platforms: [.iOS(.v16)],
    products: [
        .executable(name: "NavigationPoCApp", targets: ["NavigationPoCApp"])
    ],
    dependencies: [
        .package(path: "../NavigationPoC")
    ],
    targets: [
        .executableTarget(
            name: "NavigationPoCApp",
            dependencies: [
                .product(name: "NavigationPoC", package: "NavigationPoC")
            ]
        )
    ]
)
EOF

echo "✅ Created app wrapper project"
echo ""
echo "Now:"
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. Choose iOS > App"
echo "4. Name it 'NavigationPoCApp'"
echo "5. Save it in the 'Navigation PoC' folder"
echo "6. Then follow the instructions in setup_xcode.md"