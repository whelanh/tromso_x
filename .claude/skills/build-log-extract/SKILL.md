---
name: build-log-extract
description: Extract error context from BuildStream logs. Use this to quickly get the failure details, error messages, and last 50 lines of a build log without having to read the entire file. Pass the log file path and it returns the relevant error section.
---

# Build Log Error Extractor

Extract error messages and context from BuildStream build logs.

## Usage

```bash
# Extract errors from a build log
build-log-extract /root/.cache/buildstream/logs/gnome/kde-plasma-kwin/f835f6d5-build.20260426-143229.log
```

## Output

Returns:
- **Error message** (the actual compilation/build error)
- **Last 50 lines** of the log (context around the failure)
- **Element name** (which package failed)
- **Timestamp** (when the failure occurred)

## Implementation

Run this script directly with Bash:

```bash
bash /var/home/james/dev/kde-linux/.claude/skills/build-log-extract/scripts/extract_error.sh <log_file>
```

This extracts the last 100 lines containing the error, rather than loading the entire log into context.
