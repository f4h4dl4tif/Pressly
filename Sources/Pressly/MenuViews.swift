import SwiftUI

/// The top of the menu bar menu: current switch, status and the master switch.
struct MenuHeaderView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var triggers = SleepTriggers.shared

    var body: some View {
        let p = settings.profile
        HStack(spacing: 12) {
            LiveKeycap(profile: p, label: p.capLabel, size: 40)
                .opacity(settings.enabled ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pressly").font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $settings.enabled).toggleStyle(.switch).labelsHidden().controlSize(.small).tint(p.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6).padding(.bottom, 4)
    }

    private var status: String {
        if !settings.enabled { return "Off · \(HotkeyFormat.string(code: settings.toggleKey, mods: settings.toggleMods)) to turn on" }
        if let r = triggers.reason { return "Sleeping · \(r)" }
        return "\(settings.profile.name) · \(settings.profile.kind.rawValue)"
    }
}

struct MenuVolumeView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(.secondary)
            Slider(value: $settings.volume, in: 0...1).controlSize(.small).tint(settings.profile.accentColor)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
    }
}
