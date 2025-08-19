#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
from astar_navigation import FloorPlanNavigator
import json

def main():
    navigator = FloorPlanNavigator('floor_plan_config.yaml')
    
    with open('office_locations.json', 'r') as f:
        locations = json.load(f)
    
    print(f"Floor plan dimensions: {navigator.width_meters:.2f}m x {navigator.height_meters:.2f}m")
    print(f"Image dimensions: {navigator.map_array.shape[1]} x {navigator.map_array.shape[0]} pixels")
    print(f"Resolution: {navigator.resolution:.3f} meters/pixel")
    print(f"Available locations: {list(locations.keys())}")
    print()
    
    test_routes = [
        ("entrance", "reception"),
        ("desk_area_1", "desk_area_2"),
        ("meeting_room_2", "meeting_room_3"),
        ("storage_area", "workstation_1"),
        ("entrance", "elevator_area"),
    ]
    
    successful_paths = 0
    
    for start_name, goal_name in test_routes:
        if start_name in locations and goal_name in locations:
            start_loc = locations[start_name]
            goal_loc = locations[goal_name]
            
            start_pixels = navigator.meters_to_pixels(start_loc['x'], start_loc['y'])
            goal_pixels = navigator.meters_to_pixels(goal_loc['x'], goal_loc['y'])
            
            print(f"\nFinding path from {start_name} to {goal_name}:")
            print(f"  Start: ({start_loc['x']:.2f}m, {start_loc['y']:.2f}m) -> pixels {start_pixels}")
            print(f"  Goal: ({goal_loc['x']:.2f}m, {goal_loc['y']:.2f}m) -> pixels {goal_pixels}")
            
            path = navigator.find_path(start_pixels, goal_pixels)
            
            if path:
                distance = navigator.calculate_path_length(path)
                print(f"  ✓ Path found! Length: {distance:.2f} meters ({len(path)} waypoints)")
                
                save_name = f"path_{start_name}_to_{goal_name}.png"
                fig = navigator.visualize_path(path, start_name, goal_name, save_name)
                plt.close(fig)
                print(f"  Visualization saved to {save_name}")
                successful_paths += 1
            else:
                print(f"  ✗ No path found!")
    
    print(f"\n========================================")
    print(f"Summary: {successful_paths}/{len(test_routes)} paths successfully found")
    print(f"========================================")
    
    print("\nThe A* navigation system is working! You can:")
    print("1. Add more locations to office_locations.json")
    print("2. Adjust robot_radius and inflation_radius in floor_plan_config.yaml")
    print("3. Use the FloorPlanNavigator class in your own applications")

if __name__ == "__main__":
    main()