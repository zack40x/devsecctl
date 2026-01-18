#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

docker_usage() {
  cat <<'USAGE'
Usage:
  devsecctl docker status
  devsecctl docker ps
  devsecctl docker up
  devsecctl docker down
  devsecctl docker clean

Notes:
- "up/down" auto-detects compose files in the current directory:
  compose.yaml, compose.yml, docker-compose.yml, docker-compose.yaml

Examples:
  devsecctl docker status
  devsecctl docker up
USAGE
}

have_docker() {
  command -v docker >/dev/null 2>&1
}

docker_engine_ok() {
  docker info >/dev/null 2>&1
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return 0
  fi
  return 1
}

detect_compose_file() {
  local files=("compose.yaml" "compose.yml" "docker-compose.yml" "docker-compose.yaml")
  local f
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

docker_status() {
  if ! have_docker; then
    die "docker not found. Install Docker Desktop (or a compatible Docker engine) first."
  fi

  info "Docker CLI:"
  docker --version || true

  if docker_engine_ok; then
    info "Docker engine: reachable ✅"
    docker version 2>/dev/null | sed -n '1,25p' || true
  else
    warn "Docker engine not reachable."
    warn "If you're using Docker Desktop, open it and wait until it says 'Running'."
    return 1
  fi

  if compose_cmd >/dev/null 2>&1; then
    info "Compose: available ✅"
    $(compose_cmd) version || true
  else
    warn "Compose not found. Update Docker Desktop or install docker-compose."
  fi
}

docker_ps() {
  have_docker || die "docker not found."
  docker_engine_ok || die "Docker engine not reachable. Start Docker Desktop first."
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

docker_up() {
  have_docker || die "docker not found."
  docker_engine_ok || die "Docker engine not reachable. Start Docker Desktop first."

  local cc
  cc="$(compose_cmd)" || die "Compose not available. Need 'docker compose' or 'docker-compose'."

  local cf
  cf="$(detect_compose_file)" || die "No compose file found in $(pwd). Expected: compose.yaml / compose.yml / docker-compose.yml / docker-compose.yaml"

  info "Using compose file: $cf"
  info "Bringing stack up (detached)..."
  $cc -f "$cf" up -d

  info "Current containers:"
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

docker_down() {
  have_docker || die "docker not found."
  docker_engine_ok || die "Docker engine not reachable. Start Docker Desktop first."

  local cc
  cc="$(compose_cmd)" || die "Compose not available."

  local cf
  cf="$(detect_compose_file)" || die "No compose file found in $(pwd)."

  info "Using compose file: $cf"
  info "Stopping stack..."
  $cc -f "$cf" down
}

docker_clean() {
  have_docker || die "docker not found."
  docker_engine_ok || die "Docker engine not reachable. Start Docker Desktop first."

  warn "This will remove unused Docker objects (safe prune)."
  echo "It may delete stopped containers, unused networks, dangling images, and build cache."
  read -r -p "Continue? [y/N] " ans
  case "${ans:-N}" in
    y|Y)
      info "Pruning..."
      docker system prune -f
      info "Optional: remove unused volumes (can be destructive)."
      read -r -p "Prune unused volumes too? [y/N] " ans2
      case "${ans2:-N}" in
        y|Y) docker volume prune -f ;;
        *) info "Skipping volume prune." ;;
      esac
      ;;
    *) info "Cancelled." ;;
  esac
}

docker_main() {
  local sub="${1:-help}"
  shift || true

  case "$sub" in
    help|-h|--help) docker_usage ;;
    status) docker_status ;;
    ps) docker_ps ;;
    up) docker_up ;;
    down) docker_down ;;
    clean) docker_clean ;;
    *) die "Unknown docker subcommand: $sub. Run: devsecctl docker help" ;;
  esac
}
