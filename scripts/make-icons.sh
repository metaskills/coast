#!/bin/bash
# Renders assets/*.svg into Resources/AppIcon.icns and the menu bar template images.
# Uses QuickLook (built into macOS) for SVG rendering and sips/iconutil for sizes.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

qlmanage -t -s 1024 -o "$tmp" assets/logo.svg >/dev/null 2>&1
cp "$tmp/logo.svg.png" assets/logo.png

set_dir="$tmp/AppIcon.iconset"
mkdir -p "$set_dir"
for size in 16 32 128 256 512; do
  sips -z $size $size assets/logo.png --out "$set_dir/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/logo.png --out "$set_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$set_dir" -o Resources/AppIcon.icns

# Menu bar template image: black on transparent, macOS tints it. QuickLook renders
# on white, so render big, then use darkness as the alpha channel.
sed 's/width="36" height="36"/width="1024" height="1024"/' assets/menubar.svg > "$tmp/menubar.svg"
qlmanage -t -s 1024 -o "$tmp" "$tmp/menubar.svg" >/dev/null 2>&1
magick "$tmp/menubar.svg.png" -colorspace gray -negate -alpha copy -fill black -colorize 100 \
  -resize 36x36 Resources/MenuBarIcon@2x.png
magick Resources/MenuBarIcon@2x.png -resize 18x18 Resources/MenuBarIcon.png
echo "Icons written to Resources/"
