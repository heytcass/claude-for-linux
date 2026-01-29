# Claude Desktop Cowork for Linux - File Index

## 📂 Complete File Listing

All files related to the Cowork Linux implementation are in `/tmp/`. This index helps you find what you need.

---

## 🚀 Getting Started (Read First!)

### **COWORK_README.md** (8.6K)
**START HERE!** Quick start guide with everything you need to know.
- What Cowork is
- Quick install instructions
- How to use it
- Common use cases
- Troubleshooting basics

**Use when**: You want to get Cowork working fast.

---

## 📦 Installation Files

### **install-cowork-linux.sh** (4.7K)
**Automated installer** - Run this to install Cowork.

```bash
chmod +x /tmp/install-cowork-linux.sh
./tmp/install-cowork-linux.sh
```

**What it does**:
1. Checks prerequisites
2. Installs bubblewrap
3. Backs up current installation
4. Extracts, patches, repacks app.asar
5. Installs patched version
6. Verifies installation

**Use when**: You want automatic installation.

---

## 🔧 Core Implementation Files

### **claude-cowork-linux.js** (8.9K)
**Session manager and bubblewrap wrapper**

**Contains**:
- `CoworkSessionManager` class
- `VMCompatibilityAdapter` class
- Session management logic
- Sandbox process spawning
- Directory mounting

**Use when**: You need to understand or modify the core implementation.

### **patch-cowork-linux-v2.js** (5.3K)
**Patcher that modifies Claude Desktop**

**What it does**:
- Injects claude-cowork-linux module
- Adds VM interceptor
- Patches dialog handling
- Adds availability checks

**Use when**: You need to manually patch or update the implementation.

**Note**: `patch-cowork-linux.js` (5.6K) is v1 - use v2 instead.

---

## 📚 Documentation

### **COWORK_SUMMARY.md** (12K)
**Complete implementation overview**

**Covers**:
- Architecture diagrams
- Component descriptions
- Flow diagrams
- Security analysis
- Performance metrics
- Integration guide

**Use when**: You want to understand how everything works together.

### **COWORK_INSTALLATION.md** (7.5K)
**Detailed installation guide**

**Includes**:
- Prerequisites
- Step-by-step installation
- Testing procedures
- Troubleshooting
- Advanced configuration
- Integration with updates

**Use when**: You need detailed installation instructions or encounter issues.

### **cowork-research.md** (4.4K)
**Technical research and design decisions**

**Contains**:
- macOS implementation analysis
- Linux adaptation strategies
- Technology comparisons
- Implementation plan
- Files to create/modify

**Use when**: You want to understand the "why" behind design decisions.

---

## ✅ Testing & Validation

### **cowork-validation-checklist.md** (5.1K)
**Comprehensive testing checklist**

**Sections**:
- Pre-installation validation
- Installation validation
- Functionality testing (6 levels)
- Security validation
- Performance testing
- Rollback testing
- Final sign-off

**Use when**: You need to verify everything works correctly.

---

## 📖 File Purpose Quick Reference

| File | Purpose | When to Use |
|------|---------|-------------|
| **COWORK_README.md** | Quick start | Getting started |
| **install-cowork-linux.sh** | Automated installer | Installing |
| **claude-cowork-linux.js** | Core implementation | Understanding/modifying code |
| **patch-cowork-linux-v2.js** | Patcher script | Manual patching |
| **COWORK_SUMMARY.md** | Complete overview | Understanding architecture |
| **COWORK_INSTALLATION.md** | Detailed install guide | Troubleshooting |
| **cowork-research.md** | Research & design | Understanding decisions |
| **cowork-validation-checklist.md** | Testing checklist | Validation |
| **COWORK_INDEX.md** | This file | Finding files |

---

## 🎯 Common Scenarios

### "I just want to install Cowork"
1. Read: `COWORK_README.md` (5 minutes)
2. Run: `install-cowork-linux.sh`
3. Test: Use the examples in README

### "Installation failed, need help"
1. Check: `cowork-validation-checklist.md` (pre-installation section)
2. Read: `COWORK_INSTALLATION.md` (troubleshooting section)
3. Review: Installation script output

### "I want to understand how it works"
1. Start: `COWORK_SUMMARY.md` (architecture)
2. Read: `cowork-research.md` (design decisions)
3. Study: `claude-cowork-linux.js` (implementation)

### "Something's not working right"
1. Use: `cowork-validation-checklist.md` (find which test fails)
2. Check: `COWORK_INSTALLATION.md` (troubleshooting)
3. Review: `COWORK_SUMMARY.md` (how it should work)

### "I want to modify the implementation"
1. Understand: `cowork-research.md` (design)
2. Review: `claude-cowork-linux.js` (current code)
3. Modify: Make changes
4. Test: Use `cowork-validation-checklist.md`
5. Patch: Run `patch-cowork-linux-v2.js`

### "I need to integrate with updates"
1. Read: `COWORK_INSTALLATION.md` (integration section)
2. Modify: `/opt/claude-desktop/update-claude-desktop.sh`
3. Test: Run update script

---

## 📏 File Sizes

Total implementation: ~56KB of documentation and code

```
Documentation:
  COWORK_README.md             8.6K  (Quick start)
  COWORK_SUMMARY.md           12.0K  (Complete overview)
  COWORK_INSTALLATION.md       7.5K  (Detailed guide)
  cowork-research.md           4.4K  (Research notes)
  cowork-validation-checklist  5.1K  (Testing)
  COWORK_INDEX.md              [this file]

Code:
  claude-cowork-linux.js       8.9K  (Core implementation)
  patch-cowork-linux-v2.js     5.3K  (Patcher)
  install-cowork-linux.sh      4.7K  (Installer)
```

---

## 🔗 Dependencies Between Files

```
install-cowork-linux.sh
  ├── Requires: claude-cowork-linux.js
  ├── Requires: patch-cowork-linux-v2.js
  └── References: COWORK_INSTALLATION.md

patch-cowork-linux-v2.js
  └── Installs: claude-cowork-linux.js into app.asar

COWORK_README.md
  ├── References: COWORK_INSTALLATION.md
  ├── References: COWORK_SUMMARY.md
  └── References: cowork-validation-checklist.md

COWORK_INSTALLATION.md
  ├── Uses: install-cowork-linux.sh
  └── References: cowork-validation-checklist.md

COWORK_SUMMARY.md
  ├── Describes: claude-cowork-linux.js
  ├── Describes: patch-cowork-linux-v2.js
  └── References: cowork-research.md
```

---

## 🎓 Reading Order

### For Users (Just Want It Working)
1. `COWORK_README.md` - Understand what it is
2. `install-cowork-linux.sh` - Run installer
3. `cowork-validation-checklist.md` - Verify it works
4. `COWORK_INSTALLATION.md` - If issues arise

### For Developers (Want to Understand)
1. `cowork-research.md` - Background and design
2. `COWORK_SUMMARY.md` - Architecture overview
3. `claude-cowork-linux.js` - Core implementation
4. `patch-cowork-linux-v2.js` - Integration method
5. `COWORK_INSTALLATION.md` - Deployment details

### For Testers
1. `COWORK_README.md` - Quick overview
2. `install-cowork-linux.sh` - Install
3. `cowork-validation-checklist.md` - Test systematically
4. `COWORK_INSTALLATION.md` - Troubleshoot issues

---

## 🗂️ Where Files Go

### During Installation

**Source** (`/tmp/`):
- All files start here
- Safe to delete after installation

**Installation** (`/opt/claude-desktop/`):
```
/opt/claude-desktop/
  ├── app.asar                    # Patched version
  ├── app.asar.pre-cowork        # Backup
  └── modules/
      ├── claude-cowork-linux.js
      └── patch-cowork-linux-v2.js
```

**Runtime** (`/tmp/claude-cowork-sessions/`):
```
/tmp/claude-cowork-sessions/
  └── {session-id}/
      ├── mnt/
      └── session.json
```

---

## 🔄 Update Workflow

1. **New Claude Desktop version released**
2. Run update script
3. If Cowork integration added to update script:
   - Automatically re-applies patches
4. If not:
   - Re-run: `install-cowork-linux.sh`

---

## 📋 Checklist: Do I Have Everything?

Run this to verify all files are present:

```bash
cd /tmp
ls -lh COWORK_*.md claude-cowork-linux.js patch-cowork-linux-v2.js \
       install-cowork-linux.sh cowork-*.md

# Should show 9 files:
# - COWORK_README.md
# - COWORK_SUMMARY.md
# - COWORK_INSTALLATION.md
# - COWORK_INDEX.md
# - claude-cowork-linux.js
# - patch-cowork-linux-v2.js
# - install-cowork-linux.sh
# - cowork-research.md
# - cowork-validation-checklist.md
```

---

## 🎉 Quick Start (TL;DR)

```bash
# 1. Read the README (5 min)
cat /tmp/COWORK_README.md

# 2. Run the installer
chmod +x /tmp/install-cowork-linux.sh
./tmp/install-cowork-linux.sh

# 3. Launch and test
claude-desktop
# Then ask: "Can you help me work with files in my Documents?"

# 4. If issues, check
cat /tmp/COWORK_INSTALLATION.md  # Troubleshooting section
```

---

## 💾 Backup This Documentation

These files document a complete implementation. Consider backing them up:

```bash
# Create backup
mkdir -p ~/claude-cowork-docs
cp /tmp/COWORK_*.md ~/claude-cowork-docs/
cp /tmp/cowork-*.md ~/claude-cowork-docs/
cp /tmp/claude-cowork-linux.js ~/claude-cowork-docs/
cp /tmp/patch-cowork-linux-v2.js ~/claude-cowork-docs/
cp /tmp/install-cowork-linux.sh ~/claude-cowork-docs/

echo "Backup created in ~/claude-cowork-docs/"
```

---

## 📧 File Manifest

Complete file list with checksums:

```bash
cd /tmp
md5sum COWORK_*.md cowork-*.md *.js *.sh 2>/dev/null | grep -E "cowork|COWORK"
```

---

**Last Updated**: 2026-01-29
**Implementation**: Ralph Loop Iteration 1
**Total Files**: 9
**Total Size**: ~56KB

---

**Need help? Start with `COWORK_README.md`! 🚀**
