-- Test: Berufe aus Chat-Links merken (texlua tests/tradelink_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Freewood" end
_G.GetNormalizedRealmName = function() return "Steel" end
_G.GetRealmName = function() return "Steel" end
local now = 100
_G.GetTime = function() return now end
_G.time = function() return 1234 end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local printed = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print(t) printed[#printed + 1] = t end
function FW:RegisterEvent() end
_G.Freewood = FW
local filters = {}
_G.ChatFrame_AddMessageEventFilter = function(ev, fn) filters[ev] = fn end
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
local changed = 0
Guild.Changed = function() changed = changed + 1 end
assert(loadfile("GuildTradeLink.lua"))("Freewood-Guild", NS)
local T = Guild.TradeLink

eq(filters["CHAT_MSG_GUILD"] ~= nil and filters["CHAT_MSG_WHISPER"] ~= nil, true, "Filter fuer Gilde und Fluestern")

-- Beruf-ID aus dem Link (echte Linkdaten vom Client)
eq(T.SkillLine("trade:Player-6940-0130E476:3909:197"), 197, "Schneiderei")
eq(T.SkillLine("trade:Player-6940-005B0A4D:3811:165"), 165, "Lederverarbeitung")
eq(T.SkillLine("trade:2018:300:375:0x1:AAA"), nil, "alte Form ohne ID")
eq(T.SkillLine("trade:Player-1-ABC:2018:99999"), nil, "unbekannte ID")
eq(T.SkillLine("item:123"), nil, "kein Beruf-Link")

local msg = "|cffffd000|Htrade:Player-6940-0130E476:3909:197|h[Schneiderei]|h|r"
local l = T.Parse(msg)
eq(#l, 1, "ein Link")
eq(l[1].profId, 197, "Beruf aus ID")
l = T.Parse("|Htrade:xyz|h[Kochkunst]|h")
eq(l[1].profId, Guild.ProfByName("Kochkunst"), "Beruf aus Name, wenn die ID fehlt")
eq(#T.Parse("kein Link |Hitem:123|h[x]|h"), 0, "Item-Link zaehlt nicht")
eq(#T.Parse(nil), 0, "nil")

-- Gildenmitglied ohne Addon: Beruf wird gemerkt
Guild.rowByKey = { ["anna"] = { name = "Anna" }, ["bob"] = { name = "Bob" } }
local got = {}
T.AddHook(function(info) got[#got + 1] = info end)
eq(T.Process("Anna", msg), 1, "Mitglied gemeldet")
local rec = Guild.DB().members["anna"]
eq(rec and rec.skills[197] and rec.skills[197].chat, true, "Beruf mit Chat-Markierung")
eq(rec.skills[197].rank, 0, "Stufe unbekannt = 0")
eq(got[1].profId, 197, "Haken bekommt die Beruf-ID")
eq(changed, 1, "Oberflaeche wird aktualisiert")
eq(T.Process("Anna", msg), 0, "gleiche Zeile sofort nochmal: nichts")
now = 110
eq(T.Process("Anna", msg), 1, "spaeter wieder gemeldet")
eq(changed, 1, "kein neuer Eintrag, keine Aktualisierung")
-- zweiter Beruf kommt dazu
now = 120
T.Process("Anna", "|Htrade:Player-6940-0130E476:3811:165|h[Lederverarbeitung]|h")
eq(rec.skills[165] ~= nil and rec.skills[197] ~= nil, true, "beide Berufe")

-- Mitglied mit Addon (hat Profil): nichts ueberschreiben
Guild.DB().members["bob"] = { stamp = 5, skills = { [164] = { rank = 300, max = 300 } } }
now = 130
T.Process("Bob", msg)
eq(Guild.DB().members["bob"].skills[197], nil, "Addon-Daten bleiben unberuehrt")

-- kein Mitglied / selbst
now = 140
eq(T.Process("Fremder", msg), 0, "Nicht-Mitglied")
Guild.rowByKey["pinky freewood"] = {}
eq(T.Process("Pinky Freewood", msg), 0, "eigener Link")
eq(Guild.DB().members["fremder"], nil, "Fremder nicht gespeichert")

-- Filter: Text bleibt, Einstellung schaltet ab
now = 150
Guild.DB().settings.tradeChat = false
Guild.DB().members["anna"] = nil
eq(filters["CHAT_MSG_GUILD"](nil, "CHAT_MSG_GUILD", msg, "Anna"), false, "Filter gibt false zurueck")
eq(Guild.DB().members["anna"], nil, "ausgeschaltet: nichts gemerkt")
Guild.DB().settings.tradeChat = true
now = 160
filters["CHAT_MSG_GUILD"](nil, "CHAT_MSG_GUILD", msg, "Anna")
eq(Guild.DB().members["anna"] ~= nil, true, "eingeschaltet: gemerkt")

-- Liste
local list = T.List()
eq(#list, 1, "ein Mitglied in der Liste")
eq(list[1]:find("Anna") ~= nil, true, "Name in der Liste")
-- echte Daten ersetzen den Chat-Eintrag (wie Nachricht "P")
Guild.DB().members["anna"].skills = { [171] = { rank = 100, max = 150 } }
Guild.DB().members["anna"].stamp = 9
eq(#T.List(), 0, "mit echten Daten nicht mehr in der Liste")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
