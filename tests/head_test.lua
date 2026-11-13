-- Test fuer GuildHead.lua: Symbol ueber dem Kopf von Gildenmitgliedern (texlua tests/head_test.lua)
local function Proxy()
    local o = { _pts = {} }
    return setmetatable(o, { __index = function(t, k)
        return function(self, ...)
            if k == "SetPoint" then self._pts[#self._pts + 1] = { ... } end
            if k == "ClearAllPoints" then self._pts = {} end
            if k == "Show" then rawset(self, "shown", true) end
            if k == "Hide" then rawset(self, "shown", false) end
            if k == "SetSize" then rawset(self, "size", ...) end
            if k == "SetAlpha" then rawset(self, "alpha", ...) end
            if k == "SetTexture" then rawset(self, "texture", ...) end
            if k == "CreateTexture" then local x = Proxy(); rawset(self, "tex", x); return x end
            return Proxy()
        end
    end })
end
local events = {}
_G.CreateFrame = function(_, _, parent)
    local f = Proxy()
    f.RegisterEvent = function() end
    f.SetScript = function(self, name, fn) events[name] = fn end
    f.parent = parent
    return f
end
local units = {}
local plates = {}
local function MakePlate(token)
    local p = Proxy()
    p.namePlateUnitToken = token
    p.UnitFrame = Proxy()
    plates[token] = p
    return p
end
local cvars = { nameplateShowFriends = "0" }
local setCalls = {}
_G.UnitExists = function(u) return units[u] ~= nil end
_G.UnitIsPlayer = function(u) return units[u] and units[u].player end
_G.UnitIsUnit = function(u, v) return units[u] and v == "player" and units[u].me or false end
_G.UnitCanAttack = function() return false end
_G.UnitName = function(u) return units[u].name end
_G.GetGuildInfo = function() return nil end
local combat, instance = false, false
_G.InCombatLockdown = function() return combat end
_G.IsInInstance = function() return instance, instance and "party" or "none" end
_G.hooksecurefunc = function() end
_G.GetCVar = function(n) return cvars[n] end
_G.SetCVar = function(n, v) cvars[n] = v; setCalls[#setCalls + 1] = n .. "=" .. v end
_G.C_NamePlate = {
    GetNamePlateForUnit = function(u) return plates[u] end,
    GetNamePlates = function() local o = {}; for _, p in pairs(plates) do o[#o + 1] = p end; return o end,
}
local settings = { headShow = true, headSize = 28, headPlates = true }
local Guild = {
    Setting = function(k) return settings[k] end,
    DB = function() return { settings = settings } end,
    Key = function(n) return n and n:lower() end,
    rowByKey = { anna = { rankIndex = 3 }, boss = { rankIndex = 0 }, me = { rankIndex = 1 } },
}
_G.Freewood = { Util = { IsSecret = function() return false end } }
assert(loadfile("GuildHead.lua"))("Freewood-Guild", { Guild = Guild })
local Head = Guild.Head
assert(Head)

units.nameplate1 = { player = true, name = "Anna" }
units.nameplate2 = { player = true, name = "Boss" }
units.nameplate3 = { player = true, name = "Me", me = true }
units.nameplate4 = { player = true, name = "Fremder" }
units.nameplate5 = { player = false, name = "Wolf" }
for i = 1, 5 do MakePlate("nameplate" .. i) end

assert(Head.Classify("nameplate1") == "member")
assert(Head.Classify("nameplate2") == "master")
assert(Head.Classify("nameplate3") == nil, "eigener Charakter bekommt kein Symbol")
assert(Head.Classify("nameplate4") == nil, "kein Gildenmitglied")
assert(Head.Classify("nameplate5") == nil, "kein Spieler")

-- Frische Installation: Spieleinstellung wird einmal eingeschaltet
Head.Apply()
assert(cvars.nameplateShowFriends == "1", "Plaketten einmal eingeschaltet")
assert(settings.plateInit == true and settings.headPlates == true, "gleichgeschaltet")
local calls0 = #setCalls
Head.UpdateAll()
assert(Head.Update("nameplate1") == "member")
assert(Head.Update("nameplate2") == "master")
assert(Head.Update("nameplate3") == nil)
assert(Head.Update("nameplate4") == nil)
-- Standard (Lebensbalken zeigen = an): Plakette bleibt sichtbar
assert(plates.nameplate4.UnitFrame.alpha ~= 0, "Standard: Plakettenbild bleibt sichtbar")
-- Lebensbalken aus: Plakettenbild freundlicher Spieler wird ausgeblendet
settings.headBars = false
Head.Update("nameplate4")
assert(plates.nameplate4.UnitFrame.alpha == 0, "Plakettenbild ausgeblendet")
-- In Instanzen: Blizzard-Standard, nichts ausblenden, Symbol bleibt
instance = true
Head.Update("nameplate4")
assert(plates.nameplate4.UnitFrame.alpha == 1, "Instanz: Plakettenbild bleibt")
assert(Head.Update("nameplate1") == "member", "Instanz: Symbol bleibt")
settings.headInst = false
assert(Head.Update("nameplate1") == nil, "Instanz: Symbol per Einstellung aus")
settings.headInst = true
instance = false
assert(Head.Update("nameplate1") == "member", "ausserhalb: Symbol wieder da")
settings.headBars = true
Head.Update("nameplate4")
assert(plates.nameplate4.UnitFrame.alpha == 1, "wieder sichtbar: " .. tostring(plates.nameplate4.UnitFrame.alpha))
-- Groesse
settings.headSize = 40
assert(Head.Size() == 40)
-- Symbol aus: kein Symbol, Spieleinstellung bleibt unberuehrt
settings.headShow = false
Head.Apply()
assert(Head.Update("nameplate1") == nil, "aus: kein Symbol")
assert(cvars.nameplateShowFriends == "1", "Spieleinstellung bleibt")
assert(#setCalls == calls0, "keine Schreibzugriffe durch headShow")
settings.headShow = true

-- Spieler schaltet die Plaketten in den Blizzard-Einstellungen aus: unser Haken folgt, nichts wird zurueckgeschaltet
cvars.nameplateShowFriends = "0"
Head.Apply()
assert(settings.headPlates == false, "Haken folgt der Spieleinstellung (aus)")
Head.Apply(); Head.Apply()
assert(cvars.nameplateShowFriends == "0" and #setCalls == calls0, "wird nicht wieder eingeschaltet")
cvars.nameplateShowFriends = "1"
Head.Apply()
assert(settings.headPlates == true, "Haken folgt der Spieleinstellung (an)")

-- Unser Haken geaendert: Spieleinstellung folgt
Head.SetPlates(false)
assert(cvars.nameplateShowFriends == "0" and settings.headPlates == false, "Haken aus setzt Spieleinstellung aus")
Head.SetPlates(true)
assert(cvars.nameplateShowFriends == "1" and settings.headPlates == true, "Haken an setzt Spieleinstellung an")

-- Im Kampf: Schreiben wartet bis zum Kampfende, die Gleichschaltung dreht es nicht zurueck
combat = true
Head.SetPlates(false)
assert(cvars.nameplateShowFriends == "1", "im Kampf nicht geschrieben")
Head.Apply()
assert(settings.headPlates == false, "Haken bleibt aus trotz alter Spieleinstellung")
combat = false
events.OnEvent(nil, "PLAYER_REGEN_ENABLED")
assert(cvars.nameplateShowFriends == "0", "nach dem Kampf geschrieben")

-- Update von der alten Version: gemerkter Ursprungswert, aktueller Wert gilt
settings.plateInit, settings.origFriendlyPlayerPlates, settings.headPlates = nil, "0", true
cvars.nameplateShowFriends = "1"
local before = #setCalls
Head.Apply()
assert(settings.headPlates == true and settings.origFriendlyPlayerPlates == nil and settings.plateInit == true, "Altwert uebernommen")
assert(#setCalls == before, "dabei nichts geschrieben")
settings.plateInit, settings.origFriendlyPlayerPlates = nil, "0"
cvars.nameplateShowFriends = "0"
Head.Apply()
assert(settings.headPlates == false and cvars.nameplateShowFriends == "0", "Alt: war aus, bleibt aus")

-- Forever: nur der Retail-Name existiert
cvars.nameplateShowFriends = nil
cvars.nameplateShowFriendlyPlayers = "0"
settings.plateInit, settings.origFriendlyPlayerPlates, settings.headPlates = nil, nil, true
Head.Apply()
assert(cvars.nameplateShowFriendlyPlayers == "1", "Retail-Name eingeschaltet: " .. tostring(cvars.nameplateShowFriendlyPlayers))
local dh = Head.DiagLines()
assert(type(dh) == "table" and #dh >= 3, "Messzeilen Kopf")
print("OK")
