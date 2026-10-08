import SwiftUI
import WidgetKit

@main
struct FairwayLedgerApp: App {
    @State private var ledger: Ledger
    @State private var router = Router()
    @State private var pro: Pro
    @State private var extras: Extras

    init() {
        let args = ProcessInfo.processInfo.arguments
        let demo = args.contains("-shot") || UserDefaults.standard.bool(forKey: "demoMode")
        _ledger = State(initialValue: Ledger(demo: demo))
        // Screenshots and the review recording show Pro; the paywall and locked shots show it locked.
        let shot = args.firstIndex(of: "-shot").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        let staged = shot != nil || args.contains("-demoAutoplay")
        _pro = State(initialValue: staged ? Pro(forced: !lockedShot) : Pro())
        _extras = State(initialValue: Extras(demo: staged, locked: lockedShot || shot == "shop"))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ledger)
                .environment(router)
                .environment(pro)
                .environment(extras)
                .preferredColorScheme(.dark)
                .tint(Gold.leaf)
                .onAppear {
                    router.applyShotArgs(ledger, pro)
                    Autopilot.shared.run(router)
                    ledger.didSave = { [ledger, pro] in
                        ledger.glance(unlocked: pro.unlocked, weeklyTarget: UserDefaults.standard.object(forKey: "weeklyTarget") as? Int ?? 240).save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    ledger.didSave?()
                }
                .onChange(of: pro.unlocked) { _, _ in ledger.didSave?() }
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
    /// Bumped when the finish changes, so every view redraws in the new metal.
    var finishTick = 0

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
        case "paywall": tab = .stats; pro.paywall = .stats
        case "plan": plan = Planner.make(l)
        case "poster": tab = .rounds; poster = l.rounds[0]
        case "course": tab = .rounds; course = l.courses.first { c in l.rounds.filter { $0.courseID == c.id }.count >= 3 } ?? l.courses.first
        case "shop": shop = true
        case "widgets": showcase = true
        case "strokes": tab = .stats
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

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
