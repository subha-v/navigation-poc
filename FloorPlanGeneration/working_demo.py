#!/usr/bin/env python3

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
from astar_navigation import FloorPlanNavigator

def main():
    print("=== VALUENEX Office A* Navigation Demo ===\n")
    
    navigator = FloorPlanNavigator('floor_plan_config.yaml')
    
    # Manually select clear walkable areas from visual inspection
    test_points = [
        (570, 800),   # Upper middle area
        (300, 800),   # Upper left
        (840, 800),   # Upper right
        (570, 2500),  # Middle area
        (570, 3500),  # Lower middle
    ]
    
    print(f"Office: {navigator.width_meters:.2f}m × {navigator.height_meters:.2f}m")
    print(f"Resolution: {navigator.resolution*1000:.0f}mm/pixel")
    print(f"Robot radius: {navigator.config['robot_radius']*100:.0f}cm\n")
    
    # Test multiple path combinations
    path_tests = [
        (test_points[1], test_points[2], "Left to Right (Upper)"),
        (test_points[0], test_points[3], "Upper to Middle"),
        (test_points[3], test_points[4], "Middle to Lower"),
    ]
    
    successful = 0
    results = []
    
    for start, goal, description in path_tests:
        start_m = navigator.pixels_to_meters(start[0], start[1])
        goal_m = navigator.pixels_to_meters(goal[0], goal[1])
        
        print(f"\nTest: {description}")
        print(f"  From: ({start_m[0]:.2f}m, {start_m[1]:.2f}m)")
        print(f"  To: ({goal_m[0]:.2f}m, {goal_m[1]:.2f}m)")
        
        path = navigator.find_path(start, goal)
        
        if path:
            length = navigator.calculate_path_length(path)
            print(f"  ✓ SUCCESS: {length:.2f}m path with {len(path)} waypoints")
            successful += 1
            results.append((path, start, goal, description, length))
        else:
            print(f"  ✗ Failed to find path")
    
    print(f"\n{'='*50}")
    print(f"Success rate: {successful}/{len(path_tests)} paths found")
    print(f"{'='*50}")
    
    # Create comprehensive visualization
    if results:
        fig = plt.figure(figsize=(12, 20))
        
        # Show original map
        ax1 = plt.subplot(3, 1, 1)
        ax1.imshow(navigator.map_array, cmap='gray')
        ax1.set_title('Original Floor Plan', fontsize=14)
        ax1.axis('off')
        
        # Show inflated map with obstacles
        ax2 = plt.subplot(3, 1, 2)
        ax2.imshow(navigator.inflated_map, cmap='gray_r')
        ax2.set_title('Map with Robot Clearance (Inflated Obstacles)', fontsize=14)
        ax2.axis('off')
        
        # Show all successful paths
        ax3 = plt.subplot(3, 1, 3)
        ax3.imshow(navigator.map_array, cmap='gray', alpha=0.7)
        
        colors = ['blue', 'green', 'red', 'orange', 'purple']
        for i, (path, start, goal, desc, length) in enumerate(results):
            path_array = np.array(path)
            color = colors[i % len(colors)]
            ax3.plot(path_array[:, 0], path_array[:, 1], color=color, linewidth=2, 
                    label=f'{desc}: {length:.1f}m', alpha=0.8)
            ax3.plot(start[0], start[1], 'o', color=color, markersize=8)
            ax3.plot(goal[0], goal[1], 's', color=color, markersize=8)
        
        ax3.set_title('A* Pathfinding Results', fontsize=14)
        ax3.legend(loc='upper right', fontsize=10)
        ax3.axis('off')
        
        plt.tight_layout()
        plt.savefig('navigation_demo.png', dpi=150, bbox_inches='tight')
        print(f"\n✅ Visualization saved to navigation_demo.png")
        
        # Save the first successful path for detailed view
        if results:
            path, start, goal, desc, length = results[0]
            fig2, ax = plt.subplots(figsize=(8, 16))
            
            # Create colored map
            display = np.stack([navigator.map_array/255] * 3, axis=2)
            
            # Draw path
            path_array = np.array(path)
            for i in range(len(path)-1):
                ax.plot([path[i][0], path[i+1][0]], [path[i][1], path[i+1][1]], 
                       'b-', linewidth=3, alpha=0.7)
            
            ax.imshow(display)
            ax.plot(start[0], start[1], 'go', markersize=12, label='Start')
            ax.plot(goal[0], goal[1], 'ro', markersize=12, label='Goal')
            ax.set_title(f'{desc}\nPath Length: {length:.2f}m', fontsize=14)
            ax.legend(fontsize=12)
            ax.axis('off')
            
            plt.tight_layout()
            plt.savefig('path_detail.png', dpi=150, bbox_inches='tight')
            print(f"✅ Detailed path saved to path_detail.png")
    
    print("\n🎉 A* Navigation System Ready!")
    print("The system can now:")
    print("• Find optimal paths avoiding obstacles")
    print("• Respect robot clearance requirements")
    print("• Calculate accurate path distances")
    print("• Integrate with your indoor navigation app")

if __name__ == "__main__":
    main()