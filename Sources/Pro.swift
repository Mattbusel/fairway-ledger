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

    enum Reason: String, Identifiable { case stats, export, settings, insights, backup, plus; var id: String { rawValue } }

    private(set) var unlocked: Bool
    /// Fairway Ledger Plus includes everything in Pro while it is active. Set by the app from Plus; never stored,
    /// so a lapsed subscription takes nothing that was bought.
    var viaPlus = false
    /// What the screens ask: Pro owned (or grandfathered), or Plus active.
    var has: Bool { unlocked || viaPlus }
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

    func ask(_ why: Reason) {
        switch why {
        case .insights, .backup, .plus: paywall = why
        default: if !has { paywall = why }
        }
    }

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
    static let short = "The full stat book, course pages, the Ledger widget and CSV export."
    static let features: [(icon: String, title: String, body: String)] = [
        ("chart.line.uptrend.xyaxis", "Score trend", "Every round on one line, with your average ruled across it."),
        ("chart.bar.xaxis", "Where the strokes go", "Over par on par 3s, 4s and 5s, penalties and three-putts, per round."),
        ("map", "Every course, hole by hole", "How each hole plays for you, the ones that cost you, and the ones to attack."),
        ("rectangle.3.group", "The Ledger widget", "Your last ten scores, putts, fairways and greens on the Home Screen."),
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

/// One page for both ways in: Fairway Ledger Plus (monthly, or yearly with a week's free trial) and the
/// one-time Pro unlock. It shows every term a subscription page must: price, period, trial, auto-renewal,
/// Terms of Use, Privacy Policy, Restore Purchases and the subscription settings.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Plus.self) private var plus
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false
    @State private var choice: Choice = .yearly
    @State private var redeem = false
    @State private var manage = false

    enum Choice: Hashable { case yearly, monthly, pro }

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SheetHeader(eyebrow: Plus.name, title: headline) { dismiss() }
                        .padding(.horizontal, -20)
                    Text("Logging stays yours, whatever you choose. Plus turns the ledger into a coach; Pro is the stat book, once.")
                        .font(.body(15)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                    teaser
                    compare
                    if pro.unlocked && !plus.active { proOwner }
                    VStack(spacing: 10) {
                        option(.yearly, title: "Plus Yearly", price: "\(plus.price(Plus.yearlyID)) a year",
                               note: plus.trialText.map { "\($0) free, then \(plus.price(Plus.yearlyID)) a year" } ?? plus.yearlyPerMonth.map { "Works out at \($0) a month" },
                               badge: plus.trialText == nil ? "Best value" : "Free trial")
                        option(.monthly, title: "Plus Monthly", price: "\(plus.price(Plus.monthlyID)) a month", note: "Cancel any time", badge: nil)
                        if !pro.unlocked {
                            option(.pro, title: Pro.name, price: "\(pro.price) once", note: "The stat book only, yours for good", badge: nil)
                        }
                    }
                    if let m = plus.message ?? pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    FoilButton(busy ? "One moment" : cta, icon: choice == .pro ? "lock.open.fill" : "sparkles") {
                        Task {
                            switch choice {
                            case .pro: await pro.buy()
                            case .yearly: await plus.buy(Plus.yearlyID)
                            case .monthly: await plus.buy(Plus.monthlyID)
                            }
                        }
                    }
                    .disabled(busy || (plus.active && choice != .pro))
                    terms
                    HStack(spacing: 10) {
                        GhostButton("Restore", icon: "arrow.clockwise") { Task { await plus.restore(); await pro.restore() } }
                        GhostButton("Redeem code", icon: "giftcard") { redeem = true }
                    }
                    if plus.active { GhostButton("Manage subscription", icon: "gearshape") { manage = true } }
                    HStack(spacing: 18) {
                        Link("Terms of Use", destination: Plus.terms)
                        Link("Privacy Policy", destination: Plus.privacy)
                    }
                    .font(.body(12.5, .semibold)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .offerCodeRedemption(isPresented: $redeem) { _ in Task { await plus.refresh() } }
        .manageSubscriptionsSheet(isPresented: $manage)
        .task { await plus.load() }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) { shown = true }
        }
        .onChange(of: plus.active) { _, now in if now { dismiss() } }
        .onChange(of: pro.unlocked) { _, now in if now && choice == .pro { dismiss() } }
    }

    private var busy: Bool { pro.busy || plus.busy }

    private var headline: String {
        switch reason {
        case .export: return "Take your ledger anywhere."
        case .insights: return "See where your game is going."
        case .backup: return "Keep the ledger safe in iCloud."
        case .plus: return "A coach in your bag."
        default: return "Read your game like a pro."
        }
    }

    private var cta: String {
        switch choice {
        case .pro: return "Unlock Pro for \(pro.price)"
        case .monthly: return plus.active ? "Plus is on" : "Subscribe for \(plus.price(Plus.monthlyID)) a month"
        case .yearly:
            if plus.active { return "Plus is on" }
            return plus.trialText.map { "Start \($0) free trial" } ?? "Subscribe for \(plus.price(Plus.yearlyID)) a year"
        }
    }

    private var terms: some View {
        let y = plus.price(Plus.yearlyID), m = plus.price(Plus.monthlyID)
        let trial = plus.trialText.map { " The yearly plan starts with \($0) free; you are charged \(y) when the trial ends unless you cancel before then." } ?? ""
        return Text("Plus is an auto-renewable subscription: \(m) a month or \(y) a year.\(trial) Payment is charged to your Apple ID when you confirm the purchase. It renews automatically for the same period and price unless auto-renew is turned off at least 24 hours before the end of the current period; your account is charged for the renewal within the 24 hours before the period ends. Manage or cancel in Settings > your name > Subscriptions. Pro is a single purchase with no renewal.")
            .font(.body(11)).foregroundStyle(Gold.faint).fixedSize(horizontal: false, vertical: true)
    }

    private var proOwner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("You own Pro. It stays yours.", systemImage: "checkmark.seal.fill").font(.body(14, .semibold)).foregroundStyle(Gold.pale)
            Text("Plus adds the insights, every finish, iCloud backup, and new plans and posters each month, on top of everything Pro already gives you. Have an offer code? Redeem it below.")
                .font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func option(_ c: Choice, title: String, price: String, note: String?, badge: String?) -> some View {
        let on = choice == c
        return Button { Haptic.tap(); withAnimation(.snappy) { choice = c } } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 20))
                    .foregroundStyle(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                        if let badge {
                            Text(badge.uppercased()).font(.body(9.5, .bold)).tracking(1.2).foregroundStyle(Gold.ink)
                                .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(Gold.foil))
                        }
                    }
                    if let note { Text(note).font(.body(12)).foregroundStyle(Gold.muted) }
                }
                Spacer(minLength: 6)
                Text(price).font(.body(13.5, .semibold)).foregroundStyle(Gold.ivory).multilineTextAlignment(.trailing)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.lacquer))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.leaf.opacity(0.14)), lineWidth: on ? 1.6 : 0.8))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(title), \(price)" + (note.map { ", \($0)" } ?? ""))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var compare: some View {
        let rows: [(String, Bool)] = [
            ("Score trend, where the strokes go, course pages", true),
            ("Ledger widget and spreadsheet export", true),
            ("Handicap pace and strokes against your target", false),
            ("Every colour finish and its app icon", false),
            ("\(Plus.monthlyPlans) practice plans and \(Plus.monthlyPosters) posters every month", false),
            ("iCloud backup of the whole ledger", false),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text("PRO").frame(width: 46)
                Text("PLUS").frame(width: 46)
            }
            .font(.body(10, .bold)).tracking(1.4).foregroundStyle(Gold.muted).padding(.bottom, 8)
            ForEach(rows, id: \.0) { r in
                HStack(spacing: 10) {
                    Text(r.0).font(.body(13)).foregroundStyle(Gold.ivory.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: r.1 ? "checkmark" : "minus").font(.body(12, .bold))
                        .foregroundStyle(r.1 ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.faint)).frame(width: 46)
                    Image(systemName: "checkmark").font(.body(12, .bold)).foil().frame(width: 46)
                }
                .padding(.vertical, 9)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.0 + (r.1 ? ", in Pro and Plus" : ", Plus only"))
                Rectangle().fill(Gold.leaf.opacity(0.08)).frame(height: 0.8)
            }
        }
        .card()
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
            .frame(height: 110)
            .blur(radius: 4)
            .overlay { ProSeal(size: 80).scaleEffect(shown ? 1 : 0.3).rotationEffect(.degrees(shown ? 0 : -30)) }
        }
        .card()
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
                FoilButton("See Plus and Pro", icon: "sparkles") { pro.ask(reason) }
                Text("Comes with Plus, or with Pro once. Your ledger stays yours either way.").font(.body(12)).foregroundStyle(Gold.faint)
                    .multilineTextAlignment(.center)
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
            if pro.has {
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
        .task(id: pro.has) { if pro.has { files = ledger.exportCSV() } }
    }
}

/// The Pro status card on Home, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pro.has ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Gold.lacquerHi))
                Image(systemName: pro.has ? "checkmark" : "lock.fill").font(.body(13, .bold))
                    .foregroundStyle(pro.has ? AnyShapeStyle(Gold.ink) : AnyShapeStyle(Gold.foil))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.has ? Pro.name : "\(Pro.name), \(pro.price) once").font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for buying the ledger early." : "Unlocked. Thank you.")
                     : pro.viaPlus ? "Included with your Plus membership." : ProCopy.short)
                    .font(.body(12)).foregroundStyle(Gold.muted)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.body(11.5, .semibold)).foregroundStyle(Gold.pale) }
            }
            Spacer(minLength: 6)
            if !pro.has {
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
