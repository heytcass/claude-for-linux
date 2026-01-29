#!/usr/bin/env node
/**
 * Cowork Linux Patcher V2
 *
 * Patches Claude Desktop's minified index.js to enable Linux Cowork.
 * Handles single-line minified JavaScript.
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');
const COWORK_MODULE_PATH = path.join(EXTRACTED_DIR, 'node_modules/claude-cowork-linux');

console.log('=== Claude Cowork Linux Patcher V2 ===\n');

// Step 1: Copy cowork-linux module
console.log('[1/5] Installing claude-cowork-linux module...');
if (!fs.existsSync(COWORK_MODULE_PATH)) {
  fs.mkdirSync(COWORK_MODULE_PATH, { recursive: true });
}

fs.copyFileSync(
  '/tmp/claude-cowork-linux.js',
  path.join(COWORK_MODULE_PATH, 'index.js')
);

fs.writeFileSync(
  path.join(COWORK_MODULE_PATH, 'package.json'),
  JSON.stringify({
    name: 'claude-cowork-linux',
    version: '1.0.0',
    description: 'Linux Cowork implementation using bubblewrap',
    main: 'index.js',
  }, null, 2)
);

console.log('✓ Module installed\n');

// Step 2: Read index.js
console.log('[2/5] Reading index.js...');
let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log(`✓ Read ${(originalSize / 1024 / 1024).toFixed(2)} MB (minified)\n`);

// Step 3: Create backup
console.log('[3/5] Creating backup...');
fs.writeFileSync(INDEX_JS_PATH + '.pre-cowork', indexContent);
console.log('✓ Backup created: index.js.pre-cowork\n');

// Step 4: Apply patches
console.log('[4/5] Applying patches...');

let patchCount = 0;

// Patch 1: Add Linux Cowork loader at the end of file
// This is safer for minified code - append our module loader
const coworkLoader = `;(function(){if(process.platform!=="linux")return;try{const{CoworkSessionManager:L,VMCompatibilityAdapter:V}=require("claude-cowork-linux");if(!global.__linuxCowork){global.__linuxCowork={manager:new L(),adapter:V};console.log("[Cowork] Linux Cowork enabled via bubblewrap")}}catch(e){console.error("[Cowork] Failed to load Linux Cowork:",e)}})();`;

indexContent += coworkLoader;
patchCount++;
console.log('✓ Added Linux Cowork loader');

// Patch 2: Intercept VM creation by monkey-patching
// Find and wrap the vi() function (VM instance getter)
// We'll add a runtime check at the end of the file
const vmInterceptor = `;(function(){if(process.platform!=="linux"||!global.__linuxCowork)return;const orig={};if(typeof vi!=="undefined"){orig.vi=vi;vi=function(){const sessionId=require("crypto").randomUUID();return new global.__linuxCowork.adapter(global.__linuxCowork.manager,sessionId)}}})();`;

indexContent += vmInterceptor;
patchCount++;
console.log('✓ Added VM interceptor');

// Patch 3: Handle request_cowork_directory
// Patch the dialog result handling to work with Linux paths
const dialogPatcher = `;(function(){if(process.platform!=="linux"||!global.__linuxCowork)return;const origDialog=oe.dialog.showOpenDialog;oe.dialog.showOpenDialog=async function(...args){const result=await origDialog.apply(this,args);if(result&&!result.canceled&&result.filePaths&&result.filePaths.length>0&&global.__linuxCowork){try{const sessionId=global.__linuxCowork.currentSession||require("crypto").randomUUID();global.__linuxCowork.currentSession=sessionId;for(const p of result.filePaths){global.__linuxCowork.manager.addMount(sessionId,p)}}catch(e){console.error("[Cowork] Failed to mount:",e)}}return result}})();`;

indexContent += dialogPatcher;
patchCount++;
console.log('✓ Added dialog patcher');

// Patch 4: Add bubblewrap availability check
// Replace any hardcoded macOS VM checks
if (indexContent.includes('darwin')) {
  // Add runtime platform check for Cowork availability
  const availCheck = `;(function(){if(process.platform==="linux"&&global.__linuxCowork){const L=require("claude-cowork-linux").CoworkSessionManager;if(L.isAvailable()){console.log("[Cowork] Bubblewrap available:",L.getVersion())}else{console.warn("[Cowork] Bubblewrap not found - install with: sudo apt install bubblewrap")}}})();`;

  indexContent += availCheck;
  patchCount++;
  console.log('✓ Added availability check');
}

console.log(`\nTotal patches applied: ${patchCount}\n`);

// Step 5: Write patched file
console.log('[5/5] Writing patched index.js...');
fs.writeFileSync(INDEX_JS_PATH, indexContent);

const newSize = indexContent.length;
console.log(`✓ Written ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`  Size increase: ${((newSize - originalSize) / 1024).toFixed(2)} KB`);
console.log();

console.log('=== Patching Complete ===');
console.log();
console.log('Patches applied:');
console.log('  1. Linux Cowork module loader');
console.log('  2. VM function interceptor');
console.log('  3. Dialog result patcher for mounts');
console.log('  4. Bubblewrap availability check');
console.log();
console.log('Next steps:');
console.log('1. Install bubblewrap: sudo nala install bubblewrap');
console.log('2. Repack app.asar: python3 /opt/claude-desktop/asar_tool.py pack /tmp/app-extracted /tmp/app-patched.asar');
console.log('3. Install: sudo cp /tmp/app-patched.asar /opt/claude-desktop/app.asar');
console.log('4. Restart: killall electron && claude-desktop');
console.log();
console.log('Rollback: sudo cp /opt/claude-desktop/app.asar.pre-cowork /opt/claude-desktop/app.asar');
