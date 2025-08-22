# Create Xcode Project for VNXNavigationApp

## Step 1: Open Xcode and Create New Project

1. Open Xcode
2. Click **"Create New Project"** (or File → New → Project)
3. Select **iOS** → **App**
4. Click **Next**

## Step 2: Configure the Project

Fill in these details:
- **Product Name**: `VNXNavigationApp`
- **Team**: Select your team (Subha Vadlamannati)
- **Organization Identifier**: `com.valuenex`
- **Bundle Identifier**: (will auto-fill as `com.valuenex.VNXNavigationApp`)
- **Interface**: **SwiftUI**
- **Language**: **Swift**
- **Use Core Data**: ❌ Unchecked
- **Include Tests**: ✅ Checked

Click **Next**

## Step 3: Save Location

**IMPORTANT**: Save the project INSIDE the VNXNavigationApp folder:
- Navigate to: `/Users/subha/Downloads/VALUENEX/Navigation PoC/VNXNavigationApp`
- Click **Create**

## Step 4: Remove Default Files

In Xcode, delete these default files (Move to Trash):
- `ContentView.swift`
- `VNXNavigationAppApp.swift` (the default one)
- `Assets.xcassets` (we'll use our own)

## Step 5: Add Existing Source Files

1. Right-click on the `VNXNavigationApp` folder in Xcode
2. Select **"Add Files to VNXNavigationApp..."**
3. Navigate to the `Sources` folder
4. Select the entire `Sources` folder
5. Make sure these options are set:
   - ❌ **Copy items if needed** (uncheck - files are already there)
   - ✅ **Create groups**
   - ✅ **Add to target: VNXNavigationApp**
6. Click **Add**

## Step 6: Add Package Dependencies

1. Click on the project (blue icon) in the navigator
2. Select the project (not the target)
3. Click **Package Dependencies** tab
4. Click the **+** button

Add Supabase:
- URL: `https://github.com/supabase-community/supabase-swift`
- Dependency Rule: Up to Next Major Version
- Click **Add Package**
- Select products: **Supabase**
- Click **Add Package**

Add Alamofire:
- Click **+** again
- URL: `https://github.com/Alamofire/Alamofire`
- Dependency Rule: Up to Next Major Version
- Click **Add Package**
- Select products: **Alamofire**
- Click **Add Package**

## Step 7: Configure Info.plist

1. Select `Info.plist` in the navigator
2. Right-click → **Open As** → **Source Code**
3. The permissions are already configured in our Info.plist

## Step 8: Add Capabilities

1. Select the project in navigator
2. Select the **VNXNavigationApp** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add:
   - Search for "Background Modes" and add it
   - Check "Uses Nearby Interaction" under Background Modes

## Step 9: Configure Build Settings

1. Still in the target settings
2. Go to **General** tab
3. Set:
   - **Minimum Deployments**: iOS 16.0
   - **Supported Destinations**: iPhone only

## Step 10: Build and Run

1. Select your iPhone device (or simulator for testing UI)
2. Press **Run** (▶️)

## Troubleshooting

### "No such module 'Supabase'"
- Make sure you added the package dependencies (Step 6)
- Try: File → Packages → Resolve Package Versions
- Clean build folder: Product → Clean Build Folder

### Build errors about missing files
- Make sure you added the Sources folder correctly (Step 5)
- Verify all Swift files show up in the navigator

### Signing errors
- Make sure your Team is selected in Signing & Capabilities
- Ensure your bundle identifier is unique

## Testing the App

1. **Start the Python server**:
   ```bash
   cd /Users/subha/Downloads/VALUENEX/Navigation\ PoC/FloorPlanGeneration
   python3 map_server.py
   ```

2. **For device testing**: Update `ServerConfig.swift` with your Mac's IP

3. **Run on device**: Nearby Interaction requires a real device with U1 chip

## Success!

Once built successfully, you'll see the login screen and can:
- Create an account
- Choose anchor or navigator role
- Test the navigation features