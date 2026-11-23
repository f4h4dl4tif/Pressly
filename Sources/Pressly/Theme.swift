import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
    func shade(_ f: CGFloat) -> NSColor { blended(withFraction: f, of: .black) ?? self }
    func tint(_ f: CGFloat) -> NSColor { blended(withFraction: f, of: .white) ?? self }
}

extension Color {
    init(hex: String) { self.init(nsColor: NSColor(hex: hex)) }
}

extension SwitchProfile {
    var capColor: NSColor { NSColor(hex: cap) }
    var accentColor: Color { Color(hex: accent) }
}

/// A sculpted keycap: dark skirt, lighter dished top, legend, and a press animation.
struct KeycapView: View {
    var profile: SwitchProfile
    var label: String = ""
    var size: CGFloat = 64
    var pressed = false
    var widthUnits: CGFloat = 1

    var body: some View {
        let cap = profile.capColor
        let w = size * widthUnits
        let r = size * 0.2
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: r)
                .fill(Color.black.opacity(0.28))
                .frame(width: w, height: size)
                .offset(y: pressed ? size * 0.03 : size * 0.08)
                .blur(radius: size * 0.06)
            RoundedRectangle(cornerRadius: r)
                .fill(LinearGradient(colors: [Color(nsColor: cap.shade(0.1)), Color(nsColor: cap.shade(0.34))], startPoint: .top, endPoint: .bottom))
                .frame(width: w, height: size)
            RoundedRectangle(cornerRadius: r * 0.75)
                .fill(LinearGradient(colors: [Color(nsColor: cap.tint(0.22)), Color(nsColor: cap)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: r * 0.75).strokeBorder(Color.white.opacity(0.28), lineWidth: max(0.5, size * 0.012)))
                .frame(width: w - size * 0.24, height: size * 0.7)
                .overlay(
                    Text(label)
                        .font(.system(size: size * (label.count > 2 ? 0.16 : 0.27), weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: profile.legend))
                )
                .offset(y: size * 0.05)
        }
        .frame(width: w, height: size * 1.08, alignment: .top)
        .offset(y: pressed ? size * 0.05 : 0)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(response: 0.12, dampingFraction: 0.55), value: pressed)
    }
}

/// A keycap that dips whenever a key is pressed anywhere.
struct LiveKeycap: View {
    var profile: SwitchProfile
    var label: String
    var size: CGFloat
    @ObservedObject private var live = LiveKeys.shared
    @State private var down = false

    var body: some View {
        KeycapView(profile: profile, label: label, size: size, pressed: down)
            .onChange(of: live.presses) {
                down = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { down = false }
            }
    }
}

/// Grouped container used throughout Settings.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
        }
    }
}

struct Row<Control: View>: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 8)
    }
}

struct RowDivider: View {
    var body: some View { Divider().opacity(0.6) }
}

struct ToggleRow: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Row(title: title, subtitle: subtitle, symbol: symbol) {
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
    }
}

/// Pill-shaped status indicator.
struct StatusPill: View {
    var text: String
    var good: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(good ? Color.green : Color.orange).frame(width: 7, height: 7)
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

/// Renders a keycap as an image (for the Dock icon while Settings is open).
@MainActor
func keycapIcon(_ profile: SwitchProfile) -> NSImage? {
    let view = ZStack {
        RoundedRectangle(cornerRadius: 230, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#34353B"), Color(hex: "#1B1C20")], startPoint: .top, endPoint: .bottom))
            .frame(width: 824, height: 824)
        KeycapView(profile: profile, label: "", size: 470)
            .offset(y: 10)
    }
    .frame(width: 1024, height: 1024)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    return renderer.nsImage
}
