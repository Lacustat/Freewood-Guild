-- Test: Gildenerfolge (Zaehlen, Teilen, Katalog, Auswertung, Hinweise) (texlua tests/ach_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

local now, clock = 1000000, 0
_G.time = function() return now end
_G.GetTime = function() return clock end
_G.GetLocale = function() return "enUS" end
_G.FreewoodGuildDB = nil
local locales = {}
local events, fired = {}, {}
local FW = { L = {}, Util = { IsSecret = function() return false end } }
function FW:RequireAPI() return true end
function FW:NewModule(_, o) return o end
function FW:Fire(e, ...) fired[#fired + 1] = e; for _, cb in ipairs(events[e] or {}) do cb(...) end end
function FW:On(e, fn) events[e] = events[e] or {}; table.insert(events[e], fn) end
local registered = {}
function FW:RegisterEvent(e, fn) registered[e] = fn end
function FW:AddLocale(code, t) locales[code] = locales[code] or {}; for k, v in pairs(t) do locales[code][k] = v end end
function FW:Print() end
_G.Freewood = FW
_G.SlashCmdList = {}
local NS = {}
assert(loadfile("Guild.lua"))("Freewood-Guild", NS)
local Guild = NS.Guild
-- Teilen stuetzen
local queued, tasks = {}, {}
local Share = { handlers = {}, startHooks = {}, requestHooks = {}, sendAllHooks = {},
    Queue = function(t) queued[#queued + 1] = t; return true end,
    After = function(s, fn) tasks[#tasks + 1] = fn end,
    Split = function(text, len) local o = {}; local i = 1; while i <= #text do o[#o + 1] = text:sub(i, i + len - 1); i = i + len end; return o end }
Guild.Share = Share
Guild.InGuild = function() return true end
assert(loadfile("GuildInst.lua"))("Freewood-Guild", NS)
assert(loadfile("GuildAchText.lua"))("Freewood-Guild", NS)
assert(loadfile("GuildAch.lua"))("Freewood-Guild", NS)
local Ach, Inst = Guild.Ach, Guild.Inst
FW.L = setmetatable({}, { __index = function(_, k) return locales.enUS[k] end })

-- Katalog
local cat = Ach.Catalog()
eq(#cat > 120, true, "viele Erfolge (" .. #cat .. ")")
local ids, total = {}, 0
for _, e in ipairs(cat) do
    eq(ids[e.id], nil, "Kennung eindeutig " .. e.id); ids[e.id] = true
    total = total + e.pts
    for _, spec in ipairs({ e.name, e.desc }) do
        eq(locales.enUS[spec[1]] ~= nil, true, "Text EN " .. spec[1])
        eq(locales.deDE[spec[1]] ~= nil, true, "Text DE " .. spec[1])
        local s = Ach.Text(spec)
        eq(s:find("%%") == nil, true, "Text ohne Platzhalter: " .. s)
    end
end
for _, c in ipairs(Ach.CATEGORIES) do eq(locales.enUS["ACHC_" .. c[1]] ~= nil and locales.deDE["ACHC_" .. c[1]] ~= nil, true, "Kategorie " .. c[1]) end
for k in pairs(locales.enUS) do eq(locales.deDE[k] ~= nil, true, "DE hat " .. k) end

-- Letzter Boss
local rfc, sm, strat = Inst.Get("RFC"), Inst.Get("SM"), Inst.Get("STRAT")
eq(Ach.IsFinal(rfc, "Bazzalan"), true, "letzter Boss RFC"); eq(Ach.IsFinal(rfc, "Oggleflint"), false, "kein letzter Boss")
eq(Ach.IsFinal(sm, "Herod"), true, "SM Herod"); eq(Ach.IsFinal(strat, "Balnazzar"), true, "STRAT Balnazzar")

-- Gildenliste: 3 Mitglieder, ich bin "pinky"
local db = Guild.DB()
Guild.rows = {
    { key = "pinky", name = "Pinky", level = 60, class = "HUNTER", race = "Orc", online = true, guid = "G1" },
    { key = "anna", name = "Anna", level = 42, class = "WARRIOR", race = "Troll", online = true, guid = "G2" },
    { key = "bob", name = "Bob", level = 10, class = "MAGE", race = "Tauren", online = false, guid = "G3" },
}
Guild.rowByKey = { pinky = Guild.rows[1], anna = Guild.rows[2], bob = Guild.rows[3] }
_G.UnitName = function() return "Pinky" end
_G.UnitFullName = function() return "Pinky", "Steel" end
_G.GetRealmName = function() return "Steel" end
_G.GetNormalizedRealmName = function() return "Steel" end
db.members.anna = { level = 42, played = 7200, skills = { [164] = { rank = 300, max = 300 }, [185] = { rank = 120, max = 300 } }, recipes = { [164] = { 1, 2, 3 } }, stamp = 1 }
db.members.bob = { level = 10, played = 3600 }
db.members.pinky = { level = 60, played = 36000, stamp = 1, kills = { RFC = { Bazzalan = true, Oggleflint = true } } }

-- Gruppe erkennen (ueber GUID)
local units = { party1 = { guid = "G2" }, party2 = { guid = "XX", name = "Bob" }, party3 = { guid = "ZZ", name = "Fremd" } }
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() return 4 end
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitIsUnit = function() return false end
_G.UnitGUID = function(u) return units[u] and units[u].guid end
local fullName = {}
_G.UnitFullName = function(u) if u == "player" then return "Pinky", "Steel" end return units[u] and units[u].name, nil end
eq(Ach.GroupGuildCount(), 3, "Gruppe: ich, Anna (GUID), Bob (Name)")

-- Boss besiegt mit 3 Gildenmitgliedern: Erfolg "Gemeinsam durch RFC"
eq(Ach.RecordKill("Ragefire Chasm", "Bazzalan", 3), true, "Kill gezaehlt")
eq(Ach.RecordKill("Ragefire Chasm", "Bazzalan", 3), false, "Doppelter Kill (Ereignis doppelt) ignoriert")
local g = db.members.pinky.g
eq(g.k[3], 1, "Zaehler 3"); eq(g.k[5], nil, "Zaehler 5 nicht"); eq(g.cl.RFC[3], now, "Durchlauf mit Zeit")
local res = Ach.Evaluate()
local byId = {}
for _, r in ipairs(res) do byId[r.entry.id] = r end
eq(byId.D3_RFC.done, true, "Erfolg RFC 3"); eq(byId.D3_RFC.who[1], "Pinky", "wer")
eq(byId.D5_RFC.done, false, "Erfolg RFC 5 offen"); eq(byId.D5_RFC.cur, 3, "beste Gruppe 3 von 5")
eq(byId.K3_10.cur, 1, "Boss-Zaehler")
-- Kontext
eq(byId.M_10.cur, 3, "Mitglieder"); eq(byId.L_60.done, true, "Stufe 60"); eq(byId.L60_3.cur, 1, "eine Person auf 60")
eq(byId.LS_250.cur, 112, "Stufensumme"); eq(byId.P_164.done, true, "Schmiedekunst Meister"); eq(byId.P_164.who[1], "Anna", "Meister Name")
eq(byId.P_185.done, false, "Kochen nicht auf 300"); eq(byId.RC_100.cur, 3, "Rezepte"); eq(byId.T_100.cur, 13, "Stunden")
eq(byId.V_C3.done, true, "3 Klassen"); eq(byId.V_R3.done, true, "3 Voelker"); eq(byId.O_10.cur, 2, "online")
eq(byId.C_RFC.cur, 2, "Gildenwissen RFC"); eq(byId.C_RFC.goal, 4, "Gildenwissen Ziel")
local got, tot, done, count = Ach.Points(res)
eq(got > 0 and got < tot, true, "Punkte"); eq(tot, total, "Gesamtpunkte"); eq(count, #cat, "Anzahl")

-- Teilen: Kodieren und Dekodieren
local text = Ach.Encode("pinky")
eq(text:match("^1,0,0,0;RFC%^3=%d+$") ~= nil, true, "Kodierung " .. text)
local back = Ach.Decode(text)
eq(back.k[3], 1, "Dekodiert Zaehler"); eq(back.cl.RFC[3], now, "Dekodiert Zeit")
eq(Ach.Decode("quatsch"), nil, "Muell abgelehnt")
eq(Ach.Decode("1,2,3,4;XYZ^3=5").cl.XYZ, nil, "unbekannte Instanz ignoriert")
-- Empfang
Share.handlers["E"]("anna", "1|1|" .. "2,1,0,0;DM^3=" .. (now - 100) .. ",5=" .. (now - 100))
eq(db.members.anna.g.cl.DM[5], now - 100, "Empfang gespeichert")
eq(Ach.Send(), true, "Senden"); eq(queued[1]:match("^E|1|1|") ~= nil, true, "Nachricht E")

-- Hinweise: erste Pruefung still (init fehlt), danach nur Neues
local toasts = {}
Ach.Notify = function(e) toasts[#toasts + 1] = e.id end
db.ach = nil
clock = 1000
local silent = Ach.Check()
eq(#toasts, 0, "erste Pruefung still"); eq(db.ach.init, nil, "noch nicht initialisiert (Startphase)")
-- Startphase vorbei
for _, h in ipairs(Share.startHooks) do pcall(h) end
clock = 5000
db.ach.init = true
db.members.anna.g.cl.STRAT = { [3] = now }                 -- frisch
db.members.anna.g.cl.ULD = { [3] = now - 5000 }            -- alt: nur still vermerkt
local fresh = Ach.Check()
local names = {}
for _, e in ipairs(fresh) do names[#names + 1] = e.id end
local joined = "," .. table.concat(names, ",") .. ","
eq(joined:find(",D3_STRAT,") ~= nil, true, "neuer Erfolg gemeldet")
eq(joined:find(",D3_ULD,") ~= nil, false, "alter Erfolg still")
eq(db.ach.done.D3_ULD ~= nil, true, "alter Erfolg vermerkt")
eq(#toasts, #fresh, "Hinweise je neuem Erfolg")
eq(#Ach.Check(), 0, "zweite Pruefung ohne Neues")
-- Hinweise aus
db.settings.achNotify = false
local c = #toasts
db.members.anna.g.cl.ZF = { [3] = now }
Ach.Check()
eq(#toasts, c, "bei ausgeschalteter Einstellung kein Fenster")
eq(db.ach.done.D3_ZF ~= nil, true, "trotzdem vermerkt")
eq(#db.ach.log >= 3, true, "Liste der letzten Erfolge")

-- Forever-Dungeons
local rol = Inst.Get("ROL")
eq(rol ~= nil and #rol.bosses == 7, true, "ROL vorhanden")
local ce, cb = Inst.Canon("Ruinen von Lordaeron", "Der Schlächter")
eq(ce and ce.id, "ROL", "Canon ROL (DE)"); eq(cb, "The Baron", "Schlaechter = Baron")
local _, cb2 = Inst.Canon("Ruins of Lordaeron", "Viktor der Üble"); eq(cb2, "Viktor the Vile", "Viktor DE")
eq(Ach.IsFinal(rol, "The Baron"), true, "ROL Endboss"); eq(Ach.IsFinal(Inst.Get("DAL"), "Shade of the Archmage"), true, "DAL Endboss")
local me0 = Guild.SelfKey()
Guild.DB().members[me0] = Guild.DB().members[me0] or {}
Guild.DB().members[me0].kills = { ["*Ruinen von Lordaeron"] = { ["Welkzahn"] = true, ["Der Schlächter"] = true } }
eq(Inst.MigrateDynamic(), true, "Migration")
local k = Guild.DB().members[me0].kills
eq(k["*Ruinen von Lordaeron"], nil, "alter Eintrag weg"); eq(k.ROL and k.ROL["Witherfang"] and k.ROL["The Baron"], true, "Kills uebernommen")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
