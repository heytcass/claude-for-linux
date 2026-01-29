#!/usr/bin/env node
/**
 * Cowork Linux Patcher V3 - WITH PROCESS GUARD
 *
 * This version includes the critical process type guard to prevent
 * renderer crashes. Loads actual Cowork module safely.
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');
const COWORK_MODULE_PATH = path.join(EXTRACTED_DIR, 'node_modules/claude-cowork-linux');
const SOURCE_MODULE = path.join(__dirname, '../modules/claude-cowork-linux.js');

console.log('=== Claude Cowork Linux Patcher V3 (WITH GUARD) ===\n');

// Step 1: Install claude-cowork-linux module
console.log('[1/5] Installing claude-cowork-linux module...');
if (!fs.existsSync(COWORK_MODULE_PATH)) {
  fs.mkdirSync(COWORK_MODULE_PATH, { recursive: true });
}

fs.copyFileSync(SOURCE_MODULE, path.join(COWORK_MODULE_PATH, 'index.js'));

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
console.log(`✓ Read ${(originalSize / 1024 / 1024).toFixed(2)} MB\n`);

// Step 3: Create backup
console.log('[3/5] Creating backup...');
fs.writeFileSync(INDEX_JS_PATH + '.v3-backup', indexContent);
console.log('✓ Backup created: index.js.v3-backup\n');

// Step 4: Apply patch with GUARD
console.log('[4/5] Applying Cowork patch WITH process guard...\n');

const coworkPatch = `
;(function(){
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Linux Cowork Implementation (v3 - WITH GUARD)
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // CRITICAL: Check process type FIRST to prevent renderer crashes
  if (process.type !== 'browser') {
    // Renderer process - exit immediately without error
    return;
  }

  // Only main process continues from here
  if (process.platform !== 'linux') {
    return;
  }

  console.log('[Cowork] Linux Cowork initialization starting...');

  try {
    // Load Cowork module
    const {CoworkSessionManager, VMCompatibilityAdapter} =
      require('claude-cowork-linux');

    // Initialize global Cowork instance
    global.__linuxCowork = {
      manager: new CoworkSessionManager(),
      adapter: VMCompatibilityAdapter,
      version: '1.0.0-linux',
      platform: 'bubblewrap'
    };

    console.log('[Cowork] ✅ Linux Cowork enabled via bubblewrap');
    console.log('[Cowork] Manager type:', typeof global.__linuxCowork.manager);
    console.log('[Cowork] Adapter type:', typeof global.__linuxCowork.adapter);
    console.log('[Cowork] Version:', global.__linuxCowork.version);

    // Check bubblewrap availability
    const {CoworkSessionManager: CSM} = require('claude-cowork-linux');
    if (CSM.isAvailable && typeof CSM.isAvailable === 'function') {
      if (CSM.isAvailable()) {
        const version = CSM.getVersion ? CSM.getVersion() : 'unknown';
        console.log('[Cowork] Bubblewrap available:', version);
      } else {
        console.warn('[Cowork] ⚠️ Bubblewrap not found - install with: sudo apt install bubblewrap');
      }
    }

  } catch(e) {
    console.error('[Cowork] ❌ Failed to load Linux Cowork:', e.message);
    console.error('[Cowork] Stack:', e.stack);
  }
})();
`;

indexContent += coworkPatch;

console.log('Patch details:');
console.log('  - Process guard: ✅ Included');
console.log('  - Platform check: ✅ Linux only');
console.log('  - Module loading: ✅ Safe with try/catch');
console.log('  - Error handling: ✅ Comprehensive');
console.log('  - Logging: ✅ Detailed');
console.log('  - Size: ~2.5 KB\n');

// Step 5: Write patched file
console.log('[5/5] Writing patched index.js...');
fs.writeFileSync(INDEX_JS_PATH, indexContent);

const newSize = indexContent.length;
console.log(`✓ Written ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`✓ Added ${(coworkPatch.length / 1024).toFixed(2)} KB\n`);

console.log('═══════════════════════════════════════════════════════════');
console.log('✅ Cowork V3 patch applied successfully!');
console.log('═══════════════════════════════════════════════════════════\n');

console.log('Key features:');
console.log('  ✅ Process type guard prevents renderer crashes');
console.log('  ✅ Linux platform check');
console.log('  ✅ Safe module loading with error handling');
console.log('  ✅ Detailed logging for debugging');
console.log('  ✅ Bubblewrap availability check\n');

console.log('Next steps:');
console.log('  1. Repack: python3 tools/asar_tool.py pack /tmp/app-extracted /tmp/app-cowork-v3.asar');
console.log('  2. Backup: sudo cp /opt/claude-desktop/app.asar /opt/claude-desktop/app.asar.backup-v3');
console.log('  3. Install: sudo cp /tmp/app-cowork-v3.asar /opt/claude-desktop/app.asar');
console.log('  4. Test: claude-desktop 2>&1 | tee /tmp/cowork-v3-test.log\n');

console.log('Expected console output:');
console.log('  [Cowork] Linux Cowork initialization starting...');
console.log('  [Cowork] ✅ Linux Cowork enabled via bubblewrap');
console.log('  [Cowork] Manager type: object');
console.log('  [Cowork] Adapter type: function');
console.log('  [Cowork] Bubblewrap available: <version>\n');

console.log('To restore:');
console.log(`  cp ${INDEX_JS_PATH}.v3-backup ${INDEX_JS_PATH}\n`);
