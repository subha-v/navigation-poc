#!/usr/bin/env python3

from flask import Flask, render_template_string, request, jsonify, send_from_directory
from flask_cors import CORS
import json
import os
from astar_navigation import FloorPlanNavigator

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configuration
CONFIG_FILE = 'floor_plan_updated_config.yaml'
LOCATIONS_FILE = 'office_locations_updated.json'

# Initialize navigator
navigator = FloorPlanNavigator(CONFIG_FILE)

@app.route('/')
def index():
    """Serve the main HTML interface"""
    with open('web_map_editor.html', 'r') as f:
        return f.read()

@app.route('/<path:filename>')
def serve_static(filename):
    """Serve static files (images, etc.)"""
    return send_from_directory('.', filename)

@app.route('/api/locations', methods=['GET'])
def get_locations():
    """Get all saved locations"""
    if os.path.exists(LOCATIONS_FILE):
        with open(LOCATIONS_FILE, 'r') as f:
            locations = json.load(f)
    else:
        locations = {}
    return jsonify(locations)

@app.route('/api/locations', methods=['POST'])
def save_locations():
    """Save locations to file"""
    locations = request.json
    with open(LOCATIONS_FILE, 'w') as f:
        json.dump(locations, f, indent=2)
    return jsonify({'status': 'success', 'count': len(locations)})

@app.route('/api/validate_position', methods=['POST'])
def validate_position():
    """Check if a position is valid (not occupied)"""
    data = request.json
    x_meters = data['x']
    y_meters = data['y']
    
    x_pixels, y_pixels = navigator.meters_to_pixels(x_meters, y_meters)
    is_valid = navigator.is_valid_position(x_pixels, y_pixels)
    
    return jsonify({
        'valid': is_valid,
        'x_pixels': x_pixels,
        'y_pixels': y_pixels
    })

@app.route('/api/find_path', methods=['POST'])
def find_path():
    """Find A* path between two locations"""
    data = request.json
    start = data['start']  # {x: meters, y: meters}
    goal = data['goal']    # {x: meters, y: meters}
    
    # Convert to pixels
    start_pixels = navigator.meters_to_pixels(start['x'], start['y'])
    goal_pixels = navigator.meters_to_pixels(goal['x'], goal['y'])
    
    # Find path
    path = navigator.find_path(start_pixels, goal_pixels)
    
    if path:
        # Calculate distance
        distance = navigator.calculate_path_length(path)
        
        # Convert path to list for JSON serialization
        path_list = [[int(p[0]), int(p[1])] for p in path]
        
        return jsonify({
            'success': True,
            'path': path_list,
            'distance': round(distance, 2),
            'waypoints': len(path)
        })
    else:
        return jsonify({
            'success': False,
            'error': 'No path found'
        })

@app.route('/api/map_info', methods=['GET'])
def get_map_info():
    """Get map configuration information"""
    return jsonify({
        'width_meters': navigator.width_meters,
        'height_meters': navigator.height_meters,
        'resolution': navigator.resolution,
        'image_width': navigator.map_array.shape[1],
        'image_height': navigator.map_array.shape[0],
        'robot_radius': navigator.config['robot_radius'],
        'inflation_radius': navigator.config['inflation_radius']
    })

if __name__ == '__main__':
    print("=" * 50)
    print("VALUENEX Office Map Server")
    print("=" * 50)
    print(f"Configuration: {CONFIG_FILE}")
    print(f"Locations file: {LOCATIONS_FILE}")
    print(f"Map dimensions: {navigator.width_meters:.2f}m x {navigator.height_meters:.2f}m")
    print(f"Resolution: {navigator.resolution*1000:.0f}mm per pixel")
    print("=" * 50)
    print("Server starting on http://localhost:5000")
    print("Open this URL in your browser to use the map editor")
    print("=" * 50)
    
    app.run(debug=True, port=5000)