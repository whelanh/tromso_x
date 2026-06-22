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
**Status: Root cause not determined. All pushed fixes verified on a fresh image
(2026-06-22) — no improvement. Fresh-image theory ruled out.**

**Symptoms:**
- Panel launcher "All Applications" shows no entries
- KRunner (Alt+F2) cannot find newly-installed apps (e.g. plasma-discover)
- Discover → Installed category shows "Nothing Found"
- System Settings → Default Apps doesn't recognize any installed apps
- `kbuildsycoca6 --noincremental` runs without error but the sycoca cache is either
  not being read or does not contain application entries

**Diagnostics performed (SSH on live VM):**
- `/usr/share/applications/` — 142 `.desktop` files present and readable ✓
- `/etc/xdg/menus/applications.menu` — present with correct `<DefaultAppDirs/>` content ✓
- kded6 running with `XDG_DATA_DIRS=/usr/share:/usr/local/share` ✓
- `XDG_SESSION_TYPE=wayland` on fresh image (was `tty` on older VM) ✓
- `LANG=C.UTF-8` set in plasmashell environment (Qt still warns "Detected locale C") ✓
- `kbuildsycoca6` produces a 405KB cache when run with `LANG=C.UTF-8 XDG_DATA_DIRS`,
  but kded6 rebuilds a 227KB cache that overwrites it
- `locale -a` confirms `C.utf8` and `en_US.utf8` are available on the system
- No `kded_ksycoca` or sycoca-related kded6 modules found under `/usr/lib*/kded/`

**Comparison with working Fedora Kinoite system:**
- Kinoite sycoca cache: 615–676KB vs Aurora's 405KB (manually built) / 227KB (kded6 auto-build)
- Kinoite locale: `en_US.UTF-8` vs Aurora's `C.UTF-8`
- Kinoite has full locale data installed
- No significant structural differences in XDG variables or kded6 configuration

**Attempted fixes (all verified on fresh build, none resolved the issue):**
1. Install `/etc/xdg/menus/applications.menu` (the menu definition XML)
2. Run `kbuildsycoca6 --noincremental` at OCI build time in overlay chroot
3. Add XDG autostart `.desktop` that runs kbuildsycoca6 on user login
4. Set `XDG_DATA_DIRS=/usr/share:/usr/local/share` system-wide via `/etc/environment.d/`
5. Delete old caches, rebuild with `LANG=C.UTF-8 XDG_DATA_DIRS`, restart plasmashell
6. Rebuild cache, terminate session, log back in fresh
7. Set `LANG=C.UTF-8` + cache cleanup in autostart Exec, move to phase 2
8. Download Mozilla CA bundle directly in OCI compose (curl -k to curl.se/ca/cacert.pem)
9. Add `ca-certificates` element to deps.bst + `update-ca-certificates` overlay step
   (fd-sdk certificate paths are Fedora-style `/etc/pki/`, which the compose drops)
10. Rebuild on fresh image from scratch — no improvement on any issue

**Working theories for root cause:**
1. The sycoca cache built by `kbuildsycoca6` is in a format that plasmashell / kded6
   cannot read, possibly due to a KF6 version mismatch between build and runtime.
2. Desktop-file XML parsing fails silently due to locale issues (`LANG=C` →
   `C.UTF-8` fallback may not be sufficient; full `en_US.UTF-8` locale may be needed).
3. Composefs/bootc filesystem metadata (xattrs, timestamps) causes sycoca to
   reject desktop files from the read-only layer.
4. A required KDE service plugin for application model bridging is not loaded
   (no `kded_ksycoca` module found).

**Recommended next investigative steps:**
- Install full glibc locale data and test with `LANG=en_US.UTF-8`.
- Run `strace kbuildsycoca6 --noincremental` to trace which files/dirs are accessed
  during indexing (requires `strace` on the image).
- Build and boot the KDE Linux base image (without Aurora layer) to determine if
  the problem exists there too — if the base image works, the issue is in the
  Aurora layer; if not, it's a KDE/fd-sdk integration issue.
- Test `plasmashell` with `QT_LOGGING_RULES=org.kde.ksycoca=true` for debug output
  about sycoca database loading.
- Attempt building sycoca cache on a different system with the same KF6 versions
  and transplanting the cache file.

#### 4. bootc Deployment Loses `/etc` Files (PARTIALLY RESOLVED)
Previously affected `/etc/pam.d/sddm*`, `/etc/xdg/menus/applications.menu`,
and `/etc/sddm.conf.d/wayland.conf`. SDDM configs eliminated by PLM migration.
Applications menu now installed in child layer `/etc/xdg/menus/`.
Remaining: `/etc/fonts/fonts.conf` — fontconfig config (still needs audit).

#### 5. Missing CA Certificates / Locale (UNRESOLVED — partially related to #3)

**CA Certificates:**
- No root CA certificates on the system (`/etc/ssl/certs/` empty, no certs anywhere).
- OpenSSL default path is `/etc/pki/tls` (Fedora-style).  The freedesktop-sdk
  `ca-certificates.bst` element installs certs under `/etc/pki/ca-trust/...` but
  the compose step drops `/etc` content — the certs never reach the final image.
- Fixes attempted and deployed (neither worked on fresh build):
  a) Added `ca-certificates` to `tromso/deps.bst` + overlay `update-ca-certificates` step
  b) Direct download of Mozilla CA bundle via `curl` in `oci/tromso.bst`
- **Workaround (manual)**: `curl -k -o /etc/ssl/certs/ca-certificates.crt https://curl.se/ca/cacert.pem`
  This works when run manually on the VM — Discover SSL errors resolved, Flathub
  remote add succeeds.  But the build-time `curl` in oci/tromso.bst runs inside
  a container sandbox that may lack network access or `curl`.

**Locale:**
- Qt reports: "Detected locale 'C' with character encoding 'ANSI_X3.4-1968'".
  `LANG=C.UTF-8` fallback works in-user-session (`locale -a` confirms `C.utf8`
  and `en_US.utf8` are available).
- May contribute to sycoca parsing failures (see issue #3).

---

## Post-Boot Workaround Script

After each `just generate-bootable-image` + `just boot-vm`:

```bash
ssh -p 2222 root@127.0.0.1

# 1. Create user (still manual until first-boot user setup is automated)
useradd -m -G video,render,input,audio -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd

# 2. Download CA certificates (manual workaround — build-time fixes deployed
#    but not working; see Known Issues #5):
mkdir -p /etc/ssl/certs
curl -k -o /etc/ssl/certs/ca-certificates.crt https://curl.se/ca/cacert.pem

# 3. Application launcher / sycoca (UNRESOLVED — see Known Issues #3).
#    The panel launcher and Discover's "Installed" view remain empty.
#    Workaround: launch apps via Konsole or KRunner (Alt+F2) by binary name,
#    e.g. plasma-discover, dolphin, systemsettings.
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
