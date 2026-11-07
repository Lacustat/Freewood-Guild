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
_G.InCombatLockdown = function() return false end
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

Head.Apply()
assert(cvars.nameplateShowFriends == "1", "Plaketten eingeschaltet")
assert(settings.origFriendlyPlayerPlates == "0", "alter Wert gemerkt")
Head.UpdateAll()
-- Ergebnis ueber Update-Rueckgabe
assert(Head.Update("nameplate1") == "member")
assert(Head.Update("nameplate2") == "master")
assert(Head.Update("nameplate3") == nil)
assert(Head.Update("nameplate4") == nil)
-- Ausblenden des Plakettenbilds fuer freundliche Spieler
assert(plates.nameplate4.UnitFrame.alpha == 0, "Plakettenbild ausgeblendet")
-- Groesse und Aus
settings.headSize = 40
assert(Head.Size() == 40)
settings.headShow = false
Head.Apply()
assert(Head.Update("nameplate1") == nil, "aus: kein Symbol")
assert(cvars.nameplateShowFriends == "0", "alter Wert zurueckgesetzt: " .. tostring(cvars.nameplateShowFriends))
assert(settings.origFriendlyPlayerPlates == nil)
-- Spieler hat Plaketten selbst an: nichts aendern, nichts ausblenden
cvars.nameplateShowFriends = "1"
settings.headShow = true
Head.Apply()
assert(Head.Update("nameplate1") == "member")
print("OK")
