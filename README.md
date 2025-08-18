# E57 to Nav2 Map Converter

Converts E57 LiDAR point cloud scans to Nav2-compatible occupancy grid maps for indoor navigation.

## Overview

This tool processes raw `.e57` point cloud data and generates:
- `grid.png` - 8-bit grayscale occupancy image (0=free, 255=occupied)
- `grid.yaml` - Nav2/ROS map metadata file
- `report.json` - Conversion statistics and parameters

The output maps are fully compatible with Nav2/ROS map_server and ready for A* path planning.

## Installation

### Using Conda (Recommended)

```bash
# Create environment with PDAL E57 support
conda env create -f environment.yml
conda activate e57_nav
```

### Manual Installation

1. Install PDAL with E57 support:
```bash
conda install -c conda-forge pdal python-pdal
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

## Usage

Basic conversion:
```bash
python e57_to_navmap.py --in scan.e57 --out output_map
```

With custom parameters:
```bash
python e57_to_navmap.py \
    --in data/building.e57 \
    --out maps/floor1 \
    --res 0.05 \
    --zmin 0.15 \
    --zmax 2.0 \
    --inflate 0.25 \
    --preview
```

### Command-Line Options

- `--in` (required): Path to input E57 file
- `--out` (required): Output directory for map files
- `--res`: Grid resolution in meters/pixel (default: 0.10)
- `--zmin`: Min height above floor to include (default: 0.10m)
- `--zmax`: Max height above floor to include (default: 2.20m)
- `--inflate`: Obstacle inflation radius in meters (default: 0.30m)
- `--preview`: Generate preview image with scale bar

## Map Format

### Coordinate System

The map uses a **floor-aligned local frame**:
- Origin: Bottom-left pixel of the image
- X-axis: Rightward in the image (East in map frame)
- Y-axis: Upward in the image (North in map frame)
- Units: Meters

### YAML Fields

```yaml
image: grid.png          # Occupancy grid image file
mode: trinary           # Occupancy mode (free/occupied/unknown)
resolution: 0.10        # Meters per pixel
origin: [x, y, 0.0]     # Bottom-left pixel pose (meters, radians)
negate: 0               # Don't invert colors
occupied_thresh: 0.65   # Threshold for occupied cells
free_thresh: 0.20       # Threshold for free cells
```

### Pixel to World Coordinates

To convert between pixel coordinates and world coordinates:

```
World X = origin[0] + pixel_x * resolution
World Y = origin[1] + (height - 1 - pixel_y) * resolution
```

Note: Image row 0 is at the **top**, but represents the **maximum** Y coordinate in the map frame.

### Image Convention

```
Image Space:          Map Space:
[0,0]---->[x]        [max_y]
  |                     ^
  v                     |
 [y]                [min_y]---->[max_x]
                      origin
```

## Parameters Guide

### Resolution
- **0.10 m/px**: Standard for most indoor spaces
- **0.05 m/px**: For narrow corridors or detailed maps
- **0.20 m/px**: For large open spaces, faster planning

### Height Slice (zmin/zmax)
- **zmin=0.10m**: Ignore floor noise
- **zmax=2.20m**: Capture walls and human-scale obstacles
- Adjust based on your environment and robot height

### Inflation
- **0.30m**: Standard body width + safety margin
- **0.20m**: Tighter spaces, skilled operators
- **0.40m**: Conservative, wider clearance

## Output Files

### grid.png
8-bit grayscale image:
- 0 (black): Free space
- 255 (white): Occupied/obstacles

### grid.yaml
Nav2-compatible map metadata linking the image to world coordinates.

### report.json
Conversion statistics including:
- Point counts at each stage
- Map dimensions and extents
- Occupancy ratio
- Processing parameters

## Pipeline Stages

1. **Read E57**: Load and merge all point clouds in file
2. **Preprocess**: Downsample (3cm voxel) and remove outliers
3. **Floor Detection**: RANSAC plane fitting and alignment
4. **Normalization**: Rotate to align floor with Z=0
5. **Slicing**: Keep points between zmin and zmax
6. **Projection**: Orthographic projection to 2D
7. **Rasterization**: Convert to occupancy grid
8. **Morphology**: Close small gaps, inflate obstacles
9. **Export**: Save PNG + YAML in Nav2 format

## Validation

The tool performs automatic validation:
- Verifies PDAL E57 reader availability
- Checks minimum point counts
- Validates floor plane detection
- Warns on suspicious occupancy ratios (>90% or <1%)

## Integration with Nav2

Load the generated map in Nav2/ROS2:

```bash
ros2 run nav2_map_server map_server --ros-args \
    -p yaml_filename:=output_map/grid.yaml
```

Or in ROS1:
```bash
rosrun map_server map_server output_map/grid.yaml
```

## A* Path Planning

The generated PNG can be used directly for A* planning:
- Treat pixels as graph nodes
- Use 8-connected neighbors for smooth paths
- Cost = 1 for free cells, infinite for occupied

## Limitations

- Only supports Cartesian E57 files (not spherical)
- Assumes single floor/level (no multi-story)
- Requires adequate point density for wall detection
- Static maps only (no dynamic obstacles)