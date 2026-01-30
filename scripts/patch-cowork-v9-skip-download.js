#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V9: Skip Bundle Download ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log('Size: ' + (originalSize / 1024 / 1024).toFixed(2) + ' MB\n');

fs.writeFileSync(INDEX_JS_PATH + '.v9-backup', indexContent);

// Patch the B_e bundle status check function
// Original: function B_e(t,e){const r=Ee.join(t,e)
const original = 'function B_e(t,e){const r=Ee.join(t,e)';

const replacement = `function B_e(t,e){
  // LINUX: Skip bundle check entirely
  if(process.platform==="linux"&&global.__linuxCowork){
    console.log("[Cowork Linux] Skipping bundle check - using bubblewrap");
    return{ready:!0};
  }
  const r=Ee.join(t,e)`;

console.log('Searching for B_e bundle status function...');
if (indexContent.includes(original)) {
  indexContent = indexContent.replace(original, replacement);
  console.log('✅ Found and patched B_e() function!\n');
} else {
  console.log('❌ B_e() function not found in expected form\n');
}

fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V9 patch applied\n');
