import Foundation
import Combine

@available(macOS 11.0, *)
class SettingsManager: ObservableObject {
    @Published var debounceDelay: Int {
        didSet {
            persist("debounceDelay", value: debounceDelay)
        }
    }

    @Published var autoStart: Bool {
        didSet {
            persist("autoStart", value: autoStart)
            updateLaunchAtStartup()
        }
    }

    @Published var filterKeys: [Int] {
        didSet {
            persist("filterKeys", value: filterKeys)
        }
    }

    @Published var enableFiltering: Bool {
        didSet {
            persist("enableFiltering", value: enableFiltering)
        }
    }

    @Published var maxKeyPressesPerSecond: Int {
        didSet {
            persist("maxKeyPressesPerSecond", value: maxKeyPressesPerSecond)
        }
    }

    private var defaults: UserDefaults
    private var persistEnabled = false
    private let suiteName = "com.keyboardfilter.mac"
    private let launchLabel = "com.keyboardfilter.mac.app"

    init() {
        defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard

        debounceDelay = defaults.object(forKey: "debounceDelay") as? Int ?? 50
        autoStart = defaults.object(forKey: "autoStart") as? Bool ?? false
        filterKeys = defaults.object(forKey: "filterKeys") as? [Int] ?? []
        enableFiltering = defaults.object(forKey: "enableFiltering") as? Bool ?? true
        maxKeyPressesPerSecond = defaults.object(forKey: "maxKeyPressesPerSecond") as? Int ?? 30

        persistEnabled = true

        if defaults.object(forKey: "firstRun") == nil {
            setDefaultSettings()
            defaults.set(true, forKey: "firstRun")
        }

        updateLaunchAtStartup()
    }

    private func persist<T>(_ key: String, value: T) {
        guard persistEnabled else { return }
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    private func setDefaultSettings() {
        debounceDelay = 50
        autoStart = false
        filterKeys = []
        enableFiltering = true
        maxKeyPressesPerSecond = 30
    }

    func resolvedExecutablePath() -> String {
        if let exec = Bundle.main.executableURL?.path,
           FileManager.default.isExecutableFile(atPath: exec) {
            return exec
        }

        if let first = ProcessInfo.processInfo.arguments.first, !first.isEmpty {
            let url: URL
            if first.hasPrefix("/") {
                url = URL(fileURLWithPath: first)
            } else {
                url = URL(
                    fileURLWithPath: first,
                    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                )
            }
            let path = url.standardizedFileURL.path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/usr/local/bin/KeyboardFilterMac"
    }

    func updateLaunchAtStartup() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let agentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistURL = agentsDir.appendingPathComponent("\(launchLabel).plist")

        if !autoStart {
            unloadLaunchAgent(plistURL: plistURL)
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try? FileManager.default.removeItem(at: plistURL)
            }
            return
        }

        let executablePath = resolvedExecutablePath()
        let plistContent: [String: Any] = [
            "Label": launchLabel,
            "ProgramArguments": [executablePath, "--launched-at-login"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        do {
            try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plistContent,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)
            loadLaunchAgent(plistURL: plistURL)
        } catch {
            NSLog("创建启动项失败: \(error.localizedDescription)")
        }
    }

    private func loadLaunchAgent(plistURL: URL) {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let service = "\(domain)/\(launchLabel)"
        _ = runLaunchctl(["bootout", service])
        let bootstrap = runLaunchctl(["bootstrap", domain, plistURL.path])
        if bootstrap != 0 {
            _ = runLaunchctl(["unload", plistURL.path])
            _ = runLaunchctl(["load", "-w", plistURL.path])
        }
    }

    private func unloadLaunchAgent(plistURL: URL) {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let service = "\(domain)/\(launchLabel)"
        _ = runLaunchctl(["bootout", service])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            _ = runLaunchctl(["unload", plistURL.path])
        }
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    func resetToDefaults() {
        setDefaultSettings()
    }
}
