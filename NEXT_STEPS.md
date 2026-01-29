# Next Steps - Cowork Implementation

**Current Status**: ROOT CAUSE IDENTIFIED, FIX DESIGNED
**Last Updated**: 2026-01-29 (Iteration 2 complete)

---

## Quick Summary

**Problem**: Iteration 1 patches ran in renderer, causing crashes
**Solution**: Add `if (process.type !== 'browser') return;` guard
**Status**: Fix designed, ready to test

---

## Immediate Action: Test the Guard

### 1. Apply Test Patch

```bash
cd /home/tom/projects/claude-for-linux

# Make sure we have clean extraction
sudo cp /opt/claude-desktop/app.asar.pre-cowork /tmp/test.asar 2>/dev/null || \
  sudo cp /opt/claude-desktop/app.asar /tmp/test.asar

# Extract
cd /tmp
rm -rf app-extracted
python3 -m asar extract test.asar app-extracted

# Apply test patch
node /home/tom/projects/claude-for-linux/scripts/test-process-guard.js /tmp/app-extracted

# Repack
python3 -m asar pack app-extracted test-patched.asar

# Install (backup first!)
sudo cp /opt/claude-desktop/app.asar /opt/claude-desktop/app.asar.backup-$(date +%s)
sudo cp test-patched.asar /opt/claude-desktop/app.asar
```

### 2. Test Claude Desktop

```bash
# Launch and watch console
claude-desktop 2>&1 | tee /tmp/cowork-guard-test.log

# In another terminal, check for zombies
ps aux | grep -E "electron|<defunct>"
```

### 3. Expected Output

**Should see in log**:
```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = browser
[CoworkGuardTest] MAIN PROCESS - Would load Cowork here
[CoworkGuardTest] process.type = renderer
[CoworkGuardTest] RENDERER - Exiting safely
```

**Should NOT see**:
- `<defunct>` processes
- Crashes
- Module resolution errors
- Frozen window

### 4. Success Criteria

- [ ] Claude Desktop window appears
- [ ] No zombie (`<defunct>`) processes
- [ ] Console shows both process types logging
- [ ] Main process logs "MAIN PROCESS" message
- [ ] Renderer logs "RENDERER" message then exits
- [ ] Application works normally

---

## If Test Succeeds → Iteration 3

### Create Real Patch v3

Replace test patch with actual module loading:

```javascript
;(function(){
  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;

  try {
    const {CoworkSessionManager, VMCompatibilityAdapter} =
      require('claude-cowork-linux');

    global.__linuxCowork = {
      manager: new CoworkSessionManager(),
      adapter: VMCompatibilityAdapter,
      version: '1.0.0-linux'
    };

    console.log('[Cowork] Linux Cowork enabled via bubblewrap');
    console.log('[Cowork] Manager:', typeof global.__linuxCowork.manager);

  } catch(e) {
    console.error('[Cowork] Failed to load Linux Cowork:', e);
  }
})();
```

### Test Module Loading

1. Apply patch v3
2. Check that module loads
3. Verify no errors
4. Confirm `global.__linuxCowork` exists

---

## If Test Fails → Debug

### Check These

1. **Did guard execute?**
   - Look for `[CoworkGuardTest]` messages
   - If missing, patch didn't apply

2. **Did renderer still crash?**
   - Check for `<defunct>` processes
   - Look for stack traces in log

3. **Wrong process type?**
   - Verify what `process.type` actually is
   - May need different check

4. **Syntax error?**
   - Check that patch is valid JavaScript
   - Verify no broken strings

### Restore Working Version

```bash
sudo cp /opt/claude-desktop/app.asar.backup-* /opt/claude-desktop/app.asar
# Or use pre-cowork backup:
sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar
```

---

## File Reference

### Documentation (Read These)
- `COWORK_STATUS.md` - Current status and overview
- `RALPH_ITERATION_2_SUMMARY.md` - What we learned
- `RALPH_ITERATION_2_ANALYSIS.md` - Deep technical analysis
- `RALPH_ITERATION_2_FINDINGS.md` - Key discoveries

### Scripts
- `scripts/test-process-guard.js` - Minimal guard test
- `scripts/patch-cowork-linux-v2.js` - OLD (broken, don't use)
- `scripts/install-cowork-linux.sh` - OLD (broken, don't use)

### Implementation
- `modules/claude-cowork-linux.js` - Session manager (needs guard)

---

## The One-Line Fix

Everything from Iteration 1 can be salvaged by adding ONE LINE at the start:

```javascript
if (process.type !== 'browser') return;
```

This prevents renderer crashes while keeping all the Cowork logic intact.

---

## Timeline

- **Iteration 1**: Built Cowork, but crashes renderer ❌
- **Iteration 2**: Identified cause, designed fix ✅
- **Iteration 3**: Test guard, load module ⏳
- **Iteration 4**: Implement VM stub ⏳
- **Iteration 5**: End-to-end testing ⏳

---

## Questions to Answer

### For This Test

- [ ] Does the guard prevent renderer execution?
- [ ] Does main process still run our code?
- [ ] Are there any side effects?

### For Next Steps

- [ ] What is the exact VM API to implement?
- [ ] How is request_cowork_directory registered?
- [ ] Where do we hook into the tool system?

---

## Success Looks Like

```
$ claude-desktop
[Cowork] Linux Cowork enabled via bubblewrap
[Cowork] Manager: object
[Cowork] Adapter: function
[Main] Application ready

# In UI: "Work with files in /home/user/projects"
# → Directory picker appears
# → User selects directory
# → Directory is mounted via bubblewrap
# → Files are accessible to Claude
# → Sandbox isolation verified
```

---

**Next Action**: Run the test patch and verify the guard works!
