#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

ports_usage() {
  cat <<'USAGE'
Usage:
  devsecctl ports list
  devsecctl ports who <port>
  devsecctl ports kill <port>

Examples:
  devsecctl ports list
  devsecctl ports who 3000
  devsecctl ports kill 3000
USAGE
}

is_port() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 ))
}

ports_list() {
  need_cmd lsof
  need_cmd awk
  info "Listening TCP ports (process -> port)"
  # -nP: no DNS, no service name
  # LISTEN: only listeners
  # Output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
  # NAME example: TCP *:3000 (LISTEN)
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
    | awk 'NR==1 {print; next} {print}' \
    | sed 's/$/ /'  # keep output stable
}

ports_who() {
  need_cmd lsof
  local port="${1:-}"
  is_port "$port" || die "Invalid port: $port"

  # lsof exit code is non-zero if nothing found; don't fail the script for that
  local out=""
  out="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "$out" ]]; then
    warn "No process is listening on port $port."
    return 1
  fi

  echo "$out"
}

ports_kill() {
  need_cmd lsof
  need_cmd ps
  local port="${1:-}"
  is_port "$port" || die "Invalid port: $port"

  # Grab PIDs listening on the port
  local pids=""
  pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "$pids" ]]; then
    warn "No process is listening on port $port."
    return 1
  fi

  info "Processes listening on port $port:"
  # Show command lines for clarity
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    ps -p "$pid" -o pid=,comm=,args= || true
  done <<< "$pids"

  echo
  read -r -p "Kill these process(es)? [y/N] " ans
  case "${ans:-N}" in
    y|Y)
      info "Sending SIGTERM..."
      while read -r pid; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
      done <<< "$pids"

      sleep 1

      # If still alive, offer SIGKILL
      local still=""
      still="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
      if [[ -n "$still" ]]; then
        warn "Some process(es) still listening on $port:"
        while read -r pid; do
          [[ -n "$pid" ]] || continue
          ps -p "$pid" -o pid=,comm=,args= || true
        done <<< "$still"
        echo
        read -r -p "Force kill (SIGKILL)? [y/N] " ans2
        case "${ans2:-N}" in
          y|Y)
            info "Sending SIGKILL..."
            while read -r pid; do
              [[ -n "$pid" ]] || continue
              kill -9 "$pid" 2>/dev/null || true
            done <<< "$still"
            ;;
          *) info "OK, leaving remaining processes running." ;;
        esac
      else
        info "Port $port is now free."
      fi
      ;;
    *) info "Cancelled." ;;
  esac
}

ports_main() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    help|-h|--help) ports_usage ;;
    list) ports_list ;;
    who)  ports_who "${1:-}" ;;
    kill) ports_kill "${1:-}" ;;
    *) die "Unknown ports subcommand: $sub. Run: devsecctl ports help" ;;
  esac
}
