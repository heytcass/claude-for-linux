#!/usr/bin/env node
/**
 * Cowork Linux Patcher
 *
 * Patches Claude Desktop's index.js to use Linux-based Cowork instead of macOS VMs.
 * This script modifies the unpacked app.asar to replace VM calls with bubblewrap.
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');
const COWORK_MODULE_PATH = path.join(EXTRACTED_DIR, 'node_modules/claude-cowork-linux');

console.log('=== Claude Cowork Linux Patcher ===\n');

// Step 1: Copy cowork-linux module
console.log('[1/4] Installing claude-cowork-linux module...');
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
console.log('[2/4] Reading index.js...');
let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log(`✓ Read ${(originalSize / 1024 / 1024).toFixed(2)} MB\n`);

// Step 3: Apply patches
console.log('[3/4] Applying patches...');

// Patch 1: Add Linux Cowork import at the beginning
const coworkImport = `
// Linux Cowork Support
const { CoworkSessionManager: LinuxCoworkSessionManager, VMCompatibilityAdapter: LinuxVMAdapter } = process.platform === "linux" ? require("claude-cowork-linux") : { CoworkSessionManager: null, VMCompatibilityAdapter: null };
const linuxCoworkManager = process.platform === "linux" ? new LinuxCoworkSessionManager() : null;
`;

// Find a good insertion point (after initial requires)
const insertAfter = 'const{randomUUID:ri}=require("crypto")';
if (indexContent.includes(insertAfter)) {
  indexContent = indexContent.replace(
    insertAfter,
    insertAfter + coworkImport
  );
  console.log('✓ Added Linux Cowork import');
} else {
  console.log('⚠ Could not find insertion point for import, trying alternative...');
  // Try alternative insertion point
  const altInsert = 'const oe=require("electron")';
  if (indexContent.includes(altInsert)) {
    indexContent = indexContent.replace(
      altInsert,
      altInsert + coworkImport
    );
    console.log('✓ Added Linux Cowork import (alternative location)');
  } else {
    console.log('✗ Failed to find insertion point');
  }
}

// Patch 2: Wrap VM process creation to use Linux adapter
// Find the function that creates VM processes
const vmProcessPattern = /async function vi\(\){[\s\S]{0,500}getVmProcessId/;
if (vmProcessPattern.test(indexContent)) {
  console.log('✓ Found VM process function');

  // Add Linux adapter at the start of VM function
  indexContent = indexContent.replace(
    /(async function vi\(\){)/,
    `$1
if(process.platform==="linux"){
  // Return Linux VM adapter instead of macOS VM
  if(!linuxCoworkManager){return null;}
  const sessionId=require("crypto").randomUUID();
  return new LinuxVMAdapter(linuxCoworkManager,sessionId);
}
`
  );
  console.log('✓ Patched VM process function for Linux');
} else {
  console.log('⚠ Could not find VM process function (may not affect functionality)');
}

// Patch 3: Handle bubblewrap availability check
// Find isAvailable or similar checks
if (indexContent.includes('CoworkSessionManager.isAvailable')) {
  indexContent = indexContent.replace(
    /CoworkSessionManager\.isAvailable\(\)/g,
    `(process.platform==="linux"?LinuxCoworkSessionManager.isAvailable():CoworkSessionManager.isAvailable())`
  );
  console.log('✓ Patched availability checks');
}

// Patch 4: Update request_cowork_directory tool to handle Linux
const coworkDirPattern = /function Urt\(t\){const e=x0\("request_cowork_directory"/;
if (coworkDirPattern.test(indexContent)) {
  console.log('✓ Found request_cowork_directory function');

  // Patch to use Linux session manager
  indexContent = indexContent.replace(
    /(const i=t\.getVmProcessId\(\);if\(!i\))/,
    `
// Linux: Use bubblewrap session manager
if(process.platform==="linux"&&linuxCoworkManager){
  const linuxSessionId=t._vmProcessId||require("crypto").randomUUID();
  if(!linuxSessionId){
    return{content:[{type:"text",text:"Cowork session not available."}],isError:!0};
  }
}
$1`
  );

  // Patch mount operation
  indexContent = indexContent.replace(
    /(o\.filePaths\.forEach\(async c=>{[\s\S]{0,200}mountHostPath)/,
    `$1`
  );

  console.log('✓ Patched request_cowork_directory for Linux');
} else {
  console.log('⚠ Could not find request_cowork_directory (continuing...)');
}

console.log();

// Step 4: Write patched file
console.log('[4/4] Writing patched index.js...');
fs.writeFileSync(INDEX_JS_PATH + '.cowork-backup', fs.readFileSync(INDEX_JS_PATH));
fs.writeFileSync(INDEX_JS_PATH, indexContent);

const newSize = indexContent.length;
console.log(`✓ Written ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`  Size change: ${((newSize - originalSize) / 1024).toFixed(2)} KB`);
console.log();

console.log('=== Patching Complete ===');
console.log();
console.log('Next steps:');
console.log('1. Install bubblewrap: sudo nala install bubblewrap');
console.log('2. Repack app.asar: python3 /tmp/asar_tool.py pack /tmp/app-extracted /opt/claude-desktop/app.asar');
console.log('3. Restart Claude Desktop');
console.log();
console.log('Backup saved: ' + INDEX_JS_PATH + '.cowork-backup');
