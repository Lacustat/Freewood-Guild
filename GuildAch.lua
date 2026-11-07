-- Freewood-Guild: Gildenerfolge. Die Gilde sammelt Punkte, zum Beispiel wenn mindestens 3 Gildenmitglieder
-- in einer Gruppe einen Dungeon besiegen. Jeder Spieler zaehlt nur seine eigene Beteiligung (Art "E");
-- die Gilde ergibt sich aus der Summe aller Mitglieder. UNGEPRUEFT im Spiel.
--
-- Inhalt
--   1. Zaehlen (Gruppe, Bosskills)   2. Teilen (Art "E")   3. Katalog   4. Auswertung   5. Benachrichtigung

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share or not Guild.Inst then
    return
end

local G = _G
local Share, Inst = Guild.Share, Guild.Inst
local Ach = {}
Guild.Ach = Ach

local function Secret(v) return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false end
local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end

Ach.TIERS = { 3, 5, 10, 20 }     -- Gildenmitglieder in der Gruppe

------------------------------------------------------------------------
-- Speicher: members[key].g = { k = { [3]=n, [5]=n, [10]=n, [20]=n }, cl = { [Instanz] = { [3]=ts, [5]=ts ... } } }
-- Eigene Erfolgsdaten der Gilde: db.ach = { done = { [id] = ts }, log = { {id, ts} }, init = true }
------------------------------------------------------------------------

function Ach.Db()
    local db = Guild.DB()
    db.ach = db.ach or {}
    db.ach.done = db.ach.done or {}
    db.ach.log = db.ach.log or {}
    return db.ach
end

local function GRec(key, create)
    local m = Guild.DB().members
    local r = m[key]
    if not r then
        if not create then return nil end
        r = {}
        m[key] = r
    end
    if not r.g then
        if not create then return nil end
        r.g = { k = {}, cl = {} }
    end
    r.g.k = r.g.k or {}
    r.g.cl = r.g.cl or {}
    return r.g
end

------------------------------------------------------------------------
-- 1. Zaehlen
------------------------------------------------------------------------

-- Letzter Boss (jeder Eintrag zaehlt als "bezwungen"); Standard ist der letzte Boss der Liste
Ach.FINAL = {
    SM = { "Herod", "Scarlet Commander Mograine", "High Inquisitor Whitemane" },
    DME = { "King Gordok", "Prince Tortheldrin", "Immol'thar" },
    STRAT = { "Baron Rivendare", "Balnazzar" },
}
Ach.RAIDS = { ONY = true, MC = true, BWL = true, ZG = true, AQ20 = true, AQ40 = true, NAXX = true }

function Ach.IsFinal(e, boss)
    if not e or not boss then return false end
    local list = Ach.FINAL[e.id]
    if list then
        for _, b in ipairs(list) do if string.lower(b) == string.lower(boss) then return true end end
        return false
    end
    local last = e.bosses and e.bosses[#e.bosses]
    return last ~= nil and string.lower(last) == string.lower(boss)
end

-- Wie viele Gildenmitglieder (mit mir) sind in meiner Gruppe? Erkennung ueber die Spieler-ID (GUID) aus der Gildenliste,
-- ersatzweise ueber den Namen.
function Ach.GroupGuildCount()
    local count = 1
    local guids, byKey = {}, Guild.rowByKey or {}
    for _, row in ipairs(Guild.rows or {}) do
        if row.guid then guids[row.guid] = true end
    end
    local units = {}
    local inRaid = G.IsInRaid and G.IsInRaid()
    local total = G.GetNumGroupMembers and tonumber(G.GetNumGroupMembers()) or 0
    if inRaid then
        for i = 1, math.max(total, 1) do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    for _, unit in ipairs(units) do
        if G.UnitExists and G.UnitExists(unit) and not (G.UnitIsUnit and G.UnitIsUnit(unit, "player")) then
            local match = false
            local guid = G.UnitGUID and G.UnitGUID(unit)
            if type(guid) == "string" and not Secret(guid) and guids[guid] then match = true end
            if not match then
                local names = {}
                if G.UnitFullName then
                    local ok, n, second = pcall(G.UnitFullName, unit)
                    if ok and type(n) == "string" then
                        names[#names + 1] = n
                        if type(second) == "string" and second ~= "" then names[#names + 1] = n .. " " .. second end
                    end
                end
                if G.GetUnitName then
                    local ok, n = pcall(G.GetUnitName, unit, true)
                    if ok and type(n) == "string" then names[#names + 1] = n end
                end
                for _, n in ipairs(names) do
                    if not Secret(n) then
                        local key = Guild.Key(n)
                        if key and byKey[key] then match = true break end
                    end
                end
            end
            if match then count = count + 1 end
        end
    end
    return count
end

local lastKill = {}

-- Ein Boss wurde besiegt (eigene Gruppe). n = Gildenmitglieder in der Gruppe einschliesslich mir.
function Ach.RecordKill(instName, bossName, n)
    if Secret(instName) or Secret(bossName) or type(bossName) ~= "string" or bossName == "" then return false end
    local e, boss = Inst.Canon(instName, bossName)
    local id = e and e.id or ("*" .. (type(instName) == "string" and instName or "?"))
    local dedupe = id .. "|" .. tostring(boss)
    if lastKill[dedupe] and Clock() - lastKill[dedupe] < 120 then return false end
    lastKill[dedupe] = Clock()
    local me = Guild.SelfKey()
    if not me then return false end
    n = tonumber(n) or Ach.GroupGuildCount()
    local g = GRec(me, true)
    local ts = Now()
    local changed = false
    for _, t in ipairs(Ach.TIERS) do
        if n >= t then
            g.k[t] = (g.k[t] or 0) + 1
            changed = true
            if e and Ach.IsFinal(e, boss) then
                g.cl[e.id] = g.cl[e.id] or {}
                if not g.cl[e.id][t] then g.cl[e.id][t] = ts end
            end
        end
    end
    if changed then
        FW:Fire("GUILD_MODULE_INST")
        Ach.ScheduleSend()
    end
    return changed
end

------------------------------------------------------------------------
-- 2. Teilen: E|<Teil>|<Teile>|<Text>, Text = "k3,k5,k10,k20;ID^3=ts,5=ts#ID2^..."
------------------------------------------------------------------------

local MAX_PIECES = 6
local rbuf = {}

function Ach.Encode(key)
    local g = GRec(key, false)
    if not g then return "" end
    local head = {}
    for _, t in ipairs(Ach.TIERS) do head[#head + 1] = tostring(g.k[t] or 0) end
    local ids = {}
    for id in pairs(g.cl) do ids[#ids + 1] = id end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do
        local tiers = {}
        for _, t in ipairs(Ach.TIERS) do
            if g.cl[id][t] then tiers[#tiers + 1] = t .. "=" .. g.cl[id][t] end
        end
        if #tiers > 0 and string.sub(id, 1, 1) ~= "*" then parts[#parts + 1] = id .. "^" .. table.concat(tiers, ",") end
    end
    return table.concat(head, ",") .. ";" .. table.concat(parts, "#")
end

function Ach.Decode(text)
    local out = { k = {}, cl = {} }
    local head, rest = string.match(text or "", "^([%d,]*);(.*)$")
    if not head then return nil end
    local i = 0
    for n in string.gmatch(head, "%d+") do
        i = i + 1
        if Ach.TIERS[i] then out.k[Ach.TIERS[i]] = math.min(tonumber(n) or 0, 100000) end
    end
    for chunk in string.gmatch(rest, "[^#]+") do
        local id, body = string.match(chunk, "^([%w]+)%^(.*)$")
        if id and Inst.Get(id) then
            for t, ts in string.gmatch(body, "(%d+)=(%d+)") do
                t = tonumber(t)
                for _, ok in ipairs(Ach.TIERS) do
                    if ok == t then
                        out.cl[id] = out.cl[id] or {}
                        out.cl[id][t] = tonumber(ts)
                    end
                end
            end
        end
    end
    return out
end

function Ach.Send()
    if not Guild.InGuild() then return false end
    local me = Guild.SelfKey()
    if not me then return false end
    local text = Ach.Encode(me)
    Ach.lastSend = Clock()
    if text == "" or text == "0,0,0,0;" then return false end
    local pieces = Share.Split(text, 190)
    if #pieces > MAX_PIECES then return false end
    for i, p in ipairs(pieces) do
        Share.Queue(string.format("E|%d|%d|%s", i, #pieces, p), "GUILD")
    end
    return true
end

function Ach.ScheduleSend()
    if Ach.sendPending then return end
    Ach.sendPending = true
    Share.After(20, function() Ach.sendPending = false; Ach.Send() end)
end

Share.handlers["E"] = function(key, body)
    local idx, n, chunk = string.match(body, "^(%d+)|(%d+)|(.*)$")
    idx, n = tonumber(idx), tonumber(n)
    if not idx or not n or n < 1 or n > MAX_PIECES or idx < 1 or idx > n then return end
    local buf = rbuf[key]
    if idx == 1 or not buf or buf.n ~= n then buf = { n = n, parts = {}, got = 0 }; rbuf[key] = buf end
    if not buf.parts[idx] then buf.got = buf.got + 1 end
    buf.parts[idx] = chunk
    if buf.got == n then
        rbuf[key] = nil
        local g = Ach.Decode(table.concat(buf.parts))
        if g then
            local rec = Guild.DB().members[key] or {}
            Guild.DB().members[key] = rec
            rec.g = g
            Ach.Changed()
        end
    end
end

table.insert(Share.startHooks, function() Share.After(50 + math.random() * 20, Ach.Send) end)
table.insert(Share.requestHooks, function() Share.After(12 + math.random() * 30, Ach.Send) end)
table.insert(Share.sendAllHooks, Ach.Send)

------------------------------------------------------------------------
-- 3. Katalog
------------------------------------------------------------------------

local DUNGEONS = {
    { "RFC", 10 }, { "WC", 10 }, { "DM", 10 }, { "SFK", 10 }, { "BFD", 10 }, { "STOCK", 10 }, { "GNOM", 10 },
    { "RFK", 15 }, { "SM", 15 }, { "RFD", 15 }, { "ULD", 15 }, { "ZF", 15 }, { "MARA", 15 }, { "ST", 15 },
    { "BRD", 20 }, { "LBRS", 20 }, { "UBRS", 20 }, { "DME", 20 }, { "STRAT", 20 }, { "SCHOLO", 20 },
}
local RAIDS = { { "ONY", 25 }, { "ZG", 25 }, { "AQ20", 25 }, { "MC", 30 }, { "BWL", 35 }, { "AQ40", 40 }, { "NAXX", 50 } }
local BIG_RAIDS = { ONY = true, MC = true, BWL = true, AQ40 = true, NAXX = true }

Ach.CATEGORIES = {
    { "dungeon", "INV_Misc_Key_03" }, { "raid", "INV_Misc_Head_Dragon_01" }, { "bosses", "INV_Misc_Bone_HumanSkull_01" },
    { "cover", "INV_Misc_Book_09" }, { "members", "INV_Shirt_GuildTabard_01" }, { "levels", "Ability_Rogue_Sprint" },
    { "profs", "INV_Hammer_20" }, { "recipes", "INV_Scroll_03" }, { "time", "INV_Misc_PocketWatch_01" }, { "variety", "INV_Misc_Eye_01" },
}

local catalog
function Ach.Catalog()
    if catalog then return catalog end
    local list = {}
    local function Add(cat, id, pts, name, desc, calc)
        list[#list + 1] = { id = id, cat = cat, pts = pts, name = name, desc = desc, calc = calc }
    end

    -- Dungeons und Schlachtzuege: Gruppe mit Gildenmitgliedern, letzter Boss
    local function Clear(instId, tier)
        return function(ctx)
            local best, ts, who = 0, nil, {}
            for _, m in ipairs(ctx.members) do
                local cl = m.g and m.g.cl[instId]
                if cl then
                    for _, t in ipairs(Ach.TIERS) do
                        if cl[t] and t >= tier then
                            who[#who + 1] = m.name
                            if not ts or cl[t] < ts then ts = cl[t] end
                            break
                        end
                    end
                    for _, t in ipairs(Ach.TIERS) do if cl[t] and t > best then best = t end end
                end
            end
            local done = #who > 0
            return done and tier or math.min(best, tier - 1), tier, done and ts or nil, who
        end
    end
    for _, d in ipairs(DUNGEONS) do
        Add("dungeon", "D3_" .. d[1], d[2], { "A_DUNG3", { inst = d[1] } }, { "A_DUNG3_D", { inst = d[1] } }, Clear(d[1], 3))
        Add("dungeon", "D5_" .. d[1], d[2] + 5, { "A_DUNG5", { inst = d[1] } }, { "A_DUNG5_D", { inst = d[1] } }, Clear(d[1], 5))
    end
    for _, r in ipairs(RAIDS) do
        Add("raid", "R10_" .. r[1], r[2], { "A_RAID10", { inst = r[1] } }, { "A_RAID10_D", { inst = r[1] } }, Clear(r[1], 10))
        if BIG_RAIDS[r[1]] then
            Add("raid", "R20_" .. r[1], r[2] + 15, { "A_RAID20", { inst = r[1] } }, { "A_RAID20_D", { inst = r[1] } }, Clear(r[1], 20))
        end
    end

    -- Boss-Zaehler (alle Mitglieder zusammen)
    local function Sum(tier)
        return function(ctx)
            local s = 0
            for _, m in ipairs(ctx.members) do s = s + ((m.g and m.g.k[tier]) or 0) end
            return s
        end
    end
    local k3 = Sum(3)
    for i, n in ipairs({ 10, 50, 100, 250, 500, 1000 }) do
        local goal = n
        Add("bosses", "K3_" .. n, ({ 5, 10, 15, 20, 30, 50 })[i], { "A_K3", { n } }, { "A_K3_D", { n } },
            function(ctx) return k3(ctx), goal end)
    end
    local k10 = Sum(10)
    for i, n in ipairs({ 5, 25, 50, 100 }) do
        local goal = n
        Add("bosses", "K10_" .. n, ({ 10, 20, 30, 50 })[i], { "A_K10", { n } }, { "A_K10_D", { n } },
            function(ctx) return k10(ctx), goal end)
    end

    -- Gildenwissen: alle Bosse einer Instanz irgendwann von jemandem besiegt
    local function Cover(instId)
        return function(ctx)
            local e = Inst.Get(instId)
            if not e then return 0, 1 end
            local n = 0
            for _, boss in ipairs(e.bosses) do
                if ctx.kills[instId] and ctx.kills[instId][boss] then n = n + 1 end
            end
            return n, #e.bosses
        end
    end
    for _, d in ipairs(DUNGEONS) do
        Add("cover", "C_" .. d[1], 5, { "A_COVER", { inst = d[1] } }, { "A_COVER_D", { inst = d[1] } }, Cover(d[1]))
    end
    for _, r in ipairs(RAIDS) do
        Add("cover", "C_" .. r[1], 10, { "A_COVER", { inst = r[1] } }, { "A_COVER_D", { inst = r[1] } }, Cover(r[1]))
    end

    -- Mitglieder
    for i, n in ipairs({ 10, 25, 50, 75, 100, 150, 200 }) do
        local goal = n
        Add("members", "M_" .. n, 5 + i * 5, { "A_MEM", { n } }, { "A_MEM_D", { n } }, function(ctx) return ctx.count, goal end)
    end
    for i, n in ipairs({ 5, 10, 25, 50 }) do
        local goal = n
        Add("members", "U_" .. n, 5 + i * 5, { "A_USERS", { n } }, { "A_USERS_D", { n } }, function(ctx) return ctx.users, goal end)
    end
    for i, n in ipairs({ 10, 20 }) do
        local goal = n
        Add("members", "O_" .. n, 10 + i * 10, { "A_ONLINE", { n } }, { "A_ONLINE_D", { n } }, function(ctx) return ctx.online, goal end)
    end

    -- Stufen
    for i, n in ipairs({ 10, 20, 30, 40, 50, 60 }) do
        local goal = n
        Add("levels", "L_" .. n, ({ 5, 5, 10, 10, 15, 25 })[i], { "A_LVL", { n } }, { "A_LVL_D", { n } },
            function(ctx) return ctx.maxLevel, goal end)
    end
    for i, n in ipairs({ 3, 5, 10, 25 }) do
        local goal = n
        Add("levels", "L60_" .. n, ({ 20, 30, 50, 75 })[i], { "A_LVL60", { n } }, { "A_LVL60_D", { n } },
            function(ctx) return ctx.at60, goal end)
    end
    for i, n in ipairs({ 250, 500, 1000, 2500, 5000 }) do
        local goal = n
        Add("levels", "LS_" .. n, ({ 5, 10, 15, 25, 40 })[i], { "A_LVSUM", { n } }, { "A_LVSUM_D", { n } },
            function(ctx) return ctx.levelSum, goal end)
    end

    -- Berufe
    local profIds = {}
    for id in pairs(Guild.PROF or {}) do profIds[#profIds + 1] = id end
    table.sort(profIds)
    for _, id in ipairs(profIds) do
        local pid = id
        Add("profs", "P_" .. id, 10, { "A_PROF", { prof = id } }, { "A_PROF_D", { prof = id } }, function(ctx)
            local who = ctx.master[pid]
            return who and #who > 0 and 1 or 0, 1, nil, who
        end)
    end
    Add("profs", "P_ALL", 25, { "A_PROFALL" }, { "A_PROFALL_D" }, function(ctx)
        local n, total = 0, 0
        for _, id in ipairs(profIds) do total = total + 1; if ctx.skilled[id] then n = n + 1 end end
        return n, math.max(total, 1)
    end)
    for i, n in ipairs({ 3, 5, 10, 20 }) do
        local goal = n
        Add("profs", "PM_" .. n, 5 + i * 5, { "A_MASTERS", { n } }, { "A_MASTERS_D", { n } }, function(ctx) return ctx.masters, goal end)
    end

    -- Rezepte
    for i, n in ipairs({ 100, 250, 500, 1000, 2500 }) do
        local goal = n
        Add("recipes", "RC_" .. n, 5 + i * 5, { "A_RECIPES", { n } }, { "A_RECIPES_D", { n } }, function(ctx) return ctx.recipes, goal end)
    end

    -- Zeit
    for i, n in ipairs({ 100, 500, 1000, 2500, 5000, 10000, 25000 }) do
        local goal = n
        Add("time", "T_" .. n, 5 + i * 5, { "A_TIME", { n } }, { "A_TIME_D", { n } }, function(ctx) return math.floor(ctx.hours), goal end)
    end

    -- Vielfalt
    for i, n in ipairs({ 3, 5, 7, 9 }) do
        local goal = n
        Add("variety", "V_C" .. n, 5 + i * 5, { "A_CLASSES", { n } }, { "A_CLASSES_D", { n } }, function(ctx) return ctx.classes, goal end)
    end
    for i, n in ipairs({ 3, 5, 8 }) do
        local goal = n
        Add("variety", "V_R" .. n, 5 + i * 5, { "A_RACES", { n } }, { "A_RACES_D", { n } }, function(ctx) return ctx.races, goal end)
    end

    catalog = list
    return list
end

-- Text eines Eintrags ({ Schluessel, Argumente })
function Ach.Text(spec)
    local L = FW.L
    local args = {}
    for i, a in ipairs(spec[2] or {}) do args[i] = a end
    local a = spec[2]
    if a and a.inst then args = { Inst.DisplayName(Inst.Get(a.inst) or a.inst) } end
    if a and a.prof then args = { Guild.ProfName(a.prof) } end
    local fmt = L[spec[1]] or spec[1]
    local ok, s = pcall(string.format, fmt, unpack(args))
    return ok and s or fmt
end

------------------------------------------------------------------------
-- 4. Auswertung
------------------------------------------------------------------------

-- Alle Zahlen, aus denen die Erfolge bestehen. Nur Mitglieder der Gilde (laut Gildenliste) zaehlen.
function Ach.Context()
    local ctx = { members = {}, kills = {}, master = {}, skilled = {}, count = 0, users = 0, online = 0, maxLevel = 0,
        at60 = 0, levelSum = 0, masters = 0, recipes = 0, hours = 0, classes = 0, races = 0 }
    local db = Guild.DB()
    local classSet, raceSet, recipeSet = {}, {}, {}
    for _, row in ipairs(Guild.rows or {}) do
        ctx.count = ctx.count + 1
        if row.online then ctx.online = ctx.online + 1 end
        local lv = tonumber(row.level) or 0
        local rec = db.members[row.key]
        if rec and tonumber(rec.level) and tonumber(rec.level) > lv then lv = tonumber(rec.level) end
        ctx.levelSum = ctx.levelSum + lv
        if lv > ctx.maxLevel then ctx.maxLevel = lv end
        if lv >= 60 then ctx.at60 = ctx.at60 + 1 end
        if row.class and row.class ~= "" then classSet[row.class] = true end
        if row.race and row.race ~= "" then raceSet[row.race] = true end
        local name = row.name or row.key
        ctx.members[#ctx.members + 1] = { key = row.key, name = name, g = rec and rec.g or nil }
        if rec then
            if rec.stamp or rec.level or rec.skills then ctx.users = ctx.users + 1 end
            ctx.hours = ctx.hours + (tonumber(rec.played) or 0) / 3600
            local isMaster = false
            for id, s in pairs(rec.skills or {}) do
                if type(s) == "table" then
                    ctx.skilled[id] = true
                    if (tonumber(s.rank) or 0) >= 300 then
                        ctx.master[id] = ctx.master[id] or {}
                        table.insert(ctx.master[id], name)
                        isMaster = true
                    end
                end
            end
            if isMaster then ctx.masters = ctx.masters + 1 end
            for _, ids in pairs(rec.recipes or {}) do
                for _, rid in ipairs(ids) do recipeSet[rid] = true end
            end
            for instId, bosses in pairs(rec.kills or {}) do
                ctx.kills[instId] = ctx.kills[instId] or {}
                for boss in pairs(bosses) do ctx.kills[instId][boss] = true end
            end
        end
    end
    for _ in pairs(classSet) do ctx.classes = ctx.classes + 1 end
    for _ in pairs(raceSet) do ctx.races = ctx.races + 1 end
    for _ in pairs(recipeSet) do ctx.recipes = ctx.recipes + 1 end
    return ctx
end

-- Ergebnis je Erfolg: { entry, cur, goal, done, ts, who }
function Ach.Evaluate(ctx)
    ctx = ctx or Ach.Context()
    local db = Ach.Db()
    local out = {}
    for _, e in ipairs(Ach.Catalog()) do
        local cur, goal, ts, who = e.calc(ctx)
        cur, goal = tonumber(cur) or 0, tonumber(goal) or 1
        local done = cur >= goal
        if done then ts = ts or db.done[e.id] end
        out[#out + 1] = { entry = e, cur = math.min(cur, goal), goal = goal, done = done, ts = ts, who = who }
    end
    return out
end

function Ach.Points(results)
    local got, total, n, done = 0, 0, 0, 0
    for _, r in ipairs(results or {}) do
        total = total + r.entry.pts
        n = n + 1
        if r.done then got = got + r.entry.pts; done = done + 1 end
    end
    return got, total, done, n
end

------------------------------------------------------------------------
-- 5. Neue Erfolge erkennen und melden
------------------------------------------------------------------------

Ach.queue = {}
local startedAt = nil

function Ach.Changed()
    if Ach.checkPending then return end
    Ach.checkPending = true
    Share.After(4, function() Ach.checkPending = false; pcall(Ach.Check) end)
    FW:Fire("GUILD_MODULE_ACH")
end

-- Vergleicht mit dem Gemerkten. Die ersten 120 Sekunden nach dem Anmelden (Daten treffen erst ein) und
-- alles Aeltere als 15 Minuten werden still als erreicht vermerkt.
function Ach.Check()
    if #(Guild.rows or {}) == 0 then return {} end
    local db = Ach.Db()
    local results = Ach.Evaluate()
    local fresh = {}
    local quiet = db.init ~= true or (startedAt and Clock() - startedAt < 120)
    local now = Now()
    for _, r in ipairs(results) do
        if r.done and not db.done[r.entry.id] then
            local ts = r.ts or now
            db.done[r.entry.id] = ts
            db.log[#db.log + 1] = { r.entry.id, ts }
            while #db.log > 60 do table.remove(db.log, 1) end
            if not quiet and now - ts < 900 then fresh[#fresh + 1] = r.entry end
        end
    end
    if startedAt and Clock() - startedAt >= 120 then db.init = true end
    if #fresh > 0 and Guild.Setting("achNotify") and Ach.Notify then
        for _, e in ipairs(fresh) do Ach.Notify(e) end
    end
    return fresh
end

table.insert(Share.startHooks, function()
    startedAt = Clock()
    Share.After(130, function() pcall(Ach.Check) end)
    local owner = {}
    local function Kill(_, _, name)
        local instName
        if G.GetInstanceInfo then
            local ok, n = pcall(G.GetInstanceInfo)
            if ok and type(n) == "string" and not Secret(n) then instName = n end
        end
        pcall(Ach.RecordKill, instName, name)
    end
    FW:RegisterEvent("ENCOUNTER_END", function(_, id, name, difficulty, size, success)
        if success == 1 or success == true then Kill(nil, id, name) end
    end, owner)
    FW:RegisterEvent("BOSS_KILL", Kill, owner)
end)

FW:On("GUILD_MODULE_DATA", function() Ach.Changed() end)
FW:On("GUILD_MODULE_ROSTER", function() Ach.Changed() end)
FW:On("GUILD_MODULE_INST", function() Ach.Changed() end)
