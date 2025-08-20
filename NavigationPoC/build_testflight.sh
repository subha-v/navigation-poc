#!/bin/bash

# VALUENEX Navigation PoC - TestFlight Build Script
# This script builds and uploads the app to TestFlight

set -e

echo "🚀 Building VALUENEX Navigation PoC for TestFlight"

# Configuration
PROJECT_NAME="NavigationPoC"
SCHEME="NavigationPoC"
BUNDLE_ID="com.valuenex.navigationpoc"
TEAM_ID="YOUR_TEAM_ID"  # Replace with your Apple Team ID

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf build/
mkdir -p build

# Resolve dependencies
echo "📦 Resolving Swift Package dependencies..."
swift package resolve

# Build archive
echo "🔨 Building archive..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -archivePath "build/$PROJECT_NAME.xcarchive" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

# Export IPA
echo "📱 Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "build/$PROJECT_NAME.xcarchive" \
    -exportPath "build/" \
    -exportOptionsPlist "ExportOptions.plist" \
    -allowProvisioningUpdates

# Upload to TestFlight
echo "☁️ Uploading to TestFlight..."
xcrun altool --upload-app \
    -f "build/$PROJECT_NAME.ipa" \
    -t ios \
    --apiKey "YOUR_API_KEY" \
    --apiIssuer "YOUR_ISSUER_ID"

echo "✅ Upload complete! Check App Store Connect for processing status."
echo "📲 TestFlight link will be available once processing is complete."