# tmux-port

A tiny tmux plugin to view listening ports, kill processes, and tunnel them out — in an fzf-driven popup.

https://github.com/user-attachments/assets/672e5a16-8be0-441b-ba86-ef36d5dca411

## Features

- **Prefix + t** toggles a floating popup listing every listening TCP port — `PORT • PID • COMMAND • TUNNEL URL` — in an fzf picker (numbered prompt fallback if fzf isn't installed). Rebindable via `@port_bind`.
- Shows all listening ports by default, not just a preset "web dev" range; narrow it down with `@port_filter_ports` if you want.
- Works on macOS (lsof) and Linux (ss).

Inside the picker:

| Key       | Action                                                     |
| --------- | ------------------------------------------------------------ |
| `ctrl-x`  | Kill the selected port's process (and its tunnel, if any) — the only way to kill, without leaving the list |
| `ctrl-t`  | Toggle a Cloudflare Quick Tunnel for the selected port       |
| `ctrl-y`  | Copy the selected port's tunnel URL to the clipboard         |
| `ctrl-r`  | Refresh the list                                             |
| `enter` / `esc` | Close the popup — deliberately does nothing else, so browsing can never accidentally kill anything |

`ctrl-t` starts (or, pressed again, stops) `cloudflared tunnel --url http://localhost:<port>` **entirely in the background** — no new pane, no takeover, the popup stays on the list. As soon as the `trycloudflare.com` URL is assigned it's copied to your clipboard, opened in your browser (disable with `set -g @port_tunnel_open_browser off`), and shown right in the table under **TUNNEL URL** — the picker itself waits for it, so it lands on the same reload instead of needing a manual `ctrl-r` (it only keeps reading `(starting…)` if cloudflared is genuinely slow to come up). Grab the URL again anytime with `ctrl-y`. If `cloudflared` isn't installed, it's installed automatically (no sudo) — via `brew` if available, otherwise a direct download of the official static binary into `~/.local/bin`.

## Prerequisites

- **tmux ≥ 3.0**
- **[fzf](https://github.com/junegunn/fzf)** (recommended — falls back to a numbered prompt without it)
- **[cloudflared](https://github.com/cloudflare/cloudflared)** (optional — only needed for `ctrl-t` tunneling; auto-installed on first use if missing)

## Install via github 
```sh
git clone git@github.com:fiqryq/port.git #close inside tmux/plugin and hit bind + I for install plugins
```

## Install (TPM)

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'fiqryq/port'

# Optional:
set -g @port_bind          't'  # prefix + t opens the popup
set -g @port_popup_width   '90%'
set -g @port_popup_height  '90%'
set -g @port_popup_border  on   # on|off
set -g @port_fzf_options   ''   # extra fzf args, e.g. '--height=100%'
set -g @port_filter_ports  ''   # e.g. '3000 5173 8080' — empty shows every listening port
set -g @port_tunnel_open_browser on  # on|off — auto-open the tunnel URL (ctrl-t)

run '~/.tmux/plugins/tpm/tpm'
```
