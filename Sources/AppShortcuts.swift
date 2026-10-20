import AppIntents

/// Siri phrases and Spotlight shortcuts. The intents live in Shared so the widgets and controls can use them too.
struct FairwayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartPracticeIntent(),
                    phrases: ["Start practice in \(.applicationName)", "Start a \(.applicationName) range session"],
                    shortTitle: "Start Practice", systemImageName: "figure.golf")
        AppShortcut(intent: LogRoundIntent(),
                    phrases: ["Log a round in \(.applicationName)", "New scorecard in \(.applicationName)"],
                    shortTitle: "Log a Round", systemImageName: "flag.fill")
        AppShortcut(intent: HandicapIntent(),
                    phrases: ["What's my handicap in \(.applicationName)", "\(.applicationName) handicap"],
                    shortTitle: "Handicap Index", systemImageName: "gauge.with.dots.needle.50percent")
        AppShortcut(intent: QuickLogIntent(),
                    phrases: ["Log practice in \(.applicationName)", "Log range time in \(.applicationName)"],
                    shortTitle: "Log Practice", systemImageName: "timer")
        AppShortcut(intent: ChallengeIntent(),
                    phrases: ["Show my \(.applicationName) challenge"],
                    shortTitle: "Monthly Challenge", systemImageName: "medal")
    }
}
