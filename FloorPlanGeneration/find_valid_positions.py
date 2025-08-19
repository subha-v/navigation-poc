#!/usr/bin/env python3

import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
import json

image = Image.open('VNX_BW_Floorplan.PNG')
map_array = np.array(image.convert('L'))

map_binary = (map_array > 128).astype(np.uint8)

fig, ax = plt.subplots(figsize=(10, 20))
ax.imshow(map_binary, cmap='gray')
ax.set_title('Click on valid (white) areas to get coordinates')

valid_positions = []

def onclick(event):
    if event.xdata is not None and event.ydata is not None:
        x, y = int(event.xdata), int(event.ydata)
        if 0 <= x < map_binary.shape[1] and 0 <= y < map_binary.shape[0]:
            if map_binary[y, x] == 1:
                x_meters = x * 0.005
                y_meters = y * 0.005
                print(f"Valid position: pixels ({x}, {y}) -> meters ({x_meters:.2f}, {y_meters:.2f})")
                ax.plot(x, y, 'ro', markersize=5)
                plt.draw()
                valid_positions.append({'x': x, 'y': y, 'x_meters': x_meters, 'y_meters': y_meters})
            else:
                print(f"Position ({x}, {y}) is occupied (black)")

cid = fig.canvas.mpl_connect('button_press_event', onclick)

resolution = 0.005
width_pixels = map_binary.shape[1]
height_pixels = map_binary.shape[0]

free_areas = []
for y in range(0, height_pixels, 100):
    for x in range(0, width_pixels, 100):
        if map_binary[y, x] == 1:
            window = map_binary[max(0, y-10):min(height_pixels, y+10),
                              max(0, x-10):min(width_pixels, x+10)]
            if np.mean(window) > 0.8:
                free_areas.append({
                    'x_pixels': x,
                    'y_pixels': y,
                    'x_meters': x * resolution,
                    'y_meters': y * resolution
                })
                ax.plot(x, y, 'g+', markersize=8, alpha=0.5)

print("\nSample valid positions found:")
for i, area in enumerate(free_areas[:15]):
    print(f"  Position {i+1}: pixels ({area['x_pixels']}, {area['y_pixels']}) -> meters ({area['x_meters']:.2f}, {area['y_meters']:.2f})")

plt.show()

if valid_positions:
    with open('clicked_positions.json', 'w') as f:
        json.dump(valid_positions, f, indent=2)
    print(f"\nSaved {len(valid_positions)} clicked positions to clicked_positions.json")