import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageDraw
import yaml
import os
import re
from svgpathtools import svg2paths2, Path
import matplotlib.pyplot as plt
from matplotlib.patches import PathPatch
from matplotlib.path import Path as MPath

def parse_svg_dimensions(svg_file):
    """Parse SVG file to get dimensions and viewBox"""
    tree = ET.parse(svg_file)
    root = tree.getroot()
    
    # Get viewBox or width/height
    viewbox = root.get('viewBox')
    width = root.get('width')
    height = root.get('height')
    
    if viewbox:
        parts = viewbox.split()
        min_x, min_y, vb_width, vb_height = map(float, parts)
        return min_x, min_y, vb_width, vb_height
    elif width and height:
        # Remove units if present
        width = float(re.findall(r'[\d.]+', width)[0]) if re.findall(r'[\d.]+', width) else 1000
        height = float(re.findall(r'[\d.]+', height)[0]) if re.findall(r'[\d.]+', height) else 1000
        return 0, 0, width, height
    else:
        # Default dimensions if not specified
        return 0, 0, 1000, 1000

def svg_to_png_matplotlib(svg_file, resolution_cm=2, max_size=4000):
    """Convert SVG to PNG using matplotlib and svgpathtools"""
    print(f"Converting SVG to PNG using matplotlib")
    
    # Parse SVG paths
    paths, attributes, svg_attributes = svg2paths2(svg_file)
    
    # Get SVG dimensions
    min_x, min_y, svg_width, svg_height = parse_svg_dimensions(svg_file)
    
    # Calculate bounds from paths
    all_points = []
    for path in paths:
        for segment in path:
            # Sample points along the segment
            for t in np.linspace(0, 1, 10):
                point = segment.point(t)
                all_points.append([point.real, point.imag])
    
    if all_points:
        all_points = np.array(all_points)
        path_min_x = np.min(all_points[:, 0])
        path_max_x = np.max(all_points[:, 0])
        path_min_y = np.min(all_points[:, 1])
        path_max_y = np.max(all_points[:, 1])
        
        # Use path bounds if available
        width = path_max_x - path_min_x
        height = path_max_y - path_min_y
        min_x = path_min_x
        min_y = path_min_y
    else:
        width = svg_width
        height = svg_height
    
    # Add padding
    padding = max(width, height) * 0.05
    min_x -= padding
    min_y -= padding
    width += 2 * padding
    height += 2 * padding
    
    # Estimate real-world dimensions (assuming width represents ~20 meters)
    estimated_width_meters = 20.0
    meters_per_unit = estimated_width_meters / width
    
    real_width = width * meters_per_unit
    real_height = height * meters_per_unit
    
    # Calculate image dimensions based on resolution
    resolution_meters = resolution_cm / 100.0
    img_width = int(real_width / resolution_meters)
    img_height = int(real_height / resolution_meters)
    
    # Limit maximum size
    if max(img_width, img_height) > max_size:
        scale_factor = max_size / max(img_width, img_height)
        img_width = int(img_width * scale_factor)
        img_height = int(img_height * scale_factor)
        resolution_meters = real_width / img_width
    
    print(f"Creating image: {img_width}x{img_height} pixels")
    print(f"Real-world dimensions: {real_width:.2f}m x {real_height:.2f}m")
    print(f"Resolution: {resolution_meters*100:.2f} cm/pixel")
    
    # Create figure with white background
    dpi = 100
    fig_width = img_width / dpi
    fig_height = img_height / dpi
    
    fig, ax = plt.subplots(figsize=(fig_width, fig_height), dpi=dpi)
    ax.set_xlim(min_x, min_x + width)
    ax.set_ylim(min_y + height, min_y)  # Flip Y axis
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_facecolor('white')
    ax.set_facecolor('white')
    
    # Draw paths
    for path, attrs in zip(paths, attributes):
        # Convert svg path to matplotlib path
        vertices = []
        codes = []
        
        for segment in path:
            # Sample points along the segment
            points = []
            for t in np.linspace(0, 1, 20):
                point = segment.point(t)
                points.append([point.real, point.imag])
            
            if not vertices:
                vertices.append(points[0])
                codes.append(MPath.MOVETO)
            
            for point in points[1:]:
                vertices.append(point)
                codes.append(MPath.LINETO)
        
        if vertices:
            mpath = MPath(vertices, codes)
            
            # Determine stroke and fill
            stroke = attrs.get('stroke', 'black')
            fill = attrs.get('fill', 'none')
            stroke_width = float(attrs.get('stroke-width', '1').replace('px', ''))
            
            # Convert RGB strings to hex or use default
            if stroke and stroke.startswith('rgb'):
                # Parse rgb(r,g,b) format
                try:
                    rgb_vals = re.findall(r'\d+', stroke)
                    if len(rgb_vals) >= 3:
                        r, g, b = int(rgb_vals[0]), int(rgb_vals[1]), int(rgb_vals[2])
                        stroke = '#{:02x}{:02x}{:02x}'.format(r, g, b)
                    else:
                        stroke = 'black'
                except:
                    stroke = 'black'
            
            if fill and fill.startswith('rgb'):
                try:
                    rgb_vals = re.findall(r'\d+', fill)
                    if len(rgb_vals) >= 3:
                        r, g, b = int(rgb_vals[0]), int(rgb_vals[1]), int(rgb_vals[2])
                        fill = '#{:02x}{:02x}{:02x}'.format(r, g, b)
                    else:
                        fill = 'none'
                except:
                    fill = 'none'
            
            # Draw the path
            if fill != 'none' and fill != 'transparent':
                patch = PathPatch(mpath, facecolor=fill, edgecolor='none')
                ax.add_patch(patch)
            
            if stroke != 'none' and stroke != 'transparent':
                patch = PathPatch(mpath, facecolor='none', edgecolor=stroke, 
                                linewidth=stroke_width * 0.5)
                ax.add_patch(patch)
    
    # Save to temporary file and load as PIL image
    import tempfile
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
        fig.savefig(tmp.name, dpi=dpi, bbox_inches='tight', pad_inches=0, 
                   facecolor='white', edgecolor='none')
        tmp_path = tmp.name
    
    img = Image.open(tmp_path)
    os.unlink(tmp_path)  # Delete temporary file
    
    plt.close(fig)
    
    # Process image to ensure walls are clear
    img_array = np.array(img)
    gray = np.mean(img_array, axis=2).astype(np.uint8)
    
    # Invert if necessary (make walls black, space white)
    if np.mean(gray) < 128:
        gray = 255 - gray
    
    # Apply threshold
    threshold = 200
    binary = (gray > threshold).astype(np.uint8) * 255
    
    # Convert back to RGB
    img = Image.fromarray(binary, mode='L').convert('RGB')
    
    return img, min_x * meters_per_unit, min_y * meters_per_unit, \
           (min_x + width) * meters_per_unit, (min_y + height) * meters_per_unit, \
           resolution_meters

def generate_yaml_config(min_x, min_y, max_x, max_y, resolution, image_filename, svg_filename):
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
            'format': 'SVG',
            'original_file': os.path.basename(svg_filename),
            'estimated_scale': 'SVG width mapped to ~20 meters'
        }
    }
    
    return config

def main():
    # Input files
    svg_file = "[Polycam Floor Plan] 8_19_2025.svg"
    output_png = "floor_plan_svg.png"
    output_yaml = "floor_plan_svg_config.yaml"
    
    print(f"Processing SVG file: {svg_file}")
    
    # Convert SVG to PNG
    img, min_x, min_y, max_x, max_y, resolution = svg_to_png_matplotlib(
        svg_file, resolution_cm=2
    )
    
    # Save PNG
    print(f"Saving floor plan to: {output_png}")
    img.save(output_png)
    
    # Generate and save YAML
    print(f"Generating YAML configuration: {output_yaml}")
    config = generate_yaml_config(min_x, min_y, max_x, max_y, resolution, 
                                 output_png, svg_file)
    
    with open(output_yaml, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("\nSVG conversion complete!")
    print(f"Floor plan saved to: {output_png}")
    print(f"Configuration saved to: {output_yaml}")

if __name__ == "__main__":
    main()