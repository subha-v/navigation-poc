# Setup Instructions for E57 to Nav2 Converter

## Required: Install PDAL with E57 Support

PDAL is required for reading E57 files. The E57 reader is NOT included in pip installations, so you must use conda.

### Option 1: Using Anaconda/Miniconda (Recommended)

1. Install Miniconda if you don't have it:
   - Download from: https://docs.conda.io/en/latest/miniconda.html
   - For macOS: `brew install --cask miniconda`

2. Create and activate the environment:
```bash
conda env create -f environment.yml
conda activate e57_nav
```

3. Verify PDAL installation:
```bash
pdal --version
pdal --drivers | grep e57  # Should show readers.e57
```

### Option 2: Manual Conda Installation

```bash
# Create new environment
conda create -n e57_nav python=3.9
conda activate e57_nav

# Install PDAL with E57 support
conda install -c conda-forge pdal python-pdal

# Install Python dependencies
pip install open3d Pillow PyYAML scipy numpy
```

### Option 3: Using Homebrew (macOS only)

```bash
# Install PDAL
brew install pdal

# Note: Homebrew PDAL may not include E57 support by default
# Check with: pdal --drivers | grep e57
```

## Running the Converter

After installation:

```bash
# Activate the conda environment
conda activate e57_nav

# Run the converter
python e57_to_navmap.py --in "Scan at 14.14.e57" --out output_map --preview
```

## Troubleshooting

If you see "PDAL not found" or "E57 reader not found":
1. Make sure you're in the conda environment: `conda activate e57_nav`
2. Verify PDAL is installed: `which pdal`
3. Check E57 support: `pdal --drivers | grep e57`

If E57 reader is missing after conda install:
- Try: `conda install -c conda-forge pdal=2.5`
- Or build PDAL from source with E57 support enabled