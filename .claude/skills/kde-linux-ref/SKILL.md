name: kde-linux-ref
description: Fetch authoritative build configuration and package lists from invent.kde.org/kde-linux. Use this to verify package dependencies, build flags, and configuration for any KDE Linux package or infrastructure component. Always use this as the source of truth for how packages should be built in Aurora.
compatibility: bash, curl, git
---

# KDE Linux Official Reference

Fetch authoritative build configuration, cmake flags, dependencies, and package lists directly from the official KDE Linux repositories on invent.kde.org.

## When to use

- You need to verify how a KDE package should be built (dependencies, cmake flags)
- You're diagnosing a build failure and need to match official KDE Linux configuration
- You need to check if a package exists in KDE Linux or what version is used
- You're unsure about transitive dependencies or optional build features
- You need the canonical package list from KDE Linux

## Supported queries

### Package build information
```bash
kde-linux-ref package kinfocenter
kde-linux-ref package kdeplasma-addons
kde-linux-ref package konsole
```

Returns: mkosi configuration references, build dependencies, version info from kde-linux repos

### Infrastructure and system packages
```bash
kde-linux-ref package cups
kde-linux-ref package fprintd
kde-linux-ref package vulkan-headers
```

Returns: Package status in KDE Linux mkosi configs (included/excluded), version, purpose

### Search for packages
```bash
kde-linux-ref search printing
kde-linux-ref search hardware
kde-linux-ref search vulkan
```

Returns: All packages in KDE Linux matching the search term, grouped by category

### Get full package list
```bash
kde-linux-ref list all
kde-linux-ref list kde
kde-linux-ref list infrastructure
```

Returns: Complete package list from KDE Linux mkosi configs, organized by category

## Output

Returns structured information from the authoritative source:

- **Package version** (what version KDE Linux uses)
- **mkosi configuration** (from mkosi.conf.d/ files)
- **Dependencies** (runtime and build dependencies)
- **Build flags** (cmake options, configure flags)
- **Rationale** (comments from KDE Linux about why package is included)
- **File location** (which mkosi.conf.d/*.conf file it's in)

## Implementation

Run this script directly with Bash:

```bash
bash /var/home/james/dev/kde-linux/.claude/skills/kde-linux-ref/scripts/fetch_kde_linux_ref.sh <command> [args]
```

## Source repos

Primary:
- **invent.kde.org/kde-linux/kde-linux** — Official KDE Linux distribution (mkosi-based)
  - mkosi.conf — Base config
  - mkosi.conf.d/*.conf — Category-specific package lists
- **invent.kde.org/kde-linux/kde-build-meta** — BuildStream .bst configs (if applicable)

Fallback (if official repos unavailable):
- Local clones in /tmp/kde-linux/ or /var/home/james/dev/kde-linux/kde-linux-reference/

## Example usage

**Verify kinfocenter in official KDE Linux:**
```
kde-linux-ref package kinfocenter
```

Output shows that KDE Linux includes `vulkan-headers` as a make dependency (from mkosi.conf.d/80-packages-cli.conf).

**Check if printing packages are in KDE Linux:**
```
kde-linux-ref search printing
```

Output lists all printing-related packages (cups, hplip, system-config-printer, etc.) with their mkosi.conf.d locations.

**Get complete infrastructure package list:**
```
kde-linux-ref list infrastructure
```

Output shows all system packages (filesystems, printing, hardware) that KDE Linux includes.

## Notes

- invent.kde.org is the **authoritative source** — configurations there reflect official KDE decisions
- KDE Linux uses mkosi (Arch-based), not BuildStream, but the configuration logic applies
- Always prefer invent.kde.org information over Arch PKGBUILD or other sources
- When a package is in KDE Linux, Aurora should include it to maintain feature parity
