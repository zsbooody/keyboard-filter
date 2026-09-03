#!/bin/bash

# macOS键盘防抖工具构建脚本
# 使用swiftc直接编译

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始构建键盘防抖工具 (Swift编译)...${NC}"

# 检查所需工具
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: 未找到 $1${NC}"
        echo "请安装Xcode命令行工具: xcode-select --install"
        exit 1
    fi
}

check_tool swift
check_tool swiftc

# 创建构建目录
BUILD_DIR=".build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 收集源文件
SOURCES=()
while IFS= read -r -d $'\0' file; do
    SOURCES+=("$file")
done < <(find Sources -name "*.swift" -print0)

echo "找到 ${#SOURCES[@]} 个源文件"

# 编译参数
FRAMEWORKS="-framework Cocoa -framework CoreGraphics -framework Foundation"
MIN_MACOS="-target x86_64-apple-macos11.0"
SWIFT_FLAGS="-swift-version 5 -O -suppress-warnings"

# 编译单个模块
echo -e "${YELLOW}编译Swift源文件...${NC}"

# 创建module.modulemap
cat > "$BUILD_DIR/module.modulemap" << 'EOF'
module AppKit [system] {
    header "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/AppKit.h"
    link "AppKit"
    export *
}

module CoreGraphics [system] {
    header "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreGraphics.framework/Headers/CoreGraphics.h"
    link "CoreGraphics"
    export *
}

module Foundation [system] {
    header "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Headers/Foundation.h"
    link "Foundation"
    export *
}
EOF

# 尝试直接编译
echo "编译命令: swiftc ${SWIFT_FLAGS} ${MIN_MACOS} ${FRAMEWORKS} ${SOURCES[@]} -o KeyboardFilterMac"

# 编译
if swiftc ${SWIFT_FLAGS} ${MIN_MACOS} ${FRAMEWORKS} "${SOURCES[@]}" -o "$BUILD_DIR/KeyboardFilterMac"; then
    echo -e "${GREEN}编译成功!${NC}"

    # 复制到当前目录
    cp "$BUILD_DIR/KeyboardFilterMac" .
    chmod +x KeyboardFilterMac

    # 显示文件信息
    echo -e "\n${YELLOW}构建结果:${NC}"
    file KeyboardFilterMac
    echo "文件大小: $(du -h KeyboardFilterMac | cut -f1)"

    # 显示使用说明
    echo -e "\n${GREEN}构建完成!${NC}"
    echo -e "\n${YELLOW}使用说明:${NC}"
    echo "1. 运行应用: ./KeyboardFilterMac"
    echo "2. 首次运行需要授予辅助功能权限"
    echo "3. 授予权限后重新启动应用"
    echo -e "\n详细说明请查看 README.md 和 安装说明.txt"

else
    echo -e "${RED}编译失败${NC}"
    echo "尝试使用备用构建方法..."

    # 尝试简单编译
    echo "尝试简单编译..."
    if swiftc -framework Cocoa -framework CoreGraphics "${SOURCES[@]}" -o "$BUILD_DIR/KeyboardFilterMacSimple"; then
        cp "$BUILD_DIR/KeyboardFilterMacSimple" KeyboardFilterMac
        chmod +x KeyboardFilterMac
        echo -e "${YELLOW}使用简化版本编译成功${NC}"
    else
        echo -e "${RED}所有编译尝试都失败${NC}"
        echo "请确保已安装Xcode命令行工具: xcode-select --install"
        echo "或尝试使用Xcode打开项目"
        exit 1
    fi
fi