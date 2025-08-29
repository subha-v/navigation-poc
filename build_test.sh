#!/bin/bash

echo "Testing VNXNavigationApp build with new UI components..."

cd "/Users/subha/Downloads/VALUENEX/Navigation PoC/VNXNavigationApp/VNXNavigationApp"

# Clean build folder
xcodebuild clean -scheme VNXNavigationApp

# Try to build
echo "Building project..."
xcodebuild build \
  -scheme VNXNavigationApp \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath /tmp/VNXBuild \
  2>&1 | grep -E "(error:|warning:|SUCCEEDED|FAILED|Compiling)"

echo "Build test complete."