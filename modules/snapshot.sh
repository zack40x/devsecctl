#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

snapshot_usage() {
  cat <<'USAGE'
Usage:
  devsecctl snapshot [full|min|latest|open]

Commands:
  snapshot full   Create a full snapshot (includes sysctl -a)
  snapshot min    Create a fast snapshot (skips heavy sysctl -a)
  snapshot        Same as: snapshot min
  snapshot latest Print the path to the latest report.md
  snapshot open   Open the latest report.md in the default app (macOS)
USAGE
}

root_dir() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

latest_snapshot_dir() {
  local r; r="$(root_dir)"
  ls -1 "$r/output/snapshots" 2>/dev/null | tail -n 1 | awk '{print $0}'
}

latest_report_path() {
  local r d
  r="$(root_dir)"
  d="$(latest_snapshot_dir || true)"
  [[ -n "$d" ]] || return 1
  echo "$r/output/snapshots/$d/report.md"
}

write_cmd() {
  local out="$1"; shift
  {
    echo "### COMMAND: $*"
    echo "### TIME: $(date)"
    echo
    "$@" 2>&1 || true
    echo
  } > "$out"
}

append_cmd() {
  local out="$1"; shift
  {
    echo "### COMMAND: $*"
    echo "### TIME: $(date)"
    echo
    "$@" 2>&1 || true
    echo
  } >> "$out"
}

persistence_launchd() {
  local out="$1"
  {
    echo "## User LaunchAgents (~/Library/LaunchAgents)"
    ls -la "$HOME/Library/LaunchAgents" 2>&1 || true
    echo
    echo "## System LaunchAgents (/Library/LaunchAgents)"
    ls -la "/Library/LaunchAgents" 2>&1 || true
    echo
    echo "## System LaunchDaemons (/Library/LaunchDaemons)"
    ls -la "/Library/LaunchDaemons" 2>&1 || true
    echo
    echo "## launchctl list (user domain)"
    launchctl list 2>&1 || true
  } > "$out"
}

persistence_cron() {
  local out="$1"
  {
    echo "## User crontab"
    crontab -l 2>&1 || true
    echo
    echo "## /etc/crontab"
    cat /etc/crontab 2>&1 || true
    echo
    echo "## /etc/periodic"
    ls -la /etc/periodic 2>&1 || true
  } > "$out"
}

shell_hooks() {
  local out="$1"
  local files=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.zlogin"
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.config/zsh/.zshrc"
  )

  {
    echo "## Shell startup hooks (existence + metadata)"
    local f
    for f in "${files[@]}"; do
      if [[ -e "$f" ]]; then
        echo
        echo "### $f"
        ls -la "$f" 2>&1 || true
        stat "$f" 2>&1 || true
      fi
    done
  } > "$out"
}

generate_report_md() {
  local dir="$1"
  local out="$dir/report.md"

  local host osver ts_now
  host="$(scutil --get ComputerName 2>/dev/null || hostname)"
  osver="$(sw_vers 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' || true)"
  ts_now="$(date)"

  {
    echo "# devsecctl snapshot"
    echo
    echo "- **Host:** $host"
    echo "- **Date:** $ts_now"
    echo "- **OS:** $osver"
    echo
    echo "## Contents"
    echo "- system.txt"
    echo "- processes.txt"
    echo "- listening_ports.txt"
    echo "- connections.txt"
    echo "- users.txt"
    echo "- persistence_launchd.txt"
    echo "- persistence_cron.txt"
    echo "- shell_startup_hooks.txt"
    echo
    echo "## Quick highlights"
    echo "### Listening ports (first 20 lines)"
    echo '```'
    grep -v '^### ' "$dir/listening_ports.txt" 2>/dev/null | head -n 20 || true
    echo '```'
    echo
    echo "### Recent logins (last 30)"
    echo '```'
    grep -v '^### ' "$dir/users.txt" 2>/dev/null | tail -n 40 || true
    echo '```'
  } > "$out"
}

snapshot_create() {
  local mode="$1" # min|full

  need_cmd sw_vers
  need_cmd ps
  need_cmd lsof
  need_cmd who
  need_cmd last
  need_cmd launchctl
  need_cmd stat
  need_cmd uname
  need_cmd uptime

  local r out_dir
  r="$(root_dir)"
  out_dir="$r/output/snapshots/$(ts)"
  mkdir -p "$out_dir"

  info "Creating snapshot ($mode): $out_dir"

  write_cmd "$out_dir/system.txt" uname -a
  append_cmd "$out_dir/system.txt" sw_vers
  append_cmd "$out_dir/system.txt" uptime

  if [[ "$mode" == "full" ]]; then
    need_cmd sysctl
    append_cmd "$out_dir/system.txt" sysctl -a
  else
    append_cmd "$out_dir/system.txt" sysctl kern.ostype kern.osrelease kern.version 2>/dev/null || true
  fi

  write_cmd "$out_dir/processes.txt" ps aux
  write_cmd "$out_dir/listening_ports.txt" lsof -nP -iTCP -sTCP:LISTEN
  write_cmd "$out_dir/connections.txt" lsof -nP -iTCP -sTCP:ESTABLISHED

  write_cmd "$out_dir/users.txt" who
  append_cmd "$out_dir/users.txt" last -n 30

  persistence_launchd "$out_dir/persistence_launchd.txt"
  persistence_cron "$out_dir/persistence_cron.txt"
  shell_hooks "$out_dir/shell_startup_hooks.txt"

  generate_report_md "$out_dir"

  info "Snapshot complete ✅"
  info "View report:"
  info "  cat \"$out_dir/report.md\""
  info "  open \"$out_dir/report.md\""
}

snapshot_latest() {
  local p
  p="$(latest_report_path || true)"
  [[ -n "$p" && -f "$p" ]] || die "No snapshots found yet. Run: devsecctl snapshot"
  echo "$p"
}

snapshot_open() {
  need_cmd open
  local p
  p="$(snapshot_latest)"
  info "Opening: $p"
  open "$p"
}

snapshot_main() {
  local sub="${1:-min}"
  shift || true

  case "$sub" in
    help|-h|--help) snapshot_usage ;;
    min|"") snapshot_create "min" ;;
    full) snapshot_create "full" ;;
    latest) snapshot_latest ;;
    open) snapshot_open ;;
    *) die "Unknown snapshot subcommand: $sub. Run: devsecctl snapshot help" ;;
  esac
}
