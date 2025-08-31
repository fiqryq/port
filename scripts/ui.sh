#!/usr/bin/env sh
set -eu

. "$(dirname "$0")/helpers.sh"

refresh() {
  clear
  echo "PORT — listening"; echo
  print_header
  "$(dirname "$0")/list_ports.sh" | awk -F '\t' '{ printf "% -7s  %-7s  % -s\n", $1, $2, $3 }'
  echo
  echo "[k] Kill by selecting a row    [r] Refresh    [q] Quit"
  echo "Star this project on Github : https://github.com/fiqryq/port"
}

kill_by_pid() {
  pid="$1"
  if [ -z "$pid" ]; then
    tmux display-message "port: empty PID"
    return 1
  fi
  if kill -TERM "$pid" 2>/dev/null; then
    sleep 0.2
    if ps -p "$pid" >/dev/null 2>&1; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    tmux display-message "port: killed PID $pid"
  else
    tmux display-message "port: failed to signal PID $pid"
    return 1
  fi
}

pick_and_kill() {
  if command -v fzf >/dev/null 2>&1; then
    row="$($(dirname "$0")/list_ports.sh | awk -F '\t' '{ printf "% -7s  %-7s  % -s\n", $1, $2, $3 }' | fzf --ansi --prompt 'kill> ' --header 'Select a row to kill (Enter)' --reverse || true)"
    [ -z "$row" ] && return 0
    pid="$(printf "%s" "$row" | awk '{print $2}')"
    [ -n "$pid" ] && kill_by_pid "$pid"
  else
    map_file="$(mktemp)"
    n=0
    "$(dirname "$0")/list_ports.sh" | while IFS=$'\t' read -r port pid cmd; do
      n=$((n+1))
      printf "%2d) %-7s  %-7s  %s\n" "$n" "$port" "$pid" "$cmd"
      printf "%s\t%s\t%s\n" "$port" "$pid" "$cmd" >> "$map_file"
    done
    [ "$n" -eq 0 ] && { echo "No listening ports."; rm -f "$map_file"; read -r _; return 0; }
    printf "\nEnter number to kill (or blank to cancel): "
    read -r choice || true
    case "$choice" in
      '' ) rm -f "$map_file"; return 0 ;;
      * ) 
        if echo "$choice" | grep -Eq '^[0-9]+$' && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
          pid="$(awk -F '\t' 'NR==$choice{print $2}' "$map_file" )"
          rm -f "$map_file"
          [ -n "$pid" ] && kill_by_pid "$pid"
        else
          rm -f "$map_file"
          echo "Invalid choice."; read -r _
        fi
      ;; 
    esac
  fi
}

while :; do
  refresh
  stty -echo -icanon time 0 min 1 2>/dev/null || true
  key="$(dd bs=1 count=1 2>/dev/null || true)"
  stty sane 2>/dev/null || true

  case "$key" in
    k|K) clear; echo "Kill mode…"; echo; pick_and_kill ;; 
    r|R) : ;; 
    q|Q|$'\e') exit 0 ;; 
    *) : ;; 
  esac
done
