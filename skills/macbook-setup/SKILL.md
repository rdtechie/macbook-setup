---
name: macbook-setup
description: Configure Richard's macOS DevOps workstation from the macbook-setup repository.
---

Use this repository as the source of truth for workstation configuration. Do not invent one-off setup steps when a repository script or plan step exists.

Follow `plans/implementation-plan.md` in order. Treat the plan as the execution contract: inspect, run the stated commands, verify, stop on failures, and report status.

Safety rules:

- Never delete user data.
- Never overwrite files without backing them up first.
- Never store secrets, tokens, passwords, SSH keys, recovery keys, or personal credentials in this repository or in logs.
- Ask before running any command that uses `sudo` or modifies system-owned files.
- Ask before changing the user's login shell.
- Prefer repository scripts over ad hoc commands.
- Use dry runs first when a script supports `--dry-run` and the current state is uncertain.
- Run `./scripts/verify.sh` after every major phase.
- Stop and report if a command fails. Do not continue through failed provisioning steps.

Operational behavior:

1. Confirm the working directory is the `macbook-setup` repository.
2. Read `plans/implementation-plan.md` before running setup commands.
3. Execute phases in order unless the user explicitly asks for a narrower phase.
4. Before a command that may prompt for administrator approval, explain what it changes and ask for approval.
5. Before `./scripts/setup-fish.sh --change-shell`, ask for explicit approval.
6. Backups created by repository scripts should remain under `~/.backup/macbook-setup/<timestamp>/`.
7. Prefer `brew bundle --file Brewfile`, `stow`, and the scripts in `scripts/` over direct package or dotfile edits.
8. After each phase, summarize what changed and run verification.
9. Final response must summarize completed work, failed work, skipped work, and manual follow-up.
10. **Phase 7 destroys the current Dock layout.** Before running `./scripts/apply-macos-defaults.sh`, warn the user that all pinned Dock icons will be removed (only Finder stays) and ask for explicit approval.

macOS defaults applied by `scripts/apply-macos-defaults.sh`:

| Setting | Value | Notes |
|---------|-------|-------|
| Dock auto-hide | always on | Dock slides away when not in use |
| Dock icon size | 24 px | Half the macOS default of 48 px |
| Dock pinned apps | cleared | All icons removed; Finder is always present separately |
| Key repeat rate | 2 (fastest) | `NSGlobalDomain KeyRepeat` |
| Initial key repeat delay | 25 | ~25% of slider range; fast end (`NSGlobalDomain InitialKeyRepeat`) |
| Screenshot location | `~/Pictures/Screenshots` | Keeps Desktop clean |
| Screenshot format | PNG | |
| Finder: show extensions | true | |
| Finder: path bar | true | |
| Finder: status bar | true | |
| Finder: search scope | current folder | |
| Finder: folders first | true | |
| Finder: default view | list | |
| .DS_Store on network/USB | disabled | |

If verification reports warnings only, explain whether they are expected manual actions. If verification reports failures, provide the exact failing checks and the next command or approval required.

## Stow directory-folding behaviour

This repository uses GNU Stow's **directory-folding** strategy for packages whose configs live under `~/.config/`. Rather than creating individual file symlinks, Stow replaces the entire config subdirectory with a single directory-level symlink into the repo:

| Live path | Symlink target |
|-----------|----------------|
| `~/.config/fish` | `~/src/macbook-setup/dotfiles/fish/.config/fish` |
| `~/.config/ghostty` | `~/src/macbook-setup/dotfiles/ghostty/.config/ghostty` |
| `~/.config/mise` | `~/src/macbook-setup/dotfiles/mise/.config/mise` |
| `~/.config/nvim` | `~/src/macbook-setup/dotfiles/nvim/.config/nvim` |

Files inside those directories are **regular files in the repo**, not themselves symlinks. `verify.sh`'s `check_dotfile_link` function is aware of this: it calls `realpath` on the target path and passes if the resolved path falls under `$REPO_DIR/dotfiles/`.

### Gotcha: `setup-dotfiles.sh` backup removes repo files

If `setup-dotfiles.sh` runs while any of the above directory-level symlinks already exist, its conflict-backup logic will `mv` files like `config.fish` **out of the repo directory** (because the live path resolves into the repo). The files land safely in `~/.backup/macbook-setup/<timestamp>/`, but they are absent from the dotfiles tree until restored.

**Recovery procedure** (no data is lost — just copy from backup):

```bash
BACKUP=~/.backup/macbook-setup/<timestamp>
cp "$BACKUP/config.fish"   ~/src/macbook-setup/dotfiles/fish/.config/fish/config.fish
cp "$BACKUP/fish_variables" ~/src/macbook-setup/dotfiles/fish/.config/fish/fish_variables
cp "$BACKUP/config"        ~/src/macbook-setup/dotfiles/ghostty/.config/ghostty/config
cp "$BACKUP/config.toml"   ~/src/macbook-setup/dotfiles/mise/.config/mise/config.toml
cp "$BACKUP/init.lua"      ~/src/macbook-setup/dotfiles/nvim/.config/nvim/init.lua
cp "$BACKUP/lazy.lua"      ~/src/macbook-setup/dotfiles/nvim/.config/nvim/lua/config/lazy.lua
cp "$BACKUP/editor.lua"    ~/src/macbook-setup/dotfiles/nvim/.config/nvim/lua/plugins/editor.lua
```

After restoring, run `./scripts/verify.sh` — all dotfile checks should PASS with "exists via stowed directory".

### `fish_variables`

`dotfiles/fish/.config/fish/fish_variables` is committed to the repo. It contains only the fish initialization marker (`__fish_initialized`) and is safe to track. Fish regenerates it automatically if absent.
