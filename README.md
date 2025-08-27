# VALUENEX Indoor Navigation System

A proof-of-concept indoor navigation system for conferences and large venues, enabling precise indoor positioning and navigation using smartphone technology.

**Last Updated**: August 26, 2024  
**Current Version**: 1.0 (MultipeerConnectivity)  
**Next Version**: 2.0 (Nearby Interaction - In Development)

## 🎯 Project Vision

Create an indoor navigation system where attendees can download an app that helps them navigate conferences and events by:
- Using their phone to trilaterate position from 3-5 base stations (anchor phones)
- Getting real-time directions to booths, rooms, or points of interest
- Supporting multi-floor navigation with optimal path planning
- Enabling smart features like "I'm interested in AI in healthcare - where should I go?"

## 📱 Current Implementation (v1.0)

### What's Built
The current iOS app provides the foundation for device-to-device communication using MultipeerConnectivity:

#### Authentication System
- **Firebase Authentication**: Secure user login/signup with email verification
- **Role-based Access**: Users select either "Anchor" (base station) or "Navigator" (moving user) role
- **User Profiles**: Stored in Firebase Firestore with role persistence

#### Device Communication
- **MultipeerConnectivity Framework**: Enables iPhone-to-iPhone discovery and connection
- **Anchor Mode**: Phones act as fixed base stations, advertising their presence
- **Navigator Mode**: Moving phones discover and connect to nearby anchors
- **Local Network Permission**: Automatic permission request for device discovery

#### Core Services
- **`AuthService.swift`**: Firebase authentication and session management
- **`MultipeerService.swift`**: Base class for peer-to-peer communication
- **`AnchorService.swift`**: Advertising service for anchor devices
- **`NavigatorService.swift`**: Discovery and connection service for navigators
- **`LocalNetworkAuthorization.swift`**: Forces iOS local network permission prompt

#### User Interface
- **Login/Signup Views**: Clean authentication flow with password reset
- **Home View**: Role selection (Anchor vs Navigator)
- **Anchor View**: Simple interface showing advertising status and connected peers
- **Navigator View**: Shows discovered anchors and connection status

### Current Architecture
```
VNXNavigationApp/
├── Sources/
│   ├── App/                  # App entry point
│   │   └── VNXNavigationApp.swift
│   ├── Models/               # Data models
│   │   └── User.swift
│   ├── Services/             # Core services
│   │   ├── AuthService.swift
│   │   ├── MultipeerService.swift
│   │   ├── AnchorService.swift
│   │   ├── NavigatorService.swift
│   │   └── LocalNetworkAuthorization.swift
│   └── Views/                # SwiftUI views
│       ├── LoginView.swift
│       ├── SignupView.swift
│       ├── HomeView.swift
│       ├── AnchorView.swift
│       └── NavigatorView.swift
├── Info.plist               # App permissions
└── GoogleService-Info.plist # Firebase configuration
```

## 🚀 Next Phase: Nearby Interaction (v2.0)

### Planned Upgrades
Transform the current MultipeerConnectivity foundation into a full UWB-based navigation system:

#### Phase 1: UWB Integration
- [ ] Replace MultipeerConnectivity with Nearby Interaction API
- [ ] Implement UWB distance ranging between devices
- [ ] Add direction finding (azimuth and elevation)
- [ ] Create trilateration algorithm for position calculation

#### Phase 2: Navigation Engine
- [ ] Integrate floor plan mapping (from FloorPlanGeneration/)
- [ ] Implement A* pathfinding algorithm
- [ ] Add real-time position tracking
- [ ] Create arrow-based navigation UI

#### Phase 3: Advanced Features
- [ ] Multi-floor support with elevator/stair routing
- [ ] Points of Interest (POI) management
- [ ] Smart recommendations ("Show me AI booths")
- [ ] Path optimization for multiple destinations
- [ ] Historical analytics and heatmaps

### Technical Requirements for v2.0
- **Nearby Interaction API**: For precise UWB ranging (10cm accuracy)
- **Core Location**: For initial position estimation
- **ARKit Integration**: For improved position tracking
- **Local Pathfinding Server**: Python Flask backend with A* algorithm
- **Floor Plan Data**: Building maps with obstacle definitions

## 🛠️ Setup Instructions

### Prerequisites
- 4+ iPhones with iOS 16+ (iPhone 11 or newer for UWB in v2.0)
- Mac with Xcode 15+
- Apple Developer account
- Firebase project (free tier)
- Same WiFi network for all devices

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/subha-v/navigation-poc.git
   cd "Navigation PoC/VNXNavigationApp"
   ```

2. **Open in Xcode**:
   ```bash
   open VNXNavigationApp/VNXNavigationApp.xcodeproj
   ```

3. **Configure signing**:
   - Select your Apple Developer Team
   - Update bundle identifier if needed

4. **Build and deploy**:
   - Connect iPhones via USB
   - Build and run on each device
   - Trust developer certificate on devices

5. **Test the system**:
   - Deploy 3 phones as anchors (login and select Anchor role)
   - Use 1 phone as navigator (login and select Navigator role)
   - Navigator should discover and connect to anchors

## 📊 FloorPlanGeneration (For Future Integration)

The repository includes a Python-based floor plan system ready for v2.0:

```
FloorPlanGeneration/
├── astar_navigation.py          # A* pathfinding algorithm
├── map_server.py                # Flask API server
├── web_map_editor_connected.html # Web-based map editor
├── floor_plan_updated_config.yaml # Floor plan configuration
└── office_locations_updated.json  # POI definitions
```

This will be integrated in v2.0 to provide:
- Real-time pathfinding
- Obstacle avoidance
- Web-based location management
- Path visualization

## 🎮 How It Works (Current v1.0)

1. **Anchor Setup**:
   - Launch app on 3+ iPhones
   - Login with email/password
   - Select "Anchor" role
   - Phones start advertising as base stations

2. **Navigator Connection**:
   - Launch app on navigator iPhone
   - Login and select "Navigator" role
   - App discovers nearby anchors
   - Establishes peer-to-peer connections

3. **Communication**:
   - Devices exchange ping/pong messages
   - Connection status shown in real-time
   - Forms mesh network of devices

## 🔮 Future Use Cases

1. **Conference Navigation**: Guide attendees to specific booths
2. **Healthcare Facilities**: Navigate hospitals and clinics
3. **Shopping Malls**: Find stores and facilities
4. **Museums**: Self-guided tours with location awareness
5. **Emergency Evacuation**: Direct to nearest exits
6. **Accessibility**: Assist visually impaired users

## 🏗️ Technologies

### Current Stack
- **iOS**: Swift 5.9, SwiftUI
- **Networking**: MultipeerConnectivity, Bonjour
- **Backend**: Firebase Auth, Firestore
- **Build**: Xcode 15, iOS 16+

### Planned for v2.0
- **UWB**: Nearby Interaction API
- **AR**: ARKit for position fusion
- **Backend**: Python Flask, NumPy
- **Algorithms**: Trilateration, A* pathfinding

## 📝 Known Issues & Solutions

### Local Network Permission
- iOS 18+ may not show permission prompt automatically
- Solution: App includes LocalNetworkAuthorization service to force prompt
- Check: Settings → Privacy → Local Network → VNXNavigationApp

### Connection Timeouts
- Ensure all devices on same WiFi network
- Disable VPN if active
- Check firewall settings

## 🤝 Contributing

This is a proof-of-concept for VALUENEX. For contributions:
1. Fork the repository
2. Create feature branch
3. Commit changes with clear messages
4. Push to branch
5. Open pull request

## 📄 License

Proprietary - VALUENEX © 2024

## 🙏 Acknowledgments

- Apple for MultipeerConnectivity and Nearby Interaction frameworks
- Firebase for authentication infrastructure
- OpenAI Claude for development assistance
- VALUENEX team for project vision and support