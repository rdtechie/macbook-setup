#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

PASS_ITEMS=()
WARN_ITEMS=()
FAIL_ITEMS=()
NEXT_ACTIONS=()

usage() {
	cat <<'USAGE'
Usage: ./scripts/verify.sh

Verifies the macbook-setup workstation state. Safe to run on a partially configured system.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 0
fi

pass_item() {
	PASS_ITEMS+=("$1")
	printf 'PASS %s\n' "$1"
}

warn_item() {
	WARN_ITEMS+=("$1")
	printf 'WARN %s\n' "$1"
}

fail_item() {
	FAIL_ITEMS+=("$1")
	printf 'FAIL %s\n' "$1"
}

next_action() {
	NEXT_ACTIONS+=("$1")
}

check_command() {
	local command_name="$1"
	if command_exists "$command_name"; then
		pass_item "$command_name exists ($(command -v "$command_name"))"
	else
		fail_item "$command_name is missing"
		next_action "Install $command_name via ./bootstrap.sh or brew bundle."
	fi
}

check_gh_auth() {
	if ! command_exists gh; then
		fail_item "gh auth status cannot run because gh is missing"
		return 0
	fi

	if gh auth status >/dev/null 2>&1; then
		pass_item "gh is authenticated"
	else
		warn_item "gh is installed but not authenticated"
		next_action "Run gh auth login --web, then gh auth setup-git."
	fi
}

check_dotfile_link() {
	local path="$1"
	local label="$2"

	if [[ -L "$path" ]]; then
		pass_item "$label symlink exists: $path"
	elif [[ -e "$path" ]]; then
		# Also pass when the file lives inside a stow-folded directory that
		# is itself a symlink into this repo's dotfiles tree.
		local real_path
		real_path="$(realpath "$path" 2>/dev/null || true)"
		if [[ -n "$real_path" && "$real_path" == "$REPO_DIR/dotfiles/"* ]]; then
			pass_item "$label exists via stowed directory: $path"
		else
			warn_item "$label exists but is not a symlink: $path"
			next_action "Review $path, then run ./scripts/setup-dotfiles.sh to back up conflicts and stow dotfiles."
		fi
	else
		warn_item "$label symlink missing: $path"
		next_action "Run ./scripts/setup-dotfiles.sh."
	fi
}

check_pi_skill() {
	local target="$HOME/.pi/agent/skills/macbook-setup"
	local expected="$REPO_DIR/skills/macbook-setup"

	if [[ -L "$target" ]]; then
		local actual
		actual="$(readlink "$target")"
		if [[ "$actual" == "$expected" ]]; then
			pass_item "Pi skill symlink exists: $target -> $expected"
		else
			warn_item "Pi skill symlink points elsewhere: $target -> $actual"
			next_action "Re-run ./bootstrap.sh to register the repository skill."
		fi
	elif [[ -e "$target" ]]; then
		warn_item "Pi skill path exists but is not a symlink: $target"
		next_action "Back up $target, then re-run ./bootstrap.sh."
	else
		fail_item "Pi skill symlink missing: $target"
		next_action "Run ./bootstrap.sh to register the Pi skill."
	fi
}

check_brewfile() {
	if [[ ! -f "$REPO_DIR/Brewfile" ]]; then
		fail_item "Brewfile missing from repository"
		return 0
	fi

	if ! command_exists brew; then
		warn_item "brew bundle check skipped because brew is missing"
		return 0
	fi

	if brew bundle check --file "$REPO_DIR/Brewfile" >/dev/null 2>&1; then
		pass_item "brew bundle check passes"
	else
		warn_item "brew bundle check reports missing or changed packages"
		next_action "Run brew bundle --file $REPO_DIR/Brewfile."
	fi
}

print_summary() {
	printf '\nSummary\n'
	printf '  PASS: %d\n' "${#PASS_ITEMS[@]}"
	printf '  WARN: %d\n' "${#WARN_ITEMS[@]}"
	printf '  FAIL: %d\n' "${#FAIL_ITEMS[@]}"

	if [[ ${#NEXT_ACTIONS[@]} -gt 0 ]]; then
		printf '\nNext manual actions\n'
		local action seen_actions=""
		for action in "${NEXT_ACTIONS[@]}"; do
			if [[ "$seen_actions" == *"|$action|"* ]]; then
				continue
			fi
			printf '  - %s\n' "$action"
			seen_actions+="|$action|"
		done
	fi
}

main() {
	if is_macos; then
		pass_item "macOS detected"
	else
		fail_item "macOS not detected"
		next_action "Run this repository on macOS."
	fi

	check_command brew
	check_command gh
	check_gh_auth
	check_command node
	check_command npm
	check_command pi
	check_command fish
	check_command tmux
	check_command nvim
	check_command mise
	check_command uv
	check_command stow
	check_command lazygit

	check_dotfile_link "$HOME/.config/fish/config.fish" "fish config"
	check_dotfile_link "$HOME/.gitconfig.macbook-setup" "git include config"
	check_dotfile_link "$HOME/.config/nvim/init.lua" "Neovim config"
	check_dotfile_link "$HOME/.tmux.conf" "tmux config"
	check_dotfile_link "$HOME/.config/ghostty/config" "Ghostty config"
	check_dotfile_link "$HOME/.aerospace.toml" "AeroSpace config"
	check_dotfile_link "$HOME/.config/mise/config.toml" "mise config"

	check_pi_skill
	check_brewfile
	print_summary

	if [[ ${#FAIL_ITEMS[@]} -gt 0 ]]; then
		exit 1
	fi
}

main
