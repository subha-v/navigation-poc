import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageDraw
import yaml
import os
import re
import cairosvg
from io import BytesIO

def parse_svg_dimensions(svg_file):
    """Parse SVG file to get dimensions and viewBox"""
    tree = ET.parse(svg_file)
    root = tree.getroot()
    
    # Get SVG namespace
    namespace = {'svg': 'http://www.w3.org/2000/svg'}
    
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
        width = float(re.findall(r'[\d.]+', width)[0])
        height = float(re.findall(r'[\d.]+', height)[0])
        return 0, 0, width, height
    else:
        # Default dimensions if not specified
        return 0, 0, 1000, 1000

def svg_to_png_cairo(svg_file, output_png, scale_factor=1.0):
    """Convert SVG to PNG using cairosvg"""
    print(f"Converting SVG to PNG with scale factor: {scale_factor}")
    
    # Read SVG content
    with open(svg_file, 'rb') as f:
        svg_content = f.read()
    
    # Convert to PNG
    png_data = cairosvg.svg2png(
        bytestring=svg_content,
        scale=scale_factor
    )
    
    # Load as PIL Image
    img = Image.open(BytesIO(png_data))
    
    # Convert to RGB if necessary
    if img.mode == 'RGBA':
        # Create white background
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    return img

def calculate_real_world_dimensions(svg_file, target_resolution_cm=2):
    """Calculate real-world dimensions and scale factor"""
    
    # Parse SVG dimensions
    min_x, min_y, width, height = parse_svg_dimensions(svg_file)
    
    # Assume SVG units are in pixels, and we want to map to real-world dimensions
    # We'll assume a reasonable scale where the floor plan represents a real space
    # Typical floor plan might be 10-30 meters across
    
    # Estimate real-world dimensions (assuming SVG width represents ~20 meters)
    estimated_width_meters = 20.0  # Adjust this based on your actual floor plan
    svg_to_meters_ratio = estimated_width_meters / width
    
    real_width = width * svg_to_meters_ratio
    real_height = height * svg_to_meters_ratio
    
    # Calculate scale factor for desired resolution
    resolution_meters = target_resolution_cm / 100.0
    pixels_per_meter = 1.0 / resolution_meters
    
    # Scale factor to achieve desired resolution
    scale_factor = pixels_per_meter * svg_to_meters_ratio
    
    # Calculate output dimensions
    output_width = int(width * scale_factor)
    output_height = int(height * scale_factor)
    
    # Limit maximum size
    max_dim = 4000
    if max(output_width, output_height) > max_dim:
        limiting_factor = max_dim / max(output_width, output_height)
        scale_factor *= limiting_factor
        output_width = int(width * scale_factor)
        output_height = int(height * scale_factor)
        resolution_meters = real_width / output_width
    
    return {
        'min_x': min_x * svg_to_meters_ratio,
        'min_y': min_y * svg_to_meters_ratio,
        'real_width': real_width,
        'real_height': real_height,
        'scale_factor': scale_factor,
        'resolution': resolution_meters,
        'output_width': output_width,
        'output_height': output_height
    }

def process_floor_plan_image(img):
    """Process the floor plan image to ensure walls are clearly defined"""
    
    # Convert to numpy array
    img_array = np.array(img)
    
    # Convert to grayscale if needed
    if len(img_array.shape) == 3:
        gray = np.mean(img_array, axis=2).astype(np.uint8)
    else:
        gray = img_array
    
    # Threshold to create binary image (walls as black, space as white)
    threshold = 128
    binary = (gray > threshold).astype(np.uint8) * 255
    
    # Convert back to PIL Image
    processed_img = Image.fromarray(binary, mode='L').convert('RGB')
    
    return processed_img

def generate_yaml_config(dimensions, image_filename, svg_filename):
    """Generate YAML configuration for A* pathfinding"""
    
    config = {
        'map': {
            'image': image_filename,
            'resolution': float(dimensions['resolution']),
            'origin': [float(dimensions['min_x']), float(dimensions['min_y']), 0.0],
            'occupied_thresh': 0.65,
            'free_thresh': 0.196,
            'negate': 0
        },
        'dimensions': {
            'width_meters': float(dimensions['real_width']),
            'height_meters': float(dimensions['real_height']),
            'width_pixels': int(dimensions['output_width']),
            'height_pixels': int(dimensions['output_height'])
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
    
    # Calculate dimensions and scale
    dimensions = calculate_real_world_dimensions(svg_file, target_resolution_cm=2)
    
    print(f"Output dimensions: {dimensions['output_width']}x{dimensions['output_height']} pixels")
    print(f"Real-world dimensions: {dimensions['real_width']:.2f}m x {dimensions['real_height']:.2f}m")
    print(f"Resolution: {dimensions['resolution']*100:.2f} cm/pixel")
    
    # Convert SVG to PNG
    img = svg_to_png_cairo(svg_file, output_png, dimensions['scale_factor'])
    
    # Process the image to ensure clear walls
    img = process_floor_plan_image(img)
    
    # Save PNG
    print(f"Saving floor plan to: {output_png}")
    img.save(output_png)
    
    # Generate and save YAML
    print(f"Generating YAML configuration: {output_yaml}")
    config = generate_yaml_config(dimensions, output_png, svg_file)
    
    with open(output_yaml, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("\nSVG conversion complete!")
    print(f"Floor plan saved to: {output_png}")
    print(f"Configuration saved to: {output_yaml}")

if __name__ == "__main__":
    main()