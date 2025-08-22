# TestFlight Setup Guide for VNXNavigationApp

## Prerequisites

Before you begin, ensure you have:
1. **Apple Developer Account** ($99/year) - Required for TestFlight
2. **Xcode 15+** installed
3. **Access to App Store Connect** (comes with developer account)
4. **Two physical iPhones with U1 chip** (iPhone 11 or newer) for testing

## Step 1: Configure App Identifiers & Capabilities

### 1.1 Create App ID in Apple Developer Portal
1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in and navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → **App**
5. Enter:
   - Description: `VNX Navigation App`
   - Bundle ID: `com.valuenex.VNXNavigationApp` (or your organization's bundle ID)
6. Enable capabilities:
   - **Nearby Interaction** ✓ (REQUIRED for UWB)
   - **Push Notifications** (if needed)
7. Click **Continue** → **Register**

### 1.2 Update Xcode Project Settings
1. Open `VNXNavigationApp.xcodeproj` in Xcode
2. Select the project in navigator
3. Select **VNXNavigationApp** target
4. Go to **Signing & Capabilities** tab
5. Enable **Automatically manage signing**
6. Select your **Team** (your developer account)
7. Update **Bundle Identifier** to match the one created above
8. Add capability: Click **+ Capability** → search and add **Nearby Interaction**

## Step 2: Configure Info.plist for Nearby Interaction

1. Open `Info.plist` in Xcode
2. Add the following keys:

```xml
<key>NSNearbyInteractionAllowOnceUsageDescription</key>
<string>This app uses Nearby Interaction to help you navigate to other phones acting as anchors.</string>

<key>NSNearbyInteractionUsageDescription</key>
<string>This app uses Ultra-Wideband technology to measure distance and direction to nearby anchor devices for navigation.</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>nfc</string>
    <string>nearby-interaction</string>
</array>
```

## Step 3: Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - Platform: **iOS**
   - Name: `VNX Navigation`
   - Primary Language: **English**
   - Bundle ID: Select the one you created
   - SKU: `vnxnavigation001` (any unique string)
4. Click **Create**

## Step 4: Build and Archive the App

### 4.1 Set Build Number and Version
1. In Xcode, select the target
2. Go to **General** tab
3. Set:
   - Version: `1.0.0`
   - Build: `1` (increment for each upload)

### 4.2 Select Generic iOS Device
1. In the scheme selector (top bar), change from simulator to **Any iOS Device (arm64)**

### 4.3 Archive the App
1. Menu: **Product** → **Archive**
2. Wait for build to complete (may take 5-10 minutes)
3. The Organizer window will open automatically

## Step 5: Upload to App Store Connect

1. In the Organizer window:
   - Select your archive
   - Click **Distribute App**
2. Choose **App Store Connect** → **Next**
3. Select **Upload** → **Next**
4. Review options:
   - **Include bitcode**: Yes (recommended)
   - **Upload symbols**: Yes
5. Click **Next** → **Upload**
6. Wait for upload to complete

## Step 6: Configure TestFlight

### 6.1 Wait for Processing
- After upload, wait 5-30 minutes for Apple to process
- You'll receive an email when ready

### 6.2 Set Up TestFlight Testing
1. In App Store Connect, go to your app
2. Click **TestFlight** tab
3. You'll see your build (may show "Processing" initially)

### 6.3 Add Test Information
1. Click on the build
2. Add **Test Details**:
   - What to Test: "Test phone-to-phone navigation using UWB"
   - Email: Your contact email
3. Answer Export Compliance: 
   - Usually **No** for navigation apps

### 6.4 Create Testing Group
1. Go to **Internal Testing** or **External Testing**
2. Create a new group: "Navigation Testers"
3. Add testers by email (up to 100 for internal, 10,000 for external)

## Step 7: Install and Test via TestFlight

### On Each Test iPhone:
1. Download **TestFlight** app from App Store
2. Sign in with Apple ID that was invited
3. Accept the invitation (check email)
4. Install **VNX Navigation** from TestFlight
5. Open the app

### Testing the Navigation:
1. **Phone 1**: 
   - Launch app → Login/Register
   - Select **Anchor** role
   - Tap **Start Broadcasting**
   
2. **Phone 2**:
   - Launch app → Login/Register  
   - Select **Navigator** role
   - Tap **Start Navigation**
   - Should see "Searching..." then connect
   - Distance and arrow should appear

## Troubleshooting

### Common Issues:

1. **"Nearby Interaction not supported"**
   - Ensure iPhone 11 or newer
   - Check Info.plist has correct keys
   - Verify capability is enabled in project

2. **Can't find anchor phone**
   - Ensure both phones have Bluetooth and Wi-Fi enabled
   - Keep phones within 9 meters
   - Both apps must be in foreground

3. **Archive option grayed out**
   - Select "Any iOS Device" not simulator
   - Ensure no build errors

4. **TestFlight not showing build**
   - Wait up to 30 minutes for processing
   - Check email for any issues from Apple
   - Verify upload completed successfully

## Important Notes

- **Privacy**: The app will request Nearby Interaction permission on first launch
- **Battery**: UWB uses more battery - expect ~10-15% drain per hour of active use
- **Range**: Maximum range is ~9 meters with clear line of sight
- **Accuracy**: Best accuracy (~10-30cm) within 3 meters

## Build Automation (Optional)

Create a script for faster builds:

```bash
#!/bin/bash
# File: build_testflight.sh

# Update version and build number
agvtool next-version -all
agvtool new-marketing-version 1.0.0

# Archive
xcodebuild -project VNXNavigationApp.xcodeproj \
  -scheme VNXNavigationApp \
  -sdk iphoneos \
  -configuration Release \
  -archivePath ./build/VNXNavigationApp.xcarchive \
  archive

# Export
xcodebuild -exportArchive \
  -archivePath ./build/VNXNavigationApp.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

## Next Steps

Once testing is successful:
1. Gather feedback from testers
2. Fix any bugs found
3. Increment build number for updates
4. Consider adding crash reporting (Firebase Crashlytics)
5. Add analytics to track usage patterns

---

For questions or issues, contact the development team.