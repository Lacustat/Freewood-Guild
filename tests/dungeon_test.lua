-- Test: Dungeon-Browser (Nachricht, Vorschlag, Annehmen, Lesen der eigenen Suche) (texlua tests/dungeon_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
local now = 1000
_G.GetTime = function() return now end
_G.time = function() return 5000 + now end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Freewood" end
_G.GetNormalizedRealmName = function() return "R" end
_G.GetRealmName = function() return "R" end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local sent, printed, chat, accepted = {}, {}, {}, 0
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print(t) printed[#printed + 1] = t end
local events = {}
function FW:RegisterEvent(ev, fn) events[ev] = fn end
FW.L.DUNG_CHAT_SOLO = "%s|%s|%s"
FW.L.DUNG_CHAT_GROUP = "%s|%s|%s|%d"
FW.L.DUNG_ROLE_T, FW.L.DUNG_ROLE_H, FW.L.DUNG_ROLE_D = "Tank", "Heiler", "Schaden"
_G.Freewood = FW
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
Guild.InGuild = function() return true end
local tasks = {}
Guild.Share = { handlers = {}, startHooks = {}, requestHooks = {}, sendAllHooks = {},
    Queue = function(t) sent[#sent + 1] = t end, After = function(s, fn) tasks[#tasks + 1] = fn end }
Guild.rowByKey = {}
Guild.rows = {}
-- Stand des Spiels
local active, info, roles, grp = true, { activityIDs = { 799 } }, { false, false, false, true }, nil
_G.C_LFGList = {
    HasActiveEntryInfo = function() return active end,
    GetActiveEntryInfo = function() return info end,
    GetActivityFullName = function(id) return id == 799 and "Todesminen" or "Wehklage" end,
    GetAvailableRoles = function() return false, false, true end,
}
_G.GetLFGRoles = function() return unpack(roles) end
_G.IsInGroup = function() return grp ~= nil end
_G.GetNumGroupMembers = function() return grp and #grp or 0 end
_G.UnitExists = function(u) if u == "player" then return grp ~= nil end local i = tonumber(u:match("party(%d)")); return grp and grp[i + 1] ~= nil end
_G.UnitGroupRolesAssigned = function(u) local i = (u == "player") and 1 or (tonumber(u:match("party(%d)")) + 1); return grp[i] end
_G.SendChatMessage = function(t, ch) chat[#chat + 1] = ch .. ":" .. t end
_G.AcceptGroup = function() accepted = accepted + 1 end
assert(loadfile("GuildDungeon.lua"))("Freewood-Guild", NS)
local D = Guild.Dungeon
Guild.Share.startHooks[1]()
-- Nachricht
local m = { roles = { T = true, D = true }, size = 1, have = { T = 0, H = 0, D = 1 }, ids = { 799, 800 }, label = "Todes;minen" }
local enc = D.Encode(m)
eq(enc, "L|r=TD;n=1;h=0.0.1;a=799,800;t=Todes minen", "Kodierung")
local d = D.Decode(enc:sub(3))
eq(d.roles.T, true, "Rolle T"); eq(d.roles.H, nil, "Rolle H nicht"); eq(d.have.D, 1, "vorhanden D"); eq(#d.ids, 2, "zwei Aktivitaeten"); eq(d.label, "Todes minen", "Name")
eq(D.Decode("kaputt"), nil, "kaputte Nachricht")
-- Eigene Suche lesen (allein, Schaden)
local cur = D.ReadSelf()
eq(D.RoleString(cur.roles), "D", "allein: Schaden")
eq(cur.label, "Todesminen", "Dungeon-Name")
eq(cur.size, 1, "allein")
-- Update: sendet versteckt + Chat
D.Update()
eq(#sent, 1, "eine versteckte Nachricht"); eq(chat[1], "GUILD:Pinky|Todesminen|Schaden", "Zeile im Gildenchat")
D.Update()
eq(#sent, 1, "unveraendert: keine zweite Nachricht")
-- Suche beendet
active = false
D.Update()
eq(sent[#sent], "L|x", "Ende gemeldet"); eq(D.mine, nil, "Stand leer")
-- Gruppe: Pinky (Schaden) + Tank + Schaden -> es fehlen Heiler und Schaden
active, grp = true, { "DAMAGER", "TANK", "DAMAGER" }
cur = D.ReadSelf()
eq(cur.size, 3, "Gruppe 3"); eq(D.RoleString(cur.roles), "HD", "fehlt Heiler und Schaden")
eq(cur.have.T, 1, "Tank vorhanden"); eq(cur.have.D, 2, "Schaden vorhanden")
grp = nil
-- Empfangen
Guild.Share.handlers["L"]("anna", "r=H;n=1;h=0.0.0;a=799;t=Todesminen", "GUILD", "Anna")
Guild.Share.handlers["L"]("bob", "r=T;n=1;h=0.0.0;a=799;t=Todesminen", "GUILD", "Bob")
Guild.Share.handlers["L"]("cem", "r=DT;n=1;h=0.0.0;a=799;t=Todesminen", "WHISPER", "Cem")
eq(D.list["cem"], nil, "Fluestern wird ignoriert")
active = false; D.Update(); D.mine = nil
local list = D.List()
eq(#list, 2, "zwei Sucher")
-- Vorschlag: Tank Bob, Heiler Anna, 3 Schaden fehlen
local groups = D.SuggestByLabel(list)
eq(#groups, 1, "ein Dungeon")
local plan = groups[1].plan
eq(plan.T.name, "Bob", "Tank Bob"); eq(plan.H.name, "Anna", "Heiler Anna"); eq(#plan.D, 0, "kein Schaden")
eq(#plan.missing, 3, "fehlt 3x Schaden"); eq(plan.count, 2, "zwei Spieler")
-- Mehrfachrollen: Cem (T,D), Dora (D), Eli (D), Fox (H)
Guild.Share.handlers["L"]("cem", "r=TD;n=1;h=0.0.0;a=799;t=Wehklage", "GUILD", "Cem")
Guild.Share.handlers["L"]("dora", "r=D;n=1;h=0.0.0;a=799;t=Wehklage", "GUILD", "Dora")
Guild.Share.handlers["L"]("eli", "r=D;n=1;h=0.0.0;a=799;t=Wehklage", "GUILD", "Eli")
Guild.Share.handlers["L"]("fox", "r=H;n=1;h=0.0.0;a=799;t=Wehklage", "GUILD", "Fox")
Guild.Share.handlers["L"]("gus", "r=D;n=1;h=0.0.0;a=799;t=Wehklage", "GUILD", "Gus")
local p2
for _, g in ipairs(D.SuggestByLabel(D.List())) do if g.label == "Wehklage" then p2 = g.plan end end
eq(p2.count, 5, "volle Gruppe"); eq(#p2.missing, 0, "nichts fehlt")
eq(p2.T.name, "Cem", "Tank mit Mehrfachrolle"); eq(#p2.D, 3, "drei Schaden")
-- Annehmen: nur bei laufender Suche, nur Gilde/Freunde, nur mit Haken
Guild.rowByKey["jinxer darktide"] = { name = "Jinxer Darktide" }
Guild.DB().settings.dungAutoGuild = true
active, grp = true, nil
D.Update()
events["PARTY_INVITE_REQUEST"](nil, "Jinxer Darktide")
eq(accepted, 1, "Gildeneinladung angenommen")
events["PARTY_INVITE_REQUEST"](nil, "Fremder Spieler")
eq(accepted, 1, "Fremder nicht")
Guild.DB().settings.dungAutoGuild = false
events["PARTY_INVITE_REQUEST"](nil, "Jinxer Darktide")
eq(accepted, 1, "ohne Haken nicht")
Guild.DB().settings.dungAutoGuild = true
active = false; D.Update()
events["PARTY_INVITE_REQUEST"](nil, "Jinxer Darktide")
eq(accepted, 1, "ohne laufende Suche nicht")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
