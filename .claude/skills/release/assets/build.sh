#!/bin/bash
# Archive, notarize, verify and zip a Satellite Eyes release.
#
#   .claude/skills/release/assets/build.sh <version>
#
# Expects the version bump to be committed already. Works in
# /tmp/satellite-eyes-<version> and writes the zip to ../sparkle beside the app
# repo. Exits non-zero, with the tail of the failing log, at the first problem.

set -euo pipefail

VERSION="${1:?usage: build.sh <version>}"
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
WORK="/tmp/satellite-eyes-$VERSION"
ARCHIVE="$WORK/satellite-eyes-$VERSION.xcarchive"
APP="$WORK/export/Satellite Eyes.app"
ZIP="$ROOT/../sparkle/satellite-eyes-$VERSION.zip"
AUTHORITY="Developer ID Application: Tom Taylor (UY2GK6B69X)"

cd "$ROOT"

fail() {
  echo "FAILED: $1" >&2
  [[ -n "${2:-}" && -f "$2" ]] && tail -20 "$2" >&2
  exit 1
}

run() { # run <log> <command...>
  local log="$1"; shift
  "$@" > "$log" 2>&1 || fail "$(basename "$log" .log)" "$log"
}

[[ -e "$ZIP" ]] && fail "$ZIP already exists"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "==> Archiving"
run "$WORK/archive.log" xcodebuild -project SatelliteEyes.xcodeproj -scheme "Satellite Eyes" \
  -configuration Release -archivePath "$ARCHIVE" archive
# The AppIntents metadata warning appears on every build and is harmless.
if grep "warning:" "$WORK/archive.log" | grep -v "Metadata extraction skipped" | sort -u | grep .; then
  fail "archive has warnings (above)"
fi

echo "==> Uploading for notarization"
run "$WORK/upload.log" xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist .claude/skills/release/assets/ExportOptions.plist \
  -allowProvisioningUpdates

# -exportNotarizedApp does not wait: it fails with "is processing" until Apple
# has finished, so retry for up to 20 minutes.
echo "==> Waiting for notarization"
for attempt in $(seq 1 40); do
  if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$WORK/export" \
      > "$WORK/notarize.log" 2>&1; then
    break
  fi
  grep -q "is processing" "$WORK/notarize.log" || fail "notarized export" "$WORK/notarize.log"
  [[ $attempt -eq 40 ]] && fail "still processing after 20 minutes" "$WORK/notarize.log"
  sleep 30
done

echo "==> Verifying"
INFO="$APP/Contents/Info.plist"
SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO")
[[ "$SHORT" == "$VERSION" ]] || fail "bundle version is $SHORT, expected $VERSION"
[[ "$BUILD" =~ ^[1-9][0-9]*$ ]] || fail "bad build number '$BUILD'"
codesign -dvv "$APP" 2>&1 | grep -q "Authority=$AUTHORITY" || fail "not signed by $AUTHORITY"
codesign -dvv "$APP" 2>&1 | grep -q "Runtime Version" || fail "hardened runtime missing"
xcrun stapler validate "$APP" > "$WORK/stapler.log" 2>&1 || fail "stapler validate" "$WORK/stapler.log"
spctl -a -vvv -t exec "$APP" > "$WORK/spctl.log" 2>&1 || fail "spctl" "$WORK/spctl.log"
grep -q "source=Notarized Developer ID" "$WORK/spctl.log" || fail "not notarized" "$WORK/spctl.log"

echo "==> Zipping"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "version: $SHORT"
echo "build:   $BUILD"
echo "zip:     $ZIP ($(stat -f %z "$ZIP") bytes)"
