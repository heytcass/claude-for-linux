# Cowork Implementation Status

**Branch**: `feature/cowork-debug`
**Status**: 🟡 **ROOT CAUSE IDENTIFIED** - Fix designed, ready to test
**Last Updated**: 2026-01-29 (Iteration 2)
**Previous Status**: 🔴 BROKEN - Renderer crashes on launch

---

## Problem Summary

The Cowork implementation causes Claude Desktop renderer processes to crash during initialization:

- ✅ Main process loads successfully
- ✅ Cowork module loads: `[Cowork] Linux Cowork enabled via bubblewrap`
- ❌ Renderer processes crash (become `<defunct>` zombies)
- ❌ Application window never appears

## Root Cause (Iteration 2 Analysis)

**THE CORE ISSUE**: Patches execute in BOTH main and renderer processes

When code is appended to `index.js`, it runs in:
1. ✅ Main process (type='browser') - Has full Node.js
2. ❌ Renderer process (type='renderer') - No require(), crashes

### The Fatal Sequence

```
1. index.js loads in main → ✅ Patches work
2. index.js loads in renderer → ❌ require("claude-cowork-linux") FAILS
3. Renderer crashes → becomes <defunct> zombie
4. Window never appears → app looks frozen
```

### Why This Happens

**Iteration 1 patches had NO process type guard**:
```javascript
;(function(){
  // This runs in BOTH processes!
  const module = require("claude-cowork-linux");  // ❌ Crashes renderer
})();
```

**Modern Electron security** (in renderer):
- `nodeIntegration: false` - Can't use require()
- `contextIsolation: true` - No Node APIs
- `sandbox: true` - Restricted environment

### The Simple Fix

**Add ONE LINE**:
```javascript
;(function(){
  if (process.type !== 'browser') return;  // ✅ Renderer exits safely

  // Now safe - only main process reaches here
  const module = require("claude-cowork-linux");
})();
```

**Why this works**:
- Renderer checks type, exits immediately before require()
- Main process continues, loads module successfully
- No crashes, no zombies, window appears normally

## Current Approach (Broken)

**Method**: Runtime patching by appending JavaScript to `index.js`

**Files**:
- `scripts/patch-cowork-linux-v2.js` - Patcher script
- `modules/claude-cowork-linux.js` - Session manager
- `scripts/install-cowork-linux.sh` - Installer

**What happens**:
1. Patcher appends 4 IIFEs to end of minified index.js
2. Patches try to load `claude-cowork-linux` module
3. Main process loads successfully
4. Renderer process crashes with module resolution errors

## The Solution (Iteration 2)

### Approach: Guarded Main-Process-Only Patches

**Strategy**: Use process type guard to prevent renderer execution

```javascript
;(function(){
  // CRITICAL: Check process type FIRST
  if (process.type !== 'browser') {
    return;  // Renderer exits immediately, safely
  }

  // Platform check
  if (process.platform !== 'linux') {
    return;
  }

  // Now safe - only Linux main process reaches here
  try {
    const {CoworkSessionManager, VMCompatibilityAdapter} =
      require('claude-cowork-linux');

    global.__linuxCowork = {
      manager: new CoworkSessionManager(),
      adapter: VMCompatibilityAdapter
    };

    console.log('[Cowork] Linux Cowork enabled via bubblewrap');
  } catch(e) {
    console.error('[Cowork] Failed to load:', e);
  }
})();
```

**Why this is better than Iteration 1**:
- ✅ Renderer never tries to load module
- ✅ No crashes, no zombies
- ✅ No IPC changes needed
- ✅ Tool infrastructure already exists (`request_cowork_directory`)
- ✅ Minimal changes to existing code

## Investigation Needed

- [ ] Analyze how macOS Cowork communicates between processes
- [ ] Find where `request_cowork_directory` tool is registered
- [ ] Identify IPC channels used by Claude Desktop
- [ ] Determine if we can hook into existing IPC
- [ ] Test if preload scripts are allowed

## Files to Review

Main implementation:
- `/tmp/app-extracted/node_modules/claude-cowork-linux/` - Module location
- `/tmp/app-extracted/.vite/build/index.js` - Patched main file
- `/tmp/app-extracted/.vite/build/index.js.pre-cowork` - Backup

Original research:
- `docs/cowork-research.md` - Design decisions
- `docs/COWORK_SUMMARY.md` - Architecture
- `docs/RALPH_ITERATION_1_COMPLETE.md` - What was attempted

## Testing Commands

**Restore working version**:
```bash
sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar
claude-desktop  # Should work
```

**Test patched version**:
```bash
sudo cp /opt/claude-desktop/app.asar.pre-cowork /tmp/test.asar
# Apply patches...
sudo cp /tmp/test.asar /opt/claude-desktop/app.asar
claude-desktop 2>&1 | tee /tmp/cowork-test.log
```

**Check for zombies**:
```bash
ps aux | grep -E "[e]lectron|<defunct>"
```

## Next Steps (Iteration 2 → 3)

### Phase 1: Test the Guard ⏳
1. Run test patch: `scripts/test-process-guard.js`
2. Repack and install app.asar
3. Launch Claude Desktop
4. Verify:
   - [ ] Window appears (no crash!)
   - [ ] No `<defunct>` zombie processes
   - [ ] Console shows correct process types
   - [ ] Main process logs its messages
   - [ ] Renderer logs its messages (but exits safely)

### Phase 2: Load Actual Module (Next Iteration)
Once guard is verified working:
1. Modify guard test to actually load module
2. Verify CoworkSessionManager instantiates
3. Test that global.__linuxCowork is created
4. Check for any load errors

### Phase 3: Implement VM Stub
1. Create `modules/claude-cowork-linux/vm-stub.js`
2. Match macOS VM API
3. Implement using bubblewrap
4. Add heartbeat system

### Phase 4: End-to-End Testing
1. Test directory selection dialog
2. Verify mount happens
3. Test file operations
4. Confirm bubblewrap isolation

## Success Criteria

- [ ] Claude Desktop launches without crashes
- [ ] No zombie renderer processes
- [ ] `request_cowork_directory` tool works
- [ ] File picker dialog appears
- [ ] Selected directory is accessible
- [ ] Files can be read/written
- [ ] Sandbox isolation verified

## Key Discoveries (Iteration 2)

### Tool Already Exists
Found `"request_cowork_directory"` in index.js - this means:
- ✅ UI knows how to request cowork directories
- ✅ Infrastructure is already there
- ✅ We just need to provide Linux implementation
- ✅ No renderer changes needed!

### Process Type Detection
Electron uses:
- `process.type === 'browser'` for main process
- `process.type === 'renderer'` for UI windows

This is the standard way to guard main-process-only code.

### Why Iteration 1 Failed
Simple: **No process type check** → Code ran in renderer → require() failed → Crash

### The One-Line Fix
```javascript
if (process.type !== 'browser') return;
```

This single guard prevents all renderer crashes.

## Documentation (Iteration 2)

Created during troubleshooting:
- `RALPH_ITERATION_2_ANALYSIS.md` - Root cause analysis
- `RALPH_ITERATION_2_FINDINGS.md` - Technical discoveries
- `RALPH_ITERATION_2_SUMMARY.md` - Complete iteration summary
- `scripts/test-process-guard.js` - Minimal test patcher

## Notes

- Current working version: `main` branch (no Cowork)
- Broken implementation: `feature/cowork-debug` branch (Iteration 1)
- Fixed approach: Process type guard (Iteration 2)
- All files organized in git repo
- Ready for guard testing
