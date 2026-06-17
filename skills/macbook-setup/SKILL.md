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

If verification reports warnings only, explain whether they are expected manual actions. If verification reports failures, provide the exact failing checks and the next command or approval required.
