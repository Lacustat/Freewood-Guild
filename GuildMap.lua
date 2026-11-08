-- Freewood-Guild: Positionen der Gildenmitglieder auf der Weltkarte.
-- Jeder Spieler mit dem Addon meldet seine Position etwa alle 10 Sekunden (Art "X|Karte|x|y", x und y in Promille).
-- Positionen verfallen nach 120 Sekunden. Minimap: Umrechnung ueber C_Map.GetWorldPosFromMapPos. Eingeschaltet/ausgeschaltet und Groesse (8 bis 64 Pixel) in den Einstellungen.
-- UNGEPRUEFT im Spiel. Die Karten-Technik folgt dem Kartenlayer von Freewood-Codex (Retail-Karte mit GetCanvas/OnMapChanged).

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share then
    return
end

local G = _G
local Share = Guild.Share
local Map = {}
Guild.Map = Map

local SEND_EVERY = 10
local EXPIRE = 120
local ICON_MEMBER = "Interface\\AddOns\\Freewood-Guild\\Media\\affen_mitglied.tga"
local ICON_MASTER = "Interface\\AddOns\\Freewood-Guild\\Media\\ober_affe.tga"

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end
local function Clock() return G.GetTime and G.GetTime() or 0 end

Map.pos = {}            -- [Schluessel] = { map, x, y, at }
Map.MIN, Map.MAX = 8, 64
Map.MINI_MIN, Map.MINI_MAX = 8, 32
local PREDICT_MAX = 12      -- so viele Sekunden werden die Positionen auf der Minimap fortgeschrieben

function Map.Size()
    local v = tonumber(Guild.Setting("mapSize")) or 24
    return math.max(Map.MIN, math.min(Map.MAX, math.floor(v + 0.5)))
end

function Map.MiniSize()
    local v = tonumber(Guild.Setting("miniSize")) or 14
    return math.max(Map.MINI_MIN, math.min(Map.MINI_MAX, math.floor(v + 0.5)))
end

------------------------------------------------------------------------
-- Eigene Position senden und fremde empfangen
------------------------------------------------------------------------

function Map.OwnPosition()
    local cm = G.C_Map
    if not (cm and cm.GetBestMapForUnit and cm.GetPlayerMapPosition) then return nil end
    local ok, id = pcall(cm.GetBestMapForUnit, "player")
    if not ok or type(id) ~= "number" or Secret(id) then return nil end
    local ok2, pos = pcall(cm.GetPlayerMapPosition, id, "player")
    if not ok2 or not pos then return nil end
    local ok3, x, y = pcall(pos.GetXY, pos)
    if not ok3 or type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    if x <= 0 and y <= 0 then return nil end
    return id, x, y
end

function Map.Encode(id, x, y)
    return string.format("X|%d|%d|%d", id, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5))
end

function Map.Decode(body)
    local id, x, y = string.match(body or "", "^(%d+)|(%d+)|(%d+)$")
    id, x, y = tonumber(id), tonumber(x), tonumber(y)
    if not id or not x or not y or x > 1000 or y > 1000 then return nil end
    return id, x / 1000, y / 1000
end

function Map.Send(force)
    if not Guild.Setting("mapShare") or not Guild.InGuild() then return false end
    local id, x, y = Map.OwnPosition()
    if not id then return false end
    local now = Clock()
    local last = Map.last
    if not force and last and now - last.at < SEND_EVERY then return false end
    if not force and last and last.id == id and math.abs(last.x - x) < 0.004 and math.abs(last.y - y) < 0.004 and now - last.at < SEND_EVERY * 4 then
        return false
    end
    Map.last = { id = id, x = x, y = y, at = now }
    Share.Queue(Map.Encode(id, x, y), "GUILD")
    return true
end

Share.handlers["X"] = function(key, body)
    local id, x, y = Map.Decode(body)
    if not id then return end
    local now = Clock()
    local old = Map.pos[key]
    local entry = { map = id, x = x, y = y, at = now }
    -- Geschwindigkeit (Kartenanteil je Sekunde) fuer die Fortschreibung auf der Minimap
    if old and old.map == id and now - old.at >= 1 and now - old.at <= 40 then
        entry.vx, entry.vy = (x - old.x) / (now - old.at), (y - old.y) / (now - old.at)
        if math.abs(entry.vx) > 0.02 or math.abs(entry.vy) > 0.02 then entry.vx, entry.vy = nil, nil end   -- Sprung (Portal) nicht fortschreiben
    end
    Map.pos[key] = entry
    if Map.layer and Map.layer:IsShown() then Map.Refresh() end
end

function Map.Active()
    local out = {}
    local now = Clock()
    for key, p in pairs(Map.pos) do
        if now - p.at <= EXPIRE then out[key] = p else Map.pos[key] = nil end
    end
    return out
end

------------------------------------------------------------------------
-- Karte
------------------------------------------------------------------------

local pins = {}

local function Canvas()
    local wm = G.WorldMapFrame
    if not wm then return nil end
    if wm.GetCanvas then
        local ok, c = pcall(wm.GetCanvas, wm)
        if ok and c then return c end
    end
    return wm.ScrollContainer and wm.ScrollContainer.Child or nil
end

local function EnsureLayer()
    if Map.layer then return Map.layer end
    local wm = G.WorldMapFrame
    if not wm or not Canvas() then return nil end
    local layer = CreateFrame("Frame", nil, wm)
    layer:SetAllPoints(wm.ScrollContainer or wm)
    layer:SetFrameLevel((wm:GetFrameLevel() or 1) + 60)
    if wm.GetFrameStrata then layer:SetFrameStrata(wm:GetFrameStrata()) end
    if layer.SetClipsChildren then layer:SetClipsChildren(true) end
    layer:SetScript("OnSizeChanged", function() Map.Refresh() end)
    Map.layer = layer
    return layer
end

local function PinTip(self)
    if not G.GameTooltip or not self.key then return end
    G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    G.GameTooltip:AddLine(Guild.NameOfKey and Guild.NameOfKey(self.key) or Guild.Display(self.key), 1, 0.82, 0)
    local row = Guild.rowByKey and Guild.rowByKey[self.key]
    if row then
        local bits = {}
        if row.level and row.level > 0 then bits[#bits + 1] = tostring(row.level) end
        if row.className and row.className ~= "" then bits[#bits + 1] = row.className end
        if row.rank and row.rank ~= "" then bits[#bits + 1] = row.rank end
        if #bits > 0 then G.GameTooltip:AddLine(table.concat(bits, " - "), 0.8, 0.8, 0.8) end
    end
    G.GameTooltip:Show()
end

local function NewPin(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:EnableMouse(true)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p:SetScript("OnEnter", PinTip)
    p:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    return p
end

local function GetPin(i, layer)
    local p = pins[i]
    if p then return p end
    p = NewPin(layer)
    pins[i] = p
    return p
end

local function ScaleRatio(layer, canvas)
    local ui = G.UIParent and G.UIParent.GetEffectiveScale and G.UIParent:GetEffectiveScale() or 1
    local a = canvas.GetEffectiveScale and canvas:GetEffectiveScale() or ui
    local b = layer.GetEffectiveScale and layer:GetEffectiveScale() or ui
    if type(ui) ~= "number" or ui <= 0 then ui = 1 end
    if type(a) ~= "number" or a <= 0 then a = ui end
    if type(b) ~= "number" or b <= 0 then b = ui end
    return (a / ui) / (b / ui), b / ui
end

function Map.Refresh()
    local layer = EnsureLayer()
    if not layer then return end
    for _, p in ipairs(pins) do p:Hide() end
    if not Guild.Setting("mapShow") then return end
    local wm = G.WorldMapFrame
    local canvas = Canvas()
    if not (wm and canvas and wm.GetMapID) then return end
    local ok, mapID = pcall(wm.GetMapID, wm)
    if not ok or type(mapID) ~= "number" then return end
    local width, height = canvas:GetWidth() or 0, canvas:GetHeight() or 0
    if width < 2 or height < 2 then return end
    local ratio, layerScale = ScaleRatio(layer, canvas)
    local size = Map.Size() / layerScale
    local n = 0
    local me = Guild.SelfKey()
    for key, p in pairs(Map.Active()) do
        if p.map == mapID and key ~= me then
            n = n + 1
            local pin = GetPin(n, layer)
            local row = Guild.rowByKey and Guild.rowByKey[key]
            local master = row and row.rankIndex == 0
            pin.key = key
            pin.tex:SetTexture(master and ICON_MASTER or ICON_MEMBER)
            pin:SetSize(size, size)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", p.x * width * ratio, -p.y * height * ratio)
            pin:SetFrameLevel(layer:GetFrameLevel() + (master and 3 or 2))
            pin:Show()
        end
    end
end

------------------------------------------------------------------------
-- Minimap
------------------------------------------------------------------------

local OUTDOOR = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { 300, 240, 180, 120, 80, 50 }
local worldCache = {}
local miniPins = {}

-- Kontinent und Weltposition (Yards) zu Karte + Anteilen; nil, wenn das Spiel sie nicht liefert
local function WorldPos(m, x, y)
    local key = m .. ":" .. math.floor(x * 2000 + 0.5) .. ":" .. math.floor(y * 2000 + 0.5)
    local c = worldCache[key]
    if c == nil then
        c = false
        local CM = G.C_Map
        if CM and CM.GetWorldPosFromMapPos and G.CreateVector2D then
            local ok, cont, pos = pcall(function()
                local a, b = CM.GetWorldPosFromMapPos(m, G.CreateVector2D(x, y))
                return a, b
            end)
            if ok and cont and pos and pos.GetXY then
                local ok2, wx, wy = pcall(pos.GetXY, pos)
                if ok2 and type(wx) == "number" and type(wy) == "number" then c = { cont, wx, wy } end
            end
        end
        local n = 0
        for _ in pairs(worldCache) do n = n + 1 end
        if n > 3000 then worldCache = {} end
        worldCache[key] = c
    end
    if c then return c[1], c[2], c[3] end
end

-- eigene Lage: Kontinent, Weltposition, Einheitsvektoren Osten/Sueden in Weltkoordinaten
local function PlayerBasis()
    local id, x, y = Map.OwnPosition()
    if not id then return nil end
    local cont, wx, wy = WorldPos(id, x, y)
    if not cont then return nil end
    local _, ex, ey = WorldPos(id, math.min(x + 0.05, 1), y)
    local _, sx, sy = WorldPos(id, x, math.min(y + 0.05, 1))
    if not (ex and sx) then return nil end
    local e1, e2, s1, s2 = ex - wx, ey - wy, sx - wx, sy - wy
    local el, sl = math.sqrt(e1 * e1 + e2 * e2), math.sqrt(s1 * s1 + s2 * s2)
    if el < 0.001 or sl < 0.001 then return nil end
    return { cont = cont, x = wx, y = wy, e = { e1 / el, e2 / el }, s = { s1 / sl, s2 / sl } }
end

local function ViewRadius(MM)
    if G.C_Minimap and G.C_Minimap.GetViewRadius then
        local ok, r = pcall(G.C_Minimap.GetViewRadius)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    local zoom = MM.GetZoom and MM:GetZoom() or 0
    local indoor = false
    if G.IsIndoors then local ok, v = pcall(G.IsIndoors); indoor = ok and v and true or false end
    return (indoor and INDOOR or OUTDOOR)[(zoom or 0) + 1] or 200
end

local function HideMini(from)
    for i = from, #miniPins do miniPins[i]:Hide() end
end

function Map.RefreshMini()
    local MM = G.Minimap
    if not MM or not Guild.Setting("mapMini") then return HideMini(1) end
    local me = Map.Active()
    if next(me) == nil then return HideMini(1) end
    local p = PlayerBasis()
    if not p then return HideMini(1) end
    local radius = ViewRadius(MM)
    local rotate = G.GetCVar and G.GetCVar("rotateMinimap") == "1"
    local heading
    if rotate and G.GetPlayerFacing then
        local ok, f = pcall(G.GetPlayerFacing)
        if ok and type(f) == "number" then heading = (2 * math.pi - f) % (2 * math.pi) end
    end
    local half = (MM:GetWidth() or 140) / 2 - 4
    local scale = half / radius
    local size = Map.MiniSize()
    local meKey = Guild.SelfKey()
    local now = Clock()
    local used = 0
    for key, e in pairs(me) do
        if key ~= meKey then
            local x, y = e.x, e.y
            if e.vx then
                local dt = math.min(now - e.at, PREDICT_MAX)
                x = math.max(0, math.min(1, x + e.vx * dt))
                y = math.max(0, math.min(1, y + e.vy * dt))
            end
            local cont, wx, wy = WorldPos(e.map, x, y)
            if cont and cont == p.cont then
                local dx, dy = wx - p.x, wy - p.y
                local east = dx * p.e[1] + dy * p.e[2]
                local north = -(dx * p.s[1] + dy * p.s[2])
                if east * east + north * north < radius * radius then
                    if heading then
                        local c, s = math.cos(heading), math.sin(heading)
                        east, north = east * c - north * s, east * s + north * c
                    end
                    used = used + 1
                    local pin = miniPins[used]
                    if not pin then
                        pin = NewPin(MM)
                        pin:SetFrameLevel((MM:GetFrameLevel() or 1) + 6)
                        miniPins[used] = pin
                    end
                    local row = Guild.rowByKey and Guild.rowByKey[key]
                    pin.key = key
                    pin.tex:SetTexture((row and row.rankIndex == 0) and ICON_MASTER or ICON_MEMBER)
                    pin:SetSize(size, size)
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", MM, "CENTER", east * scale, north * scale)
                    pin:Show()
                end
            end
        end
    end
    HideMini(used + 1)
end

-- Messzeilen fuer /fwguild stats
function Map.DiagLines()
    local out = {}
    local function Add(...) out[#out + 1] = string.format(...) end
    local d = Share.diag or {}
    local kinds = {}
    for k, v in pairs(d.byKind or {}) do kinds[#kinds + 1] = k .. "=" .. v end
    table.sort(kinds)
    Add("Empfang: %d Meldungen (ohne Namen %d, vom eigenen Namen %d); Arten: %s", d.recv or 0, d.noKey or 0, d.self or 0, #kinds > 0 and table.concat(kinds, " ") or "-")
    if d.last then Add("Zuletzt von: '%s' (Schluessel '%s', Kanal %s, vor %d s)", tostring(d.last.sender), tostring(d.last.key), tostring(d.last.channel), math.floor(Clock() - d.last.at)) end
    Add("Eigener Schluessel: '%s'", tostring(Guild.SelfKey()))
    Add("Einstellungen: Karte zeigen=%s, Minimap=%s, Position teilen=%s", tostring(Guild.Setting("mapShow")), tostring(Guild.Setting("mapMini")), tostring(Guild.Setting("mapShare")))
    local id, x, y = Map.OwnPosition()
    Add("Eigene Position: %s", id and string.format("Karte %d, %.3f / %.3f", id, x, y) or "nicht lesbar")
    local wm = G.WorldMapFrame
    local okm, wid = false, nil
    if wm and wm.GetMapID then okm, wid = pcall(wm.GetMapID, wm) end
    Add("Weltkarte: Karten-ID %s, Ebene %s, Haken %s", okm and tostring(wid) or "?", Map.layer and "ja" or "nein", Map.hooked and "ja" or "nein")
    local n, shown = 0, 0
    for key, p in pairs(Map.Active()) do
        n = n + 1
        if n <= 6 then Add("  Position '%s': Karte %d, %.3f / %.3f, vor %d s", key, p.map, p.x, p.y, math.floor(Clock() - p.at)) end
    end
    Add("Aktive Positionen: %d", n)
    for _, p in ipairs(pins) do if p:IsShown() then shown = shown + 1 end end
    local mshown = 0
    for _, p in ipairs(miniPins) do if p:IsShown() then mshown = mshown + 1 end end
    Add("Gezeichnet: Weltkarte %d, Minimap %d", shown, mshown)
    local b = PlayerBasis()
    Add("Minimap-Berechnung: %s", b and ("Kontinent " .. tostring(b.cont)) or "keine Weltposition (C_Map.GetWorldPosFromMapPos)")
    return out
end

function Map.Hook()
    if Map.hooked then return true end
    local wm = G.WorldMapFrame
    if not wm or not Canvas() then return false end
    Map.hooked = true
    if wm.OnMapChanged then pcall(G.hooksecurefunc, wm, "OnMapChanged", function() Map.Refresh() end) end
    if wm.HookScript then wm:HookScript("OnShow", function() Map.Refresh() end) end
    return true
end

------------------------------------------------------------------------
-- Zeitgeber
------------------------------------------------------------------------

local acc, accRefresh, accMini = 0, 0, 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    accRefresh = accRefresh + (elapsed or 0)
    accMini = accMini + (elapsed or 0)
    if accMini >= 0.25 then
        accMini = 0
        pcall(Map.RefreshMini)
    end
    if acc >= 10 then
        acc = 0
        if Share.started then pcall(Map.Send, false) end
    end
    if accRefresh >= 3 then
        accRefresh = 0
        if G.WorldMapFrame and G.WorldMapFrame:IsShown() then
            if not Map.hooked then pcall(Map.Hook) end
            pcall(Map.Refresh)
        end
    end
end)

table.insert(Share.startHooks, function()
    Share.After(20 + math.random() * 10, function() Map.Send(true) end)
    pcall(Map.Hook)
end)
table.insert(Share.requestHooks, function() Share.After(5 + math.random() * 15, function() Map.Send(true) end) end)
table.insert(Share.sendAllHooks, function() Map.Send(true) end)
