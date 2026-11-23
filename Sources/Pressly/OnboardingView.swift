import SwiftUI

struct OnboardingView: View {
    var finish: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var step = 0
    @State private var trusted = AXIsProcessTrusted()
    @State private var login = Controller.shared.launchAtLogin

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: permission
                case 2: pick
                default: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule().fill(i == step ? settings.profile.accentColor : Color.primary.opacity(0.15))
                            .frame(width: i == step ? 18 : 7, height: 7)
                    }
                }
                Spacer()
                if step > 0 && step < 3 { Button("Back") { go(step - 1) } }
                Button(nextTitle) { step == 3 ? complete() : go(step + 1) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == 1 && !trusted)
                if step == 1 && !trusted { Button("Skip") { go(2) } }
            }
            .padding(20)
        }
        .frame(width: 640, height: 520)
        .tint(settings.profile.accentColor)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in trusted = AXIsProcessTrusted() }
    }

    private var nextTitle: String {
        switch step {
        case 0: return "Get Started"
        case 3: return "Start Typing"
        default: return "Continue"
        }
    }

    private func go(_ s: Int) { withAnimation(.easeInOut(duration: 0.25)) { step = s } }

    private func complete() {
        settings.onboarded = true
        finish()
    }

    private var welcome: some View {
        VStack(spacing: 26) {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: 10) {
                    ForEach(Array(SwitchProfile.all.prefix(7).enumerated()), id: \.offset) { i, p in
                        let phase = (t * 1.6 - Double(i) * 0.22).truncatingRemainder(dividingBy: 2.4)
                        KeycapView(profile: p, label: String(Array("PRESSLY")[i]), size: 58, pressed: phase > 0 && phase < 0.18)
                    }
                }
            }
            .frame(height: 90)
            VStack(spacing: 8) {
                Text("Welcome to Pressly").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("The feel of a mechanical keyboard, on any keyboard.\nPick a switch, and every key you press sounds the part.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 30)
    }

    private var permission: some View {
        VStack(spacing: 22) {
            Image(systemName: trusted ? "checkmark.shield.fill" : "lock.shield.fill")
                .font(.system(size: 56)).foregroundStyle(trusted ? Color.green : settings.profile.accentColor)
                .contentTransition(.symbolEffect(.replace))
            VStack(spacing: 8) {
                Text("Let Pressly hear your keys").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("macOS needs your OK before an app can react to key presses in other apps. Pressly only looks at which key was pressed, never what you type, and password fields are hidden from it.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
            }
            if trusted {
                StatusPill(text: "Accessibility allowed", good: true)
            } else {
                VStack(spacing: 10) {
                    Button("Open Accessibility Settings") { Permissions.requestAccessibility() }.controlSize(.large)
                    Text("Switch on Pressly in Privacy & Security → Accessibility, then come back.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 30)
    }

    private var pick: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Choose your switch").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Real, studio-recorded switches. Click one to hear it; change it any time from the menu bar.").foregroundStyle(.secondary)
            }
            .padding(.top, 26)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 14) {
                ForEach(SwitchProfile.recorded) { p in
                    Button {
                        Controller.shared.setSwitch(p.id, announce: false)
                        SoundEngine.shared.preview(p, variation: settings.pitchVariation)
                    } label: {
                        VStack(spacing: 6) {
                            KeycapView(profile: p, label: p.capLabel, size: 44, pressed: settings.switchID == p.id)
                            Text(p.name).font(.system(size: 11, weight: settings.switchID == p.id ? .bold : .regular, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(p.kind.rawValue).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(settings.switchID == p.id ? p.accentColor.opacity(0.18) : Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var done: some View {
        VStack(spacing: 22) {
            LiveKeycap(profile: settings.profile, label: settings.profile.capLabel, size: 90)
            VStack(spacing: 8) {
                Text("You're all set").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Pressly lives in your menu bar. Turn it on or off any time with \(HotkeyFormat.string(code: settings.toggleKey, mods: settings.toggleMods)).")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 440)
            }
            Toggle("Open Pressly at login", isOn: Binding(get: { login }, set: { Controller.shared.launchAtLogin = $0; login = Controller.shared.launchAtLogin }))
                .toggleStyle(.checkbox)
        }
        .padding(.top, 36)
    }
}
