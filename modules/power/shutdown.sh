#!/usr/bin/env bash
set -euo pipefail

# Add any custom pre-shutdown commands below.
python3 ~/.config/hypr/scripts/keyboard-breathing-toggle.py '#ff0000' 75 || true
killall chrome --wait || true

systemctl poweroff
