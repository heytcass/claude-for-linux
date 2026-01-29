# Cowork Linux Validation Checklist

## Pre-Installation Validation

- [ ] Claude Desktop installed at `/opt/claude-desktop/`
- [ ] `asar_tool.py` exists at `/opt/claude-desktop/asar_tool.py`
- [ ] Current `app.asar` is working correctly
- [ ] Python 3 installed (`python3 --version`)
- [ ] Node.js installed (`node --version`)

## Installation Validation

- [ ] Bubblewrap installed (`bwrap --version`)
- [ ] Backup created (`/opt/claude-desktop/app.asar.pre-cowork` exists)
- [ ] Module created (`/tmp/app-extracted/node_modules/claude-cowork-linux/`)
- [ ] Patches applied (4 patches reported by patcher)
- [ ] app.asar repacked successfully
- [ ] New app.asar installed
- [ ] Claude Desktop launches without errors

## Functionality Validation

### Level 1: Basic Launch
- [ ] Claude Desktop launches
- [ ] No JavaScript errors in console
- [ ] Can start new conversation
- [ ] Can send messages normally

### Level 2: Cowork Detection
- [ ] Console shows "[Cowork] Linux Cowork enabled via bubblewrap"
- [ ] No "bubblewrap not found" warnings
- [ ] Ask Claude: "Can you use Cowork?" - Should say yes

### Level 3: Directory Access
- [ ] Ask: "Can you list files in my Documents?"
- [ ] Claude invokes `request_cowork_directory` tool
- [ ] File picker dialog appears
- [ ] Can select directory
- [ ] Claude confirms access to directory
- [ ] Claude can list directory contents

### Level 4: File Operations
- [ ] Claude can read file contents
- [ ] Claude can create new files
- [ ] Claude can modify existing files
- [ ] Claude can delete files (with confirmation)
- [ ] Files appear in correct location on host

### Level 5: Multiple Directories
- [ ] Can mount second directory
- [ ] Claude can access both directories
- [ ] Can copy files between directories
- [ ] Sessions are isolated properly

### Level 6: Process Execution
- [ ] Claude Code can execute bash commands
- [ ] Commands run in sandbox
- [ ] Commands can access mounted directories
- [ ] Commands cannot access unmounted directories

## Security Validation

### Sandbox Isolation
- [ ] Check `/tmp/claude-cowork-sessions/` exists
- [ ] Session directories have correct permissions (700)
- [ ] Mounted directories are symlinks
- [ ] Running `ps aux | grep bwrap` shows sandboxed processes

### Permission Checks
- [ ] Sandboxed processes cannot access /home directly
- [ ] Sandboxed processes cannot modify /etc
- [ ] Sandboxed processes have separate /tmp
- [ ] Sandboxed processes have separate PID namespace

### Resource Limits
- [ ] Session cleanup works (directories removed)
- [ ] No zombie processes after session end
- [ ] Memory usage reasonable (<50MB per session)
- [ ] CPU usage normal

## Performance Validation

### Timing
- [ ] Session creation < 100ms
- [ ] Directory mount < 100ms
- [ ] Process spawn < 200ms
- [ ] File operations at native speed

### Resource Usage
- [ ] Idle: No extra memory usage
- [ ] Active session: <10MB overhead
- [ ] Running command: Reasonable based on command

## Integration Validation

### Update Script
- [ ] Can run update script with Cowork installed
- [ ] Update preserves Cowork patches (if integrated)
- [ ] Can roll back if needed

### Other Features
- [ ] Claude Code still works
- [ ] Window decorations still work
- [ ] Regular file operations (non-Cowork) work
- [ ] Git operations work
- [ ] Terminal operations work

## Error Handling Validation

### Expected Errors
- [ ] Canceling directory picker returns gracefully
- [ ] Requesting unmounted directory fails gracefully
- [ ] Invalid commands fail with proper error messages
- [ ] Permission denied handled correctly

### Edge Cases
- [ ] Mounting same directory twice handled
- [ ] Mounting directory then deleting it handled
- [ ] Very long directory paths work
- [ ] Special characters in paths work
- [ ] Symlinks in paths work

## Rollback Validation

### Test Rollback
- [ ] Can restore from backup
- [ ] Backup version launches correctly
- [ ] No Cowork features in backup version
- [ ] Can re-install Cowork after rollback

## Documentation Validation

- [ ] `/tmp/COWORK_SUMMARY.md` exists and is complete
- [ ] `/tmp/COWORK_INSTALLATION.md` exists and is accurate
- [ ] `/tmp/cowork-research.md` documents implementation
- [ ] README or guide explains how to use Cowork

## Final Checks

### Files Present
- [ ] `/tmp/claude-cowork-linux.js` (module source)
- [ ] `/tmp/patch-cowork-linux-v2.js` (patcher)
- [ ] `/tmp/install-cowork-linux.sh` (installer)
- [ ] `/opt/claude-desktop/app.asar.pre-cowork` (backup)
- [ ] `/opt/claude-desktop/modules/` (installed modules)

### Cleanup
- [ ] Temporary extraction directories removed
- [ ] Intermediate .asar files removed
- [ ] Build artifacts cleaned up

## Sign-off

- [ ] All critical validations passed
- [ ] Documentation complete
- [ ] Ready for user testing
- [ ] Rollback procedure verified

## Notes

Use this space to document any issues found or special configuration needed:

---

**Installation Date**: _______________
**Validated By**: _______________
**Claude Desktop Version**: _______________
**Bubblewrap Version**: _______________
**Issues Found**: _______________
**Status**: [ ] PASS [ ] FAIL [ ] PARTIAL
