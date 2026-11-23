import AppKit

struct KeyInfo: Hashable {
    let code: UInt16
    let label: String
    let width: Double
}

enum KeyCategory {
    case normal, space, enter, backspace, modifier, function, numpad, arrow

    var sound: SoundCategory {
        switch self {
        case .space: return .space
        case .enter: return .enter
        case .backspace: return .backspace
        case .modifier: return .modifier
        default: return .normal
        }
    }
}

/// A Mac ANSI laptop layout. Drives stereo placement, the live keyboard view and shortcut labels.
enum KeyMap {
    private static func k(_ code: UInt16, _ label: String, _ w: Double = 1) -> KeyInfo { KeyInfo(code: code, label: label, width: w) }

    static let rows: [[KeyInfo]] = [
        [k(53, "esc", 1.5), k(122, "F1", 13.0 / 12), k(120, "F2", 13.0 / 12), k(99, "F3", 13.0 / 12), k(118, "F4", 13.0 / 12),
         k(96, "F5", 13.0 / 12), k(97, "F6", 13.0 / 12), k(98, "F7", 13.0 / 12), k(100, "F8", 13.0 / 12), k(101, "F9", 13.0 / 12),
         k(109, "F10", 13.0 / 12), k(103, "F11", 13.0 / 12), k(111, "F12", 13.0 / 12)],
        [k(50, "`"), k(18, "1"), k(19, "2"), k(20, "3"), k(21, "4"), k(23, "5"), k(22, "6"), k(26, "7"), k(28, "8"), k(25, "9"),
         k(29, "0"), k(27, "-"), k(24, "="), k(51, "delete", 1.5)],
        [k(48, "tab", 1.5), k(12, "Q"), k(13, "W"), k(14, "E"), k(15, "R"), k(17, "T"), k(16, "Y"), k(32, "U"), k(34, "I"), k(31, "O"),
         k(35, "P"), k(33, "["), k(30, "]"), k(42, "\\")],
        [k(57, "caps", 1.8), k(0, "A"), k(1, "S"), k(2, "D"), k(3, "F"), k(5, "G"), k(4, "H"), k(38, "J"), k(40, "K"), k(37, "L"),
         k(41, ";"), k(39, "'"), k(36, "return", 1.7)],
        [k(56, "shift", 2.3), k(6, "Z"), k(7, "X"), k(8, "C"), k(9, "V"), k(11, "B"), k(45, "N"), k(46, "M"), k(43, ","), k(47, "."),
         k(44, "/"), k(60, "shift", 2.2)],
        [k(63, "fn"), k(59, "⌃"), k(58, "⌥"), k(55, "⌘", 1.25), k(49, "", 5), k(54, "⌘", 1.25), k(61, "⌥"),
         k(123, "←", 0.75), k(125, "↓", 0.75), k(126, "↑", 0.75), k(124, "→", 0.75)],
    ]

    static let rowUnits = 14.5

    /// Horizontal key centre from 0 (left) to 1 (right).
    static let xPosition: [UInt16: Double] = {
        var map: [UInt16: Double] = [:]
        for row in rows {
            var x = 0.0
            for key in row {
                map[key.code] = (x + key.width / 2) / rowUnits
                x += key.width
            }
        }
        for code in numpad { map[code] = 1.0 }
        map[117] = 0.97  // forward delete
        map[115] = 0.97; map[119] = 0.97; map[116] = 0.97; map[121] = 0.97  // home/end/page
        return map
    }()

    /// Keyboard row 0 (number row) … 4 (bottom row), matching the recorded GENERIC_R0…R4 takes.
    static let row: [UInt16: Int] = {
        var map: [UInt16: Int] = [:]
        for (i, keys) in rows.enumerated() { for key in keys { map[key.code] = max(0, i - 1) } }
        for code in numpad { map[code] = 2 }
        return map
    }()

    static let numpad: Set<UInt16> = [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
    static let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    static func category(_ code: UInt16) -> KeyCategory {
        if numpad.contains(code) { return code == 76 ? .enter : .numpad }
        if functionKeys.contains(code) { return .function }
        switch code {
        case 49: return .space
        case 36: return .enter
        case 51, 117: return .backspace
        case 54...63: return .modifier
        case 123...126: return .arrow
        default: return .normal
        }
    }

    /// Media keys (brightness, volume, play) arrive as NX key types; place them on the F-row.
    static func xForMediaKey(_ nx: Int) -> Double {
        let fKey: [Int: UInt16] = [3: 122, 2: 120, 22: 99, 21: 118, 18: 98, 16: 100, 17: 101, 7: 109, 1: 103, 0: 111]
        if let code = fKey[nx], let x = xPosition[code] { return x }
        return 0.5
    }

    static let labels: [UInt16: String] = {
        var map: [UInt16: String] = [:]
        for row in rows { for key in row where !key.label.isEmpty { map[key.code] = key.label } }
        map[49] = "Space"; map[51] = "⌫"; map[36] = "↩"; map[48] = "⇥"; map[53] = "⎋"; map[117] = "⌦"
        map[115] = "↖"; map[119] = "↘"; map[116] = "⇞"; map[121] = "⇟"
        return map
    }()
}

enum HotkeyFormat {
    // Carbon modifier masks.
    static let cmd = 256, shift = 512, option = 2048, control = 4096

    static func carbon(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmd }
        if flags.contains(.shift) { m |= shift }
        if flags.contains(.option) { m |= option }
        if flags.contains(.control) { m |= control }
        return m
    }

    static func string(code: Int, mods: Int) -> String {
        guard code >= 0 else { return "Not set" }
        var s = ""
        if mods & control != 0 { s += "⌃" }
        if mods & option != 0 { s += "⌥" }
        if mods & shift != 0 { s += "⇧" }
        if mods & cmd != 0 { s += "⌘" }
        return s + (KeyMap.labels[UInt16(code)] ?? "#\(code)")
    }
}
