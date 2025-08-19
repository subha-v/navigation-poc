# VALUENEX Office Map Editor - A* Navigation System

## Overview
Interactive map editor with A* pathfinding for indoor navigation in the VALUENEX office.

## Features
- 🗺️ Interactive point placement on floor plan
- 📍 Label locations (kitchen, desks, meeting rooms, etc.)
- 🚀 A* pathfinding algorithm for optimal routes
- 💾 Save/load locations to JSON
- 🎯 Real-time path visualization
- 📏 Accurate distance calculations (5mm resolution)

## Quick Start

### Option 1: Web Interface with Server (Recommended)
```bash
# Start the Flask server
python3 map_server.py

# Open browser to http://localhost:5000
```

### Option 2: Standalone HTML (Limited Features)
```bash
# Open the HTML file directly
open web_map_editor.html
```

### Option 3: Python Tkinter GUI
```bash
python3 interactive_map_editor.py
```

## Usage

### Adding Locations
1. Select "Add Location" mode
2. Click on any white (free) area on the map
3. Enter a name (e.g., "kitchen", "desk_1")
4. Location is automatically saved

### Finding Paths
1. Select "Navigate" mode
2. Choose start and destination from dropdowns
   OR click two locations on the map
3. Click "Find Path"
4. Optimal path is displayed in blue

### Managing Locations
- **Save**: Saves to `office_locations_updated.json`
- **Load**: Loads from saved file
- **Delete**: Click delete button next to location
- **Export**: Download locations as JSON

## Files

- `floor_plan_updated_config.yaml` - Map configuration
- `office_locations_updated.json` - Saved locations
- `astar_navigation.py` - A* pathfinding algorithm
- `map_server.py` - Flask server for web interface
- `web_map_editor_connected.html` - Full-featured web interface
- `interactive_map_editor.py` - Python GUI version

## Configuration

Edit `floor_plan_updated_config.yaml`:
```yaml
resolution: 0.005  # 5mm per pixel
robot_radius: 0.2  # 20cm clearance
inflation_radius: 0.3  # 30cm safety margin
```

## Requirements
```bash
pip3 install flask flask-cors opencv-python matplotlib pillow pyyaml numpy
```

## Integration
The system outputs paths as JSON for easy integration with your indoor navigation app:
```json
{
  "path": [[x1,y1], [x2,y2], ...],
  "distance": 15.3,
  "waypoints": 250
}
```