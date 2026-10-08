import StoreKit
import SwiftUI
import WidgetKit

/// The 99-cent corner, kept apart from Pro so Pro's grandfathering stays exactly as it was.
/// Practice Plans and Round Posters are consumables people buy again; finishes are one-time.
@MainActor
@Observable
final class Extras {
    static let plansID = "com.mattbusel.fairwayledger.plans"
    static let postersID = "com.mattbusel.fairwayledger.posters"
    static func finishID(_ id: String) -> String { "com.mattbusel.fairwayledger.finish." + id }
    static var allIDs: [String] { [plansID, postersID] + Finish.all.filter { $0.id != "gold" }.map { finishID($0.id) } }

    private(set) var owned: Set<String> = []
    private(set) var products: [String: Product] = [:]
    var busy: String?
    var message: String?
    private var updates: Task<Void, Never>?
    private let demo: Bool
    private let d = UserDefaults.standard

    /// Banked consumables.
    var plans: Int { didSet { d.set(plans, forKey: "extras.plans") } }
    var posters: Int { didSet { d.set(posters, forKey: "extras.posters") } }

    init(demo: Bool, locked: Bool = false) {
        self.demo = demo
        plans = d.integer(forKey: "extras.plans")
        posters = d.integer(forKey: "extras.posters")
        if demo {
            owned = locked ? [] : [Extras.finishID("rose")]
            return
        }
        owned = Set(d.stringArray(forKey: "extras.owned") ?? [])
        updates = Task { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
        Task {
            for await r in Transaction.unfinished { await handle(r) }
            await refresh()
        }
    }

    func price(_ id: String) -> String { products[id]?.displayPrice ?? (demo ? "$0.99" : "…") }
    func ownsFinish(_ id: String) -> Bool { id == "gold" || owned.contains(Extras.finishID(id)) }

    // MARK: free allowances

    static var week: String {
        let c = Calendar(identifier: .iso8601)
        let w = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return "\(w.yearForWeekOfYear ?? 0)-\(w.weekOfYear ?? 0)"
    }
    /// One plan a week is free for everyone.
    var freePlanLeft: Bool { d.string(forKey: "extras.freePlanWeek") != Extras.week }
    var firstPosterFree: Bool { !d.bool(forKey: "extras.freePosterUsed") }
    /// How many plans have been drawn this week, so each new one leans on a different weakness.
    var plansThisWeek: Int { d.string(forKey: "extras.planWeek") == Extras.week ? d.integer(forKey: "extras.planCount") : 0 }

    func loadProducts() async {
        guard !demo, products.count < Extras.allIDs.count else { return }
        if let ps = try? await Product.products(for: Extras.allIDs) { for p in ps { products[p.id] = p } }
    }

    func refresh() async {
        guard !demo else { return }
        var has: Set<String> = []
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil, t.productType == .nonConsumable, t.productID != Pro.productID { has.insert(t.productID) }
        }
        owned = has
        d.set(Array(has), forKey: "extras.owned")
        // A refunded finish falls back to gold leaf.
        if !ownsFinish(Finish.current.id) { Finish.apply("gold"); WidgetCenter.shared.reloadAllTimelines() }
        await loadProducts()
    }

    private func handle(_ r: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = r, Extras.allIDs.contains(t.productID) else { return }
        credit(t)
        await t.finish()
        await refresh()
    }

    /// Bank a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: StoreKit.Transaction) {
        guard t.productType == .consumable, t.revocationDate == nil else { return }
        var seen = Set(d.stringArray(forKey: "extras.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id)); d.set(Array(seen), forKey: "extras.credited")
        if t.productID == Extras.plansID { plans += 3 }
        if t.productID == Extras.postersID { posters += 3 }
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        message = nil
        if demo {
            if id == Extras.plansID { plans += 3 } else if id == Extras.postersID { posters += 3 } else { owned.insert(id) }
            return true
        }
        await loadProducts()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return false }
        busy = id; defer { busy = nil }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "Apple could not confirm that purchase. Try Restore in a minute."; return false }
                credit(t)
                await t.finish()
                await refresh()
                Haptic.done()
                return true
            case .pending: message = "Waiting for approval. It arrives by itself once approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
        return false
    }

    func restore() async {
        guard !demo else { return }
        busy = "restore"; defer { busy = nil }
        try? await AppStore.sync()
        await refresh()
    }

    /// Spend this week's free plan, or a banked one. False if there is nothing to spend.
    func spendPlan() -> Bool {
        if freePlanLeft { d.set(Extras.week, forKey: "extras.freePlanWeek") }
        else if plans > 0 { plans -= 1 }
        else { return false }
        let n = plansThisWeek + 1
        d.set(Extras.week, forKey: "extras.planWeek"); d.set(n, forKey: "extras.planCount")
        return true
    }

    /// Spend a poster credit (or the free first one). False if there is nothing to spend.
    func spendPoster() -> Bool {
        if demo { return true }
        if firstPosterFree { d.set(true, forKey: "extras.freePosterUsed"); return true }
        guard posters > 0 else { return false }
        posters -= 1
        return true
    }
}

// MARK: - Shop

struct ShopSheet: View {
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    @State private var current = Finish.current.id
    var onFinish: () -> Void = {}

    var body: some View {
        ZStack {
            LacquerBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(eyebrow: "Extras", title: "Small things,\n99 cents each.") { dismiss() }.padding(.horizontal, -20)

                    VStack(spacing: 0) {
                        row(icon: "list.bullet.clipboard", title: "Practice Plans, 3 for 99¢",
                            sub: "A range session built from your own numbers: the clubs, targets and putts your last rounds say need work. One a week is free" + (extras.freePlanLeft ? " (this week's is ready)." : "; you've drawn this week's.") + " Banked: \(extras.plans).",
                            id: Extras.plansID)
                        Rectangle().fill(Gold.leaf.opacity(0.1)).frame(height: 0.8).padding(.horizontal, 16)
                        row(icon: "photo.artframe", title: "Round Posters, 3 for 99¢",
                            sub: "A gold-leaf scorecard of a round to share or frame. " + (extras.firstPosterFree ? "Your first one is free." : "Left: \(extras.posters)."),
                            id: Extras.postersID)
                    }
                    .card(padding: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Finishes")
                        Text("Re-leaf the whole ledger, the widgets and the app icon. Yours without Pro.").font(.body(13)).foregroundStyle(Gold.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Finish.all) { f in finishCard(f) }
                    }

                    if let m = extras.message { Text(m).font(.body(13, .semibold)).foregroundStyle(Gold.pale).frame(maxWidth: .infinity) }
                    GhostButton(extras.busy == "restore" ? "Restoring" : "Restore purchases", icon: "arrow.clockwise") { Task { await extras.restore() } }
                    Text("Finishes restore on all your devices. Plans and posters are used up as you use them.")
                        .font(.body(11.5)).foregroundStyle(Gold.faint).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .task { await extras.loadProducts() }
    }

    private func row(icon: String, title: String, sub: String, id: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.body(16, .semibold)).foil()
                .frame(width: 40, height: 40).background(Circle().fill(Gold.lacquerHi))
                .overlay(Circle().strokeBorder(Gold.hairline, lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.display(17, .medium)).foregroundStyle(Gold.ivory)
                Text(sub).font(.body(12.5)).foregroundStyle(Gold.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button { Task { await extras.buy(id) } } label: {
                Group { if extras.busy == id { ProgressView().tint(Gold.ink) } else { Text(extras.price(id)).font(.body(13, .bold)) } }
                    .foregroundStyle(Gold.ink).padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(Gold.foil))
            }
            .buttonStyle(PressStyle()).disabled(extras.busy != nil)
        }
        .padding(16)
    }

    private func finishCard(_ f: Finish) -> some View {
        let owned = extras.ownsFinish(f.id), on = current == f.id
        return Button {
            if owned { use(f) } else { Task { if await extras.buy(Extras.finishID(f.id)) { use(f) } } }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Gold.ink)
                    Circle().fill(LinearGradient(colors: f.band, startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "flag.fill").font(.system(size: 17)).foregroundStyle(Gold.ink.opacity(0.75)))
                        .shadow(color: f.leaf.opacity(0.45), radius: 12)
                }.frame(height: 72)
                HStack {
                    Text(f.name).font(.display(16, .medium)).foregroundStyle(Gold.ivory)
                    Spacer()
                    if on { Image(systemName: "checkmark.seal.fill").foregroundStyle(f.leaf) }
                    else if owned { Text("Use").font(.body(12, .bold)).foregroundStyle(f.leaf) }
                    else { Text(extras.price(Extras.finishID(f.id))).font(.body(11.5, .bold)).foregroundStyle(Gold.ink).padding(.horizontal, 8).frame(height: 22).background(Capsule().fill(LinearGradient(colors: f.band, startPoint: .leading, endPoint: .trailing))) }
                }
                Text(f.blurb).font(.body(11)).foregroundStyle(Gold.muted).lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Gold.lacquer))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? f.leaf : Gold.leaf.opacity(0.12), lineWidth: on ? 1.6 : 0.8))
        }
        .buttonStyle(PressStyle()).disabled(extras.busy != nil)
    }

    private func use(_ f: Finish) {
        Finish.apply(f.id)
        current = f.id
        if UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != f.icon,
           !ProcessInfo.processInfo.arguments.contains("-shot") {
            UIApplication.shared.setAlternateIconName(f.icon)
        }
        WidgetCenter.shared.reloadAllTimelines()
        Haptic.thud()
        onFinish()
    }
}
