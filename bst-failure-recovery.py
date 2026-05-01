#!/usr/bin/env python3
"""Automated BuildStream failure recovery with Claude Code integration.

Monitors build logs for failures and automatically triggers Claude Code
to diagnose and fix issues using reference repositories.
"""

import os
import re
import sys
import time
import json
import fcntl
import argparse
import subprocess
import threading
from datetime import datetime
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────

LOCK_FILE = "/var/tmp/bst-failure-recovery.lock"
PI_MODEL = "unsloth/Qwen3.6-27B-GGUF"
SESSION_NAME = "pi-recovery-session"

# Whitelist of safe directories to clean when disk space is low
SAFE_CLEANUP_WHITELIST = [
    "/root/.cache/buildstream",
    "/var/tmp/bst-*.log",
    "/var/tmp/guestfs-*",
    "/var/tmp/aurora-*.qcow2",
]

def parse_args():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--log",              default=None)
    p.add_argument("--project",          default=None)
    p.add_argument("--dashboard-port",   type=int, default=None)
    p.add_argument("--help", "-h",       action="store_true")
    args, _ = p.parse_known_args()
    if args.help:
        print(__doc__)
        sys.exit(0)
    return args

args = parse_args()

LOG_FILE = args.log or os.environ.get("BST_LOG", "/var/tmp/aurora-build.log")
PROJECT_DIR = args.project or os.environ.get("BST_PROJECT", "/var/home/james/dev/kde-linux")
DASHBOARD_PORT = args.dashboard_port or int(os.environ.get("BST_DASHBOARD_PORT", "8765"))

def ensure_exclusive():
    """Ensure that only one instance of this script is running."""
    lock_file = open(LOCK_FILE, "w")
    try:
        fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return lock_file
    except IOError:
        print(f"[{datetime.now().isoformat()}] Error: Another instance of bst-failure-recovery.py is already running.", file=sys.stderr)
        sys.exit(1)

# ── Failure Detection ──────────────────────────────────────────────────────

class FailureDetector:
    def __init__(self):
        self.last_failure_hash = None

    def strip_ansi(self, text):
        return re.sub(r'\x1b\[[0-9;]*[mGKHF]', '', text)

    def extract_failure_context(self, log_content):
        clean = self.strip_ansi(log_content)
        # Look for the failure pattern anywhere in the log
        failure_pattern = r'FAILURE\s+([\w./:-]+\.bst[^\n]*)'
        failures = re.findall(failure_pattern, clean)
        seen = set()
        # Keep unique failures in order
        failures = [f.strip() for f in failures if not (f.strip() in seen or seen.add(f.strip()))]

        # Try to find a failure summary block if it exists
        summary_pattern = r'Failure Summary.*?(?=Pipeline Summary|\Z)'
        summary_match = re.search(summary_pattern, clean, re.DOTALL)
        summary_section = summary_match.group(0) if summary_match else ""

        # Extract log paths mentioned in the log
        log_path_pattern = r'(?:/root|/var/home/[^/]+)/\.cache/buildstream/logs/\S+\.log'
        raw_paths = re.findall(log_path_pattern, clean)
        home = os.path.expanduser("~")
        log_paths = [p.replace("/root/.cache", f"{home}/.cache") for p in raw_paths]

        return {
            "failures": failures,
            "summary": summary_section,
            "log_paths": log_paths,
            "timestamp": datetime.now().isoformat(),
        }

    def check_for_failures(self):
        if not os.path.exists(LOG_FILE):
            return None
        try:
            with open(LOG_FILE, "r") as f:
                content = f.read()

            # We don't wait for "Pipeline Summary" anymore. 
            # If ANY failure is present, we want to know.
            if "FAILURE" not in content:
                return None

            context = self.extract_failure_context(content)
            if not context["failures"]:
                return None

            # Only return context if the set of failures has changed
            failure_hash = hash(tuple(sorted(context["failures"])))
            if failure_hash != self.last_failure_hash:
                self.last_failure_hash = failure_hash
                return context

            return None
        except Exception as e:
            print(f"Error checking for failures: {e}", file=sys.stderr)
            return None

# ── Claude Code Integration ────────────────────────────────────────────────

class PiRecovery:
    def __init__(self, project_dir):
        self.project_dir = project_dir
        self.session = SESSION_NAME
        self.is_active = False 
        self.start_time = 0

    def is_process_running(self):
        """Check if the 'pi' process is still alive in the tmux session."""
        res = subprocess.run(["tmux", "has-session", "-t", self.session], capture_output=True, check=False)
        if res.returncode != 0:
            return False
        
        # Check if pi is running in the session
        # We look for 'pi' as a command name or in the cmdline
        try:
            res = subprocess.run(["pgrep", "-f", "pi --model"], capture_output=True, check=False)
            return res.returncode == 0
        except Exception:
            return False

    def is_busy(self):
        """Check if the pi agent is currently working (not at prompt)."""
        # We consider it busy if the tmux pane doesn't end with a prompt
        try:
            pane = subprocess.run(
                ["tmux", "capture-pane", "-t", f"{self.session}:0", "-p"],
                capture_output=True, text=True, check=False
            ).stdout
            # Common shell prompts or Pi prompt
            if re.search(r'(❯|#|\$)\s*$', pane.strip(), re.MULTILINE):
                return False
            return True
        except Exception:
            return False

    def interrupt(self):
        """Interrupt the active pi agent."""
        print(f"[{datetime.now().isoformat()}] Interrupting active pi agent...", file=sys.stderr)
        subprocess.run(["tmux", "send-keys", "-t", f"{self.session}:0", "C-c"], check=False)
        time.sleep(1)

    def invoke_recovery(self, failure_context, log_file, reuse_existing=False):
        """Invoke or re-prompt pi coding agent in a tmux window."""
        self._append_failure_header(failure_context, log_file, reuse_existing)
        
        if reuse_existing:
            prompt_text = "\n\n⚠️  STEERING UPDATE: New Build failure detected while you were working!\n"
            prompt_text += "Please add this to your task list or pivot if this is more urgent:\n"
        else:
            prompt_text = "Build failure detected:\n"
        
        prompt_text += self._format_failure_message(failure_context)
        
        target = f"{self.session}:0"
        
        if not reuse_existing:
            print(f"[{datetime.now().isoformat()}] Starting fresh pi recovery agent on {target}...", file=sys.stderr)
            pi_cmd = self._build_pi_command(prompt_text)
            
            # Kill existing session if any to start clean
            subprocess.run(["tmux", "kill-session", "-t", self.session], capture_output=True, check=False)
            subprocess.run(["tmux", "new-session", "-d", "-s", self.session], check=False)
            time.sleep(0.5)
            # Use printf to send multiline command safely
            subprocess.run(["tmux", "send-keys", "-t", target, f"cd {self.project_dir} && {pi_cmd}", "Enter"], check=False)
        else:
            print(f"[{datetime.now().isoformat()}] Re-prompting existing pi recovery agent on {target}...", file=sys.stderr)
            # Send the new prompt text into the existing tmux session
            # We use a more robust way to send text: write to a temp file and read it in tmux if possible,
            # but send-keys is simpler for now.
            escaped_prompt = prompt_text.replace("'", "'\\''")
            subprocess.run(["tmux", "send-keys", "-t", target, escaped_prompt, "Enter"], check=False)

        self.is_active = True
        self.start_time = time.time()

    def poll(self):
        """Check if pi agent has finished its task (returned to prompt)."""
        if not self.is_active:
            return False
        
        if not self.is_busy():
            # If it's not busy anymore, it might have finished
            self.is_active = False
            return True
        
        return False

    def get_output(self):
        try:
            return subprocess.run(
                ["tmux", "capture-pane", "-t", f"{self.session}:0", "-p", "-S", "-500"],
                capture_output=True, text=True, check=False
            ).stdout
        except Exception:
            return "Failed to capture output"

    def _build_pi_command(self, prompt):
        # We need to escape the prompt for the shell command
        escaped_prompt = prompt.replace("'", "'\"'\"'")
        return f"pi --model {PI_MODEL} --session-dir {self.project_dir}/.claude/sessions --no-extensions --no-prompt-templates --no-themes --no-context-files --skill {self.project_dir}/.claude/skills/arch-pkgbuild --skill {self.project_dir}/.claude/skills/build-log-extract --skill {self.project_dir}/.claude/skills/bst-lint --skill {self.project_dir}/.claude/skills/bump-package-source --system-prompt 'You are an automated build repair agent for KDE Linux BuildStream. You must fully fix build failures without stopping to ask questions or summarize. Always: extract the error, read the .bst file, apply a fix, validate with bst-lint, commit with git, and append to RECOVERY_LOG.md. Never stop partway through.' '{escaped_prompt}'"

    def _format_failure_message(self, failure_context):
        failures = failure_context.get("failures", [])
        summary = failure_context.get("summary", "No summary available")
        log_paths = failure_context.get("log_paths", [])
        msg = f"Failing elements: {', '.join(failures[:3]) if failures else 'Unknown'}\n"
        if summary:
            msg += f"Failure summary:\n{summary[:1000]}\n"
        if log_paths:
            msg += f"\nPossible log: {log_paths[-1]}\n"
        msg += """
Execute these steps:
1. Find exact error in log (use build-log-extract).
2. Read failing .bst (check kde-build-meta-local/elements/).
3. Apply minimal fix.
4. Validate with bst-lint.
5. Commit fix in kde-build-meta-local.
6. Clear stale artifact: just bst artifact delete <element>
7. Append summary to RECOVERY_LOG.md.
"""
        return msg

    def _append_failure_header(self, context, log_file, reuse_existing):
        recovery_log = os.path.join(self.project_dir, "RECOVERY_LOG.md")
        status = "RE-PROMPTING" if reuse_existing else "PENDING"
        header = f"\n### [{datetime.now().isoformat()}] - FAILURE DETECTED ({status})\n"
        header += f"**Failing element(s):** {', '.join(context.get('failures', []))}\n"
        header += f"**Build log:** {log_file}\n"
        try:
            with open(recovery_log, "a") as f:
                f.write(header)
        except Exception:
            pass

    def notify_dashboard(self, status, message=""):
        try:
            import http.client
            conn = http.client.HTTPConnection("localhost", DASHBOARD_PORT, timeout=2)
            payload = json.dumps({
                "event": "recovery_update", "status": status, "message": message,
                "timestamp": datetime.now().isoformat(),
                "elapsed": int(time.time() - self.start_time) if self.is_active else 0
            })
            conn.request("POST", "/api/recovery-status", payload, {"Content-Type": "application/json"})
            conn.close()
        except Exception:
            pass

# ── Main Loop ──────────────────────────────────────────────────────────────

def main():
    lock_h = ensure_exclusive()
    detector = FailureDetector()
    recovery = PiRecovery(PROJECT_DIR)

    print(f"[{datetime.now().isoformat()}] Recovery monitor started")

    while True:
        try:
            failure_context = detector.check_for_failures()

            if failure_context:
                is_running = recovery.is_process_running()
                if is_running:
                    # RE-PROMPT existing agent by just sending keys (no interrupt)
                    recovery.invoke_recovery(failure_context, LOG_FILE, reuse_existing=True)
                else:
                    # START fresh agent
                    recovery.invoke_recovery(failure_context, LOG_FILE, reuse_existing=False)
                
                recovery.notify_dashboard("working", f"Fixing {failure_context['failures'][0]}...")

            if recovery.is_active:
                if recovery.poll():
                    output = recovery.get_output()
                    success = "git commit" in output or "RECOVERY_LOG" in output
                    if success:
                        print(f"[{datetime.now().isoformat()}] Recovery SUCCESS")
                        recovery.notify_dashboard("success", "Fixes applied")
                    else:
                        print(f"[{datetime.now().isoformat()}] Recovery FAILED or INCOMPLETE")
                        recovery.notify_dashboard("failed", "Check tmux session")
            
            time.sleep(15)

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            time.sleep(10)

if __name__ == "__main__":
    main()
