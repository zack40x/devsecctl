#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

install_usage() {
  cat <<'USAGE'
Usage:
  devsecctl install

Creates a symlink so you can run:
  devsecctl ...

Targets (in order):
  /usr/local/bin
  /opt/homebrew/bin
  ~/.linuxbrew/bin
  /home/linuxbrew/.linuxbrew/bin
USAGE
}

install_main() {
  local sub="${1:-run}"
  case "$sub" in
    help|-h|--help) install_usage; return 0 ;;
    run|"") ;;
    *) die "Unknown install subcommand: $sub" ;;
  esac

  local root target link
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  target=""

  if [[ -d "/usr/local/bin" ]]; then
    target="/usr/local/bin"
  elif [[ -d "/opt/homebrew/bin" ]]; then
    target="/opt/homebrew/bin"
  elif [[ -d "$HOME/.linuxbrew/bin" ]]; then
    target="$HOME/.linuxbrew/bin"
  elif [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    target="/home/linuxbrew/.linuxbrew/bin"
  else
    die "No standard bin directory found. Add this repo to PATH manually."
  fi

  link="$target/devsecctl"

  info "Installing symlink:"
  info "  $link -> $root/devsecctl"
  echo
  read -r -p "Proceed? [y/N] " ans
  case "${ans:-N}" in
    y|Y)
      # If installing into a system dir, use sudo. For user-owned dirs, no sudo needed.
      if [[ "$target" == "$HOME/.linuxbrew/bin" ]]; then
        ln -sf "$root/devsecctl" "$link"
      else
        sudo ln -sf "$root/devsecctl" "$link"
      fi

      info "Installed ✅"
      info "Test:"
      info "  devsecctl --version"
      ;;
    *) info "Cancelled." ;;
  esac
}
