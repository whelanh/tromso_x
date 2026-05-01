---
name: kde-build-manager
description: Manage KDE Linux build with Arch PKGBUILD referencing and BuildStream integration. Use for dependency mapping, checking build logs, and handling failures.
---

# KDE Build Manager

This skill manages the Aurora KDE Linux build by providing tools to reference Arch Linux package configurations and BuildStream build operations.

## Core Workflows

### 1. Reference Arch PKGBUILDs
Use this to align dependencies and build flags with upstream Arch Linux.
- **Fetch PKGBUILD**: 
  ```bash
  bash /var/home/james/dev/kde-linux/.claude/skills/arch-pkgbuild/scripts/fetch_pkgbuild.sh <package_name>
  ```
- **Analysis**: Compare the output `depends`, `makedepends`, and `cmake` flags against `kde-build-meta-local/elements/<path-to-bst>`.

### 2. Build Management
- **Build**: Always use the official BuildStream recipe.
  ```bash
  just bst-build
  ```
- **Check Status**: 
  ```bash
  just bst show oci/aurora.bst
  ```
- **Clear Failed Artifact**: 
  ```bash
  just bst artifact delete kde-build-meta.bst:<element_path>
  ```

### 3. Log Analysis & Failure Recovery
- **Extract Error**: Identify the root cause from complex build logs.
  ```bash
  bash /var/home/james/dev/kde-linux/.claude/skills/build-log-extract/scripts/extract_error.sh <path_to_log>
  ```
- **Failure Monitoring**: Monitor build logs in real-time.
  ```bash
  tail -f /var/tmp/aurora-build.log
  ```
