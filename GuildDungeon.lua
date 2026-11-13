-- Freewood-Guild: Dungeon-Browser (Logik). Lauscht bei der Gruppensuche des Spiels mit (C_LFGList), meldet der Gilde, wer wofuer
-- sucht (versteckte Nachricht fuer Freewood-Nutzer, auf Wunsch eine Zeile im Gildenchat), schlaegt Gruppen vor und kann
-- Einladungen von Gildenmitgliedern/Freunden bei laufender Suche annehmen. Alles UNGEPRUEFT im Spiel; die Grundlagen
-- (Funktionen, Ereignisse, lesbare Werte) stammen aus der Probe /fwlfg in Freewood-Dev 0.13.5 bis 0.13.8.
--
-- Nachricht (Praefix FWGuild1, Gilde):
--   L|r=TH;n=1;h=0.0.1;a=799,800;t=Todesminen   Suche: Rollen (T Tank, H Heiler, D Schaden), Mitglieder, vorhanden T.H.D, Aktivitaeten, Name
--   L|x                                         Suche beendet
--
-- Inhalt: Hilfen, Lesen, Senden, Empfangen, Vorschlag, Einladungen, Ablauf

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share then
    return
end

local G = _G
local Share = Guild.Share
local Dung = {}
Guild.Dungeon = Dung

local TTL = 900            -- Sekunden, nach denen eine Suche ohne neue Meldung verschwindet
local RESEND = 120         -- Sekunden zwischen zwei Meldungen bei laufender Suche
local CHAT_GAP = 60        -- Sekunden Mindestabstand zwischen zwei Zeilen im Gildenchat
local ROLE_ORDER = { "T", "H", "D" }

local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Now() return G.time and G.time() or 0 end
local function Secret(v) return Guild.Secret(v) end
function Dung.NowClock() return Clock() end

Dung.list = {}      -- [Schluessel] = { name, key, roles = {T=,H=,D=}, size, have = {T,H,D}, ids, label, since, at, self }
Dung.mine = nil     -- eigener Stand: { roles, size, have, ids, label, sig }
Dung.lastChat = {}  -- [Signatur] = Uhrzeit

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

local function Clean(s)
    return (string.gsub(tostring(s or ""), "[|;=\n\r]", " "))
end

function Dung.RoleString(roles)
    local out = ""
    for _, r in ipairs(ROLE_ORDER) do
        if roles and roles[r] then out = out .. r end
    end
    return out
end

local function ParseRoles(s)
    local roles = {}
    for r in string.gmatch(s or "", "[THD]") do roles[r] = true end
    return roles
end

function Dung.RoleWords(roles)
    local L = FW.L
    local out = {}
    if roles.T then out[#out + 1] = L.DUNG_ROLE_T end
    if roles.H then out[#out + 1] = L.DUNG_ROLE_H end
    if roles.D then out[#out + 1] = L.DUNG_ROLE_D end
    return table.concat(out, "/")
end

------------------------------------------------------------------------
-- Eigenen Stand lesen
------------------------------------------------------------------------

local function ActivityLabel(id)
    local C = G.C_LFGList
    if C and C.GetActivityFullName then
        local ok, n = pcall(C.GetActivityFullName, id)
        if ok and type(n) == "string" and not Secret(n) and n ~= "" then return n end
    end
    if C and C.GetActivityInfoTable then
        local ok, t = pcall(C.GetActivityInfoTable, id)
        if ok and type(t) == "table" and not Secret(t) then
            local n = t.fullName or t.shortName or t.name
            if type(n) == "string" and not Secret(n) and n ~= "" then return n end
        end
    end
    return "#" .. tostring(id)
end

function Dung.LabelFor(ids)
    if type(ids) ~= "table" or #ids == 0 then return "?" end
    local seen, names = {}, {}
    for _, id in ipairs(ids) do
        local n = ActivityLabel(id)
        if not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    local label = names[1]
    if #names > 1 then label = label .. " (+" .. (#names - 1) .. ")" end
    return label
end

-- Rollen der Gruppe: Zaehler T, H, D (ohne Rolle zaehlt nicht)
function Dung.GroupHave()
    local have = { T = 0, H = 0, D = 0 }
    local size = 1
    if G.IsInGroup and G.IsInGroup() then
        size = tonumber(G.GetNumGroupMembers and G.GetNumGroupMembers()) or 1
        local units = { "player" }
        for i = 1, 4 do units[#units + 1] = "party" .. i end
        for _, u in ipairs(units) do
            if G.UnitExists and G.UnitExists(u) then
                local ok, r = pcall(G.UnitGroupRolesAssigned, u)
                if ok and not Secret(r) then
                    if r == "TANK" then have.T = have.T + 1
                    elseif r == "HEALER" then have.H = have.H + 1
                    elseif r == "DAMAGER" then have.D = have.D + 1 end
                end
            end
        end
    end
    return have, size
end

-- Liest die laufende Suche aus dem Spiel; nil, wenn keine laeuft
function Dung.ReadSelf()
    local C = G.C_LFGList
    if not C or not C.HasActiveEntryInfo or not C.GetActiveEntryInfo then return nil end
    local ok, active = pcall(C.HasActiveEntryInfo)
    if not ok or Secret(active) or not active then return nil end
    local ok2, info = pcall(C.GetActiveEntryInfo)
    if not ok2 or type(info) ~= "table" or Secret(info) then return nil end
    local ids = {}
    if type(info.activityIDs) == "table" then
        for _, id in ipairs(info.activityIDs) do ids[#ids + 1] = id end
    elseif info.activityID then
        ids[1] = info.activityID
    end
    local have, size = Dung.GroupHave()
    local roles = {}
    if size <= 1 then
        -- Einzelsuche: gewaehlte Rollen (Anführer, Tank, Heiler, Schaden)
        local ok3, _, tank, healer, dps = pcall(G.GetLFGRoles)
        if ok3 then
            if tank == true then roles.T = true end
            if healer == true then roles.H = true end
            if dps == true then roles.D = true end
        end
        if not next(roles) then
            local ok4, t2, h2, d2 = pcall(C.GetAvailableRoles)
            if ok4 and d2 == true then roles.D = true end
        end
    else
        -- Gruppe sucht: es fehlt, was noch nicht besetzt ist (Tank 1, Heiler 1, Schaden 3)
        if have.T < 1 then roles.T = true end
        if have.H < 1 then roles.H = true end
        if have.D < 3 then roles.D = true end
    end
    local label = Dung.LabelFor(ids)
    local sig = table.concat(ids, ",") .. "|" .. Dung.RoleString(roles) .. "|" .. (size > 1 and "g" or "s")
    return { roles = roles, size = size, have = have, ids = ids, label = label, sig = sig }
end

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

function Dung.Encode(m)
    return string.format("L|r=%s;n=%d;h=%d.%d.%d;a=%s;t=%s", Dung.RoleString(m.roles), m.size or 1,
        m.have.T or 0, m.have.H or 0, m.have.D or 0, table.concat(m.ids or {}, ","), Clean(m.label))
end

function Dung.Decode(body)
    local f = {}
    for k, v in string.gmatch(body or "", "(%a+)=([^;]*)") do f[k] = v end
    if not f.r then return nil end
    local h1, h2, h3 = string.match(f.h or "", "^(%d+)%.(%d+)%.(%d+)$")
    local ids = {}
    for id in string.gmatch(f.a or "", "%d+") do ids[#ids + 1] = tonumber(id) end
    return {
        roles = ParseRoles(f.r),
        size = tonumber(f.n) or 1,
        have = { T = tonumber(h1) or 0, H = tonumber(h2) or 0, D = tonumber(h3) or 0 },
        ids = ids,
        label = (f.t and f.t ~= "") and string.sub(f.t, 1, 60) or "?",
    }
end

local function ChatLine(m)
    local L = FW.L
    local me = Guild.SelfFirstName() or "?"
    if m.size > 1 then
        return string.format(L.DUNG_CHAT_GROUP, me, m.label, Dung.RoleWords(m.roles), m.size)
    end
    return string.format(L.DUNG_CHAT_SOLO, me, m.label, Dung.RoleWords(m.roles))
end

function Dung.SendChat(m)
    if not Guild.Setting("dungChat") or not Guild.InGuild() then return false end
    if not next(m.roles) then return false end
    local last = Dung.lastChat[m.sig]
    if last and Clock() - last < CHAT_GAP then return false end
    Dung.lastChat[m.sig] = Clock()
    local text = ChatLine(m)
    local fn = (G.C_ChatInfo and G.C_ChatInfo.SendChatMessage) or G.SendChatMessage
    if not fn then return false end
    local ok = pcall(fn, text, "GUILD")
    return ok
end

function Dung.Send(m, withChat)
    if not Guild.InGuild() then return end
    Share.Queue(Dung.Encode(m), "GUILD")
    if withChat then pcall(Dung.SendChat, m) end
end

function Dung.SendStop()
    if not Guild.InGuild() then return end
    Share.Queue("L|x", "GUILD")
end

------------------------------------------------------------------------
-- Empfangen
------------------------------------------------------------------------

local function Changed() FW:Fire("GUILD_MODULE_DUNGEON") end

function Dung.Purge()
    local now = Clock()
    for key, e in pairs(Dung.list) do
        if now - e.at > TTL then Dung.list[key] = nil end
    end
end

function Dung.Accept(key, sender, m)
    local old = Dung.list[key]
    local row = Guild.Row and Guild.Row(sender)
    m.key = key
    m.name = (row and row.name) or Guild.Display(sender)
    m.class = row and row.class
    m.at = Clock()
    m.since = (old and old.label == m.label and old.since) or Clock()
    Dung.list[key] = m
    Changed()
end

Share.handlers["L"] = function(key, body, channel, sender)
    if channel and channel ~= "GUILD" then return end
    if body == "x" then
        if Dung.list[key] then Dung.list[key] = nil; Changed() end
        return
    end
    local m = Dung.Decode(body)
    if m then Dung.Accept(key, sender, m) end
end

-- Sortierte Liste fuer die Anzeige (eigene Suche eingeschlossen)
function Dung.List()
    Dung.Purge()
    local out = {}
    for _, e in pairs(Dung.list) do out[#out + 1] = e end
    if Dung.mine then
        local self = {
            self = true, key = Guild.SelfKey(), name = Guild.SelfName() or "?", roles = Dung.mine.roles,
            size = Dung.mine.size, have = Dung.mine.have, ids = Dung.mine.ids, label = Dung.mine.label,
            since = Dung.mine.since or Clock(), at = Clock(),
        }
        local row = Guild.Row and Guild.Row(self.name)
        self.class = row and row.class
        out[#out + 1] = self
    end
    table.sort(out, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        if a.since ~= b.since then return a.since < b.since end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

------------------------------------------------------------------------
-- Gruppenvorschlag: 1 Tank, 1 Heiler, 3 Schaden aus den Einzelsuchern eines Dungeons
------------------------------------------------------------------------

-- cands: Liste von Eintraegen (nur Einzelsucher), Rueckgabe { T = e, H = e, D = { e, ... }, missing = { "T", ... }, count }
function Dung.Suggest(cands)
    local list = {}
    for _, e in ipairs(cands) do
        if (e.size or 1) <= 1 and next(e.roles) then list[#list + 1] = e end
    end
    table.sort(list, function(a, b) return a.since < b.since end)
    if #list > 8 then for i = #list, 9, -1 do list[i] = nil end end
    local rank = {}
    for i, e in ipairs(list) do rank[e] = #list - i + 1 end
    local best, bestCount, bestScore
    local assign = { T = nil, H = nil, D = {} }
    local used = {}
    local function Score()
        local count = (assign.T and 1 or 0) + (assign.H and 1 or 0) + #assign.D
        -- gleich viele Spieler: Vorrang fuer fruehere Anmeldungen
        local score = 0
        local function Add(e) if e then score = score + (rank[e] or 0) end end
        Add(assign.T); Add(assign.H)
        for _, e in ipairs(assign.D) do Add(e) end
        return count, score
    end
    local function Rec(i)
        if i > #list then
            local count, score = Score()
            if not best or count > bestCount or (count == bestCount and score > bestScore) then
                best = { T = assign.T, H = assign.H, D = { unpack(assign.D) } }
                bestCount, bestScore = count, score
            end
            return
        end
        local e = list[i]
        Rec(i + 1)                                                    -- nicht aufnehmen
        if e.roles.T and not assign.T then assign.T = e; Rec(i + 1); assign.T = nil end
        if e.roles.H and not assign.H then assign.H = e; Rec(i + 1); assign.H = nil end
        if e.roles.D and #assign.D < 3 then
            assign.D[#assign.D + 1] = e; Rec(i + 1); assign.D[#assign.D] = nil
        end
    end
    Rec(1)
    best = best or { D = {} }
    best.missing = {}
    if not best.T then best.missing[#best.missing + 1] = "T" end
    if not best.H then best.missing[#best.missing + 1] = "H" end
    for _ = #best.D + 1, 3 do best.missing[#best.missing + 1] = "D" end
    best.count = (best.T and 1 or 0) + (best.H and 1 or 0) + #best.D
    -- wer lädt ein: der mit der frühesten Anmeldung
    local first
    local function Pick(e) if e and (not first or e.since < first.since) then first = e end end
    Pick(best.T); Pick(best.H)
    for _, e in ipairs(best.D) do Pick(e) end
    best.inviter = first
    return best
end

function Dung.SuggestByLabel(list)
    local groups, order = {}, {}
    for _, e in ipairs(list) do
        if not groups[e.label] then groups[e.label] = {}; order[#order + 1] = e.label end
        local g = groups[e.label]
        g[#g + 1] = e
    end
    local out = {}
    for _, label in ipairs(order) do
        out[#out + 1] = { label = label, members = groups[label], plan = Dung.Suggest(groups[label]) }
    end
    return out
end

-- Alle Mitglieder des Vorschlags einladen; nur wer sich zuerst angemeldet hat, darf (die anderen warten)
function Dung.InviteAll(plan)
    if not plan or not plan.inviter or not plan.inviter.self then return 0 end
    local invite = (G.C_PartyInfo and G.C_PartyInfo.InviteUnit) or G.InviteUnit
    if not invite then return 0 end
    local n = 0
    local function Go(e)
        if e and not e.self then
            local ok = pcall(invite, e.name)
            if ok then n = n + 1 end
        end
    end
    Go(plan.T); Go(plan.H)
    for _, e in ipairs(plan.D) do Go(e) end
    return n
end

------------------------------------------------------------------------
-- Einladungen annehmen
------------------------------------------------------------------------

local function IsFriend(name)
    local FL = G.C_FriendList
    if FL and FL.GetFriendInfo then
        local ok, info = pcall(FL.GetFriendInfo, name)
        if ok and info then return true end
    end
    return false
end

-- Rueckgabe: "guild", "friend" oder nil
function Dung.Relation(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    if Guild.Row and Guild.Row(name) then return "guild" end
    if IsFriend(name) then return "friend" end
    return nil
end

function Dung.WantsAccept(inviter)
    if not Dung.mine then return false end                     -- nur bei laufender Suche
    if G.IsInGroup and G.IsInGroup() then return false end
    local rel = Dung.Relation(inviter)
    if rel == "guild" then return Guild.Setting("dungAutoGuild") == true end
    if rel == "friend" then return Guild.Setting("dungAutoFriends") == true end
    return false
end

function Dung.OnInvite(inviter)
    if not Dung.WantsAccept(inviter) then return false end
    if not G.AcceptGroup then return false end
    -- Das Einladungsfenster NICHT verstecken: das loest im Spiel DeclineGroup aus (Probe)
    local ok = pcall(G.AcceptGroup)
    if ok then FW:Print(string.format(FW.L.DUNG_ACCEPTED, Guild.Display(inviter))) end
    return ok
end

------------------------------------------------------------------------
-- Ablauf
------------------------------------------------------------------------

local pendingAt = nil
function Dung.Schedule(delay)
    local at = Clock() + (delay or 0.4)
    if not pendingAt or at < pendingAt then pendingAt = at end
    Share.After(delay or 0.4, function()
        if pendingAt and Clock() >= pendingAt - 0.01 then
            pendingAt = nil
            Dung.Update()
        end
    end)
end

local resendAt = nil

function Dung.Update()
    local cur = Dung.ReadSelf()
    local old = Dung.mine
    if not cur then
        if old then
            Dung.mine = nil
            Dung.SendStop()
            Changed()
        end
        return
    end
    cur.since = (old and old.sigBase == cur.sig and old.since) or Clock()
    cur.sigBase = cur.sig
    Dung.mine = cur
    local changed = (not old) or old.sig ~= cur.sig
    local haveChanged = old and (old.have.T ~= cur.have.T or old.have.H ~= cur.have.H or old.have.D ~= cur.have.D or old.size ~= cur.size)
    if changed or haveChanged then
        Dung.Send(cur, changed)
        resendAt = Clock() + RESEND
    end
    Changed()
end

function Dung.Tick()
    if Dung.mine and resendAt and Clock() >= resendAt then
        resendAt = Clock() + RESEND
        Dung.Send(Dung.mine, false)
    end
    Dung.Purge()
end

local owner = {}
local started = false

local function Start()
    if started then return end
    started = true
    local C = G.C_LFGList
    if C and G.hooksecurefunc then
        for _, name in ipairs({ "CreateListing", "UpdateListing", "RemoveListing" }) do
            if type(C[name]) == "function" then
                pcall(G.hooksecurefunc, C, name, function() Dung.Schedule(0.5) end)
            end
        end
    end
    FW:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE", function() Dung.Schedule(0.3) end, owner)
    FW:RegisterEvent("GROUP_ROSTER_UPDATE", function() if Dung.mine then Dung.Schedule(1) end end, owner)
    FW:RegisterEvent("PLAYER_ROLES_ASSIGNED", function() if Dung.mine then Dung.Schedule(1) end end, owner)
    FW:RegisterEvent("PARTY_INVITE_REQUEST", function(_, inviter) pcall(Dung.OnInvite, inviter) end, owner)
    -- Tick ueber die Warteschlange des Teilens
    local function Loop()
        pcall(Dung.Tick)
        Share.After(15, Loop)
    end
    Share.After(15, Loop)
    -- nach /reload mit laufender Suche: erneut melden
    Share.After(18 + math.random() * 8, function() Dung.Update() end)
end

table.insert(Share.startHooks, Start)
table.insert(Share.requestHooks, function()
    if Dung.mine then Share.After(4 + math.random() * 12, function() if Dung.mine then Dung.Send(Dung.mine, false) end end) end
end)
table.insert(Share.sendAllHooks, function() if Dung.mine then Dung.Send(Dung.mine, false) end end)

SLASH_FREEWOODDUNGEON1 = "/fwdungeon"
SLASH_FREEWOODDUNGEON2 = "/fwdg"
SlashCmdList["FREEWOODDUNGEON"] = function(msg)
    if string.lower(tostring(msg or "")) == "pos" and Guild.DungeonWin and Guild.DungeonWin.ResetPos then
        Guild.DungeonWin.ResetPos()
        FW:Print(FW.L.DUNG_WIN_RESET)
        return
    end
    if FW.UI and FW.UI.Toggle then FW.UI:Toggle("guild") end
end
