-- Test: Dungeon-Fenster (Zeilen, Anzeigeregeln, Klick) (texlua tests/dungwin_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.GetTime = function() return 1000 end
_G.time = function() return 6000 end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Freewood" end
_G.GetNormalizedRealmName = function() return "R" end
_G.GetRealmName = function() return "R" end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local printed = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print(t) printed[#printed + 1] = t end
function FW:RegisterEvent() end
FW.L.DUNG_WIN_SOLO, FW.L.DUNG_WIN_GROUP = "solo %s", "gruppe %d %s"
FW.L.DUNG_ROLE_T, FW.L.DUNG_ROLE_H, FW.L.DUNG_ROLE_D = "Tank", "Heiler", "Schaden"
_G.Freewood = FW
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
Guild.InGuild = function() return true end
Guild.Share = { handlers = {}, startHooks = {}, requestHooks = {}, sendAllHooks = {}, Queue = function() end, After = function() end }
Guild.rowByKey, Guild.rows = {}, {}
assert(loadfile("GuildDungeon.lua"))("Freewood-Guild", NS)
assert(loadfile("GuildDungeonWin.lua"))("Freewood-Guild", NS)
local W = Guild.DungeonWin
assert(W, "Modul da")
eq(Guild.Setting("dungWin"), true, "Standard: Fenster an")
eq(W.On(), true, "an")

-- Zeilen
local lines, more = W.Lines({
    { key = "a", name = "Anna", class = "PRIEST", label = "Todesminen", size = 1, roles = { H = true } },
    { key = "b", name = "Bob", label = "Wehklage", size = 3, roles = { T = true, H = true }, self = true },
})
eq(#lines, 2, "zwei Zeilen"); eq(more, 0, "nichts verborgen")
eq(lines[1].name, "Anna", "Name"); eq(lines[1].text, "solo Heiler", "Einzelsucher: " .. tostring(lines[1].text))
eq(lines[2].text, "gruppe 3 Tank/Heiler", "Gruppe: " .. tostring(lines[2].text)); eq(lines[2].self, true, "eigene Zeile")
local many = {}
for i = 1, 11 do many[i] = { key = "k" .. i, name = "N" .. i, label = "X", size = 1, roles = { D = true } } end
lines, more = W.Lines(many)
eq(#lines, 8, "hoechstens 8 Zeilen"); eq(more, 3, "drei weitere")
lines, more = W.Lines(nil)
eq(#lines, 0, "leer"); eq(more, 0, "leer: nichts verborgen")

-- Anzeigeregeln
eq(W.ShouldShow(0), false, "niemand sucht: zu")
eq(W.ShouldShow(2), true, "jemand sucht: offen")
W.Dismiss(2)
eq(W.ShouldShow(2), false, "mit X geschlossen: bleibt zu")
eq(W.ShouldShow(1), false, "weniger Leute: bleibt zu")
eq(W.ShouldShow(2), true, "Zahl sank und stieg wieder: jemand Neues, wieder offen")
W.Dismiss(2)
eq(W.ShouldShow(3), true, "neue Suche: wieder offen")
W.Dismiss(3)
eq(W.ShouldShow(0), false, "niemand: zu")
eq(W.ShouldShow(1), true, "nach leerer Liste wieder offen")
Guild.DB().settings.dungWin = false
eq(W.ShouldShow(5), false, "abgeschaltet: nie offen")
Guild.DB().settings.dungWin = true

-- Klick
local opened, invited = {}, {}
_G.ChatFrame_OpenChat = function(t) opened[#opened + 1] = t end
_G.C_PartyInfo = { InviteUnit = function(n) invited[#invited + 1] = n end }
eq(W.Click({ name = "Anna" }, "LeftButton"), true, "Linksklick")
eq(opened[1], "/w Anna ", "Fluestern geoeffnet")
eq(W.Click({ name = "Anna" }, "RightButton"), true, "Rechtsklick")
eq(invited[1], "Anna", "Einladung")
eq(W.Click({ name = "Ich", self = true }, "LeftButton"), false, "eigene Zeile: nichts")
eq(W.Click(nil, "LeftButton"), false, "keine Zeile")
_G.C_PartyInfo = nil
_G.InviteUnit = nil
eq(W.Click({ name = "Anna" }, "RightButton"), false, "ohne Einladefunktion: nichts")

-- Fenster mit Platzhalter-Oberflaeche: laeuft ohne Fehler durch
local function Proxy()
    return setmetatable({}, { __index = function() return function() return Proxy() end end })
end
FW.UI = Proxy()
FW.On = function() end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
assert(loadfile("GuildDungeonWin.lua"))("Freewood-Guild", NS)
W = Guild.DungeonWin
Guild.Dungeon.list = { a = { key = "a", name = "Anna", class = "PRIEST", label = "Todesminen", size = 1, roles = { H = true }, since = 1, at = 1000 } }
Guild.Dungeon.mine = nil
eq(pcall(W.Refresh), true, "Refresh ohne Fehler")
eq(pcall(W.ResetPos), true, "Position zuruecksetzen")
eq(Guild.DB().settings.dungWinPos, nil, "Position geloescht")
Guild.Dungeon.list = {}
eq(pcall(W.Refresh), true, "leere Liste ohne Fehler")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
