#!/bin/bash
# Lint BuildStream .bst files
# Usage: lint_bst.sh <bst_file>

set -euo pipefail

BST_FILE="${1:?BST file path required}"

# Convert element path (e.g., "kde/plasma/kwin.bst") to file path
if [[ "$BST_FILE" != /* ]]; then
    # Relative path - prepend elements directory
    if [[ -d "elements" ]]; then
        BST_FILE="elements/$BST_FILE"
    elif [[ -d ".claude/elements" ]]; then
        BST_FILE=".claude/elements/$BST_FILE"
    else
        # Try to find it
        BST_FILE=$(find . -name "$(basename "$BST_FILE")" 2>/dev/null | head -1)
    fi
fi

if [[ ! -f "$BST_FILE" ]]; then
    echo "Error: File not found: $BST_FILE" >&2
    exit 1
fi

echo "=== BuildStream File Lint ===" >&2
echo "File: $BST_FILE" >&2
echo "" >&2

# Check if python3 and pyyaml are available
if ! command -v python3 &> /dev/null; then
    echo "⚠️  python3 not found, doing basic checks only" >&2
    echo "" >&2
fi

# Try to validate YAML
if command -v python3 &> /dev/null; then
    python3 -c "
import yaml
import sys

try:
    with open('$BST_FILE', 'r') as f:
        data = yaml.safe_load(f)
    print('✓ YAML syntax: Valid')

    # Check required fields
    required = ['kind']
    for field in required:
        if field in data:
            print(f'✓ {field}: Present')
        else:
            print(f'✗ {field}: MISSING')

    # Show build-depends
    if 'build-depends' in data:
        deps = data['build-depends']
        print(f'✓ build-depends: {len(deps)} items')
        for i, dep in enumerate(deps[:5]):
            print(f'  - {dep}')
        if len(deps) > 5:
            print(f'  ... and {len(deps) - 5} more')
    else:
        print('⚠️  build-depends: Not defined')

except yaml.YAMLError as e:
    print(f'✗ YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ Error: {e}')
    sys.exit(1)
" 2>&1
else
    # Fallback: basic grep checks
    echo "Basic checks (YAML parser not available):" >&2
    echo "" >&2

    if grep -q "^kind:" "$BST_FILE"; then
        echo "✓ kind: Present"
    else
        echo "✗ kind: MISSING"
    fi

    if grep -q "build-depends:" "$BST_FILE"; then
        echo "✓ build-depends: Present"
        echo "  First 3 entries:"
        grep -A 3 "build-depends:" "$BST_FILE" | head -4
    else
        echo "⚠️  build-depends: Not defined"
    fi
fi

echo "" >&2
echo "=== File Content ===" >&2
wc -l "$BST_FILE"
head -30 "$BST_FILE"
