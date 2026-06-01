#!/usr/bin/env bash
set -euo pipefail

# Kill all Chrome processes before logout
killall chrome --wait || true

# Safely log out from Hyprland
hyprctl eval "hl.dispatch(hl.dsp.exit())"
