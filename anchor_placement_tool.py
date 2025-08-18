#!/usr/bin/env python3
"""
Interactive Anchor Placement Tool
Click on the map to place anchor phones and generate anchors.json
"""

import json
import yaml
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.widgets import Button, TextBox
import sys
from pathlib import Path


class AnchorPlacementTool:
    def __init__(self, map_dir):
        self.map_dir = Path(map_dir)
        self.anchors = []
        self.pois = []
        self.current_mode = 'anchor'  # 'anchor' or 'poi'
        self.next_anchor_id = 1
        self.next_poi_id = 1
        
        # Load map data
        self.load_map_data()
        
        # Setup matplotlib
        self.setup_plot()
        
    def load_map_data(self):
        """Load PNG and YAML files"""
        # Load YAML
        yaml_path = self.map_dir / "grid.yaml"
        with open(yaml_path, 'r') as f:
            self.map_metadata = yaml.safe_load(f)
            
        # Extract metadata
        self.resolution = self.map_metadata['resolution']
        self.origin = self.map_metadata['origin']
        
        # Load PNG
        png_path = self.map_dir / "grid.png"
        self.grid_image = Image.open(png_path)
        self.grid_array = np.array(self.grid_image)
        
        # Calculate map bounds in meters
        height, width = self.grid_array.shape
        self.width_m = width * self.resolution
        self.height_m = height * self.resolution
        self.min_x = self.origin[0]
        self.min_y = self.origin[1]
        self.max_x = self.min_x + self.width_m
        self.max_y = self.min_y + self.height_m
        
        print(f"Map loaded: {width}x{height} pixels")
        print(f"Resolution: {self.resolution} m/px")
        print(f"Map bounds: X[{self.min_x:.2f}, {self.max_x:.2f}], Y[{self.min_y:.2f}, {self.max_y:.2f}] meters")
        
    def pixel_to_meters(self, px, py):
        """Convert pixel coordinates to world coordinates in meters"""
        # Note: Image Y is flipped
        x = self.min_x + px * self.resolution
        y = self.min_y + (self.grid_array.shape[0] - 1 - py) * self.resolution
        return x, y
        
    def meters_to_pixel(self, x, y):
        """Convert world coordinates to pixel coordinates"""
        px = (x - self.min_x) / self.resolution
        py = self.grid_array.shape[0] - 1 - (y - self.min_y) / self.resolution
        return int(px), int(py)
        
    def setup_plot(self):
        """Setup matplotlib interactive plot"""
        self.fig, self.ax = plt.subplots(figsize=(12, 10))
        plt.subplots_adjust(bottom=0.15)
        
        # Display map
        self.im = self.ax.imshow(self.grid_array, cmap='gray_r', 
                                 extent=[self.min_x, self.max_x, self.min_y, self.max_y])
        
        self.ax.set_xlabel('X (meters)')
        self.ax.set_ylabel('Y (meters)')
        self.ax.set_title('Click to place anchors (red) or POIs (blue)')
        self.ax.grid(True, alpha=0.3)
        
        # Anchor plots
        self.anchor_scatter = self.ax.scatter([], [], c='red', s=200, marker='^', 
                                              label='Anchors', zorder=5)
        self.anchor_texts = []
        
        # POI plots
        self.poi_scatter = self.ax.scatter([], [], c='blue', s=100, marker='o', 
                                           label='POIs', zorder=4)
        self.poi_texts = []
        
        # Add legend
        self.ax.legend()
        
        # Add buttons
        ax_anchor_btn = plt.axes([0.15, 0.05, 0.1, 0.04])
        self.btn_anchor = Button(ax_anchor_btn, 'Anchor Mode')
        self.btn_anchor.on_clicked(self.set_anchor_mode)
        
        ax_poi_btn = plt.axes([0.30, 0.05, 0.1, 0.04])
        self.btn_poi = Button(ax_poi_btn, 'POI Mode')
        self.btn_poi.on_clicked(self.set_poi_mode)
        
        ax_clear_btn = plt.axes([0.45, 0.05, 0.1, 0.04])
        self.btn_clear = Button(ax_clear_btn, 'Clear All')
        self.btn_clear.on_clicked(self.clear_all)
        
        ax_save_btn = plt.axes([0.60, 0.05, 0.1, 0.04])
        self.btn_save = Button(ax_save_btn, 'Save JSON')
        self.btn_save.on_clicked(self.save_json)
        
        ax_export_btn = plt.axes([0.75, 0.05, 0.1, 0.04])
        self.btn_export = Button(ax_export_btn, 'Export Map')
        self.btn_export.on_clicked(self.export_annotated_map)
        
        # Connect click event
        self.cid = self.fig.canvas.mpl_connect('button_press_event', self.on_click)
        
        # Status text
        self.status_text = self.fig.text(0.02, 0.02, f'Mode: {self.current_mode.upper()}', 
                                         fontsize=10)
        
    def set_anchor_mode(self, event):
        """Switch to anchor placement mode"""
        self.current_mode = 'anchor'
        self.status_text.set_text('Mode: ANCHOR')
        plt.draw()
        
    def set_poi_mode(self, event):
        """Switch to POI placement mode"""
        self.current_mode = 'poi'
        self.status_text.set_text('Mode: POI')
        plt.draw()
        
    def on_click(self, event):
        """Handle mouse clicks on the map"""
        if event.inaxes != self.ax:
            return
            
        x, y = event.xdata, event.ydata
        
        # Check if point is in free space
        px, py = self.meters_to_pixel(x, y)
        if 0 <= px < self.grid_array.shape[1] and 0 <= py < self.grid_array.shape[0]:
            if self.grid_array[py, px] > 127:  # Occupied
                print(f"Warning: ({x:.2f}, {y:.2f}) is in occupied space!")
                return
                
        if self.current_mode == 'anchor':
            self.add_anchor(x, y)
        else:
            self.add_poi(x, y)
            
    def add_anchor(self, x, y):
        """Add an anchor at the specified location"""
        anchor_id = f"anchor_{chr(64 + self.next_anchor_id)}"  # A, B, C...
        anchor = {
            'id': anchor_id,
            'xy': [round(x, 2), round(y, 2)],
            'yaw_deg': 0
        }
        self.anchors.append(anchor)
        self.next_anchor_id += 1
        
        print(f"Added {anchor_id} at ({x:.2f}, {y:.2f})")
        self.update_plot()
        
    def add_poi(self, x, y):
        """Add a POI at the specified location"""
        poi_id = f"poi_{self.next_poi_id}"
        poi = {
            'id': poi_id,
            'name': f"Point {self.next_poi_id}",
            'xy': [round(x, 2), round(y, 2)]
        }
        self.pois.append(poi)
        self.next_poi_id += 1
        
        print(f"Added {poi_id} at ({x:.2f}, {y:.2f})")
        self.update_plot()
        
    def clear_all(self, event):
        """Clear all anchors and POIs"""
        self.anchors = []
        self.pois = []
        self.next_anchor_id = 1
        self.next_poi_id = 1
        print("Cleared all anchors and POIs")
        self.update_plot()
        
    def update_plot(self):
        """Update the plot with current anchors and POIs"""
        # Clear old texts
        for txt in self.anchor_texts:
            txt.remove()
        for txt in self.poi_texts:
            txt.remove()
        self.anchor_texts = []
        self.poi_texts = []
        
        # Update anchors
        if self.anchors:
            anchor_xs = [a['xy'][0] for a in self.anchors]
            anchor_ys = [a['xy'][1] for a in self.anchors]
            self.anchor_scatter.set_offsets(np.c_[anchor_xs, anchor_ys])
            
            # Add labels
            for anchor in self.anchors:
                txt = self.ax.text(anchor['xy'][0], anchor['xy'][1] + 0.5, 
                                   anchor['id'].replace('anchor_', ''),
                                   ha='center', va='bottom', fontsize=10, 
                                   fontweight='bold', color='red')
                self.anchor_texts.append(txt)
        else:
            self.anchor_scatter.set_offsets(np.empty((0, 2)))
            
        # Update POIs
        if self.pois:
            poi_xs = [p['xy'][0] for p in self.pois]
            poi_ys = [p['xy'][1] for p in self.pois]
            self.poi_scatter.set_offsets(np.c_[poi_xs, poi_ys])
            
            # Add labels
            for poi in self.pois:
                txt = self.ax.text(poi['xy'][0], poi['xy'][1] + 0.3,
                                   poi['name'], ha='center', va='bottom',
                                   fontsize=8, color='blue')
                self.poi_texts.append(txt)
        else:
            self.poi_scatter.set_offsets(np.empty((0, 2)))
            
        plt.draw()
        
    def save_json(self, event):
        """Save anchors and POIs to JSON files"""
        # Save anchors.json
        anchors_path = self.map_dir / "anchors.json"
        with open(anchors_path, 'w') as f:
            json.dump(self.anchors, f, indent=2)
        print(f"Saved {len(self.anchors)} anchors to {anchors_path}")
        
        # Save pois.json
        if self.pois:
            pois_path = self.map_dir / "pois.json"
            with open(pois_path, 'w') as f:
                json.dump(self.pois, f, indent=2)
            print(f"Saved {len(self.pois)} POIs to {pois_path}")
            
        # Also save a combined config
        config = {
            'map_metadata': {
                'resolution': self.resolution,
                'origin': self.origin,
                'width_px': self.grid_array.shape[1],
                'height_px': self.grid_array.shape[0],
                'bounds_m': {
                    'min_x': self.min_x,
                    'max_x': self.max_x,
                    'min_y': self.min_y,
                    'max_y': self.max_y
                }
            },
            'anchors': self.anchors,
            'pois': self.pois
        }
        config_path = self.map_dir / "navigation_config.json"
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"Saved complete config to {config_path}")
        
    def export_annotated_map(self, event):
        """Export map with anchors and POIs overlaid"""
        # Create a color version of the map
        img = Image.fromarray(self.grid_array).convert('RGB')
        draw = ImageDraw.Draw(img)
        
        # Draw anchors
        for anchor in self.anchors:
            px, py = self.meters_to_pixel(anchor['xy'][0], anchor['xy'][1])
            # Draw red triangle
            size = 10
            points = [(px, py-size), (px-size, py+size), (px+size, py+size)]
            draw.polygon(points, fill='red', outline='darkred')
            # Label
            draw.text((px, py-size-5), anchor['id'].replace('anchor_', ''),
                     fill='red', anchor='ms')
            
        # Draw POIs
        for poi in self.pois:
            px, py = self.meters_to_pixel(poi['xy'][0], poi['xy'][1])
            # Draw blue circle
            radius = 5
            draw.ellipse([px-radius, py-radius, px+radius, py+radius],
                        fill='blue', outline='darkblue')
            # Label
            draw.text((px, py-radius-5), poi['name'],
                     fill='blue', anchor='ms')
            
        # Add scale bar
        scale_m = 5  # 5 meter scale bar
        scale_px = int(scale_m / self.resolution)
        margin = 20
        bar_y = img.height - margin - 10
        draw.rectangle([margin, bar_y, margin + scale_px, bar_y + 5],
                      fill='red', outline='red')
        draw.text((margin, bar_y - 15), f"{scale_m} meters", fill='red')
        
        # Save
        annotated_path = self.map_dir / "map_with_anchors.png"
        img.save(annotated_path)
        print(f"Exported annotated map to {annotated_path}")
        
    def run(self):
        """Run the interactive tool"""
        print("\n=== Anchor Placement Tool ===")
        print("- Click to place anchors (red triangles) or POIs (blue circles)")
        print("- Use buttons to switch modes and save")
        print("- Anchors will be used for Nearby Interaction localization")
        print("- POIs are navigation destinations")
        plt.show()


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Interactive anchor placement tool')
    parser.add_argument('map_dir', help='Directory containing grid.png and grid.yaml')
    args = parser.parse_args()
    
    tool = AnchorPlacementTool(args.map_dir)
    tool.run()


if __name__ == '__main__':
    main()