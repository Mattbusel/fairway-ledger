# Fairway Ledger

A golf practice journal and stat book for iPhone, finished in black and gold.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Swift%205-orange) ![Built on GitHub Actions](https://img.shields.io/badge/built%20on-GitHub%20Actions%20macOS-2088FF)

**[Download Fairway Ledger on the App Store](https://apps.apple.com/app/id6813452174)**

<p align="center">
  <img src="fastlane/screenshots/en-US/01_iPhone.png" width="250" alt="Fairway Ledger screenshot">
  <img src="fastlane/screenshots/en-US/02_iPhone.png" width="250" alt="Fairway Ledger screenshot">
  <img src="fastlane/screenshots/en-US/03_iPhone.png" width="250" alt="Fairway Ledger screenshot">
</p>

Log range sessions ball by ball, write down what clicked, keep scorecards hole by hole, and let the numbers show where to practise next. Fairway Ledger is the sibling of Baseline Ledger and shares its design kit.

## Features

- At the range: full swing, wedges, chipping, pitching, bunker, putting; tap each shot for strike, shape and miss; undo any tap
- Carry distances per club, and putting makes and misses by distance against the tour make rate
- Journal: rate the session, swing thought, what clicked, what to work on; search and filter
- Rounds: hole-by-hole scorecard with putts, tee shot, penalties; GIR, scrambling, sand saves and three-putts worked out
- A Handicap Index estimate from your best rounds (World Handicap System style)
- Stats (Swift Charts) and a yardage book with a gapping chart that flags gaps and overlaps

## Price

A paid app: one price, no in-app purchases, no subscription, no ads.

## Privacy

No network code at all: Fairway Ledger makes no requests and collects no data. Everything is saved on the device in `ledger.json`. The privacy manifest (`Resources/PrivacyInfo.xcprivacy`) declares no tracking and no collected data types.

## Built without a Mac

This app was written on a Windows PC. No Mac is involved at any point: every build, signature, screenshot and App Store submission runs on GitHub Actions macOS runners, driven by the App Store Connect API.

- **`project.yml`** is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated on the runner and never committed, so the repo can be edited on any OS and there are no `.pbxproj` merge conflicts.
- **`.github/workflows/build.yml`** runs on every push: picks the newest Xcode 26 and iPhone simulator on the runner, builds, then launches the app once per screen with `-shot <screen>` (sample data, fixed 9:41 status bar) and captures the store screenshots with `simctl`, uploaded as a workflow artifact.
- **`.github/workflows/appstore.yml`** (manual) has three modes: `compile`, `dry_run` (build, sign, upload, do not submit) and `release` (also submits for review). The distribution certificate is imported from a secret into a throwaway keychain; [fastlane](https://fastlane.tools) (`fastlane/Fastfile`) fetches the App Store profile with the API key, sets the build number one above the latest on TestFlight, archives, and uploads the binary with `fastlane/metadata` and the committed `fastlane/screenshots`.
- **`.github/workflows/review-video.yml`** records the App Review screen recording: the app is launched with `-demoAutoplay` and drives its own real screens.
- **`Store/*.py`** talk to the App Store Connect API directly from Windows (Python, `requests` + `PyJWT`): `asc.py` registers the bundle id and pushes metadata, `listing.py` sets the age rating, review details, price and screenshots, and `signing.py` creates the distribution certificate locally so its private key is never stranded on a disposable runner.

Only one step is manual: Apple's API will not create the app record itself, so that is made once in the App Store Connect web UI.

## Build and run

With a Mac and Xcode 26 (the version CI uses; the app targets iOS 17+):

```bash
brew install xcodegen
xcodegen generate
open FairwayLedger.xcodeproj
```

Run the `FairwayLedger` scheme on any iPhone simulator. No signing is needed for the simulator; from the command line:

```bash
xcodebuild build -project FairwayLedger.xcodeproj -scheme FairwayLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

To see it filled with sample data, launch with a screenshot argument, e.g. `xcrun simctl launch booted com.mattbusel.fairwayledger -shot home`.

Without a Mac: fork the repo and push. The Build workflow compiles it on a GitHub macOS runner and attaches the screenshots as an artifact.

Shipping your own build needs these repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (base64 of the `.p8`), `DEVELOPMENT_TEAM`, `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, plus your own bundle id in `project.yml` and `fastlane/Fastfile`.

## Code map

All app code is in `Sources/` (SwiftUI, Observation, no third-party dependencies).

| File | What it does |
| --- | --- |
| `App.swift` | entry point, floating tab bar, `-shot` handling |
| `Model.swift` | sessions, shots, rounds, clubs, handicap and stats maths, JSON persistence |
| `LiveSessionView.swift` | the one-handed range screen |
| `SessionViews.swift` | post-session reflection |
| `RoundViews.swift` | scorecards |
| `StatsView.swift` | charts and pattern read-outs |
| `BagView.swift` | yardage book and gapping |
| `HomeView.swift` / `JournalView.swift` | home and the searchable journal |
| `Kit/` | shared components and the black-and-gold theme |
| `Demo.swift` / `Autopilot.swift` | screenshot data and the App Review recording |

`Store/` holds the App Store Connect scripts, `fastlane/` the lanes, listing text and screenshots, `Resources/` the asset catalog and privacy manifest.

---

**More apps built the same way:** [Chain](https://github.com/Mattbusel/chain), [Ironbook](https://github.com/Mattbusel/ironbook), [Quiver](https://github.com/Mattbusel/quiver), [Race Fuel](https://github.com/Mattbusel/race-fuel), [Minder](https://github.com/Mattbusel/minder), [Baseline Ledger](https://github.com/Mattbusel/baseline-ledger), [Odometer](https://github.com/Mattbusel/odometer), [Rooms](https://github.com/Mattbusel/rooms), [Clockout](https://github.com/Mattbusel/clockout), [Curve](https://github.com/Mattbusel/curve), [Pricebook](https://github.com/Mattbusel/pricebook), [Chores](https://github.com/Mattbusel/chores), [Pawprint](https://github.com/Mattbusel/pawprint), [Pocket Beings](https://github.com/Mattbusel/pocket-beings), [Glyphstorm](https://github.com/Mattbusel/glyphstorm), [Clear the Strait](https://github.com/Mattbusel/clear-the-strait).
