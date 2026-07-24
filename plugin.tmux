#!/usr/bin/env bash
# tmux-port
#
# View listening ports, kill processes, and tunnel them out — via an fzf
# popup. Press prefix + <bind key> to open (default: t).
#
# Install via TPM:
#   set -g @plugin 'fiqryq/port'
#
# Or source directly in tmux.conf:
#   run-shell /path/to/plugin.tmux

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/scripts/helpers.sh"

bind_key="$(get_tmux_option @port_bind 't')"

# Use your actual folder name "port" to avoid #{plugin_dir} issues
tmux unbind -q "$bind_key"
tmux bind-key "$bind_key" run-shell "$TMUX_PLUGIN_MANAGER_PATH/port/scripts/popup.sh"
