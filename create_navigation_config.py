#!/usr/bin/env python3
"""
Create predefined anchors and POIs for the navigation system
Places anchors at strategic locations for good coverage
"""

import json
from pathlib import Path

def create_navigation_config(map_dir):
    """Create anchors and POIs for the map"""
    map_dir = Path(map_dir)
    
    # Define anchors at strategic positions for good trilateration coverage
    # Based on the map bounds from report.json: X[-10.18, 7.74], Y[-10.86, 10.32]
    anchors = [
        {
            "id": "anchor_A",
            "xy": [-5.0, 5.0],  # Top-left area
            "yaw_deg": 0
        },
        {
            "id": "anchor_B", 
            "xy": [3.0, 5.0],   # Top-right area
            "yaw_deg": 0
        },
        {
            "id": "anchor_C",
            "xy": [-5.0, -5.0], # Bottom-left area
            "yaw_deg": 0
        },
        {
            "id": "anchor_D",
            "xy": [3.0, -5.0],  # Bottom-right area
            "yaw_deg": 0
        },
        {
            "id": "anchor_E",
            "xy": [-1.0, 0.0],  # Center area for better coverage
            "yaw_deg": 0
        }
    ]
    
    # Define POIs (Points of Interest) - example locations
    pois = [
        {
            "id": "poi_1",
            "name": "Reception",
            "xy": [-8.0, 0.0]
        },
        {
            "id": "poi_2",
            "name": "Conference Room A",
            "xy": [-3.0, 3.0]
        },
        {
            "id": "poi_3",
            "name": "Conference Room B",
            "xy": [2.0, 3.0]
        },
        {
            "id": "poi_4",
            "name": "AI Healthcare Booth",
            "xy": [-2.0, -3.0]
        },
        {
            "id": "poi_5",
            "name": "Innovation Lab",
            "xy": [4.0, 0.0]
        },
        {
            "id": "poi_6",
            "name": "Cafeteria",
            "xy": [0.0, -7.0]
        },
        {
            "id": "poi_7",
            "name": "Demo Area",
            "xy": [-6.0, 7.0]
        },
        {
            "id": "poi_8",
            "name": "VR Experience Zone",
            "xy": [5.0, 7.0]
        }
    ]
    
    # Save anchors.json
    anchors_path = map_dir / "anchors.json"
    with open(anchors_path, 'w') as f:
        json.dump(anchors, f, indent=2)
    print(f"Created {len(anchors)} anchors in {anchors_path}")
    
    # Save pois.json
    pois_path = map_dir / "pois.json"
    with open(pois_path, 'w') as f:
        json.dump(pois, f, indent=2)
    print(f"Created {len(pois)} POIs in {pois_path}")
    
    # Create complete navigation config
    config = {
        "map_metadata": {
            "resolution": 0.01,
            "origin": [-10.183403122754692, -10.85751695737398, 0.0],
            "width_px": 1793,
            "height_px": 2118,
            "bounds_m": {
                "min_x": -10.183403122754692,
                "max_x": 7.7386974646492135,
                "min_y": -10.85751695737398,
                "max_y": 10.315749005479974
            }
        },
        "anchors": anchors,
        "pois": pois,
        "navigation_settings": {
            "min_anchors_for_trilateration": 3,
            "max_anchor_range_m": 20.0,
            "position_smoothing_factor": 0.3,
            "path_smoothing_epsilon": 0.5,
            "nlos_detection_threshold": 2.0
        }
    }
    
    config_path = map_dir / "navigation_config.json"
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"Created complete navigation config in {config_path}")
    
    return anchors, pois

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        map_dir = sys.argv[1]
    else:
        map_dir = "output_map_1cm"
    
    anchors, pois = create_navigation_config(map_dir)
    print(f"\nAnchors placed at:")
    for a in anchors:
        print(f"  {a['id']}: ({a['xy'][0]:.1f}, {a['xy'][1]:.1f})")
    print(f"\nPOIs created:")
    for p in pois:
        print(f"  {p['name']}: ({p['xy'][0]:.1f}, {p['xy'][1]:.1f})")