#!/bin/bash
# Claude Desktop Linux Installation Script
# This script requires sudo access

set -e

echo "=== Claude Desktop Linux Installation ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo"
  echo "Usage: sudo bash $0"
  exit 1
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
echo "Installing Claude Desktop for user: $ACTUAL_USER"
echo

# Step 1: Install to /opt/claude-desktop
echo "[1/5] Installing to /opt/claude-desktop..."
mkdir -p /opt/claude-desktop
cp -r /tmp/claude-install/* /opt/claude-desktop/
chmod +x /opt/claude-desktop/claude-desktop.sh
chmod +x /opt/claude-desktop/electron
echo "  ✓ Files installed"

# Step 2: Create symlink for command-line access
echo "[2/5] Creating /usr/local/bin/claude-desktop symlink..."
ln -sf /opt/claude-desktop/claude-desktop.sh /usr/local/bin/claude-desktop
echo "  ✓ Symlink created"

# Step 3: Install icons
echo "[3/5] Installing icons..."
for size in 16 32 48 128 256 512; do
  ICON_DIR="/usr/local/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$ICON_DIR"
  if [ -f "/tmp/icon_${size}x${size}.png" ]; then
    cp "/tmp/icon_${size}x${size}.png" "$ICON_DIR/claude-desktop.png"
  fi
done

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache /usr/local/share/icons/hicolor/ 2>/dev/null || true
  echo "  ✓ Icons installed and cache updated"
else
  echo "  ✓ Icons installed (gtk-update-icon-cache not found, skipping cache update)"
fi

# Step 4: Install desktop entry
echo "[4/5] Installing desktop entry..."
cp /tmp/claude-install/claude-desktop.desktop /usr/local/share/applications/
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/local/share/applications/ 2>/dev/null || true
  echo "  ✓ Desktop entry installed and database updated"
else
  echo "  ✓ Desktop entry installed (update-desktop-database not found, skipping)"
fi

# Step 5: Set permissions
echo "[5/5] Setting permissions..."
chown -R root:root /opt/claude-desktop
chmod 755 /opt/claude-desktop
echo "  ✓ Permissions set"

echo
echo "=== Installation Complete! ==="
echo
echo "You can now launch Claude Desktop by:"
echo "  1. Searching for 'Claude Desktop' in your application menu"
echo "  2. Running: claude-desktop"
echo
echo "Installation details:"
echo "  - Application: /opt/claude-desktop/"
echo "  - Version: $(cat /opt/claude-desktop/version.txt 2>/dev/null || echo 'unknown')"
echo "  - Desktop entry: /usr/local/share/applications/claude-desktop.desktop"
echo "  - Command: /usr/local/bin/claude-desktop"
echo
