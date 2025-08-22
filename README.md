# VALUENEX Indoor Navigation System

A proof-of-concept indoor navigation system using Ultra-Wideband (UWB) technology via Apple's Nearby Interaction API, combined with AI-powered floor plan analysis and A* pathfinding algorithms.

**Last Updated**: August 21, 2024  
**Current Version**: 2.0 (VNXNavigationApp)

## Project Overview

This system enables precise indoor navigation in the VALUENEX office (5.71m × 23.19m) by combining:
- **UWB-based trilateration** using iPhone 11+ devices as anchors and navigators
- **AI-analyzed floor plans** with obstacle detection and path planning
- **Real-time navigation** with visual arrow guidance and distance measurements
- **Web-based map editor** for location management and testing

## System Architecture

### 1. Floor Plan Generation (`/FloorPlanGeneration`)
Python-based backend for floor plan processing and pathfinding:

- **`astar_navigation.py`** - A* pathfinding algorithm with obstacle inflation
- **`map_server.py`** - Flask REST API server (port 8080) providing:
  - Navigation endpoints for the Swift app
  - Location management API
  - Anchor registration and status tracking
- **`web_map_editor_connected.html`** - Interactive web interface for:
  - Adding/editing office locations
  - Testing pathfinding between points
  - Visualizing navigation paths
- **`floor_plan_updated_config.yaml`** - Floor plan configuration (5mm resolution)
- **`office_locations_updated.json`** - Predefined office locations (kitchen, entrance, desks, etc.)

### 2. iOS Navigation App (`/NavigationPoC`)
Swift package implementing UWB-based indoor navigation:

#### Core Services
- **`NearbyInteractionService.swift`** - UWB ranging and device discovery
- **`NavigationService.swift`** - Navigation engine with arrow direction calculation
- **`PathfindingService.swift`** - Integration with Python A* server
- **`CoordinateTransformService.swift`** - Converts UWB measurements to floor plan coordinates
- **`SupabaseService.swift`** - Authentication and user management

#### UI Views
- **`LoginView.swift`** - User authentication
- **`RoleSelectionView.swift`** - Choose anchor or navigator role
- **`AnchorView.swift`** - Interface for fixed anchor devices
- **`TaggerView.swift`** - Destination selection for navigators
- **`NavigationView.swift`** - Real-time navigation with arrow display

#### Models
- **`User.swift`** - User profiles with roles (anchor/tagger)
- **`FloorPlan.swift`** - Office locations and navigation destinations
- **`NavigationPath.swift`** - Path representation and waypoint management

## How It Works

### Setup Phase
1. **Deploy 3 Anchor iPhones** at fixed positions:
   - Kitchen (2.73m, 1.2m)
   - Entrance (3.56m, 22.18m)
   - Side Table (4.62m, 17.37m)

2. **Start Python Server** on local network:
   ```bash
   cd FloorPlanGeneration
   python3 map_server.py
   ```

3. **Configure Anchors** via iOS app:
   - Sign in as "anchor" role
   - Select position (kitchen/entrance/side table)
   - Start broadcasting UWB signals

### Navigation Phase
1. **Navigator (Tagger) Setup**:
   - Sign in as "tagger" role
   - Select destination from available locations
   - Start navigation

2. **Position Calculation**:
   - App measures distances to all 3 anchors using UWB
   - Trilateration algorithm calculates precise position
   - Position converted to floor plan coordinates

3. **Path Guidance**:
   - Python server calculates optimal path using A*
   - App displays arrow pointing to next waypoint
   - Real-time distance and direction updates
   - Path recalculation if user deviates >2m

## Technical Specifications

### UWB Ranging
- **Technology**: Apple Nearby Interaction API
- **Accuracy**: ~10cm in ideal conditions
- **Update Rate**: 10-15 Hz
- **Range**: Up to 9 meters
- **Requirements**: iPhone 11+ with U1 chip

### Floor Plan Processing
- **Resolution**: 5mm per pixel
- **Office Dimensions**: 5.71m × 23.19m
- **Obstacle Inflation**: 30cm radius for safe navigation
- **Path Smoothing**: Waypoint reduction algorithm

### Network Architecture
- **Local Server**: Flask on port 8080
- **Authentication**: Supabase cloud service
- **Device Discovery**: MultipeerConnectivity framework
- **API Format**: RESTful JSON

## Project Structure

```
/Navigation PoC/
├── FloorPlanGeneration/          # Python backend
│   ├── map_server.py             # Flask API server
│   ├── astar_navigation.py       # Pathfinding algorithm
│   ├── web_map_editor_connected.html  # Web interface
│   ├── floor_plan_updated_config.yaml # Map configuration
│   ├── office_locations_updated.json  # Location database
│   └── VNX_BW_Floorplan_Updated.PNG  # Office floor plan
│
├── VNXNavigationApp/             # iOS Swift app (Current)
│   ├── VNXNavigationApp.xcodeproj  # Xcode project
│   ├── VNXNavigationApp/         # App source files
│   │   ├── Assets.xcassets/     # App icons and colors
│   │   └── Info.plist            # App permissions
│   ├── Sources/                  # Swift source code
│   │   ├── App/                  # App entry point
│   │   ├── Config/               # Configuration files
│   │   ├── Models/               # Data models
│   │   ├── Services/             # Core services
│   │   └── Views/                # SwiftUI views
│   └── Package.swift             # Package dependencies
│
└── CLAUDE.md                     # AI assistant instructions
```

## Key Features

- **Real-time Indoor Positioning**: <10cm accuracy using UWB trilateration
- **Intelligent Path Planning**: A* algorithm with obstacle avoidance
- **Visual Navigation**: Arrow-based guidance with distance indicators
- **Multi-floor Support**: Ready for expansion to multiple building levels
- **Web Testing Interface**: Browser-based path visualization and testing
- **Role-based System**: Separate interfaces for anchors and navigators
- **Cloud Authentication**: Secure user management via Supabase
- **Offline Capability**: Local server for reliability

## Getting Started

### Prerequisites
- 4 iPhones with iOS 16+ and U1 chip (iPhone 11 or newer)
- Mac with Xcode 15+
- Python 3.8+
- Local WiFi network
- Apple Developer account (for device deployment)
- Supabase account (free tier works)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/subha-v/navigation-poc.git
   cd "Navigation PoC"
   ```

2. **Set up Python server**:
   ```bash
   cd FloorPlanGeneration
   pip install flask flask-cors pyyaml numpy pillow
   python3 map_server.py
   ```

3. **Configure iOS app**:
   - Open `VNXNavigationApp.xcodeproj` in Xcode
   - Supabase credentials are in `Sources/Config/SupabaseConfig.swift`
   - Server IP is in `Sources/Config/ServerConfig.swift`
   - Set your Apple Developer Team ID in project settings
   - Build and run on devices

4. **Access web interface**:
   - Open browser to `http://localhost:8080`
   - Add/edit office locations
   - Test pathfinding

## Use Cases

1. **Conference Navigation**: Guide attendees to specific booths or rooms
2. **Emergency Evacuation**: Direct people to nearest exits
3. **Accessibility**: Assist visually impaired users with precise guidance
4. **Asset Tracking**: Locate equipment or personnel in real-time
5. **Visitor Management**: Guide guests to meeting rooms or offices

## Future Enhancements

- [ ] Multi-floor navigation with elevator/stair routing
- [ ] Voice-guided navigation
- [ ] Augmented Reality overlay
- [ ] Historical path analytics
- [ ] Integration with calendar for automatic destination selection
- [ ] Support for more anchor devices for improved accuracy
- [ ] Android app version
- [ ] Cloud-based path computation for scalability

## Technologies Used

- **iOS**: Swift 5.9, SwiftUI, Nearby Interaction, MultipeerConnectivity
- **Backend**: Python 3, Flask, NumPy, Pillow
- **Cloud**: Supabase (PostgreSQL, Authentication)
- **Algorithms**: A* pathfinding, Trilateration, Kalman filtering
- **Protocols**: REST API, WebSockets (planned)

## Contributing

This is a proof-of-concept project for VALUENEX. For contributions or questions, please contact the development team.

## License

Proprietary - VALUENEX © 2024

## Acknowledgments

- Apple for Nearby Interaction API documentation
- OpenAI for AI-assisted development
- Supabase for authentication infrastructure