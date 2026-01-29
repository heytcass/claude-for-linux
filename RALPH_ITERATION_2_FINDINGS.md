# Ralph Loop Iteration 2 - Key Findings

**Date**: 2026-01-29
**Iteration**: 2/5

---

## Critical Discoveries

### 1. The Tool Exists! ✅

Found in index.js:
```
"request_cowork_directory"
```

This confirms that Claude Desktop ALREADY has the infrastructure for Cowork on Linux!

### 2. Process Type Detection ✅

The code uses:
```javascript
process.type === "renderer"
```

This is the correct way to detect which process we're in:
- `process.type === "browser"` → Main process
- `process.type === "renderer"` → Renderer process

### 3. VM Instance Function

Found references to `vi()` function which appears to be the VM instance getter. Context shows:
- VM heartbeat monitoring
- Process spawning
- Directory mounting
- Guest connection checks

### 4. Why Our Patches Failed

Our patches did this:
```javascript
;(function(){
  if(process.platform!=="linux") return;  // ✅ Good
  try{
    const {CoworkSessionManager:L,VMCompatibilityAdapter:V} =
      require("claude-cowork-linux");  // ❌ FAILS in renderer!
    // ...
  }catch(e){
    console.error("[Cowork] Failed to load:", e);
  }
})();
```

**Problem**: This IIFE runs in BOTH processes because it's appended to index.js which loads in both.

**What happens**:
1. Main process: ✅ Works, module loads
2. Renderer process: ❌ `require()` fails, crashes

---

## The Fix Strategy

### Phase 1: Guard Against Renderer

Wrap ALL our code in a process type check:

```javascript
;(function(){
  // CRITICAL: Only run in main process
  if (process.type !== 'browser') {
    return;  // Renderer exits immediately
  }

  // Now safe to use require() and Node APIs
  if (process.platform !== 'linux') {
    return;
  }

  try {
    const {CoworkSessionManager, VMCompatibilityAdapter} =
      require("claude-cowork-linux");

    global.__linuxCowork = {
      manager: new CoworkSessionManager(),
      adapter: VMCompatibilityAdapter
    };

    console.log("[Cowork] Linux Cowork enabled");
  } catch(e) {
    console.error("[Cowork] Failed:", e);
  }
})();
```

This simple change prevents renderer from trying to load the module!

### Phase 2: Hook VM Creation

The index.js has a `vi()` function that creates VM instances. We need to:

1. **Find the function** (it's minified as `vi` currently)
2. **Wrap it** to return our adapter instead
3. **Do this ONLY in main process**

**Challenge**: `vi` is a minified variable name that:
- Changes between versions
- May not be globally accessible
- Lives in a closure

**Solution**: Instead of patching `vi` directly, we should:
- Hook into the VM module loading
- Or replace the VM module itself
- Or hook the tool registration

### Phase 3: Understand macOS Implementation

From the grep output, we see the macOS version has:
- VM heartbeat monitoring
- Process spawning in VM
- Mount management
- Guest connectivity checks

**Key insight**: The tool `request_cowork_directory` exists, which means:
- ✅ UI already knows how to request directories
- ✅ Tool infrastructure exists
- ✅ We just need to provide the implementation

---

## Revised Implementation Plan

### Approach: Minimal VM Module Replacement

Instead of trying to patch the minified code, we should:

1. **Create a VM module stub** that looks like macOS VM module
2. **Hook require()** to return our stub when VM is requested
3. **Implement the same API** using bubblewrap

**Why this works**:
- ✅ No need to find minified variable names
- ✅ Works regardless of minification
- ✅ Main-process-only guard prevents renderer issues
- ✅ Drop-in replacement for macOS VM

### Code Structure

```
modules/
  claude-cowork-linux/
    index.js          → Main entry (CoworkSessionManager)
    vm-stub.js        → VM API compatibility layer
    spawn.js          → Process spawning with bubblewrap
    mounts.js         → Directory mount management

scripts/
  patch-cowork-linux-v3.js → New patcher (process.type guard!)
```

### Patch V3 Strategy

```javascript
// Append to index.js:

;(function(){
  // GUARD: Main process only!
  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;

  try {
    // Load our module
    const CoworkLinux = require('claude-cowork-linux');

    // Hook into module loading to replace VM module
    const Module = require('module');
    const originalRequire = Module.prototype.require;

    Module.prototype.require = function(id) {
      // Intercept VM module requests
      if (id === 'enhanced-claude-native' || id === './vm-module') {
        return CoworkLinux.getVMStub();
      }
      return originalRequire.apply(this, arguments);
    };

    console.log('[Cowork] Linux Cowork VM stub installed');
  } catch(e) {
    console.error('[Cowork] Failed:', e);
  }
})();
```

---

## Technical Insights

### 1. Module Loading in Electron Main Process

Main process CAN use `require()` because:
- ✅ Full Node.js environment
- ✅ Access to node_modules
- ✅ Can load custom modules

### 2. Why Renderer Can't Load Modules

Modern Electron security:
```javascript
{
  nodeIntegration: false,      // No require() in renderer
  contextIsolation: true,      // Separate JavaScript contexts
  sandbox: true,               // Process sandbox
}
```

### 3. The VM Abstraction

Claude Desktop uses a VM abstraction that:
- On macOS: Uses actual VMs (Virtualization.framework)
- On Linux: Should use namespace isolation (bubblewrap)
- On Windows: Unknown (possibly WSL2?)

The abstraction has methods like:
- `createVM()`
- `spawn(command, args)`
- `mount(path)`
- `isGuestConnected()`
- `isProcessRunning(name)`

### 4. Heartbeat System

The code shows a heartbeat system:
- Pings guest every 2000ms
- Allows 5000ms timeout
- Fails after 3 consecutive failures
- Used to detect VM crashes

We need to implement this for bubblewrap!

---

## Next Actions

### Immediate (This Iteration)

1. ✅ Create process.type guard in patches
2. ✅ Design VM stub API
3. ✅ Implement VM stub matching macOS interface
4. ✅ Test that renderer doesn't crash
5. ✅ Verify main process loads module

### Testing

1. Add `console.log` statements to verify:
   - Guard works (renderer doesn't execute)
   - Main process loads module
   - VM stub is created
   - No crashes occur

2. Check process list:
   ```bash
   ps aux | grep electron
   ```
   - Should see main process
   - Should see renderer(s)
   - Should NOT see `<defunct>`

### Future (Iteration 3)

1. Implement actual VM stub methods
2. Hook tool registration
3. Test directory selection
4. Verify bubblewrap spawning
5. End-to-end testing

---

## Success Criteria for This Iteration

- [ ] Create patch with `process.type === 'browser'` guard
- [ ] Verify renderer processes don't try to load module
- [ ] Confirm main process loads successfully
- [ ] No zombie processes
- [ ] Claude Desktop window appears
- [ ] No JavaScript errors in console

---

## Code Snippets for Implementation

### Minimal Test Patch

```javascript
// Test that guard works
;(function(){
  console.log('[Cowork Test] Process type:', process.type);

  if (process.type !== 'browser') {
    console.log('[Cowork Test] Renderer - skipping');
    return;
  }

  console.log('[Cowork Test] Main process - would load module here');
})();
```

If this logs correctly in BOTH processes without crashing, we know the guard works!

---

**Status**: Ready to implement guarded patch v3
