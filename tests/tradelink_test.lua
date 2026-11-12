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

-- Zweiter Weg: Shift+Klick im Zauberbuch (trade-Link ohne passende ID oder Zauberlink) zaehlt ueber die Beschriftung
local ALCH, ENCH = Guild.ProfName(171), Guild.ProfName(333)
local sp = T.Parse("|cff71d5ff|Hspell:2259:0|h[" .. ALCH .. "]|h|r")
eq(#sp, 1, "Zauberlink mit Berufsnamen zaehlt")
eq(sp[1].profId, 171, "Beruf aus dem Namen des Zauberlinks")
eq(sp[1].kind, "spell", "Typ spell")
eq(#T.Parse("|Hspell:133:0|h[Feuerball]|h"), 0, "anderer Zauber zaehlt nicht")
eq(#T.Parse("|Hitem:2589|h[" .. ALCH .. "]|h"), 0, "Item-Link mit Berufsnamen zaehlt nicht")
eq(#T.Parse("|Henchant:7418|h[" .. ENCH .. "]|h"), 1, "Verzauberlink mit Berufsnamen zaehlt")
local mixed = T.Parse("|Htrade:Player-1-ABC:2018:164|h[Schmiedekunst]|h und |Hspell:2259:0|h[" .. ALCH .. "]|h")
eq(#mixed, 2, "beide Wege in einer Zeile")
now = 300
Guild.DB().members["anna"] = nil
eq(T.Process("Anna", "|Hspell:2259:0|h[" .. ALCH .. "]|h"), 1, "Zauberlink eines Mitglieds gemeldet")
eq(Guild.DB().members["anna"].skills[171] ~= nil, true, "Beruf aus Zauberlink gemerkt")
-- Fehlersuche
printed = {}
T.debug = true
now = 310
T.Process("Anna", "|Hspell:2259:0|h[" .. ALCH .. "]|h")
eq(#printed >= 1 and printed[1]:find("Typ spell", 1, true) ~= nil, true, "Fehlersuche meldet Typ")
T.debug = false

-- Zauber-ID und Stufentext aus dem Link
eq(T.SpellId("trade:Player-6948-006B268F:4038:202"), 4038, "Zauber-ID (neue Form)")
eq(T.SpellId("trade:4038:300:375"), 4038, "Zauber-ID (alte Form)")
eq(T.SpellId("item:1"), nil, "kein Beruf-Link: keine Zauber-ID")
eq(T.SpellText(4038), nil, "ohne C_Spell nichts")
_G.C_Spell = { GetSpellName = function(id) return id == 4038 and "Ingenieurskunst" or nil end,
               GetSpellSubtext = function(id) return id == 4038 and "Experte" or "" end }
local nm, sub = T.SpellText(4038)
eq(nm, "Ingenieurskunst", "Name des Zaubers"); eq(sub, "Experte", "Stufentext")
local nm2, sub2 = T.SpellText(999)
eq(nm2, nil, "unbekannte ID: kein Name"); eq(sub2, nil, "unbekannte ID: kein Stufentext")
printed = {}
T.debug = true
now = 400
T.Process("Anna", "|Htrade:Player-6948-006B268F:4038:202|h[Ingenieurskunst]|h")
local joined = table.concat(printed, "\n")
eq(joined:find("Zauber 4038: Name Ingenieurskunst, Stufentext Experte", 1, true) ~= nil, true, "Fehlersuche zeigt Name und Stufentext")
T.debug = false
_G.C_Spell = nil

-- Liste
local list = T.List()
eq(#list, 1, "ein Mitglied in der Liste")
eq(list[1]:find("Anna") ~= nil, true, "Name in der Liste")
-- echte Daten ersetzen den Chat-Eintrag (wie Nachricht "P")
Guild.DB().members["anna"].skills = { [171] = { rank = 100, max = 150 } }
Guild.DB().members["anna"].stamp = 9
eq(#T.List(), 0, "mit echten Daten nicht mehr in der Liste")

-- Fremdes Berufefenster auslesen
Guild.Share = { ReadRecipes = function() return 185, { 1, 2, 3 } end }
eq(T.Read(), nil, "ohne C_TradeSkillUI nichts")
local events = {}
FW.RegisterEvent = function(_, ev, fn) events[ev] = fn end
_G.C_TradeSkillUI = {
    IsTradeSkillLinked = function() return true, "Weedo Cowking" end,
    IsTradeSkillGuildMember = function() return false end,
    IsTradeSkillGuild = function() return false end,
    GetAllRecipeIDs = function() return { 10, 11, 12, 13 } end,
    GetRecipeInfo = function(id) return { name = "R" .. id, learned = (id ~= 13) } end,
    GetBaseProfessionInfo = function() return { skillLevel = 250, maxSkillLevel = 300 } end,
}
Guild.rowByKey["weedo cowking"] = { name = "Weedo Cowking" }
local e = T.Read()
eq(e.name, "Weedo Cowking", "Name aus dem Fenster")
eq(e.total, 4, "gesamt"); eq(e.learned, 3, "gelernt"); eq(e.unmarked, 0, "alle markiert")
eq(e.skill, 250, "Rang"); eq(e.inGuild, true, "Gildenmitglied")
eq(type(T.Describe(e)), "string", "Beschreibung")
eq(T.Describe(e):find("Weedo Cowking") ~= nil, true, "Name in der Zeile")
printed = {}
now = 500
eq(T.Capture() ~= nil, true, "Probe geschrieben")
eq(#T.Log(), 1, "ein Eintrag"); eq(#printed, 1, "eine Zeile im Chat")
eq(T.Capture(), nil, "Wiederholung innerhalb 5 s ignoriert")
-- Gildenmitglied-Ansicht ohne Link
_G.C_TradeSkillUI.IsTradeSkillLinked = function() return false end
_G.C_TradeSkillUI.IsTradeSkillGuildMember = function() return true end
now = 600
eq(T.Capture() ~= nil, true, "Mitglieder-Ansicht erkannt")
-- eigenes Fenster
_G.C_TradeSkillUI.IsTradeSkillGuildMember = function() return false end
eq(T.Read(), nil, "eigenes Fenster: nichts")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
