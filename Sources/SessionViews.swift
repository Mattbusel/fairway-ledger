import SwiftUI

/// After the range: how it went, in your own words.
struct FinishSessionView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var session: PracticeSession

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: session.date.ledgerDay, title: "How did it go?") { dismiss() }
                        .padding(.horizontal, -20)
                    summary
                    VStack(spacing: 18) {
                        ratingRow("Session", $session.rating)
                        divider
                        ratingRow("Mood", $session.mood)
                        divider
                        ratingRow("Energy", $session.energy)
                    }
                    .card()
                    LedgerField(label: "Where", text: $session.place, prompt: "Range, course, backyard net")
                    LedgerField(label: "Focus", text: $session.focus, prompt: "What were you working on?")
                    LedgerField(label: "Swing thought", text: $session.swingThought, prompt: "The one cue that worked")
                    LedgerField(label: "What clicked", text: $session.clicked, prompt: "Keep this", multiline: true)
                    LedgerField(label: "Work on next", text: $session.workOn, prompt: "Carry this into next time", multiline: true)
                    LedgerField(label: "Journal", text: $session.journal, prompt: "Anything else. Feel, conditions, what your coach said.", multiline: true)
                    FoilButton("Save to ledger", icon: "checkmark.seal.fill") {
                        ledger.upsert(session); Haptic.done(); dismiss()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }
        .onCue { cue in
            withAnimation(.snappy) {
                switch cue {
                case "fin.rating": session.rating = 4
                case "fin.mood": session.mood = 4; session.energy = 4
                case "fin.place": session.place = "Riverside range"
                case "fin.focus": session.focus = "7 iron strike"
                case "fin.thought": session.swingThought = "Finish tall, belt buckle to the target"
                case "fin.workOn": session.workOn = "Short putts. Missed two inside six feet."
                case "fin.save": ledger.upsert(session); Haptic.done(); dismiss()
                default: break
                }
            }
        }
    }

    private var divider: some View { Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8) }

    private func ratingRow(_ label: String, _ v: Binding<Int>) -> some View {
        HStack {
            Text(label).font(.display(18)).foregroundStyle(Gold.ivory)
            Spacer()
            DiamondRating(value: v, size: 22)
        }
    }

    private var summary: some View {
        let swings = session.blocks.filter { !$0.kind.isPutting }
        let pure = swings.reduce(0) { $0 + ($1.contact[.pure] ?? 0) }
        let hit = swings.reduce(0) { $0 + $1.balls }
        let putts = session.blocks.filter(\.kind.isPutting)
        let holed = putts.reduce(0) { $0 + $1.onTarget }, tried = putts.reduce(0) { $0 + $1.putts }
        return HStack(spacing: 10) {
            StatTile(label: "Minutes", value: "\(session.minutes)")
            StatTile(label: "Pure", value: pct(pure, hit), unit: "%")
            StatTile(label: "Holed", value: pct(holed, tried), unit: "%")
        }
    }
}

/// Read view of one session: the journal first, then the numbers.
struct SessionDetailView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let session: PracticeSession

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SheetHeader(eyebrow: session.date.ledgerDay, title: session.focus.isEmpty ? "Practice" : session.focus) { dismiss() }
                        .padding(.horizontal, -20).padding(.top, 10)
                    HStack(spacing: 16) {
                        Label("\(session.minutes) min", systemImage: "clock")
                        Label("\(session.balls) balls", systemImage: "circle.grid.3x3")
                        if !session.place.isEmpty { Label(session.place, systemImage: "mappin").lineLimit(1) }
                    }
                    .font(.body(12.5, .medium)).foregroundStyle(Gold.muted)

                    if !session.swingThought.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Swing thought")
                            Text("“\(session.swingThought)”").font(.display(24).italic()).foregroundStyle(Gold.ivory)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                    if !session.clicked.isEmpty { note("What clicked", session.clicked, "sparkles") }
                    if !session.workOn.isEmpty { note("Work on next", session.workOn, "arrow.turn.down.right") }
                    if !session.journal.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Journal")
                            Text(session.journal).font(.display(17)).foregroundStyle(Gold.ivory.opacity(0.9)).lineSpacing(5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                    ForEach(session.blocks) { b in BlockCard(block: b) }
                    HStack(spacing: 12) {
                        GhostButton("Edit notes", icon: "pencil") {
                            let s = session; dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.finishing = s }
                        }
                        GhostButton("Delete", icon: "trash") {
                            ledger.sessions.removeAll { $0.id == session.id }; dismiss()
                        }
                        .frame(width: 130)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
    }

    private func note(_ title: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.body(14, .semibold)).foil().frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(title)
                Text(text).font(.body(15)).foregroundStyle(Gold.ivory.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .card(padding: 16, radius: 20)
    }
}

struct BlockCard: View {
    let block: DrillBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: block.kind.icon).font(.body(15, .semibold)).foil()
                    .frame(width: 36, height: 36).background(Circle().fill(Gold.leaf.opacity(0.1)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.title).font(.body(15, .semibold)).foregroundStyle(Gold.ivory)
                    Text(block.kind.rawValue).font(.body(12)).foregroundStyle(Gold.muted)
                }
                Spacer()
                Text(block.kind.isPutting ? "\(pct(block.onTarget, block.putts))%" : "\(Int(block.pureRate.rounded()))%")
                    .font(.figure(24)).foil()
            }
            if block.kind.isPutting {
                SplitBar(parts: [("Holed", block.onTarget)] + PuttMiss.allCases.map { ($0.rawValue, block.puttMisses[$0] ?? 0) })
            } else {
                SplitBar(parts: Contact.allCases.map { ($0.rawValue, block.contact[$0] ?? 0) })
                let shapes = Shape.allCases.map { ($0.rawValue, block.shape[$0] ?? 0) }
                if shapes.contains(where: { $0.1 > 0 }) { SplitBar(parts: shapes) }
                let misses = Miss.allCases.compactMap { m -> String? in
                    let n = block.misses[m] ?? 0
                    return n > 0 ? "\(m.rawValue) \(n)" : nil
                }
                if !misses.isEmpty {
                    Text("Misses: " + misses.joined(separator: " · ")).font(.body(12)).foregroundStyle(Gold.muted)
                }
                if let avg = block.avgCarry {
                    Text("Average carry \(avg) yd over \(block.carries.count) logged").font(.body(12, .medium)).foregroundStyle(Gold.pale)
                }
            }
        }
        .card(padding: 16, radius: 20)
    }
}
