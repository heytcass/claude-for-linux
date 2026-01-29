#!/usr/bin/env node
/**
 * Minimal Test: Process Type Guard
 *
 * Tests that our process.type guard prevents renderer execution.
 * This should NOT crash the renderer!
 */

const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Process Guard Test Patcher ===\n');

// Read index.js
console.log('Reading index.js...');
const indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
console.log(`Size: ${(indexContent.length / 1024 / 1024).toFixed(2)} MB\n`);

// Create backup
const backupPath = INDEX_JS_PATH + '.guard-test-backup';
console.log(`Creating backup: ${backupPath}`);
fs.writeFileSync(backupPath, indexContent);

// The test patch - MINIMAL and SAFE
const testPatch = `
;(function(){
  console.log('[CoworkGuardTest] START');
  console.log('[CoworkGuardTest] process.type =', process.type);
  console.log('[CoworkGuardTest] process.platform =', process.platform);

  if (process.type !== 'browser') {
    console.log('[CoworkGuardTest] RENDERER - Exiting safely');
    return;
  }

  console.log('[CoworkGuardTest] MAIN PROCESS - Would load Cowork here');
  console.log('[CoworkGuardTest] This should only appear in main process!');
})();
`;

// Append the test
const patchedContent = indexContent + testPatch;

// Write it
console.log('\nApplying test patch...');
fs.writeFileSync(INDEX_JS_PATH, patchedContent);

const newSize = patchedContent.length;
console.log(`New size: ${(newSize / 1024 / 1024).toFixed(2)} MB`);
console.log(`Added: ${(testPatch.length / 1024).toFixed(2)} KB\n`);

console.log('✅ Test patch applied!\n');
console.log('Now run Claude Desktop and check the console output.');
console.log('You should see:');
console.log('  - [CoworkGuardTest] messages in main process');
console.log('  - [CoworkGuardTest] RENDERER message from renderer');
console.log('  - [CoworkGuardTest] MAIN PROCESS message ONLY from main');
console.log('  - NO crashes!');
console.log('\nTo restore:');
console.log(`  cp ${backupPath} ${INDEX_JS_PATH}`);
