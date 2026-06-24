# Build Status & Next Steps

Last updated: 2026-06-24

## Current State

### Working
- **Two build targets**: `oci/tromso.bst` (Aurora overlay) and `oci/kde-minimal.bst` (pure KDE)
  - `just build` / `just build-kde` — full build + export
  - `just generate-bootable-image` / `just generate-bootable-kde` — VM disk image
- **KDE Plasma 6.7.80 desktop** loads with fonts and wallpaper
- **plasma-login-manager** login screen works — SDDM fully replaced
- **Application launcher (kickoff/kicker)** shows all installed apps (FIXED 2026-06-24)
- **KRunner** finds installed apps and newly-installed Flatpaks (FIXED 2026-06-24)
- **Discover connects to Flathub** and shows remote apps
- **Discover "Installed" tab** shows system apps (FIXED 2026-06-24)
- **Panel icons** display correctly — no blank/white icons (FIXED 2026-06-24)
- **Non-root users can install Flatpak apps** via Discover or CLI (FIXED 2026-06-24)
- **Network, System Settings, Konsole** functional
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

#### 5. Launcher, KRunner, Discover Empty — Missing `/etc/xdg` in XDG_CONFIG_DIRS (FIXED 2026-06-24)
**Root cause**: `kde-settings.sh` was overriding `XDG_CONFIG_DIRS` without including
`/etc/xdg`. This prevented the XDG menu system from finding `applications.menu`,
causing the launcher, KRunner, and Discover's "Installed" tab to show nothing.
`KDEDIRS=/usr` and `KDE_FULL_SESSION=true` were also missing — these are present
on every working KDE host and tell KDE it's in a full desktop session.

**Why it was hard to find**: The sycoca cache was correct and `kbuildsycoca6 --menutest`
showed all apps because it reads the menu file directly from the filesystem. But
plasmashell/kickoff/krunner use the XDG config search path to find the menu file,
and `/etc/xdg` wasn't in that path. The host comparison revealed the discrepancy.

**Also fixed**: `KDEDIRS=/usr` and `KDE_FULL_SESSION=true` added to match
working KDE hosts.

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

#### 1. Unprivileged User Namespaces (UNRESOLVED)
Flatpak `run` shows "CanCreateUserNamespace() clone() failure: EPERM". This
means unprivileged user namespaces are restricted on this kernel. Flatpak apps
can be installed but may fail at runtime. May need `kernel.unprivileged_userns_clone=1`.

#### 2. Fusermount3 Warnings (COSMETIC)
`Could not unmount revokefs-fuse` warnings appear during flatpak install but
do not prevent successful installation. The warning is cosmetic.

## TODO

### SELinux Integration
The image currently runs without mandatory access control. freedesktop-sdk
already ships `libselinux` and the kernel has SELinux built in. What's missing:

1. **SELinux policy packages** — add to the build stack (reference: gnome-build-meta
   already integrates SELinux)
2. **Filesystem labeling** — run `setfiles` to label the filesystem with the
   loaded policy in the OCI build script (after layer assembly, before `build-oci`)
3. **Kernel args** — add `selinux=1 security=selinux` to the bootc kargs
   (currently in `oci/tromso-ostree.bst` and the `generate-bootable-image` recipe)

The gnome-build-meta project provides the reference pattern for how to wire
SELinux into a freedesktop-sdk-based build.

## Tracking Strategy

All KDE elements track `master` (git HEAD). Using `refs/tags/v6.*.?` to pin
to stable releases was attempted but abandoned because:
- BST tracking across junctions requires `project.refs` (not configured)
- The pattern `v6.*.?` excludes pre-release tags (`.90`, `-rc`) but tracking
  from within kde-build-meta-x failed due to container image issues
- Pinning plasma-desktop/plasma-workspace to `v6.7.1` caused API skew with
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
| `Justfile` | Added build-kde, export-kde, generate-bootable-kde recipes | 2026-06-24 |

### kde-build-meta-x Changes

| Change | Reason |
|--------|--------|
| `plasma-desktop.bst` BUILD_X11=ON | Enable kickoff/kicker plasmoid build |
| `plasma-desktop.bst` / `plasma-workspace.bst` url: github:KDE | KDE GitHub mirror (invent.kde.org unreachable from BST container) |
| `plasma-login-manager.bst` xorg-lib-xcursor build-dep | v6.7.1 libklookandfeel requires Xcursor at link time |

## Build & Test Commands

```bash
# Aurora (full) build
just build
just generate-bootable-image && just boot-vm

# Minimal KDE build
just build-kde
just generate-bootable-kde
just boot-vm

# SSH access
ssh -p 2222 root@127.0.0.1      # root (password: aurora)
ssh -p 2222 aurora@127.0.0.1    # user (password: aurora)

# Create user
useradd -m -G video,render,input,audio,wheel,flatpak -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd
```
