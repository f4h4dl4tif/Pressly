import Foundation

struct DayStat: Codable, Equatable {
    var keys = 0
    var clicks = 0
    var scrolls = 0
    var words = 0
}

/// Local typing statistics. Counts only; Pressly never records which text you type.
final class Stats: ObservableObject {
    static let shared = Stats()

    private struct Store: Codable {
        var days: [String: DayStat]
        var keyCounts: [String: Int]
        var since: Date
    }

    @Published private(set) var days: [String: DayStat] = [:]
    @Published private(set) var keyCounts: [String: Int] = [:]
    @Published private(set) var since = Date()
    private var dirty = false
    private var lastWasSpace = true

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pressly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL), let store = try? JSONDecoder().decode(Store.self, from: data) {
            days = store.days
            keyCounts = store.keyCounts
            since = store.since
        }
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.save() }
    }

    func key(for date: Date) -> String { formatter.string(from: date) }
    var today: DayStat { days[key(for: Date())] ?? DayStat() }

    func recordKey(_ code: UInt16) {
        let k = key(for: Date())
        days[k, default: DayStat()].keys += 1
        keyCounts[String(code), default: 0] += 1
        let isSpace = code == 49 || code == 36 || code == 48
        if !isSpace && lastWasSpace { days[k, default: DayStat()].words += 1 }
        lastWasSpace = isSpace
        dirty = true
    }

    func recordClick() { days[key(for: Date()), default: DayStat()].clicks += 1; dirty = true }
    func recordScroll() { days[key(for: Date()), default: DayStat()].scrolls += 1; dirty = true }

    var totalKeys: Int { days.values.reduce(0) { $0 + $1.keys } }
    var totalClicks: Int { days.values.reduce(0) { $0 + $1.clicks } }
    var totalWords: Int { days.values.reduce(0) { $0 + $1.words } }
    var bestDay: (String, Int)? { days.max { $0.value.keys < $1.value.keys }.map { ($0.key, $0.value.keys) } }

    func lastDays(_ n: Int) -> [(date: Date, stat: DayStat)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<n).reversed().compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: start) else { return nil }
            return (d, days[key(for: d)] ?? DayStat())
        }
    }

    func topKeys(_ n: Int) -> [(label: String, count: Int)] {
        keyCounts.sorted { $0.value > $1.value }.prefix(n).map { (KeyMap.labels[UInt16($0.key) ?? 0] ?? "#\($0.key)", $0.value) }
    }

    func reset() {
        days = [:]; keyCounts = [:]; since = Date(); dirty = true
        save()
    }

    func save() {
        guard dirty else { return }
        dirty = false
        let store = Store(days: days, keyCounts: keyCounts, since: since)
        if let data = try? JSONEncoder().encode(store) { try? data.write(to: fileURL, options: .atomic) }
    }
}
