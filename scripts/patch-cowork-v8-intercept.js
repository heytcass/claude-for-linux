#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V8: Intercept VM Start ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log('Size: ' + (originalSize / 1024 / 1024).toFixed(2) + ' MB\n');

fs.writeFileSync(INDEX_JS_PATH + '.v8-backup', indexContent);

// Find and wrap the $rt VM start function
// Original pattern: async function $rt(t,e,r){const n=O_(),i=Date.now(),a=ya();Oe.info(`[VM:start] Beginning startup
const original = 'async function $rt(t,e,r){const n=O_(),i=Date.now(),a=ya();Oe.info(`[VM:start] Beginning startup';

const replacement = `async function $rt(t,e,r){
  // LINUX: Create bubblewrap session early (but don't return - let function continue)
  if(process.platform==="linux"&&global.__linuxCowork&&!global.__linuxCowork.vmInstance){
    console.log("[Cowork Linux] Creating bubblewrap session early");
    const {manager}=global.__linuxCowork;
    try {
      const {randomUUID} = require('crypto');
      const sessionId = randomUUID();
      manager.createSession(sessionId);
      console.log("[Cowork Linux] Session created:", sessionId);

      // Create mock VM instance
      const vmInstance = {
        sessionId,
        isConnected: () => true,
        isGuestConnected: () => Promise.resolve(true),
        isProcessRunning: (name) => {
          console.log("[Cowork Linux] isProcessRunning:", name);
          return Promise.resolve(name === "__heartbeat_ping__");
        },
        startVM: async (bundlePath, memoryGB, config) => {
          console.log("[Cowork Linux] startVM called (no-op for Linux)");
          return Promise.resolve();
        },
        stopVM: async () => {
          console.log("[Cowork Linux] stopVM called");
          return Promise.resolve();
        },
        installSdk: async (subpath, version) => {
          console.log("[Cowork Linux] installSdk called (no-op for Linux)");
          return Promise.resolve();
        },
        setEventCallbacks: (onStdout, onStderr, onExit) => {
          console.log("[Cowork Linux] setEventCallbacks registered");
        },
        executeCommand: (cmd) => {
          console.log("[Cowork Linux] executeCommand:", cmd);
          return manager.spawnSandboxed(sessionId, cmd.command, cmd.args || []);
        },
        addMount: (hostPath, guestPath) => {
          console.log("[Cowork Linux] addMount:", hostPath, "->", guestPath);
          return manager.addMount(sessionId, hostPath);
        },
        dispose: () => {
          console.log("[Cowork Linux] Disposing session");
          manager.destroySession(sessionId);
          delete global.__linuxCowork.vmInstance;
        },
        addApprovedOauthToken: (token) => {
          console.log("[Cowork Linux] addApprovedOauthToken called (no-op for Linux)");
          return Promise.resolve();
        },
        spawn: (command, args, options) => {
          console.log("[Cowork Linux] spawn:", command, args);
          const procInfo = manager.spawnSandboxed(sessionId, command, args || []);
          const child = procInfo.child;
          // Use Proxy to add writeStdin while delegating everything else to child
          const proxy = new Proxy(child, {
            get(target, prop) {
              if (prop === 'writeStdin') {
                return (data) => {
                  if (target.stdin) target.stdin.write(data);
                };
              }
              if (prop === 'processId') {
                return procInfo.id;
              }
              return target[prop];
            }
          });
          return proxy;
        },
        exec: (command) => {
          console.log("[Cowork Linux] exec:", command);
          return manager.spawnSandboxed(sessionId, '/bin/sh', ['-c', command]);
        },
        mkdir: (path, options) => {
          console.log("[Cowork Linux] mkdir:", path);
          return Promise.resolve();
        },
        readFile: (path, encoding) => {
          console.log("[Cowork Linux] readFile:", path);
          const fs = require('fs');
          return Promise.resolve(fs.readFileSync(path, encoding || 'utf8'));
        },
        writeFile: (path, data, encoding) => {
          console.log("[Cowork Linux] writeFile:", path);
          const fs = require('fs');
          fs.writeFileSync(path, data, encoding || 'utf8');
          return Promise.resolve();
        },
        rm: (path, options) => {
          console.log("[Cowork Linux] rm:", path);
          return Promise.resolve();
        }
      };

      // Store globally
      global.__linuxCowork.vmInstance = vmInstance;
      console.log("[Cowork Linux] VM instance stored, continuing with $rt");

      // Signal UI that we're ready (jf.Ready = "ready")
      try {
        console.log("[Cowork Linux] Dispatching Ready status to UI");
        AE({Offline:"offline",Booting:"booting",Ready:"ready"}.Ready);
      } catch(statusErr) {
        console.log("[Cowork Linux] Status dispatch failed (may not be critical):", statusErr.message);
      }

      // ACTUALLY, just return the vmInstance immediately instead of running rest of $rt
      // The rest expects a real VM and will fail
      console.log("[Cowork Linux] Returning vmInstance early to skip macOS VM logic");
      return vmInstance;
    } catch(e) {
      console.error("[Cowork Linux] Session creation failed:", e);
    }
  }

  // Continue with original function (will use fake Swift module on Linux)
  const n=O_(),i=Date.now(),a=ya();Oe.info(\`[VM:start] Beginning startup`;

console.log('Searching for $rt function...');
if (indexContent.includes(original)) {
  indexContent = indexContent.replace(original, replacement);
  console.log('✅ Found and wrapped $rt() function!\n');
} else {
  console.log('❌ $rt() function not found in expected form\n');
}

fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V8 patch applied\n');
