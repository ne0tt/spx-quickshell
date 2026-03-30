#!/bin/bash
# Colorize map_default.png with source_color from quickshell Colors.qml

COLORS_QML="$HOME/dotfiles/.config/quickshell/Colors.qml"
BASE_IMAGE="$HOME/.config/quickshell/assets/map_default.png"
OUT_DIR="$HOME/.config/quickshell/assets"
OUT_IMAGE="$OUT_DIR/map_colorized_latest.png"
OUT_IMAGE_DARK="$OUT_DIR/map_colorized_latest_dark.png"
CACHE_FILE="$OUT_DIR/.map_last_color"

# Fail fast — check ImageMagick before doing any work
if ! command -v magick &> /dev/null; then
    echo "ImageMagick not found. Please install it: sudo pacman -S imagemagick"
    exit 1
fi

# Extract col_source_color and col_background in a single pass
SOURCE_COLOR=$(grep -oP 'col_source_color[^#]*\K#[0-9a-fA-F]{6,8}' "$COLORS_QML" | head -1)
DARK_COLOR=$(grep -oP 'col_background[^#]*\K#[0-9a-fA-F]{6,8}' "$COLORS_QML" | head -1)

if [ -z "$SOURCE_COLOR" ]; then
    echo "Could not read col_source_color from $COLORS_QML, skipping colorization"
    exit 1
fi

# Skip if color hasn't changed and output already exists
if [ -f "$CACHE_FILE" ] && [ -f "$OUT_IMAGE" ] && [ "$(cat "$CACHE_FILE")" = "$SOURCE_COLOR" ]; then
    exit 0
fi

# Colorize the image directly to final output
magick "$BASE_IMAGE" \
    \( +clone -fill "$SOURCE_COLOR" -colorize 255 \) \
    -compose Screen -composite \
    -type TrueColorAlpha PNG32:"$OUT_IMAGE"

# Colorize the image directly to final output
magick "$BASE_IMAGE" \
    \( +clone -fill "$DARK_COLOR" -colorize 255 \) \
    -compose Screen -composite \
    -type TrueColorAlpha PNG32:"$OUT_IMAGE_DARK"

echo "$SOURCE_COLOR" > "$CACHE_FILE"
echo "Colorized map with $SOURCE_COLOR"