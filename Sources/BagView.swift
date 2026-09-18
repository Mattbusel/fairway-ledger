import SwiftUI

struct BagView: View {
    @Environment(Ledger.self) private var ledger
    @State private var editing: Club?

    /// Average carry per club from everything logged at the range.
    private var rangeCarry: [String: Int] {
        let blocks = ledger.allBlocks.filter { !$0.carries.isEmpty }
        let grouped = Dictionary(grouping: blocks, by: \.club)
        return grouped.mapValues { bs in
            let all = bs.flatMap(\.carries); return all.reduce(0, +) / max(1, all.count)
        }
    }

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "\(ledger.bag.count) of 14 clubs", title: "Yardage book")
                Spacer()
                Button { editing = Club(name: "", loft: 0, carry: 100, total: 105) } label: {
                    Image(systemName: "plus").font(.body(18, .semibold)).foregroundStyle(Gold.ink)
                        .frame(width: 48, height: 48).background(Circle().fill(Gold.foil))
                }
                .buttonStyle(PressStyle())
                .disabled(ledger.bag.count >= 14)
            }
            gapping
            VStack(spacing: 0) {
                ForEach(ledger.bag) { c in
                    Button { editing = c } label: { row(c) }.buttonStyle(.plain)
                    if c.id != ledger.bag.last?.id { Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8) }
                }
            }
            .card(padding: 6)
            Text("Carry is where the ball lands. Tap a club to edit. Range averages come from carries you log during practice.")
                .font(.body(12)).foregroundStyle(Gold.muted).padding(.horizontal, 6)
        }
        .sheet(item: $editing) { c in
            ClubEditor(club: c).presentationDetents([.medium]).presentationBackground(Gold.ink)
        }
    }

    private var gapping: some View {
        let clubs = ledger.bag.sorted { $0.carry > $1.carry }
        let maxTotal = CGFloat(max(clubs.map(\.total).max() ?? 1, 1))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Gapping")
                Spacer()
                legend(Gold.foil, "carry"); legend(Gold.leaf.opacity(0.22), "roll")
            }
            ForEach(Array(clubs.enumerated()), id: \.element.id) { i, c in
                let gap = i + 1 < clubs.count ? c.carry - clubs[i + 1].carry : nil
                HStack(spacing: 10) {
                    Text(c.name).font(.body(12.5, .semibold)).foregroundStyle(Gold.ivory).frame(width: 46, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Gold.leaf.opacity(0.22)).frame(width: g.size.width * CGFloat(c.total) / maxTotal)
                            Capsule().fill(Gold.foil).frame(width: g.size.width * CGFloat(c.carry) / maxTotal)
                                .shadow(color: Gold.leaf.opacity(0.35), radius: 6)
                        }
                    }
                    .frame(height: 12)
                    Text("\(c.carry)").font(.figure(13)).foregroundStyle(Gold.pale).frame(width: 34, alignment: .trailing)
                }
                if let gap {
                    HStack {
                        Spacer().frame(width: 56)
                        Text(gapNote(gap)).font(.body(10, .semibold))
                            .foregroundStyle(gap > 18 || gap < 7 ? Gold.bad : Gold.faint)
                        Spacer()
                    }
                    .frame(height: 12)
                }
            }
        }
        .card()
    }

    private func gapNote(_ g: Int) -> String {
        if g > 18 { return "↕ \(g) yd gap, consider a club here" }
        if g < 7 { return "↕ \(g) yd, these two overlap" }
        return "↕ \(g)"
    }

    private func legend(_ fill: some ShapeStyle, _ t: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(fill).frame(width: 14, height: 6)
            Text(t).font(.body(10.5)).foregroundStyle(Gold.muted)
        }
    }

    private func row(_ c: Club) -> some View {
        HStack(spacing: 14) {
            Text(c.name).font(.display(18, .medium)).foil().frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.loft > 0 ? String(format: "%.1f° loft", c.loft) : "loft —").font(.body(12)).foregroundStyle(Gold.muted)
                if let r = rangeCarry[c.name] {
                    Text("Range avg \(r) yd").font(.body(11.5, .medium)).foregroundStyle(r < c.carry - 5 ? Gold.bad : Gold.good)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(c.carry)").font(.figure(20)).foregroundStyle(Gold.ivory)
                Text("carry").font(.body(9.5, .semibold)).foregroundStyle(Gold.muted)
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(c.total)").font(.figure(20)).foregroundStyle(Gold.ivory.opacity(0.6))
                Text("total").font(.body(9.5, .semibold)).foregroundStyle(Gold.muted)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 12).padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct ClubEditor: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State var club: Club

    var body: some View {
        VStack(spacing: 16) {
            SheetHeader(eyebrow: "Club", title: club.name.isEmpty ? "New club" : club.name) { dismiss() }
                .padding(.horizontal, -20).padding(.top, 20)
            LedgerField(label: "Name", text: $club.name, prompt: "7i, 54°, Driver")
            VStack(spacing: 14) {
                LedgerStepper(label: "Carry (yd)", value: $club.carry, range: 1...380)
                LedgerStepper(label: "Total (yd)", value: $club.total, range: 1...400)
                LedgerStepper(label: "Loft (°)", value: Binding(get: { Int(club.loft) }, set: { club.loft = Double($0) }), range: 0...64)
            }
            .card(padding: 16)
            HStack(spacing: 12) {
                if ledger.bag.contains(where: { $0.id == club.id }) {
                    GhostButton("Remove", icon: "trash") { ledger.bag.removeAll { $0.id == club.id }; dismiss() }.frame(width: 130)
                }
                FoilButton("Save") {
                    guard !club.name.isEmpty else { return }
                    if let i = ledger.bag.firstIndex(where: { $0.id == club.id }) { ledger.bag[i] = club } else { ledger.bag.append(club) }
                    ledger.bag.sort { $0.carry > $1.carry }
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
