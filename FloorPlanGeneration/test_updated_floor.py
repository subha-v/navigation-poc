#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from astar_navigation import FloorPlanNavigator

def main():
    print("Testing A* on Updated Floor Plan...")
    
    navigator = FloorPlanNavigator('floor_plan_updated_config.yaml')
    
    # Test points in clear areas
    test_paths = [
        ((300, 800), (840, 800), "Left to Right"),
        ((570, 800), (570, 2500), "Top to Middle"),
        ((570, 2500), (570, 3500), "Middle to Lower"),
    ]
    
    successful = 0
    for start, goal, desc in test_paths:
        print(f"\nTesting: {desc}")
        path = navigator.find_path(start, goal)
        if path:
            length = navigator.calculate_path_length(path)
            print(f"  ✓ Path found: {length:.2f}m")
            successful += 1
        else:
            print(f"  ✗ No path found")
    
    print(f"\nSuccess: {successful}/{len(test_paths)} paths found")
    
    if successful > 0:
        # Visualize one successful path
        start, goal, desc = test_paths[0]
        path = navigator.find_path(start, goal)
        if path:
            fig, ax = plt.subplots(figsize=(8, 16))
            ax.imshow(navigator.map_array, cmap='gray', alpha=0.7)
            path_array = [[p[0], p[1]] for p in path]
            import numpy as np
            path_array = np.array(path_array)
            ax.plot(path_array[:, 0], path_array[:, 1], 'b-', linewidth=2)
            ax.plot(start[0], start[1], 'go', markersize=10)
            ax.plot(goal[0], goal[1], 'ro', markersize=10)
            ax.set_title('A* Path on Updated Floor Plan')
            ax.axis('off')
            plt.savefig('updated_floor_test.png', dpi=150, bbox_inches='tight')
            print("Visualization saved to updated_floor_test.png")

if __name__ == "__main__":
    main()