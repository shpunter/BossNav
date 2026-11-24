// Downloads the WoW Forever boss loot that players have seen drop, from
// foreverchanges.pro, and saves it as Tools/forever_loot.json.
//
// The game never loads this file. Run it when you want fresher loot data:
//   node Tools/fetch_forever_loot.js
// Nothing reads it automatically any more (the Atlas export was removed).
// Forever Atlas has no loot for the Forever-only dungeons; this fills them in.
"use strict";
const fs = require("fs");
const path = require("path");

const SITE = "https://foreverchanges.pro";
const OUT = path.join(__dirname, "forever_loot.json");

async function get(url) {
    const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
    return res.text();
}

function text(html) {
    return html.replace(/<!-- -->/g, "").replace(/<[^>]+>/g, "")
        .replace(/&#x27;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, "&").trim();
}

// One dungeon page -> [{ boss, kind, items: [{ id, name, quality, chance, kills }] }]
// kind: "boss", "rare" (rare spawn), "object" (chest or object), "trash".
function parseDungeon(html) {
    const bosses = [];
    const sectionRe = /<section id="[^"]+" class="lb-boss[^"]*"[^>]*>([\s\S]*?)<\/section>/g;
    let s;
    while ((s = sectionRe.exec(html))) {
        const body = s[1];
        const boss = text((body.match(/<h2[^>]*>([\s\S]*?)<\/h2>/) || [, ""])[1]);
        const about = text((body.match(/<header>[\s\S]*?<p>([\s\S]*?)<\/p>/) || [, ""])[1]);
        let kind = "boss";
        if (/^Trash mobs$/i.test(boss)) kind = "trash";
        else if (/Rare spawn/i.test(about)) kind = "rare";
        else if (/Chest or object/i.test(about)) kind = "object";
        const items = [];
        const itemRe = /<a href="\/item\/(\d+)\/[^"]*">([\s\S]*?)<\/a>/g;
        let i;
        while ((i = itemRe.exec(body))) {
            const row = i[2];
            const seen = row.match(/Seen in (\d+) of (\d+) kills/);
            const pct = row.match(/\(\s*(?:<!-- -->)?([\d.]+)%/);
            items.push({
                id: Number(i[1]),
                name: text((row.match(/class="lb-name[^"]*">([\s\S]*?)<\/span>/) || [, ""])[1]),
                quality: Number((row.match(/lb-icon lb-q(\d)/) || [, -1])[1]),
                chance: pct ? Number(pct[1]) : 0,
                kills: seen ? Number(seen[2]) : 0,
            });
        }
        bosses.push({ boss, kind, items });
    }
    return bosses;
}

(async () => {
    const index = await get(`${SITE}/dungeons`);
    const slugs = [...new Set([...index.matchAll(/href="\/dungeons\/([a-z0-9-]+)"/g)].map(m => m[1]))].sort();
    const dungeons = {};
    for (const slug of slugs) {
        const bosses = parseDungeon(await get(`${SITE}/dungeons/${slug}`));
        dungeons[slug] = bosses;
        console.log(`${slug}: ${bosses.length} sources, ${bosses.reduce((n, b) => n + b.items.length, 0)} items`);
    }
    const data = { source: `${SITE}/dungeons`, fetched: new Date().toISOString().slice(0, 10), dungeons };
    fs.writeFileSync(OUT, JSON.stringify(data, null, 1) + "\n");
    console.log(`wrote ${OUT}`);
})().catch(e => { console.error(e.message); process.exit(1); });
