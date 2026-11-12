-- Test: Berufe-Links aus dem Chat (texlua tests/tradelink_test.lua)
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
local events = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print(t) printed[#printed + 1] = t end
function FW:RegisterEvent(ev, fn) events[ev] = fn end
_G.Freewood = FW
local filters = {}
_G.ChatFrame_AddMessageEventFilter = function(ev, fn) filters[ev] = fn end
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
Guild.Share = { ReadRecipes = function() return 164, { 1, 2, 3 } end }
assert(loadfile("GuildTradeLink.lua"))("Freewood-Guild", NS)
local T = Guild.TradeLink

eq(filters["CHAT_MSG_GUILD"] ~= nil and filters["CHAT_MSG_WHISPER"] ~= nil, true, "Filter fuer Gilde und Fluestern")

-- Parser
local msg = "schaut: |cffffd000|Htrade:Player-1-ABC:2018:164|h[Schmiedekunst]|h|r und |Htrade:2018:300:375:0x1:AAA|h[Kochkunst]|h"
local l = T.Parse(msg)
eq(#l, 2, "zwei Links")
eq(l[1].link, "trade:Player-1-ABC:2018:164", "Link 1")
eq(l[1].label, "Schmiedekunst", "Name ohne Klammern")
eq(l[2].link, "trade:2018:300:375:0x1:AAA", "Link 2 (alte Form)")
eq(#T.Parse("kein Link |Hitem:123|h[x]|h"), 0, "Item-Link zaehlt nicht")
eq(#T.Parse(nil), 0, "nil")

-- Gildenmitglied
Guild.rowByKey = { ["anna"] = { name = "Anna" } }
local got = {}
T.AddHook(function(info) got[#got + 1] = info end)
eq(T.Process("Anna", msg), 2, "Mitglied: zwei Meldungen")
eq(got[1].name, "Anna", "Name")
eq(got[1].known, false, "noch nicht erfasst")
eq(got[1].text, "|Htrade:Player-1-ABC:2018:164|h[Schmiedekunst]|h", "Text zum Oeffnen")
-- Doppelte Zeile (zweites Chatfenster)
eq(T.Process("Anna", msg), 0, "gleiche Zeile sofort nochmal: nichts")
now = 110
eq(T.Process("Anna", msg), 2, "spaeter wieder")
-- kein Mitglied / selbst
eq(T.Process("Fremder", msg), 0, "Nicht-Mitglied")
Guild.rowByKey["pinky freewood"] = {}
eq(T.Process("Pinky Freewood", msg), 0, "eigener Link")
-- schon erfasst
local profId = Guild.ProfByName("Schmiedekunst") or Guild.ProfByName("Blacksmithing")
if profId then
    Guild.DB().members["anna"] = { recipes = { [profId] = { 1, 2 } } }
    now = 130
    got = {}
    T.Process("Anna", msg)
    eq(got[1].known, true, "erfasst: known")
end

-- Filter stoert den Text nicht
eq(filters["CHAT_MSG_GUILD"](nil, "CHAT_MSG_GUILD", msg, "Anna"), false, "Filter gibt false zurueck")

-- Auslesen
eq(T.Read(), nil, "ohne C_TradeSkillUI nichts")
_G.C_TradeSkillUI = {
    IsTradeSkillLinked = function() return true, "Anna" end,
    IsTradeSkillGuild = function() return false end,
    GetAllRecipeIDs = function() return { 10, 11, 12, 13 } end,
    GetRecipeInfo = function(id) return { name = "R" .. id, learned = (id ~= 13) and true or false } end,
    GetBaseProfessionInfo = function() return { skillLevel = 250, maxSkillLevel = 300 } end,
}
local e = T.Read()
eq(e.name, "Anna", "gelesener Name")
eq(e.total, 4, "gesamt")
eq(e.learned, 3, "gelernt laut Share")
eq(e.unmarked, 0, "alle markiert")
eq(e.skill, 250, "Rang")
eq(e.member, true, "Mitglied")
eq(#e.samples, 3, "Beispiele")
eq(type(T.Describe(e)), "string", "Beschreibung")
-- Ereignis
now = 200
events["TRADE_SKILL_SHOW"]()
eq(#T.Log(), 1, "ein Probeeintrag")
eq(#printed, 1, "eine Zeile im Chat")
events["TRADE_SKILL_LIST_UPDATE"]()
eq(#T.Log(), 1, "Wiederholung innerhalb 5 s ignoriert")
-- ausgeschaltet
Guild.DB().settings.tradeProbe = false
now = 300
events["TRADE_SKILL_SHOW"]()
eq(#T.Log(), 1, "ausgeschaltet: nichts")
-- nicht verlinkt
Guild.DB().settings.tradeProbe = true
_G.C_TradeSkillUI.IsTradeSkillLinked = function() return false end
eq(T.Read(), nil, "eigenes Fenster: nichts")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
