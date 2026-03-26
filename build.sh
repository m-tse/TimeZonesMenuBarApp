#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building World Clock..."

SDK_PATH=$(xcrun --show-sdk-path)

swiftc \
    -target arm64-apple-macos13.0 \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -O \
    -o WorldClock \
    Sources/*.swift

echo "Creating app bundle..."
rm -rf "Time Zones.app"
mkdir -p "Time Zones.app/Contents/MacOS"
mkdir -p "Time Zones.app/Contents/Resources"
cp WorldClock "Time Zones.app/Contents/MacOS/"
cp Info.plist "Time Zones.app/Contents/"
rm WorldClock

echo "Built successfully: Time Zones.app"
echo "Run with: open 'Time Zones.app'"
