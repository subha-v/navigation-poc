# VNX Navigation App - Indoor Navigation PoC

An iOS application demonstrating indoor navigation using Ultra-Wideband (UWB) technology with Apple's Nearby Interaction API and MultipeerConnectivity framework.

## Overview

This proof-of-concept app enables precise indoor positioning and navigation by using multiple iPhones as base stations (anchors) that communicate with navigator devices. The system uses UWB ranging for accurate distance measurements between devices.

## Current Features ✅

### Core Functionality
- **Firebase Authentication**: User registration and login system with role-based access
- **Dual Mode Operation**: 
  - **Anchor Mode**: Device acts as a stationary base station broadcasting its location
  - **Navigator Mode**: Mobile device that discovers and connects to anchors for positioning

### Technical Implementation
- **MultipeerConnectivity Framework**: 
  - Automatic device discovery using Bonjour/mDNS
  - Secure peer-to-peer connections between devices
  - Custom browsing interface and system UI options
  - Real-time connection status monitoring

- **Nearby Interaction API**:
  - UWB-based precise distance measurement
  - Discovery token exchange between devices
  - NISession management for ranging
  - Distance display in real-time

- **Permissions Management**:
  - Automatic Local Network permission prompt
  - Nearby Interaction permission handling
  - Device capability checking for UWB support

### UI Components
- **NavigatorView**: 
  - Displays discovered anchors
  - Connection management interface
  - NI session controls and status
  - Real-time distance measurements

- **AnchorView**:
  - Broadcasting controls
  - Connected navigators list
  - Session token display
  - Ping/connection testing

## Architecture

```
VNXNavigationApp/
├── Sources/
│   ├── App/
│   │   └── VNXNavigationApp.swift
│   ├── Models/
│   │   └── User.swift
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── MultipeerService.swift
│   │   ├── NavigatorService.swift
│   │   ├── AnchorService.swift
│   │   ├── NISessionService.swift
│   │   ├── LocalNetworkAuthorization.swift
│   │   └── NearbyInteractionAuthorization.swift
│   └── Views/
│       ├── Components/
│       │   ├── ConnectedPeerRow.swift
│       │   ├── DiscoveredAnchorRow.swift
│       │   └── NISessionView.swift
│       ├── LoginView.swift
│       ├── SignupView.swift
│       ├── HomeView.swift
│       ├── NavigatorView.swift
│       └── AnchorView.swift
```

## Requirements

- iOS 16.6+
- iPhone with UWB chip (iPhone 11 or newer)
- Xcode 14+
- Firebase project configured

## Setup Instructions

1. Clone the repository
2. Open `VNXNavigationApp.xcodeproj` in Xcode
3. Configure Firebase:
   - Add your `GoogleService-Info.plist` file
   - Enable Authentication and Firestore in Firebase Console
4. Build and run on physical devices (UWB not available in simulator)

## How to Use

1. **Initial Setup**:
   - Launch app on multiple iPhones
   - Create accounts or sign in
   - Grant Local Network and Nearby Interaction permissions when prompted

2. **Anchor Setup**:
   - Select "Anchor" role on stationary devices
   - Tap "Start Advertising" to broadcast presence
   - Device will show as online to navigators

3. **Navigator Usage**:
   - Select "Navigator" role on mobile device
   - Tap "Custom Browse" or "System UI" to discover anchors
   - Select an anchor to connect
   - Start NI Session to begin ranging
   - View real-time distance measurements

## TODO - Remaining Features 🚧

### High Priority
- [ ] **Trilateration Implementation**: Calculate absolute position using 3+ anchors
- [ ] **Floor Plan Integration**: 
  - Import building floor plans (E57/PDF format)
  - Convert to navigable grid using PDAL/pye57
  - Overlay user position on map
- [ ] **Path Planning**:
  - A* pathfinding on occupancy grids
  - Route optimization
  - Turn-by-turn navigation

### Navigation Features
- [ ] **Multi-floor Support**: Handle navigation across different floors
- [ ] **Points of Interest**: Mark and navigate to specific locations
- [ inevitable] **Booth/Room Finding**: Search and navigate to conference booths
- [ ] **Category-based Navigation**: "Show me AI/Healthcare booths"

### Technical Enhancements
- [ ] **NLOS Mitigation**: Handle Non-Line-of-Sight scenarios with base stations
- [ ] **Position Filtering**: Kalman filter for position smoothing
- [ ] **Anchor Calibration**: Automated anchor position determination
- [ ] **Cross-validation**: Use 5th anchor for position verification

### Smart Contract Integration
- [ ] **Usage Tracking**: Implement token-based payment for location services
- [ ] **Analytics**: Track navigation patterns and popular routes
- [ ] **Access Control**: Premium navigation features

### User Experience
- [ ] **AR Navigation**: ARKit integration for visual guidance
- [ ] **Voice Guidance**: Audio turn-by-turn directions
- [ ] **Offline Mode**: Cache floor plans for offline navigation
- [ ] **Path History**: Save and replay navigation routes

## Known Issues

- UWB ranging requires line-of-sight for best accuracy
- MultipeerConnectivity limited to 8 simultaneous connections
- Local Network permission must be granted for device discovery

## Technical Notes

- Service Type: `vnx` (Bonjour/mDNS)
- Encryption: Required for all peer connections
- Token Format: Base64 encoded NIDiscoveryToken
- Distance Update Rate: ~10Hz when in range

## Contributing

This is a proof-of-concept project for VALUENEX indoor navigation research.

## License

Proprietary - VALUENEX Internal Use Only