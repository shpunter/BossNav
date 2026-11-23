-- Bundled portraits for the bosses new in WoW Forever.
--
-- These bosses have no published creature display ID, so the game can't draw
-- their portrait from BOSS_DISPLAY. The pictures in Images\Portraits are
-- round 64x64 TGAs, all made the same way from the boss head shots on
-- method.gg's WoW Forever dungeon guides.
-- A bundled picture wins over a portrait learned in game (BossNav_Portraits.lua).
local ADDON, ns = ...

local DIR = "Interface\\AddOns\\BossNav\\Images\\Portraits\\"

local BOSS_IMAGE = {
    -- Hall of Thanes
    ["Faldrim Anvilmar"]        = DIR .. "FaldrimAnvilmar",
    ["Magmatus (Infurnus)"]     = DIR .. "Magmatus",
    ["Plunder"]                 = DIR .. "Plunder",
    ["Durgen Dirgehammer"]      = DIR .. "DurgenDirgehammer",
    -- Ruins of Lordaeron
    ["Witherfang"]              = DIR .. "Witherfang",
    ["The Baron (The Butcher)"] = DIR .. "TheBaron",
    ["The Abandoned"]           = DIR .. "TheAbandoned",
    ["Bjork"]                   = DIR .. "Bjork",
    ["Rath'mael"]               = DIR .. "Rathmael",
    ["Viktor the Vile"]         = DIR .. "ViktorTheVile",
    -- Excavation Site: Wetlands
    ["Saltspine"]               = DIR .. "Saltspine",
    ["Shadetooth"]              = DIR .. "Shadetooth",
    ["Highland Horror"]         = DIR .. "HighlandHorror",
    ["Relic Guardian"]          = DIR .. "RelicGuardian",
    -- City of Dalaran (method.gg has no picture of Mana Elemental or Mana Wraith)
    ["Arcane Anomaly"]          = DIR .. "ArcaneAnomaly",
    ["Fel Ancient"]             = DIR .. "FelAncient",
    ["Mana Devourer"]           = DIR .. "ManaDevourer",
    ["Unstable Sentinel"]       = DIR .. "UnstableSentinel",
    ["Shade of the Archmage"]   = DIR .. "ShadeOfTheArchmage",
    ["Lyn the Ignored"]         = DIR .. "LynTheIgnored",
    ["Atrexis the Grave Knight"] = DIR .. "AtrexisTheGraveKnight",
    -- Alcaz Prison
    ["Overseer Wrex"]           = DIR .. "OverseerWrex",
    ["Blazeroar"]               = DIR .. "Blazeroar",           -- method.gg: "Zarla, Ober & Blazeroar"
    ["Tidemistress Ca'zass"]    = DIR .. "TidemistressCazass",
    ["The Questioner"]          = DIR .. "TheQuestioner",
    ["Katerina the Cleaner"]    = DIR .. "KaterinaTheCleaner",
    -- Krol'dok Stronghold
    ["Nar'gurk"]                = DIR .. "Nargurk",
    ["Slavecrusher Grox"]       = DIR .. "SlavecrusherGrox",
    ["Overseer Mugg"]           = DIR .. "OverseerMugg",        -- method.gg: "Overlord Mugg"
    ["Twilight Commander Zarmok"] = DIR .. "TwilightCommanderZarmok",
    ["Handler Ashka"]           = DIR .. "HandlerAshka",        -- method.gg: "War-Handler Ashka"
    -- The Drowned City
    ["Zul'Alai"]                = DIR .. "ZulAlai",
    ["Var'Taka"]                = DIR .. "VarTaka",
    ["Captain Dreadrise"]       = DIR .. "CaptainDreadrise",
    ["Deathless Guardians"]     = DIR .. "DeathlessGuardians",  -- method.gg: "Deathless Marrow"
    ["Min'loth the Serpent"]    = DIR .. "MinlothTheSerpent",
    ["Primeval Elemental"]      = DIR .. "PrimevalElemental",
    -- No pictures published yet (Nov 2026): Blackmaw Hold, Shaper's Terrace,
    -- Half-Pint Tavern, Lordaeron Captain. Those still learn theirs in game.
}

-- shared with the other BossNav files
ns.BOSS_IMAGE = BOSS_IMAGE
