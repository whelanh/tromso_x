# Update Procedures

This document covers how to keep the tromso_x image up to date with
the latest KDE, Qt, and freedesktop-sdk releases.

---

## Table of Contents

1. [How It Works — Local Tracking Script](#1-how-it-works)
2. [Qt6 Tracking Notes](#2-qt6-tracking-notes)
3. [Intentionally Pinned Elements](#3-intentionally-pinned-elements)
4. [Patch Conflicts After Tracking](#4-patch-conflicts-after-tracking)
5. [Adding New KDE Packages](#5-adding-new-kde-packages)
6. [Freedesktop-SDK Major Version Bumps](#6-freedesktop-sdk-major-version-bumps)
7. [Git Authentication](#7-git-authentication)

---

## 1. How It Works — Local Tracking Script

Ref tracking is done locally using `scripts/track-refs-local.sh`. This
is more reliable than CI-based tracking because `bst source track` needs
to query ~200 git repos (KDE Invent, GitHub, freedesktop GitLab), which
hits rate limits on CI runners.

### To update all refs

```bash
bash scripts/track-refs-local.sh
```

This single command:
1. Clones/updates `whelanh/kde-build-meta-x` to `/tmp/kde-build-meta-x-track`
2. Runs `bst source track` on all KDE, Qt6, core-deps, and freedesktop-sdk elements
3. Commits and pushes updated refs to `kde-build-meta-x`
4. Updates the junction in `tromso_x`, clears caches, commits, and pushes

### After tracking, build locally

```bash
BST_FLAGS="--max-jobs $(nproc) --fetchers $(nproc) --no-interactive" just bst build oci/tromso.bst && just export
```

### CI workflow (backup)

The `update-refs.yml` GitHub Actions workflow still exists but its
schedule is disabled. It can be triggered manually via **Actions →
Track Upstream Refs → Run workflow** if needed, but the local script
is preferred because CI tracking is unreliable for this many elements.

### Prerequisites

- `podman` installed (runs the BST container)
- SSH access to `github.com:whelanh/kde-build-meta-x.git`
- Run from the `tromso_x` project root

---

## 2. Qt6 Tracking Notes

All 30 Qt6 elements now use `git_repo` sources with `track: 'v6.*'` and
are **automatically tracked** by `scripts/track-refs-local.sh` alongside
KDE frameworks, plasma, and apps. Pre-release tags (`*rc*`, `*alpha*`,
`*beta*`) are excluded.

### When manual intervention is needed

- **Qt major version change** (e.g., Qt 6 → Qt 7): Update the `track:`
  pattern in all 30 elements from `'v6.*'` to `'v7.*'`. This is unlikely
  in the near term.

- **Track pattern adjustment**: If Qt starts using a different tag format,
  update the `track:` and `exclude:` fields in the `.bst` files under
  `elements/kde/qt6/` in
  [kde-build-meta-x](https://github.com/whelanh/kde-build-meta-x).

### Qt6 element source format

```yaml
sources:
- kind: git_repo
  url: github:qt/<module>.git
  track: 'v6.*'
  exclude:
  - '*rc*'
  - '*alpha*'
  - '*beta*'
  ref: v6.10.3-0-g<commit-sha>
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
- `elements/kde/plasma/kwin.bst` — applies
  `patches/kwin/0001-killer-no-x11.patch` (cmake option for window killer)
  and `patches/kwin/0002-fix-missing-qqml-include.patch` (missing QtQml
  header after framework tracking update)

Note: Several freedesktop-sdk patches were removed from
`patches/freedesktop-sdk/` because they modified `files/linux/fdsdk-config.sh`
which drifts with each freedesktop-sdk update. The removed patches were
aarch64-specific kernel config entries not needed for x86_64 builds.

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

The `scripts/track-refs-local.sh` script handles **point releases** within 25.08
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

## 7. Git Authentication

### Local script (`scripts/track-refs-local.sh`)

The local script uses **SSH** to push to both repos. Ensure your SSH key
is registered at **https://github.com/settings/keys**.

### CI workflow (backup)

If you use the CI workflow as a backup, it needs a fine-grained PAT stored
as `KBM_PUSH_TOKEN` at
**https://github.com/whelanh/tromso_x/settings/secrets/actions**:

- `Contents: Read and write` on `whelanh/kde-build-meta-x`

Fine-grained PATs have a maximum lifetime (default 90 days). Set
expiration to "No expiration" for a personal project, or rotate by
regenerating at **https://github.com/settings/personal-access-tokens**
and updating the secret.
