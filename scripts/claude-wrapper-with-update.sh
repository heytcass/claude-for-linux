#!/bin/bash
# Claude Desktop Wrapper with Auto-Update Check
# Checks for updates before launching Claude

set -e

# Configuration
UPDATE_CHECK_INTERVAL=$((24 * 3600))  # 24 hours in seconds
LAST_CHECK_FILE="$HOME/.cache/claude-desktop/last-update-check"
VERSION_FILE="/opt/claude-desktop/version.txt"
UPDATE_SCRIPT="/opt/claude-desktop/update-claude-desktop.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure cache directory exists
mkdir -p "$(dirname "$LAST_CHECK_FILE")"

# Function to check if update is needed
should_check_update() {
    # If never checked, do it now
    if [ ! -f "$LAST_CHECK_FILE" ]; then
        return 0
    fi

    # Check time since last check
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))

    if [ $TIME_DIFF -ge $UPDATE_CHECK_INTERVAL ]; then
        return 0
    else
        return 1
    fi
}

# Function to quick-check for updates (fast, non-blocking)
quick_update_check() {
    local current_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.1.0")
    local current_build=$(echo "$current_version" | cut -d. -f3)
    local test_build=$((current_build + 10))  # Check 10 versions ahead
    local test_version="1.1.$test_build"
    local base_url="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-mac-release"

    # Quick HEAD request with 2s timeout
    if timeout 2 curl -sf -I "$base_url/Claude-darwin-universal-${test_version}.dmg" >/dev/null 2>&1; then
        return 0  # Update available
    else
        return 1  # No update or network issue
    fi
}

# Function to show update notification
show_update_notification() {
    if command -v notify-send &> /dev/null; then
        notify-send -i dialog-information \
            "Claude Desktop Update Available" \
            "A newer version is available. Run 'sudo bash $UPDATE_SCRIPT' to update."
    else
        echo -e "${YELLOW}⚠️  Claude Desktop update available!${NC}"
        echo "Run: sudo bash $UPDATE_SCRIPT"
    fi
}

# Main update check logic
if should_check_update; then
    echo -e "${BLUE}Checking for Claude Desktop updates...${NC}"

    # Record check time
    date +%s > "$LAST_CHECK_FILE"

    # Quick check (non-blocking, times out after 2s)
    if quick_update_check; then
        show_update_notification

        # Ask user if they want to update now
        echo -e "${YELLOW}Update available! Update now? [y/N]${NC}"
        read -t 5 -n 1 -r REPLY || REPLY="n"
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -f "$UPDATE_SCRIPT" ]; then
                echo "Launching updater (requires sudo)..."
                sudo bash "$UPDATE_SCRIPT"
                echo "Update complete! Restarting Claude..."
                sleep 2
            else
                echo -e "${RED}Update script not found at $UPDATE_SCRIPT${NC}"
            fi
        else
            echo "Skipping update. You can update later with: sudo bash $UPDATE_SCRIPT"
        fi
    else
        echo -e "${GREEN}✓ Claude Desktop is up to date${NC}"
    fi
fi

# Launch Claude Desktop
if [ -f "/opt/claude-desktop/claude-desktop.sh" ]; then
    exec /opt/claude-desktop/claude-desktop.sh --no-sandbox "$@"
elif [ -f "/opt/claude-desktop/claude" ]; then
    exec /opt/claude-desktop/claude --no-sandbox "$@"
else
    echo -e "${RED}Error: Claude Desktop executable not found${NC}"
    exit 1
fi
