import Cocoa
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusBar = StatusBarController()
    private var instanceLock: FileHandle?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireSingleInstance() {
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
                AccessibilityGuideWindowController.showIfNeeded()
            }
        } else {
            AccessibilityGuideWindowController.showIfNeeded()
        }
        statusBar.checkPermissionAndTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SettingsStore.shared.persistNow()
        FilterEngine.shared.removeTap()
    }

    private func acquireSingleInstance() -> Bool {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/KeyboardFilter")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lockURL = dir.appendingPathComponent("instance.lock")
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: lockURL) else { return true }
        let fd = handle.fileDescriptor
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            try? handle.close()
            return false
        }
        instanceLock = handle
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
