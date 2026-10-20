import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct FairwayWidgets: WidgetBundle {
    var body: some Widget {
        HandicapWidget()
        PracticeWidget()
        LedgerWidget()
        RoundLiveActivity()
        if #available(iOS 18.0, *) {
            PracticeControl()
            RoundControl()
            QuickLogControl()
        }
    }
}

struct GlanceEntry: TimelineEntry {
    let date: Date
    let g: Glance
}

struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry { GlanceEntry(date: .now, g: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        Finish.reload()
        let g = Glance.load()
        completion(GlanceEntry(date: .now, g: context.isPreview && g.lastScore == nil ? .sample : g))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        Finish.reload()
        // The practice bar is "this week", so look again at midnight.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [GlanceEntry(date: .now, g: Glance.load())], policy: .after(midnight)))
    }
}

/// Free: the handicap index on the Home Screen, the Lock Screen and in StandBy.
struct HandicapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "handicap", provider: GlanceProvider()) { e in
            HandicapFamilyView(g: e.g).containerBackground(for: .widget) { LacquerBackground() }
                .widgetURL(URL(string: "fairwayledger://stats"))
        }
        .configurationDisplayName("Handicap")
        .description("Your handicap index, last round and this week's practice.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct HandicapFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let g: Glance
    private var index: String { g.handicap.map { String(format: "%.1f", $0) } ?? "–" }
    private var week: Double { min(1, Double(g.weekMinutes) / Double(max(1, g.weeklyTarget))) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: week) {
                Image(systemName: "figure.golf")
            } currentValueLabel: {
                Text(index).font(.system(size: 15, weight: .semibold, design: .serif))
            }
            .gaugeStyle(.accessoryCircular)
            .accessibilityLabel("Handicap index \(index), \(g.weekMinutes) practice minutes this week")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("HANDICAP").font(.system(size: 10, weight: .semibold)).tracking(1)
                    Text(index).font(.system(size: 26, weight: .semibold, design: .serif)).widgetAccentable()
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let s = g.lastScore { Text("Last \(s) \(g.lastToPar)").font(.system(size: 12, weight: .semibold)) }
                    Text("\(g.weekMinutes) min this week").font(.system(size: 12))
                    ProgressView(value: week).tint(.white)
                }
            }
        case .accessoryInline:
            Text("Index \(index) · \(g.weekMinutes) min practice")
        default:
            HandicapGlanceView(g: g)
        }
    }
}

/// Free and interactive: this week's practice ring, with buttons that log minutes without opening the app.
struct PracticeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "practice", provider: GlanceProvider()) { e in
            PracticeWidgetView(g: e.g).containerBackground(for: .widget) { LacquerBackground() }
        }
        .configurationDisplayName("Practice")
        .description("This week's practice, and buttons to log range time without opening the app.")
        .supportedFamilies([.systemSmall])
    }
}

struct PracticeWidgetView: View {
    let g: Glance
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().stroke(Gold.leaf.opacity(0.15), lineWidth: 5)
                    Circle().trim(from: 0, to: max(0.001, min(1, Double(g.weekMinutes) / Double(max(1, g.weeklyTarget)))))
                        .stroke(Gold.foil, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(g.weekMinutes)").font(.figure(15)).foil().minimumScaleFactor(0.6)
                }
                .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 1) {
                    Text("PRACTICE").font(.body(9, .semibold)).tracking(1.4).foregroundStyle(Gold.muted)
                    Text("of \(g.weeklyTarget) min").font(.body(11)).foregroundStyle(Gold.ivory)
                    Text("this week").font(.body(10)).foregroundStyle(Gold.muted)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach([15, 30], id: \.self) { m in
                    Button(intent: QuickLogIntent(minutes: m)) {
                        Text("+\(m)").font(.body(13, .bold)).foregroundStyle(Gold.ink)
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .background(Capsule().fill(Gold.foil))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(m) minutes of practice")
                }
            }
        }
    }
}

/// Pro: the last ten rounds.
struct LedgerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ledger", provider: GlanceProvider()) { e in
            Group { if e.g.unlocked { LedgerGlanceView(g: e.g) } else { LockedGlanceView() } }
                .containerBackground(for: .widget) { LacquerBackground() }
        }
        .configurationDisplayName("Ledger")
        .description("Your last ten scores, putts, fairways and greens.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: Control Center (iOS 18)

@available(iOS 18.0, *)
struct PracticeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.fairwayledger.control.practice") {
            ControlWidgetButton(action: StartPracticeIntent()) {
                Label("Start Practice", systemImage: "figure.golf")
            }
        }
        .displayName("Start Practice")
        .description("Opens a live range session in Fairway Ledger.")
    }
}

@available(iOS 18.0, *)
struct RoundControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.fairwayledger.control.round") {
            ControlWidgetButton(action: LogRoundIntent()) {
                Label("Log a Round", systemImage: "flag.fill")
            }
        }
        .displayName("Log a Round")
        .description("Opens a new scorecard, or the one in progress.")
    }
}

@available(iOS 18.0, *)
struct QuickLogControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.fairwayledger.control.quicklog") {
            ControlWidgetButton(action: QuickLogIntent(minutes: 15)) {
                Label("Log 15 min Practice", systemImage: "timer")
            }
        }
        .displayName("Log 15 min Practice")
        .description("Adds 15 practice minutes to this week without opening the app.")
    }
}

/// The round in progress, on the Lock Screen and in the Dynamic Island.
struct RoundLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundActivity.self) { ctx in
            RoundLiveView(course: ctx.attributes.course, s: ctx.state)
                .activityBackgroundTint(Gold.ink)
                .activitySystemActionForegroundColor(Gold.leaf)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Hole \(ctx.state.hole)").font(.display(18, .medium)).foregroundStyle(Gold.ivory)
                        Text("Par \(ctx.state.par)").font(.body(12)).foregroundStyle(Gold.muted)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ctx.state.toPar).font(.figure(28, .light)).foregroundStyle(Gold.leaf)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(ctx.attributes.course.isEmpty ? "Round" : ctx.attributes.course) · thru \(ctx.state.thru) · \(ctx.state.score) strokes")
                        .font(.body(12)).foregroundStyle(Gold.muted).lineLimit(1)
                }
            } compactLeading: {
                Text("H\(ctx.state.hole)").font(.body(13, .semibold)).foregroundStyle(Gold.ivory)
            } compactTrailing: {
                Text(ctx.state.toPar).font(.figure(14)).foregroundStyle(Gold.leaf)
            } minimal: {
                Text(ctx.state.toPar).font(.figure(12)).foregroundStyle(Gold.leaf)
            }
        }
    }
}
