# 键盘防抖工具 v2.5.4

轻量 Windows 托盘小工具：底层键盘钩子过滤抖动/连击。静态链接，单文件约 260KB。

## 资源占用

- 钩子热路径：固定数组 + GetTickCount64，无堆分配、不写注册表、不刷新 UI
- 设置写入延迟合并
- 空闲时几乎无后台循环

## 工作模式

1. 全盘模式（全部按键防抖）
2. 高级设置：手动选键 / 自动分析（同一页，均可鼠标点选增减）

## 编译

```powershell
.\build.ps1 -Install
```

## macOS 版

`macos/` 下为功能对齐的 macOS 菜单栏版（Swift + CGEventTap），需在 macOS 上运行 `macos/build.sh` 编译，详见 `macos/README-macos.md`。
