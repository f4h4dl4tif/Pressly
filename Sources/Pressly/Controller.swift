import AppKit
import Combine
import ServiceManagement

/// Keys currently held, for the live keyboard and the animated keycaps.
final class LiveKeys: ObservableObject {
    static let shared = LiveKeys()
    @Published var pressed: Set<UInt16> = []
    @Published var presses = 0
}

/// Wires input events to sounds and applies every rule about when to stay quiet.
final class Controller {
    static let shared = Controller()

    let settings = AppSettings.shared
    let engine = SoundEngine.shared
    let input = InputMonitor()
    let triggers = SleepTriggers.shared
    let stats = Stats.shared
    let live = LiveKeys.shared

    private var bag = Set<AnyCancellable>()
    private(set) var trusted = AXIsProcessTrusted()
    private var scrollAccumulator: CGFloat = 0
    private var lastScrollTick = Date.distantPast

    func start() {
        engine.deviceUID = settings.outputDeviceUID
        engine.volume = Float(settings.volume)
        engine.load(profile: settings.profile, variation: settings.pitchVariation)
        engine.start()

        input.onKey = { [weak self] code, down, rep in self?.key(code, down: down, isRepeat: rep) }
        input.onMediaKey = { [weak self] nx, down, rep in self?.mediaKey(nx, down: down, isRepeat: rep) }
        input.onMouse = { [weak self] down in self?.mouse(down) }
        input.onScroll = { [weak self] e in self?.scroll(e) }
        input.start()
        triggers.start()
        registerHotKeys()

        settings.$switchID.combineLatest(settings.$pitchVariation)
            .dropFirst()
            .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .sink { [weak self] id, variation in self?.engine.load(profile: SwitchProfile.named(id), variation: variation) }
            .store(in: &bag)
        settings.$volume.sink { [weak self] v in self?.engine.volume = Float(v) }.store(in: &bag)
        settings.$outputDeviceUID.dropFirst().sink { [weak self] uid in self?.engine.deviceUID = uid }.store(in: &bag)
        Publishers.MergeMany(settings.$toggleKey, settings.$toggleMods, settings.$nextKey, settings.$nextMods)
            .dropFirst(4)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.registerHotKeys() }
            .store(in: &bag)

        // Accessibility can be granted while we run; restart the monitors when it is.
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = AXIsProcessTrusted()
            if now != self.trusted {
                self.trusted = now
                if now { self.input.start() }
                NotificationCenter.default.post(name: .presslyTrustChanged, object: nil)
            }
        }
    }

    func registerHotKeys() {
        HotKeys.shared.register(id: 1, code: settings.toggleKey, mods: settings.toggleMods) { [weak self] in self?.toggle() }
        HotKeys.shared.register(id: 2, code: settings.nextKey, mods: settings.nextMods) { [weak self] in self?.nextSwitch() }
    }

    func suspendHotKeys() { HotKeys.shared.unregisterAll() }

    // MARK: Actions

    func toggle() {
        settings.enabled.toggle()
        HUD.shared.showToggle(settings.enabled)
    }

    func setSwitch(_ id: String, announce: Bool = true) {
        settings.switchID = id
        if announce { HUD.shared.showSwitch(settings.profile) }
    }

    func nextSwitch() {
        let all = SwitchProfile.all
        let i = all.firstIndex { $0.id == settings.switchID } ?? 0
        setSwitch(all[(i + 1) % all.count].id)
    }

    // MARK: Rules

    var silenceReason: String? {
        if !settings.enabled { return "Sounds are off" }
        if let r = triggers.reason { return r }
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, settings.mutedApps.contains(id) {
            return "Muted in this app"
        }
        if settings.silentOutputUIDs.contains(engine.activeDeviceUID) { return "Muted on this output" }
        return nil
    }

    private func pan(forX x: Double) -> Float {
        settings.spatialAudio ? Float((x - 0.5) * 2 * settings.spatialWidth) : 0
    }

    // MARK: Events

    private func key(_ code: UInt16, down: Bool, isRepeat: Bool) {
        if down { live.pressed.insert(code); if !isRepeat { live.presses += 1 } } else { live.pressed.remove(code) }
        if down && !isRepeat { stats.recordKey(code) }
        guard !isRepeat, silenceReason == nil else { return }

        let cat = KeyMap.category(code)
        switch cat {
        case .modifier where !settings.modifierSounds: return
        case .function where !settings.functionKeySounds: return
        case .numpad where !settings.numpadSounds: return
        default: break
        }
        if !down && !settings.keyUpSounds { return }
        let sound: SoundKey = cat.sound == .normal ? .row(KeyMap.row[code] ?? 2, up: !down) : .key(cat.sound, up: !down)
        engine.play(sound, pan: pan(forX: KeyMap.xPosition[code] ?? 0.5))
    }

    private func mediaKey(_ nx: Int, down: Bool, isRepeat: Bool) {
        guard settings.functionKeySounds, !isRepeat, silenceReason == nil else { return }
        if !down && !settings.keyUpSounds { return }
        engine.play(.key(.normal, up: !down), pan: pan(forX: KeyMap.xForMediaKey(nx)))
    }

    private func mouse(_ down: Bool) {
        if down { stats.recordClick() }
        guard settings.mouseClicks, silenceReason == nil else { return }
        engine.play(down ? .mouseDown : .mouseUp, pan: pan(forX: cursorX()), gain: Float(settings.mouseVolume))
    }

    private func cursorX() -> Double {
        let p = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) else { return 0.5 }
        return Double((p.x - screen.frame.minX) / screen.frame.width)
    }

    private func scroll(_ e: NSEvent) {
        let delta = abs(e.scrollingDeltaY) > abs(e.scrollingDeltaX) ? e.scrollingDeltaY : e.scrollingDeltaX
        guard delta != 0 else { return }
        var tick = false
        if e.hasPreciseScrollingDeltas {
            scrollAccumulator += abs(delta)
            if scrollAccumulator >= 14 { scrollAccumulator = 0; tick = true }
        } else {
            tick = true
        }
        guard tick, Date().timeIntervalSince(lastScrollTick) > 0.028 else { return }
        lastScrollTick = Date()
        stats.recordScroll()
        guard silenceReason == nil else { return }
        if settings.scrollSounds {
            engine.play(.scroll, pan: pan(forX: cursorX()), gain: Float(settings.mouseVolume))
        }
        if settings.scrollHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    // MARK: Login item

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("Pressly: login item change failed: \(error)") }
        }
    }
}

extension Notification.Name {
    static let presslyTrustChanged = Notification.Name("presslyTrustChanged")
}
