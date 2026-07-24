#!/usr/bin/env sh
# Outputs: PORT	PID	COMMAND	TUNNEL URL
set -eu

. "$(dirname "$0")/helpers.sh"

# All listening ports are shown by default. @port_filter_ports optionally
# narrows the list to a space-separated allowlist (e.g. '3000 5173 8080'),
# but leaving it unset — the default — shows everything, not just a
# preset "web dev" range.
FILTER_PORTS="$(get_tmux_option @port_filter_ports '')"

if have ss; then
  # Linux path
  ss -ltnp 2>/dev/null | awk '
    BEGIN{OFS="\t"}
    NR>1 {
      port=$4
      sub(/:.*/, "", port)
      cmd_pid=$NF
      cmd=""
      pid=""
      if (match(cmd_pid, /\("?([^\",]+)"?\\?,pid=([0-9]+)/, m)) { cmd=m[1]; pid=m[2] }
      else if (match(cmd_pid, /\("([^\",]+)",pid=([0-9]+)/, m)) { cmd=m[1]; pid=m[2] }
      if (port != "" && pid != "" && cmd != "") print port, pid, cmd
    }' 
elif have lsof; then
  # macOS / fallback
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk '
    BEGIN{OFS="\t"}
    NR>1 {
      cmd=$1; pid=$2; name=$9
      port=name
      # Extract port number from *:port, ip:port, or [ip]:port
      if (match(port, /:([0-9]+)$/)) {
        port = substr(port, RSTART+1)
        sub(/\(LISTEN\)$/, "", port)
      } else if (match(port, /]:([0-9]+)$/)) {
        port = substr(port, RSTART+2)
        sub(/\(LISTEN\)$/, "", port)
      }
      if (port ~ /^[0-9]+$/) print port, pid, cmd
    }'
else
  echo "Missing tools: need either 'ss' (Linux) or 'lsof' (macOS)" >&2
  exit 1
fi | awk -v filter="$FILTER_PORTS" '
  BEGIN {
    n = split(filter, ports, " ")
    for (i in ports) allow[ports[i]] = 1
  }
  n == 0 || $1 in allow { print $0 }
' | sort -n -k1,1 -k2,2 | awk -F'\t' '!seen[$1 FS $2]++' | {
  # Columns are padded and separated by 2+ spaces (not a bare tab) so the
  # table has real breathing room instead of relying on the terminal's
  # default tab-stop width. picker.sh's fzf --delimiter matches that same
  # "2+ spaces" run, so {1}/{2}/etc. still extract clean, unpadded values.
  while IFS="$(printf '\t')" read -r port pid cmd; do
    url="$(tunnel_url_for "$port")"
    printf '%-8s  %-8s  %-16s  %s\n' "$port" "$pid" "$cmd" "$url"
  done
}