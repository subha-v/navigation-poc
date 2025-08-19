import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
import yaml
import struct
from pathlib import Path
from scipy.spatial import ConvexHull
from scipy.ndimage import binary_dilation, binary_erosion, binary_closing
from skimage import morphology
from skimage.measure import find_contours
import cv2

def read_ply_file(filename):
    """Read PLY file and extract point cloud data"""
    points = []
    colors = []
    
    with open(filename, 'rb') as f:
        # Read header
        header_lines = []
        while True:
            line = f.readline().decode('ascii').strip()
            header_lines.append(line)
            if line == 'end_header':
                break
        
        # Parse header to get vertex count and properties
        vertex_count = 0
        for line in header_lines:
            if line.startswith('element vertex'):
                vertex_count = int(line.split()[2])
                break
        
        print(f"Reading {vertex_count} vertices from PLY file...")
        
        # Read binary data (assuming binary_little_endian format)
        for i in range(vertex_count):
            # Read x, y, z as doubles (8 bytes each)
            x = struct.unpack('<d', f.read(8))[0]
            y = struct.unpack('<d', f.read(8))[0]
            z = struct.unpack('<d', f.read(8))[0]
            
            # Read RGB as unsigned chars (1 byte each)
            r = struct.unpack('<B', f.read(1))[0]
            g = struct.unpack('<B', f.read(1))[0]
            b = struct.unpack('<B', f.read(1))[0]
            
            points.append([x, y, z])
            colors.append([r, g, b])
            
            if i % 100000 == 0:
                print(f"  Processed {i}/{vertex_count} vertices")
    
    return np.array(points), np.array(colors)

def project_to_2d_floor_plan(points, colors, resolution_cm=2, z_threshold_percentile=10):
    """
    Project 3D point cloud to 2D floor plan
    resolution_cm: resolution in centimeters (1-3 cm for high accuracy)
    z_threshold_percentile: percentile to determine floor height
    """
    print("Projecting to 2D floor plan...")
    
    # Determine floor height (use lower percentile of z values)
    z_floor = np.percentile(points[:, 2], z_threshold_percentile)
    z_ceiling = np.percentile(points[:, 2], 100 - z_threshold_percentile)
    
    # Filter points that are near floor level (walls extend from floor to ceiling)
    # We'll take points from the lower portion to capture walls
    z_range = z_ceiling - z_floor
    z_max_for_floor = z_floor + z_range * 0.3  # Use bottom 30% for floor plan
    
    floor_mask = points[:, 2] <= z_max_for_floor
    floor_points = points[floor_mask]
    floor_colors = colors[floor_mask]
    
    print(f"Using {len(floor_points)} points for floor plan (z range: {z_floor:.2f} to {z_max_for_floor:.2f})")
    
    # Get 2D coordinates (x, y)
    points_2d = floor_points[:, :2]
    
    # Determine bounds
    min_x, min_y = points_2d.min(axis=0)
    max_x, max_y = points_2d.max(axis=0)
    
    # Convert resolution from cm to coordinate units
    # Assuming the PLY file uses meters as units
    resolution = resolution_cm / 100.0
    
    # Calculate image dimensions
    width = int((max_x - min_x) / resolution) + 1
    height = int((max_y - min_y) / resolution) + 1
    
    print(f"Floor plan dimensions: {width}x{height} pixels")
    print(f"Real-world dimensions: {max_x - min_x:.2f}m x {max_y - min_y:.2f}m")
    
    # Create occupancy grid
    occupancy_grid = np.zeros((height, width), dtype=np.uint8)
    color_grid = np.zeros((height, width, 3), dtype=np.uint8)
    
    # Map points to grid
    for point, color in zip(points_2d, floor_colors):
        x_idx = int((point[0] - min_x) / resolution)
        y_idx = int((point[1] - min_y) / resolution)
        
        if 0 <= x_idx < width and 0 <= y_idx < height:
            occupancy_grid[y_idx, x_idx] = 255
            color_grid[y_idx, x_idx] = color
    
    # Apply morphological operations to clean up the floor plan
    kernel_size = max(3, int(5 / resolution_cm))  # Adaptive kernel size
    kernel = np.ones((kernel_size, kernel_size), np.uint8)
    
    # Close gaps in walls
    occupancy_grid = cv2.morphologyEx(occupancy_grid, cv2.MORPH_CLOSE, kernel)
    
    # Dilate slightly to make walls more visible
    occupancy_grid = cv2.dilate(occupancy_grid, kernel, iterations=1)
    
    # Find contours to identify rooms and walls
    contours, _ = cv2.findContours(occupancy_grid, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    
    # Create final floor plan image
    floor_plan = np.ones((height, width, 3), dtype=np.uint8) * 255  # White background
    
    # Draw walls in black
    for contour in contours:
        cv2.drawContours(floor_plan, [contour], -1, (0, 0, 0), 2)
    
    # Fill occupied areas with light gray
    occupied_mask = occupancy_grid > 0
    floor_plan[occupied_mask] = [200, 200, 200]
    
    # Re-draw walls in black for clarity
    edge_mask = cv2.Canny(occupancy_grid, 50, 150)
    floor_plan[edge_mask > 0] = [0, 0, 0]
    
    return floor_plan, min_x, min_y, max_x, max_y, resolution

def generate_yaml_config(min_x, min_y, max_x, max_y, resolution, image_filename):
    """Generate YAML configuration for A* pathfinding"""
    
    # Calculate real-world dimensions
    width_meters = max_x - min_x
    height_meters = max_y - min_y
    
    # Convert numpy types to Python native types
    config = {
        'map': {
            'image': image_filename,
            'resolution': float(resolution),  # meters per pixel
            'origin': [float(min_x), float(min_y), 0.0],  # [x, y, theta]
            'occupied_thresh': 0.65,
            'free_thresh': 0.196,
            'negate': 0  # 0 = white is free, black is occupied
        },
        'dimensions': {
            'width_meters': float(width_meters),
            'height_meters': float(height_meters),
            'width_pixels': int(width_meters / resolution),
            'height_pixels': int(height_meters / resolution)
        },
        'pathfinding': {
            'algorithm': 'A*',
            'allow_diagonal': True,
            'heuristic': 'euclidean',
            'obstacle_threshold': 128,  # Grayscale value above which is considered obstacle
            'safety_margin_cm': 10  # Safety margin around obstacles
        },
        'coordinate_system': {
            'unit': 'meters',
            'origin_description': 'Bottom-left corner of the map',
            'x_axis': 'East',
            'y_axis': 'North'
        }
    }
    
    return config

def main():
    # Input and output files
    ply_file = "8_19_2025.ply"
    output_png = "floor_plan.png"
    output_yaml = "floor_plan_config.yaml"
    
    # Read PLY file
    print(f"Reading PLY file: {ply_file}")
    points, colors = read_ply_file(ply_file)
    
    # Generate floor plan with 2cm resolution for high accuracy
    floor_plan, min_x, min_y, max_x, max_y, resolution = project_to_2d_floor_plan(
        points, colors, resolution_cm=2
    )
    
    # Save floor plan as PNG
    print(f"Saving floor plan to: {output_png}")
    floor_plan_image = Image.fromarray(floor_plan)
    floor_plan_image.save(output_png)
    
    # Generate and save YAML configuration
    print(f"Generating YAML configuration: {output_yaml}")
    config = generate_yaml_config(min_x, min_y, max_x, max_y, resolution, output_png)
    
    with open(output_yaml, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("\nConversion complete!")
    print(f"Floor plan saved to: {output_png}")
    print(f"Configuration saved to: {output_yaml}")
    print(f"\nMap details:")
    print(f"  Resolution: {resolution*100:.1f} cm/pixel")
    print(f"  Dimensions: {max_x - min_x:.2f}m x {max_y - min_y:.2f}m")
    print(f"  Image size: {floor_plan.shape[1]}x{floor_plan.shape[0]} pixels")

if __name__ == "__main__":
    main()