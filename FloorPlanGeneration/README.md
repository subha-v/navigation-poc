# VALUENEX Office Navigation System - A* Pathfinding

## 🚀 Quick Start

```bash
# Install dependencies
pip3 install flask flask-cors opencv-python matplotlib pillow pyyaml numpy

# Start the server
python3 map_server.py

# Open browser to http://localhost:5001
```

## 📁 Files

- `VNX_BW_Floorplan_Updated.PNG` - Office floor plan image
- `floor_plan_updated_config.yaml` - Map configuration (5mm resolution)
- `office_locations_updated.json` - Saved location points
- `astar_navigation.py` - A* pathfinding algorithm
- `map_server.py` - Flask server
- `web_map_editor_connected.html` - Interactive web interface

## 🗺️ Features

- **Interactive Map Editor**: Click to add/label locations
- **A* Pathfinding**: Optimal route calculation avoiding obstacles
- **Real-time Visualization**: See paths drawn on the map
- **Distance Calculation**: Accurate to 5mm resolution
- **JSON Export**: Easy integration with other systems

## 📍 Current Locations

The system includes pre-defined locations:
- entrance
- kitchen_sink
- david_desk, taide_desk
- conference_room_entrance
- beanbag area
- near victor desk, near isabel desk
- side_table, front_table

## 🔧 Configuration

Edit `floor_plan_updated_config.yaml` to adjust:
- `robot_radius`: Clearance for navigation (default: 20cm)
- `inflation_radius`: Safety margin (default: 30cm)
- `resolution`: 5mm per pixel

## 🎯 Usage

1. **Add Location**: Select "Add" mode → Click on map → Enter name
2. **Find Path**: Select "Navigate" mode → Choose start/end → Click "Calculate Path"
3. **Save**: Click "Save to Server" to persist changes

## 📊 API Endpoints

- `GET /api/locations` - Get all saved locations
- `POST /api/locations` - Save locations
- `POST /api/find_path` - Calculate A* path between points
- `POST /api/validate_position` - Check if position is valid

## 🔌 Integration

The pathfinding results are returned as JSON:
```json
{
  "success": true,
  "path": [[x1,y1], [x2,y2], ...],
  "distance": 15.3,
  "waypoints": 250
}
```

Perfect for integration with your trilateration-based indoor navigation app!