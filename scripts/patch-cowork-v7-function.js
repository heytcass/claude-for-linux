#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V7: Direct Function Patch ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log('Size: ' + (originalSize / 1024 / 1024).toFixed(2) + ' MB\n');

fs.writeFileSync(INDEX_JS_PATH + '.v7-backup', indexContent);

// Find and replace the m6() function check
const original = 'function m6(){return process.platform!=="darwin"?{status:"unsupported",reason:"Darwin only"}:process.arch!=="arm64"?{status:"unsupported",reason:"arm64';

const replacement = 'function m6(){if(process.platform==="linux"&&global.__linuxCowork)return{status:"supported"};return process.platform!=="darwin"?{status:"unsupported",reason:"Darwin only"}:process.arch!=="arm64"?{status:"unsupported",reason:"arm64';

console.log('Searching for m6() function...');
if (indexContent.includes(original)) {
  indexContent = indexContent.replace(original, replacement);
  console.log('✅ Found and patched m6() function!\n');
} else {
  console.log('❌ m6() function not found in expected form\n');
  console.log('Trying alternative patch...\n');
}

fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V7 patch applied\n');
