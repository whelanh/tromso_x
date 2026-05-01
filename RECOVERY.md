# Automated Build Failure Recovery System

This document describes the automated failure recovery system for Aurora KDE Linux builds.

## Overview

The recovery system monitors BuildStream builds for failures and automatically invokes Claude Code to diagnose and fix issues. It:

1. **Detects failures** — Monitors the build log for "Pipeline Summary" and failure markers
2. **Extracts context** — Captures which elements failed and extracts error details
3. **Invokes Claude Code** — Runs Claude Code with a comprehensive diagnostic prompt
4. **Implements fixes** — Claude Code reads logs, references authority sources, and fixes issues
5. **Commits changes** — Automatically commits fixes with clear messages to git

## Components

### `bst-failure-recovery.py`
Main monitor process that:
- Tails `/var/tmp/aurora-build.log`
- Detects build failures
- Invokes Claude Code with diagnostic prompt
- Manages disk space using safe whitelist
- Reports status to dashboard

**Usage (standalone):**
```bash
python3 bst-failure-recovery.py \
  --log /var/tmp/aurora-build.log \
  --project /var/home/james/dev/kde-linux \
  --dashboard-port 8765
```

### `build-recovery-prompt.txt`
Comprehensive, well-structured prompt for Claude Code that includes:
- Project context and directory structure
- Skills definition (Read, Grep, Edit, Bash, Glob)
- Step-by-step diagnosis methodology
- Common failure patterns and solutions
- Authority source references (Arch PKGBUILD, gnome-build-meta, Dakota)
- Safety constraints and cleanup whitelist
- Success criteria

This prompt is loaded by the recovery script and customized with specific failure details.

### `run-build-with-recovery.sh`
Convenience wrapper that launches:
1. Dashboard (HTML UI on port 8765)
2. Failure recovery monitor (noninteractive agent)
3. Build process (foreground)

All three processes run in parallel. When the build fails, Claude Code automatically kicks in.

## Usage

### Quick Start (Recommended)
```bash
./run-build-with-recovery.sh
# Or for a specific target:
./run-build-with-recovery.sh kde-build-meta.bst:kde/plasma/plasma-workspace.bst
# Or with custom fetchers:
./run-build-with-recovery.sh oci/aurora.bst --fetchers 32
```

This starts:
- `http://localhost:8765` — Live dashboard
- `/tmp/bst-dashboard.log` — Dashboard logs
- `/tmp/bst-failure-recovery.log` — Recovery agent logs
- `/var/tmp/aurora-build.log` — Build output

### Manual Operation (Advanced)
If you want to run components separately:

**Terminal 1: Start the build**
```bash
just bst-build oci/aurora.bst
```

**Terminal 2: Monitor with recovery**
```bash
python3 bst-failure-recovery.py
```

**Terminal 3 (optional): Watch the logs**
```bash
tail -f /tmp/bst-failure-recovery.log
```

## How It Works

### Failure Detection
1. Script watches `/var/tmp/aurora-build.log` for "Pipeline Summary" marker
2. When found, checks if log contains "failed" (case-insensitive)
3. Extracts failing element names and summary from Failure Summary section
4. Creates unique failure ID to avoid duplicate processing

### Claude Code Invocation
When a failure is detected:

1. **Extract context** from build log:
   - Which elements failed
   - What error messages were logged
   - Which BuildStream log file contains details

2. **Build diagnostic prompt** by combining:
   - Base prompt from `build-recovery-prompt.txt`
   - Specific failure context (element names, log file path)

3. **Invoke Claude Code** with:
   - Model: `claude-opus-4-6` (strongest model)
   - No session persistence (noninteractive)
   - Full project context
   - Existing CLAUDE.md instructions

4. **Claude Code will:**
   - Read the build log file
   - Grep for failure patterns in .bst files
   - Consult authority sources:
     - Arch PKGBUILD for KDE packages
     - /var/home/james/reference-repos/gnome-build-meta/ for system packages
     - /var/home/james/reference-repos/dakota/ for OCI/bootc setup
   - Identify root cause
   - Make minimal, targeted fix
   - Commit changes to git
   - Push to origin/main

### Disk Space Management

Safe cleanup whitelist (buildstream-only):
- `/root/.cache/buildstream/*` — BuildStream artifact cache (safe to rebuild)
- `/var/tmp/bst-*.log` — Old build logs (safe to delete)
- `/var/tmp/guestfs-*` — guestfs temporary files (safe to delete)
- `/var/tmp/aurora-*.qcow2` — Old test images (safe, older than 7 days)

If /var reaches 85% usage, these directories are cleaned automatically.

**Important:** The whitelist explicitly excludes user data directories:
- `/var/home/james/.local` — NOT cleaned (user data)
- `/var/home/james/dev` — NOT cleaned (project files)

## Prompt Structure

The recovery prompt is structured in sections:

### 1. Project Context
- What is Aurora KDE Linux?
- Directory structure
- Key files and repos

### 2. Your Skills
- **Read**: Logs, .bst files, PKGBUILD
- **Grep**: Search in .bst files and reference repos
- **Edit**: Modify .bst and cmake files
- **Bash**: Test commands (use sparingly)
- **Glob**: Find files and patches

### 3. Diagnosis Methodology
Step-by-step process:
1. Understand the failure
2. Locate the source
3. Consult authority sources
4. Identify root cause
5. Implement minimal fix
6. Verify the fix

### 4. Common Patterns
Pattern-to-solution mapping:
- "could not find package" → Add missing dependency
- "undefined reference" → Missing library link
- "Patch failed to apply" → Check file existence or update patch
- "Subdirectory references optional component" → Add conditional logic

### 5. Authority Sources
Where to look for correct patterns:
- **Arch PKGBUILD** for KDE packages
- **gnome-build-meta** for system packages (bootc, initramfs, kernel)
- **Dakota** for OCI and bootc setup patterns

### 6. Safety & Success Criteria
- What's safe to modify
- What's NOT safe to touch
- What constitutes success
- What to avoid

## Expected Behavior

### Success Path
1. Build runs and completes
2. If it succeeds, nothing happens (no failure to recover)
3. If it fails, Claude Code is invoked automatically
4. Claude Code diagnoses and fixes the issue
5. Fix is committed and pushed
6. On next build, the fix is already in place

### Failure Path (Claude Code can't fix)
If Claude Code cannot fix the issue:
1. Recovery output is streamed to console
2. Operator reviews the diagnosis
3. Operator can manually fix and re-run build
4. Or modify the prompt in `build-recovery-prompt.txt` for better guidance

### Disk Space Recovery
If /var reaches 85% full during build:
1. Recovery script detects high usage
2. Cleans safe caches (see whitelist above)
3. Reports what was cleaned
4. Build continues

## Logs

### Build Output
```bash
/var/tmp/aurora-build.log      # Main build log (tailed by recovery monitor)
```

### Recovery Agent
```bash
/tmp/bst-failure-recovery.log  # Recovery monitor logs
```

### Dashboard
```bash
/tmp/bst-dashboard.log         # Dashboard logs
```

### Claude Code Session
Output is streamed to recovery logs and console. Full transcript can be found in:
```bash
~/.claude/sessions/  # If session persistence is enabled
```

## Troubleshooting

### Recovery monitor is running but Claude Code isn't invoked
- Check if build actually failed (look for "failed" in `/var/tmp/aurora-build.log`)
- Check `/tmp/bst-failure-recovery.log` for errors
- Ensure `claude` command is installed and in PATH

### Claude Code invoked but fix doesn't work
- Review the diagnostic prompt in `build-recovery-prompt.txt`
- Check Claude Code output in `/tmp/bst-failure-recovery.log`
- The prompt may need refinement for this specific failure type
- Add more detailed guidance to the prompt for similar failures

### Disk space still filling up
- Check what's actually consuming space: `du -sh /var/home/*`
- The whitelist may be incomplete; review CLEANUP section
- Consider extending cleanup whitelist carefully (ask before adding)

### Dashboard not updating
- Check port 8765 is accessible: `curl http://localhost:8765`
- Check dashboard is running: `ps aux | grep bst-dashboard`
- Check `/tmp/bst-dashboard.log` for errors

## Advanced Configuration

### Change the model used
Edit `bst-failure-recovery.py`:
```python
CLAUDE_CODE_MODEL = "claude-opus-4-6"  # Change to sonnet, haiku, etc
```

### Change the dashboard port
```bash
BST_DASHBOARD_PORT=9000 ./run-build-with-recovery.sh
```

### Change the build log location
```bash
BST_LOG=/var/tmp/custom-build.log ./run-build-with-recovery.sh
```

### Extend the recovery prompt
Edit `build-recovery-prompt.txt` to add:
- Project-specific patterns
- Known failure types
- Custom authority sources
- Team-specific practices

## Future Enhancements

Potential improvements:
1. **API-based invocation**: Use RemoteTrigger API instead of CLI
2. **Dashboard integration**: Real-time status updates from recovery
3. **Automated rerun**: Detect if fix is successful and auto-resume build
4. **Multiple models**: Try weaker model first, escalate if needed
5. **Failure caching**: Remember similar failures and pre-built fixes
6. **Notification**: Alert via email/Slack when recovery completes
7. **Metrics**: Track failure rates and recovery success rates

## Files Reference

| File | Purpose |
|------|---------|
| `bst-failure-recovery.py` | Main monitor and Claude Code invoker |
| `build-recovery-prompt.txt` | Comprehensive diagnostic prompt for Claude Code |
| `run-build-with-recovery.sh` | Convenience wrapper (dashboard + recovery + build) |
| `RECOVERY.md` | This document |
| `CLAUDE.md` | Project-wide instructions for Claude Code |

## Integration with CLAUDE.md

The recovery system works in concert with `/var/home/james/dev/kde-linux/CLAUDE.md`:

1. **Reference repos** — Defined in CLAUDE.md, used in recovery prompt
2. **Project guidelines** — CLAUDE.md provides context for Claude Code
3. **Safety constraints** — CLAUDE.md and RECOVERY.md define what's safe to modify

When Claude Code is invoked for recovery, it has full access to CLAUDE.md instructions.
