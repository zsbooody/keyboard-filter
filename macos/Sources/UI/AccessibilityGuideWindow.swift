import AppKit
import ApplicationServices

enum AccessibilityMonitor {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for spec in urls {
            if let url = URL(string: spec), NSWorkspace.shared.open(url) {
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
}

final class AccessibilityGuideWindowController: NSWindowController {
    enum Mode {
        /// 未获得辅助功能授权（或旧授权已随版本更新失效）。
        case needPermission
        /// 授权正常，但事件监听尚未建立（常见于刚登录系统的前几秒），正在自动重试。
        case tapRetry
    }

    static var current: AccessibilityGuideWindowController?

    static func showIfNeeded(mode: Mode) {
        if let wc = current {
            wc.applyMode(mode)
            return
        }
        let wc = AccessibilityGuideWindowController(mode: mode)
        current = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        current?.close()
        current = nil
    }

    private var bodyLabel: NSTextField?
    private var settingsButton: NSButton?

    init(mode: Mode) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 470, height: 300))
        view.autoresizingMask = [.width, .height]

        let label = NSTextField(wrappingLabelWithString: "")
        label.frame = NSRect(x: 20, y: 76, width: 430, height: 200)
        view.addSubview(label)
        bodyLabel = label

        let button = NSButton(title: "打开系统设置", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 155, y: 20, width: 160, height: 32)
        button.target = self
        button.action = #selector(openSettings)
        view.addSubview(button)
        settingsButton = button

        window.contentView = view
        applyMode(mode)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyMode(_ mode: Mode) {
        guard let window = window, let label = bodyLabel, let button = settingsButton else { return }
        switch mode {
        case .needPermission:
            window.title = "需要辅助功能权限"
            label.stringValue =
                "键盘防抖需要「辅助功能」权限才能拦截抖动按键。\n\n"
                + "请到 系统设置 → 隐私与安全性 → 辅助功能 中勾选本应用。授权后会自动开始工作。\n\n"
                + "※ 若列表中本应用的开关已经是打开的（常见于更新/替换应用版本之后）："
                + "说明旧的授权记录已失效，请先在列表中将它移除（−），再点「+」重新添加本应用并打开开关。"
            button.isHidden = false
        case .tapRetry:
            window.title = "正在恢复键盘监听"
            label.stringValue =
                "辅助功能权限已生效，正在自动恢复键盘监听，通常几秒内完成，无需任何操作。\n\n"
                + "若长时间停留在此窗口，请尝试退出应用后重新打开；"
                + "若菜单栏仍显示「无辅助功能权限」，请按引导重新授权。"
            button.isHidden = true
        }
    }

    @objc private func openSettings() {
        _ = AccessibilityMonitor.isTrusted(prompt: true)
        AccessibilityMonitor.openSystemSettings()
    }
}
