# Claude Cowork for Linux - Nix Flake Guide

This project provides a Nix flake for declarative installation of Claude Desktop with Cowork support on Linux.

## Quick Start

### Prerequisites

1. Install Nix with flakes enabled:
```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes (add to ~/.config/nix/nix.conf)
experimental-features = nix-command flakes
```

2. Install Claude Desktop (proprietary binary from Anthropic)

### One-Command Install

```bash
# Install Cowork patches
nix run github:yourusername/claude-for-linux

# Or from local directory
nix run .
```

### Launch Claude with Cowork

```bash
# Run with Nix wrapper (ensures bubblewrap is available)
nix run .#run

# Or use the system install
claude-desktop-cowork
```

## Installation Methods

### Method 1: Standalone Install (Any Linux)

Use the flake without modifying your system configuration:

```bash
# Install patches
nix run github:yourusername/claude-for-linux

# Add to your shell profile for easy launching
nix profile install github:yourusername/claude-for-linux#wrapper
```

### Method 2: NixOS System-Wide

Add to your `/etc/nixos/configuration.nix`:

```nix
{
  inputs.claude-cowork.url = "github:yourusername/claude-for-linux";

  # In your configuration
  imports = [ claude-cowork.nixosModules.default ];

  services.claude-cowork = {
    enable = true;
    autoInstall = true;  # Auto-apply patches on system activation
  };
}
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

### Method 3: Home Manager

Add to your `home.nix`:

```nix
{
  inputs.claude-cowork.url = "github:yourusername/claude-for-linux";

  # In your home configuration
  imports = [ claude-cowork.homeManagerModules.default ];

  programs.claude-cowork = {
    enable = true;
    installPatches = true;
    createDesktopEntry = true;  # Creates "Claude (Cowork)" launcher
  };
}
```

Then apply:
```bash
home-manager switch
```

## How It Works

The Nix flake provides:

1. **Reproducible Patching**: All patches are applied deterministically
2. **Dependency Management**: Bubblewrap is automatically available
3. **Clean Isolation**: No system-wide pollution
4. **Declarative Config**: NixOS/Home Manager integration

### What Gets Installed

- **Bubblewrap**: Linux sandboxing tool (replaces macOS VMs)
- **Cowork Patches**: 6 JavaScript patches to the Electron app
- **Cowork Module**: `claude-cowork-linux.js` for session management
- **Wrapper Scripts**: Launch Claude with correct environment

### Architecture

```
┌─────────────────────────────────────────┐
│ Claude Desktop (Electron)               │
│  ├── app.asar.pre-cowork (backup)       │
│  └── app.asar (patched)                 │
│      ├── Patch v3: Module loading       │
│      ├── Patch v7: Availability check   │
│      ├── Patch v8: VM start intercept   │
│      ├── Patch v9: Skip bundle download │
│      ├── Patch v10: VM getter           │
│      └── Patch v11: Swift module stub   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ claude-cowork-linux (Node.js module)    │
│  ├── CoworkSessionManager               │
│  └── VMCompatibilityAdapter             │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ Bubblewrap (Sandboxing)                 │
│  ├── Process isolation                  │
│  ├── Namespace separation               │
│  └── Bind mounts for directories        │
└─────────────────────────────────────────┘
```

## Development

### Enter Development Shell

```bash
nix develop
```

This provides:
- Node.js (for patching scripts)
- Python 3 (for ASAR tool)
- Bubblewrap (for sandboxing)
- Development tools (eslint, prettier)

### Build Individual Components

```bash
# Build just the patches
nix build .#patches

# Build the Cowork module
nix build .#module

# Build the ASAR tool
nix build .#asar-tool

# Build the installer
nix build .#installer
```

### Test Installation

```bash
# Install patches
nix run .

# Launch and check logs
nix run .#run 2>&1 | grep -E "Cowork|error"
```

## Updating

### Update Flake Inputs

```bash
nix flake update
```

### Update Patches

1. Modify patch scripts in `scripts/`
2. Test: `nix run .`
3. Commit changes
4. Flake automatically uses new versions

### Rollback

```bash
# NixOS
sudo nixos-rebuild switch --rollback

# Home Manager
home-manager generations  # List generations
home-manager switch --switch-generation <number>

# Manual
sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar
```

## Comparison: Nix vs Ubuntu Install

| Feature | Nix Flake | Ubuntu Script |
|---------|-----------|---------------|
| **Reproducibility** | ✅ Guaranteed | ⚠️ Depends on system state |
| **Dependencies** | ✅ Auto-managed | ❌ Manual `nala install` |
| **Rollback** | ✅ Built-in | ❌ Manual backup restore |
| **Multi-user** | ✅ Isolated profiles | ⚠️ System-wide only |
| **Declarative** | ✅ Config as code | ❌ Imperative script |
| **Update Safety** | ✅ Atomic updates | ⚠️ Can break mid-update |

Both methods work! Use Nix if you:
- Want declarative system management
- Need reproducible builds
- Use NixOS or Home Manager
- Want easy rollbacks

Use Ubuntu script if you:
- Prefer traditional package management
- Want simpler one-time setup
- Don't use Nix ecosystem

## Troubleshooting

### Flake Doesn't Find Claude Desktop

```bash
# Set custom installation path
export CLAUDE_DIR="/path/to/claude-desktop"
nix run .
```

Or modify the flake to look in your custom location.

### Patches Don't Apply

```bash
# Check if backup exists
ls -la /opt/claude-desktop/app.asar*

# Manually restore backup
sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar

# Try again
nix run .
```

### Bubblewrap Errors

```bash
# Check bubblewrap availability
nix shell nixpkgs#bubblewrap -c bwrap --version

# Test sandboxing
nix shell nixpkgs#bubblewrap -c bwrap \
  --ro-bind /usr /usr \
  --proc /proc \
  --dev /dev \
  --unshare-pid \
  /usr/bin/echo "Sandbox works!"
```

### Cowork UI Doesn't Appear

Check logs:
```bash
nix run .#run 2>&1 | tee /tmp/claude-cowork.log
grep -i cowork /tmp/claude-cowork.log
```

Expected output:
```
[Cowork Linux] Session created: <uuid>
[Cowork Linux] Dispatching Ready status to UI
```

## Advanced Usage

### Custom Flake Overlays

```nix
# flake.nix
{
  outputs = { self, nixpkgs }:
    let
      # Customize bubblewrap version
      pkgs = import nixpkgs {
        overlays = [
          (final: prev: {
            bubblewrap = prev.bubblewrap.overrideAttrs (old: {
              # Custom build flags, patches, etc.
            });
          })
        ];
      };
    in {
      # ... rest of flake
    };
}
```

### Pinning Versions

```nix
# flake.lock pins nixpkgs automatically
# To use specific version:
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
}
```

### Cross-System Support

The flake supports multiple systems via `flake-utils`:
- x86_64-linux
- aarch64-linux
- x86_64-darwin (for future macOS testing)
- aarch64-darwin

## Contributing

1. Test changes:
```bash
nix flake check  # Validate flake
nix run .        # Test install
```

2. Update documentation in `NIX_README.md`

3. Submit PR with:
   - Working flake
   - Updated docs
   - Test results

## Resources

- [Nix Flakes Reference](https://nixos.wiki/wiki/Flakes)
- [Bubblewrap Documentation](https://github.com/containers/bubblewrap)
- [ASAR Format Specification](https://github.com/electron/asar)
- [Project Status](./COWORK_PROGRESS.md)

## License

Same as the main project (see root LICENSE file).

## Credits

- Nix flake by Claude Code Ralph Loop iterations
- Original Ubuntu install script and patches
- Bubblewrap sandboxing approach
- Cowork Linux implementation
