# XcodeBuildMCP Setup for Navigation PoC

This document describes how to use XcodeBuildMCP with Claude Code to build and manage the Navigation PoC Xcode projects.

## Prerequisites

- macOS with Xcode installed
- Node.js and npm installed
- Claude Desktop application

## Setup Complete

The XcodeBuildMCP has been configured for Claude Code. The configuration file has been created at:
`~/.config/claude/claude_desktop_config.json`

## Project Structure

- `AnchorStation/` - Xcode project for the anchor app (created)
- `IndoorNavigator/` - Xcode project for the navigator app (to be created)
- `build_with_mcp.sh` - Build script using XcodeBuildMCP

## Using XcodeBuildMCP with Claude Code

After restarting Claude Desktop, you can use MCP commands in Claude Code to:

### Build Projects
```bash
# Build AnchorStation app
npx xcodebuildmcp@latest build \
    --project "NavigationSystem/AnchorStation/AnchorStation.xcodeproj" \
    --scheme "AnchorStation"
```

### List Available Devices
```bash
npx xcodebuildmcp@latest list-devices
```

### List Simulators
```bash
npx xcodebuildmcp@latest list-simulators
```

### Run Tests
```bash
npx xcodebuildmcp@latest test \
    --project "NavigationSystem/AnchorStation/AnchorStation.xcodeproj" \
    --scheme "AnchorStation"
```

### Clean Build
```bash
npx xcodebuildmcp@latest clean \
    --project "NavigationSystem/AnchorStation/AnchorStation.xcodeproj" \
    --scheme "AnchorStation"
```

## MCP Tools Available in Claude Code

Once Claude Desktop is restarted with the configuration, these MCP tools will be available:

- `xcode_build` - Build Xcode projects
- `xcode_test` - Run tests
- `xcode_clean` - Clean build artifacts
- `xcode_archive` - Create archives
- `xcode_export` - Export archives
- `simulator_boot` - Boot simulators
- `simulator_shutdown` - Shutdown simulators
- `simulator_install` - Install apps on simulators
- `simulator_launch` - Launch apps on simulators
- And many more...

## Direct Command Line Usage

You can also use XcodeBuildMCP directly from the terminal:

```bash
# Run the build script
cd NavigationSystem
./build_with_mcp.sh
```

## Troubleshooting

### MCP Not Available in Claude Code
1. Restart Claude Desktop after configuration changes
2. Check the config file exists: `~/.config/claude/claude_desktop_config.json`
3. Verify npm and npx are available in your PATH

### Build Failures
1. Ensure Xcode is installed and up to date
2. Check that the project path is correct
3. Verify the scheme name matches the project

### Permission Issues
1. Grant necessary permissions to Xcode and Terminal
2. Ensure Developer Mode is enabled on test devices

## Environment Variables

The MCP is configured with:
- `INCREMENTAL_BUILDS_ENABLED=false` - Ensures clean builds
- `XCODEBUILDMCP_SENTRY_DISABLED=false` - Enables error reporting

## Next Steps

1. Create the IndoorNavigator Xcode project
2. Add the navigation source files
3. Configure signing and capabilities
4. Build and deploy to test devices

## Additional Resources

- [XcodeBuildMCP GitHub](https://github.com/cameroncooke/XcodeBuildMCP)
- [MCP Documentation](https://modelcontextprotocol.io)
- [Claude Desktop MCP Guide](https://docs.anthropic.com/en/docs/claude-code/mcp)