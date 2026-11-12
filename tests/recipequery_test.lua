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
_G.C_GuildInfo = { QueryGuildMembersForRecipe = function(skill, rid, lvl)
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
-- Antwort
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()
eq(#queried, 2, "zweite Abfrage nach Antwort")
local joined = table.concat(printed, "\n")
eq(joined:find("2 Mitglieder, 1 online") ~= nil, true, "Ergebnis mit Anzahl und online")
eq(joined:find("Anna, Bob %(offline%)") ~= nil, true, "Namen")
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()   -- Rezept 12
events["GUILD_RECIPE_KNOWN_BY_MEMBERS"]()   -- Rezept 13 wird abgelehnt, 14 wartet
eq(#queried >= 4, true, "weiter bis zum Ende")
joined = table.concat(printed, "\n")
eq(joined:find("abgelehnt") ~= nil, true, "abgelehnte Abfrage gemeldet")
-- Zeitueberschreitung
for _, fn in ipairs(timers) do fn() end
-- Log gespeichert
eq(#Q.Log() > 0, true, "Log gespeichert")
-- kein Fenster
open = false
printed = {}
eq(Q.Run(), false, "ohne Berufefenster")
eq(table.concat(printed, "\n"):find("erst den eigenen Beruf") ~= nil, true, "Hinweis Fenster oeffnen")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
