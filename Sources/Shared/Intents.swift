import AppIntents
import Foundation
import WidgetKit

/// Practice minutes logged without opening the app (the Practice widget's buttons, Control Center, Siri).
/// They wait in the app group until the app next opens and files them as sessions in the ledger.
enum QuickLog {
    struct Entry: Codable { var date: Date; var minutes: Int }
    private static let key = "quicklog"

    static func add(_ minutes: Int) {
        var all = pending
        all.append(Entry(date: .now, minutes: minutes))
        if let d = try? JSONEncoder().encode(all) { Shared.defaults.set(d, forKey: key) }
        var g = Glance.load()
        g.weekMinutes += minutes
        g.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var pending: [Entry] {
        guard let d = Shared.defaults.data(forKey: key), let all = try? JSONDecoder().decode([Entry].self, from: d) else { return [] }
        return all
    }

    static func take() -> [Entry] {
        let p = pending
        Shared.defaults.removeObject(forKey: key)
        return p
    }
}

/// A screen the app can be opened on by a control, a shortcut or an In-App Event link.
enum Route: String {
    case practice, round, plan, challenge, stats, insights, plus

    static let key = "pendingRoute"
    static func request(_ r: Route) {
        Shared.defaults.set(r.rawValue, forKey: key)
        NotificationCenter.default.post(name: .fairwayRoute, object: nil)
    }
    static func take() -> Route? {
        guard let s = Shared.defaults.string(forKey: key) else { return nil }
        Shared.defaults.removeObject(forKey: key)
        return Route(rawValue: s)
    }
}

extension Notification.Name {
    static let fairwayRoute = Notification.Name("fairwayRoute")
}

// MARK: - Intents (Siri, Shortcuts, Spotlight, controls, widget buttons)

struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Practice"
    static var description = IntentDescription("Adds practice minutes to this week's total without opening the app.")

    @Parameter(title: "Minutes", default: 15)
    var minutes: Int

    init() {}
    init(minutes: Int) { self.minutes = minutes }

    static var parameterSummary: some ParameterSummary { Summary("Log \(\.$minutes) minutes of practice") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let m = max(1, min(600, minutes))
        QuickLog.add(m)
        return .result(dialog: "Logged \(m) minutes. \(Glance.load().weekMinutes) minutes of practice this week.")
    }
}

struct StartPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Practice"
    static var description = IntentDescription("Opens a live range session.")
    static var openAppWhenRun = true
    init() {}
    func perform() async throws -> some IntentResult {
        Route.request(.practice)
        return .result()
    }
}

struct LogRoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Round"
    static var description = IntentDescription("Opens a new scorecard, or the one you left half entered.")
    static var openAppWhenRun = true
    init() {}
    func perform() async throws -> some IntentResult {
        Route.request(.round)
        return .result()
    }
}

struct ChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Monthly Challenge"
    static var description = IntentDescription("Shows this month's challenge and how close you are.")
    static var openAppWhenRun = true
    init() {}
    func perform() async throws -> some IntentResult {
        Route.request(.challenge)
        return .result()
    }
}

struct HandicapIntent: AppIntent {
    static var title: LocalizedStringResource = "Handicap Index"
    static var description = IntentDescription("Tells you your handicap index estimate and your last round.")
    init() {}
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let g = Glance.load()
        guard let h = g.handicap else {
            return .result(dialog: "Log three eighteen-hole rounds and Fairway Ledger works out your index.")
        }
        let last = g.lastScore.map { " Your last round was \($0)" + (g.lastCourse.isEmpty ? "." : " at \(g.lastCourse).") } ?? ""
        return .result(dialog: "Your handicap index is \(String(format: "%.1f", h)).\(last)")
    }
}
