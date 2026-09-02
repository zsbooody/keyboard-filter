#!/bin/bash
# 在 macOS 上编译（需要 Xcode 命令行工具）
set -e
cd "$(dirname "$0")"
swift build -c release
mkdir -p ../dist/KeyboardFilter-macOS
cp .build/release/KeyboardFilter ../dist/KeyboardFilter-macOS/keyboard_filter
cp README-macos.md ../dist/KeyboardFilter-macOS/ 2>/dev/null || true
echo "Build OK: ../dist/KeyboardFilter-macOS/keyboard_filter"
echo "首次运行需授予「辅助功能」权限。"
