-- LfgBossInfo (WoW 3.3.5a): tells you which boss completes a Dungeon Finder run.
--  * Specific queue: the invite names the dungeon -> announced right away.
--  * Random queue: the server only sends "Random ... Dungeon" (retail behaviour), so the dungeon is announced when
--    you arrive. If the instance has several Dungeon Finder versions (Blackrock Depths, Scarlet Monastery, Dire Maul,
--    Maraudon), all versions and their final bosses are listed. Blackrock Depths Prison and Upper City even share the
--    same arrival point, so kill Gerstahn first: if no reward appears, it is Upper City (Emperor Thaurissan).
-- /lfgboss shows it again. Tables generated from the server's instance_encounters and the client's LFGDungeons.dbc.

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

local DUNGEON_NAME = {
    [1] = "Wailing Caverns",
    [2] = "Scholomance",
    [4] = "Ragefire Chasm",
    [6] = "Deadmines",
    [8] = "Shadowfang Keep",
    [10] = "Blackfathom Deeps",
    [12] = "Stormwind Stockade",
    [14] = "Gnomeregan",
    [16] = "Razorfen Kraul",
    [18] = "Scarlet Monastery - Graveyard",
    [20] = "Razorfen Downs",
    [22] = "Uldaman",
    [24] = "Zul'Farrak",
    [26] = "Maraudon - Orange Crystals",
    [28] = "Sunken Temple",
    [30] = "Blackrock Depths - Prison",
    [32] = "Lower Blackrock Spire",
    [34] = "Dire Maul - East",
    [36] = "Dire Maul - West",
    [38] = "Dire Maul - North",
    [40] = "Stratholme - Main Gate",
    [136] = "Hellfire Ramparts",
    [137] = "Blood Furnace",
    [138] = "Shattered Halls",
    [140] = "Slave Pens",
    [146] = "Underbog",
    [147] = "The Steamvault",
    [148] = "Mana-Tombs",
    [149] = "Auchenai Crypts",
    [150] = "Sethekk Halls",
    [151] = "Shadow Labyrinth",
    [163] = "Scarlet Monastery - Armory",
    [164] = "Scarlet Monastery - Cathedral",
    [165] = "Scarlet Monastery - Library",
    [170] = "The Escape From Durnholde",
    [171] = "The Black Morass",
    [172] = "The Mechanar",
    [173] = "The Botanica",
    [174] = "The Arcatraz",
    [198] = "Magisters' Terrace",
    [202] = "Utgarde Keep",
    [203] = "Utgarde Pinnacle",
    [204] = "Azjol-Nerub",
    [206] = "The Oculus",
    [207] = "Halls of Lightning",
    [208] = "Halls of Stone",
    [209] = "The Culling of Stratholme",
    [214] = "Drak'Tharon Keep",
    [216] = "Gundrak",
    [218] = "Ahn'kahet: The Old Kingdom",
    [220] = "Violet Hold",
    [225] = "The Nexus",
    [245] = "Trial of the Champion",
    [251] = "The Forge of Souls",
    [253] = "Pit of Saron",
    [255] = "Halls of Reflection",
    [272] = "Maraudon - Purple Crystals",
    [273] = "Maraudon - Pristine Waters",
    [274] = "Stratholme - Service Entrance",
    [276] = "Blackrock Depths - Upper City",
    [285] = "The Headless Horseman",
    [286] = "The Frost Lord Ahune",
    [287] = "Coren Direbrew",
    [288] = "The Crown Chemical Co.",
    [42] = "Zul'Gurub",
    [44] = "Upper Blackrock Spire",
    [46] = "Onyxia's Lair",
    [48] = "Molten Core",
    [50] = "Blackwing Lair",
    [159] = "Naxxramas",
    [160] = "Ahn'Qiraj Ruins",
    [161] = "Ahn'Qiraj Temple",
    [175] = "Karazhan",
    [176] = "Magtheridon's Lair",
    [177] = "Gruul's Lair",
    [193] = "Tempest Keep",
    [194] = "Serpentshrine Cavern",
    [195] = "Hyjal Past",
    [196] = "Black Temple",
    [197] = "Zul'Aman",
    [199] = "The Sunwell",
    [223] = "The Eye of Eternity",
    [224] = "The Obsidian Sanctum",
    [227] = "Naxxramas",
    [237] = "The Eye of Eternity",
    [238] = "The Obsidian Sanctum",
    [239] = "Vault of Archavon",
    [240] = "Vault of Archavon",
    [243] = "Ulduar",
    [244] = "Ulduar",
    [246] = "Trial of the Crusader",
    [247] = "Trial of the Grand Crusader",
    [248] = "Trial of the Crusader",
    [250] = "Trial of the Grand Crusader",
    [257] = "Onyxia's Lair",
    [279] = "Icecrown Citadel",
    [280] = "Icecrown Citadel",
    [293] = "Ruby Sanctum",
    [294] = "Ruby Sanctum",
}

local PREFIX = "|cffe8b84aDungeon Finder:|r "

local function say(msg, loud)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
    if loud then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
        PlaySound("RaidWarning")
    end
end

-- all Dungeon Finder versions of the instance we are in: { {name, boss}, ... }
local function versionsOf(instanceName)
    local list, seen = {}, {}
    for id, name in pairs(DUNGEON_NAME) do
        if (name == instanceName or name:find(instanceName .. " - ", 1, true) == 1) and FINAL_BOSS[id] and not seen[name] then
            seen[name] = true
            table.insert(list, { name, FINAL_BOSS[id] })
        end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

local function announceInstance(loud)
    local inInstance, kind = IsInInstance()
    if not inInstance or (kind ~= "party" and kind ~= "raid") then
        say("not inside a dungeon.", false); return
    end
    local instanceName = GetInstanceInfo()
    local list = versionsOf(instanceName or "")
    if #list == 0 then
        say((instanceName or "?") .. ": no Dungeon Finder end boss known.", false)
    elseif #list == 1 then
        say(list[1][1] .. " - finish by killing " .. list[1][2], loud)
    else
        say(instanceName .. " has " .. #list .. " Dungeon Finder versions:", loud)
        for _, v in ipairs(list) do say("   " .. v[1] .. ": " .. v[2], false) end
        if instanceName == "Blackrock Depths" then
            say("   Prison and Upper City share one entrance - kill Gerstahn first; no reward = Upper City.", false)
        else
            say("   The Dungeon Finder put you at the entrance of the version you got.", false)
        end
    end
end

local announcedFor, specificId
local f = CreateFrame("Frame")
f:RegisterEvent("LFG_PROPOSAL_SHOW")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
    if event == "LFG_PROPOSAL_SHOW" then
        local ok, exists, typeID, id, name = pcall(GetLFGProposal)
        if ok and exists and id and FINAL_BOSS[id] then
            specificId = id
            say((DUNGEON_NAME[id] or name) .. " - finish by killing " .. FINAL_BOSS[id], true)
        elseif ok and exists then
            specificId = nil
            say((name or "Random dungeon") .. " - the server picks the dungeon; it is announced when you arrive.", false)
        end
    else
        -- once per instance visit, a moment after loading so the instance info is ready
        local inInstance, kind = IsInInstance()
        if inInstance and (kind == "party" or kind == "raid") then
            local name = GetInstanceInfo()
            if name and name ~= announcedFor then
                announcedFor = name
                announceInstance(true)
            end
        else
            announcedFor = nil
        end
    end
end)

SLASH_LFGBOSSINFO1 = "/lfgboss"
SlashCmdList["LFGBOSSINFO"] = function() announceInstance(false) end