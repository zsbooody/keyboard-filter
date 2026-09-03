import SwiftUI
import Carbon
import Cocoa

@available(macOS 11.0, *)
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var monitor: KeyboardMonitor
    @State private var showingResetAlert = false
    @State private var keyCodeInput = ""
    @State private var permissionTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            TabView {
                basicsTab
                    .tabItem { Label("基本", systemImage: "gearshape") }
                keysTab
                    .tabItem { Label("按键", systemImage: "keyboard") }
                aboutTab
                    .tabItem { Label("关于", systemImage: "info.circle") }
            }
        }
        .onAppear {
            syncPermissionAndMonitor()
        }
        .onReceive(permissionTimer) { _ in
            syncPermissionAndMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncPermissionAndMonitor()
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("重置设置"),
                message: Text("这将重置所有设置为默认值，包括防抖延迟、过滤按键等。此操作不可撤销。"),
                primaryButton: .destructive(Text("重置")) {
                    settings.resetToDefaults()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.headline)
                Spacer()
                if monitor.hasAccessibilityPermission {
                    Button(monitor.isMonitoring ? "停止监听" : "开始监听") {
                        toggleMonitoring()
                    }
                } else {
                    Button("授予辅助功能权限") {
                        openAccessibilitySettings()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }

            HStack(spacing: 16) {
                Text(monitor.hasAccessibilityPermission ? "权限：已授权" : "权限：未授权")
                    .foregroundColor(monitor.hasAccessibilityPermission ? .secondary : .orange)
                Text("按键 \(monitor.keyPressCount)")
                    .foregroundColor(.secondary)
                Text("已过滤 \(monitor.filteredCount)")
                    .foregroundColor(.secondary)
                Spacer()
                if monitor.keyPressCount > 0 || monitor.filteredCount > 0 {
                    Button("清零") {
                        monitor.clearStatistics()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .font(.caption)

            if !monitor.hasAccessibilityPermission {
                Text("没有辅助功能权限时无法拦截键盘，防抖不会生效。打开系统设置后勾选本应用，再回到这里。")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var basicsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("基本设置")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("防抖延迟")
                            Spacer()
                            Text("\(settings.debounceDelay)ms")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.debounceDelay) },
                                set: { settings.debounceDelay = Int($0) }
                            ),
                            in: 10...200,
                            step: 5
                        ) {
                            Text("防抖延迟")
                        } minimumValueLabel: {
                            Text("10ms")
                        } maximumValueLabel: {
                            Text("200ms")
                        }
                        .help("同一按键两次按下的最短间隔，用于滤掉机械抖动")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最大按键频率")
                            Spacer()
                            Text("\(settings.maxKeyPressesPerSecond) 次/秒")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.maxKeyPressesPerSecond) },
                                set: { settings.maxKeyPressesPerSecond = Int($0) }
                            ),
                            in: 5...100,
                            step: 5
                        ) {
                            Text("最大按键频率")
                        } minimumValueLabel: {
                            Text("5/秒")
                        } maximumValueLabel: {
                            Text("100/秒")
                        }
                        .help("限制每秒按键次数；长按自动重复不受此限制")
                    }

                    Toggle("启用防抖与过滤", isOn: $settings.enableFiltering)
                        .help("关闭后仍监听键盘，但不再拦截任何按键")

                    Toggle("开机自启动", isOn: $settings.autoStart)
                        .help("登录后自动启动并开始防抖")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .padding()
    }

    private var keysTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("按键过滤")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 15) {
                    Text("过滤特定按键")
                        .font(.headline)

                    Text("输入按键代码并添加，或使用下方按钮添加常用按键")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("按键代码 (0-255)", text: $keyCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)

                        Button("添加") {
                            addKeyCode()
                        }
                        .disabled(keyCodeInput.isEmpty)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("常用按键:")
                            .font(.subheadline)

                        HStack(spacing: 10) {
                            ForEach(commonKeyCodes, id: \.self) { keyCode in
                                Button(keyName(for: keyCode)) {
                                    if !settings.filterKeys.contains(keyCode) {
                                        settings.filterKeys.append(keyCode)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(settings.filterKeys.contains(keyCode))
                            }
                        }
                    }

                    if !settings.filterKeys.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已过滤按键:")
                                .font(.headline)

                            ScrollView {
                                VStack(spacing: 5) {
                                    ForEach(settings.filterKeys.sorted(), id: \.self) { keyCode in
                                        HStack {
                                            Text("\(keyName(for: keyCode)) (代码: \(keyCode))")
                                                .font(.system(.body, design: .monospaced))
                                            Spacer()
                                            Button("移除") {
                                                if let index = settings.filterKeys.firstIndex(of: keyCode) {
                                                    settings.filterKeys.remove(at: index)
                                                }
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundColor(.red)
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)

                            Button("清空列表") {
                                settings.filterKeys.removeAll()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Text("当前没有过滤任何按键")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .padding()
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 25) {
                Image(systemName: "keyboard.badge.eye")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)

                VStack(spacing: 10) {
                    Text("键盘防抖工具")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("macOS 版本 1.0.1")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("基于 Windows 键盘防抖工具 v2.3.3.0 开发")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(
                        icon: "hand.tap",
                        title: "键盘防抖",
                        description: "过滤机械键盘按键抖动，防止重复输入"
                    )
                    FeatureRow(
                        icon: "slider.horizontal.3",
                        title: "延迟调节",
                        description: "可调节防抖延迟时间，适应不同键盘"
                    )
                    FeatureRow(
                        icon: "key",
                        title: "按键过滤",
                        description: "过滤特定按键，支持自定义按键代码"
                    )
                    FeatureRow(
                        icon: "speedometer",
                        title: "频率限制",
                        description: "限制每秒按键次数；长按不受影响"
                    )
                    FeatureRow(
                        icon: "power",
                        title: "自启动",
                        description: "登录后自动启动并开始防抖"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Button("重置所有设置为默认值") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)

                Text("需要辅助功能权限才能监听键盘事件")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .padding()
    }

    private var statusColor: Color {
        if !monitor.hasAccessibilityPermission { return .orange }
        if monitor.isMonitoring && settings.enableFiltering { return .green }
        if monitor.isMonitoring { return .yellow }
        return .red
    }

    private var statusText: String {
        if !monitor.hasAccessibilityPermission { return "等待辅助功能权限" }
        if monitor.isMonitoring && settings.enableFiltering { return "防抖运行中" }
        if monitor.isMonitoring { return "已监听（过滤已关闭）" }
        return "未在监听"
    }

    private func syncPermissionAndMonitor() {
        let wasAllowed = monitor.hasAccessibilityPermission
        let allowed = monitor.refreshAccessibilityPermission()
        if allowed && !wasAllowed && !monitor.isMonitoring && !monitor.userPaused {
            monitor.startMonitoring()
        }
    }

    private func toggleMonitoring() {
        if monitor.isMonitoring {
            monitor.stopMonitoring()
        } else if monitor.refreshAccessibilityPermission() {
            monitor.startMonitoring()
        } else {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        monitor.requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func addKeyCode() {
        guard let code = Int(keyCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...255).contains(code) else {
            keyCodeInput = ""
            return
        }

        if !settings.filterKeys.contains(code) {
            settings.filterKeys.append(code)
        }
        keyCodeInput = ""
    }

    private func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_Delete: return "退格"
        case kVK_Tab: return "Tab"
        case kVK_Return: return "回车"
        case kVK_Escape: return "Esc"
        case kVK_Space: return "空格"
        case kVK_ForwardDelete: return "删除"
        default: return "按键 \(keyCode)"
        }
    }
}

private let commonKeyCodes: [Int] = [
    kVK_Delete,
    kVK_Tab,
    kVK_Return,
    kVK_Escape,
    kVK_Space,
    kVK_ForwardDelete
]

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
