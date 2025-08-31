#!/usr/bin/env sh

# resolve plugin dir from this script's location
plugin_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Get popup settings with defaults
w="$(tmux show -gqv @port_popup_width)"
h="$(tmux show -gqv @port_popup_height)"
bd="$(tmux show -gqv @port_popup_border)"
x="$(tmux show -gqv @port_popup_x)"
y="$(tmux show -gqv @port_popup_y)"

# Use floating popup if supported
if tmux display-popup -h >/dev/null 2>&1; then
  # Build popup command
  popup_cmd="tmux display-popup"
  popup_cmd="$popup_cmd -w ${w:-80}"
  popup_cmd="$popup_cmd -h ${h:-20}"
  popup_cmd="$popup_cmd ${bd:-on}"
  
  # Add positioning if specified
  if [ -n "$x" ]; then
    popup_cmd="$popup_cmd -x $x"
  fi
  if [ -n "$y" ]; then
    popup_cmd="$popup_cmd -y $y"
  fi
  
  # Center popup by default if no position specified
  if [ -z "$x" ] && [ -z "$y" ]; then
    popup_cmd="$popup_cmd -d '#{pane_width}x#{pane_height}'"
  fi
  
  # Execute the UI script
  popup_cmd="$popup_cmd -E \"$plugin_dir/scripts/ui.sh\""
  
  eval "$popup_cmd"
else
  # Fallback to split window
  tmux split-window -v -l "${h:-20}" "$plugin_dir/scripts/ui.sh"
fi