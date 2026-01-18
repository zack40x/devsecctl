#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

redact_usage() {
  cat <<'USAGE'
Usage:
  devsecctl redact latest
  devsecctl redact <snapshot_dir>

Creates a sanitized copy of a snapshot bundle for safe sharing.
Output:
  output/redacted/<timestamp>/

Redactions (best-effort):
- username + /Users/<name> paths
- home directory paths
- local/private IPs (10.x, 172.16-31.x, 192.168.x)
- MAC addresses (basic pattern)
USAGE
}

root_dir() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

latest_snapshot_dir_path() {
  local r d
  r="$(root_dir)"
  d="$(ls -1 "$r/output/snapshots" 2>/dev/null | tail -n 1 || true)"
  [[ -n "$d" ]] || return 1
  echo "$r/output/snapshots/$d"
}

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  (cd "$src" && tar -cf - .) | (cd "$dst" && tar -xf -)
}

redact_file_in_place() {
  local f="$1"
  local user home
  user="$(id -un 2>/dev/null || echo "")"
  home="$HOME"

  DEVSECCTL_USER="$user" DEVSECCTL_HOME="$home" perl -i -pe '
    my $user = $ENV{"DEVSECCTL_USER"} // "";
    my $home = $ENV{"DEVSECCTL_HOME"} // "";

    # redact explicit username occurrences (standalone) + /Users/<user>
    if ($user ne "") {
      s/\b\Q$user\E\b/<USER>/g;
      s/\/Users\/\Q$user\E/\/Users\/<USER>/g;
    }

    # redact home directory path
    if ($home ne "") {
      s/\Q$home\E/<HOME>/g;
    }

    # redact generic /Users/<something>
    s/\/Users\/[A-Za-z0-9._-]+/\/Users\/<USER>/g;

    # private IPv4 ranges
    s/\b10(?:\.\d{1,3}){3}\b/<PRIVATE_IP>/g;
    s/\b192\.168(?:\.\d{1,3}){2}\b/<PRIVATE_IP>/g;
    s/\b172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2}\b/<PRIVATE_IP>/g;

    # MAC addresses
    s/\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b/<MAC>/g;
  ' "$f" 2>/dev/null || true
}

redact_dir() {
  local src="$1"
  [[ -d "$src" ]] || die "Snapshot directory not found: $src"

  local r out_dir
  r="$(root_dir)"
  out_dir="$r/output/redacted/$(ts)"
  mkdir -p "$out_dir"

  info "Copying snapshot -> $out_dir"
  copy_tree "$src" "$out_dir"

  info "Redacting files..."
  find "$out_dir" -type f \( -name "*.txt" -o -name "*.md" -o -name "*.log" \) -print0 \
    | while IFS= read -r -d '' f; do
        redact_file_in_place "$f"
      done

  info "Redaction complete ✅"
  info "Safe-to-share folder:"
  info "  $out_dir"
  info "Tip: zip it"
  info "  (cd \"$out_dir\" && zip -r ../redacted_$(basename "$out_dir").zip .)"
}

redact_main() {
  local arg="${1:-help}"

  case "$arg" in
    help|-h|--help) redact_usage ;;
    latest)
      local p
      p="$(latest_snapshot_dir_path || true)"
      [[ -n "$p" ]] || die "No snapshots found. Run: devsecctl snapshot"
      redact_dir "$p"
      ;;
    *)
      redact_dir "$arg"
      ;;
  esac
}
