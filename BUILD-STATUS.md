# Build Status & Next Steps

Last updated: 2026-06-30

## Current State

### Working
- **Two build targets**: `oci/tromso.bst` (Aurora overlay) and `oci/kde-minimal.bst` (pure KDE)
  - `just build` / `just build-kde` — full build + export
  - `just generate-bootable-image` / `just generate-bootable-kde` — VM disk image
- **KDE Plasma 6.7.80 desktop** loads with fonts and wallpaper
- **plasma-login-manager** login screen works — SDDM fully replaced
- **Application launcher (kickoff/kicker)** shows all installed apps (FIXED 2026-06-24)
- **KRunner** finds installed apps and newly-installed Flatpaks (FIXED 2026-06-24)
- **Discover "Installed" tab** shows Flatpaks
- **Panel icons** display correctly — no blank/white icons (FIXED 2026-06-24)
- **Non-root users can install Flatpak apps** via Discover or CLI (FIXED 2026-06-24)
- **Network, System Settings, Konsole** functional
- **CA certificates** work for TLS connections
- **Local `just` recipes** for both Aurora and minimal KDE images
- **OCI image** builds and boots correctly via bootc

### Fixed Issues

#### 1. Sudo setuid (FIXED 2026-06-23)
The compose step strips the setuid bit from `/usr/bin/sudo`. Added `chmod u+s`
in the OCI build script as a safety net.

#### 2. systemd-homed D-Bus Activation (FIXED 2026-06-23)
`systemd-homed.service` was masked but its D-Bus activation file
(`dbus-org.freedesktop.home1.service`) was still active, causing accountsservice
to trip over a broken home1 activation during user enumeration. Masked all homed
services and their sub-services.

#### 3. CA Certificates (FIXED 2026-06-23)
CA certs were installed to `/etc/pki/` which bootc's tmpfs overlay hides at runtime.
Fixed by installing certs to `/usr/etc/pki/` and ensuring the `/usr/etc/` convention
is used consistently.

#### 4. Launcher, KRunner, Discover Empty — Missing `/etc/xdg` in XDG_CONFIG_DIRS (FIXED 2026-06-24)
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

#### 5. Flatpak User Install (FIXED 2026-06-24)
Two issues prevented non-root users from installing Flatpaks:
1. **Polkit**: the default flatpak polkit rule only covers `app-install`,
   `runtime-install`, etc. — not internal operations `Deploy` and `GetRevokefsFd`.
   Added `99-flatpak-wheel.rules` allowing all `org.freedesktop.Flatpak.*` actions
   for active wheel-group members (dropping `subject.local` which is unreliable on bootc).
2. **fusermount3**: the compose step strips setuid bits. Added `chmod u+s`
   on fusermount3 so non-root users can mount/unmount FUSE filesystems during
   flatpak installation.

#### 6. plasma-desktop X11 Build (FIXED 2026-06-24)
`BUILD_X11=OFF` was disabling the entire kickoff/kicker/taskmanager plasmoid build.
Changed to `ON`; the X11 headers were already in build-depends, so this added no
new runtime dependencies. The plasmoids are compiled as `.so` plugins at
`/usr/lib/plugins/plasma/applets/`.

#### 7. Single-squash-layer export + `gzip: disabled` (FIXED 2026-06-29)
Following Dakota's pattern: export now uses `--squash-all` in `podman build` to
produce a single-layer final image. Build-OCI configs changed from `gzip: gzip`
to `gzip: disabled` (avoiding double-compression). This fixed the bootc
"Tree contains both /etc and /usr/etc" error on `bootc switch`.

#### 8. plasmalogin QML greeter crash in VMs (FIXED 2026-06-29)
`plasmalogin` uses Qt Quick for its login UI. On VM GPUs (virtio-gpu/QXL)
without hardware acceleration, Qt Quick crashes trying to initialize OpenGL.
Added `QT_QUICK_BACKEND=software` and `KWIN_COMPOSE=Q` environment to
plasmalogin via systemd drop-in in `kde-minimal.bst`.

#### 9. podman push config-blob-as-layer bug (WORKAROUND 2026-06-29)
Buildah 1.44.0 (podman 6.x) has a bug: `podman push` duplicates the image
config blob as an `application/octet-stream` layer in the manifest. When bootc
pulls the pushed image, it tries to extract the 1232-byte JSON config as a
rootfs layer, corrupting the deployment and causing cascading systemd service
failures. **Fix**: Use `skopeo copy` instead (or `just push-kde`/`just push`
recipes).

### Known Issues

#### 1. Unprivileged User Namespaces (UNRESOLVED)
Flatpak `run` shows "CanCreateUserNamespace() clone() failure: EPERM". This
means unprivileged user namespaces are restricted on this kernel. Flatpak apps
can be installed but may fail at runtime. May need `kernel.unprivileged_userns_clone=1`.

#### 2. Fusermount3 Warnings
`Could not unmount revokefs-fuse` warnings appear during flatpak install but
do not prevent successful installation. The warning is cosmetic.

#### 3. Flathub not auto-configured in OCI (FIXED 2026-06-29)
Discover showed "No Flatpak sources" on a fresh bootc deployment because Flathub
was only configured by the ISO installer (`install-flatpaks.sh`), not in the
base OCI image. Fixed by shipping `/etc/flatpak/remotes.d/flathub.flatpakrepo`
directly in the image.

#### 5. bootc deployment: "Tree contains both /etc and /usr/etc" (FIXED 2026-06-29)
**Root cause (corrected)**: `oci/kde-linux/image.bst` used multi-layer OCI with
`platform/image.bst` as parent (which has `/usr/etc`, OSTree convention) and
`filesystem.bst` as the added layer (which has `/etc`). Normalization only
touched the added layer, not the parent's lower layer. Extracting the parent's
*last* layer to check for `/usr/etc` missed content from *earlier* layers.

**Fix**: All OCI image builders (`image.bst`, `tromso.bst`, `kde-minimal.bst`)
now produce **single-layer** OCI images (Dakota's approach). The parent OCI's
rootfs is extracted from ALL layers, merged with the `/layer` content, then
normalized to `/etc` before `build-oci` creates a single-layer image with no
parent. This guarantees no `/usr/etc` exists anywhere in the final image.

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
| `elements/tromso/system-config.bst` | /etc/xdg in XDG_CONFIG_DIRS, KDEDIRS, KDE_FULL_SESSION, homed masks, flatpak polkit rule, LANG env | 2026-06-23/24 |
| `elements/oci/kde-minimal.bst` | New minimal KDE-only build target | 2026-06-24 |
| `elements/tromso/deps-minimal.bst` | Minimal deps for kde-minimal | 2026-06-24 |
| `.github/workflows/update-refs.yml` | Updated tracking description | 2026-06-23 |
| `Justfile` | Added build-kde, export-kde, generate-bootable-kde recipes | 2026-06-24 |
| `Justfile` | SUDO_CMD uses podman check (enables rootless), rootless→rootful image copy, policy.json mount, HOME=/root for bootc | 2026-06-28 |
| `elements/oci/kde-linux/image.bst` | Single-layer OCI (Dakota approach): extract all parent layers, merge, normalize to /etc | 2026-06-29 |
| `elements/oci/tromso.bst` | Single-layer OCI + Flathub repo config | 2026-06-29 |
| `elements/oci/kde-minimal.bst` | Single-layer OCI + Flathub repo config | 2026-06-29 |
| `Justfile`, `kde-minimal.bst`, `tromso.bst` | `--squash-all` export + `gzip:disabled` (Dakota pattern) | 2026-06-29 |
| `Justfile` | Added `push-kde`/`push` recipes using `skopeo copy` (buildah push bug workaround) | 2026-06-29 |
| `AGENTS.md` | Documented podman push buildah bug, skopeo workaround, gzip:disabled convention | 2026-06-29 |
| `kde-minimal.bst` | plasmalogin `QT_QUICK_BACKEND=software` drop-in for VM rendering | 2026-06-29 |

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

# Push to registry (use skopeo, NOT podman push — buildah bug)
just push-kde ghcr.io/whelanh/tromso-kde-min
```
