#!/bin/bash

# Build script for Navigation PoC using XcodeBuildMCP
# This script demonstrates how to build the Xcode projects using the MCP

echo "Building Navigation PoC Xcode Projects"
echo "======================================="

# Build AnchorStation app
echo "Building AnchorStation app..."
npx -y xcodebuildmcp@latest build \
    --project "AnchorStation/AnchorStation.xcodeproj" \
    --scheme "AnchorStation" \
    --configuration "Debug"

# Build IndoorNavigator app (when created)
# echo "Building IndoorNavigator app..."
# npx -y xcodebuildmcp@latest build \
#     --project "IndoorNavigator/IndoorNavigator.xcodeproj" \
#     --scheme "IndoorNavigator" \
#     --configuration "Debug"

echo "Build complete!"