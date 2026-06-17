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

Run `bootstrap.sh` as your normal macOS user. Do not run it with `sudo`. Homebrew refuses root installs, and `sudo` changes `$HOME`, which would put repo state and Pi config under `/var/root`.

macOS uses zsh as the default login shell. This repo still uses Bash for scripts because the scripts need deterministic Bash behavior. The Homebrew installer itself is also a Bash script. `bootstrap.sh` downloads that installer and runs it attached to `/dev/tty`, so prompts work from zsh, bash, or a `curl | bash` bootstrap run.

The bootstrap script can install Xcode Command Line Tools and Homebrew if missing. Homebrew's official installer may ask for administrator approval. `bootstrap.sh` runs `sudo -v` once before the installer and keeps the sudo timestamp alive while Homebrew runs, so you should not get password prompts for every installer step. Approve that initial prompt when it appears, but do not start this repo's bootstrap script with `sudo`.

## Fresh MacBook usage

Recommended first run on a fresh Mac:

```bash
# 1. Install Xcode Command Line Tools if missing.
xcode-select -p >/dev/null 2>&1 || xcode-select --install

# 2. Install Homebrew manually if missing. This installer may ask for your macOS password.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Load Homebrew in the current shell.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"      # Intel
fi

# 4. Clone and run the repository bootstrap as your normal user.
git clone git@github.com:rdtechie/macbook-setup.git ~/src/macbook-setup
cd ~/src/macbook-setup
./bootstrap.sh
```

If Homebrew is already installed, the shorter local flow is enough:

```bash
git clone git@github.com:rdtechie/macbook-setup.git ~/src/macbook-setup
cd ~/src/macbook-setup
./bootstrap.sh
```

Remote bootstrap flow, useful after Homebrew is already working:

```bash
curl -fsSL https://raw.githubusercontent.com/rdtechie/macbook-setup/main/bootstrap.sh | bash
```

Do not use this:

```bash
sudo ./bootstrap.sh
curl -fsSL https://raw.githubusercontent.com/rdtechie/macbook-setup/main/bootstrap.sh | sudo bash
```

## First Pi session

After bootstrap completes:

```bash
cd ~/src/macbook-setup
pi
```

Inside Pi:

1. If Pi asks whether to trust the project, trust this repository. The repo contains the local skill and plan that Pi needs to load.
2. Authenticate an AI provider:

   ```text
   /login
   ```

   For GitHub Copilot, select `GitHub Copilot`. When asked for the host, press Enter for `github.com` unless you use GitHub Enterprise Server. Complete the browser/device-code login. Pi stores OAuth tokens in `~/.pi/agent/auth.json`, not in this repository.

3. Select a model:

   ```text
   /model
   ```

   Recommended with GitHub Copilot: choose the latest available Claude Sonnet model, for example `claude-sonnet-4-5` if shown. It is the best default for multi-file repo setup, shell-script review, and agentic edits. If Sonnet is unavailable, choose the latest Copilot-backed coding model shown by Pi, for example a GPT-5 Codex/GPT-5 model if available.

   If Pi says a Copilot model is not supported, open VS Code, go to Copilot Chat's model selector, select that model once, and enable it. Then return to Pi and run `/model` again.

4. Start the repository skill:

   ```text
   /skill:macbook-setup
   ```

The skill will read `plans/implementation-plan.md`, execute phases in order, verify after major steps, and report manual follow-up.

Useful Pi commands during setup:

```text
/login          authenticate or switch provider credentials
/model          choose model
/settings       adjust thinking level, theme, and behavior
/reload         reload skills after editing SKILL.md
/quit           exit Pi
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

If Homebrew installation fails because it cannot access an interactive terminal or cannot complete administrator approval, do not retry with `sudo ./bootstrap.sh`. Run the official Homebrew installer manually as your normal user, approve its sudo prompt, load `brew shellenv`, then re-run `./bootstrap.sh`. If macOS still asks repeatedly, run `sudo -v` first in the same terminal, then start the installer.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
./bootstrap.sh
```

If Pi starts without an authenticated provider, run `/login`, select `GitHub Copilot`, complete browser authentication, then run `/model` and choose the latest available Claude Sonnet model or Copilot coding model.

If `/etc/shells` does not include fish, run `./scripts/setup-fish.sh` and approve the isolated sudo prompt, or add the printed path manually.

## Manual steps still required

- Sign in to macOS services and App Store if needed.
- Sign in to 1Password, Vivaldi, Raycast, Ghostty, and Visual Studio Code.
- Authenticate GitHub CLI with `gh auth login --web` if skipped during bootstrap.
- Authenticate Pi with `/login`, for example GitHub Copilot, then choose a model with `/model`.
- Configure `git user.name` and `git user.email` if not already set.
- Review and customize `Brewfile`, dotfiles, and `dotfiles/mise/.config/mise/config.toml` for personal runtime choices.
- Optionally change login shell with `./scripts/setup-fish.sh --change-shell`.
