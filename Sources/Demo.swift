import Foundation

/// Sample history, used only for store screenshots (-shot) and the empty-state "see an example".
enum Demo {
    static func fill(_ l: Ledger) {
        var rng = SeededRNG(seed: 7)
        let cal = Calendar.current
        func daysAgo(_ d: Int, hour: Int = 17) -> Date {
            cal.date(bySettingHour: hour, minute: 10, second: 0, of: cal.date(byAdding: .day, value: -d, to: .now)!)!
        }

        let journals = [
            ("Ball position two inches forward with the driver. Stopped hanging back.", "Low point with the wedges is finally in front of the ball.", "Start line on putts inside 6 ft. Pushing them."),
            ("Hold the finish for three seconds.", "Trusted the lag putting. Nothing past 3 ft all day.", "Bunker exits. Opening the face but not committing."),
            ("Tempo 3:1. Hum it.", "7i pure streak: nine in a row.", "Fade is creeping into a slice when I rush."),
            ("Quiet hands, turn through.", "Chips landing on my spot, releasing just like the plan.", "Distance control from 60 to 80 yards."),
        ]
        let places = ["Pebble Creek range", "Home putting green", "Riverside short game area", "Pebble Creek range", "Back 9, Oak Hollow"]

        for i in 0..<14 {
            var s = PracticeSession()
            s.date = daysAgo(i * 2 + (i > 3 ? 1 : 0), hour: 7 + (i % 3) * 5)
            s.place = places[i % places.count]
            s.minutes = [45, 60, 75, 90, 50][i % 5]
            s.focus = ["Driver start line", "Wedge distance ladder", "Putting 3 to 8 ft", "Bunker commitment", "Iron contact"][i % 5]
            s.rating = [4, 3, 5, 3, 4, 2, 4][i % 7]
            s.mood = [4, 3, 5, 4, 3][i % 5]
            s.energy = [3, 4, 4, 2, 5][i % 5]
            let j = journals[i % journals.count]
            s.swingThought = j.0; s.clicked = j.1; s.workOn = j.2
            s.journal = i == 0
                ? "Warmed up with the 9 iron and half swings. The driver was loose early, then the ball-position change clicked and I hit twelve of the last fifteen on my line. Stayed patient on the green: two lag drills and the clock drill. Left feeling like the swing is repeatable again."
                : "Solid hour. Kept it structured: block practice first, then random targets to finish."
            let improve = Double(14 - i) / 14
            let kinds: [DrillKind] = i % 3 == 0 ? [.fullSwing, .wedges, .putting] : i % 3 == 1 ? [.putting, .chipping, .bunker] : [.fullSwing, .pitching, .putting]
            for k in kinds {
                var b = DrillBlock(kind: k)
                if k.isPutting {
                    b.target = [3, 5, 8, 12, 20][Int.random(in: 0...4, using: &rng)]
                    b.putts = 20
                    let make = max(0.1, min(0.95, 1.1 - Double(b.target) * 0.045 + improve * 0.12))
                    b.onTarget = Int(Double(b.putts) * make)
                    let miss = b.putts - b.onTarget
                    b.puttMisses = [.low: miss / 2, .high: miss / 4, .short: miss / 6, .long: miss - miss / 2 - miss / 4 - miss / 6]
                } else {
                    b.club = k == .fullSwing ? ["Driver", "7i", "5i", "3W", "9i"][i % 5] : k == .wedges ? "54°" : "58°"
                    b.target = k == .fullSwing ? (b.club == "Driver" ? 240 : b.club == "7i" ? 160 : b.club == "5i" ? 185 : b.club == "3W" ? 215 : 140)
                        : k == .wedges ? 80 : k == .bunker ? 15 : 25
                    let n = Int.random(in: 30...50, using: &rng)
                    let pure = Int(Double(n) * (0.25 + improve * 0.25))
                    let poor = Int(Double(n) * (0.25 - improve * 0.12))
                    b.contact = [.pure: pure, .solid: n - pure - poor, .poor: poor]
                    b.onTarget = Int(Double(n) * (0.35 + improve * 0.25))
                    if k == .fullSwing || k == .wedges {
                        b.shape = [.draw: n / 3, .straight: n / 3, .fade: n / 6, .slice: n / 12, .hook: n - n / 3 - n / 3 - n / 6 - n / 12]
                        b.carries = (0..<5).map { _ in b.target + Int.random(in: -8...6, using: &rng) }
                    }
                    b.misses = [.right: Int(Double(n) * 0.14), .left: Int(Double(n) * 0.07), .fat: poor / 2, .thin: poor - poor / 2,
                                .short: n / 10, .long: n / 20]
                }
                s.blocks.append(b)
            }
            l.sessions.append(s)
        }

        let courses = [("Oak Hollow", "Blue", 71.8, 131), ("Pebble Creek", "White", 70.2, 124), ("Riverside Links", "White", 72.4, 128)]
        for i in 0..<11 {
            let c = courses[i % 3]
            var r = Round()
            r.date = daysAgo(i * 4 + 1, hour: 9)
            r.course = c.0; r.tees = c.1; r.rating = c.2; r.slope = c.3
            let skill = 0.55 + Double(i) * 0.05
            r.holes = Round.standardPars.enumerated().map { idx, par in
                var h = Hole(id: idx + 1, par: par, score: par)
                let x = Double.random(in: 0...1, using: &rng)
                h.score = par + (x < 0.1 ? -1 : x < 0.45 - skill * 0.2 ? 0 : x < 0.88 ? 1 : 2)
                h.putts = h.score < par ? 1 : (Double.random(in: 0...1, using: &rng) < 0.12 + skill * 0.06 ? 3 : 2)
                if h.score == par && Double.random(in: 0...1, using: &rng) < 0.35 { h.putts = 1 }
                h.putts = min(h.putts, h.score)
                if par > 3 {
                    let f = Double.random(in: 0...1, using: &rng)
                    h.fairway = f < 0.52 ? .hit : f < 0.8 ? .right : .left
                } else { h.fairway = .none }
                h.penalties = h.score - par >= 2 && Double.random(in: 0...1, using: &rng) < 0.4 ? 1 : 0
                h.sand = Double.random(in: 0...1, using: &rng) < 0.12
                return h
            }
            r.notes = i == 0 ? "Played the par 5s in one under. Two doubles both came from the tee shot right: that fade again under pressure." : ""
            r.mood = [4, 3, 4, 2, 5][i % 5]
            l.rounds.append(r)
        }
        l.goals = [
            Goal(text: "Break 80 at Oak Hollow", due: cal.date(byAdding: .month, value: 2, to: .now)),
            Goal(text: "Make 80% from 5 feet", due: cal.date(byAdding: .day, value: 30, to: .now)),
            Goal(text: "Zero three-putts in a round", due: nil, done: true),
        ]
        l.name = "Matthew"
        l.sessions.sort { $0.date > $1.date }
        l.rounds.sort { $0.date > $1.date }
    }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
