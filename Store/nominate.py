"""Featuring nomination for this update (App Store Connect > Nominations), through the API.

    python Store/nominate.py [--submit]      create (or update) the draft; --submit sends it to Apple
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP_ID = "6813452174"
NAME = "Fairway Ledger: monthly challenges and Plus insights"
DESC = ("Fairway Ledger is a private golf practice journal, scorecard and stat book, finished in black and gold, built by one developer. "
        "This update adds a monthly challenge (tracked automatically from the golfer's own cards, with a medal cabinet), an interactive "
        "Practice widget that logs range time with App Intents, the handicap index on the Lock Screen and in StandBy, Control Center "
        "controls, Siri phrases, TipKit onboarding, and Fairway Ledger Plus: the handicap's pace and an estimate of the strokes each part "
        "of the game costs against a target handicap, iCloud backup and every colour finish. No account, no ads, no tracking; all data "
        "stays on the device. Localized into Japanese, Korean, Simplified Chinese, Spanish, German, French, Italian and Portuguese.")


def main(submit: bool):
    events = asc.call("GET", f"/v1/apps/{APP_ID}/appEvents", params={"limit": 20})["data"]
    found = None
    for st in ("DRAFT", "SUBMITTED"):
        got = asc.call("GET", "/v1/nominations", params={"limit": 50, "filter[state]": st}) or {"data": []}
        found = found or next((n for n in got["data"] if n["attributes"].get("name") == NAME), None)
    attrs = {"name": NAME, "type": "APP_ENHANCEMENTS", "description": DESC[:1000], "submitted": submit,
             "publishStartDate": "2026-11-03T16:00:00Z", "hasInAppEvents": bool(events),
             "deviceFamilies": ["IPHONE"], "launchInSelectMarketsFirst": False, "preOrderEnabled": False,
             "locales": ["en-US", "en-GB", "ja", "ko", "zh-Hans", "es-MX", "es-ES", "de-DE", "fr-FR", "it", "pt-BR"],
             "notes": "Free download with optional one-time Pro, 99-cent extras and the Plus subscription. In-App Events: November challenge and the fall update."}
    rels = {"relatedApps": {"data": [{"type": "apps", "id": APP_ID}]}}
    # Draft events are refused here; the events are named in the notes instead.
    if found:
        r = asc.call("PATCH", f"/v1/nominations/{found['id']}", {"data": {"type": "nominations", "id": found["id"], "attributes": attrs,
                     "relationships": rels}})
    else:
        r = asc.call("POST", "/v1/nominations", {"data": {"type": "nominations", "attributes": attrs, "relationships": rels}})
    print(json.dumps(r)[:800] if r else "FAILED")


if __name__ == "__main__":
    main("--submit" in sys.argv)
