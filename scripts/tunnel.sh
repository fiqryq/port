#!/usr/bin/env bash
# Background Cloudflare Quick Tunnel manager for a port. No visible pane or
# window — state (cloudflared PID + assigned URL) lives in a small file per
# port under tunnel_state_dir(), which list_ports.sh reads to populate the
# TUNNEL URL column.
#
#   tunnel.sh <port>          toggle: start a tunnel if none is running for
#                              this port, stop it if one already is. Returns
#                              immediately either way.
#   tunnel.sh --stop <port>   unconditional stop, no-op if nothing's running.
#   tunnel.sh --copy <port>   copy this port's tunnel URL to the clipboard,
#                              no-op (with a message) if it's not up yet.
#   tunnel.sh --worker <port> internal: install cloudflared if needed, start
#                              it, wait for the URL, copy/open it. Always
#                              launched fully detached from its caller.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

STATE_DIR="$(tunnel_state_dir)"
mkdir -p "$STATE_DIR"

copy_to_clipboard() {
  if have pbcopy; then
    pbcopy
  elif have wl-copy; then
    wl-copy
  elif have xclip; then
    xclip -selection clipboard
  else
    cat >/dev/null
  fi
}

open_browser() {
  if have open; then
    open "$1" >/dev/null 2>&1
  elif have xdg-open; then
    xdg-open "$1" >/dev/null 2>&1
  elif have wslview; then
    wslview "$1" >/dev/null 2>&1
  fi
}

# install_cloudflared: no sudo, nothing system-wide. Prefers brew (kept up
# to date via normal brew upgrades); otherwise pulls the official static
# binary straight from Cloudflare's GitHub releases into ~/.local/bin.
install_cloudflared() {
  echo "cloudflared not found — installing…"

  if have brew; then
    echo "+ brew install cloudflared"
    brew install cloudflared && return 0
    echo "brew install failed, trying a direct download instead…"
  fi

  dest_dir="$HOME/.local/bin"
  mkdir -p "$dest_dir"
  os="$(uname -s)"
  arch="$(uname -m)"
  asset=""
  case "$os" in
    Darwin) asset="cloudflared-darwin-amd64.tgz" ;;
    Linux)
      case "$arch" in
        x86_64 | amd64) asset="cloudflared-linux-amd64" ;;
        aarch64 | arm64) asset="cloudflared-linux-arm64" ;;
        armv7l | armv6l) asset="cloudflared-linux-arm" ;;
      esac
      ;;
  esac
  if [ -z "$asset" ]; then
    echo "Don't know how to install cloudflared for $os/$arch."
    echo "See: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    return 1
  fi

  url="https://github.com/cloudflare/cloudflared/releases/latest/download/$asset"
  echo "+ downloading $url"
  case "$asset" in
    *.tgz)
      tmp="$(mktemp -d)"
      curl -fL "$url" -o "$tmp/cloudflared.tgz" &&
        tar -xzf "$tmp/cloudflared.tgz" -C "$tmp" &&
        mv "$tmp/cloudflared" "$dest_dir/cloudflared" &&
        chmod +x "$dest_dir/cloudflared"
      rc=$?
      rm -rf "$tmp"
      [ "$rc" -eq 0 ] || return 1
      ;;
    *)
      curl -fL "$url" -o "$dest_dir/cloudflared" && chmod +x "$dest_dir/cloudflared" || return 1
      ;;
  esac
  case ":$PATH:" in
    *":$dest_dir:"*) ;;
    *) echo "Note: add $dest_dir to your PATH to use cloudflared outside this plugin." ;;
  esac
  export PATH="$dest_dir:$PATH"
  echo "Installed cloudflared to $dest_dir/cloudflared"
}

# ---------- worker mode: does the real work, always fully detached ----------
if [ "${1:-}" = '--worker' ]; then
  port="${2:?usage: tunnel.sh --worker <port>}"
  f="$STATE_DIR/$port"
  install_log="$STATE_DIR/$port.install.log"

  if ! have cloudflared; then
    tmux display-message "port $port: cloudflared not found — installing…" 2>/dev/null || true
    if ! install_cloudflared >"$install_log" 2>&1 || ! have cloudflared; then
      tmux display-message "port $port: cloudflared install failed (see $install_log)" 2>/dev/null || true
      rm -f "$f"
      exit 1
    fi
    rm -f "$install_log"
  fi

  log="$STATE_DIR/$port.log"
  cloudflared tunnel --url "http://localhost:$port" >"$log" 2>&1 &
  cf_pid=$!
  printf '%s\n\n' "$cf_pid" >"$f"

  url=""
  for _ in $(seq 1 50); do
    url="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$log" 2>/dev/null | head -n1)"
    [ -n "$url" ] && break
    sleep 0.2
  done

  if [ -n "$url" ]; then
    printf '%s\n%s\n' "$cf_pid" "$url" >"$f"
    printf '%s' "$url" | copy_to_clipboard
    tmux display-message "port $port -> $url (copied to clipboard)" 2>/dev/null || true
    if [ "$(get_tmux_option @port_tunnel_open_browser on)" != "off" ]; then
      # Don't open until it's actually reachable — quick tunnels can fail to
      # ever come up, and opening regardless just shows a dead DNS error.
      ready=1
      for _ in $(seq 1 20); do
        curl -sf -o /dev/null --max-time 2 "$url" 2>/dev/null && { ready=0; break; }
        sleep 1
      done
      if [ "$ready" -eq 0 ]; then
        open_browser "$url"
      else
        tmux display-message "port $port: $url not reachable yet — it may still come up; retry ctrl-t if not" 2>/dev/null || true
      fi
    fi
  else
    tmux display-message "port $port: tunnel did not come up in time" 2>/dev/null || true
  fi

  wait "$cf_pid" 2>/dev/null
  rm -f "$f" "$log"
  exit 0
fi

# ---------- --stop: unconditional stop, no-op if nothing's running ----------
# Used when a port's process is killed, so its tunnel doesn't outlive it.
if [ "${1:-}" = '--stop' ]; then
  port="${2:?usage: tunnel.sh --stop <port>}"
  f="$STATE_DIR/$port"
  if [ -f "$f" ]; then
    pid="$(sed -n '1p' "$f" 2>/dev/null)"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$f" "$STATE_DIR/$port.log"
    tmux display-message "port $port: tunnel stopped (port killed)" 2>/dev/null || true
  fi
  exit 0
fi

# ---------- --copy: copy this port's tunnel URL to the clipboard ----------
if [ "${1:-}" = '--copy' ]; then
  port="${2:?usage: tunnel.sh --copy <port>}"
  url="$(tunnel_url_for "$port")"
  case "$url" in
    https://*)
      printf '%s' "$url" | copy_to_clipboard
      tmux display-message "port $port: copied $url" 2>/dev/null || true
      ;;
    *)
      tmux display-message "port $port: no tunnel URL yet" 2>/dev/null || true
      ;;
  esac
  exit 0
fi

# ---------- default: toggle start/stop, return immediately ----------
port="${1:?usage: tunnel.sh <port>}"
f="$STATE_DIR/$port"

if [ -f "$f" ]; then
  pid="$(sed -n '1p' "$f" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    rm -f "$f" "$STATE_DIR/$port.log"
    tmux display-message "port $port: tunnel stopped" 2>/dev/null || true
    exit 0
  fi
  rm -f "$f"
fi

tmux display-message "port $port: starting tunnel…" 2>/dev/null || true
if have setsid; then
  setsid "$DIR/tunnel.sh" --worker "$port" </dev/null >/dev/null 2>&1 &
else
  nohup "$DIR/tunnel.sh" --worker "$port" </dev/null >/dev/null 2>&1 &
fi
disown 2>/dev/null || true
