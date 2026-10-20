// App Store screenshots: a serif headline in gold over each raw simulator shot, on lacquer.
//   node Store/art/frame.mjs <dir of CI shots> [en-US | ja | ko | zh-Hans | cpp-practice | cpp-handicap | cpp-stats]
// Writes fastlane/screenshots/<locale>/NN_iPhone.png (or Store/cpp/<name>/) at 1320x2868 (the 6.9" size).
// No price words in any caption: Apple rejects screenshots that mention price, free, or subscriptions.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = loc.startsWith("cpp-")
  ? `C:/Users/Matthew/fairway-ledger/Store/cpp/${loc.slice(4)}`
  : `C:/Users/Matthew/fairway-ledger/fastlane/screenshots/${loc}`;
const EN = {
  home: ["Your game,<br>in one ledger.", "Handicap, practice and rounds, <b>finished in gold.</b>"],
  insights: ["See where your<br>index is heading.", "Your pace, and the strokes each part <b>of your game costs.</b>"],
  scorecard: ["Every hole,<br>every putt.", "Score, putts, fairways, penalties, <b>and your net.</b>"],
  widgets: ["Your round on<br>the Lock Screen.", "Your index on the Lock Screen, <b>score to par as you play.</b>"],
  challenge: ["A new challenge<br>every month.", "Tracked from what you log, <b>with a medal for each.</b>"],
  plan: ["Practise what<br>costs you strokes.", "A weekly plan <b>built from your own numbers.</b>"],
  course: ["Know every hole<br>you play.", "The ones that cost you, <b>and the ones to attack.</b>"],
  stats: ["See where the<br>strokes go.", "Par 3s, 4s and 5s, <b>penalties and three-putts.</b>"],
  poster: ["A round worth<br>framing.", "Gold-leaf scorecards <b>to share.</b>"],
  live: ["Log the range,<br>ball by ball.", "Strike, shape, misses <b>and real carries.</b>"],
  rounds: ["Saved courses,<br>nine or eighteen.", "Pars, rating and slope <b>fill in by themselves.</b>"],
};
const ORDER = ["home", "insights", "scorecard", "widgets", "challenge", "plan", "course", "stats", "poster", "live"];
// Custom product pages: the same screens, ordered and captioned for one kind of golfer each.
const CPP = {
  practice: [
    ["live", "Practise with<br>a purpose.", "Every ball logged: <b>strike, shape and carry.</b>"],
    ["plan", "A plan for every<br>range session.", "Built from the putts and clubs <b>that cost you strokes.</b>"],
    ["challenge", "A new challenge<br>every month.", "Eight sessions, a hundred putts, <b>a medal for each.</b>"],
    ["widgets", "Log practice<br>in one tap.", "Practice minutes from the Home Screen, <b>no app to open.</b>"],
    ["home", "Your game,<br>in one ledger.", "Practice, rounds and handicap, <b>finished in gold.</b>"],
    ["stats", "See what the<br>practice changes.", "Putting by distance, ball flight <b>and your misses.</b>"],
    ["insights", "Know where<br>to practise next.", "The strokes each part of your game <b>costs you.</b>"],
  ],
  handicap: [
    ["insights", "Watch your<br>handicap drop.", "Your index, its pace, <b>and where it is heading.</b>"],
    ["home", "Your handicap<br>in gold.", "World Handicap style estimate, <b>course handicap and net.</b>"],
    ["widgets", "Your index on<br>the Lock Screen.", "And your round live <b>as you play.</b>"],
    ["scorecard", "Every hole,<br>every putt.", "Score, putts, fairways, penalties, <b>and your net.</b>"],
    ["course", "Know every hole<br>you play.", "The ones that cost you, <b>and the ones to attack.</b>"],
    ["challenge", "Break your<br>next barrier.", "A monthly challenge <b>tracked from your cards.</b>"],
    ["poster", "A round worth<br>framing.", "Gold-leaf scorecards <b>to share.</b>"],
  ],
  stats: [
    ["stats", "Golf stats that<br>tell you why.", "Fairways, greens, putts, scrambling <b>and three-putts.</b>"],
    ["insights", "Strokes against<br>your target.", "Driving, approach, short game, putting: <b>what each one costs.</b>"],
    ["course", "Every course,<br>hole by hole.", "Your average on every hole <b>against par.</b>"],
    ["scorecard", "Every hole,<br>every putt.", "Greens in regulation and up-and-downs <b>worked out for you.</b>"],
    ["live", "Practice data,<br>ball by ball.", "Strike, shape, misses <b>and real carries.</b>"],
    ["home", "Your game,<br>in one ledger.", "Handicap, practice and rounds, <b>finished in gold.</b>"],
  ],
};
// Captions for the Japanese, Korean and Simplified Chinese store pages; the app screens themselves stay English.
const L10N = {
  "ja": {
    home: ["ゴルフのすべてを<br>1冊に。", "ハンデ、練習、ラウンドを<b>ゴールドで。</b>"],
    insights: ["ハンデの行き先が<br>見える。", "上達のペースと、<b>どこで打数を失うか。</b>"],
    scorecard: ["全ホール、<br>全パット。", "スコア、パット、フェアウェイ、ペナルティ、<b>ネットスコアも。</b>"],
    widgets: ["ラウンドを<br>ロック画面に。", "ロック画面にハンデ、<b>プレー中のスコアも。</b>"],
    challenge: ["毎月、新しい<br>チャレンジ。", "記録から自動で集計、<b>達成するとメダル。</b>"],
    plan: ["スコアを落とす<br>ところを練習。", "毎週のプランは<b>自分の数字から。</b>"],
    course: ["回るコースを<br>ホールごとに。", "スコアを落とすホールと、<b>攻めるホール。</b>"],
    stats: ["どこで打数を<br>失っているか。", "パー3、4、5ごとに、<b>ペナルティと3パット。</b>"],
    poster: ["飾りたくなる<br>ラウンド。", "金箔のスコアカードを<b>シェア。</b>"],
    live: ["練習場を<br>1球ずつ記録。", "当たり、球筋、ミス、<b>実際のキャリー。</b>"],
  },
  "ko": {
    home: ["나의 골프를<br>한 권에.", "핸디캡, 연습, 라운드를 <b>골드로.</b>"],
    insights: ["핸디캡이 가는<br>방향을 한눈에.", "향상 속도와 <b>타수를 잃는 곳.</b>"],
    scorecard: ["모든 홀,<br>모든 퍼트.", "타수, 퍼트, 페어웨이, 벌타, <b>네트 스코어까지.</b>"],
    widgets: ["잠금 화면에<br>내 라운드.", "잠금 화면에 핸디캡, <b>플레이 중 스코어도.</b>"],
    challenge: ["매달 새로운<br>챌린지.", "기록으로 자동 집계, <b>달성하면 메달.</b>"],
    plan: ["타수를 잃는 곳을<br>연습하세요.", "주간 플랜은 <b>내 기록으로.</b>"],
    course: ["모든 홀을<br>파악하세요.", "타수를 잃는 홀과 <b>공략할 홀.</b>"],
    stats: ["타수가 새는 곳을<br>한눈에.", "파3, 파4, 파5, <b>벌타와 3퍼트.</b>"],
    poster: ["액자에 걸고 싶은<br>라운드.", "금박 스코어카드를 <b>공유하세요.</b>"],
    live: ["연습장에서<br>공 하나하나.", "타구감, 구질, 미스, <b>실제 캐리.</b>"],
  },
  "zh-Hans": {
    home: ["你的球技,<br>尽在一本账。", "差点、练习和轮次,<b>金色呈现。</b>"],
    insights: ["看清差点的<br>走向。", "进步的速度,<b>以及在哪里丢杆。</b>"],
    scorecard: ["每一洞,<br>每一推。", "杆数、推杆、球道、罚杆,<b>还有净杆。</b>"],
    widgets: ["锁屏上<br>看本轮成绩。", "锁屏显示差点,<b>边打边看成绩。</b>"],
    challenge: ["每月一个<br>新挑战。", "根据记录自动统计,<b>完成即得奖牌。</b>"],
    plan: ["专练让你<br>丢杆的地方。", "每周计划<b>来自你自己的数据。</b>"],
    course: ["摸清你打的<br>每一个洞。", "让你丢杆的洞,<b>和可以进攻的洞。</b>"],
    stats: ["看清杆<br>丢在哪里。", "三杆洞、四杆洞、五杆洞,<b>罚杆和三推。</b>"],
    poster: ["值得装框的<br>一轮。", "金箔记分卡,<b>拿去分享。</b>"],
    live: ["练习场,<br>逐球记录。", "击球质量、球路、失误,<b>以及真实落点距离。</b>"],
  },
};
const steps = loc.startsWith("cpp-") ? CPP[loc.slice(4)]
  : ORDER.map((k) => [k, ...(loc === "en-US" ? EN[k] : L10N[loc][k])]);
const cjk = { ja: "Noto Sans JP", ko: "Noto Sans KR", "zh-Hans": "Noto Sans SC" }[loc];
const cjkSerif = { ja: "Noto Serif JP", ko: "Noto Serif KR", "zh-Hans": "Noto Serif SC" }[loc];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of steps) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&family=Inter:wght@500;600&display=block" rel="stylesheet">${cjk ? `
<link href="https://fonts.googleapis.com/css2?family=${cjkSerif.replace(/ /g, "+")}:wght@600;700;900&family=${cjk.replace(/ /g, "+")}:wght@500;600;700;800;900&display=block" rel="stylesheet">` : ""}
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#0b0a08;font-family:Inter,${cjk ? `"${cjk}",` : ""}sans-serif}
  .glow{position:absolute;inset:0;background:radial-gradient(1200px 900px at 50% -8%,rgba(212,175,55,.26),transparent 62%),radial-gradient(900px 700px at 100% 100%,rgba(156,122,34,.10),transparent 60%)}
  .rule{position:absolute;left:96px;right:96px;top:150px;height:2px;background:linear-gradient(90deg,transparent,rgba(247,231,176,.6),transparent)}
  .col{position:absolute;left:96px;right:96px;top:196px;display:flex;flex-direction:column;align-items:center;text-align:center}
  h1{margin:0;font-family:'Cormorant Garamond',${cjk ? `"${cjkSerif}",` : ""}serif;font-weight:600;font-size:118px;line-height:1.0;letter-spacing:-1px;
     background:linear-gradient(135deg,#9e7824 0%,#f7e6a3 30%,#cca33a 52%,#fff0bd 74%,#a8802a 100%);-webkit-background-clip:text;color:transparent}
  p{margin:30px 0 0;color:rgba(243,235,216,.62);font-weight:500;font-size:46px;line-height:1.25}
  p b{color:#f7e7b0;font-weight:600}
  .phone{margin:70px auto 0;width:1060px;border-radius:118px;padding:20px;background:linear-gradient(135deg,#6b4f1a,#d4af37 30%,#3a2e14 55%,#cca33a 80%,#6b4f1a);box-shadow:0 60px 140px rgba(0,0,0,.75)}
  .phone img{display:block;width:100%;border-radius:100px}
${cjk ? "h1,p{text-wrap:balance}" : ""}</style></head><body><div class="glow"></div><div class="rule"></div>
<div class="col"><h1>${head}</h1><p>${sub}</p>
<div class="phone"><img src="data:image/png;base64,${img}"></div></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
