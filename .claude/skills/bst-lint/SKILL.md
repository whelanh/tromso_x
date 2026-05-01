---
name: bst-lint
description: Validate and lint BuildStream .bst files. Use this to check YAML syntax, required keys, and structural validity before committing changes. Pass the .bst file path.
---

# BuildStream File Linter

Validate BuildStream .bst files for syntax errors and structural issues.

## Usage

```bash
# Validate a .bst file
bst-lint elements/kde-build-meta.bst:kde/plasma/kwin.bst

# Or with full path
bst-lint /var/home/james/dev/kde-linux/elements/kde/plasma/kwin.bst
```

## Output

Returns:
- **Syntax errors** (if any YAML is malformed)
- **Required key warnings** (kind, sources, build-depends, etc.)
- **Indentation issues**
- **Dependencies check** (lists all build-depends)
- **Overall validity** (pass/fail)

## Implementation

The script will:

1. Parse the .bst file as YAML
2. Check required fields (kind, sources, etc.)
3. Validate indentation and structure
4. Report any issues found

Use this before committing to catch mistakes early.
