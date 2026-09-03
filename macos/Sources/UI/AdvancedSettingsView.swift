import AppKit
import Combine
import SwiftUI

final class AdvancedSettingsModel: ObservableObject {
    @Published var useAutoPage: Bool
    @Published var tempKeys: Set<Int>
    private let engine: FilterEngine
    private var cancellables = Set<AnyCancellable>()

    init(useAuto: Bool, manualKeys: Set<Int>, engine: FilterEngine = .shared) {
        self.useAutoPage = useAuto
        self.tempKeys = manualKeys
        self.engine = engine

        engine.$autoRevision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var selectedKeys: Set<Int> {
        useAutoPage ? engine.autoKeys : tempKeys
    }

    var hint: String {
        if useAutoPage {
            return "自动分析：只把极短接触抖动（约 ≤35ms）计入，正常快打不会纳入。可用鼠标点选/取消任意键。仅鼠标操作。"
        }
        return "手动选键：用鼠标点选要防抖的键，再次点击可取消。仅鼠标操作。"
    }

    var status: String {
        let n = selectedKeys.count
        if useAutoPage {
            return "当前 \(n) 个按键 · 可点选增减 · 仅 ≤\(Int(kLearnBounceMs))ms 抖动计入 · ≥\(kAutoAnomalyToAdd) 次纳入"
        }
        return "已选择 \(n) 个按键 · 点确定后启用高级模式"
    }

    func toggle(code: Int) {
        if useAutoPage {
            engine.toggleAutoKey(code)
            objectWillChange.send()
        } else if tempKeys.contains(code) {
            tempKeys.remove(code)
        } else {
            tempKeys.insert(code)
        }
    }

    func clear() {
        if useAutoPage {
            engine.clearAutoKeys()
            objectWillChange.send()
        } else {
            tempKeys.removeAll()
        }
    }

    func result() -> (useAuto: Bool, manualKeys: Set<Int>) {
        (useAutoPage, tempKeys)
    }
}

struct KeyCapView: View {
    let spec: KeySpec
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(spec.label)
                .font(.system(size: spec.label.count > 2 ? 10 : 12, weight: .semibold))
                .foregroundColor(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .frame(
            width: KeyboardLayout.unit * spec.width + KeyboardLayout.gap * max(spec.width - 1, 0),
            height: KeyboardLayout.unit
        )
    }
}

struct KeyRowView: View {
    let keys: [KeySpec]
    let selected: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: KeyboardLayout.gap) {
            ForEach(keys) { spec in
                KeyCapView(spec: spec, selected: selected.contains(spec.code)) {
                    onToggle(spec.code)
                }
            }
        }
    }
}

struct KeyboardBoardView: View {
    let selected: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KeyboardLayout.gap) {
            KeyRowView(keys: KeyboardLayout.functionRow, selected: selected, onToggle: onToggle)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: KeyboardLayout.gap) {
                    ForEach(Array(KeyboardLayout.mainRows.enumerated()), id: \.offset) { _, row in
                        KeyRowView(keys: row, selected: selected, onToggle: onToggle)
                    }
                }

                VStack(alignment: .leading, spacing: KeyboardLayout.gap) {
                    KeyRowView(keys: KeyboardLayout.navTop, selected: selected, onToggle: onToggle)
                    KeyRowView(keys: KeyboardLayout.navBottom, selected: selected, onToggle: onToggle)
                    Spacer(minLength: KeyboardLayout.unit * 0.4)
                    HStack {
                        Spacer(minLength: KeyboardLayout.unit + KeyboardLayout.gap)
                        KeyRowView(keys: KeyboardLayout.arrowUp, selected: selected, onToggle: onToggle)
                        Spacer(minLength: KeyboardLayout.unit + KeyboardLayout.gap)
                    }
                    KeyRowView(keys: KeyboardLayout.arrowRow, selected: selected, onToggle: onToggle)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var model: AdvancedSettingsModel
    @ObservedObject var engine: FilterEngine
    let onConfirm: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                radio("手动选键（只防抖勾选的键）", selected: !model.useAutoPage) {
                    model.useAutoPage = false
                }
                radio("自动分析（抖动自动纳入，仍可点选取消）", selected: model.useAutoPage) {
                    model.useAutoPage = true
                }
                Spacer()
            }

            Text(model.hint)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.status)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            KeyboardBoardView(selected: model.selectedKeys, onToggle: { code in
                model.toggle(code: code)
            })

            HStack {
                Button("清空全部") { onClear() }
                    .focusable(false)
                Spacer()
                Button("确定") { onConfirm() }
                    .focusable(false)
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func radio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? .accentColor : .secondary)
                Text(title)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

final class KeySwallowingWindow: NSWindow {
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

final class AdvancedSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AdvancedSettingsModel
    private var didFinish = false
    var onConfirm: ((_ useAuto: Bool, _ manualKeys: Set<Int>) -> Void)?

    init(useAuto: Bool, manualKeys: Set<Int>) {
        self.model = AdvancedSettingsModel(useAuto: useAuto, manualKeys: manualKeys)
        let window = KeySwallowingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "高级设置"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        let root = AdvancedSettingsView(
            model: model,
            engine: .shared,
            onConfirm: { [weak self] in self?.finish() },
            onClear: { [weak self] in self?.model.clear() }
        )
        let hosting = NSHostingController(rootView: root)
        window.contentViewController = hosting
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        let result = model.result()
        onConfirm?(result.useAuto, result.manualKeys)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        if !didFinish {
            didFinish = true
            let result = model.result()
            onConfirm?(result.useAuto, result.manualKeys)
        }
    }
}
