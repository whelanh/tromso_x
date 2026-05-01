# Aurora SSH Bootable Image — Build Status Update

**Session Date:** 2026-04-27
**Status:** PROGRESSING - Transitive Qt6 fix verified; kscreenlocker fixed
**Goal:** Bootable VM and ISO with SSH support + KDE desktop apps

## ✅ Major Accomplishments Today

1.  **Qt6 Transitive Dependency Fix**: Moved critical system libraries in `qt6-qtbase.bst` to `depends`. This successfully unblocked `qt6-qtdeclarative`, `qt6-qtshadertools`, `qt6-qtsvg`, and `qt6-qtwayland`.
2.  **kscreenlocker X11 Linker Fix**: 
    - **Issue**: Linker failure `undefined reference to symbol 'XInternAtom'`.
    - **Root Cause**: `kscreenlocker` code in `greeterapp.cpp` was using X11 symbols guarded by `QT_CONFIG(xcb)` instead of our `HAVE_X11` flag.
    - **Fix**: Updated `patches/kscreenlocker/0004-guard-qx11application.patch` to use `#ifdef HAVE_X11`.
    - **Verification**: `kde/plasma/kscreenlocker.bst` built successfully.

## 🔨 Current Build Progress

- **Current Stage**: Building KDE Frameworks (`baloo`, `ktextwidgets`, `kpty`, etc.).
- **Next Milestone**: `plasma-workspace.bst` CMake configuration.

---

## 🔧 Infrastructure Note: Bootc

**Issue:** `bootc` still cannot be built locally due to Cargo networking restrictions.
**Workaround:** Focus on building the KDE OCI image first.

## 📊 Monitoring

```bash
# Monitor background build
tail -f /var/home/james/.cache/buildstream/logs/gnome/kde-plasma-plasma-workspace/*.log
```
