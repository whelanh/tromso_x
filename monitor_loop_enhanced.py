#!/usr/bin/env python3
import time
import subprocess
from datetime import datetime

def check_build():
    print(f"[{datetime.now().isoformat()}] Checking build status...")
    # Use just to show status
    result = subprocess.run(["just", "bst", "show", "oci/aurora.bst"], capture_output=True, text=True)
    
    if "failed" in result.stdout.lower():
        print(f"[{datetime.now().isoformat()}] ⚠️ FAILURE DETECTED!")
        # Trigger the recovery agent
        subprocess.run(["pkill", "-f", "bst-failure-recovery.py"])
        subprocess.run(["python3", "bst-failure-recovery.py", "--log", "/var/tmp/aurora-build.log", "--project", "/var/home/james/dev/kde-linux", "--dashboard-port", "8765"], start_new_session=True)
    else:
        print(f"[{datetime.now().isoformat()}] Build progressing...")

if __name__ == "__main__":
    while True:
        check_build()
        time.sleep(120)  # 2 minute timer
