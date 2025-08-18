#!/usr/bin/env python3
"""
Alternative E57 to Nav2 Map Converter using pye57
This version uses pye57 library directly instead of PDAL for E57 reading
"""

import os
import sys
import json
import argparse
import tempfile
from pathlib import Path
from typing import Tuple, Dict, Any, Optional

import numpy as np
import open3d as o3d
import yaml
from PIL import Image
from scipy import ndimage

# Try to import pye57
try:
    import pye57
    HAS_PYE57 = True
except ImportError:
    HAS_PYE57 = False
    print("Note: pye57 not installed. Install with: pip install pye57")


class E57ToNavMapConverterAlt:
    def __init__(self, resolution: float = 0.10, zmin: float = 0.10, 
                 zmax: float = 2.20, inflate: float = 0.30):
        self.resolution = resolution
        self.zmin = zmin
        self.zmax = zmax
        self.inflate = inflate
        self.stats = {}
        
    def read_e57_direct(self, input_path: str) -> o3d.geometry.PointCloud:
        """Read E57 file directly using pye57"""
        if not HAS_PYE57:
            raise ImportError("pye57 not installed. Install with: pip install pye57")
            
        print(f"Reading E57 file with pye57: {input_path}")
        
        e57 = pye57.E57(input_path)
        
        all_points = []
        
        # Read all scans in the file
        for scan_index in range(e57.scan_count):
            print(f"  Reading scan {scan_index + 1}/{e57.scan_count}")
            scan = e57.read_scan(scan_index, ignore_missing_fields=True)
            
            # Check if we have Cartesian coordinates
            if 'cartesianX' in scan and 'cartesianY' in scan and 'cartesianZ' in scan:
                x = scan['cartesianX']
                y = scan['cartesianY']
                z = scan['cartesianZ']
                
                # Stack points
                points = np.column_stack((x, y, z))
                all_points.append(points)
                
            elif 'sphericalRange' in scan:
                print("WARNING: Spherical scan detected, attempting conversion...")
                # Convert spherical to Cartesian
                r = scan['sphericalRange']
                theta = scan.get('sphericalAzimuth', np.zeros_like(r))
                phi = scan.get('sphericalElevation', np.zeros_like(r))
                
                x = r * np.cos(phi) * np.cos(theta)
                y = r * np.cos(phi) * np.sin(theta)
                z = r * np.sin(phi)
                
                points = np.column_stack((x, y, z))
                all_points.append(points)
            else:
                print(f"  Warning: Scan {scan_index} has no recognized coordinate system")
                
        if not all_points:
            raise ValueError("No valid point data found in E57 file")
            
        # Combine all scans
        combined_points = np.vstack(all_points)
        print(f"Total points loaded: {len(combined_points)}")
        
        # Create Open3D point cloud
        pcd = o3d.geometry.PointCloud()
        pcd.points = o3d.utility.Vector3dVector(combined_points)
        
        self.stats['initial_points'] = len(combined_points)
        
        return pcd
        
    def downsample_and_clean(self, pcd: o3d.geometry.PointCloud, 
                            voxel_size: float = 0.01) -> o3d.geometry.PointCloud:
        """Downsample and remove outliers from point cloud"""
        print(f"Downsampling with voxel size {voxel_size}m...")
        
        # Voxel downsampling
        pcd_down = pcd.voxel_down_sample(voxel_size=voxel_size)
        
        print(f"Points after downsampling: {len(pcd_down.points)}")
        
        # Statistical outlier removal
        print("Removing outliers...")
        pcd_clean, ind = pcd_down.remove_statistical_outlier(nb_neighbors=20, 
                                                              std_ratio=2.5)
        
        print(f"Points after outlier removal: {len(pcd_clean.points)}")
        self.stats['points_after_cleaning'] = len(pcd_clean.points)
        
        return pcd_clean
        
    def detect_floor_and_normalize(self, pcd: o3d.geometry.PointCloud) -> o3d.geometry.PointCloud:
        """Detect floor plane and normalize point cloud"""
        print("Detecting floor plane...")
        
        points = np.asarray(pcd.points)
        if len(points) < 100:
            raise ValueError(f"Too few points after cleaning: {len(points)}")
            
        # RANSAC plane detection for floor - use more tolerant parameters
        plane_model, inliers = pcd.segment_plane(distance_threshold=0.05,  # Increased tolerance
                                                 ransac_n=3,
                                                 num_iterations=2000)  # More iterations
        
        # Be more lenient with inlier requirement
        if len(inliers) < len(points) * 0.05:  # Reduced from 0.1 to 0.05
            print(f"WARNING: Floor plane has only {len(inliers)} inliers ({100*len(inliers)/len(points):.1f}%)")
            # Try with even more tolerance
            plane_model, inliers = pcd.segment_plane(distance_threshold=0.10,
                                                     ransac_n=3,
                                                     num_iterations=3000)
            if len(inliers) < len(points) * 0.02:
                raise ValueError(f"Floor plane not found with adequate inliers (only {len(inliers)} found)")
            
        [a, b, c, d] = plane_model
        normal = np.array([a, b, c])
        
        # Ensure normal points up (positive Z)
        if normal[2] < 0:
            normal = -normal
            d = -d
            
        # Calculate rotation to align floor normal with Z axis
        z_axis = np.array([0, 0, 1])
        if not np.allclose(normal, z_axis):
            v = np.cross(normal, z_axis)
            s = np.linalg.norm(v)
            c = np.dot(normal, z_axis)
            if s > 1e-6:  # Avoid division by zero
                vx = np.array([[0, -v[2], v[1]],
                              [v[2], 0, -v[0]],
                              [-v[1], v[0], 0]])
                R = np.eye(3) + vx + vx @ vx * (1 - c) / (s ** 2)
            else:
                R = np.eye(3)
        else:
            R = np.eye(3)
            
        # Apply rotation
        pcd.rotate(R, center=(0, 0, 0))
        
        # Translate so floor is at z=0
        points = np.asarray(pcd.points)
        floor_z = np.percentile(points[:, 2], 5)  # Use 5th percentile as floor level
        pcd.translate((0, 0, -floor_z))
        
        self.stats['floor_inliers'] = len(inliers)
        self.stats['total_points_after_floor'] = len(points)
        
        return pcd
        
    def slice_point_cloud(self, pcd: o3d.geometry.PointCloud) -> o3d.geometry.PointCloud:
        """Slice point cloud to retain points between zmin and zmax"""
        print(f"Slicing points between z={self.zmin}m and z={self.zmax}m...")
        
        points = np.asarray(pcd.points)
        mask = (points[:, 2] >= self.zmin) & (points[:, 2] <= self.zmax)
        sliced_points = points[mask]
        
        if len(sliced_points) < 10:
            raise ValueError(f"Too few points in slice: {len(sliced_points)}")
            
        sliced_pcd = o3d.geometry.PointCloud()
        sliced_pcd.points = o3d.utility.Vector3dVector(sliced_points)
        
        self.stats['points_in_slice'] = len(sliced_points)
        
        return sliced_pcd
        
    def create_occupancy_grid(self, pcd: o3d.geometry.PointCloud) -> Tuple[np.ndarray, Dict[str, float]]:
        """Create 2D occupancy grid from point cloud"""
        print(f"Creating occupancy grid at {self.resolution}m/px resolution...")
        
        points = np.asarray(pcd.points)
        
        # Get XY bounds
        min_x, min_y = points[:, 0].min(), points[:, 1].min()
        max_x, max_y = points[:, 0].max(), points[:, 1].max()
        
        # Add small margin
        margin = self.resolution * 2
        min_x -= margin
        min_y -= margin
        max_x += margin
        max_y += margin
        
        # Calculate grid dimensions
        width = int(np.ceil((max_x - min_x) / self.resolution))
        height = int(np.ceil((max_y - min_y) / self.resolution))
        
        # Initialize grid (0 = free, 255 = occupied)
        grid = np.zeros((height, width), dtype=np.uint8)
        
        # Project points to grid
        grid_x = ((points[:, 0] - min_x) / self.resolution).astype(int)
        grid_y = ((points[:, 1] - min_y) / self.resolution).astype(int)
        
        # Clip to grid bounds
        grid_x = np.clip(grid_x, 0, width - 1)
        grid_y = np.clip(grid_y, 0, height - 1)
        
        # Mark occupied cells (flip Y for image coordinates)
        grid[height - 1 - grid_y, grid_x] = 255
        
        # Morphological cleanup
        kernel = np.ones((3, 3), np.uint8)
        grid = ndimage.binary_closing(grid > 127, structure=kernel).astype(np.uint8) * 255
        
        # Inflate obstacles
        if self.inflate > 0:
            inflate_pixels = int(np.ceil(self.inflate / self.resolution))
            kernel = np.ones((2 * inflate_pixels + 1, 2 * inflate_pixels + 1), np.uint8)
            grid = ndimage.binary_dilation(grid > 127, structure=kernel).astype(np.uint8) * 255
            
        # Calculate statistics
        occupied_ratio = np.sum(grid > 127) / (width * height)
        if occupied_ratio > 0.9:
            print(f"WARNING: Grid is {occupied_ratio:.1%} occupied - may be too dense")
        elif occupied_ratio < 0.01:
            print(f"WARNING: Grid is only {occupied_ratio:.1%} occupied - may be too sparse")
            
        self.stats['grid_width'] = width
        self.stats['grid_height'] = height
        self.stats['occupied_ratio'] = occupied_ratio
        self.stats['map_extents_m'] = {
            'x': [min_x, max_x],
            'y': [min_y, max_y]
        }
        
        map_info = {
            'origin_x': min_x,
            'origin_y': min_y,
            'width': width,
            'height': height
        }
        
        return grid, map_info
        
    def save_nav2_map(self, grid: np.ndarray, map_info: Dict[str, float], 
                      output_dir: str) -> None:
        """Save grid as Nav2-compatible PNG and YAML files"""
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save PNG
        png_path = output_path / "grid.png"
        Image.fromarray(grid).save(png_path)
        print(f"Saved occupancy grid to: {png_path}")
        
        # Create YAML metadata - ensure clean float values
        yaml_data = {
            'image': 'grid.png',
            'mode': 'trinary',
            'resolution': float(self.resolution),
            'origin': [float(map_info['origin_x']), float(map_info['origin_y']), 0.0],
            'negate': 0,
            'occupied_thresh': 0.65,
            'free_thresh': 0.20
        }
        
        yaml_path = output_path / "grid.yaml"
        with open(yaml_path, 'w') as f:
            yaml.dump(yaml_data, f, default_flow_style=False)
        print(f"Saved map metadata to: {yaml_path}")
        
        # Save statistics report
        self.stats['resolution_m_per_px'] = self.resolution
        self.stats['inflation_radius_m'] = self.inflate
        self.stats['z_slice_m'] = [self.zmin, self.zmax]
        
        report_path = output_path / "report.json"
        with open(report_path, 'w') as f:
            json.dump(self.stats, f, indent=2)
        print(f"Saved conversion report to: {report_path}")
        
    def generate_preview(self, grid: np.ndarray, map_info: Dict[str, float], 
                        output_dir: str) -> None:
        """Generate preview image with scale information"""
        from PIL import ImageDraw
        
        output_path = Path(output_dir)
        
        # Create preview with scale bar
        preview = Image.fromarray(grid).convert('RGB')
        draw = ImageDraw.Draw(preview)
        
        # Add scale bar (1 meter)
        scale_pixels = int(1.0 / self.resolution)
        margin = 20
        bar_y = preview.height - margin - 10
        draw.rectangle([margin, bar_y, margin + scale_pixels, bar_y + 5], 
                      fill='red', outline='red')
        
        # Add text (basic font)
        try:
            draw.text((margin, bar_y - 15), "1 meter", fill='red')
        except:
            pass  # Skip if font issues
            
        # Add grid info
        info_text = f"Resolution: {self.resolution}m/px\n"
        info_text += f"Size: {map_info['width']}x{map_info['height']}px\n"
        info_text += f"Extents: {map_info['width']*self.resolution:.1f}x{map_info['height']*self.resolution:.1f}m"
        
        try:
            draw.text((margin, margin), info_text, fill='green')
        except:
            pass
            
        preview_path = output_path / "preview.png"
        preview.save(preview_path)
        print(f"Saved preview image to: {preview_path}")
        
    def convert(self, input_e57: str, output_dir: str, preview: bool = False) -> bool:
        """Main conversion pipeline"""
        try:
            # Step 1: Read E57 directly
            pcd = self.read_e57_direct(input_e57)
            
            # Step 2: Downsample and clean
            pcd = self.downsample_and_clean(pcd)
            
            # Step 3: Detect floor and normalize
            pcd = self.detect_floor_and_normalize(pcd)
            
            # Step 4: Slice point cloud
            pcd = self.slice_point_cloud(pcd)
            
            # Step 5: Create occupancy grid
            grid, map_info = self.create_occupancy_grid(pcd)
            
            # Step 6: Save Nav2 map files
            self.save_nav2_map(grid, map_info, output_dir)
            
            # Step 7: Generate preview if requested
            if preview:
                self.generate_preview(grid, map_info, output_dir)
                
            print("\nConversion complete!")
            print(f"Output files in: {output_dir}")
            print(f"  - grid.png: Occupancy grid image")
            print(f"  - grid.yaml: Nav2 map metadata")
            print(f"  - report.json: Conversion statistics")
            
            return True
            
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback
            traceback.print_exc()
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Convert E57 point cloud to Nav2-compatible occupancy map (pye57 version)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This is an alternative version that uses pye57 instead of PDAL.
Install with: pip install pye57

Examples:
  %(prog)s --in scan.e57 --out maps/floor1
  %(prog)s --in scan.e57 --out output --res 0.05 --preview
  %(prog)s --in scan.e57 --out output --zmin 0.2 --zmax 2.0 --inflate 0.25
        """
    )
    
    parser.add_argument('--in', dest='input', required=True,
                       help='Path to input E57 file')
    parser.add_argument('--out', dest='output', required=True,
                       help='Output directory for map files')
    parser.add_argument('--res', type=float, default=0.10,
                       help='Grid resolution in meters per pixel (default: 0.10)')
    parser.add_argument('--zmin', type=float, default=0.10,
                       help='Minimum height above floor in meters (default: 0.10)')
    parser.add_argument('--zmax', type=float, default=2.20,
                       help='Maximum height above floor in meters (default: 2.20)')
    parser.add_argument('--inflate', type=float, default=0.30,
                       help='Obstacle inflation radius in meters (default: 0.30)')
    parser.add_argument('--preview', action='store_true',
                       help='Generate preview image with scale bar')
    
    args = parser.parse_args()
    
    # Check if pye57 is available
    if not HAS_PYE57:
        print("ERROR: pye57 not installed.")
        print("Install with: pip install pye57")
        sys.exit(1)
    
    # Validate input file
    if not os.path.exists(args.input):
        print(f"ERROR: Input file not found: {args.input}")
        sys.exit(1)
        
    if not args.input.lower().endswith('.e57'):
        print(f"WARNING: Input file does not have .e57 extension: {args.input}")
        
    # Create converter and run
    converter = E57ToNavMapConverterAlt(
        resolution=args.res,
        zmin=args.zmin,
        zmax=args.zmax,
        inflate=args.inflate
    )
    
    success = converter.convert(args.input, args.output, preview=args.preview)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()