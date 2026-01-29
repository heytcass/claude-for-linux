# Test Instructions - Process Guard Verification

**Status**: Patch installed ✅, ready to test
**Date**: 2026-01-29

---

## Installation Status ✅

Confirmed:
- ✅ Backup created: `/opt/claude-desktop/app.asar.backup-guard-test-1769729006`
- ✅ Patched version installed: `/opt/claude-desktop/app.asar` (23MB)
- ✅ Ready to test

---

## How to Test

### Launch Claude Desktop

**Important**: You need to launch the **desktop app**, not the CLI tool.

```bash
# Launch Claude Desktop (GUI application)
/opt/claude-desktop/claude-desktop 2>&1 | tee /tmp/cowork-guard-test.log
```

Or if there's a desktop launcher:
```bash
claude-desktop 2>&1 | tee /tmp/cowork-guard-test.log
```

### What to Look For

**In the console output, you should see:**
```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = browser
[CoworkGuardTest] process.platform = linux
[CoworkGuardTest] MAIN PROCESS - Would load Cowork here
[CoworkGuardTest] This should only appear in main process!

[CoworkGuardTest] START
[CoworkGuardTest] process.type = renderer
[CoworkGuardTest] process.platform = linux
[CoworkGuardTest] RENDERER - Exiting safely
```

**Visually, you should see:**
- ✅ Claude Desktop window appears
- ✅ UI loads normally
- ✅ App is responsive
- ✅ No error dialogs

### Verify No Zombies

In another terminal:
```bash
ps aux | grep electron
```

**Should see:**
- Main process (normal)
- Renderer process(es) (normal)
- NO `<defunct>` processes

---

## Success Criteria

### ✅ TEST PASSES if:

1. **Console shows both messages**:
   - `[CoworkGuardTest] MAIN PROCESS` from main
   - `[CoworkGuardTest] RENDERER - Exiting safely` from renderer

2. **Window appears normally**

3. **No zombie processes**

4. **App works fine**

**This means**: The guard works! Renderer exits safely, main continues.

### ❌ TEST FAILS if:

1. **Window doesn't appear** → Likely crash

2. **Zombie `<defunct>` processes** → Renderer crashed

3. **Only see MAIN PROCESS message** → Renderer may have crashed before logging

4. **Only see RENDERER message** → Guard may be backwards

5. **See neither message** → Patch didn't apply or file syntax error

---

## After Testing

### If Test Passes ✅

Come back and report:
```
"Test passed! Window appeared, saw both messages, no zombies."
```

Then we'll:
1. Document success
2. Create v3 patch with REAL Cowork loading (with guard!)
3. Move to Iteration 4

### If Test Fails ❌

Come back and report:
```
"Test failed. Here's what I saw: [describe]"
```

And share:
- Console output from `/tmp/cowork-guard-test.log`
- Process list output
- What happened visually

Then we'll debug and fix.

---

## Restore Original

If you need to restore:

```bash
# Restore backup
sudo cp /opt/claude-desktop/app.asar.backup-guard-test-1769729006 \
        /opt/claude-desktop/app.asar

# Or restore pre-cowork version
sudo cp /opt/claude-desktop/app.asar.pre-cowork \
        /opt/claude-desktop/app.asar
```

---

## Current Iteration

We're in **Iteration 3 of 5**:

- Iteration 1: ❌ Built Cowork, crashed
- Iteration 2: ✅ Found root cause, designed fix
- Iteration 3: ⏳ **Testing the fix** ← YOU ARE HERE
- Iteration 4: ⏳ Load real Cowork module
- Iteration 5: ⏳ End-to-end testing

---

**Ready to test!**

Launch Claude Desktop and let me know what you see.
