#!/bin/sh
# Build a signed debug build and install it on the connected iPhone.
# Free-Apple-ID signatures expire after 7 days; rerun this to refresh.
set -eu
cd "$(dirname "$0")/.."

DEVICE_ID="${1:-D6888A73-DE9C-53E2-82FB-9D945AFB92B1}" # iPhone - Konstas

if ! [ -d DriveStats.xcodeproj ]; then
  xcodegen generate
fi

# codesign chokes on Finder metadata that Downloads/AirDrop leave on files.
xattr -cr App Packages project.yml 2>/dev/null || true

xcodebuild -project DriveStats.xcodeproj -scheme DriveStats \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  -derivedDataPath build-device \
  build

xcrun devicectl device install app --device "$DEVICE_ID" \
  build-device/Build/Products/Debug-iphoneos/DriveStats.app
