import SwiftUI

struct HomeView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @State private var newGoal = ""
    @AppStorage("weeklyTarget") private var weeklyTarget = 240

    var body: some View {
        Page {
            header
            hero
            HStack(spacing: 12) {
                FoilButton("Start practice", icon: "play.fill") {
                    router.live = PracticeSession()
                }
                GhostButton("Log round", icon: "flag.fill") { router.editingRound = Round() }
                    .frame(width: 138)
            }
            if let last = ledger.sessions.first { lastSession(last) }
            goals
            if !ledger.rounds.isEmpty { recentRounds }
            if ledger.sessions.isEmpty && ledger.rounds.isEmpty { emptyState }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let part = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return ledger.name.isEmpty ? part : "\(part), \(ledger.name)"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                Text(greeting).font(.display(30)).foregroundStyle(Gold.ivory).lineLimit(2)
            }
            Spacer()
            Monogram()
        }
        .padding(.horizontal, 4).padding(.top, 12)
    }

    private var hero: some View {
        let week = ledger.minutes(inLast: 7)
        let progress = Double(week) / Double(max(weeklyTarget, 1))
        return HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HANDICAP INDEX").font(.body(10.5, .semibold)).tracking(1.8).foregroundStyle(Gold.muted)
                    Text(ledger.handicap.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.figure(58, .light)).foil()
                        .shadow(color: Gold.leaf.opacity(0.35), radius: 18)
                    Text(ledger.handicap == nil ? "Log 3 rounds to calculate" : "From your best \(min(8, max(1, ledger.rounds.count / 2))) of \(min(20, ledger.rounds.count)) rounds")
                        .font(.body(12)).foregroundStyle(Gold.muted)
                }
                HStack(spacing: 18) {
                    mini("\(ledger.practiceStreakWeeks)", "week streak")
                    mini("\(ledger.sessions.prefix(10).reduce(0) { $0 + $1.balls })", "balls, last 10")
                }
            }
            Spacer(minLength: 0)
            ZStack {
                FoilRing(progress: progress, width: 9).frame(width: 116, height: 116)
                VStack(spacing: 0) {
                    Text("\(week)").font(.figure(30)).foil()
                    Text("of \(weeklyTarget) min").font(.body(10.5, .medium)).foregroundStyle(Gold.muted)
                    Text("this week").font(.body(10.5, .medium)).foregroundStyle(Gold.muted)
                }
            }
            .contextMenu {
                ForEach([120, 180, 240, 360, 480], id: \.self) { m in Button("\(m) min a week") { weeklyTarget = m } }
            }
        }
        .card(padding: 22, radius: 28)
    }

    private func mini(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.figure(19)).foregroundStyle(Gold.ivory)
            Text(l).font(.body(11)).foregroundStyle(Gold.muted)
        }
    }

    private func lastSession(_ s: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Last session", trailing: "Open") { router.viewing = s }
            Button { router.viewing = s } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(s.date.ledgerDay).font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                        Spacer()
                        DiamondRating(value: .constant(s.rating), size: 11).allowsHitTesting(false)
                    }
                    if !s.swingThought.isEmpty {
                        Text("“\(s.swingThought)”").font(.display(21).italic()).foregroundStyle(Gold.ivory)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        ForEach(s.blocks.prefix(3)) { b in
                            Label(b.kind.rawValue, systemImage: b.kind.icon)
                                .font(.body(11.5, .semibold)).foregroundStyle(Gold.pale)
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Capsule().fill(Gold.leaf.opacity(0.1)))
                        }
                    }
                    if !s.workOn.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.turn.down.right").font(.body(12, .bold)).foil()
                            Text("Next: \(s.workOn)").font(.body(14)).foregroundStyle(Gold.ivory.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(PressStyle())
        }
    }

    private var goals: some View {
        @Bindable var ledger = ledger
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Goals")
            VStack(spacing: 0) {
                ForEach($ledger.goals) { $g in
                    HStack(spacing: 14) {
                        Button {
                            Haptic.tap(); withAnimation(.snappy) { g.done.toggle() }
                        } label: {
                            Image(systemName: g.done ? "checkmark.seal.fill" : "seal")
                                .font(.system(size: 22)).foregroundStyle(g.done ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.text).font(.display(17)).foregroundStyle(g.done ? Gold.muted : Gold.ivory).strikethrough(g.done, color: Gold.leaf)
                            if let due = g.due, !g.done {
                                Text("by \(due.shortDay)").font(.body(12)).foregroundStyle(Gold.muted)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .contextMenu { Button("Delete", role: .destructive) { ledger.goals.removeAll { $0.id == g.id } } }
                    Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8)
                }
                HStack(spacing: 12) {
                    Image(systemName: "plus").font(.body(15, .bold)).foil().frame(width: 22)
                    TextField("", text: $newGoal, prompt: Text("Add a goal, e.g. Break 85").foregroundStyle(Gold.faint))
                        .font(.display(17)).foregroundStyle(Gold.ivory)
                        .submitLabel(.done)
                        .onSubmit {
                            let t = newGoal.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            ledger.goals.append(Goal(text: t)); newGoal = ""; Haptic.done()
                        }
                }
                .padding(.vertical, 13)
            }
            .card(padding: 16)
        }
    }

    private var recentRounds: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Recent rounds", trailing: "All") { router.tab = .rounds }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ledger.rounds.prefix(6)) { r in
                        Button { router.editingRound = r } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(r.course).font(.body(13, .semibold)).foregroundStyle(Gold.ivory).lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(r.score)").font(.figure(36, .light)).foil()
                                    Text(r.toParText).font(.body(13, .semibold)).foregroundStyle(Gold.muted)
                                }
                                Text(r.date.shortDay).font(.body(11.5)).foregroundStyle(Gold.muted)
                            }
                            .frame(width: 126, alignment: .leading)
                            .card(padding: 16, radius: 20)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 6)
            }
            .padding(.horizontal, -18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.golf").font(.system(size: 42)).foil()
            Text("Your ledger is empty").font(.display(22)).foregroundStyle(Gold.ivory)
            Text("Start a practice session at the range, or log your last round. Everything stays on this phone.")
                .font(.body(14)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).card(padding: 26)
    }
}

/// A small gold crest.
struct Monogram: View {
    var body: some View {
        ZStack {
            Circle().fill(Gold.lacquerHi)
            Circle().strokeBorder(Gold.foil, lineWidth: 1.4)
            Circle().strokeBorder(Gold.leaf.opacity(0.3), lineWidth: 0.6).padding(4)
            Image(systemName: "flag.fill").font(.system(size: 17)).foil()
        }
        .frame(width: 50, height: 50)
        .shadow(color: Gold.leaf.opacity(0.25), radius: 12)
    }
}
