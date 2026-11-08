-- Freewood-Guild: Affensymbol ueber dem Kopf von Gildenmitgliedern.
-- Das Symbol haengt an der Namensplakette des Spielers (C_NamePlate, wie die Ziel-Symbole von Freewood-Quest). Der Gildenleiter
-- bekommt das Symbol mit der Krone. Der eigene Charakter bekommt keines. Nur du siehst die Symbole.
-- Einstellungen: headShow (an/aus), headSize (16 bis 64 Pixel), headPlates (Plaketten freundlicher Spieler einschalten und ihr Bild
-- ausblenden, nur das Symbol bleibt; der alte Wert der Spieleinstellung wird gemerkt und beim Ausschalten zurueckgesetzt).
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local Head = {}
Guild.Head = Head

local ICON_MEMBER = "Interface\\AddOns\\Freewood-Guild\\Media\\affen_mitglied.tga"
local ICON_MASTER = "Interface\\AddOns\\Freewood-Guild\\Media\\ober_affe.tga"
Head.MIN, Head.MAX = 16, 64

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

function Head.Size()
    local v = tonumber(Guild.Setting("headSize")) or 28
    return math.max(Head.MIN, math.min(Head.MAX, math.floor(v + 0.5)))
end

------------------------------------------------------------------------
-- Wer ist Gildenmitglied?
------------------------------------------------------------------------

-- Rueckgabe: nil (kein Mitglied oder unbekannt), "member" oder "master"
function Head.Classify(unit)
    if not (G.UnitExists and G.UnitExists(unit)) then return nil end
    if not (G.UnitIsPlayer and G.UnitIsPlayer(unit)) then return nil end
    if G.UnitIsUnit and G.UnitIsUnit(unit, "player") then return nil end
    local ok, name = pcall(G.UnitName, unit)
    if not ok or type(name) ~= "string" or Secret(name) then return nil end
    local key = Guild.Key(name)
    local row = key and Guild.rowByKey and Guild.rowByKey[key]
    if row then
        return (row.rankIndex == 0) and "master" or "member"
    end
    -- Rueckfall: gleiche Gilde laut Spiel
    if G.GetGuildInfo then
        local ok2, mine = pcall(G.GetGuildInfo, "player")
        local ok3, theirs, _, rankIndex = pcall(G.GetGuildInfo, unit)
        if ok2 and ok3 and type(mine) == "string" and mine ~= "" and theirs == mine then
            return (tonumber(rankIndex) == 0) and "master" or "member"
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Plaketten
------------------------------------------------------------------------

local icons = setmetatable({}, { __mode = "k" })   -- Plakette -> Symbol
local hideFriendly, cvarPending = false, false

local function PlateOf(unit)
    local NP = G.C_NamePlate
    if not (NP and NP.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(NP.GetNamePlateForUnit, unit)
    if ok then return plate end
    return nil
end

local function IconFor(plate)
    local f = icons[plate]
    if f then return f end
    local ok, fr = pcall(G.CreateFrame, "Frame", nil, plate)
    if not ok or not fr then return nil end
    fr:SetFrameStrata("HIGH")
    if fr.EnableMouse then fr:EnableMouse(false) end
    fr.tex = fr:CreateTexture(nil, "OVERLAY")
    fr.tex:SetAllPoints()
    fr:Hide()
    icons[plate] = fr
    return fr
end

local function SetPlateVisible(plate, hide)
    local uf = plate.UnitFrame
    if type(uf) ~= "table" or not uf.SetAlpha then return end
    if hide then
        if not plate.fwHeadHook and G.hooksecurefunc then
            plate.fwHeadHook = true
            pcall(G.hooksecurefunc, uf, "SetAlpha", function(self, a)
                if plate.fwHeadHidden and (a or 0) > 0 and not plate.fwHeadGuard then
                    plate.fwHeadGuard = true
                    self:SetAlpha(0)
                    plate.fwHeadGuard = nil
                end
            end)
        end
        plate.fwHeadHidden = true
        plate.fwHeadGuard = true
        uf:SetAlpha(0)
        plate.fwHeadGuard = nil
    elseif plate.fwHeadHidden then
        plate.fwHeadHidden = nil
        uf:SetAlpha(1)
    end
end

local function InCombat() return G.InCombatLockdown and G.InCombatLockdown() end

-- Eine Einheit (Token) pruefen und das Symbol setzen oder entfernen
function Head.Update(unit)
    local plate = PlateOf(unit)
    if not plate then return nil end
    local show = Guild.Setting("headShow") ~= false
    local kind = show and Head.Classify(unit) or nil
    -- Plakettenbild freundlicher Spieler ausblenden, wenn so gewuenscht
    local friendly = G.UnitIsPlayer and G.UnitIsPlayer(unit) and not (G.UnitCanAttack and G.UnitCanAttack("player", unit))
    SetPlateVisible(plate, hideFriendly and show and friendly and not (G.UnitIsUnit and G.UnitIsUnit(unit, "player")))
    local f = icons[plate]
    if not kind then
        if f then f:Hide() end
        return nil
    end
    f = f or IconFor(plate)
    if not f then return nil end
    local size = Head.Size()
    f:SetSize(size, size)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", plate, "TOP", 0, 4)
    f.tex:SetTexture(kind == "master" and ICON_MASTER or ICON_MEMBER)
    f:Show()
    return kind
end

function Head.UpdateAll()
    local NP = G.C_NamePlate
    if not (NP and NP.GetNamePlates) then return end
    local ok, plates = pcall(NP.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then Head.Update(unit) elseif icons[plate] then icons[plate]:Hide() end
    end
end

------------------------------------------------------------------------
-- Spieleinstellung "Plaketten freundlicher Spieler"
------------------------------------------------------------------------

local function CVarName()
    if not G.GetCVar then return nil end
    local ok, v = pcall(G.GetCVar, "nameplateShowFriends")
    if ok and v ~= nil then return "nameplateShowFriends", tostring(v) end
    return nil
end

function Head.ApplyPlateMode(forceOff)
    local st = Guild.DB().settings
    local want = (not forceOff) and Guild.Setting("headShow") ~= false and Guild.Setting("headPlates") ~= false
    local name, cur = CVarName()
    cvarPending = false
    if want and name then
        if st.origFriendlyPlayerPlates == nil then st.origFriendlyPlayerPlates = cur end
        if st.origFriendlyPlayerPlates ~= "1" then
            hideFriendly = true
            if cur ~= "1" then
                if InCombat() then cvarPending = true else pcall(G.SetCVar, name, "1") end
            end
        else
            hideFriendly = false     -- der Spieler hat die Plaketten selbst an
        end
    else
        hideFriendly = false
        if name and st.origFriendlyPlayerPlates ~= nil then
            if InCombat() then
                cvarPending = true
            else
                if cur ~= st.origFriendlyPlayerPlates then pcall(G.SetCVar, name, st.origFriendlyPlayerPlates) end
                st.origFriendlyPlayerPlates = nil
            end
        end
    end
end

-- Messzeilen fuer /fwguild stats
function Head.DiagLines()
    local out = {}
    local function Add(...) out[#out + 1] = string.format(...) end
    local st = Guild.DB().settings
    local name, cur = CVarName()
    Add("Affe ueber dem Kopf: an=%s, Plaketten selbst einschalten=%s", tostring(Guild.Setting("headShow")), tostring(Guild.Setting("headPlates")))
    Add("Spieleinstellung %s = %s (gemerkter alter Wert: %s), Bild ausblenden=%s, offen wegen Kampf=%s", tostring(name), tostring(cur), tostring(st.origFriendlyPlayerPlates), tostring(hideFriendly), tostring(cvarPending))
    local NP = G.C_NamePlate
    local ok, plates = false, nil
    if NP and NP.GetNamePlates then ok, plates = pcall(NP.GetNamePlates) end
    Add("Plaketten sichtbar: %s", (ok and type(plates) == "table") and tostring(#plates) or "?")
    if ok and type(plates) == "table" then
        for i, plate in ipairs(plates) do
            if i > 6 then break end
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            local nm = unit and G.UnitName and select(2, pcall(G.UnitName, unit))
            local uf = plate.UnitFrame
            Add("  %s '%s': Mitglied=%s, Symbol=%s, Bildtransparenz=%s", tostring(unit), tostring(nm), tostring(unit and Head.Classify(unit)),
                (icons[plate] and icons[plate]:IsShown()) and "ja" or "nein", (function() local ok2, al = pcall(function() return uf:GetAlpha() end); return (ok2 and type(al) == "number") and string.format("%.1f", al) or "?" end)())
        end
    end
    return out
end

-- nach Aenderung einer Einstellung
function Head.Apply()
    pcall(Head.ApplyPlateMode)
    pcall(Head.UpdateAll)
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

local ev = G.CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GUILD_ROSTER_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if unit then pcall(Head.Update, unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = unit and PlateOf(unit)
        if plate then
            if icons[plate] then icons[plate]:Hide() end
            SetPlateVisible(plate, false)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if cvarPending then pcall(Head.ApplyPlateMode) end
        pcall(Head.UpdateAll)
    else
        pcall(Head.Apply)
    end
end)

-- gelegentlich neu pruefen (Gildenliste wird nach dem Anmelden erst spaeter geladen, Raenge aendern sich)
local acc = 0
ev:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc >= 3 then
        acc = 0
        pcall(Head.UpdateAll)
    end
end)
