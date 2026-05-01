---
name: pi-recovery-steering
description: Manage and steer the automated pi recovery agent sessions. Use this to manually provide context, override tasks, or pivot the agent without interrupting progress.
---

# Pi Recovery Steering

This skill provides the commands to manage the automated build failure recovery agent.

## Core Commands

- **Steer Agent**: Send updated context to the active `pi` recovery session.
  ```bash
  cat <<'EOF' | tmux load-buffer -
  [YOUR NEW CONTEXT OR STEERING INSTRUCTIONS]
  EOF
  tmux paste-buffer -t 1:6
  tmux send-keys -t 1:6 Enter
  ```
  *(Note: Adjust window target `1:6` based on the actual location of the `pi-recovery` window).*

- **Verify Agent Progress**: Capture the latest output to ensure the agent is acting on the steered input.
  ```bash
  tmux capture-pane -t 1:6 -p -S -50
  ```

## Best Practices

- **Add, Don't Stop**: Use "STEERING UPDATE" in your messages to indicate you are *adding* information, not *changing* the goal unless necessary.
- **Stay Concise**: The agent has limited context; keep steering messages focused on new failure details (log paths, specific errors).
- **Verify**: Always follow up with a `capture-pane` check to ensure the agent received the prompt.
