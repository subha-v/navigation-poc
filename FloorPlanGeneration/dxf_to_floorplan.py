import ezdxf
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image, ImageDraw
import yaml
import os
from pathlib import Path

def read_dxf_file(filename):
    """Read DXF file and extract entities"""
    print(f"Reading DXF file: {filename}")
    doc = ezdxf.readfile(filename)
    msp = doc.modelspace()
    
    lines = []
    polylines = []
    circles = []
    arcs = []
    
    # Extract different entity types
    for entity in msp:
        if entity.dxftype() == 'LINE':
            start = entity.dxf.start
            end = entity.dxf.end
            lines.append([(start.x, start.y), (end.x, end.y)])
        
        elif entity.dxftype() == 'LWPOLYLINE':
            points = []
            for point in entity.get_points():
                points.append((point[0], point[1]))
            if len(points) > 1:
                polylines.append(points)
        
        elif entity.dxftype() == 'POLYLINE':
            points = []
            for vertex in entity.vertices:
                points.append((vertex.dxf.location.x, vertex.dxf.location.y))
            if len(points) > 1:
                polylines.append(points)
        
        elif entity.dxftype() == 'CIRCLE':
            center = entity.dxf.center
            radius = entity.dxf.radius
            circles.append(((center.x, center.y), radius))
        
        elif entity.dxftype() == 'ARC':
            center = entity.dxf.center
            radius = entity.dxf.radius
            start_angle = entity.dxf.start_angle
            end_angle = entity.dxf.end_angle
            arcs.append(((center.x, center.y), radius, start_angle, end_angle))
    
    print(f"Found {len(lines)} lines, {len(polylines)} polylines, {len(circles)} circles, {len(arcs)} arcs")
    return lines, polylines, circles, arcs

def get_bounds(lines, polylines, circles, arcs):
    """Calculate the bounding box of all entities"""
    all_x = []
    all_y = []
    
    # Lines
    for line in lines:
        for point in line:
            all_x.append(point[0])
            all_y.append(point[1])
    
    # Polylines
    for polyline in polylines:
        for point in polyline:
            all_x.append(point[0])
            all_y.append(point[1])
    
    # Circles
    for (center, radius) in circles:
        all_x.extend([center[0] - radius, center[0] + radius])
        all_y.extend([center[1] - radius, center[1] + radius])
    
    # Arcs
    for (center, radius, _, _) in arcs:
        all_x.extend([center[0] - radius, center[0] + radius])
        all_y.extend([center[1] - radius, center[1] + radius])
    
    if not all_x or not all_y:
        return 0, 0, 100, 100  # Default bounds if no entities
    
    return min(all_x), min(all_y), max(all_x), max(all_y)

def dxf_to_png(lines, polylines, circles, arcs, resolution_cm=2, output_size=(2000, 2000)):
    """Convert DXF entities to PNG floor plan"""
    
    # Get bounds
    min_x, min_y, max_x, max_y = get_bounds(lines, polylines, circles, arcs)
    
    # Add padding
    padding = (max_x - min_x) * 0.05
    min_x -= padding
    min_y -= padding
    max_x += padding
    max_y += padding
    
    width = max_x - min_x
    height = max_y - min_y
    
    # Calculate image dimensions based on resolution
    # Assuming DXF units are in meters
    resolution = resolution_cm / 100.0
    img_width = int(width / resolution)
    img_height = int(height / resolution)
    
    # Limit maximum size for memory efficiency
    max_dim = max(img_width, img_height)
    if max_dim > output_size[0]:
        scale_factor = output_size[0] / max_dim
        img_width = int(img_width * scale_factor)
        img_height = int(img_height * scale_factor)
        resolution = width / img_width
    
    print(f"Creating image: {img_width}x{img_height} pixels")
    print(f"Real-world dimensions: {width:.2f}m x {height:.2f}m")
    print(f"Resolution: {resolution*100:.2f} cm/pixel")
    
    # Create image
    img = Image.new('RGB', (img_width, img_height), 'white')
    draw = ImageDraw.Draw(img)
    
    # Scale and translate function
    def transform_point(x, y):
        px = int((x - min_x) / width * img_width)
        py = int(img_height - (y - min_y) / height * img_height)  # Flip Y axis
        return px, py
    
    # Draw entities
    line_width = max(2, int(img_width / 500))
    
    # Draw lines
    for line in lines:
        p1 = transform_point(line[0][0], line[0][1])
        p2 = transform_point(line[1][0], line[1][1])
        draw.line([p1, p2], fill='black', width=line_width)
    
    # Draw polylines
    for polyline in polylines:
        if len(polyline) > 1:
            transformed = [transform_point(p[0], p[1]) for p in polyline]
            for i in range(len(transformed) - 1):
                draw.line([transformed[i], transformed[i+1]], fill='black', width=line_width)
    
    # Draw circles
    for (center, radius) in circles:
        cx, cy = transform_point(center[0], center[1])
        r = int(radius / width * img_width)
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline='black', width=line_width)
    
    # Draw arcs
    for (center, radius, start_angle, end_angle) in arcs:
        cx, cy = transform_point(center[0], center[1])
        r = int(radius / width * img_width)
        # PIL arc uses degrees, DXF uses degrees too
        draw.arc([cx-r, cy-r, cx+r, cy+r], start=start_angle, end=end_angle, 
                fill='black', width=line_width)
    
    return img, min_x, min_y, max_x, max_y, resolution

def generate_yaml_config(min_x, min_y, max_x, max_y, resolution, image_filename):
    """Generate YAML configuration for A* pathfinding"""
    
    width_meters = max_x - min_x
    height_meters = max_y - min_y
    
    config = {
        'map': {
            'image': image_filename,
            'resolution': float(resolution),
            'origin': [float(min_x), float(min_y), 0.0],
            'occupied_thresh': 0.65,
            'free_thresh': 0.196,
            'negate': 0
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
            'obstacle_threshold': 128,
            'safety_margin_cm': 10
        },
        'coordinate_system': {
            'unit': 'meters',
            'origin_description': 'Bottom-left corner of the map',
            'x_axis': 'East',
            'y_axis': 'North'
        },
        'source': {
            'format': 'DXF',
            'original_file': os.path.basename(image_filename.replace('_dxf.png', '.dxf'))
        }
    }
    
    return config

def main():
    # Input file
    dxf_file = "[Polycam Floor Plan] 8_19_2025.dxf"
    output_png = "floor_plan_dxf.png"
    output_yaml = "floor_plan_dxf_config.yaml"
    
    # Read DXF file
    lines, polylines, circles, arcs = read_dxf_file(dxf_file)
    
    # Convert to PNG with 2cm resolution
    img, min_x, min_y, max_x, max_y, resolution = dxf_to_png(
        lines, polylines, circles, arcs, resolution_cm=2
    )
    
    # Save PNG
    print(f"Saving floor plan to: {output_png}")
    img.save(output_png)
    
    # Generate and save YAML
    print(f"Generating YAML configuration: {output_yaml}")
    config = generate_yaml_config(min_x, min_y, max_x, max_y, resolution, output_png)
    
    with open(output_yaml, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("\nDXF conversion complete!")
    print(f"Floor plan saved to: {output_png}")
    print(f"Configuration saved to: {output_yaml}")

if __name__ == "__main__":
    main()