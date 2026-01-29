#!/bin/bash
# Claude Desktop Linux Update Script
# Updates Claude Desktop while preserving Linux patches

set -e

INSTALL_DIR="/opt/claude-desktop"
VERSION_FILE="$INSTALL_DIR/version.txt"
WORK_DIR="/tmp/claude-update-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Claude Desktop Linux Updater ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run with sudo${NC}"
  echo "Usage: sudo bash $0 [VERSION]"
  exit 1
fi

# Get current version
CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0")
echo "Current version: $CURRENT_VERSION"

# Auto-detect latest version if not provided
if [ -n "$1" ]; then
  LATEST_VERSION="$1"
  echo "Target version: $LATEST_VERSION (from argument)"
else
  echo
  echo -e "${YELLOW}Checking for latest version...${NC}"

  # Probe for newer versions by checking if files exist
  # Start from current version and check next 100 build numbers
  BASE_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-mac-release"
  CURRENT_BUILD=$(echo "$CURRENT_VERSION" | cut -d. -f3)
  LATEST_VERSION="$CURRENT_VERSION"

  # Quick probe - check every 10th version for speed
  for i in $(seq 10 10 100); do
    BUILD=$((CURRENT_BUILD + i))
    TEST_VERSION="1.1.$BUILD"
    if curl -sf -I "$BASE_URL/Claude-darwin-universal-${TEST_VERSION}.dmg" >/dev/null 2>&1; then
      LATEST_VERSION="$TEST_VERSION"
      echo -e "${GREEN}Found newer version: $TEST_VERSION${NC}"
    fi
  done

  # Fine-grained search around latest found
  if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
    SEARCH_START=$(echo "$LATEST_VERSION" | cut -d. -f3)
    for i in $(seq -10 1 10); do
      BUILD=$((SEARCH_START + i))
      if [ $BUILD -le $CURRENT_BUILD ]; then
        continue
      fi
      TEST_VERSION="1.1.$BUILD"
      if curl -sf -I "$BASE_URL/Claude-darwin-universal-${TEST_VERSION}.dmg" >/dev/null 2>&1; then
        LATEST_VERSION="$TEST_VERSION"
      fi
    done
  fi

  # If no newer version found
  if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo -e "${GREEN}No newer version found (checked up to 1.1.$((CURRENT_BUILD + 100)))${NC}"
    echo -e "${YELLOW}Enter version manually to force update, or press Enter to exit:${NC}"
    read -r MANUAL_VERSION
    if [ -n "$MANUAL_VERSION" ]; then
      LATEST_VERSION="$MANUAL_VERSION"
    else
      exit 0
    fi
  else
    echo -e "${GREEN}Latest version: $LATEST_VERSION${NC}"
  fi
fi

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo -e "${GREEN}Already up to date.${NC}"
  exit 0
fi

echo
echo -e "${YELLOW}Update available: $CURRENT_VERSION → $LATEST_VERSION${NC}"
echo "This will download ~214MB and install the update."
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 0
fi

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download DMG
echo
echo -e "${YELLOW}[1/7] Downloading Claude Desktop $LATEST_VERSION...${NC}"
DMG_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-mac-release/Claude-darwin-universal-${LATEST_VERSION}.dmg"

# Try direct download first
if wget -q --show-progress -O Claude.dmg "$DMG_URL" 2>/dev/null; then
  echo -e "${GREEN}✓ Downloaded via wget${NC}"
else
  # Fall back to browser download
  echo -e "${YELLOW}Direct download failed, opening browser...${NC}"
  echo "Please download the macOS .dmg file and save it to: $WORK_DIR/Claude.dmg"
  xdg-open "https://claude.com/download" 2>/dev/null || firefox "https://claude.com/download" 2>/dev/null || google-chrome "https://claude.com/download" 2>/dev/null || true

  echo "Waiting for download..."
  while [ ! -f "$WORK_DIR/Claude.dmg" ]; do
    sleep 2
    # Also check ~/Downloads
    if [ -f ~/Downloads/Claude.dmg ]; then
      mv ~/Downloads/Claude.dmg "$WORK_DIR/Claude.dmg"
      break
    fi
  done
  echo -e "${GREEN}✓ Downloaded${NC}"
fi

# Extract DMG
echo
echo -e "${YELLOW}[2/7] Extracting DMG...${NC}"
dmg2img Claude.dmg -o claude.img >/dev/null 2>&1
7z x claude.img -o"$WORK_DIR/extracted" >/dev/null 2>&1
echo -e "${GREEN}✓ Extracted${NC}"

# Extract app.asar
echo
echo -e "${YELLOW}[3/7] Extracting app.asar...${NC}"
python3 /opt/claude-desktop/asar_tool.py extract \
  "$WORK_DIR/extracted/Claude/Claude.app/Contents/Resources/app.asar" \
  "$WORK_DIR/app-contents" >/dev/null 2>&1

# Copy unpacked resources
cp -r "$WORK_DIR/extracted/Claude/Claude.app/Contents/Resources/app.asar.unpacked" \
  "$WORK_DIR/" 2>/dev/null || true

# Add i18n files
mkdir -p "$WORK_DIR/app-contents/resources/i18n"
cp "$WORK_DIR/extracted/Claude/Claude.app/Contents/Resources"/*.json \
  "$WORK_DIR/app-contents/resources/i18n/" 2>/dev/null || true

echo -e "${GREEN}✓ Extracted${NC}"

# Apply patches
echo
echo -e "${YELLOW}[4/7] Applying Linux patches...${NC}"

# Add enhanced native module stub
mkdir -p "$WORK_DIR/app-contents/node_modules/claude-native"
cp /opt/claude-desktop/enhanced-claude-native-stub.js \
  "$WORK_DIR/app-contents/node_modules/claude-native/index.js"
cat > "$WORK_DIR/app-contents/node_modules/claude-native/package.json" << 'EOF'
{
  "name": "claude-native",
  "version": "1.0.0-linux",
  "description": "Linux stub for Claude native module using Electron APIs",
  "main": "index.js"
}
EOF

# Patch platform detection for Claude Code
cd "$WORK_DIR/app-contents/.vite/build"
sed -i 's/if(process.platform==="win32")return"win32-x64";throw new Error/if(process.platform==="win32")return"win32-x64";if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";throw new Error/g' index.js

# Patch window decorations
sed -i 's/frame:!1/frame:process.platform==="linux"?!0:!1/g' index.js
sed -i 's/titleBarStyle:"hidden"/titleBarStyle:process.platform==="linux"?"default":"hidden"/g' index.js
sed -i 's/titleBarStyle:"hiddenInset"/titleBarStyle:process.platform==="linux"?"default":"hiddenInset"/g' index.js

echo -e "${GREEN}✓ Patches applied${NC}"

# Repack ASAR
echo
echo -e "${YELLOW}[5/7] Repacking app.asar...${NC}"
cd "$WORK_DIR"
python3 /opt/claude-desktop/asar_tool.py pack \
  "$WORK_DIR/app-contents" \
  "$WORK_DIR/app.asar" >/dev/null 2>&1
echo -e "${GREEN}✓ Repacked${NC}"

# Stop running instance
echo
echo -e "${YELLOW}[6/7] Stopping Claude Desktop...${NC}"
killall electron 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓ Stopped${NC}"

# Atomic installation
echo
echo -e "${YELLOW}[7/7] Installing update...${NC}"
cp "$INSTALL_DIR/app.asar" "$INSTALL_DIR/app.asar.backup-$CURRENT_VERSION"
cp "$WORK_DIR/app.asar" "$INSTALL_DIR/app.asar"
cp -r "$WORK_DIR/app.asar.unpacked" "$INSTALL_DIR/" 2>/dev/null || true
echo "$LATEST_VERSION" > "$VERSION_FILE"
echo -e "${GREEN}✓ Installed${NC}"

# Cleanup
cd /tmp
rm -rf "$WORK_DIR"

echo
echo -e "${GREEN}=== Update Complete! ===${NC}"
echo
echo "Claude Desktop updated: $CURRENT_VERSION → $LATEST_VERSION"
echo "You can now launch: claude-desktop"
echo
echo "Backup of old version: $INSTALL_DIR/app.asar.backup-$CURRENT_VERSION"
