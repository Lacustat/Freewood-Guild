-- Freewood-Guild: Oberflaeche fuer Gildenauftraege und Anfragen (zwei Seiten, ein Erstellfenster, ein Materialfenster).
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Board or not Guild.Widgets then
    return
end

local G = _G
local UI = FW.UI
local W = Guild.Widgets
local Board = Guild.Board

local function Show(frame, on)
    if on then frame:Show() else frame:Hide() end
end

-- Berufe, fuer die es Auftraege gibt
local CRAFT = { 171, 164, 333, 202, 165, 197, 185, 129 }

local function SetTooltip(self, o)
    if not G.GameTooltip or not o then return end
    local L = FW.L
    G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = false
    local link = (o.tt == "i" and "item:" or "spell:") .. o.tid
    if G.GameTooltip.SetHyperlink then
        local ok = pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, link)
        shown = ok
    end
    if not shown then G.GameTooltip:AddLine(Board.TargetName(o) or "?") end
    if #o.mats > 0 then
        G.GameTooltip:AddLine(" ")
        G.GameTooltip:AddLine(L.BOARD_MATS, 1, 0.82, 0)
        for _, m in ipairs(o.mats) do
            local nm = (Board.ItemName(m.i) or ("#" .. m.i))
            if m.h then
                G.GameTooltip:AddLine(string.format("%dx %s - %s", m.n, nm, L.BOARD_HAVE), 0.4, 0.9, 0.4)
            else
                G.GameTooltip:AddLine(string.format("%dx %s - %s", m.n, nm, L.BOARD_MISSING), 0.9, 0.4, 0.35)
            end
        end
    end
    if o.note ~= "" then G.GameTooltip:AddLine(o.note, 0.8, 0.8, 0.5, true) end
    G.GameTooltip:Show()
end

------------------------------------------------------------------------
-- Materialfenster (Haken fuer "habe ich")
------------------------------------------------------------------------

local matWin
function Guild.ShowMats(id)
    local L = FW.L
    local o = Board.Get(id)
    if not o then return end
    if not matWin then
        local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
        w:SetSize(360, 300)
        w:SetPoint("CENTER", UIParent, "CENTER", 40, 40)
        w:SetFrameStrata("DIALOG")
        w:EnableMouse(true)
        w.title = UI.CreateLabel(w, "", { font = "heading", size = 14, color = "goldLight" })
        w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -12)
        w.title:SetPoint("TOPRIGHT", w, "TOPRIGHT", -40, -12)
        w.title:SetWordWrap(false)
        local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)
        w.hint = UI.CreateLabel(w, "", { size = 11, color = "textDim" })
        w.hint:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -34)
        w.hint:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -34)
        w.rows = {}
        w:Hide()
        matWin = w
    end
    local w = matWin
    w.id = id
    function w.Fill()
        local cur = Board.Get(w.id)
        if not cur then w:Hide() return end
        w.title:SetText(Board.TargetName(cur) .. " x" .. cur.qty)
        local can = Board.CanEdit(cur)
        w.hint:SetText(can and L.BOARD_MATS_HINT or L.BOARD_MATS_VIEW)
        for i, m in ipairs(cur.mats) do
            local r = w.rows[i]
            if not r then
                r = {}
                r.name = UI.CreateLabel(w, "", { size = 12 })
                r.btn = UI.CreateButton(w, "", 110, 22, nil)
                w.rows[i] = r
            end
            r.name:ClearAllPoints()
            r.name:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -62 - (i - 1) * 30)
            r.name:SetWidth(210)
            r.name:SetWordWrap(false)
            r.name:SetText(string.format("%dx %s", m.n, Board.ItemName(m.i) or ("#" .. m.i)))
            r.btn:ClearAllPoints()
            r.btn:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -58 - (i - 1) * 30)
            r.btn:SetLabel(m.h and L.BOARD_HAVE or L.BOARD_MISSING)
            r.btn:SetStyle(m.h and "primary" or "default")
            r.btn:SetScript("OnClick", function()
                if can then Board.SetMat(w.id, i, not m.h) end
            end)
            r.name:Show(); r.btn:Show()
        end
        for i = #cur.mats + 1, #w.rows do w.rows[i].name:Hide(); w.rows[i].btn:Hide() end
        if #cur.mats == 0 then w.hint:SetText(L.BOARD_NO_MATS) end
    end
    w.Fill()
    w:Show()
end

FW:On("GUILD_MODULE_BOARD", function() if matWin and matWin:IsShown() and matWin.Fill then matWin.Fill() end end)

------------------------------------------------------------------------
-- Erstellfenster
------------------------------------------------------------------------

local createWin
local function BuildCreate()
    local L = FW.L
    local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
    w:SetSize(470, 520)
    w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    w:SetFrameStrata("DIALOG")
    w:EnableMouse(true)
    w:Hide()
    w.title = UI.CreateLabel(w, "", { font = "heading", size = 15, color = "goldLight" })
    w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -12)
    local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
    close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)

    w.state = { k = "O", prof = 171, tt = "r", tid = nil, mats = {}, mode = "target" }

    -- Art (nur bei Anfragen)
    w.typeItem = UI.CreateButton(w, L.BOARD_TYPE_ITEM, 120, 24, function() w.state.tt = "i"; w.state.tid = nil; w.state.mats = {}; w.Refresh() end)
    w.typeItem:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -40)
    w.typeRecipe = UI.CreateButton(w, L.BOARD_TYPE_RECIPE, 120, 24, function() w.state.tt = "r"; w.state.tid = nil; w.Refresh() end)
    w.typeRecipe:SetPoint("LEFT", w.typeItem, "RIGHT", 6, 0)

    -- Beruf
    w.profLabel = UI.CreateLabel(w, L.BOARD_PROFESSION, { size = 11, color = "textDim" })
    w.profLabel:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -74)
    w.profDD = UI.CreateDropdown(w, 220, 22, {
        getOptions = function()
            local list = {}
            for _, id in ipairs(CRAFT) do list[#list + 1] = { value = id, text = Guild.ProfName(id) } end
            return list
        end,
        textOf = function(v) return Guild.ProfName(v) end,
        onChange = function(v) if v then w.state.prof = v; w.state.tid = nil; w.Refresh() end end,
    })
    w.profDD:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -90)

    -- Suche
    w.modeTarget = UI.CreateButton(w, "", 150, 22, function() w.state.mode = "target"; w.search:SetText(""); w.Refresh() end)
    w.modeTarget:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -122)
    w.modeMat = UI.CreateButton(w, L.BOARD_ADD_MAT, 150, 22, function() w.state.mode = "mat"; w.search:SetText(""); w.Refresh() end)
    w.modeMat:SetPoint("LEFT", w.modeTarget, "RIGHT", 6, 0)
    w.search = W.Edit(w, 440, 24)
    w.search:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -148)
    w.search.onChange = function() w.Results() end
    w.resultButtons = {}
    for i = 1, 6 do
        local b = UI.CreateButton(w, "", 440, 20, nil)
        b:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -178 - (i - 1) * 22)
        b:Hide()
        w.resultButtons[i] = b
    end
    w.noResult = UI.CreateLabel(w, "", { size = 11, color = "textDim" })
    w.noResult:SetPoint("TOPLEFT", w, "TOPLEFT", 16, -180)

    -- Auswahl, Menge, Notiz
    w.selected = UI.CreateLabel(w, "", { size = 13, color = "goldLight" })
    w.selected:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -318)
    w.selected:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -318)
    w.selected:SetWordWrap(false)
    local qtyL = UI.CreateLabel(w, L.BOARD_QTY, { size = 11, color = "textDim" })
    qtyL:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -342)
    w.qty = W.Edit(w, 60, 24)
    w.qty:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -358)
    w.qty:SetText("1")
    local noteL = UI.CreateLabel(w, L.BOARD_NOTE, { size = 11, color = "textDim" })
    noteL:SetPoint("TOPLEFT", w, "TOPLEFT", 90, -342)
    w.note = W.Edit(w, 364, 24)
    w.note:SetPoint("TOPLEFT", w, "TOPLEFT", 90, -358)
    if w.note.edit and w.note.edit.SetMaxLetters then w.note.edit:SetMaxLetters(60) end

    -- Materialien
    w.matsLabel = UI.CreateLabel(w, "", { size = 11, color = "textDim" })
    w.matsLabel:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -392)
    w.matRows = {}
    for i = 1, 6 do
        local name = UI.CreateLabel(w, "", { size = 12 })
        name:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -410 - (i - 1) * 16)
        name:SetWidth(230)
        name:SetWordWrap(false)
        local have = UI.CreateButton(w, "", 110, 16, nil)
        have:SetPoint("TOPLEFT", w, "TOPLEFT", 256, -408 - (i - 1) * 16)
        local del = UI.CreateButton(w, "X", 20, 16, nil)
        del:SetPoint("LEFT", have, "RIGHT", 4, 0)
        w.matRows[i] = { name = name, have = have, del = del }
    end

    w.status = UI.CreateLabel(w, "", { size = 12, color = "danger" })
    w.status:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 14, 46)
    w.status:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -14, 46)
    w.ok = UI.CreateButton(w, L.BOARD_CREATE, 160, 28, function()
        local st = w.state
        if not st.tid then w.status:SetText(L.BOARD_ERR_TARGET) return end
        local o, why = Board.Create({
            k = st.k, prof = st.tt == "r" and st.prof or 0, tt = st.tt, tid = st.tid,
            qty = tonumber(w.qty:GetText()) or 1, note = w.note:GetText(), mats = st.mats,
        })
        if not o then w.status:SetText(why == "guild" and L.BOARD_ERR_GUILD or L.BOARD_ERR_TARGET) return end
        w:Hide()
    end, "primary")
    w.ok:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 14, 12)
    local cancel = UI.CreateButton(w, L.BOARD_CANCEL, 120, 28, function() w:Hide() end)
    cancel:SetPoint("LEFT", w.ok, "RIGHT", 8, 0)

    function w.Results()
        local st = w.state
        local q = w.search:GetText()
        local list = {}
        local searchItem = (st.mode == "mat") or (st.tt == "i")
        if searchItem then
            list = Board.SearchItems(q, 6)
        else
            list = Board.RecipesFor(st.prof, q)
        end
        local shown = math.min(#list, 6)
        for i = 1, 6 do
            local b = w.resultButtons[i]
            local e = list[i]
            if e then
                b:SetLabel(e.name)
                b.label:SetJustifyH("LEFT")
                b:SetScript("OnClick", function()
                    if st.mode == "mat" then
                        if #st.mats < 6 then st.mats[#st.mats + 1] = { i = e.id, n = 1, h = false } end
                        st.mode = "target"
                        w.search:SetText("")
                    else
                        st.tid = e.id
                        st.targetName = e.name
                        if st.tt == "r" then
                            local mats = (Guild.RecipeMats and Guild.RecipeMats(e.id)) or Board.MatsFor(e.name)
                            if mats then st.mats = mats end
                        end
                    end
                    w.Refresh()
                end)
                b:Show()
            else
                b:Hide()
            end
        end
        if shown == 0 then
            w.noResult:SetText(searchItem and (#q < 3 and L.BOARD_TYPE_3 or L.BOARD_NO_ITEMS) or L.BOARD_NO_RECIPES)
            w.noResult:Show()
        else
            w.noResult:Hide()
        end
    end

    function w.Refresh()
        local st = w.state
        w.title:SetText(st.k == "O" and L.BOARD_CREATE_ORDER or L.BOARD_CREATE_REQUEST)
        Show(w.typeItem, st.k == "R")
        Show(w.typeRecipe, st.k == "R")
        w.typeItem:SetStyle(st.tt == "i" and "primary" or "default")
        w.typeRecipe:SetStyle(st.tt == "r" and "primary" or "default")
        local needProf = st.tt == "r"
        Show(w.profLabel, needProf)
        Show(w.profDD, needProf)
        w.profDD:SetValue(st.prof)
        w.modeTarget:SetLabel(st.tt == "i" and L.BOARD_SEARCH_ITEM or L.BOARD_SEARCH_RECIPE)
        w.modeTarget:SetStyle(st.mode == "target" and "primary" or "default")
        w.modeMat:SetStyle(st.mode == "mat" and "primary" or "default")
        w.selected:SetText(st.tid and ((st.targetName or ("#" .. st.tid)) .. "") or L.BOARD_NOTHING_SELECTED)
        w.matsLabel:SetText(string.format(L.BOARD_MATS_COUNT, #st.mats))
        for i = 1, 6 do
            local r, m = w.matRows[i], st.mats[i]
            if m then
                r.name:SetText(string.format("%dx %s", m.n, Board.ItemName(m.i) or ("#" .. m.i)))
                r.have:SetLabel(m.h and L.BOARD_HAVE or L.BOARD_MISSING)
                r.have:SetStyle(m.h and "primary" or "default")
                r.have:SetScript("OnClick", function() m.h = not m.h; w.Refresh() end)
                r.del:SetScript("OnClick", function() table.remove(st.mats, i); w.Refresh() end)
                r.name:Show(); r.have:Show(); r.del:Show()
            else
                r.name:Hide(); r.have:Hide(); r.del:Hide()
            end
        end
        w.Results()
    end
    return w
end

function Guild.ShowCreate(kind)
    if not createWin then createWin = BuildCreate() end
    local w = createWin
    w.state = { k = kind == "R" and "R" or "O", prof = 171, tt = kind == "R" and "i" or "r", tid = nil, mats = {}, mode = "target" }
    w.search:SetText("")
    w.note:SetText("")
    w.qty:SetText("1")
    w.status:SetText("")
    w.Refresh()
    w:Show()
end

------------------------------------------------------------------------
-- Seiten
------------------------------------------------------------------------

local ROW_H = 46

local function BuildPage(kind)
    return function(content)
        local L = FW.L
        local f = CreateFrame("Frame", nil, content)
        f.filter = "open"

        local newBtn = UI.CreateButton(f, kind == "O" and L.BOARD_NEW_ORDER_BTN or L.BOARD_NEW_REQUEST_BTN, 190, 26, function()
            Guild.ShowCreate(kind)
        end, "primary")
        newBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        local dd = UI.CreateDropdown(f, 150, 24, {
            getOptions = function()
                return { { value = "open", text = L.BOARD_F_OPEN }, { value = "mine", text = L.BOARD_F_MINE }, { value = "all", text = L.BOARD_F_ALL } }
            end,
            textOf = function(v) return v == "open" and L.BOARD_F_OPEN or v == "mine" and L.BOARD_F_MINE or L.BOARD_F_ALL end,
            onChange = function(v) if v then f.filter = v; f.Refresh() end end,
        })
        dd:SetPoint("LEFT", newBtn, "RIGHT", 10, 0)
        dd:SetValue("open")
        local info = UI.CreateLabel(f, kind == "O" and L.BOARD_INFO_ORDER or L.BOARD_INFO_REQUEST, { size = 11, color = "textDim", justify = "RIGHT" })
        info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -6)
        info:SetWordWrap(false)
        local empty = UI.CreateLabel(f, L.BOARD_EMPTY, { size = 12, color = "textDim" })
        empty:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -50)

        local scroll = UI.CreateScrollFrame(f)
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -36)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        local rows = {}

        local function GetRow(i)
            local r = rows[i]
            if r then return r end
            r = CreateFrame("Frame", nil, scroll.child)
            r:SetHeight(ROW_H - 4)
            r:EnableMouse(true)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            r.bg:SetColorTexture(UI.Color("card", 0.8))
            r.line1 = UI.CreateLabel(r, "", { font = "heading", size = 13 })
            r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", 8, -5)
            r.line1:SetPoint("RIGHT", r, "RIGHT", -300, 0)
            r.line1:SetWordWrap(false)
            r.line2 = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
            r.line2:SetPoint("TOPLEFT", r, "TOPLEFT", 8, -23)
            r.line2:SetPoint("RIGHT", r, "RIGHT", -300, 0)
            r.line2:SetWordWrap(false)
            r.del = UI.CreateButton(r, L.BOARD_DELETE, 70, 22, function() if r.o then Board.Delete(r.o.id) end end)
            r.del:SetPoint("RIGHT", r, "RIGHT", -6, 0)
            r.done = UI.CreateButton(r, L.BOARD_DONE, 80, 22, function() if r.o then Board.SetDone(r.o.id, not r.o.done) end end)
            r.done:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
            r.take = UI.CreateButton(r, L.BOARD_TAKE, 96, 22, function() if r.o then Board.Take(r.o.id) end end)
            r.take:SetPoint("RIGHT", r.done, "LEFT", -4, 0)
            r.mats = UI.CreateButton(r, L.BOARD_MATS_BTN, 96, 22, function() if r.o then Guild.ShowMats(r.o.id) end end)
            r.mats:SetPoint("RIGHT", r.take, "LEFT", -4, 0)
            r:SetScript("OnEnter", function(self) SetTooltip(self, self.o) end)
            r:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
            rows[i] = r
            return r
        end

        function f.Refresh()
            local list = Board.List(kind)
            local me = Guild.SelfKey()
            local shown = {}
            for _, o in ipairs(list) do
                local ok = f.filter == "all" or (f.filter == "open" and not o.done)
                    or (f.filter == "mine" and (Guild.Key(o.by) == me or Guild.Key(o.taker or "") == me))
                if ok then shown[#shown + 1] = o end
            end
            for i, o in ipairs(shown) do
                local r = GetRow(i)
                r.o = o
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * ROW_H)
                r:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * ROW_H)
                local nm = Board.TargetName(o)
                local prof = (o.tt == "r" and o.prof > 0) and ("[" .. Guild.ProfName(o.prof) .. "] ") or ""
                r.line1:SetText(prof .. nm .. " x" .. o.qty)
                r.line1:SetTextColor(UI.Color(o.done and "textDim" or "text"))
                local age = Board.AgeText(o)
                local have, total = Board.MatsCount(o)
                local status = o.done and L.BOARD_STATUS_DONE or (o.taker and string.format(L.BOARD_STATUS_TAKEN, o.taker) or L.BOARD_STATUS_OPEN)
                local parts = { string.format(L.BOARD_BY, o.by), age, status }
                if total > 0 then parts[#parts + 1] = string.format(L.BOARD_MATS_STATE, have, total) end
                if o.note ~= "" then parts[#parts + 1] = o.note end
                r.line2:SetText(table.concat(parts, "  -  "))
                local canEdit = Board.CanEdit(o)
                local mine = Guild.Key(o.taker or "") == me
                Show(r.del, canEdit)
                Show(r.done, canEdit or mine)
                r.done:SetLabel(o.done and L.BOARD_REOPEN or L.BOARD_DONE)
                Show(r.take, not o.done and (not o.taker or mine or canEdit))
                r.take:SetLabel(mine and L.BOARD_RELEASE or L.BOARD_TAKE)
                Show(r.mats, total > 0)
                r:Show()
            end
            for i = #shown + 1, #rows do rows[i].o = nil; rows[i]:Hide() end
            scroll:SetContentHeight(#shown * ROW_H + 4)
            Show(empty, #shown == 0)
        end

        FW:On("GUILD_MODULE_BOARD", function() if f:IsVisible() then f.Refresh() end end, f)
        f.kind = kind
        if kind == "O" then Guild.OrdersFrame = f else Guild.RequestsFrame = f end
        return f
    end
end

Guild.RegisterPage("orders", {
    order = 40,
    label = function() return FW.L.BOARD_TAB_ORDERS end,
    build = BuildPage("O"),
    refresh = function(f) f.Refresh() end,
})
Guild.RegisterPage("requests", {
    order = 50,
    label = function() return FW.L.BOARD_TAB_REQUESTS end,
    build = BuildPage("R"),
    refresh = function(f) f.Refresh() end,
})
