# Cowork Adaptation Research for Linux

## Overview
Cowork is Claude Desktop's feature that allows secure, sandboxed access to user directories through a VM (Virtual Machine) environment. On macOS, this uses native virtualization features.

## Current macOS Implementation

### Key Components Found:

1. **request_cowork_directory Tool**
   - Shows directory picker dialog
   - Mounts selected directory into VM session
   - Path: `/sessions/{sessionId}/mnt/`
   - Uses Electron's `dialog.showOpenDialog()`

2. **VM Process Management**
   - `getVmProcessId()` - Gets VM process ID
   - `isGuestConnected()` - Checks VM guest connection
   - `isProcessRunning()` - Checks if process is running in VM
   - Heartbeat monitoring (2 second intervals, max 3 failures)

3. **File System Mounting**
   - Additional mounts tracked per session
   - Path translation between host and VM
   - Special "outputs" directory handling

4. **VM Bundle**
   - Bundle version: `c991333b58e26c9d99e64d1527438b837bdfb022`
   - Uses SHA hash: `dc68c6ea4592361ee0ad2d427a6b1bc878a5f419b6ba2434bc97bb6909bac6d2`

## Linux Adaptation Strategy

### Option 1: QEMU/KVM-based VM (Heavy)
- **Pros**: Full isolation, similar to macOS
- **Cons**: Requires KVM, heavyweight, complex setup
- **Feasibility**: Low (too complex for this implementation)

### Option 2: Linux Containers (Docker/Podman)
- **Pros**: Lightweight, native Linux support, good isolation
- **Cons**: Different from macOS approach, container management overhead
- **Feasibility**: Medium-High

### Option 3: Bubblewrap/Firejail Sandboxing
- **Pros**: Lightweight, Linux-native, minimal overhead
- **Cons**: Less isolation than VM/container
- **Feasibility**: High

### Option 4: Direct Mount with Linux Namespaces
- **Pros**: Very lightweight, uses kernel features
- **Cons**: Requires careful privilege management
- **Feasibility**: High

## Recommended Approach: Bubblewrap + Bind Mounts

### Why Bubblewrap?
1. **Lightweight**: No VM overhead, uses Linux namespaces
2. **Sandboxing**: Good process isolation
3. **File System Control**: Easy bind mounts
4. **Availability**: Available in most Linux distros (`bubblewrap` package)
5. **Used by Flatpak**: Battle-tested technology

### Implementation Plan

1. **Install Bubblewrap**
   ```bash
   sudo nala install bubblewrap
   ```

2. **Create Cowork Session Manager** (JavaScript/TypeScript)
   - Track active sessions
   - Manage bind mounts
   - Handle process spawning in sandbox

3. **Adapt request_cowork_directory Tool**
   - Replace VM process calls with bubblewrap execution
   - Use Electron dialog for directory selection (already works)
   - Create bind mount mappings

4. **Session Directory Structure**
   ```
   /tmp/claude-cowork-sessions/
   ├── {session-id}/
   │   ├── mnt/
   │   │   ├── {directory-name}/
   │   │   └── outputs/
   │   ├── sandbox-root/
   │   └── session.json
   ```

5. **Bubblewrap Command Template**
   ```bash
   bwrap \
     --ro-bind /usr /usr \
     --ro-bind /lib /lib \
     --ro-bind /lib64 /lib64 \
     --ro-bind /bin /bin \
     --ro-bind /sbin /sbin \
     --proc /proc \
     --dev /dev \
     --tmpfs /tmp \
     --bind /tmp/claude-cowork-sessions/{session-id}/mnt /sessions/{session-id}/mnt \
     --unshare-pid \
     --unshare-net \
     --die-with-parent \
     {command}
   ```

6. **Stub Implementation Points**
   - `getVmProcessId()` → Track bubblewrap PID
   - `isGuestConnected()` → Check if bubblewrap process alive
   - `isProcessRunning(name)` → Check process in sandbox
   - Heartbeat → Monitor bubblewrap parent process

## Next Steps

1. Create cowork session manager module
2. Implement bubblewrap wrapper functions
3. Patch index.js to use Linux implementation
4. Test with simple directory mount
5. Verify Claude Code can access mounted directories

## Files to Create/Modify

- `/tmp/claude-cowork-linux.js` - Bubblewrap session manager
- `/tmp/app-extracted/.vite/build/index.js` - Patch Cowork functions
- `/opt/claude-desktop/cowork-session-manager.js` - Production version

## Dependencies

```bash
sudo nala install bubblewrap
```

## Testing Plan

1. Launch Claude Desktop
2. Start Cowork session
3. Use request_cowork_directory tool
4. Select directory via dialog
5. Verify directory appears in /sessions/{id}/mnt/
6. Test file operations in mounted directory
7. Verify sandbox isolation
