#!/usr/bin/env node
/**
 * Cowork UI Enabler V4
 *
 * Enables Cowork UI on Linux by making it report as darwin for Cowork checks.
 * This is applied IN ADDITION to the v3 patch (which loads the module).
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork UI Enabler V4 ===\n');

// Read index.js
console.log('Reading index.js...');
let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log(`Size: ${(originalSize / 1024 / 1024).toFixed(2)} MB\n`);

// Create backup
console.log('Creating backup...');
fs.writeFileSync(INDEX_JS_PATH + '.v4-backup', indexContent);
console.log('✓ Backup created: index.js.v4-backup\n');

// The UI enabler patch
console.log('Applying UI enabler patch...\n');

const uiPatch = `
;(function(){
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Cowork UI Enabler (v4)
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;
  if (!global.__linuxCowork) {
    console.warn('[Cowork UI] Linux Cowork not loaded - UI enabler skipped');
    return;
  }

  console.log('[Cowork UI] Enabling Cowork UI for Linux...');

  // Strategy: Override platform getter for Cowork-related code
  const originalPlatform = process.platform;
  let platformOverride = null;

  Object.defineProperty(process, 'platform', {
    get: function() {
      // If override is active, return darwin
      if (platformOverride === 'darwin') {
        return 'darwin';
      }
      return originalPlatform;
    },
    set: function(value) {
      // Allow setting override
      platformOverride = value;
    },
    configurable: true
  });

  // Temporarily set to darwin to trigger Cowork initialization
  console.log('[Cowork UI] Temporarily setting platform to darwin for UI init...');
  process.platform = 'darwin';

  // Reset after a short delay (let UI initialize)
  setTimeout(() => {
    console.log('[Cowork UI] Restoring platform to linux');
    process.platform = null;  // Clear override
  }, 1000);

  // Also hook the vi() function if it exists globally
  if (typeof vi !== 'undefined') {
    const originalVi = vi;
    vi = function(...args) {
      console.log('[Cowork UI] vi() called - returning Linux Cowork adapter');
      if (global.__linuxCowork && global.__linuxCowork.adapter) {
        return new global.__linuxCowork.adapter(
          global.__linuxCowork.manager,
          require('crypto').randomUUID()
        );
      }
      return originalVi(...args);
    };
    console.log('[Cowork UI] Hooked vi() function');
  }

  console.log('[Cowork UI] ✅ UI enabler active');
})();
`;

indexContent += uiPatch;

console.log('Patch details:');
console.log('  - Platform override: ✅ Included');
console.log('  - Temporary darwin mode: ✅ For UI init');
console.log('  - vi() hook: ✅ If available');
console.log('  - Size: ~1.5 KB\n');

// Write patched file
console.log('Writing patched index.js...');
fs.writeFileSync(INDEX_JS_PATH, indexContent);

const newSize = indexContent.length;
console.log(`✓ Written ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`✓ Added ${(uiPatch.length / 1024).toFixed(2)} KB\n`);

console.log('═══════════════════════════════════════════════════════════');
console.log('✅ Cowork UI enabler applied!');
console.log('═══════════════════════════════════════════════════════════\n');

console.log('This patch:');
console.log('  ✅ Makes Linux appear as darwin temporarily for UI init');
console.log('  ✅ Hooks vi() function to return Linux Cowork adapter');
console.log('  ✅ Should enable Cowork slider in UI\n');

console.log('Next steps:');
console.log('  1. Repack and install');
console.log('  2. Launch Claude Desktop');
console.log('  3. Check if Cowork slider appears\n');

console.log('To restore:');
console.log(`  cp ${INDEX_JS_PATH}.v4-backup ${INDEX_JS_PATH}\n`);
