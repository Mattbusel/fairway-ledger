# App Review notes

---

No account, login or network connection is required.

THIS SUBMISSION (1.2, new build): fixes Guideline 2.3.7. Every screenshot is new and none mentions price, free, or subscriptions; prices appear only in the description.

NEW IN THIS BUILD:
- Fairway Ledger Plus, an auto-renewable subscription group with two plans: Plus Monthly (com.mattbusel.fairwayledger.plus.monthly) and Plus Yearly (com.mattbusel.fairwayledger.plus.yearly, one-week free trial for new subscribers).
- Monthly challenges (free), a medal cabinet, a Practice widget with buttons that log minutes (App Intents), Lock Screen and StandBy handicap widget, Control Center controls (iOS 18), Siri / Shortcuts phrases, a Sapphire finish (99-cent non-consumable).

WHERE TO FIND PLUS: Home tab, the "Fairway Ledger Plus" card near the bottom; or Stats tab > "Plus insights" > See Plus; or any locked Pro feature. The purchase page shows both plans and Pro with price, period, the free trial terms, the auto-renewal terms, links to the Terms of Use (Apple standard EULA) and the Privacy Policy, Restore, Redeem code and (when subscribed) Manage subscription.

WHAT PLUS INCLUDES: everything in the one-time Pro unlock; Plus insights (Stats > Plus insights: handicap trend with a 90-day pace line, and an estimate of strokes lost by part of the game against typical golfers at a target handicap); every colour finish while subscribed; 5 practice plans and 3 round posters added at the start of each month; iCloud key-value backup and restore of the ledger (Home > Plus card when subscribed). Pro (com.mattbusel.fairwayledger.pro, existing, non-consumable) is unchanged and stays with its owners whatever happens to Plus.

HOW TO USE: Home has "Start practice" (live range screen: tap Pure / Solid / Poor, shape and misses per ball, then "Finish & journal") and "Log round" (hole-by-hole scorecard; the course name opens details, where a saved course or 18 / Front 9 / Back 9 can be picked; swipe between holes; Save). The monthly challenge card on Home opens the challenge page. A new install starts empty; log one session and one round to see things fill in.

OTHER IN-APP PURCHASES (StoreKit 2, all optional, Restore in the Extras sheet and on the purchase page):
- Practice Plans, consumable (3 credits): Home, "This week's plan" card. One plan a week is included; after that the card offers 3 more plans.
- Round Posters, consumable (3 credits): Rounds tab, hold a round > Round poster. The first poster is included.
- Rose Gold, Platinum, Emerald, Copper and Sapphire finishes, non-consumable: Home, "Extras" card at the bottom. A bought finish recolours the app and widgets and switches to its alternate app icon.

WIDGETS AND INTENTS: the Practice widget's +15 / +30 buttons run an App Intent that stores the minutes in the app group; the app files them as practice sessions the next time it opens. Controls and Siri phrases open the app on the practice screen, a scorecard or the challenge. Deep links: fairwayledger://challenge (used by the In-App Events), practice, round, stats, insights.

PRIVACY: no data is collected. Everything stays in the app's files on the device; widgets read a small summary from the app group on the same device; the Plus backup is written only to the user's own iCloud key-value store.

PURPOSE AND AUDIENCE: a private golf practice journal, scorecard and stat book for amateur golfers who want to improve deliberately. Rated 4+.

EXTERNAL SERVICES: none. No network requests of our own, analytics, advertising or third-party frameworks. Built with SwiftUI, Swift Charts, WidgetKit, ActivityKit, App Intents, TipKit and StoreKit 2.

REGULATED / PROTECTED MATERIAL: not applicable. The handicap figure is the app's own estimate calculated on the device; it is not an official handicap and the app is not affiliated with any golf association. The benchmark numbers in Plus insights are labelled as estimates. All art, text and code are my own work.
