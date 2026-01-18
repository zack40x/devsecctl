#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

doctor_usage() {
  cat <<'USAGE'
Usage:
  devsecctl doctor

Checks your environment for required tools and common issues.
USAGE
}

check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    info "OK: $name"
    return 0
  else
    warn "MISSING: $name"
    return 1
  fi
}

doctor_main() {
  local sub="${1:-run}"
  case "$sub" in
    help|-h|--help) doctor_usage; return 0 ;;
    run|"") ;;
    *) die "Unknown doctor subcommand: $sub" ;;
  esac

  info "System"
  if is_macos; then
    info "OK: macOS detected"
  elif is_linux; then
    info "OK: Linux detected"
  else
    warn "Unknown OS: $(os_name) (some modules may not work)"
  fi
  echo

  info "Core commands"
  local missing=0
  check_cmd bash || missing=1
  check_cmd ps || missing=1
  check_cmd awk || missing=1
  check_cmd sed || missing=1
  check_cmd who || missing=1
  check_cmd last || missing=1
  check_cmd stat || missing=1

  # Ports module prefers lsof; Linux may also use ss
  if command -v lsof >/dev/null 2>&1; then
    info "OK: lsof"
  else
    warn "MISSING: lsof (ports/snapshot will degrade; install lsof)"
    missing=1
  fi

  # Snapshot networking on Linux can use ss
  if is_linux && ! command -v ss >/dev/null 2>&1; then
    warn "Missing: ss (recommended on Linux; install iproute2). Snapshot will fallback to lsof."
  fi

  # OS-specific open command
  if is_macos; then
    check_cmd open || missing=1
    check_cmd launchctl || warn "launchctl missing? (unusual on macOS)"
  elif is_linux; then
    if command -v xdg-open >/dev/null 2>&1; then
      info "OK: xdg-open"
    else
      warn "MISSING: xdg-open (snapshot open won't work; install xdg-utils)"
    fi
    if command -v systemctl >/dev/null 2>&1; then
      info "OK: systemctl"
    else
      warn "systemctl not found (persistence checks will be limited)"
    fi
  fi
  echo

  info "Docker"
  if command -v docker >/dev/null 2>&1; then
    info "OK: docker installed"
    if docker info >/dev/null 2>&1; then
      info "OK: docker engine reachable"
    else
      warn "docker engine not reachable (start Docker Desktop / Docker service)"
      missing=1
    fi

    if docker compose version >/dev/null 2>&1; then
      info "OK: docker compose available"
    elif command -v docker-compose >/dev/null 2>&1; then
      info "OK: docker-compose available"
    else
      warn "Compose not found"
      missing=1
    fi
  else
    warn "docker not installed (Docker module will not work)"
  fi
  echo

  info "Result"
  if [[ "$missing" -eq 0 ]]; then
    info "All checks passed ✅"
  else
    warn "Some checks failed. Fix items above then re-run: devsecctl doctor"
    return 1
  fi
}