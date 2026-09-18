import SwiftUI

/// The range screen. Built to be used one-handed between shots: pick what you're
/// hitting, then tap what happened. Every tap is undoable.
struct LiveSessionView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State var session: PracticeSession
    @State private var kind: DrillKind = .fullSwing
    @State private var club = "7i"
    @State private var target = 150
    @State private var feet = 5
    @State private var started = Date.now
    @State private var history: [[DrillBlock]] = []
    @State private var carryEntry = 150
    @State private var confirmQuit = false

    init(session: PracticeSession) {
        _session = State(initialValue: session)
        if let b = session.blocks.last {
            _kind = State(initialValue: b.kind); _club = State(initialValue: b.club); _target = State(initialValue: b.target)
        }
        _started = State(initialValue: Date.now.addingTimeInterval(-Double(session.minutes) * 60))
    }

    private let puttDistances = [3, 4, 5, 6, 8, 10, 12, 15, 20, 30, 40]

    var body: some View {
        ZStack {
            LacquerBackground()
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ChipRow(options: DrillKind.allCases, selection: $kind) { $0.rawValue }
                            .padding(.horizontal, -20)
                        setup
                        if kind.isPutting { puttingPad } else { swingPad }
                        blocksStrip
                    }
                    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 120)
                }
            }
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button { undo() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.body(17, .semibold))
                            .foregroundStyle(history.isEmpty ? Gold.faint : Gold.pale)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Gold.lacquerHi))
                            .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
                    }
                    .disabled(history.isEmpty)
                    FoilButton("Finish & journal", icon: "checkmark") { finish() }
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
                .background(LinearGradient(colors: [.clear, Gold.ink.opacity(0.95)], startPoint: .top, endPoint: .center).ignoresSafeArea().padding(.top, -30))
            }
        }
        .onChange(of: kind) { _, k in
            if k.isPutting { target = feet } else if k == .wedges { club = "54°"; target = 80 }
            else if k.isShortGame { club = k == .bunker ? "58°" : "54°"; target = k == .bunker ? 15 : 25 }
            else if k == .fullSwing && (club.hasSuffix("°") || club == "PW") { club = "7i"; target = 150 }
        }
        .confirmationDialog("End this session?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Discard session", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: top

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                if session.balls == 0 { dismiss() } else { confirmQuit = true }
            } label: {
                Image(systemName: "xmark").font(.body(13, .bold)).foregroundStyle(Gold.ivory.opacity(0.7))
                    .frame(width: 36, height: 36).background(Circle().fill(Gold.lacquerHi))
            }
            Spacer()
            VStack(spacing: 2) {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text(elapsed(tl.date)).font(.figure(24, .light)).foil().monospacedDigit()
                }
                Text("\(session.balls) \(session.balls == 1 ? "ball" : "balls") · \(session.blocks.count) \(session.blocks.count == 1 ? "block" : "blocks")")
                    .font(.body(11.5, .medium)).foregroundStyle(Gold.muted)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Gold.bad).frame(width: 7, height: 7)
                Text("LIVE").font(.body(10.5, .bold)).tracking(1.5).foregroundStyle(Gold.ivory.opacity(0.8))
            }
            .frame(width: 60, height: 30).background(Capsule().fill(Gold.lacquerHi))
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private func elapsed(_ now: Date) -> String {
        let s = Int(now.timeIntervalSince(started))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: setup

    @ViewBuilder private var setup: some View {
        if kind.isPutting {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Distance")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(puttDistances, id: \.self) { ft in
                            let on = ft == target
                            Button { Haptic.tap(); target = ft; feet = ft } label: {
                                VStack(spacing: 0) {
                                    Text("\(ft)").font(.figure(20)).foregroundStyle(on ? Gold.ink : Gold.ivory)
                                    Text("ft").font(.body(10, .semibold)).foregroundStyle(on ? Gold.ink.opacity(0.7) : Gold.muted)
                                }
                                .frame(width: 52, height: 56)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi)))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Gold.hairline, lineWidth: on ? 0 : 0.8))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if !kind.isShortGame || kind == .onCourse {
                    Eyebrow("Club")
                    ChipRow(options: ledger.bag.map(\.name), selection: $club) { $0 }
                        .padding(.horizontal, -20)
                } else {
                    Eyebrow("Club")
                    ChipRow(options: ["PW", "50°", "54°", "58°", "8i", "Putter"], selection: $club) { $0 }
                        .padding(.horizontal, -20)
                }
                LedgerStepper(label: kind.isShortGame ? "Target (yd)" : "Target yardage", value: $target, range: 1...350, step: kind.isShortGame ? 1 : 5)
                    .card(padding: 14, radius: 18)
            }
            .onChange(of: club) { _, c in
                if let carry = ledger.bag.first(where: { $0.name == c })?.carry, kind == .fullSwing || kind == .wedges || kind == .onCourse {
                    target = (carry / 5) * 5; carryEntry = carry
                }
            }
        }
    }

    // MARK: pads

    private var current: DrillBlock {
        session.blocks.last.flatMap { matches($0) ? $0 : nil } ?? DrillBlock(kind: kind, club: club, target: target)
    }

    private func matches(_ b: DrillBlock) -> Bool {
        b.kind == kind && b.target == target && (kind.isPutting || b.club == club)
    }

    /// Records a change against the block for the current setup, opening a new block if the setup changed.
    private func record(_ change: (inout DrillBlock) -> Void) {
        history.append(session.blocks)
        if history.count > 200 { history.removeFirst() }
        if let last = session.blocks.last, matches(last) {
            change(&session.blocks[session.blocks.count - 1])
        } else {
            var b = DrillBlock(kind: kind, club: club, target: target)
            change(&b)
            withAnimation(.snappy) { session.blocks.append(b) }
        }
    }

    private func undo() {
        guard let prev = history.popLast() else { return }
        Haptic.thud()
        withAnimation(.snappy) { session.blocks = prev }
    }

    private var swingPad: some View {
        let b = current
        let showShape = kind == .fullSwing || kind == .wedges || kind == .onCourse
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("Strike")
                    Spacer()
                    if b.balls > 0 {
                        Text("\(Int(b.pureRate.rounded()))% pure").font(.body(12, .semibold)).foil()
                    }
                }
                HStack(spacing: 10) {
                    TallyButton(label: "Pure", sub: "center, crisp", count: b.contact[.pure] ?? 0, tone: Gold.pale, tall: 104) {
                        record { $0.contact[.pure, default: 0] += 1 }
                    }
                    TallyButton(label: "Solid", sub: "playable", count: b.contact[.solid] ?? 0, tall: 104) {
                        record { $0.contact[.solid, default: 0] += 1 }
                    }
                    TallyButton(label: "Poor", sub: "mis-hit", count: b.contact[.poor] ?? 0, tone: Gold.bad, tall: 104) {
                        record { $0.contact[.poor, default: 0] += 1 }
                    }
                }
            }

            TallyButton(label: kind.isShortGame ? "Inside the circle" : "On target", sub: kind.isShortGame ? "finished within 3 ft" : "inside your window",
                        count: b.onTarget, tone: Gold.good, tall: 72) {
                record { $0.onTarget += 1 }
            }

            if showShape {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Shape")
                    HStack(spacing: 8) {
                        ForEach(Shape.allCases, id: \.self) { s in
                            TallyButton(label: s.rawValue, count: b.shape[s] ?? 0, tall: 66) { record { $0.shape[s, default: 0] += 1 } }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Miss")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Miss.allCases, id: \.self) { m in
                        TallyButton(label: m.rawValue, count: b.misses[m] ?? 0, tone: Gold.bad, tall: 64) {
                            record { $0.misses[m, default: 0] += 1 }
                        }
                    }
                }
            }

            if showShape {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Eyebrow("Carry (launch monitor or flag)")
                        Spacer()
                        if let avg = b.avgCarry { Text("avg \(avg) yd").font(.body(12, .semibold)).foil() }
                    }
                    HStack(spacing: 12) {
                        LedgerStepper(label: "", value: $carryEntry, range: 1...400)
                        Button {
                            record { $0.carries.append(carryEntry) }
                            Haptic.done()
                        } label: {
                            Text("Log").font(.body(15, .semibold)).foregroundStyle(Gold.ink)
                                .frame(width: 72, height: 40).background(Capsule().fill(Gold.foil))
                        }
                    }
                    if !b.carries.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(b.carries.enumerated()), id: \.offset) { _, c in
                                    Text("\(c)").font(.figure(13)).foregroundStyle(Gold.pale)
                                        .padding(.horizontal, 10).frame(height: 26).background(Capsule().fill(Gold.leaf.opacity(0.1)))
                                }
                            }
                        }
                    }
                }
                .card(padding: 16, radius: 20)
            }
        }
    }

    private var puttingPad: some View {
        let b = current
        let missed = b.putts - b.onTarget
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 20) {
                ZStack {
                    FoilRing(progress: b.putts == 0 ? 0 : Double(b.onTarget) / Double(b.putts), width: 10)
                    VStack(spacing: 0) {
                        Text(pct(b.onTarget, b.putts)).font(.figure(34, .light)).foil()
                        Text("holed %").font(.body(10.5, .medium)).foregroundStyle(Gold.muted)
                    }
                }
                .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(b.onTarget) of \(b.putts)").font(.display(26)).foregroundStyle(Gold.ivory)
                    Text("from \(target) feet").font(.body(14)).foregroundStyle(Gold.muted)
                    Text(benchmark(target)).font(.body(12)).foregroundStyle(Gold.pale.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 18)

            TallyButton(label: "Holed", sub: "tap for every make", count: b.onTarget, tone: Gold.good, tall: 110) {
                record { $0.putts += 1; $0.onTarget += 1 }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("Missed · where")
                    Spacer()
                    Text("\(missed) missed").font(.body(12, .semibold)).foregroundStyle(Gold.muted)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(PuttMiss.allCases, id: \.self) { m in
                        TallyButton(label: m.rawValue, count: b.puttMisses[m] ?? 0, tone: Gold.bad, tall: 72) {
                            record { $0.putts += 1; $0.puttMisses[m, default: 0] += 1 }
                        }
                    }
                }
            }
        }
    }

    /// Tour make rates, so a number means something.
    private func benchmark(_ ft: Int) -> String {
        let tour: [Int: Int] = [3: 99, 4: 91, 5: 77, 6: 66, 8: 50, 10: 40, 12: 32, 15: 23, 20: 15, 30: 7, 40: 4]
        guard let t = tour[ft] else { return "" }
        return "Tour average from here: \(t)%"
    }

    // MARK: blocks

    @ViewBuilder private var blocksStrip: some View {
        if !session.blocks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("This session")
                ForEach(session.blocks.reversed()) { b in
                    HStack(spacing: 12) {
                        Image(systemName: b.kind.icon).font(.body(14, .semibold)).foil()
                            .frame(width: 34, height: 34).background(Circle().fill(Gold.leaf.opacity(0.1)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(.body(14, .semibold)).foregroundStyle(Gold.ivory)
                            Text(b.kind.isPutting ? "\(b.onTarget)/\(b.putts) holed" : "\(b.balls) balls · \(Int(b.pureRate.rounded()))% pure · \(b.onTarget) on target")
                                .font(.body(12)).foregroundStyle(Gold.muted)
                        }
                        Spacer()
                        if matches(b) && b.id == session.blocks.last?.id {
                            Text("NOW").font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.ink)
                                .padding(.horizontal, 8).frame(height: 20).background(Capsule().fill(Gold.foil))
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gold.lacquer))
                }
            }
        }
    }

    private func finish() {
        session.minutes = max(1, Int(Date.now.timeIntervalSince(started) / 60))
        if session.date.timeIntervalSinceNow > -60 { session.date = started }
        let s = session
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.finishing = s }
    }
}
