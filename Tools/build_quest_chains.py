# Builds Quests/BossNav_QuestChains.lua: the full prerequisite chain of every
# quest in Quests/BossNav_QuestData.lua, from the QuestieDB WoW Forever data.
#
# 1. Download into one empty folder (raw.githubusercontent.com/Questie/QuestieDB/master/...):
#      data/Forever/foreverQuestDB.lua, foreverNpcDB.lua, foreverObjectDB.lua, foreverItemDB.lua
#      src/corrections/Forever/foreverQuestFixes.lua, foreverNPCFixes.lua, foreverObjectFixes.lua
#      src/corrections/Forever/generated/foreverBaseQuest.lua, foreverBaseNpc.lua, foreverBaseObject.lua
#      src/corrections/enum/zones.lua
# 2. python -I Tools/build_quest_chains.py <that folder> Quests/BossNav_QuestData.lua Quests/BossNav_QuestChains.lua
# It prints quests it could not place (givers inside dungeons, missing quests).
import re, sys, json, os
sys.stdout.reconfigure(encoding='utf-8')
QDB, QDATA, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

# ---------------------------------------------------------------- Lua literal parser
TOK = re.compile(r'''\s*(?:(--\[\[.*?\]\]|--[^\n]*)|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(-?\d+\.?\d*(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z_0-9]*(?:[.:][A-Za-z_][A-Za-z_0-9]*)*)|(.))''', re.S)

def tokens(s):
    out = []
    for m in TOK.finditer(s):
        com, st, num, ident, ch = m.groups()
        if com is not None: continue
        if st is not None:
            body = st[1:-1]
            body = re.sub(r"\\(.)", lambda x: {'n': '\n', 't': '\t'}.get(x.group(1), x.group(1)), body)
            out.append(('s', body))
        elif num is not None: out.append(('n', float(num) if ('.' in num or 'e' in num.lower()) else int(num)))
        elif ident is not None: out.append(('i', ident))
        elif ch is not None and not ch.isspace(): out.append(('c', ch))
    return out

class Sym(str): pass

class P:
    def __init__(self, toks): self.t, self.i = toks, 0
    def peek(self): return self.t[self.i] if self.i < len(self.t) else (None, None)
    def take(self): v = self.t[self.i]; self.i += 1; return v
    def expect(self, ch):
        k, v = self.take()
        assert k == 'c' and v == ch, (ch, k, v, self.t[self.i-5:self.i+5])
    def expr(self):
        v = self.term()
        while self.peek() == ('c', '+') or self.peek() == ('c', '-'):
            op = self.take()[1]; w = self.term()
            v = ('op', op, v, w)
        return v
    def term(self):
        k, v = self.take()
        if k in ('s', 'n'): return v
        if k == 'i':
            if v == 'nil': return None
            if v == 'true': return True
            if v == 'false': return False
            if self.peek() == ('c', '('):   # function call: skip args
                depth = 0
                while True:
                    kk, vv = self.take()
                    if kk == 'c' and vv == '(': depth += 1
                    if kk == 'c' and vv == ')':
                        depth -= 1
                        if depth == 0: break
                return ('call', v)
            return Sym(v)
        if k == 'c' and v == '{': self.i -= 1; return self.table()
        if k == 'c' and v == '-': return ('neg', self.term())
        raise AssertionError(('bad term', k, v, self.t[self.i-5:self.i+5]))
    def table(self):
        self.expect('{')
        arr, d = [], {}
        while self.peek() != ('c', '}'):
            if self.peek() == ('c', '['):
                self.take(); key = self.expr(); self.expect(']'); self.expect('=')
                d[key] = self.expr()
            elif self.peek()[0] == 'i' and self.t[self.i+1] == ('c', '='):
                key = self.take()[1]; self.take(); d[key] = self.expr()
            else:
                arr.append(self.expr())
            if self.peek() in (('c', ','), ('c', ';')): self.take()
        self.take()
        if d and not arr: return d
        if arr and not d: return arr
        # mixed: positional 1..n into dict
        for n, a in enumerate(arr, 1): d[n] = a
        return d

def parse_lit(s): return P(tokens(s)).expr()

def at(lst, n):
    """1-based positional field of a parsed record (list with Nones)."""
    if isinstance(lst, list): return lst[n-1] if n-1 < len(lst) else None
    if isinstance(lst, dict): return lst.get(n)
    return None

# ---------------------------------------------------------------- base DBs
def read_db(path):
    out = {}
    for line in open(path, encoding='utf-8'):
        m = re.match(r'^\[(\d+)\] = (\{.*\}),\s*$', line)
        if m:
            try: out[int(m.group(1))] = parse_lit(m.group(2))
            except AssertionError as e: print('skip', path, m.group(1), str(e)[:80])
    return out

def read_fix(path):
    s = open(path, encoding='utf-8').read()
    out = {}
    # every "return {" inside a Load function; merge
    for m in re.finditer(r'function [A-Za-z]+:Load\w*\(\)(.*?)\n\s*return \{', s, re.S):
        p = P(tokens(s[m.end()-1:]))
        t = p.table()
        for k, v in t.items():
            if isinstance(k, int): out.setdefault(k, {}).update(v)
    return out

QK = dict(name=1, startedBy=2, finishedBy=3, requiredLevel=4, questLevel=5, requiredRaces=6,
          requiredClasses=7, objectivesText=8, preQuestGroup=12, preQuestSingle=13, zoneOrSort=17,
          exclusiveTo=16, breadcrumbForQuestId=27, specialFlags=24, nextQuestInChain=22)
NK = dict(name=1, spawns=7, zoneID=9, questStarts=10, questEnds=11, friendlyToFaction=13, subName=14)
OK_ = dict(name=1, questStarts=2, questEnds=3, spawns=4, zoneID=5)

def apply_fix(base, fix, keys):
    rec = list(base) if isinstance(base, list) else ([None]*40)
    rec += [None] * (40 - len(rec))
    for k, v in fix.items():
        name = str(k).split('.')[-1]
        add = remove = False
        if name.endswith('_add'): name, add = name[:-4], True
        if name.endswith('_remove'): name, remove = name[:-7], True
        if name not in keys: continue
        i = keys[name] - 1
        if (add or remove) and isinstance(v, list) and all(isinstance(x, int) for x in v):
            have = list(rec[i] or []) if isinstance(rec[i], list) else []
            rec[i] = (have + [x for x in v if x not in have]) if add else [x for x in have if x not in v]
        elif (add or remove) and isinstance(v, dict):
            have = dict(rec[i]) if isinstance(rec[i], dict) else {}
            if add: have.update(v)
            else:
                for kk in v: have.pop(kk, None)
            rec[i] = have
        elif add or remove:
            cur = rec[i] or []
            cur = list(cur) + [None] * 3
            v = list(v) if isinstance(v, list) else [v]
            for j, part in enumerate(v):
                if part is None: continue
                have = list(cur[j] or [])
                if add: have += [x for x in part if x not in have]
                else: have = [x for x in have if x not in part]
                cur[j] = have
            rec[i] = cur[:3]
        else:
            rec[i] = v
    return rec

quests = read_db(os.path.join(QDB, 'foreverQuestDB.lua'))
npcs = read_db(os.path.join(QDB, 'foreverNpcDB.lua'))
objs = read_db(os.path.join(QDB, 'foreverObjectDB.lua'))
for f in ('foreverBaseQuest.lua', 'foreverQuestFixes.lua'):
    for qid, fx in read_fix(os.path.join(QDB, f)).items():
        quests[qid] = apply_fix(quests.get(qid), fx, QK)
for f in ('foreverBaseNpc.lua', 'foreverNPCFixes.lua'):
    for nid, fx in read_fix(os.path.join(QDB, f)).items():
        npcs[nid] = apply_fix(npcs.get(nid), fx, NK)
for f in ('foreverBaseObject.lua', 'foreverObjectFixes.lua'):
    for oid, fx in read_fix(os.path.join(QDB, f)).items():
        objs[oid] = apply_fix(objs.get(oid), fx, OK_)
print('quests', len(quests), 'npcs', len(npcs), 'objects', len(objs))

# ---------------------------------------------------------------- zones
ZONE_SYM = {}
for m in re.finditer(r'^\s*([A-Z_0-9]+) = (\d+),', open(os.path.join(QDB, 'zones.lua'), encoding='utf-8').read(), re.M):
    ZONE_SYM.setdefault(int(m.group(2)), m.group(1))
SYM_ZONE = {v: k for k, v in ZONE_SYM.items()}
SMALL = {'OF', 'THE', 'AND'}
# world-map zones (outdoor zones and cities) of the two old continents
OUTDOOR = {1,3,4,8,10,11,12,28,33,36,38,40,41,44,45,46,47,51,85,130,139,267,1497,1519,1537,
           14,15,16,17,141,148,215,331,357,361,400,405,406,440,490,493,618,1377,1637,1638,1657,
           16591}   # Forever: Riverglades
SPECIAL = {490: "Un'Goro Crater"}
def zone_name(zid):
    if zid in SPECIAL: return SPECIAL[zid]
    sym = ZONE_SYM.get(zid)
    if not sym: return None
    words = sym.split('_')
    out = [w.capitalize() if (i == 0 or w not in SMALL) else w.lower() for i, w in enumerate(words)]
    return ' '.join(out)

def spot(rec, spawn_idx):
    sp = at(rec, spawn_idx)
    if not isinstance(sp, dict) or not sp: return None
    # prefer a world-map zone, then the fewest spawns
    best = None
    for z, pts in sp.items():
        if isinstance(z, Sym): z = SYM_ZONE.get(str(z).split('.')[-1])
        if not isinstance(z, int) or not pts: continue
        p = pts[0]
        if not isinstance(p, list) or len(p) < 2 or p[0] is None or p[0] < 0: continue
        cand = (z, round(p[0], 1), round(p[1], 1), len(pts))
        rank = (z not in OUTDOOR, len(pts))
        if best is None or rank < best[0]: best = (rank, cand)
    return best and best[1]

# ---------------------------------------------------------------- faction
HORDE_BITS, ALLY_BITS = 2 | 16 | 32 | 128, 1 | 4 | 8 | 64
def faction(rec):
    r = at(rec, 6)
    def syms(x):
        if isinstance(x, tuple) and x[0] == 'op': return syms(x[2]) + syms(x[3])
        return [x]
    parts = syms(r)
    if all(isinstance(p, int) for p in parts):
        v = sum(parts) if parts else 0
        v &= 0xFFFF_FFFF
        h, a = v & HORDE_BITS, v & ALLY_BITS
        if v == 0 or (h and a): return 'B'
        if h: return 'H'
        if a: return 'A'
        # Forever-only races above bit 31 were masked; look at the raw bits
        raw = sum(parts)
        return 'H' if raw & (1 << 33) else ('A' if raw & (1 << 32) else 'B')
    names = ' '.join(str(p) for p in parts)
    if 'NONE' in names or 'ALL' in names and 'ALL_' not in names: return 'B'
    if 'HORDE' in names or any(x in names for x in ('ORC', 'UNDEAD', 'TAUREN', 'TROLL')): return 'H'
    if 'ALLIANCE' in names or any(x in names for x in ('HUMAN', 'DWARF', 'NIGHT_ELF', 'GNOME')): return 'A'
    return 'B'

# ---------------------------------------------------------------- one quest as a row
def first_text(x):
    if isinstance(x, list): return next((t for t in x if isinstance(t, str) and t), None)
    return x if isinstance(x, str) else None

def row(qid):
    rec = quests.get(qid)
    if rec is None: return {'id': qid, 'missing': True}
    r = {'id': qid, 'name': at(rec, 1), 'level': at(rec, 4), 'qlevel': at(rec, 5), 'faction': faction(rec)}
    sb = at(rec, 2) or []
    sb = list(sb) + [None] * 3
    npc_ids, obj_ids, item_ids = sb[0] or [], sb[1] or [], sb[2] or []
    if npc_ids:
        # the starter whose spawn we know, friendly first
        cands = []
        for nid in npc_ids:
            n = npcs.get(nid)
            if not n: continue
            s = spot(n, 7)
            cands.append((s is None, nid, n, s))
        cands.sort(key=lambda c: c[0])
        if cands:
            _, nid, n, s = cands[0]
            r['giver'] = at(n, 1)
            if s: r['zone'], r['x'], r['y'], r['zid'] = zone_name(s[0]) or s[0], s[1], s[2], s[0]
            if s and zone_name(s[0]) is None: r['zone_unknown'] = s[0]
            if len(npc_ids) > 1: r['givers'] = [at(npcs[i], 1) for i in npc_ids if i in npcs]
    elif obj_ids:
        o = objs.get(obj_ids[0])
        r['giver'], r['start'] = (at(o, 1) if o else '?'), 'object'
        s = spot(o, 4) if o else None
        if s: r['zone'], r['x'], r['y'], r['zid'] = zone_name(s[0]) or s[0], s[1], s[2], s[0]
    elif item_ids:
        r['start'], r['item'] = 'item', item_ids[0]
    fb = at(rec, 3) or []
    fb = list(fb) + [None] * 2
    end_npcs = fb[0] or []
    if end_npcs and not (npc_ids and end_npcs[0] in npc_ids):
        n = npcs.get(end_npcs[0])
        if n:
            r['turnin'] = at(n, 1)
            s = spot(n, 7)
            if s: r['tzone'], r['tx'], r['ty'] = zone_name(s[0]) or s[0], s[1], s[2]
    r['note'] = first_text(at(rec, 8))
    pg, ps = at(rec, 12) or [], at(rec, 13) or []
    if pg: r['preGroup'] = pg
    if ps: r['preSingle'] = ps
    return r

# ---------------------------------------------------------------- item names (item-started quests)
_items = None
def item_name(iid):
    global _items
    if _items is None:
        _items = {}
        for line in open(os.path.join(QDB, 'foreverItemDB.lua'), encoding='utf-8'):
            m = re.match(r"^\[(\d+)\] = \{'((?:\\.|[^'])*)'", line)
            if m: _items[int(m.group(1))] = m.group(2).replace("\\'", "'")
    return _items.get(iid, '?')

# ---------------------------------------------------------------- BossNav quests
# Rows that carry Season of Discovery IDs; WoW Forever has the classic quests.
REMAP = {78923: 971, 78924: 1198, 78926: 1275, 78925: 1199, 78920: 6922,
         80139: 2926, 80181: 2928, 80137: 2922, 80182: 2962, 80136: 2924, 80143: 2930,
         80180: 2929, 80134: 2843, 80133: 2842, 80132: 2841, 79985: 2904, 80153: 2951, 79986: 2945}
REMAP_BY_FACTION = {(78921, 'A'): 1200, (78922, 'H'): 6561}

src = open(QDATA, encoding='utf-8').read()
mine = []
dungeon = None
for line in src.splitlines():
    m = re.match(r'\s*\["([^"]+)"\] = \{\s*$', line)
    if m: dungeon = m.group(1)
    m = re.search(r'\{ id=(\d+), name="((?:\\.|[^"])*)", faction="(\w)"', line)
    if m:
        qid, fac = int(m.group(1)), m.group(3)
        qid = REMAP_BY_FACTION.get((qid, fac), REMAP.get(qid, qid))
        mine.append((dungeon, qid, m.group(2), fac))

def fac_ok(f, want): return want == 'B' or f == 'B' or f == want

def prereqs(qid, want):
    """(all of, any one of) for a quest, for a player of faction want."""
    r = row(qid)
    group = [p for p in r.get('preGroup', []) if fac_ok(row(p).get('faction', 'B'), want)]
    single = r.get('preSingle', [])
    opts = [s for s in single if fac_ok(row(s).get('faction', 'B'), want)] or single
    return group, opts

def chain_of(qid, want):
    """Earlier quests in the order to do them; follows the first option of an 'any one of'."""
    order, seen = [], set()
    def visit(q, depth):
        if q in seen or depth > 40: return
        seen.add(q)
        group, opts = prereqs(q, want)
        for p in group + opts[:1]: visit(p, depth + 1)
        order.append(q)
    visit(qid, 0)
    return order[:-1]

def lua_str(s): return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ') + '"'
def lua_list(xs): return '{' + ', '.join(str(x) for x in xs) + '}'

steps_needed = {}           # id -> set of factions it is used for
mains = {}                  # id -> dict(chain or chainA/chainH)
report = []
for dname, qid, name, fac in mine:
    if qid not in quests: report.append(f'NOT IN DB  {dname}: {name} [{qid}]'); continue
    if row(qid).get('name') != name: report.append(f'NAME DIFF  {dname}: {name} [{qid}] db={row(qid).get("name")}')
    wants = ['A', 'H'] if fac == 'B' else [fac]
    chains = {w: chain_of(qid, w) for w in wants}
    info = {}
    if len(wants) == 2 and chains['A'] != chains['H']:
        info['chainA'], info['chainH'] = chains['A'], chains['H']
    elif chains[wants[0]]:
        info['chain'] = chains[wants[0]]
    for w, c in chains.items():
        for s in c: steps_needed.setdefault(s, set()).add(w)
    if info: mains[qid] = info

# Steps the QuestieDB data leaves without a giver, from bindonforever.com.
OVERRIDE = {95786: dict(giver="Brother Nimetz", zone="Stranglethorn Vale", x=37.8, y=3.6, zid=33,
                        turnin="Loremaster Dibbs", tzone="Hillsbrad Foothills", tx=50.6, ty=57.1),
            # Riverglades steps QuestieDB has no giver for (bindonforever.com, 2026-11-28)
            95418: dict(giver="Clubtoe", zone="Riverglades", x=50.0, y=47.0, zid=16591,
                        turnin="Tran'gul", tzone="Riverglades", tx=59.5, ty=44.0),
            95601: dict(giver="Twilight Brute", zone="Riverglades", x=49.2, y=46.7, zid=16591,
                        turnin="Clubtoe", tzone="Riverglades", tx=50.0, ty=47.0),
            94889: dict(giver="Sergeant Riftan", zone="Riverglades", x=30.7, y=49.1, zid=16591)}

def step_lua(sid, wants):
    r = row(sid)
    r.update(OVERRIDE.get(sid, {}))
    want = 'B' if len(wants) == 2 else next(iter(wants))
    group, opts = prereqs(sid, want)
    f = [f'id={sid}', f'name={lua_str(r.get("name"))}', f'level={r.get("level") or 1}']
    if r.get('qlevel') and r.get('qlevel') != r.get('level'): f.append(f'qlevel={r["qlevel"]}')
    if r.get('start') == 'item':
        f += [f'giver={lua_str(item_name(r["item"]))}', 'start="item"']
    else:
        f.append(f'giver={lua_str(r.get("giver") or "unknown")}')
        if r.get('start') == 'object': f.append('start="object"')
    z = r.get('zone')
    if isinstance(z, str) and r.get('x') is not None and r.get('zid') in OUTDOOR:
        f += [f'zone={lua_str(z)}', f'x={r["x"]}', f'y={r["y"]}']
    elif z is not None:
        report.append(f'ZONE?  step {r.get("name")} [{sid}] giver {r.get("giver")} zone {z} {r.get("x")},{r.get("y")}')
        if isinstance(z, str): f.append(f'zone={lua_str(z)}')
    elif r.get('giver') and r.get('start') is None:
        # a giver with no spot on the world map stands inside a dungeon
        f.append('inside=true')
        report.append(f'INSIDE step {r.get("name")} [{sid}] giver {r.get("giver")}')
    if r.get('turnin'):
        f.append(f'turnin={lua_str(r["turnin"])}')
        if isinstance(r.get('tzone'), str): f += [f'tzone={lua_str(r["tzone"])}', f'tx={r["tx"]}', f'ty={r["ty"]}']
    if group: f.append(f'after={lua_list(group)}')
    if opts: f.append(f'afterAny={lua_list(opts)}')
    if r.get('note'): f.append(f'note={lua_str(r["note"])}')
    return '    [' + str(sid) + '] = { ' + ', '.join(f) + ' },'

L = []
L.append('-- Quest chains: the earlier quests a dungeon quest needs, as quest rows.')
L.append('-- GENERATED on 2026-11-27 from the QuestieDB WoW Forever data')
L.append('-- (github.com/Questie/QuestieDB: data/Forever quest/npc/object/item DBs plus')
L.append('-- the src/corrections/Forever base and fix files). Unverified in game.')
L.append('--')
L.append('-- STEPS   a quest row per chain step (fields as in BossNav_QuestData.lua),')
L.append('--         plus after = quests all needed first, afterAny = one of them')
L.append('-- CHAINS  dungeon quest ID -> its chain, first step first; A / H when a')
L.append('--         quest for both factions has a different chain for each')
L.append('-- NEEDS   dungeon quest ID -> its own { after, afterAny }')
L.append('local ADDON, ns = ...')
L.append('')
L.append('local STEPS = {')
for sid in sorted(steps_needed):
    L.append(step_lua(sid, steps_needed[sid]))
L.append('}')
L.append('')
L.append('local CHAINS = {')
for qid in sorted(mains):
    i = mains[qid]
    nm = row(qid).get('name')
    if 'chain' in i: L.append(f'    [{qid}] = {lua_list(i["chain"])},   -- {nm}')
    else: L.append(f'    [{qid}] = {{ A = {lua_list(i["chainA"])}, H = {lua_list(i["chainH"])} }},   -- {nm}')
L.append('}')
L.append('')
L.append('local NEEDS = {')
done_needs = set()
for dname, qid, name, fac in sorted(mine, key=lambda m: m[1]):
    if qid not in quests or qid in done_needs: continue
    done_needs.add(qid)
    group, opts = prereqs(qid, fac)
    if group or opts:
        parts = []
        if group: parts.append(f'after={lua_list(group)}')
        if opts: parts.append(f'afterAny={lua_list(opts)}')
        L.append(f'    [{qid}] = {{ {", ".join(parts)} }},   -- {name}')
L.append('}')
L.append('')
L.append('-- shared with the other BossNav files')
L.append('ns.QUEST_CHAIN_STEPS = STEPS')
L.append('ns.QUEST_CHAINS = CHAINS')
L.append('ns.QUEST_NEEDS = NEEDS')
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')

print('\n'.join(report))
print('steps', len(steps_needed), 'chains', len(mains))
for dname, qid, name, fac in mine:
    if qid in mains:
        i = mains[qid]
        for k in ('chain', 'chainA', 'chainH'):
            if k in i: print(f'{dname} | {name} {k}: ' + ' > '.join(str(row(s).get('name')) for s in i[k]))
