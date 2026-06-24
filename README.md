# Aurora Tromso — KDE Linux OCI/bootc Image

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

**Aurora Tromso** is a BuildStream-based KDE Linux OCI/bootc image, modeled on Project Bluefin's
[`projectbluefin/dakota`](https://github.com/projectbluefin/dakota). It builds KDE Plasma 6 on top
of freedesktop-sdk and publishes a bootable OCI image.

*All of the heavy lifting and original thought is being done upstream at the [Tromso repo](https://github.com/tuna-os/tromso). This Tromso_x fork has a different focus on using the latest KDE, Qt6, and linux packages to produce a "leading edge" rolling release of Tromso.*

Tromso_x's companion repo is [whelanh/kde-build-meta-x](https://github.com/whelanh/kde-build-meta-x).

The workflow is done locally on your own machine and is described in [MANUAL_UPDATES.md](MANUAL-UPDATES.md).

**Status: 2026-06-24: Builds successfully and boots to a working KDE Plasma 6.7.80 Wayland desktop
with functional application launcher, KRunner, Discover, and Flatpak support.
Non-root users can install and run Flatpak apps. See [BUILD-STATUS.md](BUILD-STATUS.md) for details.**
<img width="3021" height="1767" alt="Screenshot_20260624_080720" src="https://github.com/user-attachments/assets/2abd4132-480c-4ef9-960f-ea6ed33a132a" />

## Architecture

Aurora Tromso uses a two-repo model:

```
whelanh/tromso_x          (this repo — Aurora customizations + OCI composition)
├── elements/
│   ├── kde-build-meta.bst    junction → whelanh/kde-build-meta-x
│   ├── tromso/               Aurora-specific layers (theming, apps, overlays)
│   ├── oci/tromso.bst        top-level build target (Aurora overlay)
│   └── oci/kde-minimal.bst   minimal KDE-only build target (no overlay)
└── Justfile

whelanh/kde-build-meta-x  (KDE .bst elements — KDE Linux base image)
└── elements/kde/
    ├── qt6/        (~30 elements — qt6-qtbase, qt6-qtdeclarative, etc.)
    ├── frameworks/  (~70 elements — kcoreaddons, kio, kirigami, etc.)
    ├── libs/        (~17 elements — libkscreen, qcoro, phonon, etc.)
    ├── plasma/      (~41 elements — plasma-workspace, kwin, plasma-desktop, etc.)
    └── apps/        (~13 elements — dolphin, kate, discover, okular, etc.)
```

## Quick Start

### Prerequisites

- Podman
- [`just`](https://github.com/casey/just) (task runner)
- ~100 GB free disk space for build cache

### Build (Aurora — full image with overlay)

```bash
git clone https://github.com/whelanh/tromso_x.git
cd tromso_x

# Build + export
just build

# Generate bootable VM image
just generate-bootable-image

# Boot in QEMU
just boot-vm
```

### Build (KDE Minimal — no Aurora overlay, faster)

```bash
# Build + export
just build-kde

# Generate bootable VM image  
just generate-bootable-kde

# Boot in QEMU
just boot-vm
```

### Boot a VM for testing

```bash
# SSH in (password: aurora)
ssh -p 2222 root@localhost

# Create a user for graphical login
useradd -m -G video,render,input,audio,wheel,flatpak -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd

# VNC viewer
# Connect to 127.0.0.1:5900
```

### Useful Justfile recipes

| Recipe | Description |
|---|---|
| `just build` | Build Aurora image + export |
| `just build-kde` | Build KDE Minimal image + export |
| `just bst-build` | Background build, logs to `/var/tmp/aurora-build.log` |
| `just export` | Export Aurora image to podman (`tromso:latest`) |
| `just export-kde` | Export KDE Minimal to podman (`tromso-kde:latest`) |
| `just log` | Tail the build log |
| `just generate-bootable-image` | Create bootable raw disk from Aurora image |
| `just generate-bootable-kde` | Create bootable raw disk from KDE Minimal image |
| `just boot-vm` | Boot the raw image in QEMU (SSH on port 2222, serial on 4444) |
| `just bst <args>` | Run any arbitrary `bst` command inside the build container |

## Updating KDE Packages

KDE package `.bst` definitions live in [`whelanh/kde-build-meta-x`](https://github.com/whelanh/kde-build-meta-x).
After committing there, update the junction ref in `elements/kde-build-meta.bst`:

```bash
# 1. Commit + push kde-build-meta-x
cd /path/to/kde-build-meta-x
TMPDIR=/var/tmp git commit -m "..."
git push origin master

# 2. Get new SHA and hash
SHA=$(git rev-parse HEAD)
SHORT=$(git rev-parse --short=7 HEAD)
curl -sL "https://github.com/whelanh/kde-build-meta-x/archive/${SHA}.tar.gz" | tee /tmp/kbm.tar.gz | sha256sum
BASE=$(tar tzf /tmp/kbm.tar.gz | head -1 | sed 's|/$||')

# 3. Update elements/kde-build-meta.bst with new url/ref/base-dir

# 4. Commit tromso_x
cd /path/to/tromso_x
rm -rf .bst/staged-junctions/kde-build-meta.bst
TMPDIR=/var/tmp git commit -m "junction: bump to kde-build-meta-x ${SHORT}"
```

See `AGENTS.md` for full conventions and workflows.

## References

- **[whelanh/kde-build-meta-x](https://github.com/whelanh/kde-build-meta-x)** — KDE .bst elements
- **[Project Bluefin dakota](https://github.com/projectbluefin/dakota)** — reference OCI/bootc implementation
- **[gnome-build-meta](https://gitlab.gnome.org/GNOME/gnome-build-meta)** — build patterns reference
- **[freedesktop-sdk](https://freedesktop-sdk.io/)** — base SDK
- **[BuildStream](https://www.buildstream.build/)** — build system
