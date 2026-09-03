import Foundation

enum FilterMode: Int {
    case quickAll = 0
    case advanced = 1
    case autoLearn = 2
}

/// 持久化：内存为准，写入合并延迟，对齐 Windows 的 deferred registry save。
final class SettingsStore {
    static let shared = SettingsStore()

    static let suiteName = "com.keyboardfilter.mac"
    private static let saveDelay: TimeInterval = 0.35

    var mode: FilterMode = .quickAll
    var pressRate: Int = 10
    var targetKeys: Set<Int> = []
    var autoKeys: Set<Int> = []
    var autoStart: Bool = false

    private let defaults: UserDefaults
    private var saveWork: DispatchWorkItem?
    private var loaded = false

    private init() {
        defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
    }

    func load() {
        let rawMode = defaults.integer(forKey: "mode")
        mode = FilterMode(rawValue: rawMode) ?? .quickAll
        let rate = defaults.integer(forKey: "pressRate")
        pressRate = rate == 0 ? 10 : clampPressRate(rate)
        targetKeys = Set(defaults.array(forKey: "targetKeys") as? [Int] ?? [])
        autoKeys = Set(defaults.array(forKey: "autoKeys") as? [Int] ?? [])
        autoStart = defaults.bool(forKey: "autoStart")
        loaded = true
    }

    func clampPressRate(_ rate: Int) -> Int {
        min(max(rate, 1), 50)
    }

    func requestDeferredSave() {
        guard loaded else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistNow()
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDelay, execute: work)
    }

    func persistNow() {
        saveWork?.cancel()
        saveWork = nil
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(pressRate, forKey: "pressRate")
        defaults.set(Array(targetKeys).sorted(), forKey: "targetKeys")
        defaults.set(Array(autoKeys).sorted(), forKey: "autoKeys")
        defaults.set(autoStart, forKey: "autoStart")
    }
}
