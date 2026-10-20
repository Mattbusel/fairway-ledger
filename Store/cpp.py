"""Custom product pages: three audiences, each with its own screenshots (Store/cpp/<key>/) and promotional text.

    python Store/cpp.py create          make (or reuse) each page, its en-US localization and screenshots
    python Store/cpp.py keywords        try to attach search keywords to each page's localization
    python Store/cpp.py status
    python Store/cpp.py submit <draft review submission id>   add each page version to a draft review submission
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

ROOT = Path(__file__).resolve().parent / "cpp"
PAGES = {
    "practice": ("Practice journal", "Practise with a purpose: every range ball logged, a weekly plan from your own numbers, and a new challenge every month.",
                 ["practice", "drills", "range", "putting", "swing"]),
    "handicap": ("Handicap tracker", "Watch your handicap drop: an index estimate from your own cards, its pace, and the strokes each part of your game costs.",
                 ["handicap", "index", "score", "tracker", "round"]),
    "stats": ("Golf stats", "Golf stats that tell you why: fairways, greens, putts and scrambling, every course hole by hole, and strokes against your target.",
              ["stats", "gir", "strokes", "putting", "course"]),
}
DISPLAY = "APP_IPHONE_67"


def app_id():
    return asc.find_app()["id"]


def pages(aid):
    got = asc.call("GET", f"/v1/apps/{aid}/appCustomProductPages", params={"limit": 50})
    return {p["attributes"]["name"]: p for p in (got or {}).get("data", [])}


def version_and_loc(pid):
    vs = asc.call("GET", f"/v1/appCustomProductPages/{pid}/appCustomProductPageVersions", params={"limit": 10})["data"]
    v = vs[0] if vs else None
    loc = None
    if v:
        ls = asc.call("GET", f"/v1/appCustomProductPageVersions/{v['id']}/appCustomProductPageLocalizations", params={"limit": 50})["data"]
        loc = next((l for l in ls if l["attributes"]["locale"] == "en-US"), None)
    return v, loc


def upload_set(loc_id, files):
    sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc_id}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    local = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
    if sset:
        remote = [s["attributes"].get("sourceFileChecksum") for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]]
        if remote == local:
            print("   screenshots MATCH")
            return
        for s in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]:
            asc.call("DELETE", f"/v1/appScreenshots/{s['id']}")
    else:
        sset = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                        "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc_id}}}}})["data"]
    for f in files:
        data = f.read_bytes()
        made = asc.call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in made["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        asc.call("PATCH", f"/v1/appScreenshots/{made['id']}", {"data": {"type": "appScreenshots", "id": made["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"   uploaded {len(files)} screenshots")


def create():
    aid = app_id()
    have = pages(aid)
    for key, (name, promo, _) in PAGES.items():
        assert len(promo) <= 170, (key, len(promo))
        p = have.get(name)
        if not p:
            made = asc.call("POST", "/v1/appCustomProductPages", {
                "data": {"type": "appCustomProductPages", "attributes": {"name": name},
                         "relationships": {"app": {"data": {"type": "apps", "id": aid}},
                                           "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
                "included": [
                    {"type": "appCustomProductPageVersions", "id": "${v1}",
                     "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
                    {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": promo}},
                ]})
            if not made:
                print(key, "create FAILED")
                continue
            p = made["data"]
            print(key, "created", p["id"])
        else:
            print(key, "exists", p["id"])
        v, loc = version_and_loc(p["id"])
        if loc and loc["attributes"].get("promotionalText") != promo:
            asc.call("PATCH", f"/v1/appCustomProductPageLocalizations/{loc['id']}", {"data": {"type": "appCustomProductPageLocalizations",
                     "id": loc["id"], "attributes": {"promotionalText": promo}}})
        files = sorted((ROOT / key).glob("*.png"))
        if loc and files:
            upload_set(loc["id"], files)
        print("  version", v and v["id"], v and v["attributes"], "url", p["attributes"].get("url"))


def keywords():
    aid = app_id()
    have = pages(aid)
    for key, (name, _, words) in PAGES.items():
        p = have.get(name)
        if not p:
            continue
        v, loc = version_and_loc(p["id"])
        r = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc['id']}/searchKeywords", params={"limit": 50})
        print(key, "current keywords:", json.dumps(r)[:300] if r else None)
        made = asc.call("POST", f"/v1/appCustomProductPageLocalizations/{loc['id']}/relationships/searchKeywords",
                        {"data": [{"type": "appKeywords", "id": w} for w in words]})
        print(key, "keywords", "set" if made is not None else "FAILED", words)


def status():
    aid = app_id()
    for name, p in pages(aid).items():
        v, loc = version_and_loc(p["id"])
        print(name, p["id"], p["attributes"], v and v["attributes"])


def submit(draft):
    aid = app_id()
    for name, p in pages(aid).items():
        v, _ = version_and_loc(p["id"])
        r = asc.call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": draft}},
            "appCustomProductPageVersion": {"data": {"type": "appCustomProductPageVersions", "id": v["id"]}}}}})
        print(name, "added to draft" if r else "add FAILED")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "submit":
        submit(sys.argv[2])
    else:
        {"create": create, "keywords": keywords, "status": status}[cmd]()
