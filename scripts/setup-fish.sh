#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

CHANGE_SHELL=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-fish.sh [--dry-run] [--change-shell]

Ensures fish is installed and registered in /etc/shells.
The login shell is not changed unless --change-shell is provided.
Adding fish to /etc/shells requires administrator approval when /etc/shells is not writable.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      export DRY_RUN
      ;;
    --change-shell)
      CHANGE_SHELL=1
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

confirm() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then
    warn "Non-interactive session. Skipping approval prompt: $prompt"
    return 1
  fi

  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

fish_path() {
  if command_exists fish; then
    command -v fish
    return 0
  fi

  local prefix
  prefix="$(brew_prefix)"
  if [[ -x "$prefix/bin/fish" ]]; then
    printf '%s/bin/fish\n' "$prefix"
    return 0
  fi

  return 1
}

ensure_fish_installed() {
  if command_exists fish; then
    log "fish detected: $(command -v fish)"
    return 0
  fi

  die "fish is not installed. Run bootstrap.sh first."
}

ensure_shell_registered() {
  local shell_path="$1"

  if grep -Fxq "$shell_path" /etc/shells 2>/dev/null; then
    log "fish already registered in /etc/shells: $shell_path"
    return 0
  fi

  warn "fish is not listed in /etc/shells: $shell_path"
  warn "This operation modifies /etc/shells and usually requires administrator approval."

  if [[ "$DRY_RUN" == "1" ]]; then
    run sudo sh -c "printf '%s\\n' '$shell_path' >> /etc/shells"
    return 0
  fi

  if [[ -w /etc/shells ]]; then
    log "Appending fish to /etc/shells."
    printf '%s\n' "$shell_path" >> /etc/shells
    return 0
  fi

  if confirm "Add $shell_path to /etc/shells with sudo?"; then
    printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
  else
    warn "Skipped /etc/shells update. Manual command: echo '$shell_path' | sudo tee -a /etc/shells"
  fi
}

change_login_shell() {
  local shell_path="$1"

  if [[ "$CHANGE_SHELL" != "1" ]]; then
    warn "Login shell unchanged. Re-run with --change-shell if you want fish as your login shell."
    return 0
  fi

  local current_shell="${SHELL:-}"
  if [[ "$current_shell" == "$shell_path" ]]; then
    log "Login shell already set to fish: $shell_path"
    return 0
  fi

  warn "Changing the login shell affects new terminal sessions."
  if [[ "$DRY_RUN" == "1" ]]; then
    run chsh -s "$shell_path"
    return 0
  fi

  if confirm "Change login shell to $shell_path?"; then
    run chsh -s "$shell_path"
    log "Login shell changed. Open a new terminal session to use fish."
  else
    warn "Login shell unchanged."
  fi
}

main() {
  ensure_fish_installed

  local shell_path
  shell_path="$(fish_path)"
  ensure_shell_registered "$shell_path"
  change_login_shell "$shell_path"

  log "fish setup complete. A new terminal session may be required for shell changes."
}

main
