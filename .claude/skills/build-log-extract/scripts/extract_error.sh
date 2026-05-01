#!/bin/bash
# Extract error context from BuildStream build log
# Usage: extract_error.sh <log_file>

set -euo pipefail

LOG_FILE="${1:?Log file path required}"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Log file not found: $LOG_FILE" >&2
    exit 1
fi

echo "=== Build Log Error Extraction ===" >&2
echo "File: $LOG_FILE" >&2
echo "" >&2

# Extract the failing element name
ELEMENT=$(grep -oP '\[.*?\]\s+\[.*?\]\s+\[\s*build\s*:\K[^\]]*' "$LOG_FILE" | tail -1 || echo "Unknown element")

# Try to find the FAILURE marker and error details
if grep -q "FAILURE\|ERROR" "$LOG_FILE"; then
    echo "=== Error Details ===" >&2
    echo "" >&2

    # Get the last 100 lines which usually contain the actual error
    tail -100 "$LOG_FILE"
else
    echo "No explicit FAILURE marker found, showing last 50 lines:" >&2
    echo "" >&2
    tail -50 "$LOG_FILE"
fi
