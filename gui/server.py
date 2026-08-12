#!/usr/bin/env python3
"""Local-only web GUI for the dotfiles repo. Binds 127.0.0.1:4444 — never expose
this on a real interface, it executes brew/npm/code/git commands on request."""

import json
import os
import re
import secrets
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DOTFILES_DIR = Path(__file__).resolve().parent.parent
HOME = Path.home()
PORT = 4444
TOKEN = secrets.token_hex(16)

# name-safe pattern for anything passed to a subprocess as a package/extension name
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.@/-]*$")

MODULE_TARGETS = {
    "zsh": [
        ("modules/zsh/zshrc", "~/.zshrc", "link"),
        ("modules/zsh/zprofile", "~/.zprofile", "link"),
    ],
    "git": [
        ("modules/git/gitconfig", "~/.gitconfig", "link"),
        ("modules/git/gitignore_global", "~/.config/git/ignore", "link"),
    ],
    "ghostty": [("modules/ghostty/config", "~/.config/ghostty/config", "link")],
    "starship": [("modules/starship/starship.toml", "~/.config/starship.toml", "link")],
    "claude-code": [
        ("modules/claude-code/settings.json", "~/.claude/settings.json", "link"),
        ("modules/claude-code/CLAUDE.md", "~/.claude/CLAUDE.md", "link"),
        ("modules/claude-code/plugins/installed_plugins.json.tmpl", "~/.claude/plugins/installed_plugins.json", "template"),
        ("modules/claude-code/plugins/known_marketplaces.json.tmpl", "~/.claude/plugins/known_marketplaces.json", "template"),
    ],
    "agents-skills": [("modules/agents-skills/skills", "~/.agents/skills", "link")],
    "vscode": [("modules/vscode/settings.json", "~/Library/Application Support/Code/User/settings.json", "link")],
    "cursor": [
        ("modules/cursor/settings.json.tmpl", "~/Library/Application Support/Cursor/User/settings.json", "template"),
        ("modules/cursor/keybindings.json", "~/Library/Application Support/Cursor/User/keybindings.json", "link"),
    ],
}


def run(cmd, cwd=None, env=None, timeout=180):
    try:
        p = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
        return {"ok": p.returncode == 0, "code": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except FileNotFoundError as e:
        return {"ok": False, "code": -1, "stdout": "", "stderr": f"not found: {e}"}
    except subprocess.TimeoutExpired:
        return {"ok": False, "code": -1, "stdout": "", "stderr": "timed out"}


def module_installed(name):
    targets = MODULE_TARGETS.get(name, [])
    if not targets:
        return False
    for src, dest, kind in targets:
        dest_p = Path(os.path.expanduser(dest))
        src_p = DOTFILES_DIR / src
        if kind == "link":
            if not (dest_p.is_symlink() and dest_p.resolve() == src_p.resolve()):
                return False
        else:  # template
            if not (dest_p.is_file() and dest_p.stat().st_size > 0):
                return False
    return True


def parse_brewfile():
    formulae, casks, taps = [], [], []
    brewfile = DOTFILES_DIR / "Brewfile"
    if not brewfile.exists():
        return formulae, casks, taps
    for line in brewfile.read_text().splitlines():
        m = re.match(r'^brew "([^"]+)"', line)
        if m:
            formulae.append(m.group(1))
            continue
        m = re.match(r'^cask "([^"]+)"', line)
        if m:
            casks.append(m.group(1))
            continue
        m = re.match(r'^tap "([^"]+)"', line)
        if m:
            taps.append(m.group(1))
    return formulae, casks, taps


def brew_installed_sets():
    f = run(["brew", "list", "--formula", "-1"])
    c = run(["brew", "list", "--cask", "-1"])
    installed_f = set(f["stdout"].split()) if f["ok"] else set()
    installed_c = set(c["stdout"].split()) if c["ok"] else set()
    return installed_f, installed_c


def npm_state():
    manifest = DOTFILES_DIR / "modules" / "npm" / "global-packages.json"
    wanted = []
    if manifest.exists():
        try:
            data = json.loads(manifest.read_text())
            wanted = [k for k in data.get("dependencies", {}).keys() if k not in ("npm", "corepack")]
        except json.JSONDecodeError:
            pass
    listed = run(["npm", "list", "-g", "--depth=0", "--json"])
    installed = set()
    if listed["ok"] or listed["stdout"]:
        try:
            installed = set(json.loads(listed["stdout"]).get("dependencies", {}).keys())
        except json.JSONDecodeError:
            pass
    return [{"name": n, "installed": n in installed} for n in wanted]


def vscode_state():
    manifest = DOTFILES_DIR / "modules" / "vscode" / "extensions.txt"
    wanted = [l.strip() for l in manifest.read_text().splitlines() if l.strip()] if manifest.exists() else []
    listed = run(["code", "--list-extensions"])
    installed = set(listed["stdout"].split()) if listed["ok"] else set()
    return [{"name": n, "installed": n in installed} for n in wanted]


def git_status():
    run(["git", "-C", str(DOTFILES_DIR), "fetch"], timeout=30)
    branch = run(["git", "-C", str(DOTFILES_DIR), "rev-parse", "--abbrev-ref", "HEAD"])
    sb = run(["git", "-C", str(DOTFILES_DIR), "status", "-sb"])
    porcelain = run(["git", "-C", str(DOTFILES_DIR), "status", "--porcelain"])
    log = run(["git", "-C", str(DOTFILES_DIR), "log", "-1", "--format=%h %s (%cr)"])
    return {
        "branch": branch["stdout"].strip(),
        "status_line": sb["stdout"].splitlines()[0] if sb["stdout"] else "",
        "dirty": bool(porcelain["stdout"].strip()),
        "changed_files": porcelain["stdout"].strip().splitlines(),
        "last_commit": log["stdout"].strip(),
    }


def gui_autostart_installed():
    plist = HOME / "Library" / "LaunchAgents" / "com.dotfiles.gui.plist"
    return plist.exists()


def build_state():
    formulae, casks, _taps = parse_brewfile()
    installed_f, installed_c = brew_installed_sets()
    return {
        "modules": {name: module_installed(name) for name in MODULE_TARGETS},
        "gui_autostart": gui_autostart_installed(),
        "brew": {
            "formulae": [{"name": n, "installed": n in installed_f} for n in formulae],
            "casks": [{"name": n, "installed": n in installed_c} for n in casks],
        },
        "npm": npm_state(),
        "vscode": vscode_state(),
        "git": git_status(),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "DotfilesGUI/1.0"

    def log_message(self, fmt, *args):
        pass  # quiet; launchd captures stdout/stderr to log files if needed

    def _send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, text, status=200):
        body = text.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _check_token(self):
        return self.headers.get("X-Dot-Token") == TOKEN

    def _read_json_body(self):
        ctype = self.headers.get("Content-Type", "")
        if "application/json" not in ctype:
            return None, "expected application/json"
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length == 0:
            return {}, None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw), None
        except json.JSONDecodeError:
            return None, "invalid json"

    def do_GET(self):
        if self.path == "/":
            html = (DOTFILES_DIR / "gui" / "index.html").read_text()
            html = html.replace("__TOKEN__", TOKEN)
            self._send_html(html)
            return
        if self.path == "/api/state":
            if not self._check_token():
                self._send_json({"error": "unauthorized"}, 401)
                return
            self._send_json(build_state())
            return
        self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        if not self._check_token():
            self._send_json({"error": "unauthorized"}, 401)
            return
        body, err = self._read_json_body()
        if err:
            self._send_json({"error": err}, 400)
            return

        route = self.path

        if route == "/api/module/install" or route == "/api/module/reset":
            name = body.get("name", "")
            if name not in MODULE_TARGETS:
                self._send_json({"error": "unknown module"}, 400)
                return
            env = dict(os.environ, DOTFILES_DIR=str(DOTFILES_DIR))
            r = run(["bash", str(DOTFILES_DIR / "modules" / name / "install.sh")], cwd=str(DOTFILES_DIR), env=env)
            self._send_json(r)
            return

        if route == "/api/module/remove":
            name = body.get("name", "")
            if name not in MODULE_TARGETS:
                self._send_json({"error": "unknown module"}, 400)
                return
            removed = []
            for src, dest, kind in MODULE_TARGETS[name]:
                dest_p = Path(os.path.expanduser(dest))
                if dest_p.is_symlink() or dest_p.exists():
                    dest_p.unlink()
                    removed.append(str(dest_p))
            self._send_json({"ok": True, "removed": removed})
            return

        if route == "/api/brew/install" or route == "/api/brew/remove":
            name, kind = body.get("name", ""), body.get("type", "")
            formulae, casks, _ = parse_brewfile()
            valid = (kind == "formula" and name in formulae) or (kind == "cask" and name in casks)
            if not valid or not SAFE_NAME.match(name):
                self._send_json({"error": "unknown package"}, 400)
                return
            action = "install" if route.endswith("install") else "uninstall"
            cmd = ["brew", action] + (["--cask"] if kind == "cask" else []) + [name]
            self._send_json(run(cmd, timeout=600))
            return

        if route == "/api/npm/install" or route == "/api/npm/remove":
            name = body.get("name", "")
            wanted = {p["name"] for p in npm_state()}
            if name not in wanted or not SAFE_NAME.match(name):
                self._send_json({"error": "unknown package"}, 400)
                return
            action = "install" if route.endswith("install") else "uninstall"
            self._send_json(run(["npm", action, "-g", name], timeout=300))
            return

        if route == "/api/vscode/install" or route == "/api/vscode/remove":
            name = body.get("name", "")
            wanted = {p["name"] for p in vscode_state()}
            if name not in wanted or not SAFE_NAME.match(name):
                self._send_json({"error": "unknown extension"}, 400)
                return
            flag = "--install-extension" if route.endswith("install") else "--uninstall-extension"
            self._send_json(run(["code", flag, name], timeout=120))
            return

        if route == "/api/git/pull":
            self._send_json(run(["git", "-C", str(DOTFILES_DIR), "pull", "--ff-only"], timeout=60))
            return

        if route == "/api/git/push":
            msg = (body.get("message") or "").strip()
            if not msg:
                self._send_json({"error": "commit message required"}, 400)
                return
            add = run(["git", "-C", str(DOTFILES_DIR), "add", "-A"])
            porcelain = run(["git", "-C", str(DOTFILES_DIR), "status", "--porcelain"])
            if not porcelain["stdout"].strip():
                push = run(["git", "-C", str(DOTFILES_DIR), "push"], timeout=60)
                self._send_json({"ok": push["ok"], "note": "nothing to commit, pushed existing commits", "push": push})
                return
            commit = run(["git", "-C", str(DOTFILES_DIR), "commit", "-m", msg])
            push = run(["git", "-C", str(DOTFILES_DIR), "push"], timeout=60)
            self._send_json({"ok": commit["ok"] and push["ok"], "add": add, "commit": commit, "push": push})
            return

        if route == "/api/git/sync":
            gen = run(["bash", str(DOTFILES_DIR / "scripts" / "generate-manifests.sh")], cwd=str(DOTFILES_DIR), timeout=120)
            pull = run(["git", "-C", str(DOTFILES_DIR), "pull", "--ff-only"], timeout=60)
            self._send_json({"generate": gen, "pull": pull})
            return

        if route == "/api/reset-all":
            results = {}
            env = dict(os.environ, DOTFILES_DIR=str(DOTFILES_DIR))
            for name in MODULE_TARGETS:
                if module_installed(name):
                    results[name] = run(["bash", str(DOTFILES_DIR / "modules" / name / "install.sh")], cwd=str(DOTFILES_DIR), env=env)
            self._send_json({"ok": True, "results": results})
            return

        self._send_json({"error": "not found"}, 404)


def main():
    token_file = HOME / ".dotfiles-gui-token"
    token_file.write_text(TOKEN)
    token_file.chmod(0o600)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Dotfiles GUI on http://127.0.0.1:{PORT} (token in {token_file})")
    server.serve_forever()


if __name__ == "__main__":
    main()
