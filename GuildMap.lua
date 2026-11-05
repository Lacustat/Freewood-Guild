-- Freewood-Guild: Positionen der Gildenmitglieder auf der Weltkarte.
-- Jeder Spieler mit dem Addon meldet seine Position etwa alle 30 Sekunden (Art "X|Karte|x|y", x und y in Promille).
-- Positionen verfallen nach 120 Sekunden. Eingeschaltet/ausgeschaltet und Groesse (8 bis 64 Pixel) in den Einstellungen.
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

local SEND_EVERY = 30
local EXPIRE = 120
local ICON_MEMBER = "Interface\\AddOns\\Freewood-Guild\\Media\\affen_mitglied.tga"
local ICON_MASTER = "Interface\\AddOns\\Freewood-Guild\\Media\\ober_affe.tga"

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end
local function Clock() return G.GetTime and G.GetTime() or 0 end

Map.pos = {}            -- [Schluessel] = { map, x, y, at }
Map.MIN, Map.MAX = 8, 64

function Map.Size()
    local v = tonumber(Guild.Setting("mapSize")) or 24
    return math.max(Map.MIN, math.min(Map.MAX, math.floor(v + 0.5)))
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
    Map.pos[key] = { map = id, x = x, y = y, at = Clock() }
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

local function GetPin(i, layer)
    local p = pins[i]
    if p then return p end
    p = CreateFrame("Frame", nil, layer)
    p:EnableMouse(true)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p:SetScript("OnEnter", function(self)
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
    end)
    p:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
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

local acc, accRefresh = 0, 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    accRefresh = accRefresh + (elapsed or 0)
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
