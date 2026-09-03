import SwiftUI
import Cocoa
import Foundation
import Combine

@available(macOS 11.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let settings = SettingsManager()
    lazy var keyboardMonitor = KeyboardMonitor(settings: settings)
    var settingsWindow: NSWindow?

    private var launchedAtLogin: Bool {
        ProcessInfo.processInfo.arguments.contains("--launched-at-login")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyboardMonitor.settings = settings
        setupStatusItem()

        let hasPermission = keyboardMonitor.refreshAccessibilityPermission()
        if hasPermission {
            keyboardMonitor.startMonitoring()
        }

        if launchedAtLogin {
            DispatchQueue.main.async {
                NSApp.windows.forEach { $0.orderOut(nil) }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openSettings(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stopMonitoring()
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "键盘防抖工具")
            image?.isTemplate = true
            button.image = image
            button.image?.size = NSSize(width: 18, height: 18)
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let statusTitle = NSMenuItem(
            title: menuStatusTitle(),
            action: nil,
            keyEquivalent: ""
        )
        statusTitle.isEnabled = false
        menu.addItem(statusTitle)
        menu.addItem(NSMenuItem.separator())

        let monitoringItem = NSMenuItem(
            title: keyboardMonitor.isMonitoring ? "停止监听" : "开始监听",
            action: #selector(toggleMonitoring(_:)),
            keyEquivalent: "m"
        )
        monitoringItem.target = self
        menu.addItem(monitoringItem)

        let settingsItem = NSMenuItem(
            title: "打开设置",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func menuStatusTitle() -> String {
        if !keyboardMonitor.hasAccessibilityPermission {
            return "键盘防抖：无权限"
        }
        if keyboardMonitor.isMonitoring && settings.enableFiltering {
            return "键盘防抖：运行中"
        }
        if keyboardMonitor.isMonitoring {
            return "键盘防抖：已暂停过滤"
        }
        return "键盘防抖：已停止"
    }

    @objc func toggleMonitoring(_ sender: AnyObject?) {
        if keyboardMonitor.isMonitoring {
            keyboardMonitor.stopMonitoring()
        } else if keyboardMonitor.refreshAccessibilityPermission() {
            keyboardMonitor.startMonitoring()
        } else {
            keyboardMonitor.requestAccessibilityPermission()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        rebuildMenu()
    }

    @objc func openSettings(_ sender: AnyObject?) {
        if let mainWindow = NSApplication.shared.windows.first(where: {
            $0.title == "键盘防抖工具" || $0.title.hasPrefix("键盘防抖")
        }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            createSettingsWindow()
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        rebuildMenu()
    }

    @objc func quitApp(_ sender: AnyObject?) {
        NSApplication.shared.terminate(nil)
    }

    func createSettingsWindow() {
        let settingsView = SettingsView()
            .environmentObject(settings)
            .environmentObject(keyboardMonitor)
            .frame(minWidth: 500, idealWidth: 500, maxWidth: 600,
                   minHeight: 550, idealHeight: 550, maxHeight: 700)

        let hostingController = NSHostingController(rootView: settingsView)
        settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow?.title = "键盘防抖工具"
        settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        settingsWindow?.setFrameAutosaveName("KeyboardFilterSettings")
        settingsWindow?.isReleasedWhenClosed = false
        settingsWindow?.delegate = self
        settingsWindow?.center()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}

@main
@available(macOS 11.0, *)
struct KeyboardFilterMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("键盘防抖工具") {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.keyboardMonitor)
                .frame(minWidth: 500, idealWidth: 500, maxWidth: 600,
                       minHeight: 550, idealHeight: 550, maxHeight: 700)
                .onAppear {
                    appDelegate.rebuildMenu()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
