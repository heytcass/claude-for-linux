# Claude Desktop Auto-Update Feature

Automatically checks for Claude Desktop updates before launching the app.

## Quick Start

### Option 1: Ubuntu/Debian

```bash
# Install auto-update wrapper
bash scripts/install-auto-update-wrapper.sh

# Launch Claude (auto-update enabled)
claude-desktop
```

### Option 2: Nix Flake

```bash
# Launch with auto-update
nix run .#run-auto-update

# Or make it default
programs.claude-cowork = {
  enable = true;
  autoUpdate = true;  # Uses wrapper with auto-update
};
```

## How It Works

### Update Check Logic

1. **Frequency**: Checks once every 24 hours
2. **Speed**: Quick HEAD request with 2-second timeout
3. **Non-blocking**: Doesn't delay Claude launch
4. **Smart**: Only checks if >24h since last check

### Update Check Flow

```
Launch Claude
     ↓
Check last update check time
     ↓
< 24h since last? ──YES──> Skip check, launch Claude
     ↓
    NO
     ↓
Quick HTTP HEAD request (2s timeout)
     ↓
Update found? ──NO──> Launch Claude
     ↓
   YES
     ↓
Show notification
     ↓
Ask: "Update now? [y/N]"
     ↓
YES: Run updater → Launch Claude
NO:  Launch Claude
```

### Files

- **Wrapper**: `/opt/claude-desktop/claude-wrapper-with-update.sh`
- **Last Check**: `~/.cache/claude-desktop/last-update-check` (timestamp)
- **Updater**: `/opt/claude-desktop/update-claude-desktop.sh`

## Configuration

### Change Check Interval

Edit the wrapper script:

```bash
sudo nano /opt/claude-desktop/claude-wrapper-with-update.sh
```

Change this line:
```bash
UPDATE_CHECK_INTERVAL=$((24 * 3600))  # 24 hours in seconds
```

Examples:
- Every launch: `UPDATE_CHECK_INTERVAL=0`
- Every hour: `UPDATE_CHECK_INTERVAL=3600`
- Every week: `UPDATE_CHECK_INTERVAL=$((7 * 24 * 3600))`

### Disable Update Checks

Use the original launcher:

```bash
/opt/claude-desktop/claude-desktop.sh --no-sandbox
```

Or remove the alias from your shell:

```bash
# Edit ~/.bashrc and remove the claude-desktop alias
nano ~/.bashrc
```

### Force Update Check

Delete the timestamp file:

```bash
rm ~/.cache/claude-desktop/last-update-check
claude-desktop  # Will check on next launch
```

## Desktop Integration

### Desktop Launcher

The installer updates your desktop file:

**Before**:
```desktop
Exec=/opt/claude-desktop/claude-desktop.sh
```

**After**:
```desktop
Exec=/opt/claude-desktop/claude-wrapper-with-update.sh
```

### Restore Original Launcher

```bash
# Find backup
ls -la /usr/share/applications/claude.desktop.backup-*

# Restore
sudo cp /usr/share/applications/claude.desktop.backup-TIMESTAMP \
  /usr/share/applications/claude.desktop
```

## Notifications

### Desktop Notifications

Uses `notify-send` for GUI notifications:

```
┌────────────────────────────────────────┐
│ 🔔 Claude Desktop Update Available     │
│                                        │
│ A newer version is available.          │
│ Run 'sudo bash update-claude-desktop.sh'│
└────────────────────────────────────────┘
```

### Terminal Notifications

If no `notify-send`, shows in terminal:

```
⚠️  Claude Desktop update available!
Run: sudo bash /opt/claude-desktop/update-claude-desktop.sh
Update available! Update now? [y/N]
```

## Update Process

If you choose to update immediately:

1. Wrapper detects update
2. Shows prompt: "Update now? [y/N]"
3. You press `y`
4. Runs: `sudo bash update-claude-desktop.sh`
5. Downloads new version (~214MB)
6. Applies Linux patches
7. Installs atomically
8. Relaunches Claude

Total time: ~5-10 minutes depending on connection.

## Security

### Update Source

Updates are downloaded from:
```
https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-mac-release
```

This is Anthropic's official CDN.

### Verification

- Quick check: HTTP HEAD request only (no download)
- Actual update: Runs existing update script with sudo
- Atomic install: Old version backed up before replacing

### Network Timeout

- Quick check: 2-second timeout
- Won't hang Claude launch if network is down
- Fails gracefully (launches Claude anyway)

## Troubleshooting

### "Update available" but none exists

The quick check is conservative - it checks 10 versions ahead:

```bash
current=1.1.1200
quick_check=1.1.1210  # Checks this version
```

If 1.1.1205 exists, it won't be detected by quick check. Run full updater:

```bash
sudo bash /opt/claude-desktop/update-claude-desktop.sh
```

### Notifications not showing

Install libnotify:

```bash
sudo nala install libnotify-bin
```

Test:

```bash
notify-send "Test" "This is a test notification"
```

### Update check hanging

The wrapper has a 2-second timeout. If it hangs, your network may be slow. Increase timeout:

```bash
sudo nano /opt/claude-desktop/claude-wrapper-with-update.sh
```

Change:
```bash
if timeout 2 curl -sf -I "$base_url..." >/dev/null 2>&1; then
```

To:
```bash
if timeout 5 curl -sf -I "$base_url..." >/dev/null 2>&1; then
```

### Wrapper not working

Check if it's executable:

```bash
ls -la /opt/claude-desktop/claude-wrapper-with-update.sh
```

Should show: `-rwxr-xr-x` (executable)

If not:
```bash
sudo chmod +x /opt/claude-desktop/claude-wrapper-with-update.sh
```

## Comparison: With vs Without Auto-Update

| Feature | Without | With Auto-Update |
|---------|---------|------------------|
| **Update Check** | Manual | Automatic |
| **Frequency** | When you remember | Every 24h |
| **Notifications** | None | Desktop + Terminal |
| **Launch Delay** | 0ms | 0-2000ms (once/day) |
| **Interruption** | None | Optional prompt |
| **Maintenance** | High | Low |

## Advanced: Nix Integration

### Home Manager with Auto-Update

```nix
programs.claude-cowork = {
  enable = true;
  wrapper = "auto-update";  # Use auto-update wrapper
};
```

### NixOS Service with Auto-Update

```nix
services.claude-cowork = {
  enable = true;
  autoUpdate = true;
  updateCheckInterval = 24 * 3600;  # 24 hours
};
```

### Custom Update Script

```nix
programs.claude-cowork = {
  enable = true;
  updateScript = pkgs.writeShellScript "custom-update" ''
    # Your custom update logic
    notify-send "Updating Claude..."
    # ...
  '';
};
```

## Scripts Reference

### Wrapper Script

`/opt/claude-desktop/claude-wrapper-with-update.sh`

**Functions**:
- `should_check_update()` - Check if >24h since last check
- `quick_update_check()` - Fast HEAD request for new version
- `show_update_notification()` - Desktop/terminal notification

### Installer Script

`scripts/install-auto-update-wrapper.sh`

**Steps**:
1. Copy wrapper to `/opt/claude-desktop/`
2. Update desktop file
3. Add shell aliases
4. Test wrapper

### Updater Script

`/opt/claude-desktop/update-claude-desktop.sh`

**Steps**:
1. Check current version
2. Download new DMG
3. Extract and patch
4. Install atomically
5. Create backup

## Performance Impact

### Minimal Overhead

- **First launch after 24h**: +2 seconds (network check)
- **Subsequent launches**: +0ms (no check)
- **Update found**: +5-10 minutes (if you choose to update)

### Resource Usage

- **Memory**: Negligible (<1MB for curl)
- **CPU**: Negligible (one HTTP request)
- **Network**: One HEAD request (~1KB)
- **Disk**: 4KB timestamp file

## Future Enhancements

### Planned Features

1. **Background Updates**
   - Download in background while Claude runs
   - Apply on next launch
   - No interruption

2. **Version Pinning**
   - Stay on specific version
   - Skip certain updates
   - Rollback support

3. **Update Channels**
   - Stable (current)
   - Beta (experimental)
   - Nightly (cutting edge)

4. **Differential Updates**
   - Only download changes
   - Faster updates
   - Less bandwidth

## Credits

- **Implementation**: Ralph Loop iteration 1 (Claude Code)
- **Integration**: Auto-update wrapper approach
- **Inspiration**: macOS auto-update behavior

## License

Same as main project - for personal use only.
Claude Desktop is property of Anthropic.
