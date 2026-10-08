import ActivityKit
import SwiftUI
import WidgetKit

/// What the widgets show, written by the app after every save. Small, so the widget never
/// has to read the whole ledger.
struct Glance: Codable {
    var handicap: Double?
    var lastScore: Int?
    var lastToPar: String = ""
    var lastCourse: String = ""
    var lastDate: Date?
    var weekMinutes: Int = 0
    var weeklyTarget: Int = 240
    var streakWeeks: Int = 0
    /// Oldest first, up to ten.
    var recent: [Int] = []
    var avgPutts: Double?
    var firPct: Int?
    var girPct: Int?
    var unlocked = false

    static let key = "glance"
    static func load() -> Glance {
        guard let d = Shared.defaults.data(forKey: key), let g = try? JSONDecoder().decode(Glance.self, from: d) else { return Glance() }
        return g
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { Shared.defaults.set(d, forKey: Glance.key) }
    }
    static var sample: Glance {
        Glance(handicap: 12.4, lastScore: 84, lastToPar: "+12", lastCourse: "Pine Hollow", lastDate: .now, weekMinutes: 175, weeklyTarget: 240,
               streakWeeks: 6, recent: [92, 90, 91, 88, 89, 87, 90, 86, 85, 84], avgPutts: 31.4, firPct: 52, girPct: 33, unlocked: true)
    }
}

/// The round on the Lock Screen and in the Dynamic Island while you play.
struct RoundActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var hole: Int
        var par: Int
        var thru: Int
        var score: Int
        var toPar: String
        var putts: Int
    }
    var course: String
}

// MARK: Views

/// Small: the handicap index, the last card and this week's practice.
struct HandicapGlanceView: View {
    let g: Glance
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HANDICAP").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
            Text(g.handicap.map { String(format: "%.1f", $0) } ?? "—").font(.figure(38, .light)).foil()
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let s = g.lastScore {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(s)").font(.figure(17)).foregroundStyle(Gold.ivory)
                    Text(g.lastToPar).font(.body(11, .semibold)).foregroundStyle(Gold.muted)
                }
                Text(g.lastCourse).font(.body(10.5)).foregroundStyle(Gold.muted).lineLimit(1)
            } else {
                Text("Log a round to start your index.").font(.body(11)).foregroundStyle(Gold.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Gold.leaf.opacity(0.15))
                    Capsule().fill(Gold.foil).frame(width: geo.size.width * min(1, Double(g.weekMinutes) / Double(max(1, g.weeklyTarget))))
                }
            }.frame(height: 5)
            Text("\(g.weekMinutes) of \(g.weeklyTarget) min practice").font(.body(9.5)).foregroundStyle(Gold.muted)
        }
    }
}

/// Medium: the last ten scores and the averages that matter.
struct LedgerGlanceView: View {
    let g: Glance
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INDEX").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                Text(g.handicap.map { String(format: "%.1f", $0) } ?? "—").font(.figure(36, .light)).foil()
                Spacer(minLength: 0)
                stat("Putts", g.avgPutts.map { String(format: "%.1f", $0) } ?? "–")
                stat("FIR", g.firPct.map { "\($0)%" } ?? "–")
                stat("GIR", g.girPct.map { "\($0)%" } ?? "–")
            }.frame(width: 82, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("LAST \(g.recent.count) ROUNDS").font(.body(9, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                bars
                if let s = g.lastScore { Text("\(s) at \(g.lastCourse)").font(.body(11, .semibold)).foregroundStyle(Gold.ivory).lineLimit(1) }
            }
        }
    }
    private func stat(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.body(10)).foregroundStyle(Gold.muted); Spacer(); Text(v).font(.figure(12)).foregroundStyle(Gold.ivory) }
    }
    private var bars: some View {
        let lo = (g.recent.min() ?? 70) - 3, hi = (g.recent.max() ?? 100) + 1
        return GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(g.recent.enumerated()), id: \.offset) { i, s in
                    let h = geo.size.height * Double(s - lo) / Double(max(1, hi - lo))
                    RoundedRectangle(cornerRadius: 3).fill(i == g.recent.count - 1 ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.leaf.opacity(0.35)))
                        .frame(height: max(4, h))
                }
            }
        }
    }
}

/// The free plan's medium widget.
struct LockedGlanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 15, weight: .semibold)).foil()
            Text("Fairway Ledger Pro").font(.display(17, .medium)).foregroundStyle(Gold.ivory)
            Text("Your last ten rounds and averages on the Home Screen come with Pro. The Handicap widget is free.")
                .font(.body(11)).foregroundStyle(Gold.muted)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Lock Screen card for a round in progress.
struct RoundLiveView: View {
    let course: String
    let s: RoundActivity.ContentState
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.isEmpty ? "ON THE COURSE" : course.uppercased()).font(.body(10, .semibold)).tracking(1.4).foregroundStyle(Gold.muted).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Hole \(s.hole)").font(.display(22, .medium)).foregroundStyle(Gold.ivory)
                    Text("Par \(s.par)").font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                }
                Text("Thru \(s.thru) · \(s.putts) putts").font(.body(12)).foregroundStyle(Gold.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(s.toPar).font(.figure(34, .light)).foil()
                Text("\(s.score) strokes").font(.body(11)).foregroundStyle(Gold.muted)
            }
        }
        .padding(16)
    }
}
