-- Dungeon list, boss pins, trails and portraits.
-- A boss row is { name, x, y, floor }; faction = "Horde" or "Alliance" marks a
-- boss only that side can fight (BossNav_Kills.lua drops it for the other side).
local ADDON, ns = ...
-- from the files loaded before this one
local FOREVER_IMG            = ns.FOREVER_IMG
local Norm                   = ns.Norm

-- Creature display IDs per boss, taken from Forever Atlas (AtlasLootClassic_DungeonsAndRaids/data.lua).
-- Used to draw a portrait next to each boss name; bosses without one get a skull.
local BOSS_DISPLAY = {
    ["Taragaman the Hungerer"]=7970, ["Jergosh the Invoker"]=11429, ["Lady Anacondra"]=4313,
    ["Lord Cobrahn"]=4213, ["Kresh"]=5126, ["Lord Pythas"]=4214, ["Skum"]=4203,
    ["Lord Serpentis"]=4215, ["Verdan the Everliving"]=4256, ["Mutanus the Devourer"]=4088,
    ["Rhahk'Zor"]=14403, ["Sneed"]=7125, ["Gilnid"]=7124, ["Captain Greenskin"]=7113,
    ["Mr. Smite"]=2026, ["Cookie"]=1305, ["Edwin VanCleef"]=2029, ["Rethilgore"]=524,
    ["Razorclaw the Butcher"]=524, ["Baron Silverlaine"]=3222, ["Commander Springvale"]=3223,
    ["Odo the Blindwatcher"]=522, ["Fenrus the Devourer"]=2352, ["Wolf Master Nandos"]=11179,
    ["Archmage Arugal"]=2353, ["Kam Deepfury"]=825, ["Ghamoo-ra"]=5027, ["Lady Sarevess"]=4979,
    ["Gelihast"]=1773, ["Twilight Lord Kelris"]=4939, ["Old Serra'kis"]=1816, ["Aku'mai"]=2837,
    ["Grubbis"]=6533, ["Viscous Fallout"]=5497, ["Electrocutioner 6000"]=6915,
    ["Crowd Pummeler 9-60"]=6774, ["Mekgineer Thermaplugg"]=6980, ["Aggem Thorncurse"]=6097,
    ["Death Speaker Jargba"]=4644, ["Overlord Ramtusk"]=4652, ["Agathelos the Raging"]=2450,
    ["Charlga Razorflank"]=4642, ["Tuten'kash"]=7845, ["Mordresh Fire Eye"]=8055, ["Glutton"]=7864,
    ["Ragglesnout"]=11382, ["Amnennar the Coldbringer"]=7971, ["Plaguemaw the Rotting"]=6124,
    ["Interrogator Vishas"]=2044, ["Bloodmage Thalnos"]=11396, ["Houndmaster Loksey"]=2040,
    ["Arcanist Doan"]=5266, ["Herod"]=2041, ["High Inquisitor Fairbanks"]=2605,
    ["Scarlet Commander Mograine"]=2042, ["High Inquisitor Whitemane"]=2043, ["Revelosh"]=5945,
    ["Ironaya"]=6089, ["Obsidian Sentinel"]=5285, ["Ancient Stone Keeper"]=10798,
    ["Galgann Firehammer"]=6059, ["Grimlok"]=11165, ["Archaedas"]=5988, ["Antu'sul"]=7353,
    ["Theka the Martyr"]=6696, ["Witch Doctor Zum'rah"]=6434, ["Nekrum Gutchewer"]=6690,
    ["Shadowpriest Sezz'ziz"]=6441, ["Hydromancer Velratha"]=6685, ["Gahz'rilla"]=7271,
    ["Chief Ukorz Sandscalp"]=6439, ["Noxxion"]=11172, ["Razorlash"]=12389,
    ["Lord Vyletongue"]=12334, ["Celebras the Cursed"]=12350, ["Landslide"]=12293,
    ["Tinkerer Gizlock"]=7125, ["Rotgrip"]=13589, ["Princess Theradras"]=12292,
    ["Atal'alarion"]=7873, ["Avatar of Hakkar"]=8053, ["Jammal'an the Prophet"]=6708,
    ["Dreamscythe"]=7553, ["Weaver"]=6375, ["Hazzas"]=9584, ["Morphaz"]=7975,
    ["Shade of Eranikus"]=7806, ["High Interrogator Gerstahn"]=8761, ["Lord Roccor"]=5781,
    ["Houndmaster Grebmar"]=9212, ["Lord Incendius"]=1204, ["Fineous Darkvire"]=8704,
    ["Bael'Gar"]=12162, ["Pyromancer Loregrain"]=8762, ["Warder Stilgiss"]=9089,
    ["General Angerforge"]=8756, ["Golem Lord Argelmach"]=8759, ["Phalanx"]=8177,
    ["Ambassador Flamelash"]=8329, ["Magmus"]=12162, ["Princess Moira Bronzebeard"]=8705,
    ["Emperor Dagran Thaurissan"]=8807, ["Shadow Hunter Vosh'gajin"]=9732,
    ["War Master Voone"]=9733, ["Mother Smolderweb"]=9929, ["Highlord Omokk"]=11565,
    ["Urok Doomhowl"]=11583, ["Quartermaster Zigris"]=9738, ["Halycon"]=9567,
    ["Gizrul the Slavener"]=9564, ["Overlord Wyrmthalak"]=8711, ["Pyroguard Emberseer"]=2172,
    ["Warchief Rend Blackhand"]=9778, ["The Beast"]=10193, ["General Drakkisath"]=10115,
    ["Lord Valthalak"]=14308, ["Kirtonos the Herald (Kirtonos)"]=7534, ["Jandice Barov"]=11073, ["Rattlegore"]=12073,
    ["Marduk Blackpool"]=10248, ["Vectus"]=2606, ["Kormok"]=16020, ["Ras Frostwhisper"]=7919,
    ["Instructor Malicia"]=11069, ["Doctor Theolen Krastinov"]=10901, ["Lorekeeper Polkelt"]=11492,
    ["The Ravenian"]=10433, ["Lord Alexei Barov"]=11072, ["Lady Illucia Barov"]=11835,
    ["Darkmaster Gandling"]=11070, ["Skul"]=2606, ["Hearthsinger Forresten"]=10482,
    ["The Unforgiven"]=10771, ["Timmy the Cruel"]=571, ["Malor the Zealous"]=10458,
    ["Crimson Hammersmith"]=10637, ["Cannon Master Willey"]=10674, ["Archivist Galford"]=10544,
    ["Balnazzar"]=10545, ["Magistrate Barthilas"]=10433, ["Stonespine"]=7856,
    ["Baroness Anastari"]=10698, ["Black Guard Swordsmith"]=775, ["Nerub'enkan"]=9793,
    ["Maleki the Pallid"]=10546, ["Ramstein the Gorger"]=12818, ["Baron Rivendare"]=10729,
    ["Guard Mol'dar"]=11561, ["Stomper Kreeg"]=11545, ["Guard Fengus"]=11561,
    ["Guard Slip'kik"]=11561, ["Captain Kromcrush"]=11564, ["Cho'Rush the Observer"]=11537,
    ["King Gordok"]=11583, ["Tendris Warpwood"]=14383, ["Illyanna Ravenoak"]=11270,
    ["Magister Kalendris"]=14384, ["Tsu'zee"]=11250, ["Immol'thar"]=14173,
    ["Prince Tortheldrin"]=11256, ["Lord Hel'nurath"]=14556, ["Pusillin"]=7552,
    ["Zevrim Thornhoof"]=11335, ["Hydrospawn"]=5489, ["Lethtendris"]=14378,
    ["Alzzin the Wildshaper"]=14416, ["Lucifron"]=13031, ["Magmadar"]=10193, ["Gehennas"]=13030,
    ["Garr"]=12110, ["Shazzrah"]=13032, ["Baron Geddon"]=12129, ["Golemagg the Incinerator"]=11986,
    ["Sulfuron Harbinger"]=13030, ["Majordomo Executus"]=12029, ["Ragnaros"]=11121, ["Onyxia"]=8570,
    ["High Priestess Jeklik"]=15219, ["High Priest Venoxis"]=15217, ["High Priestess Mar'li"]=15220,
    ["Bloodlord Mandokir"]=11288, ["Gahz'ranka"]=15288, ["High Priest Thekal"]=15216,
    ["High Priestess Arlokk"]=15218, ["Jin'do the Hexxer"]=11311, ["Hakkar"]=15295,
    ["Razorgore the Untamed"]=10115, ["Vaelastrasz the Corrupt"]=13992,
    ["Broodlord Lashlayer"]=14308, ["Firemaw"]=6377, ["Ebonroc"]=6377, ["Flamegor"]=6377,
    ["Chromaggus"]=14367, ["Nefarian"]=11380, ["Kurinnaxx"]=15742, ["General Rajaxx"]=15376,
    ["Moam"]=15392, ["Buru the Gorger"]=15654, ["Ayamiss the Hunter"]=15431,
    ["Ossirian the Unscarred"]=15432, ["The Prophet Skeram"]=15345, ["Silithid Royalty (Bug Trio)"]=15657,
    ["Battleguard Sartura"]=15583, ["Fankriss the Unyielding"]=15743, ["Viscidus"]=15686,
    ["Princess Huhuran"]=15739, ["Twin Emperors"]=15761, ["Ouro"]=15509, ["C'Thun"]=15787,
    -- Added 2026-11-18 from the cmangos classic database (creature_template ModelId1).
    -- Group encounters show their first member.
    ["Oggleflint"]=11611, ["Bazzalan"]=2007, ["Targorr the Dread"]=517, ["Hamhock"]=3250,
    ["Dextren Ward"]=2149, ["Bazil Thredd"]=1621, ["Lorgus Jett"]=12822, ["Roogug"]=6110,
    ["Miner Johnson"]=556, ["The Lost Dwarves"]=5710, ["Hurley Blackbreath"]=8658,
    ["Ribbly Screwspigot"]=8667, ["Plugger Spazzring"]=8652, ["The Seven"]=8687,
    ["Princess Moira Bronzebeard"]=8705, ["Ring of Law"]=9329,   -- High Justice Grimstone, who runs the arena
    ["Anub'Rekhan"]=15931, ["Grand Widow Faerlina"]=15940, ["Maexxna"]=15928,
    ["Noth the Plaguebringer"]=16590, ["Heigan the Unclean"]=16309, ["Loatheb"]=16110,
    ["Instructor Razuvious"]=16582, ["Gothik the Harvester"]=16279, ["The Four Horsemen"]=16139,
    ["Patchwerk"]=16174, ["Grobbulus"]=16035, ["Gluth"]=16064, ["Thaddius"]=16137,
    ["Sapphiron"]=16033, ["Kel'Thuzad"]=15945,
}

--------------------------------------------------------------------------
-- Dungeon data.  Boss entry: { "Name", x%, y%, floor }  (no coords = no pin)
--------------------------------------------------------------------------
local DUNGEONS = {
    { zones = {"Ragefire Chasm"}, folder = "Ragefire", floors = {1}, bosses = {
        {"Oggleflint",55.5,33.4,1},{"Taragaman the Hungerer",39.6,50.2,1},
        {"Jergosh the Invoker",33.5,71.3,1},{"Bazzalan",41.0,75.4,1},
    } },
    { zones = {"Wailing Caverns","The Wailing Caverns"}, folder = "WailingCaverns", floors = {1}, bosses = {
        {"Lady Anacondra",30.1,37.3,1},{"Lord Cobrahn",15.5,49.3,1},{"Kresh",37.6,30.4,1},
        {"Lord Pythas",69.0,54.7,1},{"Skum",53.9,77.3,1},{"Lord Serpentis",60.1,46.7,1},
        {"Verdan the Everliving",66.0,72.5,1},{"Mutanus the Devourer",54.0,40.6,1},
      },
      -- Draft trails (map percent). Unverified in game: fix with /bnav mark, undo, clear.
      routes = {
        ["Lady Anacondra"] = { {41,47,"entrance ramp"}, {36,42,"west passage"} },
        ["Lord Cobrahn"] = { {30,37,"Anacondra's room"}, {22,44,"ramp down south-west"} },
        ["Kresh"] = { {41,47,"entrance ramp"}, {44,40,"central fork, go north"} },
        ["Lord Pythas"] = { {44,40,"central fork, go east"}, {54,40,"past Naralex's chamber"}, {62,48,"down the east tunnel"} },
        ["Skum"] = { {69,55,"Pythas' room"}, {60,65,"water tunnel south"} },
        ["Lord Serpentis"] = { {69,55,"Pythas' room"}, {65,50,"ramp up to the ledge"} },
        ["Verdan the Everliving"] = { {60,47,"Serpentis' ledge"}, {66,60,"south along the ledge"} },
        ["Mutanus the Devourer"] = { {41,47,"talk to Disciple of Naralex at entrance"}, {48,43,"escort north-east"} },
      } },
    { zones = {"The Deadmines","Deadmines"}, folder = "TheDeadmines", floors = {1,2},
      floorNames = {"The Deadmines","Ironclad Cove"}, bosses = {
        {"Rhahk'Zor",35.5,53.5,1},{"Miner Johnson"},{"Sneed",49.2,75.3,1},{"Gilnid",12.1,65.9,2},
        {"Captain Greenskin",59.2,32.7,2},{"Mr. Smite",27.8,40.1,2},{"Cookie",70.0,45.0,2},
        {"Edwin VanCleef",59.4,39.2,2},
    } },
    { zones = {"Shadowfang Keep"}, folder = "ShadowfangKeep", floors = {1,2,3,4,5,6,7},
      floorNames = {"The Courtyard","Dining Hall","The Wall Walk","The Vacant Den","Lower Observatory","Upper Observatory","Lord Godfrey's Chamber"}, bosses = {
        {"Rethilgore",65.2,62.9,1},{"Razorclaw the Butcher",47.8,21.0,2},{"Baron Silverlaine",29.7,66.9,2},
        {"Commander Springvale",27.3,52.2,3},{"Odo the Blindwatcher",57.8,70.8,4},{"Fenrus the Devourer",53.1,46.8,5},
        {"Wolf Master Nandos",54.9,55.0,6},{"Archmage Arugal",50.0,52.0,7},
    } },
    { zones = {"The Stockade","Stormwind Stockade"}, folder = "TheStockade", floors = {1}, bosses = {
        {"Targorr the Dread"},{"Kam Deepfury",68.1,25.5,1},{"Hamhock"},{"Dextren Ward"},{"Bazil Thredd"},
    } },
    { zones = {"Blackfathom Deeps"}, folder = "BlackfathomDeeps", floors = {1,2,3},
      floorNames = {"The Pool of Ask'Ar","Moonshrine Sanctum","The Forgotten Pool"}, bosses = {
        {"Ghamoo-ra",32.1,52.6,1},{"Lady Sarevess",11.1,34.4,1},{"Gelihast",53.2,49.3,1},{"Lorgus Jett"},
        {"Twilight Lord Kelris",51.6,71.1,2},{"Old Serra'kis",57.5,26.3,3},{"Aku'mai",84.0,75.0,2},
    } },
    { zones = {"Gnomeregan"}, folder = "Gnomeregan", floors = {1,2,3,4},
      floorNames = {"The Hall of Gears","The Dormitory","Launch Bay","Tinkers' Court"}, bosses = {
        {"Grubbis",75.8,57.8,1},{"Viscous Fallout",74.1,40.5,2},{"Electrocutioner 6000",23.7,59.0,2},
        {"Crowd Pummeler 9-60",42.1,76.4,3},{"Mekgineer Thermaplugg",50.0,58.0,4},
    } },
    { zones = {"Razorfen Kraul"}, folder = "RazorfenKraul", floors = {1}, bosses = {
        {"Roogug",87.3,41.3,1},{"Aggem Thorncurse",78.9,44.9,1},{"Death Speaker Jargba",85.5,36.2,1},
        {"Overlord Ramtusk",56.2,26.8,1},{"Agathelos the Raging",7.5,59.2,1},{"Charlga Razorflank",21.2,26.7,1},
    } },
    { zones = {"Razorfen Downs"}, folder = "RazorfenDowns", floors = {1}, bosses = {
        {"Tuten'kash",57.8,29.6,1},{"Mordresh Fire Eye",83.9,40.4,1},{"Glutton",33.8,58.0,1},
        {"Ragglesnout",34.9,42.0,1},{"Amnennar the Coldbringer",43.4,52.5,1},{"Plaguemaw the Rotting",49.3,60.5,1},
    } },
    { zones = {"Scarlet Monastery"}, folder = "ScarletMonastery", floors = {1,2,3,4},
      floorNames = {"Graveyard","Library","Armory","Cathedral"},
      floorBySubzone = {
        ["Chamber of Atonement"] = 1, ["Forlorn Cloister"] = 1, ["Honor's Tomb"] = 1,
        ["Huntsman's Cloister"] = 2, ["Gallery of Treasures"] = 2, ["Athenaeum"] = 2,
        ["Training Grounds"] = 3, ["Footman's Armory"] = 3, ["Crusader's Armory"] = 3, ["Hall of Champions"] = 3,
        ["Chapel Gardens"] = 4, ["Crusader's Chapel"] = 4,
      }, bosses = {
        {"Interrogator Vishas",49.0,63.0,1},{"Bloodmage Thalnos",23.5,48.8,1},
        {"Houndmaster Loksey",47.0,47.0,2},{"Arcanist Doan",81.6,64.6,2},
        {"Herod",52.0,42.0,3},
        {"High Inquisitor Fairbanks",40.0,24.0,4},{"Scarlet Commander Mograine",48.1,14.4,4},{"High Inquisitor Whitemane",48.0,24.0,4},
    } },
    { zones = {"Uldaman"}, folder = "Uldaman", floors = {1}, bosses = {
        {"The Lost Dwarves",57.3,80.0,1},{"Revelosh",52.2,63.0,1},{"Ironaya",36.1,64.1,1},{"Obsidian Sentinel",28.3,52.2,1},
        {"Ancient Stone Keeper",46.5,38.3,1},{"Galgann Firehammer",25.8,28.3,1},{"Grimlok",21.3,22.6,1},{"Archaedas",40.8,14.3,1},
    } },
    { zones = {"Zul'Farrak"}, folder = "ZulFarrak", floors = {1}, special = true, bosses = {
        {"Antu'sul",62.9,23.9,1},{"Theka the Martyr",51.6,22.8,1},{"Witch Doctor Zum'rah",28.8,14.8,1},{"Nekrum Gutchewer",29.8,18.3,1},
        {"Shadowpriest Sezz'ziz",24.0,15.2,1},{"Hydromancer Velratha",41.4,29.1,1},{"Gahz'rilla",62.7,63.3,1},{"Chief Ukorz Sandscalp",88.0,63.3,1},
    } },
    { zones = {"Maraudon"}, folder = "Maraudon", floors = {1,2}, floorNames = {"Orange / Purple Side","Earth Song Falls"}, bosses = {
        {"Noxxion",35.0,8.6,1},{"Razorlash",16.0,29.6,1},{"Lord Vyletongue",36.8,61.4,1},{"Celebras the Cursed",23.9,12.1,2},
        {"Landslide",40.3,42.6,2},{"Tinkerer Gizlock",49.6,56.6,2},{"Rotgrip",40.5,71.0,2},{"Princess Theradras",25.4,68.6,2},
    } },
    { zones = {"The Temple of Atal'Hakkar","Temple of Atal'Hakkar","Sunken Temple"}, folder = "TheTempleofAtalhakkar", floors = {1}, bosses = {
        {"Atal'alarion",59.6,13.4,1},{"Avatar of Hakkar",23.5,39.4,1},{"Jammal'an the Prophet",74.4,39.7,1},{"Dreamscythe",51.9,41.5,1},
        {"Weaver",45.7,41.7,1},{"Hazzas",48.7,75.5,1},{"Morphaz",45.5,75.5,1},{"Shade of Eranikus",65.0,76.3,1},
    } },
    { zones = {"Blackrock Depths"}, folder = "BlackrockDepths", floors = {1,2}, floorNames = {"Detention Block","Domicile / Inner City"}, bosses = {
        {"High Interrogator Gerstahn",47.4,92.2,1},{"Lord Roccor",55.6,67.0,1},{"Houndmaster Grebmar",53.5,57.4,1},{"Ring of Law",49.8,64.6,1},
        {"Lord Incendius",56.4,31.1,1},{"Fineous Darkvire",63.5,21.1,1},{"Bael'Gar",25.1,53.5,1},
        {"Pyromancer Loregrain",54.9,94.9,2},{"Warder Stilgiss",60.2,66.0,2},{"General Angerforge",36.3,82.4,2},{"Golem Lord Argelmach",36.5,65.2,2},
        {"Hurley Blackbreath",50.6,70.5,2},{"Ribbly Screwspigot",49.0,67.8,2},{"Plugger Spazzring",47.7,65.7,2},{"Phalanx",45.8,56.5,2},
        {"Ambassador Flamelash",53.8,48.6,2},{"The Seven",53.8,24.8,2},{"Magmus",79.6,11.9,2},
        {"Princess Moira Bronzebeard",91.0,11.9,2},{"Emperor Dagran Thaurissan",91.0,11.9,2},
    } },
    { zones = {"Blackrock Spire","Lower Blackrock Spire","Upper Blackrock Spire"}, folder = "BlackrockSpire", floors = {1,2,3,6,7},
      floorNames = {"LBRS: Tazz'Alaor / Skitterweb","UBRS: Hall of Binding / Rookery","LBRS: Hordemar City","LBRS: Chamber of Battle","UBRS: Hall of Blackhand / Spire Throne"}, bosses = {
        {"Shadow Hunter Vosh'gajin",55.3,69.3,1},{"War Master Voone",52.5,54.5,1},{"Mother Smolderweb",62.1,74.1,1},
        {"Highlord Omokk",38.7,59.0,3},{"Urok Doomhowl",45.5,55.7,3},{"Quartermaster Zigris",54.0,84.4,3},{"Halycon",38.0,84.0,3},{"Gizrul the Slavener",39.5,79.3,3},
        {"Overlord Wyrmthalak",57.5,60.0,6},
        {"Pyroguard Emberseer",18.0,69.0,2},{"Warchief Rend Blackhand",49.0,46.0,7},{"The Beast",82.0,53.0,7},{"General Drakkisath",51.0,10.0,7},{"Lord Valthalak",82.0,53.0,7},
    } },
    { zones = {"Scholomance"}, folder = "Scholomance", floors = {1,2,3,4}, floorNames = {"Reliquary","Summoning / Ossuary","Lower Study","Headmaster's Study"}, bosses = {
        {"Kirtonos the Herald (Kirtonos)",78.0,82.0,1},{"Jandice Barov",39.0,10.0,2},{"Rattlegore",49.0,45.0,2},{"Marduk Blackpool",69.0,58.0,2},{"Vectus",79.0,66.0,2},
        {"Kormok",7.0,74.0,2},{"Ras Frostwhisper",7.0,74.0,2},{"Instructor Malicia",33.0,79.0,4},{"Doctor Theolen Krastinov",69.0,62.0,4},
        {"Lorekeeper Polkelt",32.0,47.0,4},{"The Ravenian",33.0,30.0,4},{"Lord Alexei Barov",59.0,17.0,4},{"Lady Illucia Barov",32.0,8.0,4},{"Darkmaster Gandling",37.0,17.0,4},
    } },
    { zones = {"Stratholme"}, folder = "Stratholme", floors = {1,2}, floorNames = {"Living Side","Undead Side"}, bosses = {
        {"Skul",81.9,34.7,1},{"Hearthsinger Forresten",83.1,29.4,1},{"The Unforgiven",72.0,17.4,1},{"Timmy the Cruel",38.4,24.7,1},{"Malor the Zealous",29.0,35.3,1},
        {"Crimson Hammersmith",11.4,41.6,1},{"Cannon Master Willey",4.0,44.0,1},{"Archivist Galford",26.6,65.1,1},{"Balnazzar",19.8,71.0,1},
        {"Magistrate Barthilas",61.0,65.3,2},{"Stonespine",66.3,63.6,2},{"Baroness Anastari",66.0,43.7,2},{"Black Guard Swordsmith",72.5,40.1,2},
        {"Nerub'enkan",55.8,40.4,2},{"Maleki the Pallid",66.1,18.9,2},{"Ramstein the Gorger",44.3,17.1,2},{"Baron Rivendare",38.2,17.7,2},
    } },
    { zones = {"Dire Maul"}, folder = "Diremaul", floors = {1,2,3,4,5,6},
      floorNames = {"North: Gordok Commons","West: Capital Gardens","West: Upper Gardens","West: Prison of Immol'thar","East: Warpwood Quarter","East: Conservatory"}, bosses = {
        {"Guard Mol'dar",67.9,66.0,1},{"Stomper Kreeg",59.5,59.3,1},{"Guard Fengus",48.4,67.9,1},{"Guard Slip'kik",25.6,49.5,1},{"Captain Kromcrush",31.2,43.4,1},{"Cho'Rush the Observer",31.1,22.9,1},{"King Gordok",31.1,19.1,1},
        {"Tendris Warpwood",32.5,46.4,2},{"Illyanna Ravenoak",18.8,48.7,2},{"Magister Kalendris",20.3,68.0,2},{"Tsu'zee",31.3,12.7,3},{"Immol'thar",34.1,49.9,4},{"Prince Tortheldrin",60.8,20.3,4},{"Lord Hel'nurath",37.6,50.0,4},
        {"Pusillin",42.9,41.4,5},{"Zevrim Thornhoof",56.5,64.2,6},{"Hydrospawn",56.4,60.3,6},{"Lethtendris",52.4,62.0,6},{"Alzzin the Wildshaper",55.2,25.0,6},
    } },
    -- Raids
    { zones = {"Molten Core"}, folder = "MoltenCore", floors = {1}, bosses = {
        {"Lucifron",64.3,32.8,1},{"Magmadar",67.4,20.6,1},{"Gehennas",32.5,42.4,1},{"Garr",30.3,60.6,1},{"Shazzrah",51.3,67.5,1},
        {"Baron Geddon",54.0,73.7,1},{"Golemagg the Incinerator",67.1,50.9,1},{"Sulfuron Harbinger",80.9,72.2,1},{"Majordomo Executus",82.1,57.3,1},{"Ragnaros",54.5,47.2,1},
    } },
    { zones = {"Onyxia's Lair"}, folder = "OnyxiasLair", floors = {1}, bosses = { {"Onyxia",50.0,50.0,1} } },
    { zones = {"Zul'Gurub"}, folder = "ZulGurub", floors = {1}, special = true, bosses = {
        {"High Priestess Jeklik",37.9,63.6,1},{"High Priest Venoxis",49.8,47.2,1},{"High Priestess Mar'li",47.2,68.2,1},{"Bloodlord Mandokir",58.9,69.5,1},
        {"Gahz'ranka",56.3,29.6,1},{"High Priest Thekal",61.1,29.7,1},{"High Priestess Arlokk",46.8,18.0,1},{"Jin'do the Hexxer",30.8,21.5,1},{"Hakkar",48.9,34.6,1},
    } },
    -- Blackwing Lair, both Ahn'Qiraj raids and Naxxramas: pins from the game's own encounter
    -- journal positions (retail JournalEncounter via wago.tools), scaled to the classic map tiles
    -- (x * 1002/1024, y * 668/768). The same scaling reproduces the Molten Core and Wailing
    -- Caverns pins above within about 1%. Not yet checked in game.
    { zones = {"Blackwing Lair"}, folder = "BlackwingLair", floors = {1,2,3,4},
      floorNames = {"Dragonmaw Garrison","Halls of Strife","Crimson Laboratories","Nefarian's Lair"}, bosses = {
        {"Razorgore the Untamed",41.0,52.4,1},{"Vaelastrasz the Corrupt",32.6,24.0,1},{"Broodlord Lashlayer",49.5,53.7,3},
        {"Firemaw",45.4,37.4,3},{"Ebonroc",34.2,18.2,3},{"Flamegor",34.8,32.3,4},{"Chromaggus",38.6,63.2,4},{"Nefarian",68.9,63.0,4},
    } },
    { zones = {"Ruins of Ahn'Qiraj"}, folder = "RuinsofAhnQiraj", floors = {1}, special = true, bosses = {
        {"Kurinnaxx",55.1,31.1,1},{"General Rajaxx",57.1,42.7,1},{"Moam",32.2,31.4,1},{"Buru the Gorger",68.3,54.0,1},
        {"Ayamiss the Hunter",60.4,78.7,1},{"Ossirian the Unscarred",42.0,60.5,1},
    } },
    { zones = {"Ahn'Qiraj","Temple of Ahn'Qiraj","Ahn'Qiraj Temple"}, folder = "AhnQiraj", floors = {1,2,3},
      floorNames = {"The Hive Undergrounds","The Temple Gates","Vault of C'Thun"}, bosses = {
        {"The Prophet Skeram",44.8,45.4,2},{"Silithid Royalty (Bug Trio)",27.8,43.3,1},{"Battleguard Sartura",43.6,29.2,1},
        {"Fankriss the Unyielding",61.0,19.0,1},{"Viscidus",70.6,15.6,1},{"Princess Huhuran",42.6,43.8,1},
        {"Twin Emperors",59.4,60.7,1},{"Ouro",29.5,71.2,1},{"C'Thun",55.8,54.4,3},
    } },
    { zones = {"Naxxramas"}, folder = "Naxxramas", floors = {1,2,3,4,6},
      floorNames = {"The Construct Quarter","The Arachnid Quarter","The Military Quarter","The Plague Quarter","The Upper Necropolis"}, bosses = {
        {"Anub'Rekhan",30.0,40.9,2},{"Grand Widow Faerlina",43.2,31.4,2},{"Maexxna",67.2,13.3,2},
        {"Noth the Plaguebringer",33.9,49.1,4},{"Heigan the Unclean",48.7,39.7,4},{"Loatheb",74.4,24.7,4},
        {"Instructor Razuvious",41.8,40.0,3},{"Gothik the Harvester",66.1,51.9,3},{"The Four Horsemen",29.5,66.8,3},
        {"Patchwerk",53.0,36.3,1},{"Grobbulus",60.3,46.2,1},{"Gluth",45.3,38.1,1},{"Thaddius",26.0,12.7,1},
        {"Sapphiron",55.3,58.7,6},{"Kel'Thuzad",35.7,19.4,6},
    } },
    -- WoW Forever dungeons (map art in BossNav/Images where available, originally from Forever Atlas)
    { zones = {"The Hall of Thanes","Hall of Thanes"}, floors = {1},
      bundled = FOREVER_IMG .. "HallOfThanes.tga", bundledAspect = 0.871, bosses = {
        {"Faldrim Anvilmar",44.1,66.6,1},{"Magmatus (Infurnus)",89.5,41.4,1},{"Plunder",49.6,48.7,1},{"Durgen Dirgehammer",49.6,9.2,1},
    } },
    { zones = {"Ruins of Lordaeron"}, floors = {1},
      bundled = FOREVER_IMG .. "RuinsOfLordaeron.tga", bundledAspect = 1.004, bosses = {
        {"Witherfang",71.6,48.6,1},{"The Baron (The Butcher)",57.6,71.5,1},{"The Abandoned",31.5,53.1,1},
        {"Bjork",33.7,32.0,1},{"Rath'mael",38.5,61.4,1},{"Viktor the Vile",27.2,63.3,1},
        -- rare, may spawn in the west part once the others are dead; friendly to
        -- the Alliance, so only Horde can kill it (guides on method.gg, icy-veins)
        {"Lordaeron Captain", faction = "Horde"},
    } },
    { zones = {"Excavation Site: Wetlands","Excavation Site"}, floors = {1}, bosses = {
        {"Saltspine"},{"Shadetooth"},{"Highland Horror"},{"Relic Guardian"},
    } },
    { zones = {"City of Dalaran"}, floors = {1}, bosses = {
        {"Arcane Anomaly"},{"Fel Ancient"},{"Mana Devourer"},{"Mana Elemental"},{"Unstable Sentinel"},
        {"Shade of the Archmage"},{"Lyn the Ignored"},{"Atrexis the Grave Knight"},{"Mana Wraith"},
    } },
    { zones = {"Half-Pint Tavern","The Half-Pint Tavern"}, floors = {1}, bosses = { {"Deathulus"},{"Crushfist Bloodbreaker"} } },
    -- Forever dungeons with no map art or pins yet. Boss names come from the game client's
    -- DungeonEncounter table (WoW Forever build 1.60.1.70959, via wago.tools), so they match
    -- the names the game reports on a kill. /bnav markboss X Y places a pin.
    { zones = {"Blackmaw Hold"}, floors = {1}, bosses = {
        {"Withermaw"},{"Impaan the Imprisoner"},{"Bonesnout the Unbroken"},{"Blackmaw Behemoth"},
        {"Elder Shaman Bloodmane"},{"Varrox Bleakhoof"},{"Unbound Spirit"},
    } },
    { zones = {"Alcaz Prison"}, floors = {1}, bosses = {
        {"Overseer Wrex"},{"Blazeroar"},{"Tidemistress Ca'zass"},{"The Questioner"},{"Katerina the Cleaner"},
    } },
    { zones = {"Krol'dok Stronghold"}, floors = {1}, bosses = {
        {"Nar'gurk"},{"Slavecrusher Grox"},{"Overseer Mugg"},{"Twilight Commander Zarmok"},{"Handler Ashka"},
    } },
    { zones = {"The Drowned City","Drowned City"}, floors = {1}, bosses = {
        {"Zul'Alai"},{"Var'Taka"},{"Captain Dreadrise"},{"Deathless Guardians"},{"Min'loth the Serpent"},{"Primeval Elemental"},
    } },
    { zones = {"The Shaper's Terrace","Shaper's Terrace"}, floors = {1}, bosses = {
        {"Titanosaur"},{"Ravasaur Hunters"},{"Thunderhoof"},{"Venomridge"},{"Nanaya"},{"Cinder"},
        {"King Op"},{"Bolt"},{"Direhorn Matriarch"},{"Snowtalon"},{"Vitrix"},
    } },
}

local ZONE_INDEX = {}
for _, cfg in ipairs(DUNGEONS) do
    cfg.key = Norm(cfg.zones[1])
    cfg.name = cfg.zones[1]
    for _, z in ipairs(cfg.zones) do ZONE_INDEX[Norm(z)] = cfg end
end

-- Creature (NPC) IDs per boss, also from Forever Atlas data. Used to recognise a boss
-- from its unit GUID when the client hides the unit name as a secret value.
-- A few bosses have several creature IDs (phases / variants).
local BOSS_NPC = {
    ["Agathelos the Raging"]=4422, ["Aggem Thorncurse"]=4424, ["Aku'mai"]=4829,
    ["Alzzin the Wildshaper"]=11492, ["Ambassador Flamelash"]=9156, ["Amnennar the Coldbringer"]=7358,
    ["Ancient Stone Keeper"]=7206, ["Antu'sul"]=8127, ["Arcanist Doan"]=6487, ["Archaedas"]=2748,
    ["Archivist Galford"]=10811, ["Archmage Arugal"]=4275, ["Atal'alarion"]=8580,
    ["Avatar of Hakkar"]=8443, ["Ayamiss the Hunter"]=15369, ["Bael'Gar"]=9016,
    ["Balnazzar"]={10812,10813}, ["Baron Geddon"]=12056, ["Baron Rivendare"]=10440,
    ["Baron Silverlaine"]=3887, ["Baroness Anastari"]=10436, ["Battleguard Sartura"]=15516,
    ["Black Guard Swordsmith"]=11121, ["Bloodlord Mandokir"]=11382, ["Bloodmage Thalnos"]=4543,
    ["Broodlord Lashlayer"]=12017, ["Silithid Royalty (Bug Trio)"]={15543,15544,15511}, ["Buru the Gorger"]=15370,
    ["C'Thun"]=15727, ["Cannon Master Willey"]=10997, ["Captain Greenskin"]=647,
    ["Captain Kromcrush"]=14325, ["Celebras the Cursed"]=12225, ["Charlga Razorflank"]=4421,
    ["Chief Ukorz Sandscalp"]=7267, ["Cho'Rush the Observer"]=14324, ["Chromaggus"]=14020,
    ["Commander Springvale"]=4278, ["Cookie"]=645, ["Crimson Hammersmith"]=11120,
    ["Crowd Pummeler 9-60"]=6229, ["Darkmaster Gandling"]=1853, ["Death Speaker Jargba"]=4428,
    ["Doctor Theolen Krastinov"]=11261, ["Dreamscythe"]=5721, ["Ebonroc"]=14601,
    ["Edwin VanCleef"]=639, ["Electrocutioner 6000"]=6235, ["Emperor Dagran Thaurissan"]=9019,
    ["Fankriss the Unyielding"]=15510, ["Fenrus the Devourer"]=4274, ["Fineous Darkvire"]=9056,
    ["Firemaw"]=11983, ["Flamegor"]=11981, ["Gahz'ranka"]=15114, ["Gahz'rilla"]=7273,
    ["Galgann Firehammer"]=7291, ["Garr"]=12057, ["Gehennas"]=12259, ["Gelihast"]=6243,
    ["General Angerforge"]=9033, ["General Drakkisath"]=10363, ["General Rajaxx"]=15341,
    ["Ghamoo-ra"]=4887, ["Gilnid"]=1763, ["Gizrul the Slavener"]=10268, ["Glutton"]=8567,
    ["Golem Lord Argelmach"]=8983, ["Golemagg the Incinerator"]=11988, ["Grimlok"]=4854,
    ["Grubbis"]=7361, ["Guard Fengus"]=14321, ["Guard Mol'dar"]=14326, ["Guard Slip'kik"]=14323,
    ["Hakkar"]=14834, ["Halycon"]=10220, ["Hazzas"]=5722, ["Hearthsinger Forresten"]=10558,
    ["Herod"]=3975, ["High Inquisitor Fairbanks"]=4542, ["High Inquisitor Whitemane"]=3977,
    ["High Priest Thekal"]=14509, ["High Priest Venoxis"]=14507, ["High Priestess Arlokk"]=14515,
    ["High Priestess Jeklik"]=14517, ["High Priestess Mar'li"]=14510, ["Highlord Omokk"]=9196,
    ["Houndmaster Grebmar"]=9319, ["Houndmaster Loksey"]=3974, ["Hydromancer Velratha"]=7795,
    ["Hydrospawn"]=13280, ["Illyanna Ravenoak"]=11488, ["Immol'thar"]=11496,
    ["Instructor Malicia"]=10505, ["Interrogator Vishas"]=3983, ["Ironaya"]=7228,
    ["Jammal'an the Prophet"]=5710, ["Jandice Barov"]=10503, ["Jergosh the Invoker"]=11518,
    ["Jin'do the Hexxer"]=11380, ["Kam Deepfury"]=1666, ["King Gordok"]=11501, ["Kormok"]=16118,
    ["Kresh"]=3653, ["Kurinnaxx"]=15348, ["Lady Anacondra"]=3671, ["Lady Illucia Barov"]=10502,
    ["Lady Sarevess"]=4831, ["Landslide"]=12203, ["Lethtendris"]=14327, ["Lord Alexei Barov"]=10504,
    ["Lord Cobrahn"]=3669, ["Lord Hel'nurath"]=14506, ["Lord Incendius"]=9017, ["Lord Pythas"]=3670,
    ["Lord Roccor"]=9025, ["Lord Serpentis"]=3673, ["Lord Valthalak"]=16042, ["Lord Vyletongue"]=12236,
    ["Lorekeeper Polkelt"]=10901, ["Lucifron"]=12118, ["Magister Kalendris"]=11487,
    ["Magistrate Barthilas"]=10435, ["Magmadar"]=11982, ["Magmus"]=9938, ["Majordomo Executus"]=12018,
    ["Maleki the Pallid"]=10438, ["Malor the Zealous"]=11032, ["Marduk Blackpool"]=10433,
    ["Mekgineer Thermaplugg"]=7800, ["Moam"]=15340, ["Mordresh Fire Eye"]=7357, ["Morphaz"]=5719,
    ["Mother Smolderweb"]=10596, ["Mr. Smite"]=646, ["Mutanus the Devourer"]=3654, ["Nefarian"]=11583,
    ["Nekrum Gutchewer"]=7796, ["Nerub'enkan"]=10437, ["Noxxion"]=13282, ["Obsidian Sentinel"]=7023,
    ["Odo the Blindwatcher"]=4279, ["Old Serra'kis"]=4830, ["Onyxia"]=10184,
    ["Ossirian the Unscarred"]=15339, ["Ouro"]=15517, ["Overlord Ramtusk"]=4420,
    ["Overlord Wyrmthalak"]=9568, ["Phalanx"]=9502, ["Plaguemaw the Rotting"]=7356,
    ["Prince Tortheldrin"]=11486, ["Princess Huhuran"]=15509, ["Princess Theradras"]=12201,
    ["Pusillin"]=14354, ["Pyroguard Emberseer"]=9816, ["Pyromancer Loregrain"]=9024,
    ["Quartermaster Zigris"]=9736, ["Ragglesnout"]=7354, ["Ragnaros"]=11502,
    ["Ramstein the Gorger"]=10439, ["Rattlegore"]=11622, ["Razorclaw the Butcher"]=3886,
    ["Razorgore the Untamed"]=12435, ["Razorlash"]=12258, ["Rethilgore"]=3914, ["Revelosh"]=6910,
    ["Rhahk'Zor"]=644, ["Rotgrip"]=13596, ["Scarlet Commander Mograine"]=3976,
    ["Shade of Eranikus"]=5709, ["Shadow Hunter Vosh'gajin"]=9236, ["Shadowpriest Sezz'ziz"]=7275,
    ["Shazzrah"]=12264, ["Skul"]=10393, ["Skum"]=3674, ["Sneed"]=643, ["Stomper Kreeg"]=14322,
    ["Stonespine"]=10809, ["Sulfuron Harbinger"]=12098, ["Taragaman the Hungerer"]=11520,
    ["Tendris Warpwood"]=11489, ["The Beast"]=10430, ["The Prophet Skeram"]=15263,
    ["The Ravenian"]=10507, ["The Unforgiven"]=10516, ["Theka the Martyr"]=7272,
    ["Timmy the Cruel"]=10808, ["Tinkerer Gizlock"]=13601, ["Tsu'zee"]=11467, ["Tuten'kash"]=7355,
    ["Twilight Lord Kelris"]=4832, ["Twin Emperors"]={15275,15276}, ["Urok Doomhowl"]=10584,
    ["Vaelastrasz the Corrupt"]=13020, ["Vectus"]=10432, ["Verdan the Everliving"]=5775,
    ["Viscidus"]=15299, ["Viscous Fallout"]=7079, ["War Master Voone"]=9237,
    ["Warchief Rend Blackhand"]=10429, ["Warder Stilgiss"]=9041, ["Weaver"]=5720,
    ["Witch Doctor Zum'rah"]=7271, ["Wolf Master Nandos"]=3927, ["Zevrim Thornhoof"]=11490,
    -- Added 2026-11-18 from the cmangos classic database, names checked on Wowhead Classic.
    ["Oggleflint"]=11517, ["Bazzalan"]=11519, ["Targorr the Dread"]=1696, ["Hamhock"]=1717,
    ["Dextren Ward"]=1663, ["Bazil Thredd"]=1716, ["Lorgus Jett"]=12902, ["Roogug"]=6168,
    ["Miner Johnson"]=3586, ["The Lost Dwarves"]={6906,6907,6908}, ["High Interrogator Gerstahn"]=9018,
    ["Ring of Law"]={9027,9028,9029,9030,9031,9032}, ["Hurley Blackbreath"]=9537,
    ["Ribbly Screwspigot"]=9543, ["Plugger Spazzring"]=9499,
    ["The Seven"]={9034,9035,9036,9037,9038,9039,9040}, ["Princess Moira Bronzebeard"]=8929,
    ["Kirtonos the Herald (Kirtonos)"]=10506, ["Ras Frostwhisper"]=10508,
    ["Anub'Rekhan"]=15956, ["Grand Widow Faerlina"]=15953, ["Maexxna"]=15952,
    ["Noth the Plaguebringer"]=15954, ["Heigan the Unclean"]=15936, ["Loatheb"]=16011,
    ["Instructor Razuvious"]=16061, ["Gothik the Harvester"]=16060,
    ["The Four Horsemen"]={16062,16063,16064,16065}, ["Patchwerk"]=16028, ["Grobbulus"]=15931,
    ["Gluth"]=15932, ["Thaddius"]=15928, ["Sapphiron"]=15989, ["Kel'Thuzad"]=15990,
    -- WoW Forever bosses: creature IDs from Wowhead's Forever database (search by name).
    -- Their portraits are not published anywhere; BossNav_Portraits.lua learns each one
    -- in game the first time you target the boss or see its nameplate.
    -- Not found there: The Butcher (Ruins of Lordaeron), Bolt (Shaper's Terrace).
    ["Faldrim Anvilmar"]=261306, ["Magmatus (Infurnus)"]=261316, ["Plunder"]=261311,
    ["Durgen Dirgehammer"]=261319,
    ["Witherfang"]=250483, ["The Abandoned"]=250631, ["Bjork"]=256097, ["Rath'mael"]=250657,
    ["Viktor the Vile"]=256035,
    ["Saltspine"]=260322, ["Shadetooth"]=260325, ["Highland Horror"]=260808, ["Relic Guardian"]=260326,
    ["Arcane Anomaly"]=245999, ["Fel Ancient"]=246003, ["Mana Devourer"]=246008,
    ["Mana Elemental"]=240352, ["Unstable Sentinel"]=246017, ["Shade of the Archmage"]=246020,
    ["Lyn the Ignored"]=247032, ["Atrexis the Grave Knight"]=247126, ["Mana Wraith"]=246931,
    ["Deathulus"]=251615, ["Crushfist Bloodbreaker"]=251618,
    ["Withermaw"]=247195, ["Impaan the Imprisoner"]=247206, ["Bonesnout the Unbroken"]=247198,
    ["Blackmaw Behemoth"]=247207, ["Elder Shaman Bloodmane"]=247209, ["Varrox Bleakhoof"]=247234,
    ["Unbound Spirit"]=247231,
    ["Overseer Wrex"]=255391, ["Blazeroar"]=255702, ["Tidemistress Ca'zass"]=255997,
    ["The Questioner"]=256236, ["Katerina the Cleaner"]=257016,
    ["Nar'gurk"]=258964, ["Slavecrusher Grox"]=258966, ["Overseer Mugg"]=258968,   -- "Overlord Mugg" on Wowhead
    ["Twilight Commander Zarmok"]=258972, ["Handler Ashka"]=259281,                -- "War Handler Ashka" on Wowhead
    ["Zul'Alai"]={258905,270882}, ["Var'Taka"]={258924,270883}, ["Captain Dreadrise"]={260042,270884},
    ["Deathless Guardians"]={260213,268478}, ["Min'loth the Serpent"]={260243,260274,267852,269466,270886},
    ["Primeval Elemental"]={263886,270887,273738},
    ["Titanosaur"]=253201, ["Ravasaur Hunters"]={253214,262688}, ["Thunderhoof"]=261812,
    ["Venomridge"]=261813, ["Nanaya"]=261809, ["Cinder"]=261974, ["King Op"]=261993,
    ["Direhorn Matriarch"]=262127, ["Snowtalon"]=262297, ["Vitrix"]=272561,
}

-- shared with the other BossNav files
ns.BOSS_NPC = BOSS_NPC
ns.BOSS_DISPLAY = BOSS_DISPLAY
ns.DUNGEONS = DUNGEONS
ns.ZONE_INDEX = ZONE_INDEX
