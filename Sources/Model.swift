import Foundation
import Observation

// MARK: practice

enum DrillKind: String, Codable, CaseIterable, Identifiable {
    case fullSwing = "Full Swing", wedges = "Wedges", chipping = "Chipping", pitching = "Pitching",
         bunker = "Bunker", putting = "Putting", onCourse = "On Course"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .fullSwing: return "figure.golf"
        case .wedges: return "scope"
        case .chipping: return "arrow.up.forward"
        case .pitching: return "arrow.up.right.circle"
        case .bunker: return "beach.umbrella"
        case .putting: return "flag.fill"
        case .onCourse: return "map"
        }
    }
    var isPutting: Bool { self == .putting }
    var isShortGame: Bool { [.chipping, .pitching, .bunker].contains(self) }
}

enum Contact: String, Codable, CaseIterable { case pure = "Pure", solid = "Solid", poor = "Poor" }
enum Shape: String, Codable, CaseIterable { case hook = "Hook", draw = "Draw", straight = "Straight", fade = "Fade", slice = "Slice" }
enum Miss: String, Codable, CaseIterable {
    case left = "Left", right = "Right", short = "Short", long = "Long", fat = "Fat", thin = "Thin", top = "Topped", shank = "Shank"
}
enum PuttMiss: String, Codable, CaseIterable { case low = "Low side", high = "High side", short = "Short", long = "Long" }

/// One block of a session: a club or a putt distance, and everything tallied while hitting it.
struct DrillBlock: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: DrillKind
    var club: String = "7i"
    var target: Int = 150          // yards, or feet for putting
    var contact: [Contact: Int] = [:]
    var shape: [Shape: Int] = [:]
    var misses: [Miss: Int] = [:]
    var onTarget: Int = 0          // inside the target window / up-and-down / holed putt
    var putts: Int = 0             // putting attempts
    var puttMisses: [PuttMiss: Int] = [:]
    var carries: [Int] = []        // logged carry numbers
    var note: String = ""

    var balls: Int { kind.isPutting ? putts : contact.values.reduce(0, +) }
    var pureRate: Double { pctValue(contact[.pure] ?? 0, balls) }
    var avgCarry: Int? { carries.isEmpty ? nil : carries.reduce(0, +) / carries.count }
    var title: String { kind.isPutting ? "\(target) ft putts" : kind.isShortGame ? "\(kind.rawValue) · \(target) yd" : "\(club) · \(target) yd" }
}

struct PracticeSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date.now
    var minutes: Int = 0
    var place: String = ""
    var focus: String = ""
    var blocks: [DrillBlock] = []
    var rating: Int = 3
    var mood: Int = 3
    var energy: Int = 3
    var swingThought: String = ""
    var clicked: String = ""
    var workOn: String = ""
    var journal: String = ""

    var balls: Int { blocks.reduce(0) { $0 + $1.balls } }
}

// MARK: rounds

enum FairwayResult: String, Codable, CaseIterable { case hit = "Hit", left = "Left", right = "Right", none = "Par 3" }

struct Hole: Codable, Identifiable, Hashable {
    var id: Int
    var par: Int
    var score: Int
    var putts: Int = 2
    var fairway: FairwayResult = .hit
    var penalties: Int = 0
    var sand = false
    var gir: Bool { score - putts <= par - 2 }
    var upAndDown: Bool? { gir ? nil : (score <= par ? true : false) }
}

struct Round: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date.now
    var course: String = ""
    var tees: String = "White"
    var rating: Double = 72.0
    var slope: Int = 125
    var holes: [Hole] = Round.standardHoles
    var walked = true
    var mood: Int = 3
    var notes: String = ""

    static let standardPars = [4, 4, 3, 5, 4, 4, 3, 4, 5, 4, 3, 4, 5, 4, 4, 3, 5, 4]
    static var standardHoles: [Hole] { standardPars.enumerated().map { Hole(id: $0.offset + 1, par: $0.element, score: $0.element) } }

    var score: Int { holes.reduce(0) { $0 + $1.score } }
    var par: Int { holes.reduce(0) { $0 + $1.par } }
    var toPar: Int { score - par }
    var putts: Int { holes.reduce(0) { $0 + $1.putts } }
    var girs: Int { holes.filter(\.gir).count }
    var fairwayHoles: [Hole] { holes.filter { $0.par > 3 } }
    var fairwaysHit: Int { fairwayHoles.filter { $0.fairway == .hit }.count }
    var penalties: Int { holes.reduce(0) { $0 + $1.penalties } }
    var threePutts: Int { holes.filter { $0.putts >= 3 }.count }
    var scrambles: (made: Int, tries: Int) {
        let t = holes.compactMap(\.upAndDown); return (t.filter { $0 }.count, t.count)
    }
    var sandSaves: (made: Int, tries: Int) {
        let s = holes.filter(\.sand); return (s.filter { $0.score <= $0.par }.count, s.count)
    }
    var differential: Double { (Double(score) - rating) * 113 / Double(slope) }
    var toParText: String { toPar == 0 ? "E" : toPar > 0 ? "+\(toPar)" : "\(toPar)" }
}

// MARK: bag & goals

struct Club: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var loft: Double
    var carry: Int
    var total: Int
    var note: String = ""
}

struct Goal: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var due: Date?
    var done = false
}

// MARK: store

@Observable
final class Ledger {
    var sessions: [PracticeSession] = [] { didSet { save() } }
    var rounds: [Round] = [] { didSet { save() } }
    var bag: [Club] = Ledger.defaultBag { didSet { save() } }
    var goals: [Goal] = [] { didSet { save() } }
    var name: String = "" { didSet { save() } }

    private struct Snapshot: Codable {
        var sessions: [PracticeSession]; var rounds: [Round]; var bag: [Club]; var goals: [Goal]; var name: String
    }
    private var loading = false
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ledger.json")

    init(demo: Bool = false) {
        loading = true
        if demo { Demo.fill(self) } else if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            sessions = s.sessions; rounds = s.rounds; bag = s.bag; goals = s.goals; name = s.name
        }
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let snap = Snapshot(sessions: sessions, rounds: rounds, bag: bag, goals: goals, name: name)
        if let d = try? JSONEncoder().encode(snap) { try? d.write(to: url, options: .atomic) }
    }

    func upsert(_ s: PracticeSession) {
        if let i = sessions.firstIndex(where: { $0.id == s.id }) { sessions[i] = s } else { sessions.insert(s, at: 0) }
        sessions.sort { $0.date > $1.date }
    }
    func upsert(_ r: Round) {
        if let i = rounds.firstIndex(where: { $0.id == r.id }) { rounds[i] = r } else { rounds.insert(r, at: 0) }
        rounds.sort { $0.date > $1.date }
    }

    // MARK: derived

    /// World Handicap style: best 8 of the last 20 differentials, fewer when there are fewer rounds.
    var handicap: Double? {
        let diffs = rounds.prefix(20).map(\.differential).sorted()
        guard diffs.count >= 3 else { return nil }
        let use: Int = switch diffs.count { case 3...5: 1; case 6...8: 2; case 9...11: 3; case 12...14: 4; case 15...16: 5; case 17...18: 6; case 19: 7; default: 8 }
        let v = diffs.prefix(use).reduce(0, +) / Double(use)
        return (v * 0.96 * 10).rounded() / 10
    }

    func minutes(inLast days: Int) -> Int {
        let from = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return sessions.filter { $0.date >= from }.reduce(0) { $0 + $1.minutes }
    }

    var practiceStreakWeeks: Int {
        let cal = Calendar.current
        var n = 0
        var week = cal.dateInterval(of: .weekOfYear, for: .now)!
        while sessions.contains(where: { week.contains($0.date) }) {
            n += 1
            week = cal.dateInterval(of: .weekOfYear, for: week.start.addingTimeInterval(-3600))!
        }
        return n
    }

    var allBlocks: [DrillBlock] { sessions.flatMap(\.blocks) }

    /// Holed / attempted by distance, across every putting block.
    var puttingByDistance: [(feet: Int, made: Int, tries: Int)] {
        let putting = allBlocks.filter { $0.kind.isPutting }
        let grouped = Dictionary(grouping: putting, by: \.target)
        return grouped.keys.sorted().map { ft in
            let bs = grouped[ft]!
            return (ft, bs.reduce(0) { $0 + $1.onTarget }, bs.reduce(0) { $0 + $1.putts })
        }
    }

    var missTotals: [Miss: Int] {
        allBlocks.reduce(into: [:]) { acc, b in for (k, v) in b.misses { acc[k, default: 0] += v } }
    }
    var shapeTotals: [Shape: Int] {
        allBlocks.reduce(into: [:]) { acc, b in for (k, v) in b.shape { acc[k, default: 0] += v } }
    }
    var minutesByKind: [(DrillKind, Int)] {
        var m: [DrillKind: Int] = [:]
        for s in sessions where !s.blocks.isEmpty {
            let per = s.minutes / s.blocks.count
            for b in s.blocks { m[b.kind, default: 0] += per }
        }
        return DrillKind.allCases.compactMap { k in m[k].map { (k, $0) } }.filter { $0.1 > 0 }
    }

    static let defaultBag: [Club] = [
        Club(name: "Driver", loft: 10.5, carry: 238, total: 262), Club(name: "3W", loft: 15, carry: 218, total: 236),
        Club(name: "4H", loft: 21, carry: 198, total: 210), Club(name: "5i", loft: 24, carry: 184, total: 194),
        Club(name: "6i", loft: 27, carry: 173, total: 182), Club(name: "7i", loft: 31, carry: 162, total: 170),
        Club(name: "8i", loft: 35, carry: 150, total: 157), Club(name: "9i", loft: 39, carry: 138, total: 144),
        Club(name: "PW", loft: 44, carry: 126, total: 131), Club(name: "50°", loft: 50, carry: 108, total: 112),
        Club(name: "54°", loft: 54, carry: 92, total: 95), Club(name: "58°", loft: 58, carry: 74, total: 76),
    ]
}
