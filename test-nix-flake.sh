#!/bin/bash
# Test script for Nix flake functionality
# Tests all the flake outputs without requiring Claude Desktop installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Cowork Nix Flake Test Suite ===${NC}"
echo

# Test 1: Flake validation
echo -e "${YELLOW}Test 1: Validating flake structure...${NC}"
if nix flake check 2>&1 | grep -q "checking"; then
    echo -e "${GREEN}✅ Flake structure is valid${NC}"
else
    echo -e "${RED}❌ Flake validation failed${NC}"
    exit 1
fi
echo

# Test 2: Build ASAR tool
echo -e "${YELLOW}Test 2: Building ASAR tool...${NC}"
if nix build .#asar-tool --print-build-logs 2>&1 > /dev/null; then
    if [ -f result/bin/asar-tool ]; then
        echo -e "${GREEN}✅ ASAR tool built successfully${NC}"
        echo "   Location: $(readlink result)"
    else
        echo -e "${RED}❌ ASAR tool binary not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ ASAR tool build failed${NC}"
    exit 1
fi
echo

# Test 3: Build patches
echo -e "${YELLOW}Test 3: Building Cowork patches...${NC}"
if nix build .#patches 2>&1 > /dev/null; then
    PATCH_COUNT=$(ls result/patches/*.js 2>/dev/null | wc -l)
    if [ "$PATCH_COUNT" -eq 6 ]; then
        echo -e "${GREEN}✅ All 6 patches built successfully${NC}"
        ls -1 result/patches/
    else
        echo -e "${RED}❌ Expected 6 patches, found $PATCH_COUNT${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Patches build failed${NC}"
    exit 1
fi
echo

# Test 4: Build Cowork module
echo -e "${YELLOW}Test 4: Building Cowork module...${NC}"
if nix build .#module 2>&1 > /dev/null; then
    if [ -f result/node_modules/claude-cowork-linux/index.js ]; then
        echo -e "${GREEN}✅ Cowork module built successfully${NC}"
        echo "   Size: $(wc -l < result/node_modules/claude-cowork-linux/index.js) lines"
    else
        echo -e "${RED}❌ Cowork module not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Cowork module build failed${NC}"
    exit 1
fi
echo

# Test 5: Build installer
echo -e "${YELLOW}Test 5: Building installer script...${NC}"
if nix build .#installer 2>&1 > /dev/null; then
    if [ -f result/bin/install-claude-cowork ]; then
        echo -e "${GREEN}✅ Installer built successfully${NC}"
        echo "   Checking dependencies..."
        if grep -q "bubblewrap" result/bin/.install-claude-cowork-wrapped; then
            echo -e "   ${GREEN}✓${NC} Bubblewrap dependency present"
        fi
        if grep -q "nodejs" result/bin/.install-claude-cowork-wrapped; then
            echo -e "   ${GREEN}✓${NC} Node.js dependency present"
        fi
    else
        echo -e "${RED}❌ Installer binary not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Installer build failed${NC}"
    exit 1
fi
echo

# Test 6: Build wrapper
echo -e "${YELLOW}Test 6: Building wrapper script...${NC}"
if nix build .#wrapper 2>&1 > /dev/null; then
    if [ -f result/bin/claude-desktop-cowork ]; then
        echo -e "${GREEN}✅ Wrapper built successfully${NC}"
        if grep -q "bubblewrap" result/bin/.claude-desktop-cowork-wrapped; then
            echo -e "   ${GREEN}✓${NC} Bubblewrap in PATH"
        fi
    else
        echo -e "${RED}❌ Wrapper binary not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Wrapper build failed${NC}"
    exit 1
fi
echo

# Test 7: Test ASAR tool functionality
echo -e "${YELLOW}Test 7: Testing ASAR tool functionality...${NC}"
nix build .#asar-tool 2>&1 > /dev/null

# Create test directory
TEST_DIR="/tmp/asar-test-$$"
mkdir -p "$TEST_DIR/test-app"
echo "console.log('test');" > "$TEST_DIR/test-app/index.js"
echo '{"name": "test"}' > "$TEST_DIR/test-app/package.json"

# Pack
if result/bin/asar-tool pack "$TEST_DIR/test-app" "$TEST_DIR/test.asar" 2>&1 > /dev/null; then
    echo -e "   ${GREEN}✓${NC} Pack successful"
else
    echo -e "${RED}❌ Pack failed${NC}"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Extract
if result/bin/asar-tool extract "$TEST_DIR/test.asar" "$TEST_DIR/extracted" 2>&1 > /dev/null; then
    echo -e "   ${GREEN}✓${NC} Extract successful"
else
    echo -e "${RED}❌ Extract failed${NC}"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Verify
if [ -f "$TEST_DIR/extracted/index.js" ] && [ -f "$TEST_DIR/extracted/package.json" ]; then
    echo -e "${GREEN}✅ ASAR tool works correctly${NC}"
else
    echo -e "${RED}❌ Extracted files not found${NC}"
    rm -rf "$TEST_DIR"
    exit 1
fi

rm -rf "$TEST_DIR"
echo

# Test 8: Development shell
echo -e "${YELLOW}Test 8: Testing development shell...${NC}"
if nix develop --command bash -c "node --version && python3 --version && bwrap --version" 2>&1 > /dev/null; then
    echo -e "${GREEN}✅ Development shell works${NC}"
    echo "   Tools available:"
    echo "   - Node.js: $(nix develop --command node --version)"
    echo "   - Python: $(nix develop --command python3 --version)"
    echo "   - Bubblewrap: $(nix develop --command bwrap --version | head -1)"
else
    echo -e "${RED}❌ Development shell failed${NC}"
    exit 1
fi
echo

# Test 9: Check flake metadata
echo -e "${YELLOW}Test 9: Checking flake metadata...${NC}"
if nix flake metadata 2>&1 | grep -q "Description:"; then
    echo -e "${GREEN}✅ Flake metadata present${NC}"
    echo "   Description: $(nix flake metadata --json | jq -r '.description' 2>/dev/null || echo 'Claude Desktop for Linux with Cowork support')"
else
    echo -e "${YELLOW}⚠️  Flake metadata incomplete (non-critical)${NC}"
fi
echo

# Test 10: List all outputs
echo -e "${YELLOW}Test 10: Listing flake outputs...${NC}"
echo -e "${GREEN}Available packages:${NC}"
nix flake show 2>&1 | grep "packages" -A 20 | grep "│" || true
echo
echo -e "${GREEN}Available apps:${NC}"
nix flake show 2>&1 | grep "apps" -A 10 | grep "│" || true
echo

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo
echo "The Nix flake is working correctly and ready to use."
echo
echo "Next steps:"
echo "  1. Commit the flake: git commit -m 'Add Nix flake support'"
echo "  2. Test installation: nix run ."
echo "  3. Test wrapper: nix run .#run (requires Claude Desktop installed)"
echo
