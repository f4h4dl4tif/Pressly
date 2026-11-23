import AppKit
import AVFoundation

// `Pressly --render-samples <dir>` writes every switch's sounds as WAV files and exits (for testing).
if let i = CommandLine.arguments.firstIndex(of: "--render-samples"), i + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let format = SoundEngine.shared.format
    for p in SwitchProfile.all {
        let bank = SoundEngine.buildBank(p, variation: 0.5, format: format)
        for cat in SoundCategory.allCases {
            for up in [false, true] {
                guard let b = bank[.key(cat, up: up)]?.first else { continue }
                let n = Int(b.frameLength)
                let data = UnsafeBufferPointer(start: b.floatChannelData![0], count: n)
                let peak = data.reduce(Float(0)) { max($0, abs($1)) }
                let finite = data.allSatisfy { $0.isFinite }
                print("\(p.id)\t\(cat)\t\(up ? "up" : "down")\tframes=\(n)\tpeak=\(String(format: "%.3f", peak))\tfinite=\(finite)")
                let url = dir.appendingPathComponent("\(p.id)-\(cat)-\(up ? "up" : "down").wav")
                if let f = try? AVAudioFile(forWriting: url, settings: format.settings) { try? f.write(from: b) }
            }
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
