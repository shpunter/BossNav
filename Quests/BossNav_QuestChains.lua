-- Quest chains: the earlier quests a dungeon quest needs, as quest rows.
-- GENERATED on 2026-11-27 from the QuestieDB WoW Forever data
-- (github.com/Questie/QuestieDB: data/Forever quest/npc/object/item DBs plus
-- the src/corrections/Forever base and fix files). Unverified in game.
--
-- STEPS   a quest row per chain step (fields as in BossNav_QuestData.lua),
--         plus after = quests all needed first, afterAny = one of them
-- CHAINS  dungeon quest ID -> its chain, first step first; A / H when a
--         quest for both factions has a different chain for each
-- NEEDS   dungeon quest ID -> its own { after, afterAny }
local ADDON, ns = ...

local STEPS = {
    [65] = { id=65, name="The Defias Brotherhood", level=14, qlevel=18, giver="Gryan Stoutmantle", zone="Westfall", x=56.3, y=47.5, turnin="Wiley the Black", tzone="Redridge Mountains", tx=21.4, ty=45.4, note="Gryan Stoutmantle wants you to talk to Wiley in Lakeshire." },
    [132] = { id=132, name="The Defias Brotherhood", level=14, qlevel=18, giver="Wiley the Black", zone="Redridge Mountains", x=21.4, y=45.4, turnin="Gryan Stoutmantle", tzone="Westfall", tx=56.3, ty=47.5, afterAny={65}, note="Take Wiley's Note to Gryan Stoutmantle in Westfall." },
    [135] = { id=135, name="The Defias Brotherhood", level=14, qlevel=18, giver="Gryan Stoutmantle", zone="Westfall", x=56.3, y=47.5, turnin="Master Mathias Shaw", tzone="Stormwind City", tx=78.3, ty=70.7, afterAny={132}, note="Take Wiley's Note to Mathias Shaw in Stormwind." },
    [141] = { id=141, name="The Defias Brotherhood", level=14, qlevel=18, giver="Master Mathias Shaw", zone="Stormwind City", x=78.3, y=70.7, turnin="Gryan Stoutmantle", tzone="Westfall", tx=56.3, ty=47.5, afterAny={135}, note="Take Shaw's report to Gryan Stoutmantle in Westfall." },
    [142] = { id=142, name="The Defias Brotherhood", level=14, qlevel=18, giver="Gryan Stoutmantle", zone="Westfall", x=56.3, y=47.5, afterAny={141}, note="Track down the Defias Messenger in Westfall and bring his message to Stoutmantle." },
    [155] = { id=155, name="The Defias Brotherhood", level=14, qlevel=18, giver="The Defias Traitor", zone="Westfall", x=55.7, y=47.5, turnin="Gryan Stoutmantle", tzone="Westfall", tx=56.3, ty=47.5, afterAny={142}, note="Escort the Defias Traitor to the secret hideout of the Defias Brotherhood. Once the Defias Traitor shows you where VanCleef and his men are hiding out, return to Gryan Stoutmantle with the information." },
    [203] = { id=203, name="The Second Rebellion", level=30, qlevel=33, giver="Sergeant Yohwa", zone="Stranglethorn Vale", x=38.0, y=3.3, note="Kill 15 Kurzen Jungle Fighters." },
    [204] = { id=204, name="Bad Medicine", level=30, qlevel=34, giver="Sergeant Yohwa", zone="Stranglethorn Vale", x=38.0, y=3.3, note="Bring 7 Jungle Remedies and 1 Venom Fern Extract to Sergeant Yohwa at the Rebel Camp." },
    [205] = { id=205, name="Troll Witchery", level=30, qlevel=40, giver="Brother Nimetz", zone="Stranglethorn Vale", x=37.8, y=3.6, afterAny={207}, note="Bring 4 Skullsplitter Fetishes to Brother Nimetz at the Rebel Camp." },
    [207] = { id=207, name="Kurzen's Mystery", level=30, qlevel=38, giver="Brother Nimetz", zone="Stranglethorn Vale", x=37.8, y=3.6, after={204, 203}, note="Find the 4 tablets and bring their legends back to Brother Nimetz." },
    [261] = { id=261, name="Down the Scarlet Path", level=34, qlevel=39, giver="Brother Anton", zone="Desolace", x=66.5, y=7.9, note="Destroy 30 Undead Ravagers, then return to Brother Anton at Nijel's Point." },
    [275] = { id=275, name="Blisters on The Land", level=20, qlevel=26, giver="Rethiel the Greenwarden", zone="Wetlands", x=56.4, y=40.4, afterAny={277}, note="Kill 8 Fen Creepers, then return to Rethiel the Greenwarden in the Wetlands." },
    [276] = { id=276, name="Tramping Paws", level=20, qlevel=21, giver="Rethiel the Greenwarden", zone="Wetlands", x=56.4, y=40.4, note="Kill 15 Mosshide Gnolls and 10 Mosshide Mongrels, then return to Rethiel the Greenwarden in the Wetlands." },
    [277] = { id=277, name="Fire Taboo", level=20, qlevel=23, giver="Rethiel the Greenwarden", zone="Wetlands", x=56.4, y=40.4, afterAny={276}, note="Bring Rethiel the Greenwarden 9 Crude Flints." },
    [303] = { id=303, name="The Dark Iron War", level=22, qlevel=30, giver="Motley Garmason", zone="Wetlands", x=49.7, y=18.2, note="Motley Garmason at Dun Modr wants you to kill 10 Dark Iron Dwarves, 5 Dark Iron Tunnelers, 5 Dark Iron Saboteurs and 5 Dark Iron Demolitionists." },
    [356] = { id=356, name="Rear Guard Patrol", level=6, qlevel=11, giver="Deathguard Linnea", zone="Tirisfal Glades", x=65.5, y=60.2, note="Kill 8 Bleeding Horrors and 8 Wandering Spirits, then report back to Linnea at her camp." },
    [373] = { id=373, name="The Unsent Letter", level=16, qlevel=22, giver="An Unsent Letter", start="item", turnin="Baros Alexston", tzone="Stormwind City", tx=57.7, ty=47.9, note="Deliver the Letter to the City Architect to Baros Alexston in Stormwind." },
    [389] = { id=389, name="Bazil Thredd", level=16, qlevel=22, giver="Baros Alexston", zone="Stormwind City", x=57.7, y=47.9, turnin="Warden Thelwater", tzone="Stormwind City", tx=51.5, ty=69.4, afterAny={373}, note="Speak with Warden Thelwater in the Stockade." },
    [447] = { id=447, name="A Recipe For Death", level=9, qlevel=12, giver="Apothecary Renferrel", zone="Silverpine Forest", x=42.8, y=40.9, turnin="Master Apothecary Faranell", tzone="Undercity", tx=48.8, ty=69.3, note="Collect 6 Grizzled Bear Hearts and 6 samples of Skittering Blood and deliver them to Master Apothecary Faranell in the Undercity." },
    [450] = { id=450, name="A Recipe For Death", level=9, qlevel=15, giver="Master Apothecary Faranell", zone="Undercity", x=48.8, y=69.3, turnin="Apothecary Renferrel", tzone="Silverpine Forest", tx=42.8, ty=40.9, afterAny={447}, note="Retrieve Apothecary Berard's journal from Pyrewood Village and take it to Apothecary Renferrel at the Sepulcher." },
    [451] = { id=451, name="A Recipe For Death", level=9, qlevel=18, giver="Apothecary Renferrel", zone="Silverpine Forest", x=42.8, y=40.9, turnin="Master Apothecary Faranell", tzone="Undercity", tx=48.8, ty=69.3, afterAny={450}, note="Bring 6 samples of Lake Creeper Moss, 6 samples of Lake Skulker Moss and a Hardened Tumor to Master Apothecary Faranell in the Undercity." },
    [484] = { id=484, name="Young Crocolisk Skins", level=18, qlevel=22, giver="James Halloran", zone="Wetlands", x=8.6, y=55.7, note="Obtain 4 Young Crocolisk Skins for James Halloran in Menethil Harbor." },
    [544] = { id=544, name="Prison Break In", level=30, qlevel=33, giver="Magus Wordeen Voidglare", zone="Hillsbrad Foothills", x=61.6, y=20.9, note="Find the traitors and recover their artifacts, then return to Magus Voidglare in Tarren Mill." },
    [545] = { id=545, name="Dalaran Patrols", level=30, qlevel=35, giver="Magus Wordeen Voidglare", zone="Hillsbrad Foothills", x=61.6, y=20.9, after={544, 93680}, note="Kill 6 Dalaran Summoners and 12 Elemental Slaves, then return to Magus Voidglare in Tarren Mill." },
    [629] = { id=629, name="The Vile Reef", level=30, qlevel=37, giver="Kin'weelay", zone="Stranglethorn Vale", x=32.3, y=27.7, note="Bring a Tablet Shard to Kin'weelay at the Grom'gol Base Camp." },
    [707] = { id=707, name="Ironband Wants You!", level=30, qlevel=37, giver="Prospector Stormpike", zone="Ironforge", x=74.6, y=11.7, turnin="Prospector Ironband", tzone="Loch Modan", tx=65.9, ty=65.6, note="Speak with Prospector Ironband at Ironband's Excavation Site in Loch Modan." },
    [720] = { id=720, name="A Sign of Hope", level=35, giver="Crumpled Map", start="object", zone="Badlands", x=53.0, y=33.9, turnin="Prospector Ryedol", tzone="Badlands", tx=53.4, ty=43.4, note="Find Prospector Ryedol and let him know Hammertoe Grez is alive." },
    [721] = { id=721, name="A Sign of Hope", level=35, giver="Prospector Ryedol", zone="Badlands", x=53.4, y=43.4, turnin="Hammertoe Grez", tzone="Loch Modan", tx=37.3, ty=85.8, afterAny={720}, note="Find Hammertoe Grez in Uldaman." },
    [722] = { id=722, name="Amulet of Secrets", level=35, qlevel=40, giver="Hammertoe Grez", zone="Loch Modan", x=37.3, y=85.8, afterAny={721}, note="Find Hammertoe's Amulet and return it to him in Uldaman." },
    [723] = { id=723, name="Prospect of Faith", level=35, qlevel=40, giver="Hammertoe Grez", zone="Loch Modan", x=37.3, y=85.8, turnin="Prospector Ryedol", tzone="Badlands", tx=53.4, ty=43.4, afterAny={722}, note="Take Hammertoe's Amulet to Prospector Ryedol in the Badlands." },
    [724] = { id=724, name="Prospect of Faith", level=35, qlevel=40, giver="Prospector Ryedol", zone="Badlands", x=53.4, y=43.4, turnin="Historian Karnik", tzone="Ironforge", tx=77.5, ty=11.8, afterAny={723}, note="Take Hammertoe's Amulet to Historian Karnik in Ironforge." },
    [725] = { id=725, name="Passing Word of a Threat", level=35, qlevel=40, giver="Historian Karnik", zone="Ironforge", x=77.5, y=11.8, turnin="Advisor Belgrum", tzone="Ironforge", tx=77.3, ty=9.7, afterAny={724}, note="Find Advisor Belgrum and give him his note." },
    [726] = { id=726, name="Passing Word of a Threat", level=35, qlevel=40, giver="Advisor Belgrum", zone="Ironforge", x=77.3, y=9.7, turnin="Historian Karnik", tzone="Ironforge", tx=77.5, ty=11.8, afterAny={725}, note="Speak to Historian Karnik." },
    [738] = { id=738, name="Find Agmond", level=30, qlevel=38, giver="Prospector Ironband", zone="Loch Modan", x=65.9, y=65.6, afterAny={707}, note="Find Agmond." },
    [739] = { id=739, name="Murdaloc", level=30, qlevel=42, giver="Battered Dwarven Skeleton", start="object", zone="Badlands", x=50.9, y=62.4, turnin="Prospector Ironband", tzone="Loch Modan", tx=65.9, ty=65.6, afterAny={738}, note="Slay Agmond's killer, Murdaloc." },
    [762] = { id=762, name="An Ambassador of Evil", level=35, qlevel=44, giver="Historian Karnik", zone="Ironforge", x=77.5, y=11.8, turnin="Advisor Belgrum", tzone="Ironforge", tx=77.3, ty=9.7, afterAny={726}, note="Kill Ambassador Infernus in Angor Fortress and bring proof of his death to Advisor Belgrum in Ironforge." },
    [838] = { id=838, name="Scholomance", level=55, giver="High Executor Derrington", zone="Tirisfal Glades", x=83.1, y=68.9, turnin="Apothecary Dithers", tzone="Tirisfal Glades", tx=83.3, ty=69.2, afterAny={5098}, note="Speak with Apothecary Dithers at the Bulwark, Western Plaguelands." },
    [865] = { id=865, name="Raptor Horns", level=13, qlevel=18, giver="Mebok Mizzyrix", zone="The Barrens", x=62.4, y=37.6, note="Gather 5 Intact Raptor Horns from Sunscale Scytheclaws, and bring them to Mebok Mizzyrix in Ratchet." },
    [870] = { id=870, name="The Forgotten Pools", level=10, qlevel=13, giver="Tonga Runetotem", zone="The Barrens", x=52.3, y=31.9, note="Report back to Tonga Runetotem with your findings." },
    [877] = { id=877, name="The Stagnant Oasis", level=10, qlevel=16, giver="Tonga Runetotem", zone="The Barrens", x=52.3, y=31.9, afterAny={870}, note="Return to Tonga at The Crossroads, after investigating the Stagnant Oasis." },
    [880] = { id=880, name="Altered Beings", level=10, qlevel=16, giver="Tonga Runetotem", zone="The Barrens", x=52.3, y=31.9, afterAny={877}, note="Bring 8 Altered Snapjaw Shells to Tonga Runetotem at the Crossroads." },
    [964] = { id=964, name="Skeletal Fragments", level=55, qlevel=57, giver="Apothecary Dithers", zone="Tirisfal Glades", x=83.3, y=69.2, afterAny={838}, note="Bring 15 Skeletal Fragments to Apothecary Dithers at the Bulwark, Western Plaguelands." },
    [1052] = { id=1052, name="Down the Scarlet Path", level=34, qlevel=40, giver="Brother Anton", zone="Desolace", x=66.5, y=7.9, turnin="Raleigh the Devout", tzone="Hillsbrad Foothills", tx=51.5, ty=58.4, afterAny={261}, note="Take Brother Anton's Letter of Commendation to Raleigh the Devout in Southshore." },
    [1100] = { id=1100, name="Lonebrow's Journal", level=29, qlevel=34, giver="Henrig Lonebrow's Journal", start="item", turnin="Falfindel Waywarder", tzone="Feralas", tx=89.6, ty=46.6, note="Read Henrig Lonebrow's Journal." },
    [1109] = { id=1109, name="Going, Going, Guano!", level=30, qlevel=33, giver="Master Apothecary Faranell", zone="Undercity", x=48.8, y=69.3, note="Bring 1 pile of Kraul Guano to Master Apothecary Faranell in the Undercity." },
    [1149] = { id=1149, name="Test of Faith", level=25, qlevel=26, giver="Dorn Plainstalker", zone="Thousand Needles", x=54.0, y=41.5, note="If you have faith, leap from the planks overlooking Thousand Needles." },
    [1150] = { id=1150, name="Test of Endurance", level=25, qlevel=30, giver="Dorn Plainstalker", zone="Thousand Needles", x=54.0, y=41.5, afterAny={1149}, note="Bring Grenka's Claw to Dorn Plainstalker in Thousand Needles." },
    [1151] = { id=1151, name="Test of Strength", level=25, qlevel=30, giver="Dorn Plainstalker", zone="Thousand Needles", x=54.0, y=41.5, afterAny={1150}, note="Bring Fragments of Rok'Alim to Dorn Plainstalker in Thousand Needles." },
    [1152] = { id=1152, name="Test of Lore", level=25, qlevel=30, giver="Dorn Plainstalker", zone="Thousand Needles", x=54.0, y=41.5, turnin="Braug Dimspirit", tzone="Stonetalon Mountains", tx=78.8, ty=45.7, afterAny={1151}, note="Find Braug Dimspirit near the entrance to Talondeep Path in Stonetalon Mountains." },
    [1154] = { id=1154, name="Test of Lore", level=25, qlevel=30, giver="Braug Dimspirit", zone="Stonetalon Mountains", x=78.8, y=45.7, afterAny={1152}, note="Find the Legacy of the Aspects and return it to Braug Dimspirit near the entrance to Talondeep Path in Stonetalon Mountains." },
    [1159] = { id=1159, name="Test of Lore", level=25, qlevel=30, giver="Braug Dimspirit", zone="Stonetalon Mountains", x=78.8, y=45.7, turnin="Parqual Fintallas", tzone="Undercity", tx=57.8, ty=65.4, afterAny={6627}, note="Find Parqual Fintallas in Undercity." },
    [1198] = { id=1198, name="In Search of Thaelrid", level=18, qlevel=24, giver="Dawnwatcher Shaedlass", zone="Darnassus", x=55.4, y=25.0, turnin="Argent Guard Thaelrid", note="Seek out Argent Guard Thaelrid in Blackfathom Deeps." },
    [1424] = { id=1424, name="Pool of Tears", level=38, qlevel=43, giver="Fel'zerul", zone="Swamp of Sorrows", x=47.9, y=54.8, note="Fel'zerul in Stonard wants you to gather 10 Atal'ai Artifacts." },
    [1429] = { id=1429, name="The Atal'ai Exile", level=38, qlevel=44, giver="Fel'zerul", zone="Swamp of Sorrows", x=47.9, y=54.8, turnin="Atal'ai Exile", tzone="The Hinterlands", tx=33.8, ty=75.2, afterAny={1424}, note="Bring the Bundle of Atal'ai Artifacts to the Atal'ai Exile in the Hinterlands." },
    [1444] = { id=1444, name="Return to Fel'Zerul", level=38, qlevel=44, giver="Atal'ai Exile", zone="The Hinterlands", x=33.8, y=75.2, turnin="Fel'zerul", tzone="Swamp of Sorrows", tx=47.9, ty=54.8, afterAny={1429}, note="Return to Fel'Zerul in Stonard." },
    [1448] = { id=1448, name="In Search of The Temple", level=38, qlevel=43, giver="Brohann Caskbelly", zone="Stormwind City", x=69.5, y=40.4, note="Brohann Caskbelly in Stormwind wants you to search for the Temple of Atal'Hakkar." },
    [1449] = { id=1449, name="To The Hinterlands", level=38, qlevel=43, giver="Brohann Caskbelly", zone="Stormwind City", x=69.5, y=40.4, turnin="Falstad Wildhammer", tzone="The Hinterlands", tx=11.8, ty=46.8, afterAny={1448}, note="Speak with High Thane Falstad Wildhammer at Aerie Peak in the Hinterlands." },
    [1450] = { id=1450, name="Gryphon Master Talonaxe", level=38, qlevel=43, giver="Falstad Wildhammer", zone="The Hinterlands", x=11.8, y=46.8, turnin="Gryphon Master Talonaxe", tzone="The Hinterlands", tx=9.8, ty=44.5, afterAny={1449}, note="Speak with Gryphon Master Talonaxe inside the Aerie Peak Aviary." },
    [1451] = { id=1451, name="Rhapsody Shindigger", level=38, qlevel=43, giver="Gryphon Master Talonaxe", zone="The Hinterlands", x=9.8, y=44.5, turnin="Rhapsody Shindigger", tzone="The Hinterlands", tx=26.9, ty=48.6, afterAny={1450}, note="Seek out Rhapsody Shindigger in The Hinterlands." },
    [1452] = { id=1452, name="Rhapsody's Kalimdor Kocktail", level=38, qlevel=43, giver="Rhapsody Shindigger", zone="The Hinterlands", x=26.9, y=48.6, afterAny={1451}, note="Rhapsody Shindigger in The Hinterlands wants you to bring him 3 Roc Gizzards, 3 Groddoc Livers and 3 Ironfur Livers." },
    [1469] = { id=1469, name="Rhapsody's Tale", level=38, qlevel=43, giver="Rhapsody Shindigger", zone="The Hinterlands", x=26.9, y=48.6, turnin="Brohann Caskbelly", tzone="Stormwind City", tx=69.5, ty=40.4, afterAny={1452}, note="Bring the Atal'ai Tablet Fragment to Brohann Caskbelly in Stormwind." },
    [1489] = { id=1489, name="Hamuul Runetotem", level=12, qlevel=16, giver="Tonga Runetotem", zone="The Barrens", x=52.3, y=31.9, turnin="Arch Druid Hamuul Runetotem", tzone="Thunder Bluff", tx=78.6, ty=28.6, afterAny={880}, note="Speak with Hamuul Runetotem." },
    [1490] = { id=1490, name="Nara Wildmane", level=12, qlevel=16, giver="Arch Druid Hamuul Runetotem", zone="Thunder Bluff", x=78.6, y=28.6, turnin="Nara Wildmane", tzone="Thunder Bluff", tx=75.7, ty=31.6, afterAny={1489}, note="Speak with Nara Wildmane." },
    [1649] = { id=1649, name="The Tome of Valor", level=20, giver="Tome of Valor", start="item", turnin="Duthorian Rall", tzone="Stormwind City", tx=50.5, ty=47.5, note="Speak to Duthorian Rall in Stormwind." },
    [1650] = { id=1650, name="The Tome of Valor", level=20, qlevel=23, giver="Duthorian Rall", zone="Stormwind City", x=50.5, y=47.5, turnin="Daphne Stilwell", tzone="Westfall", tx=41.7, ty=89.2, afterAny={1649}, note="Find Daphne Stilwell in Westfall." },
    [1651] = { id=1651, name="The Tome of Valor", level=20, qlevel=25, giver="Daphne Stilwell", zone="Westfall", x=41.7, y=89.2, afterAny={1650}, note="Defend Daphne Stilwell from the Defias attack." },
    [1652] = { id=1652, name="The Tome of Valor", level=20, qlevel=25, giver="Daphne Stilwell", zone="Westfall", x=41.7, y=89.2, turnin="Duthorian Rall", tzone="Stormwind City", tx=50.5, ty=47.5, afterAny={1651}, note="Speak to Duthorian Rall in Stormwind." },
    [1653] = { id=1653, name="The Test of Righteousness", level=20, qlevel=21, giver="Duthorian Rall", zone="Stormwind City", x=50.5, y=47.5, turnin="Jordan Stilwell", tzone="Dun Morogh", tx=52.5, ty=36.9, afterAny={1652}, note="Speak to Jordan Stilwell in Ironforge" },
    [1698] = { id=1698, name="Yorus Barleybrew", level=20, giver="Wu Shen", zone="Stormwind City", x=80.5, y=59.9, turnin="Yorus Barleybrew", tzone="Redridge Mountains", tx=21.5, ty=44.7, note="Speak with Yorus Barleybrew." },
    [1699] = { id=1699, name="The Rethban Gauntlet", level=20, qlevel=22, giver="Yorus Barleybrew", zone="Redridge Mountains", x=21.5, y=44.7, afterAny={1698}, note="Enter the Rethban Caverns, reach the first fork, and return to Yorus Barleybrew within the time allowed." },
    [1702] = { id=1702, name="The Shieldsmith", level=20, qlevel=22, giver="Yorus Barleybrew", zone="Redridge Mountains", x=21.5, y=44.7, turnin="Furen Longbeard", tzone="Stormwind City", tx=64.6, ty=37.2, afterAny={1699}, note="Bring the Cask of Scalder to Furen Longbeard." },
    [1823] = { id=1823, name="Speak with Ruga", level=20, giver="Sorek", zone="Orgrimmar", x=80.4, y=32.4, turnin="Ruga Ragetotem", tzone="The Barrens", tx=44.7, ty=59.4, note="Speak with Ruga Ragetotem." },
    [1824] = { id=1824, name="Trial at the Field of Giants", level=20, giver="Ruga Ragetotem", zone="The Barrens", x=44.7, y=59.4, afterAny={1823}, note="Bring 5 twitching antennae to Ruga Ragetotem at Camp Taurajo" },
    [1825] = { id=1825, name="Speak with Thun'grim", level=20, giver="Ruga Ragetotem", zone="The Barrens", x=44.7, y=59.4, turnin="Thun'grim Firegaze", tzone="The Barrens", tx=57.2, ty=30.3, afterAny={1824}, note="Speak with Thun'grim Firegaze in the Barrens." },
    [1947] = { id=1947, name="Journey to the Marsh", level=30, qlevel=38, giver="Jennea Cannon", zone="Stormwind City", x=49.6, y=85.8, turnin="Tabetha", tzone="Dustwallow Marsh", tx=46.1, ty=57.1, note="Speak with Tabetha." },
    [1949] = { id=1949, name="Hidden Secrets", level=30, qlevel=38, giver="Tabetha", zone="Dustwallow Marsh", x=46.1, y=57.1, turnin="Magus Tirth", tzone="Thousand Needles", tx=78.3, ty=75.7, afterAny={1947}, note="Speak with Magus Tirth in the Shimmering Flats." },
    [1950] = { id=1950, name="Get the Scoop", level=30, giver="Magus Tirth", zone="Thousand Needles", x=78.3, y=75.7, afterAny={1949}, note="Find the phrase to Tirth's strongbox, then return to Tirth." },
    [2258] = { id=2258, name="Badlands Reagent Run", level=36, qlevel=39, giver="Jarkal Mossmeld", zone="Badlands", x=2.4, y=46.1, note="Bring 5 Buzzard Gizzards, 10 Crag Coyote Fangs, and 5 Rock Elemental Shards to Jarkal Mossmeld in Kargath, Badlands." },
    [2398] = { id=2398, name="The Lost Dwarves", level=35, qlevel=40, giver="Prospector Stormpike", zone="Ironforge", x=74.6, y=11.7, turnin="Baelog", note="Find Baelog in Uldaman." },
    [2500] = { id=2500, name="Badlands Reagent Run", level=36, qlevel=39, giver="Ghak Healtouch", zone="Loch Modan", x=37.1, y=49.4, note="Acquire the reagents Ghak Healtouch needs from the Badlands, then return to him in Thelsamar." },
    [2842] = { id=2842, name="Chief Engineer Scooty", level=25, qlevel=35, giver="Sovik", zone="Orgrimmar", x=75.5, y=25.4, turnin="Scooty", tzone="Stranglethorn Vale", tx=27.6, ty=77.5, note="Speak with Scooty in Booty Bay." },
    [2864] = { id=2864, name="Tran'rek", level=40, qlevel=45, giver="Krazek", zone="Stranglethorn Vale", x=26.9, y=77.2, turnin="Tran'rek", tzone="Tanaris", tx=51.6, ty=26.8, note="Speak with Tran'rek in Gadgetzan." },
    [2923] = { id=2923, name="Tinkmaster Overspark", level=20, qlevel=26, giver="Brother Sarno", zone="Stormwind City", x=51.0, y=48.4, turnin="Tinkmaster Overspark", tzone="Ironforge", tx=69.5, ty=50.3, note="Speak with Tinkmaster Overspark in Ironforge." },
    [2926] = { id=2926, name="Gnogaine", level=20, qlevel=27, giver="Ozzie Togglevolt", zone="Dun Morogh", x=45.9, y=49.4, afterAny={2927}, note="Use the Empty Leaden Collection Phial on Irradiated Invaders or Irradiated Pillagers to collect radioactive fallout. Once it is full, take it back to Ozzie Togglevolt in Kharanos." },
    [2927] = { id=2927, name="The Day After", level=20, qlevel=27, giver="Gnoarn", zone="Ironforge", x=69.2, y=50.5, turnin="Ozzie Togglevolt", tzone="Dun Morogh", tx=45.9, ty=49.4, note="Speak with Ozzie Togglevolt in Kharanos." },
    [2933] = { id=2933, name="Venom Bottles", level=40, qlevel=43, giver="Venom Bottle", start="object", zone="The Hinterlands", x=23.5, y=58.8, turnin="Apothecary Lydon", tzone="Hillsbrad Foothills", tx=61.4, ty=19.1, note="Bring a Venom Bottle to an apothecary in Tarren Mill." },
    [2934] = { id=2934, name="Undamaged Venom Sac", level=40, qlevel=45, giver="Apothecary Lydon", zone="Hillsbrad Foothills", x=61.4, y=19.1, afterAny={2933}, note="Bring an Undamaged Venom Sac to Apothecary Lydon in Tarren Mill." },
    [2935] = { id=2935, name="Consult Master Gadrin", level=40, qlevel=45, giver="Apothecary Lydon", zone="Hillsbrad Foothills", x=61.4, y=19.1, turnin="Master Gadrin", tzone="Durotar", tx=56.0, ty=74.7, afterAny={2934}, note="Speak with Master Gadrin in Sen'jin Village." },
    [2988] = { id=2988, name="Witherbark Cages", level=40, qlevel=45, giver="Gryphon Master Talonaxe", zone="The Hinterlands", x=9.8, y=44.5, note="Check the cages at the two Witherbark villages, then return to Gryphon Master Talonaxe." },
    [2989] = { id=2989, name="The Altar of Zul", level=40, qlevel=48, giver="Gryphon Master Talonaxe", zone="The Hinterlands", x=9.8, y=44.5, afterAny={2988}, note="Check the top of the Altar of Zul, then return to Gryphon Master Talonaxe." },
    [2990] = { id=2990, name="Thadius Grimshade", level=40, qlevel=47, giver="Gryphon Master Talonaxe", zone="The Hinterlands", x=9.8, y=44.5, turnin="Thadius Grimshade", tzone="Blasted Lands", tx=66.9, ty=19.5, afterAny={2989}, note="Bring Sharpbeak's Feather to Thadius Grimshade in the Blasted Lands." },
    [3380] = { id=3380, name="The Sunken Temple", level=46, qlevel=51, giver="Witch Doctor Uzer'i", zone="Feralas", x=74.4, y=43.4, turnin="Marvon Rivetseeker", tzone="Tanaris", tx=52.7, ty=45.9, note="Find Marvon Rivetseeker in Tanaris." },
    [3441] = { id=3441, name="Divine Retribution", level=40, qlevel=48, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, note="Listen as Kalaran Windblade tells his story." },
    [3442] = { id=3442, name="The Flawless Flame", level=40, qlevel=48, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, afterAny={3441}, note="Collect 4 Hearts of Flame and 4 globes of Golem Oil and return the items to Kalaran Windblade." },
    [3443] = { id=3443, name="Forging the Shaft", level=40, qlevel=48, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, afterAny={3442}, note="Bring 8 Thorium Plated Daggers to Kalaran Windblade." },
    [3444] = { id=3444, name="The Stone Circle", level=46, qlevel=51, giver="Marvon Rivetseeker", zone="Tanaris", x=52.7, y=45.9, afterAny={3380, 3445}, note="Retrieve the Stone Circle from Marvon Rivetseeker's workshop in Ratchet." },
    [3445] = { id=3445, name="The Sunken Temple", level=46, qlevel=51, giver="Angelas Moonbreeze", zone="Feralas", x=31.8, y=45.6, turnin="Marvon Rivetseeker", tzone="Tanaris", tx=52.7, ty=45.9, note="Find Marvon Rivetseeker in Tanaris." },
    [3452] = { id=3452, name="The Flame's Casing", level=40, qlevel=50, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, afterAny={3443}, note="Find and return a Symbol of Ragnaros to Kalaran Windblade." },
    [3453] = { id=3453, name="The Torch of Retribution", level=40, qlevel=50, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, afterAny={3452}, note="Wait for Kalaran Windblade to complete the Torch of Retribution." },
    [3454] = { id=3454, name="The Torch of Retribution", level=40, qlevel=50, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, afterAny={3453}, note="Take the Torch of Retribution." },
    [3462] = { id=3462, name="Squire Maltrake", level=40, qlevel=50, giver="Kalaran Windblade", zone="Searing Gorge", x=39.1, y=39.0, turnin="Squire Maltrake", tzone="Searing Gorge", tx=39.2, ty=39.0, afterAny={3454}, note="Speak with Squire Maltrake." },
    [3463] = { id=3463, name="Set Them Ablaze!", level=40, qlevel=52, giver="Squire Maltrake", zone="Searing Gorge", x=39.2, y=39.0, afterAny={3462}, note="Set the North, South, East, and West Sentry Towers on fire by using the Torch of Retribution inside each of the buildings. " },
    [3481] = { id=3481, name="Trinkets...", level=40, qlevel=50, giver="Hoard of the Black Dragonflight", start="object", zone="Searing Gorge", x=38.9, y=39.0, afterAny={3463}, note="Open the chest." },
    [3520] = { id=3520, name="Screecher Spirits", level=40, qlevel=44, giver="Yeh'kinya", zone="Tanaris", x=67.0, y=22.4, note="Capture the spirits of 3 screechers in Feralas, then return to Yeh'kinya in Steamwheedle Port." },
    [3523] = { id=3523, name="Scourge of the Downs", level=32, qlevel=37, giver="Belnistrasz", inside=true, note="If you agree to aid Belnistrasz, speak with him again and hand the Oathstone he gave you back to him." },
    [3527] = { id=3527, name="The Prophecy of Mosh'aru", level=40, qlevel=47, giver="Yeh'kinya", zone="Tanaris", x=67.0, y=22.4, afterAny={3520}, note="Bring the First and Second Mosh'aru Tablets to Yeh'kinya in Tanaris." },
    [3528] = { id=3528, name="The God Hakkar", level=40, qlevel=53, giver="Yeh'kinya", zone="Tanaris", x=67.0, y=22.4, afterAny={4787}, note="Bring the Filled Egg of Hakkar to Yeh'kinya in Tanaris." },
    [3701] = { id=3701, name="The Smoldering Ruins of Thaurissan", level=50, qlevel=54, giver="Royal Historian Archesonus", zone="Ironforge", x=38.4, y=55.3, afterAny={3702}, note="Venture to the Ruins of Thaurissan in the Burning Steppes and recover information from the Thaurissan Relics. Return to Royal Historian Archesonus when you have recovered the information." },
    [3702] = { id=3702, name="The Smoldering Ruins of Thaurissan", level=50, qlevel=54, giver="Royal Historian Archesonus", zone="Ironforge", x=38.4, y=55.3, note="Listen to Royal Historian Archesonus recant the history of Thaurissan." },
    [3765] = { id=3765, name="The Corruption Abroad", level=18, qlevel=24, giver="Argos Nightwhisper", zone="Stormwind City", x=36.2, y=67.6, turnin="Gershala Nightwhisper", tzone="Darkshore", tx=38.3, ty=43.0, note="Travel to Gershala Nightwhisper in Auberdine." },
    [3801] = { id=3801, name="Dark Iron Legacy", level=48, qlevel=52, giver="Franclorn Forgewright", inside=true, note="Speak with Franclorn Forgewright if you are interested in obtaining a key to the city major." },
    [3906] = { id=3906, name="Disharmony of Flame", level=48, qlevel=52, giver="Thunderheart", zone="Badlands", x=3.3, y=48.3, note="Travel to the quarry in Blackrock Mountain and slay Overmaster Pyron. Return to Thunderheart when you have completed this assignment." },
    [3981] = { id=3981, name="Commander Gor'shak", level=48, qlevel=52, giver="Galamav the Marksman", zone="Badlands", x=6.0, y=47.7, turnin="Commander Gor'shak", afterAny={3906}, note="Find Commander Gor'shak in Blackrock Depths." },
    [3982] = { id=3982, name="What Is Going On?", level=48, qlevel=54, giver="Commander Gor'shak", inside=true, afterAny={3981}, note="Defend Gor'shak." },
    [4001] = { id=4001, name="What Is Going On?", level=48, qlevel=54, giver="Commander Gor'shak", inside=true, turnin="Thrall", tzone="Orgrimmar", tx=31.7, ty=37.8, afterAny={3982}, note="Speak with Kharan Mighthammer and gather information about Princess Moira Bronzebeard's kidnapping. Take that information to Thrall in Orgrimmar." },
    [4002] = { id=4002, name="The Eastern Kingdom", level=48, qlevel=54, giver="Thrall", zone="Orgrimmar", x=31.7, y=37.8, afterAny={4001}, note="Speak with Thrall if you are prepared to take on the mission he has planned." },
    [4003] = { id=4003, name="The Royal Rescue", level=48, qlevel=59, giver="Thrall", zone="Orgrimmar", x=31.7, y=37.8, turnin="Princess Moira Bronzebeard", afterAny={4002}, note="Slay Emperor Dagran Thaurissan and free Princess Moira Bronzebeard from his evil spell. " },
    [4022] = { id=4022, name="A Taste of Flame", level=52, qlevel=54, giver="Cyrus Therepentous", zone="Burning Steppes", x=95.1, y=31.6, afterAny={3481}, note="Show Cyrus Therepentous the Black Dragonflight Molt you received from Kalaran Windblade." },
    [4061] = { id=4061, name="The Rise of the Machines", level=52, qlevel=54, giver="Hierophant Theodora Mulvadania", zone="Badlands", x=3.0, y=47.8, note="Venture to the Burning Steppes and recover 10 Fractured Elemental Shards for Hierophant Theodora Mulvadania." },
    [4062] = { id=4062, name="The Rise of the Machines", level=52, qlevel=54, giver="Hierophant Theodora Mulvadania", zone="Badlands", x=3.0, y=47.8, turnin="Lotwil Veriatus", tzone="Badlands", tx=25.9, ty=44.9, afterAny={4061}, note="Take the Elemental Shard Sample to Lotwil Veriatus." },
    [4081] = { id=4081, name="KILL ON SIGHT: Dark Iron Dwarves", level=48, qlevel=52, giver="WANTED", start="object", zone="Badlands", x=3.7, y=47.4, turnin="Warlord Goretooth", tzone="Badlands", tx=5.8, ty=47.5, note="Venture to Blackrock Depths and destroy the vile aggressors!" },
    [4121] = { id=4121, name="Precarious Predicament", level=52, qlevel=58, giver="Grark Lorkrub", zone="Burning Steppes", x=40.2, y=34.2, turnin="Lexlort", tzone="Badlands", tx=5.9, ty=47.6, afterAny={4122}, note="Escort your prisoner, Grark Lorkrub, through Burning Steppes and through Blackrock Mountain to the Searing Gorge." },
    [4122] = { id=4122, name="Grark Lorkrub", level=52, qlevel=58, giver="Lexlort", zone="Badlands", x=5.9, y=47.6, turnin="Grark Lorkrub", tzone="Burning Steppes", tx=40.2, ty=34.2, note="Travel to the Burning Steppes and find Grark Lorkrub. You recall Lexlort mentioning that he was last seen in a massive Blackrock fortress." },
    [4128] = { id=4128, name="Ragnar Thunderbrew", level=50, qlevel=55, giver="Enohar Thunderbrew", zone="Blasted Lands", x=63.6, y=20.6, turnin="Ragnar Thunderbrew", tzone="Dun Morogh", tx=46.8, ty=52.4, note="Speak with Ragnar Thunderbrew." },
    [4133] = { id=4133, name="Vivian Lagrave", level=50, qlevel=55, giver="Apothecary Zinge", zone="Undercity", x=50.1, y=68.0, turnin="Shadowmage Vivian Lagrave", tzone="Badlands", tx=2.9, ty=47.8, note="Speak with Shadowmaster Vivian Lagrave in Kargath." },
    [4141] = { id=4141, name="Muigin and Larion", level=47, qlevel=52, giver="Muigin", zone="Un'Goro Crater", x=42.9, y=9.6, note="Collect 15 Bloodpetals and return to Muigin." },
    [4142] = { id=4142, name="A Visit to Gregan", level=47, qlevel=52, giver="Muigin", zone="Un'Goro Crater", x=42.9, y=9.6, turnin="Gregan Brewspewer", tzone="Feralas", tx=45.1, ty=25.6, afterAny={4141}, note="Take a Bloodpetal to Gregan Brewspewer in Feralas." },
    [4145] = { id=4145, name="Larion and Muigin", level=47, qlevel=52, giver="Larion", zone="Un'Goro Crater", x=45.5, y=8.7, note="Hunt 5 Bloodpetal Lashers, 5 Bloodpetal Threshers, 5 Bloodpetal Flayers and 5 Bloodpetal Trappers for Larion at Marshal's Refuge." },
    [4147] = { id=4147, name="Marvon's Workshop", level=47, qlevel=52, giver="Larion", zone="Un'Goro Crater", x=45.5, y=8.7, turnin="Liv Rizzlefix", tzone="The Barrens", tx=62.5, ty=38.7, afterAny={4145}, note="Travel to Marvon Rivetseeker's workshop in Ratchet." },
    [4262] = { id=4262, name="Overmaster Pyron", level=48, qlevel=52, giver="Jalinda Sprig", zone="Burning Steppes", x=85.4, y=70.1, note="Slay Overmaster Pyron and return to Jalinda Sprig." },
    [4324] = { id=4324, name="Yuka Screwspigot", level=48, qlevel=53, giver="Yorba Screwspigot", zone="Tanaris", x=67.0, y=24.0, turnin="Yuka Screwspigot", tzone="Burning Steppes", tx=66.1, ty=21.9, note="Speak with Yuka Screwspigot in the Burning Steppes." },
    [4341] = { id=4341, name="Kharan Mighthammer", level=50, qlevel=59, giver="King Magni Bronzebeard", zone="Ironforge", x=39.1, y=56.2, turnin="Kharan Mighthammer", afterAny={3701}, note="Travel to Blackrock Depths and find Kharan Mighthammer." },
    [4361] = { id=4361, name="The Bearer of Bad News", level=50, qlevel=59, giver="Kharan Mighthammer", inside=true, turnin="King Magni Bronzebeard", tzone="Ironforge", tx=39.1, ty=56.2, afterAny={4341}, note="Return to Ironforge and deliver the bad news to King Magni Bronzebeard." },
    [4362] = { id=4362, name="The Fate of the Kingdom", level=50, qlevel=59, giver="King Magni Bronzebeard", zone="Ironforge", x=39.1, y=56.2, turnin="Princess Moira Bronzebeard", afterAny={4361}, note="Return to Blackrock Depths and rescue Princess Moira Bronzebeard from the evil clutches of Emperor Dagran Thaurissan." },
    [4726] = { id=4726, name="Broodling Essence", level=50, qlevel=52, giver="Tinkee Steamboil", zone="Burning Steppes", x=65.2, y=24.0, note="Bring 8 Broodling Essence and the Draco-Incarcinatrix 900 to Tinkee Steamboil at the Flame Crest in the Burning Steppes." },
    [4734] = { id=4734, name="Egg Freezing", level=57, qlevel=60, giver="Tinkee Steamboil", zone="Burning Steppes", x=65.2, y=24.0, afterAny={4810}, note="Use the Eggscilloscope Prototype on an egg in the Rookery." },
    [4735] = { id=4735, name="Egg Collection", level=57, qlevel=60, giver="Tinkee Steamboil", zone="Burning Steppes", x=65.2, y=24.0, afterAny={4734}, note="Bring 8 Collected Dragon Eggs and the Collectronic Module to Tinkee Steamboil at Flame Crest in the Burning Steppes." },
    [4766] = { id=4766, name="Mayara Brightwing", level=57, qlevel=60, giver="Count Remington Ridgewell", zone="Stormwind City", x=76.9, y=47.8, turnin="Mayara Brightwing", tzone="Burning Steppes", tx=84.8, ty=69.1, note="Speak with Mayara Brightwing in the Burning Steppes." },
    [4769] = { id=4769, name="Vivian Lagrave and the Darkstone Tablet", level=57, qlevel=60, giver="Apothecary Zinge", zone="Undercity", x=50.1, y=68.0, turnin="Shadowmage Vivian Lagrave", tzone="Badlands", tx=2.9, ty=47.8, note="Speak with Shadowmage Vivian Lagrave." },
    [4787] = { id=4787, name="The Ancient Egg", level=40, qlevel=50, giver="Yeh'kinya", zone="Tanaris", x=67.0, y=22.4, afterAny={3527}, note="Bring the Ancient Egg to Yeh'kinya in Tanaris." },
    [4808] = { id=4808, name="Felnok Steelspring", level=50, qlevel=54, giver="Tinkee Steamboil", zone="Burning Steppes", x=65.2, y=24.0, turnin="Felnok Steelspring", tzone="Winterspring", tx=61.6, ty=38.6, afterAny={4726}, note="Give Tinkee's Letter to Felnok Steelspring." },
    [4809] = { id=4809, name="Chillwind Horns", level=50, qlevel=54, giver="Felnok Steelspring", zone="Winterspring", x=61.6, y=38.6, afterAny={4808}, note="Bring 8 Uncracked Chillwind Horns to Felnok Steelspring." },
    [4810] = { id=4810, name="Return to Tinkee", level=50, qlevel=54, giver="Felnok Steelspring", zone="Winterspring", x=61.6, y=38.6, turnin="Tinkee Steamboil", tzone="Burning Steppes", tx=65.2, ty=24.0, afterAny={4809}, note="Bring Felnok's Package to Tinkee Steamboil in the Burning Steppes." },
    [4903] = { id=4903, name="Warlord's Command", level=55, qlevel=60, giver="Warlord Goretooth", zone="Badlands", x=5.8, y=47.5, note="Slay Highlord Omokk, War Master Voone, and Overlord Wyrmthalak. Recover Important Blackrock Documents. Return to Warlord Goretooth in Kargath when the mission has been accomplished." },
    [4941] = { id=4941, name="Eitrigg's Wisdom", level=55, qlevel=60, giver="Warlord Goretooth", zone="Badlands", x=5.8, y=47.5, turnin="Thrall", tzone="Orgrimmar", tx=31.7, ty=37.8, afterAny={4903}, note="Speak with Eitrigg in Orgrimmar. When you have discussed matters with Eitrigg, seek council from Thrall." },
    [4981] = { id=4981, name="Operative Bijou", level=55, qlevel=59, giver="Lexlort", zone="Badlands", x=5.9, y=47.6, turnin="Bijou", note="Travel to Blackrock Spire and find out what happened to Bijou." },
    [5001] = { id=5001, name="Bijou's Belongings", level=55, qlevel=59, giver="Bijou", inside=true, note="Find Bijou's Belongings and return them to her. Good luck!" },
    [5002] = { id=5002, name="Message to Maxwell", level=55, qlevel=59, giver="Bijou", inside=true, turnin="Marshal Maxwell", tzone="Burning Steppes", tx=84.7, ty=69.0, afterAny={5001}, note="Travel to the Burning Steppes and give Bijou's Information to Marshal Maxwell." },
    [5065] = { id=5065, name="The Lost Tablets of Mosh'aru", level=40, qlevel=58, giver="Prospector Ironboot", zone="Tanaris", x=66.9, y=24.0, afterAny={3528}, note="Bring the Third and Fourth Mosh'aru Tablets to Prospector Ironboot in Tanaris." },
    [5066] = { id=5066, name="A Call to Arms: The Plaguelands!", level=50, giver="Crier Goodman", zone="Stormwind City", x=56.4, y=74.1, turnin="Commander Ashlam Valorfist", tzone="Western Plaguelands", tx=42.7, ty=84.0, note="Seek out Commander Ashlam Valorfist. His base camp is located at Chillwind Camp, north of the Alterac Mountains." },
    [5092] = { id=5092, name="Clear the Way", level=50, qlevel=52, giver="Commander Ashlam Valorfist", zone="Western Plaguelands", x=42.7, y=84.0, afterAny={5066, 5090, 5091}, note="Kill 10 Skeletal Flayers and 10 Slavering Ghouls in Sorrow Hill." },
    [5093] = { id=5093, name="A Call to Arms: The Plaguelands!", level=50, giver="Warcaller Gorlach", zone="Orgrimmar", x=37.6, y=75.4, turnin="High Executor Derrington", tzone="Tirisfal Glades", tx=83.1, ty=68.9, note="Seek out High Executor Derrington. His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity." },
    [5096] = { id=5096, name="Scarlet Diversions", level=50, qlevel=53, giver="High Executor Derrington", zone="Tirisfal Glades", x=83.1, y=68.9, afterAny={5093, 5094, 5095}, note="Proceed to the Scarlet Crusade's base camp between Felstone Field and Dalson's Tears and destroy their command tent." },
    [5097] = { id=5097, name="All Along the Watchtowers", level=50, qlevel=56, giver="Commander Ashlam Valorfist", zone="Western Plaguelands", x=42.7, y=84.0, afterAny={5092}, note="Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it." },
    [5098] = { id=5098, name="All Along the Watchtowers", level=50, qlevel=56, giver="High Executor Derrington", zone="Tirisfal Glades", x=83.1, y=68.9, afterAny={5096}, note="Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it." },
    [5122] = { id=5122, name="The Medallion of Faith", level=55, qlevel=60, giver="Aurius", inside=true },
    [5212] = { id=5212, name="The Flesh Does Not Lie", level=55, qlevel=60, giver="Betina Bigglezink", zone="Eastern Plaguelands", x=71.7, y=49.9, note="Recover 10 Plagued Flesh Samples from Stratholme and return them to Betina Bigglezink. You suspect that any creature in Stratholme would have said flesh sample." },
    [5251] = { id=5251, name="The Archivist", level=55, qlevel=60, giver="Duke Nicholas Zverenhoff", zone="Eastern Plaguelands", x=71.6, y=50.1, note="Travel to Stratholme and find Archivist Galford of the Scarlet Crusade. Destroy him and burn down the Scarlet Archive." },
    [5262] = { id=5262, name="The Truth Comes Crashing Down", level=55, qlevel=60, giver="Head of Balnazzar", start="item", turnin="Duke Nicholas Zverenhoff", tzone="Eastern Plaguelands", tx=71.6, ty=50.1, afterAny={5251}, note="Take the Head of Balnazzar to Duke Nicholas Zverenhoff in the Eastern Plaguelands." },
    [5281] = { id=5281, name="The Restless Souls", level=55, qlevel=60, giver="Caretaker Alen", zone="Eastern Plaguelands", x=69.9, y=53.7, turnin="Egan", tzone="Eastern Plaguelands", tx=11.4, ty=26.6, note="Find Egan. You only know that he was last seen around Stratholme." },
    [5382] = { id=5382, name="Doctor Theolen Krastinov, the Butcher", level=55, qlevel=60, giver="Eva Sarkhoff", zone="Western Plaguelands", x=70.2, y=73.7, note="Find Doctor Theolen Krastinov inside the Scholomance. Destroy him, then burn the Remains of Eva Sarkhoff and the Remains of Lucien Sarkhoff. Return to Eva Sarkhoff when the task is complete." },
    [5384] = { id=5384, name="Kirtonos the Herald", level=55, qlevel=60, giver="Eva Sarkhoff", zone="Western Plaguelands", x=70.2, y=73.7, afterAny={5515}, note="Return to the Scholomance with the Blood of Innocents. Find the porch and place the Blood of Innocents in the brazier. Kirtonos will come to feast upon your soul." },
    [5461] = { id=5461, name="The Human, Ras Frostwhisper", level=57, qlevel=60, giver="Magistrate Marduke", zone="Western Plaguelands", x=70.6, y=74.1, afterAny={5384}, note="Travel to the Arathi Highlands, to the ruins of Stromgarde. Search Stromgarde for a Keepsake of Remembrance. If you find such an item, return with it to Magistrate Marduke." },
    [5462] = { id=5462, name="The Dying, Ras Frostwhisper", level=57, qlevel=60, giver="Magistrate Marduke", zone="Western Plaguelands", x=70.6, y=74.1, turnin="Leonid Barthalomew the Revered", tzone="Eastern Plaguelands", tx=71.9, ty=48.3, afterAny={5461}, note="Travel to Light's Hope in Eastern Plaguelands and seek out Leonid Barthalomew the Revered. Show him the Keepsake of Remembrance and tell him all that you have discovered." },
    [5463] = { id=5463, name="Menethil's Gift", level=57, qlevel=60, giver="Leonid Barthalomew the Revered", zone="Eastern Plaguelands", x=71.9, y=48.3, afterAny={5462}, note="Travel to Stratholme and find Menethil's Gift. Place the Keepsake of Remembrance upon the unholy ground." },
    [5464] = { id=5464, name="Menethil's Gift", level=57, qlevel=60, giver="Menethil's Gift", start="object", turnin="Leonid Barthalomew the Revered", tzone="Eastern Plaguelands", tx=71.9, ty=48.3, afterAny={5463}, note="Take the Soulbound Keepsake to Leonid Barthalomew in Eastern Plaguelands." },
    [5465] = { id=5465, name="Soulbound Keepsake", level=57, qlevel=60, giver="Leonid Barthalomew the Revered", zone="Eastern Plaguelands", x=71.9, y=48.3, turnin="Magistrate Marduke", tzone="Western Plaguelands", tx=70.6, ty=74.1, afterAny={5464}, note="Return to Magistrate Marduke in Caer Darrow. Show him the Soulbound Keepsake." },
    [5514] = { id=5514, name="Mold Rhymes With...", level=55, qlevel=57, giver="Apothecary Dithers", zone="Tirisfal Glades", x=83.3, y=69.2, turnin="Krinkle Goodsteel", tzone="Tanaris", tx=51.5, ty=28.8, afterAny={964}, note="Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan." },
    [5515] = { id=5515, name="Krastinov's Bag of Horrors", level=55, qlevel=60, giver="Eva Sarkhoff", zone="Western Plaguelands", x=70.2, y=73.7, afterAny={5382}, note="Locate Jandice Barov in the Scholomance and destroy her. From her corpse recover Krastinov's Bag of Horrors. Return the bag to Eva Sarkhoff." },
    [5522] = { id=5522, name="Leonid Barthalomew", level=57, qlevel=60, giver="Tinkee Steamboil", zone="Burning Steppes", x=65.2, y=24.0, turnin="Leonid Barthalomew the Revered", tzone="Eastern Plaguelands", tx=71.9, ty=48.3, afterAny={4735}, note="Bring the Frozen Eggs to Leonid Barthalomew in the Eastern Plaguelands." },
    [5527] = { id=5527, name="A Reliquary of Purity", level=56, qlevel=60, giver="Rabine Saturna", zone="Moonglade", x=51.7, y=45.1, note="Travel to Silithus and search for a Reliquary of Purity within the ruins of Southwind Village. If you are able to find it, return with it to Rabine Saturna in Nighthaven, Moonglade." },
    [5531] = { id=5531, name="Betina Bigglezink", level=57, qlevel=60, giver="Leonid Barthalomew the Revered", zone="Eastern Plaguelands", x=71.9, y=48.3, turnin="Betina Bigglezink", tzone="Eastern Plaguelands", tx=71.7, ty=49.9, afterAny={5522}, note="Bring the Frozen Eggs to Betina Bigglezink." },
    [5533] = { id=5533, name="Scholomance", level=55, giver="Commander Ashlam Valorfist", zone="Western Plaguelands", x=42.7, y=84.0, turnin="Alchemist Arbington", tzone="Western Plaguelands", tx=42.7, ty=83.8, afterAny={5097}, note="Speak with Alchemist Arbington at Chillwind Point, Western Plaguelands." },
    [5537] = { id=5537, name="Skeletal Fragments", level=55, qlevel=57, giver="Alchemist Arbington", zone="Western Plaguelands", x=42.7, y=83.8, afterAny={5533}, note="Bring 15 Skeletal Fragments to Alchemist Arbington at Chillwind Point, Western Plaguelands." },
    [5538] = { id=5538, name="Mold Rhymes With...", level=55, qlevel=57, giver="Alchemist Arbington", zone="Western Plaguelands", x=42.7, y=83.8, turnin="Krinkle Goodsteel", tzone="Tanaris", tx=51.5, ty=28.8, afterAny={5537}, note="Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan." },
    [5542] = { id=5542, name="Demon Dogs", level=52, qlevel=56, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, note="Slay 20 Plaguehound Runts, 5 Plaguehounds and 5 Frenzied Plaguehounds. Return to Tirion Fordring when the task is complete." },
    [5543] = { id=5543, name="Blood Tinged Skies", level=52, qlevel=56, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, note="Slay 30 Plaguebats and return to Tirion Fordring." },
    [5544] = { id=5544, name="Carrion Grubbage", level=52, qlevel=56, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, note="Seek out the Carrion Grubs and Devourers of the region. Slay them and harvest their meat. Return to Tirion Fordring when you have gathered 15 Slabs of Carrion Worm Meat." },
    [5722] = { id=5722, name="Searching for the Lost Satchel", level=9, qlevel=16, giver="Rahauro", zone="Thunder Bluff", x=70.1, y=29.5, turnin="Maur Grimtotem", note="Search Ragefire Chasm for Maur Grimtotem's corpse and search it for any items of interest." },
    [5726] = { id=5726, name="Hidden Enemies", level=9, qlevel=12, giver="Thrall", zone="Orgrimmar", x=31.7, y=37.8, note="Bring a Lieutenant's Insignia to Thrall in Orgrimmar." },
    [5727] = { id=5727, name="Hidden Enemies", level=9, qlevel=12, giver="Thrall", zone="Orgrimmar", x=31.7, y=37.8, afterAny={5726}, note="Take the Lieutenant's Insignia to Neeru Fireblade and speak to him. Gauge if he believes you are a member of the Burning Blade and then return to Thrall in Orgrimmar." },
    [5742] = { id=5742, name="Redemption", level=52, qlevel=56, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, after={5542, 5543, 5544}, note="Listen to what Tirion Fordring has to say." },
    [5781] = { id=5781, name="Of Forgotten Memories", level=52, qlevel=57, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, afterAny={5742}, note="Travel to the Undercroft - at the southernmost section of the Eastern Plaguelands - and recover Taelan's Hammer. Return to Tirion Fordring upon completion of your objective." },
    [5801] = { id=5801, name="Fire Plume Forged", level=55, qlevel=57, giver="Krinkle Goodsteel", zone="Tanaris", x=51.5, y=28.8, turnin="Alchemist Arbington", tzone="Western Plaguelands", tx=42.7, ty=83.8, afterAny={5538}, note="Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key." },
    [5802] = { id=5802, name="Fire Plume Forged", level=55, qlevel=57, giver="Krinkle Goodsteel", zone="Tanaris", x=51.5, y=28.8, turnin="Apothecary Dithers", tzone="Tirisfal Glades", tx=83.3, ty=69.2, afterAny={5514}, note="Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key." },
    [5803] = { id=5803, name="Araj's Scarab", level=55, qlevel=60, giver="Alchemist Arbington", zone="Western Plaguelands", x=42.7, y=83.8, afterAny={5801}, note="Destroy Araj the Summoner and bring Araj's Scarab to Alchemist Arbington at Chillwind Point, Western Plaguelands." },
    [5804] = { id=5804, name="Araj's Scarab", level=55, qlevel=60, giver="Apothecary Dithers", zone="Tirisfal Glades", x=83.3, y=69.2, afterAny={5802}, note="Destroy Araj the Summoner and bring Araj's Scarab to Apothecary Dithers at the Bulwark, Western Plaguelands." },
    [5845] = { id=5845, name="Of Lost Honor", level=52, qlevel=58, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, afterAny={5781}, note="Travel to Northdale, in the northeastern region of the Eastern Plaguelands, and recover the Symbol of Lost Honor. Return to Tirion Fordring upon completion of your objective." },
    [5846] = { id=5846, name="Of Love and Family", level=52, qlevel=58, giver="Tirion Fordring", zone="Eastern Plaguelands", x=5.2, y=35.6, turnin="Artist Renfray", tzone="Western Plaguelands", tx=65.8, ty=75.4, afterAny={5845}, note="Travel to island of Caer Darrow, in the south-central region of the Plaguelands, and look for any clues as to the whereabouts of the painting." },
    [6133] = { id=6133, name="The Ranger Lord's Behest", level=54, qlevel=60, giver="Nathanos Blightcaller", zone="Eastern Plaguelands", x=22.2, y=63.5, note="Travel to the northern borders of the Eastern Plaguelands and recover the Quel'Thalas Registry. The item is somewhere in the Quel'Lithien lodge." },
    [6135] = { id=6135, name="Duskwing, Oh How I Hate Thee...", level=56, qlevel=60, giver="Nathanos Blightcaller", zone="Eastern Plaguelands", x=22.2, y=63.5, afterAny={6133}, note="Find Duskwing and slay him. From the corpse, recover a Patch of Duskwing's Fur and return it to Nathanos Blightcaller." },
    [6522] = { id=6522, name="An Unholy Alliance", level=28, qlevel=36, giver="Small Scroll", start="item", turnin="Varimathras", tzone="Undercity", tx=56.2, ty=92.2, note="Take the Small Scroll to Varimathras in the Undercity." },
    [6562] = { id=6562, name="Trouble in the Deeps", level=17, qlevel=22, giver="Tsunaman", zone="Stonetalon Mountains", x=47.4, y=64.2, turnin="Je'neu Sancrea", tzone="Ashenvale", tx=11.6, ty=34.3, note="Speak to Je'neu Sancrea in Ashenvale." },
    [6627] = { id=6627, name="Test of Lore", level=25, qlevel=30, giver="Braug Dimspirit", zone="Stonetalon Mountains", x=78.8, y=45.7, afterAny={1154}, note="Answer Braug Dimspirit's question successfully and then speak to him again. He will remain in Stonetalon Mountains when you are ready." },
    [6804] = { id=6804, name="Poisoned Water", level=55, qlevel=56, giver="Duke Hydraxis", zone="Azshara", x=79.3, y=73.7, note="Use the Aspect of Neptulon on poisoned elementals of Eastern Plaguelands. Bring 12 Discordant Bracers and the Aspect of Neptulon to Duke Hydraxis in Azshara." },
    [6805] = { id=6805, name="Stormers and Rumblers", level=55, qlevel=57, giver="Duke Hydraxis", zone="Azshara", x=79.3, y=73.7, note="Kill 15 Dust Stormers and 15 Desert Rumblers and then return to Duke Hydraxis in Azshara." },
    [7044] = { id=7044, name="Legends of Maraudon", level=41, qlevel=49, giver="Cavindra", zone="Desolace", x=32.1, y=64.0, turnin="Celebras the Redeemed", note="Recover the two parts of the Scepter of Celebras: the Celebrian Rod and the Celebrian Diamond." },
    [7461] = { id=7461, name="The Madness Within", level=56, qlevel=60, giver="Shen'dralar Ancient", inside=true, note="You must destroy the guardians surrounding the 5 Pylons that power the Prison of Immol'thar. Once the Pylons have powered down, the force field surrounding Immol'thar will have dissipated." },
    [7492] = { id=7492, name="Camp Mojache", level=54, qlevel=57, giver="Warcaller Gorlach", zone="Orgrimmar", x=37.6, y=75.4, turnin="Talo Thornhoof", tzone="Feralas", tx=76.2, ty=43.8, note="Speak with Talo Thornhoof at Camp Mojache in Feralas." },
    [7494] = { id=7494, name="Feathermoon Stronghold", level=54, qlevel=57, giver="Crier Goodman", zone="Stormwind City", x=56.4, y=74.1, turnin="Latronicus Moonspear", tzone="Feralas", tx=30.4, ty=46.2, note="Speak with Latronicus Moonspear at the Feathermoon Stronghold in Feralas." },
    [8151] = { id=8151, name="The Hunter's Charm", level=50, qlevel=52, giver="Kary Thunderhorn", zone="Thunder Bluff", x=58.5, y=88.3, turnin="Ogtinc", tzone="Azshara", tx=42.4, ty=42.6, note="Speak to Ogtinc in Azshara." },
    [8153] = { id=8153, name="Courser Antlers", level=50, qlevel=52, giver="Ogtinc", zone="Azshara", x=42.4, y=42.6, afterAny={8151}, note="Bring a pair of Perfect Courser Antlers to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast of the Ruins of Eldarath." },
    [8231] = { id=8231, name="Wavethrashing", level=50, qlevel=52, giver="Ogtinc", zone="Azshara", x=42.4, y=42.6, afterAny={8153}, note="Bring 6 Wavethrasher Scales to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath." },
    [8234] = { id=8234, name="Sealed Azure Bag", level=50, qlevel=52, giver="Lord Jorach Ravenholdt", zone="Alterac Mountains", x=86.0, y=78.9, turnin="Archmage Xylem", tzone="Azshara", tx=29.2, ty=40.2, note="Retrieve the Sealed Azure Bag from the Timbermaw Shaman in Azshara. Then take the bag to Archmage Xylem, also found in Azshara." },
    [8235] = { id=8235, name="Encoded Fragments", level=50, qlevel=52, giver="Archmage Xylem", zone="Azshara", x=29.2, y=40.2, afterAny={8234}, note="Bring 10 Encoded Fragments to Archmage Xylem in Azshara." },
    [8250] = { id=8250, name="Magecraft", level=50, qlevel=52, giver="Thurston Xane", zone="Thunder Bluff", x=25.2, y=21.0, turnin="Sanath Lim-yo", tzone="Azshara", tx=28.1, ty=50.1, note="Seek out Sanath Lim-yo and gain passage to see Archmage Xylem." },
    [8251] = { id=8251, name="Magic Dust", level=50, qlevel=52, giver="Archmage Xylem", zone="Azshara", x=29.2, y=40.2, afterAny={8250}, note="Bring 10 Glittering Dust to Archmage Xylem." },
    [8252] = { id=8252, name="The Siren's Coral", level=50, qlevel=52, giver="Archmage Xylem", zone="Azshara", x=29.2, y=40.2, afterAny={8251}, note="Collect 6 Enchanted Coral and return them to Archmage Xylem." },
    [8254] = { id=8254, name="Cenarion Aid", level=50, qlevel=52, giver="High Priestess Laurena", zone="Stormwind City", x=49.5, y=44.6, turnin="Ogtinc", tzone="Azshara", tx=42.4, ty=42.6, note="Seek out Ogtinc in Azshara." },
    [8255] = { id=8255, name="Of Coursers We Know", level=50, qlevel=52, giver="Ogtinc", zone="Azshara", x=42.4, y=42.6, afterAny={8254}, note="Acquire 4 Healthy Courser Glands and bring them to Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath." },
    [8256] = { id=8256, name="The Ichor of Undeath", level=50, qlevel=52, giver="Ogtinc", zone="Azshara", x=42.4, y=42.6, afterAny={8255}, note="Acquire an Ichor of Undeath for Ogtinc in Azshara. Ogtinc resides atop the cliffs northeast the Ruins of Eldarath." },
    [8410] = { id=8410, name="Elemental Mastery", level=50, giver="Haromm", zone="Swamp of Sorrows", x=48.2, y=57.9, turnin="Bath'rah the Windwatcher", tzone="Alterac Mountains", tx=80.5, ty=66.9, note="Collect a sample of air, fire, earth and water for Bath'rah the Windwatcher." },
    [8412] = { id=8412, name="Spirit Totem", level=50, qlevel=52, giver="Bath'rah the Windwatcher", zone="Alterac Mountains", x=80.5, y=66.9, afterAny={8410}, note="Bring the pieces for the spirit totem to Bath'rah the Windwatcher." },
    [8414] = { id=8414, name="Dispelling Evil", level=50, qlevel=52, giver="Commander Ashlam Valorfist", zone="Western Plaguelands", x=42.7, y=84.0, turnin="High Priest Thel'danis", tzone="Western Plaguelands", tx=52.0, ty=83.3, note="Collect 20 Minion's Scourgestones and bring them to High Priest Thel'danis in the Western Plaguelands." },
    [8416] = { id=8416, name="Inert Scourgestones", level=50, qlevel=52, giver="High Priest Thel'danis", zone="Western Plaguelands", x=52.0, y=83.3, turnin="Commander Ashlam Valorfist", tzone="Western Plaguelands", tx=42.7, ty=84.0, afterAny={8414}, note="Bring the Inert Scourgestone to Commander Ashlan Valorfist in Chillwind Point." },
    [8419] = { id=8419, name="An Imp's Request", level=50, qlevel=52, giver="Demisette Cloyce", zone="Stormwind City", x=39.2, y=85.0, turnin="Impsy", tzone="Felwood", tx=41.4, ty=45.0, note="Bring a piece of felcloth to Impsy in Felwood." },
    [8421] = { id=8421, name="The Wrong Stuff", level=50, qlevel=52, giver="Impsy", zone="Felwood", x=41.4, y=45.0, afterAny={8419, 8420}, note="Bring 10 Rotting Wood and 4 Bloodvenom Essence to Impsy in Felwood." },
    [8423] = { id=8423, name="Warrior Kinship", level=50, qlevel=52, giver="Fallen Hero of the Horde", zone="Swamp of Sorrows", x=34.3, y=66.1, note="Kill 7 Helboar in the Blasted Lands and return to the Fallen Hero of the Horde." },
    [8424] = { id=8424, name="War on the Shadowsworn", level=50, qlevel=52, giver="Fallen Hero of the Horde", zone="Swamp of Sorrows", x=34.3, y=66.1, afterAny={8423}, note="Slaughter the Shadowsworn in the Blasted Lands and return to the Fallen Hero of the Horde." },
    [9051] = { id=9051, name="Toxic Test", level=50, qlevel=52, giver="Torwa Pathfinder", zone="Un'Goro Crater", x=71.6, y=76.0, afterAny={9052}, note="Stab a Devilsaur with the Devilsaur Barb. Return to Torwa Pathfinder in Un'Goro Crater when you have completed this task." },
    [9052] = { id=9052, name="Bloodpetal Poison", level=50, qlevel=52, giver="Torwa Pathfinder", zone="Un'Goro Crater", x=71.6, y=76.0, afterAny={9063}, note="Collect 8 Bloodcap and 8 Gorishi Stings, and return to Torwa Pathfinder in Un'Goro Crater." },
    [9063] = { id=9063, name="Torwa Pathfinder", level=50, qlevel=52, giver="Turak Runetotem", zone="Thunder Bluff", x=76.5, y=27.2, turnin="Torwa Pathfinder", tzone="Un'Goro Crater", tx=71.6, ty=76.0, note="Speak with Torwa Pathfinder in Un'Goro Crater." },
    [92432] = { id=92432, name="An Alarming Request", level=30, qlevel=33, giver="Emissary Jacques", zone="Hillsbrad Foothills", x=48.2, y=60, turnin="Image of Archmage Modera", tzone="Silverpine Forest", tx=68.6, ty=45.1, note="Report to the Image of Archmage Modera near the City of Dalaran." },
    [92434] = { id=92434, name="Blood in the Streets", level=30, qlevel=34, giver="Magus Wordeen Voidglare", zone="Hillsbrad Foothills", x=61.6, y=20.9, turnin="Image of Archmage Modera", tzone="Silverpine Forest", tx=68.6, ty=45.1, afterAny={545}, note="Find a way into Dalaran along the Lordamere Lake." },
    [92742] = { id=92742, name="Testing the Wells", level=9, qlevel=12, giver="Alba Fairmoon", zone="Westfall", x=52.5, y=53.0, note="Use the Well Water Sample Kit to collect samples from the wells at the Jansen Stead and the Molsen Farm." },
    [92744] = { id=92744, name="Murloc Gills", level=9, qlevel=12, giver="Alba Fairmoon", zone="Westfall", x=52.5, y=53.0, note="Alba Fairmoon wants you to collect 7 Longshore Murloc Gills along the shoreline of Westfall." },
    [92745] = { id=92745, name="The State of the Mines", level=9, qlevel=14, giver="Alba Fairmoon", zone="Westfall", x=52.5, y=53.0, after={92742, 92744}, note="Slay 4 Kobold Diggers in the Jangolode Mine and 6 Riverpaw Miners in the Gold Coast Quarry." },
    [92747] = { id=92747, name="Moonbrook Espionage", level=9, qlevel=15, giver="Alba Fairmoon", zone="Westfall", x=52.5, y=53.0, afterAny={92745}, note="Collect 8 Suspicious Industrial Supplies from Moonbrook." },
    [92748] = { id=92748, name="Explosive Consultation", level=9, qlevel=16, giver="Alba Fairmoon", zone="Westfall", x=52.5, y=53.0, turnin="Sprite Jumpsprocket", tzone="Stormwind City", tx=61.9, ty=30.6, afterAny={92747}, note="Travel to the Dwarven District in Stormwind and find an engineer who can help." },
    [92749] = { id=92749, name="A Dynamite Plan", level=9, qlevel=16, giver="Sprite Jumpsprocket", zone="Stormwind City", x=61.9, y=30.6, afterAny={92748}, note="Obtain 10 Rough Dynamite from crafting, trading, or the auction house, then return to Sprite Jumpsprocket in the Dwarven District of Stormwind." },
    [92750] = { id=92750, name="Detonation at a Distance", level=9, qlevel=16, giver="Sprite Jumpsprocket", zone="Stormwind City", x=61.9, y=30.6, turnin="Jasper Fel", tzone="Stormwind City", tx=80.3, ty=70.1, afterAny={92748}, note="Talk to someone in Stormwind Intelligence about acquiring a remote detonator." },
    [92751] = { id=92751, name="Detonation at a Distance", level=9, qlevel=16, giver="Jasper Fel", zone="Stormwind City", x=80.3, y=70.1, turnin="Sprite Jumpsprocket", tzone="Stormwind City", tx=61.9, ty=30.6, afterAny={92750}, note="Bring the Remote Detonator Kit to Sprite Jumpsprocket in the Dwarven District of Stormwind." },
    [92752] = { id=92752, name="Explosive Consultation", level=9, qlevel=16, giver="Sprite Jumpsprocket", zone="Stormwind City", x=61.9, y=30.6, turnin="Alba Fairmoon", tzone="Westfall", tx=52.5, ty=53.0, after={92749, 92751}, note="Return to Alba Fairmoon in Westfall." },
    [93680] = { id=93680, name="Key to the City", level=30, qlevel=33, giver="Magus Wordeen Voidglare", zone="Hillsbrad Foothills", x=61.6, y=20.9, note="Acquire the Dalaran Sewer Key for Magus Wordeen Voidglare in Tarren Mill." },
    [93786] = { id=93786, name="A Message in Blood", level=35, qlevel=36, giver="Krom'rosh", zone="Riverglades", x=59.4, y=45.6, note="Slay 12 Meadowsbrook Farmhands, then return to Krom'rosh with news of your success." },
    [93787] = { id=93787, name="Food for the Taking", level=36, giver="Krom'rosh", zone="Riverglades", x=59.4, y=45.6, note="Steal 6 Feed Satchels from the Alliance farm in Meadowsbrook then return to Krom'rosh." },
    [94483] = { id=94483, name="Show Them How It's Done", level=36, qlevel=39, giver="Krom'rosh", zone="Riverglades", x=59.4, y=45.6, after={93786, 93787}, note="Slay 8 Farholde Priests and 12 Farholde Scouts south of the river." },
    [94672] = { id=94672, name="Encroaching Twilight", level=36, qlevel=41, giver="Tran'gul", zone="Riverglades", x=59.4, y=44.2, afterAny={94483}, note="Defeat 8 Twilight Raiders and 8 Twilight Neophytes within Sunnyglade for Tran'gul in Rog'mar." },
    [94680] = { id=94680, name="Twilight Missives", level=36, qlevel=41, giver="Tran'gul", zone="Riverglades", x=59.4, y=44.2, afterAny={94483}, note="Retrieve 3 Twilight Missives from Twilight Shadowmancers in Sunnyglade for Tran'gul in Rog'mar." },
    [94727] = { id=94727, name="Digging for Answers", level=36, qlevel=40, giver="Tran'gul", zone="Riverglades", x=59.4, y=44.2, turnin="Clubtoe", tzone="Riverglades", tx=49.9, ty=47, after={94672, 94680}, note="Convince a Twilight's Hammer miner in Sunnyglade to divulge their secrets." },
    [94744] = { id=94744, name="The Wayward Warrior", level=38, qlevel=43, giver="Krom'rosh", zone="Riverglades", x=59.4, y=45.6, turnin="Da'grosh", tzone="Riverglades", tx=33.4, ty=38, afterAny={95428}, note="Find Da'grosh in the hills west of Rog'mar." },
    [94745] = { id=94745, name="Carving a Path", level=38, qlevel=44, giver="Da'grosh", zone="Riverglades", x=33.4, y=38, afterAny={94744}, note="Defeat 8 Twilight Fanatics, 8 Twilight Corrupters, and 8 Twilight Champions within the Twilight's Shroud for Da'grosh." },
    [94748] = { id=94748, name="Break Their Chains", level=38, qlevel=44, giver="Da'grosh", zone="Riverglades", x=33.4, y=38, afterAny={94744}, note="Rescue 5 Rog'mar Scouts within the Twilight's Shroud for Da'grosh." },
    [94768] = { id=94768, name="Bring Me His Head", level=38, qlevel=46, giver="Da'grosh", zone="Riverglades", x=33.4, y=38, after={94745, 94748}, note="Defeat Overlord Kilgar within the Twilight's Shroud and bring his head to Da'grosh." },
    [94879] = { id=94879, name="Scraps of Knowledge", level=36, qlevel=40, giver="Ashe Amberhall", zone="Riverglades", x=66.6, y=81, note="Collect 5 Twilight Pages from within Sunnyglade for Ashe Amberall in Farholde Keep." },
    [94881] = { id=94881, name="Curious Trinkets", level=36, qlevel=38, giver="Ashe Amberhall", zone="Riverglades", x=66.6, y=81, note="Retrieve 25 Twilight Charms from Twilight Shadowmancers and Twilight Neophytes in Sunnyglade for Ashe Amberhall in Farholde Keep." },
    [94886] = { id=94886, name="The Western Front", level=38, qlevel=44, giver="Demar Brant", zone="Riverglades", x=66.4, y=80.8, turnin="Sergeant Riftan", tzone="Riverglades", tx=30.4, ty=49, afterAny={94879}, note="Find Sergeant Riftan near the Twilight's Shroud to the west." },
    [94888] = { id=94888, name="No Soldier Left Behind", level=38, qlevel=44, giver="Sergeant Riftan", zone="Riverglades", x=30.4, y=49, afterAny={94886}, note="Rescue 5 Farholde Scouts within the Twilight's Shroud for Sergeant Riftan." },
    [94889] = { id=94889, name="Carving a Path", level=38, qlevel=44, giver="Sergeant Riftan", zone="Riverglades", x=30.7, y=49.1, afterAny={94886}, note="Defeat 8 Twilight Fanatics, 8 Twilight Corrupters, and 8 Twilight Champions within the Twilight's Shroud for Sergeant Riftan." },
    [94890] = { id=94890, name="Bring Me His Head", level=38, qlevel=46, giver="Sergeant Riftan", zone="Riverglades", x=30.4, y=49, after={94888, 94889}, note="Defeat Overlord Kilgar within the Twilight's Shroud and bring his head to Sergeant Riftan." },
    [94907] = { id=94907, name="A Small Favor", level=36, qlevel=44, giver="Ashe Amberhall", zone="Riverglades", x=66.6, y=81, afterAny={94881}, note="Summon a Twilight's Thrall from a conduit within the Twilight Shroud and capture it with Amberhall's Soulstone." },
    [95278] = { id=95278, name="It Is Time, Brother...", level=38, qlevel=45, giver="Da'grosh", zone="Riverglades", x=33.4, y=38, turnin="Krom'rosh", tzone="Riverglades", tx=59.4, ty=45.6, afterAny={94768}, note="Deliver the missive to Krom'rosh at Rog'mar." },
    [95417] = { id=95417, name="The Purple Ones", level=36, qlevel=40, giver="Clubtoe", zone="Riverglades", x=49.9, y=47, turnin="Twilight Brute", tzone="Riverglades", tx=48.0, ty=48.0, afterAny={94727}, note="Find missing ogres in the caves beneath Sunnyglade for Clubtoe." },
    [95418] = { id=95418, name="Spread the Word", level=36, qlevel=40, giver="Clubtoe", zone="Riverglades", x=50.0, y=47.0, turnin="Tran'gul", tzone="Riverglades", tx=59.5, ty=44.0, afterAny={95427}, note="Deliver the head of Chogg to Tran'gul in Rog'mar." },
    [95420] = { id=95420, name="Land of Giants", level=36, qlevel=40, giver="Tran'gul", zone="Riverglades", x=59.4, y=44.2, turnin="Clugfist", tzone="Riverglades", tx=64.5, ty=14.7, afterAny={95418}, note="Deliver Chogg's head to the ogre city to the north." },
    [95424] = { id=95424, name="Might Makes Right", level=36, qlevel=41, giver="Clugfist", zone="Riverglades", x=64.5, y=14.7, afterAny={95420}, note="Kill 7 Twilight Maulers and 7 Twilight Firecallers for Clugfist in Bolder'ok." },
    [95425] = { id=95425, name="Unworthy Champion", level=36, qlevel=42, giver="Clugfist", zone="Riverglades", x=64.5, y=14.7, afterAny={95420}, note="Collect Skullthumper from Klunk for Clugfist in Bolder'ok." },
    [95427] = { id=95427, name="Twilight No More!", level=36, qlevel=41, giver="Clubtoe", zone="Riverglades", x=49.9, y=47, after={95601, 95602}, note="Kill Chogg'Zac in the Sunnyglade cave and collect their heads for Clubtoe." },
    [95428] = { id=95428, name="Clugfist's Decree", level=36, qlevel=41, giver="Clugfist", zone="Riverglades", x=64.5, y=14.7, turnin="Krom'rosh", tzone="Riverglades", tx=59.4, ty=45.6, after={95424, 95425}, note="Report to Krom'rosh in Rog'mar." },
    [95601] = { id=95601, name="The Purple Ones", level=36, qlevel=40, giver="Twilight Brute", zone="Riverglades", x=49.2, y=46.7, turnin="Clubtoe", tzone="Riverglades", tx=50.0, ty=47.0, afterAny={95417}, note="Kill 5 Empowered Brutes and 10 Twilight Ritualists then return to Clubtoe in Sunnyglade." },
    [95602] = { id=95602, name="Sickening Lights", level=36, qlevel=40, giver="Clubtoe", zone="Riverglades", x=49.9, y=47, afterAny={94727}, note="Destroy 5 Twilight Ritual Circles found throughout the caves underneath Sunnyglade." },
    [95663] = { id=95663, name="Dragonmaw Rumors", level=24, qlevel=31, giver="Zaruk", zone="Arathi Highlands", x=74.5, y=35.6, turnin="Deathstalker Agent", tzone="Wetlands", tx=51.5, ty=59.3, note="Travel to the Wetlands and meet the Deathstalker Agent in the hills above the Dragonmaw camp." },
    [95748] = { id=95748, name="The Gurubashi Legends of Old", level=30, qlevel=40, giver="Kin'weelay", zone="Stranglethorn Vale", x=32.3, y=27.7, afterAny={629}, note="Use the hide and charcoal to create a rubbing of the Third Troll Legend tablet." },
    [95770] = { id=95770, name="Locating the Lost City", level=30, qlevel=40, giver="Kin'weelay", zone="Stranglethorn Vale", x=32.3, y=27.7, afterAny={95748}, note="Explore the Vile Reef and find the cavern entrance." },
    [95773] = { id=95773, name="Enemies in the Water", level=30, qlevel=37, giver="Commander Aggro'gosh", zone="Stranglethorn Vale", x=32.2, y=28.9, afterAny={95748}, note="Gather 10 Brinescale Tridents from Brinescale Skirmishers." },
    [95786] = { id=95786, name="An Acquaintance in Southshore", level=30, qlevel=40, giver="Brother Nimetz", zone="Stranglethorn Vale", x=37.8, y=3.6, turnin="Loremaster Dibbs", tzone="Hillsbrad Foothills", tx=50.6, ty=57.1, afterAny={205}, note="Find Loremaster Dibbs in Southshore and bring him the Savage Coast Report Bundle." },
    [96391] = { id=96391, name="Underground Map", level=9, qlevel=15, giver="?", start="item", turnin="Earthseer Farsen", tzone="Dun Morogh", tx=64.9, ty=58.5, note="Deliver the Dark Iron Map to Earthseer Farsen in Dun Morogh." },
    [99156] = { id=99156, name="Rear Guard Patrol", level=6, qlevel=13, giver="Deathguard Linnea", zone="Tirisfal Glades", x=65.5, y=60.2, afterAny={356}, note="Bring Riptear's Heart to Deathguard Linnea." },
}

local CHAINS = {
    [17] = {2500},   -- Uldaman Reagent Run
    [166] = {65, 132, 135, 141, 142, 155},   -- The Defias Brotherhood
    [214] = {65, 132, 135, 141, 142, 155},   -- Red Silk Bandanas
    [378] = {303},   -- The Fury Runs Deep
    [391] = {373, 389},   -- The Stockade Riots
    [545] = {544, 93680},   -- Dalaran Patrols
    [704] = {707, 738, 739},   -- Agmond's Fate
    [722] = {720, 721},   -- Amulet of Secrets
    [914] = {870, 877, 880, 1489, 1490},   -- Leaders of the Fang
    [1053] = {261, 1052},   -- In the Name of the Light
    [1101] = {1100},   -- The Crone of the Kraul
    [1113] = {1109},   -- Hearts of Zeal
    [1139] = {720, 721, 722, 723, 724, 725, 726, 762},   -- The Lost Tablets of Will
    [1160] = {1149, 1150, 1151, 1152, 1154, 6627, 1159},   -- Test of Lore
    [1200] = {1198},   -- Blackfathom Villainy
    [1275] = {3765},   -- Researching the Corruption
    [1445] = {1424, 1429, 1444},   -- The Temple of Atal'Hakkar
    [1475] = {1448, 1449, 1450, 1451, 1452, 1469},   -- Into The Temple of Atal'Hakkar
    [1491] = {865},   -- Smart Drinks
    [1654] = {1649, 1650, 1651, 1652, 1653},   -- The Test of Righteousness
    [1701] = {1698, 1699, 1702},   -- Fire Hardened Mail
    [1838] = {1823, 1824, 1825},   -- Brutal Armor
    [1951] = {1947, 1949, 1950},   -- Rituals of Power
    [2202] = {2258},   -- Uldaman Reagent Run
    [2240] = {2398},   -- The Hidden Chamber
    [2843] = {2842},   -- Gnomer-gooooone!
    [2865] = {2864},   -- Scarab Shells
    [2922] = {2923},   -- Save Techbot's Brain!
    [2926] = {2927},   -- Gnogaine
    [2936] = {2933, 2934, 2935},   -- The Spider God
    [2962] = {2927, 2926},   -- The Only Cure is More Green Glow
    [2991] = {2988, 2989, 2990},   -- Nekrum's Medallion
    [3444] = { A = {3445}, H = {3380} },   -- The Stone Circle
    [3446] = { A = {3445, 3444}, H = {3380, 3444} },   -- Into the Depths
    [3447] = { A = {3445, 3444}, H = {3380, 3444} },   -- Secret of the Circle
    [3525] = {3523},   -- Extinguishing the Idol
    [3527] = {3520},   -- The Prophecy of Mosh'aru
    [3528] = {3520, 3527, 4787},   -- The God Hakkar
    [3802] = {3801},   -- Dark Iron Legacy
    [3907] = {3906},   -- Disharmony of Fire
    [3981] = {3906},   -- Commander Gor'shak
    [3982] = {3906, 3981},   -- What Is Going On?
    [4001] = {3906, 3981, 3982},   -- What Is Going On?
    [4002] = {3906, 3981, 3982, 4001},   -- The Eastern Kingdom
    [4003] = {3906, 3981, 3982, 4001, 4002},   -- The Royal Rescue
    [4004] = {3906, 3981, 3982, 4001, 4002, 4003},   -- The Princess Saved?
    [4024] = {3441, 3442, 3443, 3452, 3453, 3454, 3462, 3463, 3481, 4022},   -- A Taste of Flame
    [4063] = {4061, 4062},   -- The Rise of the Machines
    [4082] = {4081},   -- KILL ON SIGHT: High Ranking Dark Iron Officials
    [4126] = {4128},   -- Hurley Blackbreath
    [4132] = {4122, 4121},   -- Operation: Death to Angerforge
    [4134] = {4133},   -- Lost Thunderbrew Recipe
    [4136] = {4324},   -- Ribbly Screwspigot
    [4143] = {4141, 4142},   -- Haze of Evil
    [4146] = {4145, 4147},   -- Zapper Fuel
    [4263] = {4262},   -- Incendius!
    [4341] = {3702, 3701},   -- Kharan Mighthammer
    [4361] = {3702, 3701, 4341},   -- The Bearer of Bad News
    [4362] = {3702, 3701, 4341, 4361},   -- The Fate of the Kingdom
    [4363] = {3702, 3701, 4341, 4361, 4362},   -- The Princess's Surprise
    [4734] = {4726, 4808, 4809, 4810},   -- Egg Freezing
    [4735] = {4726, 4808, 4809, 4810, 4734},   -- Egg Collection
    [4764] = {4766},   -- Doomrigger's Clasp
    [4768] = {4769},   -- The Darkstone Tablet
    [4771] = {4726, 4808, 4809, 4810, 4734, 4735, 5522, 5531},   -- Dawn's Gambit
    [4788] = {3520, 3527, 4787, 3528, 5065},   -- The Final Tablets
    [4974] = {4903, 4941},   -- For The Horde!
    [4982] = {4981},   -- Bijou's Belongings
    [5002] = {5001},   -- Message to Maxwell
    [5081] = {5001, 5002},   -- Maxwell's Mission
    [5125] = {5122},   -- Aurius' Reckoning
    [5213] = {5212},   -- The Active Agent
    [5262] = {5251},   -- The Truth Comes Crashing Down
    [5263] = {5251, 5262},   -- Above and Beyond
    [5282] = {5281},   -- The Restless Souls
    [5384] = {5382, 5515},   -- Kirtonos the Herald
    [5463] = {5382, 5515, 5384, 5461, 5462},   -- Menethil's Gift
    [5466] = {5382, 5515, 5384, 5461, 5462, 5463, 5464, 5465},   -- The Lich, Ras Frostwhisper
    [5505] = {5066, 5092, 5097, 5533, 5537, 5538, 5801, 5803},   -- The Key to Scholomance
    [5511] = {5093, 5096, 5098, 838, 964, 5514, 5802, 5804},   -- The Key to Scholomance
    [5515] = {5382},   -- Krastinov's Bag of Horrors
    [5526] = {5527},   -- Shards of the Felvine
    [5724] = {5722},   -- Returning the Lost Satchel
    [5728] = {5726, 5727},   -- Hidden Enemies
    [5848] = {5542, 5543, 5544, 5742, 5781, 5845, 5846},   -- Of Love and Family
    [6163] = {6133, 6135},   -- Ramstein
    [6521] = {6522},   -- An Unholy Alliance
    [6563] = {6562},   -- The Essence of Aku'Mai
    [6821] = {6804, 6805},   -- Eye of the Emberseer
    [7046] = {7044},   -- The Scepter of Celebras
    [7488] = {7494},   -- Lethtendris's Web
    [7489] = {7492},   -- Lethtendris's Web
    [7877] = {7461},   -- The Treasure of the Shen'dralar
    [8232] = {8151, 8153, 8231},   -- The Green Drake
    [8236] = {8234, 8235},   -- The Azure Key
    [8253] = {8250, 8251, 8252},   -- Destroy Morphaz
    [8257] = {8254, 8255, 8256},   -- Blood of Morphaz
    [8413] = {8410, 8412},   -- Da Voodoo
    [8418] = {8414, 8416},   -- Forging the Mightstone
    [8422] = {8419, 8421},   -- Trolls of a Feather
    [8425] = {8423, 8424},   -- Voodoo Feathers
    [9053] = {9063, 9052, 9051},   -- A Better Ingredient
    [92422] = {356, 99156},   -- The Wrath of Rath'mael
    [92434] = {544, 93680, 545},   -- Blood in the Streets
    [92457] = {92432},   -- Starving Arcane
    [92458] = {92432},   -- Heart of Disruption
    [92753] = {92742, 92744, 92745, 92747, 92748, 92749, 92750, 92751, 92752},   -- Destruction in Deadmines
    [94968] = {93786, 93787, 94483, 94672, 94680, 94727, 95417, 95601, 95602, 95427, 95418, 95420, 95424, 95425, 95428, 94744, 94745, 94748, 94768, 95278},   -- Eye of Mugg
    [94972] = {93786, 93787, 94483, 94672, 94680, 94727, 95417, 95601, 95602, 95427, 95418, 95420, 95424, 95425, 95428, 94744, 94745, 94748, 94768, 95278},   -- Tome of Twilight
    [94975] = {93786, 93787, 94483, 94672, 94680, 94727, 95417, 95601, 95602, 95427, 95418, 95420, 95424, 95425, 95428, 94744, 94745, 94748, 94768},   -- A Token of Vengeance
    [94983] = {94879, 94886, 94888, 94889, 94890},   -- Twilight Mementos
    [94984] = {94881, 94907},   -- Tome of Twilight
    [95216] = {447, 450, 451},   -- The New Plague
    [95646] = {276, 277, 275},   -- Horrors in the Highland
    [95682] = {95663},   -- Open the Maw
    [95775] = {629, 95748, 95770},   -- The Drowned City
    [95776] = {629, 95748, 95770, 95773},   -- The Only Good Brinescale...
    [95787] = {204, 203, 207, 205, 95786},   -- Take Two With Water
    [95788] = {204, 203, 207, 205, 95786},   -- Magics of the Drowned City
    [96393] = {96391},   -- Old Ironforge Incursion
    [96984] = {544, 93680, 545, 92434},   -- Heart of Disruption
    [98815] = {484},   -- Highland Hides
}

local NEEDS = {
    [17] = { afterAny={2500} },   -- Uldaman Reagent Run
    [166] = { afterAny={155} },   -- The Defias Brotherhood
    [214] = { afterAny={155} },   -- Red Silk Bandanas
    [378] = { afterAny={303} },   -- The Fury Runs Deep
    [391] = { afterAny={389} },   -- The Stockade Riots
    [545] = { after={544, 93680} },   -- Dalaran Patrols
    [704] = { afterAny={739} },   -- Agmond's Fate
    [722] = { afterAny={721} },   -- Amulet of Secrets
    [914] = { afterAny={1490} },   -- Leaders of the Fang
    [1053] = { afterAny={1052} },   -- In the Name of the Light
    [1101] = { afterAny={1100} },   -- The Crone of the Kraul
    [1113] = { afterAny={1109} },   -- Hearts of Zeal
    [1139] = { afterAny={762} },   -- The Lost Tablets of Will
    [1160] = { afterAny={1159} },   -- Test of Lore
    [1200] = { afterAny={1198} },   -- Blackfathom Villainy
    [1275] = { afterAny={3765} },   -- Researching the Corruption
    [1445] = { afterAny={1444} },   -- The Temple of Atal'Hakkar
    [1475] = { afterAny={1469} },   -- Into The Temple of Atal'Hakkar
    [1491] = { afterAny={865} },   -- Smart Drinks
    [1654] = { afterAny={1653} },   -- The Test of Righteousness
    [1701] = { afterAny={1702} },   -- Fire Hardened Mail
    [1838] = { afterAny={1825} },   -- Brutal Armor
    [1951] = { afterAny={1950} },   -- Rituals of Power
    [2202] = { afterAny={2258} },   -- Uldaman Reagent Run
    [2240] = { afterAny={2398} },   -- The Hidden Chamber
    [2843] = { afterAny={2842} },   -- Gnomer-gooooone!
    [2865] = { afterAny={2864} },   -- Scarab Shells
    [2922] = { afterAny={2923} },   -- Save Techbot's Brain!
    [2926] = { afterAny={2927} },   -- Gnogaine
    [2936] = { afterAny={2935} },   -- The Spider God
    [2962] = { afterAny={2926} },   -- The Only Cure is More Green Glow
    [2991] = { afterAny={2990} },   -- Nekrum's Medallion
    [3444] = { afterAny={3380, 3445} },   -- The Stone Circle
    [3446] = { afterAny={3444} },   -- Into the Depths
    [3447] = { afterAny={3444} },   -- Secret of the Circle
    [3525] = { afterAny={3523} },   -- Extinguishing the Idol
    [3527] = { afterAny={3520} },   -- The Prophecy of Mosh'aru
    [3528] = { afterAny={4787} },   -- The God Hakkar
    [3802] = { afterAny={3801} },   -- Dark Iron Legacy
    [3907] = { afterAny={3906} },   -- Disharmony of Fire
    [3981] = { afterAny={3906} },   -- Commander Gor'shak
    [3982] = { afterAny={3981} },   -- What Is Going On?
    [4001] = { afterAny={3982} },   -- What Is Going On?
    [4002] = { afterAny={4001} },   -- The Eastern Kingdom
    [4003] = { afterAny={4002} },   -- The Royal Rescue
    [4004] = { afterAny={4003} },   -- The Princess Saved?
    [4024] = { afterAny={4022, 4023} },   -- A Taste of Flame
    [4063] = { afterAny={4062} },   -- The Rise of the Machines
    [4082] = { afterAny={4081} },   -- KILL ON SIGHT: High Ranking Dark Iron Officials
    [4126] = { afterAny={4128} },   -- Hurley Blackbreath
    [4132] = { afterAny={4121} },   -- Operation: Death to Angerforge
    [4134] = { afterAny={4133} },   -- Lost Thunderbrew Recipe
    [4136] = { afterAny={4324} },   -- Ribbly Screwspigot
    [4143] = { afterAny={4142} },   -- Haze of Evil
    [4146] = { afterAny={4147} },   -- Zapper Fuel
    [4263] = { afterAny={4262} },   -- Incendius!
    [4341] = { afterAny={3701} },   -- Kharan Mighthammer
    [4361] = { afterAny={4341} },   -- The Bearer of Bad News
    [4362] = { afterAny={4361} },   -- The Fate of the Kingdom
    [4363] = { afterAny={4362} },   -- The Princess's Surprise
    [4734] = { afterAny={4810} },   -- Egg Freezing
    [4735] = { afterAny={4734} },   -- Egg Collection
    [4764] = { afterAny={4766} },   -- Doomrigger's Clasp
    [4768] = { afterAny={4769} },   -- The Darkstone Tablet
    [4771] = { afterAny={5531} },   -- Dawn's Gambit
    [4788] = { afterAny={5065} },   -- The Final Tablets
    [4974] = { afterAny={4941} },   -- For The Horde!
    [4982] = { afterAny={4981} },   -- Bijou's Belongings
    [5002] = { afterAny={5001} },   -- Message to Maxwell
    [5081] = { afterAny={5002} },   -- Maxwell's Mission
    [5125] = { afterAny={5122} },   -- Aurius' Reckoning
    [5213] = { afterAny={5212} },   -- The Active Agent
    [5262] = { afterAny={5251} },   -- The Truth Comes Crashing Down
    [5263] = { afterAny={5262} },   -- Above and Beyond
    [5282] = { afterAny={5281} },   -- The Restless Souls
    [5384] = { afterAny={5515} },   -- Kirtonos the Herald
    [5463] = { afterAny={5462} },   -- Menethil's Gift
    [5466] = { afterAny={5465} },   -- The Lich, Ras Frostwhisper
    [5505] = { afterAny={5803} },   -- The Key to Scholomance
    [5511] = { afterAny={5804} },   -- The Key to Scholomance
    [5515] = { afterAny={5382} },   -- Krastinov's Bag of Horrors
    [5526] = { afterAny={5527} },   -- Shards of the Felvine
    [5724] = { afterAny={5722} },   -- Returning the Lost Satchel
    [5728] = { afterAny={5727} },   -- Hidden Enemies
    [5848] = { afterAny={5846} },   -- Of Love and Family
    [6163] = { afterAny={6135} },   -- Ramstein
    [6521] = { afterAny={6522} },   -- An Unholy Alliance
    [6563] = { afterAny={6562} },   -- The Essence of Aku'Mai
    [6821] = { after={6804, 6805} },   -- Eye of the Emberseer
    [7046] = { afterAny={7044} },   -- The Scepter of Celebras
    [7488] = { afterAny={7494} },   -- Lethtendris's Web
    [7489] = { afterAny={7492} },   -- Lethtendris's Web
    [7877] = { afterAny={7461} },   -- The Treasure of the Shen'dralar
    [8232] = { afterAny={8231} },   -- The Green Drake
    [8236] = { afterAny={8235} },   -- The Azure Key
    [8253] = { afterAny={8252} },   -- Destroy Morphaz
    [8257] = { afterAny={8256} },   -- Blood of Morphaz
    [8413] = { afterAny={8412} },   -- Da Voodoo
    [8418] = { afterAny={8416} },   -- Forging the Mightstone
    [8422] = { afterAny={8421} },   -- Trolls of a Feather
    [8425] = { afterAny={8424} },   -- Voodoo Feathers
    [9053] = { afterAny={9051} },   -- A Better Ingredient
    [92422] = { afterAny={99156} },   -- The Wrath of Rath'mael
    [92434] = { afterAny={545} },   -- Blood in the Streets
    [92457] = { afterAny={92432} },   -- Starving Arcane
    [92458] = { afterAny={92432} },   -- Heart of Disruption
    [92753] = { afterAny={92752} },   -- Destruction in Deadmines
    [94968] = { afterAny={95278} },   -- Eye of Mugg
    [94972] = { afterAny={95278} },   -- Tome of Twilight
    [94975] = { afterAny={94768} },   -- A Token of Vengeance
    [94983] = { afterAny={94890} },   -- Twilight Mementos
    [94984] = { afterAny={94907} },   -- Tome of Twilight
    [95216] = { afterAny={451} },   -- The New Plague
    [95646] = { afterAny={275} },   -- Horrors in the Highland
    [95682] = { afterAny={95663} },   -- Open the Maw
    [95775] = { afterAny={95770} },   -- The Drowned City
    [95776] = { after={95770, 95773} },   -- The Only Good Brinescale...
    [95787] = { afterAny={95786} },   -- Take Two With Water
    [95788] = { afterAny={95786} },   -- Magics of the Drowned City
    [96393] = { afterAny={96391} },   -- Old Ironforge Incursion
    [96984] = { afterAny={92434} },   -- Heart of Disruption
    [98815] = { afterAny={484} },   -- Highland Hides
}

-- shared with the other BossNav files
ns.QUEST_CHAIN_STEPS = STEPS
ns.QUEST_CHAINS = CHAINS
ns.QUEST_NEEDS = NEEDS
