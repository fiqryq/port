#!/usr/bin/env sh
set -eu

have() { command -v "$1" >/dev/null 2>&1; }

# Pretty header
print_header() {
  printf "%-7s  %-7s  %-s\n" "PORT" "PID" "COMMAND"
  printf "%-7s  %-7s  %-s\n" "-----" "-----" "-------"
}