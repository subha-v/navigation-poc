# VALUENEX Navigation App - TestFlight Setup Guide

## Prerequisites

1. **Apple Developer Account** (required for TestFlight)
2. **Xcode 15+** installed
3. **4 iOS devices** with iOS 16+ and U1 chip (iPhone 11 or newer)
4. **Python server** running on local network

## Step 1: Configure Xcode Project

1. Open Terminal and navigate to the project:
```bash
cd "/Users/subha/Downloads/VALUENEX/Navigation PoC/NavigationPoC"
```

2. Create Xcode project:
```bash
xcodegen generate
# Or manually create in Xcode: File > New > Project > iOS App
```

3. Configure project settings:
   - **Bundle ID**: `com.valuenex.navigationpoc`
   - **Team**: Select your Apple Developer Team
   - **Minimum iOS**: 16.0
   - **Device**: iPhone only

## Step 2: Add Capabilities

In Xcode, go to Project > Signing & Capabilities and add:
- ✅ Nearby Interaction
- ✅ Background Modes (check "Uses Nearby Interaction")
- ✅ Network Extensions (for local network access)

## Step 3: Configure Supabase

1. Create a Supabase project at https://supabase.com
2. Get your project URL and anon key
3. Update `SupabaseService.swift`:
```swift
let supabaseURL = URL(string: "https://your-project.supabase.co")!
let supabaseKey = "your-anon-key"
```

4. Create database tables:
```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('anchor', 'tagger')),
    anchor_location TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Navigation ratings table
CREATE TABLE navigation_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    destination TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    feedback TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## Step 4: Build and Archive

1. Select generic iOS device as build target
2. Product > Archive
3. Distribute App > App Store Connect > Upload

## Step 5: TestFlight Configuration

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to TestFlight tab
4. Add internal testers (up to 100)
5. Create test group: "Navigation Testing"

## Step 6: Device Setup

### Anchor Devices (3 phones)
Place at these exact positions in the office:
1. **Kitchen Anchor**: Position (2.73m, 1.2m)
2. **Entrance Anchor**: Position (3.56m, 22.18m)  
3. **Side Table Anchor**: Position (4.62m, 17.37m)

### Tagger Device (1 phone)
Used for navigation testing

## Step 7: Python Server Setup

On a computer connected to the same network:

```bash
cd /Users/subha/Downloads/VALUENEX/Navigation\ PoC/FloorPlanGeneration
python3 map_server.py
```

Server will run on `http://[YOUR_IP]:8080`

Update `PathfindingService.swift` with your server IP:
```swift
private let serverURL = "http://192.168.1.X:8080"  // Replace with your IP
```

## Step 8: Testing Protocol

### Initial Setup
1. Install TestFlight app on all 4 devices
2. Accept test invitation
3. Install Navigation PoC app

### Anchor Setup
On each anchor device:
1. Launch app > Sign in as anchor
2. Select anchor position (Kitchen/Entrance/Side Table)
3. Tap "Start Sharing Location"
4. Leave device at position

### Navigation Testing
On tagger device:
1. Launch app > Sign in as tagger
2. Select destination
3. Start navigation
4. Walk around office following arrow
5. Rate experience when arrived

## Test Scenarios

1. **Basic Navigation**
   - Kitchen → Conference Room
   - Entrance → Side Table
   - Side Table → Kitchen

2. **Obstacle Avoidance**
   - Navigate around desks
   - Test path recalculation

3. **Edge Cases**
   - Lost anchor connection
   - Server offline
   - Low battery mode

## Troubleshooting

### "Nearby Interaction not available"
- Ensure device has U1 chip (iPhone 11+)
- Check iOS 16+ installed
- Verify NI permission granted

### "No anchors detected"
- Confirm all anchor devices are on
- Check same WiFi network
- Verify Bluetooth and UWB enabled

### "Path calculation failed"
- Check Python server is running
- Verify network connection
- Confirm server IP is correct

## Performance Metrics

Track these metrics during testing:
- Position accuracy (meters)
- Path following accuracy
- Battery drain (% per hour)
- Network latency (ms)
- Anchor connection stability

## Feedback Collection

After each test session:
1. Export ratings from Supabase
2. Note any navigation failures
3. Document user feedback
4. Screenshot any errors

## Contact

For issues or questions:
- Technical: [Your Email]
- TestFlight: [TestFlight Support Email]