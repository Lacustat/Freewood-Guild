-- Freewood-Guild: Dungeon-Fenster. Kleines, verschiebbares Fenster, das zeigt, wer in der Gilde gerade nach einer Gruppe sucht
-- (dieselben Daten wie die Seite "Dungeon Browser", ueber die versteckten Gildennachrichten). Es oeffnet sich, sobald jemand
-- sucht, und schliesst sich, wenn niemand mehr sucht. Startposition: unten rechts bei Aktionsleiste 3; danach frei
-- verschiebbar (die Lage wird gemerkt). Linksklick auf eine Zeile fluestert, Rechtsklick laedt ein. Ein-/Ausschalten in den
-- Einstellungen des Dungeon-Browsers (dungWin) und mit dem X im Fenster (bis jemand Neues sucht).
-- Im Design "Legion der Affen" (UI.LegionSkin.active) sitzt das Fenster in einem festen Bildrahmen (Media/suche_rahmen.tga, 512x512,
-- mit Affenkopf, Aexten, Bannern): feste Groesse, innen Platz fuer Titel und 3 Zeilen, weitere als "+n weitere". Sonst wie bisher.
-- UNGEPRUEFT im Spiel.
--
-- Inhalt: Zeilen und Anzeigeregeln (pruefbar), Klick, Fenster

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Dungeon then
    return
end

local G = _G
local Dung = Guild.Dungeon
local Win = {}
Guild.DungeonWin = Win

local MAX_ROWS = 8
local LEG_ROWS = 3
-- Legion-Rahmen: aussen 360 px (Bild 1024 px -> Faktor 0,3516); freie Innenflaeche des Bildes x 176-836, y 412-768, hier mit 2 px Rand
local LEG_SIZE = 360
local LEG_L, LEG_T, LEG_W, LEG_H = 64, 147, 228, 121
local LEG_FILL = { 0.09, 0.07, 0.06, 0.96 }    -- dunkler Grund hinter der Innenflaeche (Loch des Bildes: x 140-881, y 343-881)
local LEG_ART = "Interface\\AddOns\\Freewood-Guild\\Media\\suche_rahmen.tga"

function Win.On()
    return Guild.Setting("dungWin") ~= false
end

-- Zeilen fuer die Anzeige aus der Liste des Dungeon-Browsers. Rueckgabe: Zeilen { key, name, class, self, label, text }, Anzahl nicht gezeigter
function Win.Lines(list, maxRows)
    local L = FW.L
    local out = {}
    list = list or {}
    maxRows = maxRows or MAX_ROWS
    for _, e in ipairs(list) do
        if #out >= maxRows then break end
        local words = Dung.RoleWords(e.roles or {})
        local what
        if (e.size or 1) > 1 then
            what = string.format(L.DUNG_WIN_GROUP, e.size, words)
        else
            what = string.format(L.DUNG_WIN_SOLO, words)
        end
        -- Gruppe mit mehreren Gildenmitgliedern: alle Namen in einer Zeile ("Anna + Bob"); angeklickt wird der Melder
        local title
        if e.members and #e.members > 1 then title = table.concat(e.members, " + ") end
        out[#out + 1] = { key = e.key, name = e.name or "?", title = title, class = e.class, self = e.self and true or false, label = e.label or "?", text = what }
    end
    return out, #list - #out
end

-- Soll das Fenster offen sein? count = Anzahl der Suchenden. Mit dem X geschlossen bleibt es zu, bis mehr Leute suchen als dabei.
function Win.ShouldShow(count)
    if not Win.On() or count <= 0 then
        Win.dismissed = nil
        return false
    end
    if Win.dismissed and count < Win.dismissed then Win.dismissed = count end
    if Win.dismissed and count <= Win.dismissed then return false end
    Win.dismissed = nil
    return true
end

function Win.Dismiss(count)
    Win.dismissed = count
end

-- Klick auf eine Zeile: Linksklick fluestert, Rechtsklick laedt ein. Rueckgabe: true, wenn etwas ausgeloest wurde
function Win.Click(line, button)
    if not line or line.self or not line.name or line.name == "" then return false end
    if button == "RightButton" then
        local invite = (G.C_PartyInfo and G.C_PartyInfo.InviteUnit) or G.InviteUnit
        if not invite then return false end
        return pcall(invite, line.name) and true or false
    end
    if G.ChatFrame_OpenChat then
        return pcall(G.ChatFrame_OpenChat, "/w " .. line.name .. " ") and true or false
    end
    return false
end

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local UI = FW.UI
if not UI or not G.CreateFrame then return end

local W, HEAD, ROW_H = 290, 24, 30
local frame
local rows = {}
local owner = {}

local function Settings() return Guild.DB().settings end

local function SavePos()
    if not frame then return end
    local point, _, rel, x, y = frame:GetPoint(1)
    if point then Settings().dungWinPos = { point = point, rel = rel, x = x, y = y } end
end

local function ApplyPos()
    frame:ClearAllPoints()
    local p = Settings().dungWinPos
    if type(p) == "table" and p.point and p.x and p.y then
        frame:SetPoint(p.point, G.UIParent, p.rel or p.point, p.x, p.y)
        return
    end
    -- Startposition: ueber dem rechten Ende von Aktionsleiste 3, sonst unten rechts am Bildschirm
    local bar = G.MultiBarBottomRight
    local ok, shown = pcall(function() return bar and bar.IsShown and bar:IsShown() end)
    if ok and shown then
        frame:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 8)
    else
        frame:SetPoint("BOTTOMRIGHT", G.UIParent, "BOTTOMRIGHT", -20, 190)
    end
end

function Win.ResetPos()
    Settings().dungWinPos = nil
    if frame then ApplyPos() end
end

-- Legion-Design aktiv? (Core: UI.LegionSkin.active)
function Win.LegionOn()
    local S = UI.LegionSkin
    return S and S.active and true or false
end

-- Aussehen und Ankerpunkte je nach Design setzen (Rahmen aus Bild oder schlichtes Fenster)
local function ApplyLook(f)
    local leg = Win.LegionOn()
    f.leg = leg
    if leg then
        f:SetSize(LEG_SIZE, LEG_SIZE)
    end
    if f.bg then f.bg:SetShown(not leg) end
    local b = f.fwBorder
    if b then for _, t in pairs(b) do if t.SetShown then t:SetShown(not leg) end end end
    f.art:SetShown(leg)
    f.fill:SetShown(leg)
    f.title:ClearAllPoints()
    f.close:ClearAllPoints()
    f.more:ClearAllPoints()
    if leg then
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", LEG_L + 2, -LEG_T - 1)
        f.close:SetSize(16, 16)
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(LEG_SIZE - LEG_L - LEG_W), -LEG_T + 1)
        f.more:SetPoint("BOTTOMLEFT", f, "TOPLEFT", LEG_L + 2, -(LEG_T + LEG_H) + 1)
    else
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
        f.close:SetSize(18, 18)
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        f.more:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 4)
    end
end

local function Build()
    if frame then return frame end
    local L = FW.L
    local f = UI.CreatePanel(G.UIParent, "bg", "gold")
    f:SetSize(W, HEAD + ROW_H + 8)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    frame = f
    ApplyPos()

    -- Rahmenbild (nur im Legion-Design) mit dunklem Grund dahinter
    f.fill = f:CreateTexture(nil, "BACKGROUND")
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 49, -120)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(LEG_SIZE - 310), 50)
    f.fill:SetColorTexture(LEG_FILL[1], LEG_FILL[2], LEG_FILL[3], LEG_FILL[4])
    f.art = f:CreateTexture(nil, "ARTWORK")
    f.art:SetAllPoints()
    f.art:SetTexture(LEG_ART)
    f.title = UI.CreateLabel(f, L.DUNG_WIN_TITLE, { size = 12, color = "goldLight" })
    f.title:SetHeight(14)
    f.close = UI.CreateButton(f, "x", 18, 18, function() Win.Dismiss(f.count or 0); f:Hide() end)
    f.more = UI.CreateLabel(f, "", { size = 10, color = "textDim" })
    ApplyLook(f)
    f:Hide()
    return f
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = G.CreateFrame("Button", nil, frame)
    r:SetHeight(ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(UI.Color("card", 0.6))
    r.line1 = UI.CreateLabel(r, "", { size = 12 })
    r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -3)
    r.line1:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.line1:SetHeight(13)
    r.line1:SetWordWrap(false)
    r.line2 = UI.CreateLabel(r, "", { size = 10, color = "textDim" })
    r.line2:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -17)
    r.line2:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.line2:SetHeight(11)
    r.line2:SetWordWrap(false)
    r:SetScript("OnClick", function(self, button) Win.Click(self.line, button) end)
    r:SetScript("OnEnter", function(self)
        local tip = G.GameTooltip
        if not (tip and self.line and not self.line.self) then return end
        tip:SetOwner(self, "ANCHOR_LEFT")
        tip:SetText(self.line.name)
        tip:AddLine(FW.L.DUNG_WIN_HINT, 0.7, 0.7, 0.7)
        tip:Show()
    end)
    r:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    rows[i] = r
    return r
end

function Win.Refresh()
    local leg = Win.LegionOn()
    local lines, more = Win.Lines(Dung.List(), leg and LEG_ROWS or MAX_ROWS)
    if not Win.ShouldShow(#lines + more) then
        if frame then frame:Hide() end
        return
    end
    local f = Build()
    if f.leg ~= leg then ApplyLook(f) end
    local L = FW.L
    f.count = #lines + more
    local x0, y0, x1, pitch = 6, HEAD, -6, ROW_H + 2
    if leg then x0, y0, x1, pitch = LEG_L, LEG_T + 16, -(LEG_SIZE - LEG_L - LEG_W), ROW_H + 1 end
    for i, line in ipairs(lines) do
        local r = GetRow(i)
        r.line = line
        local cr, cg, cb
        if line.class and FW.ChatLog and FW.ChatLog.ClassColor then cr, cg, cb = FW.ChatLog.ClassColor(line.class) end
        r.line1:SetText((line.title or line.name) .. (line.self and (" " .. L.DUNG_YOU) or "") .. "  -  " .. line.label)
        if cr then r.line1:SetTextColor(cr, cg, cb) else r.line1:SetTextColor(UI.Color("text")) end
        r.line2:SetText(line.text)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y0 - (i - 1) * pitch)
        r:SetPoint("TOPRIGHT", f, "TOPRIGHT", x1, -y0 - (i - 1) * pitch)
        r:Show()
    end
    for i = #lines + 1, #rows do rows[i].line = nil; rows[i]:Hide() end
    f.more:SetText(more > 0 and string.format(L.DUNG_WIN_MORE, more) or "")
    if not leg then
        f:SetHeight(HEAD + #lines * (ROW_H + 2) + (more > 0 and 14 or 6))
    end
    f:Show()
end

FW:On("GUILD_MODULE_DUNGEON", function() pcall(Win.Refresh) end, owner)
FW:On("DESIGN_CHANGED", function() pcall(Win.Refresh) end, owner)

-- Suchen laufen nach einiger Zeit ab, ohne dass eine Meldung kommt: gelegentlich neu pruefen
local ticker = G.CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 5 then return end
    acc = 0
    if frame and frame:IsShown() then pcall(Win.Refresh) end
end)
