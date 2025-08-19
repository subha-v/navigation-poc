#!/usr/bin/env python3

import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
from PIL import Image, ImageTk, ImageDraw
import json
import os
from astar_navigation import FloorPlanNavigator
import numpy as np

class InteractiveMapEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("VALUENEX Office Map Editor")
        
        # Load configuration and navigator
        self.config_file = 'floor_plan_updated_config.yaml'
        self.locations_file = 'office_locations_updated.json'
        self.navigator = FloorPlanNavigator(self.config_file)
        
        # Load or create locations
        self.locations = self.load_locations()
        
        # UI Setup
        self.setup_ui()
        
        # Map display
        self.load_map()
        
        # Path visualization
        self.current_path = None
        self.path_line = None
        
        # Point placement
        self.placing_point = False
        self.selected_location = None
        
    def setup_ui(self):
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Left panel - Controls
        control_frame = ttk.LabelFrame(main_frame, text="Controls", padding="10")
        control_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 10))
        
        # Mode selection
        ttk.Label(control_frame, text="Mode:").grid(row=0, column=0, sticky=tk.W, pady=5)
        self.mode_var = tk.StringVar(value="view")
        ttk.Radiobutton(control_frame, text="View", variable=self.mode_var, 
                       value="view", command=self.change_mode).grid(row=1, column=0, sticky=tk.W)
        ttk.Radiobutton(control_frame, text="Add Point", variable=self.mode_var, 
                       value="add", command=self.change_mode).grid(row=2, column=0, sticky=tk.W)
        ttk.Radiobutton(control_frame, text="Navigate", variable=self.mode_var, 
                       value="navigate", command=self.change_mode).grid(row=3, column=0, sticky=tk.W)
        
        ttk.Separator(control_frame, orient='horizontal').grid(row=4, column=0, columnspan=2, 
                                                               sticky=(tk.W, tk.E), pady=10)
        
        # Locations list
        ttk.Label(control_frame, text="Locations:").grid(row=5, column=0, sticky=tk.W, pady=5)
        
        # Listbox with scrollbar
        list_frame = ttk.Frame(control_frame)
        list_frame.grid(row=6, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        scrollbar = ttk.Scrollbar(list_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.location_listbox = tk.Listbox(list_frame, yscrollcommand=scrollbar.set, 
                                          height=15, width=25)
        self.location_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.location_listbox.yview)
        
        self.location_listbox.bind('<<ListboxSelect>>', self.on_location_select)
        
        # Buttons
        button_frame = ttk.Frame(control_frame)
        button_frame.grid(row=7, column=0, columnspan=2, pady=10)
        
        ttk.Button(button_frame, text="Delete Selected", 
                  command=self.delete_location).pack(side=tk.LEFT, padx=2)
        ttk.Button(button_frame, text="Clear Path", 
                  command=self.clear_path).pack(side=tk.LEFT, padx=2)
        
        ttk.Separator(control_frame, orient='horizontal').grid(row=8, column=0, columnspan=2, 
                                                               sticky=(tk.W, tk.E), pady=10)
        
        # Navigation controls
        ttk.Label(control_frame, text="Navigation:").grid(row=9, column=0, sticky=tk.W, pady=5)
        
        nav_frame = ttk.Frame(control_frame)
        nav_frame.grid(row=10, column=0, columnspan=2)
        
        ttk.Label(nav_frame, text="From:").grid(row=0, column=0, sticky=tk.W)
        self.from_var = tk.StringVar()
        self.from_combo = ttk.Combobox(nav_frame, textvariable=self.from_var, width=20)
        self.from_combo.grid(row=0, column=1, padx=5)
        
        ttk.Label(nav_frame, text="To:").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.to_var = tk.StringVar()
        self.to_combo = ttk.Combobox(nav_frame, textvariable=self.to_var, width=20)
        self.to_combo.grid(row=1, column=1, padx=5)
        
        ttk.Button(nav_frame, text="Find Path", 
                  command=self.find_path).grid(row=2, column=0, columnspan=2, pady=10)
        
        # Path info
        self.path_info = ttk.Label(control_frame, text="", foreground="blue")
        self.path_info.grid(row=11, column=0, columnspan=2, pady=5)
        
        # Save button
        ttk.Button(control_frame, text="Save Locations", 
                  command=self.save_locations).grid(row=12, column=0, columnspan=2, pady=10)
        
        # Right panel - Map
        map_frame = ttk.LabelFrame(main_frame, text="Floor Plan", padding="5")
        map_frame.grid(row=0, column=1, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Canvas with scrollbars
        canvas_frame = ttk.Frame(map_frame)
        canvas_frame.pack(fill=tk.BOTH, expand=True)
        
        h_scrollbar = ttk.Scrollbar(canvas_frame, orient=tk.HORIZONTAL)
        h_scrollbar.pack(side=tk.BOTTOM, fill=tk.X)
        
        v_scrollbar = ttk.Scrollbar(canvas_frame, orient=tk.VERTICAL)
        v_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.canvas = tk.Canvas(canvas_frame, bg='white', width=800, height=600,
                               xscrollcommand=h_scrollbar.set,
                               yscrollcommand=v_scrollbar.set)
        self.canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        h_scrollbar.config(command=self.canvas.xview)
        v_scrollbar.config(command=self.canvas.yview)
        
        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        status_bar = ttk.Label(main_frame, textvariable=self.status_var, relief=tk.SUNKEN)
        status_bar.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        # Bind canvas events
        self.canvas.bind("<Button-1>", self.on_canvas_click)
        self.canvas.bind("<Motion>", self.on_canvas_motion)
        
    def load_map(self):
        # Load the floor plan image
        self.original_image = Image.open(self.navigator.config['image'])
        
        # Create display image
        self.display_image = self.original_image.copy()
        self.photo = ImageTk.PhotoImage(self.display_image)
        
        # Display on canvas
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor=tk.NW, image=self.photo, tags="map")
        self.canvas.config(scrollregion=self.canvas.bbox("all"))
        
        # Redraw all location markers
        self.redraw_locations()
        
    def load_locations(self):
        if os.path.exists(self.locations_file):
            with open(self.locations_file, 'r') as f:
                return json.load(f)
        return {}
    
    def save_locations(self):
        with open(self.locations_file, 'w') as f:
            json.dump(self.locations, f, indent=2)
        self.status_var.set(f"Saved {len(self.locations)} locations to {self.locations_file}")
        messagebox.showinfo("Success", f"Saved {len(self.locations)} locations!")
    
    def update_location_list(self):
        self.location_listbox.delete(0, tk.END)
        for name in sorted(self.locations.keys()):
            loc = self.locations[name]
            self.location_listbox.insert(tk.END, f"{name} ({loc['x']:.2f}, {loc['y']:.2f})")
        
        # Update combo boxes
        location_names = sorted(self.locations.keys())
        self.from_combo['values'] = location_names
        self.to_combo['values'] = location_names
    
    def redraw_locations(self):
        # Remove old markers
        self.canvas.delete("marker")
        self.canvas.delete("label")
        
        # Draw all location markers
        for name, loc in self.locations.items():
            x_pixels, y_pixels = self.navigator.meters_to_pixels(loc['x'], loc['y'])
            
            # Draw marker
            marker = self.canvas.create_oval(x_pixels-5, y_pixels-5, x_pixels+5, y_pixels+5,
                                            fill='red', outline='darkred', width=2, tags="marker")
            
            # Draw label
            label = self.canvas.create_text(x_pixels, y_pixels-10, text=name,
                                           fill='darkblue', font=('Arial', 10, 'bold'),
                                           anchor=tk.S, tags="label")
            
            # Store reference
            self.canvas.tag_bind(marker, "<Button-1>", lambda e, n=name: self.select_location(n))
            self.canvas.tag_bind(label, "<Button-1>", lambda e, n=name: self.select_location(n))
    
    def change_mode(self):
        mode = self.mode_var.get()
        self.status_var.set(f"Mode: {mode}")
        self.clear_path()
        
        if mode == "add":
            self.canvas.config(cursor="crosshair")
        elif mode == "navigate":
            self.canvas.config(cursor="hand2")
        else:
            self.canvas.config(cursor="")
    
    def on_canvas_click(self, event):
        # Get canvas coordinates
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        
        if self.mode_var.get() == "add":
            self.add_point_at(x, y)
        elif self.mode_var.get() == "navigate":
            self.handle_navigation_click(x, y)
    
    def on_canvas_motion(self, event):
        # Get canvas coordinates
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        
        # Convert to meters
        x_meters, y_meters = self.navigator.pixels_to_meters(int(x), int(y))
        
        # Check if position is valid
        if self.navigator.is_valid_position(int(x), int(y)):
            validity = "Free"
        else:
            validity = "Occupied"
        
        self.status_var.set(f"Position: ({x_meters:.2f}m, {y_meters:.2f}m) - {validity}")
    
    def add_point_at(self, x, y):
        # Check if position is valid
        if not self.navigator.is_valid_position(int(x), int(y)):
            messagebox.showwarning("Invalid Position", 
                                  "This position is occupied or too close to obstacles!")
            return
        
        # Get name from user
        name = simpledialog.askstring("Location Name", 
                                      "Enter a name for this location (e.g., 'kitchen', 'desk_1'):")
        
        if not name:
            return
        
        if name in self.locations:
            if not messagebox.askyesno("Overwrite?", 
                                       f"Location '{name}' already exists. Overwrite?"):
                return
        
        # Convert to meters
        x_meters, y_meters = self.navigator.pixels_to_meters(int(x), int(y))
        
        # Add location
        self.locations[name] = {
            "x": round(x_meters, 2),
            "y": round(y_meters, 2),
            "description": f"Added via interactive editor"
        }
        
        # Update UI
        self.update_location_list()
        self.redraw_locations()
        self.status_var.set(f"Added location: {name}")
    
    def select_location(self, name):
        # Find and select in listbox
        for i in range(self.location_listbox.size()):
            if self.location_listbox.get(i).startswith(name):
                self.location_listbox.selection_clear(0, tk.END)
                self.location_listbox.selection_set(i)
                self.location_listbox.see(i)
                break
    
    def on_location_select(self, event):
        selection = self.location_listbox.curselection()
        if selection:
            item = self.location_listbox.get(selection[0])
            name = item.split(' (')[0]
            self.selected_location = name
            
            # Highlight selected marker
            self.redraw_locations()
            if name in self.locations:
                loc = self.locations[name]
                x_pixels, y_pixels = self.navigator.meters_to_pixels(loc['x'], loc['y'])
                
                # Highlight with green circle
                self.canvas.create_oval(x_pixels-8, y_pixels-8, x_pixels+8, y_pixels+8,
                                       outline='green', width=3, tags="marker")
    
    def delete_location(self):
        if self.selected_location and self.selected_location in self.locations:
            if messagebox.askyesno("Delete Location", 
                                   f"Delete location '{self.selected_location}'?"):
                del self.locations[self.selected_location]
                self.selected_location = None
                self.update_location_list()
                self.redraw_locations()
                self.status_var.set("Location deleted")
    
    def handle_navigation_click(self, x, y):
        # Find nearest location
        min_dist = float('inf')
        nearest = None
        
        for name, loc in self.locations.items():
            loc_x, loc_y = self.navigator.meters_to_pixels(loc['x'], loc['y'])
            dist = ((x - loc_x) ** 2 + (y - loc_y) ** 2) ** 0.5
            if dist < min_dist and dist < 20:  # Within 20 pixels
                min_dist = dist
                nearest = name
        
        if nearest:
            if not self.from_var.get():
                self.from_var.set(nearest)
                self.status_var.set(f"Start: {nearest}")
            else:
                self.to_var.set(nearest)
                self.status_var.set(f"Goal: {nearest}")
                self.find_path()
    
    def find_path(self):
        start_name = self.from_var.get()
        goal_name = self.to_var.get()
        
        if not start_name or not goal_name:
            messagebox.showwarning("Missing Locations", 
                                  "Please select both start and goal locations!")
            return
        
        if start_name not in self.locations or goal_name not in self.locations:
            messagebox.showwarning("Invalid Locations", 
                                  "Selected locations not found!")
            return
        
        # Get coordinates
        start_loc = self.locations[start_name]
        goal_loc = self.locations[goal_name]
        
        start_pixels = self.navigator.meters_to_pixels(start_loc['x'], start_loc['y'])
        goal_pixels = self.navigator.meters_to_pixels(goal_loc['x'], goal_loc['y'])
        
        # Find path
        self.status_var.set("Finding path...")
        self.root.update()
        
        path = self.navigator.find_path(start_pixels, goal_pixels)
        
        if path:
            # Calculate distance
            distance = self.navigator.calculate_path_length(path)
            
            # Display path
            self.draw_path(path)
            
            # Update info
            self.path_info.config(text=f"Path: {distance:.2f}m ({len(path)} points)")
            self.status_var.set(f"Path found: {distance:.2f}m")
        else:
            messagebox.showerror("No Path", 
                               f"No path found from {start_name} to {goal_name}!")
            self.status_var.set("No path found")
    
    def draw_path(self, path):
        self.clear_path()
        
        # Draw path as lines
        for i in range(len(path) - 1):
            x1, y1 = path[i]
            x2, y2 = path[i + 1]
            self.canvas.create_line(x1, y1, x2, y2, fill='blue', width=3, tags="path")
        
        # Draw start and end markers
        if path:
            start_x, start_y = path[0]
            end_x, end_y = path[-1]
            
            self.canvas.create_oval(start_x-6, start_y-6, start_x+6, start_y+6,
                                   fill='green', outline='darkgreen', width=2, tags="path")
            self.canvas.create_oval(end_x-6, end_y-6, end_x+6, end_y+6,
                                   fill='red', outline='darkred', width=2, tags="path")
    
    def clear_path(self):
        self.canvas.delete("path")
        self.path_info.config(text="")
        self.from_var.set("")
        self.to_var.set("")

def main():
    root = tk.Tk()
    app = InteractiveMapEditor(root)
    app.update_location_list()
    root.mainloop()

if __name__ == "__main__":
    main()