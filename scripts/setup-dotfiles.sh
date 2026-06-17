#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.backup/macbook-setup/$(date +%Y%m%d%H%M%S)}"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-dotfiles.sh [--dry-run]

Stows every package under dotfiles/ into $HOME.
Conflicting files are moved to ~/.backup/macbook-setup/<timestamp>/ before stow runs.
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

same_symlink_target() {
  local link_path="$1"
  local expected_target="$2"

  [[ -L "$link_path" ]] || return 1

  local actual_target actual_real expected_real
  actual_target="$(readlink "$link_path")"

  if [[ "$actual_target" == "$expected_target" ]]; then
    return 0
  fi

  actual_real="$(cd -- "$(dirname -- "$link_path")" 2>/dev/null && cd -- "$(dirname -- "$actual_target")" 2>/dev/null && pwd -P)/$(basename -- "$actual_target")" || true
  expected_real="$(cd -- "$(dirname -- "$expected_target")" && pwd -P)/$(basename -- "$expected_target")"

  [[ "$actual_real" == "$expected_real" ]]
}

backup_conflicts_for_package() {
  local package="$1"
  local package_dir="$DOTFILES_DIR/$package"

  while IFS= read -r -d '' source_path; do
    local relative_path target_path
    relative_path="${source_path#"$package_dir/"}"
    target_path="$HOME/$relative_path"

    if [[ -L "$target_path" ]] && same_symlink_target "$target_path" "$source_path"; then
      log "Dotfile already linked: $target_path"
      continue
    fi

    if [[ -e "$target_path" || -L "$target_path" ]]; then
      warn "Backing up conflicting dotfile: $target_path"
      backup_path "$target_path" "$BACKUP_ROOT"
    fi
  done < <(find "$package_dir" -type f -print0)
}

stow_package() {
  local package="$1"
  log "Stowing package: $package"
  run stow --dir "$DOTFILES_DIR" --target "$HOME" --restow "$package"
}

main() {
  command_exists stow || die "GNU Stow is required. Run bootstrap.sh first."
  [[ -d "$DOTFILES_DIR" ]] || die "Missing dotfiles directory: $DOTFILES_DIR"

  local packages=()
  while IFS= read -r package_dir; do
    packages+=("$(basename "$package_dir")")
  done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ ${#packages[@]} -eq 0 ]]; then
    warn "No dotfile packages found in $DOTFILES_DIR."
    return 0
  fi

  for package in "${packages[@]}"; do
    backup_conflicts_for_package "$package"
    stow_package "$package"
  done

  log "Dotfile setup complete. Backups, if any, are in $BACKUP_ROOT."
}

main
