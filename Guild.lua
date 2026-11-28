-- Freewood-Guild: Gilden-Modul. Kern: Daten, Gildenliste, Berufe-Tabelle, Probe (/fwguild probe).
-- Geteilte Daten (Berufe, Rezepte, EP, Spielzeit, Gold) kommen aus GuildShare.lua. UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
if not FW or not FW:RequireAPI(1, ADDON) then
    return
end

local G = _G
local L = FW.L

local function GetMeta(field)
    local fn = (G.C_AddOns and G.C_AddOns.GetAddOnMetadata) or G.GetAddOnMetadata
    if fn then
        local ok, value = pcall(fn, ADDON, field)
        if ok then return value end
    end
    return nil
end

local Guild = FW:NewModule("Guild", {
    version = GetMeta("Version") or "dev",
    title = L.GUILD_TITLE,
    description = L.GUILD_DESC,
    defaults = { settings = {} },
})
NS.Guild = Guild
FW.Guild = Guild

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end
Guild.Secret = Secret

------------------------------------------------------------------------
-- Speicher
------------------------------------------------------------------------

G.FreewoodGuildDB = G.FreewoodGuildDB or {}

Guild.SETTINGS = {
    shareProfile = true,     -- eigene Berufe/EP/Spielzeit mit der Gilde teilen
    shareRecipes = true,     -- eigene Rezepte teilen
    shareGold = true,        -- Gold nur an online Eigentuemer schicken
    follow = false,          -- Rangliste verfolgen (Popups)
    boardNotify = true,      -- Hinweis bei neuen Auftraegen/Anfragen
    mapShow = true,          -- Gildenmitglieder auf der Weltkarte zeigen
    mapShare = true,         -- eigene Position teilen
    mapSize = 24,            -- Symbolgroesse in Pixeln (8 bis 64)
    mapMini = true,          -- Gildenmitglieder auf der Minimap zeigen
    miniSize = 14,           -- Symbolgroesse auf der Minimap (8 bis 32)
    headShow = true,         -- Affensymbol ueber dem Kopf von Gildenmitgliedern
    headSize = 28,           -- Symbolgroesse in Pixeln (16 bis 64)
    achNotify = true,        -- Hinweisfenster, wenn die Gilde einen Erfolg schafft
    tradeChat = true,        -- Berufe aus Chat-Links von Gildenmitgliedern merken
    headPlates = true,       -- Plaketten freundlicher Spieler (gleichgeschaltet mit der Spieleinstellung)
    headInst = true,         -- Symbol auch in Instanzen (dort sonst Blizzard-Standard)
    dungChat = true,         -- Zeile im Gildenchat, wenn man sich fuer einen Dungeon anmeldet
    dungAutoGuild = false,   -- Einladungen von Gildenmitgliedern bei laufender Suche annehmen
    dungAutoFriends = false, -- dasselbe fuer Freunde
    dungWin = true,          -- kleines Fenster, das zeigt, wer in der Gilde nach einer Gruppe sucht
    headBars = true,         -- Lebensbalken und Name der Plakette bleiben sichtbar (aus: nur das Symbol)
}

function Guild.DB()
    local db = G.FreewoodGuildDB
    db.members = db.members or {}      -- [Schluessel] = geteilte Daten
    db.races = db.races or {}          -- [Schluessel] = Rassenname
    db.fav = db.fav or { account = {}, chars = {} }
    db.settings = db.settings or {}
    for k, v in pairs(Guild.SETTINGS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    return db
end

function Guild.Setting(key)
    return Guild.DB().settings[key]
end

------------------------------------------------------------------------
-- Namen
------------------------------------------------------------------------

-- Realm ueber den Core (leerer Text vom Spiel zaehlt nicht, der letzte echte Name ist gemerkt; 0.9.13, Forever_Failure F-37)
local function NonEmpty(v) if type(v) == "string" and v ~= "" then return v end return nil end
local function OwnRealm()
    local FWc = G.Freewood
    local r = (FWc and FWc.Util and FWc.Util.NormalizedRealm and NonEmpty(FWc.Util.NormalizedRealm()))
        or NonEmpty(G.GetNormalizedRealmName and G.GetNormalizedRealmName())
        or NonEmpty(G.GetRealmName and G.GetRealmName()) or ""
    return string.lower((string.gsub(tostring(r or ""), "[%s%-]", "")))
end

-- Eigener Realm hat mehrere Schreibweisen (Forever: GetNormalizedRealmName, GetRealmName, UnitFullName liefert den Nachnamen)
local function IsOwnRealmVariant(r)
    if r == OwnRealm() then return true end
    if G.GetRealmName then
        local ok, v = pcall(G.GetRealmName)
        if ok and type(v) == "string" and string.lower((string.gsub(v, "[%s%-]", ""))) == r then return true end
    end
    return false
end

-- Schluessel: Kleinschreibung, eigener Realm abgeschnitten ("Name-Realm" -> "name")
function Guild.Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    local base, realm = string.match(name, "^(.-)%-([^%-]+)$")
    if base and base ~= "" then
        local r = string.lower((string.gsub(realm, "[%s]", "")))
        if IsOwnRealmVariant(r) then name = base end
    end
    return string.lower(name)
end

-- Anzeigename: eigener Realm abgeschnitten
function Guild.Display(name)
    if type(name) ~= "string" then return "?" end
    local base, realm = string.match(name, "^(.-)%-([^%-]+)$")
    if base and base ~= "" then
        local r = string.lower((string.gsub(realm, "[%s]", "")))
        if r == OwnRealm() then return base end
    end
    return name
end

-- Forever: Charaktere haben Vor- und Nachnamen. UnitName liefert nur den Vornamen ("Pinky"), UnitFullName
-- Vor- und Nachnamen getrennt ("Pinky", "Freewood"); die Gilde sieht "Pinky Freewood". Ohne den Nachnamen
-- bekam jeder Spieler zwei Eintraege (eigener Satz und das eigene Echo der Gildennachricht).
function Guild.SelfFirstName()
    local n = G.UnitName and G.UnitName("player")
    if type(n) == "string" and not Secret(n) then return n end
    return nil
end

function Guild.SelfName()
    if G.UnitFullName then
        local ok, n, second = pcall(G.UnitFullName, "player")
        if ok and type(n) == "string" and not Secret(n) and n ~= "" then
            if type(second) == "string" and not Secret(second) and second ~= ""
                and string.lower((string.gsub(second, "[%s%-]", ""))) ~= OwnRealm() and not IsOwnRealmVariant(string.lower((string.gsub(second, "[%s%-]", "")))) then
                return n .. " " .. second
            end
            return n
        end
    end
    return Guild.SelfFirstName()
end

-- Alte Eintraege unter dem Vornamen ("pinky") in den vollen Namen ("pinky freewood") ueberfuehren
local function MergeInto(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        elseif type(dst[k]) == "table" and type(v) == "table" then
            MergeInto(dst[k], v)
        end
    end
end

function Guild.MigrateSelf()
    local new, first = Guild.SelfKey(), Guild.SelfFirstName()
    local old = first and string.lower(first)
    if not new or not old or old == new then return false end
    local db = Guild.DB()
    local moved = false
    if db.members[old] then
        db.members[new] = db.members[new] or {}
        MergeInto(db.members[new], db.members[old])
        db.members[new].self = true
        db.members[old] = nil
        moved = true
    end
    if db.races and db.races[old] then
        db.races[new] = db.races[new] or db.races[old]
        db.races[old] = nil
    end
    local chars = db.fav and db.fav.chars
    if chars and chars[old] then
        chars[new] = chars[new] or chars[old]
        chars[old] = nil
        moved = true
    end
    if moved and Guild.Changed then Guild.Changed() end
    return moved
end

function Guild.SelfKey()
    return Guild.Key(Guild.SelfName())
end

------------------------------------------------------------------------
-- Berufe
------------------------------------------------------------------------

-- Fertigkeits-IDs (Vanilla-Zaehlung) und Namen in enUS/deDE
Guild.PROF = {
    [171] = { en = "Alchemy", de = "Alchemie", group = 1 },
    [164] = { en = "Blacksmithing", de = "Schmiedekunst", group = 1 },
    [333] = { en = "Enchanting", de = "Verzauberkunst", group = 1 },
    [202] = { en = "Engineering", de = "Ingenieurskunst", group = 1 },
    [165] = { en = "Leatherworking", de = "Lederverarbeitung", group = 1 },
    [197] = { en = "Tailoring", de = "Schneiderei", group = 1 },
    [182] = { en = "Herbalism", de = "Kräuterkunde", group = 2 },
    [186] = { en = "Mining", de = "Bergbau", group = 2 },
    [393] = { en = "Skinning", de = "Kürschnerei", group = 2 },
    [185] = { en = "Cooking", de = "Kochen", group = 3, alias = { "Kochkunst" } },
    [129] = { en = "First Aid", de = "Erste Hilfe", group = 3 },
    [356] = { en = "Fishing", de = "Angeln", group = 3 },
}
Guild.COOK, Guild.AID, Guild.FISH = 185, 129, 356

local byName = {}
for id, p in pairs(Guild.PROF) do
    byName[string.lower(p.en)] = id
    byName[string.lower(p.de)] = id
    if p.alias then
        for _, a in ipairs(p.alias) do byName[string.lower(a)] = id end
    end
end

function Guild.ProfByName(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    return byName[string.lower(name)]
end

local function Lang()
    local loc = G.GetLocale and G.GetLocale() or "enUS"
    return loc == "deDE" and "de" or "en"
end

function Guild.ProfName(id)
    local p = Guild.PROF[id]
    if not p then return tostring(id) end
    return p[Lang()] or p.en
end

-- Reihenfolge: aus einer Liste { [id] = { rank, max } } werden Hauptberuf 1 und 2 gewaehlt
function Guild.MainProfs(skills)
    local g1, g2 = {}, {}
    if type(skills) == "table" then
        for id, s in pairs(skills) do
            local p = Guild.PROF[id]
            if p and p.group == 1 then g1[#g1 + 1] = id
            elseif p and p.group == 2 then g2[#g2 + 1] = id end
        end
    end
    table.sort(g1)
    table.sort(g2)
    local p1, p2 = g1[1], g2[1] or g1[2]
    if not p1 and g2[1] then
        p1, p2 = g2[1], g2[2]
    end
    return p1, p2
end

------------------------------------------------------------------------
-- Rassen
------------------------------------------------------------------------

local RACE_DE = {
    Human = "Mensch", Dwarf = "Zwerg", NightElf = "Nachtelf", Gnome = "Gnom", Draenei = "Draenei",
    Worgen = "Worgen", Pandaren = "Pandaren", Orc = "Orc", Scourge = "Untoter", Undead = "Untoter",
    Tauren = "Tauren", Troll = "Troll", BloodElf = "Blutelf", Goblin = "Goblin", HighElf = "Hochelf",
    VoidElf = "Leerenelf", LightforgedDraenei = "Lichtgeschmiedeter Draenei", DarkIronDwarf = "Dunkeleisenzwerg",
    KulTiran = "Kul Tiraner", Mechagnome = "Mechagnom", Nightborne = "Nachtgeborener",
    HighmountainTauren = "Hochbergtauren", MagharOrc = "Mag'har", ZandalariTroll = "Zandalaritroll",
    Vulpera = "Vulpera", Dracthyr = "Dracthyr", EarthenDwarf = "Irdener",
}

function Guild.RaceName(token)
    if type(token) ~= "string" or token == "" then return nil end
    if Lang() == "de" and RACE_DE[token] then return RACE_DE[token] end
    return (string.gsub(token, "(%l)(%u)", "%1 %2"))
end

------------------------------------------------------------------------
-- Gildenliste
------------------------------------------------------------------------

Guild.rows = {}          -- Zeilen der Gildenliste
Guild.rowByKey = {}
Guild.version = 0        -- zaehlt hoch, wenn sich Zeilen oder Daten aendern
Guild.rosterAt = 0

local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end

function Guild.InGuild()
    return G.IsInGuild and G.IsInGuild() and true or false
end

function Guild.RequestRoster(force)
    local now = Clock()
    if not force and now - (Guild.lastRequest or -100) < 15 then return end
    Guild.lastRequest = now
    if not Guild.InGuild() then return end
    local gi = G.C_GuildInfo
    if gi and type(gi.GuildRoster) == "function" then
        pcall(gi.GuildRoster)
    elseif type(G.GuildRoster) == "function" then
        pcall(G.GuildRoster)
    end
end

local function RaceFor(key, guid)
    local db = Guild.DB()
    if db.races[key] then return db.races[key] end
    if guid and type(guid) == "string" and not Secret(guid) and G.GetPlayerInfoByGUID then
        local ok, _, _, localized, token = pcall(G.GetPlayerInfoByGUID, guid)
        if ok then
            local race = (type(localized) == "string" and localized ~= "" and localized)
                or (type(token) == "string" and token ~= "" and Guild.RaceName(token)) or nil
            if race then db.races[key] = race; return race end
        end
    end
    return nil
end

function Guild.ReadRoster()
    local rows, byKey = {}, {}
    if Guild.InGuild() and G.GetNumGuildMembers and G.GetGuildRosterInfo then
        local n = G.GetNumGuildMembers() or 0
        local db = Guild.DB()
        for i = 1, n do
            local name, rank, rankIndex, level, class, zone, note, onote, online, status, classFile, _, _, _, _, _, guid =
                G.GetGuildRosterInfo(i)
            if type(name) == "string" and not Secret(name) then
                local key = Guild.Key(name)
                local token = FW.ChatLog and FW.ChatLog.ClassToken(classFile or class) or classFile
                local shared = db.members[key]
                local race = RaceFor(key, guid) or (shared and shared.race and Guild.RaceName(shared.race)) or nil
                local last
                if not online and G.GetGuildRosterLastOnline then
                    local ok, y, m, d, h = pcall(G.GetGuildRosterLastOnline, i)
                    if ok and y then last = ((y * 12 + (m or 0)) * 30 + (d or 0)) * 24 + (h or 0) end
                end
                local row = {
                    name = Guild.Display(name), full = name, key = key,
                    level = tonumber(level) or 0, class = token, className = type(class) == "string" and class or nil,
                    race = race, rank = type(rank) == "string" and rank or "", rankIndex = tonumber(rankIndex) or 99,
                    zone = type(zone) == "string" and zone or "", online = online and true or false,
                    lastHours = last, guid = guid, note = type(note) == "string" and not Secret(note) and note or "",
                    onote = type(onote) == "string" and not Secret(onote) and onote or "",
                    index = i, rankOrder = (tonumber(rankIndex) or 98) + 1,
                }
                rows[#rows + 1] = row
                byKey[key] = row
                if FW.ChatLog and FW.ChatLog.Note then pcall(FW.ChatLog.Note, name, classFile or class, level) end
            end
        end
    end
    Guild.rows, Guild.rowByKey = rows, byKey
    Guild.rosterAt = Clock()
    Guild.version = Guild.version + 1
    FW:Fire("GUILD_MODULE_ROSTER")
end

function Guild.Row(name)
    return Guild.rowByKey[Guild.Key(name) or ""]
end

function Guild.Shared(name)
    return Guild.DB().members[Guild.Key(name) or ""]
end

function Guild.IsGuildMaster(row)
    return row and row.rankIndex == 0
end

function Guild.IsOwner()
    local c = FW.Codex
    return c and c.Trust and c.Trust.IsSelfOwner and c.Trust.IsSelfOwner() and true or false
end

function Guild.IsOwnerName(name)
    local c = FW.Codex
    return c and c.Trust and c.Trust.RoleOf and c.Trust.RoleOf(name) == "owner" or false
end

function Guild.Changed()
    Guild.version = Guild.version + 1
    FW:Fire("GUILD_MODULE_DATA")
end

------------------------------------------------------------------------
-- Zeit und Zahlen
------------------------------------------------------------------------

function Guild.FormatPlayed(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then return "-" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds - d * 86400) / 3600)
    local m = math.floor((seconds - d * 86400 - h * 3600) / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    return string.format("%dh %dm", h, m)
end

function Guild.FormatAgo(stamp)
    stamp = tonumber(stamp)
    if not stamp then return "-" end
    local diff = Now() - stamp
    if diff < 60 then return L.GUILD_AGO_NOW end
    if diff < 3600 then return string.format(L.GUILD_AGO_MIN, math.floor(diff / 60)) end
    if diff < 86400 then return string.format(L.GUILD_AGO_HOUR, math.floor(diff / 3600)) end
    return string.format(L.GUILD_AGO_DAY, math.floor(diff / 86400))
end

-- Erfahrung bis zum Erreichen eines Levels (Vanilla-Tabelle, Forever kann abweichen: UNGEPRUEFT)
local XP_NEXT = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8700, 9800, 11000, 12300, 13600, 15000, 16400, 17800,
    19300, 20800, 22400, 24000, 25500, 27200, 28900, 30500, 32200, 33900, 36300, 38800, 41600, 44600, 48000, 51400,
    55000, 58700, 62400, 66200, 70200, 74300, 78500, 82800, 87100, 91600, 96300, 101000, 105800, 110700, 115700,
    120900, 126100, 131500, 137000, 142500, 148200, 154000, 159900, 165800, 172000,
}
Guild.XP_NEXT = XP_NEXT

-- Forever weicht von der Vanilla-Tabelle ab (Probe: Level 13 braucht 11400 statt 11000). Deshalb merkt sich das Modul
-- die echten Werte, die Spieler melden (Level -> EP bis zum naechsten Level). Unbekannte Level werden aus der
-- Vanilla-Tabelle mit dem mittleren Verhaeltnis der bekannten Level hochgerechnet.
function Guild.LearnXP(level, xpmax)
    level, xpmax = tonumber(level), tonumber(xpmax)
    if not level or not xpmax or level < 1 or level > #XP_NEXT or xpmax <= 0 or Secret(xpmax) then return end
    local db = Guild.DB()
    db.xpTable = db.xpTable or {}
    db.xpTable[level] = xpmax
end

local function XPScale()
    local t = Guild.DB().xpTable
    if not t then return 1 end
    local sum, n = 0, 0
    for l, v in pairs(t) do
        if XP_NEXT[l] then sum = sum + v / XP_NEXT[l]; n = n + 1 end
    end
    return n > 0 and sum / n or 1
end

function Guild.XPNext(level, scale)
    local t = Guild.DB().xpTable
    if t and t[level] then return t[level] end
    return (XP_NEXT[level] or XP_NEXT[#XP_NEXT]) * (scale or XPScale())
end

-- Gesamt-EP, die ein Charakter bisher gesammelt hat
function Guild.TotalXP(level, xp)
    level = tonumber(level) or 1
    local total = 0
    local scale = XPScale()
    for l = 1, level - 1 do
        total = total + Guild.XPNext(l, scale)
    end
    return total + (tonumber(xp) or 0)
end

function Guild.XPFraction(level, xp, xpmax)
    xp, xpmax = tonumber(xp), tonumber(xpmax)
    if xp and xpmax and xpmax > 0 then return math.min(1, math.max(0, xp / xpmax)) end
    return nil
end

------------------------------------------------------------------------
-- Probe: was liefert Forever wirklich?
------------------------------------------------------------------------

local function Has(path)
    local obj = G
    for part in string.gmatch(path, "[^%.]+") do
        if type(obj) ~= "table" then return false end
        obj = obj[part]
        if obj == nil then return false end
    end
    return type(obj) == "function" or type(obj) == "table" or obj ~= nil
end

function Guild.ProbeText()
    local out = {}
    local function Add(s) out[#out + 1] = s end
    local names = {
        "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo", "GetGuildRosterLastOnline", "C_GuildInfo.GuildRoster",
        "GetPlayerInfoByGUID", "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
        "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetTradeSkillLine",
        "C_TradeSkillUI.GetBaseProfessionInfo", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillRecipeLink",
        "GetNumCrafts", "RequestTimePlayed", "UnitXP", "UnitXPMax", "GetMoney", "C_ChatInfo.SendAddonMessage",
        "C_ChatInfo.RegisterAddonMessagePrefix", "SendAddonMessage", "C_PartyInfo.InviteUnit", "InviteUnit",
        "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "GetSavedInstanceInfo", "C_Spell.GetSpellName",
        "GetSpellInfo",
    }
    for _, n in ipairs(names) do
        Add(string.format("%s %s", Has(n) and "+" or "-", n))
    end
    local inGuild = Guild.InGuild()
    Add("Gilde: " .. (inGuild and "ja" or "nein") .. (inGuild and "" or " (Gildenliste und Rasse per GUID koennen nur in einer Gilde geprueft werden)"))
    if inGuild and G.GetNumGuildMembers then
        Add("Mitglieder: " .. tostring(G.GetNumGuildMembers()))
        local first = { G.GetGuildRosterInfo(1) }
        local parts = {}
        for i = 1, 17 do
            local v = first[i]
            if Secret(v) then v = "<geheim>" end
            parts[#parts + 1] = i .. "=" .. tostring(v)
        end
        Add("Eintrag 1: " .. table.concat(parts, " "))
        local guid = first[17]
        if type(guid) == "string" and G.GetPlayerInfoByGUID then
            local ok, a, b, c, d = pcall(G.GetPlayerInfoByGUID, guid)
            Add("Rasse per GUID: " .. tostring(ok) .. " " .. tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d))
        else
            Add("Rasse per GUID: keine GUID im Eintrag 17")
        end
    end
    if G.GetProfessions then
        local a, b, c, d, e, f = G.GetProfessions()
        Add("GetProfessions: " .. tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d) .. " " .. tostring(e) .. " " .. tostring(f))
        if G.GetProfessionInfo then
            for i, idx in ipairs({ a, b, c, d, e, f }) do
                if idx then
                    local ok, r1, r2, r3, r4, r5, r6, r7 = pcall(G.GetProfessionInfo, idx)
                    Add("Beruf " .. i .. " (Index " .. tostring(idx) .. "): " .. tostring(r1) .. " | Rang " .. tostring(r3) .. "/" .. tostring(r4) .. " | Fertigkeit-ID " .. tostring(r7))
                end
            end
        end
    end
    Add("Eigene Berufe: " .. (function()
        local s = Guild.Share and Guild.Share.ReadSkills and Guild.Share.ReadSkills() or {}
        local t = {}
        for id, v in pairs(s) do t[#t + 1] = Guild.ProfName(id) .. " " .. tostring(v.rank) .. "/" .. tostring(v.max) end
        return #t > 0 and table.concat(t, ", ") or "keine gefunden"
    end)())
    Add("Gelernte EP-Werte: " .. (function()
        local t, n = Guild.DB().xpTable or {}, 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end)())
    Add("Max. Level-Tabelle Eintraege: " .. #XP_NEXT .. "; UnitXPMax(player) = " .. tostring(G.UnitXPMax and G.UnitXPMax("player")) ..
        " (Tabelle fuer eigenes Level: " .. tostring(XP_NEXT[(G.UnitLevel and G.UnitLevel("player") or 1)]) .. ")")
    return out
end

function Guild.Probe()
    FW:Print("Guild-Probe (+ vorhanden, - fehlt):")
    for _, line in ipairs(Guild.ProbeText()) do FW:Print(line) end
end

------------------------------------------------------------------------
-- Seiten im Gilden-Fenster (andere Dateien melden sich hier an)
------------------------------------------------------------------------

Guild.pages = {}

-- def = { order =, label = function() ... end, build = function(parent) return frame end, refresh = function(frame) end }
function Guild.RegisterPage(id, def)
    def.id = id
    def.order = def.order or 100
    Guild.pages[#Guild.pages + 1] = def
    table.sort(Guild.pages, function(a, b) return a.order < b.order end)
    if Guild.OnPageRegistered then Guild.OnPageRegistered(def) end
end

------------------------------------------------------------------------
-- Ablauf
------------------------------------------------------------------------

local ticker, accum = nil, 0

function Guild:OnEnable()
    Guild.DB()
    FW:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        Guild.pendingRead = Clock() + 0.5
    end, self)
    FW:RegisterEvent("PLAYER_GUILD_UPDATE", function() Guild.RequestRoster(true) end, self)
    ticker = ticker or CreateFrame("Frame")
    accum = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + (elapsed or 0)
        if accum < 0.25 then return end
        accum = 0
        if Guild.pendingRead and Clock() >= Guild.pendingRead then
            Guild.pendingRead = nil
            Guild.ReadRoster()
        end
        if Guild.Share and Guild.Share.Pump then Guild.Share.Pump() end
    end)
    Guild.RequestRoster(true)
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(5, function() Guild.RequestRoster(true) end)
    end
end

function Guild:OnDisable()
    FW:UnregisterEvent("GUILD_ROSTER_UPDATE", self)
    FW:UnregisterEvent("PLAYER_GUILD_UPDATE", self)
    if ticker then ticker:SetScript("OnUpdate", nil) end
end

------------------------------------------------------------------------
-- Befehle
------------------------------------------------------------------------

SLASH_FREEWOODGUILD1 = "/fwguild"
SLASH_FREEWOODGUILD2 = "/fwgilde"
SlashCmdList["FREEWOODGUILD"] = function(msg)
    msg = string.lower((string.gsub(msg or "", "^%s+", "")))
    local cmd, rest = string.match(msg, "^(%S+)%s+(.+)$")
    if cmd == "mitgliedrezepte" then
        if Guild.RecipeQuery then Guild.RecipeQuery.MemberRecipes(rest) end
        return
    end
    if msg == "sendtest" then
        FW:Print("Sende-Test (14 Nachrichten hintereinander):")
        for _, l in ipairs(Guild.Share.SendTest()) do FW:Print(l) end
        return
    elseif msg == "stats" then
        FW:Print(Guild.Share.Stats())
        for _, mod in ipairs({ Guild.Map, Guild.Head }) do
            if mod and mod.DiagLines then
                local ok, lines = pcall(mod.DiagLines)
                if ok then for _, l in ipairs(lines) do FW:Print(l) end else FW:Print("Messfehler: " .. tostring(lines)) end
            end
        end
        return
    elseif msg == "probe" then
        Guild.Probe()
    elseif msg == "share" then
        if Guild.Share then Guild.Share.SendAll(true) end
        FW:Print(L.GUILD_SHARE_SENT)
    elseif msg == "gildenberufe" then
        if Guild.RecipeQuery then Guild.RecipeQuery.RunBoard() end
    elseif msg == "mitgliedrezepte" then
        if Guild.RecipeQuery then Guild.RecipeQuery.MemberRecipes("") end
    elseif msg == "gildenrezepte" then
        if Guild.RecipeQuery then Guild.RecipeQuery.Run() end
    elseif msg == "trade" then
        if Guild.TradeLink then Guild.TradeLink.PrintList() end
    elseif msg == "linkdebug" then
        if Guild.TradeLink then Guild.TradeLink.ToggleDebug() end
    elseif msg == "refresh" then
        Guild.RequestRoster(true)
    else
        if FW.UI and FW.UI.Toggle then FW.UI:Toggle("guild") end
    end
end
