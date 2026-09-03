#!/bin/bash

# macOS键盘防抖工具构建脚本
# 使用此脚本编译应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始构建键盘防抖工具...${NC}"

# 检查所需工具
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: 未找到 $1${NC}"
        echo "请安装Xcode命令行工具: xcode-select --install"
        exit 1
    fi
}

check_tool swift
check_tool xcodebuild

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

# 创建临时Xcode项目（简化版）
cat > "$BUILD_DIR/KeyboardFilterMac.xcodeproj/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		OBJ_1 /* KeyboardFilterMacApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = OBJ_6 /* KeyboardFilterMacApp.swift */; };
		OBJ_2 /* KeyboardMonitor.swift in Sources */ = {isa = PBXBuildFile; fileRef = OBJ_7 /* KeyboardMonitor.swift */; };
		OBJ_3 /* SettingsManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = OBJ_8 /* SettingsManager.swift */; };
		OBJ_4 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = OBJ_9 /* SettingsView.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		OBJ_5 /* KeyboardFilterMac */ = {isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = KeyboardFilterMac; sourceTree = BUILT_PRODUCTS_DIR; };
		OBJ_6 /* KeyboardFilterMacApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KeyboardFilterMacApp.swift; sourceTree = "<group>"; };
		OBJ_7 /* KeyboardMonitor.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KeyboardMonitor.swift; sourceTree = "<group>"; };
		OBJ_8 /* SettingsManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsManager.swift; sourceTree = "<group>"; };
		OBJ_9 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		OBJ_10 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		OBJ_11 /* Products */ = {
			isa = PBXGroup;
			children = (
				OBJ_5 /* KeyboardFilterMac */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		OBJ_12 /* KeyboardFilterMac */ = {
			isa = PBXGroup;
			children = (
				OBJ_6 /* KeyboardFilterMacApp.swift */,
				OBJ_7 /* KeyboardMonitor.swift */,
				OBJ_8 /* SettingsManager.swift */,
				OBJ_9 /* SettingsView.swift */,
				OBJ_11 /* Products */,
			);
			name = KeyboardFilterMac;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		OBJ_13 /* KeyboardFilterMac */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = OBJ_16 /* Build configuration list for PBXNativeTarget "KeyboardFilterMac" */;
			buildPhases = (
				OBJ_14 /* Sources */,
				OBJ_10 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = KeyboardFilterMac;
			productName = KeyboardFilterMac;
			productReference = OBJ_5 /* KeyboardFilterMac */;
			productType = "com.apple.product-type.tool";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		OBJ_17 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastUpgradeCheck = 9999;
				TargetAttributes = {
					OBJ_13 = {
						CreatedOnToolsVersion = 14.0;
					};
				};
			};
			buildConfigurationList = OBJ_18 /* Build configuration list for PBXProject "KeyboardFilterMac" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
			);
			mainGroup = OBJ_12;
			productRefGroup = OBJ_11 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				OBJ_13 /* KeyboardFilterMac */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		OBJ_14 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			fileRefs = (
				OBJ_6 /* KeyboardFilterMacApp.swift */,
				OBJ_7 /* KeyboardMonitor.swift */,
				OBJ_8 /* SettingsManager.swift */,
				OBJ_9 /* SettingsView.swift */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		OBJ_15 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ENABLE_OBJC_WEAK = YES;
				COMBINE_HIDPI_IMAGES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				FRAMEWORK_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/../../../../Library/Frameworks",
				);
				GCC_OPTIMIZATION_LEVEL = 0;
				HEADER_SEARCH_PATHS = (
					"$(inherited)",
					/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/**,
				);
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 11.0;
				OTHER_LDFLAGS = "-framework Cocoa -framework CoreGraphics";
				OTHER_SWIFT_FLAGS = "-suppress-warnings";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
				USE_HEADERMAP = NO;
			};
			name = Debug;
		};
		OBJ_16 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ENABLE_OBJC_WEAK = YES;
				COMBINE_HIDPI_IMAGES = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				FRAMEWORK_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/../../../../Library/Frameworks",
				);
				HEADER_SEARCH_PATHS = (
					"$(inherited)",
					/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/**,
				);
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 11.0;
				OTHER_LDFLAGS = "-framework Cocoa -framework CoreGraphics";
				OTHER_SWIFT_FLAGS = "-suppress-warnings";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
				USE_HEADERMAP = NO;
			};
			name = Release;
		};
		OBJ_18 /* Default */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ENABLE_OBJC_WEAK = YES;
				COMBINE_HIDPI_IMAGES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				FRAMEWORK_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/../../../../Library/Frameworks",
				);
				GCC_OPTIMIZATION_LEVEL = 0;
				HEADER_SEARCH_PATHS = (
					"$(inherited)",
					/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/**,
				);
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 11.0;
				OTHER_LDFLAGS = "-framework Cocoa -framework CoreGraphics";
				OTHER_SWIFT_FLAGS = "-suppress-warnings";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
				USE_HEADERMAP = NO;
			};
			name = Default;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		OBJ_19 /* Build configuration list for PBXProject "KeyboardFilterMac" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				OBJ_18 /* Default */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Default;
		};
		OBJ_20 /* Build configuration list for PBXNativeTarget "KeyboardFilterMac" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				OBJ_15 /* Debug */,
				OBJ_16 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = OBJ_17 /* Project object */;
}
EOF

# 复制源文件到构建目录
cp -r Sources "$BUILD_DIR/"

# 使用xcodebuild构建
echo -e "${YELLOW}使用xcodebuild构建...${NC}"
cd "$BUILD_DIR"
xcodebuild -project KeyboardFilterMac.xcodeproj -configuration Release -scheme KeyboardFilterMac build

# 检查构建结果
if [ -f "build/Release/KeyboardFilterMac" ]; then
    cp "build/Release/KeyboardFilterMac" ..
    cd ..
    echo -e "${GREEN}构建成功!${NC}"
    echo "可执行文件: KeyboardFilterMac"

    # 设置执行权限
    chmod +x KeyboardFilterMac

    # 显示使用说明
    echo -e "\n${YELLOW}使用说明:${NC}"
    echo "1. 运行应用: ./KeyboardFilterMac"
    echo "2. 首次运行需要授予辅助功能权限"
    echo "3. 授予权限后重新启动应用"

else
    echo -e "${RED}构建失败${NC}"
    exit 1
fi