#!/usr/bin/env python3

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS, cross_origin
import json
import os
import traceback
from astar_navigation import FloorPlanNavigator

app = Flask(__name__)
# Configure CORS with explicit settings
CORS(app, resources={r"/api/*": {"origins": "*", "methods": ["GET", "POST", "OPTIONS"]}})

# Configuration
CONFIG_FILE = 'floor_plan_updated_config.yaml'
LOCATIONS_FILE = 'office_locations_updated.json'

# Initialize navigator
try:
    navigator = FloorPlanNavigator(CONFIG_FILE)
    print(f"Navigator initialized successfully")
except Exception as e:
    print(f"Error initializing navigator: {e}")
    navigator = None

@app.route('/')
def index():
    """Serve the main HTML interface"""
    try:
        with open('web_map_editor_connected.html', 'r') as f:
            return f.read()
    except FileNotFoundError:
        return "HTML file not found. Please ensure web_map_editor_connected.html exists.", 404

@app.route('/<path:filename>')
def serve_static(filename):
    """Serve static files (images, etc.)"""
    try:
        return send_from_directory('.', filename)
    except Exception as e:
        return str(e), 404

@app.route('/api/locations', methods=['GET', 'OPTIONS'])
@cross_origin()
def get_locations():
    """Get all saved locations"""
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        if os.path.exists(LOCATIONS_FILE):
            with open(LOCATIONS_FILE, 'r') as f:
                locations = json.load(f)
            print(f"Loaded {len(locations)} locations from {LOCATIONS_FILE}")
        else:
            locations = {}
            print(f"No locations file found, returning empty dict")
        return jsonify(locations)
    except Exception as e:
        print(f"Error loading locations: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/locations', methods=['POST', 'OPTIONS'])
@cross_origin()
def save_locations():
    """Save locations to file"""
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        locations = request.get_json()
        if locations is None:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        with open(LOCATIONS_FILE, 'w') as f:
            json.dump(locations, f, indent=2)
        
        print(f"Saved {len(locations)} locations to {LOCATIONS_FILE}")
        return jsonify({'status': 'success', 'count': len(locations)})
    except Exception as e:
        print(f"Error saving locations: {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/validate_position', methods=['POST', 'OPTIONS'])
@cross_origin()
def validate_position():
    """Check if a position is valid (not occupied)"""
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        if not navigator:
            return jsonify({'error': 'Navigator not initialized'}), 500
        
        data = request.get_json()
        if not data or 'x' not in data or 'y' not in data:
            return jsonify({'error': 'Missing x or y coordinates'}), 400
        
        x_meters = float(data['x'])
        y_meters = float(data['y'])
        
        x_pixels, y_pixels = navigator.meters_to_pixels(x_meters, y_meters)
        is_valid = navigator.is_valid_position(x_pixels, y_pixels)
        
        return jsonify({
            'valid': is_valid,
            'x_pixels': x_pixels,
            'y_pixels': y_pixels
        })
    except Exception as e:
        print(f"Error validating position: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/find_path', methods=['POST', 'OPTIONS'])
@cross_origin()
def find_path():
    """Find A* path between two locations"""
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        if not navigator:
            return jsonify({'error': 'Navigator not initialized'}), 500
        
        data = request.get_json()
        if not data or 'start' not in data or 'goal' not in data:
            return jsonify({'error': 'Missing start or goal coordinates'}), 400
        
        start = data['start']
        goal = data['goal']
        
        # Convert to pixels
        start_pixels = navigator.meters_to_pixels(start['x'], start['y'])
        goal_pixels = navigator.meters_to_pixels(goal['x'], goal['y'])
        
        print(f"Finding path from {start_pixels} to {goal_pixels}")
        
        # Find path
        path = navigator.find_path(start_pixels, goal_pixels)
        
        if path:
            # Calculate distance
            distance = navigator.calculate_path_length(path)
            
            # Convert path to list for JSON serialization
            path_list = [[int(p[0]), int(p[1])] for p in path]
            
            print(f"Path found: {distance:.2f}m with {len(path)} waypoints")
            
            return jsonify({
                'success': True,
                'path': path_list,
                'distance': round(distance, 2),
                'waypoints': len(path)
            })
        else:
            print("No path found")
            return jsonify({
                'success': False,
                'error': 'No path found'
            })
    except Exception as e:
        print(f"Error finding path: {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/map_info', methods=['GET', 'OPTIONS'])
@cross_origin()
def get_map_info():
    """Get map configuration information"""
    if request.method == 'OPTIONS':
        return '', 204
    
    try:
        if not navigator:
            return jsonify({'error': 'Navigator not initialized'}), 500
        
        return jsonify({
            'width_meters': navigator.width_meters,
            'height_meters': navigator.height_meters,
            'resolution': navigator.resolution,
            'image_width': navigator.map_array.shape[1],
            'image_height': navigator.map_array.shape[0],
            'robot_radius': navigator.config['robot_radius'],
            'inflation_radius': navigator.config['inflation_radius']
        })
    except Exception as e:
        print(f"Error getting map info: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/test', methods=['GET'])
@cross_origin()
def test_endpoint():
    """Test endpoint to verify server is running"""
    return jsonify({'status': 'ok', 'message': 'Server is running'})

if __name__ == '__main__':
    print("=" * 50)
    print("VALUENEX Office Map Server")
    print("=" * 50)
    print(f"Configuration: {CONFIG_FILE}")
    print(f"Locations file: {LOCATIONS_FILE}")
    
    if navigator:
        print(f"Map dimensions: {navigator.width_meters:.2f}m x {navigator.height_meters:.2f}m")
        print(f"Resolution: {navigator.resolution*1000:.0f}mm per pixel")
    else:
        print("WARNING: Navigator not initialized properly")
    
    print("=" * 50)
    print("Server starting on http://localhost:5001")
    print("Open this URL in your browser to use the map editor")
    print("Test the server: http://localhost:5001/api/test")
    print("=" * 50)
    
    # Run with host='0.0.0.0' to allow external connections
    app.run(debug=True, host='0.0.0.0', port=5001)