import ActivityKit
import Charts
import SwiftUI
import UIKit
import WidgetKit

// MARK: Live Activity

/// Keeps the Lock Screen card in step with the scorecard. Free for everyone.
@MainActor
enum RoundLive {
    private static var activity: Activity<RoundActivity>?

    static func state(_ r: Round, hole: Int) -> RoundActivity.ContentState {
        let played = r.holes.prefix(hole + 1)
        let score = played.reduce(0) { $0 + $1.score }, par = played.reduce(0) { $0 + $1.par }
        let d = score - par
        return .init(hole: r.holes[hole].id, par: r.holes[hole].par, thru: hole + 1, score: score,
                     toPar: d == 0 ? "E" : d > 0 ? "+\(d)" : "\(d)", putts: played.reduce(0) { $0 + $1.putts })
    }

    static func start(_ r: Round, hole: Int) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled,
              !ProcessInfo.processInfo.arguments.contains("-shot") else { return }
        activity = try? Activity.request(attributes: RoundActivity(course: r.course),
                                         content: .init(state: state(r, hole: hole), staleDate: .now.addingTimeInterval(6 * 3600)))
    }
    static func update(_ r: Round, hole: Int) {
        guard let a = activity else { return }
        let s = state(r, hole: hole)
        Task { await a.update(.init(state: s, staleDate: .now.addingTimeInterval(6 * 3600))) }
    }
    static func end(_ r: Round?) {
        guard let a = activity else { return }
        activity = nil
        let final = r.map { state($0, hole: $0.holes.count - 1) }
        Task { await a.end(final.map { .init(state: $0, staleDate: nil) }, dismissalPolicy: .after(.now.addingTimeInterval(1800))) }
    }
}

// MARK: Widgets

extension Ledger {
    /// The small summary the widgets read.
    func glance(unlocked: Bool, weeklyTarget: Int) -> Glance {
        let rs = Array(rounds.filter { !$0.isNine }.prefix(10))
        let last = rounds.first
        let holes = rs.reduce(0) { $0 + $1.holes.count }
        return Glance(handicap: handicap, lastScore: last?.score, lastToPar: last?.toParText ?? "", lastCourse: last?.course ?? "", lastDate: last?.date,
                      weekMinutes: minutes(inLast: 7), weeklyTarget: weeklyTarget, streakWeeks: practiceStreakWeeks,
                      recent: rs.reversed().map(\.score),
                      avgPutts: rs.isEmpty ? nil : Double(rs.reduce(0) { $0 + $1.putts }) / Double(rs.count),
                      firPct: rs.isEmpty ? nil : Int(pctValue(rs.reduce(0) { $0 + $1.fairwaysHit }, rs.reduce(0) { $0 + $1.fairwayHoles.count }).rounded()),
                      girPct: rs.isEmpty ? nil : Int(pctValue(rs.reduce(0) { $0 + $1.girs }, holes).rounded()),
                      unlocked: unlocked)
    }
}

// MARK: Where the strokes go (Pro)

struct StrokesCard: View {
    @Environment(Ledger.self) private var ledger
    var body: some View {
        let rs = Array(ledger.rounds.filter { !$0.isNine }.prefix(10))
        let n = Double(max(1, rs.count))
        func avgOver(_ par: Int) -> Double {
            let hs = rs.flatMap(\.holes).filter { $0.par == par }
            return hs.isEmpty ? 0 : Double(hs.reduce(0) { $0 + $1.score - $1.par }) / Double(hs.count)
        }
        let p3 = avgOver(3), p4 = avgOver(4), p5 = avgOver(5)
        let pens = Double(rs.reduce(0) { $0 + $1.penalties }) / n
        let threes = Double(rs.reduce(0) { $0 + $1.threePutts }) / n
        let perRound: [(String, Double)] = [
            ("Par 3s", p3 * 4), ("Par 4s", p4 * 10), ("Par 5s", p5 * 4),
        ]
        let leak = [("penalties", pens), ("three-putts", threes)].max { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Where the strokes go · last \(rs.count)")
            HStack(spacing: 10) {
                ForEach(perRound, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%+.1f", item.1)).font(.figure(24)).foil()
                        Text(item.0.uppercased()).font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.muted)
                        Text("per round").font(.body(10)).foregroundStyle(Gold.faint)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: 10) {
                StatTile(label: "Penalties", value: String(format: "%.1f", pens), unit: "a round")
                StatTile(label: "3-putts", value: String(format: "%.1f", threes), unit: "a round")
            }
            if let worst = perRound.max(by: { $0.1 < $1.1 }), worst.1 > 0 {
                Text("Most of your over-par strokes come on \(worst.0.lowercased()): \(String(format: "%.1f", worst.1)) a round" + (leak.map { $0.1 >= 1 ? ", and \(String(format: "%.1f", $0.1)) \($0.0) on top." : "." } ?? "."))
                    .font(.display(16).italic()).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

// MARK: Courses

struct CourseStrip: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Courses")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ledger.courses) { c in
                        let played = ledger.rounds.filter { $0.courseID == c.id || ($0.course == c.name && $0.tees == c.tees) }
                        Button { router.course = c } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(c.name).font(.display(16, .medium)).foregroundStyle(Gold.ivory).lineLimit(1)
                                Text("\(c.tees) · par \(c.par)").font(.body(11)).foregroundStyle(Gold.muted)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(played.map(\.score).min().map(String.init) ?? "–").font(.figure(24, .light)).foil()
                                    Text("best · \(played.count) played").font(.body(10.5)).foregroundStyle(Gold.muted)
                                }
                            }
                            .frame(width: 150, alignment: .leading)
                            .card(padding: 14, radius: 18)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 6)
            }
            .padding(.horizontal, -18)
        }
    }
}

/// A course's page: every card there, and how each hole plays for you (Pro).
struct CourseDetail: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let course: Course
    @State private var confirmDelete = false

    var body: some View {
        let played = ledger.rounds.filter { $0.courseID == course.id || ($0.course == course.name && $0.tees == course.tees) }
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "\(course.tees) tees · \(String(format: "%.1f", course.rating))/\(course.slope)", title: course.name) { dismiss() }.padding(.horizontal, -20)
                    HStack(spacing: 10) {
                        StatTile(label: "Best", value: played.map(\.score).min().map(String.init) ?? "–")
                        StatTile(label: "Average", value: played.isEmpty ? "–" : String(format: "%.1f", Double(played.map(\.score).reduce(0, +)) / Double(played.count)))
                        StatTile(label: "Played", value: "\(played.count)")
                    }
                    FoilButton("Play \(course.name)", icon: "flag.fill") {
                        dismiss()
                        let r = Round.at(course)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.editingRound = r }
                    }
                    if pro.unlocked {
                        holeByHole(played)
                    } else {
                        LockedSection(reason: .stats, title: "How each hole plays for you",
                                      pitch: "Your average on every hole against par, the holes that cost you, and the ones to attack.") { holeByHole(played) }
                    }
                    ForEach(played.prefix(8)) { r in
                        Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.editingRound = r } } label: { RoundCard(round: r) }
                            .buttonStyle(PressStyle())
                    }
                    Button("Remove course", role: .destructive) { confirmDelete = true }.font(.body(13, .semibold))
                        .frame(maxWidth: .infinity)
                        .confirmationDialog("Remove \(course.name)? Rounds played there stay.", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Remove", role: .destructive) { ledger.courses.removeAll { $0.id == course.id }; dismiss() }
                        }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }

    private func holeByHole(_ played: [Round]) -> some View {
        let full = played.filter { $0.holes.count == 18 }
        let avgs: [(Int, Double)] = (0..<18).map { i in
            let s = full.map { Double($0.holes[i].score - $0.holes[i].par) }
            return (i + 1, s.isEmpty ? 0 : s.reduce(0, +) / Double(s.count))
        }
        let worst = avgs.max { $0.1 < $1.1 }, best = avgs.min { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Over par, hole by hole")
            Chart(avgs, id: \.0) { item in
                BarMark(x: .value("Hole", "\(item.0)"), y: .value("Over par", item.1))
                    .foregroundStyle(item.1 > 1 ? AnyShapeStyle(Gold.bad.opacity(0.75)) : AnyShapeStyle(Gold.foil))
                    .cornerRadius(3)
            }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Gold.leaf.opacity(0.1)); AxisValueLabel().foregroundStyle(Gold.muted) } }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Gold.muted).font(.body(8)) } }
            .frame(height: 150)
            if let worst, let best, !full.isEmpty {
                Text("Hole \(worst.0) costs you \(String(format: "%.1f", worst.1)) a visit. Hole \(best.0) is your best at \(String(format: "%+.1f", best.1)).")
                    .font(.body(13)).foregroundStyle(Gold.ivory.opacity(0.85))
            }
        }
        .card()
    }
}

/// Saved courses to start a card from, at the top of the scorecard's details.
struct CoursePicker: View {
    @Environment(Ledger.self) private var ledger
    @Binding var round: Round
    @State private var nine: Course.Nine = .all
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Play a saved course")
            Picker("", selection: $nine) { ForEach(Course.Nine.allCases) { n in Text(n.rawValue).tag(n) } }.pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { Haptic.tap(); let id = round.id; round = Round.nine(nine); round.id = id } label: { chip("Standard par", on: round.courseID == nil) }
                    ForEach(ledger.courses) { c in
                        Button { Haptic.tap(); let id = round.id, date = round.date; round = Round.at(c, nine: nine); round.id = id; round.date = date } label: { chip(c.name, on: round.courseID == c.id) }
                    }
                }
            }
        }
        .card(padding: 16, radius: 18)
    }
    private func chip(_ t: String, on: Bool) -> some View {
        Text(t).font(.body(13, .semibold)).foregroundStyle(on ? Gold.ink : Gold.ivory.opacity(0.8))
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ink.opacity(0.5))))
            .overlay(Capsule().strokeBorder(Gold.hairline, lineWidth: 0.6))
    }
}

// MARK: Poster

/// A gold-leaf scorecard of one round, to share. The first is free; then packs of three.
struct PosterSheet: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    let round: Round
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "Round poster", title: round.course.isEmpty ? "Your round" : round.course) { dismiss() }.padding(.horizontal, -20)
                    RoundPoster(round: round, net: ledger.net(round))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                    if let image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("\(round.score) at \(round.course)", image: Image(uiImage: image))) {
                            HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text("Share or save").font(.body(16, .semibold)) }
                                .foregroundStyle(Gold.ink).frame(maxWidth: .infinity).frame(height: 56).background(Capsule().fill(Gold.foil))
                        }
                        Text("Made. Save it to Photos from the share sheet.").font(.body(12)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                    } else if extras.firstPosterFree || extras.posters > 0 {
                        FoilButton(extras.firstPosterFree ? "Make it · your first is free" : "Make it · \(extras.posters) left", icon: "photo.artframe") { make() }
                    } else {
                        FoilButton(extras.busy == Extras.postersID ? "One moment" : "3 posters · \(extras.price(Extras.postersID))", icon: "plus") {
                            Task { if await extras.buy(Extras.postersID) { make() } }
                        }
                        Text("Posters are used up as you make them. Finishes in Extras change their colour too.").font(.body(12)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                    }
                    if let m = extras.message { Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale).frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }

    @MainActor private func make() {
        guard extras.spendPoster() else { return }
        let r = ImageRenderer(content: RoundPoster(round: round, net: ledger.net(round)).frame(width: 360))
        r.scale = 3
        image = r.uiImage
        Haptic.done()
    }
}

struct RoundPoster: View {
    let round: Round
    let net: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased()).font(.body(9.5, .semibold)).tracking(1.6).foregroundStyle(Gold.muted)
                    Text(round.course.isEmpty ? "A round of golf" : round.course).font(.display(26, .medium)).foregroundStyle(Gold.ivory).lineLimit(2)
                    Text("\(round.tees) tees · \(String(format: "%.1f", round.rating))/\(round.slope)").font(.body(11)).foregroundStyle(Gold.muted)
                }
                Spacer()
                ZStack {
                    Circle().fill(Gold.foil)
                    Circle().strokeBorder(Gold.ink.opacity(0.25), lineWidth: 2).padding(5)
                    VStack(spacing: -2) {
                        Text("\(round.score)").font(.figure(30, .regular)).foregroundStyle(Gold.ink)
                        Text(round.toParText).font(.body(11, .bold)).foregroundStyle(Gold.ink.opacity(0.7))
                    }
                }.frame(width: 84, height: 84)
            }
            card(Array(round.holes.prefix(9)), label: "OUT")
            if round.holes.count > 9 { card(Array(round.holes.suffix(round.holes.count - 9)), label: "IN") }
            HStack(spacing: 0) {
                stat("FIR", "\(round.fairwaysHit)/\(round.fairwayHoles.count)")
                stat("GIR", "\(round.girs)/\(round.holes.count)")
                stat("Putts", "\(round.putts)")
                stat(net == nil ? "Penalties" : "Net", net.map(String.init) ?? "\(round.penalties)")
            }
            HStack {
                Rectangle().fill(Gold.hairline).frame(height: 0.8)
                Text("FAIRWAY LEDGER").font(.body(8.5, .bold)).tracking(2.4).foregroundStyle(Gold.leaf.opacity(0.7))
                Rectangle().fill(Gold.hairline).frame(height: 0.8)
            }
        }
        .padding(22)
        .background(ZStack { Gold.ink; RadialGradient(colors: [Gold.leaf.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 360) })
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 1).padding(6))
    }

    private func card(_ holes: [Hole], label: String) -> some View {
        HStack(spacing: 3) {
            ForEach(holes) { h in
                let d = h.score - h.par
                VStack(spacing: 2) {
                    Text("\(h.id)").font(.body(7.5, .bold)).foregroundStyle(Gold.muted)
                    ZStack {
                        if d < 0 { Circle().strokeBorder(Gold.leaf, lineWidth: 1).frame(width: 22, height: 22) }
                        if d > 0 { RoundedRectangle(cornerRadius: 2).strokeBorder(Gold.ivory.opacity(0.35), lineWidth: 1).frame(width: 21, height: 21) }
                        Text("\(h.score)").font(.figure(13)).foregroundStyle(d < 0 ? Gold.pale : Gold.ivory)
                    }.frame(height: 24)
                }.frame(maxWidth: .infinity)
            }
            VStack(spacing: 2) {
                Text(label).font(.body(7.5, .bold)).foregroundStyle(Gold.muted)
                Text("\(holes.reduce(0) { $0 + $1.score })").font(.figure(14)).foil().frame(height: 24)
            }.frame(width: 30)
        }
    }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.figure(16)).foregroundStyle(Gold.ivory)
            Text(l.uppercased()).font(.body(8.5, .bold)).tracking(1.2).foregroundStyle(Gold.muted)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: Screenshot-only

/// The widgets and the round's Live Activity on a home screen, for the App Store screenshot.
/// The real widgets draw these same views.
struct WidgetShowcase: View {
    @Environment(Ledger.self) private var ledger
    var body: some View {
        let g = ledger.glance(unlocked: true, weeklyTarget: 240)
        let r = ledger.rounds.first ?? Round()
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.10), Color(red: 0.04, green: 0.06, blue: 0.05), Gold.ink], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 22) {
                VStack(spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.body(17, .semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("9:41").font(.system(size: 84, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                }.padding(.top, 50)
                RoundLiveView(course: r.course, s: RoundLive.state(r, hole: min(11, r.holes.count - 1)))
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Gold.ink.opacity(0.92)))
                    .padding(.horizontal, 14)
                HStack(spacing: 22) {
                    tile(HandicapGlanceView(g: g), w: 170, h: 170)
                    VStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 14) { ForEach(0..<2, id: \.self) { _ in RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)).frame(width: 64, height: 64) } }
                        }
                    }
                }
                tile(LedgerGlanceView(g: g), w: 364, h: 170)
                Spacer()
            }
        }
    }
    private func tile<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
        v.padding(16).frame(width: w, height: h, alignment: .topLeading)
            .background(LacquerBackground().clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 0.6))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}
