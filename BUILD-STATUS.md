# Build Status & Next Steps

Last updated: 2026-06-22

## Current State

### Working
- **Full build completes** — 1169 elements build successfully
- **KDE Plasma 6.8 Dev desktop** loads with proper fonts and wallpaper
- **SDDM login screen** renders correctly (with manual workarounds)
- **Network, System Settings** functional
- **Qt6 6.11.1** auto-tracked via git_repo with `track: 'v6.*'`
- **KDE Frameworks/Plasma/Apps** tracked to latest master
- **Vulkan-headers 1.4.354** override resolves kwin RAII compat issues
- **Local tracking script** (`scripts/track-refs-local.sh`) reliably updates all refs
- **OCI image** builds correctly — all fixes verified inside the container

### Known Issues (Priority Order)

#### 1. plasma-login-manager Migration (HIGH PRIORITY)
SDDM is being replaced by `plasma-login-manager` in upstream KDE. We should
migrate BEFORE investing more time in SDDM workarounds. All dependencies
already exist in the build:
- PlasmaQuick (`kde/plasma/libplasma.bst`)
- LayerShellQt (`kde/plasma/layer-shell-qt.bst`)
- LibKWorkspace (`kde/plasma/plasma-workspace.bst`)
- KF6Screen (`kde/plasma/libkscreen.bst`)
- PAM, systemd, xau (freedesktop-sdk)

Source: https://invent.kde.org/plasma/plasma-login-manager
- Requires Qt >= 6.10.0 ✓, KF6 >= 6.26.0 ✓
- Has own PAM configs, systemd service, sysusers.d entries
- Eliminates SDDM PAM workaround entirely

#### 2. Runtime Dependency Audit (HIGH)
Many elements use `build-depends` for libraries that should be `depends`
(runtime). This causes "cannot open shared library" errors at runtime:
- `konsole` → needs `libssh.so.4` at runtime (FIXED in latest commit)
- `kcalc` → needs `libmpc.so.3` at runtime (NOT YET FIXED)
- Likely many more — need systematic audit

**Pattern**: In the original gnome-build-meta, many libraries were
implicitly available through the platform runtime. Our fork's layer
composition doesn't include them implicitly. Each element needs explicit
`depends:` entries for all runtime libraries.

**Recommended approach**: For each KDE app/component, check Arch Linux
PKGBUILD `depends()` and ensure matching `depends:` entries in the `.bst`
file.

#### 3. bootc Deployment Loses `/etc` Files (MEDIUM)
When `bootc install to-disk` deploys the OCI image, parent-layer `/etc`
files are lost when the child layer also has entries in `/etc`. Affected:
- `/etc/pam.d/sddm*` — SDDM PAM configs (will be eliminated by plasma-login-manager)
- `/etc/fonts/fonts.conf` — fontconfig config
- `/etc/xdg/menus/applications.menu` — KDE app menu definition
- `/etc/sddm.conf.d/wayland.conf` — SDDM Wayland config

**Current workaround**: Manual fix script after each boot (see below).
**Proper fix**: Move configs to `/usr/lib/` paths (immutable, survives
deployment) or ensure they're created in system-config.bst (child layer).
plasma-login-manager migration may eliminate most of these.

#### 4. Application Launcher Empty (MEDIUM)
The KDE application launcher shows no apps because:
- `/etc/xdg/menus/applications.menu` is missing (bootc deployment issue)
- `kbuildsycoca6` needs to be run after creating the menu file
- May also need `plasmashell` restart to pick up changes

#### 5. Locale Warnings (LOW)
Qt reports: "Detected locale 'C' with character encoding 'ANSI_X3.4-1968'".
Not a blocker but should be fixed by installing locale data or setting
`LANG=C.UTF-8` in the environment.

---

## Post-Boot Workaround Script

Until the above issues are fixed in the build, run this after each
`just generate-bootable-image` + `just boot-vm`:

```bash
ssh -p 2222 root@127.0.0.1

# 1. SDDM PAM configs (lost during bootc deployment)
cat > /etc/pam.d/sddm-greeter << 'EOF'
auth     required pam_env.so
auth     required pam_permit.so
account  required pam_permit.so
session  required pam_unix.so
-session optional pam_systemd.so
EOF

cat > /etc/pam.d/sddm << 'EOF'
auth     include  system-auth
account  include  system-auth
password include  system-auth
session  include  system-auth
EOF

cat > /etc/pam.d/sddm-autologin << 'EOF'
auth     required pam_env.so
auth     required pam_permit.so
account  include  system-auth
password include  system-auth
session  include  system-auth
EOF

# 2. SDDM service drop-in (writable /etc override for immutable /usr)
mkdir -p /etc/systemd/system/sddm.service.d
cat > /etc/systemd/system/sddm.service.d/override.conf << 'EOF'
[Service]
Environment=QT_QUICK_BACKEND=software
Environment=KWIN_COMPOSE=Q
StandardOutput=journal+console
StandardError=journal+console
EOF

# 3. Application menu definition
cat > /etc/xdg/menus/applications.menu << 'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <DefaultAppDirs/>
  <DefaultDirectoryDirs/>
  <DefaultMergeDirs/>
  <Include>
    <All/>
  </Include>
</Menu>
EOF

# 4. Create user
useradd -m -G video,render,input,audio -s /bin/zsh aurora
echo 'aurora:aurora' | chpasswd

# 5. Restart
systemctl daemon-reload
systemctl restart sddm

# 6. After logging in as aurora, rebuild app cache:
# ssh -p 2222 aurora@127.0.0.1
# kbuildsycoca6 --noincremental
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
