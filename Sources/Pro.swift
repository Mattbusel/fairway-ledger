import SwiftUI
import StoreKit
import Charts

/// Fairway Ledger Pro: one non-consumable. Logging is free forever; Pro is the stat book.
///
/// Everyone who installed a build from the paid era keeps everything. AppTransaction's
/// originalAppVersion is the build number they first installed; the paid 1.0 was build 1.
/// Only trusted in production: sandbox and Xcode report made-up values, and App Review
/// must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.fairwayledger.pro"
    static let name = "Fairway Ledger Pro"
    /// The first build that has Pro in it. Anything earlier was sold with every feature.
    static let firstFreemiumBuild = 2

    enum Reason: String, Identifiable { case stats, export, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "fairwayledger.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - What Pro adds, in this app's words

enum ProCopy {
    static let pitch = "Logging stays free forever. Pro turns the ledger into a stat book."
    static let short = "The full stat book and CSV export."
    static let features: [(icon: String, title: String, body: String)] = [
        ("chart.line.uptrend.xyaxis", "Score trend", "Every round on one line, with your average ruled across it."),
        ("flag.fill", "Putting against the tour", "Your make rate from each distance next to the tour's."),
        ("scope", "Ball flight read", "Strike, shape, mis-hits and which side you miss, in plain English."),
        ("chart.pie.fill", "Practice mix", "Where your range time goes, and minutes week by week."),
        ("square.and.arrow.up", "Export the ledger", "Rounds and sessions as spreadsheet files, yours to keep."),
    ]
    static func headline(_ r: Pro.Reason) -> String {
        switch r {
        case .export: return "Take your ledger anywhere."
        default: return "Read your game like a pro."
        }
    }
}

extension Ledger {
    /// The paywall teaser: the user's own scores if there are enough, sample otherwise.
    var proTeaser: (label: String, values: [Double]) {
        let rs = rounds.prefix(12).reversed().map { Double($0.score) }
        if rs.count >= 3 { return ("Your score, last \(rs.count) rounds", Array(rs)) }
        return ("What it looks like", [94, 92, 95, 91, 90, 92, 88, 89, 87, 88, 85, 86])
    }

    /// Two spreadsheet files: every round, and every practice session.
    func exportCSV() -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FairwayLedgerExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let day = Date.now.formatted(.iso8601.year().month().day())
        var r = [csvRow(["date", "course", "tees", "course rating", "slope", "score", "par", "to par", "putts",
                         "fairways hit", "fairway holes", "greens in regulation", "penalties", "three putts",
                         "differential", "walked", "notes"])]
        for x in rounds {
            r.append(csvRow([x.date.formatted(.iso8601.year().month().day()), x.course, x.tees, String(format: "%.1f", x.rating),
                             "\(x.slope)", "\(x.score)", "\(x.par)", "\(x.toPar)", "\(x.putts)", "\(x.fairwaysHit)",
                             "\(x.fairwayHoles.count)", "\(x.girs)", "\(x.penalties)", "\(x.threePutts)",
                             String(format: "%.1f", x.differential), x.walked ? "yes" : "no", x.notes]))
        }
        var s = [csvRow(["date", "minutes", "place", "focus", "balls", "blocks", "rating", "mood", "energy",
                         "swing thought", "what clicked", "work on next", "journal"])]
        for x in sessions {
            s.append(csvRow([x.date.formatted(.iso8601.year().month().day()), "\(x.minutes)", x.place, x.focus, "\(x.balls)",
                             x.blocks.map(\.title).joined(separator: "; "), "\(x.rating)", "\(x.mood)", "\(x.energy)",
                             x.swingThought, x.clicked, x.workOn, x.journal]))
        }
        let a = dir.appendingPathComponent("Fairway Ledger rounds \(day).csv")
        let b = dir.appendingPathComponent("Fairway Ledger practice \(day).csv")
        try? r.joined(separator: "\n").write(to: a, atomically: true, encoding: .utf8)
        try? s.joined(separator: "\n").write(to: b, atomically: true, encoding: .utf8)
        return [a, b]
    }
}

func csvRow(_ fields: [String]) -> String {
    fields.map { f in
        let needs = f.contains(",") || f.contains("\"") || f.contains("\n")
        return needs ? "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : f
    }.joined(separator: ",")
}

// MARK: - Paywall

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(eyebrow: Pro.name, title: ProCopy.headline(reason)) { dismiss() }
                        .padding(.horizontal, -20)
                    Text(ProCopy.pitch).font(.body(15)).foregroundStyle(Gold.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    teaser
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(ProCopy.features, id: \.title) { f in feature(f.icon, f.title, f.body) }
                    }
                    .card()
                    priceBlock
                    if let m = pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    FoilButton(pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 12) {
                        GhostButton("Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        GhostButton("Not now") { dismiss() }.frame(width: 120)
                    }
                    Text("One payment, yours for good. No subscription. Family Sharing works. Everything you have logged stays yours, Pro or not.")
                        .font(.body(11.5)).foregroundStyle(Gold.faint).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) { shown = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    private var teaser: some View {
        let t = ledger.proTeaser
        let lo = (t.values.min() ?? 0) - 2, hi = (t.values.max() ?? 1) + 2
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(t.label)
            Chart(Array(t.values.enumerated()), id: \.offset) { item in
                AreaMark(x: .value("i", item.offset), yStart: .value("lo", lo), yEnd: .value("v", item.element))
                    .foregroundStyle(LinearGradient(colors: [Gold.leaf.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("i", item.offset), y: .value("v", item.element))
                    .foregroundStyle(Gold.foil).lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 120)
            .blur(radius: 4)
            .overlay { ProSeal(size: 84).scaleEffect(shown ? 1 : 0.3).rotationEffect(.degrees(shown ? 0 : -30)) }
        }
        .card()
    }

    private var priceBlock: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pro.price).font(.figure(40, .light)).foil()
                Text("ONCE. NOT A MONTH.").font(.body(10.5, .semibold)).tracking(2).foregroundStyle(Gold.muted)
            }
            Spacer()
            Text("No\nsubscription").font(.display(14).italic()).multilineTextAlignment(.trailing).foregroundStyle(Gold.pale)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Gold.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .card()
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.body(15, .semibold)).foil()
                .frame(width: 38, height: 38).background(Circle().fill(Gold.lacquerHi))
                .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                Text(body).font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A foil wax seal with a lock in it.
struct ProSeal: View {
    var size: CGFloat = 90
    var body: some View {
        ZStack {
            Circle().fill(Gold.foil)
            Circle().strokeBorder(Gold.ink.opacity(0.35), lineWidth: 1).padding(size * 0.08)
            VStack(spacing: 1) {
                Image(systemName: "lock.fill").font(.system(size: size * 0.2, weight: .bold))
                Text("PRO").font(.body(size * 0.13, .bold)).tracking(2)
            }
            .foregroundStyle(Gold.ink)
        }
        .frame(width: size, height: size)
        .shadow(color: Gold.leaf.opacity(0.45), radius: 18)
    }
}

// MARK: - Locked content

/// Pro content for a free user: the real section drawn from their own data, frosted, with a way in.
struct LockedSection<Content: View>: View {
    @Environment(Pro.self) private var pro
    let reason: Pro.Reason
    let title: String
    let pitch: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 22) { content }
                .frame(maxHeight: 560, alignment: .top).clipped()
                .blur(radius: 10).allowsHitTesting(false).accessibilityHidden(true)
                .overlay(LinearGradient(colors: [Gold.ink.opacity(0.2), Gold.ink.opacity(0.9)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 16) {
                ProSeal(size: 96)
                Text(title).font(.display(28)).foregroundStyle(Gold.ivory).multilineTextAlignment(.center)
                Text(pitch).font(.body(14.5)).foregroundStyle(Gold.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                FoilButton("See \(Pro.name)", icon: "sparkles") { pro.ask(reason) }
                Text("\(pro.price) once. Your ledger stays free.").font(.body(12)).foregroundStyle(Gold.faint)
            }
            .padding(.horizontal, 20).padding(.top, 60)
        }
        .frame(minHeight: 460)
    }
}

/// Export card: Pro shares the files, free opens the paywall.
struct ExportCard: View {
    @Environment(Pro.self) private var pro
    @Environment(Ledger.self) private var ledger
    @State private var files: [URL] = []

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "tablecells").font(.body(17, .semibold)).foil()
                .frame(width: 42, height: 42).background(Circle().fill(Gold.lacquerHi))
            VStack(alignment: .leading, spacing: 2) {
                Text("Export the ledger").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                Text("Spreadsheet files for Numbers, Excel or Sheets").font(.body(12)).foregroundStyle(Gold.muted)
            }
            Spacer()
            if pro.unlocked {
                ShareLink(items: files) {
                    Image(systemName: "square.and.arrow.up").font(.body(16, .bold)).foregroundStyle(Gold.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(Gold.foil))
                }
                .disabled(files.isEmpty)
            } else {
                Button { pro.ask(.export) } label: {
                    Image(systemName: "lock.fill").font(.body(15, .bold)).foil()
                        .frame(width: 44, height: 44).overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 1))
                }
            }
        }
        .card(padding: 14)
        .task(id: pro.unlocked) { if pro.unlocked { files = ledger.exportCSV() } }
    }
}

/// The Pro status card on Home, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pro.unlocked ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi))
                Image(systemName: pro.unlocked ? "checkmark" : "lock.fill").font(.body(13, .bold))
                    .foregroundStyle(pro.unlocked ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.foil))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.unlocked ? Pro.name : "\(Pro.name), \(pro.price) once").font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for buying the ledger early." : "Unlocked. Thank you.") : ProCopy.short)
                    .font(.body(12)).foregroundStyle(Gold.muted)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.body(11.5, .semibold)).foregroundStyle(Gold.pale) }
            }
            Spacer(minLength: 6)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("SEE").font(.body(12, .bold)).tracking(1.5).foregroundStyle(Gold.ink)
                            .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Gold.foil))
                    }
                    .buttonStyle(PressStyle())
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.body(11, .semibold)).foregroundStyle(Gold.muted).underline()
                    }
                }
            }
        }
        .card(padding: 14)
    }
}
