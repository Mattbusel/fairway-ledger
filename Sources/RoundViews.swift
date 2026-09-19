import SwiftUI

struct RoundsView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "\(ledger.rounds.count) rounds", title: "Rounds")
                Spacer()
                Button { router.editingRound = Round() } label: {
                    Image(systemName: "plus").font(.body(18, .semibold)).foregroundStyle(Gold.ink)
                        .frame(width: 48, height: 48).background(Circle().fill(Gold.foil))
                        .shadow(color: Gold.leaf.opacity(0.4), radius: 12)
                }
                .buttonStyle(PressStyle())
            }
            if let best = ledger.rounds.min(by: { $0.toPar < $1.toPar }) {
                HStack(spacing: 10) {
                    StatTile(label: "Best", value: "\(best.score)", unit: best.toParText)
                    StatTile(label: "Average", value: String(format: "%.1f", Double(ledger.rounds.prefix(10).map(\.score).reduce(0, +)) / Double(min(10, ledger.rounds.count))), unit: "last 10")
                }
            }
            if ledger.rounds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "flag.2.crossed").font(.system(size: 38)).foil()
                    Text("No rounds yet").font(.display(20)).foregroundStyle(Gold.ivory)
                    Text("Log hole by hole: score, putts, fairway, penalties and bunkers. Your handicap builds from here.")
                        .font(.body(14)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).card(padding: 26)
            }
            ForEach(ledger.rounds) { r in
                Button { router.editingRound = r } label: { RoundCard(round: r) }.buttonStyle(PressStyle())
            }
        }
    }
}

struct RoundCard: View {
    let round: Round
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(round.course.isEmpty ? "Round" : round.course).font(.display(20, .medium)).foregroundStyle(Gold.ivory)
                    Text("\(round.date.ledgerDay) · \(round.tees) tees · \(String(format: "%.1f", round.rating))/\(round.slope)")
                        .font(.body(12)).foregroundStyle(Gold.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(round.score)").font(.figure(40, .light)).foil()
                    Text(round.toParText).font(.body(12, .bold)).foregroundStyle(round.toPar <= 0 ? Gold.good : Gold.muted)
                }
            }
            MiniScorecard(holes: round.holes)
            HStack(spacing: 0) {
                stat("FIR", "\(round.fairwaysHit)/\(round.fairwayHoles.count)")
                stat("GIR", "\(round.girs)/18")
                stat("Putts", "\(round.putts)")
                stat("Scr", "\(pct(round.scrambles.made, round.scrambles.tries))%")
            }
        }
        .card()
    }
    private func stat(_ l: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.figure(16)).foregroundStyle(Gold.ivory)
            Text(l.uppercased()).font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Eighteen little squares, coloured the way a scorecard marks them.
struct MiniScorecard: View {
    let holes: [Hole]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(holes) { h in
                let d = h.score - h.par
                RoundedRectangle(cornerRadius: 3)
                    .fill(d < 0 ? AnyShapeStyle(Gold.foil) : d == 0 ? AnyShapeStyle(Gold.leaf.opacity(0.28)) : d == 1 ? AnyShapeStyle(Gold.ivory.opacity(0.12)) : AnyShapeStyle(Gold.bad.opacity(0.55)))
                    .frame(height: 16)
                    .overlay(Text("\(h.score)").font(.body(8.5, .bold)).foregroundStyle(d < 0 ? Gold.ink : Gold.ivory.opacity(0.75)))
            }
        }
    }
}

/// Hole by hole entry. One hole on screen at a time, big targets, swipe between holes.
struct ScorecardView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var round: Round
    @State private var hole = 0
    @State private var showDetails = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            LacquerBackground()
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body(13, .bold)).foregroundStyle(Gold.ivory.opacity(0.7))
                            .frame(width: 36, height: 36).background(Circle().fill(Gold.lacquerHi))
                    }
                    Spacer()
                    Button { showDetails.toggle() } label: {
                        HStack(spacing: 6) {
                            Text(round.course.isEmpty ? "Course details" : round.course).font(.display(17, .medium)).lineLimit(1)
                            Image(systemName: "chevron.down").font(.body(11, .bold)).rotationEffect(.degrees(showDetails ? 180 : 0))
                        }
                        .foregroundStyle(Gold.ivory)
                    }
                    Spacer()
                    Button {
                        ledger.upsert(round); Haptic.done(); dismiss()
                    } label: {
                        Text("Save").font(.body(14, .semibold)).foregroundStyle(Gold.ink)
                            .padding(.horizontal, 16).frame(height: 36).background(Capsule().fill(Gold.foil))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if showDetails { details.transition(.move(edge: .top).combined(with: .opacity)) }

                totals
                holeStrip
                TabView(selection: $hole) {
                    ForEach(round.holes.indices, id: \.self) { i in
                        HoleEditor(hole: $round.holes[i]).tag(i).padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .animation(.snappy, value: showDetails)
        .onCue { cue in
            withAnimation(.snappy) {
                switch cue {
                case "card.course": showDetails = true; round.course = "Pine Hollow"
                case "card.closeDetails": showDetails = false
                case "card.birdie": round.holes[hole].score = round.holes[hole].par - 1; round.holes[hole].putts = 1
                case "card.par": round.holes[hole].putts = 2
                case "card.bogey": round.holes[hole].score = round.holes[hole].par + 1; round.holes[hole].putts = 2
                case "card.double": round.holes[hole].score = round.holes[hole].par + 2; round.holes[hole].putts = 3
                case "card.next": hole = min(hole + 1, round.holes.count - 1)
                case "card.save": ledger.upsert(round); Haptic.done(); dismiss()
                default: break
                }
            }
        }
    }

    private var details: some View {
        VStack(spacing: 12) {
            LedgerField(label: "Course", text: $round.course, prompt: "Course name")
            HStack(spacing: 10) {
                LedgerField(label: "Tees", text: $round.tees, prompt: "White")
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Rating / Slope")
                    HStack {
                        TextField("", value: $round.rating, format: .number.precision(.fractionLength(1))).keyboardType(.decimalPad)
                        Text("/").foregroundStyle(Gold.muted)
                        TextField("", value: $round.slope, format: .number).keyboardType(.numberPad)
                    }
                    .font(.display(17)).foregroundStyle(Gold.ivory)
                }
                .card(padding: 16, radius: 18)
            }
            DatePicker("Date", selection: $round.date, displayedComponents: .date)
                .font(.body(15, .medium)).foregroundStyle(Gold.ivory).card(padding: 14, radius: 18)
            LedgerField(label: "Notes", text: $round.notes, prompt: "What decided the round?", multiline: true)
            if ledger.rounds.contains(where: { $0.id == round.id }) {
                Button("Delete round", role: .destructive) { confirmDelete = true }.font(.body(14, .semibold))
                    .confirmationDialog("Delete this round?", isPresented: $confirmDelete) {
                        Button("Delete", role: .destructive) { ledger.rounds.removeAll { $0.id == round.id }; dismiss() }
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    private var totals: some View {
        let out = round.holes.prefix(9).reduce(0) { $0 + $1.score }
        let inn = round.holes.suffix(9).reduce(0) { $0 + $1.score }
        return HStack(spacing: 0) {
            total("Out", "\(out)")
            total("In", "\(inn)")
            total("Total", "\(round.score)", big: true)
            total("To par", round.toParText)
            total("Putts", "\(round.putts)")
        }
        .padding(.vertical, 12)
        .card(padding: 4, radius: 20)
        .padding(.horizontal, 20)
    }

    private func total(_ l: String, _ v: String, big: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.figure(big ? 28 : 19, big ? .regular : .medium))
                .foregroundStyle(big ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ivory))
                .contentTransition(.numericText())
            Text(l.uppercased()).font(.body(9, .bold)).tracking(1.1).foregroundStyle(Gold.muted)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: v)
    }

    private var holeStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(round.holes.indices, id: \.self) { i in
                        let h = round.holes[i]
                        let d = h.score - h.par
                        let on = i == hole
                        Button { Haptic.tap(); withAnimation(.snappy) { hole = i } } label: {
                            VStack(spacing: 3) {
                                Text("\(h.id)").font(.body(10, .bold)).foregroundStyle(on ? Gold.ink.opacity(0.7) : Gold.muted)
                                Text("\(h.score)").font(.figure(17)).foregroundStyle(on ? Gold.ink : d < 0 ? Gold.pale : d > 0 ? Gold.ivory.opacity(0.8) : Gold.ivory)
                            }
                            .frame(width: 42, height: 54)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(d < 0 && !on ? Gold.leaf : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressStyle())
                        .id(i)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: hole) { _, h in withAnimation { proxy.scrollTo(h, anchor: .center) } }
        }
    }
}

struct HoleEditor: View {
    @Binding var hole: Hole

    private var scoreName: String {
        switch hole.score - hole.par {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        case 3: return "Triple"
        default: return "+\(hole.score - hole.par)"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow("Hole \(hole.id)")
                            HStack(spacing: 6) {
                                ForEach([3, 4, 5], id: \.self) { p in
                                    Button { Haptic.tap(); hole.par = p; if p == 3 { hole.fairway = .none } else if hole.fairway == .none { hole.fairway = .hit } } label: {
                                        Text("Par \(p)").font(.body(13, .semibold))
                                            .foregroundStyle(hole.par == p ? Gold.ink : Gold.ivory.opacity(0.7))
                                            .padding(.horizontal, 12).frame(height: 30)
                                            .background(Capsule().fill(hole.par == p ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ink.opacity(0.5))))
                                    }
                                }
                            }
                        }
                        Spacer()
                        Text(scoreName).font(.display(20).italic()).foregroundStyle(hole.score < hole.par ? Gold.pale : Gold.muted)
                            .contentTransition(.opacity)
                    }
                    HStack(spacing: 24) {
                        bigButton("minus") { hole.score = max(1, hole.score - 1); hole.putts = min(hole.putts, hole.score) }
                        Text("\(hole.score)").font(.figure(88, .ultraLight)).foil()
                            .shadow(color: Gold.leaf.opacity(0.3), radius: 20)
                            .frame(minWidth: 110)
                            .contentTransition(.numericText())
                        bigButton("plus") { hole.score = min(15, hole.score + 1) }
                    }
                    .animation(.snappy, value: hole.score)
                }
                .card(padding: 20, radius: 26)

                VStack(spacing: 16) {
                    LedgerStepper(label: "Putts", value: $hole.putts, range: 0...min(6, hole.score))
                    Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8)
                    LedgerStepper(label: "Penalty strokes", value: $hole.penalties, range: 0...6)
                    Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8)
                    Toggle(isOn: $hole.sand) {
                        Text("In a greenside bunker").font(.body(15, .medium)).foregroundStyle(Gold.ivory.opacity(0.9))
                    }
                    .tint(Gold.leaf)
                }
                .card(padding: 18)

                if hole.par > 3 {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow("Tee shot")
                        HStack(spacing: 8) {
                            ForEach([FairwayResult.left, .hit, .right], id: \.self) { f in
                                Button { Haptic.tap(); hole.fairway = f } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: f == .left ? "arrow.up.left" : f == .right ? "arrow.up.right" : "arrow.up")
                                            .font(.body(18, .semibold))
                                        Text(f == .hit ? "Fairway" : f.rawValue).font(.body(12.5, .semibold))
                                    }
                                    .foregroundStyle(hole.fairway == f ? Gold.ink : Gold.ivory.opacity(0.75))
                                    .frame(maxWidth: .infinity).frame(height: 70)
                                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hole.fairway == f ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.ink.opacity(0.5))))
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }
                    .card(padding: 18)
                }

                HStack(spacing: 10) {
                    badge("GIR", hole.gir)
                    if let ud = hole.upAndDown { badge("Up & down", ud) }
                    if hole.putts >= 3 { badge("3-putt", false) }
                }
                .padding(.bottom, 30)
            }
        }
    }

    private func bigButton(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); act() } label: {
            Image(systemName: icon).font(.body(22, .semibold)).foregroundStyle(Gold.leaf)
                .frame(width: 64, height: 64).background(Circle().fill(Gold.ink.opacity(0.6)))
                .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }

    private func badge(_ t: String, _ good: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: good ? "checkmark.circle.fill" : "xmark.circle")
            Text(t)
        }
        .font(.body(12.5, .semibold))
        .foregroundStyle(good ? Gold.good : Gold.muted)
        .padding(.horizontal, 12).frame(height: 32)
        .background(Capsule().fill(Gold.lacquerHi))
    }
}
