import StoreKit
import SwiftUI
import WidgetKit

/// Fairway Ledger Plus: an auto-renewable subscription, monthly or yearly (the yearly with a week's free trial).
/// While it is active it includes everything in Pro, every finish, a monthly refill of plans and posters,
/// the Plus insights and an iCloud backup of the ledger. Kept apart from Pro, whose one-time unlock and
/// grandfathering stay exactly as they were: a lapsed Plus takes nothing anyone bought.
@MainActor
@Observable
final class Plus {
    static let monthlyID = "com.mattbusel.fairwayledger.plus.monthly"
    static let yearlyID = "com.mattbusel.fairwayledger.plus.yearly"
    static let ids = [yearlyID, monthlyID]
    static let name = "Fairway Ledger Plus"
    /// Apple's standard licence agreement, which the app uses as its Terms of Use.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/fairway-ledger/privacy/")!
    /// Plans and posters added at the start of each month while Plus is active.
    static let monthlyPlans = 5
    static let monthlyPosters = 3

    private(set) var active: Bool
    private(set) var products: [String: Product] = [:]
    private(set) var plan: String?
    private(set) var renews: Date?
    private(set) var willRenew = true
    private(set) var trialEligible = true
    var busy = false
    var message: String?
    /// Told whenever Plus starts or lapses: the app passes it to Pro, Extras and the widgets.
    @ObservationIgnored var onChange: ((Bool) -> Void)?

    private let forced: Bool
    private var updates: Task<Void, Never>?
    private let key = "fairwayledger.plus.active"

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced {
            active = forced
            if forced { plan = Plus.yearlyID; renews = Calendar.current.date(byAdding: .month, value: 7, to: .now) }
            return
        }
        active = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                guard case .verified(let t) = r, Plus.ids.contains(t.productID) else { continue }
                await t.finish()
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    var yearly: Product? { products[Plus.yearlyID] }
    var monthly: Product? { products[Plus.monthlyID] }
    var isDemo: Bool { forced }

    func price(_ id: String) -> String {
        if let p = products[id] { return p.displayPrice }
        return forced ? (id == Plus.yearlyID ? "$14.99" : "$2.99") : "…"
    }

    /// "1 week" for the yearly plan's free trial, if this Apple ID can still take it.
    var trialText: String? {
        guard trialEligible else { return nil }
        if forced { return "1 week" }
        guard let o = yearly?.subscription?.introductoryOffer, o.paymentMode == .freeTrial else { return nil }
        return Plus.periodText(o.period)
    }

    static func periodText(_ p: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch p.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return p.value == 1 ? "1 \(unit)" : "\(p.value) \(unit)s"
    }

    /// The yearly plan's price spread over twelve months, for the comparison line.
    var yearlyPerMonth: String? {
        if forced { return "$1.25" }
        guard let y = yearly else { return nil }
        return (y.price / 12).formatted(y.priceFormatStyle)
    }

    func load() async {
        guard !forced, products.count < Plus.ids.count else { return }
        if let ps = try? await Product.products(for: Plus.ids) { for p in ps { products[p.id] = p } }
    }

    func refresh() async {
        guard !forced else { return }
        await load()
        var found: StoreKit.Transaction?
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Plus.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if (t.expirationDate ?? .distantFuture) > .now { found = t }
        }
        plan = found?.productID
        renews = found?.expirationDate
        if let p = yearly ?? monthly, let statuses = try? await p.subscription?.status,
           let s = statuses.first(where: { if case .verified(let t) = $0.transaction { return Plus.ids.contains(t.productID) } else { return false } }),
           case .verified(let info) = s.renewalInfo {
            willRenew = info.willAutoRenew
        }
        if let y = yearly { trialEligible = await y.subscription?.isEligibleForIntroOffer ?? false }
        set(found != nil)
    }

    private func set(_ now: Bool) {
        let changed = now != active
        if changed { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { active = now } }
        UserDefaults.standard.set(now, forKey: key)
        onChange?(now)
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        guard !forced, !busy else { return false }
        busy = true; message = nil
        defer { busy = false }
        await load()
        guard let product = products[id] else {
            message = "The App Store did not answer. Check your connection and try again."
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result else {
                    message = "Apple could not confirm the purchase. Try Restore in a minute."
                    return false
                }
                await t.finish()
                await refresh()
                if active { Haptic.done() }
                return active
            case .pending:
                message = "Waiting for approval. Plus starts by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
        return false
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
        message = active ? "Plus is active. Welcome back." : "No active Plus subscription on this Apple ID."
    }
}

// MARK: - iCloud backup (Plus)

/// The whole ledger, compressed, in the user's own iCloud key-value store. Nothing goes anywhere else.
enum CloudBackup {
    private static let dataKey = "ledger.backup"
    private static let dateKey = "ledger.backupDate"
    private static let store = NSUbiquitousKeyValueStore.default
    /// The key-value store holds 1 MB per app; leave headroom.
    static let limit = 960_000

    static var lastDate: Date? {
        let t = store.double(forKey: dateKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    @discardableResult
    static func save(_ raw: Data?) -> Bool {
        guard let raw, let packed = try? (raw as NSData).compressed(using: .lzfse) as Data, packed.count < limit else { return false }
        store.set(packed, forKey: dataKey)
        store.set(Date.now.timeIntervalSince1970, forKey: dateKey)
        return store.synchronize()
    }

    static func load() -> Data? {
        store.synchronize()
        guard let packed = store.data(forKey: dataKey) else { return nil }
        return try? (packed as NSData).decompressed(using: .lzfse) as Data
    }
}

// MARK: - Plus on Home

/// Home's membership card: what Plus is, or what it is doing for you.
struct PlusCard: View {
    @Environment(Plus.self) private var plus
    @Environment(Pro.self) private var pro
    @Environment(Router.self) private var router

    var body: some View {
        Button { if plus.active { router.plusHub = true } else { pro.ask(.plus) } } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Gold.foil)
                    Image(systemName: plus.active ? "crown.fill" : "sparkles").font(.body(15, .bold)).foregroundStyle(Gold.ink)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plus.active ? "\(Plus.name) is on" : Plus.name).font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                    Text(plus.active ? "Insights, every finish, iCloud backup, and new plans and posters each month."
                                     : "Everything in Pro, plus insights, every finish, iCloud backup and new plans each month.")
                        .font(.body(12)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.body(13, .bold)).foil()
            }
            .card(padding: 14)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(plus.active ? "Fairway Ledger Plus settings" : "See Fairway Ledger Plus")
    }
}

/// For a Plus member: the plan, backup and restore, and the subscription settings.
struct PlusHub: View {
    @Environment(Plus.self) private var plus
    @Environment(Ledger.self) private var ledger
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    @State private var manage = false
    @State private var confirmRestore = false
    @State private var note: String?
    @State private var last = CloudBackup.lastDate

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHeader(eyebrow: Plus.name, title: "Your membership") { dismiss() }.padding(.horizontal, -20)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plus.plan == Plus.yearlyID ? "Plus Yearly" : "Plus Monthly").font(.display(22, .medium)).foregroundStyle(Gold.ivory)
                        if let d = plus.renews {
                            Text((plus.willRenew ? "Renews " : "Ends ") + d.formatted(date: .long, time: .omitted)).font(.body(13)).foregroundStyle(Gold.muted)
                        }
                        Text("This month: \(Plus.monthlyPlans) practice plans and \(Plus.monthlyPosters) round posters added. Banked now: \(extras.plans) plans, \(extras.posters) posters.")
                            .font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow("iCloud backup")
                        Text(last.map { "Last backup " + $0.formatted(date: .abbreviated, time: .shortened) + ". The ledger backs itself up as you save." }
                             ?? "The ledger backs itself up to your iCloud as you save. Nothing leaves your Apple account.")
                            .font(.body(13)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            GhostButton("Back up now", icon: "icloud.and.arrow.up") {
                                if CloudBackup.save(ledger.backupData()) { last = CloudBackup.lastDate; note = "Backed up."; Haptic.done() }
                                else { note = "iCloud is not available. Check that you are signed in to iCloud." }
                            }
                            GhostButton("Restore", icon: "icloud.and.arrow.down") { confirmRestore = true }
                        }
                        if let note { Text(note).font(.body(12.5, .semibold)).foregroundStyle(Gold.pale) }
                    }
                    .card()
                    .confirmationDialog("Replace this phone's ledger with the iCloud backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                        Button("Restore from iCloud", role: .destructive) {
                            if let d = CloudBackup.load(), ledger.restore(from: d) { note = "Restored."; Haptic.done() }
                            else { note = "No backup found in iCloud yet." }
                        }
                    }

                    GhostButton("Manage subscription", icon: "gearshape") { manage = true }
                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: Plus.terms)
                        Link("Privacy Policy", destination: Plus.privacy)
                    }
                    .font(.body(12, .semibold)).foregroundStyle(Gold.muted).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .manageSubscriptionsSheet(isPresented: $manage)
    }
}
