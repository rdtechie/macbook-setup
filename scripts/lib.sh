#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  error "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_dir() {
  local dir="$1"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '[dry-run] mkdir -p %q\n' "$dir"
    return 0
  fi
  mkdir -p "$dir"
}

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

backup_path() {
  local path="$1"
  local backup_root="${2:-$HOME/.backup/macbook-setup/$(date +%Y%m%d%H%M%S)}"

  [[ -e "$path" || -L "$path" ]] || return 0

  ensure_dir "$backup_root"

  local base dest counter
  base="$(basename "$path")"
  dest="$backup_root/$base"
  counter=1

  while [[ -e "$dest" || -L "$dest" ]]; do
    dest="$backup_root/${base}.${counter}"
    counter=$((counter + 1))
  done

  log "Backing up $path to $dest"
  run mv "$path" "$dest"
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

brew_prefix() {
  if command_exists brew; then
    brew --prefix
    return 0
  fi

  if [[ "$(uname -m)" == "arm64" && -x /opt/homebrew/bin/brew ]]; then
    printf '/opt/homebrew\n'
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    printf '/usr/local\n'
    return 0
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    printf '/opt/homebrew\n'
  else
    printf '/usr/local\n'
  fi
}
