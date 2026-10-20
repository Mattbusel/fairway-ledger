"""Give Plus Monthly and Plus Yearly a different description in every locale (Apple 2.3.2: promoted items must differ)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

D = {
    "en-US": ("Monthly plan: Pro, insights, all finishes", "Yearly plan: all of Plus for a full year"),
    "en-GB": ("Monthly plan: Pro, insights, all finishes", "Yearly plan: all of Plus for a full year"),
    "en-AU": ("Monthly plan: Pro, insights, all finishes", "Yearly plan: all of Plus for a full year"),
    "en-CA": ("Monthly plan: Pro, insights, all finishes", "Yearly plan: all of Plus for a full year"),
    "es-MX": ("Plan mensual: Pro, análisis y acabados", "Plan anual: todo Plus durante un año"),
    "es-ES": ("Plan mensual: Pro, análisis y acabados", "Plan anual: todo Plus durante un año"),
    "de-DE": ("Monatsplan: Pro, Analysen, alle Farben", "Jahresplan: alles aus Plus ein ganzes Jahr"),
    "fr-FR": ("Formule mensuelle : Pro, analyses, finitions", "Formule annuelle : tout Plus pendant un an"),
    "it": ("Piano mensile: Pro, analisi e finiture", "Piano annuale: tutto Plus per un anno"),
    "pt-BR": ("Plano mensal: Pro, análises e acabamentos", "Plano anual: todo o Plus por um ano"),
    "ja": ("月額プラン:Pro、分析、全カラー", "年額プラン:Plusのすべてを1年間"),
    "ko": ("월간 플랜: Pro, 분석, 모든 컬러", "연간 플랜: 1년 동안 Plus 전체"),
    "zh-Hans": ("月度方案:Pro、分析与全部配色", "年度方案:全年享受全部 Plus"),
}
ids = {"monthly": "6824726341", "yearly": "6824727689"}
for k, sid in ids.items():
    locs = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations", params={"limit": 50})["data"]
    for l in locs:
        loc = l["attributes"]["locale"]
        d = D[loc][0 if k == "monthly" else 1]
        assert len(d) <= 45, (loc, d, len(d))
        if l["attributes"].get("description") == d:
            continue
        r = asc.call("PATCH", f"/v1/subscriptionLocalizations/{l['id']}", {"data": {"type": "subscriptionLocalizations", "id": l["id"], "attributes": {"description": d}}})
        print(k, loc, "ok" if r else "FAILED", l["attributes"]["name"])
