import Cocoa
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusBar = StatusBarController()
    private var instanceLock: FileHandle?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingleInstance() {
            // Registering a RunAtLoad LaunchAgent can start it immediately.
            if ProcessInfo.processInfo.arguments.contains("--launched-at-login") {
                NSApp.terminate(nil)
                return
            }
            let alert = NSAlert()
            alert.messageText = "键盘防抖工具已在运行中"
            alert.informativeText = "请检查菜单栏图标。"
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        SettingsStore.shared.load()
        FilterEngine.shared.loadFromSettings()
        FilterEngine.shared.onAutoKeysChanged = { [weak self] in
            self?.statusBar.rebuildMenu()
        }

        statusBar.install()

        if AccessibilityMonitor.isTrusted() {
            if !FilterEngine.shared.installTap() {
                AccessibilityGuideWindowController.showIfNeeded(mode: .tapRetry)
            }
        } else {
            AccessibilityGuideWindowController.showIfNeeded(mode: .needPermission)
        }
        statusBar.checkPermissionAndTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard instanceLock != nil else { return }
        SettingsStore.shared.persistNow()
        FilterEngine.shared.removeTap()
    }

    private func acquireSingleInstance() -> Bool {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeyboardFilter")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lockURL = dir.appendingPathComponent("instance.lock")
        let fd = open(lockURL.path, O_WRONLY | O_CREAT | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return false }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        instanceLock = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
