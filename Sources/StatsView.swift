import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Pro.self) private var pro

    var body: some View {
        Page {
            PageHeader(eyebrow: "Everything you've logged", title: "The numbers")
            if ledger.rounds.isEmpty && ledger.sessions.isEmpty {
                Text("Charts appear once you have a few sessions or rounds in the ledger.")
                    .font(.display(17)).foregroundStyle(Gold.muted).card()
            }
            // The last-ten averages are free; the stat book below them is Pro.
            if !ledger.rounds.isEmpty { roundAverages }
            if pro.unlocked {
                statBook
            } else {
                LockedSection(reason: .stats, title: "The full stat book",
                              pitch: "Score trend, putting against the tour, your ball flight read and where your practice time goes, all from what you have logged.") {
                    if ledger.rounds.isEmpty && ledger.sessions.isEmpty { sampleCard } else { statBook }
                }
            }
            ExportCard()
        }
    }

    @ViewBuilder private var statBook: some View {
        if !ledger.rounds.isEmpty { scoreTrend }
        if !ledger.puttingByDistance.isEmpty { puttingChart }
        if !ledger.allBlocks.isEmpty {
            ballFlight
            practiceMix
        }
        if !ledger.sessions.isEmpty { weekly }
    }

    /// Something to frost when the ledger is still empty.
    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Score")
            Chart(Array([94, 92, 95, 91, 90, 88, 89, 86].enumerated()), id: \.offset) { item in
                LineMark(x: .value("Round", item.offset), y: .value("Score", item.element))
                    .foregroundStyle(Gold.foil).interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 190)
        }
        .card()
    }

    // MARK: rounds

    private var roundAverages: some View {
        let rs = Array(ledger.rounds.prefix(10))
        let n = Double(rs.count)
        let fir = pct(rs.reduce(0) { $0 + $1.fairwaysHit }, rs.reduce(0) { $0 + $1.fairwayHoles.count })
        let gir = pct(rs.reduce(0) { $0 + $1.girs }, rs.count * 18)
        let putts = String(format: "%.1f", Double(rs.reduce(0) { $0 + $1.putts }) / n)
        let scr = pct(rs.reduce(0) { $0 + $1.scrambles.made }, rs.reduce(0) { $0 + $1.scrambles.tries })
        let three = String(format: "%.1f", Double(rs.reduce(0) { $0 + $1.threePutts }) / n)
        let sand = pct(rs.reduce(0) { $0 + $1.sandSaves.made }, rs.reduce(0) { $0 + $1.sandSaves.tries })
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Last \(rs.count) rounds")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                StatTile(label: "Fairways", value: fir, unit: "%")
                StatTile(label: "Greens", value: gir, unit: "%")
                StatTile(label: "Putts", value: putts)
                StatTile(label: "Scramble", value: scr, unit: "%")
                StatTile(label: "3-putts", value: three)
                StatTile(label: "Sand save", value: sand, unit: "%")
            }
        }
    }

    private var scoreTrend: some View {
        let rs = Array(ledger.rounds.prefix(20).reversed())
        let avg = Double(rs.map(\.score).reduce(0, +)) / Double(rs.count)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Score")
                Spacer()
                Text("avg \(String(format: "%.1f", avg))").font(.body(12, .semibold)).foil()
            }
            Chart {
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(Gold.leaf.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                ForEach(Array(rs.enumerated()), id: \.element.id) { i, r in
                    AreaMark(x: .value("Round", i), yStart: .value("Floor", (rs.map(\.score).min() ?? 70) - 3), yEnd: .value("Score", r.score))
                        .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Round", i), y: .value("Score", r.score))
                        .foregroundStyle(Gold.foil)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Round", i), y: .value("Score", r.score))
                        .foregroundStyle(Gold.pale).symbolSize(28)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Gold.leaf.opacity(0.08))
                AxisValueLabel().foregroundStyle(Gold.muted).font(.body(10))
            } }
            .frame(height: 190)
        }
        .card()
    }

    // MARK: putting

    private var puttingChart: some View {
        let data = ledger.puttingByDistance
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Putts holed by distance")
                Spacer()
                HStack(spacing: 4) { Rectangle().fill(Gold.ivory.opacity(0.5)).frame(width: 10, height: 2); Text("tour").font(.body(10.5)) }
                    .foregroundStyle(Gold.muted)
            }
            Chart {
                ForEach(data, id: \.feet) { d in
                    BarMark(x: .value("Feet", "\(d.feet)′"), y: .value("Holed", pctValue(d.made, d.tries)))
                        .foregroundStyle(LinearGradient(colors: [Gold.pale, Gold.deep], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(Int(pctValue(d.made, d.tries).rounded()))").font(.body(10, .semibold)).foregroundStyle(Gold.pale)
                        }
                    if let t = tour[d.feet] {
                        PointMark(x: .value("Feet", "\(d.feet)′"), y: .value("Tour", t))
                            .symbol { Rectangle().fill(Gold.ivory.opacity(0.6)).frame(width: 16, height: 2) }
                    }
                }
            }
            .chartYScale(domain: 0...105)
            .chartYAxis(.hidden)
            .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Gold.muted).font(.body(11, .medium)) } }
            .frame(height: 180)
        }
        .card()
    }
    private let tour: [Int: Double] = [3: 99, 4: 91, 5: 77, 6: 66, 8: 50, 10: 40, 12: 32, 15: 23, 20: 15, 30: 7, 40: 4]

    // MARK: ball flight

    private var ballFlight: some View {
        let miss = ledger.missTotals
        let shape = ledger.shapeTotals
        let swings = ledger.allBlocks.filter { !$0.kind.isPutting }
        let contact = Contact.allCases.map { c in (c.rawValue, swings.reduce(0) { $0 + ($1.contact[c] ?? 0) }) }
        return VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Ball flight, all practice")
            VStack(alignment: .leading, spacing: 8) {
                Text("Strike").font(.display(16)).foregroundStyle(Gold.ivory)
                SplitBar(parts: contact)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Shape").font(.display(16)).foregroundStyle(Gold.ivory)
                SplitBar(parts: Shape.allCases.map { ($0.rawValue, shape[$0] ?? 0) })
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Direction of misses").font(.display(16)).foregroundStyle(Gold.ivory)
                let l = miss[.left] ?? 0, r = miss[.right] ?? 0
                HStack {
                    Text("Left \(l)").font(.body(12, .semibold)).foregroundStyle(Gold.muted)
                    GeometryReader { g in
                        let total = max(1, l + r)
                        ZStack {
                            Capsule().fill(Gold.lacquerHi)
                            Rectangle().fill(Gold.leaf.opacity(0.4)).frame(width: 1.5)
                            Circle().fill(Gold.foil).frame(width: 16, height: 16)
                                .shadow(color: Gold.leaf, radius: 8)
                                .offset(x: (CGFloat(r - l) / CGFloat(total)) * (g.size.width / 2 - 10))
                        }
                    }
                    .frame(height: 16)
                    Text("\(r) Right").font(.body(12, .semibold)).foregroundStyle(Gold.muted)
                }
                Text(bias(l, r)).font(.body(12.5)).foregroundStyle(Gold.pale.opacity(0.85))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Mis-hits").font(.display(16)).foregroundStyle(Gold.ivory)
                Chart {
                    ForEach([Miss.fat, .thin, .top, .shank, .short, .long], id: \.self) { m in
                        BarMark(x: .value("Count", miss[m] ?? 0), y: .value("Miss", m.rawValue))
                            .foregroundStyle(Gold.foil).cornerRadius(4)
                            .annotation(position: .trailing) { Text("\(miss[m] ?? 0)").font(.body(10.5, .semibold)).foregroundStyle(Gold.muted) }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Gold.ivory.opacity(0.75)).font(.body(11.5, .medium)) } }
                .frame(height: 170)
            }
        }
        .card()
    }

    private func bias(_ l: Int, _ r: Int) -> String {
        let t = l + r
        guard t >= 10 else { return "Log more misses to see a pattern." }
        let share = Double(r) / Double(t)
        if share > 0.65 { return "\(Int(share * 100))% of your directional misses go right. Worth a look at face angle at impact." }
        if share < 0.35 { return "\(Int((1 - share) * 100))% of your directional misses go left. Check grip and release." }
        return "Your misses are balanced left and right. That's a good sign."
    }

    // MARK: practice mix

    private var practiceMix: some View {
        let mix = ledger.minutesByKind
        let total = max(1, mix.map(\.1).reduce(0, +))
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Where your practice time goes")
            HStack(spacing: 20) {
                Chart(mix, id: \.0) { k, m in
                    SectorMark(angle: .value("Minutes", m), innerRadius: .ratio(0.62), angularInset: 2)
                        .foregroundStyle(Gold.chartScale[(DrillKind.allCases.firstIndex(of: k) ?? 0) % Gold.chartScale.count])
                        .cornerRadius(3)
                }
                .frame(width: 140, height: 140)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(total / 60)").font(.figure(26)).foil()
                        Text("hours").font(.body(10.5)).foregroundStyle(Gold.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(mix, id: \.0) { k, m in
                        HStack(spacing: 8) {
                            Circle().fill(Gold.chartScale[(DrillKind.allCases.firstIndex(of: k) ?? 0) % Gold.chartScale.count]).frame(width: 8, height: 8)
                            Text(k.rawValue).font(.body(12.5, .medium)).foregroundStyle(Gold.ivory.opacity(0.85))
                            Spacer()
                            Text("\(m * 100 / total)%").font(.figure(12.5)).foregroundStyle(Gold.muted)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var weekly: some View {
        let cal = Calendar.current
        let weeks: [(Date, Int)] = (0..<8).reversed().map { back in
            let start = cal.dateInterval(of: .weekOfYear, for: cal.date(byAdding: .weekOfYear, value: -back, to: .now)!)!
            return (start.start, ledger.sessions.filter { start.contains($0.date) }.reduce(0) { $0 + $1.minutes })
        }
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Practice minutes per week")
            Chart {
                ForEach(weeks, id: \.0) { w, m in
                    BarMark(x: .value("Week", w, unit: .weekOfYear), y: .value("Minutes", m))
                        .foregroundStyle(LinearGradient(colors: [Gold.pale, Gold.deep], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(5)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Gold.muted).font(.body(10))
            } }
            .chartYAxis { AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Gold.leaf.opacity(0.08))
                AxisValueLabel().foregroundStyle(Gold.muted).font(.body(10))
            } }
            .frame(height: 170)
        }
        .card()
    }
}
