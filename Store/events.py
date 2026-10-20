"""Fairway Ledger In-App Events: localized, with card and details art, deep linked into the app.

    python Store/events.py <media dir> [--dry]

Media dir holds <key>-card.png (1920x1080) and <key>-details.png (1080x1920) for each event key.
Idempotent: reuses an event with the same reference name and only uploads missing art.
"""
import hashlib
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

media = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
DRY = "--dry" in sys.argv

EVENTS = {
    "challenge": dict(
        ref="November challenge: zero three-putts",
        badge="CHALLENGE", link="fairwayledger://challenge",
        schedule={"publishStart": "2026-10-26T16:00:00Z", "eventStart": "2026-11-01T11:00:00Z", "eventEnd": "2026-11-30T23:00:00Z"},
        copy={
            "en-US": ("Zero Three-Putts Challenge", "Play a full round without a three-putt",
                      "November's challenge: one eighteen-hole round with no three-putts, tracked from your card. Finish it for a medal."),
            "en-GB": ("Zero Three-Putts Challenge", "Play a full round without a three-putt",
                      "November's challenge: one eighteen-hole round with no three-putts, tracked from your card. Finish it for a medal."),
            "es-MX": ("Reto: cero tres putts", "Juega una ronda completa sin un tres putts",
                      "El reto de noviembre: una ronda de 18 hoyos sin tres putts, contada desde tu tarjeta. Termínalo y gana una medalla."),
            "es-ES": ("Reto: cero tres putts", "Juega una vuelta completa sin un tres putts",
                      "El reto de noviembre: una vuelta de 18 hoyos sin tres putts, contada desde tu tarjeta. Complétalo y gana una medalla."),
            "de-DE": ("Challenge: kein Dreiputt", "Eine ganze Runde ohne Dreiputt",
                      "Die Challenge im November: eine 18-Loch-Runde ohne Dreiputt, gezählt von deiner Scorekarte. Dafür gibt es eine Medaille."),
            "fr-FR": ("Défi : zéro trois-putts", "Un parcours complet sans trois-putts",
                      "Le défi de novembre : un 18 trous sans trois-putts, suivi depuis votre carte. Réussissez-le pour gagner une médaille."),
            "it": ("Sfida: zero tre putt", "Un giro completo senza un tre putt",
                   "La sfida di novembre: un giro da 18 buche senza tre putt, contato dal tuo score. Completala e vinci una medaglia."),
            "pt-BR": ("Desafio: zero three-putts", "Uma volta completa sem three-putt",
                      "O desafio de novembro: uma volta de 18 buracos sem three-putt, contada no seu cartão. Complete e ganhe uma medalha."),
            "ja": ("3パットゼロ チャレンジ", "18ホールを3パットなしで回ろう",
                   "11月のチャレンジ:3パットなしの18ホールを1ラウンド。スコアカードから自動で集計、達成するとメダルがもらえます。"),
            "ko": ("3퍼트 제로 챌린지", "18홀을 3퍼트 없이 돌아보세요",
                   "11월 챌린지: 3퍼트 없는 18홀 라운드 하나. 스코어카드로 자동 집계되고, 달성하면 메달을 받습니다."),
            "zh-Hans": ("零三推挑战", "打一轮没有三推的 18 洞",
                        "十一月挑战:打一轮没有三推的 18 洞。根据你的记分卡自动统计,完成即可获得奖牌。"),
        }),
    "update": dict(
        ref="Fall update: challenges and practice widget",
        badge="MAJOR_UPDATE", link="fairwayledger://challenge",
        schedule={"publishStart": "2026-10-31T16:00:00Z", "eventStart": "2026-11-03T16:00:00Z", "eventEnd": "2026-12-01T16:00:00Z"},
        copy={
            "en-US": ("Challenges and Practice Widget", "A monthly challenge and one-tap practice logs",
                      "A new challenge every month with a medal cabinet, a widget that logs range time in one tap, and Lock Screen widgets."),
            "en-GB": ("Challenges and Practice Widget", "A monthly challenge and one-tap practice logs",
                      "A new challenge every month with a medal cabinet, a widget that logs range time in one tap, and Lock Screen widgets."),
            "es-MX": ("Retos y widget de práctica", "Un reto al mes y práctica con un toque",
                      "Un reto nuevo cada mes con medallas, un widget que registra tu práctica con un toque y widgets de pantalla bloqueada."),
            "es-ES": ("Retos y widget de práctica", "Un reto al mes y práctica con un toque",
                      "Un reto nuevo cada mes con medallas, un widget que registra tu práctica con un toque y widgets de pantalla bloqueada."),
            "de-DE": ("Challenges und Training-Widget", "Jeden Monat eine Challenge, Training per Tipp",
                      "Jeden Monat eine neue Challenge mit Medaillen, ein Widget für Training per Tipp und Widgets für den Sperrbildschirm."),
            "fr-FR": ("Défis et widget d'entraînement", "Un défi par mois, l'entraînement en un geste",
                      "Un défi chaque mois avec médailles, un widget pour noter l'entraînement d'un geste, des widgets écran verrouillé."),
            "it": ("Sfide e widget allenamento", "Una sfida al mese, allenamento con un tocco",
                   "Una nuova sfida ogni mese con medaglie, un widget per registrare l'allenamento con un tocco e widget in blocco schermo."),
            "pt-BR": ("Desafios e widget de treino", "Um desafio por mês e treino com um toque",
                      "Um desafio novo todo mês com medalhas, um widget que registra o treino com um toque e widgets na tela bloqueada."),
            "ja": ("チャレンジと練習ウィジェット", "毎月のチャレンジと、ワンタップの練習記録",
                   "毎月新しいチャレンジとメダル棚、ワンタップで練習時間を記録できるウィジェット、ロック画面のウィジェットが登場。"),
            "ko": ("챌린지와 연습 위젯", "매달 챌린지, 한 번 탭으로 연습 기록",
                   "매달 새로운 챌린지와 메달 진열장, 한 번 탭으로 연습 시간을 기록하는 위젯, 잠금 화면 위젯이 추가되었습니다."),
            "zh-Hans": ("挑战与练习小组件", "每月挑战,一点即可记录练习",
                        "每月一个新挑战和奖牌柜,一点即可记录练习时间的小组件,以及锁屏小组件。"),
        }),
}

for key, e in EVENTS.items():
    for loc, (n, s, l) in e["copy"].items():
        if len(n) > 30 or len(s) > 50 or len(l) > 120: print("TOO LONG", key, loc, len(n), len(s), len(l)); DRY = True
        assert "—" not in n + s + l
if DRY:
    print("copy ok")
    sys.exit()

app = asc.find_app()
aid = app["id"]
terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
all_events = asc.call("GET", f"/v1/apps/{aid}/appEvents", params={"limit": 50})["data"]


def upload(lid: str, kind: str, f: Path):
    data = f.read_bytes()
    made = asc.call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(data), "appEventAssetType": kind},
                    "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": lid}}}}})
    if not made:
        print("   reserve failed", kind)
        return
    made = made["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    asc.call("PATCH", f"/v1/appEventScreenshots/{made['id']}", {"data": {"type": "appEventScreenshots", "id": made["id"],
             "attributes": {"uploaded": True}}})


for key, e in EVENTS.items():
    ev = next((x for x in all_events if x["attributes"]["referenceName"] == e["ref"]), None)
    attrs = {"referenceName": e["ref"], "badge": e["badge"], "deepLink": e["link"], "primaryLocale": "en-US", "priority": "NORMAL",
             "purpose": "APPROPRIATE_FOR_ALL_USERS", "purchaseRequirement": "NO_COST_ASSOCIATED", "territorySchedules": [dict(territories=terr, **e["schedule"])]}
    if ev:
        print(key, "reusing", ev["id"], ev["attributes"]["eventState"])
        if ev["attributes"].get("purchaseRequirement") != "NO_COST_ASSOCIATED":
            asc.call("PATCH", f"/v1/appEvents/{ev['id']}", {"data": {"type": "appEvents", "id": ev["id"], "attributes": {"purchaseRequirement": "NO_COST_ASSOCIATED"}}})
    else:
        made = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": attrs,
                        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
        if not made:
            print(key, "create FAILED")
            continue
        ev = made["data"]
        print(key, "created", ev["id"])
    locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appEvents/{ev['id']}/localizations", params={"limit": 50})["data"]}
    for loc, (n, s, l) in e["copy"].items():
        la = {"name": n, "shortDescription": s, "longDescription": l}
        if loc in locs:
            asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": la}})
        else:
            made = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **la),
                            "relationships": {"appEvent": {"data": {"type": "appEvents", "id": ev["id"]}}}}})
            if not made:
                print("  loc FAILED", loc)
                continue
            locs[loc] = made["data"]
        lid = locs[loc]["id"]
        have = {x["attributes"]["appEventAssetType"] for x in asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]}
        for kind, f in (("EVENT_CARD", media / f"{key}-card.png"), ("EVENT_DETAILS_PAGE", media / f"{key}-details.png")):
            if kind not in have and f.exists():
                upload(lid, kind, f)
        print("  ", loc, "ok")
    time.sleep(3)
    ev = asc.call("GET", f"/v1/appEvents/{ev['id']}")["data"]
    print(key, "state:", ev["attributes"]["eventState"], ev["id"])
