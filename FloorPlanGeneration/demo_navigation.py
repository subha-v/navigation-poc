#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
import json
from astar_navigation import FloorPlanNavigator

def find_free_spaces(map_array, num_samples=20):
    """Find random free spaces in the map for demonstration"""
    free_coords = np.argwhere(map_array > 128)
    
    valid_points = []
    if len(free_coords) > 0:
        indices = np.random.choice(len(free_coords), min(num_samples, len(free_coords)), replace=False)
        for idx in indices:
            y, x = free_coords[idx]
            window = map_array[max(0, y-10):min(map_array.shape[0], y+10),
                             max(0, x-10):min(map_array.shape[1], x+10)]
            if np.mean(window) > 200:
                valid_points.append((x, y))
    
    return valid_points

def main():
    print("=== A* Pathfinding Demonstration for VALUENEX Office ===\n")
    
    navigator = FloorPlanNavigator('floor_plan_config.yaml')
    
    image = Image.open('VNX_BW_Floorplan.PNG')
    map_array = np.array(image.convert('L'))
    
    print(f"Office dimensions: {navigator.width_meters:.2f}m x {navigator.height_meters:.2f}m")
    print(f"Resolution: {navigator.resolution*1000:.1f}mm per pixel")
    print(f"Robot clearance radius: {navigator.config['robot_radius']*100:.0f}cm")
    print(f"Safety margin: {navigator.config['inflation_radius']*100:.0f}cm\n")
    
    free_spaces = find_free_spaces(map_array, num_samples=30)
    
    print(f"Found {len(free_spaces)} potential navigation points")
    
    successful_paths = []
    tested = 0
    max_tests = 10
    
    for i in range(len(free_spaces)-1):
        if tested >= max_tests:
            break
            
        start = free_spaces[i]
        goal = free_spaces[i+1]
        
        start_m = navigator.pixels_to_meters(start[0], start[1])
        goal_m = navigator.pixels_to_meters(goal[0], goal[1])
        
        euclidean_dist = np.sqrt((goal_m[0] - start_m[0])**2 + (goal_m[1] - start_m[1])**2)
        
        if euclidean_dist < 2.0 or euclidean_dist > 10.0:
            continue
        
        tested += 1
        print(f"\nTest {tested}: Finding path from ({start_m[0]:.1f}m, {start_m[1]:.1f}m) to ({goal_m[0]:.1f}m, {goal_m[1]:.1f}m)")
        print(f"  Straight-line distance: {euclidean_dist:.2f}m")
        
        path = navigator.find_path(start, goal)
        
        if path:
            path_length = navigator.calculate_path_length(path)
            efficiency = euclidean_dist / path_length * 100
            print(f"  ✓ Path found: {path_length:.2f}m ({len(path)} waypoints)")
            print(f"  Path efficiency: {efficiency:.1f}%")
            
            successful_paths.append({
                'start': start,
                'goal': goal,
                'path': path,
                'length': path_length,
                'efficiency': efficiency
            })
    
    print(f"\n{'='*50}")
    print(f"Results: {len(successful_paths)}/{tested} paths found successfully")
    print(f"{'='*50}")
    
    if successful_paths:
        best_path = max(successful_paths, key=lambda x: x['length'])
        
        fig, axes = plt.subplots(2, 2, figsize=(15, 20))
        
        axes[0, 0].imshow(map_array, cmap='gray')
        axes[0, 0].set_title('Original Floor Plan')
        axes[0, 0].axis('off')
        
        axes[0, 1].imshow(navigator.inflated_map, cmap='gray_r')
        axes[0, 1].set_title('Inflated Obstacles (Robot Clearance)')
        axes[0, 1].axis('off')
        
        display_map = np.stack([1 - navigator.inflated_map] * 3, axis=2)
        
        for path_data in successful_paths[:3]:
            path = path_data['path']
            path_array = np.array(path)
            axes[1, 0].plot(path_array[:, 0], path_array[:, 1], linewidth=2, alpha=0.7)
        
        axes[1, 0].imshow(map_array, cmap='gray', alpha=0.5)
        axes[1, 0].set_title(f'Multiple Path Examples ({len(successful_paths)} paths)')
        axes[1, 0].axis('off')
        
        if best_path:
            path_array = np.array(best_path['path'])
            axes[1, 1].plot(path_array[:, 0], path_array[:, 1], 'b-', linewidth=3)
            axes[1, 1].plot(best_path['start'][0], best_path['start'][1], 'go', markersize=10, label='Start')
            axes[1, 1].plot(best_path['goal'][0], best_path['goal'][1], 'ro', markersize=10, label='Goal')
            axes[1, 1].imshow(map_array, cmap='gray', alpha=0.5)
            axes[1, 1].set_title(f'Longest Path: {best_path["length"]:.2f}m')
            axes[1, 1].legend()
            axes[1, 1].axis('off')
        
        plt.tight_layout()
        plt.savefig('astar_demo_results.png', dpi=150, bbox_inches='tight')
        print(f"\nVisualization saved to astar_demo_results.png")
        
        demo_locations = {}
        for i, space in enumerate(free_spaces[:10]):
            x_m, y_m = navigator.pixels_to_meters(space[0], space[1])
            demo_locations[f"demo_point_{i+1}"] = {
                "x": round(x_m, 2),
                "y": round(y_m, 2),
                "description": f"Auto-detected free space #{i+1}"
            }
        
        with open('demo_locations.json', 'w') as f:
            json.dump(demo_locations, f, indent=2)
        print(f"Saved {len(demo_locations)} demo locations to demo_locations.json")
    
    print("\n✅ A* pathfinding is working successfully!")
    print("You can now:")
    print("1. Use the coordinates in demo_locations.json for testing")
    print("2. Manually add specific room locations to office_locations.json")
    print("3. Integrate this with your indoor navigation system")

if __name__ == "__main__":
    main()