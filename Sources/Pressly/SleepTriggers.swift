import AppKit
import EventKit

/// Automatically silences Pressly in situations where clicking sounds would be unwelcome.
final class SleepTriggers: ObservableObject {
    static let shared = SleepTriggers()

    @Published private(set) var reason: String?
    @Published private(set) var calendarAccess: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var focusReadable = true

    var isSleeping: Bool { reason != nil }

    private let store = EKEventStore()
    private var calendarBusy = false
    private var lastCalendarCheck = Date.distantPast
    private var gameCache: [String: Bool] = [:]
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.evaluate() }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.lastCalendarCheck = .distantPast
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evaluate()
        }
        evaluate()
    }

    func evaluate() {
        let s = AppSettings.shared
        var r: String?
        if s.sleepGaming, isGameFrontmost() { r = "Playing a game" }
        else if s.sleepScreenShare, isScreenSharing() { r = "Screen sharing" }
        else if s.sleepCalendar, isInMeeting() { r = "In a calendar event" }
        else if s.sleepFocus, isFocusOn() { r = "A Focus is on" }
        else if s.sleepMedia, AudioDevices.otherProcessIsPlayingAudio() { r = "Media is playing" }
        if r != reason { reason = r }
    }

    // MARK: Gaming

    private func isGameFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else { return false }
        if let cached = gameCache[id] { return cached }
        var game = false
        if let url = app.bundleURL, let info = Bundle(url: url)?.infoDictionary,
           let category = info["LSApplicationCategoryType"] as? String {
            game = category.contains("games")
        }
        let launchers = ["com.valvesoftware.steam.helper", "com.blizzard.worldofwarcraft", "com.riotgames.LeagueofLegends.GameClient"]
        if launchers.contains(id) { game = true }
        gameCache[id] = game
        return game
    }

    // MARK: Screen sharing

    private func isScreenSharing() -> Bool {
        let sharingIDs: Set<String> = ["us.zoom.CptHost", "com.apple.screensharing.agent"]
        return NSWorkspace.shared.runningApplications.contains { app in
            if let id = app.bundleIdentifier, sharingIDs.contains(id) { return true }
            return app.localizedName == "CptHost"
        }
    }

    // MARK: Calendar

    func requestCalendarAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.calendarAccess = EKEventStore.authorizationStatus(for: .event)
                self?.lastCalendarCheck = .distantPast
                self?.evaluate()
            }
        }
    }

    private func isInMeeting() -> Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }
        if Date().timeIntervalSince(lastCalendarCheck) > 30 {
            lastCalendarCheck = Date()
            let now = Date()
            let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-12 * 3600), end: now.addingTimeInterval(60), calendars: nil)
            calendarBusy = store.events(matching: predicate).contains {
                !$0.isAllDay && $0.startDate <= now && $0.endDate > now && $0.availability != .free
            }
        }
        return calendarBusy
    }

    // MARK: Focus

    /// Reads the Focus assertion database. Needs Full Disk Access; reports `focusReadable` otherwise.
    private func isFocusOn() -> Bool {
        let path = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if focusReadable { focusReadable = false }
            return false
        }
        if !focusReadable { focusReadable = true }
        let records = (json["data"] as? [[String: Any]])?.first?["storeAssertionRecords"] as? [Any]
        return !(records ?? []).isEmpty
    }
}
