# Create GitHub Repository

## Option 1: Create via GitHub Web Interface

1. Go to https://github.com/new
2. Repository name: `navigation-poc`
3. Description: "Indoor Navigation PoC with E57 LiDAR processing and iOS Nearby Interaction"
4. Set to **Public**
5. DO NOT initialize with README (we already have one)
6. Click "Create repository"

## Option 2: Using GitHub CLI

If you have GitHub CLI installed:
```bash
gh repo create navigation-poc --public --description "Indoor Navigation PoC with E57 LiDAR processing and iOS Nearby Interaction"
```

## After Creating the Repo

Run these commands to push your code:

```bash
cd "/Users/subha/Downloads/VALUENEX/Navigation PoC"

# If the repo was created successfully, push the code:
git push -u origin main
```

## If you get authentication errors:

### Option A: Use Personal Access Token
1. Go to GitHub Settings → Developer Settings → Personal Access Tokens
2. Generate new token with 'repo' scope
3. When prompted for password, use the token instead

### Option B: Use SSH
```bash
# Change remote to SSH
git remote set-url origin git@github.com:subha-v/navigation-poc.git

# Then push
git push -u origin main
```

## Repository Contents

Your repository will contain:
- **E57 to Nav2 converter** - Python tools for processing LiDAR scans
- **Anchor placement tool** - Interactive map annotation
- **iOS Anchor App** - UWB broadcasting for base stations  
- **iOS Navigator App** - Full navigation with ARKit + Nearby Interaction
- **Documentation** - Complete setup and usage guides

## Next Steps After Push

1. Add a LICENSE file (MIT recommended)
2. Create releases for stable versions
3. Add GitHub Actions for CI/CD (optional)
4. Enable GitHub Pages for documentation (optional)