#!/usr/bin/env sh
# Outputs: PORT	PID	COMMAND
set -eu

. "$(dirname "$0")/helpers.sh"

# Get web dev ports from tmux option or use defaults
WEB_DEV_PORTS="$(tmux show -gqv @port_web_dev_ports 2>/dev/null || echo '3000 3001 3002 3003 3004 3005 3006 3007 3008 3009 3010 4000 4001 4002 4003 4004 4005 4006 4007 4008 4009 4010 5000 5001 5002 5003 5004 5005 5006 5007 5008 5009 5010 5173 5174 5175 5176 5177 5178 5179 5180 6000 6001 6002 6003 6004 6005 6006 6007 6008 6009 6010 7000 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 8000 8001 8002 8003 8004 8005 8006 8007 8008 8009 8010 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089 8090 8091 8092 8093 8094 8095 8096 8097 8098 8099 8100 9000 9001 9002 9003 9004 9005 9006 9007 9008 9009 9010')"

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
fi | awk -v dev_ports="$WEB_DEV_PORTS" '
  BEGIN {
    split(dev_ports, ports, " ")
    for (i in ports) dev_port_set[ports[i]] = 1
  }
  $1 in dev_port_set { print $0 }
' | sort -n -k1,1