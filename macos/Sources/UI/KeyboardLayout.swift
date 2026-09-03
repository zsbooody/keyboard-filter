import CoreGraphics
import Foundation

struct KeySpec: Identifiable, Hashable {
    let code: Int
    let label: String
    /// 相对标准键宽（1.0 = 一颗字母键）
    let width: CGFloat
    let id: String

    init(code: Int, label: String, width: CGFloat = 1.0) {
        self.code = code
        self.label = label
        self.width = width
        self.id = "\(code)-\(label)-\(width)"
    }
}

enum KeyboardLayout {
    static let unit: CGFloat = 44
    static let gap: CGFloat = 5

    static let functionRow: [KeySpec] = [
        KeySpec(code: 53, label: "Esc"),
        KeySpec(code: 122, label: "F1"),
        KeySpec(code: 120, label: "F2"),
        KeySpec(code: 99, label: "F3"),
        KeySpec(code: 118, label: "F4"),
        KeySpec(code: 96, label: "F5"),
        KeySpec(code: 97, label: "F6"),
        KeySpec(code: 98, label: "F7"),
        KeySpec(code: 100, label: "F8"),
        KeySpec(code: 101, label: "F9"),
        KeySpec(code: 109, label: "F10"),
        KeySpec(code: 103, label: "F11"),
        KeySpec(code: 111, label: "F12")
    ]

    static let numberRow: [KeySpec] = [
        KeySpec(code: 50, label: "`"),
        KeySpec(code: 18, label: "1"),
        KeySpec(code: 19, label: "2"),
        KeySpec(code: 20, label: "3"),
        KeySpec(code: 21, label: "4"),
        KeySpec(code: 23, label: "5"),
        KeySpec(code: 22, label: "6"),
        KeySpec(code: 26, label: "7"),
        KeySpec(code: 28, label: "8"),
        KeySpec(code: 25, label: "9"),
        KeySpec(code: 29, label: "0"),
        KeySpec(code: 27, label: "-"),
        KeySpec(code: 24, label: "="),
        KeySpec(code: 51, label: "Delete", width: 1.6)
    ]

    static let tabRow: [KeySpec] = [
        KeySpec(code: 48, label: "Tab", width: 1.5),
        KeySpec(code: 12, label: "Q"),
        KeySpec(code: 13, label: "W"),
        KeySpec(code: 14, label: "E"),
        KeySpec(code: 15, label: "R"),
        KeySpec(code: 17, label: "T"),
        KeySpec(code: 16, label: "Y"),
        KeySpec(code: 32, label: "U"),
        KeySpec(code: 34, label: "I"),
        KeySpec(code: 31, label: "O"),
        KeySpec(code: 35, label: "P"),
        KeySpec(code: 33, label: "["),
        KeySpec(code: 30, label: "]"),
        KeySpec(code: 42, label: "\\", width: 1.5)
    ]

    static let capsRow: [KeySpec] = [
        KeySpec(code: 57, label: "Caps", width: 1.75),
        KeySpec(code: 0, label: "A"),
        KeySpec(code: 1, label: "S"),
        KeySpec(code: 2, label: "D"),
        KeySpec(code: 3, label: "F"),
        KeySpec(code: 5, label: "G"),
        KeySpec(code: 4, label: "H"),
        KeySpec(code: 38, label: "J"),
        KeySpec(code: 40, label: "K"),
        KeySpec(code: 37, label: "L"),
        KeySpec(code: 41, label: ";"),
        KeySpec(code: 39, label: "'"),
        KeySpec(code: 36, label: "Return", width: 1.85)
    ]

    static let shiftRow: [KeySpec] = [
        KeySpec(code: 56, label: "Shift", width: 2.25),
        KeySpec(code: 6, label: "Z"),
        KeySpec(code: 7, label: "X"),
        KeySpec(code: 8, label: "C"),
        KeySpec(code: 9, label: "V"),
        KeySpec(code: 11, label: "B"),
        KeySpec(code: 45, label: "N"),
        KeySpec(code: 46, label: "M"),
        KeySpec(code: 43, label: ","),
        KeySpec(code: 47, label: "."),
        KeySpec(code: 44, label: "/"),
        KeySpec(code: 60, label: "Shift", width: 2.35)
    ]

    static let bottomRow: [KeySpec] = [
        KeySpec(code: 59, label: "Ctrl", width: 1.25),
        KeySpec(code: 58, label: "Opt", width: 1.25),
        KeySpec(code: 55, label: "Cmd", width: 1.35),
        KeySpec(code: 49, label: "Space", width: 5.5),
        KeySpec(code: 54, label: "Cmd", width: 1.35),
        KeySpec(code: 61, label: "Opt", width: 1.25),
        KeySpec(code: 62, label: "Ctrl", width: 1.25)
    ]

    static let navTop: [KeySpec] = [
        KeySpec(code: 117, label: "Del"),
        KeySpec(code: 115, label: "Home"),
        KeySpec(code: 116, label: "PgUp")
    ]

    static let navBottom: [KeySpec] = [
        KeySpec(code: 119, label: "End"),
        KeySpec(code: 121, label: "PgDn")
    ]

    static let arrowUp: [KeySpec] = [
        KeySpec(code: 126, label: "↑")
    ]

    static let arrowRow: [KeySpec] = [
        KeySpec(code: 123, label: "←"),
        KeySpec(code: 125, label: "↓"),
        KeySpec(code: 124, label: "→")
    ]

    static let mainRows: [[KeySpec]] = [
        numberRow, tabRow, capsRow, shiftRow, bottomRow
    ]
}
