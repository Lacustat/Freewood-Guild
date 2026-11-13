-- Test: Dungeon-Browser, Gruppen (nur der Leiter meldet, eine Chatzeile, Einspringen, Zusammenfassen) (texlua tests/dungeon_group_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
local now = 1000
_G.GetTime = function() return now end
_G.time = function() return 5000 + now end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function(u)
    local t = { player = { "Pinky", "Freewood" }, party1 = { "Jinxer", "Darktide" }, party2 = { "Fremder", "Wicht" } }
    local v = t[u]; if v then return v[1], v[2] end
end
_G.GetNormalizedRealmName = function() return "R" end
_G.GetRealmName = function() return "R" end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local sent, chat = {}, {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print() end
function FW:RegisterEvent() end
FW.L.DUNG_CHAT_SOLO = "%s|%s|%s"
FW.L.DUNG_CHAT_GROUP = "G1 %s|%s|%s|%d"
FW.L.DUNG_CHAT_GROUPS = "G2 %s|%s|%s|%d"
FW.L.DUNG_ROLE_T, FW.L.DUNG_ROLE_H, FW.L.DUNG_ROLE_D = "Tank", "Heiler", "Schaden"
_G.Freewood = FW
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
Guild.InGuild = function() return true end
local tasks = {}
Guild.Share = { handlers = {}, startHooks = {}, requestHooks = {}, sendAllHooks = {},
    Queue = function(t) sent[#sent + 1] = t end, After = function(s, fn) tasks[#tasks + 1] = fn end }
Guild.rowByKey = { ["pinky freewood"] = { name = "Pinky Freewood" }, ["jinxer darktide"] = { name = "Jinxer Darktide" } }
Guild.rows = {}
local active, info = true, { activityIDs = { 799 } }
local leaderUnit, party = "player", { party1 = true }
_G.C_LFGList = {
    HasActiveEntryInfo = function() return active end,
    GetActiveEntryInfo = function() return info end,
    GetActivityFullName = function() return "Blackfathom-Tiefe" end,
    GetAvailableRoles = function() return false, false, true end,
}
_G.GetLFGRoles = function() return false, false, false, true end
_G.IsInGroup = function() return next(party) ~= nil end
_G.GetNumGroupMembers = function() local n = 1; for _ in pairs(party) do n = n + 1 end; return n end
_G.UnitExists = function(u) return u == "player" or party[u] == true end
_G.UnitGroupRolesAssigned = function(u) return u == "player" and "DAMAGER" or "DAMAGER" end
_G.UnitIsGroupLeader = function(u) return u == leaderUnit end
_G.SendChatMessage = function(t, ch) chat[#chat + 1] = ch .. ":" .. t end
assert(loadfile("GuildDungeon.lua"))("Freewood-Guild", NS)
local D = Guild.Dungeon
Guild.Share.startHooks[1]()
local function RunTasks()
    now = now + 40
    local t = tasks; tasks = {}
    for _, fn in ipairs(t) do pcall(fn) end
end

-- Kodierung mit Leiter und Namen, und zurueck
local m = { roles = { T = true }, size = 2, have = { T = 0, H = 0, D = 2 }, ids = { 799 }, label = "BDT", leader = true, members = { "Pinky Freewood", "Jinxer Darktide" } }
local enc = D.Encode(m)
eq(enc, "L|r=T;n=2;h=0.0.2;a=799;t=BDT;l=1;m=Pinky Freewood,Jinxer Darktide", "Kodierung mit Leiter und Namen")
local d = D.Decode(enc:sub(3))
eq(d.leader, true, "Leiter"); eq(#d.members, 2, "zwei Namen"); eq(d.memberKeys["jinxer darktide"], true, "Schluessel der Namen")
m.members = { string.rep("N", 120), string.rep("M", 120) }
eq(D.Encode(m):find(";m=", 1, true), nil, "zu lang: ohne Namen")
m.members = nil
eq(D.Encode(m):find(";m=", 1, true), nil, "ohne Mitglieder kein Feld")

-- Leiter (Pinky) mit Jinxer in der Gruppe: eine Meldung, eine Chatzeile mit beiden Namen
D.Update()
eq(#sent, 1, "Leiter meldet"); eq(sent[1]:find(";l=1", 1, true) ~= nil, true, "Leiter-Kennzeichen")
eq(sent[1]:find("m=Pinky Freewood,Jinxer Darktide", 1, true) ~= nil, true, "beide Gildenmitglieder genannt: " .. tostring(sent[1]))
eq(#chat, 1, "eine Chatzeile"); eq(chat[1], "GUILD:G2 Pinky Freewood, Jinxer Darktide|Blackfathom-Tiefe|Tank/Heiler/Schaden|2", "Chatzeile: " .. tostring(chat[1]))
-- Gruppe aendert sich (Fremder kommt dazu): Meldung ja, Chatzeile nein
party.party2 = true
now = now + 5
D.Update()
eq(#sent, 2, "Aenderung wird versteckt gemeldet"); eq(#chat, 1, "keine zweite Chatzeile bei Aenderung")
eq(sent[2]:find("n=3", 1, true) ~= nil, true, "neue Gruppenstaerke")
eq(sent[2]:find("Fremder", 1, true), nil, "Nicht-Gildenmitglied wird nicht genannt")
-- anderer Dungeon: neue Chatzeile
info = { activityIDs = { 800 } }
now = now + 70
D.Update()
eq(#chat, 2, "anderer Dungeon: neue Chatzeile")
-- Suche beendet
active = false
D.Update()
eq(sent[#sent], "L|x", "Ende gemeldet")

-- /reload bei laufender Suche: melden, aber keine Chatzeile
active, party.party2, info = true, nil, { activityIDs = { 799 } }
D.mine, D.reporting = nil, false
local chatBefore, sentBefore = #chat, #sent
now = now + 200
D.Update(true)
eq(#chat, chatBefore, "nach /reload keine Chatzeile"); eq(#sent, sentBefore + 1, "nach /reload wird gemeldet")
active = false; D.Update()

-- Nicht-Leiter (Jinxer leitet): schweigt zuerst, Liste zeigt sich selbst
leaderUnit, party = "party1", { party1 = true }
active = true
D.mine, D.reporting, D.list = nil, false, {}
chatBefore, sentBefore = #chat, #sent
D.Update()
eq(#sent, sentBefore, "Nicht-Leiter sendet nicht"); eq(#chat, chatBefore, "Nicht-Leiter schreibt nicht")
eq(D.Covered(), false, "noch von niemandem gemeldet")
-- Leiter hat das Addon nicht: nach der Wartezeit springt er ein (einmal)
RunTasks()
eq(#sent, sentBefore + 1, "eingesprungen: meldet"); eq(#chat, chatBefore + 1, "eingesprungen: eine Chatzeile")
eq(sent[#sent]:find(";l=1", 1, true), nil, "Einspringer ist kein Leiter")
-- Jetzt meldet doch der Leiter (Jinxer) die Gruppe: der Einspringer hoert auf
Guild.Share.handlers["L"]("jinxer darktide", "r=T;n=2;h=0.0.2;a=799;t=Blackfathom-Tiefe;l=1;m=Jinxer Darktide,Pinky Freewood", "GUILD", "Jinxer Darktide")
RunTasks()
eq(D.Covered(), true, "vom Leiter gemeldet")
eq(sent[#sent], "L|x", "Einspringer zieht seine Meldung zurueck"); eq(D.reporting, false, "meldet nicht mehr")
-- Liste: Gruppe einmal, mit beiden Namen
local list = D.List()
eq(#list, 1, "eine Zeile fuer die Gruppe"); eq(list[1].name, "Jinxer Darktide", "Melder ist der Leiter"); eq(#list[1].members, 2, "beide Namen in der Zeile")
-- Wartet der Nicht-Leiter noch, wenn der Leiter schon meldet: nichts gesendet
D.mine, D.reporting, D.fallback = nil, false, false
sentBefore = #sent
D.Update()
RunTasks()
eq(#sent, sentBefore, "Leiter meldet schon: kein Einspringen")

-- Zwei Einspringer gleichzeitig: nur einer bleibt (Vorrang nach Schluessel)
D.list = {}
D.mine = { leader = false }
local me = Guild.SelfKey()
D.list["aaa"] = { key = "aaa", at = now, memberKeys = { [me] = true, aaa = true }, leader = false }
D.list["zzz"] = { key = "zzz", at = now, memberKeys = { [me] = true, zzz = true }, leader = false }
eq(D.Beats({ key = "aaa" }, { key = "zzz" }), true, "kleinerer Schluessel gewinnt")
eq(D.Beats({ key = "zzz", leader = true }, { key = "aaa" }), true, "Leiter schlaegt Schluessel")
-- Meldung eines Fremdlings ohne mich in der Namensliste deckt mich nicht
D.list = { ["aaa"] = { key = "aaa", at = now, memberKeys = { aaa = true }, leader = true } }
eq(D.Covered(), false, "Meldung ohne mich deckt mich nicht")
-- veraltete Meldung deckt nicht mehr
D.list = { ["aaa"] = { key = "aaa", at = now - 1000, memberKeys = { [me] = true }, leader = true } }
eq(D.Covered(), false, "veraltete Meldung deckt nicht")

print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
