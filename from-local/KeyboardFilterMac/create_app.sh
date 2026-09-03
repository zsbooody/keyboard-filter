#!/bin/bash

# 创建macOS应用包脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}创建macOS应用包...${NC}"

# 检查可执行文件是否存在
if [ ! -f "KeyboardFilterMac" ]; then
    echo -e "${RED}错误: 未找到可执行文件 KeyboardFilterMac${NC}"
    echo "请先运行 ./build.sh 构建应用"
    exit 1
fi

# 应用包名称
APP_NAME="键盘防抖工具"
APP_BUNDLE_NAME="${APP_NAME}.app"
APP_BUNDLE_DIR="dist/${APP_BUNDLE_NAME}"
CONTENTS_DIR="${APP_BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 清理旧目录
rm -rf "dist"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo -e "${YELLOW}创建应用包结构...${NC}"

# 复制可执行文件
cp "KeyboardFilterMac" "${MACOS_DIR}/"
chmod +x "${MACOS_DIR}/KeyboardFilterMac"

# 创建Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
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
    <string>键盘防抖工具</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>

    <!-- 辅助功能权限说明 -->
    <key>NSAppleEventsUsageDescription</key>
    <string>键盘防抖工具需要监听键盘事件以实现防抖功能</string>

</dict>
</plist>
EOF

# 创建简单的应用图标（如果没有）
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo -e "${YELLOW}创建默认应用图标...${NC}"
    # 创建临时图标文件（使用系统图标）
    cat > "${RESOURCES_DIR}/AppIcon.icns" << 'EOF'
<!-- 占位符图标，实际使用中应提供真正的.icns文件 -->
EOF
    echo "注意: 使用默认图标，建议提供自定义 AppIcon.icns 文件"
fi

# 创建文档目录
DOCS_DIR="dist/文档"
mkdir -p "${DOCS_DIR}"

# 复制文档
cp "README.md" "${DOCS_DIR}/README.md"
cp "安装说明.txt" "${DOCS_DIR}/安装说明.txt"

# 转换文档为纯文本格式（如果需要）
iconv -f utf-8 -t utf-8 "${DOCS_DIR}/安装说明.txt" > "${DOCS_DIR}/安装说明_中文.txt" 2>/dev/null || true

# 创建版本信息文件
cat > "dist/版本信息.txt" << 'EOF'
键盘防抖工具 (macOS 版本)
版本: 1.0.0
构建日期: 2026-01-26
系统要求: macOS 11.0 (Big Sur) 或更高版本
架构: x86_64 (Intel) 和 Apple Silicon (通过Rosetta 2)

功能特性:
- 键盘防抖: 过滤机械键盘按键抖动
- 延迟调节: 10-200ms 可调
- 按键过滤: 支持自定义按键代码
- 频率限制: 5-100次/秒
- 开机自启动: 通过LaunchAgents实现
- 设置保存: 自动保存用户配置

安装说明:
1. 将"键盘防抖工具.app"拖到"应用程序"文件夹
2. 首次运行需要授予辅助功能权限
3. 在系统设置 → 隐私与安全性 → 辅助功能中启用

卸载说明:
1. 删除"键盘防抖工具.app"
2. 删除配置文件: ~/Library/Preferences/com.keyboardfilter.mac.plist
3. 删除启动项: ~/Library/LaunchAgents/com.keyboardfilter.mac.app.plist

注意事项:
- 必须授予辅助功能权限才能正常工作
- 权限授予后需要重新启动应用
- 建议防抖延迟设置: 机械键盘30-50ms, 薄膜键盘10-20ms

基于Windows键盘防抖工具 v2.3.3.0 开发
EOF

echo -e "${GREEN}应用包创建完成!${NC}"
echo -e "\n${YELLOW}生成的文件:${NC}"
echo "dist/"
echo "  ├── ${APP_BUNDLE_NAME}/          # macOS应用包"
echo "  ├── 文档/                        # 使用文档"
echo "  │   ├── README.md               # 英文说明"
echo "  │   └── 安装说明.txt            # 中文安装指南"
echo "  └── 版本信息.txt                # 版本详情"

echo -e "\n${YELLOW}安装方法:${NC}"
echo "1. 将 '${APP_BUNDLE_NAME}' 拖到 '应用程序' 文件夹"
echo "2. 首次运行时授予辅助功能权限"
echo "3. 启动应用后点击 '开始监听'"

echo -e "\n${YELLOW}打包为ZIP:${NC}"
echo "cd dist && zip -r '${APP_NAME}_macOS_v1.0.0.zip' '${APP_BUNDLE_NAME}' 文档 版本信息.txt"

# 自动创建ZIP包
echo -e "\n${GREEN}创建ZIP分发包...${NC}"
cd dist && zip -qr "${APP_NAME}_macOS_v1.0.0.zip" "${APP_BUNDLE_NAME}" "文档" "版本信息.txt"
cd ..

echo -e "${GREEN}完成!${NC}"
echo "ZIP包: dist/${APP_NAME}_macOS_v1.0.0.zip"
echo "大小: $(du -h "dist/${APP_NAME}_macOS_v1.0.0.zip" | cut -f1)"