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

    private static func capture(_ name: String, _ dir: URL) {
        guard let w = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil && $0.frame.width > 300 }),
              let view = w.contentView?.superview ?? w.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
#endif
