# Aurora KDE Linux — Agent Context

Aurora is a BuildStream-based KDE Linux OCI/bootc image, modeled on Project Bluefin's `projectbluefin/dakota`.
It builds KDE Plasma 6 on top of freedesktop-sdk using two repos:

- **`/var/home/hugh/Downloads/tromso_x`** — top-level OCI project (this repo)
- **`/var/home/hugh/Downloads/kde-build-meta-x`** — KDE `.bst` elements (junctioned in)

---

## Critical Rules About Reference Repos

### Dakota & gnome-build-meta are authoritative

**NEVER invent workarounds for build issues.** For any infrastructure, bootc, systemd, kernel, or non-KDE/QT packages:

1. **FIRST**: Examine `/var/home/hugh/Downloads/dakota` (if needed)
2. **ALWAYS**: Copy the `.bst` patterns and approaches from these known-good repos
3. **NEVER**: Use pre-built binaries, shortcuts, or workarounds to bypass build failures
4. **EXAMPLE**: When bootc compilation fails with Cargo DNS errors:
   - Don't create a bootc import element with a pre-built binary ❌
   - Instead, examine how Dakota/gnome-build-meta compile bootc in their CI ✓
   - Copy their exact `.bst` configuration and build infrastructure

### Reference Sources

| Situation | Reference |
|-----------|-----------|
| Bootc build issues | Dakota CI config + gnome-build-meta |
| Boot infrastructure (systemd-boot, fwupd, initramfs) | gnome-build-meta |
| OCI composition, layering, or export | Dakota's oci/ elements |
| Non-KDE package configuration | gnome-build-meta |
| KDE package cmake flags, dependencies | Arch Linux PKGBUILD |

### Bootc Handling

Bootc is a critical tool for creating bootable OCI images. It is compiled from source (Rust, ~400 Cargo dependencies) in:
- `gnome-build-meta`: https://gitlab.gnome.org/GNOME/gnome-build-meta (canonical reference)
- `projectbluefin/dakota`: https://github.com/projectbluefin/dakota (proven working setup)

If bootc build fails in the containerized BuildStream environment:
1. Check Dakota's and gnome-build-meta's CI/build configuration (`*.yml` in `.gitlab-ci/` or `.github/workflows/`)
2. Determine if they resolve DNS/Cargo issues via container networking or CI environment setup
3. Apply the same approach rather than using a pre-built binary


---

## Two-Repo Model

All KDE package definitions live in `/var/home/hugh/Downloads/kde-build-meta-x`.
After committing there, update the junction in this repo (`elements/kde-build-meta.bst`):

```bash
# 1. Commit + push kde-build-meta
cd /var/home/hugh/Downloads/kde-build-meta-x
TMPDIR=/var/tmp git commit -m "..."
git push origin master

# 2. Get new tarball SHA256 (must re-download after push — GitHub tarballs are non-deterministic)
SHA=$(git rev-parse --short=7 HEAD)
curl -sL https://github.com/whelanhans/kde-build-meta-x/archive/${SHA}.tar.gz | tee /tmp/kbm.tar.gz | sha256sum
tar tzf /tmp/kbm.tar.gz | head -1   # get base-dir

# 3. Update elements/kde-build-meta.bst with new url, ref, base-dir

# 4. Commit tromso
cd /var/home/hugh/Downloads/tromso_x
TMPDIR=/var/tmp git commit -m "Update junction to kde-build-meta ${SHA} (...)"
```

**CRITICAL**: Always use `TMPDIR=/var/tmp` for git commits — `/tmp` is full.
**CRITICAL**: Always use short SHA (7 chars) in GitHub archive URLs for stability.
**CRITICAL**: GitHub archive SHA256 changes each request — compute it fresh after every push.
**CRITICAL**: `base-dir` must match the exact directory name extracted from the tarball (full SHA in name).

---

## Build Commands (Use `just`)

**MANDATORY**: Always use the `just` recipes for running any `bst` (BuildStream) or diagnostic commands. The `Justfile` wraps BuildStream inside a pinned container image with correct volume mounts and permissions to ensure reproducibility.

```bash
# Recommended: Background build with logging and tail
just bst-build

# Foreground build + OCI export
just build

# Arbitrary BuildStream command (shell, show, checkout, etc.)
just bst <command> <args>

# Example: Run shell in a sandbox
just bst shell oci/tromso.bst

# View logs
just log
```

- **NEVER** run `bst` directly on the host or via `pipx` for project work.
- Never use `just bst-build` directly in a blocking tool call — it uses `tail -f`.
- The build container image is pinned in `Justfile` for reproducibility.
- Build log location: `/var/tmp/aurora-build.log`

---

## Fixing a Failed Element

1. Check the build log for the element name:
   ```bash
   grep "FAILURE" /var/tmp/aurora-build.log | grep -v "^    "
   ```

2. Read the detailed log:
   ```bash
   ls -t ~/.cache/buildstream/logs/gnome/kde-frameworks-ELEMENT/ | head -1 | \
     xargs -I{} cat ~/.cache/buildstream/logs/gnome/kde-frameworks-ELEMENT/{}
   ```

3. Fix the `.bst` file in `hanthor/kde-build-meta`.

4. **Clear the cached failure** (BST caches failed artifacts):
   ```bash
   # Clear ONLY the failed element to preserve cache for unrelated elements
   rm -rf ~/.cache/buildstream/artifacts/refs/gnome/kde-CATEGORY-ELEMENT/
   rm -rf ~/.cache/buildstream/logs/gnome/kde-CATEGORY-ELEMENT/
   ```
   **⚠️ CRITICAL**: Never clear `kde-*` broadly — this forces rebuild of ALL KDE elements, not just the fix.
   Instead, clear only the specific element that failed.

5. Commit + push `kde-build-meta`, update junction, restart build.

---

## Common Build Patterns

### All KDE cmake elements need:

```yaml
build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- kde/frameworks/extra-cmake-modules.bst
- kde/qt6/qt6-qtbase.bst   # needed at configure time for Qt6 CMake detection
```

Use `cmake-local` (NOT `cmake-options`) for cmake flags:

```yaml
variables:
  cmake-local: -DBUILD_TESTING=OFF
```

### KDE frameworks that depend on other KDE frameworks

CMake config detection requires the dependency to be present in the **sandbox** at configure time.
Any KDE framework listed in `depends:` that is needed by CMake `find_package()` **must also appear in `build-depends:`**.

Pattern — if upstream `CMakeLists.txt` has `find_package(KF6Foo REQUIRED)`, then `kde/frameworks/foo.bst` must be in `build-depends`.

### Modules already in freedesktop-sdk (do NOT redefine)

| Package | freedesktop-sdk element |
|---|---|
| pam | `freedesktop-sdk.bst:components/linux-pam-base.bst` |
| polkit | `freedesktop-sdk.bst:components/polkit.bst` |
| NetworkManager | `freedesktop-sdk.bst:components/networkmanager.bst` |

---

## File locations

- **Build logs**: `/var/tmp/aurora-build.log`
- **Cache**: `~/.cache/buildstream/`
- **This project**: `/var/home/hugh/Downloads/tromso_x/`

---

## VM & Graphical Boot Troubleshooting

### Systemd Ordering Cycles
If the VM hangs or boots to an emergency shell with "Ordering cycle found" messages in the serial log:
- Check `elements/tromso/system-config.bst`.
- **NEVER** use `Before=basic.target` on core services like `dbus.service`. This is a common source of cycles that causes D-Bus to be skipped

### Linker Cache (`ldconfig`)

### Disk Image Corruption (Loop Devices)
When generating bootable images with `bootc install`:
- **Avoid Sparse Files**: `truncate` followed by `bootc` on loop devices can lead to metadata corruption (especially on EXT4).
- **Use `fallocate`**: Always pre-allocate the full disk size using `fallocate -l 30G bootable.raw`.
- **Prefer XFS**: For the bootable image filesystem, XFS has shown better resilience than EXT4 in this specific loopback deployment workflow.
- **Syncing**: Always `sync` before detaching loop devices or starting the VM.

---

## How to Use This (AI Assistant Mandate)

When you are asked to fix a build failure, add a package, or resolve an infrastructure issue:

1. **DO NOT** search the web or guess at solutions.
2. **DO** read the reference repo files 
3. **DO** compare the working configuration in Dakota/gnome-build-meta to the Aurora configuration.
4. **DO** apply the exact pattern or approach used in the reference repos.
5. **DO** document the reasoning in memory or commit messages.

---


### OCI Layer Compression

For normal bootc images (composefs disabled), use `gzip: disabled` in `build-oci` config — Dakota convention.
This avoids double-compression: BuildStream already compresses layers, `gzip: disabled` wraps the raw tar.

For the ISO installer path (composefs enabled), gzip compression IS required:
- The ISO builder must use `gzip: gzip` or re-compress via:
  `skopeo copy --dest-compress-format gzip --dest-force-compress-format`
- Uncompressed layers cause bootc's composefs splitstream to deadlock

### Pushing to Registries

**NEVER use `podman push`.** Buildah 1.44.0 (podman 6.x) has a bug where both `podman push` and `podman build --squash-all` duplicate the config blob as an `application/octet-stream` layer in the manifest. When bootc pulls this broken image, it tries to extract the 1232-byte config JSON as a rootfs layer, corrupting the deployment and causing cascading systemd service failures.

**NEVER use `podman build --squash-all`.** Same buildah 1.44 bug — the squashed image in containers-storage will have the config blob duplicated as a layer, which gets faithfully transferred by skopeo copy.

**Use `skopeo copy` for both import and push:**
- **Import** from OCI layout: `skopeo copy oci:.build-out containers-storage:localhost/tromso-kde:latest`
- **Push** to registry: `skopeo copy containers-storage:localhost/tromso-kde:latest docker://ghcr.io/... --dest-creds=...`

The `skopeo copy oci:...` import bypasses buildah entirely (no `podman pull`, no `podman build`), so the manifest stays clean. Use `podman save | sudo podman load` only for rootless→rootful copy (that path doesn't rewrite manifests).

**Always use `skopeo copy` with `--dest-creds`** (run as normal user, not sudo):

```bash
skopeo copy \
  containers-storage:localhost/tromso-kde:latest \
  docker://ghcr.io/whelanh/tromso-kde-min:latest \
  --dest-creds=whelanh:"$(cat ~/chessFiles/ghcr_token.txt)"
```

**Why `--dest-creds` instead of stored auth:**
- `sudo skopeo login` requires an interactive terminal (can't be scripted)
- The GHCR token only has `repo, write:packages` scopes (no `read:packages`), which is fine for `--dest-creds` but some skopeo auth store paths may fail on blob-reuse checks
- `skopeo login` stores credentials to `~/.docker/config.json` (rootless) which works, but the `--dest-creds` approach is simpler and more reliable

The `just push-kde` and `just push` recipes in the Justfile use this approach. Run them as:
```bash
just push-kde ghcr.io/whelanh/tromso-kde-min
# or for the full Aurora image:
just push ghcr.io/whelanh/tromso
```

The token is read from `~/chessFiles/ghcr_token.txt` or the `GHCR_TOKEN` env var. Get a token at https://github.com/settings/tokens with `repo` and `write:packages` scopes.

### VFS Containers-Storage in Squashfs

The squashfs embeds the tromso OCI image as VFS containers-storage.  The skopeo import into VFS **must run from inside the installer container** (not the build host) so the tar-split metadata is written in the format the live ISO can read.  See dakota-iso's justfile comment for details.

