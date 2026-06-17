#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-git.sh [--dry-run]

Configures safe global Git defaults. Existing user.name and user.email values are preserved.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      export DRY_RUN
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

ensure_git() {
  command_exists git || die "git is required. Run bootstrap.sh first."
}

set_git_config() {
  local key="$1"
  local value="$2"
  local current
  current="$(git config --global --get "$key" 2>/dev/null || true)"

  if [[ "$current" == "$value" ]]; then
    log "Git config already set: $key=$value"
    return 0
  fi

  log "Setting Git config: $key=$value"
  run git config --global "$key" "$value"
}

preserve_identity() {
  local name email
  name="$(git config --global --get user.name 2>/dev/null || true)"
  email="$(git config --global --get user.email 2>/dev/null || true)"

  if [[ -n "$name" ]]; then
    log "Preserving existing git user.name: $name"
  else
    warn "git user.name is not set. Configure it manually with: git config --global user.name 'Your Name'"
  fi

  if [[ -n "$email" ]]; then
    log "Preserving existing git user.email: $email"
  else
    warn "git user.email is not set. Configure it manually with: git config --global user.email you@example.com"
  fi
}

setup_gh_git_auth() {
  if ! command_exists gh; then
    warn "gh is not installed. Skipping gh auth setup-git."
    return 0
  fi

  if gh auth status >/dev/null 2>&1; then
    log "Configuring Git credential integration through gh."
    run gh auth setup-git
  else
    warn "gh is not authenticated. Run gh auth login --web, then re-run this script."
  fi
}

main() {
  ensure_git
  preserve_identity

  set_git_config init.defaultBranch main
  set_git_config pull.rebase false
  set_git_config fetch.prune true
  set_git_config rerere.enabled true
  set_git_config core.editor nvim

  setup_gh_git_auth
  log "Git setup complete."
}

main
