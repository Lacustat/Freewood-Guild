-- Freewood-Guild: Berufe-Links aus dem Chat (Probe).
--
-- Mitglieder ohne dieses Addon koennen ihren Beruf im Spiel in den Chat posten. Oeffnet man den Link, zeigt das
-- Berufefenster dessen Rezepte (Ansichtsmodus). Dieses Modul
--   1. erkennt Beruf-Links im Chat (jeder Kanal) und meldet sie, wenn der Absender in der Gildenliste steht
--      (Haken fuer andere Module: Guild.TradeLink.AddHook, z. B. das Hinweisfenster in Freewood-Dev),
--   2. liest beim Oeffnen eines verlinkten Berufs aus, was das Spiel liefert (Name, Beruf, Rang, Zahl der Rezepte,
--      ob sie als "gelernt" markiert sind) und schreibt es als Probe in den Chat und nach FreewoodGuildDB.tradeProbe.
-- In der Gildenuebersicht wird in dieser Stufe noch nichts gespeichert. UNGEPRUEFT im Spiel.

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
local MAX_LOG = 20
local seen = {}

local function Secret(v) return Guild.Secret(v) end
local function Clock() return G.GetTime and G.GetTime() or 0 end

function T.AddHook(fn)
    if type(fn) == "function" then hooks[#hooks + 1] = fn end
end

------------------------------------------------------------------------
-- Links im Text finden
------------------------------------------------------------------------

-- Rueckgabe: Liste { link = "trade:...", text = "|H...|h[Name]|h", label = "Name" }
function T.Parse(msg)
    local out = {}
    if type(msg) ~= "string" or Secret(msg) then return out end
    for link, label in string.gmatch(msg, "|H(trade:[^|]*)|h(.-)|h") do
        local name = string.gsub(string.gsub(label, "^%[", ""), "%]$", "")
        out[#out + 1] = { link = link, text = "|H" .. link .. "|h" .. label .. "|h", label = name }
    end
    return out
end

-- Beruf (ID aus Guild.PROF) zu einem Link; nil, wenn der Name keinem bekannten Beruf entspricht
local function ProfOf(entry)
    local id = Guild.ProfByName(entry.label)
    if id then return id end
    for word in string.gmatch(entry.label, "[^%s%-:%(%)]+") do
        id = Guild.ProfByName(word)
        if id then return id end
    end
    return nil
end

-- Schon Rezepte dieses Mitglieds und Berufs bekannt (vom Mitglied selbst gemeldet)?
function T.IsKnown(key, profId)
    local rec = Guild.DB().members[key]
    if not rec then return false end
    if profId then
        return rec.recipes ~= nil and rec.recipes[profId] ~= nil
    end
    return false
end

-- Eine Chatzeile pruefen. Rueckgabe: Anzahl gemeldeter Links
function T.Process(author, msg)
    if type(author) ~= "string" or author == "" or Secret(author) then return 0 end
    local links = T.Parse(msg)
    if #links == 0 then return 0 end
    local key = Guild.Key(author)
    if not key or key == Guild.SelfKey() then return 0 end
    if not (Guild.rowByKey and Guild.rowByKey[key]) then return 0 end   -- nur Gildenmitglieder
    local now = Clock()
    local n = 0
    for _, e in ipairs(links) do
        local sig = key .. "|" .. e.link
        if not seen[sig] or now - seen[sig] > DEDUPE then
            seen[sig] = now
            local profId = ProfOf(e)
            local info = {
                name = Guild.Display(author), key = key, link = e.link, text = e.text,
                label = e.label, profId = profId, known = T.IsKnown(key, profId),
            }
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
    if not Guild.Setting("tradeProbe") then return false end
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

------------------------------------------------------------------------
-- Verlinktes Berufefenster auslesen (Probe)
------------------------------------------------------------------------

function T.Log()
    local db = Guild.DB()
    db.tradeProbe = db.tradeProbe or {}
    return db.tradeProbe
end

-- Liest das offene Berufefenster. Rueckgabe: Eintrag oder nil, wenn kein verlinkter Beruf offen ist
function T.Read()
    local ts = G.C_TradeSkillUI
    if not ts or not ts.IsTradeSkillLinked then return nil end
    local okL, linked, linkedName = pcall(ts.IsTradeSkillLinked)
    if not okL or not linked then return nil end
    local e = { at = G.time and G.time() or 0, linked = true }
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
    e.member = key ~= nil and Guild.rowByKey ~= nil and Guild.rowByKey[key] ~= nil
    return e
end

function T.Describe(e)
    local parts = {
        "Berufe-Link: " .. tostring(e.name or "?") .. " | " .. tostring(e.prof or "Beruf unbekannt"),
        "Rezepte gesamt " .. tostring(e.total), "gelernt " .. tostring(e.learned),
        "ohne Markierung " .. tostring(e.unmarked),
        "Gilde " .. (e.member and "ja" or "nein"),
    }
    if e.skill then parts[#parts + 1] = "Rang " .. tostring(e.skill) .. "/" .. tostring(e.maxSkill) end
    if e.guildView then parts[#parts + 1] = "Gildenansicht" end
    local line = table.concat(parts, " | ")
    if #e.samples > 0 then line = line .. " | z. B. " .. table.concat(e.samples, ", ") end
    return line
end

local lastSig, lastAt = nil, 0
function T.Capture()
    if not Guild.Setting("tradeProbe") then return nil end
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

-- /fwguild trade : letzte Proben im Chat
function T.PrintLog()
    local log = T.Log()
    if #log == 0 then
        FW:Print("Berufe-Link: noch keine Probe. Einen geposteten Beruf eines Gildenmitglieds anklicken.")
        return
    end
    for i = math.max(1, #log - 4), #log do FW:Print(T.Describe(log[i])) end
end
