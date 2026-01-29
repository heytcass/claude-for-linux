# Ralph Loop Iteration 3 - In Progress

**Task**: Test the process guard to verify it prevents renderer crashes
**Iteration**: 3/5
**Status**: ⏳ IN PROGRESS - Patch ready, awaiting installation
**Date**: 2026-01-29

---

## Objective

Test that the `process.type !== 'browser'` guard prevents renderer crashes.

---

## Progress So Far ✅

### 1. Repository Recovered ✅
- Fixed git corruption from interrupted commits
- Re-initialized repository with all Iteration 2 work
- All documentation and code preserved

### 2. App Extracted ✅
- Used Python asar_tool.py to extract /opt/claude-desktop/app.asar
- Extracted to /tmp/app-extracted
- Verified index.js exists at /tmp/app-extracted/.vite/build/index.js

### 3. Test Patch Applied ✅
- Ran `scripts/test-process-guard.js`
- Applied minimal guard test to index.js
- Created backup at index.js.guard-test-backup
- Patch adds ~460 bytes of test code

### 4. App Repacked ✅
- Used Python asar_tool.py to pack patched app
- Created /tmp/app-test-patched.asar
- Size: 23,456,439 bytes (~23.4 MB)
- Ready to install

---

## Next Steps ⏳

### 5. Install Patched App (NEEDS USER)
**Requires sudo authentication:**

```bash
# Backup original
sudo cp /opt/claude-desktop/app.asar \
        /opt/claude-desktop/app.asar.backup-guard-test-$(date +%s)

# Install test version
sudo cp /tmp/app-test-patched.asar /opt/claude-desktop/app.asar
```

### 6. Test Claude Desktop
```bash
# Launch and observe console
claude-desktop 2>&1 | tee /tmp/cowork-guard-test.log
```

### 7. Verify Results

**Expected console output:**
```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = browser
[CoworkGuardTest] MAIN PROCESS - Would load Cowork here

[CoworkGuardTest] START
[CoworkGuardTest] process.type = renderer
[CoworkGuardTest] RENDERER - Exiting safely
```

**Expected system state:**
- [ ] Window appears normally
- [ ] No `<defunct>` zombie processes
- [ ] App is responsive
- [ ] No crashes in console

**Verification commands:**
```bash
# Check for zombies
ps aux | grep -E "electron|<defunct>"

# Check log
grep "CoworkGuardTest" /tmp/cowork-guard-test.log
```

---

## The Test Patch

Located at `/tmp/app-extracted/.vite/build/index.js` (end of file):

```javascript
;(function(){
  console.log('[CoworkGuardTest] START');
  console.log('[CoworkGuardTest] process.type =', process.type);
  console.log('[CoworkGuardTest] process.platform =', process.platform);

  if (process.type !== 'browser') {
    console.log('[CoworkGuardTest] RENDERER - Exiting safely');
    return;
  }

  console.log('[CoworkGuardTest] MAIN PROCESS - Would load Cowork here');
  console.log('[CoworkGuardTest] This should only appear in main process!');
})();
```

**What it does:**
1. Logs process type in both main and renderer
2. Guards with `if (process.type !== 'browser')`
3. Renderer exits at guard, logs "RENDERER"
4. Main continues past guard, logs "MAIN PROCESS"
5. No module loading, no crashes

---

## Files Ready

| File | Location | Status |
|------|----------|--------|
| Original app.asar | /opt/claude-desktop/app.asar | ✅ Ready to backup |
| Extracted app | /tmp/app-extracted | ✅ Extracted |
| Patched index.js | /tmp/app-extracted/.vite/build/index.js | ✅ Patched |
| Test app.asar | /tmp/app-test-patched.asar | ✅ Ready to install |
| Backup (to create) | /opt/claude-desktop/app.asar.backup-* | ⏳ Needs sudo |

---

## Success Criteria

### If Test SUCCEEDS ✅

Means the guard works! Then:
1. Document results in RALPH_ITERATION_3_COMPLETE.md
2. Create patch-cowork-linux-v3.js with real module loading
3. Apply v3 patch (with guard!) to load actual Cowork
4. Move to Iteration 4: Implement VM stub

### If Test FAILS ❌

Debug:
1. Check which logs appear (main? renderer? both?)
2. Verify process.type value in each process
3. Look for any errors before/after guard
4. Check if guard syntax is correct
5. Revise guard logic if needed

---

## Restoration

If anything goes wrong:

```bash
# Restore original app
sudo cp /opt/claude-desktop/app.asar.backup-guard-test-* \
        /opt/claude-desktop/app.asar

# Or restore from unpatched backup
sudo cp /opt/claude-desktop/app.asar.backup-* \
        /opt/claude-desktop/app.asar
```

---

## Tools Used

**Extraction:**
- `tools/asar_tool.py extract` - Python ASAR extractor

**Patching:**
- `scripts/test-process-guard.js` - Minimal test patcher

**Packing:**
- `tools/asar_tool.py pack` - Python ASAR packer

**Testing:**
- Manual launch and observation

---

## Current State

**Completed:**
- ✅ Git repository recovered
- ✅ App extracted
- ✅ Patch applied
- ✅ App repacked
- ✅ Ready to install

**Waiting for:**
- ⏳ User to provide sudo authentication
- ⏳ Installation and testing

**Next action:**
User needs to run the install commands, then launch Claude Desktop.

---

## Confidence

**HIGH** - The patch is:
- Minimal (just logging and guard)
- Safe (no module loading)
- Testable (clear expected output)
- Reversible (backups created)

If this works, we've proven the fix and can proceed with confidence to load the actual Cowork module.

---

**Status**: Patch ready, awaiting user to install and test
**Iteration**: 3 of 5
**Progress**: 80% (extraction and patching done, testing pending)
