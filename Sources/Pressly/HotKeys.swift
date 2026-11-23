import Carbon

/// System-wide keyboard shortcuts via Carbon's RegisterEventHotKey (no permission needed).
final class HotKeys {
    static let shared = HotKeys()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { HotKeys.shared.actions[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    func register(id: UInt32, code: Int, mods: Int, action: @escaping () -> Void) {
        installHandler()
        unregister(id: id)
        actions[id] = action
        guard code >= 0 else { return }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x5448_4B59), id: id)  // 'THKY'
        if RegisterEventHotKey(UInt32(code), UInt32(mods), hkID, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
            refs[id] = ref
        }
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    }

    func unregisterAll() { refs.keys.forEach(unregister) }
}
