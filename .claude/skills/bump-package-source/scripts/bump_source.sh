#!/bin/bash
# Bump package version and update source hashes in .bst files
# Usage: bump_source.sh <bst_file> [--version VERSION] [--git-ref] [--sha256-url URL]

set -euo pipefail

BST_FILE="${1:?BST file path required}"
VERSION="${2:-}"
GIT_REF="${3:-}"
SHA256_URL="${4:-}"

if [[ ! -f "$BST_FILE" ]]; then
    echo "Error: File not found: $BST_FILE" >&2
    exit 1
fi

echo "=== Package Source Bumper ===" >&2
echo "File: $BST_FILE" >&2
echo "" >&2

# Extract current values from .bst file
CURRENT_VERSION=$(grep -oP '(?<=pkgver=|version=)[^\s]+' "$BST_FILE" | head -1 || echo "unknown")
echo "Current version: $CURRENT_VERSION" >&2

# Handle git ref update
if [[ "$GIT_REF" == "true" || "$GIT_REF" == "--git-ref" ]]; then
    echo "" >&2
    echo "Updating git references..." >&2

    # Extract git sources from .bst file
    git_urls=$(grep -oP 'https?://github\.com/[^\s"]+' "$BST_FILE" || echo "")

    if [[ -n "$git_urls" ]]; then
        # For each git URL, get the latest commit hash
        while IFS= read -r git_url; do
            echo "  Fetching latest commit from: $git_url" >&2

            # Extract owner/repo from GitHub URL
            if [[ "$git_url" =~ github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
                owner="${BASH_REMATCH[1]}"
                repo="${BASH_REMATCH[2]}"

                # Fetch latest commit hash
                latest_ref=$(curl -sfL "https://api.github.com/repos/$owner/$repo/commits/HEAD" 2>/dev/null | grep -oP '"sha": "\K[a-f0-9]{40}' | head -1)

                if [[ -n "$latest_ref" ]]; then
                    echo "    Latest commit: $latest_ref" >&2
                    echo "    Update in .bst file: Change 'ref:' to $latest_ref"
                else
                    echo "    Could not fetch latest commit" >&2
                fi
            fi
        done <<< "$git_urls"
    else
        echo "  No git sources found in file" >&2
    fi
fi

# Handle SHA256 calculation
if [[ -n "$SHA256_URL" && "$SHA256_URL" != "--"* ]]; then
    echo "" >&2
    echo "Calculating SHA256 for tarball..." >&2
    echo "URL: $SHA256_URL" >&2

    # Download tarball and calculate SHA256
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT

    if curl -sfL -o "$tmpfile" "$SHA256_URL"; then
        sha256=$(sha256sum "$tmpfile" | cut -d' ' -f1)
        echo "New SHA256: $sha256" >&2
        echo "" >&2
        echo "Update in .bst file: Change 'sha256:' to $sha256"
    else
        echo "Error: Could not download tarball" >&2
        exit 1
    fi
fi

echo "" >&2
echo "=== Current .bst file ===" >&2
head -20 "$BST_FILE"
