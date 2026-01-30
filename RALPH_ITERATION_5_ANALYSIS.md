# Ralph Loop Iteration 5 - Analysis

**Task**: UI Integration - Make Cowork slider appear
**Iteration**: 5/5
**Status**: ⏳ IN PROGRESS - Analyzing UI integration
**Date**: 2026-01-29

---

## Current Status

### What Works ✅

- ✅ Process guard prevents crashes
- ✅ Cowork module loads successfully
- ✅ CoworkSessionManager instantiated
- ✅ VMCompatibilityAdapter available
- ✅ Bubblewrap detected (v0.11.0)
- ✅ `global.__linuxCowork` created

### What Doesn't Work ❌

- ❌ Cowork slider not showing in UI
- ❌ Can't select directories
- ❌ Tool not available to user

---

## The Problem

**Backend is ready, but UI doesn't know about it.**

The Cowork UI slider likely has a platform check:
```javascript
// Probably somewhere in the UI code:
if (process.platform === 'darwin') {
  // Show Cowork slider
}
```

**Our Linux implementation isn't hooked in**, so the UI doesn't show the option.

---

## What We've Learned

### From Iteration 2

Found in index.js:
- Tool name: `"request_cowork_directory"`
- Infrastructure exists from macOS version
- UI already knows how to request directories

### From Iteration 4

Successfully loaded:
- CoworkSessionManager (backend)
- VMCompatibilityAdapter (shim)
- Bubblewrap detection (isolation)

### The Gap

**Missing link**: UI → Backend connection

The UI needs to:
1. Know that Cowork is available on Linux
2. Show the slider/button
3. Call the backend when user selects a directory

---

## Possible Solutions

### Option A: Patch Platform Check

Find and modify the UI platform check:

```javascript
// Original (macOS only)
if (process.platform === 'darwin') {
  showCoworkSlider();
}

// Patched (include Linux)
if (process.platform === 'darwin' ||
    (process.platform === 'linux' && global.__linuxCowork)) {
  showCoworkSlider();
}
```

**Pros:**
- ✅ Direct fix
- ✅ UI shows slider

**Cons:**
- ❌ Need to find exact location in minified code
- ❌ May be multiple checks
- ❌ Fragile (minification changes)

### Option B: Hook VM Module

Replace or wrap the VM module to make Linux look like macOS:

```javascript
// In our patch
const originalVI = vi;  // macOS VM function
vi = function() {
  if (process.platform === 'linux' && global.__linuxCowork) {
    return global.__linuxCowork.adapter;
  }
  return originalVI();
};
```

**Pros:**
- ✅ No UI changes needed
- ✅ Reuses existing code paths

**Cons:**
- ❌ `vi` is minified variable name (unstable)
- ❌ Hard to find in minified code

### Option C: Feature Flag / Environment Variable

Set a flag that enables Cowork on Linux:

```javascript
// In our patch
process.env.COWORK_LINUX_ENABLED = 'true';
// OR
global.COWORK_PLATFORM_OVERRIDE = 'darwin';
```

**Pros:**
- ✅ Simple toggle
- ✅ Easy to test

**Cons:**
- ❌ May not work if UI checks platform directly
- ❌ Hacky

### Option D: IPC Handler Override

Register our own IPC handler for the Cowork tool:

```javascript
// In our patch
const {ipcMain} = require('electron');

ipcMain.handle('cowork:requestDirectory', async () => {
  const {dialog} = require('electron');
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory']
  });

  if (!result.canceled && result.filePaths[0]) {
    const sessionId = require('crypto').randomUUID();
    global.__linuxCowork.manager.addMount(sessionId, result.filePaths[0]);
    return {sessionId, path: result.filePaths[0]};
  }

  return null;
});
```

**Pros:**
- ✅ Direct control
- ✅ Works regardless of UI checks

**Cons:**
- ❌ Don't know exact IPC channel name
- ❌ May conflict with existing handler

---

## Investigation Needed

### 1. Find Platform Checks

Search for where UI checks platform for Cowork:
- Look for `darwin` + `cowork`
- Look for `process.platform`
- Check for feature flags

### 2. Find IPC Channels

Identify exact IPC channel names:
- `cowork:requestDirectory`?
- `request_cowork_directory`?
- `vm:createSession`?

### 3. Understand Tool Registration

How is `request_cowork_directory` registered?
- Where in the code?
- What does it call?
- How to hook it?

---

## Recommended Approach

### Phase 1: Debug Logging

Add logging to see what's being called:

```javascript
// In our v3 patch, add:
console.log('[Cowork Debug] Checking if tool system sees us...');
console.log('[Cowork Debug] global.__linuxCowork:', !!global.__linuxCowork);
console.log('[Cowork Debug] Platform:', process.platform);
```

### Phase 2: Try IPC Handler

Add a test IPC handler:

```javascript
const {ipcMain} = require('electron');

ipcMain.handle('test:cowork:ping', async () => {
  console.log('[Cowork Test] Ping received!');
  return {success: true, platform: 'linux'};
});
```

Then test from renderer (DevTools console):
```javascript
await window.electronAPI.invoke('test:cowork:ping');
```

### Phase 3: Find and Patch UI Check

Once we know it works, find the platform check and patch it.

---

## Next Steps

1. **Add debug logging** to v3 patch
2. **Test IPC communication** main ↔ renderer
3. **Find platform check** in minified code
4. **Patch UI** to show Cowork on Linux
5. **Test directory selection** end-to-end

---

## Files to Investigate

- `/tmp/app-extracted/.vite/build/index.js` - Main app (has platform checks)
- `/tmp/app-extracted/.vite/build/mainWindow.js` - Main window (UI code?)
- Console DevTools - Check for feature flags

---

## Questions to Answer

- [ ] What is the exact IPC channel name?
- [ ] Where is the platform check for Cowork UI?
- [ ] Can we override `process.platform` temporarily?
- [ ] Is there a feature flag we can set?
- [ ] What does `request_cowork_directory` actually do?

---

## Timeline

| Phase | Goal | Status |
|-------|------|--------|
| 1 | Debug logging | ⏳ Next |
| 2 | IPC testing | ⏳ Pending |
| 3 | Find UI check | ⏳ Pending |
| 4 | Patch UI | ⏳ Pending |
| 5 | E2E test | ⏳ Pending |

---

## Current Blockers

1. **Don't know exact UI check location** - Minified code is hard to search
2. **Don't know IPC channel names** - Need to find in code or test
3. **May need renderer code** - UI might be in separate bundle

---

## Success Criteria for Iteration 5

- [ ] Cowork slider appears in UI
- [ ] Can click to enable Cowork
- [ ] Can select a directory
- [ ] Directory gets mounted
- [ ] Files are accessible in sandbox
- [ ] Full workflow works end-to-end

---

**Status**: Analysis complete, ready to implement debugging
**Next**: Add IPC handler and debug logging to v3 patch
