-- StartAttackMacros (WoW 3.3.5a)
--   /sam        replace harmful abilities on all action bars (incl. stance bars) with
--               #showtooltip / /startattack / /cast <ability> macros
--   /sam all    same, but for every ability (stances, shouts, ...)
--   /sam undo   put the original abilities back and delete the macros this addon made
--   /sam list   show what is currently converted

local PREFIX = "|cffe8b84aStartAttackMacros:|r "
local MAX_SLOT = 120
local MAX_ACCOUNT, MAX_CHAR = 36, 18

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

local function db()
    StartAttackMacrosDB = StartAttackMacrosDB or { slots = {}, macros = {} }
    StartAttackMacrosDB.slots = StartAttackMacrosDB.slots or {}   -- slot -> spell name
    StartAttackMacrosDB.macros = StartAttackMacrosDB.macros or {} -- spell name -> macro name
    return StartAttackMacrosDB
end

local function macroName(spell)
    -- macro names are limited to 16 characters; keep them unique per spell
    local name = string.sub(spell, 1, 16)
    return name
end

local function macroBody(spell)
    return "#showtooltip\n/startattack\n/cast " .. spell
end

-- find or create the macro for a spell, returns its index or nil when no slot is free
local function ensureMacro(spell)
    local d = db()
    local name = d.macros[spell] or macroName(spell)
    local index = GetMacroIndexByName(name)
    if index and index > 0 then
        local _, _, body = GetMacroInfo(index)
        if body and string.find(body, "/startattack", 1, true) then
            d.macros[spell] = name
            return index
        end
        name = string.sub(spell, 1, 14) .. "*"   -- a macro of the user's has that name - don't touch it
        index = GetMacroIndexByName(name)
        if index and index > 0 then d.macros[spell] = name; return index end
    end
    local numAccount, numChar = GetNumMacros()
    local perChar
    if numChar < MAX_CHAR then perChar = 1 elseif numAccount < MAX_ACCOUNT then perChar = nil else return nil end
    index = CreateMacro(name, 1, macroBody(spell), perChar)
    if index then d.macros[spell] = name end
    return index
end

local function convert(all)
    if InCombatLockdown() then say("can't change action bars in combat."); return end
    local d = db()
    local done, skipped, full = 0, 0, false
    for slot = 1, MAX_SLOT do
        local kind, id, _, spellId = GetActionInfo(slot)
        if kind == "spell" then
            local spell = spellId and GetSpellInfo(spellId) or (id and GetSpellName(id, BOOKTYPE_SPELL))
            if spell then
                if all or IsHarmfulSpell(spell) then
                    local index = ensureMacro(spell)
                    if index then
                        ClearCursor()
                        PickupMacro(index)
                        PlaceAction(slot)
                        ClearCursor()
                        d.slots[slot] = spell
                        done = done + 1
                    else
                        full = true
                    end
                else
                    skipped = skipped + 1
                end
            end
        end
    end
    say(string.format("converted %d button(s), left %d non-attack ability button(s) alone.", done, skipped))
    -- the client writes macros (and this addon's undo list) to disk only on logout or /reload;
    -- a client crash before that leaves the bars pointing at macros that no longer exist
    if done > 0 then say("|cffff5555type /reload now|r so the new macros are saved - a crash before that would empty these buttons.") end
    if full then say("|cffff5555ran out of macro slots|r - some buttons were not converted. Delete unused macros and run /sam again.") end
    if not all and skipped > 0 then say("use |cffffffff/sam all|r to convert those too.") end
end

local function undo()
    if InCombatLockdown() then say("can't change action bars in combat."); return end
    local d = db()
    local restored = 0
    for slot, spell in pairs(d.slots) do
        local kind, id = GetActionInfo(slot)
        local mine = false
        if kind == "macro" and id then
            local name = GetMacroInfo(id)
            mine = name and d.macros[spell] == name
        end
        if mine then
            PickupSpell(spell)
            if CursorHasSpell() then
                PlaceAction(slot)
                restored = restored + 1
            end
            ClearCursor()
        end
        d.slots[slot] = nil
    end
    local deleted = 0
    for spell, name in pairs(d.macros) do
        local index = GetMacroIndexByName(name)
        if index and index > 0 then
            local _, _, body = GetMacroInfo(index)
            if body and string.find(body, "/startattack", 1, true) then DeleteMacro(index); deleted = deleted + 1 end
        end
        d.macros[spell] = nil
    end
    say(string.format("restored %d button(s), deleted %d macro(s).", restored, deleted))
end

local function list()
    local d = db()
    local n = 0
    for slot, spell in pairs(d.slots) do say("slot " .. slot .. ": " .. spell); n = n + 1 end
    if n == 0 then say("nothing converted.") end
end

SLASH_STARTATTACKMACROS1 = "/sam"
SlashCmdList["STARTATTACKMACROS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))
    if msg == "undo" then undo()
    elseif msg == "list" then list()
    elseif msg == "all" then convert(true)
    elseif msg == "" then convert(false)
    else say("/sam, /sam all, /sam undo, /sam list") end
end
