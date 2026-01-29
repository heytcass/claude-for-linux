# Cowork Linux Installation Guide

## Overview
This guide walks through enabling Claude Desktop's Cowork feature on Linux using bubblewrap for sandboxing instead of macOS VMs.

## Prerequisites

1. **Claude Desktop Linux** (from our previous installation)
2. **Bubblewrap** (Linux sandboxing tool)
3. **Python 3** (for ASAR manipulation)

## Step 1: Install Dependencies

```bash
# Install bubblewrap
sudo nala install bubblewrap

# Verify installation
bwrap --version
# Should output: bubblewrap 0.x.x
```

## Step 2: Extract Current app.asar

```bash
# Create working directory
mkdir -p /tmp/cowork-patch
cd /tmp/cowork-patch

# Extract current app.asar
python3 /opt/claude-desktop/asar_tool.py extract \
  /opt/claude-desktop/app.asar \
  /tmp/app-extracted
```

## Step 3: Apply Cowork Patch

```bash
# Run the patcher
node /tmp/patch-cowork-linux.js /tmp/app-extracted
```

Expected output:
```
=== Claude Cowork Linux Patcher ===

[1/4] Installing claude-cowork-linux module...
✓ Module installed

[2/4] Reading index.js...
✓ Read X.XX MB

[3/4] Applying patches...
✓ Added Linux Cowork import
✓ Found VM process function
✓ Patched VM process function for Linux
✓ Patched availability checks
✓ Found request_cowork_directory function
✓ Patched request_cowork_directory for Linux

[4/4] Writing patched index.js...
✓ Written X.XX MB
  Size change: X.XX KB

=== Patching Complete ===
```

## Step 4: Repack app.asar

```bash
# Create backup
sudo cp /opt/claude-desktop/app.asar /opt/claude-desktop/app.asar.pre-cowork

# Repack with Cowork patches
python3 /opt/claude-desktop/asar_tool.py pack \
  /tmp/app-extracted \
  /tmp/app-patched.asar

# Install patched version
sudo cp /tmp/app-patched.asar /opt/claude-desktop/app.asar

# Copy unpacked resources
sudo cp -r /tmp/app-extracted/app.asar.unpacked /opt/claude-desktop/ 2>/dev/null || true
```

## Step 5: Restart Claude Desktop

```bash
# Kill any running instances
killall electron

# Launch Claude Desktop
claude-desktop
```

## Testing Cowork

### Test 1: Basic Availability

1. Open Claude Desktop
2. Start a new conversation
3. Type: "Can you use Cowork to access my home directory?"
4. Claude should offer to use `request_cowork_directory` tool

### Test 2: Directory Request

1. In conversation, say: "I want you to analyze files in my Documents folder"
2. Claude should invoke `request_cowork_directory`
3. A file picker dialog should appear
4. Select your Documents folder
5. Claude should confirm access and show directory structure

### Test 3: File Operations

1. After mounting a directory, ask: "List all files in this directory"
2. Claude should be able to read directory contents
3. Ask: "Read the contents of [filename]"
4. Verify Claude can read file contents

### Test 4: Sandbox Verification

```bash
# Check active Cowork sessions
ls -la /tmp/claude-cowork-sessions/

# You should see session directories when Cowork is active
# Each session has:
# - mnt/ (mounted directories)
# - sandbox-root/ (sandbox environment)
# - session.json (metadata)
```

## Troubleshooting

### Error: "bubblewrap not found"

```bash
# Verify bubblewrap is installed
which bwrap

# If not found, install
sudo nala install bubblewrap
```

### Error: "Session VM process not available"

This means the Cowork patches weren't applied correctly. Verify:

```bash
# Check if claude-cowork-linux module exists
ls -la /tmp/app-extracted/node_modules/claude-cowork-linux/

# Should contain:
# - index.js
# - package.json
```

### Error: "Permission denied" when mounting

Bubblewrap needs proper permissions. Check:

```bash
# Verify bubblewrap has correct permissions
ls -l /usr/bin/bwrap

# Should be: -rwxr-xr-x or with setuid bit
```

Some distros require bubblewrap to be setuid:

```bash
# Check if setuid bit is needed
getcap /usr/bin/bwrap

# If needed, your distro should set this during package installation
```

### Directories not appearing in /sessions/

Check the session manager:

```bash
# View session directories
ls -la /tmp/claude-cowork-sessions/

# Check recent logs
journalctl -xe | grep claude
```

## Advanced Configuration

### Custom Sandbox Options

Edit `/opt/claude-desktop/node_modules/claude-cowork-linux/index.js`:

```javascript
// Add additional isolation
bwrapArgs.push(
  '--unshare-net',  // Disable network access
  '--ro-bind', '/etc', '/etc',  // Read-only /etc
);
```

### Session Cleanup

Cowork sessions are automatically cleaned up, but you can manually clear:

```bash
# Remove all stale sessions
rm -rf /tmp/claude-cowork-sessions/*
```

### Debugging

Enable verbose logging:

```javascript
// In claude-cowork-linux.js, add console logs
console.log('[CoworkDebug]', ...);
```

View logs:

```bash
# Run Claude Desktop from terminal to see logs
claude-desktop 2>&1 | grep Cowork
```

## Security Notes

### Sandbox Isolation

Bubblewrap provides:
- ✅ PID namespace isolation
- ✅ IPC namespace isolation
- ✅ Separate /tmp
- ✅ Read-only system mounts
- ⚠️ Network is NOT isolated by default (can be enabled)

### Differences from macOS VM

| Feature | macOS VM | Linux Bubblewrap |
|---------|----------|------------------|
| Isolation Level | Full VM | Process namespace |
| Network Isolation | Yes | Optional |
| Disk Isolation | Yes | Via namespaces |
| Performance | Heavier | Lighter |
| Startup Time | Slower | Faster |

### What's Sandboxed

When Claude Code runs in Cowork:
- ✅ File system access limited to mounted directories
- ✅ Cannot access home directory unless mounted
- ✅ Cannot modify system files
- ✅ Process isolation from host
- ⚠️ Can still access network (unless --unshare-net added)

### What's NOT Sandboxed

- Network access (by default)
- GPU access
- Some /dev devices

## Integration with Update Script

The Cowork patches should be applied during updates. Edit `/opt/claude-desktop/update-claude-desktop.sh`:

```bash
# After "Apply patches" section, add:

# Apply Cowork patches
echo -e "${YELLOW}[4.5/7] Applying Cowork patches...${NC}"
node /opt/claude-desktop/patch-cowork-linux.js "$WORK_DIR/app-contents"
echo -e "${GREEN}✓ Cowork patches applied${NC}"
```

## Rollback

If Cowork causes issues:

```bash
# Restore pre-Cowork version
sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar

# Restart
killall electron
claude-desktop
```

## What Works

- ✅ Directory selection via GUI
- ✅ File reading/writing in mounted directories
- ✅ Multiple directory mounts
- ✅ Session isolation
- ✅ Process sandboxing
- ✅ Claude Code tool execution

## Known Limitations

- ⚠️ Network sandboxing not enabled by default
- ⚠️ GPU access not restricted
- ⚠️ Some advanced VM features may not work
- ⚠️ Performance slightly different from macOS VM

## Future Enhancements

Possible improvements:
1. Add network isolation option
2. Implement resource limits (CPU, memory)
3. Add session persistence across restarts
4. Implement VM snapshot/restore equivalent
5. Add cgroups for resource management

## Support

If you encounter issues:

1. Check bubblewrap version: `bwrap --version`
2. Verify patches applied: Check index.js.cowork-backup exists
3. Check session directory: `ls /tmp/claude-cowork-sessions/`
4. View detailed logs: Run Claude Desktop from terminal

## Files Created/Modified

- `/tmp/claude-cowork-linux.js` - Session manager
- `/tmp/patch-cowork-linux.js` - Patcher script
- `/tmp/cowork-research.md` - Research notes
- `/tmp/app-extracted/node_modules/claude-cowork-linux/` - Installed module
- `/tmp/app-extracted/.vite/build/index.js` - Patched main file
- `/opt/claude-desktop/app.asar` - Updated application
