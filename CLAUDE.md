# claude-for-linux

Enabling macOS-only Claude Desktop features on Linux via runtime patching.

## Architecture

- **Target**: Electron app at `/opt/claude-desktop/app.asar`
- **Method**: Extract ASAR, patch minified JS, repack
- **Installer**: `scripts/install-cowork-v12.sh` (requires sudo for /opt/ access)

## Key Commands

```bash
# Install patches (extracts from pre-cowork backup for clean slate)
bash scripts/install-cowork-v12.sh

# Launch for testing
/opt/claude-desktop/claude-desktop.sh --no-sandbox 2>&1 | grep -E "Cowork|error"

# Verify patch applied to extracted app
node -e "const fs=require('fs'); const c=fs.readFileSync('/tmp/app-extracted/.vite/build/index.js','utf8'); console.log(c.includes('SEARCH_PATTERN') ? 'FOUND' : 'NOT FOUND');"

# Search minified code for patterns
grep -o ".\{0,50\}PATTERN.\{0,50\}" /tmp/app-extracted/.vite/build/index.js | head -5
```

## Patching Workflow

1. **Always extract from backup**: Use `app.asar.pre-cowork` not `app.asar` (already patched)
2. **Test patches on extracted app**: Before repacking, verify changes with grep/node
3. **Search for all method calls**: `grep -o "vmInstance\.[a-zA-Z_]*" file.js | sort -u`
4. **Process guards are critical**: `if (process.type !== 'browser') return;` prevents renderer crashes

## Electron Gotchas

- **Process types**: Main (type='browser') vs renderer - only main can access Node.js
- **ASAR tool**: Use `/opt/claude-desktop/asar_tool.py` not `npx asar` (has bugs)
- **App caching**: Kill all processes with `pkill -f claude-desktop` before testing new patches
- **ChildProcess objects**: Can't add methods via assignment - use Proxy or Object.defineProperty

## Current State

See `COWORK_PROGRESS.md` for detailed status of Cowork Linux implementation.
