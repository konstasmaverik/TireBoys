#!/bin/sh
# Build a signed debug build and install it on the connected iPhone.
# Free-Apple-ID signatures expire after 7 days; rerun this to refresh.
set -eu
cd "$(dirname "$0")/.."

DEVICE_ID="${1:-D6888A73-DE9C-53E2-82FB-9D945AFB92B1}" # iPhone - Konstas

if ! [ -d DriveStats.xcodeproj ]; then
  xcodegen generate
fi

# Build outside the repo: ~/Documents is iCloud-synced, and the file-provider
# xattrs iCloud stamps onto the .app make codesign fail with "resource fork,
# Finder information, or similar detritus not allowed".
DERIVED_DATA="$HOME/Library/Developer/DriveStats-build"

# codesign also chokes on Finder metadata that Downloads/AirDrop leave on files.
xattr -cr App Packages project.yml 2>/dev/null || true

xcodebuild -project DriveStats.xcodeproj -scheme DriveStats \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  -derivedDataPath "$DERIVED_DATA" \
  build

xcrun devicectl device install app --device "$DEVICE_ID" \
  "$DERIVED_DATA/Build/Products/Debug-iphoneos/DriveStats.app"
