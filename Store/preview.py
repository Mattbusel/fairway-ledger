"""App Preview video: cut the CI simulator recording to an App Store preview and upload it to a version's localizations.

    python Store/preview.py make <recording.mp4> [start seconds]   -> Store/preview/preview.mp4 (886x1920, 30 fps, <= 29.5 s, silent stereo)
    python Store/preview.py upload <version> [locale ...]         replace the 6.9" preview for each locale (default en-US)
    python Store/preview.py status <version>
"""
import hashlib
import subprocess
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

OUT = Path(__file__).resolve().parent / "preview" / "preview.mp4"
TYPE = "IPHONE_67"


def make(src: str, start: float = 0.0):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-y", "-ss", str(start), "-i", src, "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
           "-t", "29.5", "-vf", "scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,fps=30,format=yuv420p",
           "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-preset", "slow", "-crf", "18", "-r", "30",
           "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2", "-shortest", "-movflags", "+faststart", str(OUT)]
    subprocess.run(cmd, check=True, capture_output=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height,r_frame_rate,codec_name",
                            "-of", "compact", str(OUT)], capture_output=True, text=True).stdout
    print(probe)


def version_locs(version: str):
    app = asc.find_app()
    v = asc.call("GET", f"/v1/apps/{app['id']}/appStoreVersions", params={"filter[versionString]": version})["data"][0]
    return {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations", params={"limit": 50})["data"]}


def upload(version: str, locales):
    data = OUT.read_bytes()
    md5 = hashlib.md5(data).hexdigest()
    locs = version_locs(version)
    for loc in locales:
        l = locs.get(loc)
        if not l:
            print(loc, "no localization"); continue
        sets = asc.call("GET", f"/v1/appStoreVersionLocalizations/{l['id']}/appPreviewSets")["data"]
        pset = next((s for s in sets if s["attributes"]["previewType"] == TYPE), None)
        if pset:
            cur = asc.call("GET", f"/v1/appPreviewSets/{pset['id']}/appPreviews")["data"]
            if any(p["attributes"].get("sourceFileChecksum") == md5 for p in cur):
                print(loc, "preview MATCH"); continue
            for p in cur:
                asc.call("DELETE", f"/v1/appPreviews/{p['id']}")
        else:
            pset = asc.call("POST", "/v1/appPreviewSets", {"data": {"type": "appPreviewSets", "attributes": {"previewType": TYPE},
                            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": l["id"]}}}}})["data"]
        made = asc.call("POST", "/v1/appPreviews", {"data": {"type": "appPreviews",
                        "attributes": {"fileName": OUT.name, "fileSize": len(data), "mimeType": "video/mp4", "previewFrameTimeCode": "00:00:05:00"},
                        "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": pset["id"]}}}}})
        if not made:
            print(loc, "reserve FAILED"); continue
        m = made["data"]
        for op in m["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=300).raise_for_status()
        r = asc.call("PATCH", f"/v1/appPreviews/{m['id']}", {"data": {"type": "appPreviews", "id": m["id"],
                     "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
        print(loc, "preview uploaded" if r else "commit FAILED")


def status(version: str):
    for loc, l in version_locs(version).items():
        for s in asc.call("GET", f"/v1/appStoreVersionLocalizations/{l['id']}/appPreviewSets")["data"]:
            for p in asc.call("GET", f"/v1/appPreviewSets/{s['id']}/appPreviews")["data"]:
                a = p["attributes"]
                print(loc, s["attributes"]["previewType"], a.get("assetDeliveryState", {}).get("state"), a.get("assetDeliveryState", {}).get("errors"))


if __name__ == "__main__":
    a = sys.argv
    if a[1] == "make":
        make(a[2], float(a[3]) if len(a) > 3 else 0.0)
    elif a[1] == "upload":
        upload(a[2], a[3:] or ["en-US"])
    else:
        status(a[2])
