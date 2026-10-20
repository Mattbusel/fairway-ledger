import Charts
import SwiftUI

/// Plus insights: the handicap trend with where it is heading, and strokes lost by part of the game against
/// typical amateurs at the handicap you are aiming for. Estimates from the user's own cards, labelled as such.
enum Benchmarks {
    /// Typical amateur numbers per eighteen holes by handicap index: fairways %, greens %, putts,
    /// up-and-down %, penalty strokes. Rounded from published amateur stat studies; an estimate, not a rule.
    static let table: [(hcp: Double, fir: Double, gir: Double, putts: Double, scr: Double, pens: Double)] = [
        (0, 58, 58, 29.9, 52, 0.4),
        (5, 53, 46, 31.0, 40, 0.8),
        (10, 48, 35, 32.0, 31, 1.2),
        (15, 44, 26, 33.0, 23, 1.7),
        (20, 40, 18, 34.0, 17, 2.2),
        (25, 36, 12, 35.0, 12, 2.7),
        (30, 32, 8, 36.0, 8, 3.2),
    ]

    static func at(_ h: Double) -> (fir: Double, gir: Double, putts: Double, scr: Double, pens: Double) {
        let x = max(0, min(30, h))
        let i = min(table.count - 2, Int(x / 5))
        let a = table[i], b = table[i + 1]
        let t = (x - a.hcp) / (b.hcp - a.hcp)
        func mix(_ p: Double, _ q: Double) -> Double { p + (q - p) * t }
        return (mix(a.fir, b.fir), mix(a.gir, b.gir), mix(a.putts, b.putts), mix(a.scr, b.scr), mix(a.pens, b.pens))
    }
}

struct StrokeLeak: Identifiable {
    let id: String
    let icon: String
    let strokes: Double
    let line: String
}

extension Ledger {
    /// Where the strokes go against a target handicap, from the last ten eighteen-hole rounds. Positive = lost.
    func leaks(against target: Double) -> [StrokeLeak] {
        let rs = Array(rounds.filter { !$0.isNine }.prefix(10))
        guard !rs.isEmpty else { return [] }
        let n = Double(rs.count)
        let fir = pctValue(rs.reduce(0) { $0 + $1.fairwaysHit }, rs.reduce(0) { $0 + $1.fairwayHoles.count })
        let gir = pctValue(rs.reduce(0) { $0 + $1.girs }, rs.reduce(0) { $0 + $1.holes.count })
        let putts = Double(rs.reduce(0) { $0 + $1.putts }) / n
        let tries = rs.reduce(0) { $0 + $1.scrambles.tries }
        let scr = tries == 0 ? 0 : pctValue(rs.reduce(0) { $0 + $1.scrambles.made }, tries)
        let pens = Double(rs.reduce(0) { $0 + $1.penalties }) / n
        let b = Benchmarks.at(target)
        let missed = 18 * (1 - gir / 100)
        let tee = (b.fir - fir) / 100 * 14 * 0.3 + (pens - b.pens)
        let approach = (b.gir - gir) / 100 * 18 * 0.8
        let short = tries == 0 ? 0 : (b.scr - scr) / 100 * missed
        let green = putts - b.putts
        return [
            StrokeLeak(id: "Off the tee", icon: "arrow.up.right", strokes: tee,
                       line: String(format: "%.0f%% fairways and %.1f penalties a round, against %.0f%% and %.1f.", fir, pens, b.fir, b.pens)),
            StrokeLeak(id: "Approach", icon: "scope", strokes: approach,
                       line: String(format: "%.0f%% greens in regulation, against %.0f%%.", gir, b.gir)),
            StrokeLeak(id: "Around the green", icon: "arrow.uturn.up", strokes: short,
                       line: tries == 0 ? "No missed greens logged yet." : String(format: "Up and down %.0f%% of the time, against %.0f%%.", scr, b.scr)),
            StrokeLeak(id: "Putting", icon: "flag.fill", strokes: green,
                       line: String(format: "%.1f putts a round, against %.1f.", putts, b.putts)),
        ].sorted { $0.strokes > $1.strokes }
    }

    /// Where the index is heading: change per 30 days from a straight line through the recent history.
    var handicapPace: Double? {
        let h = handicapHistory.suffix(12)
        guard h.count >= 4, let first = h.first?.date else { return nil }
        let xs = h.map { $0.date.timeIntervalSince(first) / 86_400 }, ys = h.map(\.index)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        let sxx = zip(xs, xs).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - mx) }
        guard sxx > 1 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return sxy / sxx * 30
    }
}

/// The Plus insights page.
struct InsightsView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Plus.self) private var plus
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @AppStorage("plus.target") private var target: Double = -1

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "Plus insights", title: "Where your game is going") { dismiss() }.padding(.horizontal, -20)
                    if plus.active {
                        content
                    } else {
                        ZStack {
                            VStack(alignment: .leading, spacing: 18) { content }
                                .blur(radius: 9).allowsHitTesting(false).accessibilityHidden(true)
                            VStack(spacing: 14) {
                                ProSeal(size: 84)
                                Text("Insights come with Plus").font(.display(24)).foregroundStyle(Gold.ivory)
                                Text("Your handicap trend and where it is heading, and the strokes each part of your game costs against the handicap you want.")
                                    .font(.body(14)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                                FoilButton("See Plus", icon: "sparkles") { pro.ask(.insights) }
                            }
                            .padding(.horizontal, 12).padding(.top, 40).frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }

    private var goal: Double {
        if target >= 0 { return target }
        return max(0, ((ledger.handicap ?? 18) - 3).rounded())
    }

    @ViewBuilder private var content: some View {
        trend
        leaks
        Text("Estimates from your last ten eighteen-hole rounds, against typical amateur numbers at the target handicap. The handicap figure is the app's own estimate, not an official index.")
            .font(.body(11)).foregroundStyle(Gold.faint).fixedSize(horizontal: false, vertical: true)
    }

    private var trend: some View {
        let h = Array(ledger.handicapHistory.suffix(24))
        let pace = ledger.handicapPace
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Handicap trend")
                Spacer()
                if let now = h.last?.index { Text(String(format: "%.1f", now)).font(.figure(24)).foil() }
            }
            if h.count < 2 {
                Text("Log three eighteen-hole rounds and the trend starts drawing itself.").font(.body(13)).foregroundStyle(Gold.muted)
            } else {
                Chart {
                    ForEach(Array(h.enumerated()), id: \.offset) { _, p in
                        AreaMark(x: .value("Date", p.date), yStart: .value("Floor", (h.map(\.index).min() ?? 0) - 1), yEnd: .value("Index", p.index))
                            .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Date", p.date), y: .value("Index", p.index))
                            .foregroundStyle(Gold.foil).lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    if let pace, let last = h.last {
                        LineMark(x: .value("Date", last.date), y: .value("Index", last.index), series: .value("s", "pace"))
                            .foregroundStyle(Gold.pale.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
                        LineMark(x: .value("Date", last.date.addingTimeInterval(90 * 86_400)), y: .value("Index", max(0, last.index + pace * 3)), series: .value("s", "pace"))
                            .foregroundStyle(Gold.pale.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis { AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Gold.leaf.opacity(0.08))
                    AxisValueLabel().foregroundStyle(Gold.muted).font(.body(10))
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Gold.muted).font(.body(10))
                } }
                .frame(height: 190)
                Text(paceLine(pace, h.last?.index)).font(.display(16).italic()).foregroundStyle(Gold.ivory.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func paceLine(_ pace: Double?, _ now: Double?) -> String {
        guard let pace, let now else { return "A few more rounds and the pace line appears." }
        if pace < -0.05 {
            let then = max(0, now + pace * 3)
            let when = Date.now.addingTimeInterval(90 * 86_400).formatted(.dateTime.month(.wide))
            return String(format: "Dropping %.1f a month. Keep this pace and you are near %.1f by %@.", -pace, then, when)
        }
        if pace > 0.05 { return String(format: "Up %.1f a month lately. The breakdown below shows where to win it back.", pace) }
        return "Holding steady. The breakdown below shows the quickest strokes to find."
    }

    private var leaks: some View {
        let ls = ledger.leaks(against: goal)
        let worst = ls.first
        let span = max(1, ls.map { abs($0.strokes) }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Strokes against a \(Int(goal)) handicap")
                Spacer()
                Stepper("", value: Binding(get: { goal }, set: { target = max(0, min(30, $0)) }), in: 0...30, step: 1)
                    .labelsHidden().tint(Gold.leaf)
                    .accessibilityLabel("Target handicap \(Int(goal))")
            }
            if ls.isEmpty {
                Text("Log an eighteen-hole round to see where the strokes go.").font(.body(13)).foregroundStyle(Gold.muted)
            }
            ForEach(ls) { l in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(l.id, systemImage: l.icon).font(.body(13.5, .semibold)).foregroundStyle(Gold.ivory)
                        Spacer()
                        Text(String(format: "%+.1f", l.strokes)).font(.figure(17)).foregroundStyle(l.strokes > 0.05 ? Gold.bad : Gold.good)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Gold.lacquerHi)
                            Capsule().fill(l.strokes > 0 ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.good.opacity(0.6)))
                                .frame(width: max(6, g.size.width * min(1, abs(l.strokes) / span)))
                        }
                    }
                    .frame(height: 8)
                    Text(l.line).font(.body(12)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let worst, worst.strokes > 0.3 {
                Text(String(format: "%@ costs you about %.1f strokes a round against a %d handicap. Start there.", worst.id, worst.strokes, Int(goal)))
                    .font(.display(16).italic()).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

/// The Stats tab's way in to the insights.
struct InsightsTeaser: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Plus.self) private var plus

    var body: some View {
        Button { router.insights = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.downtrend.xyaxis").font(.body(17, .semibold)).foil()
                    .frame(width: 42, height: 42).background(Circle().fill(Gold.lacquerHi))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plus insights").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                    Text(plus.active ? "Handicap trend, pace, and strokes against your target" : "Your handicap's pace and where the strokes go. With Plus.")
                        .font(.body(12)).foregroundStyle(Gold.muted)
                }
                Spacer()
                Image(systemName: plus.active ? "chevron.right" : "lock.fill").font(.body(13, .bold)).foil()
            }
            .card(padding: 14)
        }
        .buttonStyle(PressStyle())
    }
}
