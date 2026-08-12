#!/usr/bin/env bash
set -euo pipefail

# macOS system defaults.
# All commands are opt-out-safe: any line starting with '# SKIP:' is skipped.
# Comment/uncomment to control what applies per-machine.
# Some commands need sudo; they are guarded with run_sudo() and skip if not available.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUDO_ASKED=0
ask_sudo_once() {
  if [ "$SUDO_ASKED" -eq 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo -v
    SUDO_ASKED=1
  fi
}
run_sudo() {
  ask_sudo_once
  sudo "$@"
}

# --- Dock ---------------------------------------------------------------------
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -int 0
# PATCH[killall-dock]: killed below; keep only one killall Dock line.
defaults write com.apple.dock autohide-time-modifier -float 0.4
# SKIP: defaults write com.apple.dock show-recents -bool false
# SKIP: defaults write com.apple.dock showAppExposeGestureEnabled -bool true

# --- Trackpad -----------------------------------------------------------------
# Tap-to-click (must run as user, not sudo).
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
run_sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
run_sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Tracking speed (cursor acceleration). 0=slow, 3=max.
defaults write -g com.apple.trackpad.scaling -float 3

# Force click / haptic (0=force click enabled, 1=force suppressed).
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
defaults write com.apple.AppleMultitouchTrackpad ActuateDetents -bool true

# Scrolling.
defaults write com.apple.AppleMultitouchTrackpad TrackpadScroll -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadHorizScroll -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll -bool true
defaults write com.apple.AppleMultitouchTrackpad DragLock -bool false
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool false

# Gestures.
defaults write com.apple.AppleMultitouchTrackpad TrackpadPinch -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRotate -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -bool false

# Three-finger swipe: 2=Mission Control. (Already set; keep explicit.)
defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerVertSwipeGesture -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerHorizSwipeGesture -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerVertSwipeGesture -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerHorizSwipeGesture -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fiveFingerPinchGesture -int 2
defaults -currentHost write NSGlobalDomain com.apple.trackpad.fourFingerPinchGesture -int 2

# Hand resting detection.
defaults write com.apple.AppleMultitouchTrackpad TrackpadHandResting -bool true

# Disable USB mouse from disabling trackpad.
defaults write com.apple.AppleMultitouchTrackpad USBMouseStopsTrackpad -bool false

# --- Global / keyboard ---------------------------------------------------------
#SKIP: defaults write NSGlobalDomain KeyRepeat -int 2

# --- Finder -------------------------------------------------------------------
#SKIP: defaults write com.apple.finder AppleShowAllFiles -bool true
#SKIP: defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"

# --- Default apps -------------------------------------------------------------
# Open .command / .sh / unix executables in Ghostty. Using dutti avoids corrupting the launchservices plist.
if command -v duti >/dev/null 2>&1; then
  duti -s com.mitchellh.ghostty public.unix-executable all
elif command -v brew >/dev/null 2>&1; then
  echo "Install duti to set Ghostty as default terminal: brew install duti"
fi

# --- Restart affected apps -----------------------------------------------------
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
