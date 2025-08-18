# iOS App Setup Guide for Xcode

## Prerequisites
- Xcode 14.0+ installed
- iPhone with iOS 15.0+ (iPhone 11+ for Nearby Interaction)
- Apple Developer Account (free or paid)
- USB cable to connect iPhone to Mac

## Step 1: Create Xcode Projects

### A. Create Anchor App Project

1. Open Xcode
2. File → New → Project
3. Choose: **iOS → App**
4. Configure:
   - Product Name: `AnchorStation`
   - Team: Select your Apple ID
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **No**
   - Include Tests: **No**
5. Save to: `NavigationSystem/AnchorStation/`

### B. Create Navigator App Project

1. File → New → Project  
2. Choose: **iOS → App**
3. Configure:
   - Product Name: `IndoorNavigator`
   - Team: Select your Apple ID
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **No**
   - Include Tests: **No**
4. Save to: `NavigationSystem/IndoorNavigator/`

## Step 2: Add Required Capabilities

### For BOTH Apps:

1. Select project in navigator
2. Select target → Signing & Capabilities
3. Click **+ Capability** and add:
   - **Nearby Interaction** (REQUIRED)
   - **Background Modes** → Check "Uses Bluetooth LE accessories"

## Step 3: Update Info.plist

### For BOTH Apps, add these privacy descriptions:

1. Select Info.plist
2. Add these keys (right-click → Add Row):

```xml
<key>NSNearbyInteractionAllowOnceUsageDescription</key>
<string>This app uses Nearby Interaction to determine precise distance to anchor phones for indoor navigation.</string>

<key>NSNearbyInteractionUsageDescription</key>
<string>This app uses Nearby Interaction for precise indoor positioning.</string>

<key>NSCameraUsageDescription</key>
<string>This app uses ARKit for motion tracking during navigation.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover navigation anchors.</string>

<key>NSBonjourServices</key>
<array>
    <string>_nav-anchor._tcp</string>
    <string>_nav-anchor._udp</string>
</array>
```

## Step 4: Add Source Files

### A. For Anchor App:
1. Delete the default ContentView.swift
2. Drag and drop these files into Xcode project:
   - `AnchorApp/AnchorApp.swift`
   - `AnchorApp/ContentView.swift`
   - `AnchorApp/AnchorManager.swift`

### B. For Navigator App:
1. Delete the default ContentView.swift  
2. Create folder groups in Xcode: Models, PathPlanning, Localization
3. Drag and drop files:
   - `NavigatorApp/NavigatorApp.swift`
   - `NavigatorApp/NavigationView.swift`
   - `NavigatorApp/NavigationManager.swift`
   - `Models/MapData.swift`
   - `PathPlanning/AStar.swift`
   - `Localization/LocalizationManager.swift`

## Step 5: Add Map Files to Navigator App

1. In Navigator app, create a new folder: **Resources**
2. Drag your map files into Resources:
   - `output_map/grid.png`
   - `output_map/grid.yaml`
   - `output_map/anchors.json`
   - `output_map/pois.json` (if you have it)
3. Make sure "Copy items if needed" is checked
4. Select "Create folder references"

## Step 6: Configure for Device Testing

1. Connect your iPhone via USB
2. In Xcode, select your iPhone from device list (top bar)
3. First time setup:
   - Go to Settings → Privacy & Security → Developer Mode on iPhone
   - Enable Developer Mode
   - Restart iPhone

## Step 7: Build and Run

### A. Deploy Anchor App (on anchor phones):

1. Open AnchorStation project
2. Select anchor iPhone in device list
3. Click Run (▶️) or Cmd+R
4. Trust developer certificate on iPhone if prompted:
   - Settings → General → VPN & Device Management
   - Select your developer profile → Trust

### B. Deploy Navigator App (on user's phone):

1. Open IndoorNavigator project
2. Select user's iPhone in device list
3. Click Run (▶️) or Cmd+R

## Step 8: Testing

### On Anchor Phones:
1. Launch AnchorStation app
2. Enter anchor ID (e.g., "anchor_A")
3. Enter X, Y position from your anchors.json
4. Tap "Start"
5. Should show "Active" status

### On Navigator Phone:
1. Launch IndoorNavigator app
2. Walk near an anchor phone
3. Tap "Init at Anchor"
4. Select the anchor you're near
5. Choose a destination POI
6. Follow navigation instructions

## Troubleshooting

### "Untrusted Developer" Error
- Settings → General → VPN & Device Management
- Select your profile → Trust

### "Nearby Interaction Not Available"
- Requires iPhone 11 or newer
- Check Settings → Privacy → Nearby Interactions is enabled

### Build Errors
- Clean build: Product → Clean Build Folder (Shift+Cmd+K)
- Delete Derived Data: ~/Library/Developer/Xcode/DerivedData

### No Anchors Found
- Ensure all phones on same WiFi network
- Check Bluetooth is enabled
- Restart apps on all devices

### Map Not Loading
- Verify map files are in app bundle
- Check file names match exactly
- Ensure Build Phases → Copy Bundle Resources includes map files

## Quick Deploy Script

Create `deploy.sh`:

```bash
#!/bin/bash
# Deploy to specific device
DEVICE_ID="your-device-id"  # Get from: xcrun xctrace list devices

# Build and install Anchor app
xcodebuild -project AnchorStation/AnchorStation.xcodeproj \
    -scheme AnchorStation \
    -destination "id=$DEVICE_ID" \
    clean build

# Build and install Navigator app  
xcodebuild -project IndoorNavigator/IndoorNavigator.xcodeproj \
    -scheme IndoorNavigator \
    -destination "id=$DEVICE_ID" \
    clean build
```

## Testing Checklist

- [ ] Anchor phones mounted and powered
- [ ] All devices on same WiFi
- [ ] Bluetooth enabled on all devices
- [ ] Developer mode enabled
- [ ] Apps trusted in Settings
- [ ] Map files included in Navigator app
- [ ] anchors.json positions match physical locations
- [ ] At least 3 anchors running
- [ ] Navigator initializes at anchor successfully
- [ ] Path planning works to POIs
- [ ] Turn instructions appear correctly