# Xcode Project Setup Guide

## Creating the Xcode Project

Since you have a Swift Package, you need to create an iOS app project that uses this package. Here's how:

### Step 1: Create New Xcode Project

1. Open Xcode
2. Click **"Create New Project"** (not "Open")
3. Select **iOS** → **App**
4. Click **Next**

### Step 2: Configure Project Settings

Fill in these details:
- **Product Name**: NavigationPoC
- **Team**: Select your Apple Developer Team
- **Organization Identifier**: com.valuenex
- **Bundle Identifier**: Will auto-fill as `com.valuenex.NavigationPoC`
- **Interface**: SwiftUI
- **Language**: Swift
- **Use Core Data**: ❌ Unchecked
- **Include Tests**: ✅ Checked

Click **Next** and save the project INSIDE the NavigationPoC folder (alongside Package.swift)

### Step 3: Add Local Swift Package

1. In Xcode, select your project in the navigator
2. Click on the project name at the top
3. Select your app target
4. Go to **General** tab
5. Scroll to **Frameworks, Libraries, and Embedded Content**
6. Click the **+** button
7. Click **Add Package Dependency**
8. Click **Add Local...**
9. Navigate to your NavigationPoC folder and select it
10. Click **Add Package**

### Step 4: Add Capabilities

Now you can add the Nearby Interaction capability:

1. Select your project in the navigator
2. Select your app target
3. Click on **Signing & Capabilities** tab
4. Click **+ Capability** button (top left of the tab)
5. Search for and add these capabilities:
   - **Nearby Interaction**
   - **Background Modes** (then check "Uses Nearby Interaction")
   - **Push Notifications** (if you want to use notifications)

### Step 5: Configure Info.plist

The Info.plist permissions are already in the file, but verify they're included:

1. Select Info.plist in the navigator
2. Ensure these keys exist:
   - `NSNearbyInteractionAllowOnceUsageDescription`
   - `NSNearbyInteractionUsageDescription`
   - `NSMotionUsageDescription`
   - `NSLocalNetworkUsageDescription`

### Step 6: Replace Default ContentView

1. Open the default `ContentView.swift` that Xcode created
2. Replace its contents with:

```swift
import SwiftUI
import NavigationPoC

struct ContentView: View {
    var body: some View {
        NavigationPoCApp.MainView()
    }
}
```

### Step 7: Update App File

1. Open the `[YourAppName]App.swift` file
2. Import your package and update:

```swift
import SwiftUI
import NavigationPoC

@main
struct NavigationPoCAppWrapper: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 8: Configure Network Settings

For the Python server connection to work:

1. In Info.plist, add App Transport Security exception:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
        <!-- Add your server IP here -->
        <key>192.168.1.100</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Step 9: Build and Run

1. Select your iPhone device or simulator
2. Update `PathfindingService.swift` with your Mac's IP address:
   ```swift
   private let serverURL = "http://YOUR_MAC_IP:8080"
   ```
3. Start the Python server on your Mac:
   ```bash
   cd FloorPlanGeneration
   python3 map_server.py
   ```
4. Click **Run** (▶️) in Xcode

## Troubleshooting

### "No such module 'NavigationPoC'"
- Make sure you added the local package dependency correctly
- Clean build folder: Product → Clean Build Folder

### "Nearby Interaction not available"
- Requires real device with U1 chip (iPhone 11+)
- Won't work in simulator

### Network connection issues
- Ensure iPhone and Mac are on same WiFi
- Check firewall settings on Mac
- Verify server IP address in PathfindingService.swift

## Required Files Checklist

✅ Supabase tables created (verified)
✅ SupabaseConfig.swift with credentials
✅ Python server dependencies installed
✅ Floor plan and locations configured
⬜ Apple Developer Team ID set
⬜ Xcode project created with capabilities
⬜ Server IP configured