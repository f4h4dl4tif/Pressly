import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = AppSettings.shared
    private var statusItem: NSStatusItem!
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        Controller.shared.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        settings.$showMenuIcon.combineLatest(settings.$menuIcon, settings.$enabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &bag)
        SleepTriggers.shared.$reason.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateStatusItem() }.store(in: &bag)
        settings.$switchID.receive(on: RunLoop.main).sink { _ in WindowManager.shared.updateDockIcon() }.store(in: &bag)

        #if DEBUG
        DebugSnapshot.runIfRequested()
        if CommandLine.arguments.contains("--snapshot") { return }
        if DebugSnapshot.runGlassIfRequested() { return }
        #endif
        if !settings.onboarded || !AXIsProcessTrusted() {
            WindowManager.shared.showOnboarding()
        }
    }

    /// Opening the app again (e.g. from Applications) brings up Settings, which matters when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Stats.shared.save()
    }

    // MARK: Status item

    private func updateStatusItem() {
        guard let statusItem else { return }
        statusItem.isVisible = settings.showMenuIcon
        let quiet = !settings.enabled || SleepTriggers.shared.isSleeping
        let image = NSImage(systemSymbolName: settings.menuIcon, accessibilityDescription: "Pressly")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = quiet
        statusItem.button?.toolTip = quiet ? "Pressly — \(Controller.shared.silenceReason ?? "quiet")" : "Pressly — \(settings.profile.name)"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem()
        header.view = hosted(MenuHeaderView(), width: 280)
        menu.addItem(header)
        menu.addItem(.separator())

        let sound = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        sound.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        sound.submenu = soundMenu()
        menu.addItem(sound)

        let switches = NSMenuItem(title: "Switches", action: nil, keyEquivalent: "")
        switches.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: nil)
        switches.submenu = switchMenu()
        menu.addItem(switches)

        menu.addItem(.separator())
        let today = Stats.shared.today
        let statsItem = item("\(today.keys.formatted()) keystrokes today", #selector(openStats))
        statsItem.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: nil)
        menu.addItem(statsItem)
        menu.addItem(.separator())
        menu.addItem(item("Pressly Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Quit Pressly", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func soundMenu() -> NSMenu {
        let m = NSMenu()
        let slider = NSMenuItem()
        slider.view = hosted(MenuVolumeView(), width: 250)
        m.addItem(slider)
        m.addItem(.separator())
        m.addItem(toggle("Key-up sounds", \.keyUpSounds))
        m.addItem(toggle("Modifier keys", \.modifierSounds))
        m.addItem(toggle("Function & media keys", \.functionKeySounds))
        m.addItem(toggle("Numpad", \.numpadSounds))
        m.addItem(toggle("Spatial audio", \.spatialAudio))
        m.addItem(.separator())
        m.addItem(toggle("Mouse clicks", \.mouseClicks))
        m.addItem(toggle("Scroll ticks", \.scrollSounds))
        m.addItem(.separator())
        m.addItem(.sectionHeader(title: "Output"))
        let def = item("System Output", #selector(pickOutput(_:)))
        def.representedObject = ""
        def.state = settings.outputDeviceUID.isEmpty ? .on : .off
        m.addItem(def)
        for device in AudioDevices.outputDevices() {
            let i = item(device.name, #selector(pickOutput(_:)))
            i.representedObject = device.uid
            i.state = settings.outputDeviceUID == device.uid ? .on : .off
            m.addItem(i)
        }
        return m
    }

    private func switchMenu() -> NSMenu {
        let m = NSMenu()
        func add(_ p: SwitchProfile) {
            let i = item(p.name, #selector(pickSwitch(_:)))
            i.representedObject = p.id
            i.state = settings.switchID == p.id ? .on : .off
            i.image = swatch(p)
            if p.isNew { i.badge = NSMenuItemBadge(string: "New") }
            m.addItem(i)
        }
        for kind in SwitchKind.allCases {
            let profiles = SwitchProfile.recorded.filter { $0.kind == kind }
            guard !profiles.isEmpty else { continue }
            m.addItem(.sectionHeader(title: kind.rawValue))
            profiles.forEach(add)
        }
        m.addItem(.separator())
        let originals = NSMenuItem(title: "Pressly Originals (Synthesized)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for p in SwitchProfile.synthesized {
            let i = item(p.name, #selector(pickSwitch(_:)))
            i.representedObject = p.id
            i.state = settings.switchID == p.id ? .on : .off
            i.image = swatch(p)
            sub.addItem(i)
        }
        originals.submenu = sub
        if SwitchProfile.named(settings.switchID).isRecorded == false { originals.state = .on }
        m.addItem(originals)
        m.addItem(.separator())
        let next = item("Next Switch", #selector(nextSwitch))
        m.addItem(next)
        m.addItem(item("Preview Current Switch", #selector(previewSwitch)))
        return m
    }

    private func swatch(_ p: SwitchProfile) -> NSImage {
        NSImage(size: NSSize(width: 14, height: 14), flipped: false) { r in
            let path = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 3.5, yRadius: 3.5)
            NSColor(hex: p.cap).setFill(); path.fill()
            NSColor(hex: p.cap).shade(0.35).setStroke(); path.lineWidth = 1; path.stroke()
            return true
        }
    }

    private func hosted<V: View>(_ view: V, width: CGFloat) -> NSView {
        let host = NSHostingView(rootView: view.frame(width: width))
        host.frame.size = host.fittingSize
        return host
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = target ?? self
        return i
    }

    private func toggle(_ title: String, _ path: ReferenceWritableKeyPath<AppSettings, Bool>) -> NSMenuItem {
        let i = ToggleMenuItem(title: title, action: #selector(flip(_:)), keyEquivalent: "")
        i.target = self
        i.path = path
        i.state = settings[keyPath: path] ? .on : .off
        return i
    }

    @objc private func flip(_ sender: ToggleMenuItem) {
        guard let path = sender.path else { return }
        settings[keyPath: path].toggle()
    }

    @objc private func pickOutput(_ sender: NSMenuItem) { settings.outputDeviceUID = sender.representedObject as? String ?? "" }
    @objc private func pickSwitch(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Controller.shared.setSwitch(id)
    }
    @objc private func nextSwitch() { Controller.shared.nextSwitch() }
    @objc private func previewSwitch() { SoundEngine.shared.preview(settings.profile, variation: settings.pitchVariation) }
    @objc private func openSettings() { WindowManager.shared.showSettings() }
    @objc private func openStats() { WindowManager.shared.showSettings(.stats) }

    // MARK: URL scheme  pressly://toggle | on | off | next | switch/<name> | settings

    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URL(string: s) else { return }
        let c = Controller.shared
        switch url.host?.lowercased() {
        case "toggle": c.toggle()
        case "on": settings.enabled = true; HUD.shared.showToggle(true)
        case "off": settings.enabled = false; HUD.shared.showToggle(false)
        case "next": c.nextSwitch()
        case "switch":
            let name = url.pathComponents.dropFirst().first?.lowercased() ?? ""
            if let p = SwitchProfile.all.first(where: { $0.id == name || $0.name.lowercased() == name }) { c.setSwitch(p.id) }
        case "settings": WindowManager.shared.showSettings()
        default: break
        }
    }

    // MARK: AppleScript (see Pressly.sdef)

    private static let scriptKeys: Set<String> = ["scriptEnabled", "scriptSwitch", "scriptSwitchNames", "scriptVolume", "scriptSleeping",
                                                  "scriptKeysToday", "scriptKeysTotal", "scriptClicksToday"]

    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool { Self.scriptKeys.contains(key) }

    @objc var scriptEnabled: Bool {
        get { settings.enabled }
        set { settings.enabled = newValue }
    }
    @objc var scriptSwitch: String {
        get { settings.profile.name }
        set {
            if let p = SwitchProfile.all.first(where: { $0.name.caseInsensitiveCompare(newValue) == .orderedSame || $0.id == newValue.lowercased() }) {
                Controller.shared.setSwitch(p.id)
            }
        }
    }
    @objc var scriptSwitchNames: [String] { SwitchProfile.all.map(\.name) }
    @objc var scriptVolume: Int {
        get { Int((settings.volume * 100).rounded()) }
        set { settings.volume = Double(max(0, min(100, newValue))) / 100 }
    }
    @objc var scriptSleeping: Bool { SleepTriggers.shared.isSleeping }
    @objc var scriptKeysToday: Int { Stats.shared.today.keys }
    @objc var scriptKeysTotal: Int { Stats.shared.totalKeys }
    @objc var scriptClicksToday: Int { Stats.shared.today.clicks }
}

final class ToggleMenuItem: NSMenuItem {
    var path: ReferenceWritableKeyPath<AppSettings, Bool>?
}

@objc(PresslyToggleCommand) final class PresslyToggleCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        Controller.shared.toggle()
        return AppSettings.shared.enabled
    }
}

@objc(PresslyNextCommand) final class PresslyNextCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        Controller.shared.nextSwitch()
        return AppSettings.shared.profile.name
    }
}
