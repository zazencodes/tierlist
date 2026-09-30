#!/usr/bin/env bash
# Builds build/Tier List ZC.app. The app finds the repo from its own location, so it runs from there.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Tier List ZC.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
swiftc -O "$root/mac/main.swift" -framework Cocoa -framework WebKit -o "$app/Contents/MacOS/TierList"

# App icon: render mac/icon.swift at 1024px, scale it to every size an .icns holds.
iconset="$root/build/AppIcon.iconset"
rm -rf "$iconset" && mkdir -p "$iconset" "$app/Contents/Resources"
swift "$root/mac/icon.swift" "$iconset/icon_512x512@2x.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${s}x${s}.png" >/dev/null
  if [ $s -lt 512 ]; then sips -z $((s * 2)) $((s * 2)) "$iconset/icon_512x512@2x.png" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null; fi
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tier List ZC</string>
  <key>CFBundleIdentifier</key><string>com.zazencodes.tierlist</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>TierList</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$app"
echo "Built $app"
