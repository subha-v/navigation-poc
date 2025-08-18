# Simple Drop-In Indoor Navigation Module

## What This Is
ONE Swift package that works as both:
- **Anchor mode** - For stationary phones
- **Navigator mode** - For user's phone

No need for separate apps!

## Quick Setup (5 minutes)

### 1. Create New Xcode Project
- File → New → Project → iOS App
- Name: `MyNavigationApp`
- Interface: SwiftUI
- Language: Swift

### 2. Add the Module
Simply drag the `IndoorNavigation` folder into your Xcode project

OR use Swift Package Manager:
- File → Add Package Dependencies
- Add local package → Select `IndoorNavigation` folder

### 3. Add Required Capabilities
In Xcode project settings → Signing & Capabilities → Add:
- ✅ Nearby Interaction

### 4. Update Info.plist
Add these privacy descriptions:
```xml
<key>NSNearbyInteractionUsageDescription</key>
<string>Used for precise indoor positioning</string>

<key>NSCameraUsageDescription</key>
<string>Used for AR motion tracking</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Used to discover navigation anchors</string>

<key>NSBonjourServices</key>
<array>
    <string>_indoor-nav._tcp</string>
    <string>_indoor-nav._udp</string>
</array>
```

### 5. Use in Your App
Replace your ContentView with:

```swift
import SwiftUI
import IndoorNavigation

struct ContentView: View {
    var body: some View {
        IndoorNavigationView()
    }
}
```

That's it! The app now has both modes built in.

## How to Use

### For Anchor Phones:
1. Launch app
2. Switch to "Anchor" mode (top toggle)
3. Enter anchor ID (A, B, or C)
4. Tap "Start"
5. Leave phone in position

### For Navigator (User):
1. Launch app
2. Stay in "Navigator" mode
3. Tap "Start Tracking"
4. Walk near an anchor
5. Tap "Navigate" to see path

## Features Included
- ✅ Nearby Interaction (UWB ranging)
- ✅ ARKit motion tracking
- ✅ Automatic anchor discovery
- ✅ Simple A* pathfinding
- ✅ Map display
- ✅ Turn instructions

## Customization

### Add Your Map
Place your map files in `Resources/`:
- `grid.png` - Your occupancy grid
- `grid.yaml` - Map metadata
- `anchors.json` - Anchor positions

### Change App Behavior
Edit `IndoorNavigation.swift` to:
- Customize UI colors/layout
- Add more navigation features
- Integrate with your backend
- Add custom POIs

## Testing
1. Install on 3+ iPhones (11 or newer)
2. Place 3 phones as anchors
3. Use 4th phone as navigator
4. All phones must be on same WiFi

## One App, Two Modes
The same app works for both anchors and navigators. Just toggle the mode at the top. No need for separate Xcode projects or complicated setup!

## Minimal Example App

```swift
// AppDelegate.swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            IndoorNavigationView()
        }
    }
}
```

That's literally all you need!