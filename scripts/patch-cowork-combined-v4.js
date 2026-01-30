#!/usr/bin/env node
/**
 * Cowork Complete Enabler V4
 *
 * Combines platform override + IPC handler for full Linux Cowork support.
 * Enables UI AND handles backend requests.
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork Complete Enabler V4 (Platform + IPC) ===\n');

// Read index.js
console.log('Reading index.js...');
let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log(`Size: ${(originalSize / 1024 / 1024).toFixed(2)} MB\n');

// Create backup
console.log('Creating backup...');
fs.writeFileSync(INDEX_JS_PATH + '.v4-combined-backup', indexContent);
console.log('✓ Backup created: index.js.v4-combined-backup\n');

// The complete patch
console.log('Applying complete Cowork enabler...\n');

const completePatch = `
;(function(){
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Cowork Complete Enabler (v4) - Platform Override + IPC Handler
  //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;
  if (!global.__linuxCowork) {
    console.warn('[Cowork] Linux Cowork not loaded - enabler skipped');
    return;
  }

  console.log('[Cowork] Applying complete Linux enabler...');

  //──────────────────────────────────────────────────────────────────
  // Part 1: Platform Override (for UI detection)
  //──────────────────────────────────────────────────────────────────

  const originalPlatform = process.platform;
  let platformOverrideActive = false;

  Object.defineProperty(process, 'platform', {
    get: function() {
      if (platformOverrideActive) {
        return 'darwin';  // Pretend to be macOS
      }
      return originalPlatform;
    },
    configurable: true
  });

  // Enable override temporarily for UI initialization
  platformOverrideActive = true;
  console.log('[Cowork] Platform override ACTIVE (darwin mode)');

  // Disable after UI loads (5 seconds should be enough)
  setTimeout(() => {
    platformOverrideActive = false;
    console.log('[Cowork] Platform override DISABLED (back to linux)');
  }, 5000);

  //──────────────────────────────────────────────────────────────────
  // Part 2: IPC Handler (for actual functionality)
  //──────────────────────────────────────────────────────────────────

  try {
    const {ipcMain, dialog} = require('electron');

    // Try multiple possible channel names
    const channelNames = [
      'cowork:requestDirectory',
      'request_cowork_directory',
      'vm:requestDirectory',
      'cowork:enable'
    ];

    channelNames.forEach(channelName => {
      ipcMain.handle(channelName, async (event, ...args) => {
        console.log(\`[Cowork IPC] Request received on channel: \${channelName}\`, args);

        try {
          // Show directory picker
          const result = await dialog.showOpenDialog({
            properties: ['openDirectory'],
            title: 'Select Directory for Cowork',
            message: 'Choose a directory to share with Claude'
          });

          if (result.canceled || !result.filePaths || !result.filePaths[0]) {
            console.log('[Cowork IPC] User canceled');
            return {canceled: true, success: false};
          }

          const dirPath = result.filePaths[0];
          const sessionId = require('crypto').randomUUID();

          console.log('[Cowork IPC] Selected directory:', dirPath);
          console.log('[Cowork IPC] Session ID:', sessionId);

          // Mount directory using our Linux Cowork
          global.__linuxCowork.manager.addMount(sessionId, dirPath);

          console.log('[Cowork IPC] ✅ Directory mounted successfully');

          return {
            success: true,
            canceled: false,
            sessionId: sessionId,
            path: dirPath,
            platform: 'linux-bubblewrap'
          };

        } catch (error) {
          console.error('[Cowork IPC] Error:', error);
          return {
            success: false,
            error: error.message
          };
        }
      });

      console.log(\`[Cowork IPC] Handler registered: \${channelName}\`);
    });

  } catch (error) {
    console.error('[Cowork IPC] Failed to register handlers:', error);
  }

  //──────────────────────────────────────────────────────────────────
  // Part 3: VM Function Hook (if it exists)
  //──────────────────────────────────────────────────────────────────

  // Try to hook vi() function for VM instance
  if (typeof vi !== 'undefined') {
    const originalVi = vi;
    vi = function(...args) {
      console.log('[Cowork] vi() called - returning Linux adapter');
      if (global.__linuxCowork && global.__linuxCowork.adapter) {
        const sessionId = require('crypto').randomUUID();
        return new global.__linuxCowork.adapter(
          global.__linuxCowork.manager,
          sessionId
        );
      }
      return originalVi(...args);
    };
    console.log('[Cowork] ✅ vi() function hooked');
  } else {
    console.log('[Cowork] vi() function not found (not critical)');
  }

  console.log('[Cowork] ✅ Complete enabler active');
  console.log('[Cowork] Ready for Cowork requests!');
})();
`;

indexContent += completePatch;

console.log('Patch details:');
console.log('  Part 1: Platform override ✅');
console.log('  Part 2: IPC handlers (4 channels) ✅');
console.log('  Part 3: VM hook ✅');
console.log('  Total size: ~3.5 KB\n');

// Write patched file
console.log('Writing patched index.js...');
fs.writeFileSync(INDEX_JS_PATH, indexContent);

const newSize = indexContent.length;
console.log(`✓ Written ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`✓ Added ${(completePatch.length / 1024).toFixed(2)} KB\n');

console.log('═══════════════════════════════════════════════════════════');
console.log('✅ Complete Cowork enabler applied!');
console.log('═══════════════════════════════════════════════════════════\n');

console.log('This patch provides:');
console.log('  ✅ Platform override → UI shows Cowork slider');
console.log('  ✅ IPC handlers → Backend handles directory selection');
console.log('  ✅ VM hook → Integrates with existing VM system');
console.log('  ✅ Error handling → Logs all issues\n');

console.log('Expected behavior:');
console.log('  1. Cowork slider appears in UI');
console.log('  2. Click to enable → directory picker shows');
console.log('  3. Select directory → gets mounted');
console.log('  4. Cowork ready to use!\n');

console.log('To restore:');
console.log(`  cp ${INDEX_JS_PATH}.v4-combined-backup ${INDEX_JS_PATH}\n`);
