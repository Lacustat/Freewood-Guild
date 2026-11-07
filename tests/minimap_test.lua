-- Test der Minimap-Umrechnung in GuildMap.lua (texlua tests/minimap_test.lua)
local function Proxy()
    local o = { _pts = {} }
    return setmetatable(o, { __index = function(t, k)
        if k == "_set" then return nil end
        return function(self, ...)
            if k == "SetPoint" then self._pts[#self._pts + 1] = { ... } end
            if k == "ClearAllPoints" then self._pts = {} end
            if k == "Show" then rawset(self, "shown", true) end
            if k == "Hide" then rawset(self, "shown", false) end
            if k == "GetWidth" then return 140 end
            if k == "GetFrameLevel" then return 1 end
            if k == "SetSize" then rawset(self, "size", ...) end
            return Proxy()
        end
    end })
end
local frames = {}
_G.CreateFrame = function() local f = Proxy(); frames[#frames + 1] = f; return f end
_G.Minimap = Proxy()
_G.GetTime = function() return 100 end
local zone = { [1] = true }
_G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
_G.C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetWorldPosFromMapPos = function(m, v) return 7, { GetXY = function() return v.x * 1000, v.y * 1000 end } end,
}
_G.C_Minimap = { GetViewRadius = function() return 200 end }
_G.GetCVar = function() return "0" end
local settings = { mapMini = true, miniSize = 14, mapShare = true }
local Guild = {
    Setting = function(k) return settings[k] end, InGuild = function() return true end, SelfKey = function() return "me" end,
    rowByKey = { b = { rankIndex = 0 } },
}
local Share = { handlers = {}, startHooks = {}, requestHooks = {}, sendAllHooks = {}, Queue = function() end, After = function() end }
Guild.Share = Share
_G.Freewood = { Util = { IsSecret = function() return false end } }
assert(loadfile("GuildMap.lua"))("Freewood-Guild", { Guild = Guild })
local Map = Guild.Map
assert(Map and Map.RefreshMini)

-- Kodierung
assert(Map.Encode(5, 0.25, 0.75) == "X|5|250|750")
local id, x, y = Map.Decode("5|250|750")
assert(id == 5 and x == 0.25 and y == 0.75)

-- niemand da: nichts sichtbar
Map.RefreshMini()
-- Mitglied 100 Yards oestlich, eines weit weg, eines auf anderer Karte (hier gleicher Kontinent, aber 600 Yards)
Share.handlers["X"]("a", "1|600|500")   -- x 0.6 -> 600 yd, Spieler 500 -> 100 yd Osten
Share.handlers["X"]("b", "1|500|400")   -- y 0.4 -> 100 yd Norden (y waechst nach Sueden)
Share.handlers["X"]("c", "1|900|500")   -- 400 yd: ausserhalb von Radius 200
Map.RefreshMini()
local shown = {}
for _, f in ipairs(frames) do if rawget(f, "shown") and rawget(f, "size") then shown[#shown + 1] = f end end
assert(#shown == 2, "sichtbare Pins " .. #shown)
local function Offset(f) local p = f._pts[1]; return p[4], p[5] end
local ex, ny
for _, f in ipairs(shown) do
    local dx, dy = Offset(f)
    if f.key == "a" then ex, ny = dx, dy end
end
local scale = (140 / 2 - 4) / 200
assert(math.abs(ex - 100 * scale) < 0.01 and math.abs(ny) < 0.01, "Osten " .. tostring(ex) .. "," .. tostring(ny))
for _, f in ipairs(shown) do
    if f.key == "b" then
        local dx, dy = Offset(f)
        assert(math.abs(dx) < 0.01 and math.abs(dy - 100 * scale) < 0.01, "Norden " .. dx .. "," .. dy)
    end
end
-- aus: alles weg
settings.mapMini = false
Map.RefreshMini()
for _, f in ipairs(frames) do assert(not (rawget(f, "shown") and rawget(f, "size")), "Pins sollten weg sein") end
print("OK")
