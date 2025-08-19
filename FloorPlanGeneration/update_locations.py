#!/usr/bin/env python3

import numpy as np
from PIL import Image
import json

image = Image.open('VNX_BW_Floorplan.PNG')
map_array = np.array(image.convert('L'))

map_binary = (map_array > 128).astype(np.uint8)

resolution = 0.005

def find_nearest_valid(x_pixels, y_pixels, map_binary, search_radius=50):
    height, width = map_binary.shape
    
    for radius in range(1, search_radius):
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                if abs(dx) == radius or abs(dy) == radius:
                    nx, ny = x_pixels + dx, y_pixels + dy
                    if 0 <= nx < width and 0 <= ny < height:
                        if map_binary[ny, nx] == 1:
                            window = map_binary[max(0, ny-5):min(height, ny+5),
                                              max(0, nx-5):min(width, nx+5)]
                            if np.mean(window) > 0.7:
                                return nx, ny
    return None

updated_locations = {
    "entrance": {
        "x": 2.85,
        "y": 1.0,
        "description": "Main entrance at top of building"
    },
    "conference_room": {
        "x": 2.85,
        "y": 11.5,
        "description": "Large conference room in center"
    },
    "desk_area_1": {
        "x": 1.5,
        "y": 4.0,
        "description": "Desk area on left side"
    },
    "desk_area_2": {
        "x": 4.2,
        "y": 4.0,
        "description": "Desk area on right side"
    },
    "meeting_room_1": {
        "x": 2.85,
        "y": 7.0,
        "description": "Small meeting room"
    },
    "meeting_room_2": {
        "x": 1.2,
        "y": 9.0,
        "description": "Meeting room on left"
    },
    "meeting_room_3": {
        "x": 4.5,
        "y": 9.0,
        "description": "Meeting room on right"
    },
    "kitchen": {
        "x": 2.85,
        "y": 15.0,
        "description": "Kitchen/break area"
    },
    "storage_area": {
        "x": 1.5,
        "y": 18.0,
        "description": "Storage room"
    },
    "workstation_1": {
        "x": 4.0,
        "y": 18.0,
        "description": "Individual workstation"
    },
    "elevator_area": {
        "x": 2.85,
        "y": 21.0,
        "description": "Elevator/stairs area"
    },
    "reception": {
        "x": 2.85,
        "y": 2.0,
        "description": "Reception desk area"
    }
}

validated_locations = {}
for name, loc in updated_locations.items():
    x_pixels = int(loc['x'] / resolution)
    y_pixels = int(loc['y'] / resolution)
    
    if 0 <= x_pixels < map_binary.shape[1] and 0 <= y_pixels < map_binary.shape[0]:
        if map_binary[y_pixels, x_pixels] == 1:
            validated_locations[name] = loc
            print(f"✓ {name}: ({loc['x']:.2f}, {loc['y']:.2f}) meters -> pixels ({x_pixels}, {y_pixels}) - VALID")
        else:
            result = find_nearest_valid(x_pixels, y_pixels, map_binary)
            if result:
                nx, ny = result
                new_x = nx * resolution
                new_y = ny * resolution
                validated_locations[name] = {
                    "x": new_x,
                    "y": new_y,
                    "description": loc['description']
                }
                print(f"⚠ {name}: Original ({loc['x']:.2f}, {loc['y']:.2f}) was occupied, moved to ({new_x:.2f}, {new_y:.2f})")
            else:
                print(f"✗ {name}: Could not find valid position near ({loc['x']:.2f}, {loc['y']:.2f})")

with open('office_locations.json', 'w') as f:
    json.dump(validated_locations, f, indent=2)

print(f"\nUpdated {len(validated_locations)} valid locations in office_locations.json")