import AppKit

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var advancedWC: AdvancedSettingsWindowController?
    private var permissionTimer: Timer?
    private var lastTrusted: Bool?
    private var lastTapInstalled: Bool?
    private var tapRetryStreak = 0

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "键盘防抖工具")
            image?.isTemplate = true
            button.image = image
            button.image?.size = NSSize(width: 18, height: 18)
        }
        rebuildMenu()
        startPermissionWatch()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let engine = FilterEngine.shared
        let trusted = AccessibilityMonitor.isTrusted()
        let tapInstalled = FilterEngine.shared.eventTap != nil
        let summary: String
        if !trusted {
            summary = "键盘防抖 · 无辅助功能权限"
        } else if !tapInstalled {
            summary = "键盘防抖 · 正在恢复键盘监听…"
        } else {
            summary = "键盘防抖 · \(engine.statusText()) · \(SettingsStore.shared.pressRate)/秒"
        }
        statusItem?.button?.toolTip = summary

        let summaryItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(.separator())

        if !trusted {
            let perm = NSMenuItem(title: "授予辅助功能权限…", action: #selector(showPermissionGuide), keyEquivalent: "")
            perm.target = self
            menu.addItem(perm)
            menu.addItem(.separator())
        }

        let quick = NSMenuItem(title: "全盘模式（全部按键防抖）", action: #selector(selectQuick), keyEquivalent: "")
        quick.target = self
        quick.state = engine.mode == .quickAll ? .on : .off
        menu.addItem(quick)

        let adv = NSMenuItem(title: "高级设置（手动选键 / 自动分析）…", action: #selector(openAdvanced), keyEquivalent: "")
        adv.target = self
        adv.state = engine.mode != .quickAll ? .on : .off
        menu.addItem(adv)

        menu.addItem(.separator())

        let rateMenu = NSMenu()
        let rates: [(Int, String)] = [
            (1, "1次/秒 (非常强防抖)"),
            (5, "5次/秒 (中等防抖)"),
            (10, "10次/秒 (默认防抖)"),
            (20, "20次/秒 (轻微防抖)")
        ]
        for (rate, label) in rates {
            let item = NSMenuItem(title: label, action: #selector(setRate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = rate
            item.state = SettingsStore.shared.pressRate == rate ? .on : .off
            rateMenu.addItem(item)
        }
        let rateItem = NSMenuItem(title: "防抖频率", action: nil, keyEquivalent: "")
        menu.addItem(rateItem)
        menu.setSubmenu(rateMenu, for: rateItem)

        let autoTitle = SettingsStore.shared.autoStart ? "关闭自启" : "开启自启"
        let autoItem = NSMenuItem(title: autoTitle, action: #selector(toggleAutoStart), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = SettingsStore.shared.autoStart ? .on : .off
        menu.addItem(autoItem)

        let test = NSMenuItem(title: "测试防抖效果", action: #selector(testAntiBounce), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
        refreshIcon(trusted: trusted)
    }

    private func refreshIcon(trusted: Bool) {
        guard let button = statusItem?.button else { return }
        let name = trusted ? "keyboard" : "exclamationmark.triangle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "键盘防抖工具")
        image?.isTemplate = true
        button.image = image
        button.image?.size = NSSize(width: 18, height: 18)
    }

    private func startPermissionWatch() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPermissionAndTap()
        }
        permissionTimer?.tolerance = 0.4
    }

    func checkPermissionAndTap() {
        let trusted = AccessibilityMonitor.isTrusted()
        var tapInstalled = false
        if trusted {
            if FilterEngine.shared.eventTap == nil {
                tapInstalled = FilterEngine.shared.installTap()
            } else {
                tapInstalled = true
            }
        } else if FilterEngine.shared.eventTap != nil {
            FilterEngine.shared.removeTap()
        }

        if trusted && tapInstalled {
            tapRetryStreak = 0
            AccessibilityGuideWindowController.dismiss()
        } else if !trusted {
            tapRetryStreak = 0
            AccessibilityGuideWindowController.showIfNeeded(mode: .needPermission)
        } else {
            // 已授权但事件 tap 尚未建立（登录初期常见），短暂静默重试后再提示。
            tapRetryStreak += 1
            if tapRetryStreak >= 3 {
                AccessibilityGuideWindowController.showIfNeeded(mode: .tapRetry)
            }
        }

        if lastTrusted != trusted || lastTapInstalled != tapInstalled {
            lastTrusted = trusted
            lastTapInstalled = tapInstalled
            rebuildMenu()
        }
    }

    @objc private func showPermissionGuide() {
        AccessibilityGuideWindowController.showIfNeeded(mode: .needPermission)
        _ = AccessibilityMonitor.isTrusted(prompt: true)
        AccessibilityMonitor.openSystemSettings()
    }

    @objc private func selectQuick() {
        FilterEngine.shared.setMode(.quickAll)
        rebuildMenu()
        let alert = NSAlert()
        alert.messageText = "已切换到全盘模式"
        alert.informativeText = "将对全部按键按当前频率防抖。\n若只需对个别键防抖，或想用自动分析，请打开「高级设置」。"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func openAdvanced() {
        let engine = FilterEngine.shared
        let wc = AdvancedSettingsWindowController(
            useAuto: engine.mode == .autoLearn,
            manualKeys: SettingsStore.shared.targetKeys
        )
        wc.onConfirm = { [weak self] useAuto, manualKeys in
            if !useAuto {
                SettingsStore.shared.targetKeys = manualKeys
            }
            engine.setMode(useAuto ? .autoLearn : .advanced)
            engine.syncMasks()
            SettingsStore.shared.requestDeferredSave()
            self?.rebuildMenu()
            self?.advancedWC = nil
        }
        advancedWC = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setRate(_ sender: NSMenuItem) {
        FilterEngine.shared.setPressRate(sender.tag)
        rebuildMenu()
    }

    @objc private func toggleAutoStart() {
        let enabled = !SettingsStore.shared.autoStart
        SettingsStore.shared.autoStart = enabled
        AutoStartManager.apply(enabled: enabled)
        SettingsStore.shared.requestDeferredSave()
        rebuildMenu()
    }

    @objc private func testAntiBounce() {
        let alert = NSAlert()
        alert.messageText = "防抖测试"
        switch FilterEngine.shared.mode {
        case .quickAll:
            alert.informativeText = "全盘模式：全部按键防抖。\n请快速连按任意键验证。"
            alert.alertStyle = .informational
        case .advanced:
            if SettingsStore.shared.targetKeys.isEmpty {
                alert.informativeText = "手动选键为空。请打开「高级设置」勾选按键。"
                alert.alertStyle = .warning
            } else {
                alert.informativeText = "手动模式已选 \(SettingsStore.shared.targetKeys.count) 键。请连按已选按键验证。"
                alert.alertStyle = .informational
            }
        case .autoLearn:
            alert.informativeText = "自动分析，当前纳入 \(FilterEngine.shared.autoKeys.count) 键。\n对可疑键制造抖动；纳入后连按应被过滤。"
            alert.alertStyle = .informational
        }
        alert.runModal()
    }

    @objc private func quitApp() {
        SettingsStore.shared.persistNow()
        FilterEngine.shared.removeTap()
        NSApp.terminate(nil)
    }
}
