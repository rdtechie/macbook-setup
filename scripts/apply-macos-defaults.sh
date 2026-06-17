#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"

usage() {
	cat <<'USAGE'
Usage: ./scripts/apply-macos-defaults.sh [--dry-run]

Applies macOS defaults: Finder settings, Dock (auto-hide, half-size, Finder-only),
and keyboard (fastest repeat rate, 25% initial delay).
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=1
		export DRY_RUN
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		die "Unknown argument: $1"
		;;
	esac
	shift
done

require_macos() {
	if is_macos; then
		return 0
	fi

	if [[ "${DRY_RUN:-0}" == "1" ]]; then
		warn "Not running on macOS. Continuing because this is a dry run."
		return 0
	fi

	die "macOS defaults can only be applied on macOS."
}

restart_service() {
	local service="$1"
	if [[ "${DRY_RUN:-0}" == "1" ]]; then
		run killall "$service"
		return 0
	fi

	killall "$service" >/dev/null 2>&1 || true
}

main() {
	require_macos

	# Create a dedicated screenshot directory instead of cluttering the Desktop.
	ensure_dir "$SCREENSHOT_DIR"

	# Save screenshots to the dedicated screenshot directory.
	run defaults write com.apple.screencapture location -string "$SCREENSHOT_DIR"

	# Save screenshots as PNG, the macOS default and safest sharing format.
	run defaults write com.apple.screencapture type -string png

	# Show all filename extensions in Finder to reduce ambiguity when editing config files.
	run defaults write NSGlobalDomain AppleShowAllExtensions -bool true

	# Show the Finder path bar for easier filesystem navigation.
	run defaults write com.apple.finder ShowPathbar -bool true

	# Show the Finder status bar for selected item counts and free-space visibility.
	run defaults write com.apple.finder ShowStatusBar -bool true

	# Search the current folder by default from Finder search windows.
	run defaults write com.apple.finder FXDefaultSearchScope -string SCcf

	# Keep folders first when sorting by name in Finder.
	run defaults write com.apple.finder _FXSortFoldersFirst -bool true

	# Use list view for new Finder windows for denser file operations.
	run defaults write com.apple.finder FXPreferredViewStyle -string Nlsv

	# Avoid writing .DS_Store files to network volumes.
	run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

	# Avoid writing .DS_Store files to USB volumes.
	run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

	# Expand save panels by default so paths and advanced options are visible.
	run defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

	# Expand print panels by default for quicker access to printer options.
	run defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

	# Auto-hide the Dock to reclaim vertical screen space.
	run defaults write com.apple.dock autohide -bool true

	# Set Dock icon size to half the default (48 → 24).
	run defaults write com.apple.dock tilesize -int 24

	# Remove all pinned app icons from the Dock; Finder is always present separately.
	run defaults write com.apple.dock persistent-apps -array

	# Set the keyboard key-repeat rate to the fastest available value.
	run defaults write NSGlobalDomain KeyRepeat -int 2

	# Set the initial key-repeat delay to approximately 25% of the slider range (fast end).
	run defaults write NSGlobalDomain InitialKeyRepeat -int 25

	# Restart affected UI services so non-disruptive defaults take effect.
	restart_service Finder
	restart_service SystemUIServer
	restart_service Dock

	log "macOS defaults applied. Some settings may require a new Finder window or terminal session."
}

main
