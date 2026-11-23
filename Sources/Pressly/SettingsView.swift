import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, switches, sound, mouse, sleep, apps, shortcuts, stats, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .switches: return "Switches"
        case .sound: return "Sound"
        case .mouse: return "Mouse & Scroll"
        case .sleep: return "Sleep Triggers"
        case .apps: return "Muted Apps"
        case .shortcuts: return "Shortcuts"
        case .stats: return "Stats"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .switches: return "square.grid.3x3.fill"
        case .sound: return "speaker.wave.2.fill"
        case .mouse: return "computermouse.fill"
        case .sleep: return "moon.zzz.fill"
        case .apps: return "app.badge.checkmark"
        case .shortcuts: return "command"
        case .stats: return "chart.bar.fill"
        case .about: return "info.circle.fill"
        }
    }
}

final class SettingsNav: ObservableObject {
    @Published var page: SettingsPage = .general
}

struct SettingsView: View {
    @EnvironmentObject private var nav: SettingsNav
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 0) {
            if settings.useGlass {
                // Liquid Glass: the sidebar floats as an inset glass panel over the window.
                // It runs up under the title bar so the window controls sit inside it.
                sidebar
                    .glassSurface(true, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(8)
                    .ignoresSafeArea(.container, edges: .top)
            } else {
                sidebar
                    .background(.ultraThinMaterial)
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(nav.page.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    page
                }
                .padding(.horizontal, 28)
                .padding(.top, 38)
                .padding(.bottom, 28)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(settings.profile.accentColor)
        .frame(minWidth: 760, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                KeycapView(profile: settings.profile, label: "P", size: 30)
                Text("Pressly").font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.top, settings.useGlass ? 60 : 40)
            .padding(.bottom, 14)

            ForEach(SettingsPage.allCases) { p in
                Button { nav.page = p } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(nav.page == p ? .white : settings.profile.accentColor)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(nav.page == p ? settings.profile.accentColor : settings.profile.accentColor.opacity(0.14)))
                        Text(p.title).font(.system(size: 13, weight: nav.page == p ? .semibold : .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(nav.page == p ? Color.primary.opacity(0.08) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Controller.shared.silenceReason == nil ? Color.green : Color.orange).frame(width: 7, height: 7)
                Text(settings.enabled ? (SleepTriggers.shared.reason ?? "Listening") : "Off").font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .padding(.horizontal, 10)
        .frame(width: settings.useGlass ? 202 : 210)
    }

    @ViewBuilder private var page: some View {
        switch nav.page {
        case .general: GeneralPage()
        case .switches: SwitchesPage()
        case .sound: SoundPage()
        case .mouse: MousePage()
        case .sleep: SleepPage()
        case .apps: AppsPage()
        case .shortcuts: ShortcutsPage()
        case .stats: StatsPage()
        case .about: AboutPage()
        }
    }
}

// MARK: - General

struct GeneralPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var trusted = AXIsProcessTrusted()
    @State private var login = Controller.shared.launchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero
            Card(title: "Live keyboard") {
                LiveKeyboardView(profile: settings.profile)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            Card(title: "App") {
                Row(title: "Accessibility access", subtitle: "Needed to hear your keystrokes in every app.", symbol: "lock.shield") {
                    if trusted { StatusPill(text: "Allowed", good: true) } else {
                        Button("Allow…") { Permissions.requestAccessibility() }
                    }
                }
                RowDivider()
                ToggleRow(title: "Open at login", symbol: "power", isOn: Binding(get: { login }, set: { Controller.shared.launchAtLogin = $0; login = Controller.shared.launchAtLogin }))
                RowDivider()
                ToggleRow(title: "Show pop-up when switching", subtitle: "A small badge when you change switches or turn sounds on or off.", symbol: "rectangle.on.rectangle", isOn: $settings.showSwitchHUD)
                RowDivider()
                ToggleRow(title: "Dynamic app icon", subtitle: "The Dock icon takes on the colour of your switch.", symbol: "app.dashed", isOn: Binding(get: { settings.dynamicIcon }, set: { settings.dynamicIcon = $0; WindowManager.shared.updateDockIcon() }))
                RowDivider()
                if GlassTheme.available {
                    ToggleRow(title: "Liquid Glass theme", subtitle: "Use Liquid Glass for the sidebar, header card and pop-up.", symbol: "drop.halffull", isOn: $settings.glassTheme)
                } else {
                    ToggleRow(title: "Liquid Glass theme", subtitle: "Requires macOS 26.", symbol: "drop.halffull", isOn: .constant(false))
                        .disabled(true)
                }
            }
            Card(title: "Menu bar") {
                ToggleRow(title: "Show menu bar icon", subtitle: "When hidden, open Pressly again from Applications to get back here.", symbol: "menubar.rectangle", isOn: $settings.showMenuIcon)
                RowDivider()
                Row(title: "Icon", symbol: "paintbrush") {
                    HStack(spacing: 4) {
                        ForEach(AppSettings.menuIcons, id: \.self) { name in
                            Button { settings.menuIcon = name } label: {
                                Image(systemName: name).frame(width: 28, height: 24)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(settings.menuIcon == name ? settings.profile.accentColor.opacity(0.25) : Color.primary.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presslyTrustChanged)) { _ in trusted = AXIsProcessTrusted() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in trusted = AXIsProcessTrusted() }
    }

    private var hero: some View {
        HStack(spacing: 22) {
            LiveKeycap(profile: settings.profile, label: settings.profile.capLabel, size: 86)
                .opacity(settings.enabled ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.profile.name).font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(settings.profile.kind.rawValue) · \(settings.profile.blurb)").foregroundStyle(.secondary)
                HStack {
                    Button("Change Switch") { WindowManager.shared.nav.page = .switches }
                    Button("Preview") { SoundEngine.shared.preview(settings.profile, variation: settings.pitchVariation) }
                }
                .padding(.top, 4)
            }
            Spacer()
            VStack(spacing: 6) {
                Toggle("", isOn: $settings.enabled).toggleStyle(.switch).labelsHidden()
                Text(settings.enabled ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .modifier(HeroBackground(accent: settings.profile.accentColor, glass: settings.useGlass))
    }
}

/// The General page's header card: an accent gradient, or tinted Liquid Glass with the glass theme on.
private struct HeroBackground: ViewModifier {
    var accent: Color
    var glass: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if glass {
            content.glassSurface(true, in: shape, tint: accent.opacity(0.18))
        } else {
            content
                .background(shape.fill(LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(shape.strokeBorder(accent.opacity(0.25)))
        }
    }
}

/// A miniature keyboard that lights up as you type anywhere on your Mac.
struct LiveKeyboardView: View {
    var profile: SwitchProfile
    @ObservedObject private var live = LiveKeys.shared

    var body: some View {
        let unit: CGFloat = 34
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(KeyMap.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.code) { key in
                        let on = live.pressed.contains(key.code)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(on ? profile.accentColor : Color.primary.opacity(0.07))
                            .overlay(Text(key.label).font(.system(size: key.label.count > 2 ? 7.5 : 10, weight: .medium, design: .rounded))
                                .foregroundStyle(on ? Color.white : Color.secondary))
                            .frame(width: unit * key.width - 4, height: 26)
                            .scaleEffect(on ? 0.92 : 1)
                            .animation(.easeOut(duration: 0.08), value: on)
                    }
                }
            }
        }
    }
}

// MARK: - Switches

struct SwitchesPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var tryText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Studio recordings of real mechanical switches, with separate press and release takes for each keyboard row and the big keys.")
                .foregroundStyle(.secondary)
            Card(title: "Try it") {
                TextField("Type here to hear \(settings.profile.name)…", text: $tryText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding(.vertical, 10)
            }
            sectionTitle("Studio Recorded", "Real switches, recorded")
            ForEach(SwitchKind.allCases, id: \.self) { kind in
                let profiles = SwitchProfile.recorded.filter { $0.kind == kind }
                if !profiles.isEmpty { group(kind.rawValue, profiles) }
            }
            Divider().padding(.vertical, 6)
            sectionTitle("Pressly Originals", "Synthesized live on your Mac")
            group(nil, SwitchProfile.synthesized)
        }
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func group(_ title: String?, _ profiles: [SwitchProfile]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                ForEach(profiles) { p in
                    SwitchCard(profile: p, selected: settings.switchID == p.id) {
                        Controller.shared.setSwitch(p.id, announce: false)
                        SoundEngine.shared.preview(p, variation: settings.pitchVariation)
                    }
                }
            }
        }
    }
}

struct SwitchCard: View {
    var profile: SwitchProfile
    var selected: Bool
    var action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressed = false }
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    KeycapView(profile: profile, label: profile.capLabel, size: 48, pressed: pressed)
                    Spacer()
                    if profile.isRecorded {
                        Image(systemName: "waveform").font(.system(size: 11, weight: .semibold)).foregroundStyle(profile.accentColor)
                            .help("Studio recording")
                    }
                    if profile.isNew {
                        Text("NEW").font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(profile.accentColor)).foregroundStyle(.white)
                    }
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? profile.accentColor : Color.secondary.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(profile.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? profile.accentColor : Color.primary.opacity(hover ? 0.18 : 0.07), lineWidth: selected ? 2 : 1))
            .shadow(color: .black.opacity(hover ? 0.12 : 0.04), radius: hover ? 8 : 3, y: hover ? 4 : 1)
            .offset(y: hover ? -2 : 0)
            .animation(.easeOut(duration: 0.15), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Sound

struct SoundPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var devices = AudioDevices.outputDevices()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card(title: "Volume") {
                Row(title: "Volume", subtitle: "Pressly can't play louder than your Mac's system volume.", symbol: "speaker.wave.2") {
                    Slider(value: $settings.volume, in: 0...1).frame(width: 200)
                    Text("\(Int(settings.volume * 100))%").monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
            }
            Card(title: "Keys") {
                ToggleRow(title: "Key-up sounds", subtitle: "Play the release as well as the press.", symbol: "arrow.up.square", isOn: $settings.keyUpSounds)
                RowDivider()
                ToggleRow(title: "Modifier keys", subtitle: "Shift, Control, Option, Command, Caps Lock and fn.", symbol: "shift", isOn: $settings.modifierSounds)
                RowDivider()
                ToggleRow(title: "Function & media keys", subtitle: "F1–F12, brightness, volume and playback keys.", symbol: "sun.max", isOn: $settings.functionKeySounds)
                RowDivider()
                ToggleRow(title: "Numpad", symbol: "number", isOn: $settings.numpadSounds)
            }
            Card(title: "Character") {
                Row(title: "Randomized pitch", subtitle: "Small pitch changes so repeated keys never sound robotic.", symbol: "dial.medium") {
                    Slider(value: $settings.pitchVariation, in: 0...1).frame(width: 200)
                }
                RowDivider()
                ToggleRow(title: "Spatial audio", subtitle: "Keys on the left sound from the left, keys on the right from the right. Best with headphones.", symbol: "headphones", isOn: $settings.spatialAudio)
                if settings.spatialAudio {
                    RowDivider()
                    Row(title: "Stereo width", symbol: "arrow.left.and.right") {
                        Slider(value: $settings.spatialWidth, in: 0.1...1).frame(width: 200)
                    }
                }
            }
            Card(title: "Output") {
                Row(title: "Play through", symbol: "hifispeaker") {
                    Picker("", selection: $settings.outputDeviceUID) {
                        Text("System Output").tag("")
                        ForEach(devices) { Text($0.name).tag($0.uid) }
                    }
                    .labelsHidden().frame(width: 220)
                }
                RowDivider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Play on these outputs").padding(.top, 8)
                    Text("Turn an output off to keep Pressly silent whenever sound goes there, such as your speakers in the office.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(devices) { d in
                        Toggle(d.name, isOn: Binding(
                            get: { !settings.silentOutputUIDs.contains(d.uid) },
                            set: { on in
                                settings.silentOutputUIDs.removeAll { $0 == d.uid }
                                if !on { settings.silentOutputUIDs.append(d.uid) }
                            }))
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .onAppear { devices = AudioDevices.outputDevices() }
    }
}

// MARK: - Mouse

struct MousePage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card(title: "Mouse") {
                ToggleRow(title: "Click sounds", subtitle: "A crisp switch click for every mouse and trackpad click.", symbol: "cursorarrow.click", isOn: $settings.mouseClicks)
                RowDivider()
                ToggleRow(title: "Scroll ticks", subtitle: "A soft detent tick as you scroll, like a notched wheel.", symbol: "scroll", isOn: $settings.scrollSounds)
                RowDivider()
                ToggleRow(title: "Haptic ticks", subtitle: "Feel each scroll detent on a Force Touch trackpad.", symbol: "hand.tap", isOn: $settings.scrollHaptics)
                RowDivider()
                Row(title: "Mouse & scroll volume", symbol: "speaker.wave.1") {
                    Slider(value: $settings.mouseVolume, in: 0...1).frame(width: 200)
                }
            }
            Button("Test Click") { SoundEngine.shared.play(.mouseDown, gain: Float(settings.mouseVolume)) }
        }
    }
}

// MARK: - Sleep

struct SleepPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var triggers = SleepTriggers.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: triggers.isSleeping ? "moon.zzz.fill" : "sun.max.fill")
                    .font(.system(size: 22)).foregroundStyle(triggers.isSleeping ? Color.indigo : Color.orange)
                VStack(alignment: .leading) {
                    Text(triggers.isSleeping ? "Sleeping" : "Awake").font(.headline)
                    Text(triggers.reason ?? "Pressly goes quiet on its own when one of these is happening.").foregroundStyle(.secondary).font(.callout)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))

            Card(title: "Go quiet while") {
                ToggleRow(title: "Gaming", subtitle: "A game is the frontmost app.", symbol: "gamecontroller", isOn: $settings.sleepGaming)
                RowDivider()
                ToggleRow(title: "Screen sharing", subtitle: "Sharing your screen in Zoom, or someone is viewing this Mac with Screen Sharing.", symbol: "rectangle.inset.filled.and.person.filled", isOn: $settings.sleepScreenShare)
                RowDivider()
                ToggleRow(title: "Media playing", subtitle: "Another app is playing audio: music, videos or calls.", symbol: "play.circle", isOn: $settings.sleepMedia)
                RowDivider()
                ToggleRow(title: "In a meeting", subtitle: calendarSubtitle, symbol: "calendar", isOn: Binding(get: { settings.sleepCalendar }, set: { on in
                    settings.sleepCalendar = on
                    if on { triggers.requestCalendarAccess() }
                }))
                RowDivider()
                ToggleRow(title: "Focus is on", subtitle: focusSubtitle, symbol: "moon", isOn: $settings.sleepFocus)
                if settings.sleepFocus && !triggers.focusReadable {
                    Button("Open Full Disk Access Settings") { Permissions.openFullDiskAccess() }.padding(.bottom, 8)
                }
            }
        }
    }

    private var calendarSubtitle: String {
        switch triggers.calendarAccess {
        case .fullAccess: return "A busy calendar event is happening now."
        case .denied, .restricted: return "Calendar access was declined. Allow it in System Settings → Privacy & Security → Calendars."
        default: return "A busy calendar event is happening now. Asks for calendar access."
        }
    }

    private var focusSubtitle: String {
        triggers.focusReadable || !settings.sleepFocus
            ? "Do Not Disturb or any other Focus is turned on."
            : "Needs Full Disk Access to see your Focus. Add Pressly in System Settings → Privacy & Security → Full Disk Access."
    }
}

// MARK: - Apps

struct AppsPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pressly stays silent while any of these apps is in front.").foregroundStyle(.secondary)
            Card {
                if settings.mutedApps.isEmpty {
                    Text("No muted apps yet.").foregroundStyle(.secondary).padding(.vertical, 14)
                }
                ForEach(settings.mutedApps, id: \.self) { id in
                    HStack(spacing: 10) {
                        Image(nsImage: AppInfo.icon(id)).resizable().frame(width: 26, height: 26)
                        Text(AppInfo.name(id))
                        Spacer()
                        Button { settings.mutedApps.removeAll { $0 == id } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                    }
                    .padding(.vertical, 7)
                    if id != settings.mutedApps.last { RowDivider() }
                }
            }
            HStack {
                Button("Add App…") { addFromPanel() }
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? "App") { add(app.bundleIdentifier) }
                    }
                }
                .fixedSize()
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func add(_ id: String?) {
        guard let id, !settings.mutedApps.contains(id) else { return }
        settings.mutedApps.append(id)
    }

    private func addFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls { add(Bundle(url: url)?.bundleIdentifier) }
        }
    }
}

enum AppInfo {
    static func url(_ id: String) -> URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) }
    static func name(_ id: String) -> String { url(id).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? id }
    static func icon(_ id: String) -> NSImage { url(id).map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)! }
}

// MARK: - Shortcuts

struct ShortcutsPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card(title: "Keyboard shortcuts") {
                Row(title: "Turn sounds on or off", symbol: "power") {
                    HotkeyRecorder(code: $settings.toggleKey, mods: $settings.toggleMods)
                }
                RowDivider()
                Row(title: "Next switch", symbol: "arrow.right.square") {
                    HotkeyRecorder(code: $settings.nextKey, mods: $settings.nextMods)
                }
            }
            Card(title: "Links") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use these in Shortcuts, Raycast, Alfred or a Stream Deck.").font(.caption).foregroundStyle(.secondary)
                    ForEach(["pressly://toggle", "pressly://on", "pressly://off", "pressly://next", "pressly://switch/midnight", "pressly://settings"], id: \.self) { link in
                        Text(link).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    }
                }
                .padding(.vertical, 10)
            }
            Card(title: "AppleScript") {
                Text("""
                tell application "Pressly"
                    set enabled to true
                    set current switch to "Skylark"
                    set sound volume to 60
                    keystrokes today
                    toggle sounds
                    next switch
                end tell
                """)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, 10)
            }
        }
    }
}

struct HotkeyRecorder: View {
    @Binding var code: Int
    @Binding var mods: Int
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button { recording ? stop() : begin() } label: {
                Text(recording ? "Type shortcut…" : HotkeyFormat.string(code: code, mods: mods))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 110)
            }
            if code >= 0 && !recording {
                Button { code = -1 } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
        }
        .onDisappear { stop() }
    }

    private func begin() {
        recording = true
        Controller.shared.suspendHotKeys()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }
            let m = HotkeyFormat.carbon(from: e.modifierFlags)
            guard m != 0 else { NSSound.beep(); return nil }
            code = Int(e.keyCode)
            mods = m
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording {
            recording = false
            Controller.shared.registerHotKeys()
        }
    }
}

// MARK: - Stats

struct StatsPage: View {
    @ObservedObject private var stats = Stats.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var confirmReset = false

    var body: some View {
        let today = stats.today
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                tile("Keystrokes today", today.keys, "keyboard")
                tile("Words today", today.words, "text.word.spacing")
                tile("Clicks today", today.clicks, "cursorarrow.click")
            }
            Card(title: "Last 14 days") {
                Chart(stats.lastDays(14), id: \.date) { item in
                    BarMark(x: .value("Day", item.date, unit: .day), y: .value("Keystrokes", item.stat.keys))
                        .foregroundStyle(settings.profile.accentColor.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 180)
                .padding(.vertical, 12)
            }
            HStack(alignment: .top, spacing: 12) {
                Card(title: "All time") {
                    statRow("Keystrokes", stats.totalKeys.formatted())
                    RowDivider()
                    statRow("Words", stats.totalWords.formatted())
                    RowDivider()
                    statRow("Clicks", stats.totalClicks.formatted())
                    RowDivider()
                    statRow("Best day", stats.bestDay.map { "\($0.1.formatted()) keys" } ?? "—")
                    RowDivider()
                    statRow("Counting since", stats.since.formatted(date: .abbreviated, time: .omitted))
                }
                Card(title: "Most pressed") {
                    let top = stats.topKeys(6)
                    if top.isEmpty { Text("Start typing!").foregroundStyle(.secondary).padding(.vertical, 10) }
                    ForEach(Array(top.enumerated()), id: \.offset) { i, k in
                        statRow(k.label, k.count.formatted())
                        if i < top.count - 1 { RowDivider() }
                    }
                }
            }
            HStack {
                Text("Stats stay on this Mac and count keys only, never what you type.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Reset Stats…") { confirmReset = true }
            }
        }
        .confirmationDialog("Reset all typing stats?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { stats.reset() }
        } message: { Text("This can't be undone.") }
    }

    private func tile(_ title: String, _ value: Int, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(settings.profile.accentColor)
            Text(value.formatted()).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).monospacedDigit().foregroundStyle(.secondary) }.padding(.vertical, 7)
    }
}

// MARK: - About

struct AboutPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                HStack(spacing: -10) {
                    ForEach(SwitchProfile.all.prefix(5)) { p in KeycapView(profile: p, label: p.capLabel, size: 44) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pressly").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")").foregroundStyle(.secondary)
                }
            }
            Card {
                Text("Mechanical keyboard sounds for every keystroke. Nothing you type is recorded, uploaded or tracked.")
                    .padding(.vertical, 10)
                RowDivider()
                Text("Studio-recorded switches come from the open-source projects Mechanical Keyboard Simulator (kbsim) by Thomas Lai and Mechvibes by Hải Nguyễn, used under the MIT License.")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 10)
                RowDivider()
                HStack {
                    Button("Show Welcome Screen") { WindowManager.shared.showOnboarding() }
                    Button("Sound Credits & Licenses") {
                        if let url = Recordings.root?.appendingPathComponent("CREDITS.txt") { NSWorkspace.shared.open(url) }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }
}

enum Permissions {
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    static func openFullDiskAccess() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
}
