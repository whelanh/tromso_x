#!/bin/bash
# Fetch PKGBUILD or .bst configuration for a package
# Usage: fetch_pkgbuild.sh <package_name> [version]

set -euo pipefail

PACKAGE_NAME="${1:?Package name required}"
VERSION="${2:-}"

# KDE packages that should query Arch
KDE_PACKAGES=(
    kwin plasma-workspace plasma-desktop plasma-panel
    kdeclarative kactivitymanagerd kded kdeconnect
    kwin-wayland kwin-x11 kscreenlocker
    kate dolphin okular gwenview elisa ark kcalc kdeconnect
    frameworks frameworks-base kdeclarative
    qt6 qt6-base qt6-wayland qt6-declarative
    kconfig kdecorations kwindowsystem kdisplay
)

# System packages that should check gnome-build-meta or dakota
SYSTEM_PACKAGES=(
    systemd bootc lvm2 dracut kernel
    linux-firmware busybox util-linux
    libsystemd libcrypt
)

# Determine package type
is_kde_package() {
    local pkg="$1"
    # Check if package matches KDE pattern
    if [[ "$pkg" =~ ^(kwin|plasma|kdeclarative|kactivity|kded|kscreen|kate|dolphin|okular|gwenview|elisa|ark|kcalc|kdeconnect|frameworks|kconfig|kdecoration|kwindowsystem|kdisplay|qt6) ]]; then
        return 0
    fi
    return 1
}

is_system_package() {
    local pkg="$1"
    if [[ "$pkg" =~ ^(systemd|bootc|lvm2|dracut|kernel|linux|firmware|busybox|util-linux|libsystemd|libcrypt) ]]; then
        return 0
    fi
    return 1
}

# Fetch from Arch PKGBUILD
fetch_arch_pkgbuild() {
    local pkg="$1"
    local ver="${2:-}"

    # Try to fetch from git.archlinux.org (correct format)
    echo "=== Fetching Arch PKGBUILD for $pkg ===" >&2

    # Try new Arch GitLab packaging repo first (Plasma 6 era, no auth needed)
    url="https://gitlab.archlinux.org/archlinux/packaging/packages/${pkg}/-/raw/main/PKGBUILD"
    if output=$(curl -sfL "$url" 2>/dev/null) && echo "$output" | grep -q "^pkgname"; then
        echo "$output"
        echo "" >&2
        return 0
    fi

    # Fallback: GitHub mirrors of Arch svntogit (older Plasma 5 packages)
    for repo in svntogit-packages svntogit-community; do
        url="https://raw.githubusercontent.com/archlinux/${repo}/packages/${pkg}/trunk/PKGBUILD"
        if output=$(curl -sfL "$url" 2>/dev/null) && echo "$output" | grep -q "^pkgname"; then
            echo "$output"
            echo "" >&2
            return 0
        fi
    done

    # Fallback: show where to find it manually
    echo "" >&2
    echo "❌ Could not fetch PKGBUILD automatically." >&2
    echo "Manual lookup: https://archlinux.org/packages/?q=$pkg" >&2
    return 1
}

# Fetch from gnome-build-meta or dakota
fetch_system_config() {
    local pkg="$1"

    echo "=== Fetching system package config for $pkg ===" >&2

    # Check gnome-build-meta first
    GNOME_BUILD_META="/var/home/james/reference-repos/gnome-build-meta"
    DAKOTA="/var/home/james/reference-repos/dakota"

    # Look for .bst files
    if [[ -d "$GNOME_BUILD_META" ]]; then
        local bst_file=$(find "$GNOME_BUILD_META" -name "*$pkg*.bst" 2>/dev/null | head -1)
        if [[ -f "$bst_file" ]]; then
            echo "Found in gnome-build-meta: $bst_file" >&2
            echo "" >&2
            cat "$bst_file"
            return 0
        fi
    fi

    if [[ -d "$DAKOTA" ]]; then
        local bst_file=$(find "$DAKOTA" -name "*$pkg*.bst" 2>/dev/null | head -1)
        if [[ -f "$bst_file" ]]; then
            echo "Found in dakota: $bst_file" >&2
            echo "" >&2
            cat "$bst_file"
            return 0
        fi
    fi

    echo "Package config not found in gnome-build-meta or dakota" >&2
    echo "Search paths:" >&2
    echo "  - $GNOME_BUILD_META/elements/" >&2
    echo "  - $DAKOTA/elements/" >&2
    return 1
}

# Main logic
if is_kde_package "$PACKAGE_NAME"; then
    echo "Detected: KDE package" >&2
    fetch_arch_pkgbuild "$PACKAGE_NAME" "$VERSION"
elif is_system_package "$PACKAGE_NAME"; then
    echo "Detected: System package" >&2
    fetch_system_config "$PACKAGE_NAME"
else
    # Try KDE first, then system
    echo "Package type unknown, trying Arch first..." >&2
    if fetch_arch_pkgbuild "$PACKAGE_NAME" "$VERSION" 2>/dev/null; then
        exit 0
    fi
    echo "Not found in Arch, trying system package sources..." >&2
    fetch_system_config "$PACKAGE_NAME"
fi
