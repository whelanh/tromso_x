# Tromso ISO

Live ISO installer for [Tromso KDE Linux](https://github.com/hanthor/tromso) — a KDE Plasma 6 desktop built on freedesktop-sdk with bootc-powered atomic updates.

Based on [projectbluefin/dakota-iso](https://github.com/projectbluefin/dakota-iso).

## Architecture

Three-stage Containerfile build:

1. **`tromso-ref`** — pull `ghcr.io/hanthor/tromso:latest` (kernel modules source)
2. **`initramfs-builder`** — Debian: build a `dmsquash-live` initramfs against Tromso's kernel modules
3. **`final`** — Tromso image with replaced initramfs + SDDM autologin + `tuna-installer` + flatpaks

The ISO uses **systemd-boot** (no GRUB2, no shim). The live environment boots via `dmsquash-live` (squashfs + overlayfs), autologs into a **KDE Plasma** session as `liveuser`, and auto-launches the **tuna-installer** flatpak for graphical installation.

## Building Locally

Prerequisites: `podman`, `buildah`, `just`, `mtools`, `xorriso`, `skopeo`

```bash
# Build the live ISO
just iso-sd-boot tromso

# Output: output/tromso-live.iso
```

For background builds with logging:
```bash
just build-bg tromso
```

On machines with limited disk space, use an XFS loopback at `/mnt` for VFS import:
```bash
sudo just mount-xfs
sudo just workdir=/mnt iso-sd-boot tromso
```

## Installation

1. Write the ISO to USB: `dd if=output/tromso-live.iso of=/dev/sdX bs=4M status=progress`
2. Boot from USB
3. The **Tromso Installer** launches automatically in the live KDE session
4. Select your disk and install

## CI

Builds trigger on:
- Push to `tromso/**` or `justfile`
- Daily schedule (05:00 UTC) to pick up Tromso image updates
- `repository_dispatch` with type `oci-image-published` (triggered by `hanthor/tromso`)
- Manual `workflow_dispatch`

Built ISOs are published as [GitHub Releases](https://github.com/hanthor/tromso-iso/releases).

## Icons & Branding

Place icon files at:
```
tromso/src/icons/hicolor/{16,24,32,48,64,128,256,512}x{16,24,32,48,64,128,256,512}/apps/tromso.png
```

Place installer tour image at:
```
tromso/src/images/tromso-welcome.png
```

These are optional — the installer will fall back to generic assets if not present.
