# Build Status & Next Steps

Last updated: 2026-07-01

## Current State

### Working
- **Two build targets**: `oci/tromso.bst` (Aurora overlay) and `oci/kde-minimal.bst` (pure KDE)
  - `just build` / `just build-kde` — full build + export
  - `just generate-bootable-image` / `just generate-bootable-kde` — VM disk image
- **KDE Plasma 6.7.90 desktop** loads with fonts and wallpaper
- **plasma-login-manager** login screen works — SDDM fully replaced
- **Application launcher (kickoff/kicker)** shows all installed apps
- **KRunner** finds installed apps and newly-installed Flatpaks
- **Discover "Installed" tab** shows Flatpaks
- **Panel icons** display correctly — no blank/white icons
- **Non-root users can install Flatpak apps** via Discover or CLI
- **Network, System Settings, Konsole** functional
- **CA certificates** work for TLS connections
- **Local `just` recipes** for both Aurora and minimal KDE images
- **bootc switch deploys successfully** — `ghcr.io/whelanh/tromso-kde-min:latest` (FIXED 2026-07-01)

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

#### 5. Flatpak User Install (FIXED 2026-06-24)
Two issues prevented non-root users from installing Flatpaks:
1. **Polkit**: the default flatpak polkit rule only covers `app-install`,
   `runtime-install`, etc. — not internal operations `Deploy` and `GetRevokefsFd`.
   Added `99-flatpak-wheel.rules` allowing all `org.freedesktop.Flatpak.*` actions
   for active wheel-group members.
2. **fusermount3**: the compose step strips setuid bits. Added `chmod u+s`
   on fusermount3 so non-root users can mount/unmount FUSE filesystems during
   flatpak installation.

#### 6. plasma-desktop X11 Build (FIXED 2026-06-24)
`BUILD_X11=OFF` was disabling the entire kickoff/kicker/taskmanager plasmoid build.
Changed to `ON`; the X11 headers were already in build-depends, so this added no
new runtime dependencies. The plasmoids are compiled as `.so` plugins at
`/usr/lib/plugins/plasma/applets/`.

#### 7. plasmalogin QML greeter crash in VMs (FIXED 2026-06-29)
`plasmalogin` uses Qt Quick for its login UI. On VM GPUs (virtio-gpu/QXL)
without hardware acceleration, Qt Quick crashes trying to initialize OpenGL.
Added `QT_QUICK_BACKEND=software` and `KWIN_COMPOSE=Q` environment to
plasmalogin via systemd drop-in.

#### 8. Flathub auto-config (FIXED 2026-06-29)
Discover showed "No Flatpak sources" on a fresh bootc deployment because Flathub
was only configured by the ISO installer. Fixed by shipping
`/etc/flatpak/remotes.d/flathub.flatpakrepo` directly in the OCI image.

#### 9. bootc deployment: "Tree contains both /etc and /usr/etc" (FIXED 2026-07-01)
**Root cause**: The OCI images were layered on top of
`oci/kde-linux/image.bst` as a parent OCI, which used a multi-layer composition
(freedesktop-sdk platform + KDE Linux filesystem). A 140-line Python script
tried to extract all the parent's OCI layers and merge them with the `/layer`
content into a single rootfs. This approach was fundamentally broken because:
1. Python's `tarfile` module cannot correctly process OCI whiteout entries
   (`.wh.*` markers that remove files from lower layers)
2. `shutil.rmtree` and `robust_merge` had edge cases with symlinks and overlayfs
3. The freedesktop-sdk platform's `/usr/etc` config leaked into `/etc`

**Fix**: Adopted `projectbluefin/dakota`'s self-contained OCI architecture:
- Removed the parent OCI dependency entirely — the compose layer is the
  complete rootfs with no layering
- Replaced the 140-line Python merge script with Dakota's 5-line shell:
  `cp -a /layer/usr/etc/. /layer/etc/ && rm -rf /layer/usr/etc`
- `build-oci` now uses `/layer` directly with no `parent:` field
- Export uses Dakota's `podman pull oci:` + `podman build --squash-all`
  + `podman push` pipeline

Result: `bootc switch ghcr.io/whelanh/tromso-kde-min:latest` deploys without
the `/etc`/`usr/etc` conflict. The image is 3.3 GB (down from 3.7 GB —
freedesktop-sdk platform whiteout bloat eliminated).

### Known Issues

#### Boot failure after deployment (investigating)
The image deploys via `bootc switch` but does not reach the login screen after
`systemctl reboot`. Systemd services fail during boot. This also affects
`projectbluefin/dakota` on this VM, suggesting a VM/configuration issue
rather than an image-specific bug.

## TODO

### Boot troubleshooting
Investigate the boot failure — compare service states with a working Dakota
deployment, check serial console output, review systemd journal for
failed services and ordering cycles.

### SELinux Integration
The image currently runs without mandatory access control. freedesktop-sdk
already ships `libselinux` and the kernel has SELinux built in. What's missing:
1. **SELinux policy packages** — add to the build stack (reference: gnome-build-meta)
2. **Filesystem labeling** — run `setfiles` to label the filesystem
3. **Kernel args** — add `selinux=1 security=selinux` to the bootc kargs

## Tracking Strategy

All KDE elements track `master` (git HEAD). See the tracking notes in
`kde-build-meta-x`. Using `refs/tags/v6.*.?` to pin to stable releases was
attempted but abandoned due to BST junction tracking limitations.

## Key Build Changes

| File | Change | Date |
|------|--------|------|
| `elements/oci/tromso.bst` | Parent-aware /etc normalization, sudo setuid, fusermount3 setuid | 2026-06-23/24 |
| `elements/tromso/system-config.bst` | /etc/xdg in XDG_CONFIG_DIRS, KDEDIRS, homed masks, flatpak polkit rule | 2026-06-23/24 |
| `elements/oci/kde-minimal.bst` | New minimal KDE-only build target | 2026-06-24 |
| `elements/tromso/deps-minimal.bst` | Minimal deps for kde-minimal | 2026-06-24 |
| `Justfile` | Added build-kde, export-kde, generate-bootable-kde recipes | 2026-06-24 |
| `Justfile` | Rootless→rootful image copy, policy.json mount, HOME=/root for bootc | 2026-06-28 |
| `elements/oci/kde-linux/image.bst` | Removed Python platform /usr/etc merge script (bugfix) | 2026-07-01 |
| `elements/oci/kde-minimal.bst` | Full rewrite: self-contained, no parent OCI, Dakota 5-line /usr/etc merge | 2026-07-01 |
| `elements/oci/tromso.bst` | Full rewrite: self-contained, no parent OCI, Dakota 5-line /usr/etc merge | 2026-07-01 |
| `Justfile` | Dakota export pipeline: podman pull + squash-all + podman push | 2026-07-01 |
| `Justfile` | Added `podman-push` recipe, updated `export-kde`/`push-kde` | 2026-07-01 |
| `AGENTS.md` | Documented self-contained OCI architecture, Dakota push pattern | 2026-07-01 |

### kde-build-meta-x Changes

| Change | Reason |
|--------|--------|
| `plasma-desktop.bst` BUILD_X11=ON | Enable kickoff/kicker plasmoid build |
| `plasma-desktop.bst` / `plasma-workspace.bst` url: github:KDE | KDE GitHub mirror (invent.kde.org unreachable from BST container) |
| `plasma-login-manager.bst` xorg-lib-xcursor build-dep | v6.7.1 libklookandfeel requires Xcursor at link time |

## Build & Test Commands

```bash
# Minimal KDE build (recommended for testing)
just build-kde

# Aurora (full) build
just build

# Push to registry
just push-kde ghcr.io/whelanh/tromso-kde-min

# Test on a bootc-enabled VM
sudo bootc switch ghcr.io/whelanh/tromso-kde-min:latest
```
