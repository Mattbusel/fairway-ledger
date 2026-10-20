import SwiftUI

/// Drives the real screens through a typical first use, for the App Review
/// recording (-demoAutoplay). It only sends cues; each screen performs the same
/// action its own buttons would, so what is recorded is the shipping code path.
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }

    private(set) var tick = 0
    private(set) var cue = ""
    private var running = false

    @MainActor private func send(_ c: String, then pause: Double = 0.7) async {
        cue = c; tick += 1
        try? await Task.sleep(for: .seconds(pause))
    }

    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    /// -preview: a 25-second tour on the sample ledger for the App Store app preview video.
    static var preview: Bool { ProcessInfo.processInfo.arguments.contains("-preview") }

    @MainActor
    private func runPreview(_ router: Router) {
        Task { @MainActor in
            await wait(2.6)
            router.challenge = true
            await wait(2.4)
            router.challenge = false
            await wait(0.6)
            router.live = PracticeSession()
            await wait(1.2)
            for c in ["live.pure", "live.solid", "live.target", "live.pure", "live.draw", "live.pure", "live.target", "live.carry"] {
                await send(c, then: 0.32)
            }
            await wait(0.4)
            await send("live.finish", then: 1.6)
            await send("fin.rating", then: 0.5)
            await send("fin.save", then: 1.0)
            router.editingRound = Round()
            await wait(1.2)
            for c in ["card.par", "card.next", "card.birdie", "card.next", "card.bogey", "card.next", "card.par"] {
                await send(c, then: 0.45)
            }
            await send("card.save", then: 1.0)
            withAnimation { router.tab = .stats }
            await wait(2.0)
            router.insights = true
            await wait(3.2)
            router.insights = false
            await wait(0.6)
            withAnimation { router.showcase = true }
            await wait(3.0)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? Data().write(to: docs.appendingPathComponent("demo_done"))
        }
    }

    @MainActor
    func run(_ router: Router) {
        if Autopilot.preview, !running { running = true; runPreview(router); return }
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)

            // A practice session at the range.
            router.live = PracticeSession()
            await wait(2)
            for c in ["live.pure", "live.pure", "live.solid", "live.target", "live.pure", "live.straight",
                      "live.target", "live.poor", "live.missRight", "live.pure", "live.draw", "live.carry", "live.carry"] {
                await send(c)
            }
            await wait(1)
            await send("live.putting", then: 1.6)
            for c in ["live.holed", "live.holed", "live.puttLow", "live.holed", "live.puttShort", "live.holed"] {
                await send(c)
            }
            await wait(1.2)
            await send("live.finish", then: 2.2)

            // Journal it.
            for c in ["fin.rating", "fin.mood", "fin.place", "fin.focus", "fin.thought", "fin.workOn"] {
                await send(c, then: 0.9)
            }
            await wait(1)
            await send("fin.save", then: 3)

            // Log a round, hole by hole.
            router.editingRound = Round()
            await wait(2)
            await send("card.course", then: 1.6)
            await send("card.closeDetails", then: 1)
            let holes = ["card.bogey", "card.par", "card.birdie", "card.par", "card.double", "card.par"]
            for c in holes {
                await send(c, then: 0.8)
                await send("card.next", then: 0.8)
            }
            await wait(1)
            await send("card.save", then: 3)

            // The saved data, tab by tab.
            for t in [Tab.journal, .rounds, .stats, .bag, .home] {
                withAnimation { router.tab = t }
                await wait(3)
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? Data().write(to: docs.appendingPathComponent("demo_done"))
        }
    }
}

extension View {
    /// Runs `handle` for every autopilot cue. Inert outside -demoAutoplay.
    func onCue(_ handle: @escaping (String) -> Void) -> some View {
        onChange(of: Autopilot.shared.tick) { _, _ in handle(Autopilot.shared.cue) }
    }
}
