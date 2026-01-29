#!/bin/bash
# Claude Desktop Cowork Linux Installer
# Enables Cowork functionality using bubblewrap sandboxing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Claude Desktop Cowork Linux Installer ===${NC}"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Error: Do not run this script with sudo${NC}"
  echo "The script will prompt for sudo when needed."
  exit 1
fi

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

# Check if Claude Desktop is installed
if [ ! -f "/opt/claude-desktop/app.asar" ]; then
  echo -e "${RED}Error: Claude Desktop not found at /opt/claude-desktop/${NC}"
  echo "Please install Claude Desktop for Linux first."
  exit 1
fi
echo "  ✓ Claude Desktop found"

# Check if asar_tool.py exists
if [ ! -f "/opt/claude-desktop/asar_tool.py" ]; then
  echo -e "${RED}Error: asar_tool.py not found${NC}"
  echo "Please ensure asar_tool.py is installed at /opt/claude-desktop/"
  exit 1
fi
echo "  ✓ ASAR tool found"

# Check if patch files exist
if [ ! -f "/tmp/claude-cowork-linux.js" ]; then
  echo -e "${RED}Error: claude-cowork-linux.js not found in /tmp/${NC}"
  exit 1
fi
if [ ! -f "/tmp/patch-cowork-linux-v2.js" ]; then
  echo -e "${RED}Error: patch-cowork-linux-v2.js not found in /tmp/${NC}"
  exit 1
fi
echo "  ✓ Patch files found"

echo

# Step 2: Install bubblewrap
echo -e "${YELLOW}[2/8] Installing bubblewrap...${NC}"

if command -v bwrap &> /dev/null; then
  BWRAP_VERSION=$(bwrap --version 2>&1 | head -1)
  echo "  ✓ Bubblewrap already installed: $BWRAP_VERSION"
else
  echo "  Installing bubblewrap..."
  sudo nala install -y bubblewrap
  echo "  ✓ Bubblewrap installed"
fi

echo

# Step 3: Create backup
echo -e "${YELLOW}[3/8] Creating backup...${NC}"

if [ ! -f "/opt/claude-desktop/app.asar.pre-cowork" ]; then
  sudo cp /opt/claude-desktop/app.asar /opt/claude-desktop/app.asar.pre-cowork
  echo "  ✓ Backup created: app.asar.pre-cowork"
else
  echo "  ⚠ Backup already exists, skipping"
fi

echo

# Step 4: Extract app.asar
echo -e "${YELLOW}[4/8] Extracting app.asar...${NC}"

rm -rf /tmp/app-extracted-cowork
python3 /opt/claude-desktop/asar_tool.py extract \
  /opt/claude-desktop/app.asar \
  /tmp/app-extracted-cowork > /dev/null 2>&1

echo "  ✓ Extracted to /tmp/app-extracted-cowork"
echo

# Step 5: Apply patches
echo -e "${YELLOW}[5/8] Applying Cowork patches...${NC}"

node /tmp/patch-cowork-linux-v2.js /tmp/app-extracted-cowork | grep -E "✓|Total patches"

echo

# Step 6: Repack app.asar
echo -e "${YELLOW}[6/8] Repacking app.asar...${NC}"

python3 /opt/claude-desktop/asar_tool.py pack \
  /tmp/app-extracted-cowork \
  /tmp/app-cowork.asar > /dev/null 2>&1

ASAR_SIZE=$(du -h /tmp/app-cowork.asar | cut -f1)
echo "  ✓ Repacked: $ASAR_SIZE"
echo

# Step 7: Install patched version
echo -e "${YELLOW}[7/8] Installing patched version...${NC}"

sudo cp /tmp/app-cowork.asar /opt/claude-desktop/app.asar

# Copy cowork module to installation directory for future use
sudo mkdir -p /opt/claude-desktop/modules
sudo cp /tmp/claude-cowork-linux.js /opt/claude-desktop/modules/
sudo cp /tmp/patch-cowork-linux-v2.js /opt/claude-desktop/modules/

echo "  ✓ Installed to /opt/claude-desktop/"
echo

# Step 8: Cleanup and verify
echo -e "${YELLOW}[8/8] Cleanup and verification...${NC}"

rm -rf /tmp/app-extracted-cowork
rm -f /tmp/app-cowork.asar

# Kill running instances
killall electron 2>/dev/null || true
sleep 1

echo "  ✓ Cleanup complete"
echo

echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo
echo -e "${BLUE}What's been installed:${NC}"
echo "  • Bubblewrap (Linux sandboxing)"
echo "  • Claude Cowork Linux module"
echo "  • Patched Claude Desktop with Cowork support"
echo
echo -e "${BLUE}Backups:${NC}"
echo "  • /opt/claude-desktop/app.asar.pre-cowork (original)"
echo
echo -e "${BLUE}To use Cowork:${NC}"
echo "  1. Launch Claude Desktop: claude-desktop"
echo "  2. Start a conversation"
echo "  3. Ask Claude to work with files in a directory"
echo "  4. Claude will use 'request_cowork_directory' tool"
echo "  5. Select directory in file picker dialog"
echo
echo -e "${BLUE}Testing:${NC}"
echo "  Try: 'Can you list files in my Documents folder?'"
echo "  Claude should request directory access"
echo
echo -e "${BLUE}Rollback if needed:${NC}"
echo "  sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar"
echo
echo -e "${BLUE}Documentation:${NC}"
echo "  • /tmp/COWORK_INSTALLATION.md - Full installation guide"
echo "  • /tmp/cowork-research.md - Technical research notes"
echo
echo -e "${GREEN}Ready to launch! Run: claude-desktop${NC}"
