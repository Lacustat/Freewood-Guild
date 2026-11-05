-- Freewood-Guild: geteilte Daten. Jeder Spieler mit dem Addon meldet in der Gilde: Berufe, Level, EP, Spielzeit, Rasse
-- und (nach dem Oeffnen des Berufefensters) seine Rezepte. Gold geht nur als Fluesternachricht an online Eigentuemer.
-- Alle Nachrichten laufen ueber eine gedrosselte Warteschlange. Alles UNGEPRUEFT im Spiel.
--
-- Nachrichten (Praefix FWGuild1, Gilde):
--   P|l=<Level>;x=<EP>;m=<EP bis Level>;t=<Spielzeit s>;r=<Rasse>;s=<id:Rang:Max,...>   Profil
--   C|<Beruf>|<Teil>|<Teile>|<id,id,...>                                                  Rezepte (in Stuecken)
--   Q|r=1                                                                                 Bitte um Profile (r=1 auch Rezepte)
--   G|<Kupfer>                                                                            Gold (Fluestern an Eigentuemer)

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local Share = {}
Guild.Share = Share

local PREFIX = "FWGuild1"
local GAP = 0.7                 -- Sekunden zwischen zwei gesendeten Nachrichten
local MAX_QUEUE = 120
local PIECE = 200               -- Zeichen je Rezept-Stueck
local PROFILE_EVERY = 300       -- Sekunden zwischen zwei Profil-Meldungen
local GOLD_EVERY = 600
local MAX_RECIPES = 400         -- je Beruf

local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Now() return G.time and G.time() or 0 end
local function Secret(v) return Guild.Secret(v) end

local queue, tasks = {}, {}
local lastSend = -100
local lastProfile, lastRecipes, lastGold = -10000, -10000, -10000
local rbuf = {}
local played = nil              -- { base =, at = }

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

local function Raw(text, dist, target)
    local api = G.C_ChatInfo
    if api and api.SendAddonMessage then
        local ok = pcall(api.SendAddonMessage, PREFIX, text, dist, target)
        return ok
    elseif G.SendAddonMessage then
        return pcall(G.SendAddonMessage, PREFIX, text, dist, target)
    end
    return false
end

function Share.Queue(text, dist, target)
    if #text > 250 then return false end
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    queue[#queue + 1] = { text = text, dist = dist or "GUILD", target = target }
    return true
end

function Share.After(seconds, fn)
    tasks[#tasks + 1] = { at = Clock() + seconds, fn = fn }
end

function Share.QueueLength() return #queue end
function Share.Reset() queue, tasks = {}, {} end

function Share.Pump()
    local now = Clock()
    if #tasks > 0 then
        local keep = {}
        local due = {}
        for _, t in ipairs(tasks) do
            if t.at <= now then due[#due + 1] = t else keep[#keep + 1] = t end
        end
        tasks = keep
        for _, t in ipairs(due) do pcall(t.fn) end
    end
    if Share.scanAt and now >= Share.scanAt then
        Share.scanAt = nil
        pcall(Share.ScanRecipes)
    end
    if Share.dirtyAt and now >= Share.dirtyAt then
        Share.dirtyAt = nil
        pcall(Share.UpdateSelf)
    end
    if #queue > 0 and now - lastSend >= GAP then
        local m = table.remove(queue, 1)
        lastSend = now
        Raw(m.text, m.dist, m.target)
    end
    if Guild.Setting("shareProfile") and Guild.InGuild() and now - lastProfile >= PROFILE_EVERY and Share.started then
        Share.SendProfile()
    end
    if Guild.Setting("shareGold") and Guild.InGuild() and now - lastGold >= GOLD_EVERY and Share.started then
        Share.SendGold()
    end
end

------------------------------------------------------------------------
-- Eigene Daten lesen
------------------------------------------------------------------------

-- Berufe: { [id] = { rank =, max = } }
function Share.ReadSkills()
    local out = {}
    if G.GetProfessions and G.GetProfessionInfo then
        local a, b, c, d, e, f = G.GetProfessions()
        local idxs = { a, b, c, d, e, f }
        for i = 1, 6 do
            local idx = idxs[i]
            if idx then
                local ok, name, _, rank, maxRank, _, _, skillLine = pcall(G.GetProfessionInfo, idx)
                if ok and not Secret(name) then
                    local id = (skillLine and Guild.PROF[skillLine] and skillLine) or Guild.ProfByName(name)
                    if id then out[id] = { rank = tonumber(rank) or 0, max = tonumber(maxRank) or 0 } end
                end
            end
        end
    end
    if next(out) == nil and G.GetNumSkillLines and G.GetSkillLineInfo then
        local n = G.GetNumSkillLines() or 0
        for i = 1, n do
            local name, header, _, rank, _, _, maxRank = G.GetSkillLineInfo(i)
            if name and not header then
                local id = Guild.ProfByName(name)
                if id then out[id] = { rank = tonumber(rank) or 0, max = tonumber(maxRank) or 0 } end
            end
        end
    end
    return out
end

function Share.PlayedNow()
    if not played then return nil end
    return played.base + (Clock() - played.at)
end

local function AskPlayed()
    if not G.RequestTimePlayed then return end
    -- die Chatfenster sollen die Zeile "Gesamtspielzeit" nicht ausgeben
    local hidden = {}
    local n = G.NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        local cf = G["ChatFrame" .. i]
        if cf and cf.IsEventRegistered and cf.UnregisterEvent then
            local ok, reg = pcall(cf.IsEventRegistered, cf, "TIME_PLAYED_MSG")
            if ok and reg then
                pcall(cf.UnregisterEvent, cf, "TIME_PLAYED_MSG")
                hidden[#hidden + 1] = cf
            end
        end
    end
    pcall(G.RequestTimePlayed)
    if #hidden > 0 then
        Share.After(2.5, function()
            for _, cf in ipairs(hidden) do pcall(cf.RegisterEvent, cf, "TIME_PLAYED_MSG") end
        end)
    end
end
Share.AskPlayed = AskPlayed

function Share.OwnData()
    local d = { stamp = Now(), skills = Share.ReadSkills() }
    d.level = G.UnitLevel and tonumber(G.UnitLevel("player")) or nil
    d.xp = G.UnitXP and tonumber(G.UnitXP("player")) or nil
    d.xpmax = G.UnitXPMax and tonumber(G.UnitXPMax("player")) or nil
    if G.UnitRace then
        local _, token = G.UnitRace("player")
        if type(token) == "string" and not Secret(token) then d.race = token end
    end
    d.played = Share.PlayedNow()
    d.gold = G.GetMoney and tonumber(G.GetMoney()) or nil
    return d
end

-- eigene Daten in die Tabelle der Gilde uebernehmen
function Share.UpdateSelf()
    local key = Guild.SelfKey()
    if not key then return end
    local db = Guild.DB()
    local d = Share.OwnData()
    local rec = db.members[key] or {}
    rec.level, rec.xp, rec.xpmax = d.level, d.xp, d.xpmax
    rec.race = d.race or rec.race
    rec.skills = d.skills
    rec.played = d.played or rec.played
    rec.gold = d.gold
    rec.stamp = d.stamp
    rec.self = true
    db.members[key] = rec
    Guild.Changed()
end

------------------------------------------------------------------------
-- Profil senden und empfangen
------------------------------------------------------------------------

local function EncodeProfile(d)
    local s = {}
    for id, v in pairs(d.skills or {}) do
        s[#s + 1] = id .. ":" .. (v.rank or 0) .. ":" .. (v.max or 0)
    end
    table.sort(s)
    local parts = {}
    if d.level then parts[#parts + 1] = "l=" .. d.level end
    if d.xp then parts[#parts + 1] = "x=" .. d.xp end
    if d.xpmax then parts[#parts + 1] = "m=" .. d.xpmax end
    if d.played then parts[#parts + 1] = "t=" .. math.floor(d.played) end
    if d.race then parts[#parts + 1] = "r=" .. string.gsub(d.race, "[^%w]", "") end
    parts[#parts + 1] = "s=" .. table.concat(s, ",")
    return "P|" .. table.concat(parts, ";")
end
Share.EncodeProfile = EncodeProfile

local function DecodeProfile(body)
    local d = { skills = {} }
    for k, v in string.gmatch(body, "(%a+)=([^;]*)") do
        if k == "l" then d.level = tonumber(v)
        elseif k == "x" then d.xp = tonumber(v)
        elseif k == "m" then d.xpmax = tonumber(v)
        elseif k == "t" then d.played = tonumber(v)
        elseif k == "r" then d.race = v ~= "" and v or nil
        elseif k == "s" then
            for id, rank, max in string.gmatch(v, "(%d+):(%d+):(%d+)") do
                id = tonumber(id)
                if Guild.PROF[id] then d.skills[id] = { rank = tonumber(rank), max = tonumber(max) } end
            end
        end
    end
    return d
end
Share.DecodeProfile = DecodeProfile

function Share.SendProfile()
    lastProfile = Clock()
    if not Guild.Setting("shareProfile") or not Guild.InGuild() then return false end
    Share.UpdateSelf()
    local rec = Guild.DB().members[Guild.SelfKey() or ""]
    if not rec then return false end
    return Share.Queue(EncodeProfile(rec), "GUILD")
end

local function OnlineOwners()
    local out = {}
    for _, row in ipairs(Guild.rows) do
        if row.online and row.key ~= Guild.SelfKey() and Guild.IsOwnerName(row.full) then out[#out + 1] = row end
    end
    return out
end

function Share.SendGold()
    lastGold = Clock()
    if not Guild.Setting("shareGold") or not Guild.InGuild() then return 0 end
    local money = G.GetMoney and tonumber(G.GetMoney())
    if not money then return 0 end
    local n = 0
    for _, row in ipairs(OnlineOwners()) do
        if n >= 6 then break end
        Share.Queue("G|" .. math.floor(money), "WHISPER", row.full)
        n = n + 1
    end
    return n
end

------------------------------------------------------------------------
-- Rezepte
------------------------------------------------------------------------

local function IdFromLink(link)
    if type(link) ~= "string" or Secret(link) then return nil end
    local id = string.match(link, "enchant:(%d+)") or string.match(link, "spell:(%d+)") or string.match(link, "recipe:(%d+)")
    return id and tonumber(id) or nil
end

-- Berufsfenster lesen. Rueckgabe: Beruf-ID, Liste der bekannten Rezept-IDs
function Share.ReadRecipes()
    local ts = G.C_TradeSkillUI
    local profId, ids
    local function ProfFrom(a, b)
        if type(a) == "number" and Guild.PROF[a] then return a end
        if type(a) == "string" then return Guild.ProfByName(a) end
        if type(b) == "string" then return Guild.ProfByName(b) end
        return nil
    end
    if ts and ts.GetAllRecipeIDs and ts.GetRecipeInfo then
        local ok, all = pcall(ts.GetAllRecipeIDs)
        if ok and type(all) == "table" and #all > 0 then
            ids = {}
            for _, rid in ipairs(all) do
                local okInfo, info = pcall(ts.GetRecipeInfo, rid)
                if okInfo and type(info) == "table" and info.learned then ids[#ids + 1] = rid end
            end
            if ts.GetBaseProfessionInfo then
                local okB, bi = pcall(ts.GetBaseProfessionInfo)
                if okB and type(bi) == "table" then
                    profId = ProfFrom(bi.professionID, bi.professionName)
                end
            end
            if not profId and ts.GetTradeSkillLine then
                local okL, a, b = pcall(ts.GetTradeSkillLine)
                if okL then profId = ProfFrom(a, b) end
            end
        end
    end
    if not ids and G.GetNumTradeSkills and G.GetTradeSkillInfo then
        local n = G.GetNumTradeSkills() or 0
        if n > 0 then
            ids = {}
            for i = 1, n do
                local _, ttype = G.GetTradeSkillInfo(i)
                if ttype and ttype ~= "header" and G.GetTradeSkillRecipeLink then
                    local okL, link = pcall(G.GetTradeSkillRecipeLink, i)
                    local id = okL and IdFromLink(link) or nil
                    if id then ids[#ids + 1] = id end
                end
            end
            if G.GetTradeSkillLine then
                local okL, a, b = pcall(G.GetTradeSkillLine)
                if okL then profId = ProfFrom(a, b) end
            end
        end
    end
    if not ids and G.GetNumCrafts and G.GetCraftInfo then
        local n = G.GetNumCrafts() or 0
        if n > 0 then
            ids = {}
            for i = 1, n do
                local fn = G.GetCraftRecipeLink or G.GetCraftItemLink
                if fn then
                    local okL, link = pcall(fn, i)
                    local id = okL and IdFromLink(link) or nil
                    if id then ids[#ids + 1] = id end
                end
            end
            if G.GetCraftDisplaySkillLine then
                local okL, a = pcall(G.GetCraftDisplaySkillLine)
                if okL then profId = ProfFrom(a, nil) end
            end
            profId = profId or Guild.PROF_ENCHANT or 333
        end
    end
    return profId, ids
end

local function UniqueSorted(ids)
    local seen, out = {}, {}
    for _, id in ipairs(ids) do
        if not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
    table.sort(out)
    if #out > MAX_RECIPES then
        local cut = {}
        for i = 1, MAX_RECIPES do cut[i] = out[i] end
        out = cut
    end
    return out
end

local function Pieces(ids)
    local out, cur = {}, {}
    local len = 0
    for _, id in ipairs(ids) do
        local s = tostring(id)
        if len + #s + 1 > PIECE and #cur > 0 then
            out[#out + 1] = table.concat(cur, ",")
            cur, len = {}, 0
        end
        cur[#cur + 1] = s
        len = len + #s + 1
    end
    if #cur > 0 then out[#out + 1] = table.concat(cur, ",") end
    return out
end

function Share.SendRecipes(profId, ids)
    local pieces = Pieces(ids)
    for i, csv in ipairs(pieces) do
        Share.Queue("C|" .. profId .. "|" .. i .. "|" .. #pieces .. "|" .. csv, "GUILD")
    end
    return #pieces
end

function Share.ScanRecipes()
    local profId, ids = Share.ReadRecipes()
    if not profId or not ids or #ids == 0 then return false end
    ids = UniqueSorted(ids)
    local key = Guild.SelfKey()
    if not key then return false end
    local db = Guild.DB()
    local rec = db.members[key] or {}
    rec.recipes = rec.recipes or {}
    local hash = table.concat(ids, ",")
    local changed = rec.recipes[profId] == nil or table.concat(rec.recipes[profId], ",") ~= hash
    rec.recipes[profId] = ids
    rec.recipeStamp = Now()
    db.members[key] = rec
    if changed then
        Guild.Changed()
        if Guild.Setting("shareRecipes") and Guild.InGuild() then Share.SendRecipes(profId, ids) end
    end
    return true, profId, #ids
end

------------------------------------------------------------------------
-- Empfangen
------------------------------------------------------------------------

local function Member(key)
    local db = Guild.DB()
    local rec = db.members[key]
    if not rec then rec = {}; db.members[key] = rec end
    return rec
end

local function SendRecipesAll()
    local rec = Guild.DB().members[Guild.SelfKey() or ""]
    if not (rec and rec.recipes) then return end
    for profId, ids in pairs(rec.recipes) do Share.SendRecipes(profId, ids) end
end

function Share.OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" or Secret(text) or Secret(sender) then return end
    local key = Guild.Key(sender)
    if not key or key == Guild.SelfKey() then return end
    local kind = string.sub(text, 1, 1)
    local body = string.sub(text, 3)
    if string.sub(text, 2, 2) ~= "|" then return end
    if kind == "P" then
        local d = DecodeProfile(body)
        local rec = Member(key)
        rec.level, rec.xp, rec.xpmax = d.level, d.xp, d.xpmax
        rec.played = d.played or rec.played
        rec.race = d.race or rec.race
        rec.skills = d.skills
        rec.stamp = Now()
        rec.self = nil
        Guild.Changed()
    elseif kind == "C" then
        local prof, idx, n, csv = string.match(body, "^(%d+)|(%d+)|(%d+)|([%d,]*)$")
        prof, idx, n = tonumber(prof), tonumber(idx), tonumber(n)
        if not prof or not Guild.PROF[prof] or not idx or not n or n < 1 or n > 12 or idx < 1 or idx > n then return end
        local bk = key .. "|" .. prof
        local buf = rbuf[bk]
        if idx == 1 or not buf or buf.n ~= n then
            buf = { n = n, parts = {}, got = 0 }
            rbuf[bk] = buf
        end
        if not buf.parts[idx] then buf.got = buf.got + 1 end
        buf.parts[idx] = csv
        if buf.got == n then
            local ids = {}
            for i = 1, n do
                for id in string.gmatch(buf.parts[i] or "", "%d+") do
                    ids[#ids + 1] = tonumber(id)
                    if #ids >= MAX_RECIPES then break end
                end
            end
            rbuf[bk] = nil
            local rec = Member(key)
            rec.recipes = rec.recipes or {}
            rec.recipes[prof] = UniqueSorted(ids)
            rec.recipeStamp = Now()
            Guild.Changed()
        end
    elseif kind == "Q" then
        local wantRecipes = string.find(body, "r=1", 1, true) ~= nil
        local now = Clock()
        if Guild.Setting("shareProfile") and now - lastProfile >= 120 then
            lastProfile = now
            Share.After(3 + math.random() * 27, function() Share.SendProfile() end)
        end
        if wantRecipes and Guild.Setting("shareRecipes") and now - lastRecipes >= 600 then
            lastRecipes = now
            Share.After(8 + math.random() * 50, SendRecipesAll)
        end
        if Guild.IsOwnerName(sender) and Guild.Setting("shareGold") then
            Share.After(2 + math.random() * 8, function() Share.SendGold() end)
        end
    elseif kind == "G" then
        if channel ~= "WHISPER" or not Guild.IsOwner() or not Guild.rowByKey[key] then return end
        local copper = tonumber(body)
        if not copper or copper < 0 then return end
        local rec = Member(key)
        rec.gold = copper
        rec.goldStamp = Now()
        Guild.Changed()
    end
end

function Share.Request(withRecipes)
    if not Guild.InGuild() then return false end
    return Share.Queue("Q|" .. (withRecipes and "r=1" or "r=0"), "GUILD")
end

-- alles neu senden (Befehl /fwguild share)
function Share.SendAll(force)
    if force then lastProfile, lastRecipes, lastGold = -10000, -10000, -10000 end
    Share.SendProfile()
    SendRecipesAll()
    Share.SendGold()
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

local owner = {}

local function ScheduleScan() Share.scanAt = Clock() + 1.5 end
local function ScheduleDirty() Share.dirtyAt = Clock() + 2 end

function Share.Start()
    if Share.started then return end
    Share.started = true
    lastProfile, lastGold = Clock(), Clock()
    local api = G.C_ChatInfo
    if api and api.RegisterAddonMessagePrefix then
        pcall(api.RegisterAddonMessagePrefix, PREFIX)
    elseif G.RegisterAddonMessagePrefix then
        pcall(G.RegisterAddonMessagePrefix, PREFIX)
    end
    FW:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
        Share.OnMessage(prefix, text, channel, sender)
    end, owner)
    for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
        FW:RegisterEvent(ev, ScheduleScan, owner)
    end
    FW:RegisterEvent("PLAYER_XP_UPDATE", ScheduleDirty, owner)
    FW:RegisterEvent("PLAYER_LEVEL_UP", function()
        ScheduleDirty()
        Share.After(3, AskPlayed)
        Share.After(6, function() Share.SendProfile() end)
    end, owner)
    FW:RegisterEvent("TIME_PLAYED_MSG", function(_, total)
        if type(total) == "number" and not Secret(total) then
            played = { base = total, at = Clock() }
            ScheduleDirty()
        end
    end, owner)
    local function Skills()
        ScheduleDirty()
        Share.After(20, function() Share.SendProfile() end)
    end
    FW:RegisterEvent("SKILL_LINES_CHANGED", Skills, owner)
    FW:RegisterEvent("CHAT_MSG_SKILL", Skills, owner)
    -- beim Anmelden: Spielzeit abfragen, nach kurzer Zeit melden und die anderen um ihre Daten bitten
    Share.After(6, AskPlayed)
    Share.After(10 + math.random() * 10, function()
        Share.UpdateSelf()
        Share.SendProfile()
        Share.Request(true)
    end)
    Share.After(30, function() Share.SendGold() end)
end

function Share.Stop()
    Share.started = false
    FW:UnregisterEvent("CHAT_MSG_ADDON", owner)
    for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
        "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
        FW:UnregisterEvent(ev, owner)
    end
    Share.Reset()
end

local baseEnable, baseDisable = Guild.OnEnable, Guild.OnDisable
function Guild:OnEnable()
    if baseEnable then baseEnable(self) end
    Share.Start()
end
function Guild:OnDisable()
    Share.Stop()
    if baseDisable then baseDisable(self) end
end
