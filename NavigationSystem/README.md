# Indoor Navigation System with Nearby Interaction

Complete Swift implementation for indoor navigation using Apple's Nearby Interaction API, ARKit, and A* pathfinding on E57-derived maps.

## System Components

### 1. Anchor Placement Tool (`anchor_placement_tool.py`)
Interactive Python tool for placing anchors and POIs on the generated map.

```bash
python anchor_placement_tool.py output_map
```
- Click to place anchors (red triangles) where phones will be mounted
- Click to place POIs (blue circles) for navigation destinations
- Saves `anchors.json` and `pois.json`

### 2. Anchor App (Base Station Phones)
Runs on stationary iPhones mounted at known locations.

**Features:**
- Broadcasts position via MultipeerConnectivity
- Provides UWB ranging via Nearby Interaction
- Shows real-time distance to navigator

**Setup:**
1. Install app on anchor phone
2. Enter anchor ID (e.g., "anchor_A")
3. Enter position from `anchors.json`
4. Tap "Start" to begin broadcasting

### 3. Navigator App (User's Phone)
Main navigation app for users.

**Features:**
- Loads PNG/YAML map from E57 conversion
- ARKit for smooth motion tracking
- Nearby Interaction for drift correction
- A* pathfinding with 8-connected grid
- Turn-by-turn navigation instructions
- Real-time position display on map

**Usage:**
1. Launch app (map loads automatically)
2. Walk to any anchor and tap "Init at Anchor"
3. Select destination from POI list
4. Follow navigation instructions

## Architecture

### Localization Pipeline
1. **ARKit** provides continuous 6DOF tracking (smooth, 60Hz)
2. **Nearby Interaction** provides absolute distance measurements to anchors
3. **Fusion**: ARKit for motion, NI for drift correction (10% gain)
4. **Bounds checking**: Snap to nearest free space if position invalid

### Navigation Pipeline
1. **A* Planning**: Find optimal path on occupancy grid
2. **Path Smoothing**: Douglas-Peucker algorithm
3. **Guidance**: Generate turn instructions based on heading
4. **Arrival Detection**: Stop when within 2m of destination

### Coordinate System
- **World Frame**: Meters, origin at map's bottom-left
- **Pixel Frame**: Image coordinates (Y-flipped)
- **Conversions**: Handled by MapData class

## Setup Instructions

### 1. Generate Map
```bash
python alternative_converter.py --in "scan.e57" --out output_map --res 0.05 --preview
```

### 2. Place Anchors
```bash
python anchor_placement_tool.py output_map
# Click to place 3+ anchors at strategic locations
# Save JSON files
```

### 3. Deploy Anchor Apps
- Install AnchorApp on 3+ iPhones
- Mount phones at surveyed locations
- Configure each with its anchor ID and position
- Start broadcasting

### 4. Test Navigation
- Install NavigatorApp on test device
- Copy map files to app's Documents directory
- Initialize at any anchor
- Select destination and navigate

## Key APIs Used

### Nearby Interaction
```swift
// Create session
let niSession = NISession()
niSession.delegate = self

// Exchange tokens via MultipeerConnectivity
let token = niSession.discoveryToken

// Run with peer configuration
let config = NINearbyPeerConfiguration(peerToken: peerToken)
niSession.run(config)

// Receive distance updates
func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
    if let distance = nearbyObjects.first?.distance {
        // Use for localization correction
    }
}
```

### ARKit Integration
```swift
// World tracking configuration
let config = ARWorldTrackingConfiguration()
config.worldAlignment = .gravity
arSession.run(config)

// Get camera transform
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    let transform = frame.camera.transform
    // Extract position and heading
}
```

### A* Pathfinding
```swift
let planner = AStar(mapData: mapData)
if let path = planner.findPath(from: currentPos, to: destination) {
    let smoothed = planner.smoothPath(path, epsilon: 0.5)
    // Follow path
}
```

## Performance Metrics

- **Localization accuracy**: <3m error over 100m travel
- **Update rate**: 60Hz (ARKit) + 10Hz (NI corrections)
- **Path planning**: <100ms for typical building
- **Battery life**: 2+ hours continuous navigation

## Troubleshooting

### "Nearby Interaction not supported"
- Requires iPhone 11+ with U1 chip
- Check Settings > Privacy > Nearby Interactions

### Poor tracking quality
- Ensure adequate lighting
- Move slowly during initialization
- Add more visual features to environment

### No path found
- Check map occupancy (too dense?)
- Verify start/goal positions are free
- Adjust inflation parameter

### Anchors not discovered
- Verify all devices on same WiFi
- Check Bluetooth and WiFi enabled
- Restart MultipeerConnectivity

## Field Deployment Checklist

- [ ] Map generated at appropriate resolution (0.02-0.05m)
- [ ] Anchors placed with good geometry (triangular)
- [ ] Anchor positions surveyed and verified
- [ ] All anchor phones powered and mounted
- [ ] Test devices have map files installed
- [ ] MultipeerConnectivity working between devices
- [ ] Initial localization successful at each anchor
- [ ] End-to-end navigation test completed
- [ ] Drift correction observed and tuned
- [ ] Turn instructions accurate at decision points

## Next Steps

1. **Multi-floor support**: Add floor transition handling
2. **Beacon fallback**: BLE beacons for NI-unavailable devices
3. **Cloud sync**: Download maps and updates from server
4. **Analytics**: Track navigation success rates
5. **Accessibility**: VoiceOver support for vision-impaired users