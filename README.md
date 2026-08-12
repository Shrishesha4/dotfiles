# dotfiles

Source of truth for config across my MacBooks. Private repo — symlinked into place, module by module.

## Usage

Fresh machine (no Homebrew yet):
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<gh-username>/dotfiles/main/scripts/bootstrap.sh)"
```

Existing machine (repo already cloned):
```
cd ~/dotfiles && ./install.sh
```

Pick modules in the `gum` checkbox menu, then `source ~/.zshrc`.

## Modules

`zsh`, `git`, `ghostty`, `starship`, `claude-code`, `agents-skills`, `vscode`, `cursor`, `brew`, `npm`, `macos` — each under `modules/<name>/install.sh`.

## Secrets

- `~/.zshrc.local` — untracked, chmod 600, sourced from the tracked `.zshrc`. Populate by hand on each machine.
- SSH keys sync via iCloud Drive, not git. See `scripts/sync-ssh-keys.sh`.

## Refreshing manifests

Run `scripts/generate-manifests.sh` after installing new brew packages / VSCode extensions / npm globals, then review the diff (`git diff`) and commit + push.

## Web GUI

`gui` module installs a launchd login item that runs a local dashboard at http://127.0.0.1:4444 — click to install/remove/reset config modules, brew formulae/casks, npm globals, VSCode extensions, and pull/sync/push git.

Security notes:
- Binds `127.0.0.1` only, never reachable from the network.
- Every request needs a per-run token (`~/.dotfiles-gui-token`, chmod 600) sent as the `X-Dot-Token` header — the browser page has it injected at load, so a random website you visit can't drive it even via a crafted `fetch()`.
- All install/remove actions are checked against the repo's own manifests (Brewfile, extensions.txt, global-packages.json, known module names) before running — no free-form package names get executed.
- "Reset" re-links from the repo (like re-running a module's `install.sh`); it does not touch git history or discard uncommitted repo changes.

Manual control without launchd: `scripts/gui.sh {start|stop|status|logs}`.

## Syncing one new install to the other machine

Config modules (zsh, git, ghostty, starship, claude-code, cursor, agents-skills) are symlinked — once a module is installed on a machine, `git pull` alone is enough to pick up edits. No action needed.

Actual installs (brew, npm globals, VSCode extensions) need a real install step. On the machine where you added something new:
```
scripts/generate-manifests.sh
git add -A && git commit -m "add <thing>" && git push
```
On the other machine:
```
scripts/sync-pull.sh
```
It pulls, diffs against your last local commit, and shows **only what's new** (not the full package list) — offering to install just that delta for brew/npm/VSCode.
