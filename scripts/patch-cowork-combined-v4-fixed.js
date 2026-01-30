#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork Complete Enabler V4 ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log('Size: ' + (originalSize / 1024 / 1024).toFixed(2) + ' MB\n');

fs.writeFileSync(INDEX_JS_PATH + '.v4-backup', indexContent);
console.log('Backup created\n');

const patch = `
;(function(){
  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;
  if (!global.__linuxCowork) return;

  console.log('[Cowork UI] Enabling for Linux...');

  // Platform override for UI
  const orig = process.platform;
  let override = false;
  Object.defineProperty(process, 'platform', {
    get: () => override ? 'darwin' : orig,
    configurable: true
  });

  override = true;
  setTimeout(() => { override = false; }, 5000);

  // IPC handlers
  try {
    const {ipcMain, dialog} = require('electron');
    ['cowork:requestDirectory', 'request_cowork_directory'].forEach(ch => {
      ipcMain.handle(ch, async () => {
        const r = await dialog.showOpenDialog({properties: ['openDirectory']});
        if (r.canceled) return {canceled: true};
        const sid = require('crypto').randomUUID();
        global.__linuxCowork.manager.addMount(sid, r.filePaths[0]);
        return {success: true, sessionId: sid, path: r.filePaths[0]};
      });
    });
    console.log('[Cowork UI] IPC handlers registered');
  } catch(e) {
    console.error('[Cowork UI] IPC error:', e);
  }

  console.log('[Cowork UI] Active');
})();
`;

indexContent += patch;
fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V4 patch applied\n');
