import AVFoundation

/// Loads studio-recorded switch sounds from Resources/Recordings/<id>/{press,release}/.
/// Files: GENERIC_R0…R4 (one per keyboard row), SPACE, ENTER, BACKSPACE. Each take is
/// trimmed, mixed to mono at 48 kHz and loudness-matched across switches, then given a few
/// subtly pitch-shifted copies so fast typing never repeats the exact same sound.
enum Recordings {
    static var root: URL? { Bundle.main.resourceURL?.appendingPathComponent("Recordings", isDirectory: true) }

    private static let targetPeak: Float = 0.8

    static func bank(_ profile: SwitchProfile, variation: Double, format: AVAudioFormat) -> SoundBank {
        guard let folder = profile.recording, let dir = root?.appendingPathComponent(folder) else { return [:] }
        func take(_ group: String, _ name: String) -> [Float]? {
            for ext in ["mp3", "wav", "caf", "m4a"] {
                let url = dir.appendingPathComponent(group).appendingPathComponent("\(name).\(ext)")
                if FileManager.default.fileExists(atPath: url.path), let s = loadMono(url) { return trim(s) }
            }
            return nil
        }

        let rows = (0..<5).map { take("press", "GENERIC_R\($0)") }
        let generic = rows.compactMap { $0 }
        guard !generic.isEmpty else { return [:] }

        // One gain for the whole switch, from the median row peak, keeps press/release balance natural.
        let peaks = generic.map(peak).sorted()
        let gain = targetPeak / max(0.0001, peaks[peaks.count / 2])

        var rng = RNG(seed: folder.utf8.reduce(7) { $0 &* 31 &+ UInt64($1) })
        let copies = 3
        func variants(_ src: [Float], _ g: Float = 1) -> [AVAudioPCMBuffer] {
            // Big keys are naturally louder; let them be, but never push a take past 0.95.
            let level = min(gain * g, 0.95 / max(0.0001, peak(src)))
            return (0..<copies).compactMap { i in
                let pitch = i == 0 ? 1 : 1 + rng.bipolar() * 0.045 * variation
                return buffer(limit(resample(src, by: pitch), level * (1 - Float(rng.unit()) * 0.06)), format)
            }
        }

        var out: SoundBank = [:]
        var allRows: [AVAudioPCMBuffer] = []
        for (r, s) in rows.enumerated() {
            guard let s else { continue }
            let v = variants(s)
            out[.row(r, up: false)] = v
            allRows += v
        }
        out[.key(.normal, up: false)] = allRows
        let bottom = rows[4] ?? generic.last!
        out[.key(.space, up: false)] = variants(take("press", "SPACE") ?? resample(bottom, by: 0.9), 1.05)
        out[.key(.enter, up: false)] = variants(take("press", "ENTER") ?? resample(rows[2] ?? bottom, by: 0.94))
        out[.key(.backspace, up: false)] = variants(take("press", "BACKSPACE") ?? resample(rows[0] ?? bottom, by: 0.95))
        out[.key(.modifier, up: false)] = variants(bottom, 0.8)

        if let release = take("release", "GENERIC") {
            let r = variants(release)
            out[.key(.normal, up: true)] = r
            out[.key(.modifier, up: true)] = variants(release, 0.8)
            out[.key(.space, up: true)] = variants(take("release", "SPACE") ?? release)
            out[.key(.enter, up: true)] = variants(take("release", "ENTER") ?? release)
            out[.key(.backspace, up: true)] = variants(take("release", "BACKSPACE") ?? release)
        }
        return out
    }

    // MARK: DSP helpers

    private static func loadMono(_ url: URL) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let fmt = file.processingFormat
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil, let ch = buf.floatChannelData else { return nil }
        let n = Int(buf.frameLength), channels = Int(fmt.channelCount)
        var mono = [Float](repeating: 0, count: n)
        for c in 0..<channels { for i in 0..<n { mono[i] += ch[c][i] / Float(channels) } }
        // Convert to the engine's sample rate.
        return resample(mono, by: fmt.sampleRate / Synth.sampleRate)
    }

    /// Linear-interpolation resampling. `ratio` > 1 shortens the sound and raises its pitch.
    private static func resample(_ s: [Float], by ratio: Double) -> [Float] {
        guard abs(ratio - 1) > 1e-6, s.count > 1 else { return s }
        let n = max(1, Int(Double(s.count) / ratio))
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let x = Double(i) * ratio
            let j = Int(x)
            let f = Float(x - Double(j))
            let a = s[min(j, s.count - 1)], b = s[min(j + 1, s.count - 1)]
            out[i] = a + (b - a) * f
        }
        return out
    }

    private static func peak(_ s: [Float]) -> Float { s.reduce(0) { max($0, abs($1)) } }

    /// Removes leading/trailing silence (and MP3 padding) so the sound starts right on the key press.
    private static func trim(_ s: [Float]) -> [Float] {
        let p = peak(s)
        guard p > 0 else { return s }
        let sr = Int(Synth.sampleRate)
        let first = s.firstIndex { abs($0) > p * 0.04 } ?? 0
        let last = s.lastIndex { abs($0) > p * 0.004 } ?? (s.count - 1)
        let start = max(0, first - sr / 2000)            // keep 0.5 ms before the attack
        let end = min(s.count, last + sr / 100)          // and 10 ms of tail
        var out = Array(s[start..<max(start + 1, end)])
        let fade = min(out.count, sr / 200)              // 5 ms fade-out
        for i in 0..<fade { out[out.count - 1 - i] *= Float(i) / Float(fade) }
        return out
    }

    private static func limit(_ s: [Float], _ g: Float) -> [Float] {
        s.map { x in
            let y = x * g
            return abs(y) < 0.9 ? y : (y > 0 ? 1 : -1) * (0.9 + 0.1 * tanh((abs(y) - 0.9) / 0.1))
        }
    }

    private static func buffer(_ samples: [Float], _ format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty, let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { b.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        return b
    }
}
