// 1024x1024 promotional images for the promoted in-app purchases (no text: the App Store sets the name beside it).
//   node Store/art/promo.mjs   -> Store/promo/<key>.png
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync } from "fs";

const out = "C:/Users/Matthew/fairway-ledger/Store/promo";
mkdirSync(out, { recursive: true });
const gold = ["#9e7824", "#f7e6a3", "#cca338", "#fff0bd", "#a88029"];
const items = {
  "plus-yearly": { band: gold, glow: "212,175,55", warm: "#2e2410", icon: "crown", rings: 3 },
  "plus-monthly": { band: gold, glow: "212,175,55", warm: "#2e2410", icon: "crown", rings: 1 },
  pro: { band: gold, glow: "212,175,55", warm: "#2a2010", icon: "chart", rings: 1 },
  sapphire: { band: ["#23408f", "#d3e2ff", "#5a86dc", "#e8f0ff", "#2d4fa8"], glow: "111,155,234", warm: "#101a33", icon: "flag", rings: 1 },
  rose: { band: ["#a05c4a", "#f9dcd0", "#d98f78", "#ffe9e0", "#a8604e"], glow: "222,156,134", warm: "#2e1814", icon: "flag", rings: 1 },
  plans: { band: gold, glow: "212,175,55", warm: "#2a2010", icon: "plan", rings: 1 },
};
const ICON = {
  crown: `<path d="M70 300 L110 120 L190 220 L250 90 L310 220 L390 120 L430 300 Z" fill="url(#g)"/><rect x="70" y="320" width="360" height="40" rx="14" fill="url(#g)"/>`,
  chart: `<polyline points="60,330 150,250 230,280 320,160 440,110" fill="none" stroke="url(#g)" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/><circle cx="440" cy="110" r="26" fill="url(#g)"/>`,
  flag: `<rect x="200" y="40" width="20" height="360" rx="10" fill="url(#g)"/><path d="M220 50 L420 110 L220 180 Z" fill="url(#g)"/><ellipse cx="215" cy="410" rx="170" ry="28" fill="url(#g)" opacity=".85"/>`,
  plan: `<rect x="110" y="60" width="280" height="340" rx="30" fill="none" stroke="url(#g)" stroke-width="22"/><rect x="190" y="36" width="120" height="56" rx="18" fill="url(#g)"/><g fill="url(#g)"><rect x="160" y="150" width="180" height="22" rx="11"/><rect x="160" y="220" width="180" height="22" rx="11"/><rect x="160" y="290" width="120" height="22" rx="11"/></g>`,
};
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [key, it] of Object.entries(items)) {
  const foil = `linear-gradient(135deg,${it.band[0]} 0%,${it.band[1]} 28%,${it.band[2]} 50%,${it.band[3]} 72%,${it.band[4]} 100%)`;
  const stops = it.band.map((c, i) => `<stop offset="${[0, 0.3, 0.55, 0.78, 1][i]}" stop-color="${c}"/>`).join("");
  const rings = Array.from({ length: it.rings }, (_, i) => `<div style="position:absolute;inset:${26 + i * 22}px;border-radius:50%;border:3px solid rgba(${it.glow},${0.4 - i * 0.1})"></div>`).join("");
  await p.setContent(`<body style="margin:0"><div style="width:1024px;height:1024px;background:radial-gradient(circle at 50% 0%, ${it.warm} 0%, #14110c 55%, #0b0a08 100%);display:flex;align-items:center;justify-content:center">
    <div style="width:720px;height:720px;border-radius:50%;padding:14px;box-sizing:border-box;background:${foil};box-shadow:0 0 140px rgba(${it.glow},.38)">
     <div style="width:100%;height:100%;border-radius:50%;background:#100d08;display:flex;align-items:center;justify-content:center;position:relative">${rings}
      <svg width="500" height="460" viewBox="0 0 500 460"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">${stops}</linearGradient></defs>${ICON[it.icon]}</svg>
     </div></div></div></body>`);
  await p.screenshot({ path: `${out}/${key}.png`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  console.log("wrote", key);
}
await b.close();
