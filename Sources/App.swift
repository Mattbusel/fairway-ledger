import StoreKit
import SwiftUI
import TipKit
import WidgetKit

@main
struct FairwayLedgerApp: App {
    @State private var ledger: Ledger
    @State private var router = Router()
    @State private var pro: Pro
    @State private var extras: Extras
    @State private var plus: Plus
    @Environment(\.scenePhase) private var phase

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || args.contains("-preview") || UserDefaults.standard.bool(forKey: "demoMode")
        _ledger = State(initialValue: Ledger(demo: demo))
        // Screenshots and the review recording show Plus; the paywall and locked shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        let staged = shot != nil || args.contains("-demoAutoplay") || args.contains("-preview")
        _pro = State(initialValue: staged ? Pro(forced: !lockedShot) : Pro())
        _extras = State(initialValue: Extras(demo: staged, locked: lockedShot || shot == "shop"))
        _plus = State(initialValue: staged ? Plus(forced: !lockedShot && shot != "shop") : Plus())
        if !staged { try? Tips.configure([.displayFrequency(.daily)]) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ledger)
                .environment(router)
                .environment(pro)
                .environment(extras)
                .environment(plus)
                .preferredColorScheme(.dark)
                .tint(Gold.leaf)
                .onAppear {
                    plus.onChange = { [pro, extras, ledger] on in
                        pro.viaPlus = on
                        extras.plusActive = on
                        extras.refill()
                        ledger.didSave?()
                    }
                    if plus.active { pro.viaPlus = true; extras.plusActive = true }
                    router.applyShotArgs(ledger, pro)
                    Autopilot.shared.run(router)
                    ledger.didSave = { [ledger, pro, plus] in
                        ledger.glance(unlocked: pro.has, weeklyTarget: UserDefaults.standard.object(forKey: "weeklyTarget") as? Int ?? 240).save()
                        WidgetCenter.shared.reloadAllTimelines()
                        if plus.active, !plus.isDemo { Backup.soon(ledger) }
                    }
                    ledger.ingestQuickLogs()
                    ledger.didSave?()
                    router.follow(Route.take())
                }
                .onChange(of: pro.unlocked) { _, _ in ledger.didSave?() }
                .onChange(of: phase) { _, now in
                    guard now == .active else { return }
                    ledger.ingestQuickLogs()
                    router.follow(Route.take())
                    Task { await plus.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .fairwayRoute)) { _ in router.follow(Route.take()) }
                .onOpenURL { url in router.follow(Route(rawValue: url.host() ?? url.lastPathComponent)) }
                .task {
                    // Purchases started on the App Store product page (promoted in-app purchases).
                    for await intent in PurchaseIntent.intents {
                        let id = intent.product.id
                        if Plus.ids.contains(id) { await plus.buy(id) }
                        else if id == Pro.productID { await pro.buy() }
                        else { await extras.buy(id) }
                    }
                }
        }
    }
}

/// Saves the iCloud backup a little after the last change, so a burst of edits is one write.
@MainActor
enum Backup {
    private static var pending: Task<Void, Never>?
    static func soon(_ ledger: Ledger) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            CloudBackup.save(ledger.backupData())
        }
    }
}

enum Tab: String, CaseIterable { case home = "Home", journal = "Journal", rounds = "Rounds", stats = "Stats", bag = "Bag" }

@Observable
final class Router {
    var tab: Tab = .home
    var live: PracticeSession?
    var finishing: PracticeSession?
    var editingRound: Round?
    var viewing: PracticeSession?
    var plan: PracticePlan?
    var poster: Round?
    var course: Course?
    var shop = false
    var showcase = false
    var challenge = false
    var insights = false
    var plusHub = false
    /// Bumped when the finish changes, so every view redraws in the new metal.
    var finishTick = 0
    /// Set by the app so a route can ask for the plan or a paywall.
    @ObservationIgnored var openPlan: (() -> Void)?
    @ObservationIgnored var openPlus: (() -> Void)?
    @ObservationIgnored var draft: (() -> Round?)?

    /// Open a screen asked for by a control, a shortcut, Siri or an In-App Event link.
    @MainActor
    func follow(_ r: Route?) {
        // A range session or a scorecard in progress is never thrown away for a shortcut.
        guard let r, live == nil, editingRound == nil, finishing == nil else { return }
        // Close any sheet first, so the new screen is never stacked behind one.
        plan = nil; poster = nil; course = nil; shop = false; challenge = false; insights = false; plusHub = false; viewing = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in
            switch r {
            case .practice: live = PracticeSession()
            case .round: editingRound = draft?() ?? Round()
            case .plan: tab = .home; openPlan?()
            case .challenge: tab = .home; challenge = true
            case .stats: tab = .stats
            case .insights: tab = .stats; insights = true
            case .plus: openPlus?()
            }
        }
    }

    @MainActor
    func applyShotArgs(_ l: Ledger, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "live":
            var s = l.sessions[0]; s.id = UUID(); s.minutes = 38
            s.blocks = Array(s.blocks.prefix(2))
            live = s
        case "finish": finishing = l.sessions[0]
        case "rounds": tab = .rounds
        case "scorecard": tab = .rounds; editingRound = l.rounds[0]
        case "stats": tab = .stats
        case "bag": tab = .bag
        case "journal": tab = .journal
        case "locked": tab = .stats
        case "paywall": tab = .stats; pro.paywall = .plus
        case "plan": plan = Planner.make(l)
        case "poster": tab = .rounds; poster = l.rounds[0]
        case "course": tab = .rounds; course = l.courses.first { c in l.rounds.filter { $0.courseID == c.id }.count >= 3 } ?? l.courses.first
        case "shop": shop = true
        case "widgets": showcase = true
        case "strokes": tab = .stats
        case "challenge": challenge = true
        case "insights": tab = .stats; insights = true
        case "plushub": plusHub = true
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(Extras.self) private var extras
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            LacquerBackground()
            Group {
                switch router.tab {
                case .home: HomeView()
                case .journal: JournalView()
                case .rounds: RoundsView()
                case .stats: StatsView()
                case .bag: BagView()
                }
            }
            .transition(.opacity)
            GoldTabBar(selection: $router.tab) { t in
                switch t {
                case .home: return "sun.horizon"
                case .journal: return "book.closed"
                case .rounds: return "flag.2.crossed"
                case .stats: return "chart.xyaxis.line"
                case .bag: return "bag"
                }
            }
            .padding(.bottom, 2)
        }
        .id(router.finishTick)
        .overlay { if router.showcase { WidgetShowcase() } }
        .fullScreenCover(item: $router.live) { s in LiveSessionView(session: s) }
        .fullScreenCover(item: $router.finishing) { s in FinishSessionView(session: s) }
        .fullScreenCover(item: $router.editingRound) { r in ScorecardView(round: r) }
        .sheet(item: $router.viewing) { s in SessionDetailView(session: s).presentationBackground(Gold.ink) }
        .sheet(item: $pro.paywall) { r in PaywallView(reason: r).presentationBackground(Gold.ink) }
        .sheet(item: $router.plan) { p in PlanSheet(plan: p).presentationBackground(Gold.ink) }
        .sheet(item: $router.poster) { r in PosterSheet(round: r).presentationBackground(Gold.ink) }
        .sheet(item: $router.course) { c in CourseDetail(course: c).presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.shop) { ShopSheet { router.finishTick += 1 }.presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.challenge) { ChallengeSheet().presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.insights) { InsightsView().presentationBackground(Gold.ink) }
        .sheet(isPresented: $router.plusHub) { PlusHub().presentationBackground(Gold.ink) }
        .onAppear {
            router.draft = { [ledger] in ledger.draft }
            router.openPlus = { [pro] in pro.ask(.plus) }
            router.openPlan = { [ledger, extras, router] in
                if extras.spendPlan() { router.plan = Planner.make(ledger, variant: extras.plansThisWeek - 1) }
            }
        }
        // A new best round is a happy moment: the one time a version asks for a rating.
        .onChange(of: ledger.rounds.count) { old, new in
            guard new > old, new >= 3, !ProcessInfo.processInfo.arguments.contains("-shot"), !Autopilot.on, !Autopilot.preview,
                  let latest = ledger.rounds.max(by: { $0.date < $1.date }), !latest.isNine,
                  latest.toPar <= (ledger.rounds.filter { !$0.isNine && $0.id != latest.id }.map(\.toPar).min() ?? Int.max) else { return }
            ReviewAsk.happyMoment { requestReview() }
        }
    }
}

/// Every tab is a scroll view with the same margins and room for the floating tab bar.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) { content }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(eyebrow)
            Text(title).font(.display(36, .regular)).foregroundStyle(Gold.ivory)
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }
}
