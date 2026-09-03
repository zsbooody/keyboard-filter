# 本地旧目录对照（from-local）

来源：本机 `~/Downloads/keyboard1020`（2026-01 左右的 SwiftUI macOS 实现 + 笔记）。

当前正式代码在仓库根目录，以 GitHub `main`（v2.5.4）为准：

| 路径 | 来源 | 说明 |
|------|------|------|
| `src/`、`build.ps1`、`docs/` | GitHub | Windows 托盘版 v2.5.4 |
| `macos/` | GitHub | 与 Windows 对齐的 **Swift 单文件** 菜单栏版 |
| `from-local/KeyboardFilterMac/` | 本机 Downloads | 更早的 **SwiftUI 多文件** macOS 版（包名 KeyboardFilterMac，目标 macOS 11） |
| `from-local/*.md`、`安装说明.txt`、`更新报告_2025-10-20.txt` | 本机 Downloads | 评测/安装笔记，不是当前发布文档 |
| `from-local/TestPackage/` | 本机 Downloads | 本地试验包 |

未并入本仓库的内容：编译产物、`.build` 缓存、Windows 运行时 DLL、`node_modules_cache`。图标与 `assets/keyboard_icon.ico` 相同，未重复拷贝。

两边 macOS 实现不要混编：改当前功能走 `macos/`，查旧 UI/脚本才看本目录。
