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
    static var current: AccessibilityGuideWindowController?

    static func showIfNeeded() {
        if current != nil { return }
        let wc = AccessibilityGuideWindowController()
        current = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        current?.close()
        current = nil
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "需要辅助功能权限"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 220))
        view.autoresizingMask = [.width, .height]

        let label = NSTextField(wrappingLabelWithString: "键盘防抖需要「辅助功能」权限才能拦截抖动按键。\n\n请到 系统设置 → 隐私与安全性 → 辅助功能 中勾选本应用，然后回到这里。授权后会自动开始工作。")
        label.frame = NSRect(x: 20, y: 72, width: 400, height: 120)
        view.addSubview(label)

        let button = NSButton(title: "打开系统设置", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 140, y: 20, width: 160, height: 32)
        button.target = self
        button.action = #selector(openSettings)
        view.addSubview(button)

        window.contentView = view
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func openSettings() {
        _ = AccessibilityMonitor.isTrusted(prompt: true)
        AccessibilityMonitor.openSystemSettings()
    }
}
