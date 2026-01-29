# Ralph Loop Iteration 2 - Analysis

**Task**: Review previous attempts to enable cowork and troubleshoot
**Iteration**: 2/5
**Date**: 2026-01-29

---

## Problem Summary

The Cowork implementation from Iteration 1 **crashes renderer processes** due to fundamental misunderstanding of Electron's process model.

### What Iteration 1 Did Wrong

1. **Appended patches to minified code** - The patches reference variables like `vi`, `oe` that only exist in certain scopes
2. **Executed patches in ALL processes** - Both main AND renderer processes try to run the patches
3. **Renderer can't resolve modules** - `require("claude-cowork-linux")` fails in renderer (no node integration)
4. **Assumed shared scope** - Variables defined in main process aren't accessible in renderer

### The Crash Sequence

```
1. Claude Desktop launches → main process starts ✅
2. index.js loads → patches execute in main ✅
3. global.__linuxCowork created in main ✅
4. Log message appears: "[Cowork] Linux Cowork enabled" ✅
5. Renderer process spawns → tries to load index.js ❌
6. Patches execute again in renderer context ❌
7. require("claude-cowork-linux") FAILS (no module resolution) ❌
8. Patches reference undefined variables (vi, oe) ❌
9. Renderer crashes → becomes <defunct> zombie ❌
10. Window never appears ❌
```

---

## Root Cause Analysis

### Issue 1: Wrong Process Architecture

**Electron has TWO separate JavaScript contexts:**

| Process | Purpose | Capabilities | Context |
|---------|---------|--------------|---------|
| **Main** | Backend logic | Full Node.js API, File I/O, IPC host | Runs once |
| **Renderer** | UI display | Limited/no Node.js, IPC client | Runs per window |

**Our patches assume a single shared context** - this is fundamentally wrong for Electron apps.

### Issue 2: Module Resolution

In main process:
```javascript
require("claude-cowork-linux")  // ✅ Works - full Node.js
```

In renderer process:
```javascript
require("claude-cowork-linux")  // ❌ FAILS - no module resolution
```

Modern Electron has `nodeIntegration: false` by default, so renderer can't use `require()`.

### Issue 3: Variable References

The patches do this:
```javascript
if (typeof vi !== "undefined") {
  orig.vi = vi;
  vi = function() { ... }
}
```

But `vi` is a minified variable name that:
- ✅ Might exist in main process scope
- ❌ Doesn't exist in renderer scope
- ❌ Changes between Claude Desktop versions
- ❌ Is unpredictable in minified code

### Issue 4: Dialog API Access

```javascript
const origDialog = oe.dialog.showOpenDialog;
```

`oe` is likely `electron` but:
- In main: `electron.dialog` exists ✅
- In renderer: `electron.dialog` is undefined (remote module disabled) ❌

---

## Why Appending Doesn't Work

Iteration 1's approach: Append patches to end of `index.js`

**Problems:**
1. **Executes in all processes** - No way to control which process runs the code
2. **No scope isolation** - Patches pollute global scope
3. **Fragile references** - Depends on minified variable names
4. **No process detection** - Can't distinguish main from renderer early enough

**What we need:** Patches that **ONLY run in main process** and use **IPC** to communicate with renderer.

---

## The Right Architecture

### How Claude Desktop (macOS) Works

Looking at the status doc, the macOS version likely:

1. **Main process**: Manages VM lifecycle, handles file operations
2. **IPC channels**: Renderer requests cowork via IPC
3. **VM abstraction**: Presents consistent API to renderer
4. **Dialog handling**: Main process owns showOpenDialog

### How Linux Version Should Work

```
┌─────────────────────────────────────────────┐
│              Main Process                    │
│                                              │
│  ┌──────────────────────────────┐           │
│  │ CoworkSessionManager         │           │
│  │  - createSession()           │           │
│  │  - addMount()                │           │
│  │  - spawnProcess()            │           │
│  └──────────────────────────────┘           │
│                                              │
│  IPC Handlers:                               │
│  - cowork:requestDirectory                   │
│  - cowork:createSession                      │
│  - cowork:spawnProcess                       │
│                                              │
└─────────────────┬────────────────────────────┘
                  │
            IPC Channel
                  │
┌─────────────────▼────────────────────────────┐
│           Renderer Process                   │
│                                              │
│  No Cowork code needed!                      │
│  Just uses existing IPC calls                │
│                                              │
└──────────────────────────────────────────────┘
```

---

## Investigation Required

Before we can fix this, we need to:

### 1. Find Existing IPC Patterns ✅ NEXT
- Search for `ipcMain.handle` in index.js
- Identify how macOS Cowork communicates
- Find the `request_cowork_directory` tool registration

### 2. Understand Tool Architecture
- Where are MCP tools registered?
- How does the tool system work?
- Can we hook into existing patterns?

### 3. Identify Injection Points
- Where can we safely add main-process-only code?
- Can we wrap existing IPC handlers?
- Do we need preload scripts?

---

## Proposed Solutions (Revised)

### Option A: IPC Handler Injection (RECOMMENDED)

**Strategy**: Add IPC handlers in main process only, leave renderer untouched

**Method**:
1. Detect if we're in main process: `if (process.type === 'browser')`
2. Add IPC handlers for cowork operations
3. Renderer already knows how to call these (from macOS version)
4. No renderer code changes needed!

**Pros**:
- ✅ Minimal changes
- ✅ No renderer crashes
- ✅ Follows Electron best practices
- ✅ Compatible with existing code

**Cons**:
- ❓ Need to find exact IPC channel names
- ❓ May need to understand tool registration

### Option B: Preload Script

**Strategy**: Create a bridge using Electron's preload mechanism

**Method**:
1. Create `cowork-preload.js`
2. Expose safe APIs via `contextBridge`
3. Main process handles implementation
4. Modify BrowserWindow to use preload

**Pros**:
- ✅ Clean separation
- ✅ Secure by design
- ✅ Standard Electron pattern

**Cons**:
- ❌ Requires modifying BrowserWindow creation
- ❌ More invasive changes
- ❌ Harder to patch at runtime

### Option C: Main-Process-Only Module

**Strategy**: Load Cowork module ONLY in main process

**Method**:
```javascript
// At start of index.js, add:
if (process.type === 'browser') {
  // Main process only
  require('claude-cowork-linux-main');
}
```

**Pros**:
- ✅ Simple guard prevents renderer execution
- ✅ All logic in one module
- ✅ Easy to test

**Cons**:
- ❓ Injection point must be at file start
- ❓ May interfere with minification

---

## Next Steps

1. **Extract and analyze IPC patterns** from index.js
2. **Find cowork-related IPC channels** (if they exist)
3. **Design minimal IPC injection**
4. **Implement Option A** (IPC handler approach)
5. **Test in isolated environment**
6. **Verify no renderer crashes**

---

## Success Criteria (Updated)

- [ ] Understand macOS cowork IPC architecture
- [ ] Identify safe injection points in main process
- [ ] Implement main-process-only patches
- [ ] Verify renderer processes don't crash
- [ ] Test cowork functionality works
- [ ] No zombie processes
- [ ] Window appears correctly

---

## Files to Create/Modify

### New Files
- `scripts/analyze-ipc.js` - Extract IPC patterns
- `modules/claude-cowork-linux-main.js` - Main-process-only version
- `scripts/patch-cowork-linux-v3.js` - Fixed patcher

### Modified Files
- `COWORK_STATUS.md` - Update with new understanding
- Test scripts as needed

---

## Lessons Learned

1. **Electron ≠ Node.js** - Different process model
2. **Renderer has no Node** - Can't use require() by default
3. **Minified variables are unstable** - Never reference them
4. **Appending to end of file** - Runs in ALL processes
5. **IPC is the bridge** - Proper way to communicate

This explains why Iteration 1 looked good but failed at runtime.

---

**Status**: Analysis complete, ready to investigate IPC patterns
