# Troubleshooting Guide

## Common Issues and Solutions

### PDAL E57 Reader Not Found

**Error**: `ERROR: PDAL E57 reader not found`

**Solution**:
```bash
# Install PDAL with E57 support via conda
conda install -c conda-forge pdal

# Verify E57 reader is available
pdal --drivers | grep e57
```

**Note**: pip-installed PDAL often lacks E57 support. Use conda-forge channel.

### Spherical E57 Not Supported

**Error**: `ERROR: E57 appears to be spherical. PDAL readers.e57 supports Cartesian only`

**Solution**: 
- Convert spherical E57 to Cartesian using CloudCompare or other tools
- Or use alternative readers that support spherical data

### Too Few Points After Processing

**Error**: `Too few points after cleaning: N`

**Possible Causes**:
1. E57 file is corrupted or empty
2. Aggressive outlier removal
3. Wrong units (mm vs meters)

**Solutions**:
- Verify E57 file in CloudCompare
- Adjust outlier filter parameters in code
- Check point cloud units

### Floor Plane Not Found

**Error**: `Floor plane not found with adequate inliers`

**Possible Causes**:
1. No clear floor in scan
2. Scan starts above floor level
3. Heavily cluttered floor

**Solutions**:
- Ensure scan includes floor surface
- Adjust RANSAC parameters (distance_threshold)
- Pre-process in CloudCompare to isolate floor region

### Grid Too Dense/Sparse

**Warning**: `Grid is X% occupied - may be too dense/sparse`

**Causes & Solutions**:

**Too Dense (>90%)**:
- Resolution too low for space → Decrease resolution (e.g., 0.05m)
- Inflation too large → Reduce inflate parameter
- Noise not filtered → Increase outlier removal

**Too Sparse (<1%)**:
- Resolution too high → Increase resolution (e.g., 0.20m)
- Wrong slice heights → Adjust zmin/zmax
- Points outside bounds → Check coordinate system

### Large File Processing

**Issue**: E57 file takes too long or crashes

**Solutions**:
1. Increase voxel downsampling:
   ```python
   "cell": 0.05  # Increase from 0.03 to 0.05 or 0.10
   ```

2. Process in sections:
   - Split E57 into smaller regions using CloudCompare
   - Process each section separately
   - Merge resulting maps

3. Use more memory:
   ```bash
   export PDAL_DRIVER_PATH=/path/to/pdal/drivers
   ulimit -n 4096  # Increase file handle limit
   ```

### Memory Errors

**Error**: `MemoryError` or system crash

**Solutions**:
- Increase downsampling in PDAL pipeline
- Process on machine with more RAM
- Use 64-bit Python environment
- Close other applications

### No Module Named 'pdal'

**Error**: `ModuleNotFoundError: No module named 'pdal'`

**Solution**:
```bash
conda activate e57_nav  # Activate correct environment
conda install python-pdal  # Install Python bindings
```

### Invalid YAML for Nav2

**Issue**: Nav2/ROS rejects the YAML file

**Common Fixes**:
1. Ensure image path is relative, not absolute
2. Check YAML syntax (no tabs, proper indentation)
3. Verify image file exists and is readable
4. Use correct field names (origin, not origin_pose)

### Preview Image Issues

**Issue**: Preview image has no scale bar or text

**Solution**: Install Pillow with font support:
```bash
pip install --upgrade Pillow
```

### Coordinate System Confusion

**Issue**: Map appears flipped or inverted

**Remember**:
- Image origin (0,0) is top-left
- Map origin is bottom-left
- Y-axis is inverted between image and map space

**Debug**:
```python
# To verify coordinates
print(f"Image point [0, 0] maps to world [{origin_x}, {origin_y + height*resolution}]")
print(f"Image point [0, {height-1}] maps to world [{origin_x}, {origin_y}]")
```

## Performance Optimization

### Slow Processing

1. **Reduce point density early**:
   - Increase voxel grid size
   - Limit input bounds if known

2. **Parallel processing**:
   - PDAL uses multiple threads automatically
   - Open3D operations are single-threaded

3. **Profile bottlenecks**:
   ```python
   import time
   start = time.time()
   # operation
   print(f"Operation took {time.time()-start:.2f}s")
   ```

### Quality vs Speed Tradeoffs

| Parameter | Fast | Balanced | Quality |
|-----------|------|----------|---------|
| Voxel size | 0.10m | 0.03m | 0.01m |
| Resolution | 0.20m | 0.10m | 0.05m |
| Outlier k | 10 | 20 | 50 |
| RANSAC iter | 100 | 1000 | 5000 |

## Debugging Tools

### Inspect E57 Structure
```bash
pdal info scan.e57 --all | head -100
```

### Visualize in CloudCompare
```bash
# Install CloudCompare
# Mac: brew install cloudcompare
# Linux: apt-get install cloudcompare

CloudCompare scan.e57
```

### Test PDAL Pipeline
```bash
# Test pipeline without Python
pdal pipeline test_pipeline.json
```

### Validate Output Map
```python
# Quick validation script
import yaml
import numpy as np
from PIL import Image

with open('grid.yaml') as f:
    meta = yaml.safe_load(f)
    
img = Image.open(meta['image'])
print(f"Image size: {img.size}")
print(f"Map extents: {img.width * meta['resolution']}m x {img.height * meta['resolution']}m")
print(f"Origin: {meta['origin']}")

# Check occupancy
arr = np.array(img)
occupied = np.sum(arr > 127) / arr.size
print(f"Occupied: {occupied:.1%}")
```

## Getting Help

1. Check error messages carefully - they often indicate the specific issue
2. Run with verbose/debug output if available
3. Test with a known-good E57 file to isolate issues
4. Visualize intermediate outputs (PLY file, point cloud) in CloudCompare
5. For PDAL issues: https://pdal.io/community.html
6. For Open3D issues: http://www.open3d.org/docs/