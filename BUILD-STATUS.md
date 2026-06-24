# Build Status & Next Steps

Last updated: 2026-06-24

## Current State

### Working
- **Two build targets**: `oci/tromso.bst` (Aurora overlay) and `oci/kde-minimal.bst` (pure KDE)
  - `just build` / `just build-kde` — full build + export
  - `just generate-bootable-image` / `just generate-bootable-kde` — VM disk image
- **KDE Plasma 6.7.80 desktop** loads with fonts and wallpaper
- **plasma-login-manager** login screen works — SDDM fully replaced
- **Network, System Settings, Konsole** functional
- **Discover connects to Flathub** and shows remote apps
- **Discover "Installed" tab** shows system apps (FIXED 2026-06-24)
- **CA certificates** work for TLS connections
- **Local `just` recipes** for both Aurora and minimal KDE images
- **OCI image** builds and boots correctly via bootc

### Fixed Issues

#### 1. OCI /etc vs /usr/etc Convention (FIXED 2026-06-23)
bootc requires exactly one of `/etc` or `/usr/etc` in the OCI image. Previously
`kde-linux/image.bst` and `tromso.bst` used opposite conventions, causing "Tree
contains both /etc and /usr/etc" deployment errors. Fixed with parent-aware
normalization in both image builders that matches each layer to its parent.

#### 2. Sudo setuid (FIXED 2026-06-23)
The compose step strips the setuid bit from `/usr/bin/sudo`. Added `chmod u+s`
in the OCI build script as a safety net.

#### 3. systemd-homed D-Bus Activation (FIXED 2026-06-23)
`systemd-homed.service` was masked but its D-Bus activation file
(`dbus-org.freedesktop.home1.service`) was still active, causing accountsservice
to trip over a broken home1 activation during user enumeration. Masked all homed
services and their sub-services.

#### 4. CA Certificates (FIXED 2026-06-23)
CA certs were installed to `/etc/pki/` which bootc's tmpfs overlay hides at runtime.
Fixed by installing certs to `/usr/etc/pki/` and ensuring the `/usr/etc/` convention
is used consistently.

#### 5. Sycoca / XDG Menu Not Found (FIXED 2026-06-24)
`kde-settings.sh` was overriding `XDG_CONFIG_DIRS` without including `/etc/xdg`.
This prevented the XDG menu system from finding `applications.menu`, causing
both the launcher and Discover's "Installed" tab to show nothing. Fixed by
always including `/etc/xdg` in the XDG_CONFIG_DIRS path. Also added
`KDEDIRS=/usr` and `KDE_FULL_SESSION=true` to match working KDE hosts.

#### 6. Flatpak User Install (FIXED 2026-06-24)
Two issues prevented non-root users from installing Flatpaks:
1. **Polkit**: the default flatpak polkit rule only covers `app-install`,
   `runtime-install`, etc. — not internal operations `Deploy` and `GetRevokefsFd`.
   Added `99-flatpak-wheel.rules` allowing all `org.freedesktop.Flatpak.*` actions
   for active wheel-group members (dropping `subject.local` which is unreliable on bootc).
2. **fusermount3**: the compose step strips setuid bits. Added `chmod u+s`
   on fusermount3 so non-root users can mount/unmount FUSE filesystems during
   flatpak installation.

#### 7. plasma-desktop X11 Build (FIXED 2026-06-24)
`BUILD_X11=OFF` was disabling the entire kickoff/kicker/taskmanager plasmoid build.
Changed to `ON`; the X11 headers were already in build-depends, so this added no
new runtime dependencies. The plasmoids are compiled as `.so` plugins at
`/usr/lib/plugins/plasma/applets/`.

### Known Issues

#### 1. Application Launcher Empty (PARTIALLY FIXED — Discover works, kickoff/kicker does not)
**Fixed**: Discover's "Installed" tab now shows system applications (the XDG menu fix).

**Still broken**: The kickoff/kicker application launcher in the Plasma panel shows no
applications. KRunner similarly cannot find installed desktop apps.

**Evidence gathered (2026-06-24):**
- Sycoca cache is correct: `kbuildsycoca6 --menutest` shows 24 apps even from
  plasmashell's exact environment
- kickoff/kicker `.so` plugins are installed and loaded by plasmashell
- kded6 is running with 19 modules, properly maintains the sycoca cache
- `KApplicationTrader::query` (the method kickoff/kicker/krunner use) returns
  empty results even though the sycoca cache has valid entries
- Both plasmashell and kbuildsycoca6 link the SAME `libKF6Service.so.6`
- The hash mismatch bug in kservice (`7e01820`, March 2026) is fixed in our build

**Ruled out**:
- Aurora overlay is NOT the cause (kde-minimal build has same issue)
- Missing plasmoid files (they're compiled `.so` plugins, not QML files)
- Locale / LANG issues (set to `en_US.UTF-8`)
- Compose filtering (all plugins present)
- Sycoca cache corruption (verified correct)
- KService version mismatch (same library linked everywhere)

**Comparison with working host** (Plasma 6.7.80):
- Host sycoca cache: 628-691KB vs VM: 226-396KB
- Host XDG_CONFIG_DIRS includes `/etc/xdg` (now fixed on VM)
- Host has `KDE_FULL_SESSION=true` and `KDEDIRS=/usr` (now set on VM)
- Host has 29 kded6 modules vs VM 19 (additional KDE packages)
- Host kservices6: 0 files (same as VM — no system-level service types)
- Host desktop files: 208 vs VM: 136

**Recommended next step**: After rebuild with the `XDG_CONFIG_DIRS`, `KDEDIRS`,
and `KDE_FULL_SESSION` fixes, test the launcher again. If still broken, the
next investigation should focus on what `KApplicationTrader::query` does
internally vs what `--menutest` does differently. The sycoca cache is correct
but the launcher model doesn't consume it.

#### 2. Unprivileged User Namespaces (UNRESOLVED)
Flatpak `run` shows "CanCreateUserNamespace() clone() failure: EPERM". This
means unprivileged user namespaces are restricted on this kernel. Flatpak apps
can be installed (with the polkit + fusermount fixes) but may fail at runtime.
May need `kernel.unprivileged_userns_clone=1`.

#### 3. Tracker Dependencies (kcm_plasmalogin) (UNRESOLVED, LOW PRIORITY)
`Could not unmount revokefs-fuse` errors during flatpak install (cosmetic,
flatpaks install successfully despite the warning).

## Tracking Strategy

All KDE elements track `master` (git HEAD). Using `refs/tags/v6.*.?` to pin
to stable releases was attempted but abandoned because:
- BST tracking across junctions requires `project.refs` (not configured)
- The pattern `v6.*.?` excludes pre-release tags (`.90`, `-rc`) but tracking
  from within kde-build-meta-x failed due to container image issues
- Pinng plasma-desktop/plasma-workspace to `v6.7.1` caused API skew with
  master-tracked deps (link-time Xcursor dependency failures)
- Tracking from tromso_x is blocked by junction boundaries
- The `scripts/track-refs-local.sh` script uses a BST session limit of 50

## Key Build Changes

| File | Change | Date |
|------|--------|------|
| `elements/oci/tromso.bst` | Parent-aware /etc normalization, sudo setuid, fusermount3 setuid | 2026-06-23/24 |
| `elements/oci/kde-linux/image.bst` | Parent-aware /etc normalization (matching) | 2026-06-23 |
| `elements/tromso/system-config.bst` | /etc/xdg in XDG_CONFIG_DIRS, KDEDIRS, KDE_FULL_SESSION, homed masks, flatpak polkit rule, LANG env | 2026-06-23/24 |
| `elements/oci/kde-minimal.bst` | New minimal KDE-only build target | 2026-06-24 |
| `elements/tromso/deps-minimal.bst` | Minimal deps for kde-minimal | 2026-06-24 |
| `.github/workflows/update-refs.yml` | Updated tracking description | 2026-06-23 |

### kde-build-meta-x Changes

| Change | Reason |
|--------|--------|
| `plasma-desktop.bst` BUILD_X11=ON | Enable kickoff/kicker plasmoid build |
| `plasma-desktop.bst` / `plasma-workspace.bst` url: github:KDE | KDE GitHub mirror (invent.kde.org unreachable from BST container) |
| `plasma-login-manager.bst` xorg-lib-xcursor build-dep | v6.7.1 libklookandfeel requires Xcursor at link time |

## Build & Test Commands

```bash
# Aurora (full) build
BST_FLAGS="--no-interactive" just bst build oci/tromso.bst && just export
just generate-bootable-image && just boot-vm

# Minimal KDE build
just build-kde
just generate-bootable-kde
just boot-vm

# SSH access
ssh -p 2222 root@127.0.0.1      # root (password: aurora)
ssh -p 2222 aurora@127.0.0.1    # user (password: aurora)

# Create user
useradd -m -G video,render,input,audio,wheel -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd
```
