import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FairwayWidgets: WidgetBundle {
    var body: some Widget {
        HandicapWidget()
        LedgerWidget()
        RoundLiveActivity()
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

/// Free: the handicap index on the Home Screen.
struct HandicapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "handicap", provider: GlanceProvider()) { e in
            HandicapGlanceView(g: e.g).containerBackground(for: .widget) { LacquerBackground() }
        }
        .configurationDisplayName("Handicap")
        .description("Your handicap index, last round and this week's practice.")
        .supportedFamilies([.systemSmall])
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
