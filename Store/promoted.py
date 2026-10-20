"""Promoted in-app purchases on the product page: Plus Yearly, Plus Monthly, Pro, Sapphire and Rose Gold finishes, Practice Plans.

    python Store/promoted.py            upload each 1024x1024 promo image (Store/promo/<key>.png), create the promotions, set the order
    python Store/promoted.py status
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP_ID = "6813452174"
PROMO = Path(__file__).resolve().parent / "promo"
# key, kind, product id, image
ORDER = [
    ("plus-yearly", "sub", "com.mattbusel.fairwayledger.plus.yearly"),
    ("plus-monthly", "sub", "com.mattbusel.fairwayledger.plus.monthly"),
    ("pro", "iap", "com.mattbusel.fairwayledger.pro"),
    ("sapphire", "iap", "com.mattbusel.fairwayledger.finish.sapphire"),
    ("rose", "iap", "com.mattbusel.fairwayledger.finish.rose"),
    ("plans", "iap", "com.mattbusel.fairwayledger.plans"),
]


def find(kind, pid):
    if kind == "iap":
        got = asc.call("GET", f"/v1/apps/{APP_ID}/inAppPurchasesV2", params={"filter[productId]": pid, "limit": 10})
        return next((d for d in (got or {}).get("data", []) if d["attributes"]["productId"] == pid), None)
    for g in asc.call("GET", f"/v1/apps/{APP_ID}/subscriptionGroups", params={"limit": 20})["data"]:
        for s in asc.call("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", params={"limit": 20})["data"]:
            if s["attributes"]["productId"] == pid:
                return s
    return None


def image(kind, item_id, f: Path):
    res, rel, typ = ("inAppPurchaseImages", "inAppPurchase", "inAppPurchases") if kind == "iap" else ("subscriptionImages", "subscription", "subscriptions")
    path = f"/v2/inAppPurchases/{item_id}/images" if kind == "iap" else f"/v1/subscriptions/{item_id}/images"
    cur = asc.call("GET", path, quiet=True)
    if cur and cur.get("data"):
        print("   image exists", cur["data"][0]["attributes"].get("state"))
        return
    data = f.read_bytes()
    made = asc.call("POST", f"/v1/{res}", {"data": {"type": res, "attributes": {"fileName": f.name, "fileSize": len(data)},
                    "relationships": {rel: {"data": {"type": typ, "id": item_id}}}}})
    if not made:
        print("   image reserve FAILED")
        return
    m = made["data"]
    for op in m["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    r = asc.call("PATCH", f"/v1/{res}/{m['id']}", {"data": {"type": res, "id": m["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("   image", "uploaded" if r else "commit FAILED")


def main():
    existing = asc.call("GET", f"/v1/apps/{APP_ID}/promotedPurchases", params={"limit": 50, "include": "inAppPurchaseV2,subscription"}) or {"data": []}
    have = {}
    for p in existing["data"]:
        rel = p.get("relationships", {})
        for k in ("inAppPurchaseV2", "subscription"):
            d = rel.get(k, {}).get("data")
            if d:
                have[d["id"]] = p["id"]
    ids = []
    for key, kind, pid in ORDER:
        it = find(kind, pid)
        if not it:
            print(pid, "missing")
            continue
        print(pid, it["id"], it["attributes"].get("state"))
        image(kind, it["id"], PROMO / f"{key}.png")
        if it["id"] in have:
            ids.append(have[it["id"]])
            continue
        rel = {"app": {"data": {"type": "apps", "id": APP_ID}}}
        rel["inAppPurchaseV2" if kind == "iap" else "subscription"] = {"data": {"type": "inAppPurchases" if kind == "iap" else "subscriptions", "id": it["id"]}}
        made = asc.call("POST", "/v1/promotedPurchases", {"data": {"type": "promotedPurchases",
                        "attributes": {"visibleForAllUsers": True, "enabled": True}, "relationships": rel}})
        if made:
            ids.append(made["data"]["id"])
            print("   promoted", made["data"]["id"], made["data"]["attributes"])
        else:
            print("   promote FAILED")
    if ids:
        r = asc.call("PATCH", f"/v1/apps/{APP_ID}/relationships/promotedPurchases", {"data": [{"type": "promotedPurchases", "id": i} for i in ids]})
        print("order", "set" if r is not None else "FAILED")


def status():
    got = asc.call("GET", f"/v1/apps/{APP_ID}/promotedPurchases", params={"limit": 50})
    for p in (got or {}).get("data", []):
        print(p["id"], p["attributes"])


if __name__ == "__main__":
    status() if len(sys.argv) > 1 and sys.argv[1] == "status" else main()
