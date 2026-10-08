import SwiftUI

/// Black lacquer and gold leaf (or whichever finish is chosen). Every colour and type choice in the app comes from here.
enum Gold {
    static let ink = Color(red: 0.043, green: 0.039, blue: 0.031)        // #0B0A08
    static let lacquer = Color(red: 0.078, green: 0.070, blue: 0.055)    // cards
    static let lacquerHi = Color(red: 0.115, green: 0.102, blue: 0.078)
    static let ivory = Color(red: 0.953, green: 0.922, blue: 0.847)
    static let muted = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.52)
    static let faint = Color(red: 0.953, green: 0.922, blue: 0.847).opacity(0.28)
    static var leaf: Color { Finish.current.leaf }
    static var pale: Color { Finish.current.pale }
    static var deep: Color { Finish.current.deep }
    static var bronze: Color { Finish.current.bronze }
    static let good = Color(red: 0.62, green: 0.80, blue: 0.52)
    static let bad = Color(red: 0.90, green: 0.46, blue: 0.38)

    /// Brushed foil: several light bands, so it reads as metal rather than a flat colour.
    static var foil: LinearGradient {
        let f = Finish.current
        return LinearGradient(stops: [
            .init(color: f.band[0], location: 0),
            .init(color: f.band[1], location: 0.28),
            .init(color: f.band[2], location: 0.5),
            .init(color: f.band[3], location: 0.72),
            .init(color: f.band[4], location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var hairline: LinearGradient {
        LinearGradient(colors: [pale.opacity(0.55), leaf.opacity(0.12), pale.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var chartScale: [Color] { [leaf, pale, deep, leaf.opacity(0.7), bronze, Color(red: 0.75, green: 0.72, blue: 0.62)] }
}

/// The metal the ledger is leafed in. Gold is free; the others are 99-cent finishes, each with
/// a matching app icon.
struct Finish: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let leaf: Color, pale: Color, deep: Color, bronze: Color
    /// Five light bands for the foil, dark to bright and back.
    let band: [Color]
    var icon: String? { id == "gold" ? nil : "AppIcon-" + name.replacingOccurrences(of: " ", with: "") }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let all: [Finish] = [
        Finish(id: "gold", name: "Gold Leaf", blurb: "The original. Free.", leaf: rgb(0xD4AF37), pale: rgb(0xF7E7B0), deep: rgb(0x9C7A22), bronze: rgb(0x6B4F1A),
               band: [rgb(0x9E7824), rgb(0xF7E6A3), rgb(0xCCA338), rgb(0xFFF0BD), rgb(0xA88029)]),
        Finish(id: "rose", name: "Rose Gold", blurb: "Warm pink metal, clubhouse bar light.", leaf: rgb(0xDE9C86), pale: rgb(0xF8D8CC), deep: rgb(0xA8604E), bronze: rgb(0x6B3A2E),
               band: [rgb(0xA05C4A), rgb(0xF9DCD0), rgb(0xD98F78), rgb(0xFFE9E0), rgb(0xA8604E)]),
        Finish(id: "platinum", name: "Platinum", blurb: "Cool and quiet, like a member's card.", leaf: rgb(0xC9CDD4), pale: rgb(0xF2F3F6), deep: rgb(0x8C929C), bronze: rgb(0x4E535B),
               band: [rgb(0x7F858F), rgb(0xF4F5F8), rgb(0xBFC4CC), rgb(0xFFFFFF), rgb(0x8A909A)]),
        Finish(id: "emerald", name: "Emerald", blurb: "Augusta green, polished.", leaf: rgb(0x4CC38A), pale: rgb(0xBDF2D6), deep: rgb(0x1F7A50), bronze: rgb(0x0F4229),
               band: [rgb(0x1B6E47), rgb(0xBDF2D6), rgb(0x42B47E), rgb(0xDDFBEA), rgb(0x1F7A50)]),
        Finish(id: "copper", name: "Copper", blurb: "Old pennies and a well-worn putter face.", leaf: rgb(0xD27D3E), pale: rgb(0xF6C9A2), deep: rgb(0x9A4E1E), bronze: rgb(0x5C2C10),
               band: [rgb(0x8E4518), rgb(0xF6C9A2), rgb(0xCB7436), rgb(0xFFDDBF), rgb(0x9A4E1E)]),
    ]
    /// Read once and kept: the foil is asked for on every frame.
    static var current: Finish = byID(Shared.finish)
    static func byID(_ id: String) -> Finish { all.first { $0.id == id } ?? all[0] }
    static func reload() { current = byID(Shared.finish) }
    static func apply(_ id: String) { Shared.finish = id; current = byID(id) }
}

/// What the app and its widgets share, through the app group.
enum Shared {
    static let group = "group.com.mattbusel.fairwayledger"
    static let defaults = UserDefaults(suiteName: group) ?? .standard
    static var finish: String {
        get { defaults.string(forKey: "finish") ?? "gold" }
        set { defaults.set(newValue, forKey: "finish") }
    }
}

extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .serif) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .default) }
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .serif).monospacedDigit() }
}

/// The page background: lacquer with a faint warm bloom from the top, and grain.
struct LacquerBackground: View {
    var body: some View {
        ZStack {
            Gold.ink
            RadialGradient(colors: [Gold.leaf.opacity(0.16), .clear], center: .init(x: 0.5, y: -0.05), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Gold.deep.opacity(0.10), .clear], center: .init(x: 1.1, y: 0.9), startRadius: 10, endRadius: 420)
            Canvas { ctx, size in
                // Deterministic grain so it never crawls between frames.
                var seed: UInt64 = 0x9E3779B97F4A7C15
                for _ in 0..<900 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 33 % 10000) / 10000 * size.width
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed >> 33 % 10000) / 10000 * size.height
                    ctx.fill(Path(CGRect(x: x.truncatingRemainder(dividingBy: size.width), y: y.truncatingRemainder(dividingBy: size.height), width: 1, height: 1)),
                             with: .color(Gold.pale.opacity(0.05)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func foil() -> some View { foregroundStyle(Gold.foil) }

    /// A lacquered card with a gold hairline.
    func card(padding: CGFloat = 18, radius: CGFloat = 24) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Gold.lacquerHi, Gold.lacquer], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Gold.hairline, lineWidth: 0.8))
    }
}
