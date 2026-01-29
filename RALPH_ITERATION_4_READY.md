# Ralph Loop Iteration 4 - Ready to Start

**Task**: Load actual Cowork module with process guard
**Iteration**: 4/5
**Status**: ⏳ READY - Patch v3 created, awaiting application
**Date**: 2026-01-29

---

## Progress Summary

### Iterations Completed ✅

1. **Iteration 1** (Pre-existing): Built Cowork, crashed ❌
2. **Iteration 2**: Analyzed crashes, found root cause ✅
3. **Iteration 3**: Tested guard, proved fix works ✅

### Current: Iteration 4 ⏳

**Goal**: Load the REAL Cowork module (with guard!)

**Status**: Patch v3 created and ready to apply

---

## What's Different in V3

### Iteration 1 Patch (BROKEN) ❌

```javascript
;(function(){
  // ❌ NO GUARD - crashes renderer
  if(process.platform!=="linux") return;
  const module = require("claude-cowork-linux");
  global.__linuxCowork = { ... };
})();
```

### Iteration 3 Test (WORKS) ✅

```javascript
;(function(){
  if (process.type !== 'browser') return;  // ✅ Guard!
  // Just logging - no module loading
  console.log('[CoworkGuardTest] MAIN PROCESS');
})();
```

### V3 Patch (REAL COWORK + GUARD) 🎯

```javascript
;(function(){
  // ✅ GUARD FIRST
  if (process.type !== 'browser') return;

  if (process.platform !== 'linux') return;

  try {
    // ✅ Load REAL module
    const {CoworkSessionManager, VMCompatibilityAdapter} =
      require('claude-cowork-linux');

    // ✅ Initialize
    global.__linuxCowork = {
      manager: new CoworkSessionManager(),
      adapter: VMCompatibilityAdapter,
      version: '1.0.0-linux'
    };

    console.log('[Cowork] ✅ Linux Cowork enabled');
  } catch(e) {
    console.error('[Cowork] Failed:', e);
  }
})();
```

**Key improvements:**
- ✅ Process guard prevents renderer crashes
- ✅ Loads actual Cowork functionality
- ✅ Error handling with try/catch
- ✅ Detailed logging
- ✅ Bubblewrap availability check

---

## Files Ready

| File | Status | Purpose |
|------|--------|---------|
| scripts/patch-cowork-linux-v3.js | ✅ Created | Main patcher with guard |
| modules/claude-cowork-linux.js | ✅ Exists | Session manager implementation |
| tools/asar_tool.py | ✅ Exists | Pack/unpack tool |

---

## Next Steps

### Option A: Auto-Apply (Recommended)

Let me apply the patch and test it:

1. Extract app.asar
2. Apply v3 patch
3. Repack
4. Install
5. Test and report results

**Say**: "Apply v3 patch" and I'll do it all.

### Option B: Manual Application

You can apply it yourself:

```bash
# 1. Extract (if not already done)
cd /tmp
rm -rf app-extracted
python3 ~/projects/claude-for-linux/tools/asar_tool.py extract \
  /opt/claude-desktop/app.asar app-extracted

# 2. Apply v3 patch
node ~/projects/claude-for-linux/scripts/patch-cowork-linux-v3.js

# 3. Repack
python3 ~/projects/claude-for-linux/tools/asar_tool.py pack \
  app-extracted app-cowork-v3.asar

# 4. Backup and install
sudo cp /opt/claude-desktop/app.asar \
        /opt/claude-desktop/app.asar.backup-v3-$(date +%s)
sudo cp app-cowork-v3.asar /opt/claude-desktop/app.asar

# 5. Test
claude-desktop 2>&1 | tee /tmp/cowork-v3-test.log
```

---

## Expected Results

### Success Criteria ✅

**Console should show:**
```
[Cowork] Linux Cowork initialization starting...
[Cowork] ✅ Linux Cowork enabled via bubblewrap
[Cowork] Manager type: object
[Cowork] Adapter type: function
[Cowork] Version: 1.0.0-linux
[Cowork] Bubblewrap available: <version>
```

**And:**
- ✅ Window appears normally
- ✅ No crashes
- ✅ No zombie processes
- ✅ Module loads successfully
- ✅ `global.__linuxCowork` is created

### Potential Issues ⚠️

**If module fails to load:**
- Check that `claude-cowork-linux.js` was copied correctly
- Verify package.json was created
- Look for require() errors

**If bubblewrap not found:**
- Warning is expected if not installed
- Module still loads (just won't work until bwrap installed)
- Install with: `sudo apt install bubblewrap`

---

## Testing Plan

### Phase 1: Module Loading (This Iteration)
1. Apply v3 patch
2. Verify module loads
3. Check `global.__linuxCowork` exists
4. Confirm no crashes

### Phase 2: VM Stub (Next Iteration)
1. Implement VM API stub
2. Hook into tool registration
3. Test directory selection

### Phase 3: End-to-End (Final Iteration)
1. Test full workflow
2. Verify isolation
3. Confirm file operations work

---

## Restoration

If anything goes wrong:

```bash
# Restore from backup
sudo cp /opt/claude-desktop/app.asar.backup-v3-* \
        /opt/claude-desktop/app.asar

# Or restore test version
sudo cp /opt/claude-desktop/app.asar.backup-guard-test-* \
        /opt/claude-desktop/app.asar

# Or restore original
sudo cp /opt/claude-desktop/app.asar.pre-cowork \
        /opt/claude-desktop/app.asar
```

---

## Confidence Level

**HIGH** for module loading:
- ✅ Guard proven to work (Iteration 3)
- ✅ Module exists and is tested
- ✅ Error handling in place
- ✅ Safe to test

**MEDIUM** for full functionality:
- ❓ VM stub not yet implemented
- ❓ Tool registration unknown
- ❓ Directory selection untested
- ⏳ Will address in Iteration 5

---

## Comparison to Previous Attempts

| Aspect | Iteration 1 | Iteration 3 Test | V3 Patch |
|--------|-------------|------------------|----------|
| Guard | ❌ No | ✅ Yes | ✅ Yes |
| Module | ✅ Yes | ❌ No | ✅ Yes |
| Crashes | ❌ Yes | ✅ No | ✅ Expected: No |
| Functional | ❌ No | N/A | ⏳ Testing |

---

## What Could Go Wrong

### Low Risk ✅
- Module loading (error handled)
- Guard failing (proven to work)
- Window not appearing (guard prevents this)

### Medium Risk ⚠️
- Module has bugs (will see in console)
- CoworkSessionManager fails to initialize (logged)
- Bubblewrap not available (just a warning)

### Mitigation
- Try/catch around module loading
- Detailed error logging
- Easy rollback via backups

---

## Timeline

| Iteration | Goal | Status | Time |
|-----------|------|--------|------|
| 1 | Build Cowork | ❌ Failed | Pre-existing |
| 2 | Find cause | ✅ Done | 1 session |
| 3 | Test guard | ✅ Done | 1 session |
| 4 | Load module | ⏳ Ready | This session |
| 5 | E2E test | ⏳ Next | Next session |

---

## Ready to Proceed?

**Current state**:
- ✅ V3 patch created
- ✅ All files ready
- ✅ Restoration plan in place
- ✅ Success criteria defined

**Your options**:
1. **"Apply v3 patch"** - I'll do it automatically
2. **"I'll do it manually"** - Follow the commands above
3. **"Wait"** - Review the patch first

---

**Status**: Ready for your go-ahead to proceed with Iteration 4!
**Confidence**: HIGH - The guard works, now adding real functionality
