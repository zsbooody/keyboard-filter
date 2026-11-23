import Cocoa
import Combine
import CoreGraphics
import Foundation
import IOKit.hidsystem
import QuartzCore

let kLearnBounceMs: Double = 35
let kAutoAnomalyToAdd = 5
let kAutoCleanStreakToRemove = 120
let kAutoAnomalyDecayEvery = 20
let kKeyCount = 128
let kRepeatIgnoreMs: Double = 180
let kKeyUpLostMs: Double = 500

struct KeyInfo {
    var lastPressMs: Double = 0
    var isBlocked = false
}

private enum KeySequence: Equatable {
    case idle
    case forwarded(protected: Bool)
    case suppressed
    case suppressedModifier

    var wasForwarded: Bool {
        if case .forwarded = self { return true }
        return false
    }

    var wasSuppressed: Bool { self == .suppressed || self == .suppressedModifier }

    var blocksNonRepeat: Bool {
        switch self {
        case .forwarded(let protected): return protected
        case .suppressed, .suppressedModifier: return true
        case .idle: return false
        }
    }
}

private struct ModifierPair {
    let key: Int
    let otherKey: Int
    let flag: CGEventFlags
    let side: CGEventFlags
    let otherSide: CGEventFlags

    static let leftShift = Self(key: 56, otherKey: 60, flag: .maskShift,
                                side: .init(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK)),
                                otherSide: .init(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK)))
    static let leftControl = Self(key: 59, otherKey: 62, flag: .maskControl,
                                  side: .init(rawValue: UInt64(NX_DEVICELCTLKEYMASK)),
                                  otherSide: .init(rawValue: UInt64(NX_DEVICERCTLKEYMASK)))
    static let leftOption = Self(key: 58, otherKey: 61, flag: .maskAlternate,
                                 side: .init(rawValue: UInt64(NX_DEVICELALTKEYMASK)),
                                 otherSide: .init(rawValue: UInt64(NX_DEVICERALTKEYMASK)))
    static let leftCommand = Self(key: 55, otherKey: 54, flag: .maskCommand,
                                  side: .init(rawValue: UInt64(NX_DEVICELCMDKEYMASK)),
                                  otherSide: .init(rawValue: UInt64(NX_DEVICERCMDKEYMASK)))

    static let leftSides = [leftShift, leftControl, leftOption, leftCommand]

    var reversed: Self {
        Self(key: otherKey, otherKey: key, flag: flag, side: otherSide, otherSide: side)
    }

    static func forKey(_ key: Int) -> Self? {
        switch key {
        case 56: return leftShift
        case 60: return leftShift.reversed
        case 59: return leftControl
        case 62: return leftControl.reversed
        case 58: return leftOption
        case 61: return leftOption.reversed
        case 55: return leftCommand
        case 54: return leftCommand.reversed
        default: return nil
        }
    }
}

struct AutoKeyStats {
    var rawLastMs: Double = 0
    var downStartedMs: Double = 0
    var hasRaw = false
    var isDown = false
    var anomalyHits = 0
    var cleanStreak = 0
}

/// 每键输入状态与防抖计时保存在固定大小的数组中。
final class FilterEngine: ObservableObject {
    static let shared = FilterEngine()

    var mode: FilterMode = .quickAll
    var minIntervalMs: Double = 100
    var targetMask = [Bool](repeating: false, count: kKeyCount)
    var autoMask = [Bool](repeating: false, count: kKeyCount)
    var keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
    var autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
    var autoKeys = Set<Int>()
    var eventTap: CFMachPort?
    var onAutoKeysChanged: (() -> Void)?

    /// SwiftUI 观察自动名单变化。
    @Published private(set) var autoRevision: UInt64 = 0

    private var keySequences = [KeySequence](repeating: .idle, count: kKeyCount)
    private var suppressedModifierCount = 0
    private var runLoopSource: CFRunLoopSource?

    private let clock: () -> Double

    init(clock: @escaping () -> Double = { CACurrentMediaTime() * 1000 }) {
        self.clock = clock
    }

    func loadFromSettings(_ store: SettingsStore = .shared) {
        mode = store.mode
        setPressRate(store.pressRate, persist: false)
        autoKeys = store.autoKeys
        syncMasks(targetKeys: store.targetKeys)
    }

    func syncMasks(targetKeys: Set<Int> = SettingsStore.shared.targetKeys) {
        targetMask = [Bool](repeating: false, count: kKeyCount)
        autoMask = [Bool](repeating: false, count: kKeyCount)
        for key in targetKeys where key >= 0 && key < kKeyCount {
            targetMask[key] = true
        }
        for key in autoKeys where key >= 0 && key < kKeyCount {
            autoMask[key] = true
        }
    }

    func setPressRate(_ rate: Int, persist: Bool = true) {
        let clamped = SettingsStore.shared.clampPressRate(rate)
        SettingsStore.shared.pressRate = clamped
        minIntervalMs = 1000.0 / Double(clamped)
        if persist {
            SettingsStore.shared.requestDeferredSave()
        }
    }

    func setMode(_ newMode: FilterMode) {
        mode = newMode
        SettingsStore.shared.mode = newMode
        SettingsStore.shared.requestDeferredSave()
    }

    private func nowMs() -> Double {
        clock()
    }

    /// 返回 true 表示该次按下应被拦截。
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
            if sinceLast > kKeyUpLostMs {
                autoStats[key].isDown = false
            } else {
                let sinceDown = now - autoStats[key].downStartedMs
                autoStats[key].rawLastMs = now
                if sinceDown >= kRepeatIgnoreMs {
                    return
                }
                if sinceLast <= kLearnBounceMs {
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

        if dt <= kLearnBounceMs {
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

    func toggleAutoKey(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        if autoKeys.contains(key) {
            autoKeys.remove(key)
            autoMask[key] = false
            autoStats[key] = AutoKeyStats()
            keyStates[key] = KeyInfo()
        } else {
            autoKeys.insert(key)
            autoMask[key] = true
        }
        persistAutoKeys()
    }

    func clearAutoKeys() {
        autoKeys.removeAll()
        autoMask = [Bool](repeating: false, count: kKeyCount)
        autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
        keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
        persistAutoKeys()
    }

    private func persistAutoKeys() {
        SettingsStore.shared.autoKeys = autoKeys
        SettingsStore.shared.requestDeferredSave()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoRevision &+= 1
            self.onAutoKeysChanged?()
        }
    }

    func statusText() -> String {
        switch mode {
        case .quickAll:
            return "全盘"
        case .advanced:
            return "手动(\(SettingsStore.shared.targetKeys.count))"
        case .autoLearn:
            return "自动(\(autoKeys.count))"
        }
    }

    func shouldBlockKeyDown(key: Int) -> Bool {
        guard key >= 0 && key < kKeyCount else { return false }
        switch mode {
        case .quickAll:
            return applyDebounce(key)
        case .advanced:
            return targetMask[key] && applyDebounce(key)
        case .autoLearn:
            analyzeRawKeyDown(key)
            return autoMask[key] && applyDebounce(key)
        }
    }

    @discardableResult
    func installTap() -> Bool {
        removeTap()
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func reenableTap() {
        if let tap = eventTap {
            // The system can lose transitions while the tap is disabled.
            resetInputState()
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func removeTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        resetInputState()
    }

    private func resetInputState() {
        for key in keySequences.indices {
            keySequences[key] = .idle
            keyStates[key] = KeyInfo()
            autoStats[key].isDown = false
            autoStats[key].hasRaw = false
        }
        suppressedModifierCount = 0
    }

    private func modifierIsDown(key: Int, flags: CGEventFlags) -> Bool? {
        if key == 63 { return flags.contains(.maskSecondaryFn) }
        guard let pair = ModifierPair.forKey(key) else { return nil }
        if !flags.contains(pair.flag) { return false }
        if !flags.intersection([pair.side, pair.otherSide]).isEmpty {
            return flags.contains(pair.side)
        }
        // A side-less event toggles this key when its peer explains the aggregate bit.
        if keySequences[pair.otherKey] != .idle {
            return keySequences[key] == .idle
        }
        return keySequences[key] == .idle ? true : nil
    }

    private func forwardedFlags(_ flags: CGEventFlags) -> CGEventFlags {
        guard suppressedModifierCount > 0 else { return flags }
        var result = flags
        for pair in ModifierPair.leftSides {
            let blocked = keySequences[pair.key] == .suppressedModifier
            let otherBlocked = keySequences[pair.otherKey] == .suppressedModifier
            guard blocked || otherBlocked else { continue }
            if blocked { result.remove(pair.side) }
            if otherBlocked { result.remove(pair.otherSide) }
            let knownForwarded = keySequences[pair.key].wasForwarded ||
                keySequences[pair.otherKey].wasForwarded
            if !knownForwarded && result.intersection([pair.side, pair.otherSide]).isEmpty {
                result.remove(pair.flag)
            }
        }
        if keySequences[63] == .suppressedModifier { result.remove(.maskSecondaryFn) }
        return result
    }

    func processKeyEvent(_ type: CGEventType, event: CGEvent) -> Bool {
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if key >= 0 && key < kKeyCount {
            switch type {
            case .flagsChanged:
                if let down = modifierIsDown(key: key, flags: event.flags) {
                    if down {
                        if keySequences[key] == .idle {
                            let blocked = shouldBlockKeyDown(key: key)
                            keySequences[key] = blocked ? .suppressedModifier : .forwarded(protected: filtersKey(key))
                            if blocked { suppressedModifierCount += 1 }
                        }
                        if keySequences[key].wasSuppressed { return false }
                    } else if releaseKey(key) {
                        return false
                    }
                }
            case .keyDown:
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                    if keySequences[key].wasSuppressed { return false }
                } else if keySequences[key] == .idle {
                    let block = shouldBlockKeyDown(key: key)
                    keySequences[key] = block ? .suppressed : .forwarded(protected: filtersKey(key))
                    if block { return false }
                } else {
                    if mode == .autoLearn { analyzeRawKeyDown(key) }
                    if keySequences[key].blocksNonRepeat { return false }
                }
            case .keyUp:
                if releaseKey(key) { return false }
            default:
                break
            }
        }
        if suppressedModifierCount > 0 { event.flags = forwardedFlags(event.flags) }
        return true
    }

    private func filtersKey(_ key: Int) -> Bool {
        switch mode {
        case .quickAll: return true
        case .advanced: return targetMask[key]
        case .autoLearn: return autoMask[key]
        }
    }

    private func releaseKey(_ key: Int) -> Bool {
        if mode == .autoLearn || autoStats[key].isDown { analyzeRawKeyUp(key) }
        let sequence = keySequences[key]
        if sequence == .suppressedModifier { suppressedModifierCount -= 1 }
        keySequences[key] = .idle
        return sequence.wasSuppressed
    }
}

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let engine = FilterEngine.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        engine.reenableTap()
        return Unmanaged.passUnretained(event)
    }
    return engine.processKeyEvent(type, event: event) ? Unmanaged.passUnretained(event) : nil
}
