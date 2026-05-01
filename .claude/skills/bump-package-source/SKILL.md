---
name: bump-package-source
description: Bump package versions and update source hashes in .bst files. Use this when a build failure requires updating git refs, tarball URLs, or SHA256 checksums. Fetches the latest git commit hash or calculates new tarball SHA256.
---

# Package Source Bumper

Update package versions, git refs, and tarball SHAs in .bst files.

## When to use

- Build fails due to missing source or old version
- Need to update git commit reference to latest
- Need to recalculate SHA256 for a new tarball
- Version bump required to match upstream

## Usage

```bash
# Update git ref to latest commit
bump-package-source kde/plasma/kwin.bst --git-ref

# Calculate SHA256 for a new tarball
bump-package-source kde/plasma/kwin.bst --sha256-url https://github.com/.../archive/v6.1.0.tar.gz

# Update both version and git ref
bump-package-source kde/plasma/kwin.bst --version 6.1.0 --git-ref
```

## What it does

1. **Git refs**: Fetches latest commit hash from git repository
2. **Tarballs**: Downloads tarball and calculates SHA256
3. **Version updates**: Updates version strings in .bst file
4. **Validation**: Verifies the .bst file is valid after changes

## Output

Returns the updated .bst file content with:
- New git ref or tarball URL
- Updated SHA256 hash
- Version bumped
- All other fields preserved
