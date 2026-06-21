#!/usr/bin/env bash
set -euo pipefail

# Local ref tracking script for tromso_x / kde-build-meta-x
# Runs bst source track locally (more reliable than CI) and updates
# all KDE, Qt6, core-deps, and freedesktop-sdk refs.
#
# Usage: bash scripts/track-refs-local.sh
#
# Prerequisites:
#   - podman installed
#   - SSH access to github.com/whelanh/kde-build-meta-x
#   - Run from the tromso_x project root

TROMSO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KBM_DIR="/tmp/kde-build-meta-x-track"
KBM_REPO="git@github.com:whelanh/kde-build-meta-x.git"
BST2_IMAGE="registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2:64eb0b4930d57a92710822898fb73af6cc1ae35d"

echo "==> Step 1: Clone/update kde-build-meta-x"
if [ -d "$KBM_DIR/.git" ]; then
    cd "$KBM_DIR" && git fetch origin && git reset --hard origin/master
else
    rm -rf "$KBM_DIR"
    git clone "$KBM_REPO" "$KBM_DIR"
fi
cd "$KBM_DIR"

echo "==> Step 2: Pull BST container image (if needed)"
podman pull "$BST2_IMAGE" 2>/dev/null || true

echo "==> Step 3: Track KDE elements (frameworks, plasma, apps, libs, Qt6)"
podman run --rm --privileged \
    --device /dev/fuse --network=host \
    --security-opt label=type:unconfined_t \
    -v "$KBM_DIR:/src:rw" \
    -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
    -w /src \
    "$BST2_IMAGE" \
    bash -c '
        ELEMENTS=$(find elements/kde -name "*.bst" | sed "s|^elements/||" | sort | tr "\n" " ")
        echo "Tracking $(echo $ELEMENTS | wc -w) KDE elements..."
        bst --no-interactive source track $ELEMENTS || true
    '

echo "==> Step 4: Track core-deps and freedesktop-sdk junction"
podman run --rm --privileged \
    --device /dev/fuse --network=host \
    --security-opt label=type:unconfined_t \
    -v "$KBM_DIR:/src:rw" \
    -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
    -w /src \
    "$BST2_IMAGE" \
    bash -c '
        ELEMENTS=$(find elements/core-deps -name "*.bst" | sed "s|^elements/||" | sort | tr "\n" " ")
        echo "Tracking $(echo $ELEMENTS | wc -w) core-deps + freedesktop-sdk..."
        bst --no-interactive source track freedesktop-sdk.bst $ELEMENTS || true
    '

echo "==> Step 5: Check for changes"
cd "$KBM_DIR"
if git diff --quiet elements/; then
    echo "No ref changes detected. Nothing to do."
    exit 0
fi

echo "Changed elements:"
git diff --stat elements/

echo "==> Step 6: Commit and push to kde-build-meta-x"
git add elements/
TMPDIR=/var/tmp git commit -m "Track all upstream refs $(date -u +%Y-%m-%d)"
git push origin master

echo "==> Step 7: Update tromso_x junction"
FULL_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short=7 HEAD)
curl -sL "https://github.com/whelanh/kde-build-meta-x/archive/${FULL_SHA}.tar.gz" \
    -o /tmp/kbm-track.tar.gz
NEW_REF=$(sha256sum /tmp/kbm-track.tar.gz | cut -d' ' -f1)
NEW_BASE=$(tar tzf /tmp/kbm-track.tar.gz | head -1 | sed 's|/$||')

cd "$TROMSO_DIR"
sed -i "s|url: github:whelanh/kde-build-meta-x/archive/.*|url: github:whelanh/kde-build-meta-x/archive/${FULL_SHA}.tar.gz|" elements/kde-build-meta.bst
sed -i "s|ref: .*|ref: ${NEW_REF}|" elements/kde-build-meta.bst
sed -i "s|base-dir: .*|base-dir: ${NEW_BASE}|" elements/kde-build-meta.bst

echo "==> Step 8: Clear stale caches"
rm -rf .bst/staged-junctions/kde-build-meta.bst

echo "==> Step 9: Commit and push tromso_x"
git add elements/kde-build-meta.bst
TMPDIR=/var/tmp git commit -m "Update junction to kde-build-meta-x ${SHORT_SHA} (tracked refs)"
git push origin main

echo "==> Done! Junction updated to ${SHORT_SHA}"
echo "    Run: BST_FLAGS=\"--no-interactive\" just bst build oci/tromso.bst"
