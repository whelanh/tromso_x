# Next Actions - After plasma-workspace Build Completes

## ✅ Prerequisites (Already Done)
- [x] X11 support enabled in KWin (-DKWIN_BUILD_X11=ON)
- [x] X11 libraries added to KWin build-depends
- [x] Vulkan headers added for testing
- [x] plasma-workspace and kwin uncommented in aurora/deps.bst
- [x] Documentation prepared for all next steps

## 🚀 Immediate Next Steps (When Build Completes Successfully)

### Step 1: Update plasma-desktop.bst
**File**: `kde-build-meta-local/elements/kde/plasma/plasma-desktop.bst`

**Changes Required**:
```
Line 12 - Un-comment KWin:
  - kde/plasma/kwin.bst

Line 67-69 - Enable X11 KCM modules:
  -DBUILD_KCM_TABLET=ON
  -DBUILD_KCM_MOUSE_X11=ON
  -DBUILD_KCM_TOUCHPAD_X11=ON

Line 70 - Enable X11:
  -DWITH_X11=ON
```

### Step 2: Build plasma-desktop
```bash
just bst-build kde-build-meta-local.bst:kde/plasma/plasma-desktop.bst
```
Expected time: 30-45 minutes

### Step 3: Build Full Aurora OCI (once plasma-desktop succeeds)
```bash
just bst-build oci/aurora.bst
```
Expected time: 2-3 hours (full stack)

### Step 4: Create Bootable Image
```bash
just generate-bootable-image
```

### Step 5: Boot in VM and Test
```bash
just boot-vm
```

## 📋 Testing Checklist for VM

- [ ] System boots to login screen
- [ ] Can SSH to VM (ssh -p 2222 root@127.0.0.1)
- [ ] Plasma Wayland session available
- [ ] Plasma X11 session available (if testing both)
- [ ] Launch Dolphin (file manager)
- [ ] Launch Kate (text editor)
- [ ] Check no GNOME packages present
- [ ] Verify KDE Plasma desktop works smoothly

## 🎯 Build Decision Tree

### If plasma-workspace Compiled Successfully ✅
→ Proceed to Step 1 (Update plasma-desktop.bst)

### If plasma-workspace Failed ❌
**Check log for error type**:
- Vulkan-related error? → Remove vulkan-headers, rebuild plasma-workspace only
- X11 library error? → Check correct freedesktop-sdk paths, update build-depends
- Other cmake error? → Check Arch PKGBUILD for correct cmake flags

### If Vulkan Build Failed but X11 Works ✅
→ Remove vulkan-headers from KWin, keep X11 support, continue with plasma-desktop

### If Vulkan Build Succeeded ✅
→ Keep vulkan-headers in KWin build config, continue normally

## 📝 Key Files to Edit (in order)

1. `kde-build-meta-local/elements/kde/plasma/plasma-desktop.bst`
2. (Then commit before proceeding with next build)

## ⏱️ Expected Total Timeline

- plasma-workspace: 2-3 hours ⏳ (currently running)
- plasma-desktop: 30-45 min
- Full Aurora OCI: 2-3 hours
- Image creation: 10-15 min
- **Total**: ~6-8 hours from start of plasma-workspace build

---

**Status**: Waiting for plasma-workspace compilation
**Monitors**: Active - watching for KDE components build start
**Prepared**: All documentation and git commits ready for next phase
