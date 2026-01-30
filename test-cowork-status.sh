#!/bin/bash
set -e

echo "=== Testing Cowork with Ready Status Signal ==="
echo

# Run installation (it will prompt for sudo internally)
bash scripts/install-cowork-v12.sh

# Launch and watch logs
echo
echo "=== Launching Claude Desktop ==="
echo "Watch for '[Cowork Linux] Dispatching Ready status to UI' in the logs"
echo
/opt/claude-desktop/claude-desktop.sh --no-sandbox 2>&1 | grep -i "cowork\|ready\|status" || /opt/claude-desktop/claude-desktop.sh --no-sandbox
