#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
REPO_URL="${REPO_URL:-https://github.com/rdtechie/macbook-setup.git}"
REPO_DIR="${REPO_DIR:-$HOME/src/macbook-setup}"
SKIP_GH_AUTH="${SKIP_GH_AUTH:-0}"
SKIP_PI_INSTALL="${SKIP_PI_INSTALL:-0}"
SKIP_PI_PACKAGES="${SKIP_PI_PACKAGES:-0}"
PI_INSTALL_COMMAND="${PI_INSTALL_COMMAND:-bun install -g @earendil-works/pi-coding-agent}"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap.sh [--dry-run] [--help]

Run this script as your normal macOS user. Do not run it with sudo.
Homebrew may ask for administrator approval during its own installer.

Environment variables:
  REPO_URL          Git URL used when cloning this repo.
  REPO_DIR          Local checkout path. Default: ~/src/macbook-setup
  SKIP_GH_AUTH      Set to 1 to skip GitHub CLI authentication.
  SKIP_PI_INSTALL   Set to 1 to skip installing pi when missing.
  SKIP_PI_PACKAGES  Set to 1 to skip installing packages from config/pi-packages.txt.
  PI_INSTALL_COMMAND Command used to install pi. Default: bun install -g @earendil-works/pi-coding-agent
USAGE
}

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
die() { error "$*"; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_shell() {
  local command_string="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] bash -lc %q\n' "$command_string"
    return 0
  fi
  bash -lc "$command_string"
}

run_homebrew_installer() {
  local install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] /bin/bash -c "$(curl -fsSL %s)"\n' "$install_url"
    return 0
  fi

  # Run the official installer directly from this terminal, without an extra bash -lc wrapper,
  # so sudo prompts stay attached to the user's interactive session.
  /bin/bash -c "$(curl -fsSL "$install_url")"
}

ensure_dir() {
  local dir="$1"
  run mkdir -p "$dir"
}

backup_path() {
  local path="$1"
  local backup_root="$HOME/.backup/macbook-setup/$(date +%Y%m%d%H%M%S)"
  [[ -e "$path" || -L "$path" ]] || return 0
  ensure_dir "$backup_root"
  local dest="$backup_root/$(basename "$path")"
  local counter=1
  while [[ -e "$dest" || -L "$dest" ]]; do
    dest="$backup_root/$(basename "$path").$counter"
    counter=$((counter + 1))
  done
  log "Backing up $path to $dest"
  run mv "$path" "$dest"
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

brew_binary() {
  if command_exists brew; then
    command -v brew
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '/opt/homebrew/bin/brew\n'
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    printf '/usr/local/bin/brew\n'
    return 0
  fi
  return 1
}

brew_prefix_guess() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    printf '/opt/homebrew\n'
  else
    printf '/usr/local\n'
  fi
}

load_homebrew_env() {
  local brew_bin
  brew_bin="$(brew_binary || true)"
  if [[ -z "$brew_bin" ]]; then
    return 1
  fi
  eval "$("$brew_bin" shellenv)"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
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
  export DRY_RUN
}

require_not_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    warn "Running as root. Continuing because this is a dry run."
    return 0
  fi

  die "Do not run bootstrap.sh with sudo. Homebrew refuses root installs and sudo changes HOME. Run as your normal user and approve Homebrew's sudo prompts when requested."
}

require_macos() {
  if is_macos; then
    log "macOS detected: $(sw_vers -productVersion 2>/dev/null || true)"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    warn "Not running on macOS. Continuing because this is a dry run."
    return 0
  fi

  die "This bootstrap script must run on macOS."
}

detect_architecture() {
  case "$(uname -m)" in
    arm64) log "Architecture detected: Apple Silicon" ;;
    x86_64) log "Architecture detected: Intel" ;;
    *) warn "Unknown architecture: $(uname -m)" ;;
  esac
}

ensure_xcode_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed."
    return 0
  fi

  log "Xcode Command Line Tools are missing."
  run xcode-select --install

  if [[ "$DRY_RUN" != "1" ]]; then
    die "Finish the Xcode Command Line Tools installer, then re-run bootstrap.sh."
  fi
}

ensure_homebrew() {
  if load_homebrew_env; then
    log "Homebrew detected: $(brew --version | head -n 1)"
    return 0
  fi

  log "Homebrew is missing. Installing Homebrew as the current user."
  warn "Do not re-run this script with sudo. The Homebrew installer may ask for your macOS password when it needs administrator approval."
  warn "If this step cannot prompt correctly, run the Homebrew installer manually, then re-run ./bootstrap.sh."
  run_homebrew_installer

  local prefix
  prefix="$(brew_prefix_guess)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Would load Homebrew environment from $prefix/bin/brew."
    return 0
  fi

  if [[ ! -x "$prefix/bin/brew" ]]; then
    die "Homebrew installation did not create $prefix/bin/brew."
  fi

  eval "$("$prefix/bin/brew" shellenv)"
}

current_checkout_dir() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$script_dir/Brewfile" && -d "$script_dir/scripts" && -d "$script_dir/skills" ]]; then
    printf '%s\n' "$script_dir"
  else
    printf '%s\n' "$REPO_DIR"
  fi
}

ensure_repo() {
  local repo_dir="$1"
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  if [[ "$repo_dir" == "$script_dir" && -f "$repo_dir/Brewfile" ]]; then
    log "Using local repository checkout: $repo_dir"
    return 0
  fi

  if [[ -d "$repo_dir/.git" ]]; then
    log "Updating existing repository checkout: $repo_dir"
    run git -C "$repo_dir" fetch --prune
    run git -C "$repo_dir" pull --ff-only
    return 0
  fi

  if [[ -e "$repo_dir" ]]; then
    die "$repo_dir exists but is not a Git checkout. Back it up or set REPO_DIR."
  fi

  log "Cloning $REPO_URL to $repo_dir"
  ensure_dir "$(dirname "$repo_dir")"
  run git clone "$REPO_URL" "$repo_dir"
}

install_brew_bundle() {
  local repo_dir="$1"
  local brewfile="$repo_dir/Brewfile"
  [[ -f "$brewfile" ]] || die "Missing Brewfile: $brewfile"
  log "Installing Homebrew packages from $brewfile"
  run brew bundle --file "$brewfile"
}

configure_gh() {
  if [[ "$SKIP_GH_AUTH" == "1" ]]; then
    log "Skipping GitHub CLI authentication because SKIP_GH_AUTH=1."
    return 0
  fi

  if ! command_exists gh; then
    warn "gh is not available after brew bundle. Skipping GitHub authentication."
    return 0
  fi

  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI already authenticated."
  else
    log "GitHub CLI is not authenticated. Starting browser-based login."
    run gh auth login --web
  fi

  if [[ "$DRY_RUN" == "1" ]] || gh auth status >/dev/null 2>&1; then
    log "Configuring Git to use GitHub CLI credentials."
    run gh auth setup-git
  else
    warn "GitHub CLI is still unauthenticated. Skipping gh auth setup-git."
  fi
}

install_pi() {
  if command_exists pi; then
    log "Pi detected: $(command -v pi)"
    return 0
  fi

  if [[ "$SKIP_PI_INSTALL" == "1" ]]; then
    warn "Pi is missing and SKIP_PI_INSTALL=1."
    return 0
  fi

  log "Installing Pi with: $PI_INSTALL_COMMAND"
  run_shell "$PI_INSTALL_COMMAND"
}

install_pi_packages() {
  local repo_dir="$1"
  local packages_file="$repo_dir/config/pi-packages.txt"

  if [[ "$SKIP_PI_PACKAGES" == "1" ]]; then
    log "Skipping Pi package installation because SKIP_PI_PACKAGES=1."
    return 0
  fi

  if ! command_exists pi && [[ "$DRY_RUN" != "1" ]]; then
    warn "Pi is not installed. Skipping Pi package installation."
    return 0
  fi

  [[ -f "$packages_file" ]] || die "Missing Pi packages file: $packages_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[$'\t\r\n ']/}"
    [[ -n "$line" ]] || continue

    local source="$line"
    if [[ "$source" != npm:* && "$source" != git:* && "$source" != http:* && "$source" != https:* && "$source" != /* && "$source" != ./* ]]; then
      source="npm:$source"
    fi

    log "Installing Pi package: $source"
    run pi install "$source"
  done < "$packages_file"
}

register_pi_skill() {
  local repo_dir="$1"
  local source="$repo_dir/skills/macbook-setup"
  local target_dir="$HOME/.pi/agent/skills"
  local target="$target_dir/macbook-setup"

  [[ -f "$source/SKILL.md" ]] || die "Missing skill: $source/SKILL.md"
  ensure_dir "$target_dir"

  if [[ -L "$target" ]]; then
    local existing
    existing="$(readlink "$target")"
    if [[ "$existing" == "$source" ]]; then
      log "Pi skill already registered: $target -> $source"
      return 0
    fi
    backup_path "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  log "Registering Pi skill: $target -> $source"
  run ln -s "$source" "$target"
}

main() {
  parse_args "$@"
  require_not_root
  require_macos
  detect_architecture
  ensure_xcode_command_line_tools
  ensure_homebrew

  local repo_dir
  repo_dir="$(current_checkout_dir)"
  ensure_repo "$repo_dir"

  install_brew_bundle "$repo_dir"
  configure_gh
  install_pi
  install_pi_packages "$repo_dir"
  register_pi_skill "$repo_dir"

  cat <<EOF

Bootstrap complete.

Next steps:
  cd $repo_dir
  pi
  /skill:macbook-setup

EOF
}

main "$@"
