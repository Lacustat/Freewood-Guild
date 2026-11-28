-- Freewood-Guild: Verwaltung fuer Offiziere und Gildenmeister (seit 0.12.0)
--
-- Was das Spiel erlaubt (Forever 1.60.1, Quelle: wow-ui-source Zweig "forever" und warcraft.wiki.gg):
--   * Geschuetzt (#protected, nur aus sicherem Code): C_GuildInfo.Promote, Demote, Uninvite, SetLeader (und Invite, Leave,
--     Disband ueber die sicheren Chatbefehle). Ein Addon darf sie NICHT direkt aufrufen (sonst "Aktion blockiert").
--     Weg hier: ein sicherer Knopf (SecureActionButtonTemplate, type = "macro") mit dem Chatbefehl als Makrotext,
--     z. B. "/gpromote Vorname Nachname". Der Klick des Spielers fuehrt ihn aus. Im Kampf gesperrt (Attribute).
--     Rangwechsel um mehrere Stufen = mehrere Zeilen /gpromote bzw. /gdemote.
--   * Direkt aufrufbar (wie Blizzards eigene Dialoge): C_GuildInfo.SetNote (Notizen, 31 Zeichen), SetMOTD, SetInfoText,
--     GuildControl* (Raenge: Name, Rechte, neu, loeschen, verschieben), QueryGuildEventLog / GetGuildEventInfo (Protokoll).
--   * Rechte: CanEditPublicNote, C_GuildInfo.CanViewOfficerNote / CanEditOfficerNote, CanGuildPromote/Demote/Invite/Remove,
--     CanEditMOTD, CanEditGuildInfo, IsGuildLeader, C_GuildInfo.IsGuildRankAssignmentAllowed.
-- Rangordnung: 1 = Gildenmeister, groessere Zahl = niedriger. GetGuildRosterInfo liefert rankIndex ab 0 (Order = Index + 1).
-- UNGEPRUEFT im Spiel: alles hier, besonders die sicheren Makro-Knoepfe mit Vor- und Nachnamen und mehrstufige Rangwechsel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local A = {}
Guild.Admin = A

A.NOTE_MAX = 31
A.MOTD_MAX = 128
A.INFO_MAX = 500
A.MAX_RANKS = 10
A.FLAG_COUNT = 13     -- Rechte 1-13 (Chat, Befoerdern ... Gildeninfo); 14 ist veraltet, Rest betrifft Bank/Kalender

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

local function GI() return G.C_GuildInfo or {} end
local function Bool(v) return v == true or v == 1 end
local function InCombat() return G.InCombatLockdown and G.InCombatLockdown() and true or false end
A.InCombat = InCombat

------------------------------------------------------------------------
-- Rechte
------------------------------------------------------------------------

function A.IsLeader() return Bool(Call(G.IsGuildLeader)) end
function A.CanPromote() return Bool(Call(G.CanGuildPromote)) end
function A.CanDemote() return Bool(Call(G.CanGuildDemote)) end
function A.CanInvite() return Bool(Call(G.CanGuildInvite)) end
function A.CanRemove() return Bool(Call(G.CanGuildRemove)) end
function A.CanEditPublic() return Bool(Call(G.CanEditPublicNote)) end
function A.CanViewOfficer()
    local v = Call(GI().CanViewOfficerNote)
    if v == nil then v = Call(G.CanViewOfficerNote) end
    return Bool(v)
end
function A.CanEditOfficer()
    local v = Call(GI().CanEditOfficerNote)
    if v == nil then v = Call(G.CanEditOfficerNote) end
    return Bool(v)
end
function A.CanEditMOTD() return Bool(Call(G.CanEditMOTD)) end
function A.CanEditInfo() return Bool(Call(G.CanEditGuildInfo)) end
function A.IsOfficer()
    local v = Call(GI().IsGuildOfficer)
    if v == nil then v = Call(G.IsGuildOfficer) end
    return Bool(v) or A.IsLeader()
end

-- Irgendein Verwaltungsrecht?
function A.HasAnyRight()
    return A.IsLeader() or A.CanPromote() or A.CanDemote() or A.CanInvite() or A.CanRemove() or A.CanEditPublic()
        or A.CanEditOfficer() or A.CanEditMOTD() or A.CanEditInfo()
end

function A.GuildName()
    local n = Call(G.GetGuildInfo, "player")
    if type(n) ~= "string" or Guild.Secret(n) then return "" end
    return n
end

function A.NumRanks() return tonumber(Call(G.GuildControlGetNumRanks)) or 0 end
function A.RankName(order) return Call(G.GuildControlGetRankName, order) or ("#" .. tostring(order)) end

-- Eigene Rangordnung (1 = Gildenmeister)
function A.MyRankOrder()
    local row = Guild.rowByKey and Guild.rowByKey[Guild.SelfKey and Guild.SelfKey() or ""]
    if row and row.rankOrder then return row.rankOrder end
    local _, _, idx = Call(G.GetGuildInfo, "player")
    if tonumber(idx) then return tonumber(idx) + 1 end
    return 99
end

function A.IsSelf(row)
    return row ~= nil and Guild.SelfKey and row.key == Guild.SelfKey()
end

-- Was darf ich mit diesem Mitglied? Rueckgabe: Tabelle mit Wahrheitswerten
function A.RightsFor(row)
    local r = {}
    if not row then return r end
    local mine, theirs, num = A.MyRankOrder(), row.rankOrder or 99, A.NumRanks()
    local self = A.IsSelf(row)
    r.publicNote = self or A.CanEditPublic()
    r.viewOfficer = A.CanViewOfficer()
    r.officerNote = A.CanEditOfficer()
    r.promote = not self and A.CanPromote() and theirs > mine + 1
    r.demote = not self and A.CanDemote() and theirs > mine and theirs < num
    r.rank = r.promote or r.demote
    r.remove = not self and A.CanRemove() and theirs > mine
    r.leader = not self and A.IsLeader()
    return r
end

-- Raenge, auf die ich dieses Mitglied setzen darf: Liste { order, name, allowed }
function A.RankChoices(row)
    local out = {}
    if not row then return out end
    local r = A.RightsFor(row)
    local mine, cur, num = A.MyRankOrder(), row.rankOrder or 99, A.NumRanks()
    local top = r.promote and (mine + 1) or cur
    local bottom = r.demote and num or cur
    for order = top, bottom do
        local allowed = true
        local fn = GI().IsGuildRankAssignmentAllowed
        if order ~= cur and type(fn) == "function" and row.guid then
            local ok, v = pcall(fn, row.guid, order)
            if ok and v == false then allowed = false end
        end
        out[#out + 1] = { order = order, name = A.RankName(order), allowed = allowed, current = order == cur }
    end
    return out
end

------------------------------------------------------------------------
-- Makrotext fuer die geschuetzten Befehle
------------------------------------------------------------------------

local SLASH = {
    promote = { "SLASH_GUILD_PROMOTE1", "/gpromote" },
    demote = { "SLASH_GUILD_DEMOTE1", "/gdemote" },
    remove = { "SLASH_GUILD_UNINVITE1", "/gremove" },
    leader = { "SLASH_GUILD_LEADER1", "/gleader" },
    invite = { "SLASH_GUILD_INVITE1", "/ginvite" },
    leave = { "SLASH_GUILD_LEAVE1", "/gquit" },
    disband = { "SLASH_GUILD_DISBAND1", "/gdisband" },
}

function A.Slash(kind)
    local s = SLASH[kind]
    if not s then return nil end
    local v = G[s[1]]
    if type(v) == "string" and v:sub(1, 1) == "/" then return v end
    return s[2]
end

-- Name fuer den Chatbefehl: kein Zeilenumbruch, keine Steuerzeichen, hoechstens 48 Bytes
function A.CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if name == "" or #name > 48 then return nil end
    return name
end

-- Makrotext: kind = promote/demote/remove/leader/invite/leave/disband, steps = Anzahl Zeilen (Rangwechsel)
function A.Macro(kind, name, steps)
    local cmd = A.Slash(kind)
    if not cmd then return nil end
    if kind == "leave" or kind == "disband" then return cmd end
    name = A.CleanName(name)
    if not name then return nil end
    local lines = {}
    for i = 1, math.max(1, math.min(tonumber(steps) or 1, A.MAX_RANKS)) do lines[i] = cmd .. " " .. name end
    return table.concat(lines, "\n")
end

-- Rangwechsel von row auf order: Makrotext oder nil, Fehlertext
function A.RankMacro(row, order)
    if not row or not order then return nil, "args" end
    local cur = row.rankOrder or 99
    if order == cur then return nil, "same" end
    local r = A.RightsFor(row)
    if order < cur then
        if not r.promote or order < A.MyRankOrder() + 1 then return nil, "rights" end
        return A.Macro("promote", row.full, cur - order)
    end
    if not r.demote or order > A.NumRanks() then return nil, "rights" end
    return A.Macro("demote", row.full, order - cur)
end

------------------------------------------------------------------------
-- Sicherer Knopf (einer fuer alle geschuetzten Befehle)
------------------------------------------------------------------------

local secure
function A.SecureButton()
    if secure or not G.CreateFrame then return secure end
    if InCombat() then return nil end
    local ok, b = pcall(G.CreateFrame, "Button", "FreewoodGuildSecureAction", G.UIParent, "SecureActionButtonTemplate")
    if not ok or not b then return nil end
    secure = b
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetFrameStrata("FULLSCREEN_DIALOG")
    b:Hide()
    b:SetScript("PostClick", function(self)
        local done = self.fwDone
        self.fwDone = nil
        if done then pcall(done) end
        if G.C_Timer and G.C_Timer.After then
            G.C_Timer.After(1, function() Guild.RequestRoster(true) end)
        end
    end)
    return b
end

-- Den sicheren Knopf ueber einen sichtbaren Knopf legen. Rueckgabe: true, wenn bereit (nicht im Kampf)
function A.Arm(over, macrotext, onDone)
    local b = A.SecureButton()
    if not b or InCombat() or type(macrotext) ~= "string" then return false end
    b:SetAttribute("macrotext", macrotext)
    b.fwDone = onDone
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", over, "TOPLEFT", 0, 0)
    b:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT", 0, 0)
    b:SetFrameLevel((over:GetFrameLevel() or 1) + 10)
    b:Show()
    A.armedOver = over
    return true
end

function A.Disarm()
    if secure and not InCombat() then
        secure:Hide()
        secure:SetAttribute("macrotext", nil)
        secure:ClearAllPoints()
        secure.fwDone = nil
    end
    A.armedOver = nil
end

function A.Armed() return secure ~= nil and secure:IsShown() and true or false end

FW:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    -- Kampf beginnt: vor der Sperre verstecken
    A.Disarm()
    FW:Fire("GUILD_ADMIN_COMBAT", true)
end)
FW:RegisterEvent("PLAYER_REGEN_ENABLED", function() FW:Fire("GUILD_ADMIN_COMBAT", false) end)

------------------------------------------------------------------------
-- Notizen (direkt)
------------------------------------------------------------------------

local function CutNote(text)
    text = tostring(text or ""):gsub("[%c|]", " ")
    if #text > A.NOTE_MAX then
        -- nicht mitten in einem UTF-8-Zeichen abschneiden
        local cut = A.NOTE_MAX
        while cut > 0 and text:byte(cut + 1) and text:byte(cut + 1) >= 128 and text:byte(cut + 1) < 192 do cut = cut - 1 end
        text = text:sub(1, cut)
    end
    return text
end
A.CutNote = CutNote

function A.SetNote(row, text, isPublic)
    if not row then return false, "row" end
    local r = A.RightsFor(row)
    if isPublic and not r.publicNote then return false, "rights" end
    if not isPublic and not r.officerNote then return false, "rights" end
    text = CutNote(text)
    local fn = GI().SetNote
    local ok = false
    if type(fn) == "function" and row.guid then
        ok = pcall(fn, row.guid, text, isPublic and true or false)
    end
    if not ok and row.index then
        local legacy = isPublic and G.GuildRosterSetPublicNote or G.GuildRosterSetOfficerNote
        if type(legacy) == "function" then ok = pcall(legacy, row.index, text) end
    end
    if ok then
        if isPublic then row.note = text else row.onote = text end
        if G.C_Timer and G.C_Timer.After then G.C_Timer.After(1, function() Guild.RequestRoster(true) end) end
    end
    return ok
end

------------------------------------------------------------------------
-- Nachricht des Tages und Gildeninformation (direkt)
------------------------------------------------------------------------

function A.GetMOTD()
    local v = Call(GI().GetMOTD)
    if v == nil then v = Call(G.GetGuildRosterMOTD) end
    if type(v) ~= "string" or Guild.Secret(v) then return "" end
    return v
end

function A.SetMOTD(text)
    if not A.CanEditMOTD() then return false end
    text = tostring(text or ""):gsub("[%c|]", " "):sub(1, A.MOTD_MAX)
    local fn = GI().SetMOTD or G.GuildSetMOTD
    if type(fn) ~= "function" then return false end
    return (pcall(fn, text))
end

function A.GetInfo()
    local v = Call(GI().GetInfoText)
    if v == nil then v = Call(G.GetGuildInfoText) end
    if type(v) ~= "string" or Guild.Secret(v) then return "" end
    return v
end

function A.SetInfo(text)
    if not A.CanEditInfo() then return false end
    text = tostring(text or ""):gsub("|", "/"):sub(1, A.INFO_MAX)
    local fn = GI().SetInfoText or G.SetGuildInfoText
    if type(fn) ~= "function" then return false end
    return (pcall(fn, text))
end

------------------------------------------------------------------------
-- Gildenprotokoll
------------------------------------------------------------------------

function A.QueryLog()
    if type(G.QueryGuildEventLog) == "function" then pcall(G.QueryGuildEventLog) return true end
    return false
end

local EVENT_FMT = {
    invite = { "GUILDEVENT_TYPE_INVITE", "%s invited %s to the guild." },
    join = { "GUILDEVENT_TYPE_JOIN", "%s joined the guild." },
    promote = { "GUILDEVENT_TYPE_PROMOTE", "%s promoted %s to %s." },
    demote = { "GUILDEVENT_TYPE_DEMOTE", "%s demoted %s to %s." },
    remove = { "GUILDEVENT_TYPE_REMOVE", "%s removed %s from the guild." },
    quit = { "GUILDEVENT_TYPE_QUIT", "%s has left the guild." },
}

-- Liste der Eintraege, neueste zuerst: { text, kind, ago }
function A.LogLines()
    local out = {}
    local n = tonumber(Call(G.GetNumGuildEvents)) or 0
    local unknown = G.UNKNOWN or "?"
    for i = n, 1, -1 do
        local kind, p1, p2, rank, y, m, d, h = Call(G.GetGuildEventInfo, i)
        local f = EVENT_FMT[kind]
        if f then
            local fmt = type(G[f[1]]) == "string" and G[f[1]] or f[2]
            local a, b = p1 or unknown, p2 or unknown
            local ok, text = pcall(string.format, fmt, a, b, rank or unknown)
            if not ok then text = kind .. ": " .. tostring(a) .. " " .. tostring(b) end
            local ago = ((tonumber(y) or 0) * 365 + (tonumber(m) or 0) * 30 + (tonumber(d) or 0)) * 24 + (tonumber(h) or 0)
            out[#out + 1] = { text = text, kind = kind, ago = ago }
        end
    end
    return out
end

function A.FormatAgo(hours)
    local L = FW.L
    hours = tonumber(hours) or 0
    if hours < 1 then return L.GADM_AGO_NOW end
    if hours < 24 then return string.format(L.GADM_AGO_H, hours) end
    return string.format(L.GADM_AGO_D, math.floor(hours / 24))
end

------------------------------------------------------------------------
-- Raenge verwalten (nur Gildenmeister)
------------------------------------------------------------------------

function A.RankFlags(order)
    local fn = GI().GuildControlGetRankFlags
    if type(fn) == "function" then
        local ok, t = pcall(fn, order)
        if ok and type(t) == "table" then return t end
    end
    if type(G.GuildControlSetRank) == "function" and type(G.GuildControlGetRankFlags) == "function" then
        pcall(G.GuildControlSetRank, order)
        local res = { pcall(G.GuildControlGetRankFlags) }
        if res[1] then
            local t = {}
            for i = 2, #res do t[i - 1] = res[i] and true or false end
            return t
        end
    end
    return {}
end

function A.FlagLabel(i)
    local v = G["GUILDCONTROL_OPTION" .. i]
    if type(v) == "string" then return v end
    return FW.L["GADM_FLAG_" .. i] or ("#" .. i)
end

-- Nur Raenge unter dem Gildenmeister (2..n) sind bearbeitbar
local function EditableRank(order)
    return A.IsLeader() and tonumber(order) and order >= 2 and order <= A.NumRanks()
end
A.EditableRank = EditableRank

function A.SetRankFlag(order, flag, on)
    if not EditableRank(order) or type(G.GuildControlSetRankFlag) ~= "function" then return false end
    pcall(G.GuildControlSetRank, order)
    return (pcall(G.GuildControlSetRankFlag, flag, on and true or false))
end

function A.RenameRank(order, name)
    if not (A.IsLeader() and tonumber(order) and order >= 1 and order <= A.NumRanks()) then return false end
    name = tostring(name or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 30 or type(G.GuildControlSaveRank) ~= "function" then return false end
    pcall(G.GuildControlSetRank, order)
    return (pcall(G.GuildControlSaveRank, name))
end

function A.MembersInRank(order)
    local v = tonumber(Call(G.GetNumMembersInRank, order))
    if v then return v end
    local c = 0
    for _, row in ipairs(Guild.rows or {}) do if row.rankOrder == order then c = c + 1 end end
    return c
end

function A.CanAddRank() return A.IsLeader() and A.NumRanks() < A.MAX_RANKS and type(G.GuildControlAddRank) == "function" end

function A.AddRank(name)
    if not A.CanAddRank() then return false end
    name = tostring(name or ""):gsub("[%c|]", "")
    if name == "" then name = G.GUILD_NEW_RANK or FW.L.GADM_NEW_RANK end
    return (pcall(G.GuildControlAddRank, name))
end

function A.CanDeleteRank(order)
    return EditableRank(order) and A.NumRanks() > 2 and A.MembersInRank(order) == 0 and type(G.GuildControlDelRank) == "function"
end

function A.DeleteRank(order)
    if not A.CanDeleteRank(order) then return false end
    return (pcall(G.GuildControlDelRank, order))
end

-- Verschieben: up = hoeher (kleinere Zahl). Rueckgabe: moeglich?
function A.CanShift(order, up)
    if not EditableRank(order) or A.NumRanks() <= 2 then return false end
    if type(G.GuildControlGetAllowedShifts) == "function" then
        local ok, canUp, canDown = pcall(G.GuildControlGetAllowedShifts, order)
        if ok then return (up and canUp or (not up and canDown)) and true or false end
    end
    if up then return order > 2 end
    return order < A.NumRanks()
end

function A.Shift(order, up)
    if not A.CanShift(order, up) then return false end
    local fn = up and G.GuildControlShiftRankUp or G.GuildControlShiftRankDown
    if type(fn) ~= "function" then return false end
    return (pcall(fn, order))
end

-- Blizzards eigenes Fenster der Rangverwaltung (Rueckfall)
function A.OpenBlizzardRanks()
    if InCombat() then return false end
    if type(G.GuildControlUI_LoadUI) == "function" then pcall(G.GuildControlUI_LoadUI) end
    local fr = G.GuildControlUI
    if fr then
        if G.ShowUIPanel then pcall(G.ShowUIPanel, fr) else pcall(fr.Show, fr) end
        return true
    end
    return false
end

-- Aenderungen der Raenge und des Protokolls melden
FW:RegisterEvent("GUILD_RANKS_UPDATE", function() FW:Fire("GUILD_ADMIN_CHANGED", "ranks") end)
FW:RegisterEvent("GUILD_EVENT_LOG_UPDATE", function() FW:Fire("GUILD_ADMIN_CHANGED", "log") end)
FW:RegisterEvent("GUILD_MOTD", function() FW:Fire("GUILD_ADMIN_CHANGED", "motd") end)
