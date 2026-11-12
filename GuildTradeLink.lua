-- Freewood-Guild: Berufe aus Chat-Links merken.
--
-- Mitglieder ohne dieses Addon koennen ihren Beruf im Spiel in den Chat posten. Das Spiel erlaubt es nicht, fremde
-- Beruf-Links zu oeffnen (geprueft auf OctoWoW/Forever: Klick oeffnet nichts), die Rezepte sind also nicht zu lesen.
-- Der Link selbst enthaelt aber die Beruf-ID:  trade:<Spieler-GUID>:<Zauber-ID>:<Beruf-ID>   (z. B. ...:3909:197 = Schneiderei).
-- Dieses Modul liest in jedem Chat-Kanal mit, und wenn der Absender in der Gildenliste steht und dieses Addon nicht hat
-- (keine eigenen Berufsdaten), merkt es sich den Beruf. Die Gildenuebersicht zeigt ihn dann mit "?" statt der Stufe.
-- Meldet das Mitglied spaeter selbst seine Berufe (Addon), ersetzen die echten Daten den Eintrag.
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local T = {}
Guild.TradeLink = T

local hooks = {}
local DEDUPE = 3         -- Sekunden: derselbe Link vom selben Absender zaehlt einmal (jedes Chatfenster ruft den Filter)
local seen = {}

local function Secret(v) return Guild.Secret(v) end
local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Now() return G.time and G.time() or 0 end

-- Andere Module koennen sich melden lassen: fn(info) mit { name, key, link, text, label, profId }
function T.AddHook(fn)
    if type(fn) == "function" then hooks[#hooks + 1] = fn end
end

------------------------------------------------------------------------
-- Links im Text finden
------------------------------------------------------------------------

-- Beruf-ID aus den Linkdaten: "trade:Player-1-ABC:2018:164" -> 164; alte Form "trade:2018:300:375:guid:bits" -> nil
function T.SkillLine(data)
    if type(data) ~= "string" then return nil end
    local f = {}
    for part in string.gmatch(data, "[^:]+") do f[#f + 1] = part end
    if f[1] ~= "trade" then return nil end
    if string.sub(f[2] or "", 1, 7) == "Player-" then
        local id = tonumber(f[4])
        if id and Guild.PROF[id] then return id end
    end
    return nil
end

-- Linktypen, die nie ein Beruf sind (auch wenn der Name zufaellig passt)
local NOT_PROF = { item = true, quest = true, achievement = true, player = true, channel = true, currency = true, unit = true,
    bnplayer = true, instancelock = true, journal = true, keystone = true, battlepet = true, garrmission = true }

-- Rueckgabe: Liste { link = "trade:...", text = "|H...|h[Name]|h", label = "Name", profId = ..., kind = "trade"|"spell"|... }
-- Zwei Wege, einen Beruf zu verlinken: die Sprechblase im Berufefenster (trade:-Link mit Beruf-ID) und Shift+Klick im Zauberbuch
-- (trade:-Link oder, falls das Spiel keinen liefert, ein Zauberlink). Darum zaehlt jeder Link, dessen Beschriftung ein Beruf ist.
function T.Parse(msg)
    local out = {}
    if type(msg) ~= "string" or Secret(msg) then return out end
    for link, label in string.gmatch(msg, "|H([^|]*)|h(.-)|h") do
        local kind = string.lower(string.match(link, "^([^:]*)") or "")
        local name = string.gsub(string.gsub(label, "^%[", ""), "%]$", "")
        local profId
        if kind == "trade" then
            profId = T.SkillLine(link) or Guild.ProfByName(name)
        elseif kind ~= "" and not NOT_PROF[kind] then
            profId = Guild.ProfByName(name)
        end
        if kind == "trade" or profId then
            out[#out + 1] = { link = link, text = "|H" .. link .. "|h" .. label .. "|h", label = name, profId = profId, kind = kind }
        end
    end
    return out
end

------------------------------------------------------------------------
-- Merken
------------------------------------------------------------------------

-- Beruf eines Mitglieds ohne Addon eintragen. Rueckgabe: true, wenn neu eingetragen
function T.Record(key, profId)
    if not key or not profId or not Guild.PROF[profId] then return false end
    local db = Guild.DB()
    local rec = db.members[key]
    if rec and rec.stamp then return false end          -- hat das Addon: eigene Daten gelten
    if rec and rec.skills and rec.skills[profId] then
        rec.skills[profId].at = Now()
        return false
    end
    rec = rec or {}
    db.members[key] = rec
    rec.skills = rec.skills or {}
    rec.skills[profId] = { rank = 0, max = 0, chat = true, at = Now() }
    if Guild.Changed then Guild.Changed() end
    return true
end

-- Zauber-ID aus den Linkdaten: "trade:Player-1-ABC:4038:202" -> 4038 (die Berufsstufe des Spielers, z. B. Experte)
function T.SpellId(data)
    if type(data) ~= "string" then return nil end
    local f = {}
    for part in string.gmatch(data, "[^:]+") do f[#f + 1] = part end
    if f[1] ~= "trade" then return nil end
    if string.sub(f[2] or "", 1, 7) == "Player-" then return tonumber(f[3]) end
    return tonumber(f[2])
end

-- Name und Stufentext dieser Zauber-ID, wie das Spiel sie kennt (alle Aufrufe geschuetzt). Rueckgabe: name, subtext oder nil
function T.SpellText(id)
    if type(id) ~= "number" then return nil end
    local C = G.C_Spell
    local name, sub
    if C and C.GetSpellName then
        local ok, v = pcall(C.GetSpellName, id)
        if ok and type(v) == "string" and not Secret(v) then name = v end
    end
    if not name and G.GetSpellInfo then
        local ok, v = pcall(G.GetSpellInfo, id)
        if ok then
            if type(v) == "table" then v = v.name end
            if type(v) == "string" and not Secret(v) then name = v end
        end
    end
    if C and C.GetSpellSubtext then
        local ok, v = pcall(C.GetSpellSubtext, id)
        if ok and type(v) == "string" and not Secret(v) and v ~= "" then sub = v end
    elseif G.GetSpellSubtext then
        local ok, v = pcall(G.GetSpellSubtext, id)
        if ok and type(v) == "string" and not Secret(v) and v ~= "" then sub = v end
    end
    return name, sub
end

-- /fwguild linkdebug : jeden Beruf-Link im Chat mit Typ und Rohdaten melden (zeigt, was Shift+Klick und die Sprechblase senden)
T.debug = false
local dbgSeen = {}
function T.DebugLinks(author, links)
    local now = Clock()
    for _, e in ipairs(links) do
        local sig = tostring(author) .. "|" .. e.link
        if not dbgSeen[sig] or now - dbgSeen[sig] > DEDUPE then
            dbgSeen[sig] = now
            local key = Guild.Key(author)
            local member = key and Guild.rowByKey and Guild.rowByKey[key] and true or false
            FW:Print("[Berufslink] " .. Guild.Display(author) .. ": Typ " .. tostring(e.kind) .. ", Name " .. tostring(e.label) ..
                ", Beruf-ID " .. tostring(e.profId) .. ", Gildenmitglied " .. tostring(member) .. ", Daten " .. string.gsub(e.link, "\124", "!"))
            local sid = T.SpellId(e.link)
            if sid then
                local nm, sub = T.SpellText(sid)
                FW:Print("[Berufslink]   Zauber " .. sid .. ": Name " .. tostring(nm) .. ", Stufentext " .. tostring(sub))
            end
        end
    end
end

function T.ToggleDebug()
    T.debug = not T.debug
    FW:Print("Berufslink-Fehlersuche: " .. (T.debug and "an (jeder Beruf-Link im Chat wird mit Typ und Daten gemeldet)" or "aus"))
end

-- Eine Chatzeile pruefen. Rueckgabe: Anzahl gemeldeter Links
function T.Process(author, msg)
    if type(author) ~= "string" or author == "" or Secret(author) then return 0 end
    local links = T.Parse(msg)
    if #links == 0 then return 0 end
    if T.debug then T.DebugLinks(author, links) end
    local key = Guild.Key(author)
    if not key or key == Guild.SelfKey() then return 0 end
    if not (Guild.rowByKey and Guild.rowByKey[key]) then return 0 end   -- nur Gildenmitglieder
    local now = Clock()
    local n = 0
    for _, e in ipairs(links) do
        local sig = key .. "|" .. e.link
        if not seen[sig] or now - seen[sig] > DEDUPE then
            seen[sig] = now
            pcall(T.Record, key, e.profId)
            local info = { name = Guild.Display(author), key = key, link = e.link, text = e.text, label = e.label, profId = e.profId }
            for _, h in ipairs(hooks) do pcall(h, info) end
            n = n + 1
        end
    end
    return n
end

local CHAT_EVENTS = {
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE",
}

local function ChatFilter(_, _, msg, author)
    if not Guild.Setting("tradeChat") then return false end
    pcall(T.Process, author, msg)
    return false   -- Text bleibt unveraendert
end

local function InstallFilter()
    if T.filterInstalled or not G.ChatFrame_AddMessageEventFilter then return end
    for _, ev in ipairs(CHAT_EVENTS) do pcall(G.ChatFrame_AddMessageEventFilter, ev, ChatFilter) end
    T.filterInstalled = true
end
InstallFilter()
T.ChatFilter = ChatFilter

-- /fwguild trade : Mitglieder, deren Beruf nur aus einem Chat-Link stammt
function T.List()
    local out = {}
    for key, rec in pairs(Guild.DB().members) do
        if type(rec) == "table" and not rec.stamp and type(rec.skills) == "table" then
            local profs = {}
            for id, s in pairs(rec.skills) do
                if type(s) == "table" and s.chat then profs[#profs + 1] = Guild.ProfName(id) end
            end
            if #profs > 0 then
                table.sort(profs)
                local row = Guild.rowByKey and Guild.rowByKey[key]
                out[#out + 1] = Guild.Display(row and row.name or key) .. ": " .. table.concat(profs, ", ")
            end
        end
    end
    table.sort(out)
    return out
end

function T.PrintList()
    local list = T.List()
    if #list == 0 then
        FW:Print("Berufe aus dem Chat: noch keine. Sobald ein Gildenmitglied ohne das Addon einen Beruf postet, wird er gemerkt.")
        return
    end
    FW:Print("Berufe aus dem Chat (" .. #list .. " Mitglieder):")
    for _, l in ipairs(list) do FW:Print(l) end
end

------------------------------------------------------------------------
-- Geoeffnetes Berufefenster eines anderen Spielers auslesen (Probe, noch ohne Speichern)
------------------------------------------------------------------------
-- Manche Beruf-Links oeffnen sich (Weedo Cowking ja, andere nicht), und C_GuildInfo.QueryGuildMemberRecipes oeffnet
-- das Fenster eines Gildenmitglieds. Zeigt das Fenster einen fremden Spieler (verlinkt oder Gildenmitglied), schreibt
-- dieses Modul in den Chat, was das Spiel liefert (Name, Beruf, Rang, Rezepte gesamt/gelernt, Beispiele) und merkt die
-- letzten Proben in FreewoodGuildDB.tradeProbe. Es wird noch nichts in der Gildenuebersicht gespeichert.

local MAX_LOG = 20

function T.Log()
    local db = Guild.DB()
    db.tradeProbe = db.tradeProbe or {}
    return db.tradeProbe
end

-- Rueckgabe: Eintrag oder nil, wenn kein Fenster eines anderen Spielers offen ist
function T.Read()
    local ts = G.C_TradeSkillUI
    if not ts then return nil end
    local linked, linkedName = false, nil
    if ts.IsTradeSkillLinked then
        local ok, l, n = pcall(ts.IsTradeSkillLinked)
        if ok and l then linked = true; linkedName = n end
    end
    local member = false
    if ts.IsTradeSkillGuildMember then
        local ok, m = pcall(ts.IsTradeSkillGuildMember)
        member = ok and m == true
    end
    if not linked and not member then return nil end
    local e = { at = Now(), linked = linked, member = member }
    if type(linkedName) == "string" and not Secret(linkedName) then e.name = linkedName end
    if ts.IsTradeSkillGuild then
        local okG, isGuild = pcall(ts.IsTradeSkillGuild)
        e.guildView = okG and isGuild == true
    end
    local profId, ids = Guild.Share.ReadRecipes()
    e.profId = profId
    e.prof = profId and Guild.ProfName(profId) or nil
    e.learned = ids and #ids or 0
    e.samples = {}
    if ts.GetAllRecipeIDs then
        local ok, all = pcall(ts.GetAllRecipeIDs)
        if ok and type(all) == "table" then
            e.total = #all
            e.unmarked = 0
            for i, rid in ipairs(all) do
                local okI, info = pcall(ts.GetRecipeInfo, rid)
                if okI and type(info) == "table" then
                    if info.learned == nil then e.unmarked = e.unmarked + 1 end
                    if #e.samples < 5 and info.learned and type(info.name) == "string" and not Secret(info.name) then
                        e.samples[#e.samples + 1] = info.name
                    end
                end
                if i >= 2000 then break end
            end
        end
    end
    if ts.GetBaseProfessionInfo then
        local okB, bi = pcall(ts.GetBaseProfessionInfo)
        if okB and type(bi) == "table" then
            e.skill, e.maxSkill = tonumber(bi.skillLevel), tonumber(bi.maxSkillLevel)
        end
    end
    local key = e.name and Guild.Key(e.name)
    e.inGuild = key ~= nil and Guild.rowByKey ~= nil and Guild.rowByKey[key] ~= nil
    return e
end

function T.Describe(e)
    local parts = {
        "Fremdes Berufefenster: " .. tostring(e.name or "?") .. " | " .. tostring(e.prof or "Beruf unbekannt"),
        "Rezepte gesamt " .. tostring(e.total), "gelernt " .. tostring(e.learned),
        "ohne Markierung " .. tostring(e.unmarked),
        "verlinkt " .. tostring(e.linked) .. ", Gildenmitglied-Ansicht " .. tostring(e.member),
        "Gilde " .. (e.inGuild and "ja" or "nein"),
    }
    if e.skill then parts[#parts + 1] = "Rang " .. tostring(e.skill) .. "/" .. tostring(e.maxSkill) end
    if e.guildView then parts[#parts + 1] = "Gilden-Berufsansicht" end
    local line = table.concat(parts, " | ")
    if #e.samples > 0 then line = line .. " | z. B. " .. table.concat(e.samples, ", ") end
    return line
end

local lastSig, lastAt = nil, 0
function T.Capture()
    if not Guild.Setting("tradeChat") then return nil end
    local e = T.Read()
    if not e then return nil end
    local sig = tostring(e.name) .. "|" .. tostring(e.profId) .. "|" .. tostring(e.total) .. "|" .. tostring(e.learned)
    local now = Clock()
    if sig == lastSig and now - lastAt < 5 then return nil end
    lastSig, lastAt = sig, now
    local log = T.Log()
    log[#log + 1] = e
    while #log > MAX_LOG do table.remove(log, 1) end
    FW:Print(T.Describe(e))
    return e
end

local function Schedule()
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(0.8, function() pcall(T.Capture) end)
    else
        pcall(T.Capture)
    end
end

FW:RegisterEvent("TRADE_SKILL_SHOW", Schedule, T)
FW:RegisterEvent("TRADE_SKILL_LIST_UPDATE", Schedule, T)
