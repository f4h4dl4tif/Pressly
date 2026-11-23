import AVFoundation
import AudioToolbox
import CoreAudio

enum SoundKey: Hashable {
    case key(SoundCategory, up: Bool)
    case row(Int, up: Bool)   // recorded switches: a take per keyboard row
    case mouseDown, mouseUp, scroll
}

typealias SoundBank = [SoundKey: [AVAudioPCMBuffer]]

/// Low-latency playback: a pool of always-running player nodes fed pre-rendered buffers.
final class SoundEngine {
    static let shared = SoundEngine()

    static let variants = 8
    let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var bank: SoundBank = [:]
    private var effects: SoundBank = [:]
    private var lastVariant: [SoundKey: Int] = [:]
    private let queue = DispatchQueue(label: "app.pressly.synth", qos: .userInitiated)
    private var buildToken = 0
    private var previewCache: [String: SoundBank] = [:]
    private var previewTimers: [Timer] = []

    var deviceUID = "" {
        didSet { if deviceUID != oldValue { restart() } }
    }

    private init() {
        for _ in 0..<24 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.restart()
        }
        AudioDevices.onChange { [weak self] in
            guard let self, self.deviceUID.isEmpty || AudioDevices.deviceID(forUID: self.deviceUID) == nil else { return }
            self.restart()
        }
    }

    // MARK: Engine

    func start() {
        applyDevice()
        engine.prepare()
        do { try engine.start() } catch { NSLog("Pressly: audio engine failed to start: \(error)") }
        players.forEach { $0.play() }
    }

    func restart() {
        engine.stop()
        start()
    }

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    /// The device sounds are going to: the chosen one, or the system output.
    var activeDeviceUID: String {
        if !deviceUID.isEmpty, AudioDevices.deviceID(forUID: deviceUID) != nil { return deviceUID }
        return AudioDevices.uid(of: AudioDevices.defaultOutputID())
    }

    private func applyDevice() {
        guard let unit = engine.outputNode.audioUnit else { return }
        var id = (deviceUID.isEmpty ? nil : AudioDevices.deviceID(forUID: deviceUID)) ?? AudioDevices.defaultOutputID()
        AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        // A small I/O buffer keeps the time from key press to sound short (~5 ms).
        var frames: UInt32 = 256
        AudioUnitSetProperty(unit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &frames, UInt32(MemoryLayout<UInt32>.size))
    }

    // MARK: Banks

    static func buildBank(_ profile: SwitchProfile, variation: Double, format: AVAudioFormat) -> SoundBank {
        if profile.isRecorded { return Recordings.bank(profile, variation: variation, format: format) }
        var out: SoundBank = [:]
        var rng = RNG(seed: profile.id.utf8.reduce(1469598103934665603) { ($0 ^ UInt64($1)) &* 1099511628211 })
        for cat in SoundCategory.allCases {
            for up in [false, true] {
                var list: [AVAudioPCMBuffer] = []
                for v in 0..<variants {
                    let pitch = 1 + rng.bipolar() * 0.07 * variation
                    let stroke = profile.stroke(cat, up: up, variant: v)
                    let samples = Synth.render(stroke, pitch: profile.style == .chime ? 1 : pitch, seed: rng.next())
                    if let b = buffer(samples, format) { list.append(b) }
                }
                out[.key(cat, up: up)] = list
            }
        }
        return out
    }

    static func buildEffects(format: AVAudioFormat) -> SoundBank {
        var rng = RNG(seed: 42)
        func make(_ s: Stroke) -> [AVAudioPCMBuffer] {
            (0..<variants).compactMap { _ in buffer(Synth.render(s, pitch: 1 + rng.bipolar() * 0.05, seed: rng.next()), format) }
        }
        return [.mouseDown: make(SwitchProfile.mouseDown), .mouseUp: make(SwitchProfile.mouseUp), .scroll: make(SwitchProfile.scrollTick)]
    }

    private static func buffer(_ samples: [Float], _ format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in b.floatChannelData![0].update(from: src.baseAddress!, count: samples.count) }
        return b
    }

    func load(profile: SwitchProfile, variation: Double) {
        buildToken += 1
        let token = buildToken
        let format = self.format
        let needEffects = effects.isEmpty
        queue.async {
            let bank = Self.buildBank(profile, variation: variation, format: format)
            let fx = needEffects ? Self.buildEffects(format: format) : nil
            DispatchQueue.main.async {
                guard token == self.buildToken else { return }
                self.bank = bank
                if let fx { self.effects = fx }
                self.previewCache[profile.id + "\(variation)"] = bank
            }
        }
    }

    // MARK: Playback

    func play(_ key: SoundKey, pan: Float = 0, gain: Float = 1) {
        let source: SoundBank
        switch key {
        case .key, .row: source = bank
        default: source = effects
        }
        play(key, from: source, pan: pan, gain: gain)
    }

    private func play(_ key: SoundKey, from source: SoundBank, pan: Float, gain: Float) {
        var key = key
        if case .row(_, let up) = key, source[key] == nil { key = .key(.normal, up: up) }
        guard engine.isRunning, let list = source[key], !list.isEmpty else { return }
        var idx = Int.random(in: 0..<list.count)
        if list.count > 1, idx == lastVariant[key] { idx = (idx + 1) % list.count }
        lastVariant[key] = idx
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.pan = max(-1, min(1, pan))
        p.volume = gain
        p.scheduleBuffer(list[idx], at: nil, options: .interrupts, completionHandler: nil)
        if !p.isPlaying { p.play() }
    }

    /// Types a short phrase with any switch so you can hear it before choosing.
    func preview(_ profile: SwitchProfile, variation: Double) {
        previewTimers.forEach { $0.invalidate() }
        previewTimers.removeAll()
        let cacheKey = profile.id + "\(variation)"
        let bank = previewCache[cacheKey] ?? Self.buildBank(profile, variation: variation, format: format)
        previewCache[cacheKey] = bank
        if !engine.isRunning { start() }

        // "thock it" ⏎ — positions spread across the keyboard.
        let sequence: [(SoundCategory, Double, Double)] = [
            (.normal, 0.36, 0), (.normal, 0.45, 0.13), (.normal, 0.64, 0.24), (.normal, 0.24, 0.36), (.normal, 0.61, 0.47),
            (.space, 0.45, 0.62), (.normal, 0.58, 0.78), (.normal, 0.36, 0.88), (.enter, 0.92, 1.1),
        ]
        for (cat, x, t) in sequence {
            let pan = Float((x - 0.5) * 1.2)
            let down = Timer.scheduledTimer(withTimeInterval: t, repeats: false) { [weak self] _ in
                self?.play(.key(cat, up: false), from: bank, pan: pan, gain: 1)
            }
            let up = Timer.scheduledTimer(withTimeInterval: t + 0.075, repeats: false) { [weak self] _ in
                self?.play(.key(cat, up: true), from: bank, pan: pan, gain: 1)
            }
            previewTimers += [down, up]
        }
    }
}
