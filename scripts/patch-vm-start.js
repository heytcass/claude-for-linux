#!/usr/bin/env node
/**
 * Dynamic VM Start Intercept Patch
 *
 * Discovers the VM start function by its semantic signature (the [VM:start]
 * log string and 4-param async function pattern), then injects a Linux
 * bubblewrap session block before the original function body.
 *
 * Version-resilient — discovers identifiers at build time, not hardcoded.
 */
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Dynamic Patch: VM Start Intercept ===\n');

let content = fs.readFileSync(INDEX_JS_PATH, 'utf8');

// Discover function signature by matching the stable pattern:
// async function WORD(WORD,WORD,WORD,WORD){var WORD,...;const WORD=WORD(),...WORD=WORD();[optional WORD(),]WORD.info(`[VM:start]
const sigRegex = /async function (\w+)\((\w+),(\w+),(\w+),(\w+)\)\{(var \w+(?:,\w+)*;const \w+=\w+\(\),\w+=Date\.now\(\),\w+=new \w+,\w+=\w+\(\);(?:\w+\(\),)?\w+\.info\(`\[VM:start\])/;
const sigMatch = content.match(sigRegex);

if (!sigMatch) {
  console.error('  ERROR: Could not find VM start function via [VM:start] pattern');
  process.exit(1);
}

const funcName = sigMatch[1];
const params = [sigMatch[2], sigMatch[3], sigMatch[4], sigMatch[5]];
const originalBody = sigMatch[6];

console.log(`  Found VM start function: ${funcName}(${params.join(',')})`);

// Discover status dispatch: WORD(WORD.Ready) near lam_vm_startup_completed
// Note: function names may contain $ (e.g. X$), so use [\w$]+ instead of \w+
const statusRegex = /([\w$]+)\(([\w$]+)\.Ready\),[\w$]+\("lam_vm_startup_completed"/;
const statusMatch = content.match(statusRegex);

let statusDispatch = 'console.log("[Cowork Linux] Ready")';
if (statusMatch) {
  statusDispatch = `${statusMatch[1]}(${statusMatch[2]}.Ready)`;
  console.log(`  Found status dispatch: ${statusDispatch}`);
} else {
  console.log('  WARNING: Could not find status dispatch, using console.log fallback');
}

// Build the injection block
const injection = `async function ${funcName}(${params.join(',')}){
  if(process.platform==="linux"&&global.__linuxCowork&&!global.__linuxCowork.vmInstance){
    console.log("[Cowork Linux] Creating bubblewrap session");
    const {manager}=global.__linuxCowork;
    try {
      const {randomUUID}=require('crypto');
      const sessionId=randomUUID();
      manager.createSession(sessionId);
      console.log("[Cowork Linux] Session created:",sessionId);
      const vmInstance={
        sessionId,
        isConnected:()=>true,
        isGuestConnected:()=>Promise.resolve(true),
        isProcessRunning:(name)=>Promise.resolve(name==="__heartbeat_ping__"),
        startVM:async()=>{},
        stopVM:async()=>{},
        installSdk:async()=>{},
        setEventCallbacks:()=>{},
        executeCommand:(cmd)=>manager.spawnSandboxed(sessionId,cmd.command,cmd.args||[]),
        addMount:(hostPath)=>manager.addMount(sessionId,hostPath),
        dispose:()=>{manager.destroySession(sessionId);delete global.__linuxCowork.vmInstance},
        addApprovedOauthToken:()=>Promise.resolve(),
        spawn:(command,args)=>{
          const procInfo=manager.spawnSandboxed(sessionId,command,args||[]);
          const child=procInfo.child;
          return new Proxy(child,{get(target,prop){
            if(prop==='writeStdin')return(data)=>{if(target.stdin)target.stdin.write(data)};
            if(prop==='processId')return procInfo.id;
            const val=target[prop];return typeof val==='function'?val.bind(target):val;
          }});
        },
        exec:(command)=>manager.spawnSandboxed(sessionId,'/bin/sh',['-c',command]),
        mkdir:()=>Promise.resolve(),
        readFile:(p,enc)=>Promise.resolve(require('fs').readFileSync(p,enc||'utf8')),
        writeFile:(p,data,enc)=>{require('fs').writeFileSync(p,data,enc||'utf8');return Promise.resolve()},
        rm:()=>Promise.resolve(),
        configure:async()=>{},
        createVM:async()=>{},
        getVmProcessId:()=>'cowork-linux-'+sessionId.slice(0,8),
        connect:async()=>{},
        disconnect:async()=>{manager.destroySession(sessionId)},
      };
      global.__linuxCowork.vmInstance=vmInstance;
      try{${statusDispatch}}catch(e){console.log("[Cowork Linux] Status dispatch note:",e.message)}
      console.log("[Cowork Linux] VM instance ready");
      return vmInstance;
    }catch(e){console.error("[Cowork Linux] Session creation failed:",e)}
  }
  ${originalBody}`;

// Find and replace the original function start
const originalStart = `async function ${funcName}(${params.join(',')}){${originalBody}`;

if (!content.includes(originalStart)) {
  console.error('  ERROR: Could not locate original function for replacement');
  process.exit(1);
}

content = content.replace(originalStart, injection);
fs.writeFileSync(INDEX_JS_PATH, content);

// Verify
const patched = fs.readFileSync(INDEX_JS_PATH, 'utf8');
if (!patched.includes('global.__linuxCowork.vmInstance=vmInstance')) {
  console.error('  ERROR: Verification failed — injection not found in output');
  process.exit(1);
}

console.log('  VM start intercept applied successfully\n');
