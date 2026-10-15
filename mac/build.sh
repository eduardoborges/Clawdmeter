#!/bin/sh
# Builds mac/build/Clawdmeter.app and signs it. macOS ties the Bluetooth
# permission to the signature, so sign with a real identity (SIGN_ID, or the
# first valid "Apple Development" certificate) or it asks again after every
# build. Without one, the app is signed ad hoc.
set -e
: "${SIGN_ID:=$(security find-identity -v -p codesigning \
  | awk '/Apple Development/ && !/REVOKED/ { print $2; exit }')}"
cd "$(dirname "$0")"
swift build -c release --product Clawdmeter
app=build/Clawdmeter.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Clawdmeter" "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
codesign --force --sign "${SIGN_ID:--}" "$app"
echo "$app"
