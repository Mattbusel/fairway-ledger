// The four finish icons: the Fairway Ledger seal, re-leafed. Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, writeFileSync } from "fs";

// Five bands, dark to bright and back, matching Finish.band in Theme.swift; glow rgb.
const finishes = {
  RoseGold: [["#a05c4a", "#f9dcd0", "#d98f78", "#ffe9e0", "#a8604e"], "222,156,134", "#2e1814"],
  Platinum: [["#7f858f", "#f4f5f8", "#bfc4cc", "#ffffff", "#8a909a"], "201,205,212", "#1c1e22"],
  Emerald: [["#1b6e47", "#bdf2d6", "#42b47e", "#ddfbea", "#1f7a50"], "76,195,138", "#0f2a1d"],
  Copper: [["#8e4518", "#f6c9a2", "#cb7436", "#ffddbf", "#9a4e1e"], "210,125,62", "#2e1a0c"],
};
const root = "C:/Users/Matthew/fairway-ledger/Resources/Assets.xcassets";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, [band, glow, warm]] of Object.entries(finishes)) {
  const foil = `linear-gradient(135deg,${band[0]} 0%,${band[1]} 28%,${band[2]} 50%,${band[3]} 72%,${band[4]} 100%)`;
  const lacquer = `radial-gradient(circle at 50% 0%, ${warm} 0%, #14110c 55%, #0b0a08 100%)`;
  const stops = band.map((c, i) => `<stop offset="${[0, 0.3, 0.55, 0.78, 1][i]}" stop-color="${c}"/>`).join("");
  await p.setContent(`<body style="margin:0"><div style="width:1024px;height:1024px;background:${lacquer};display:flex;align-items:center;justify-content:center">
     <div style="width:700px;height:700px;border-radius:50%;padding:14px;box-sizing:border-box;background:${foil};box-shadow:0 0 120px rgba(${glow},.35)">
      <div style="width:100%;height:100%;border-radius:50%;background:#100d08;display:flex;align-items:center;justify-content:center;position:relative">
       <div style="position:absolute;inset:26px;border-radius:50%;border:3px solid rgba(${glow},.35)"></div>
       <svg width="420" height="460" viewBox="0 0 420 460"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">${stops}</linearGradient></defs>
        <rect x="150" y="30" width="18" height="380" rx="9" fill="url(#g)"/>
        <path d="M168 40 L360 100 L168 170 Z" fill="url(#g)"/>
        <ellipse cx="170" cy="420" rx="150" ry="26" fill="url(#g)" opacity=".85"/></svg>
      </div></div></div></body>`);
  const dir = `${root}/AppIcon-${name}.appiconset`;
  mkdirSync(dir, { recursive: true });
  await p.screenshot({ path: `${dir}/icon-1024.png`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  writeFileSync(`${dir}/Contents.json`, JSON.stringify({ images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log("wrote", name);
}
await b.close();
