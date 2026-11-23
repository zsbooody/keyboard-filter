import Darwin
import Foundation

enum AutoStartManager {
    static let launchLabel = "com.keyboardfilter.mac.app"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(launchLabel).plist")
    }

    private static func resolvedExecutablePath() -> String? {
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

        return nil
    }

    private enum RegistrationError: LocalizedError {
        case missingExecutable
        case commandFailed(String, Int32)

        var errorDescription: String? {
            switch self {
            case .missingExecutable: return "找不到可执行文件。"
            case .commandFailed(let command, let status):
                return "launchctl \(command) 失败（状态 \(status)）。"
            }
        }
    }

    static func apply(enabled: Bool) throws {
        try apply(enabled: enabled, plist: plistURL, domain: "gui/\(getuid())",
                  executablePath: resolvedExecutablePath(), run: runLaunchctl)
    }

    static func apply(enabled: Bool, plist: URL, domain: String, executablePath: String?,
                      run: ([String]) -> Int32) throws {
        let files = FileManager.default
        let service = "\(domain)/\(launchLabel)"
        let domainStatus = run(["print", domain])
        guard domainStatus == 0 else {
            throw RegistrationError.commandFailed("print", domainStatus)
        }
        let wasLoaded = run(["print", service]) == 0
        let previous = files.fileExists(atPath: plist.path) ? try Data(contentsOf: plist) : nil

        if !enabled {
            if wasLoaded {
                let status = run(["bootout", service])
                guard status == 0 else { throw RegistrationError.commandFailed("bootout", status) }
            }
            if previous != nil {
                do {
                    try files.removeItem(at: plist)
                } catch {
                    if wasLoaded { _ = run(["bootstrap", domain, plist.path]) }
                    throw error
                }
            }
            return
        }

        guard let executablePath = executablePath else { throw RegistrationError.missingExecutable }
        let content: [String: Any] = [
            "Label": launchLabel,
            "ProgramArguments": [executablePath, "--launched-at-login"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: content, format: .xml, options: 0)
        if wasLoaded && previous == data { return }

        try files.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        if wasLoaded {
            let status = run(["bootout", service])
            guard status == 0 else { throw RegistrationError.commandFailed("bootout", status) }
        }

        var wrotePlist = false
        do {
            try data.write(to: plist, options: .atomic)
            wrotePlist = true
            let status = run(["bootstrap", domain, plist.path])
            guard status == 0 else { throw RegistrationError.commandFailed("bootstrap", status) }
        } catch {
            if wrotePlist {
                if let previous = previous {
                    try previous.write(to: plist, options: .atomic)
                } else {
                    try files.removeItem(at: plist)
                }
            }
            if wasLoaded && previous != nil { _ = run(["bootstrap", domain, plist.path]) }
            throw error
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
