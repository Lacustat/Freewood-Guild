-- Freewood-Guild: Rezeptfenster mit Ergebnis-Item (Koerperplatz, Item-Stufe, Tooltip), Material und "Beobachten".
-- Das hergestellte Item und das Material jedes Rezepts melden die Mitglieder mit ihren Rezepten (Nachricht "I").
-- Quellen fuer die eigenen Rezepte: C_TradeSkillUI.GetRecipeSchematic, sonst die Rezeptliste von Freewood-Codex.
-- "Beobachten" legt das Rezept in die Beobachtungsliste von Freewood-Core (FW.Watch, /fwwatch).
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share then
    return
end

local G = _G
local Share = Guild.Share
local UI = FW.UI
local W = Guild.Widgets

local MAX_INFO = 3000
local MAX_INFO_MSGS = 40

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

local function Cache()
    local db = Guild.DB()
    db.recipeInfo = db.recipeInfo or {}
    return db.recipeInfo
end

------------------------------------------------------------------------
-- Item-Daten
------------------------------------------------------------------------

-- Rueckgabe: { id, name, link, quality, ilvl, equipLoc, classID, loaded }
function Guild.ItemData(id)
    id = tonumber(id)
    if not id then return nil end
    local d = { id = id }
    local ci = G.C_Item
    local inst = (ci and ci.GetItemInfoInstant) or G.GetItemInfoInstant
    if inst then
        local ok, _, _, _, equipLoc, _, classID = pcall(inst, id)
        if ok then
            if type(equipLoc) == "string" and not Secret(equipLoc) then d.equipLoc = equipLoc end
            if type(classID) == "number" and not Secret(classID) then d.classID = classID end
        end
    end
    local get = (ci and ci.GetItemInfo) or G.GetItemInfo
    if get then
        local ok, name, link, quality, ilvl, _, _, _, _, equipLoc = pcall(get, id)
        if ok and type(name) == "string" and not Secret(name) then
            d.name, d.link, d.quality, d.ilvl, d.loaded = name, link, quality, ilvl, true
            if not d.equipLoc and type(equipLoc) == "string" then d.equipLoc = equipLoc end
        end
    end
    if not d.loaded and ci and ci.RequestLoadItemDataByID then pcall(ci.RequestLoadItemDataByID, id) end
    return d
end

-- Gruppen nach Koerperplatz. label: Name des Spiels (INVTYPE_*), sonst Text aus den Locales
Guild.SLOTS = {
    { "HEAD", { "INVTYPE_HEAD" }, "INVTYPE_HEAD" },
    { "NECK", { "INVTYPE_NECK" }, "INVTYPE_NECK" },
    { "SHOULDER", { "INVTYPE_SHOULDER" }, "INVTYPE_SHOULDER" },
    { "BACK", { "INVTYPE_CLOAK" }, "INVTYPE_CLOAK" },
    { "CHEST", { "INVTYPE_CHEST", "INVTYPE_ROBE" }, "INVTYPE_CHEST" },
    { "WRIST", { "INVTYPE_WRIST" }, "INVTYPE_WRIST" },
    { "HANDS", { "INVTYPE_HAND" }, "INVTYPE_HAND" },
    { "WAIST", { "INVTYPE_WAIST" }, "INVTYPE_WAIST" },
    { "LEGS", { "INVTYPE_LEGS" }, "INVTYPE_LEGS" },
    { "FEET", { "INVTYPE_FEET" }, "INVTYPE_FEET" },
    { "FINGER", { "INVTYPE_FINGER" }, "INVTYPE_FINGER" },
    { "TRINKET", { "INVTYPE_TRINKET" }, "INVTYPE_TRINKET" },
    { "WEAPON", { "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD",
        "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" }, nil, "GUILD_G_WEAPON" },
    { "BAG", { "INVTYPE_BAG", "INVTYPE_QUIVER" }, nil, "GUILD_G_BAG" },
    { "CONSUMABLE", {}, nil, "GUILD_G_CONSUMABLE" },
    { "MATERIAL", {}, nil, "GUILD_G_MATERIAL" },
    { "ENCHANT", {}, nil, "GUILD_G_ENCHANT" },
    { "OTHER", {}, nil, "GUILD_G_OTHER" },
}

local slotByLoc = {}
for i, s in ipairs(Guild.SLOTS) do
    for _, loc in ipairs(s[2]) do slotByLoc[loc] = i end
end
local function SlotIndex(key)
    for i, s in ipairs(Guild.SLOTS) do if s[1] == key then return i end end
end

function Guild.SlotLabel(i)
    local s = Guild.SLOTS[i]
    if not s then return "?" end
    if s[3] and type(G[s[3]]) == "string" then return G[s[3]] end
    return FW.L[s[4] or "GUILD_G_OTHER"]
end

-- Gruppe eines Rezepts (Index in Guild.SLOTS)
function Guild.SlotOf(itemData, profId)
    if itemData then
        if itemData.equipLoc and slotByLoc[itemData.equipLoc] then return slotByLoc[itemData.equipLoc] end
        local c = itemData.classID
        if c == 0 then return SlotIndex("CONSUMABLE") end
        if c == 7 or c == 5 then return SlotIndex("MATERIAL") end
        return SlotIndex("OTHER")
    end
    if profId == 333 then return SlotIndex("ENCHANT") end
    return SlotIndex("OTHER")
end

------------------------------------------------------------------------
-- Rezept-Info: Ergebnis-Item und Material
------------------------------------------------------------------------

local miss = {}

local function FromSchematic(rid)
    local ts = G.C_TradeSkillUI
    if not (ts and ts.GetRecipeSchematic) then return nil end
    local ok, s = pcall(ts.GetRecipeSchematic, rid, false)
    if not ok or type(s) ~= "table" then return nil end
    local info = { m = {} }
    if type(s.outputItemID) == "number" and not Secret(s.outputItemID) then info.it = s.outputItemID end
    if type(s.reagentSlotSchematics) == "table" then
        for _, slot in ipairs(s.reagentSlotSchematics) do
            local r = type(slot) == "table" and type(slot.reagents) == "table" and slot.reagents[1] or nil
            local q = type(slot) == "table" and tonumber(slot.quantityRequired) or nil
            if r and tonumber(r.itemID) and q and q > 0 and slot.required ~= false and #info.m < 8 then
                info.m[#info.m + 1] = { i = tonumber(r.itemID), n = q }
            end
        end
    end
    if not info.it and #info.m == 0 then return nil end
    return info
end

local function FromCodex(name)
    local c = FW.Codex
    local store = c and c.db and c.db.recipes
    if type(store) ~= "table" or not name then return nil end
    for _, prof in pairs(store) do
        local rec = type(prof) == "table" and prof[name]
        if type(rec) == "table" and (rec.it or type(rec.rg) == "table") then
            local info = { it = tonumber(rec.it), m = {} }
            if type(rec.rg) == "table" then
                for item, count in pairs(rec.rg) do
                    if tonumber(item) and #info.m < 8 then info.m[#info.m + 1] = { i = tonumber(item), n = tonumber(count) or 1 } end
                end
                table.sort(info.m, function(a, b) return a.i < b.i end)
            end
            return info
        end
    end
    return nil
end

-- { it = Item oder nil, m = { { i, n } } } oder nil
function Guild.RecipeInfo(rid, profId)
    rid = tonumber(rid)
    if not rid then return nil end
    local cache = Cache()
    if cache[rid] then return cache[rid] end
    if miss[rid] then return nil end
    local info = FromSchematic(rid) or FromCodex(Guild.SpellName and Guild.SpellName(rid))
    if info then
        cache[rid] = info
        return info
    end
    miss[rid] = true
    return nil
end

-- Material als Liste fuer Auftraege: { { i, n, h = false } }
function Guild.RecipeMats(rid)
    local info = Guild.RecipeInfo(rid)
    if not info or #info.m == 0 then return nil end
    local out = {}
    for _, m in ipairs(info.m) do out[#out + 1] = { i = m.i, n = m.n, h = false } end
    return out
end

------------------------------------------------------------------------
-- Teilen: I|<rid>:<item>:<i>x<n>/<i>x<n>,...  (jede Nachricht fuer sich)
------------------------------------------------------------------------

function Guild.EncodeInfo(rid, info)
    local mats = {}
    for _, m in ipairs(info.m or {}) do mats[#mats + 1] = m.i .. "x" .. m.n end
    return rid .. ":" .. (info.it or 0) .. ":" .. table.concat(mats, "/")
end

function Guild.DecodeInfo(entry)
    local rid, it, mats = string.match(entry, "^(%d+):(%d+):([%dx/]*)$")
    rid, it = tonumber(rid), tonumber(it)
    if not rid or rid > 99999999 or not it then return nil end
    local info = { it = it > 0 and it or nil, m = {} }
    for i, n in string.gmatch(mats, "(%d+)x(%d+)") do
        if #info.m < 8 then info.m[#info.m + 1] = { i = tonumber(i), n = tonumber(n) } end
    end
    if not info.it and #info.m == 0 then return nil end
    return rid, info
end

local origSend = Share.SendRecipes
function Share.SendRecipes(profId, ids)
    local n = origSend(profId, ids)
    local lines, cur = {}, ""
    for _, rid in ipairs(ids or {}) do
        local info = Guild.RecipeInfo(rid, profId)
        if info then
            local e = Guild.EncodeInfo(rid, info)
            if #cur + #e + 1 > 200 then lines[#lines + 1] = cur; cur = "" end
            cur = cur == "" and e or (cur .. "," .. e)
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    for i, l in ipairs(lines) do
        if i > MAX_INFO_MSGS then break end
        Share.Queue("I|" .. l, "GUILD")
    end
    return n
end

Share.handlers["I"] = function(key, body)
    local cache = Cache()
    local count = 0
    for entry in string.gmatch(body or "", "[^,]+") do
        count = count + 1
        if count > 12 then break end
        local rid, info = Guild.DecodeInfo(entry)
        if rid and not cache[rid] then
            local size = 0
            for _ in pairs(cache) do size = size + 1; if size >= MAX_INFO then break end end
            if size < MAX_INFO then cache[rid] = info end
        end
    end
    FW:Fire("GUILD_MODULE_RECIPEINFO")
end

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local win, rows = nil, {}
local ROW_H, HEAD_H = 36, 20

local function Vis(f, on) if on then f:Show() else f:Hide() end end

local function Tip(self)
    if not G.GameTooltip or not self.link then return end
    G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = G.GameTooltip.SetHyperlink and pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, self.link)
    if not ok then G.GameTooltip:AddLine(self.text or "?") end
    G.GameTooltip:Show()
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, win.scroll.child)
    r:EnableMouse(true)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.line1 = UI.CreateLabel(r, "", { size = 12 })
    r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -4)
    r.line1:SetPoint("RIGHT", r, "RIGHT", -196, 0)
    r.line1:SetWordWrap(false)
    r.line2 = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
    r.line2:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -19)
    r.line2:SetPoint("RIGHT", r, "RIGHT", -196, 0)
    r.line2:SetWordWrap(false)
    r.btn = UI.CreateButton(r, FW.L.GUILD_WATCH, 90, 22, function()
        local e = r.entry
        if not e then
            FW:Print("Beobachten: kein Rezept in dieser Zeile.")
            return
        end
        local W = FW.Watch
        if not (W and W.Add) then
            FW:Print("Beobachten: Freewood-Core 0.7.0 oder neuer fehlt.")
            return
        end
        local ok, res = pcall(W.Add, { key = "r" .. e.rid, name = e.title, itemId = e.info and e.info.it, spellId = e.rid, mats = e.info and e.info.m or {} })
        if not ok then
            FW:Print("Beobachten: Fehler - " .. tostring(res))
        elseif res then
            FW:Print(string.format("Beobachten: %s (%d in der Liste)", tostring(e.title), #W.List()))
            if W.Show then pcall(W.Show) end
        else
            FW:Print("Beobachten: konnte nicht hinzugefügt werden (Liste voll?).")
        end
    end)
    r.btn:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    -- Gewinn (nur mit Freewood-Auction): selbst gefarmt / alles im AH
    r.profit = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT" })
    r.profit:SetPoint("RIGHT", r.btn, "LEFT", -6, 5)
    r.profit:SetWidth(96)
    r.profit2 = UI.CreateLabel(r, "", { size = 10, justify = "RIGHT", color = "textDim" })
    r.profit2:SetPoint("RIGHT", r.btn, "LEFT", -6, -7)
    r.profit2:SetWidth(96)
    r:SetScript("OnEnter", Tip)
    r:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    rows[i] = r
    return r
end

local function Hex(q)
    local c = G.ITEM_QUALITY_COLORS and q and G.ITEM_QUALITY_COLORS[q]
    if c and c.r then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffe5e3d9"
end

local function MatText(info)
    if not info or #info.m == 0 then return FW.L.GUILD_NO_MATS end
    local parts = {}
    for _, m in ipairs(info.m) do
        local nm = (FW.Watch and FW.Watch.ItemName(m.i)) or ("#" .. m.i)
        local have = FW.Watch and FW.Watch.Have(m.i) or 0
        local col = have >= m.n and "|cff66dd66" or "|cffbbbbbb"
        parts[#parts + 1] = col .. m.n .. "x " .. nm .. "|r"
    end
    return FW.L.GUILD_MATS .. ": " .. table.concat(parts, ", ")
end

-- Eintraege bauen: { rid, name, title, info, item, slot, ilvl }
function Guild.BuildRecipeEntries(ids, profId, filter)
    local out = {}
    local q = string.lower(filter or "")
    for _, rid in ipairs(ids or {}) do
        local spell = Guild.SpellName(rid) or ("[" .. rid .. "]")
        local info = Guild.RecipeInfo(rid, profId)
        local item = info and info.it and Guild.ItemData(info.it) or nil
        local title = (item and item.name) or spell
        local hay = string.lower(spell .. " " .. title)
        if q == "" or string.find(hay, q, 1, true) then
            out[#out + 1] = {
                rid = rid, name = spell, title = title, info = info, item = item,
                slot = Guild.SlotOf(item, profId), ilvl = (item and tonumber(item.ilvl)) or 0,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        return a.title < b.title
    end)
    return out
end

local function Fill()
    if not win or not win:IsShown() then return end
    local L = FW.L
    local ids = win.ids
    if not ids or #ids == 0 then
        win.empty:SetText(L.GUILD_RECIPES_NONE)
        win.empty:Show()
        for _, r in ipairs(rows) do r:Hide() end
        win.scroll:SetContentHeight(60)
        return
    end
    win.empty:Hide()
    local list = Guild.BuildRecipeEntries(ids, win.profId, win.filter:GetText())
    local n, y, lastSlot = 0, 0, nil
    for _, e in ipairs(list) do
        if e.slot ~= lastSlot then
            lastSlot = e.slot
            n = n + 1
            local h = GetRow(n)
            h.entry, h.link = nil, nil
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", win.scroll.child, "TOPLEFT", 0, -y)
            h:SetPoint("TOPRIGHT", win.scroll.child, "TOPRIGHT", 0, -y)
            h:SetHeight(HEAD_H)
            h.bg:SetColorTexture(UI.Color("bronze", 0.35))
            h.line1:SetText("|cffe8c46a" .. Guild.SlotLabel(e.slot) .. "|r")
            h.line1:ClearAllPoints()
            h.line1:SetPoint("LEFT", h, "LEFT", 6, 0)
            h.line2:SetText("")
            h.btn:Hide()
            h:Show()
            y = y + HEAD_H + 2
        end
        n = n + 1
        local r = GetRow(n)
        r.entry = e
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", win.scroll.child, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", win.scroll.child, "TOPRIGHT", 0, -y)
        r:SetHeight(ROW_H)
        r.bg:SetColorTexture(UI.Color("card", 0.6))
        r.line1:ClearAllPoints()
        r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -4)
        local pre = e.ilvl > 0 and ("|cff9a978c[" .. e.ilvl .. "]|r ") or ""
        local nm = (e.item and e.item.loaded) and (Hex(e.item.quality) .. e.title .. "|r") or ("|cffe5e3d9" .. e.title .. "|r")
        r.line1:SetText(pre .. nm)
        r.line2:SetText(MatText(e.info))
        r.link = (e.info and e.info.it) and ("item:" .. e.info.it) or ("spell:" .. e.rid)
        r.text = e.title
        if FW.Watch then r.btn:Show() else r.btn:Hide() end
        r.profit:SetText("")
        r.profit2:SetText("")
        local A = FW.Auction
        if A and A.CraftFromInfo and e.info then
            local okc, c = pcall(A.CraftFromInfo, e.info)
            if okc and c then
                r.profit:SetText(A.SignedMoney(c.profitFarm))
                r.profit2:SetText(c.profitAH and A.SignedMoney(c.profitAH) or "")
            end
        end
        r:Show()
        y = y + ROW_H + 2
    end
    for i = n + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end
    win.count:SetText(string.format(FW.L.GUILD_RECIPES_COUNT, #list, #ids))
    win.scroll:SetContentHeight(y + 8)
end
Guild.FillRecipeWindow = Fill

local pending = false
local function Later()
    if pending then return end
    pending = true
    local function Run() pending = false; pcall(Fill) end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(0.5, Run) else Run() end
end

function Guild.ShowRecipes(name, profId)
    local L = FW.L
    local sh = Guild.Shared(name)
    if not win then
        local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
        w:SetSize(560, 600)
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        w:SetFrameStrata("DIALOG")
        w:EnableMouse(true)
        w:SetMovable(true)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        w.title = UI.CreateLabel(w, "", { font = "heading", size = 14, color = "goldLight" })
        w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -12)
        w.title:SetPoint("TOPRIGHT", w, "TOPRIGHT", -40, -12)
        w.title:SetWordWrap(false)
        w.info = UI.CreateLabel(w, "", { size = 11, color = "textDim" })
        w.info:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -34)
        w.info:SetWordWrap(false)
        w.count = UI.CreateLabel(w, "", { size = 11, color = "textDim", justify = "RIGHT" })
        w.count:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -34)
        local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)
        local watchBtn = UI.CreateButton(w, L.GUILD_WATCH_OPEN, 130, 24, function() if FW.Watch then FW.Watch.Show() end end)
        watchBtn:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -54)
        w.filter = W.Edit(w, 380, 24)
        w.filter:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -54)
        w.filter.onChange = function() if win then Fill() end end
        w.scroll = UI.CreateScrollFrame(w)
        w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -86)
        w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -14, 14)
        w.empty = UI.CreateLabel(w.scroll.child, "", { size = 12, color = "textDim" })
        w.empty:SetPoint("TOPLEFT", w.scroll.child, "TOPLEFT", 2, -4)
        FW:RegisterEvent("GET_ITEM_INFO_RECEIVED", function() if win and win:IsShown() then Later() end end, w)
        FW:RegisterEvent("BAG_UPDATE_DELAYED", function() if win and win:IsShown() then Later() end end, w)
        FW:On("GUILD_MODULE_RECIPEINFO", function() if win and win:IsShown() then Later() end end, w)
        w:Hide()
        win = w
    end
    local w = win
    w.ids = sh and sh.recipes and sh.recipes[profId]
    w.profId = profId
    local skill = sh and sh.skills and sh.skills[profId]
    w.title:SetText(Guild.Display(name) .. " - " .. Guild.ProfName(profId) .. (skill and not skill.chat and (" " .. skill.rank .. "/" .. skill.max) or ""))
    w.info:SetText(w.ids and string.format(L.GUILD_RECIPES_INFO, #w.ids, Guild.FormatAgo(sh.recipeStamp)) or "")
    w.filter:SetText("")
    w:Show()
    Fill()
end
