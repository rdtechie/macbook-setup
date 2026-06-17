# macbook-setup

Opinionated, repeatable macOS provisioning for a DevOps workstation.

This repo provisions a new MacBook in two stages:

1. `bootstrap.sh` installs prerequisites and registers the Pi skill.
2. The Pi skill follows `plans/implementation-plan.md` to apply and verify richer configuration.

The shell script installs prerequisites. The repository defines desired state. The Pi skill defines agent behavior. The implementation plan defines execution order. The agent executes, verifies, and reports.

## What this repo configures

- Xcode Command Line Tools
- Homebrew and `Brewfile` packages
- GitHub CLI authentication and Git credential integration
- Pi and Pi packages
- fish, tmux, Neovim/LazyVim-ready placeholder config, Ghostty, mise, uv
- Stow-managed dotfiles
- Conservative macOS defaults

## Prerequisites

Fresh macOS with network access. No secrets, tokens, passwords, or SSH keys belong in this repository.

The bootstrap script can install Homebrew and Xcode Command Line Tools if missing. Homebrew's official installer may request administrator approval.

## Fresh MacBook usage

Remote bootstrap flow:

```bash
curl -fsSL https://raw.githubusercontent.com/rdtechie/macbook-setup/main/bootstrap.sh | bash
```

For the remote flow, publish the repo first and set `REPO_URL` if your repository is not the default placeholder:

```bash
curl -fsSL https://raw.githubusercontent.com/rdtechie/macbook-setup/main/bootstrap.sh | REPO_URL=https://github.com/rdtechie/macbook-setup.git bash
```

Safer local flow:

```bash
git clone git@github.com:rdtechie/macbook-setup.git ~/src/macbook-setup
cd ~/src/macbook-setup
./bootstrap.sh
```

Then continue with Pi:

```bash
cd ~/src/macbook-setup
pi
/skill:macbook-setup
```

## Re-run/update usage

All scripts are designed to be safe to re-run.

```bash
cd ~/src/macbook-setup
./bootstrap.sh
./scripts/setup-git.sh
./scripts/setup-dotfiles.sh
./scripts/setup-fish.sh
./scripts/setup-dev-tools.sh
./scripts/apply-macos-defaults.sh
./scripts/verify.sh
```

Dotfile conflicts are backed up to `~/.backup/macbook-setup/<timestamp>/` before Stow links repository files.

## Dry-run usage

```bash
./bootstrap.sh --dry-run
./scripts/setup-dotfiles.sh --dry-run
./scripts/setup-fish.sh --dry-run
./scripts/apply-macos-defaults.sh --dry-run
```

Dry runs print intended commands without making changes. `verify.sh` is read-only and can run anytime:

```bash
./scripts/verify.sh
```

## Configuration knobs

`bootstrap.sh` supports:

- `REPO_URL`: Git URL used when cloning this repo.
- `REPO_DIR`: local checkout path. Default: `~/src/macbook-setup`.
- `SKIP_GH_AUTH=1`: skip GitHub CLI auth.
- `SKIP_PI_INSTALL=1`: skip installing Pi.
- `SKIP_PI_PACKAGES=1`: skip installing packages in `config/pi-packages.txt`.
- `PI_INSTALL_COMMAND`: command used to install Pi. Default: `bun install -g @earendil-works/pi-coding-agent`.

Example:

```bash
REPO_DIR=$HOME/Work/macbook-setup SKIP_GH_AUTH=1 ./bootstrap.sh
```

## Customize the Brewfile

Edit `Brewfile`, then apply:

```bash
brew bundle --file Brewfile
brew bundle check --file Brewfile
```

Keep the Brewfile deterministic. Do not add secrets or machine-local paths.

## Customize dotfiles

Each directory under `dotfiles/` is a Stow package. Package paths mirror `$HOME`.

Examples:

- `dotfiles/fish/.config/fish/config.fish` -> `~/.config/fish/config.fish`
- `dotfiles/tmux/.tmux.conf` -> `~/.tmux.conf`
- `dotfiles/ghostty/.config/ghostty/config` -> `~/.config/ghostty/config`

Apply dotfiles:

```bash
./scripts/setup-dotfiles.sh --dry-run
./scripts/setup-dotfiles.sh
```

The script backs up conflicts before stowing. It does not delete user files.

## Customize the Pi skill

Edit `skills/macbook-setup/SKILL.md` to adjust agent behavior. The bootstrap script registers the skill by symlinking it to:

```text
~/.pi/agent/skills/macbook-setup
```

The skill should continue to treat this repository and `plans/implementation-plan.md` as source of truth.

Pi packages are listed in:

```text
config/pi-packages.txt
```

Plain names are installed as npm Pi packages, for example `pi-web-access` becomes `npm:pi-web-access`.

## Safety model

- Scripts use `set -euo pipefail`.
- Scripts are idempotent and safe to re-run.
- Dotfile conflicts are backed up before linking.
- Secrets, tokens, passwords, and SSH keys are excluded by policy and `.gitignore`.
- `sudo` is avoided except where macOS requires it, such as editing `/etc/shells`.
- Sudo-requiring operations are isolated and explained.
- Login shell changes never happen unless `./scripts/setup-fish.sh --change-shell` is used and approved.
- macOS defaults are conservative. Dock autohide requires `ENABLE_DOCK_AUTOHIDE=1`.

## Troubleshooting

Run verification first:

```bash
./scripts/verify.sh
```

Common fixes:

```bash
# Homebrew packages missing
brew bundle --file Brewfile

# GitHub CLI not authenticated
gh auth login --web
gh auth setup-git

# Dotfiles not linked
./scripts/setup-dotfiles.sh --dry-run
./scripts/setup-dotfiles.sh

# Pi skill missing
./bootstrap.sh
```

If Xcode Command Line Tools installation starts, finish the GUI installer, then re-run `./bootstrap.sh`.

If `/etc/shells` does not include fish, run `./scripts/setup-fish.sh` and approve the isolated sudo prompt, or add the printed path manually.

## Manual steps still required

- Sign in to macOS services and App Store if needed.
- Sign in to 1Password, Vivaldi, Raycast, Ghostty, and Visual Studio Code.
- Authenticate GitHub CLI with `gh auth login --web` if skipped during bootstrap.
- Configure `git user.name` and `git user.email` if not already set.
- Review and customize `Brewfile`, dotfiles, and `dotfiles/mise/.config/mise/config.toml` for personal runtime choices.
- Optionally change login shell with `./scripts/setup-fish.sh --change-shell`.
