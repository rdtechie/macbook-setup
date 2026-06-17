#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-dev-tools.sh [--dry-run]

Verifies and lightly configures developer tooling. This script does not install global language runtimes.
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

check_tool() {
  local tool="$1"
  if command_exists "$tool"; then
    log "$tool detected: $($tool --version 2>/dev/null | head -n 1 || command -v "$tool")"
  else
    warn "$tool is missing. Run bootstrap.sh or brew bundle."
  fi
}

ensure_standard_dirs() {
  ensure_dir "$HOME/.local/bin"
  ensure_dir "$HOME/.config"
}

configure_mise() {
  if ! command_exists mise; then
    warn "mise is missing. Skipping mise configuration."
    return 0
  fi

  log "mise version: $(mise --version 2>/dev/null | head -n 1 || true)"

  if [[ -f "$HOME/.config/mise/config.toml" || -L "$HOME/.config/mise/config.toml" ]]; then
    log "mise config exists: $HOME/.config/mise/config.toml"
  else
    warn "mise config is not linked yet. Run ./scripts/setup-dotfiles.sh."
  fi

  if mise doctor >/dev/null 2>&1; then
    log "mise doctor passed."
  else
    warn "mise doctor reported issues. Run 'mise doctor' for details."
  fi
}

configure_uv() {
  if ! command_exists uv; then
    warn "uv is missing. Skipping uv configuration."
    return 0
  fi

  log "uv version: $(uv --version 2>/dev/null | head -n 1 || true)"
  ensure_dir "$HOME/.cache/uv"
  warn "No global uv tools are installed by default. Add desired tools to repo state before installing them."
}

main() {
  ensure_standard_dirs

  check_tool git
  check_tool gh
  check_tool tmux
  check_tool nvim
  check_tool fish
  check_tool stow
  check_tool jq
  check_tool yq
  check_tool rg
  check_tool fd
  check_tool fzf
  check_tool bat
  check_tool eza
  check_tool zoxide
  check_tool starship
  check_tool shellcheck
  check_tool shfmt

  configure_mise
  configure_uv

  log "Developer tooling setup complete."
  log "Repository root: $REPO_DIR"
}

main
