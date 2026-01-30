#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const EXTRACTED_DIR = process.argv[2] || '/tmp/app-extracted';
const INDEX_JS_PATH = path.join(EXTRACTED_DIR, '.vite/build/index.js');

console.log('=== Cowork V11: Replace Swift VM Module ===\n');

let indexContent = fs.readFileSync(INDEX_JS_PATH, 'utf8');
fs.writeFileSync(INDEX_JS_PATH + '.v11-backup', indexContent);

// Instead of intercepting $rt, replace the Swift VM module loading
// Original: fS=(async()=>{try{return Tf=(await import("@ant/claude-swift")).default
const original = 'fS=(async()=>{try{return Tf=(await import("@ant/claude-swift")).default';

const replacement = `fS=(async()=>{
  // LINUX: Return fake Swift module with our VM instance (MAIN PROCESS ONLY)
  if(process.type==="browser"&&process.platform==="linux"&&global.__linuxCowork&&global.__linuxCowork.vmInstance){
    console.log("[Cowork Linux] Returning fake Swift VM module");
    return Tf={vm:global.__linuxCowork.vmInstance};
  }
  try{return Tf=(await import("@ant/claude-swift")).default`;

console.log('Searching for Swift VM module loading...');
if (indexContent.includes(original)) {
  indexContent = indexContent.replace(original, replacement);
  console.log('✅ Found and patched Swift VM module loading!\n');
} else {
  console.log('❌ Swift VM module loading not found\n');
}

fs.writeFileSync(INDEX_JS_PATH, indexContent);
console.log('✅ V11 patch applied\n');
