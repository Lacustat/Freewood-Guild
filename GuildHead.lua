-- Freewood-Guild: Affensymbol ueber dem Kopf von Gildenmitgliedern.
-- Das Symbol haengt an der Namensplakette des Spielers (C_NamePlate, wie die Ziel-Symbole von Freewood-Quest). Der Gildenleiter
-- bekommt das Symbol mit der Krone. Der eigene Charakter bekommt keines. Nur du siehst die Symbole.
-- Einstellungen: headShow (an/aus), headSize (16 bis 64 Pixel), headBars (Lebensbalken/Name bleiben sichtbar; aus: nur das Symbol),
-- headInst (Symbol auch in Instanzen), headPlates (gleichgeschaltet mit der Spieleinstellung "Plaketten freundlicher Spieler": die
-- Spieleinstellung ist die Wahrheit, unser Haken folgt ihr und umgekehrt; das Addon schaltet sie nie von selbst zurueck).
-- In Instanzen greift das Addon nicht in die Plaketten ein (Blizzard-Standard), nur das Symbol laesst sich dort ein-/ausschalten.
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
local cvarPending = nil      -- Wert ("1"/"0"), der nach dem Kampf in die Spieleinstellung geschrieben wird

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

-- Sind wir in einer Instanz (Dungeon, Schlachtzug ...)? Dort bleibt alles beim Blizzard-Standard.
function Head.InInstance()
    if not G.IsInInstance then return false end
    local ok, inst = pcall(G.IsInInstance)
    return ok and inst and true or false
end

-- Eine Einheit (Token) pruefen und das Symbol setzen oder entfernen
function Head.Update(unit)
    local plate = PlateOf(unit)
    if not plate then return nil end
    local inst = Head.InInstance()
    local show = Guild.Setting("headShow") ~= false and not (inst and Guild.Setting("headInst") == false)
    local kind = show and Head.Classify(unit) or nil
    -- Plakettenbild freundlicher Spieler ausblenden (nur ausserhalb von Instanzen und nur, wenn "Lebensbalken sichtbar" aus ist)
    local friendly = G.UnitIsPlayer and G.UnitIsPlayer(unit) and not (G.UnitCanAttack and G.UnitCanAttack("player", unit))
    local hide = Guild.Setting("headShow") ~= false and Guild.Setting("headBars") == false and not inst and friendly
        and not (G.UnitIsUnit and G.UnitIsUnit(unit, "player"))
    SetPlateVisible(plate, hide and true or false)
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

-- Forever kennt "nameplateShowFriends" nicht (liefert nil); die Retail-Namen werden der Reihe nach probiert
local CVAR_NAMES = { "nameplateShowFriendlyPlayers", "nameplateShowFriends", "nameplateShowFriendlyPlayerNames" }
Head.CVAR_NAMES = CVAR_NAMES

local function CVarName()
    if not G.GetCVar then return nil end
    for _, n in ipairs(CVAR_NAMES) do
        local ok, v = pcall(G.GetCVar, n)
        if ok and v ~= nil then return n, tostring(v) end
    end
    return nil
end

local function WriteCVar(name, value)
    if InCombat() then cvarPending = value; return end
    cvarPending = nil
    pcall(G.SetCVar, name, value)
end

-- Gleichschaltung mit der Spieleinstellung. Die Spieleinstellung ist die Wahrheit: unser Haken (headPlates) folgt ihr.
-- Nur beim allerersten Start (frische Installation) wird sie einmal eingeschaltet, damit die Symbole sichtbar sind;
-- danach schaltet das Addon sie nie von selbst um. Eine Einstellung aus der alten Version (gemerkter Ursprungswert)
-- wird uebernommen: der aktuelle Wert der Spieleinstellung gilt.
function Head.Sync()
    local st = Guild.DB().settings
    local name, cur = CVarName()
    if not name then return end
    if cvarPending then return end                  -- eigener Schreibvorgang wartet auf das Kampfende
    if not st.plateInit then
        if st.origFriendlyPlayerPlates ~= nil then
            st.headPlates = (cur == "1")
            st.origFriendlyPlayerPlates = nil
        elseif st.headShow ~= false and st.headPlates ~= false and cur ~= "1" then
            WriteCVar(name, "1")
        elseif cur == "1" then
            st.headPlates = true
        else
            st.headPlates = false
        end
        st.plateInit = true
        return
    end
    if cur == "1" and st.headPlates ~= true then st.headPlates = true
    elseif cur == "0" and st.headPlates ~= false then st.headPlates = false end
end

-- Unser Haken wurde geaendert: Spieleinstellung genauso setzen
function Head.SetPlates(on)
    local st = Guild.DB().settings
    st.headPlates = on and true or false
    st.plateInit = true
    st.origFriendlyPlayerPlates = nil
    local name, cur = CVarName()
    local want = on and "1" or "0"
    if name and cur ~= want then WriteCVar(name, want) end
end

-- Messzeilen fuer /fwguild stats
function Head.DiagLines()
    local out = {}
    local function Add(...) out[#out + 1] = string.format(...) end
    local st = Guild.DB().settings
    local name, cur = CVarName()
    Add("Affe ueber dem Kopf: an=%s, Plaketten (Haken)=%s, Lebensbalken zeigen=%s, in Instanzen=%s, jetzt in Instanz=%s", tostring(Guild.Setting("headShow")), tostring(Guild.Setting("headPlates")), tostring(Guild.Setting("headBars") ~= false), tostring(Guild.Setting("headInst") ~= false), tostring(Head.InInstance()))
    local tried = {}
    for _, n in ipairs(CVAR_NAMES) do
        local okc, v = false, nil
        if G.GetCVar then okc, v = pcall(G.GetCVar, n) end
        tried[#tried + 1] = n .. "=" .. tostring(okc and v)
    end
    Add("Geprueft: %s", table.concat(tried, ", "))
    Add("Spieleinstellung %s = %s, gleichgeschaltet=%s, offen wegen Kampf=%s", tostring(name), tostring(cur), tostring(st.plateInit == true), tostring(cvarPending))
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
    pcall(Head.Sync)
    pcall(Head.UpdateAll)
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

local ev = G.CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GUILD_ROSTER_UPDATE", "CVAR_UPDATE" }) do
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
        if cvarPending then
            local name = CVarName()
            local v = cvarPending
            cvarPending = nil
            if name then pcall(G.SetCVar, name, v) end
        end
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
        pcall(Head.Sync)             -- Aenderung in den Spieleinstellungen uebernehmen (auch ohne CVAR_UPDATE)
        pcall(Head.UpdateAll)
    end
end)
