#!/bin/bash
# Builds build/Coast.app (Apple silicon, signed). Pass --install to copy it into /Applications.
#
# Signing: uses $CODESIGN_IDENTITY if set, otherwise the first Developer ID or Apple
# Development certificate in your keychain, otherwise ad-hoc. A real certificate
# matters here: macOS ties the Accessibility permission to the signature, so an
# ad-hoc build asks for permission again after every rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin=$(swift build -c release --show-bin-path)/Coast

app=build/Coast.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Coast"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$app/Contents/Resources/"

identity=${CODESIGN_IDENTITY:-}
if [ -z "$identity" ]; then
  identity=$(security find-identity -v -p codesigning | grep -E '"(Developer ID Application|Apple Development)' | head -1 | sed -E 's/.*"(.*)"/\1/' || true)
fi
identity=${identity:--}
codesign --force --options runtime --sign "$identity" "$app"
echo "Built $app (signed with: $identity)"

if [ "${1:-}" = "--install" ]; then
  pkill -x Coast 2>/dev/null || true
  rm -rf /Applications/Coast.app
  cp -R "$app" /Applications/
  echo "Installed /Applications/Coast.app"
fi
