-- Freewood-Guild: Oberflaeche. Gilden-Fenster (Reiter "Gilde") mit Unterseiten, Mitgliedertabelle, Rezeptfenster,
-- Rechtsklick-Menue, Hinweis-Popups, Einstellungen. UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local UI = FW.UI
local W = {}
Guild.Widgets = W

local ICON_MEMBER = "Interface\\AddOns\\Freewood-Guild\\Media\\affen_mitglied.tga"
local ICON_MASTER = "Interface\\AddOns\\Freewood-Guild\\Media\\ober_affe.tga"
Guild.ICON_MEMBER, Guild.ICON_MASTER = ICON_MEMBER, ICON_MASTER

local function Show(frame, on)
    if on then frame:Show() else frame:Hide() end
end

------------------------------------------------------------------------
-- Bausteine: Eingabefeld, Menue, Hinweis
------------------------------------------------------------------------

function W.Edit(parent, width, height)
    local box = UI.CreatePanel(parent, "card", "bronze")
    box:SetSize(width or 150, height or 24)
    local e = CreateFrame("EditBox", nil, box)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -2)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 2)
    e:SetAutoFocus(false)
    UI.SetFont(e, "body", 12)
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if box.onEnter then box.onEnter(self:GetText()) end
    end)
    e:SetScript("OnTextChanged", function(self)
        if box.onChange then box.onChange(self:GetText()) end
    end)
    box.edit = e
    function box:GetText() return e:GetText() or "" end
    function box:SetText(t) e:SetText(t or "") end
    return box
end

local menu, catcher, menuTitle, menuButtons = nil, nil, nil, {}
local function HideMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end
W.HideMenu = HideMenu

-- items: { { text, fn }, ... }
function W.Menu(title, items)
    if not menu then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:SetScript("OnClick", HideMenu)
        catcher:Hide()
        menu = UI.CreatePanel(UIParent, "bgDeep", "gold")
        menu:SetWidth(210)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(catcher:GetFrameLevel() + 5)
        menu:Hide()
        menuTitle = UI.CreateLabel(menu, "", { size = 12, color = "gold" })
        menuTitle:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8)
    end
    menuTitle:SetText(title or "")
    local n = #items
    for i = 1, n do
        local b = menuButtons[i]
        if not b then
            b = UI.CreateButton(menu, "", 194, 22, nil)
            b:SetParent(menu)
            menuButtons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -28 - (i - 1) * 24)
        b:SetLabel(items[i][1])
        b:SetScript("OnClick", function()
            HideMenu()
            if items[i][2] then items[i][2]() end
        end)
        b:Show()
    end
    for i = n + 1, #menuButtons do menuButtons[i]:Hide() end
    menu:SetHeight(28 + n * 24 + 8)
    local x, y = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc, y / sc)
    catcher:Show()
    menu:Show()
end

-- kleiner Hinweis oben in der Mitte
local toast
function Guild.Toast(text)
    if not toast then
        toast = UI.CreatePanel(UIParent, "bgDeep", "gold")
        toast:SetSize(380, 46)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -120)
        toast:SetFrameStrata("FULLSCREEN_DIALOG")
        toast.label = UI.CreateLabel(toast, "", { size = 12, justify = "CENTER" })
        toast.label:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -6)
        toast.label:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -10, 6)
        toast.label:SetWordWrap(true)
        toast:Hide()
    end
    toast.label:SetText(text or "")
    toast.left = 6
    toast:SetAlpha(1)
    toast:Show()
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - (elapsed or 0)
        if self.left <= 0 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
        elseif self.left < 1 then
            self:SetAlpha(self.left)
        end
    end)
end

------------------------------------------------------------------------
-- Rezeptfenster
------------------------------------------------------------------------

local spellCache = {}
function Guild.SpellName(id)
    local n = spellCache[id]
    if n then return n end
    if G.C_Spell and G.C_Spell.GetSpellName then
        local ok, v = pcall(G.C_Spell.GetSpellName, id)
        if ok and type(v) == "string" and v ~= "" then n = v end
    end
    if not n and G.GetSpellInfo then
        local ok, v = pcall(G.GetSpellInfo, id)
        if ok and type(v) == "string" and v ~= "" then n = v end
    end
    if n then spellCache[id] = n end
    return n
end

local recipeWin
function Guild.ShowRecipes(name, profId)
    local L = FW.L
    local sh = Guild.Shared(name)
    if not recipeWin then
        local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
        w:SetSize(380, 470)
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
        w.info:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -34)
        w.info:SetWordWrap(false)
        local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)
        w.filter = W.Edit(w, 352, 24)
        w.filter:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -54)
        w.filter.onChange = function() if w.Fill then w.Fill() end end
        w.scroll = UI.CreateScrollFrame(w)
        w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -86)
        w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -14, 14)
        w.text = UI.CreateLabel(w.scroll.child, "", { size = 12, justifyV = "TOP" })
        w.text:SetPoint("TOPLEFT", w.scroll.child, "TOPLEFT", 2, -2)
        w.text:SetPoint("TOPRIGHT", w.scroll.child, "TOPRIGHT", -2, -2)
        w.text:SetWordWrap(true)
        w:Hide()
        recipeWin = w
    end
    local w = recipeWin
    local ids = sh and sh.recipes and sh.recipes[profId]
    local skill = sh and sh.skills and sh.skills[profId]
    w.title:SetText(Guild.Display(name) .. " - " .. Guild.ProfName(profId) .. (skill and (" " .. skill.rank .. "/" .. skill.max) or ""))
    w.info:SetText(ids and string.format(L.GUILD_RECIPES_INFO, #ids, Guild.FormatAgo(sh.recipeStamp)) or "")
    function w.Fill()
        if not ids or #ids == 0 then
            w.text:SetText(L.GUILD_RECIPES_NONE)
            w.scroll:SetContentHeight(60)
            return
        end
        local q = string.lower(w.filter:GetText())
        local lines = {}
        for _, id in ipairs(ids) do
            local nm = Guild.SpellName(id) or ("[" .. id .. "]")
            if q == "" or string.find(string.lower(nm), q, 1, true) then lines[#lines + 1] = nm end
        end
        table.sort(lines)
        w.text:SetText(table.concat(lines, "\n"))
        w.scroll:SetContentHeight(math.max(30, #lines * 15 + 8))
    end
    w.filter:SetText("")
    w.Fill()
    w:Show()
end

------------------------------------------------------------------------
-- Mitgliederliste: Spalten und Zeilen
------------------------------------------------------------------------

local ROW_H = 22
local M = {}     -- Zustand der Seite
Guild.Members = M
M.filter = "online"       -- "online", "offline", "all"
M.search = ""
M.sort = { col = "rank", asc = true }

local function Lower(s) return string.lower(tostring(s or "")) end

-- Darstellungszeile aus Gildenzeile und geteilten Daten
local function MakeView(row)
    local sh = Guild.Shared(row.full) or Guild.DB().members[row.key]
    local v = { row = row, sh = sh, name = row.name, key = row.key }
    v.level = row.level
    v.class = row.className or row.class or ""
    v.race = row.race or (sh and sh.race and Guild.RaceName(sh.race)) or ""
    v.skills = sh and sh.skills or nil
    v.p1, v.p2 = Guild.MainProfs(v.skills)
    local function Rank(id) return v.skills and v.skills[id] and v.skills[id].rank or nil end
    v.cook, v.aid, v.fish = Rank(Guild.COOK), Rank(Guild.AID), Rank(Guild.FISH)
    v.played = sh and sh.played or nil
    if sh and sh.level and sh.level == row.level then
        v.frac = Guild.XPFraction(sh.level, sh.xp, sh.xpmax)
    end
    v.gold = sh and sh.gold or nil
    return v
end

local function ProfSort(v, which)
    local id = v[which]
    if not id then return "~" end
    return Lower(Guild.ProfName(id))
end

local COLS = {
    { id = "name", label = "GUILD_COL_NAME", w = 15, key = function(v) return Lower(v.name) end },
    { id = "level", label = "GUILD_COL_LEVEL", w = 5, key = function(v) return v.level or 0 end },
    { id = "class", label = "GUILD_COL_CLASS", w = 9, key = function(v) return Lower(v.class) end },
    { id = "race", label = "GUILD_COL_RACE", w = 9, key = function(v) return Lower(v.race) end },
    { id = "rank", label = "GUILD_COL_RANK", w = 9, key = function(v) return v.row.rankIndex end },
    { id = "p1", label = "GUILD_COL_PROF1", w = 12, key = function(v) return ProfSort(v, "p1") end },
    { id = "p2", label = "GUILD_COL_PROF2", w = 12, key = function(v) return ProfSort(v, "p2") end },
    { id = "cook", label = "GUILD_COL_COOK", w = 6, key = function(v) return v.cook or -1 end },
    { id = "aid", label = "GUILD_COL_AID", w = 6, key = function(v) return v.aid or -1 end },
    { id = "fish", label = "GUILD_COL_FISH", w = 6, key = function(v) return v.fish or -1 end },
    { id = "played", label = "GUILD_COL_PLAYED", w = 8, key = function(v) return v.played or -1 end },
    { id = "xp", label = "GUILD_COL_XP", w = 11, key = function(v) return v.frac or -1 end },
    { id = "gold", label = "GUILD_COL_GOLD", w = 9, owner = true, key = function(v) return v.gold or -1 end },
}
M.COLS = COLS

local function ActiveCols()
    local out = {}
    for _, c in ipairs(COLS) do
        if not c.owner or Guild.IsOwner() then out[#out + 1] = c end
    end
    return out
end

local function ColByID(id)
    for _, c in ipairs(COLS) do if c.id == id then return c end end
    return COLS[1]
end

function M.Matches(v, q)
    if q == "" then return true end
    local parts = { Lower(v.name), Lower(v.class), Lower(v.race), Lower(v.row.rank), Lower(v.row.zone) }
    if v.p1 then parts[#parts + 1] = Lower(Guild.ProfName(v.p1)) end
    if v.p2 then parts[#parts + 1] = Lower(Guild.ProfName(v.p2)) end
    if string.find(table.concat(parts, " "), q, 1, true) then return true end
    -- Rezeptsuche: wer kann das herstellen?
    if #q >= 3 and v.sh and v.sh.recipes then
        for _, ids in pairs(v.sh.recipes) do
            for _, id in ipairs(ids) do
                local nm = Guild.SpellName(id)
                if nm and string.find(Lower(nm), q, 1, true) then return true end
            end
        end
    end
    return false
end

function M.Build()
    local list = {}
    local q = Lower(M.search)
    local total, online = 0, 0
    for _, row in ipairs(Guild.rows) do
        total = total + 1
        if row.online then online = online + 1 end
        local ok = (M.filter == "all") or (M.filter == "online" and row.online) or (M.filter == "offline" and not row.online)
        if ok then
            local v = MakeView(row)
            if M.Matches(v, q) then list[#list + 1] = v end
        end
    end
    local col = ColByID(M.sort.col)
    local asc = M.sort.asc
    table.sort(list, function(a, b)
        local ka, kb = col.key(a), col.key(b)
        if ka ~= kb then
            if asc then return ka < kb end
            return ka > kb
        end
        return Lower(a.name) < Lower(b.name)
    end)
    M.view, M.total, M.online = list, total, online
    return list
end

local function ClassColor(v)
    if FW.ChatLog then
        local tok = v.row.class
        if tok then return FW.ChatLog.ClassColor(tok) end
    end
    return 0.9, 0.89, 0.84
end

local function FavMenu(v)
    local L = FW.L
    local Fav = Guild.Fav
    local name = v.row.full
    local items = {
        { L.CHAN_WHISPER, function() Guild.Whisper(name) end },
        { L.CHAN_INVITE, function() Guild.Invite(name) end },
    }
    if Fav then
        for _, scope in ipairs({ "char", "account" }) do
            local tag = scope == "char" and L.FAV_TAG_CHAR or L.FAV_TAG_ACCOUNT
            if Fav.Has(scope, name) then
                items[#items + 1] = { string.format(L.GUILD_MENU_UNFAV, tag), function() Fav.Remove(scope, name) end }
            else
                items[#items + 1] = { string.format(L.GUILD_MENU_FAV, tag), function() Fav.Add(scope, name) end }
            end
            local groups = Fav.Store(scope).groups
            for gi = 1, math.min(#groups, 4) do
                local g = groups[gi]
                items[#items + 1] = { tag .. ": " .. g.title, function() Fav.AddToGroup(scope, gi, name) end }
            end
        end
    end
    local shown = {}
    for i = 1, math.min(#items, 12) do shown[i] = items[i] end
    W.Menu(v.row.name, shown)
end

local function Tooltip(self)
    local v = self.v
    if not v or not G.GameTooltip then return end
    local L = FW.L
    G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    G.GameTooltip:AddLine(v.row.name, ClassColor(v))
    G.GameTooltip:AddLine((v.row.rank ~= "" and v.row.rank or "-") .. (v.row.zone ~= "" and (" - " .. v.row.zone) or ""), 0.9, 0.89, 0.84)
    if not v.row.online and v.row.lastHours then
        G.GameTooltip:AddLine(string.format(L.GUILD_LAST_ONLINE, math.floor(v.row.lastHours / 24)), 0.6, 0.6, 0.55)
    end
    if v.sh and v.sh.stamp then
        G.GameTooltip:AddLine(string.format(L.GUILD_DATA_AGE, Guild.FormatAgo(v.sh.stamp)), 0.6, 0.6, 0.55)
    else
        G.GameTooltip:AddLine(L.GUILD_NO_DATA, 0.6, 0.6, 0.55)
    end
    if v.row.note ~= "" then G.GameTooltip:AddLine(v.row.note, 0.8, 0.8, 0.5) end
    G.GameTooltip:Show()
end

local function BuildMembers(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    -- Kopfzeile: Filter, Suche, Zaehler
    local dd = UI.CreateDropdown(f, 130, 24, {
        getOptions = function()
            return { { value = "online", text = L.GUILD_F_ONLINE }, { value = "offline", text = L.GUILD_F_OFFLINE }, { value = "all", text = L.GUILD_F_ALL } }
        end,
        textOf = function(v) return v == "online" and L.GUILD_F_ONLINE or v == "offline" and L.GUILD_F_OFFLINE or L.GUILD_F_ALL end,
        onChange = function(v) if v then M.filter = v; f.Refresh() end end,
    })
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    dd:SetValue(M.filter)
    local search = W.Edit(f, 260, 24)
    search:SetPoint("LEFT", dd, "RIGHT", 8, 0)
    search.onChange = function(t) M.search = t or ""; f.Refresh() end
    local hint = UI.CreateLabel(f, L.GUILD_SEARCH_HINT, { size = 11, color = "textDim" })
    hint:SetPoint("LEFT", search, "RIGHT", 8, 0)
    local count = UI.CreateLabel(f, "", { size = 12, color = "textDim", justify = "RIGHT" })
    count:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -4)
    local refresh = UI.CreateButton(f, L.GUILD_REFRESH, 100, 24, function() Guild.RequestRoster(true); if Guild.Share then Guild.Share.Request(false) end end)
    refresh:SetPoint("RIGHT", count, "LEFT", -10, 0)

    -- Spaltenkoepfe
    local headerBar = CreateFrame("Frame", nil, f)
    headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -32)
    headerBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -32)
    headerBar:SetHeight(24)
    local headers = {}

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -58)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    local pool = {}
    local cols, colX, colW = {}, {}, {}
    local firstShown = 1

    local function Layout()
        cols = ActiveCols()
        local width = headerBar:GetWidth()
        if not width or width < 200 then width = 900 end
        local avail = width - 26
        local total = 0
        for _, c in ipairs(cols) do total = total + c.w end
        local x = 26
        for i, c in ipairs(cols) do
            colW[i] = math.floor(avail * c.w / total)
            colX[i] = x
            x = x + colW[i]
        end
        for i, c in ipairs(cols) do
            local h = headers[c.id]
            if not h then
                h = UI.CreateButton(headerBar, "", 50, 24, function() end, "ghost")
                h.arrow = h:CreateTexture(nil, "OVERLAY")
                h.arrow:SetSize(10, 10)
                h.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
                h.arrow:SetPoint("RIGHT", h, "RIGHT", -3, 0)
                headers[c.id] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", headerBar, "TOPLEFT", colX[i], 0)
            h:SetWidth(colW[i] - 2)
            h:SetLabel(L[c.label])
            h.label:ClearAllPoints()
            h.label:SetPoint("LEFT", h, "LEFT", 4, 0)
            h.label:SetPoint("RIGHT", h, "RIGHT", -14, 0)
            h.label:SetJustifyH("LEFT")
            h:SetScript("OnClick", function()
                if M.sort.col == c.id then M.sort.asc = not M.sort.asc else M.sort.col = c.id; M.sort.asc = true end
                f.Refresh()
            end)
            h:Show()
        end
        for id, h in pairs(headers) do
            local used = false
            for _, c in ipairs(cols) do if c.id == id then used = true end end
            if not used then h:Hide() end
        end
    end

    local function GetRow(i)
        local r = pool[i]
        if r then return r end
        r = CreateFrame("Button", nil, scroll.child)
        r:SetHeight(ROW_H)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(UI.Color("hover", 0))
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.cells = {}
        for id, _ in pairs({ name = 1, level = 1, class = 1, race = 1, rank = 1, p1 = 1, p2 = 1, cook = 1, aid = 1, fish = 1, played = 1, xp = 1, gold = 1 }) do
            local c = UI.CreateLabel(r, "", { size = 12 })
            c:SetWordWrap(false)
            r.cells[id] = c
        end
        r.barBg = r:CreateTexture(nil, "ARTWORK")
        r.barBg:SetColorTexture(UI.Color("card"))
        r.barFill = r:CreateTexture(nil, "OVERLAY")
        r.barFill:SetColorTexture(UI.Color("bronze"))
        r.barText = UI.CreateLabel(r, "", { size = 10, justify = "CENTER" })
        r.profBtn = {}
        for which = 1, 2 do
            local b = CreateFrame("Button", nil, r)
            b:SetHeight(ROW_H)
            b:SetScript("OnClick", function(self)
                local v = r.v
                local id = v and v[which == 1 and "p1" or "p2"]
                if id then Guild.ShowRecipes(v.row.full, id) end
            end)
            r.profBtn[which] = b
        end
        r:SetScript("OnEnter", function(self) self.hl:SetColorTexture(UI.Color("hover", 0.6)); Tooltip(self) end)
        r:SetScript("OnLeave", function(self) self.hl:SetColorTexture(UI.Color("hover", 0)); if G.GameTooltip then G.GameTooltip:Hide() end end)
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.v then FavMenu(self.v) end
        end)
        pool[i] = r
        return r
    end

    local function Fill(r, v)
        r.v = v
        local cr, cg, cb = ClassColor(v)
        r.icon:SetTexture(Guild.IsGuildMaster(v.row) and ICON_MASTER or ICON_MEMBER)
        for i, c in ipairs(cols) do
            local cell = r.cells[c.id]
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", r, "LEFT", colX[i] + 2, 0)
            cell:SetWidth(colW[i] - 6)
            cell:SetTextColor(UI.Color("text"))
            cell:Show()
            local id = c.id
            if id == "name" then cell:SetText(v.name); cell:SetTextColor(cr, cg, cb)
            elseif id == "level" then cell:SetText(v.level > 0 and tostring(v.level) or "-")
            elseif id == "class" then cell:SetText(v.class ~= "" and v.class or "-"); cell:SetTextColor(cr, cg, cb)
            elseif id == "race" then cell:SetText(v.race ~= "" and v.race or "-")
            elseif id == "rank" then cell:SetText(v.row.rank ~= "" and v.row.rank or "-")
            elseif id == "p1" or id == "p2" then
                local pid = v[id]
                if pid then
                    local s = v.skills and v.skills[pid]
                    cell:SetText(Guild.ProfName(pid) .. (s and (" " .. s.rank) or ""))
                    local has = v.sh and v.sh.recipes and v.sh.recipes[pid]
                    cell:SetTextColor(UI.Color(has and "goldLight" or "textDim"))
                else
                    cell:SetText("-")
                    cell:SetTextColor(UI.Color("textDim"))
                end
            elseif id == "cook" or id == "aid" or id == "fish" then
                cell:SetText(v[id] and tostring(v[id]) or "-")
            elseif id == "played" then cell:SetText(Guild.FormatPlayed(v.played))
            elseif id == "xp" then cell:SetText("")
            elseif id == "gold" then cell:SetText(v.gold and FW.Util.FormatMoney(v.gold, { noCopper = true }) or "-")
            end
        end
        for id, cell in pairs(r.cells) do
            local used = false
            for _, c in ipairs(cols) do if c.id == id then used = true end end
            if not used then cell:Hide() end
        end
        -- EP-Balken
        local xi
        for i, c in ipairs(cols) do if c.id == "xp" then xi = i end end
        if xi then
            r.barBg:ClearAllPoints()
            r.barBg:SetPoint("LEFT", r, "LEFT", colX[xi] + 2, 0)
            r.barBg:SetSize(colW[xi] - 8, 12)
            r.barBg:Show()
            r.barFill:ClearAllPoints()
            r.barFill:SetPoint("LEFT", r.barBg, "LEFT", 0, 0)
            r.barFill:SetHeight(12)
            r.barFill:SetWidth(math.max(1, (colW[xi] - 8) * (v.frac or 0)))
            Show(r.barFill, v.frac ~= nil)
            r.barText:ClearAllPoints()
            r.barText:SetPoint("CENTER", r.barBg, "CENTER", 0, 0)
            r.barText:SetText(v.frac and (math.floor(v.frac * 100) .. "%") or "-")
            r.barText:Show()
        else
            r.barBg:Hide(); r.barFill:Hide(); r.barText:Hide()
        end
        -- Berufe anklickbar
        for which = 1, 2 do
            local b = r.profBtn[which]
            local cid = which == 1 and "p1" or "p2"
            local idx
            for i, c in ipairs(cols) do if c.id == cid then idx = i end end
            if idx and v[cid] then
                b:ClearAllPoints()
                b:SetPoint("LEFT", r, "LEFT", colX[idx], 0)
                b:SetWidth(colW[idx] - 2)
                b:Show()
            else
                b:Hide()
            end
        end
        r:SetAlpha(v.row.online and 1 or 0.6)
        r.icon:SetAlpha(v.row.online and 1 or 0.5)
    end

    local function Update()
        local view = M.view or {}
        local h = scroll:GetHeight()
        if not h or h < 50 then h = 600 end
        local poolSize = math.floor(h / ROW_H) + 3
        local first = math.floor((scroll.scroll:GetVerticalScroll() or 0) / ROW_H) + 1
        if first < 1 then first = 1 end
        for i = 1, poolSize do
            local r = GetRow(i)
            local idx = first + i - 1
            local v = view[idx]
            if v then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(idx - 1) * ROW_H)
                r:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(idx - 1) * ROW_H)
                Fill(r, v)
                r:Show()
            else
                r.v = nil
                r:Hide()
            end
        end
        for i = poolSize + 1, #pool do pool[i]:Hide() end
    end

    function f.Refresh()
        Layout()
        M.Build()
        count:SetText(string.format(L.GUILD_COUNT, #M.view, M.total or 0, M.online or 0))
        for _, c in ipairs(cols) do
            local hd = headers[c.id]
            if hd then
                if M.sort.col == c.id then
                    hd.arrow:Show()
                    if M.sort.asc then hd.arrow:SetTexCoord(0, 1, 1, 0) else hd.arrow:SetTexCoord(0, 1, 0, 1) end
                    hd:SetStyle("primary")
                else
                    hd.arrow:Hide()
                    hd:SetStyle("default")
                end
            end
        end
        scroll:SetContentHeight(#M.view * ROW_H + 4)
        Update()
    end

    scroll.scroll:HookScript("OnVerticalScroll", function() Update() end)
    headerBar:SetScript("OnSizeChanged", function() if f:IsVisible() then f.Refresh() end end)
    local pending = false
    local function Later()
        if f:IsVisible() and not pending then
            pending = true
            if G.C_Timer and G.C_Timer.After then
                G.C_Timer.After(0.3, function() pending = false; if f:IsVisible() then f.Refresh() end end)
            else
                pending = false
                f.Refresh()
            end
        end
    end
    FW:On("GUILD_MODULE_ROSTER", Later, f)
    FW:On("GUILD_MODULE_DATA", Later, f)
    FW:On("GUILD_MODULE_FAV", function() end, f)
    M.frame = f
    return f
end

Guild.RegisterPage("members", {
    order = 10,
    label = function() return FW.L.GUILD_TAB_MEMBERS end,
    build = BuildMembers,
    refresh = function(f) f.Refresh() end,
})

------------------------------------------------------------------------
-- Hauptfenster: Reiter "Gilde" mit Unterseiten
------------------------------------------------------------------------

local main
local function BuildMain(content)
    local f = CreateFrame("Frame", nil, content)
    f.buttons, f.frames = {}, {}
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetHeight(28)
    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -38)
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    function f.Select(id)
        f.current = id
        for _, def in ipairs(Guild.pages) do
            local b = f.buttons[def.id]
            if b then b:SetStyle(def.id == id and "primary" or "default") end
            local fr = f.frames[def.id]
            if fr then fr:Hide() end
        end
        for _, def in ipairs(Guild.pages) do
            if def.id == id then
                local fr = f.frames[id]
                if not fr and def.build then
                    fr = def.build(area)
                    if fr then fr:SetAllPoints(area); f.frames[id] = fr end
                end
                if fr then
                    fr:Show()
                    if def.refresh then pcall(def.refresh, fr) end
                end
            end
        end
    end

    function f.LayoutBar()
        local x = 0
        for _, def in ipairs(Guild.pages) do
            local b = f.buttons[def.id]
            if not b then
                b = UI.CreateButton(bar, "", 128, 26, function() f.Select(def.id) end)
                f.buttons[def.id] = b
            end
            b:SetLabel(def.label())
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
            x = x + 132
        end
    end
    f.LayoutBar()
    main = f
    return f
end

function Guild.OnPageRegistered()
    if main then main.LayoutBar() end
end

UI:RegisterTab("guild", {
    label = function() return FW.L.GUILD_TAB end,
    order = 45,
    build = BuildMain,
    onShow = function(f)
        if #Guild.rows == 0 then Guild.ReadRoster() end
        Guild.RequestRoster()
        f.Select(f.current or "members")
    end,
})

------------------------------------------------------------------------
-- Einstellungen (Core-Einstellungen)
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("guild-module", {
        category = "general",
        order = 60,
        height = 540,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.GUILD_SET_TITLE)
            local function Box(label, key)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return Guild.Setting(key) == true end,
                    function(v) Guild.DB().settings[key] = v and true or false end), { fit = true })
            end
            Box(L.GUILD_SET_PROFILE, "shareProfile")
            Box(L.GUILD_SET_RECIPES, "shareRecipes")
            Box(L.GUILD_SET_GOLD, "shareGold")
            Box(L.GUILD_SET_BOARD, "boardNotify")
            Box(L.GUILD_SET_MAPSHOW, "mapShow")
            Box(L.GUILD_SET_MAPSHARE, "mapShare")
            local sizeLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(sizeLabel, { fit = true, gap = 8 })
            local slider = UI.CreateSlider(f, 240, {
                min = 8, max = 64, step = 2,
                get = function() return tonumber(Guild.Setting("mapSize")) or 24 end,
                set = function(v)
                    Guild.DB().settings.mapSize = v
                    sizeLabel:SetText(string.format(L.GUILD_SET_MAPSIZE, v))
                    if Guild.Map and Guild.Map.Refresh then pcall(Guild.Map.Refresh) end
                end,
            })
            slider.onText = function(v) sizeLabel:SetText(string.format(L.GUILD_SET_MAPSIZE, v)) end
            stack:Add(slider, { height = 20, gap = 4 })
            f.slider = slider
            Box(L.GUILD_SET_MINISHOW, "mapMini")
            local miniLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(miniLabel, { fit = true, gap = 8 })
            local miniSlider = UI.CreateSlider(f, 240, {
                min = 8, max = 32, step = 1,
                get = function() return tonumber(Guild.Setting("miniSize")) or 14 end,
                set = function(v)
                    Guild.DB().settings.miniSize = v
                    if Guild.Map and Guild.Map.RefreshMini then pcall(Guild.Map.RefreshMini) end
                end,
            })
            miniSlider.onText = function(v) miniLabel:SetText(string.format(L.GUILD_SET_MINISIZE, v)) end
            stack:Add(miniSlider, { height = 20, gap = 4 })
            f.miniSlider = miniSlider
            local function Apply() if Guild.Head and Guild.Head.Apply then Guild.Head.Apply() end end
            stack:Add(UI.CreateCheckbox(f, L.GUILD_SET_HEADSHOW,
                function() return Guild.Setting("headShow") ~= false end,
                function(v) Guild.DB().settings.headShow = v and true or false; Apply() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.GUILD_SET_HEADPLATES,
                function() return Guild.Setting("headPlates") ~= false end,
                function(v) Guild.DB().settings.headPlates = v and true or false; Apply() end), { fit = true })
            local headLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(headLabel, { fit = true, gap = 8 })
            local headSlider = UI.CreateSlider(f, 240, {
                min = 16, max = 64, step = 2,
                get = function() return tonumber(Guild.Setting("headSize")) or 28 end,
                set = function(v)
                    Guild.DB().settings.headSize = v
                    Apply()
                end,
            })
            headSlider.onText = function(v) headLabel:SetText(string.format(L.GUILD_SET_HEADSIZE, v)) end
            stack:Add(headSlider, { height = 20, gap = 4 })
            f.headSlider = headSlider
            local note = UI.CreateLabel(f, L.GUILD_SET_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
            note:SetWordWrap(true)
            stack:Add(note, { height = 44, gap = 8 })
            return f
        end,
        refresh = function(frame)
            if frame.slider then frame.slider:Refresh() end
            if frame.miniSlider then frame.miniSlider:Refresh() end
            if frame.headSlider then frame.headSlider:Refresh() end
        end,
    })
end
