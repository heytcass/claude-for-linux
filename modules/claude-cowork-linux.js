/**
 * Claude Cowork Linux Implementation
 *
 * Provides sandboxed directory access using bubblewrap instead of macOS VMs.
 * This module replaces VM-based isolation with Linux namespace-based sandboxing.
 */

const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

const COWORK_BASE_DIR = '/tmp/claude-cowork-sessions';
const BWRAP_PATH = '/usr/bin/bwrap';

/**
 * Session Manager - Tracks active Cowork sessions
 */
class CoworkSessionManager {
  constructor() {
    this.sessions = new Map();
    this.processes = new Map();

    // Ensure base directory exists
    if (!fs.existsSync(COWORK_BASE_DIR)) {
      fs.mkdirSync(COWORK_BASE_DIR, { recursive: true, mode: 0o700 });
    }
  }

  /**
   * Create a new Cowork session
   */
  createSession(sessionId) {
    if (this.sessions.has(sessionId)) {
      return this.sessions.get(sessionId);
    }

    const sessionDir = path.join(COWORK_BASE_DIR, sessionId);
    const mntDir = path.join(sessionDir, 'mnt');
    const outputsDir = path.join(mntDir, 'outputs');
    const sandboxRoot = path.join(sessionDir, 'sandbox-root');

    // Create session directories
    fs.mkdirSync(sessionDir, { recursive: true, mode: 0o700 });
    fs.mkdirSync(mntDir, { recursive: true, mode: 0o755 });
    fs.mkdirSync(outputsDir, { recursive: true, mode: 0o755 });
    fs.mkdirSync(sandboxRoot, { recursive: true, mode: 0o755 });

    const session = {
      id: sessionId,
      dir: sessionDir,
      mntDir: mntDir,
      outputsDir: outputsDir,
      sandboxRoot: sandboxRoot,
      mounts: new Map(),
      createdAt: Date.now(),
      lastActivity: Date.now(),
    };

    this.sessions.set(sessionId, session);

    // Write session metadata
    const metadataPath = path.join(sessionDir, 'session.json');
    fs.writeFileSync(metadataPath, JSON.stringify({
      id: sessionId,
      created: new Date().toISOString(),
      platform: 'linux-bubblewrap',
    }, null, 2));

    return session;
  }

  /**
   * Get or create session
   */
  getSession(sessionId) {
    if (this.sessions.has(sessionId)) {
      return this.sessions.get(sessionId);
    }
    return this.createSession(sessionId);
  }

  /**
   * Add a directory mount to session
   */
  addMount(sessionId, hostPath, name = null) {
    const session = this.getSession(sessionId);
    const mountName = name || path.basename(hostPath);
    const mountPoint = path.join(session.mntDir, mountName);

    // Create bind mount using symlink (simple approach for Electron)
    // For true isolation, we'll use bubblewrap when spawning processes
    if (!fs.existsSync(mountPoint)) {
      fs.symlinkSync(hostPath, mountPoint);
    }

    session.mounts.set(mountName, {
      hostPath: hostPath,
      mountPoint: mountPoint,
      name: mountName,
      addedAt: Date.now(),
    });

    session.lastActivity = Date.now();
    return mountPoint;
  }

  /**
   * Remove a mount from session
   */
  removeMount(sessionId, name) {
    const session = this.sessions.get(sessionId);
    if (!session) return false;

    const mount = session.mounts.get(name);
    if (!mount) return false;

    // Remove symlink
    try {
      if (fs.existsSync(mount.mountPoint)) {
        fs.unlinkSync(mount.mountPoint);
      }
    } catch (err) {
      console.error(`Failed to remove mount ${name}:`, err);
    }

    session.mounts.delete(name);
    session.lastActivity = Date.now();
    return true;
  }

  /**
   * Get all mounts for a session
   */
  getMounts(sessionId) {
    const session = this.sessions.get(sessionId);
    if (!session) return [];
    return Array.from(session.mounts.values());
  }

  /**
   * Cleanup session
   */
  destroySession(sessionId) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    // Kill any running processes
    const sessionProcs = Array.from(this.processes.values())
      .filter(p => p.sessionId === sessionId);

    for (const proc of sessionProcs) {
      try {
        if (proc.child && !proc.child.killed) {
          proc.child.kill('SIGTERM');
        }
      } catch (err) {
        console.error(`Failed to kill process ${proc.id}:`, err);
      }
      this.processes.delete(proc.id);
    }

    // Remove session directory
    try {
      fs.rmSync(session.dir, { recursive: true, force: true });
    } catch (err) {
      console.error(`Failed to remove session directory:`, err);
    }

    this.sessions.delete(sessionId);
  }

  /**
   * Spawn a sandboxed process using bubblewrap
   */
  spawnSandboxed(sessionId, command, args = [], options = {}) {
    const session = this.getSession(sessionId);
    const processId = randomUUID();

    // Build bubblewrap arguments
    const bwrapArgs = [
      // Read-only system mounts
      '--ro-bind', '/usr', '/usr',
      '--ro-bind', '/lib', '/lib',
      '--ro-bind', '/bin', '/bin',
      '--ro-bind', '/sbin', '/sbin',
    ];

    // Add lib64 if it exists (64-bit systems)
    if (fs.existsSync('/lib64')) {
      bwrapArgs.push('--ro-bind', '/lib64', '/lib64');
    }

    // Virtual file systems
    bwrapArgs.push(
      '--proc', '/proc',
      '--dev', '/dev',
      '--tmpfs', '/tmp',
    );

    // Bind mount session directory
    bwrapArgs.push(
      '--bind', session.mntDir, `/sessions/${sessionId}/mnt`,
    );

    // Add user mounts as read-write binds
    for (const mount of session.mounts.values()) {
      const vmPath = `/sessions/${sessionId}/mnt/${mount.name}`;
      bwrapArgs.push('--bind', mount.hostPath, vmPath);
    }

    // Isolation flags
    bwrapArgs.push(
      '--unshare-pid',     // Separate process namespace
      '--unshare-ipc',     // Separate IPC namespace
      '--die-with-parent', // Kill when parent dies
    );

    // Working directory
    if (options.cwd) {
      bwrapArgs.push('--chdir', options.cwd);
    }

    // Command and arguments
    bwrapArgs.push(command, ...args);

    // Spawn the sandboxed process
    const child = spawn(BWRAP_PATH, bwrapArgs, {
      stdio: options.stdio || 'pipe',
      env: options.env || process.env,
    });

    const procInfo = {
      id: processId,
      sessionId: sessionId,
      command: command,
      args: args,
      child: child,
      pid: child.pid,
      startedAt: Date.now(),
    };

    this.processes.set(processId, procInfo);

    // Cleanup on exit
    child.on('exit', (code, signal) => {
      procInfo.exitCode = code;
      procInfo.exitSignal = signal;
      procInfo.exitedAt = Date.now();
      // Keep in map for a bit for status queries
      setTimeout(() => {
        this.processes.delete(processId);
      }, 5000);
    });

    session.lastActivity = Date.now();
    return procInfo;
  }

  /**
   * Check if a process is running
   */
  isProcessRunning(processId) {
    const proc = this.processes.get(processId);
    if (!proc) return false;
    if (!proc.child) return false;
    if (proc.child.killed) return false;
    if (proc.exitCode !== undefined) return false;

    // Double-check with kill signal 0
    try {
      process.kill(proc.child.pid, 0);
      return true;
    } catch (err) {
      return false;
    }
  }

  /**
   * Check if bubblewrap is available
   */
  static isAvailable() {
    return fs.existsSync(BWRAP_PATH);
  }

  /**
   * Get version info
   */
  static getVersion() {
    if (!CoworkSessionManager.isAvailable()) {
      return null;
    }

    try {
      const output = execFileSync(BWRAP_PATH, ['--version'], { encoding: 'utf8' });
      return output.trim();
    } catch (err) {
      return 'unknown';
    }
  }
}

/**
 * VM Compatibility Adapter
 * Provides macOS VM-like API using Linux sandboxing
 */
class VMCompatibilityAdapter {
  constructor(sessionManager, sessionId) {
    this.sessionManager = sessionManager;
    this.sessionId = sessionId;
    this._vmProcessId = `cowork-${sessionId}`;
    this._isConnected = true;
  }

  /**
   * Get VM process ID (simulated)
   */
  getVmProcessId() {
    return this._vmProcessId;
  }

  /**
   * Check if guest is connected
   */
  isGuestConnected() {
    return Promise.resolve(this._isConnected);
  }

  /**
   * Check if a process is running
   */
  isProcessRunning(name) {
    // Special handling for heartbeat ping
    if (name === '__heartbeat_ping__') {
      return Promise.resolve(this._isConnected);
    }

    // Check if any sandboxed process matches name
    const procs = Array.from(this.sessionManager.processes.values())
      .filter(p => p.sessionId === this.sessionId);

    for (const proc of procs) {
      if (proc.command.includes(name) || proc.args.some(a => a.includes(name))) {
        if (this.sessionManager.isProcessRunning(proc.id)) {
          return Promise.resolve(true);
        }
      }
    }

    return Promise.resolve(false);
  }

  /**
   * Disconnect (cleanup)
   */
  disconnect() {
    this._isConnected = false;
    this.sessionManager.destroySession(this.sessionId);
  }
}

// Export
module.exports = {
  CoworkSessionManager,
  VMCompatibilityAdapter,
  COWORK_BASE_DIR,
};
