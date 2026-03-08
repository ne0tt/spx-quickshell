#!/bin/bash
# Colorize map_default.png with source_color from quickshell Colors.qml

COLORS_FILE="$HOME/.cache/quickshell-colors.txt"
BASE_IMAGE="$HOME/.config/quickshell/assets/map_default.png"
OUT_DIR="$HOME/.config/quickshell/assets"
OUT_IMAGE="$OUT_DIR/map_colorized_latest.png"

# Extract source_color from colors.txt (second line)
SOURCE_COLOR=$(sed -n '2p' "$COLORS_FILE" | tr -d '\n')

if [ -z "$SOURCE_COLOR" ]; then
    echo "Could not read source_color from $COLORS_FILE, skipping colorization"
    exit 1
fi

echo "Colorizing map with source color: $SOURCE_COLOR"

# Check if ImageMagick is available
if ! command -v magick &> /dev/null; then
    echo "ImageMagick not found. Please install it: sudo pacman -S imagemagick"
    exit 1
fi

# Colorize the image directly to final output
magick "$BASE_IMAGE" \
    \( +clone -fill "$SOURCE_COLOR" -colorize 100 \) \
    -compose Screen -composite \
    -type TrueColorAlpha PNG32:"$OUT_IMAGE"

echo "Colorized map created: $OUT_IMAGE"