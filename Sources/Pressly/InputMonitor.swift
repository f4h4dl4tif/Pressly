import AppKit

/// Listens to keyboard, mouse and scroll events system-wide (needs Accessibility permission).
/// Only key codes are used; Pressly never reads characters. Password fields with Secure
/// Input on are hidden from it by macOS.
final class InputMonitor {
    var onKey: ((_ code: UInt16, _ down: Bool, _ isRepeat: Bool) -> Void)?
    var onMediaKey: ((_ nxKey: Int, _ down: Bool, _ isRepeat: Bool) -> Void)?
    var onMouse: ((_ down: Bool) -> Void)?
    var onScroll: ((NSEvent) -> Void)?

    private var monitors: [Any] = []

    // Device-dependent modifier bits, so left and right keys are tracked separately.
    private static let modifierBits: [UInt16: UInt] = [
        56: 0x02, 60: 0x04,        // shift L/R
        59: 0x01, 62: 0x2000,      // control L/R
        58: 0x20, 61: 0x40,        // option L/R
        55: 0x08, 54: 0x10,        // command L/R
    ]

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown,
                                           .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel, .systemDefined]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] e in self?.handle(e) }) {
            monitors.append(g)
        }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] e in self?.handle(e); return e }) {
            monitors.append(l)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .keyDown: onKey?(e.keyCode, true, e.isARepeat)
        case .keyUp: onKey?(e.keyCode, false, false)
        case .flagsChanged: handleFlags(e)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: onMouse?(true)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp: onMouse?(false)
        case .scrollWheel: onScroll?(e)
        case .systemDefined:
            guard e.subtype.rawValue == 8 else { return }  // aux control buttons (media keys)
            let data = e.data1
            let key = (data & 0xFFFF_0000) >> 16
            let flags = data & 0xFFFF
            let state = (flags & 0xFF00) >> 8
            guard state == 0xA || state == 0xB else { return }
            onMediaKey?(key, state == 0xA, flags & 0x1 == 1)
        default: break
        }
    }

    private func handleFlags(_ e: NSEvent) {
        let code = e.keyCode
        if code == 57 {  // caps lock: one physical press per change
            onKey?(code, true, false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in self?.onKey?(code, false, false) }
            return
        }
        if code == 63 {
            onKey?(code, e.modifierFlags.contains(.function), false)
            return
        }
        guard let bit = Self.modifierBits[code] else { return }
        onKey?(code, e.modifierFlags.rawValue & bit != 0, false)
    }
}
