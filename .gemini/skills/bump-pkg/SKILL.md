---
name: bump-pkg
description: Update package sources (git ref/tarball ref) in .bst elements. Use this when syncing with upstream KDE or framework releases.
---

# Bump Package Source

This skill automates the process of updating package sources in BuildStream element files.

## Workflow

1. **Verify Source**: Check the `sources:` section in the `.bst` file.
2. **Fetch Ref**: For `git_repo`, use `git ls-remote` to get the latest ref. For `tar` sources, download the new tarball and run `sha256sum`.
3. **Apply Update**: 
   ```bash
   # Use the bump-package-source script
   bash <path-to-bump-script>/bump_source.sh <element_path> <new_ref>
   ```
4. **Commit**: Ensure you document the source bump in the commit message according to project conventions.
