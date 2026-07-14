#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
APP_BUNDLE="$APP_DIR/.build/DerivedData/Build/Products/Debug/LazyEnvironment.app"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

cd "$APP_DIR"

echo "==> Generating Xcode project"
xcodegen generate >/dev/null

echo "==> Building LazyEnvironment (Debug)"
xcodebuild -project LazyEnvironment.xcodeproj -scheme LazyEnvironment -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData build -quiet

echo "==> Launching"
pkill -x LazyEnvironment 2>/dev/null || true
sleep 1
if [ $# -gt 0 ]; then
    open "$APP_BUNDLE" --args "$@"
else
    open "$APP_BUNDLE"
fi
echo "==> Running: $APP_BUNDLE"
