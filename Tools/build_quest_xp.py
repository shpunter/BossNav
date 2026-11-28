# Builds Quests/BossNav_QuestXP.lua: the experience each quest in
# BossNav_QuestData.lua and BossNav_QuestChains.lua gives, from QuestieDB.
#
# 1. Download into one empty folder
#    (raw.githubusercontent.com/Questie/QuestieDB/master/support/Forever/QuestXP/...):
#      xpDB-traces.lua   XP measured on WoW Forever by Questie users (used first)
#      xpDB-classic.lua  classic XP, for quests the traces don't have
# 2. python -I Tools/build_quest_xp.py <that folder> Quests Quests/BossNav_QuestXP.lua
import re, sys, os
sys.stdout.reconfigure(encoding='utf-8')
SRC, QDIR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

def read(path, pattern):
    out = {}
    for m in re.finditer(pattern, open(path, encoding='utf-8').read(), re.M):
        out[int(m.group(1))] = (int(m.group(2)), int(m.group(3)))
    return out

classic = read(os.path.join(SRC, 'xpDB-classic.lua'), r'^\s*\[(\d+)\] = \{(-?\d+), (\d+)\}')
traces = read(os.path.join(SRC, 'xpDB-traces.lua'), r'^QuestXP\.db\[(\d+)\] = \{(-?\d+), (\d+)\}')

# New Forever quests QuestieDB has no XP for: { quest level, XP } from
# foreverchanges.pro/quest/<id> ("Experience:") or, marked wp, from
# wow-pilot.cc/quest/<id> (checked 2026-11-27; the two sites agree where both have it).
WEB = {
    92401: (22, 4600), 92415: (22, 6200, 'wp'), 92421: (22, 4600), 92422: (22, 4600),
    92456: (33, 9400), 92457: (33, 9400), 92458: (33, 9400), 92489: (33, 9400),
    92753: (18, 2700, 'wp'), 95189: (22, 6200), 95195: (22, 6200), 95204: (22, 5450),
    95216: (22, 5450), 95250: (21, 3900), 95646: (31, 6150), 95647: (31, 4900, 'wp'),
    95663: (31, 550, 'wp'), 95664: (31, 1400, 'wp'), 95682: (31, 6950), 95697: (31, 6950),
    95772: (31, 6150, 'wp'), 95775: (40, 8450, 'wp'), 95776: (38, 9500), 95787: (40, 8450),
    95788: (40, 8450, 'wp'), 95789: (40, 10450), 95791: (40, 10450), 96393: (16, 3200),
    96394: (15, 2300), 96395: (15, 2300), 96403: (15, 2950), 96774: (40, 8800),
    96800: (38, 6750), 96984: (33, 9400), 96986: (33, 9400), 96987: (33, 9400),
    96988: (33, 9400), 97130: (40, 10450), 97288: (21, 3450, 'wp'), 98423: (16, 2550),
    # Krol'dok Stronghold (foreverchanges.pro, 2026-11-28)
    94968: (45, 11500), 94972: (44, 11050), 94975: (42, 8200), 94982: (45, 11500),
    94983: (42, 10200), 94984: (44, 11050), 96771: (45, 11500),
}

ids, names = [], {}
for f, pat in (('BossNav_QuestData.lua', r'\{ id=(\d+), name="((?:\\.|[^"])*)"'),
               ('BossNav_QuestChains.lua', r'\{ id=(\d+), name="((?:\\.|[^"])*)"')):
    for m in re.finditer(pat, open(os.path.join(QDIR, f), encoding='utf-8').read()):
        qid = int(m.group(1))
        if qid not in names: ids.append(qid)
        names[qid] = m.group(2)

rows, missing = [], []
for qid in sorted(set(ids)):
    v = traces.get(qid) or classic.get(qid) or WEB.get(qid)
    src = '' if qid in traces else (' (classic)' if qid in classic else
          (' (wow-pilot.cc)' if len(WEB.get(qid, ())) > 2 else ' (foreverchanges.pro)'))
    if v and v[0] > 0 and v[1] > 0:
        rows.append(f'    [{qid}] = {{{v[0]}, {v[1]}}},   -- {names[qid]}' + src)
    else:
        missing.append(f'{qid} {names[qid]}')

L = ['-- Experience per quest: [quest ID] = { quest level, full XP }.',
     '-- GENERATED on 2026-11-27 by Tools/build_quest_xp.py from QuestieDB',
     "-- (support/Forever/QuestXP): XP measured on WoW Forever where known,",
     '-- else the classic value (classic), else read off a quest site (named).',
     '-- Do not edit by hand.',
     'local ADDON, ns = ...', '', 'local QUEST_XP = {'] + rows + ['}', '',
     '-- shared with the other BossNav files', 'ns.QUEST_XP = QUEST_XP']
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print(len(rows), 'quests with XP,', sum(1 for q in set(ids) if q in traces), 'from Forever traces')
print('no XP data:', len(missing)); print('\n'.join(missing))
