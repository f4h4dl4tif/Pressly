import AppKit
import SwiftUI

final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    let nav = SettingsNav()

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showSettings(_ page: SettingsPage? = nil) {
        if let page { nav.page = page }
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "Pressly Settings"
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 760, height: 520)
            let host = NSHostingController(rootView: SettingsView().environmentObject(nav))
            host.sizingOptions = []
            w.contentViewController = host
            w.setContentSize(NSSize(width: 860, height: 600))
            w.center()
            w.setFrameAutosaveName("PresslySettings")
            w.delegate = self
            settingsWindow = w
        }
        present(settingsWindow!)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in self?.onboardingWindow?.close() })
            w.center()
            w.delegate = self
            onboardingWindow = w
        }
        present(onboardingWindow!)
    }

    private func present(_ w: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        updateDockIcon()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The Dock icon (shown while a window is open) takes the colour of the current switch.
    func updateDockIcon() {
        let s = AppSettings.shared
        if s.dynamicIcon, let img = MainActor.assumeIsolated({ keycapIcon(s.profile) }) {
            NSApp.applicationIconImage = img
        } else {
            NSApp.applicationIconImage = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            let anyOpen = [self.settingsWindow, self.onboardingWindow].contains { $0?.isVisible == true }
            if !anyOpen { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

/// A brief floating badge when switching sounds or turning Pressly on/off.
final class HUD {
    static let shared = HUD()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func showSwitch(_ p: SwitchProfile) {
        show(HUDView(profile: p, title: p.name, subtitle: "\(p.kind.rawValue) · \(p.blurb)"))
        SoundEngine.shared.preview(p, variation: AppSettings.shared.pitchVariation)
    }

    func showToggle(_ on: Bool) {
        let p = AppSettings.shared.profile
        show(HUDView(profile: p, title: on ? "Sounds On" : "Sounds Off", subtitle: on ? p.name : "Press the shortcut again to turn back on", dimmed: !on))
    }

    private func show(_ view: HUDView) {
        guard AppSettings.shared.showSwitchHUD else { return }
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        if panel == nil {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .statusBar
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel = p
        }
        guard let panel, let screen = NSScreen.main else { return }
        panel.contentView = host
        let size = host.fittingSize
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + screen.frame.height * 0.16, width: size.width, height: size.height), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; panel?.animator().alphaValue = 0 }) { panel?.orderOut(nil) }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }
}

struct HUDView: View {
    var profile: SwitchProfile
    var title: String
    var subtitle: String
    var dimmed = false

    var body: some View {
        HStack(spacing: 16) {
            KeycapView(profile: profile, label: profile.capLabel, size: 48, pressed: dimmed)
                .opacity(dimmed ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .modifier(HUDBackground(glass: AppSettings.shared.useGlass))
        .padding(20)
    }
}

/// The pop-up's backing: a material card, or Liquid Glass with the glass theme on.
private struct HUDBackground: ViewModifier {
    var glass: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if glass {
            content.glassSurface(true, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
        }
    }
}
