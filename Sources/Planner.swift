import SwiftUI

/// A practice session built from the ledger: where your rounds lose strokes, which clubs you
/// carry, which putts you miss. One a week is free; more come in packs of three.
struct PracticePlan: Identifiable {
    let id = UUID()
    var title: String
    var minutes: Int
    var steps: [Step]

    struct Step: Identifiable {
        let id = UUID()
        var block: DrillBlock
        var minutes: Int
        var why: String
        var how: String
    }

    /// A live session with the plan's blocks waiting, tallies at zero.
    var session: PracticeSession {
        var s = PracticeSession()
        s.focus = title
        s.blocks = steps.map(\.block)
        return s
    }
}

enum Planner {
    /// One weakness the plan can work on, ranked by how many strokes it seems to cost.
    private struct Need { let cost: Double; let step: PracticePlan.Step }

    /// `variant` moves the plan down the list of needs, so a second plan in a week is a different session.
    static func make(_ l: Ledger, variant: Int = 0) -> PracticePlan {
        let rs = Array(l.rounds.filter { !$0.isNine }.prefix(10))
        let n = Double(max(1, rs.count))
        var needs: [Need] = []

        // Putting: three-putts and the distance you hole least often.
        let threes = Double(rs.reduce(0) { $0 + $1.threePutts }) / n
        let putts = Double(rs.reduce(0) { $0 + $1.putts }) / n
        let byDist = l.puttingByDistance.filter { $0.tries >= 10 }
        let worstShort = byDist.filter { $0.feet <= 10 }.min { Double($0.made) / Double($0.tries) < Double($1.made) / Double($1.tries) }
        var lag = DrillBlock(kind: .putting); lag.target = 30; lag.note = "Lag ladder: 20, 30, 40 ft. Score it as holed or inside 3 ft."
        needs.append(Need(cost: rs.isEmpty ? 1.2 : threes * 1.0 + max(0, putts - 31) * 0.4,
                          step: .init(block: lag, minutes: 15, why: rs.isEmpty ? "Most strokes for most golfers are lost on the green." : String(format: "%.1f three-putts a round. Lag speed saves the most.", threes),
                                      how: "Ten balls from each distance. Count how many finish inside a putter length.")))
        var short = DrillBlock(kind: .putting); short.target = worstShort?.feet ?? 6; short.note = "Clock drill at \(short.target) ft: four tees around the hole."
        if let w = worstShort {
            needs.append(Need(cost: 1.2 * (1 - Double(w.made) / Double(max(1, w.tries))) + 0.3,
                              step: .init(block: short, minutes: 10, why: "You hole \(Int(Double(w.made) / Double(w.tries) * 100))% from \(w.feet) ft. That one shows up every round.",
                                          how: "Four balls round the clock, then go again. Reset if you miss two in a row.")))
        }

        // Approach: greens hit, with the club you most often have in.
        let gir = rs.isEmpty ? 0.3 : Double(rs.reduce(0) { $0 + $1.girs }) / Double(max(1, rs.reduce(0) { $0 + $1.holes.count }))
        let mid = l.bag.first { $0.name.hasSuffix("7i") || $0.name == "7i" } ?? l.bag.first { $0.carry >= 140 && $0.carry <= 175 } ?? Club(name: "7i", loft: 31, carry: 150, total: 158)
        var approach = DrillBlock(kind: .fullSwing); approach.club = mid.name; approach.target = mid.carry
        approach.note = "Pick a flag at \(mid.carry) yd. On target means inside a 15-yard circle."
        needs.append(Need(cost: max(0, 0.45 - gir) * 6,
                          step: .init(block: approach, minutes: 15, why: rs.isEmpty ? "Greens in regulation are the best single predictor of score." : "\(Int(gir * 100))% of greens hit. Your \(mid.name) carries \(mid.carry) yd; build a stock shot with it.",
                                      how: "Twenty balls, a new target every five. Log carry and where it finished.")))

        // Off the tee.
        let fir = rs.isEmpty ? 0.5 : Double(rs.reduce(0) { $0 + $1.fairwaysHit }) / Double(max(1, rs.reduce(0) { $0 + $1.fairwayHoles.count }))
        let pens = Double(rs.reduce(0) { $0 + $1.penalties }) / n
        var tee = DrillBlock(kind: .fullSwing); tee.club = l.bag.first?.name ?? "Driver"; tee.target = l.bag.first?.carry ?? 230
        tee.note = "Fairway window: two flags 30 yards apart. Hit it inside or it's a miss."
        needs.append(Need(cost: max(0, 0.55 - fir) * 4 + pens * 0.9,
                          step: .init(block: tee, minutes: 10, why: rs.isEmpty ? "A ball in play is a hole you can par." : String(format: "%d%% fairways and %.1f penalty strokes a round.", Int(fir * 100), pens),
                                      how: "Play your stock shape at the window. Count windows hit out of fifteen.")))

        // Around the green.
        let scr = rs.reduce(0) { $0 + $1.scrambles.tries }
        let scrRate = scr == 0 ? 0.3 : Double(rs.reduce(0) { $0 + $1.scrambles.made }) / Double(scr)
        var chip = DrillBlock(kind: .chipping); chip.target = 15; chip.note = "Up and down: chip, then hole the putt. Nine stations."
        needs.append(Need(cost: max(0, 0.45 - scrRate) * 4,
                          step: .init(block: chip, minutes: 15, why: scr == 0 ? "Missed greens are coming; this is how pars survive them." : "You get up and down \(Int(scrRate * 100))% of the time.",
                                      how: "Nine lies round a green. Chip and putt out every one; count the up-and-downs.")))

        // Wedges, from the distance practice says is shakiest.
        let wedge = l.bag.last { $0.loft >= 50 } ?? Club(name: "54°", loft: 54, carry: 90, total: 93)
        var ladder = DrillBlock(kind: .wedges); ladder.club = wedge.name; ladder.target = wedge.carry
        ladder.note = "Distance ladder: \(max(30, wedge.carry - 30)), \(max(40, wedge.carry - 15)), \(wedge.carry) yd."
        needs.append(Need(cost: 0.6,
                          step: .init(block: ladder, minutes: 10, why: "Inside 100 yards is where scores drop fastest.",
                                      how: "Three balls to each rung, then climb back down. Log every carry.")))

        // Trouble the practice log keeps finding.
        if let top = l.missTotals.max(by: { $0.value < $1.value }), top.value >= 8 {
            let miss = top.key, count = top.value
            var fix = DrillBlock(kind: .fullSwing); fix.club = mid.name; fix.target = mid.carry
            fix.note = "\(miss.rawValue) is your most logged miss. Alignment stick down, half swings first."
            needs.append(Need(cost: 0.8, step: .init(block: fix, minutes: 10, why: "\(miss.rawValue) shows up \(count) times in your practice log.",
                                                     how: "Ten half swings, ten three-quarter, ten full. Only move up when contact is solid.")))
        }

        let ranked = needs.sorted { $0.cost > $1.cost }
        // Start from a different need each time, then fill to about an hour.
        let shift = ranked.isEmpty ? 0 : variant % ranked.count
        let rotated = Array(ranked[shift...] + ranked[..<shift])
        var steps: [PracticePlan.Step] = []
        var mins = 0
        for need in rotated where mins + need.step.minutes <= 60 && steps.count < 4
            && !steps.contains(where: { $0.block.title == need.step.block.title }) {
            steps.append(need.step); mins += need.step.minutes
        }
        let title = steps.first.map { s in
            switch s.block.kind {
            case .putting: return "Green speed and short putts"
            case .chipping, .pitching, .bunker: return "Save the pars"
            case .wedges: return "Wedge distances"
            default: return s.block.club == (l.bag.first?.name ?? "Driver") ? "Fairways first" : "Hit more greens"
            }
        } ?? "Practice plan"
        return PracticePlan(title: title, minutes: mins, steps: steps)
    }
}

/// The plan, step by step, with the reasons from your own numbers.
struct PlanSheet: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let plan: PracticePlan

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: "Practice plan · \(plan.minutes) min", title: plan.title) { dismiss() }.padding(.horizontal, -20)
                    Text("Built from your last rounds and your practice log. Each block opens in the live session with its target set.")
                        .font(.body(14)).foregroundStyle(Gold.muted)
                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { i, s in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(i + 1)").font(.figure(30, .light)).foil().frame(width: 30, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.block.title).font(.display(19, .medium)).foregroundStyle(Gold.ivory)
                                    Label(s.block.kind.rawValue, systemImage: s.block.kind.icon).font(.body(12, .semibold)).foregroundStyle(Gold.pale)
                                }
                                Spacer()
                                Text("\(s.minutes) min").font(.body(12, .semibold)).foregroundStyle(Gold.muted)
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "chart.bar.xaxis").font(.body(12, .bold)).foil().frame(width: 18)
                                Text(s.why).font(.body(13.5)).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "figure.golf").font(.body(12, .bold)).foil().frame(width: 18)
                                Text(s.how).font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                    }
                    FoilButton("Start this session", icon: "play.fill") {
                        let s = plan.session
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.live = s }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
    }
}

/// Home's card: this week's plan, ready to draw.
struct PlanCard: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Extras.self) private var extras

    var body: some View {
        let preview = Planner.make(ledger, variant: extras.plansThisWeek)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(extras.freePlanLeft ? "This week's plan · free" : extras.plans > 0 ? "Practice plans · \(extras.plans) banked" : "Practice plans")
                    Text(extras.freePlanLeft || extras.plans > 0 ? preview.title : "Another plan this week").font(.display(21, .medium)).foregroundStyle(Gold.ivory)
                }
                Spacer()
                Image(systemName: "list.bullet.clipboard").font(.system(size: 22)).foil()
            }
            if extras.freePlanLeft || extras.plans > 0 {
                Text(preview.steps.first?.why ?? "A session built from your own numbers.").font(.body(13.5)).foregroundStyle(Gold.muted)
                    .fixedSize(horizontal: false, vertical: true)
                FoilButton("Build it · \(preview.minutes) min", icon: "wand.and.stars") {
                    if extras.spendPlan() { router.plan = Planner.make(ledger, variant: extras.plansThisWeek - 1) }
                }
            } else {
                Text("This week's free plan is drawn. Each new one leans on the next weakness in your numbers.").font(.body(13.5)).foregroundStyle(Gold.muted)
                    .fixedSize(horizontal: false, vertical: true)
                FoilButton(extras.busy == Extras.plansID ? "One moment" : "3 more plans · \(extras.price(Extras.plansID))", icon: "plus") {
                    Task {
                        if await extras.buy(Extras.plansID), extras.spendPlan() { router.plan = Planner.make(ledger, variant: extras.plansThisWeek - 1) }
                    }
                }
            }
        }
        .card(padding: 20)
    }
}
