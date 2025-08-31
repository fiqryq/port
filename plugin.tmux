# Defaults (users can override in .tmux.conf)
set -gq @port_popup_width  80
set -gq @port_popup_height 20
set -gq @port_popup_border on
set -gq @port_popup_x      ''  # Horizontal position (empty for center)
set -gq @port_popup_y      ''  # Vertical position (empty for center)
set -gq @port_bind 'G'         # Prefix + G
set -gq @port_web_dev_ports '3000 3001 3002 3003 3004 3005 3006 3007 3008 3009 3010 4000 4001 4002 4003 4004 4005 4006 4007 4008 4009 4010 5000 5001 5002 5003 5004 5005 5006 5007 5008 5009 5010 5173 5174 5175 5176 5177 5178 5179 5180 6000 6001 6002 6003 6004 6005 6006 6007 6008 6009 6010 7000 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 8000 8001 8002 8003 8004 8005 8006 8007 8008 8009 8010 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089 8090 8091 8092 8093 8094 8095 8096 8097 8098 8099 8100 9000 9001 9002 9003 9004 9005 9006 9007 9008 9009 9010'

# Use your actual folder name "port" to avoid #{plugin_dir} issues
unbind -q G
bind-key G run-shell "$TMUX_PLUGIN_MANAGER_PATH/port/scripts/popup.sh"

# Optional hint on attach (static text keeps it simple)
set-hook -g client-attached "run-shell 'tmux display-message \"port: Prefix+G to open\"'"
