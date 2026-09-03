#!/bin/bash

# 键盘防抖工具 - 构建和分发脚本
# 自动完成构建、打包和创建分发包

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 应用信息
APP_NAME="键盘防抖工具"
APP_NAME_EN="KeyboardFilterMac"
VERSION="1.0.0"
BUILD_DATE=$(date +%Y-%m-%d)

# 显示标题
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  键盘防抖工具 macOS 版本 - 分发包构建   ${NC}"
echo -e "${BLUE}  版本: ${VERSION} | 日期: ${BUILD_DATE}    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 步骤1: 检查依赖
check_dependencies() {
    echo -e "${YELLOW}[1/4] 检查系统依赖...${NC}"

    local missing_deps=()

    # 检查Swift编译器
    if ! command -v swift &> /dev/null; then
        missing_deps+=("Swift编译器 (Xcode命令行工具)")
    fi

    # 检查Swift编译器
    if ! command -v swiftc &> /dev/null; then
        missing_deps+=("swiftc编译器")
    fi

    # 检查其他工具
    for tool in zip xcodebuild file; do
        if ! command -v $tool &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少以下依赖:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "安装Xcode命令行工具:"
        echo "  xcode-select --install"
        exit 1
    fi

    echo -e "  ${GREEN}✓ 所有依赖已安装${NC}"
    echo "  Swift版本: $(swift --version | head -n1)"
}

# 步骤2: 构建应用
build_app() {
    echo -e "\n${YELLOW}[2/4] 构建应用...${NC}"

    # 清理旧构建
    if [ -f "KeyboardFilterMac" ]; then
        echo "  清理旧构建文件..."
        rm -f KeyboardFilterMac
    fi

    # 编译Swift源文件
    echo "  编译Swift源文件..."

    # 编译命令
    local sources=$(find Sources -name "*.swift" | tr '\n' ' ')

    if swiftc -swift-version 5 -O -suppress-warnings \
        -target x86_64-apple-macos11.0 \
        -framework Cocoa -framework CoreGraphics -framework Foundation \
        $sources -o KeyboardFilterMac 2>&1; then
        echo -e "  ${GREEN}✓ 编译成功${NC}"

        # 检查文件
        local file_info=$(file KeyboardFilterMac)
        local file_size=$(du -h KeyboardFilterMac | cut -f1)
        echo "  可执行文件: $file_info"
        echo "  文件大小: $file_size"
    else
        echo -e "${RED}✗ 编译失败${NC}"
        exit 1
    fi
}

# 步骤3: 创建应用包
create_app_bundle() {
    echo -e "\n${YELLOW}[3/4] 创建应用包...${NC}"

    # 应用包路径
    local app_bundle_name="${APP_NAME}.app"
    local app_bundle_dir="dist/${app_bundle_name}"
    local contents_dir="${app_bundle_dir}/Contents"
    local macos_dir="${contents_dir}/MacOS"
    local resources_dir="${contents_dir}/Resources"

    # 清理旧目录
    echo "  准备目录结构..."
    rm -rf "dist/${app_bundle_name}"
    mkdir -p "${macos_dir}" "${resources_dir}"

    # 复制可执行文件
    echo "  复制可执行文件..."
    cp "KeyboardFilterMac" "${macos_dir}/"
    chmod +x "${macos_dir}/KeyboardFilterMac"

    # 创建Info.plist
    echo "  创建应用配置..."
    cat > "${contents_dir}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>KeyboardFilterMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.keyboardfilter.mac.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>键盘防抖工具需要监听键盘事件以实现防抖功能</string>
</dict>
</plist>
EOF

    # 清理旧文档和版本信息
    echo "  清理旧文档..."
    rm -rf "dist/文档"
    rm -f "dist/版本信息.txt"

    # 创建安装说明文件
    echo "  创建安装说明..."
    cat > "dist/安装说明.txt" << EOF
${APP_NAME} (macOS 版本)
版本: ${VERSION}
构建日期: ${BUILD_DATE}
系统要求: macOS 11.0 (Big Sur) 或更高版本
架构: x86_64 (兼容Intel和Apple Silicon via Rosetta 2)

功能特性:
- 键盘防抖: 过滤机械键盘按键抖动
- 延迟调节: 10-200ms 可调
- 按键过滤: 支持自定义按键代码
- 频率限制: 5-100次/秒
- 开机自启动: 通过LaunchAgents实现
- 设置保存: 自动保存用户配置

安装说明:
1. 解压ZIP文件
2. 将"${APP_NAME}.app"拖到"应用程序"文件夹
3. 首次运行需要授予辅助功能权限
4. 在系统设置 → 隐私与安全性 → 辅助功能中启用本应用
5. 重新启动应用

使用说明:
1. 启动应用后点击"开始监听"
2. 点击"打开设置"进行详细配置
3. 建议设置: 机械键盘30-50ms, 薄膜键盘10-20ms

卸载说明:
1. 删除"${APP_NAME}.app"
2. 删除配置文件: ~/Library/Preferences/com.keyboardfilter.mac.plist
3. 删除启动项: ~/Library/LaunchAgents/com.keyboardfilter.mac.app.plist

基于Windows键盘防抖工具 v2.3.3.0 开发
EOF

    echo -e "  ${GREEN}✓ 应用包创建完成${NC}"
    echo "  应用包路径: ${app_bundle_dir}"
}

# 步骤4: 创建分发包
create_distribution() {
    echo -e "\n${YELLOW}[4/4] 创建分发包...${NC}"

    # ZIP包名称
    local zip_name="${APP_NAME_EN}_macOS_v${VERSION}.zip"
    local zip_path="dist/${zip_name}"

    # 进入dist目录
    cd dist

    # 创建ZIP包
    echo "  创建ZIP分发包: ${zip_name}"

    # 列出要打包的文件
    local files_to_zip=()
    if [ -d "${APP_NAME}.app" ]; then
        files_to_zip+=("${APP_NAME}.app")
    fi
    if [ -f "安装说明.txt" ]; then
        files_to_zip+=("安装说明.txt")
    fi

    # 创建ZIP
    zip -qr "${zip_name}" "${files_to_zip[@]}"

    # 返回原目录
    cd ..

    # 检查ZIP文件
    if [ -f "${zip_path}" ]; then
        local zip_size=$(du -h "${zip_path}" | cut -f1)
        echo -e "  ${GREEN}✓ ZIP包创建成功${NC}"
        echo "  ZIP包路径: ${zip_path}"
        echo "  文件大小: ${zip_size}"

        # 显示MD5校验和
        echo "  MD5校验和: $(md5 -q "${zip_path}")"
    else
        echo -e "${RED}✗ ZIP包创建失败${NC}"
        exit 1
    fi
}

# 步骤5: 显示摘要
show_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}           构建完成 - 摘要              ${NC}"
    echo -e "${BLUE}========================================${NC}"

    local zip_path="dist/${APP_NAME_EN}_macOS_v${VERSION}.zip"
    local app_path="dist/${APP_NAME}.app"

    echo -e "${GREEN}✓ 所有步骤已完成${NC}"
    echo ""
    echo -e "${YELLOW}生成的文件:${NC}"
    echo "  📦 ${zip_path}"
    echo "  📁 ${app_path}"
    echo "  📄 dist/安装说明.txt"
    echo ""
    echo -e "${YELLOW}安装步骤:${NC}"
    echo "  1. 解压 ${APP_NAME_EN}_macOS_v${VERSION}.zip"
    echo "  2. 将 '${APP_NAME}.app' 拖到'应用程序'文件夹"
    echo "  3. 首次运行时授予辅助功能权限"
    echo "  4. 重新启动应用"
    echo ""
    echo -e "${YELLOW}测试运行:${NC}"
    echo "  open \"${app_path}\""
    echo ""
    echo -e "${YELLOW}清理构建文件:${NC}"
    echo "  rm -rf dist KeyboardFilterMac"
    echo ""
    echo -e "${BLUE}========================================${NC}"
}

# 主执行流程
main() {
    echo -e "${GREEN}开始构建分发包...${NC}"

    # 执行所有步骤
    check_dependencies
    build_app
    create_app_bundle
    create_distribution
    show_summary
}

# 运行主函数
main