#!/bin/bash
# KDE Linux Reference Skill
# Fetch authoritative build information from invent.kde.org/kde-linux

set -e

REPO_URL="https://invent.kde.org/kde-linux/kde-linux.git"
LOCAL_REPO="/tmp/kde-linux"
CACHE_DIR="/tmp/kde-linux-cache"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Clone or update the repository
ensure_repo() {
    if [ ! -d "$LOCAL_REPO/.git" ]; then
        echo "==> Cloning KDE Linux repository..." >&2
        git clone --depth 1 "$REPO_URL" "$LOCAL_REPO" 2>/dev/null || {
            echo "Error: Could not clone $REPO_URL" >&2
            return 1
        }
    else
        echo "==> Updating KDE Linux repository..." >&2
        cd "$LOCAL_REPO"
        git pull --rebase origin main 2>/dev/null || git pull --rebase origin master 2>/dev/null || true
        cd - >/dev/null
    fi
}

# Search for a package in mkosi configs
search_package() {
    local query="$1"
    echo "==> Searching for packages matching: $query" >&2
    echo ""
    
    grep -r "$query" "$LOCAL_REPO/mkosi.conf.d/" 2>/dev/null | grep -v "^Binary" | sed 's|'"$LOCAL_REPO"'/||' | sort -u
}

# Get info about a specific package
package_info() {
    local pkg="$1"
    echo "==> Package: $pkg" >&2
    echo ""
    
    # Search in all mkosi.conf.d files
    grep -r "$pkg" "$LOCAL_REPO/mkosi.conf.d/" 2>/dev/null | while read line; do
        file=$(echo "$line" | cut -d: -f1 | sed "s|$LOCAL_REPO/||")
        content=$(echo "$line" | cut -d: -f2-)
        echo "File: $file"
        echo "Line: $content"
        echo ""
    done
}

# List all packages in a category
list_packages() {
    local category="$1"
    
    case "$category" in
        all)
            echo "==> All packages in KDE Linux" >&2
            find "$LOCAL_REPO/mkosi.conf.d/" -name "*.conf" -exec echo "=== {} ===" \; -exec grep -E "^\s+[a-z0-9-]+\s*$" {} \;
            ;;
        kde)
            echo "==> KDE packages" >&2
            grep -A 500 "\[Content\]" "$LOCAL_REPO/mkosi.conf.d/00-packages-kde.conf" 2>/dev/null | grep -E "^\s+[a-z0-9-]+\s*$" | sort -u || echo "No 00-packages-kde.conf found"
            ;;
        infrastructure)
            echo "==> Infrastructure and system packages" >&2
            cat "$LOCAL_REPO/mkosi.conf.d/80-packages-cli.conf" 2>/dev/null | grep -E "^\s+[a-z0-9-]+\s*#\s*" | sort -u || echo "No 80-packages-cli.conf found"
            ;;
        *)
            echo "Unknown category: $category" >&2
            echo "Use: list [all|kde|infrastructure]" >&2
            return 1
            ;;
    esac
}

# Main command dispatcher
main() {
    local cmd="$1"
    shift || true
    
    # Ensure repo is available
    ensure_repo || exit 1
    
    case "$cmd" in
        package)
            [ -z "$1" ] && { echo "Usage: kde-linux-ref package <name>" >&2; exit 1; }
            package_info "$1"
            ;;
        search)
            [ -z "$1" ] && { echo "Usage: kde-linux-ref search <query>" >&2; exit 1; }
            search_package "$1"
            ;;
        list)
            list_packages "${1:-all}"
            ;;
        *)
            cat >&2 <<'EOF'
Usage: kde-linux-ref <command> [args]

Commands:
  package <name>       - Get build info for a package
  search <query>       - Search for packages matching query
  list [category]      - List all packages in category
                         Categories: all, kde, infrastructure

Examples:
  kde-linux-ref package kinfocenter
  kde-linux-ref search printing
  kde-linux-ref list infrastructure
EOF
            exit 1
            ;;
    esac
}

main "$@"
