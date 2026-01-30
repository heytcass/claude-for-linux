#!/bin/bash
# Install Auto-Update Wrapper for Claude Desktop
# Makes Claude check for updates before launching

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Auto-Update Wrapper Installer ===${NC}"
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Claude Desktop is installed
if [ ! -d "/opt/claude-desktop" ]; then
    echo -e "${RED}Error: Claude Desktop not found at /opt/claude-desktop${NC}"
    exit 1
fi

# Install wrapper script
echo -e "${YELLOW}[1/4] Installing wrapper script...${NC}"
sudo cp "$SCRIPT_DIR/claude-wrapper-with-update.sh" /opt/claude-desktop/
sudo chmod +x /opt/claude-desktop/claude-wrapper-with-update.sh
echo -e "${GREEN}✓ Wrapper installed${NC}"
echo

# Update desktop file
echo -e "${YELLOW}[2/4] Updating desktop launcher...${NC}"

# Find existing desktop file
DESKTOP_FILE=""
if [ -f "/usr/share/applications/claude.desktop" ]; then
    DESKTOP_FILE="/usr/share/applications/claude.desktop"
elif [ -f "$HOME/.local/share/applications/claude.desktop" ]; then
    DESKTOP_FILE="$HOME/.local/share/applications/claude.desktop"
fi

if [ -n "$DESKTOP_FILE" ]; then
    # Backup original
    sudo cp "$DESKTOP_FILE" "$DESKTOP_FILE.backup-$(date +%s)"

    # Update Exec line to use wrapper
    sudo sed -i 's|^Exec=.*|Exec=/opt/claude-desktop/claude-wrapper-with-update.sh|' "$DESKTOP_FILE"

    echo -e "${GREEN}✓ Desktop file updated${NC}"
    echo "  Original backed up to: $DESKTOP_FILE.backup-*"
else
    echo -e "${YELLOW}⚠️  Desktop file not found${NC}"
    echo "You'll need to manually update your launcher."
fi
echo

# Create shell alias
echo -e "${YELLOW}[3/4] Creating shell alias...${NC}"

ALIAS_LINE='alias claude-desktop="/opt/claude-desktop/claude-wrapper-with-update.sh"'

# Add to bashrc if not already there
if ! grep -q "claude-wrapper-with-update" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# Claude Desktop with auto-update" >> "$HOME/.bashrc"
    echo "$ALIAS_LINE" >> "$HOME/.bashrc"
    echo -e "${GREEN}✓ Added alias to ~/.bashrc${NC}"
else
    echo -e "${GREEN}✓ Alias already exists${NC}"
fi

# Add to zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "claude-wrapper-with-update" "$HOME/.zshrc" 2>/dev/null; then
        echo "" >> "$HOME/.zshrc"
        echo "# Claude Desktop with auto-update" >> "$HOME/.zshrc"
        echo "$ALIAS_LINE" >> "$HOME/.zshrc"
        echo -e "${GREEN}✓ Added alias to ~/.zshrc${NC}"
    fi
fi
echo

# Test wrapper
echo -e "${YELLOW}[4/4] Testing wrapper...${NC}"
if /opt/claude-desktop/claude-wrapper-with-update.sh --version 2>&1 | grep -q "Claude\|Electron"; then
    echo -e "${GREEN}✓ Wrapper works${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify wrapper (Claude may not be running)${NC}"
fi
echo

echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo
echo "The auto-update wrapper is now installed. Claude will check for updates:"
echo "  • Every 24 hours on launch"
echo "  • Quick check (2-second timeout, non-blocking)"
echo "  • Shows notification if update available"
echo "  • Asks if you want to update now"
echo
echo "Usage:"
echo "  • Desktop launcher: Click Claude icon (auto-update enabled)"
echo "  • Terminal: claude-desktop (alias, auto-update enabled)"
echo "  • Direct: /opt/claude-desktop/claude-wrapper-with-update.sh"
echo
echo "Configuration:"
echo "  • Update check interval: Edit UPDATE_CHECK_INTERVAL in wrapper script"
echo "  • Last check time: ~/.cache/claude-desktop/last-update-check"
echo
echo "To disable auto-update, use the original launcher:"
echo "  /opt/claude-desktop/claude-desktop.sh"
echo
