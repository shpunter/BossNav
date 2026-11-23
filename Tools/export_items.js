// Builds Items/BossNav_ItemData.lua from Forever Atlas (AtlasLootClassic) loot tables.
//
// The game never loads this file. Run it again when Forever Atlas updates:
//   npm install fengari@0.1.4      (once, in any folder; then point NODE_PATH at its node_modules)
//   node Tools/export_items.js
// from the BossNav folder. It runs Atlas's own data files in a small Lua
// sandbox (they rename, merge and insert bosses with Lua code, so copying the
// text would miss those changes), matches every Atlas boss to a BossNav boss
// by name, and writes one Lua table BossNav reads at load time.
"use strict";
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const BOSSNAV = path.resolve(__dirname, "..");
const ADDONS = path.resolve(BOSSNAV, "..");
const ATLAS = path.join(ADDONS, "AtlasLootClassic_DungeonsAndRaids");
const OUT = path.join(BOSSNAV, "Items", "BossNav_ItemData.lua");
// Same order as Atlas's toc (data-tbc.lua is skipped: Forever is classic content)
const ATLAS_FILES = ["data.lua", "forever-classic.lua", "forever.lua", "droprate.lua"];

// Stubs for the bits of AtlasLoot and the game the data files touch.
const PRELUDE = `
getfenv = function() return _G end
-- ATLASLOOT_* constants (colours, extra row fields): their own name is enough
setmetatable(_G, { __index = function(t, k) if type(k) == "string" and k:match("^ATLASLOOT_") then return k end end })
unpack = unpack or table.unpack
UnitFactionGroup = function() return "Alliance" end
FACTION_HORDE, FACTION_ALLIANCE = "Horde", "Alliance"
C_Map = { GetAreaInfo = function(id) return "Area " .. tostring(id) end }
local function key(t, k) return k end
local AL = setmetatable({}, { __index = key })
local diffs, ctypes = {}, {}
local proto = {}
function proto:AddDifficulty(name)
  if not diffs[name] then diffs[#diffs + 1] = name; diffs[name] = #diffs end
  return diffs[name]
end
local ittypes = 0
function proto:AddItemTableType(a) ittypes = ittypes + 1; return a == "Set" and "SET" or ittypes end
function proto:AddExtraItemTableType() return 0 end
function proto:AddContentType(name)
  if not ctypes[name] then ctypes[name] = name end
  return name
end
local store = {}
DROPRATES = {}
AtlasLoot = {
  IS_FOREVER = true, CLASSIC_VERSION_NUM = 1, BC_VERSION_NUM = 2, WRATH_VERSION_NUM = 3,
  GameVersion_GE = function(self, v, ret, retFalse) if 1 >= v then return ret or true end return retFalse end,
  GameVersion_LT = function(self, v, ret, retFalse) if 1 < v then return ret or true end return retFalse end,
  Locales = AL, IngameLocales = AL,
  ReturnForGameVersion = function(classic) return classic end,
  ItemDB = { Add = function(self, name)
    if not store[name] then store[name] = setmetatable({}, { __index = proto }) end
    return store[name]
  end },
  Data = { Droprate = { AddData = function(self, d) DROPRATES = d end } },
}
ATLAS_STORE = store
ATLAS_DIFFS = diffs
`;

function runLua(L, code, chunkName, arg) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(chunkName)) !== lua.LUA_OK) {
        throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
    let nargs = 0;
    if (arg !== undefined) { lua.lua_pushstring(L, to_luastring(arg)); nargs = 1; }
    if (lua.lua_pcall(L, nargs, 0, 0) !== lua.LUA_OK) {
        throw new Error(chunkName + ": " + to_jsstring(lua.lua_tostring(L, -1)));
    }
}

// Lua value at the top of the stack -> plain JS (tables become Maps keyed by
// number or string; functions and cycles are dropped).
function toJS(L, idx, seen) {
    idx = lua.lua_absindex(L, idx);
    switch (lua.lua_type(L, idx)) {
        case lua.LUA_TNUMBER: return lua.lua_tonumber(L, idx);
        case lua.LUA_TSTRING: return to_jsstring(lua.lua_tostring(L, idx));
        case lua.LUA_TBOOLEAN: return lua.lua_toboolean(L, idx);
        case lua.LUA_TTABLE: {
            const ptr = lua.lua_topointer(L, idx);
            if (seen.has(ptr)) return seen.get(ptr);
            const m = new Map();
            seen.set(ptr, m);
            lua.lua_pushnil(L);
            while (lua.lua_next(L, idx) !== 0) {
                const k = toJS(L, -2, seen);
                const v = toJS(L, -1, seen);
                if (k !== undefined && v !== undefined) m.set(k, v);
                lua.lua_pop(L, 1);
            }
            return m;
        }
        default: return undefined;
    }
}

function getGlobal(L, name) {
    lua.lua_getglobal(L, to_luastring(name));
    const v = toJS(L, -1, new Map());
    lua.lua_pop(L, 1);
    return v;
}

// Map with keys 1..n -> array
function arr(m) {
    const out = [];
    if (!(m instanceof Map)) return out;
    for (let i = 1; m.has(i); i++) out.push(m.get(i));
    return out;
}

// ---------------------------------------------------------------- Atlas
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
runLua(L, PRELUDE, "prelude");
for (const f of ATLAS_FILES) {
    runLua(L, fs.readFileSync(path.join(ATLAS, f), "utf8"), f, "AtlasLootClassic_DungeonsAndRaids");
}
const store = getGlobal(L, "ATLAS_STORE").get("AtlasLootClassic_DungeonsAndRaids");
const dropRates = getGlobal(L, "DROPRATES");

// Item names from the "-- Name" comments next to each item row
const itemNames = new Map();
for (const f of ["data.lua", "forever-classic.lua", "forever.lua"]) {
    const re = /\{\s*\d+\s*,\s*(\d+)\s*[,}][^\n]*?--\s*([^\n]+)/g;
    const text = fs.readFileSync(path.join(ATLAS, f), "utf8");
    let m;
    while ((m = re.exec(text))) {
        const id = Number(m[1]);
        const name = m[2].replace(/\s*\(.*$/, "").replace(/\s*\[.*$/, "").trim();
        if (id > 100 && name && !itemNames.has(id)) itemNames.set(id, name);
    }
}

// ---------------------------------------------------------------- BossNav
const BN = lauxlib.luaL_newstate();
lualib.luaL_openlibs(BN);
runLua(BN, `
  local ns = { FOREVER_IMG = "" }
  function ns.Norm(name)
    local s = tostring(name):lower():gsub("^the%s+", ""):gsub("[^%w]", "")
    return s
  end
  local chunk = assert(loadfile(...))
  chunk("BossNav", ns)
  BN_DUNGEONS = ns.DUNGEONS
`.replace("loadfile(...)", "loadfile(" + JSON.stringify(path.join(BOSSNAV, "Core", "BossNav_Data.lua")) + ")"), "bossnav");
const dungeons = arr(getGlobal(BN, "BN_DUNGEONS")).map(cfg => ({
    name: arr(cfg.get("zones"))[0],
    bosses: arr(cfg.get("bosses")).map(b => b.get(1)),
}));

function norm(s) {
    return String(s).toLowerCase().replace(/^the\s+/, "").replace(/[^a-z0-9]/g, "");
}
// Every spelling a boss name could match under: the full name, without the
// "(...)" part, and the part inside the brackets.
function keys(name) {
    const out = new Set([norm(name)]);
    const bare = name.replace(/\s*\(.*?\)\s*/g, " ").trim();
    if (bare) out.add(norm(bare));
    for (const m of name.matchAll(/\(([^)]*)\)/g)) out.add(norm(m[1]));
    out.delete("");
    return out;
}

// Atlas dungeon -> BossNav dungeon: the one sharing the most boss names
function matchDungeon(encNames) {
    let best = null, bestN = 0;
    for (const d of dungeons) {
        const bossKeys = new Set();
        d.bosses.forEach(b => keys(b).forEach(k => bossKeys.add(k)));
        let n = 0;
        for (const e of encNames) if ([...keys(e)].some(k => bossKeys.has(k))) n++;
        if (n > bestN) { best = d; bestN = n; }
    }
    return best;
}

// Atlas spellings that differ from BossNav's
const ALIAS = { "Ras Frostwhisperer": "Ras Frostwhisper" };

function matchBoss(d, encName) {
    encName = ALIAS[encName] || encName;
    const ek = keys(encName);
    for (const b of d.bosses) if (norm(b) === norm(encName)) return b;
    for (const b of d.bosses) if ([...keys(b)].some(k => ek.has(k))) return b;
    return null;
}

// Item IDs of an encounter, every difficulty, no duplicates
function encounterItems(enc) {
    const ids = [];
    for (const [k, v] of enc) {
        if (typeof k !== "number" || !(v instanceof Map)) continue;
        for (const row of arr(v)) {
            const id = row instanceof Map ? row.get(2) : undefined;
            if (typeof id === "number" && id > 100 && !ids.includes(id)) ids.push(id);
        }
    }
    return ids;
}

function npcIDs(enc) {
    const n = enc.get("npcID");
    if (typeof n === "number") return [n];
    return arr(n).filter(x => typeof x === "number");
}

const out = new Map();   // BossNav dungeon name -> [{ boss, extra, items, chance }]
const report = [];
for (const [key, dungeon] of store) {
    if (!(dungeon instanceof Map) || !dungeon.has("items")) continue;
    const encs = arr(dungeon.get("items")).filter(e => e instanceof Map
        && !e.get("IgnoreAsSource") && e.get("TableType") !== "SET" && typeof e.get("name") === "string");
    const d = matchDungeon(encs.map(e => e.get("name")));
    if (!d) { report.push(`skipped Atlas ${key}: no BossNav dungeon`); continue; }
    const list = out.get(d.name) || [];
    for (const e of encs) {
        const items = encounterItems(e);
        if (items.length === 0) continue;
        const boss = matchBoss(d, e.get("name"));
        const name = boss || e.get("name").replace(/\s*-\s*Tier.*$/, "");
        const rates = npcIDs(e).map(n => dropRates.get(n)).filter(Boolean);
        const chance = items.map(id => {
            for (const r of rates) if (r.has(id)) return r.get(id);
            return 0;
        });
        let entry = list.find(x => x.boss === name);
        if (!entry) {
            entry = { boss: name, extra: !boss, items: [], chance: [] };
            list.push(entry);
        }
        items.forEach((id, i) => {
            if (!entry.items.includes(id)) { entry.items.push(id); entry.chance.push(chance[i]); }
        });
        if (!boss) report.push(`${d.name}: "${e.get("name")}" kept as other source`);
    }
    out.set(d.name, list);
}

// ---------------------------------------------------------------- web
// Loot players have seen drop in WoW Forever (Tools/forever_loot.json, made by
// Tools/fetch_forever_loot.js). Atlas stays first: the web data only adds the
// items Atlas lacks, the drop % Atlas doesn't know, and whole bosses Atlas has
// no loot for (every Forever-only dungeon).
const WEB_FILE = path.join(__dirname, "forever_loot.json");
const MIN_QUALITY = 2;   // green and up: quest items and junk stay out
// Web spellings that differ from BossNav's
const WEB_ALIAS = { "Arcanic Enigma": "Mana Elemental", "Chest of The Seven": "The Seven", "Trash mobs": "Trash" };
let webAdded = 0, webRates = 0;
if (fs.existsSync(WEB_FILE)) {
    const web = JSON.parse(fs.readFileSync(WEB_FILE, "utf8"));
    for (const [slug, sources] of Object.entries(web.dungeons)) {
        const d = matchDungeon(sources.map(s => s.boss));
        if (!d) { report.push(`web: skipped ${slug}: no BossNav dungeon`); continue; }
        const list = out.get(d.name) || [];
        for (const s of sources) {
            const items = s.items.filter(i => i.quality >= MIN_QUALITY);
            if (items.length === 0) continue;
            const webName = WEB_ALIAS[s.boss] || s.boss.replace(/^Ring of Law:\s*/, "");
            const boss = s.kind === "trash" ? null : matchBoss(d, webName);
            const name = boss || webName;
            let entry = list.find(x => norm(x.boss) === norm(name) || norm(x.boss) === norm(s.boss));
            if (!entry) {
                entry = { boss: name, extra: !boss, items: [], chance: [] };
                list.push(entry);
                if (!boss) report.push(`${d.name}: web "${s.boss}" kept as other source`);
            }
            for (const i of items) {
                if (i.name && !itemNames.has(i.id)) itemNames.set(i.id, i.name);
                const at = entry.items.indexOf(i.id);
                if (at < 0) {
                    entry.items.push(i.id); entry.chance.push(i.chance); webAdded++;
                } else if (!entry.chance[at] && i.chance) {
                    entry.chance[at] = i.chance; webRates++;
                }
            }
        }
        out.set(d.name, list);
    }
    console.log(`web loot from ${web.source} (${web.fetched}): ${webAdded} items added, ${webRates} drop rates filled`);
}

// Bosses in BossNav's order first, then the other sources
for (const d of dungeons) {
    const list = out.get(d.name);
    if (!list) continue;
    list.sort((a, b) => {
        const ia = a.extra ? 1e3 : d.bosses.indexOf(a.boss);
        const ib = b.extra ? 1e3 : d.bosses.indexOf(b.boss);
        return ia - ib;
    });
    for (const b of d.bosses) if (!list.some(x => x.boss === b)) report.push(`${d.name}: no loot for boss "${b}"`);
}

// ---------------------------------------------------------------- write
const q = s => JSON.stringify(s);
const used = new Set();
const lines = [];
lines.push("-- Loot of every dungeon boss, generated by Tools/export_items.js from Forever");
lines.push("-- Atlas (AtlasLootClassic_DungeonsAndRaids). Do not edit by hand: run it again.");
lines.push("-- SOURCES[dungeon] = list of { boss, items = {itemID...}, chance = {drop %...} };");
lines.push("-- chance 0 = unknown; extra = true for rares, trash and other non-boss sources.");
lines.push("-- NAMES[itemID] = English name, shown until the game has the item cached.");
lines.push("local ADDON, ns = ...");
lines.push("");
lines.push("local SOURCES = {");
for (const d of dungeons) {
    const list = out.get(d.name);
    if (!list || list.length === 0) continue;
    lines.push(`    [${q(d.name)}] = {`);
    for (const e of list) {
        e.items.forEach(id => used.add(id));
        const ch = e.chance.map(c => (c ? String(Math.round(c * 100) / 100) : "0"));
        lines.push(`        { boss = ${q(e.boss)},${e.extra ? " extra = true," : ""} items = { ${e.items.join(", ")} }, chance = { ${ch.join(", ")} } },`);
    }
    lines.push("    },");
}
lines.push("}");
lines.push("");
lines.push("local NAMES = {");
for (const id of [...used].sort((a, b) => a - b)) {
    if (itemNames.has(id)) lines.push(`    [${id}] = ${q(itemNames.get(id))},`);
}
lines.push("}");
lines.push("");
lines.push("-- shared with the other BossNav files");
lines.push("ns.ITEM_SOURCES = SOURCES");
lines.push("ns.ITEM_NAMES = NAMES");
lines.push("");
fs.writeFileSync(OUT, lines.join("\r\n"));
console.log(`wrote ${OUT}: ${out.size} dungeons, ${used.size} items`);
console.log(report.join("\n"));
