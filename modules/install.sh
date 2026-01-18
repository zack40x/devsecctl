#!/usr/bin/env bash
set -euo pipefail

install_main() {
  # Resolve repo root even if called via symlink
  local SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do
    local DIR
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
  done
  local MODULES_DIR
  MODULES_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  local ROOT_DIR
  ROOT_DIR="$(cd -P "$MODULES_DIR/.." && pwd)"

  local target=""
  # Prefer Homebrew prefix on Apple Silicon if it exists
  if [[ -d "/opt/homebrew/bin" ]]; then
    target="/opt/homebrew/bin/devsecctl"
  else
    target="/usr/local/bin/devsecctl"
  fi

  echo "[*] Installing symlink:"
  echo "[*]   $target -> $ROOT_DIR/devsecctl"
  echo
  read -r -p "Proceed? [y/N] " ans
  if [[ "${ans:-N}" != "y" && "${ans:-N}" != "Y" ]]; then
    echo "[!] Cancelled."
    return 1
  fi

  # Ensure target dir exists
  local target_dir
  target_dir="$(dirname "$target")"
  if [[ ! -d "$target_dir" ]]; then
    echo "[*] Creating: $target_dir"
    sudo mkdir -p "$target_dir"
  fi

  # Create/update symlink
  sudo ln -sf "$ROOT_DIR/devsecctl" "$target"

  echo "[*] Installed ✅"
  echo "[*] Test:"
  echo "[*]   devsecctl --version"
  echo

  # ------------------------------
  # Install zsh completion (best-effort)
  # ------------------------------
  local completion_src="$ROOT_DIR/completions/_devsecctl"
  if [[ -f "$completion_src" ]]; then
    local zsh_comp_dir="$HOME/.zsh/completions"
    mkdir -p "$zsh_comp_dir"
    cp -f "$completion_src" "$zsh_comp_dir/_devsecctl"

    echo "[*] Installed zsh completion ✅"
    echo "[*]   $zsh_comp_dir/_devsecctl"

    # Offer to enable compinit automatically (optional)
    local zshrc="$HOME/.zshrc"
    local need_block="yes"
    if [[ -f "$zshrc" ]]; then
      if grep -q 'fpath=(~/.zsh/completions' "$zshrc" && grep -q 'compinit' "$zshrc"; then
        need_block="no"
      fi
    fi

    if [[ "$need_block" == "yes" ]]; then
      echo
      echo "[*] Zsh needs a one-time setup to enable tab completion."
      echo "[*] Add these lines to ~/.zshrc (recommended):"
      echo "    fpath=(~/.zsh/completions \$fpath)"
      echo "    autoload -Uz compinit"
      echo "    compinit"
      echo
      read -r -p "Add this block to ~/.zshrc now? [y/N] " addz
      if [[ "${addz:-N}" == "y" || "${addz:-N}" == "Y" ]]; then
        {
          echo ""
          echo "# devsecctl completions"
          echo "fpath=(~/.zsh/completions \$fpath)"
          echo "autoload -Uz compinit"
          echo "compinit"
        } >> "$zshrc"
        echo "[*] Updated ~/.zshrc ✅"
        echo "[*] Restart your terminal or run: exec zsh"
      else
        echo "[!] Skipped ~/.zshrc update."
        echo "[*] You can enable later by adding the 3 lines shown above."
      fi
    else
      echo "[*] ~/.zshrc already has completion enabled ✅"
    fi
  else
    echo "[!] No completion file found at: $completion_src"
    echo "[!] Skipping zsh completion install."
  fi
}