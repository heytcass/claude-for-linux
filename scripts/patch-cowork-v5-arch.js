#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V5: Architecture Override ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
fs.writeFileSync(INDEX_JS_PATH + '.v5-backup', indexContent);

const archPatch = `
;(function(){
  if (process.type !== 'browser') return;
  if (process.platform !== 'linux') return;
  if (!global.__linuxCowork) return;

  console.log('[Cowork V5] Adding architecture override...');

  // Override process.arch to report arm64 (Apple Silicon)
  const origPlatform = process.platform;
  const origArch = process.arch;
  let platformOverride = false;
  let archOverride = false;

  Object.defineProperty(process, 'platform', {
    get: () => platformOverride ? 'darwin' : origPlatform,
    configurable: true
  });

  Object.defineProperty(process, 'arch', {
    get: () => archOverride ? 'arm64' : origArch,
    configurable: true
  });

  // Enable BOTH overrides for initialization
  platformOverride = true;
  archOverride = true;
  console.log('[Cowork V5] Platform: darwin (fake), Arch: arm64 (fake)');

  // Keep them enabled (don't disable - UI needs to think we're Apple Silicon)
  setTimeout(() => {
    console.log('[Cowork V5] Overrides remain active for Cowork');
  }, 100);

})();
`;

indexContent += archPatch;
fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V5 architecture override applied\n');
