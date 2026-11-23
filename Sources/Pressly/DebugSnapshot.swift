#if DEBUG
import AppKit

/// Debug builds only: `Pressly --snapshot <dir>` renders the onboarding window and every Settings page to PNGs, then quits.
enum DebugSnapshot {
    static func runIfRequested() {
        guard let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count else { return }
        let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var steps: [() -> Void] = []
        steps.append { WindowManager.shared.showOnboarding() }
        steps.append { capture("onboarding", dir); NSApp.windows.forEach { $0.close() } }
        for page in SettingsPage.allCases {
            steps.append { WindowManager.shared.showSettings(page) }
            steps.append { capture("settings-\(page.rawValue)", dir) }
        }
        steps.append { exit(0) }
        for (n, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(n) * 0.8, execute: step)
        }
    }

    // MARK: Liquid Glass

    typealias CapFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    /// Captures a real on-screen window (cacheDisplay can't draw Liquid Glass). `below` also includes
    /// this app's windows underneath it (the backdrop), cropped to `rect` (global, top-left origin).
    static func captureWindow(_ w: NSWindow, below: Bool = false, rect: CGRect = .null, to url: URL) {
        let f = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage"), to: CapFn.self)
        guard let img = f(rect, below ? (4 | 8) : (1 | 8), UInt32(w.windowNumber), 1 | 8)?.takeRetainedValue(),
              let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { print("capture failed \(url.lastPathComponent)"); return }
        try? png.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }

    /// Debug builds only: `Pressly --glass-snapshot <dir>` captures Settings pages and the pop-up with the
    /// Liquid Glass theme off and on, in light and dark, then restores the saved setting and quits.
    static func runGlassIfRequested() -> Bool {
        guard let i = CommandLine.arguments.firstIndex(of: "--glass-snapshot"), i + 1 < CommandLine.arguments.count else { return false }
        let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let s = AppSettings.shared
        let d = UserDefaults.standard
        let saved = d.object(forKey: "glassTheme"), savedHUD = d.object(forKey: "showSwitchHUD")
        let origGlass = s.glassTheme, origHUD = s.showSwitchHUD
        let pages: [SettingsPage] = [.general, .switches, .sound, .stats]
        var steps: [() -> Void] = []
        var backdrop: NSWindow?
        for dark in [false, true] {
            for glass in [false, true] {
                let suffix = "\(glass ? "glass" : "plain")-\(dark ? "dark" : "light")"
                steps.append {
                    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    s.glassTheme = glass
                }
                for page in pages {
                    steps.append { WindowManager.shared.showSettings(page) }
                    steps.append {
                        if let w = NSApp.windows.first(where: { $0.title == "Pressly Settings" }) {
                            let primaryH = NSScreen.screens.first?.frame.height ?? 0
                            let r = CGRect(x: w.frame.minX, y: primaryH - w.frame.maxY, width: w.frame.width, height: w.frame.height)
                            captureWindow(w, rect: r, to: dir.appendingPathComponent("settings-\(page.rawValue)-\(suffix).png"))
                        }
                    }
                }
                steps.append {
                    NSApp.windows.first(where: { $0.title == "Pressly Settings" })?.orderOut(nil)
                    let screen = NSScreen.main!
                    let b = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    b.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
                    b.contentView = NSHostingView(rootView: GlassBackdrop(dark: dark))
                    b.setFrame(screen.frame, display: true)
                    b.orderFrontRegardless()
                    backdrop = b
                    s.showSwitchHUD = true
                    HUD.shared.showSwitch(s.profile)
                }
                steps.append {
                    if let p = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible }) {
                        let primaryH = NSScreen.screens.first?.frame.height ?? 0
                        let r = p.frame.insetBy(dx: -30, dy: -30)
                        let cg = CGRect(x: r.minX, y: primaryH - r.maxY, width: r.width, height: r.height)
                        captureWindow(p, below: true, rect: cg, to: dir.appendingPathComponent("hud-\(suffix).png"))
                    }
                    backdrop?.orderOut(nil)
                }
            }
        }
        steps.append {
            s.glassTheme = origGlass; s.showSwitchHUD = origHUD
            if let saved { d.set(saved, forKey: "glassTheme") } else { d.removeObject(forKey: "glassTheme") }
            if let savedHUD { d.set(savedHUD, forKey: "showSwitchHUD") } else { d.removeObject(forKey: "showSwitchHUD") }
            d.synchronize()
            exit(0)
        }
        for (n, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(n) * 1.0, execute: step)
        }
        return true
    }

    private static func capture(_ name: String, _ dir: URL) {
        guard let w = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil && $0.frame.width > 300 }),
              let view = w.contentView?.superview ?? w.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
import SwiftUI

/// Busy light/dark content for the glass snapshot to refract.
private struct GlassBackdrop: View {
    let dark: Bool
    var body: some View {
        ZStack {
            (dark ? Color(white: 0.11) : Color(white: 0.96))
            GeometryReader { g in
                ForEach(0..<24, id: \.self) { i in
                    Circle().fill([Color.blue, .orange, .green, .pink, .purple, .yellow][i % 6].opacity(dark ? 0.55 : 0.7))
                        .frame(width: 260, height: 260)
                        .position(x: CGFloat((i * 397) % Int(max(g.size.width, 1))), y: CGFloat((i * 241) % Int(max(g.size.height, 1))))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<60, id: \.self) { i in
                    Text(String(repeating: "The quick brown fox jumps over the lazy dog \(i). ", count: 6))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(dark ? .white.opacity(0.85) : .black.opacity(0.85))
                        .lineLimit(1).fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
    }
}
#endif
