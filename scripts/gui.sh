#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.dotfiles.gui.plist"

case "${1:-status}" in
  start)
    exec /usr/bin/env python3 "$DOTFILES_DIR/gui/server.py"
    ;;
  stop)
    launchctl unload "$PLIST" 2>/dev/null || true
    pkill -f "dotfiles/gui/server.py" 2>/dev/null || true
    echo "Stopped."
    ;;
  status)
    if curl -s -o /dev/null -w '' "http://127.0.0.1:4444/"; then
      echo "Running: http://127.0.0.1:4444"
    else
      echo "Not running."
    fi
    ;;
  logs)
    tail -f "$HOME/.dotfiles-gui.log" "$HOME/.dotfiles-gui.err.log"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|logs}"
    exit 1
    ;;
esac
