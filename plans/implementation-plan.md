# macbook-setup implementation plan

Execute phases in order. Prefer repository scripts over ad hoc commands. Stop on command failures unless the phase explicitly marks the result as a warning. Never delete user data. Never overwrite a user file without a backup.

## Phase 1 — Inspect current system

Goal: establish current machine state before changing anything.

Commands to run:

```bash
pwd
uname -a
sw_vers
./bootstrap.sh --dry-run
./scripts/verify.sh
```

What to verify:

- Current directory is the `macbook-setup` repository.
- Host is macOS.
- Architecture is Apple Silicon or Intel.
- `./bootstrap.sh --dry-run` shows intended operations without changing state.
- `./scripts/verify.sh` runs to completion and reports current gaps.

Stop conditions:

- Not running from the repository root.
- Not running on macOS, unless the user is only reviewing the repository.
- Dry run fails because required repository files are missing.

Manual approval points:

- Ask before continuing if verification shows existing non-symlink dotfiles that may need backup.
- Ask before continuing if the user wants to skip any phase.

## Phase 2 — Install/update Homebrew packages

Goal: install the deterministic package baseline from `Brewfile`.

Commands to run:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh
./scripts/verify.sh
```

If bootstrap has already completed and only packages need reconciliation:

```bash
brew bundle --file Brewfile
./scripts/verify.sh
```

What to verify:

- Xcode Command Line Tools are installed.
- Homebrew exists and its shell environment is loaded from the correct prefix:
  - Apple Silicon: `/opt/homebrew`
  - Intel: `/usr/local`
- `brew bundle --file Brewfile` completes.
- Required CLI tools exist: `git`, `gh`, `stow`, `fish`, `tmux`, `nvim`, `lazygit`, `mise`, `uv`, `node`, and `npm`.
- Required casks are installed or Homebrew reports actionable cask failures.

Stop conditions:

- Xcode Command Line Tools installer starts and requires the user to finish it.
- Homebrew installation fails.
- `brew bundle` fails for a reason other than a user-deferred cask installation.

Manual approval points:

- Homebrew's official installer may request administrator approval. Explain this before continuing.
- Some casks may require GUI confirmation or Rosetta prompts. Ask before retrying failed casks.

## Phase 3 — Configure Git and GitHub CLI

Goal: configure safe global Git defaults and GitHub CLI credential integration.

Commands to run:

```bash
./scripts/setup-git.sh
./scripts/verify.sh
```

If GitHub CLI is not authenticated:

```bash
gh auth login --web
gh auth setup-git
./scripts/verify.sh
```

What to verify:

- Existing `user.name` and `user.email` were not overwritten.
- These global Git keys are set:
  - `init.defaultBranch=main`
  - `pull.rebase=false`
  - `fetch.prune=true`
  - `rerere.enabled=true`
  - `core.editor=nvim`
- `gh auth status` succeeds, unless the user intentionally skipped GitHub authentication.
- `gh auth setup-git` ran after authentication.

Stop conditions:

- `git` is missing.
- Git config command fails.
- GitHub authentication fails and the user does not want to retry.

Manual approval points:

- Browser-based GitHub authentication requires user action.
- Ask before configuring any identity values. The script intentionally does not set `user.name` or `user.email`.

## Phase 4 — Apply dotfiles with Stow

Goal: link repository-managed dotfiles without deleting or overwriting user files.

Commands to run:

```bash
./scripts/setup-dotfiles.sh --dry-run
./scripts/setup-dotfiles.sh
./scripts/verify.sh
```

What to verify:

- GNU Stow is installed.
- Conflicting files are backed up to `~/.backup/macbook-setup/<timestamp>/`.
- Expected symlinks exist:
  - `~/.config/fish/config.fish`
  - `~/.gitconfig.macbook-setup`
  - `~/.config/nvim/init.lua`
  - `~/.tmux.conf`
  - `~/.config/ghostty/config`
  - `~/.aerospace.toml`
  - `~/.config/mise/config.toml`
- Re-running the script does not create duplicate backups for already-correct symlinks.

Stop conditions:

- `stow` is missing.
- Backup cannot be created.
- Stow reports unresolved conflicts after backups.

Manual approval points:

- Review dry-run output before backing up existing dotfiles.
- If a conflicting file contains important local customizations, ask whether to merge manually before running stow.

## Phase 5 — Configure fish shell

Goal: register fish as an available shell and optionally make it the login shell.

Commands to run:

```bash
./scripts/setup-fish.sh --dry-run
./scripts/setup-fish.sh
./scripts/verify.sh
```

Only if the user explicitly approves changing the login shell:

```bash
./scripts/setup-fish.sh --change-shell
./scripts/verify.sh
```

What to verify:

- `fish` exists.
- Homebrew's fish path is present in `/etc/shells` or a manual action is reported.
- Login shell changes happen only when `--change-shell` is passed and the user approves.
- New shell configuration initializes starship, zoxide, and mise when installed.

Stop conditions:

- `fish` is missing.
- `/etc/shells` update requires sudo and the user does not approve.
- `chsh` fails or the user does not approve login shell change.

Manual approval points:

- Ask before any sudo command that edits `/etc/shells`.
- Ask before changing login shell.
- Tell the user that a new terminal session may be required.

## Phase 6 — Configure dev tooling

Goal: verify core developer tools and apply light, repository-defined configuration.

Commands to run:

```bash
./scripts/setup-dev-tools.sh
./scripts/verify.sh
```

What to verify:

- `mise` exists and `mise doctor` either passes or reports actionable warnings.
- `uv` exists.
- `~/.local/bin` exists.
- `~/.config/mise/config.toml` is present as a stowed file.
- No global runtimes were installed unless explicitly added to repository state and approved.

Stop conditions:

- Required developer tools are missing after Homebrew bundle.
- A tool configuration command fails.

Manual approval points:

- Ask before adding language runtimes to `dotfiles/mise/.config/mise/config.toml`.
- Ask before installing global `uv` tools.

## Phase 7 — Apply macOS defaults

Goal: apply macOS quality-of-life settings documented in the repository.

Settings applied by this phase:

- **Dock** — auto-hide always on, icon size halved (24 px), all pinned app icons removed (Finder is always present separately).
- **Keyboard** — fastest key-repeat rate (`KeyRepeat=2`), initial key-repeat delay at roughly 25% of the slider range (`InitialKeyRepeat=25`).
- **Finder** — path bar, status bar, current-folder search, folders first, list view.
- **Screenshots** — saved to `~/Pictures/Screenshots` as PNG.
- **Desktop services** — no `.DS_Store` on network or USB volumes.

Commands to run:

```bash
./scripts/apply-macos-defaults.sh --dry-run
./scripts/apply-macos-defaults.sh
./scripts/verify.sh
```

What to verify:

- Screenshot directory exists.
- Finder settings apply without errors.
- Dock auto-hides, is noticeably smaller, and shows only Finder after re-login or Dock restart.
- Keyboard repeat and initial delay reflect the new values in System Settings → Keyboard.
- Non-disruptive affected services restart: Finder, SystemUIServer, and Dock.

Stop conditions:

- Host is not macOS.
- `defaults` command fails.

Manual approval points:

- Removing all Dock icons (except Finder) is destructive to the user's current Dock layout. Explain this and ask before running.
- Explain that keyboard delay changes take effect immediately but may feel jarring until the user adjusts.
- Explain that some UI settings require reopening Finder windows or starting a new terminal session.

## Phase 8 — Verify full setup

Goal: produce a final machine-readable-enough and human-readable status check.

Commands to run:

```bash
./scripts/verify.sh
brew bundle check --file Brewfile
```

What to verify:

- Required commands exist, including `node` and `npm` for Pi runtime support.
- `gh auth status` is successful or intentionally deferred.
- Dotfile symlinks exist.
- Pi skill symlink exists at `~/.pi/agent/skills/macbook-setup`.
- `brew bundle check --file Brewfile` passes or reports known manual cask work.

Stop conditions:

- Verification reports failures.
- Pi skill registration is missing.
- Core tools are missing after package installation.

Manual approval points:

- Ask before remediating failures that require sudo, login-shell changes, deleting files, or overwriting files.

## Phase 9 — Report final status

Goal: give the user a concise final report and next manual actions.

Commands to run:

```bash
./scripts/verify.sh
```

What to verify:

- Completed phases are listed.
- Failed or skipped phases are listed with reasons.
- Manual follow-up is explicit.
- The user knows how to invoke the continuing Pi skill:

```bash
cd <repo-dir>
pi
/skill:macbook-setup
```

Stop conditions:

- None. This is reporting only.

Manual approval points:

- Ask whether to continue only if the user wants remediation beyond the planned repository behavior.
