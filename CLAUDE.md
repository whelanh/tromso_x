# Claude Code Context — KDE Linux Aurora

This file provides Claude Code with explicit instructions and context for working on the Aurora KDE Linux project.

## Critical Rules About Reference Repos

### Dakota & gnome-build-meta are authoritative

**NEVER invent workarounds for build issues.** For any infrastructure, bootc, systemd, kernel, or non-KDE/QT packages:

1. **FIRST**: Clone and examine `/var/home/james/reference-repos/dakota` and `/var/home/james/reference-repos/gnome-build-meta`
2. **ALWAYS**: Copy the `.bst` patterns and approaches from these known-good repos
3. **NEVER**: Use pre-built binaries, shortcuts, or workarounds to bypass build failures
4. **EXAMPLE**: When bootc compilation fails with Cargo DNS errors:
   - Don't create a bootc import element with a pre-built binary ❌
   - Instead, examine how Dakota/gnome-build-meta compile bootc in their CI ✓
   - Copy their exact `.bst` configuration and build infrastructure

### Bootc Handling

Bootc is a critical tool for creating bootable OCI images. It is compiled from source (Rust, ~400 Cargo dependencies) in:
- `gnome-build-meta`: https://gitlab.gnome.org/GNOME/gnome-build-meta (canonical reference)
- `projectbluefin/dakota`: https://github.com/projectbluefin/dakota (proven working setup)

If bootc build fails in the containerized BuildStream environment:
1. Check Dakota's and gnome-build-meta's CI/build configuration (`*.yml` in `.gitlab-ci/` or `.github/workflows/`)
2. Determine if they resolve DNS/Cargo issues via container networking or CI environment setup
3. Apply the same approach rather than using a pre-built binary

**Reference files**:
- `/var/home/james/reference-repos/gnome-build-meta/elements/gnomeos-deps/bootc.bst`
- `/var/home/james/reference-repos/dakota/elements/*/bootc.bst` (if exists)

## When to Reference repos

| Situation | Reference |
|-----------|-----------|
| Bootc build issues | Dakota CI config + gnome-build-meta |
| Boot infrastructure (systemd-boot, fwupd, initramfs) | gnome-build-meta |
| OCI composition, layering, or export | Dakota's oci/ elements |
| Non-KDE package configuration | gnome-build-meta |
| KDE package cmake flags, dependencies | Arch Linux PKGBUILD |

## Two-Repo Model for Aurora Development

See `AGENTS.md` for detailed instructions. In summary:

- **`hanthor/kde-build-meta`** — KDE package definitions (Qt6, Frameworks, Plasma, Apps)
- **`hanthor/tromso` (this repo)** — OCI/bootc integration, Aurora-specific layers, and boot testing

Changes to KDE packages go into `kde-build-meta`, then update the junction ref in this repo's `elements/kde-build-meta.bst`.

## File locations

- **Reference repos**: `/var/home/james/reference-repos/`
  - `dakota/` — Project Bluefin Dakota (GNOME-based, bootc-enabled)
  - `gnome-build-meta/` — GNOME's BuildStream repository
- **Build logs**: `/var/tmp/aurora-build.log`
- **Cache**: `~/.cache/buildstream/`
- **This project**: `/var/home/james/dev/kde-linux/`

## How Claude Code (AI Assistant) Should Use This

When the user asks you to fix a build failure, add a package, or resolve an infrastructure issue:

1. **DO NOT** search the web or guess at solutions
2. **DO** read the reference repo files from `/var/home/james/reference-repos/`
3. **DO** compare the working configuration in Dakota/gnome-build-meta to the Aurora configuration
4. **DO** apply the exact pattern or approach used in the reference repos
5. **DO** document the reasoning in memory or commit messages

This ensures Aurora inherits proven patterns from known-good, maintained, widely-used projects (GNOME and Project Bluefin) rather than custom workarounds that may break or diverge from the ecosystem.
