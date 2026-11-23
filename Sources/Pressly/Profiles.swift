import Foundation

enum SoundCategory: Int, CaseIterable {
    case normal, space, enter, backspace, modifier
}

enum SwitchKind: String, CaseIterable {
    case linear = "Linear", tactile = "Tactile", clicky = "Clicky", special = "Special"
}

struct SwitchProfile: Identifiable, Equatable {
    enum Style { case standard, typewriter, chime }

    let id: String
    let name: String
    let kind: SwitchKind
    let blurb: String
    let cap: String      // keycap colour (hex)
    let legend: String   // legend colour (hex)
    let accent: String   // UI accent (hex)
    let down: Stroke
    let up: Stroke
    var style: Style = .standard
    var isNew = false
    /// Folder under Resources/Recordings for studio-recorded switches; nil for synthesized ones.
    var recording: String? = nil
    var label: String? = nil

    var isRecorded: Bool { recording != nil }
    var capLabel: String { label ?? String(name.prefix(1)) }

    static func == (a: SwitchProfile, b: SwitchProfile) -> Bool { a.id == b.id }

    private static let stabilizerRattle = L(0.003, [Mode(140, 0.03, 0.4)], 0.22, 2800, 3, 0.012)

    /// The stroke for a key category. Bigger keys get lower, longer, slightly louder sounds.
    func stroke(_ cat: SoundCategory, up isUp: Bool, variant: Int) -> Stroke {
        if style == .chime { return chime(cat, up: isUp, variant: variant) }
        if style == .typewriter, cat == .enter, !isUp { return Self.typewriterReturn }
        let base = isUp ? up : down
        switch cat {
        case .normal: return base
        case .space: return base.scaled(freq: 0.6, decay: 1.7, gain: 1.1, length: 1.5).adding(Self.stabilizerRattle)
        case .enter: return base.scaled(freq: 0.84, decay: 1.3, gain: 1.06, length: 1.2).adding(Self.stabilizerRattle)
        case .backspace: return base.scaled(freq: 0.9, decay: 1.15, gain: 1.04, length: 1.1)
        case .modifier: return base.scaled(freq: 0.96, decay: 0.9, gain: 0.85)
        }
    }

    private static let typewriterReturn: Stroke = {
        var layers = [L(0, [Mode(2093, 0.55, 1), Mode(5776, 0.25, 0.35), Mode(3140, 0.3, 0.25)], 0.2, 4000, 2, 0.003)]
        for d in [0.07, 0.11, 0.15, 0.19, 0.23] {
            layers.append(L(d, [Mode(1800, 0.003, 0.25)], 0.45, 2500, 1.5, 0.003))
        }
        layers.append(L(0.29, [Mode(180, 0.04, 0.8), Mode(420, 0.02, 0.4)], 0.6, 800, 0.8, 0.02))
        return Stroke(layers: layers, length: 1.1, lowpass: 12000, gain: 1)
    }()

    private static let pentatonic: [Double] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51]

    private func chime(_ cat: SoundCategory, up isUp: Bool, variant: Int) -> Stroke {
        if isUp { return Stroke(layers: [L(0, [], 0.2, 4000, 1, 0.002)], length: 0.03, gain: 0.07) }
        let note = Self.pentatonic[variant % Self.pentatonic.count]
        func tone(_ f: Double, _ a: Double = 1) -> [Mode] {
            [Mode(f, 0.22, a), Mode(f * 2, 0.09, 0.25 * a), Mode(f * 3, 0.05, 0.08 * a)]
        }
        let tap = L(0, [], 0.1, 3000, 1, 0.002)
        switch cat {
        case .normal: return Stroke(layers: [L(0, tone(note)), tap], length: 0.7, lowpass: 9000, gain: 0.75)
        case .space: return Stroke(layers: [L(0, tone(note / 2) + tone(note * 0.75, 0.6)), tap], length: 0.9, lowpass: 8000, gain: 0.8)
        case .enter: return Stroke(layers: [L(0, tone(note)), L(0.06, tone(note * 1.5, 0.8)), tap], length: 0.9, lowpass: 9000, gain: 0.8)
        case .backspace: return Stroke(layers: [L(0, tone(note * 0.47)), tap], length: 0.7, lowpass: 7000, gain: 0.7)
        case .modifier: return Stroke(layers: [L(0, tone(note * 2, 0.7)), tap], length: 0.5, lowpass: 10000, gain: 0.5)
        }
    }

    static let synthesized: [SwitchProfile] = [
        SwitchProfile(
            id: "butter", name: "Butter", kind: .linear, blurb: "Smooth, creamy and deep",
            cap: "#EDE3CC", legend: "#8A6F4E", accent: "#C9A46A",
            down: Stroke(layers: [L(0, [Mode(310, 0.02, 1), Mode(640, 0.013, 0.55), Mode(1180, 0.008, 0.35), Mode(2350, 0.004, 0.18)], 0.55, 1700, 0.9, 0.006)], length: 0.13, lowpass: 7000),
            up: Stroke(layers: [L(0, [Mode(520, 0.008, 0.6), Mode(1400, 0.005, 0.4)], 0.6, 2600, 1.1, 0.004)], length: 0.06, lowpass: 8000, gain: 0.38)),
        SwitchProfile(
            id: "midnight", name: "Midnight", kind: .linear, blurb: "Heavy, muted thock",
            cap: "#2A2B30", legend: "#C9CBD3", accent: "#7F8CFF",
            down: Stroke(layers: [L(0, [Mode(185, 0.032, 1), Mode(410, 0.022, 0.7), Mode(790, 0.012, 0.4), Mode(1650, 0.006, 0.18)], 0.4, 1150, 0.8, 0.008)], length: 0.16, lowpass: 4200),
            up: Stroke(layers: [L(0, [Mode(330, 0.01, 0.6), Mode(900, 0.006, 0.3)], 0.5, 1800, 1, 0.005)], length: 0.07, lowpass: 5000, gain: 0.32)),
        SwitchProfile(
            id: "marble", name: "Marble", kind: .linear, blurb: "Bright, poppy clack",
            cap: "#F4F1EA", legend: "#5E6B7A", accent: "#E0B04F",
            down: Stroke(layers: [L(0, [Mode(540, 0.012, 0.8), Mode(1280, 0.009, 0.75), Mode(2650, 0.006, 0.5), Mode(4150, 0.003, 0.3)], 0.75, 3000, 1.2, 0.005)], length: 0.1, lowpass: 11000),
            up: Stroke(layers: [L(0, [Mode(900, 0.006, 0.6), Mode(2100, 0.004, 0.45)], 0.7, 3600, 1.3, 0.003)], length: 0.05, lowpass: 12000, gain: 0.45)),
        SwitchProfile(
            id: "cardboard", name: "Parcel", kind: .linear, blurb: "Soft, papery and muffled",
            cap: "#C9A877", legend: "#6B5130", accent: "#B98B4E",
            down: Stroke(layers: [L(0, [Mode(240, 0.011, 1), Mode(520, 0.007, 0.55), Mode(980, 0.004, 0.25)], 0.85, 750, 0.7, 0.009)], length: 0.1, lowpass: 1900, gain: 0.95),
            up: Stroke(layers: [L(0, [Mode(420, 0.005, 0.5)], 0.7, 1100, 0.8, 0.005)], length: 0.05, lowpass: 2200, gain: 0.3)),
        SwitchProfile(
            id: "porcelain", name: "Porcelain", kind: .linear, blurb: "Glassy ceramic keycaps",
            cap: "#F7F7F5", legend: "#3A6EA5", accent: "#5B9BD5",
            down: Stroke(layers: [L(0, [Mode(1850, 0.022, 0.8), Mode(3150, 0.016, 0.6), Mode(4750, 0.01, 0.4), Mode(620, 0.01, 0.5)], 0.6, 4000, 2, 0.004)], length: 0.14, lowpass: 15000),
            up: Stroke(layers: [L(0, [Mode(2400, 0.01, 0.5), Mode(4100, 0.007, 0.35)], 0.5, 4800, 2, 0.002)], length: 0.07, gain: 0.4)),
        SwitchProfile(
            id: "bramble", name: "Bramble", kind: .tactile, blurb: "Rounded bump, warm bottom-out",
            cap: "#B7835A", legend: "#FFF4E6", accent: "#D08B53",
            down: Stroke(layers: [
                L(0, [Mode(2100, 0.0015, 0.25)], 0.35, 2400, 1.4, 0.0015),
                L(0.011, [Mode(270, 0.022, 1), Mode(690, 0.013, 0.5), Mode(1500, 0.008, 0.38), Mode(3000, 0.004, 0.18)], 0.5, 1900, 0.9, 0.006)], length: 0.14, lowpass: 8000),
            up: Stroke(layers: [L(0, [Mode(480, 0.008, 0.5), Mode(1300, 0.005, 0.35)], 0.55, 2400, 1.1, 0.004)], length: 0.06, gain: 0.4)),
        SwitchProfile(
            id: "sky", name: "Skylark", kind: .clicky, blurb: "Crisp click on every press",
            cap: "#CFE4F7", legend: "#2D5B8A", accent: "#4C9AE8",
            down: Stroke(layers: [
                L(0, [Mode(4300, 0.0025, 1), Mode(6100, 0.0015, 0.4)], 0.8, 4800, 2, 0.002),
                L(0.014, [Mode(360, 0.015, 0.65), Mode(920, 0.01, 0.5), Mode(2000, 0.006, 0.4)], 0.5, 2200, 1, 0.005)], length: 0.12, lowpass: 13000),
            up: Stroke(layers: [
                L(0, [Mode(4700, 0.002, 0.8), Mode(6600, 0.0012, 0.3)], 0.6, 5200, 2, 0.0015),
                L(0.006, [Mode(700, 0.006, 0.3)], 0.3, 2600, 1, 0.003)], length: 0.06, gain: 0.62)),
        SwitchProfile(
            id: "jade", name: "Jadeite", kind: .clicky, blurb: "Sharp, snappy click bar",
            cap: "#7FC8A9", legend: "#1E4D3B", accent: "#3FAE84",
            down: Stroke(layers: [
                L(0, [Mode(5200, 0.003, 1), Mode(2900, 0.002, 0.5)], 0.9, 5600, 2.5, 0.0025),
                L(0.01, [Mode(420, 0.012, 0.6), Mode(1100, 0.008, 0.5), Mode(2400, 0.005, 0.35)], 0.55, 2600, 1.1, 0.004)], length: 0.11, lowpass: 14000),
            up: Stroke(layers: [L(0, [Mode(5600, 0.002, 0.7)], 0.5, 6000, 2.5, 0.0015)], length: 0.05, gain: 0.45)),
        SwitchProfile(
            id: "typewriter", name: "Remington", kind: .special, blurb: "Vintage strikes and a bell",
            cap: "#1F1F1F", legend: "#F2E8D5", accent: "#C0392B",
            down: Stroke(layers: [
                L(0, [Mode(1150, 0.01, 0.7), Mode(2350, 0.008, 0.6), Mode(3750, 0.006, 0.4)], 0.95, 2600, 0.8, 0.01),
                L(0.009, [Mode(240, 0.025, 0.65), Mode(510, 0.015, 0.35)], 0.3, 900, 0.8, 0.01)], length: 0.18, lowpass: 10000),
            up: Stroke(layers: [L(0, [Mode(1600, 0.006, 0.4), Mode(3100, 0.004, 0.3)], 0.6, 3000, 1, 0.004)], length: 0.07, gain: 0.35),
            style: .typewriter),
        SwitchProfile(
            id: "chime", name: "Chime Pad", kind: .special, blurb: "Soft musical tones",
            cap: "#E8DDF7", legend: "#6B4FA3", accent: "#9C7BE0",
            down: Stroke(layers: []), up: Stroke(layers: []),
            style: .chime),
    ]

    private static func rec(_ id: String, _ name: String, _ kind: SwitchKind, _ blurb: String,
                            _ cap: String, _ legend: String, _ accent: String, _ label: String, new: Bool = false) -> SwitchProfile {
        SwitchProfile(id: id, name: name, kind: kind, blurb: blurb, cap: cap, legend: legend, accent: accent,
                      down: Stroke(layers: []), up: Stroke(layers: []), isNew: new, recording: id, label: label)
    }

    /// Real recordings of real switches (see Resources/Recordings/CREDITS.txt).
    static let recorded: [SwitchProfile] = [
        rec("cream", "NovelKeys Cream", .linear, "Self-lubricating POM, deep and smooth", "#F1E6C8", "#7A5C3A", "#D4A65A", "NK"),
        rec("blackink", "Gateron Black Ink", .linear, "Heavy, deep thock", "#2B2D33", "#AEB8E6", "#6C7BD9", "BI"),
        rec("alpaca", "Alpaca V2", .linear, "Smooth, muted and creamy", "#F2C6D4", "#8E3B5A", "#E07FA3", "AL"),
        rec("redink", "Gateron Red Ink", .linear, "Light, buttery and bright", "#C8463F", "#FFE9E6", "#D9534F", "RI"),
        rec("turquoise", "Zeal Tealios", .linear, "Silky with a higher-pitched clack", "#5FC9C2", "#0F4A47", "#2FB3A9", "TL"),
        rec("mxblack", "Cherry MX Black", .linear, "The classic heavy linear", "#303033", "#E0E0E0", "#8D93A5", "MX"),
        rec("holypanda", "Holy Panda", .tactile, "Sharp bump and signature thock", "#EFEDE8", "#2A2A2A", "#B98A4C", "HP"),
        rec("topre", "Topre", .tactile, "Electro-capacitive, soft rounded thock", "#D9D6CF", "#555555", "#8C7AA9", "TP"),
        rec("oreo", "Everglide Oreo", .tactile, "Deep, poppy tactile", "#1E1E20", "#F4F4F4", "#7FA7C9", "OR"),
        rec("crystalpurple", "Everglide Crystal Purple", .tactile, "Rounded bump, crisp clack", "#B9A6E6", "#3E2A73", "#8E6FD8", "CP"),
        rec("mxbrown", "Cherry MX Brown", .tactile, "Light tactile all-rounder", "#7A5235", "#F5E6D8", "#A9714B", "MX"),
        rec("buckling", "IBM Buckling Spring", .clicky, "Model M spring ping and clack", "#E9E4D6", "#3A3A3A", "#5B8DB8", "M"),
        rec("boxnavy", "Kailh Box Navy", .clicky, "Thick, heavy click bar", "#22325A", "#CFE0FF", "#4B6CB7", "BN"),
        rec("bluealps", "SKCM Blue Alps", .clicky, "Vintage, high-pitched click", "#9CC3E6", "#1F3D5C", "#5AA0D8", "AP"),
        rec("mxblue", "Cherry MX Blue", .clicky, "The classic sharp click", "#4F86C6", "#EAF2FF", "#4C8BE0", "MX"),
    ]

    /// Recorded switches first; Pressly's original synthesized sounds after them.
    static let all: [SwitchProfile] = recorded + synthesized

    static func named(_ id: String) -> SwitchProfile { all.first { $0.id == id } ?? all[0] }

    // Mouse and scroll sounds are shared by every switch.
    static let mouseDown = Stroke(layers: [L(0, [Mode(3500, 0.0015, 0.6), Mode(900, 0.004, 0.4)], 1, 3000, 1.5, 0.002)], length: 0.03, lowpass: 12000, gain: 0.8)
    static let mouseUp = Stroke(layers: [L(0, [Mode(4200, 0.0012, 0.5), Mode(1200, 0.003, 0.3)], 0.8, 3800, 1.5, 0.0015)], length: 0.025, lowpass: 13000, gain: 0.5)
    static let scrollTick = Stroke(layers: [L(0, [Mode(2500, 0.001, 0.6)], 0.5, 4000, 2, 0.001)], length: 0.012, lowpass: 12000, gain: 0.35)
}
