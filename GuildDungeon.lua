-- Freewood-Guild: Dungeon-Browser (Logik). Lauscht bei der Gruppensuche des Spiels mit (C_LFGList), meldet der Gilde, wer wofuer
-- sucht (versteckte Nachricht fuer Freewood-Nutzer, auf Wunsch eine Zeile im Gildenchat), schlaegt Gruppen vor und kann
-- Einladungen von Gildenmitgliedern/Freunden bei laufender Suche annehmen. Alles UNGEPRUEFT im Spiel; die Grundlagen
-- (Funktionen, Ereignisse, lesbare Werte) stammen aus der Probe /fwlfg in Freewood-Dev 0.13.5 bis 0.13.8.
--
-- Nachricht (Praefix FWGuild1, Gilde):
--   L|r=TH;n=1;h=0.0.1;a=799,800;t=Todesminen;l=1;m=Anna,Bob   Suche: Rollen (T Tank, H Heiler, D Schaden), Mitglieder, vorhanden T.H.D,
--                                               Aktivitaeten, Name, l=1 Gruppenleiter meldet, m = Gildenmitglieder der Gruppe (ab 0.9.10)
--   L|x                                         Suche beendet
--
-- Ab 0.9.10: Pro Gruppe meldet nur der Gruppenleiter (mit allen Gildenmitgliedern der Gruppe) und schreibt hoechstens eine Zeile in den
-- Gildenchat (bei der Anmeldung, nicht bei Aenderungen). Hat der Leiter das Addon nicht, springt nach etwa 20 s ein Mitglied ein.
-- Eintraege von Mitgliedern, die in einer gemeldeten Gruppe stehen, werden in der Liste ausgeblendet.
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
local FALLBACK = 20       -- Sekunden, nach denen ein Mitglied meldet, wenn der Gruppenleiter nicht meldet
local COVER_TTL = 360      -- so lange gilt die Meldung eines anderen fuer meine Gruppe
local CHAT_GAP = 60        -- Sekunden Mindestabstand zwischen zwei Zeilen im Gildenchat
local ROLE_ORDER = { "T", "H", "D" }

local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Now() return G.time and G.time() or 0 end
local function Secret(v) return Guild.Secret(v) end
function Dung.NowClock() return Clock() end

Dung.list = {}      -- [Schluessel] = { name, key, roles = {T=,H=,D=}, size, have = {T,H,D}, ids, label, since, at, self }
Dung.mine = nil     -- eigener Stand: { roles, size, have, ids, label, sig }
Dung.lastChat = {}  -- [Suche] = Uhrzeit
Dung.reporting = false   -- melden wir (Leiter oder eingesprungen) die laufende Suche?
Dung.fallback = false    -- als Nicht-Leiter eingesprungen

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

-- Name eines Gruppenmitglieds wie in der Gildenliste ("Vorname Nachname"), nil wenn kein Gildenmitglied
local function MemberName(unit)
    local fn = G.UnitFullName or G.UnitName
    if not fn then return nil end
    local ok, n, second = pcall(fn, unit)
    if not ok or type(n) ~= "string" or Secret(n) or n == "" then return nil end
    local cands = {}
    if type(second) == "string" and not Secret(second) and second ~= "" then cands[#cands + 1] = n .. " " .. second end
    cands[#cands + 1] = n
    for _, c in ipairs(cands) do
        local k = Guild.Key(c)
        if k and Guild.rowByKey and Guild.rowByKey[k] then return c end
    end
    return nil
end

local function IsLeader(unit)
    if not G.UnitIsGroupLeader then return false end
    local ok, v = pcall(G.UnitIsGroupLeader, unit)
    return ok and not Secret(v) and v == true
end

-- Gildenmitglieder der eigenen Gruppe: Namen (Leiter zuerst, ich eingeschlossen) und Schluessel-Menge
function Dung.GroupGuildMembers()
    local list, keys = {}, {}
    local function Add(name, leader)
        local k = Guild.Key(name)
        if not k or keys[k] then return end
        keys[k] = true
        local e = { name = Guild.Display(name), leader = leader }
        if leader then table.insert(list, 1, e) else list[#list + 1] = e end
    end
    Add(Guild.SelfName(), IsLeader("player"))
    if G.IsInGroup and G.IsInGroup() and G.UnitExists then
        for i = 1, 4 do
            local u = "party" .. i
            if G.UnitExists(u) then
                local nm = MemberName(u)
                if nm then Add(nm, IsLeader(u)) end
            end
        end
    end
    local names = {}
    for _, e in ipairs(list) do names[#names + 1] = e.name end
    return names, keys
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
    local idsSig = table.concat(ids, ",")
    local sig = idsSig .. "|" .. Dung.RoleString(roles) .. "|" .. (size > 1 and "g" or "s")
    local leader = true
    if size > 1 and G.UnitIsGroupLeader then leader = IsLeader("player") end
    local members, memberKeys = Dung.GroupGuildMembers()
    local mk = {}
    for k in pairs(memberKeys) do mk[#mk + 1] = k end
    table.sort(mk)
    return { roles = roles, size = size, have = have, ids = ids, label = label, sig = sig, idsSig = idsSig, leader = leader,
        members = members, memberKeys = memberKeys, membersSig = table.concat(mk, ",") }
end

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

function Dung.Encode(m)
    local s = string.format("L|r=%s;n=%d;h=%d.%d.%d;a=%s;t=%s", Dung.RoleString(m.roles), m.size or 1,
        m.have.T or 0, m.have.H or 0, m.have.D or 0, table.concat(m.ids or {}, ","), Clean(m.label))
    if m.leader then s = s .. ";l=1" end
    if m.members and #m.members > 0 then
        local names = {}
        for i, n in ipairs(m.members) do if i <= 5 then names[#names + 1] = (string.gsub(Clean(n), ",", " ")) end end
        local withNames = s .. ";m=" .. table.concat(names, ",")
        if #withNames <= 240 then s = withNames end      -- zu lang: ohne Namen senden (Grenze der Warteschlange 250)
    end
    return s
end

function Dung.Decode(body)
    local f = {}
    for k, v in string.gmatch(body or "", "(%a+)=([^;]*)") do f[k] = v end
    if not f.r then return nil end
    local h1, h2, h3 = string.match(f.h or "", "^(%d+)%.(%d+)%.(%d+)$")
    local ids = {}
    for id in string.gmatch(f.a or "", "%d+") do ids[#ids + 1] = tonumber(id) end
    local members, memberKeys = {}, {}
    for n in string.gmatch(f.m or "", "[^,]+") do
        members[#members + 1] = n
        local k = Guild.Key(n)
        if k then memberKeys[k] = true end
    end
    return {
        leader = f.l == "1",
        members = members,
        memberKeys = memberKeys,
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
        if m.members and #m.members > 1 then
            return string.format(L.DUNG_CHAT_GROUPS, table.concat(m.members, ", "), m.label, Dung.RoleWords(m.roles), m.size)
        end
        return string.format(L.DUNG_CHAT_GROUP, (m.members and m.members[1]) or me, m.label, Dung.RoleWords(m.roles), m.size)
    end
    return string.format(L.DUNG_CHAT_SOLO, me, m.label, Dung.RoleWords(m.roles))
end

function Dung.SendChat(m)
    if not Guild.Setting("dungChat") or not Guild.InGuild() then return false end
    if not next(m.roles) then return false end
    local last = Dung.lastChat[m.idsSig or m.sig]
    if last and Clock() - last < CHAT_GAP then return false end
    Dung.lastChat[m.idsSig or m.sig] = Clock()
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
        if Dung.mine then Dung.Schedule(1) end        -- vielleicht meldet jetzt niemand mehr meine Gruppe
        return
    end
    local m = Dung.Decode(body)
    if m then
        Dung.Accept(key, sender, m)
        if Dung.mine then Dung.Schedule(1) end        -- meldet jemand meine Gruppe, muss ich es nicht
    end
end

-- Hat e Vorrang vor f, wenn beide dieselben Spieler melden? Gruppenleiter zuerst, sonst nach Schluessel (auf allen Rechnern gleich)
local function Beats(e, f)
    if (e.leader and true or false) ~= (f.leader and true or false) then return e.leader and true or false end
    return (e.key or "") < (f.key or "")
end
Dung.Beats = Beats

-- Meldet schon ein anderer meine Gruppe (frische Meldung, die mich nennt und Vorrang hat)?
function Dung.Covered()
    local me = Guild.SelfKey()
    if not me or not Dung.mine then return false end
    local mine = { key = me, leader = Dung.mine.leader }
    local now = Clock()
    for key, e in pairs(Dung.list) do
        if key ~= me and e.memberKeys and e.memberKeys[me] and now - e.at < COVER_TTL and Beats(e, mine) then return true end
    end
    return false
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
            leader = Dung.mine.leader, members = Dung.mine.members, memberKeys = Dung.mine.memberKeys,
        }
        local row = Guild.Row and Guild.Row(self.name)
        self.class = row and row.class
        out[#out + 1] = self
    end
    -- Wer in der Gruppe eines anderen genannt wird, bekommt keine eigene Zeile (die Gruppe steht einmal)
    local kept = {}
    for _, e in ipairs(out) do
        local covered = false
        for _, f in ipairs(out) do
            if f ~= e and f.memberKeys and f.memberKeys[e.key] and Beats(f, e) then covered = true; break end
        end
        if not covered then kept[#kept + 1] = e end
    end
    out = kept
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

-- Als Nicht-Leiter einspringen, wenn nach FALLBACK Sekunden niemand die Gruppe meldet (der Leiter hat das Addon nicht)
function Dung.ScheduleFallback()
    if Dung.fbPending then return end
    Dung.fbPending = true
    Share.After(FALLBACK + math.random() * 10, function()
        Dung.fbPending = false
        if Dung.mine and not Dung.mine.leader and not Dung.fallback and not Dung.Covered() then
            Dung.fallback = true
            Dung.Update()
        end
    end)
end

-- silent: keine Zeile in den Gildenchat (nach /reload bei laufender Suche)
function Dung.Update(silent)
    local cur = Dung.ReadSelf()
    local old = Dung.mine
    if not cur then
        Dung.fallback = false
        Dung.mine = nil
        if Dung.reporting then
            Dung.reporting = false
            Dung.SendStop()
        end
        if old then Changed() end
        return
    end
    cur.since = (old and old.idsSig == cur.idsSig and old.since) or Clock()
    Dung.mine = cur
    -- Wer meldet? Der Gruppenleiter (oder wer allein sucht); sonst nur, wer eingesprungen ist
    local want = cur.leader or Dung.fallback
    if not cur.leader then
        if Dung.Covered() then
            Dung.fallback = false
            want = false
        elseif not Dung.fallback then
            Dung.ScheduleFallback()
        end
    end
    if want then
        -- Eine Zeile im Gildenchat nur bei der Anmeldung (neue Suche oder anderer Dungeon), nie bei Aenderungen der Gruppe
        local chatDue = (not Dung.reporting) or (not old) or old.idsSig ~= cur.idsSig
        local changed = (not Dung.reporting) or (not old) or old.sig ~= cur.sig or old.membersSig ~= cur.membersSig
            or old.size ~= cur.size or old.have.T ~= cur.have.T or old.have.H ~= cur.have.H or old.have.D ~= cur.have.D
            or old.leader ~= cur.leader
        if changed then
            Dung.Send(cur, chatDue and not silent)
            resendAt = Clock() + RESEND
        end
        Dung.reporting = true
    elseif Dung.reporting then
        Dung.reporting = false
        Dung.SendStop()
    end
    Changed()
end

function Dung.Tick()
    if Dung.mine and Dung.reporting and resendAt and Clock() >= resendAt then
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
    Share.After(18 + math.random() * 8, function() Dung.Update(true) end)
end

table.insert(Share.startHooks, Start)
table.insert(Share.requestHooks, function()
    if Dung.mine and Dung.reporting then Share.After(4 + math.random() * 12, function() if Dung.mine and Dung.reporting then Dung.Send(Dung.mine, false) end end) end
end)
table.insert(Share.sendAllHooks, function() if Dung.mine and Dung.reporting then Dung.Send(Dung.mine, false) end end)

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
