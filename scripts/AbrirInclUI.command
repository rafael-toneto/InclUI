#!/bin/zsh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
swift build --product inclui-gui

bin_dir="$(swift build --show-bin-path)"
binary="$bin_dir/inclui-gui"
resource_bundle="$bin_dir/InclUI_inclui-gui.bundle"
icon_source="$repo/Sources/InclUIGUI/Resources/AppIcon.png"
app="$HOME/Applications/InclUI.app"

if [[ ! -f "$binary" || ! -d "$resource_bundle" || ! -f "$icon_source" ]]; then
    echo 'O build não produziu o executável ou os recursos necessários.' >&2
    exit 1
fi

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/InclUI"
rm -rf "$app/Contents/Resources/InclUI_inclui-gui.bundle"
cp -R "$resource_bundle" "$app/Contents/Resources/"

icon_work="$(mktemp -d)"
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 64 128 256 512 1024; do
    sips -s format png -z "$size" "$size" "$icon_source" --out "$icon_work/$size.png" >/dev/null
 done
cp "$icon_work/16.png" "$iconset/icon_16x16.png"
cp "$icon_work/32.png" "$iconset/icon_16x16@2x.png"
cp "$icon_work/32.png" "$iconset/icon_32x32.png"
cp "$icon_work/64.png" "$iconset/icon_32x32@2x.png"
cp "$icon_work/128.png" "$iconset/icon_128x128.png"
cp "$icon_work/256.png" "$iconset/icon_128x128@2x.png"
cp "$icon_work/256.png" "$iconset/icon_256x256.png"
cp "$icon_work/512.png" "$iconset/icon_256x256@2x.png"
cp "$icon_work/512.png" "$iconset/icon_512x512.png"
cp "$icon_work/1024.png" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>pt_BR</string>
    <key>CFBundleDisplayName</key><string>InclUI</string>
    <key>CFBundleExecutable</key><string>InclUI</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.rafaeltoneto.InclUI</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>InclUI</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$app"
open "$app"
