#!/usr/bin/env python3

import yaml
import numpy as np
from PIL import Image
import heapq
import matplotlib.pyplot as plt
import json
from typing import List, Tuple, Optional, Dict
import cv2

class FloorPlanNavigator:
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.image = Image.open(self.config['image'])
        self.map_array = np.array(self.image.convert('L'))
        
        self.map_array = (self.map_array < 128).astype(np.uint8)
        
        self.resolution = self.config['resolution']
        self.width_meters = self.config['width_meters']
        self.height_meters = self.config['height_meters']
        
        self.robot_radius_pixels = int(self.config['robot_radius'] / self.resolution)
        self.inflation_radius_pixels = int(self.config['inflation_radius'] / self.resolution)
        
        self.inflated_map = self._inflate_obstacles()
        
        self.allow_diagonal = self.config.get('allow_diagonal', True)
        self.diagonal_cost = self.config.get('diagonal_cost', 1.414)
        self.straight_cost = self.config.get('straight_cost', 1.0)
    
    def _inflate_obstacles(self) -> np.ndarray:
        kernel_size = 2 * self.inflation_radius_pixels + 1
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
        inflated = cv2.dilate(self.map_array, kernel, iterations=1)
        return inflated
    
    def meters_to_pixels(self, x_meters: float, y_meters: float) -> Tuple[int, int]:
        x_pixels = int(x_meters / self.resolution)
        y_pixels = int(y_meters / self.resolution)
        return (x_pixels, y_pixels)
    
    def pixels_to_meters(self, x_pixels: int, y_pixels: int) -> Tuple[float, float]:
        x_meters = x_pixels * self.resolution
        y_meters = y_pixels * self.resolution
        return (x_meters, y_meters)
    
    def is_valid_position(self, x: int, y: int) -> bool:
        if x < 0 or x >= self.inflated_map.shape[1] or y < 0 or y >= self.inflated_map.shape[0]:
            return False
        return self.inflated_map[y, x] == 0
    
    def get_neighbors(self, x: int, y: int) -> List[Tuple[int, int, float]]:
        neighbors = []
        
        directions = [(0, 1, self.straight_cost), (1, 0, self.straight_cost),
                     (0, -1, self.straight_cost), (-1, 0, self.straight_cost)]
        
        if self.allow_diagonal:
            directions.extend([(1, 1, self.diagonal_cost), (1, -1, self.diagonal_cost),
                             (-1, 1, self.diagonal_cost), (-1, -1, self.diagonal_cost)])
        
        for dx, dy, cost in directions:
            nx, ny = x + dx, y + dy
            if self.is_valid_position(nx, ny):
                neighbors.append((nx, ny, cost))
        
        return neighbors
    
    def heuristic(self, x1: int, y1: int, x2: int, y2: int) -> float:
        if self.allow_diagonal:
            dx = abs(x2 - x1)
            dy = abs(y2 - y1)
            return self.straight_cost * (dx + dy) + (self.diagonal_cost - 2 * self.straight_cost) * min(dx, dy)
        else:
            return abs(x2 - x1) + abs(y2 - y1)
    
    def find_path(self, start: Tuple[int, int], goal: Tuple[int, int]) -> Optional[List[Tuple[int, int]]]:
        if not self.is_valid_position(start[0], start[1]):
            print(f"Start position {start} is invalid (occupied or out of bounds)")
            return None
        if not self.is_valid_position(goal[0], goal[1]):
            print(f"Goal position {goal} is invalid (occupied or out of bounds)")
            return None
        
        open_set = []
        heapq.heappush(open_set, (0, start))
        
        came_from = {}
        g_score = {start: 0}
        f_score = {start: self.heuristic(start[0], start[1], goal[0], goal[1])}
        
        visited = set()
        
        while open_set:
            current_f, current = heapq.heappop(open_set)
            
            if current in visited:
                continue
            
            visited.add(current)
            
            if current == goal:
                path = []
                while current in came_from:
                    path.append(current)
                    current = came_from[current]
                path.append(start)
                return path[::-1]
            
            for nx, ny, cost in self.get_neighbors(current[0], current[1]):
                neighbor = (nx, ny)
                
                if neighbor in visited:
                    continue
                
                tentative_g = g_score[current] + cost
                
                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f = tentative_g + self.heuristic(nx, ny, goal[0], goal[1])
                    f_score[neighbor] = f
                    heapq.heappush(open_set, (f, neighbor))
        
        return None
    
    def visualize_path(self, path: List[Tuple[int, int]], start_name: str = "Start", 
                      goal_name: str = "Goal", save_path: str = None):
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 10))
        
        ax1.imshow(self.map_array, cmap='gray')
        ax1.set_title('Original Map')
        ax1.axis('off')
        
        display_map = np.stack([self.inflated_map] * 3, axis=2)
        display_map = 1 - display_map
        
        if path:
            path_array = np.array(path)
            for i in range(len(path) - 1):
                y_coords = [path[i][1], path[i+1][1]]
                x_coords = [path[i][0], path[i+1][0]]
                ax2.plot(x_coords, y_coords, 'b-', linewidth=2)
            
            ax2.plot(path[0][0], path[0][1], 'go', markersize=10, label=start_name)
            ax2.plot(path[-1][0], path[-1][1], 'ro', markersize=10, label=goal_name)
            
            for i in range(len(path_array)):
                display_map[path_array[i, 1], path_array[i, 0]] = [0, 0, 1]
            
            display_map[path[0][1], path[0][0]] = [0, 1, 0]
            display_map[path[-1][1], path[-1][0]] = [1, 0, 0]
        
        ax2.imshow(display_map)
        ax2.set_title('Path on Inflated Map')
        ax2.legend()
        ax2.axis('off')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.show()
        
        return fig
    
    def calculate_path_length(self, path: List[Tuple[int, int]]) -> float:
        if not path or len(path) < 2:
            return 0.0
        
        total_distance = 0.0
        for i in range(len(path) - 1):
            dx = path[i+1][0] - path[i][0]
            dy = path[i+1][1] - path[i][1]
            distance = np.sqrt(dx**2 + dy**2) * self.resolution
            total_distance += distance
        
        return total_distance

def load_locations(json_path: str) -> Dict:
    with open(json_path, 'r') as f:
        return json.load(f)

def main():
    navigator = FloorPlanNavigator('floor_plan_config.yaml')
    
    locations = load_locations('office_locations.json')
    
    print(f"Floor plan dimensions: {navigator.width_meters:.2f}m x {navigator.height_meters:.2f}m")
    print(f"Image dimensions: {navigator.map_array.shape[1]} x {navigator.map_array.shape[0]} pixels")
    print(f"Resolution: {navigator.resolution:.3f} meters/pixel")
    print()
    
    test_routes = [
        ("entrance", "conference_room"),
        ("desk_area_1", "kitchen"),
        ("meeting_room_1", "desk_area_2"),
    ]
    
    for start_name, goal_name in test_routes:
        if start_name in locations and goal_name in locations:
            start_loc = locations[start_name]
            goal_loc = locations[goal_name]
            
            start_pixels = navigator.meters_to_pixels(start_loc['x'], start_loc['y'])
            goal_pixels = navigator.meters_to_pixels(goal_loc['x'], goal_loc['y'])
            
            print(f"\nFinding path from {start_name} to {goal_name}:")
            print(f"  Start: {start_loc} -> pixels {start_pixels}")
            print(f"  Goal: {goal_loc} -> pixels {goal_pixels}")
            
            path = navigator.find_path(start_pixels, goal_pixels)
            
            if path:
                distance = navigator.calculate_path_length(path)
                print(f"  Path found! Length: {distance:.2f} meters ({len(path)} waypoints)")
                
                save_name = f"path_{start_name}_to_{goal_name}.png"
                navigator.visualize_path(path, start_name, goal_name, save_name)
                print(f"  Visualization saved to {save_name}")
            else:
                print(f"  No path found!")

if __name__ == "__main__":
    main()