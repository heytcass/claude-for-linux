# Claude Desktop for Linux

Native Claude Desktop implementation for Linux (Ubuntu 25.11) extracted from macOS build.

## Status

- ✅ **Working**: Claude Desktop running natively on Linux with Wayland support
- ✅ **Claude Code**: Enabled and functional (v2.1.20)
- ✅ **Window Decorations**: GNOME title bar working
- ⚠️ **Cowork**: Implementation in progress (currently broken - see cowork branch)

## Quick Start

If you just want to install Claude Desktop for Linux:

```bash
# Install dependencies
sudo nala install dmg2img p7zip-full python3 nodejs

# Run the installer
./scripts/install-claude-desktop.sh

# Launch
claude-desktop
```

## Project Structure

```
.
├── docs/                    # Documentation
│   ├── START_HERE.md       # Quick start guide
│   ├── COWORK_README.md    # Cowork documentation
│   └── ...                 # Other docs
├── scripts/                # Installation and update scripts
│   ├── install-claude-desktop.sh
│   ├── install-cowork-linux.sh  (broken)
│   ├── update-claude-desktop.sh
│   └── patch-cowork-linux-v2.js
├── modules/                # Custom modules
│   ├── enhanced-claude-native-stub.js
│   └── claude-cowork-linux.js
└── tools/                  # Utilities
    └── asar_tool.py       # ASAR manipulation
```

## What Works

- ✅ Native Wayland support (not XWayland)
- ✅ HiDPI scaling (sharp, not blurry)
- ✅ Window decorations (GNOME title bar)
- ✅ Claude Code tool execution
- ✅ File uploads and downloads
- ✅ Full chat functionality
- ✅ Automatic updates (via update script)

## What's Broken

- ⚠️ **Cowork** (sandboxed directory access) - see `cowork` branch for attempted implementation

## Installation

Claude Desktop 1.1.1200 is installed at `/opt/claude-desktop/` with:
- Enhanced native module stub (replaces macOS native module)
- Electron 37.10.3 runtime
- Wayland optimization flags
- XDG directory compliance

## Branches

- `main` - Working Claude Desktop without Cowork
- `cowork` - Cowork implementation (currently broken, needs debugging)

## Documentation

- **Quick Start**: `docs/START_HERE.md`
- **Installation Guide**: `docs/COWORK_INSTALLATION.md`
- **Technical Overview**: `docs/COWORK_SUMMARY.md`
- **File Index**: `docs/COWORK_INDEX.md`

## Contributing

This is a personal project for running Claude Desktop on Linux. Contributions welcome!

## Credits

- **Implementation**: Extracted from Claude Desktop macOS build
- **Cowork Research**: Ralph Loop iteration 1
- **Tools**: Electron, Python ASAR manipulation

## License

For personal use only. Claude Desktop is property of Anthropic.
