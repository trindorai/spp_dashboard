-- LfgBossInfo (WoW 3.3.5a): when the Dungeon Finder forms a group, say loudly WHICH dungeon it is and which boss
-- completes it. Several dungeons share an entrance (Blackrock Depths Prison / Upper City, Scarlet Monastery wings,
-- Dire Maul wings, Maraudon) and the Random reward only comes from that version's final boss.
-- /lfgboss shows it again. The boss list was generated from the server's instance_encounters table.

local FINAL_BOSS = {
    [1] = "Mutanus the Devourer",
    [2] = "Darkmaster Gandling",
    [4] = "Taragaman the Hungerer",
    [6] = "Edwin VanCleef",
    [8] = "Archmage Arugal",
    [10] = "Aku'mai",
    [12] = "Dextren Ward",
    [14] = "Mekgineer Thermaplugg",
    [16] = "Charlga Razorflank",
    [18] = "Bloodmage Thalnos",
    [20] = "Amnennar the Coldbringer",
    [22] = "Archaedas",
    [24] = "Chief Ukorz Sandscalp",
    [26] = "Razorlash",
    [28] = "Shade of Eranikus",
    [30] = "High Interrogator Gerstahn",
    [32] = "Overlord Wyrmthalak",
    [34] = "Alzzin the Wildshaper",
    [36] = "Prince Tortheldrin",
    [38] = "King Gordok",
    [40] = "Balnazzar",
    [42] = "Hakkar",
    [44] = "General Drakkisath",
    [46] = "Onyxia",
    [48] = "Ragnaros",
    [50] = "Nefarian",
    [136] = "Vazruden",
    [137] = "Keli'dan the Breaker",
    [138] = "Warchief Kargath Bladefist",
    [140] = "Quagmirran",
    [146] = "The Black Stalker",
    [147] = "Warlord Kalithresh",
    [148] = "Nexus-Prince Shaffar",
    [149] = "Exarch Maladaar",
    [150] = "Talon King Ikiss",
    [151] = "Murmur",
    [159] = "Kel'Thuzad",
    [160] = "Ossirian the Unscarred",
    [161] = "C'Thun",
    [163] = "Herod",
    [164] = "High Inquisitor Whitemane",
    [165] = "Arcanist Doan",
    [170] = "Epoch Hunter",
    [171] = "Aeonus",
    [172] = "Pathaleon the Calculator",
    [173] = "Warp Splinter",
    [174] = "Harbinger Skyriss",
    [175] = "Prince Malchezaar",
    [176] = "Magtheridon",
    [177] = "Gruul the Dragonkiller",
    [178] = "Exarch Maladaar",
    [179] = "Nexus-Prince Shaffar",
    [180] = "Talon King Ikiss",
    [181] = "Murmur",
    [182] = "Aeonus",
    [183] = "Epoch Hunter",
    [184] = "Quagmirran",
    [185] = "Warlord Kalithresh",
    [186] = "The Black Stalker",
    [187] = "Keli'dan the Breaker",
    [188] = "Vazruden",
    [189] = "Warchief Kargath Bladefist",
    [190] = "Harbinger Skyriss",
    [191] = "Warp Splinter",
    [192] = "Pathaleon the Calculator",
    [193] = "Kael'thas Sunstrider",
    [194] = "Lady Vashj",
    [195] = "Archimonde",
    [196] = "Illidan Stormrage",
    [197] = "Zul'jin",
    [198] = "Kael'thas Sunstrider",
    [199] = "Kil'jaeden",
    [201] = "Kael'thas Sunstrider",
    [202] = "Ingvar the Plunderer",
    [203] = "King Ymiron",
    [204] = "Anub'arak",
    [205] = "King Ymiron",
    [206] = "Ley-Guardian Eregos",
    [207] = "Loken",
    [208] = "Sjonnir The Ironshaper",
    [209] = "creature 58630",
    [210] = "creature 58630",
    [211] = "Ley-Guardian Eregos",
    [212] = "Loken",
    [213] = "Sjonnir The Ironshaper",
    [214] = "creature 61863",
    [215] = "creature 61863",
    [216] = "Gal'darah",
    [217] = "Gal'darah",
    [218] = "Herald Volazj",
    [219] = "Herald Volazj",
    [220] = "Cyanigosa",
    [221] = "Cyanigosa",
    [223] = "Malygos",
    [224] = "Sartharion",
    [225] = "Keristrasza",
    [226] = "Keristrasza",
    [227] = "Kel'Thuzad",
    [237] = "Malygos",
    [238] = "Sartharion",
    [239] = "Toravon the Ice Watcher",
    [240] = "Toravon the Ice Watcher",
    [241] = "Anub'arak",
    [242] = "Ingvar the Plunderer",
    [243] = "Algalon the Observer",
    [244] = "Algalon the Observer",
    [245] = "creature 68663",
    [246] = "Anub'arak",
    [247] = "Anub'arak",
    [248] = "Anub'arak",
    [249] = "creature 68663",
    [250] = "Anub'arak",
    [251] = "Devourer of Souls",
    [252] = "Devourer of Souls",
    [253] = "Scourgelord Tyrannus",
    [254] = "Scourgelord Tyrannus",
    [255] = "creature 72830",
    [256] = "creature 72830",
    [257] = "Onyxia",
    [272] = "Lord Vyletongue",
    [273] = "Princess Theradras",
    [274] = "Baron Rivendare",
    [276] = "Emperor Dagran Thaurissan",
    [279] = "The Lich King",
    [280] = "The Lich King",
    [293] = "Halion",
    [294] = "Halion",

}

local PREFIX = "|cffe8b84aDungeon Finder:|r "

local function announce(name, id, loud)
    if not name then return end
    local boss = id and FINAL_BOSS[id]
    local msg = boss and string.format("%s - finish by killing %s", name, boss) or name
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
    if loud then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
        PlaySound("RaidWarning")
    end
end

local lastId, lastName

local function fromProposal()
    local ok, exists, typeID, id, name = pcall(GetLFGProposal)
    if ok and exists and name then lastId, lastName = id, name; return id, name end
end

local f = CreateFrame("Frame")
f:RegisterEvent("LFG_PROPOSAL_SHOW")
f:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
f:SetScript("OnEvent", function(self, event)
    if event == "LFG_PROPOSAL_SHOW" then
        local id, name = fromProposal()
        announce(name, id, true)
    elseif event == "LFG_PROPOSAL_SUCCEEDED" and lastName then
        announce(lastName, lastId, false)
    end
end)

SLASH_LFGBOSSINFO1 = "/lfgboss"
SlashCmdList["LFGBOSSINFO"] = function()
    if lastName then announce(lastName, lastId, false)
    else DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "no Dungeon Finder group formed yet this session.") end
end