#!/usr/bin/env bash
# Interactive fzf picker for listening ports.
#
#   picker.sh          fzf picker; ctrl-x is the only way to kill a port —
#                       enter/esc just close the popup, no action taken.
#   picker.sh --list   print header + rows (initial input and reload target).
#
# When fzf isn't installed, falls back to a numbered prompt (there, typing
# a number IS the kill action — there's no separate "just browse" key in a
# plain prompt).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

rows() {
  printf '%-8s  %-8s  %-16s  %s\n' "PORT" "PID" "COMMAND" "TUNNEL URL"
  "$DIR/list_ports.sh"
}

[ "${1:-}" = '--list' ] && { rows; exit 0; }

# --wait-list <port>: reload target for right after ctrl-t starts a tunnel.
# The worker publishes its URL asynchronously (cloudflared takes a few
# seconds), so reloading right away just reprints "(starting...)" — poll
# the state file for up to ~10s (matching the worker's own timeout) before
# printing rows, so the URL shows up on this reload instead of needing a
# manual ctrl-r afterwards. If ctrl-t just *stopped* a tunnel instead, the
# state file is already gone synchronously by the time this runs, so the
# loop below is skipped and this behaves like a plain --list.
if [ "${1:-}" = '--wait-list' ]; then
  port="${2:?usage: picker.sh --wait-list <port>}"
  f="$(tunnel_state_dir)/$port"
  if [ -f "$f" ]; then
    for _ in $(seq 1 40); do
      case "$(tunnel_url_for "$port")" in https://*) break ;; esac
      [ -f "$f" ] || break
      sleep 0.25
    done
  fi
  rows
  exit 0
fi

kill_by_pid() {
  port="$1"
  pid="$2"
  if [ -z "$pid" ]; then
    tmux display-message "port: empty PID" 2>/dev/null || true
    return 1
  fi
  if kill -TERM "$pid" 2>/dev/null; then
    sleep 0.2
    if ps -p "$pid" >/dev/null 2>&1; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    tmux display-message "port: killed PID $pid" 2>/dev/null || true
    # A tunnel outliving the process it points at is just a dead link —
    # stop it too, if one's running (no-op otherwise).
    [ -n "$port" ] && "$DIR/tunnel.sh" --stop "$port" >/dev/null 2>&1
  else
    tmux display-message "port: failed to signal PID $pid" 2>/dev/null || true
    return 1
  fi
}

if ! have fzf; then
  # Prompt fallback: no fzf available.
  map_file="$(mktemp)"
  n=0
  while read -r port pid cmd url; do
    n=$((n + 1))
    printf "%2d) %-7s  %-7s  %-15s  %s\n" "$n" "$port" "$pid" "$cmd" "$url"
    printf '%s\t%s\t%s\t%s\n' "$port" "$pid" "$cmd" "$url" >>"$map_file"
  done <<EOF
$("$DIR/list_ports.sh")
EOF
  if [ "$n" -eq 0 ]; then
    echo "No listening ports."
    rm -f "$map_file"
    read -r _
    exit 0
  fi
  printf "\nEnter number to kill (or blank to cancel): "
  read -r choice
  case "$choice" in
    '')
      rm -f "$map_file"
      ;;
    *)
      if echo "$choice" | grep -Eq '^[0-9]+$' && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
        row_port="$(awk -F '\t' -v n="$choice" 'NR==n{print $1}' "$map_file")"
        pid="$(awk -F '\t' -v n="$choice" 'NR==n{print $2}' "$map_file")"
        rm -f "$map_file"
        [ -n "$pid" ] && kill_by_pid "$row_port" "$pid"
      else
        rm -f "$map_file"
        echo "Invalid choice."
        read -r _
      fi
      ;;
  esac
  exit 0
fi

self="$DIR/picker.sh"

# A user's own FZF_DEFAULT_OPTS (e.g. a custom --preview) would otherwise
# silently mix into this invocation's options — this picker sets its own
# explicit set below and shouldn't inherit anything else.
export FZF_DEFAULT_OPTS=''

# Arbitrary user fzf options (e.g. custom --bind or --preview-window)
extra_opts=()
fzf_options="$(get_tmux_option @port_fzf_options '')"
[ -n "$fzf_options" ] && eval "extra_opts=($fzf_options)"

# ctrl-x is the only way to kill: it kills without leaving the list, so
# multiple ports can be cleared in one sitting. enter is deliberately
# inert here — it just closes the popup like esc, so browsing/selecting a
# row can never accidentally kill anything.
# ctrl-t toggles a Cloudflare Quick Tunnel for the selected port entirely in
# the background — no new pane or window. tunnel.sh returns immediately
# after kicking off (or stopping) a detached worker; --wait-list polls for
# the URL so it shows up on this same reload instead of needing ctrl-r.
# ctrl-y copies the tunnel URL to the clipboard once it's up.
rows | fzf --ansi --delimiter='\s\s+' --header-lines=1 \
  --prompt 'port> ' --reverse --cycle \
  --header='Ports · ctrl-x: kill · ctrl-t: tunnel (bg) · ctrl-y: copy url · ctrl-r: refresh · enter/esc: close' \
  --preview='ps -o pid,ppid,etime,rss,command -p {2} 2>/dev/null || echo "(process gone)"' \
  --preview-window='down,6,border-top' \
  --bind="ctrl-x:execute-silent(kill {2} 2>/dev/null; $DIR/tunnel.sh --stop {1} >/dev/null 2>&1; sleep 0.2)+reload($self --list)" \
  --bind="ctrl-t:execute-silent($DIR/tunnel.sh {1})+reload(sleep 0.3; $self --wait-list {1})" \
  --bind="ctrl-y:execute-silent($DIR/tunnel.sh --copy {1})" \
  --bind="ctrl-r:reload($self --list)" \
  ${extra_opts[@]+"${extra_opts[@]}"} >/dev/null

exit 0
