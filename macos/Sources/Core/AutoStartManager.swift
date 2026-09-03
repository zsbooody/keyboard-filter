import Darwin
import Foundation

enum AutoStartManager {
    static let launchLabel = "com.keyboardfilter.mac.app"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(launchLabel).plist")
    }

    static func resolvedExecutablePath() -> String {
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

        return "/usr/local/bin/KeyboardFilter"
    }

    static func apply(enabled: Bool) {
        let plist = plistURL
        if !enabled {
            unload(plistURL: plist)
            if FileManager.default.fileExists(atPath: plist.path) {
                try? FileManager.default.removeItem(at: plist)
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
            try FileManager.default.createDirectory(
                at: plist.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: plistContent,
                format: .xml,
                options: 0
            )
            try data.write(to: plist, options: .atomic)
            load(plistURL: plist)
        } catch {
            NSLog("创建启动项失败: \(error.localizedDescription)")
        }
    }

    private static func load(plistURL: URL) {
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

    private static func unload(plistURL: URL) {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let service = "\(domain)/\(launchLabel)"
        _ = runLaunchctl(["bootout", service])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            _ = runLaunchctl(["unload", plistURL.path])
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
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
}
