import Foundation

// Procedural keyboard-sound synthesis. Every sound in Pressly is generated here at runtime:
// a keystroke is a few "layers" (a click transient, a bottom-out hit), each a sum of damped
// resonant modes plus a burst of band-passed noise.

struct Mode {
    var f: Double       // frequency in Hz
    var decay: Double   // time constant in seconds
    var amp: Double
    init(_ f: Double, _ decay: Double, _ amp: Double) { self.f = f; self.decay = decay; self.amp = amp }
}

struct Layer {
    var delay: Double = 0
    var modes: [Mode] = []
    var noise: Double = 0
    var noiseFreq: Double = 2000
    var noiseQ: Double = 1
    var noiseDecay: Double = 0.005
}

func L(_ delay: Double, _ modes: [Mode], _ noise: Double = 0, _ nf: Double = 2000, _ nq: Double = 1, _ nd: Double = 0.005) -> Layer {
    Layer(delay: delay, modes: modes, noise: noise, noiseFreq: nf, noiseQ: nq, noiseDecay: nd)
}

struct Stroke {
    var layers: [Layer]
    var length: Double = 0.12
    var lowpass: Double = 12000
    var highpass: Double = 70
    var gain: Double = 1

    func scaled(freq: Double = 1, decay: Double = 1, gain g: Double = 1, length len: Double = 1) -> Stroke {
        var s = self
        s.layers = layers.map { l in
            var l = l
            l.modes = l.modes.map { Mode($0.f * freq, $0.decay * decay, $0.amp) }
            l.noiseFreq *= freq
            l.noiseDecay *= decay
            return l
        }
        s.gain *= g
        s.length *= len
        return s
    }

    func adding(_ layer: Layer) -> Stroke {
        var s = self
        s.layers.append(layer)
        return s
    }
}

struct RNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func bipolar() -> Double { unit() * 2 - 1 }
}

struct Biquad {
    var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var z1 = 0.0, z2 = 0.0

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    private static func make(_ b0: Double, _ b1: Double, _ b2: Double, _ a0: Double, _ a1: Double, _ a2: Double) -> Biquad {
        Biquad(b0: b0 / a0, b1: b1 / a0, b2: b2 / a0, a1: a1 / a0, a2: a2 / a0)
    }

    static func bandpass(_ f: Double, q: Double, sr: Double) -> Biquad {
        let w = 2 * Double.pi * f / sr, alpha = sin(w) / (2 * q), c = cos(w)
        return make(alpha, 0, -alpha, 1 + alpha, -2 * c, 1 - alpha)
    }

    static func lowpass(_ f: Double, q: Double = 0.707, sr: Double) -> Biquad {
        let w = 2 * Double.pi * f / sr, alpha = sin(w) / (2 * q), c = cos(w)
        return make((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + alpha, -2 * c, 1 - alpha)
    }

    static func highpass(_ f: Double, q: Double = 0.707, sr: Double) -> Biquad {
        let w = 2 * Double.pi * f / sr, alpha = sin(w) / (2 * q), c = cos(w)
        return make((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + alpha, -2 * c, 1 - alpha)
    }
}

enum Synth {
    static let sampleRate = 48000.0

    /// Renders one stroke. `pitch` scales every frequency; `seed` drives the small random
    /// differences that keep two presses of the same key from sounding identical.
    static func render(_ s: Stroke, pitch: Double, seed: UInt64) -> [Float] {
        var rng = RNG(seed: seed)
        let sr = sampleRate
        let n = max(64, Int(s.length * sr))
        var out = [Double](repeating: 0, count: n)

        for layer in s.layers {
            let start = Int(max(0, layer.delay * (1 + rng.bipolar() * 0.12)) * sr)
            guard start < n else { continue }

            for m in layer.modes {
                let f = m.f * pitch * (1 + rng.bipolar() * 0.015)
                guard f > 20, f < sr * 0.45 else { continue }
                let a = m.amp * (1 + rng.bipolar() * 0.15)
                let tau = max(0.0003, m.decay * (1 + rng.bipolar() * 0.1))
                let phase = rng.unit() * 2 * Double.pi
                let w = 2 * Double.pi * f / sr
                let k = exp(-1 / (tau * sr))
                let attack = 0.0004 * sr
                var env = 1.0
                var i = 0
                while start + i < n && env > 1e-4 {
                    out[start + i] += a * env * min(1, Double(i) / attack) * sin(w * Double(i) + phase)
                    env *= k
                    i += 1
                }
            }

            if layer.noise > 0 {
                var bp = Biquad.bandpass(min(layer.noiseFreq * pitch, sr * 0.45), q: layer.noiseQ, sr: sr)
                let k = exp(-1 / (max(0.0002, layer.noiseDecay * (1 + rng.bipolar() * 0.15)) * sr))
                let attack = 0.00015 * sr
                var burst: [Double] = []
                var env = 1.0
                var i = 0
                while start + i < n && env > 1e-4 {
                    burst.append(bp.process(rng.bipolar()) * env * min(1, Double(i) / attack))
                    env *= k
                    i += 1
                }
                let peak = burst.reduce(0) { max($0, abs($1)) }
                if peak > 0 {
                    let g = layer.noise * (1 + rng.bipolar() * 0.12) / peak
                    for (j, v) in burst.enumerated() { out[start + j] += v * g }
                }
            }
        }

        var hp = Biquad.highpass(s.highpass, sr: sr)
        var lp = Biquad.lowpass(min(s.lowpass, sr * 0.45), sr: sr)
        for i in 0..<n { out[i] = lp.process(hp.process(out[i])) }

        let fade = min(n, Int(0.004 * sr))
        for j in 0..<fade { out[n - 1 - j] *= Double(j) / Double(fade) }

        let peak = out.reduce(0) { max($0, abs($1)) }
        let target = 0.9 * s.gain * (0.86 + rng.unit() * 0.14)
        let g = peak > 0 ? target / peak : 0
        return out.map { Float($0 * g) }
    }
}
