-- Test: eigener voller Name (Vor- und Nachname) und Zusammenfuehren alter Eintraege (texlua tests/self_test.lua)
local fails = 0
local function eq(a, b, m) if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Freewood" end
_G.GetNormalizedRealmName = function() return "ClassicBetaPvP2" end
_G.GetRealmName = function() return "Steel" end
_G.FreewoodGuildDB = nil
_G.SlashCmdList = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), Util = { IsSecret = function() return false end }, UI = nil }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire() end
_G.Freewood = FW
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
eq(Guild.SelfName(), "Pinky Freewood", "voller Name aus UnitFullName")
eq(Guild.SelfKey(), "pinky freewood", "Schluessel mit Nachname")
eq(Guild.Key("Pinky Freewood-Steel"), "pinky freewood", "Echo mit Realm Steel (GetRealmName)")
eq(Guild.Key("Pinky Freewood-ClassicBetaPvP2"), "pinky freewood", "Echo mit normalisiertem Realm")
eq(Guild.Key("Anna-Fremd"), "anna-fremd", "fremder Realm bleibt")
-- Zusammenfuehren
local db = Guild.DB()
db.members["pinky"] = { self = true, level = 19, kills = { RFC = { Oggleflint = true } } }
db.members["pinky freewood"] = { level = 18, kills = { RFC = { Bazzalan = true } }, gold = 5 }
db.fav = { account = {}, chars = { pinky = { groups = {} } } }
eq(Guild.MigrateSelf(), true, "Migration lief")
eq(db.members["pinky"], nil, "alter Eintrag weg")
local m = db.members["pinky freewood"]
eq(m.level, 18, "vorhandene Werte bleiben"); eq(m.gold, 5, "Gold bleibt")
eq(m.kills.RFC.Oggleflint, true, "Kills vereinigt (alt)"); eq(m.kills.RFC.Bazzalan, true, "Kills vereinigt (neu)")
eq(m.self, true, "Eigen-Markierung")
eq(db.fav.chars["pinky"], nil, "Favoriten umgezogen"); eq(db.fav.chars["pinky freewood"] ~= nil, true, "Favoriten neu")
eq(Guild.MigrateSelf(), false, "zweiter Lauf tut nichts")
print(fails == 0 and "OK" or (fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
