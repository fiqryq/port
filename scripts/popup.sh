#!/usr/bin/env sh

# resolve plugin dir from this script's location
plugin_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Get popup settings with defaults
w="$(tmux show -gqv @port_popup_width)"
h="$(tmux show -gqv @port_popup_height)"
bd="$(tmux show -gqv @port_popup_border)"
x="$(tmux show -gqv @port_popup_x)"
y="$(tmux show -gqv @port_popup_y)"

# Use floating popup if supported. `tmux display-popup -h` (no value) is
# always a parse error ("-h expects an argument") regardless of whether the
# running tmux actually has display-popup, so that can't be used to detect
# support — check the command table instead.
if tmux list-commands 2>/dev/null | grep -q '^display-popup '; then
  # Build popup command. display-popup has no on/off argument for the
  # border — it's shown by default and -B turns it off.
  popup_cmd="tmux display-popup"
  popup_cmd="$popup_cmd -w ${w:-90%}"
  popup_cmd="$popup_cmd -h ${h:-90%}"
  case "${bd:-on}" in
    off | Off | OFF) popup_cmd="$popup_cmd -B" ;;
  esac


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
  popup_cmd="$popup_cmd -E \"$plugin_dir/scripts/picker.sh\""
  
  eval "$popup_cmd"
else
  # Fallback to split window (only reached on tmux < 3.2, no display-popup)
  tmux split-window -v -l "${h:-90%}" "$plugin_dir/scripts/picker.sh"
fi