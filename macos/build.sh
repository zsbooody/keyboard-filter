#!/bin/bash
# 在 macOS 上编译并打包菜单栏应用（需要 Xcode 命令行工具）
set -euo pipefail
cd "$(dirname "$0")"

SDKROOT="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}"
if [ ! -d "$SDKROOT" ]; then
  SDKROOT="$(/usr/bin/xcrun --show-sdk-path 2>/dev/null || true)"
fi
if [ -z "${SDKROOT}" ] || [ ! -d "${SDKROOT}" ]; then
  echo "找不到 macOS SDK" >&2
  exit 1
fi
export SDKROOT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos12.0"
BIN_DIR=".build/release"
mkdir -p "$BIN_DIR"
BIN="$BIN_DIR/KeyboardFilter"

# Command Line Tools 上的 SwiftPM 会因 PlatformPath 失败，改用 swiftc。
# shellcheck disable=SC2046
swiftc -O \
  -target "$TARGET" \
  -sdk "$SDKROOT" \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Combine \
  -framework CoreGraphics \
  -framework ApplicationServices \
  -framework QuartzCore \
  -o "$BIN" \
  $(find Sources -name '*.swift' | sort)

DIST="../dist/KeyboardFilter-macOS"
APP="$DIST/KeyboardFilter.app"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/KeyboardFilter"
chmod +x "$APP/Contents/MacOS/KeyboardFilter"

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh_CN</string>
	<key>CFBundleExecutable</key>
	<string>KeyboardFilter</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.keyboardfilter.mac</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>键盘防抖工具</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>2.5.4</string>
	<key>CFBundleVersion</key>
	<string>2.5.4</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

cp README-macos.md "$DIST/" 2>/dev/null || true

echo "Build OK: $APP"
echo "首次运行需授予「辅助功能」权限。"
