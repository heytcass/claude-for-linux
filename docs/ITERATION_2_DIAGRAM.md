# Iteration 2: Visual Problem & Solution

## The Problem: Why Iteration 1 Crashed

```
┌──────────────────────────────────────────────────────────────┐
│                    Claude Desktop Launch                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            ├─────────────────────┬────────────────────┐
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ Main Process  │     │ Renderer #1   │   │ Renderer #2   │
                    │ type=browser  │     │ type=renderer │   │ type=renderer │
                    └───────┬───────┘     └───────┬───────┘   └───────┬───────┘
                            │                     │                    │
                            │ Loads index.js      │ Loads index.js     │ Loads index.js
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ Appended Code │     │ Appended Code │   │ Appended Code │
                    │ Executes      │     │ Executes      │   │ Executes      │
                    └───────┬───────┘     └───────┬───────┘   └───────┬───────┘
                            │                     │                    │
                            │ require("module")   │ require("module")  │ require("module")
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │   ✅ SUCCESS   │     │   ❌ ERROR     │   │   ❌ ERROR     │
                    │ Module loaded │     │ Cannot find   │   │ Cannot find   │
                    │               │     │ module!       │   │ module!       │
                    └───────────────┘     └───────┬───────┘   └───────┬───────┘
                                                  │                    │
                                                  ▼                    ▼
                                          ┌───────────────┐   ┌───────────────┐
                                          │  💀 CRASH      │   │  💀 CRASH      │
                                          │  <defunct>    │   │  <defunct>    │
                                          └───────────────┘   └───────────────┘
                                                  │
                                                  ▼
                                          ┌───────────────────────┐
                                          │ No Window Appears     │
                                          │ App Seems Frozen      │
                                          └───────────────────────┘
```

## The Solution: Process Type Guard

```
┌──────────────────────────────────────────────────────────────┐
│                    Claude Desktop Launch                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            ├─────────────────────┬────────────────────┐
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ Main Process  │     │ Renderer #1   │   │ Renderer #2   │
                    │ type=browser  │     │ type=renderer │   │ type=renderer │
                    └───────┬───────┘     └───────┬───────┘   └───────┬───────┘
                            │                     │                    │
                            │ Loads index.js      │ Loads index.js     │ Loads index.js
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ Appended Code │     │ Appended Code │   │ Appended Code │
                    │ WITH GUARD    │     │ WITH GUARD    │   │ WITH GUARD    │
                    └───────┬───────┘     └───────┬───────┘   └───────┬───────┘
                            │                     │                    │
                            │ Check type          │ Check type         │ Check type
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ type=browser? │     │ type=browser? │   │ type=browser? │
                    │ ✅ YES        │     │ ❌ NO         │   │ ❌ NO         │
                    └───────┬───────┘     └───────┬───────┘   └───────┬───────┘
                            │                     │                    │
                            │ Continue            │ RETURN (exit)      │ RETURN (exit)
                            ▼                     ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ Load platform? │     │ ✅ SAFE EXIT  │   │ ✅ SAFE EXIT  │
                    │ ✅ Linux      │     │ No crash!     │   │ No crash!     │
                    └───────┬───────┘     │               │   │               │
                            │              └───────┬───────┘   └───────┬───────┘
                            │ Continue             │                    │
                            ▼                      ▼                    ▼
                    ┌───────────────┐     ┌───────────────┐   ┌───────────────┐
                    │ require()     │     │ UI Loads      │   │ UI Loads      │
                    │ ✅ SUCCESS    │     │ Normally      │   │ Normally      │
                    └───────┬───────┘     └───────────────┘   └───────────────┘
                            │                      │                    │
                            ▼                      │                    │
                    ┌───────────────┐              │                    │
                    │ Module loaded │              │                    │
                    │ global set    │              │                    │
                    └───────────────┘              │                    │
                                                   ▼                    ▼
                                          ┌────────────────────────────────┐
                                          │   ✅ Window Appears             │
                                          │   ✅ App Works                  │
                                          │   ✅ No Zombies                 │
                                          └────────────────────────────────┘
```

## Code Comparison

### Before (Iteration 1) - BROKEN ❌

```javascript
;(function(){
  // ❌ No guard - runs in ALL processes
  if(process.platform!=="linux") return;

  try{
    // ❌ This fails in renderer!
    const module = require("claude-cowork-linux");

    global.__linuxCowork = { ... };
  }catch(e){
    // ❌ Renderer crashes before catch
    console.error("[Cowork] Failed:", e);
  }
})();
```

**Result**: Renderer tries to execute, hits require(), crashes.

### After (Iteration 2) - FIXED ✅

```javascript
;(function(){
  // ✅ GUARD: Check process type FIRST
  if (process.type !== 'browser') {
    return;  // ✅ Renderer exits here safely
  }

  // ✅ Only main process reaches this point
  if(process.platform!=="linux") return;

  try{
    // ✅ Safe - only main process executes
    const module = require("claude-cowork-linux");

    global.__linuxCowork = { ... };
  }catch(e){
    console.error("[Cowork] Failed:", e);
  }
})();
```

**Result**: Renderer exits immediately, main process loads module successfully.

## The Guard in Detail

```
┌─────────────────────────────────────────┐
│  if (process.type !== 'browser') {      │
│    return;                              │
│  }                                      │
└─────────────────────────────────────────┘
         │
         ├─ In Main Process:
         │  process.type === 'browser'
         │  Check fails, continue ✅
         │
         └─ In Renderer Process:
            process.type === 'renderer'
            Check succeeds, return immediately ✅
            Never reaches require() ✅
```

## Process Type Reference

| Process | process.type | Can require()? | Runs Our Code? |
|---------|--------------|----------------|----------------|
| Main | `'browser'` | ✅ Yes | ✅ Yes (after guard) |
| Renderer | `'renderer'` | ❌ No | ❌ No (exits at guard) |
| Worker | `'worker'` | ⚠️ Maybe | ❌ No (exits at guard) |

## Electron Security Model

```
┌────────────────────────────────────────────┐
│         Modern Electron Security           │
├────────────────────────────────────────────┤
│                                            │
│  Main Process:                             │
│  ✅ nodeIntegration: true                  │
│  ✅ Full Node.js API                       │
│  ✅ Can require() modules                  │
│  ✅ File system access                     │
│  ✅ Child process spawning                 │
│                                            │
│  Renderer Process:                         │
│  ❌ nodeIntegration: false (default)       │
│  ❌ contextIsolation: true (default)       │
│  ❌ No require() access                    │
│  ❌ Limited Node APIs                      │
│  ✅ Can use IPC to talk to main            │
│                                            │
└────────────────────────────────────────────┘
```

## Why This Matters

### Security

Modern Electron disables Node.js in renderer for security:
- Prevents XSS from accessing file system
- Isolates untrusted content
- Requires explicit IPC for privileged operations

### Architecture

Renderer is for UI, main is for logic:
- Renderer: Display, user interaction
- Main: File I/O, child processes, system access

### Our Cowork

Cowork needs:
- ✅ File system (main process only)
- ✅ Child processes for bubblewrap (main process only)
- ✅ Module loading (main process only)

Therefore: **Cowork must run in main process only!**

## Timeline

```
Iteration 1:
  ├─ Built Cowork module ✅
  ├─ Created patcher ✅
  ├─ Documented ✅
  └─ NO PROCESS GUARD ❌
     └─> Renderer crashes

Iteration 2:
  ├─ Analyzed crash ✅
  ├─ Found root cause ✅
  ├─ Designed fix (process.type guard) ✅
  ├─ Created test patch ✅
  └─ Documented ✅
     └─> Ready to test

Iteration 3:
  ├─ Test guard ⏳
  ├─ Verify no crashes ⏳
  └─ Load Cowork module ⏳
```

## Expected Test Results

### Console Output (Main Process)

```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = browser
[CoworkGuardTest] MAIN PROCESS - Would load Cowork here
```

### Console Output (Renderer Process)

```
[CoworkGuardTest] START
[CoworkGuardTest] process.type = renderer
[CoworkGuardTest] RENDERER - Exiting safely
```

### System State

```bash
$ ps aux | grep electron

tom  12345  Main process       ✅ Running
tom  12346  Renderer process   ✅ Running (not defunct!)
tom  12347  Renderer process   ✅ Running (not defunct!)
```

### Application Behavior

```
✅ Window appears
✅ UI is responsive
✅ No error messages
✅ No frozen state
```

## Key Takeaway

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  One line prevents renderer crashes:            │
│                                                 │
│    if (process.type !== 'browser') return;      │
│                                                 │
│  Everything else from Iteration 1 was correct!  │
│                                                 │
└─────────────────────────────────────────────────┘
```
