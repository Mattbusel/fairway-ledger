import StoreKit
import SwiftUI

/// One challenge a month, the same for everyone, tracked from what is already in the ledger.
/// Free: it is the reason to open the app between rounds.
struct Challenge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let how: String
    let icon: String
    let target: Int
    let unit: String
    let progress: (Ledger, DateInterval) -> Int

    static var month: DateInterval { Calendar.current.dateInterval(of: .month, for: .now)! }
    static var monthKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
    static var monthName: String { Date.now.formatted(.dateTime.month(.wide)) }

    /// January first. Each month has its own, and the calendar picks it.
    static let calendar: [Challenge] = [
        Challenge(id: "putts100", title: "Hundred putts holed", detail: "Hole 100 practice putts this month.",
                  how: "Log putting blocks in a practice session; every holed putt counts. The carpet at home counts too.",
                  icon: "flag.fill", target: 100, unit: "putts",
                  progress: { l, m in l.sessions.filter { m.contains($0.date) }.flatMap(\.blocks).filter { $0.kind.isPutting }.reduce(0) { $0 + $1.onTarget } }),
        Challenge(id: "balls500", title: "Five hundred balls", detail: "Hit 500 logged balls at the range this month.",
                  how: "Tap each ball in a live session. Full swing, wedges and short game all count.",
                  icon: "circle.grid.3x3.fill", target: 500, unit: "balls",
                  progress: { l, m in l.sessions.filter { m.contains($0.date) }.flatMap(\.blocks).filter { !$0.kind.isPutting }.reduce(0) { $0 + $1.balls } }),
        Challenge(id: "minutes600", title: "Ten hours of practice", detail: "Log 600 practice minutes this month.",
                  how: "Every session counts, including minutes logged from the widget or Siri.",
                  icon: "timer", target: 600, unit: "min",
                  progress: { l, m in l.sessions.filter { m.contains($0.date) }.reduce(0) { $0 + $1.minutes } }),
        Challenge(id: "rounds3", title: "Three rounds", detail: "Play and log three rounds this month.",
                  how: "Nine-hole and eighteen-hole cards both count.",
                  icon: "flag.2.crossed", target: 3, unit: "rounds",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) }.count }),
        Challenge(id: "fairways", title: "Find the short grass", detail: "Hit half your fairways or more in an eighteen-hole round.",
                  how: "Mark each tee shot on the scorecard: hit, left or right.",
                  icon: "arrow.up", target: 1, unit: "round",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) && !$0.isNine && !$0.fairwayHoles.isEmpty && $0.fairwaysHit * 2 >= $0.fairwayHoles.count }.isEmpty ? 0 : 1 }),
        Challenge(id: "greens6", title: "Six greens", detail: "Hit six greens in regulation in one round.",
                  how: "Fairway Ledger works out greens in regulation from your score and putts on each hole.",
                  icon: "circle.circle", target: 6, unit: "greens",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) }.map(\.girs).max() ?? 0 }),
        Challenge(id: "birdies2", title: "Birdie hunt", detail: "Make two birdies (or better) this month.",
                  how: "Every hole under par on any card this month counts.",
                  icon: "bird.fill", target: 2, unit: "birdies",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) }.flatMap(\.holes).filter { $0.score < $0.par }.count }),
        Challenge(id: "clean", title: "A clean card", detail: "Play an eighteen-hole round without a penalty stroke.",
                  how: "Log penalties on each hole. A round with none completes it.",
                  icon: "checkmark.shield.fill", target: 1, unit: "round",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) && !$0.isNine && $0.penalties == 0 }.isEmpty ? 0 : 1 }),
        Challenge(id: "scramble4", title: "The scrambler", detail: "Get up and down four times in one round.",
                  how: "Miss a green, still make par: that is an up and down. The scorecard spots them for you.",
                  icon: "arrow.uturn.up", target: 4, unit: "saves",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) }.map { $0.scrambles.made }.max() ?? 0 }),
        Challenge(id: "range8", title: "Eight at the range", detail: "Log eight practice sessions this month.",
                  how: "Any session counts: range, short game area, putting green or a quick log.",
                  icon: "figure.golf", target: 8, unit: "sessions",
                  progress: { l, m in l.sessions.filter { m.contains($0.date) }.count }),
        Challenge(id: "zero3", title: "Zero three-putts", detail: "Play an eighteen-hole round without a three-putt.",
                  how: "Lag it close. Log your putts on every hole and a round with no three-putts completes it.",
                  icon: "flag.slash.fill", target: 1, unit: "round",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) && !$0.isNine && $0.threePutts == 0 }.isEmpty ? 0 : 1 }),
        Challenge(id: "putts30", title: "Thirty or fewer", detail: "Take 30 putts or fewer in an eighteen-hole round.",
                  how: "Indoor sim rounds count too if you log them.",
                  icon: "30.circle", target: 1, unit: "round",
                  progress: { l, m in l.rounds.filter { m.contains($0.date) && !$0.isNine && $0.putts <= 30 }.isEmpty ? 0 : 1 }),
    ]

    static var current: Challenge {
        let m = Calendar.current.component(.month, from: .now)
        return calendar[(m - 1) % calendar.count]
    }

    func value(_ l: Ledger) -> Int { min(target, progress(l, Challenge.month)) }
    func done(_ l: Ledger) -> Bool { value(l) >= target }

    /// Months completed, as "2026-11:zero3".
    static var medals: [String] { UserDefaults.standard.stringArray(forKey: "challenge.medals") ?? [] }
    static func award(_ c: Challenge) -> Bool {
        let tag = monthKey + ":" + c.id
        var all = medals
        guard !all.contains(tag) else { return false }
        all.append(tag)
        UserDefaults.standard.set(all, forKey: "challenge.medals")
        return true
    }
}

/// Home's card: this month's challenge and the progress toward it.
struct ChallengeCard: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.requestReview) private var requestReview
    @State private var bounce = 0

    var body: some View {
        let c = Challenge.current
        let v = c.value(ledger), done = c.done(ledger)
        Button { router.challenge = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    FoilRing(progress: Double(v) / Double(c.target), width: 6).frame(width: 62, height: 62)
                    Image(systemName: done ? "checkmark.seal.fill" : c.icon).font(.system(size: 22, weight: .semibold)).foil()
                        .symbolEffect(.bounce, value: bounce)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("\(Challenge.monthName) challenge")
                    Text(c.title).font(.display(20, .medium)).foregroundStyle(Gold.ivory)
                    Text(done ? "Done. The medal is in your cabinet." : "\(v) of \(c.target) \(c.unit) · \(c.detail)")
                        .font(.body(12.5)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .card(padding: 18)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(Challenge.monthName) challenge, \(c.title), \(v) of \(c.target) \(c.unit)")
        .onAppear { celebrate(c) }
        .onChange(of: v) { _, _ in celebrate(c) }
    }

    /// The first time a month's challenge is done: a bounce, a buzz, and (once a version) the review prompt.
    private func celebrate(_ c: Challenge) {
        let args = ProcessInfo.processInfo.arguments
        // Never in screenshots, the preview or the review recording: no prompt over staged screens.
        guard c.done(ledger), !args.contains("-shot"), !args.contains("-preview"), !args.contains("-demoAutoplay"), Challenge.award(c) else { return }
        bounce += 1
        Haptic.done()
        ReviewAsk.happyMoment { requestReview() }
    }
}

/// The challenge page: how to do it, and the medal cabinet.
struct ChallengeSheet: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let c = Challenge.current
        let v = c.value(ledger)
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "\(Challenge.monthName) challenge", title: c.title) { dismiss() }.padding(.horizontal, -20)
                    VStack(spacing: 14) {
                        ZStack {
                            FoilRing(progress: Double(v) / Double(c.target), width: 12).frame(width: 190, height: 190)
                            VStack(spacing: 2) {
                                Image(systemName: c.done(ledger) ? "checkmark.seal.fill" : c.icon).font(.system(size: 30, weight: .semibold)).foil()
                                Text("\(v)").font(.figure(52, .light)).foil()
                                Text("of \(c.target) \(c.unit)").font(.body(12, .medium)).foregroundStyle(Gold.muted)
                            }
                        }
                        Text(c.detail).font(.display(18)).foregroundStyle(Gold.ivory).multilineTextAlignment(.center)
                        Text(daysLeft).font(.body(12.5, .semibold)).foregroundStyle(Gold.muted)
                    }
                    .frame(maxWidth: .infinity).card(padding: 22)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("How it counts")
                        Text(c.how).font(.body(14)).foregroundStyle(Gold.ivory.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()
                    HStack(spacing: 12) {
                        FoilButton("Start practice", icon: "play.fill") { go { router.live = PracticeSession() } }
                        GhostButton("Log round", icon: "flag.fill") { go { router.editingRound = ledger.draft ?? Round() } }.frame(width: 140)
                    }
                    cabinet
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }

    private var daysLeft: String {
        let end = Challenge.month.end
        let d = max(0, Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 0)
        return d == 0 ? "Last day" : "\(d) days left this month"
    }

    private func go(_ open: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { open() }
    }

    private var cabinet: some View {
        let medals = Challenge.medals
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Medal cabinet")
            if medals.isEmpty {
                Text("Finish a monthly challenge and its medal lands here. A new challenge starts on the first of every month.")
                    .font(.body(13)).foregroundStyle(Gold.muted).card()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(medals, id: \.self) { tag in
                        let parts = tag.split(separator: ":").map(String.init)
                        let ch = Challenge.calendar.first { $0.id == parts.last }
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(Gold.foil).frame(width: 54, height: 54)
                                Image(systemName: ch?.icon ?? "medal.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Gold.ink)
                            }
                            Text(ch?.title ?? "Challenge").font(.body(11, .semibold)).foregroundStyle(Gold.ivory).multilineTextAlignment(.center).lineLimit(2)
                            Text(parts.first ?? "").font(.body(10)).foregroundStyle(Gold.muted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Gold.lacquer))
                    }
                }
            }
        }
    }
}

/// The App Store review prompt, only at a happy moment and at most once per app version.
enum ReviewAsk {
    static func happyMoment(_ ask: () -> Void) {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        guard UserDefaults.standard.string(forKey: "review.askedVersion") != v else { return }
        UserDefaults.standard.set(v, forKey: "review.askedVersion")
        ask()
    }
}
