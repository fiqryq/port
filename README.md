# tmux-port

A tiny tmux plugin to view listening ports and kill processes — in a centered popup or split panes.

https://github.com/user-attachments/assets/672e5a16-8be0-441b-ba86-ef36d5dca411

## Features

- **Prefix + G** toggles a floating popup showing `PORT • PID • COMMAND`.
- Kill a process by selecting it (fzf if available; prompt fallback).
- Works on macOS (lsof) and Linux (ss).

## Install (TPM)

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'fiqry/port'

# Optional:
set -g @port_popup_width  80
set -g @port_popup_height 20
set -g @port_popup_border on   # on|off

run '~/.tmux/plugins/tpm/tpm'
```
