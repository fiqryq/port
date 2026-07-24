#!/usr/bin/env sh
# Sourced by other scripts — deliberately does not `set -e`/`-u` here, since
# that would silently override whatever error-handling policy the sourcing
# script chose for itself (list_ports.sh sets its own -eu; picker.sh and
# tunnel.sh intentionally skip -e since normal operation involves commands
# that "fail" harmlessly, e.g. grep finding no match yet).

have() { command -v "$1" >/dev/null 2>&1; }

# get_tmux_option <option-name> <default>
# Echoes the global tmux option value, or the default when unset/empty.
get_tmux_option() {
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# Pretty header
print_header() {
  printf "%-7s  %-7s  %-s\n" "PORT" "PID" "COMMAND"
  printf "%-7s  %-7s  %-s\n" "-----" "-----" "-------"
}

# tunnel_state_dir — directory holding one state file per active tunnel,
# named by port. File format: line 1 = cloudflared PID, line 2 = URL (blank
# until assigned).
tunnel_state_dir() {
  base="${TMPDIR:-/tmp}"
  printf '%s/tmux-port-tunnels-%s' "${base%/}" "$(id -u)"
}

# tunnel_url_for <port> — echoes the tunnel URL for a port if one is
# running and ready, "(starting…)" if running but not ready yet, or nothing
# if no tunnel is active. Prunes the state file if its process has died.
tunnel_url_for() {
  f="$(tunnel_state_dir)/$1"
  [ -f "$f" ] || return 0
  pid="$(sed -n '1p' "$f" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    url="$(sed -n '2p' "$f" 2>/dev/null)"
    if [ -n "$url" ]; then
      printf '%s' "$url"
    else
      printf '(starting…)'
    fi
  else
    rm -f "$f"
  fi
}