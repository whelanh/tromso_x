---
name: arch-pkgbuild
description: Fetch authoritative PKGBUILD or .bst configuration for a package. Use this whenever you need to reference how a package is built, its dependencies, or cmake flags. For KDE/Plasma/Framework packages, this helps align our BuildStream elements with upstream Arch Linux standards.
---

# Arch PKGBUILD Reference

This skill allows you to retrieve Arch Linux PKGBUILDs to use as an authoritative source for dependency mapping and configuration.

## Usage

- **Fetch PKGBUILD**:
  ```bash
  # Execute this script to fetch the latest PKGBUILD for a package
  bash /var/home/james/dev/kde-linux/.claude/skills/arch-pkgbuild/scripts/fetch_pkgbuild.sh <package_name>
  ```

- **Analysis Workflow**:
  1. Fetch the PKGBUILD.
  2. Compare `depends`, `makedepends`, and `cmake` flags with the corresponding `.bst` element.
  3. Update `build-depends` and `variables: cmake-local` in the `.bst` file accordingly.
