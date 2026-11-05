-- Freewood-Guild: Gildenauftraege und Anfragen (Datenhaltung und Abgleich).
-- Jeder Spieler mit dem Addon speichert die Eintraege der Gilde (7 Tage) und reicht fehlende im Hintergrund weiter.
-- Auftrag (k = "O"): Beruf und Rezept. Anfrage (k = "R"): Item oder Rezept. Beide haben Menge, Notiz und Materialliste
-- ("habe ich / habe ich nicht"). Loeschen duerfen der Ersteller, der Gildenleiter und Eigentuemer. Nach 7 Tagen verschwindet alles.
--
-- Nachrichten (ueber GuildShare):
--   O|<id>|<Teil>|<Teile>|<Text>      Eintrag in Stuecken
--   D|<id>:<rev>,<id>:<rev>,...       bekannte Eintraege (beim Anmelden und alle 15 Minuten)
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share then
    return
end

local G = _G
local Share = Guild.Share
local Board = {}
Guild.Board = Board

local DAY = 86400
local LIFETIME = 7 * DAY
local MAX_ENTRIES = 60
local MAX_NOTE = 60
local MAX_MATS = 6
local PIECE = 190
local MAX_PIECES = 4
local DIGEST_EVERY = 900
local RELAY_COOLDOWN = 600

local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end

local function Store()
    local db = Guild.DB()
    db.board = db.board or {}
    return db.board
end

------------------------------------------------------------------------
-- Kodierung
------------------------------------------------------------------------

local function Clean(text, max)
    text = tostring(text or "")
    text = string.gsub(text, "[;|%c]", " ")
    text = string.gsub(text, "|", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return string.sub(text, 1, max or 60)
end
Board.Clean = Clean

local function EncodeMats(mats)
    local out = {}
    for i, m in ipairs(mats or {}) do
        if i > MAX_MATS then break end
        out[#out + 1] = (tonumber(m.i) or 0) .. ":" .. (tonumber(m.n) or 1) .. ":" .. (m.h and 1 or 0)
    end
    return table.concat(out, ",")
end

local function DecodeMats(text)
    local out = {}
    for i, n, h in string.gmatch(text or "", "(%d+):(%d+):([01])") do
        if #out >= MAX_MATS then break end
        out[#out + 1] = { i = tonumber(i), n = tonumber(n), h = h == "1" }
    end
    return out
end

local function Split(text, sep)
    local out = {}
    local pos = 1
    while true do
        local a, b = string.find(text, sep, pos, true)
        if not a then
            out[#out + 1] = string.sub(text, pos)
            break
        end
        out[#out + 1] = string.sub(text, pos, a - 1)
        pos = b + 1
    end
    return out
end

-- Text: k;by;ts;rev;prof;tt;tid;qty;taker;done;del;note;mats
function Board.Encode(o)
    return table.concat({
        o.k or "O", Clean(o.by, 40), o.ts or 0, o.rev or 0, o.prof or 0, o.tt or "r", o.tid or 0, o.qty or 1,
        Clean(o.taker, 40), o.done and 1 or 0, o.del and 1 or 0, Clean(o.note, MAX_NOTE), EncodeMats(o.mats),
    }, ";")
end

function Board.Decode(id, text)
    local f = Split(text, ";")
    if #f < 13 then return nil end
    local k = f[1]
    if k ~= "O" and k ~= "R" then return nil end
    local o = {
        id = id, k = k, by = f[2], ts = tonumber(f[3]) or 0, rev = tonumber(f[4]) or 0, prof = tonumber(f[5]) or 0,
        tt = f[6] == "i" and "i" or "r", tid = tonumber(f[7]) or 0, qty = math.max(1, math.min(999, tonumber(f[8]) or 1)),
        taker = f[9] ~= "" and f[9] or nil, done = f[10] == "1", del = f[11] == "1", note = f[12], mats = DecodeMats(f[13]),
    }
    if o.by == "" or o.ts <= 0 then return nil end
    return o
end

------------------------------------------------------------------------
-- Zugriff
------------------------------------------------------------------------

function Board.Purge()
    local st = Store()
    local now = Now()
    local n = 0
    for id, o in pairs(st) do
        if (o.ts or 0) + LIFETIME < now then st[id] = nil; n = n + 1 end
    end
    -- zu viele Eintraege: aelteste zuerst weg
    local list = {}
    for id, o in pairs(st) do list[#list + 1] = { id = id, ts = o.ts or 0 } end
    if #list > MAX_ENTRIES then
        table.sort(list, function(a, b) return a.ts < b.ts end)
        for i = 1, #list - MAX_ENTRIES do st[list[i].id] = nil end
    end
    return n
end

-- kind: "O" oder "R"; Rueckgabe: nach Zeit absteigend, ohne geloeschte
function Board.List(kind)
    Board.Purge()
    local out = {}
    for _, o in pairs(Store()) do
        if o.k == kind and not o.del then out[#out + 1] = o end
    end
    table.sort(out, function(a, b)
        if (a.done and 1 or 0) ~= (b.done and 1 or 0) then return not a.done end
        return a.ts > b.ts
    end)
    return out
end

function Board.Get(id) return Store()[id] end

function Board.SelfName() return Guild.SelfName() end

local function IsMaster()
    local row = Guild.Row(Guild.SelfName() or "")
    return row ~= nil and row.rankIndex == 0
end

function Board.CanEdit(o)
    if not o then return false end
    if Guild.Key(o.by) == Guild.SelfKey() then return true end
    return IsMaster() or Guild.IsOwner()
end

function Board.MatsCount(o)
    local have, total = 0, 0
    for _, m in ipairs(o.mats or {}) do
        total = total + 1
        if m.h then have = have + 1 end
    end
    return have, total
end

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

function Board.SendOrder(o)
    local text = Board.Encode(o)
    local pieces = Share.Split(text, PIECE)
    if #pieces > MAX_PIECES then return false end
    for i, p in ipairs(pieces) do
        Share.Queue("O|" .. o.id .. "|" .. i .. "|" .. #pieces .. "|" .. p, "GUILD")
    end
    return true
end

local function NewID()
    return string.format("%x%x", math.random(0, 0xfffff), Now() % 0xfffff)
end

-- fields: k, prof, tt, tid, qty, note, mats
function Board.Create(fields)
    local name = Guild.SelfName()
    if not name or not Guild.InGuild() then return nil, "guild" end
    local o = {
        id = NewID(), k = fields.k == "R" and "R" or "O", by = Guild.Display(name), ts = Now(),
        prof = tonumber(fields.prof) or 0, tt = fields.tt == "i" and "i" or "r", tid = tonumber(fields.tid) or 0,
        qty = math.max(1, math.min(999, tonumber(fields.qty) or 1)), note = Clean(fields.note, MAX_NOTE), mats = {},
    }
    o.rev = o.ts
    for i, m in ipairs(fields.mats or {}) do
        if i > MAX_MATS then break end
        if tonumber(m.i) then o.mats[#o.mats + 1] = { i = tonumber(m.i), n = math.max(1, tonumber(m.n) or 1), h = m.h and true or false } end
    end
    if o.tid <= 0 then return nil, "target" end
    Store()[o.id] = o
    Board.SendOrder(o)
    Board.Changed()
    return o
end

function Board.Modify(id, change)
    local o = Store()[id]
    if not o then return false end
    change(o)
    o.rev = math.max(Now(), (o.rev or 0) + 1)
    Board.SendOrder(o)
    Board.Changed()
    return true
end

function Board.Delete(id)
    local o = Store()[id]
    if not o or not Board.CanEdit(o) then return false end
    return Board.Modify(id, function(e) e.del = true end)
end

function Board.SetDone(id, on)
    local o = Store()[id]
    if not o then return false end
    if not Board.CanEdit(o) and Guild.Key(o.taker or "") ~= Guild.SelfKey() then return false end
    return Board.Modify(id, function(e) e.done = on and true or false end)
end

function Board.Take(id)
    local o = Store()[id]
    local me = Guild.SelfName()
    if not o or not me or o.done then return false end
    local mine = Guild.Key(o.taker or "") == Guild.SelfKey()
    if o.taker and not mine and not Board.CanEdit(o) then return false end
    return Board.Modify(id, function(e) e.taker = (not mine) and Guild.Display(me) or nil end)
end

function Board.SetMat(id, index, have)
    local o = Store()[id]
    if not o or not Board.CanEdit(o) or not o.mats[index] then return false end
    return Board.Modify(id, function(e) e.mats[index].h = have and true or false end)
end

function Board.Changed()
    Guild.version = Guild.version + 1
    FW:Fire("GUILD_MODULE_BOARD")
end

------------------------------------------------------------------------
-- Abgleich
------------------------------------------------------------------------

local rbuf = {}
local heard = {}         -- [id:rev] = Uhrzeit, zu der der Eintrag zuletzt gehoert wurde
local relayed = {}       -- [id:rev] = Uhrzeit, zu der wir ihn zuletzt weitergegeben haben
local lastDigest = -10000

function Board.Accept(o, direct)
    if not o or (o.ts or 0) + LIFETIME < Now() then return false end
    local st = Store()
    local old = st[o.id]
    if old and (old.rev or 0) >= o.rev then return false end
    st[o.id] = o
    Board.Purge()
    Board.Changed()
    if not old and direct and not o.del and Now() - o.ts < 600 and Guild.Key(o.by) ~= Guild.SelfKey() and Guild.Setting("boardNotify") and Guild.Toast then
        local L = FW.L
        Guild.Toast(string.format(o.k == "O" and L.BOARD_NEW_ORDER or L.BOARD_NEW_REQUEST, o.by, Board.TargetName(o) or "?"))
    end
    return true
end

Share.handlers["O"] = function(key, body, channel, sender)
    local id, idx, n, chunk = string.match(body, "^(%x+)|(%d+)|(%d+)|(.*)$")
    idx, n = tonumber(idx), tonumber(n)
    if not id or #id > 12 or not idx or not n or n < 1 or n > MAX_PIECES or idx < 1 or idx > n then return end
    local bk = key .. "|" .. id
    local buf = rbuf[bk]
    if idx == 1 or not buf or buf.n ~= n then buf = { n = n, parts = {}, got = 0 }; rbuf[bk] = buf end
    if not buf.parts[idx] then buf.got = buf.got + 1 end
    buf.parts[idx] = chunk
    if buf.got == n then
        rbuf[bk] = nil
        local o = Board.Decode(id, table.concat(buf.parts))
        if o then
            heard[id .. ":" .. o.rev] = Clock()
            Board.Accept(o, true)
        end
    end
end

Share.handlers["D"] = function(key, body, channel, sender)
    local theirs = {}
    for id, rev in string.gmatch(body, "(%x+):(%d+)") do theirs[id] = tonumber(rev) end
    for id, o in pairs(Store()) do
        local tr = theirs[id]
        if (not tr or tr < (o.rev or 0)) and (o.ts or 0) + LIFETIME > Now() then
            local hk = id .. ":" .. (o.rev or 0)
            if not relayed[hk] or Clock() - relayed[hk] > RELAY_COOLDOWN then
                local scheduled = Clock()
                Share.After(4 + math.random() * 36, function()
                    local h = heard[hk]
                    if h and h >= scheduled then return end      -- inzwischen hat es jemand anders gesendet
                    local cur = Store()[id]
                    if cur and cur.rev == o.rev then
                        relayed[hk] = Clock()
                        Board.SendOrder(cur)
                    end
                end)
            end
        end
    end
end

function Board.SendDigest()
    lastDigest = Clock()
    if not Guild.InGuild() then return false end
    Board.Purge()
    local parts, cur = {}, {}
    for id, o in pairs(Store()) do
        cur[#cur + 1] = id .. ":" .. (o.rev or 0)
        if #cur >= 9 then parts[#parts + 1] = table.concat(cur, ","); cur = {} end
    end
    if #cur > 0 or #parts == 0 then parts[#parts + 1] = table.concat(cur, ",") end
    for _, p in ipairs(parts) do Share.Queue("D|" .. p, "GUILD") end
    return true
end

table.insert(Share.startHooks, function() Share.After(12 + math.random() * 10, Board.SendDigest) end)
table.insert(Share.requestHooks, function() Share.After(6 + math.random() * 20, Board.SendDigest) end)
table.insert(Share.sendAllHooks, Board.SendDigest)

-- alle 15 Minuten
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 30 then return end
    acc = 0
    if Share.started and Clock() - lastDigest >= DIGEST_EVERY then Board.SendDigest() end
end)

------------------------------------------------------------------------
-- Namen: Rezepte, Items, Materialien
------------------------------------------------------------------------

local function Seed()
    local c = FW.Codex
    if c and c.Seed and c.Seed.Load then pcall(c.Seed.Load) end
    return G.FreewoodCodexSeed
end

function Board.ItemName(id)
    id = tonumber(id)
    if not id then return nil end
    local c = FW.Codex
    if c and c.ItemName then
        local ok, n = pcall(c.ItemName, c, id)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    local S = Seed()
    if S then
        local de = G.GetLocale and G.GetLocale() == "deDE"
        local n = de and (S.id and S.id[id] or S.ie and S.ie[id]) or (S.ie and S.ie[id] or S.id and S.id[id])
        if n then return n end
    end
    if G.C_Item and G.C_Item.GetItemNameByID then
        local ok, n = pcall(G.C_Item.GetItemNameByID, id)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    return nil
end

function Board.TargetName(o)
    if o.tt == "i" then return Board.ItemName(o.tid) or ("#" .. o.tid) end
    return (Guild.SpellName and Guild.SpellName(o.tid)) or ("#" .. o.tid)
end

-- Item-Suche in den Namenslisten von CodexData. Rueckgabe: { {id, name}, ... }
function Board.SearchItems(query, limit)
    local out = {}
    query = string.lower(tostring(query or ""))
    if #query < 3 then return out end
    local S = Seed()
    if not S then return out end
    limit = limit or 8
    local seen = {}
    local de = G.GetLocale and G.GetLocale() == "deDE"
    local tables = de and { S.id, S.ie } or { S.ie, S.id }
    for _, t in ipairs(tables) do
        if type(t) == "table" then
            for id, name in pairs(t) do
                if not seen[id] and type(name) == "string" and string.find(string.lower(name), query, 1, true) then
                    seen[id] = true
                    out[#out + 1] = { id = id, name = name }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local la, lb = #a.name, #b.name
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    local cut = {}
    for i = 1, math.min(limit, #out) do cut[i] = out[i] end
    return cut
end

-- Rezepte eines Berufs, die irgendein Gildenmitglied kennt (Name aus dem Spiel). Rueckgabe: { {id, name}, ... }
function Board.RecipesFor(profId, query)
    local out, seen = {}, {}
    query = string.lower(tostring(query or ""))
    for _, rec in pairs(Guild.DB().members) do
        local ids = rec.recipes and rec.recipes[profId]
        if ids then
            for _, id in ipairs(ids) do
                if not seen[id] then
                    seen[id] = true
                    local name = Guild.SpellName and Guild.SpellName(id)
                    if name and (query == "" or string.find(string.lower(name), query, 1, true)) then
                        out[#out + 1] = { id = id, name = name }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Materialien eines Rezepts aus der Rezeptliste des Codex (gelernt beim Oeffnen der Berufsfenster)
function Board.MatsFor(recipeName)
    local c = FW.Codex
    local store = c and c.db and c.db.recipes
    if type(store) ~= "table" or not recipeName then return nil end
    for _, prof in pairs(store) do
        local rec = prof[recipeName]
        if type(rec) == "table" and type(rec.rg) == "table" then
            local mats = {}
            for item, count in pairs(rec.rg) do
                if tonumber(item) and #mats < MAX_MATS then mats[#mats + 1] = { i = tonumber(item), n = tonumber(count) or 1, h = false } end
            end
            table.sort(mats, function(a, b) return a.i < b.i end)
            return mats
        end
    end
    return nil
end

function Board.AgeText(o)
    local days = math.floor((Now() - (o.ts or 0)) / DAY)
    local left = math.max(0, 7 - days)
    return days <= 0 and FW.L.BOARD_TODAY or string.format(FW.L.BOARD_DAYS, days), left
end
