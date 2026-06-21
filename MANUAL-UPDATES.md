# Manual Update Procedures

The `update-refs.yml` workflow automates tracking for most elements via
`bst source track`. This document covers the components that **cannot** be
auto-tracked and require manual intervention.

---

## Table of Contents

1. [How It Works — GitHub-Hosted CI + Local Builds](#1-how-it-works)
2. [Qt6 Version Bumps (25 tar-based elements)](#2-qt6-version-bumps)
3. [Intentionally Pinned Elements](#3-intentionally-pinned-elements)
4. [Patch Conflicts After Tracking](#4-patch-conflicts-after-tracking)
5. [Adding New KDE Packages](#5-adding-new-kde-packages)
6. [Freedesktop-SDK Major Version Bumps](#6-freedesktop-sdk-major-version-bumps)
7. [PAT Token Rotation](#7-pat-token-rotation)

---

## 1. How It Works — GitHub-Hosted CI + Local Builds

The `update-refs.yml` workflow runs on a free GitHub-hosted `ubuntu-24.04`
runner. It only does lightweight `bst source track` operations (git
metadata fetches), not full builds. The workflow:

1. Clones `whelanh/kde-build-meta-x`
2. Runs `bst source track` to update all `ref:` fields to latest upstream commits
3. Pushes the updated refs to `kde-build-meta-x`
4. Updates the junction in `tromso_x` and opens a PR

### Your local workflow

1. **Merge the PR** that the workflow created on `tromso_x`
2. **Pull locally**: `git pull origin main`
3. **Clear the stale junction cache**: `rm -rf .bst/staged-junctions/kde-build-meta.bst`
4. **Build**: `just build` (or `just bst-build` for background builds)

The workflow runs weekly (Monday 04:00 UTC) or on-demand via the Actions
tab → "Track Upstream Refs" → "Run workflow".

---

## 2. Qt6 Version Bumps

**25 Qt6 elements** use `tar` sources pointing to versioned release
tarballs from `https://download.qt.io/`. They have **no `track` key** and
are invisible to `bst source track`.

### Current version: Qt 6.10.3

All 25 tar-based elements are at the same Qt version. Their URLs follow the
pattern:

```
qt:6.10/6.10.3/submodules/MODULENAME-everywhere-src-6.10.3.tar.xz
```

### Files to update (all in `kde-build-meta-x`)

These live under `elements/kde/qt6/` in the
[kde-build-meta-x](https://github.com/whelanh/kde-build-meta-x) repo:

| Element | Module name in URL |
|---------|--------------------|
| `qt6-qt5compat.bst` | `qt5compat` |
| `qt6-qtbase.bst` | `qtbase` |
| `qt6-qtconnectivity.bst` | `qtconnectivity` |
| `qt6-qtdeclarative.bst` | `qtdeclarative` |
| `qt6-qthttpserver.bst` | `qthttpserver` |
| `qt6-qtimageformats.bst` | `qtimageformats` |
| `qt6-qtlanguageserver.bst` | `qtlanguageserver` |
| `qt6-qtlocation.bst` | `qtlocation` |
| `qt6-qtmultimedia.bst` | `qtmultimedia` |
| `qt6-qtnetworkauth.bst` | `qtnetworkauth` |
| `qt6-qtpositioning.bst` | `qtpositioning` |
| `qt6-qtremoteobjects.bst` | `qtremoteobjects` |
| `qt6-qtscxml.bst` | `qtscxml` |
| `qt6-qtsensors.bst` | `qtsensors` |
| `qt6-qtserialbus.bst` | `qtserialbus` |
| `qt6-qtserialport.bst` | `qtserialport` |
| `qt6-qtshadertools.bst` | `qtshadertools` |
| `qt6-qtspeech.bst` | `qtspeech` |
| `qt6-qtsvg.bst` | `qtsvg` |
| `qt6-qttools.bst` | `qttools` |
| `qt6-qtvirtualkeyboard.bst` | `qtvirtualkeyboard` |
| `qt6-qtwayland.bst` | `qtwayland` |
| `qt6-qtwebchannel.bst` | `qtwebchannel` |
| `qt6-qtwebsockets.bst` | `qtwebsockets` |
| `qt6-qtwebview.bst` | `qtwebview` |

### 5 additional Qt6 elements use `git_repo` and ARE auto-tracked:

| Element | Track branch |
|---------|-------------|
| `qt6-qtgrpc.bst` | `dev` |
| `qt6-qtquick3d.bst` | `dev` |
| `qt6-qtquick3dphysics.bst` | `dev` |
| `qt6-qtquickeffectmaker.bst` | `dev` |
| `qt6-qtwebengine.bst` | `dev` |

### How to bump Qt6

1. Check for new releases at **https://download.qt.io/official_releases/qt/6.10/**
   (or the next minor series like `6.11/`).

2. For each of the 25 tar-based elements, update three things in the `.bst`
   file:

   - The **URL** — change the version numbers in the path:
     ```yaml
     url: qt:6.10/6.10.4/submodules/qtbase-everywhere-src-6.10.4.tar.xz
     ```

   - The **ref** (SHA256 checksum) — download and hash the new tarball:
     ```bash
     curl -sL https://download.qt.io/official_releases/qt/6.10/6.10.4/submodules/qtbase-everywhere-src-6.10.4.tar.xz \
       | sha256sum
     ```

   - If the major.minor changed (e.g., 6.10 to 6.11), update the directory
     component in the URL too.

3. A helper script to update all 25 elements at once:

   ```bash
   cd /path/to/kde-build-meta-x

   OLD_VER="6.10.3"
   NEW_VER="6.10.4"
   OLD_SERIES="6.10"
   NEW_SERIES="6.10"

   for bst in elements/kde/qt6/qt6-*.bst; do
     # Skip git_repo-based elements
     if grep -q 'kind: git_repo' "$bst"; then continue; fi

     # Extract module name from URL
     MODULE=$(grep -oP '(?<=submodules/)\S+(?=-everywhere)' "$bst")
     if [ -z "$MODULE" ]; then continue; fi

     # Download new tarball and compute SHA256
     URL="https://download.qt.io/official_releases/qt/${NEW_SERIES}/${NEW_VER}/submodules/${MODULE}-everywhere-src-${NEW_VER}.tar.xz"
     echo "Fetching $MODULE..."
     NEW_SHA=$(curl -sfL "$URL" | sha256sum | cut -d' ' -f1)
     if [ -z "$NEW_SHA" ] || [ "$NEW_SHA" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
       echo "  FAILED: $URL not found or empty"
       continue
     fi

     # Update the .bst file
     sed -i "s|qt:${OLD_SERIES}/${OLD_VER}/submodules/${MODULE}-everywhere-src-${OLD_VER}|qt:${NEW_SERIES}/${NEW_VER}/submodules/${MODULE}-everywhere-src-${NEW_VER}|" "$bst"
     sed -i "s|ref: .*|ref: ${NEW_SHA}|" "$bst"
     echo "  Updated: $NEW_SHA"
   done
   ```

4. Commit, push, and update the tromso junction (see section below).

### After updating kde-build-meta-x, update the tromso junction

```bash
cd /path/to/kde-build-meta-x
git add elements/kde/qt6/
TMPDIR=/var/tmp git commit -m "Bump Qt6 to ${NEW_VER}"
git push origin master

SHA=$(git rev-parse HEAD)
SHORT=$(git rev-parse --short=7 HEAD)
curl -sL "https://github.com/whelanh/kde-build-meta-x/archive/${SHA}.tar.gz" \
  -o /tmp/kbm.tar.gz
NEW_REF=$(sha256sum /tmp/kbm.tar.gz | cut -d' ' -f1)
BASEDIR=$(tar tzf /tmp/kbm.tar.gz | head -1 | sed 's|/$||')

cd /path/to/tromso_x
cat > elements/kde-build-meta.bst << EOF
kind: junction
description: Junction to whelanh/kde-build-meta-x (KDE Plasma 6 build metadata)

sources:
- kind: tar
  url: github:whelanh/kde-build-meta-x/archive/${SHA}.tar.gz
  ref: ${NEW_REF}
  base-dir: ${BASEDIR}

config:
  options:
    arch: "%{arch}"
EOF

TMPDIR=/var/tmp git add elements/kde-build-meta.bst
TMPDIR=/var/tmp git commit -m "Update junction to kde-build-meta-x ${SHORT} (Qt6 ${NEW_VER})"
git push origin main
```

---

## 3. Intentionally Pinned Elements

These elements track a specific tag or branch rather than `master` because
the latest `master` is known to be incompatible or unstable. **Do not
blindly change their `track:` to `master`.**

### SDDM — `elements/kde/plasma/sddm.bst`

| Field | Value |
|-------|-------|
| `track` | `v0.21.0` |
| `ref` | `v0.21.0-0-g4832736de...` |
| Source | `kde:plasma/sddm.git` |
| KDE Invent | https://invent.kde.org/plasma/sddm |

**Why pinned:** SDDM upstream is transitioning to a new architecture. The
`master` branch may contain breaking changes that prevent login.

**When to bump:** Check for new stable tags at
https://invent.kde.org/plasma/sddm/-/tags. When a new `v0.22.0` (or
similar) tag appears, update both `track:` and `ref:` and test that the
display manager starts correctly in a VM (`just generate-bootable-image &&
just boot-vm`).

### plasma-vault — `elements/kde/plasma/plasma-vault.bst`

| Field | Value |
|-------|-------|
| `track` | `Plasma/6.6` |
| `ref` | `v6.3.5-0-g94adb85b2b...` |
| Source | `kde:plasma/plasma-vault.git` |
| KDE Invent | https://invent.kde.org/plasma/plasma-vault |

**Why pinned:** Held back to the Plasma 6.6 maintenance branch. The
`master` branch targets a newer Plasma version that may have API
incompatibilities.

**When to bump:** When the rest of the Plasma stack moves to 6.7+, update
`track:` to `Plasma/6.7` (or `master` if it stabilizes). Check the branch
list at https://invent.kde.org/plasma/plasma-vault/-/branches.

### kirigami-addons — `elements/kde/libs/kirigami-addons.bst`

| Field | Value |
|-------|-------|
| `track` | `v1.12.0` |
| `ref` | `v1.12.0-0-g6d2b5add1b...` |
| Source | `kde:libraries/kirigami-addons.git` |
| KDE Invent | https://invent.kde.org/libraries/kirigami-addons |

**Why pinned:** Tracks a specific release tag. Newer versions may require
newer Kirigami framework APIs.

**When to bump:** Check for new tags at
https://invent.kde.org/libraries/kirigami-addons/-/tags. Update `track:` to
the new tag (e.g., `v1.13.0`) and verify the build succeeds.

### How to update a pinned element

```bash
cd /path/to/kde-build-meta-x

# Edit the .bst file — change track: to the new tag/branch
# Then run bst source track on just that element to update the ref:
just bst source track kde/plasma/sddm.bst

# Or manually set the ref — get the commit from KDE Invent:
# https://invent.kde.org/plasma/sddm/-/commit/HASH
```

---

## 4. Patch Conflicts After Tracking

Some elements apply local patches on top of the tracked source. If
`bst source track` updates the `ref:` to a commit where the patch no
longer applies cleanly, the **build** will fail (not the track step).

### Elements with patches

Check for patches in kde-build-meta-x:

```bash
cd /path/to/kde-build-meta-x
grep -rl 'kind: patch' elements/kde/ elements/core-deps/
```

Currently known:
- `elements/kde/plasma/plasma-desktop.bst` — applies
  `patches/plasma-desktop/0001-fix-libinput-pkgconfig.patch`

### How to fix a patch conflict

1. Read the build log to confirm the patch failed:
   ```
   FAILURE kde/plasma/plasma-desktop.bst
   ...
   error: patch failed: CMakeLists.txt:42
   ```

2. Check if the upstream commit fixed the issue the patch addresses. If so,
   **remove the patch source** from the `.bst` file and delete the patch
   file.

3. If the patch is still needed, regenerate it:
   ```bash
   cd /tmp
   git clone https://invent.kde.org/plasma/plasma-desktop.git
   cd plasma-desktop
   git checkout <the-new-ref-commit>

   # Apply your fix, then:
   git diff > /path/to/kde-build-meta-x/patches/plasma-desktop/0001-fix-libinput-pkgconfig.patch
   ```

4. Commit the updated patch to kde-build-meta-x and update the junction.

---

## 5. Adding New KDE Packages

When KDE releases a new framework, Plasma component, or application that
you want to include:

### Step 1: Check Arch Linux for build details

The Arch Linux PKGBUILD is the best reference for CMake flags and
dependencies:

```
https://gitlab.archlinux.org/archlinux/packaging/packages/PACKAGE_NAME/-/blob/main/PKGBUILD
```

### Step 2: Create the .bst file

Use an existing element as a template. For a KDE Framework:

```bash
cp elements/kde/frameworks/kcoreaddons.bst \
   elements/kde/frameworks/NEW-FRAMEWORK.bst
```

Edit the new file:

```yaml
kind: cmake
description: new-framework

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- kde/frameworks/extra-cmake-modules.bst
- kde/qt6/qt6-qtbase.bst
# Add other build-depends from the PKGBUILD makedepends()

depends:
# Add runtime dependencies from the PKGBUILD depends()

variables:
  cmake-local: -DBUILD_TESTING=OFF

sources:
- kind: git_repo
  url: kde:frameworks/new-framework.git
  track: master
  ref: SET-BY-BST-TRACK
```

### Step 3: Get the initial ref

```bash
cd /path/to/kde-build-meta-x
just bst source track kde/frameworks/new-framework.bst
```

This fills in the `ref:` field with the latest commit on `master`.

### Step 4: Wire it into the build

Add the new element as a dependency wherever it's needed. Typically this
means adding it to a stack element like `elements/kde/org.kde.Sdk.bst` or
`elements/kde/org.kde.plasma.desktop.bst`.

### Step 5: Commit, push, update junction

Follow the same junction update process described in section 2.

---

## 6. Freedesktop-SDK Major Version Bumps

The freedesktop-sdk junction in kde-build-meta-x currently tracks the
`25.08` release series:

```yaml
# In kde-build-meta-x: elements/freedesktop-sdk.bst
track: freedesktop-sdk-25.08*
ref: freedesktop-sdk-25.08.9-0-g3361ede6aa...
```

The `update-refs.yml` workflow handles **point releases** within 25.08
automatically (e.g., 25.08.9 to 25.08.10).

### When a new major version ships (e.g., 26.08)

1. Check the release at
   https://gitlab.com/freedesktop-sdk/freedesktop-sdk/-/tags

2. Update the `track:` glob in
   `kde-build-meta-x/elements/freedesktop-sdk.bst`:
   ```yaml
   track: freedesktop-sdk-26.08*
   ```

3. Run `bst source track` on the junction:
   ```bash
   cd /path/to/kde-build-meta-x
   just bst source track freedesktop-sdk.bst
   ```

4. Check the **patch queue** at `kde-build-meta-x/patches/freedesktop-sdk/`.
   Local patches may conflict with the new freedesktop-sdk version. Review
   each patch and drop or rebase as needed.

5. Check the **overrides** section in `elements/freedesktop-sdk.bst`. The
   new freedesktop-sdk may have renamed or restructured elements, requiring
   override path updates.

6. Build and test thoroughly — a major freedesktop-sdk bump changes the
   entire toolchain (gcc, glibc, mesa, systemd, etc.).

---

## 7. PAT Token Rotation

The `update-refs.yml` workflow uses two fine-grained PAT secrets stored at
**https://github.com/whelanh/tromso_x/settings/secrets/actions**:

- `KBM_PUSH_TOKEN` — `Contents: Read and write` on `whelanh/kde-build-meta-x`
- `TROMSO_PUSH_TOKEN` — `Contents: Read and write` and `Pull requests: Read and write` on `whelanh/tromso_x`

`TROMSO_PUSH_TOKEN` is required because the repository currently does not allow
the default `GITHUB_TOKEN` to create pull requests. Without it, the workflow
will track refs but skip PR creation.

Fine-grained PATs have a maximum lifetime (default 90 days). When a token
expires, the `update-refs.yml` workflow will fail at the matching push/PR step.

### To rotate

1. Go to **https://github.com/settings/personal-access-tokens**
2. Find the token you want to replace:
   - `tromso-kbm-push` for `KBM_PUSH_TOKEN`
   - `tromso-pr-push` (or equivalent) for `TROMSO_PUSH_TOKEN`
3. Click **Regenerate** (or create a new token with the same settings)
4. Copy the new token
5. Go to **https://github.com/whelanh/tromso_x/settings/secrets/actions**
6. Click **Update** on the matching secret and paste the new value

### To avoid expiration entirely

Set the PAT expiration to "No expiration" when creating it (available under
fine-grained PATs if your account permits it). This is less secure but
eliminates the rotation burden for a personal project.
