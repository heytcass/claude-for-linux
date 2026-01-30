#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V10: Patch vi() Function ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
const originalSize = indexContent.length;
console.log('Size: ' + (originalSize / 1024 / 1024).toFixed(2) + ' MB\n');

fs.writeFileSync(INDEX_JS_PATH + '.v10-backup', indexContent);

// Patch the vi() function to return our Linux VM
// Original: async function vi(){const t=await R_e();return(t==null?void 0:t.vm)??null}
const original = 'async function vi(){const t=await R_e();return(t==null?void 0:t.vm)??null}';

const replacement = `async function vi(){
  // LINUX: Return our bubblewrap session if active
  if(process.platform==="linux"&&global.__linuxCowork){
    console.log("[Cowork Linux] vi() called, vmInstance exists:", !!global.__linuxCowork.vmInstance);
    if(global.__linuxCowork.vmInstance){
      console.log("[Cowork Linux] Returning Linux VM instance");
      return global.__linuxCowork.vmInstance;
    }
  }
  const t=await R_e();return(t==null?void 0:t.vm)??null}`;

console.log('Searching for vi() function...');
if (indexContent.includes(original)) {
  indexContent = indexContent.replace(original, replacement);
  console.log('✅ Found and patched vi() function!\n');
} else {
  console.log('❌ vi() function not found in expected form\n');
}

fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V10 patch applied\n');
