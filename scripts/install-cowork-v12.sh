#!/bin/bash
# Claude Desktop Cowork Linux Installer v12
# Applies all patches: v3, v7, v8, v9, v10, v11

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Cowork Linux Installer v12 ===${NC}"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Error: Do not run this script with sudo${NC}"
  exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"

# Check Claude Desktop
if [ ! -d "/opt/claude-desktop" ]; then
  echo -e "${RED}Error: Claude Desktop not found at /opt/claude-desktop${NC}"
  exit 1
fi
echo "  ✓ Claude Desktop found"

# Check patch files
PATCHES=(
  "patch-cowork-linux-v3.js"
  "patch-cowork-v7-function.js"
  "patch-cowork-v8-intercept.js"
  "patch-cowork-v9-skip-download.js"
  "patch-cowork-v10-vi-function.js"
  "patch-cowork-v11-swift-module.js"
)

for patch in "${PATCHES[@]}"; do
  if [ ! -f "$SCRIPT_DIR/$patch" ]; then
    echo -e "${RED}Error: $patch not found${NC}"
    exit 1
  fi
done
echo "  ✓ All patch files found"

# Check cowork module
if [ ! -f "$PROJECT_ROOT/modules/claude-cowork-linux.js" ]; then
  echo -e "${RED}Error: claude-cowork-linux.js not found${NC}"
  exit 1
fi
echo "  ✓ Cowork module found"

echo

echo -e "${YELLOW}[2/7] Installing bubblewrap...${NC}"
if command -v bwrap &> /dev/null; then
  echo "  ✓ Bubblewrap already installed"
else
  sudo nala install -y bubblewrap
  echo "  ✓ Bubblewrap installed"
fi

echo

echo -e "${YELLOW}[3/7] Extracting app.asar...${NC}"
sudo rm -rf /tmp/app-extracted
# Extract from pre-cowork backup to get clean slate
python3 /opt/claude-desktop/asar_tool.py extract \
  /opt/claude-desktop/app.asar.pre-cowork \
  /tmp/app-extracted > /dev/null 2>&1
sudo chown -R $USER:$USER /tmp/app-extracted
echo "  ✓ Extracted from pre-cowork backup"

echo

echo -e "${YELLOW}[4/7] Installing cowork module...${NC}"
sudo mkdir -p /tmp/app-extracted/node_modules/claude-cowork-linux
sudo cp "$PROJECT_ROOT/modules/claude-cowork-linux.js" \
  /tmp/app-extracted/node_modules/claude-cowork-linux/index.js
sudo chown -R $USER:$USER /tmp/app-extracted/node_modules/claude-cowork-linux
echo "  ✓ Module installed"

echo

echo -e "${YELLOW}[5/7] Applying patches...${NC}"
for patch in "${PATCHES[@]}"; do
  echo "  Applying $patch..."
  node "$SCRIPT_DIR/$patch" /tmp/app-extracted 2>&1 | grep -E "✅|Found|Applied" || true
done
echo "  ✓ All patches applied"

echo

echo -e "${YELLOW}[6/7] Repacking app.asar...${NC}"
sudo mv /opt/claude-desktop/app.asar /opt/claude-desktop/app.asar.backup-$(date +%s)
python3 /opt/claude-desktop/asar_tool.py pack \
  /tmp/app-extracted \
  /tmp/app-extracted-new.asar > /dev/null 2>&1
sudo mv /tmp/app-extracted-new.asar /opt/claude-desktop/app.asar
echo "  ✓ Repacked"

echo

echo -e "${YELLOW}[7/7] Cleaning up...${NC}"
# Keep /tmp/app-extracted for debugging
echo "  ✓ Done (kept /tmp/app-extracted for debugging)"

echo
echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo "Launch Claude Code and toggle Cowork on."
echo "Watch for: '[Cowork Linux] Dispatching Ready status to UI'"
