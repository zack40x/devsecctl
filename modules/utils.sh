#!/usr/bin/env bash
set -euo pipefail

info() { printf "[*] %s\n" "$*"; }
warn() { printf "[!] %s\n" "$*" >&2; }
die()  { printf "[x] %s\n" "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

ts() { date +"%Y-%m-%d_%H-%M-%S"; }

os_name() {
  uname -s 2>/dev/null || echo "Unknown"
}

is_macos() { [[ "$(os_name)" == "Darwin" ]]; }
is_linux() { [[ "$(os_name)" == "Linux" ]]; }

open_file() {
  local path="$1"
  if is_macos; then
    need_cmd open
    open "$path"
  elif is_linux; then
    need_cmd xdg-open
    xdg-open "$path" >/dev/null 2>&1 &
  else
    die "open_file not supported on this OS."
  fi
}
