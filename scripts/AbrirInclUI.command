#!/bin/zsh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
swift build --product inclui-gui

bin_dir="$(swift build --show-bin-path)"
binary="$bin_dir/inclui-gui"
resource_bundle="$bin_dir/InclUI_inclui-gui.bundle"
icon_source="$repo/Sources/InclUIGUI/Resources/AppIcon.icon"
app="$HOME/Applications/InclUI.app"

if [[ ! -f "$binary" || ! -d "$resource_bundle" || ! -f "$icon_source/icon.json" ]]; then
    echo 'O build não produziu o executável ou os recursos necessários.' >&2
    exit 1
fi

developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ ! -x "$developer_dir/usr/bin/actool" ]]; then
    developer_dir="/Applications/Xcode.app/Contents/Developer"
fi
if [[ ! -x "$developer_dir/usr/bin/actool" ]]; then
    echo 'Instale o Xcode para compilar o ícone dinâmico do InclUI.' >&2
    exit 1
fi

icon_work="$(mktemp -d)"
trap 'rm -rf "$icon_work"' EXIT
DEVELOPER_DIR="$developer_dir" xcrun actool \
    --compile "$icon_work" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$icon_work/partial.plist" \
    "$icon_source"
if [[ ! -s "$icon_work/Assets.car" || ! -s "$icon_work/AppIcon.icns" ]]; then
    echo 'O Xcode não gerou os recursos do ícone do InclUI.' >&2
    exit 1
fi

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/InclUI"
rm -rf "$app/Contents/Resources/InclUI_inclui-gui.bundle"
cp -R "$resource_bundle" "$app/Contents/Resources/"
cp "$icon_work/Assets.car" "$icon_work/AppIcon.icns" "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>pt_BR</string>
    <key>CFBundleDisplayName</key><string>InclUI</string>
    <key>CFBundleExecutable</key><string>InclUI</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
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
if [[ "${INCLUI_SKIP_OPEN:-0}" != 1 ]]; then
    open "$app"
fi
