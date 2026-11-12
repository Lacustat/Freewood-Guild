-- Test: Gilden-Rezeptabfrage (texlua tests/recipequery_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Freewood" end
_G.GetNormalizedRealmName = function() return "Steel" end
_G.GetRealmName = function() return "Steel" end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local printed, events, timers = {}, {}, {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
function FW:Print(t) printed[#printed + 1] = t end
function FW:RegisterEvent(ev, fn) events[ev] = fn end
_G.Freewood = FW
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
Guild.InGuild = function() return true end
assert(loadfile("GuildRecipeQuery.lua"))("Freewood-Guild", NS)
local Q = Guild.RecipeQuery

-- ohne Funktionen
local lines, all = Q.Availability()
eq(all, false, "ohne Funktionen: nicht alles da")
eq(Q.Run(), false, "Run ohne Funktionen")
eq(printed[#printed]:find("nicht moeglich") ~= nil, true, "Meldung nicht moeglich")

-- mit Funktionen
local queried, cur = {}, nil
_G.C_GuildInfo = { GetGuildRecipesX = function() end, QueryGuildMembersForRecipe = function(skill, rid, lvl)
    queried[#queried + 1] = rid
    if rid == 13 then return nil end   -- abgelehnt
    cur = { skill, rid }
    return rid
end }
_G.GetGuildRecipeInfoPostQuery = function() return cur[1], cur[2], 2 end
_G.GetGuildRecipeMember = function(i) return i == 1 and "Anna" or "Bob", "Full", "MAGE", i == 1 end
_G.C_Timer = { After = function(s, fn) timers[#timers + 1] = fn end }
local open = true
_G.C_TradeSkillUI = {
    IsTradeSkillGuild = function() return false end,
    IsTradeSkillLinked = function() return false end,
    GetBaseProfessionInfo = function() if open then return { professionID = 164, professionName = "Schmiedekunst" } end end,
    GetAllRecipeIDs = function() return { 10, 11, 12, 13, 14, 15 } end,
    GetRecipeInfo = function(id) return { name = "R" .. id, learned = id <= 12 } end,
}
printed = {}
eq(Q.Run(), true, "Run laeuft")
eq(#queried, 1, "erste Abfrage gesendet")
local scanned = table.concat(printed, "\n")
eq(scanned:find("Gilde/Beruf%-Funktionen") ~= nil, true, "Funktionsliste")
-- Antwort
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()
eq(#queried, 2, "zweite Abfrage (gleiches Rezept, Stufe 0) nach Antwort")
local joined = table.concat(printed, "\n")
eq(joined:find("2 Mitglieder, 1 online") ~= nil, true, "Ergebnis mit Anzahl und online")
eq(joined:find("Ereignis GUILD_RECIPE_KNOWN_BY_MEMBERS") ~= nil, true, "Ereignis mitgeschrieben")
eq(joined:find("Anna, Bob %(offline%)") ~= nil, true, "Namen")
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()   -- Rezept 12
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()   -- Rezept 13 folgt
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()   -- 13 wird abgelehnt, 14 wartet
eq(#queried >= 4, true, "weiter bis zum Ende")
joined = table.concat(printed, "\n")
eq(joined:find("abgelehnt") ~= nil, true, "abgelehnte Abfrage gemeldet")
-- Zeitueberschreitung
for _, fn in ipairs(timers) do fn() end
eq(table.concat(printed, "\n"):find("keine Antwort") ~= nil, true, "Zeitueberschreitung gemeldet")
-- Log gespeichert
eq(#Q.Log() > 0, true, "Log gespeichert")
-- kein Fenster
open = false
printed = {}
eq(Q.Run(), false, "ohne Berufefenster")
eq(table.concat(printed, "\n"):find("erst den eigenen Beruf") ~= nil, true, "Hinweis Fenster oeffnen")

-- Alte Gilden-Berufsliste
printed, timers = {}, {}
_G.QueryGuildRecipes = function() end
_G.GetNumGuildTradeSkill = function() return 2 end
local expandedSet, expanded = {}, false
_G.ExpandGuildTradeSkillHeader = function(i) expandedSet[i] = true; expanded = true end
_G.GetGuildTradeSkillInfo = function(i) return 164, not expandedSet[i], "icon", "Schmiedekunst", 3, 3, 3, "Anna", "MAGE", true end
_G.CanViewGuildRecipes = function(id) return id == 164 end
local zeroCalled, filterCalled = false, false
_G.CollapseGuildTradeSkillHeader = function() end
_G.SetGuildTradeSkillItemNameFilter = function() filterCalled = true end
_G.SetGuildTradeSkillCategoryFilter = function() end
local baseExpand = _G.ExpandGuildTradeSkillHeader
_G.ExpandGuildTradeSkillHeader = function(i) if i == 0 then zeroCalled = true end baseExpand(i) end
eq(Q.RunBoard(), true, "Berufsliste gestartet")
local ti = 1
while timers[ti] do timers[ti](); ti = ti + 1 end
local pj = table.concat(printed, "\n")
eq(pj:find("2 Eintraege") ~= nil, true, "Anzahl Eintraege")
eq(expanded, true, "Ueberschriften aufgeklappt")
eq(pj:find("Ueberschriften aufgeklappt: 2") ~= nil, true, "Anzahl aufgeklappt gemeldet")
eq(pj:find("1: 164, false, icon, Schmiedekunst") ~= nil, true, "Eintrag mit Rohwerten (nach dem Aufklappen)")
eq(zeroCalled, true, "Expand(0) versucht")
eq(filterCalled, true, "Filter versucht")
eq(pj:find("Zeilen hinter der Anzahl", 1, true) ~= nil, true, "Zeilen hinter der Anzahl geprueft")
eq(pj:find("Weitere Versuche beendet", 1, true) ~= nil, true, "Versuche beendet")
eq(pj:find("CanViewGuildRecipes ja fuer: " .. Guild.ProfName(164), 1, true) ~= nil, true, "CanView")
_G.QueryGuildRecipes = nil
printed = {}
eq(Q.RunBoard(), false, "ohne Funktion")

-- Rezepte eines Mitglieds
Guild.rowByKey = { ["weedo cowking"] = { name = "Weedo Cowking", key = "weedo cowking", guid = "Player-1-ABC", online = true } }
Guild.Row = function(n) return Guild.rowByKey[Guild.Key(n) or ""] end
local called
_G.C_GuildInfo.QueryGuildMemberRecipes = function(guid, skill) called = { guid, skill } end
printed = {}
eq(Q.MemberRecipes("weedo cowking kochen"), true, "Mitglied abgefragt")
eq(called and called[1], "Player-1-ABC", "GUID uebergeben")
eq(called and called[2], Guild.ProfByName("Kochen"), "Beruf-ID uebergeben")
eq(Q.MemberRecipes("Weedo Cowking 185"), true, "mit Zahl")
eq(Q.MemberRecipes("Niemand kochen"), false, "unbekanntes Mitglied")
eq(Q.MemberRecipes("Weedo Cowking quatsch"), false, "unbekannter Beruf")
eq(Q.MemberRecipes(""), false, "ohne Angaben")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
