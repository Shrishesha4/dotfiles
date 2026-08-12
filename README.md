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
