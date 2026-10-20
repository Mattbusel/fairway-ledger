"""Fairway Ledger Plus: an auto-renewable subscription group with a monthly and a yearly plan.

    python Store/subs.py create             group, localizations, both plans, prices in every territory,
                                            availability, the yearly plan's one-week free trial (idempotent)
    python Store/subs.py shot <png>         review screenshot for both plans
    python Store/subs.py status             ids and states
    python Store/subs.py offercode          the Pro owners' offer code (custom code PROPLUS, first month free)

Pro (com.mattbusel.fairwayledger.pro) is untouched: Plus is a separate group, not an upgrade path out of Pro.
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP_ID = "6813452174"
GROUP_REF = "Fairway Ledger Plus"
BASE = "com.mattbusel.fairwayledger.plus."
NOTE = ("Fairway Ledger Plus is an auto-renewable subscription (monthly or yearly; the yearly plan starts with a one-week "
        "free trial). It includes everything in the one-time Pro unlock, every colour finish while subscribed, 5 practice "
        "plans and 3 round posters added each month, the Plus insights (handicap trend and projection, strokes lost by part "
        "of the game against golfers at your target handicap) and iCloud backup of the ledger. Where: Home tab, the Plus card "
        "at the bottom (or Stats > See Plus). The paywall shows price, period, trial terms, auto-renew text, Terms of Use "
        "(Apple standard EULA) and Privacy Policy links, Restore Purchases and Manage subscription. Pro owners keep Pro "
        "exactly as before. No account or login is needed.")
PLANS = [
    # suffix, period, reference name, display name (30), description (45), USD price
    ("monthly", "ONE_MONTH", "Plus Monthly", "Plus Monthly", "Pro, all finishes, monthly plans and insights", "2.99"),
    ("yearly", "ONE_YEAR", "Plus Yearly", "Plus Yearly", "Pro, all finishes, monthly plans and insights", "14.99"),
]
# Display names and descriptions for the store pages that get translated metadata.
L10N = {
    "en-US": ("Fairway Ledger Plus", {"monthly": ("Plus Monthly", "Pro, all finishes, monthly plans and insights"),
                                      "yearly": ("Plus Yearly", "Pro, all finishes, monthly plans and insights")}),
    "en-GB": ("Fairway Ledger Plus", {"monthly": ("Plus Monthly", "Pro, all finishes, monthly plans and insights"),
                                      "yearly": ("Plus Yearly", "Pro, all finishes, monthly plans and insights")}),
    "en-AU": ("Fairway Ledger Plus", {"monthly": ("Plus Monthly", "Pro, all finishes, monthly plans and insights"),
                                      "yearly": ("Plus Yearly", "Pro, all finishes, monthly plans and insights")}),
    "en-CA": ("Fairway Ledger Plus", {"monthly": ("Plus Monthly", "Pro, all finishes, monthly plans and insights"),
                                      "yearly": ("Plus Yearly", "Pro, all finishes, monthly plans and insights")}),
    "es-MX": ("Fairway Ledger Plus", {"monthly": ("Plus mensual", "Pro, acabados, planes mensuales y análisis"),
                                      "yearly": ("Plus anual", "Pro, acabados, planes mensuales y análisis")}),
    "es-ES": ("Fairway Ledger Plus", {"monthly": ("Plus mensual", "Pro, acabados, planes mensuales y análisis"),
                                      "yearly": ("Plus anual", "Pro, acabados, planes mensuales y análisis")}),
    "de-DE": ("Fairway Ledger Plus", {"monthly": ("Plus monatlich", "Pro, alle Farben, Monatspläne und Analysen"),
                                      "yearly": ("Plus jährlich", "Pro, alle Farben, Monatspläne und Analysen")}),
    "fr-FR": ("Fairway Ledger Plus", {"monthly": ("Plus mensuel", "Pro, finitions, plans mensuels et analyses"),
                                      "yearly": ("Plus annuel", "Pro, finitions, plans mensuels et analyses")}),
    "it": ("Fairway Ledger Plus", {"monthly": ("Plus mensile", "Pro, finiture, piani mensili e analisi"),
                                   "yearly": ("Plus annuale", "Pro, finiture, piani mensili e analisi")}),
    "pt-BR": ("Fairway Ledger Plus", {"monthly": ("Plus mensal", "Pro, acabamentos, planos mensais e análises"),
                                      "yearly": ("Plus anual", "Pro, acabamentos, planos mensais e análises")}),
    "ja": ("Fairway Ledger Plus", {"monthly": ("Plus 月額", "Proの全機能、全カラー、毎月のプランと分析"),
                                   "yearly": ("Plus 年額", "Proの全機能、全カラー、毎月のプランと分析")}),
    "ko": ("Fairway Ledger Plus", {"monthly": ("Plus 월간", "Pro 전체, 모든 컬러, 월간 플랜과 분석"),
                                   "yearly": ("Plus 연간", "Pro 전체, 모든 컬러, 월간 플랜과 분석")}),
    "zh-Hans": ("Fairway Ledger Plus", {"monthly": ("Plus 月度", "Pro 全部功能、全部配色、每月计划与分析"),
                                        "yearly": ("Plus 年度", "Pro 全部功能、全部配色、每月计划与分析")}),
}


def group():
    got = asc.call("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"limit": 50})
    for g in (got or {}).get("data", []):
        if g["attributes"]["referenceName"] == GROUP_REF:
            return g
    made = asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP_REF},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    print("group created" if made else "group FAILED")
    return made["data"] if made else None


def sub(gid: str, suffix: str):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 50})
    for s in (got or {}).get("data", []):
        if s["attributes"]["productId"] == BASE + suffix:
            return s
    return None


def territories():
    return [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]


def create():
    g = group()
    if not g:
        return
    gid = g["id"]
    print("group", gid)
    glocs = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations", params={"limit": 50}) or {"data": []}
    have = {l["attributes"]["locale"] for l in glocs["data"]}
    for loc, (gname, _) in L10N.items():
        if loc not in have:
            r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                         "attributes": {"locale": loc, "name": gname, "customAppName": None},
                         "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            print("  group loc", loc, "ok" if r else "FAILED")
    terr = None
    for suffix, period, ref, name, desc, price in PLANS:
        s = sub(gid, suffix)
        if not s:
            made = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": BASE + suffix, "subscriptionPeriod": period, "familySharable": False,
                "reviewNote": NOTE, "groupLevel": 1},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not made:
                print(suffix, "create FAILED"); continue
            s = made["data"]
        sid = s["id"]
        print(f"{BASE + suffix}: {sid} {s['attributes'].get('state')}")
        locs = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations", params={"limit": 50}) or {"data": []}
        have = {l["attributes"]["locale"] for l in locs["data"]}
        for loc, (_, per) in L10N.items():
            if loc in have:
                continue
            n, d = per[suffix]
            assert len(n) <= 30 and len(d) <= 55, (loc, n, d)
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": loc, "name": n, "description": d},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print("  loc", loc, "ok" if r else "FAILED")
        # Availability first: prices are only accepted in territories the plan is sold in.
        avail = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
        if not avail or not avail.get("data"):
            terr = terr or territories()
            r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", "ok" if r else "FAILED")
        prices(sid, price)
        if suffix == "yearly":
            trial(sid)


def prices(sid: str, usd: str):
    cur = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200, "include": "territory"}) or {"data": []}
    done = {p["relationships"]["territory"]["data"]["id"] for p in cur["data"] if p.get("relationships", {}).get("territory", {}).get("data")}
    if len(done) >= 170:
        print(f"  prices: {len(done)} territories already")
        return
    pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
    base = None
    while pts:
        base = next((p for p in pts["data"] if p["attributes"]["customerPrice"] == usd), None)
        nxt = pts.get("links", {}).get("next")
        if base or not nxt:
            break
        pts = asc.call("GET", nxt)
    if not base:
        print("  no USD price point", usd); return
    eq = asc.call("GET", f"/v1/subscriptionPricePoints/{base['id']}/equalizations", params={"limit": 200, "include": "territory"})
    points = [("USA", base["id"])]
    while eq:
        for p in eq["data"]:
            points.append((p["relationships"]["territory"]["data"]["id"], p["id"]))
        nxt = eq.get("links", {}).get("next")
        eq = asc.call("GET", nxt) if nxt else None
    ok = 0
    for terr, pp in points:
        if terr in done:
            continue
        r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
                     "attributes": {"startDate": None, "preserveCurrentPrice": False},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp}},
                                       "territory": {"data": {"type": "territories", "id": terr}}}}}, quiet=True)
        ok += 1 if r else 0
    print(f"  prices: ${usd} base, {ok} new territory prices ({len(points)} points)")


def trial(sid: str):
    cur = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200}) or {"data": []}
    if len(cur["data"]) >= 170:
        print(f"  trial: {len(cur['data'])} territories already"); return
    have = set()
    full = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200, "include": "territory"}) or {"data": []}
    for o in full["data"]:
        t = o.get("relationships", {}).get("territory", {}).get("data")
        if t:
            have.add(t["id"])
    ok = 0
    avail = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability")
    terr = [t["id"] for t in asc.call("GET", f"/v1/subscriptionAvailabilities/{avail['data']['id']}/availableTerritories", params={"limit": 200})["data"]]
    for t in terr:
        if t in have:
            continue
        r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                     "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "territory": {"data": {"type": "territories", "id": t}}}}}, quiet=ok > 0)
        ok += 1 if r else 0
    print(f"  trial: one week free, {ok} new territories")


def shot(png: str):
    data = Path(png).read_bytes()
    g = group()
    for suffix, *_ in PLANS:
        s = sub(g["id"], suffix)
        if not s:
            continue
        sid = s["id"]
        cur = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/subscriptionAppStoreReviewScreenshots", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                        "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
        if not made:
            print(suffix, "reserve FAILED"); continue
        rid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{rid}", {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": rid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, "review screenshot", "uploaded" if r else "FAILED")


def status():
    g = group()
    print("group", g["id"], g["attributes"])
    for suffix, *_ in PLANS:
        s = sub(g["id"], suffix)
        print(BASE + suffix, (s["id"] + " " + s["attributes"]["state"]) if s else "missing")


def offercode():
    """A custom offer code for Pro owners: their first month of Plus monthly free. Shown in the app only to Pro owners."""
    g = group()
    s = sub(g["id"], "monthly")
    sid = s["id"]
    got = asc.call("GET", f"/v1/subscriptions/{sid}/offerCodes", params={"limit": 50}) or {"data": []}
    oc = next((o for o in got["data"] if o["attributes"]["name"] == "Pro owners"), None)
    if not oc:
        avail = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability")
        terr = [t["id"] for t in asc.call("GET", f"/v1/subscriptionAvailabilities/{avail['data']['id']}/availableTerritories", params={"limit": 200})["data"]]
        prices = [{"type": "subscriptionOfferCodePrices", "id": f"${{p{i}}}"} for i in range(len(terr))]
        inc = [{"type": "subscriptionOfferCodePrices", "id": f"${{p{i}}}", "relationships": {"territory": {"data": {"type": "territories", "id": t}}}}
               for i, t in enumerate(terr)]
        made = asc.call("POST", "/v1/subscriptionOfferCodes", {"data": {"type": "subscriptionOfferCodes", "attributes": {
            "name": "Pro owners", "customerEligibilities": ["NEW", "EXPIRED"], "offerEligibility": "STACK_WITH_INTRO_OFFERS",
            "duration": "ONE_MONTH", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}, "prices": {"data": prices}}},
            "included": inc})
        if not made:
            print("offer code FAILED"); return
        oc = made["data"]
    print("offer code", oc["id"], oc["attributes"])
    codes = asc.call("GET", f"/v1/subscriptionOfferCodes/{oc['id']}/customCodes", params={"limit": 50}) or {"data": []}
    if not any(c["attributes"]["customCode"] == "PROPLUS" for c in codes["data"]):
        r = asc.call("POST", "/v1/subscriptionOfferCodeCustomCodes", {"data": {"type": "subscriptionOfferCodeCustomCodes", "attributes": {
            "customCode": "PROPLUS", "numberOfCodes": 25000, "expirationDate": "2027-10-19"},
            "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": oc["id"]}}}}})
        print("custom code PROPLUS", "created" if r else "FAILED")
    else:
        print("custom code PROPLUS exists")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2])
    else:
        {"create": create, "status": status, "offercode": offercode}.get(cmd, lambda: sys.exit(__doc__))()
