// 键盘防抖工具 macOS 版 v2.5.4
// 与 Windows 版逻辑对齐：
// - 全盘模式：全部按键防抖
// - 高级设置：手动选键 / 自动分析（同一页，仅鼠标点选增减，只有「确定」）
// - 自动分析：只看原始信号；长按系统连发不纳入；仅 ≤35ms 接触抖动计入，累计 ≥5 次纳入
// 需要「辅助功能」权限（系统设置 → 隐私与安全性 → 辅助功能）。

import Cocoa
import CoreGraphics

// MARK: - 常量（与 Windows 版一致）

let kLearnBounceMs: Double = 35
let kAutoAnomalyToAdd = 5
let kAutoCleanStreakToRemove = 120
let kAutoAnomalyDecayEvery = 20
let kKeyCount = 128 // macOS 虚拟键码 0..127

enum FilterMode: Int {
    case quickAll = 0
    case advanced = 1
    case autoLearn = 2
}

// MARK: - 设置存取

struct Settings {
    static let d = UserDefaults.standard

    static var mode: FilterMode {
        get { FilterMode(rawValue: d.integer(forKey: "mode")) ?? .quickAll }
        set { d.set(newValue.rawValue, forKey: "mode") }
    }
    static var pressRate: Int {
        get { let r = d.integer(forKey: "pressRate"); return r == 0 ? 10 : min(max(r, 1), 50) }
        set { d.set(min(max(newValue, 1), 50), forKey: "pressRate") }
    }
    static var targetKeys: Set<Int> {
        get { Set((d.array(forKey: "targetKeys") as? [Int]) ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: "targetKeys") }
    }
    static var autoKeys: Set<Int> {
        get { Set((d.array(forKey: "autoKeys") as? [Int]) ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: "autoKeys") }
    }
}

// MARK: - 防抖核心

struct KeyInfo {
    var lastPressMs: Double = 0
    var isBlocked = false
}

struct AutoKeyStats {
    var rawLastMs: Double = 0
    var downStartedMs: Double = 0
    var hasRaw = false
    var isDown = false
    var anomalyHits = 0
    var cleanStreak = 0
}

final class FilterEngine {
    static let shared = FilterEngine()

    var mode: FilterMode = Settings.mode
    var minIntervalMs: Double = 1000.0 / Double(Settings.pressRate)
    var targetMask = [Bool](repeating: false, count: kKeyCount)
    var autoMask = [Bool](repeating: false, count: kKeyCount)
    var keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
    var autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
    var autoKeys = Settings.autoKeys
    var onAutoKeysChanged: (() -> Void)?

    private init() { syncMasks() }

    func syncMasks() {
        targetMask = [Bool](repeating: false, count: kKeyCount)
        autoMask = [Bool](repeating: false, count: kKeyCount)
        for k in Settings.targetKeys where k >= 0 && k < kKeyCount { targetMask[k] = true }
        for k in autoKeys where k >= 0 && k < kKeyCount { autoMask[k] = true }
    }

    func setPressRate(_ rate: Int) {
        Settings.pressRate = rate
        minIntervalMs = 1000.0 / Double(Settings.pressRate)
    }

    private func nowMs() -> Double { CACurrentMediaTime() * 1000 }

    /// 返回 true 表示该次按下应被拦截
    func applyDebounce(_ key: Int) -> Bool {
        guard key >= 0 && key < kKeyCount else { return false }
        let now = nowMs()
        if keyStates[key].isBlocked {
            if now - keyStates[key].lastPressMs < minIntervalMs { return true }
            keyStates[key].isBlocked = false
        }
        keyStates[key].lastPressMs = now
        keyStates[key].isBlocked = true
        return false
    }

    /// 只分析原始信号；autorepeat 由调用方过滤（macOS 事件自带标记）
    func analyzeRawKeyDown(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        let now = nowMs()
        var listChanged = false

        func tryAdd() {
            if !autoMask[key] && autoStats[key].anomalyHits >= kAutoAnomalyToAdd {
                autoKeys.insert(key)
                autoMask[key] = true
                keyStates[key].lastPressMs = now
                keyStates[key].isBlocked = true
                listChanged = true
            }
        }
        func tryRemove() {
            if autoMask[key] && autoStats[key].cleanStreak >= kAutoCleanStreakToRemove {
                autoKeys.remove(key)
                autoMask[key] = false
                autoStats[key] = AutoKeyStats()
                keyStates[key] = KeyInfo()
                listChanged = true
            }
        }

        if autoStats[key].isDown {
            let sinceLast = now - autoStats[key].rawLastMs
            if sinceLast > 500 {
                autoStats[key].isDown = false // KEYUP 丢失，视为新按下
            } else {
                autoStats[key].rawLastMs = now
                // 未抬起时的极短重复 down = 接触抖动（autorepeat 已在上游滤掉）
                if sinceLast < kLearnBounceMs {
                    autoStats[key].anomalyHits += 1
                    autoStats[key].cleanStreak = 0
                    tryAdd()
                }
                if listChanged { persistAutoKeys() }
                return
            }
        }

        let dt = autoStats[key].hasRaw ? (now - autoStats[key].rawLastMs) : 1_000_000
        autoStats[key].isDown = true
        autoStats[key].downStartedMs = now
        autoStats[key].rawLastMs = now
        autoStats[key].hasRaw = true

        if dt < kLearnBounceMs {
            autoStats[key].anomalyHits += 1
            autoStats[key].cleanStreak = 0
            tryAdd()
        } else {
            autoStats[key].cleanStreak += 1
            if autoStats[key].cleanStreak % kAutoAnomalyDecayEvery == 0 && autoStats[key].anomalyHits > 0 {
                autoStats[key].anomalyHits -= 1
            }
            tryRemove()
        }
        if listChanged { persistAutoKeys() }
    }

    func analyzeRawKeyUp(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        autoStats[key].isDown = false
        autoStats[key].rawLastMs = nowMs()
    }

    private func persistAutoKeys() {
        let keys = autoKeys
        DispatchQueue.main.async {
            Settings.autoKeys = keys
            self.onAutoKeysChanged?()
        }
    }
}

// MARK: - 事件挂钩（CGEventTap）

func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                      refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let engine = FilterEngine.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = AppDelegate.shared?.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

    if type == .keyUp {
        if engine.mode == .autoLearn { engine.analyzeRawKeyUp(key) }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    // 系统长按连发：不学习也不拦截（与 Windows 版语义一致）
    if isRepeat { return Unmanaged.passUnretained(event) }

    switch engine.mode {
    case .quickAll:
        if engine.applyDebounce(key) { return nil }
    case .advanced:
        if key < kKeyCount && engine.targetMask[key] && engine.applyDebounce(key) { return nil }
    case .autoLearn:
        engine.analyzeRawKeyDown(key)
        if key < kKeyCount && engine.autoMask[key] && engine.applyDebounce(key) { return nil }
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - 高级设置窗口

final class AdvancedWindowController: NSWindowController, NSWindowDelegate {
    private var useAutoPage: Bool
    private var tempKeys: Set<Int>
    private let radioManual = NSButton(radioButtonWithTitle: "手动选键（只防抖勾选的键）", target: nil, action: nil)
    private let radioAuto = NSButton(radioButtonWithTitle: "自动分析（抖动自动纳入，仍可点选取消）", target: nil, action: nil)
    private let hintLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private var keyButtons: [Int: NSButton] = [:]
    var onConfirm: ((_ useAuto: Bool, _ manualKeys: Set<Int>) -> Void)?

    // macOS 虚拟键码键盘布局（ANSI）
    private static let rows: [[(Int, String)]] = [
        [(53, "Esc"), (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"),
         (98, "F7"), (100, "F8"), (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12")],
        [(50, "`"), (18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"), (22, "6"), (26, "7"),
         (28, "8"), (25, "9"), (29, "0"), (27, "-"), (24, "="), (51, "Del")],
        [(48, "Tab"), (12, "Q"), (13, "W"), (14, "E"), (15, "R"), (17, "T"), (16, "Y"), (32, "U"),
         (34, "I"), (31, "O"), (35, "P"), (33, "["), (30, "]"), (42, "\\")],
        [(57, "Caps"), (0, "A"), (1, "S"), (2, "D"), (3, "F"), (5, "G"), (4, "H"), (38, "J"),
         (40, "K"), (37, "L"), (41, ";"), (39, "'"), (36, "Return")],
        [(56, "LShift"), (6, "Z"), (7, "X"), (8, "C"), (9, "V"), (11, "B"), (45, "N"), (46, "M"),
         (43, ","), (47, "."), (44, "/"), (60, "RShift")],
        [(59, "LCtrl"), (58, "LOpt"), (55, "LCmd"), (49, "Space"), (54, "RCmd"), (61, "ROpt"),
         (123, "←"), (126, "↑"), (125, "↓"), (124, "→")],
    ]

    init(useAuto: Bool, manualKeys: Set<Int>) {
        self.useAutoPage = useAuto
        self.tempKeys = manualKeys
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 520),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "高级设置"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
        refreshPage()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        radioManual.frame = NSRect(x: 24, y: 480, width: 300, height: 24)
        radioManual.target = self; radioManual.action = #selector(pickManual)
        radioAuto.frame = NSRect(x: 340, y: 480, width: 380, height: 24)
        radioAuto.target = self; radioAuto.action = #selector(pickAuto)
        content.addSubview(radioManual)
        content.addSubview(radioAuto)

        hintLabel.frame = NSRect(x: 24, y: 450, width: 930, height: 22)
        hintLabel.font = .systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: 24, y: 428, width: 930, height: 20)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        content.addSubview(hintLabel)
        content.addSubview(statusLabel)

        // 键盘按钮
        let keyW: CGFloat = 62, keyH: CGFloat = 44, gap: CGFloat = 6
        var y: CGFloat = 360
        for row in Self.rows {
            var x: CGFloat = 24
            for (code, name) in row {
                let b = NSButton(title: name, target: self, action: #selector(keyClicked(_:)))
                b.frame = NSRect(x: x, y: y, width: name.count > 2 ? keyW + 14 : keyW, height: keyH)
                b.tag = code
                b.setButtonType(.pushOnPushOff)
                b.bezelStyle = .regularSquare
                b.refusesFirstResponder = true // 不接受键盘焦点，仅鼠标
                content.addSubview(b)
                keyButtons[code] = b
                x += b.frame.width + gap
            }
            y -= keyH + gap
        }

        let clearBtn = NSButton(title: "清空全部", target: self, action: #selector(clearAll))
        clearBtn.frame = NSRect(x: 24, y: 16, width: 110, height: 34)
        clearBtn.refusesFirstResponder = true
        content.addSubview(clearBtn)

        let okBtn = NSButton(title: "确定", target: self, action: #selector(confirm))
        okBtn.frame = NSRect(x: 860, y: 16, width: 96, height: 34)
        okBtn.refusesFirstResponder = true
        content.addSubview(okBtn)
    }

    private func currentKeys() -> Set<Int> {
        useAutoPage ? FilterEngine.shared.autoKeys : tempKeys
    }

    private func refreshPage() {
        radioManual.state = useAutoPage ? .off : .on
        radioAuto.state = useAutoPage ? .on : .off
        hintLabel.stringValue = useAutoPage
            ? "自动分析：只把极短接触抖动（约 ≤35ms）计入，正常快打不会纳入。可用鼠标点选/取消任意键。"
            : "手动选键：用鼠标点选要防抖的键，再次点击可取消。仅鼠标操作。"
        let keys = currentKeys()
        statusLabel.stringValue = useAutoPage
            ? "当前 \(keys.count) 个按键 · 可点选增减 · 仅 ≤\(Int(kLearnBounceMs))ms 抖动计入 · ≥\(kAutoAnomalyToAdd) 次纳入"
            : "已选择 \(keys.count) 个按键 · 点确定后启用高级模式"
        for (code, btn) in keyButtons {
            btn.state = keys.contains(code) ? .on : .off
        }
    }

    @objc private func pickManual() { useAutoPage = false; refreshPage() }
    @objc private func pickAuto() { useAutoPage = true; refreshPage() }

    @objc private func keyClicked(_ sender: NSButton) {
        let code = sender.tag
        let engine = FilterEngine.shared
        if useAutoPage {
            if engine.autoKeys.contains(code) {
                engine.autoKeys.remove(code)
                if code < kKeyCount {
                    engine.autoMask[code] = false
                    engine.autoStats[code] = AutoKeyStats()
                    engine.keyStates[code] = KeyInfo()
                }
            } else {
                engine.autoKeys.insert(code)
                if code < kKeyCount { engine.autoMask[code] = true }
            }
            Settings.autoKeys = engine.autoKeys
        } else {
            if tempKeys.contains(code) { tempKeys.remove(code) } else { tempKeys.insert(code) }
        }
        refreshPage()
    }

    @objc private func clearAll() {
        if useAutoPage {
            let engine = FilterEngine.shared
            engine.autoKeys.removeAll()
            engine.autoMask = [Bool](repeating: false, count: kKeyCount)
            engine.autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
            engine.keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
            Settings.autoKeys = []
        } else {
            tempKeys.removeAll()
        }
        refreshPage()
    }

    @objc private func confirm() {
        onConfirm?(useAutoPage, tempKeys)
        window?.close()
    }

    // 无「取消」：关窗即确认当前选择
    func windowWillClose(_ notification: Notification) {
        onConfirm?(useAutoPage, tempKeys)
    }
}

// MARK: - 应用与托盘（菜单栏）

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem!
    var eventTap: CFMachPort?
    private var advancedWC: AdvancedWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        FilterEngine.shared.onAutoKeysChanged = { [weak self] in self?.rebuildMenu() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨"
        rebuildMenu()

        installTap()
    }

    private func installTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback, userInfo: nil
        ) else {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "请到 系统设置 → 隐私与安全性 → 辅助功能 中允许本应用，然后重新启动。"
            alert.runModal()
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func statusText() -> String {
        switch FilterEngine.shared.mode {
        case .quickAll: return "全盘"
        case .advanced: return "手动(\(Settings.targetKeys.count))"
        case .autoLearn: return "自动(\(FilterEngine.shared.autoKeys.count))"
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let engine = FilterEngine.shared

        menu.addItem(withTitle: "键盘防抖 · \(statusText()) · \(Settings.pressRate)/秒", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

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
        for (rate, label) in [(1, "1次/秒 (非常强防抖)"), (5, "5次/秒 (中等防抖)"),
                              (10, "10次/秒 (默认防抖)"), (20, "20次/秒 (轻微防抖)")] {
            let item = NSMenuItem(title: label, action: #selector(setRate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = rate
            item.state = Settings.pressRate == rate ? .on : .off
            rateMenu.addItem(item)
        }
        let rateItem = NSMenuItem(title: "防抖频率", action: nil, keyEquivalent: "")
        menu.addItem(rateItem)
        menu.setSubmenu(rateMenu, for: rateItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func selectQuick() {
        FilterEngine.shared.mode = .quickAll
        Settings.mode = .quickAll
        rebuildMenu()
        let alert = NSAlert()
        alert.messageText = "已切换到全盘模式"
        alert.informativeText = "将对全部按键按当前频率防抖。\n若只需对个别键防抖，或想用自动分析，请打开「高级设置」。"
        alert.runModal()
    }

    @objc private func openAdvanced() {
        let engine = FilterEngine.shared
        let wc = AdvancedWindowController(useAuto: engine.mode == .autoLearn,
                                          manualKeys: Settings.targetKeys)
        wc.onConfirm = { [weak self] useAuto, manualKeys in
            let engine = FilterEngine.shared
            if !useAuto { Settings.targetKeys = manualKeys }
            engine.mode = useAuto ? .autoLearn : .advanced
            Settings.mode = engine.mode
            engine.syncMasks()
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
}

// MARK: - 入口

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 仅菜单栏，无 Dock 图标
let delegate = AppDelegate()
app.delegate = delegate
app.run()
