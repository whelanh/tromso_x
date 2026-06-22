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

#### 3. Empty Application Launcher + Sycoca / Desktop File Indexing (UNRESOLVED)
**Status: Root cause under investigation. Multiple attempted fixes on live VM — none
resolved the issue.**

**Symptoms:**
- Panel launcher "All Applications" shows no entries
- KRunner (Alt+F2) cannot find newly-installed apps (e.g. plasma-discover)
- Discover → Installed category shows "Nothing Found"
- System Settings → Default Apps doesn't recognize any installed apps
- `kbuildsycoca6 --noincremental` runs without error but produces a sycoca cache
  that doesn't include desktop-file entries

**Diagnostics performed (on live VM via SSH):**
- `/usr/share/applications/` — 142 `.desktop` files present and readable
- `/etc/xdg/menus/applications.menu` — present with correct `<DefaultAppDirs/>` content
- kded6 running, `XDG_DATA_DIRS` correctly set to `/usr/share:/usr/local/share`
- `kbuildsycoca6` runs and produces a 405KB cache file (when run with
  `LANG=C.UTF-8 XDG_DATA_DIRS`), but the launcher doesn't use it
- Multiple cache files (227KB + 405KB) coexist; kded6 appears to rebuild a
  smaller 227KB cache that lacks application entries, conflicting with the
  manually-built 405KB one
- `LANG=C` (not UTF-8) — Qt warns it switches to C.UTF-8 internally, but
  this locale mismatch may cause silent failures during desktop file parsing
- No CA certificates on the system (`/etc/ssl/certs/` empty) — causes
  Discover SSL errors but is a separate issue from the empty launcher

**Attempted fixes (all tested on live VM, none resolved the launcher issue):**
1. Install `/etc/xdg/menus/applications.menu` (the menu definition XML)
2. Run `kbuildsycoca6 --noincremental` at OCI build time in overlay chroot
3. Add XDG autostart `.desktop` that runs kbuildsycoca6 on user login
4. Set `XDG_DATA_DIRS=/usr/share:/usr/local/share` system-wide via
   `/etc/environment.d/50-aurora-xdg.conf`
5. Delete old caches, rebuild with `LANG=C.UTF-8 XDG_DATA_DIRS`, restart plasmashell
6. Rebuild cache, terminate session, log back in fresh
7. Set `LANG=C.UTF-8` in the autostart Exec line alongside XDG_DATA_DIRS

**Pushed build fixes (not yet verified with a fresh image):**
- `system-config.bst`: applications.menu + XDG autostart + `/etc/environment.d`
- `oci/tromso.bst`: applications.menu re-creation after prepare-image.sh,
  CA trust store generation (`update-ca-certificates`), flatpak-system-helper enabled
- `tromso/deps.bst`: `ca-certificates` added

**Working theories for root cause:**
1. KDE Plasma 6 sycoca format changes — the cache built by kbuildsycoca6
   may be in a format unrecognised by the running KDE session.
2. Locale (`LANG=C`) causes silent failures in desktop-file XML parsing;
   `C.UTF-8` is set but may not be sufficient without full locale data.
3. Composefs/bootc filesystem — the `.desktop` files in the read-only
   composefs layer may have metadata (xattrs, timestamps) that prevent
   sycoca from correctly indexing them.
4. Missing KDE infrastructure — some kded6 module or KService plugin that
   bridges desktop files into the application model may not be loaded.

**Recommended next investigative steps:**
- Rebuild with latest pushed fixes and test on a FRESH image (not the
  iteratively-modified VM which has accumulated conflicting state).
- Run `strace` on `kbuildsycoca6` (needs `strace` in the build) to trace
  which directories/files are actually opened during indexing.
- Compare with a working KDE Linux base image (without Aurora layer) to
  determine if the problem exists in the base image too.
- Install full locale data (`glibc-locales` or similar) and test with
  `LANG=en_US.UTF-8`.
- Check if `kded_ksycoca` or equivalent module exists and is loaded.
- Test running `plasmashell` with `QT_LOGGING_RULES=org.kde.ksycoca=true`
  for debug output about cache loading.

#### 4. bootc Deployment Loses `/etc` Files (PARTIALLY RESOLVED)
Previously affected `/etc/pam.d/sddm*`, `/etc/xdg/menus/applications.menu`,
and `/etc/sddm.conf.d/wayland.conf`. SDDM configs eliminated by PLM migration.
Applications menu now installed in child layer `/etc/xdg/menus/`.
Remaining: `/etc/fonts/fonts.conf` — fontconfig config (still needs audit).

#### 5. Locale Warnings / Missing CA Certificates (LOW — partially related to #3)
- Qt reports: "Detected locale 'C' with character encoding 'ANSI_X3.4-1968'"
- Locale `LANG=C` may contribute to sycoca parsing failures (see issue #3).
- `C.UTF-8` fallback works but full locale data (`glibc-locales`) should be
  installed and `LANG=en_US.UTF-8` set for production.
- CA certificates: no root CAs installed (`/etc/ssl/certs/` empty) — causes
  Discover/curl SSL verification failures.  Fix pushed: `ca-certificates`
  added to deps.bst; `update-ca-certificates` run in oci compose.  Workaround:
  `curl -k -o /etc/ssl/certs/ca-certificates.crt https://curl.se/ca/cacert.pem`

---

## Post-Boot Workaround Script

After each `just generate-bootable-image` + `just boot-vm`:

```bash
ssh -p 2222 root@127.0.0.1

# 1. Create user (still manual until first-boot user setup is automated)
useradd -m -G video,render,input,audio -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd

# 2. Download CA certificates (until ca-certificates + update-ca-trust fix
#    in oci/tromso.bst takes effect in a fresh build):
curl -k -o /etc/ssl/certs/ca-certificates.crt https://curl.se/ca/cacert.pem

# 3. Application launcher / sycoca (UNRESOLVED — see Known Issues #3).
#    The panel launcher and Discover's "Installed" view remain empty.
#    Workaround: launch apps via Konsole or KRunner (Alt+F2) by binary name,
#    e.g. `plasma-discover`, `dolphin`, `systemsettings`.
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
