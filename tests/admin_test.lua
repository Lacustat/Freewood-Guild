-- Test 0.12.0: Verwaltung (Rechte, Rangwechsel per Makrotext, Notizen, Nachricht des Tages, Protokoll, Raenge, sicherer Knopf)
-- texlua tests/admin_test.lua
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

local combat = false
local perms = { promote = true, demote = true, invite = true, remove = true, pub = true, offView = true, offEdit = true, motd = true, info = true, leader = false }
_G.InCombatLockdown = function() return combat end
_G.IsGuildLeader = function() return perms.leader end
_G.CanGuildPromote = function() return perms.promote end
_G.CanGuildDemote = function() return perms.demote end
_G.CanGuildInvite = function() return perms.invite end
_G.CanGuildRemove = function() return perms.remove end
_G.CanEditPublicNote = function() return perms.pub end
_G.CanEditMOTD = function() return perms.motd end
_G.CanEditGuildInfo = function() return perms.info end
local ranks = { "Ober-Affe", "Offizier", "Veteran", "Mitglied", "Rekrut" }
_G.GuildControlGetNumRanks = function() return #ranks end
_G.GuildControlGetRankName = function(i) return ranks[i] end
local calls = {}
local function Log(...) calls[#calls + 1] = table.concat({ ... }, ",") end
local motd, info = "Hallo", "Info"
local blocked = { [5] = true }
_G.C_GuildInfo = {
    CanViewOfficerNote = function() return perms.offView end,
    CanEditOfficerNote = function() return perms.offEdit end,
    SetNote = function(guid, note, pub) Log("note", guid, note, tostring(pub)) end,
    GetMOTD = function() return motd end,
    SetMOTD = function(t) motd = t end,
    GetInfoText = function() return info end,
    SetInfoText = function(t) info = t end,
    IsGuildRankAssignmentAllowed = function(guid, order) return not blocked[order] end,
    GuildControlGetRankFlags = function(order) return { true, true, order <= 2, order <= 2, order <= 2 } end,
}
_G.GuildControlSetRank = function(i) Log("setrank", i) end
_G.GuildControlSetRankFlag = function(f, on) Log("flag", f, tostring(on)) end
_G.GuildControlSaveRank = function(name) Log("save", name) end
_G.GuildControlAddRank = function(name) Log("add", name) end
_G.GuildControlDelRank = function(i) Log("del", i) end
_G.GuildControlShiftRankUp = function(i) Log("up", i) end
_G.GuildControlGetAllowedShifts = function(i) return i > 2, i < #ranks end
_G.GetNumMembersInRank = function(i) return i == 5 and 0 or 3 end
_G.GetGuildInfo = function() return "Legion der Affen", "Offizier", 1 end
_G.GetNumGuildEvents = function() return 2 end
_G.GetGuildEventInfo = function(i)
    if i == 1 then return "invite", "Pinky Freewood", "Neu Ling", nil, 0, 0, 2, 3 end
    return "promote", "Pinky Freewood", "Neu Ling", "Veteran", 0, 0, 0, 1
end
_G.GUILDEVENT_TYPE_PROMOTE = "%s befördert %s zu %s."
_G.C_Timer = { After = function() end }
_G.UIParent = {}
local attrs, shown = {}, false
_G.CreateFrame = function(kind, name, parent, tmpl)
    local b = { tmpl = tmpl }
    function b:RegisterForClicks() end
    function b:SetAttribute(k, v) attrs[k] = v end
    function b:SetFrameStrata() end
    function b:SetFrameLevel() end
    function b:Hide() shown = false end
    function b:Show() shown = true end
    function b:IsShown() return shown end
    function b:SetScript(k, fn) self[k] = fn end
    function b:ClearAllPoints() end
    function b:SetPoint() end
    _G[name] = b
    return b
end

local FW = { L = setmetatable({}, { __index = function(_, k) return k end }) }
local handlers, events = {}, {}
function FW:RegisterEvent(ev, fn) events[ev] = fn end
function FW:On(ev, fn) handlers[ev] = fn end
function FW:Fire(ev, ...) if handlers[ev] then handlers[ev](...) end end
_G.Freewood = FW
local Guild = { rows = {}, rowByKey = {}, Secret = function() return false end, RequestRoster = function() end }
function Guild.SelfKey() return "ich selbst" end
local NS = { Guild = Guild }
assert(loadfile("GuildAdmin.lua"))("Freewood-Guild", NS)
local A = Guild.Admin

local me = { key = "ich selbst", full = "Ich Selbst", name = "Ich Selbst", rankOrder = 2, guid = "G-me", index = 1 }
local m4 = { key = "neu ling", full = "Neu Ling", name = "Neu Ling", rankOrder = 4, guid = "G-4", index = 2, note = "", onote = "" }
local m3 = { key = "vet eran", full = "Vet Eran", name = "Vet Eran", rankOrder = 3, guid = "G-3", index = 3 }
local gm = { key = "ober affe", full = "Ober Affe", name = "Ober Affe", rankOrder = 1, guid = "G-1", index = 4 }
Guild.rows = { me, m4, m3, gm }
for _, r in ipairs(Guild.rows) do Guild.rowByKey[r.key] = r end

-- Rechte
eq(A.MyRankOrder(), 2, "eigener Rang Offizier")
local r = A.RightsFor(m4)
eq(r.promote, true, "Mitglied befoerdern (Ziel 3 > 2)")
eq(r.demote, true, "Mitglied degradieren")
eq(r.remove, true, "Mitglied entfernen")
eq(r.leader, false, "nur Gildenmeister uebergibt die Leitung")
r = A.RightsFor(m3)
eq(r.promote, false, "Veteran nicht auf meinen Rang befoerdern")
eq(r.demote, true, "Veteran degradieren")
r = A.RightsFor(gm)
eq(r.demote or r.promote or r.remove, false, "Gildenmeister unantastbar")
r = A.RightsFor(me)
eq(r.publicNote, true, "eigene Notiz")
eq(r.remove, false, "mich selbst nicht entfernen")
perms.pub = false
eq(A.RightsFor(m4).publicNote, false, "fremde Notiz ohne Recht")
eq(A.RightsFor(me).publicNote, true, "eigene Notiz immer")
perms.pub = true

-- Rangauswahl
local ch = A.RankChoices(m4)
eq(#ch, 3, "Raenge 3 bis 5")
eq(ch[1].order, 3, "hoechster waehlbarer Rang 3")
eq(ch[2].current, true, "aktueller Rang markiert")
eq(ch[3].allowed, false, "Rang 5 vom Spiel gesperrt")

-- Makrotexte
eq(A.Macro("promote", "Neu Ling"), "/gpromote Neu Ling", "Befoerdern mit Vor- und Nachname")
eq(A.RankMacro(m4, 3), "/gpromote Neu Ling", "eine Stufe hoch")
eq(A.RankMacro(m4, 5), "/gdemote Neu Ling", "eine Stufe runter")
eq(A.RankMacro(m3, 5), "/gdemote Vet Eran\n/gdemote Vet Eran", "zwei Stufen runter")
eq(A.RankMacro(m4, 2), nil, "nicht auf meinen eigenen Rang")
eq(A.RankMacro(m4, 4), nil, "gleicher Rang: nichts")
eq(A.Macro("remove", "Neu Ling"), "/gremove Neu Ling", "entfernen")
_G.SLASH_GUILD_UNINVITE1 = "/gentfernen"
eq(A.Macro("remove", "Neu Ling"), "/gentfernen Neu Ling", "lokaler Befehl des Spiels bevorzugt")
eq(A.Macro("invite", "Bad\n/run x"), "/ginvite Bad/run x", "kein Zeilenumbruch im Namen")
eq(A.Macro("invite", "  Pinky   Freewood "), "/ginvite Pinky Freewood", "Leerzeichen bereinigt")
eq(A.Macro("invite", ""), nil, "leerer Name")
eq(A.Macro("leave"), "/gquit", "verlassen ohne Namen")

-- Sicherer Knopf
local over = { GetFrameLevel = function() return 5 end }
eq(A.Arm(over, "/gpromote Neu Ling"), true, "bereit")
eq(attrs.type, "macro", "Typ Makro")
eq(attrs.macrotext, "/gpromote Neu Ling", "Makrotext gesetzt")
eq(_G.FreewoodGuildSecureAction.tmpl, "SecureActionButtonTemplate", "sichere Vorlage")
eq(A.Armed(), true, "sichtbar")
events.PLAYER_REGEN_DISABLED()
eq(A.Armed(), false, "Kampfbeginn versteckt den Knopf")
combat = true
eq(A.Arm(over, "/gpromote Neu Ling"), false, "im Kampf nicht")
combat = false
local done = false
A.Arm(over, "/gremove Neu Ling", function() done = true end)
_G.FreewoodGuildSecureAction.PostClick(_G.FreewoodGuildSecureAction)
eq(done, true, "nach dem Klick Rueckmeldung")

-- Notizen
calls = {}
eq(A.SetNote(m4, "Sammelt Kräuter und Erze für die Gilde, sehr fleißig", true), true, "Notiz gesetzt")
local cut = calls[1]:match("^note,G%-4,(.-),true$")
eq(cut ~= nil and #cut <= 31, true, "auf 31 Zeichen gekuerzt: " .. tostring(cut))
eq(cut:sub(-1):byte() < 128 or cut:sub(-2):byte() >= 192, true, "kein halbes UTF-8-Zeichen")
calls = {}
A.SetNote(m4, "Twink", false)
eq(calls[1], "note,G-4,Twink,false", "Offiziersnotiz")
perms.offEdit = false
eq(A.SetNote(m4, "x", false), false, "Offiziersnotiz ohne Recht")
perms.offEdit = true
-- Rueckfall auf die alte Funktion
local saveSet = C_GuildInfo.SetNote
C_GuildInfo.SetNote = nil
local legacy
_G.GuildRosterSetPublicNote = function(i, t) legacy = i .. ":" .. t end
A.SetNote(m4, "alt", true)
eq(legacy, "2:alt", "GuildRosterSetPublicNote mit Index")
C_GuildInfo.SetNote = saveSet

-- Nachricht des Tages / Info
eq(A.GetMOTD(), "Hallo", "MOTD lesen")
eq(A.SetMOTD("Raid um 20|cffff0000 Uhr"), true, "MOTD setzen")
eq(motd, "Raid um 20 cffff0000 Uhr", "kein Farbcode")
perms.motd = false
eq(A.SetMOTD("x"), false, "ohne Recht")
eq(A.SetInfo("Neue Info"), true, "Info setzen")
eq(info, "Neue Info", "Info gespeichert")

-- Protokoll
local lines = A.LogLines()
eq(#lines, 2, "zwei Eintraege")
eq(lines[1].text, "Pinky Freewood befördert Neu Ling zu Veteran.", "neueste zuerst, Text des Spiels")
eq(lines[2].text, "Pinky Freewood invited Neu Ling to the guild.", "Rueckfalltext")
eq(lines[2].ago, 51, "Alter in Stunden")

-- Raenge (nur Gildenmeister)
eq(A.RenameRank(3, "Veteranen"), false, "ohne Leitung nicht umbenennen")
perms.leader = true
calls = {}
eq(A.RenameRank(3, "Veteranen"), true, "umbenennen")
eq(calls[1] .. ";" .. calls[2], "setrank,3;save,Veteranen", "erst Rang waehlen, dann speichern")
calls = {}
A.SetRankFlag(4, 7, true)
eq(calls[2], "flag,7,true", "Recht setzen")
eq(A.SetRankFlag(1, 7, false), false, "Gildenmeister-Rang nicht aendern")
eq(A.CanDeleteRank(4), false, "Rang mit Mitgliedern nicht loeschen")
eq(A.CanDeleteRank(5), true, "leeren Rang loeschen")
eq(A.CanShift(2, true), false, "Offizier nicht ueber den Gildenmeister")
eq(A.CanShift(3, true), true, "hoch")
eq(A.CanAddRank(), true, "neuer Rang moeglich (5 von 10)")
eq(A.RankFlags(2)[3], true, "Rechte lesen")
local r2 = A.RightsFor(m4)
eq(r2.leader, true, "Gildenmeister darf Leitung uebergeben")

print(string.format("admin_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
