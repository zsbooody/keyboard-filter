import Cocoa
import Combine
import Foundation

@available(macOS 11.0, *)
class KeyboardMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false
    @Published var keyPressCount = 0
    @Published var filteredCount = 0
    @Published var lastKeyPressTime: Date?
    /// 用户点了停止后不再自动拉起，直到再次点开始或重新授权。
    private(set) var userPaused = false

    weak var settings: SettingsManager?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var lastKeyTimes: [Int: TimeInterval] = [:]
    private var keyPressTimestamps: [TimeInterval] = []
    private var heldKeys: Set<Int> = []
    // 计数批量刷新：避免每键一次主队列调度+SwiftUI 重渲染，拖慢事件回调（防抖延迟判定的主因）
    private var keyPressCountInternal = 0
    private var filteredCountInternal = 0
    private var lastKeyPressWall: Date?
    private var statsFlushScheduled = false

    init(settings: SettingsManager? = nil) {
        self.settings = settings
        refreshAccessibilityPermission()
    }

    deinit {
        stopMonitoring()
    }

    @discardableResult
    func refreshAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options)

        if Thread.isMainThread {
            hasAccessibilityPermission = hasPermission
        } else {
            DispatchQueue.main.async {
                self.hasAccessibilityPermission = hasPermission
            }
        }
        return hasPermission
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            _ = self.refreshAccessibilityPermission()
        }
    }

    func startMonitoring() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.startMonitoring() }
            return
        }

        userPaused = false
        guard !isMonitoring, eventTap == nil else { return }
        guard refreshAccessibilityPermission() else { return }

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isMonitoring = true
    }

    func stopMonitoring() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.stopMonitoring() }
            return
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        userPaused = true

        stateLock.lock()
        lastKeyTimes.removeAll()
        keyPressTimestamps.removeAll()
        heldKeys.removeAll()
        stateLock.unlock()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("[KeyboardFilter] tap 被系统禁用(type=%@)，重新使能", String(describing: type))
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let isKeyDown = (type == .keyDown)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        // 用事件自身时间戳算间隔（ns，同一时钟域）：即使主线程繁忙导致回调延迟处理，
        // 真实按键间隔也不会被算大——历史失手主因就是墙钟在回调时刻取样。
        let now = Double(event.timestamp) / 1_000_000_000

        if isKeyDown && !isRepeat {
            stateLock.lock()
            keyPressCountInternal += 1
            lastKeyPressWall = Date()
            let needFlush = !statsFlushScheduled
            statsFlushScheduled = true
            stateLock.unlock()
            if needFlush {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.flushStatistics()
                }
            }
        }

        guard let settings = settings, settings.enableFiltering else {
            trackHold(keyCode, isKeyDown: isKeyDown)
            return Unmanaged.passUnretained(event)
        }

        let debounceDelay = settings.debounceDelay
        let maxRate = settings.maxKeyPressesPerSecond
        let blocked = settings.filterKeys.contains(keyCode)

        if blocked {
            if !isKeyDown && releaseHeld(keyCode) {
                return Unmanaged.passUnretained(event)
            }
            recordFiltered()
            return nil
        }

        if !isKeyDown {
            _ = releaseHeld(keyCode)
            return Unmanaged.passUnretained(event)
        }

        // 长按产生的自动重复不参与防抖，否则正常按住也会被吃掉
        if isRepeat {
            markHeld(keyCode)
            return Unmanaged.passUnretained(event)
        }

        stateLock.lock()
        if let lastTime = lastKeyTimes[keyCode] {
            let intervalMs = (now - lastTime) * 1000
            if intervalMs < Double(debounceDelay) {
                stateLock.unlock()
                NSLog("[KeyboardFilter] 吞键 kc=%d 间隔=%.1fms(<%dms)", keyCode, intervalMs, debounceDelay)
                recordFiltered()
                return nil
            }
        }

        if maxRate > 0 {
            let cutoff = now - 1.0
            keyPressTimestamps.removeAll { $0 <= cutoff }
            if keyPressTimestamps.count >= maxRate {
                stateLock.unlock()
                recordFiltered()
                return nil
            }
            keyPressTimestamps.append(now)
        }

        lastKeyTimes[keyCode] = now
        let stale = now - 5
        lastKeyTimes = lastKeyTimes.filter { $0.value > stale }
        heldKeys.insert(keyCode)
        stateLock.unlock()

        return Unmanaged.passUnretained(event)
    }

    private func trackHold(_ keyCode: Int, isKeyDown: Bool) {
        stateLock.lock()
        if isKeyDown {
            heldKeys.insert(keyCode)
        } else {
            heldKeys.remove(keyCode)
        }
        stateLock.unlock()
    }

    private func markHeld(_ keyCode: Int) {
        stateLock.lock()
        heldKeys.insert(keyCode)
        stateLock.unlock()
    }

    @discardableResult
    private func releaseHeld(_ keyCode: Int) -> Bool {
        stateLock.lock()
        let wasHeld = heldKeys.remove(keyCode) != nil
        stateLock.unlock()
        return wasHeld
    }

    private func recordFiltered() {
        stateLock.lock()
        filteredCountInternal += 1
        let needFlush = !statsFlushScheduled
        statsFlushScheduled = true
        stateLock.unlock()
        if needFlush {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.flushStatistics()
            }
        }
    }

    /// 把 tap 回调里累计的计数每 0.5s 批量刷到 @Published，平时不占主线程。
    private func flushStatistics() {
        stateLock.lock()
        let kp = keyPressCountInternal
        let fc = filteredCountInternal
        let wall = lastKeyPressWall
        statsFlushScheduled = false
        stateLock.unlock()
        keyPressCount = kp
        filteredCount = fc
        lastKeyPressTime = wall
    }

    func clearStatistics() {
        DispatchQueue.main.async {
            self.keyPressCount = 0
            self.filteredCount = 0
            self.lastKeyPressTime = nil
        }
        stateLock.lock()
        keyPressTimestamps.removeAll()
        lastKeyTimes.removeAll()
        keyPressCountInternal = 0
        filteredCountInternal = 0
        lastKeyPressWall = nil
        statsFlushScheduled = false
        stateLock.unlock()
    }
}
