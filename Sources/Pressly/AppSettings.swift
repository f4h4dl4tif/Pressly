import Foundation
import Combine

/// Every user preference, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    private func load<T>(_ key: String, _ fallback: T) -> T { d.object(forKey: key) as? T ?? fallback }

    // Core
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    @Published var switchID: String { didSet { d.set(switchID, forKey: "switchID") } }
    @Published var volume: Double { didSet { d.set(volume, forKey: "volume") } }

    // Keys
    @Published var keyUpSounds: Bool { didSet { d.set(keyUpSounds, forKey: "keyUpSounds") } }
    @Published var modifierSounds: Bool { didSet { d.set(modifierSounds, forKey: "modifierSounds") } }
    @Published var functionKeySounds: Bool { didSet { d.set(functionKeySounds, forKey: "functionKeySounds") } }
    @Published var numpadSounds: Bool { didSet { d.set(numpadSounds, forKey: "numpadSounds") } }
    @Published var pitchVariation: Double { didSet { d.set(pitchVariation, forKey: "pitchVariation") } }
    @Published var spatialAudio: Bool { didSet { d.set(spatialAudio, forKey: "spatialAudio") } }
    @Published var spatialWidth: Double { didSet { d.set(spatialWidth, forKey: "spatialWidth") } }

    // Mouse & scroll
    @Published var mouseClicks: Bool { didSet { d.set(mouseClicks, forKey: "mouseClicks") } }
    @Published var mouseVolume: Double { didSet { d.set(mouseVolume, forKey: "mouseVolume") } }
    @Published var scrollSounds: Bool { didSet { d.set(scrollSounds, forKey: "scrollSounds") } }
    @Published var scrollHaptics: Bool { didSet { d.set(scrollHaptics, forKey: "scrollHaptics") } }

    // Output
    @Published var outputDeviceUID: String { didSet { d.set(outputDeviceUID, forKey: "outputDeviceUID") } }
    @Published var silentOutputUIDs: [String] { didSet { d.set(silentOutputUIDs, forKey: "silentOutputUIDs") } }

    // Menu bar & appearance
    @Published var showMenuIcon: Bool { didSet { d.set(showMenuIcon, forKey: "showMenuIcon") } }
    @Published var menuIcon: String { didSet { d.set(menuIcon, forKey: "menuIcon") } }
    @Published var showSwitchHUD: Bool { didSet { d.set(showSwitchHUD, forKey: "showSwitchHUD") } }
    @Published var dynamicIcon: Bool { didSet { d.set(dynamicIcon, forKey: "dynamicIcon") } }
    /// Liquid Glass look for the sidebar, hero card and pop-up (macOS 26+). Off by default.
    @Published var glassTheme: Bool { didSet { d.set(glassTheme, forKey: "glassTheme") } }

    // Muting
    @Published var mutedApps: [String] { didSet { d.set(mutedApps, forKey: "mutedApps") } }
    @Published var sleepGaming: Bool { didSet { d.set(sleepGaming, forKey: "sleepGaming") } }
    @Published var sleepScreenShare: Bool { didSet { d.set(sleepScreenShare, forKey: "sleepScreenShare") } }
    @Published var sleepMedia: Bool { didSet { d.set(sleepMedia, forKey: "sleepMedia") } }
    @Published var sleepCalendar: Bool { didSet { d.set(sleepCalendar, forKey: "sleepCalendar") } }
    @Published var sleepFocus: Bool { didSet { d.set(sleepFocus, forKey: "sleepFocus") } }

    // Shortcuts (Carbon key code + modifiers; -1 = none)
    @Published var toggleKey: Int { didSet { d.set(toggleKey, forKey: "toggleKey") } }
    @Published var toggleMods: Int { didSet { d.set(toggleMods, forKey: "toggleMods") } }
    @Published var nextKey: Int { didSet { d.set(nextKey, forKey: "nextKey") } }
    @Published var nextMods: Int { didSet { d.set(nextMods, forKey: "nextMods") } }

    @Published var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }

    private init() {
        let d = UserDefaults.standard
        Self.migrateFromThockly(d)
        func v<T>(_ key: String, _ fallback: T) -> T { d.object(forKey: key) as? T ?? fallback }
        enabled = v("enabled", true)
        switchID = v("switchID", "cream")
        volume = v("volume", 0.7)
        keyUpSounds = v("keyUpSounds", true)
        modifierSounds = v("modifierSounds", false)
        functionKeySounds = v("functionKeySounds", true)
        numpadSounds = v("numpadSounds", true)
        pitchVariation = v("pitchVariation", 0.5)
        spatialAudio = v("spatialAudio", true)
        spatialWidth = v("spatialWidth", 0.6)
        mouseClicks = v("mouseClicks", false)
        mouseVolume = v("mouseVolume", 0.6)
        scrollSounds = v("scrollSounds", false)
        scrollHaptics = v("scrollHaptics", false)
        outputDeviceUID = v("outputDeviceUID", "")
        silentOutputUIDs = v("silentOutputUIDs", [])
        showMenuIcon = v("showMenuIcon", true)
        menuIcon = v("menuIcon", "keyboard")
        showSwitchHUD = v("showSwitchHUD", true)
        dynamicIcon = v("dynamicIcon", true)
        glassTheme = v("glassTheme", false)
        mutedApps = v("mutedApps", [])
        sleepGaming = v("sleepGaming", false)
        sleepScreenShare = v("sleepScreenShare", false)
        sleepMedia = v("sleepMedia", false)
        sleepCalendar = v("sleepCalendar", false)
        sleepFocus = v("sleepFocus", false)
        toggleKey = v("toggleKey", 40)       // K
        toggleMods = v("toggleMods", HotkeyFormat.control | HotkeyFormat.option | HotkeyFormat.cmd)
        nextKey = v("nextKey", 45)           // N
        nextMods = v("nextMods", HotkeyFormat.control | HotkeyFormat.option | HotkeyFormat.cmd)
        onboarded = v("onboarded", false)
        // v2 added studio-recorded switches: move everyone onto one once.
        if d.integer(forKey: "soundsVersion") < 2 {
            switchID = "cream"; d.set("cream", forKey: "switchID")
            d.set(2, forKey: "soundsVersion")
        }
    }

    var profile: SwitchProfile { SwitchProfile.named(switchID) }

    /// The glass theme is on and this Mac can draw Liquid Glass.
    var useGlass: Bool { glassTheme && GlassTheme.available }

    /// The app was called Thockly before 1.2: bring its settings and stats across once.
    private static func migrateFromThockly(_ d: UserDefaults) {
        guard !d.bool(forKey: "migratedFromThockly") else { return }
        d.set(true, forKey: "migratedFromThockly")
        if let old = UserDefaults(suiteName: "app.thockly.Thockly")?.persistentDomain(forName: "app.thockly.Thockly") {
            for (key, value) in old where d.object(forKey: key) == nil { d.set(value, forKey: key) }
        }
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldStats = support.appendingPathComponent("Thockly/stats.json")
        let newDir = support.appendingPathComponent("Pressly", isDirectory: true)
        let newStats = newDir.appendingPathComponent("stats.json")
        if fm.fileExists(atPath: oldStats.path), !fm.fileExists(atPath: newStats.path) {
            try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: oldStats, to: newStats)
        }
    }

    static let menuIcons = ["keyboard", "keyboard.fill", "pianokeys", "waveform", "music.note", "command", "character.cursor.ibeam", "square.grid.3x3.fill"]
}
