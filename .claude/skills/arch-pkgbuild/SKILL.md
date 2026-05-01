---
name: arch-pkgbuild
description: Fetch authoritative PKGBUILD or .bst configuration for a package. Use this whenever you need to reference how a package is built, its dependencies, or cmake flags. For KDE/Plasma/Framework packages, returns the Arch PKGBUILD. For system packages, returns the .bst configuration from Dakota or gnome-build-meta. Always use this skill to verify build-depends, cmake flags, and dependency lists before suggesting fixes.
compatibility: bash, curl, git
---

# Arch PKGBUILD & Authority Source Lookup

Fetch the authoritative PKGBUILD or .bst configuration for a package to see how it's built, what dependencies it needs, and what cmake flags are used.

## When to use

- You're diagnosing a build failure and need to know what dependencies should be present
- You need to compare cmake flags or build configuration
- You're unsure if a dependency is required or optional
- You need to reference the official build process for a package

## Supported package types

### KDE Packages (Plasma, Frameworks, Apps)
- Query: `arch-pkgbuild kwin` or `arch-pkgbuild kwin 6.0.0`
- Returns: Arch Linux PKGBUILD for that package version
- Source: https://archlinux.org/packages/ → git.archlinux.org

### System Packages (systemd, bootc, lvm2, etc.)
- Query: `arch-pkgbuild bootc` or `arch-pkgbuild systemd`
- Returns: .bst configuration from gnome-build-meta or Dakota
- Source: `/var/home/james/reference-repos/gnome-build-meta/` or `dakota/`

## How to use

```bash
# Fetch latest Arch PKGBUILD for kwin
arch-pkgbuild kwin

# Fetch specific version
arch-pkgbuild kwin 6.0.0

# Fetch system package config
arch-pkgbuild systemd
arch-pkgbuild bootc
```

## Output

Returns the full PKGBUILD content or .bst configuration, including:
- **Package metadata** (version, release)
- **Dependencies** (depends, makedepends, build-depends)
- **Build function** (cmake flags, configure options, install steps)
- **Patches** (if any applied)

## Example

You're fixing a KWin build failure. Run:
```
arch-pkgbuild kwin 6.1.0
```

This returns:
```
pkgname=kwin
pkgver=6.1.0
...
makedepends=(...)
build() {
  cmake -B build ...
  cmake --build build
}
```

Now you can compare KWin's dependencies and cmake flags to what's in kde-build-meta.bst:kde/plasma/kwin.bst.

## Implementation

Run this script directly with Bash:

```bash
bash /var/home/james/dev/kde-linux/.claude/skills/arch-pkgbuild/scripts/fetch_pkgbuild.sh <package> [version]
```

For system packages not found via the script, grep the reference repos directly:
```bash
grep -r "<package>" /var/home/james/reference-repos/gnome-build-meta/elements/
grep -r "<package>" /var/home/james/reference-repos/dakota/elements/
```

## Notes

- Arch versions may be newer than what's in kde-linux (compare but don't blindly copy)
- System packages from gnome-build-meta are the canonical reference (used by GNOME and Fedora)
- Dakota's .bst files show how OCI/bootc packages are built
