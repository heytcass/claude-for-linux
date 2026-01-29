# 🔔 User Action Required - Iteration 3

**Status**: Test patch ready and waiting for installation
**Date**: 2026-01-29

---

## What's Ready

I've completed Iteration 3 preparation:

✅ Extracted Claude Desktop app
✅ Applied process guard test patch
✅ Repacked into new app.asar
✅ Everything ready to install

**The patch is minimal and safe** - just logging to verify the guard works.

---

## What You Need to Do

### Step 1: Install the Test Patch

Run these commands to install the patched version:

```bash
# Backup original
sudo cp /opt/claude-desktop/app.asar \
        /opt/claude-desktop/app.asar.backup-guard-test-$(date +%s)

# Install test version
sudo cp /tmp/app-test-patched.asar /opt/claude-desktop/app.asar
```

### Step 2: Test Claude Desktop

Launch and capture console output:

```bash
claude-desktop 2>&1 | tee /tmp/cowork-guard-test.log
```

### Step 3: Check Results

**You should see:**
```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = browser
[CoworkGuardTest] MAIN PROCESS - Would load Cowork here

[CoworkGuardTest] START
[CoworkGuardTest] process.type = renderer
[CoworkGuardTest] RENDERER - Exiting safely
```

**And:**
- ✅ Window appears normally
- ✅ No crashes
- ✅ No `<defunct>` zombie processes
- ✅ App works fine

**Check for zombies:**
```bash
ps aux | grep -E "electron|<defunct>"
```

### Step 4: Report Back

Let me know:
1. Did the window appear?
2. What did the console output show?
3. Were there any zombies or crashes?
4. Does the app work normally?

---

## What This Tests

This verifies that our **one-line fix** works:

```javascript
if (process.type !== 'browser') return;
```

**If successful:**
- Proves renderer doesn't crash
- Validates our solution
- Ready to load actual Cowork module
- Move to Iteration 4

**If it fails:**
- We'll debug together
- Revise the approach
- Try alternative guards

---

## Restoration

If anything goes wrong, restore the original:

```bash
# List backups
ls -lh /opt/claude-desktop/app.asar.backup-*

# Restore most recent backup
sudo cp /opt/claude-desktop/app.asar.backup-guard-test-* \
        /opt/claude-desktop/app.asar
```

---

## Files Reference

**Test patch**: `/tmp/app-test-patched.asar` (ready to install)
**Log output**: `/tmp/cowork-guard-test.log` (will be created)
**Progress doc**: `RALPH_ITERATION_3_PROGRESS.md` (this iteration)

---

## Why This Matters

This is the **critical test** that proves Iteration 2's analysis was correct.

If the guard works:
- ✅ We understand the problem
- ✅ We have the solution
- ✅ We can safely proceed

Then we just need to:
1. Load the actual Cowork module (with guard!)
2. Implement VM stub
3. Test end-to-end
4. Done!

---

**Ready when you are!**

Run the install commands above and let me know what happens.
