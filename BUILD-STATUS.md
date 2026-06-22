# Build Status & Next Steps

Last updated: 2026-06-22

## Current State

### Working
- **Full build completes** — 1169 elements build successfully
- **KDE Plasma 6.8 Dev desktop** loads with proper fonts and wallpaper
- **plasma-login-manager** login screen works — SDDM fully replaced (see fixed #1)
- **Network, System Settings** functional
- **Qt6 6.11.1** auto-tracked via git_repo with `track: 'v6.*'`
- **KDE Frameworks/Plasma/Apps** tracked to latest master
- **Vulkan-headers 1.4.354** override resolves kwin RAII compat issues
- **Local tracking script** (`scripts/track-refs-local.sh`) reliably updates all refs
- **OCI image** builds correctly — all fixes verified inside the container
- **Runtime dependency audit complete** — kde/apps and kde/plasma elements now declare
  app-specific runtime libs in `depends:` (cross-checked against Arch PKGBUILD).

### Known Issues (Priority Order)

#### 1. plasma-login-manager Migration (FIXED 2026-06-22)
SDDM replaced by `plasma-login-manager`. Element `kde/plasma/plasma-login-manager.bst`
builds and links cleanly (KCMUtils + libPlasma link-closure build-depends resolved).
PLM ships its own PAM configs to `/usr/lib/pam.d/` (immutable `/usr`), eliminating the
SDDM `/etc/pam.d/sddm*` bootc workaround entirely. System-config wires `plasmalogin.service`
as the display manager with a service drop-in for software rendering in VMs.

#### 2. Runtime Dependency Audit (FIXED 2026-06-22)
- `konsole` → `core-deps/libssh.bst` runtime dep (fixed upstream)
- `kcalc` → gmp/mpfr/mpc runtime deps added to `depends:`
- `gwenview` → jpeg/png/tiff/lcms/exiv2, `okular` → libtiff, `kate` → gpgmepp,
  `kdeconnect` → libei/libevdev/libfakekey, `ark` → libarchive,
  `libksysguard` → libnl, `kpipewire` → ffmpeg, `spectacle` → ffmpeg/libva
- Cross-checked against Arch PKGBUILD `depends()` for kde/apps + kde/plasma.

#### 3. Empty Application Launcher + Missing Default Apps (FIX PENDING BUILD)
The "All Applications" launcher is empty and System Settings → Default Apps doesn't
recognize installed KDE apps (terminal, file manager) because:
- `/etc/xdg/menus/applications.menu` is missing → the menu system has no definition to
  categorize applications. KRunner (Alt+F2) works because it queries .desktop files
  directly without the menu hierarchy.
- `kbuildsycoca6` has not been run to index the .desktop files into the service cache.

**Fix applied** (commit cef4521+): `system-config.bst` now installs `applications.menu`
to `/etc/xdg/menus/` (child layer, survives bootc), and `oci/tromso.bst` runs
`kbuildsycoca6 --noincremental` in the merged rootfs at OCI assembly time. Pending
build + VM verification.

#### 4. bootc Deployment Loses `/etc` Files (PARTIALLY RESOLVED)
Previously affected `/etc/pam.d/sddm*`, `/etc/xdg/menus/applications.menu`,
and `/etc/sddm.conf.d/wayland.conf`. SDDM configs eliminated by PLM migration.
Applications menu now installed in child layer `/etc/xdg/menus/`.
Remaining: `/etc/fonts/fonts.conf` — fontconfig config (still needs audit).

#### 5. Locale Warnings (LOW)
Qt reports: "Detected locale 'C' with character encoding 'ANSI_X3.4-1968'".
Not a blocker but should be fixed by installing locale data or setting
`LANG=C.UTF-8` in the environment.

---

## Post-Boot Workaround Script

Most previous workarounds are now baked into the build (applications.menu,
kbuildsycoca6, plasma-login-manager PAM configs).  After each
`just generate-bootable-image` + `just boot-vm`, only the user creation
step is still needed:

```bash
ssh -p 2222 root@127.0.0.1

# Create user (still manual until first-boot user setup is automated)
useradd -m -G video,render,input,audio -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd

# The application menu and kbuildsycoca6 cache are now pre-built in the
# image.  If the launcher still shows no apps after the next build, run:
#   ssh -p 2222 aurora@127.0.0.1
#   kbuildsycoca6 --noincremental
#   systemctl --user restart plasma-plasmashell
```

---

## Key Modifications Made to kde-build-meta-x

| Change | Reason |
|--------|--------|
| `core-deps/vulkan-headers.bst` override (1.4.354) | kwin RAII structured binding compat |
| `core-deps/libssh.bst` new element | Konsole SSH support |
| Qt6 tar→git_repo conversion (30 elements) | Auto-tracking via `v6.*` |
| `qt6-qtbase.bst` fontconfig/freetype/harfbuzz/libpng deps | Font rendering |
| `qt6-qttools.bst` disable Qt Assistant | Missing qlitehtml submodule |
| `qt6-qt3d.bst` disable assimp | Missing assimp submodule |
| `qt6-qtgraphs.bst` new element | kinfocenter graphs |
| `kwin.bst` patches (killer, qqml-include) | Build fixes |
| `kwin.bst` vulkan-icd-loader + kitemmodels deps | Missing build/link deps |
| Freedesktop-sdk kernel config patches removed | aarch64-only, broke x86_64 |
| Various plasma-workspace/konsole patches removed | Fixed upstream |
| kirigami-addons unpinned to track master | Needed by plasma-nm |

## Build & Test Commands

```bash
# Track all refs to latest upstream
bash scripts/track-refs-local.sh

# Build
BST_FLAGS="--no-interactive" just bst build oci/tromso.bst && just export

# Generate VM image
rm -f bootable.raw bootable.qcow2
just generate-bootable-image
qemu-img convert -f raw -O qcow2 bootable.raw bootable.qcow2

# Boot VM
just boot-vm

# SSH access
ssh -p 2222 root@127.0.0.1      # root (password: aurora)
ssh -p 2222 aurora@127.0.0.1    # user (password: aurora)

# VNC display
# Connect to 127.0.0.1:5900
```
