#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V6: Both Processes Override ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
fs.writeFileSync(INDEX_JS_PATH + '.v6-backup', indexContent);

const patch = `
;(function(){
  // REMOVE the process type guard - run in BOTH main and renderer!
  if (process.platform !== 'linux') return;

  console.log('[Cowork V6] Overriding arch in', process.type, 'process');

  // Override BOTH platform and arch
  const origPlatform = process.platform;
  const origArch = process.arch;

  try {
    Object.defineProperty(process, 'platform', {
      get: () => 'darwin',
      configurable: true
    });

    Object.defineProperty(process, 'arch', {
      get: () => 'arm64',
      configurable: true
    });

    console.log('[Cowork V6]', process.type, '→ platform:', process.platform, 'arch:', process.arch);
  } catch(e) {
    console.error('[Cowork V6] Override failed:', e);
  }
})();
`;

indexContent += patch;
fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V6 both-processes override applied\n');
