-- Freewood-Guild: Seite "Erfolge", Hinweisfenster und Liste der letzten Erfolge. UNGEPRUEFT im Spiel.
-- Hinweis (Forever): ein Label mit mehrzeiligem Text zeigt mit SetWordWrap(false) nur die erste Zeile (F-19), daher
-- ein Label je Zeile; Zeilenrahmen brauchen Breite und Hoehe (F-18).

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Ach then
    return
end

local G = _G
local UI = FW.UI
local Ach = Guild.Ach
if not UI then return end

local ICON_PATH = "Interface\\Icons\\"
local function IconOf(cat)
    for _, c in ipairs(Ach.CATEGORIES) do if c[1] == cat then return ICON_PATH .. c[2] end end
    return ICON_PATH .. "INV_Misc_QuestionMark"
end

local function DateText(ts)
    if not ts or not G.date then return "?" end
    return G.date("%d.%m.%Y", ts)
end

------------------------------------------------------------------------
-- Hinweisfenster
------------------------------------------------------------------------

local toast
local current, queueBusy

local function Build()
    local t = UI.CreatePanel(UIParent, "bgDeep", "gold")
    t:SetSize(360, 66)
    t:SetPoint("TOP", UIParent, "TOP", 0, -170)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(44, 44)
    t.icon:SetPoint("LEFT", t, "LEFT", 10, 0)
    t.title = UI.CreateLabel(t, "", { size = 11, color = "gold" })
    t.title:SetPoint("TOPLEFT", t, "TOPLEFT", 64, -8)
    t.title:SetPoint("TOPRIGHT", t, "TOPRIGHT", -10, -8)
    t.title:SetHeight(14)
    t.name = UI.CreateLabel(t, "", { font = "heading", size = 14, color = "goldLight" })
    t.name:SetPoint("TOPLEFT", t, "TOPLEFT", 64, -24)
    t.name:SetPoint("TOPRIGHT", t, "TOPRIGHT", -10, -24)
    t.name:SetHeight(18)
    t.name:SetWordWrap(false)
    t.pts = UI.CreateLabel(t, "", { size = 11, color = "textDim" })
    t.pts:SetPoint("TOPLEFT", t, "TOPLEFT", 64, -44)
    t.pts:SetPoint("TOPRIGHT", t, "TOPRIGHT", -10, -44)
    t.pts:SetHeight(14)
    t:Hide()
    return t
end

local function Next()
    if queueBusy then return end
    local e = table.remove(Ach.queue, 1)
    if not e then return end
    queueBusy = true
    toast = toast or Build()
    local L = FW.L
    toast.icon:SetTexture(IconOf(e.cat))
    toast.title:SetText(L.ACH_TOAST_TITLE)
    toast.name:SetText(Ach.Text(e.name))
    toast.pts:SetText(string.format(L.ACH_PTS, e.pts))
    toast.left = 8
    toast:SetAlpha(1)
    toast:Show()
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - (elapsed or 0)
        if self.left <= 0 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            queueBusy = false
            Next()
        elseif self.left < 1 then
            self:SetAlpha(self.left)
        end
    end)
end

function Ach.Notify(e)
    Ach.queue[#Ach.queue + 1] = e
    Next()
end

function Ach.TestToast()
    local list = Ach.Catalog()
    if list[1] then Ach.Notify(list[1]) end
end

------------------------------------------------------------------------
-- Liste der letzten Erfolge
------------------------------------------------------------------------

local logWin
function Ach.ShowLog()
    local L = FW.L
    if not logWin then
        local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
        w:SetSize(400, 360)
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        w:SetFrameStrata("DIALOG")
        w:EnableMouse(true)
        w:SetMovable(true)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        w.title = UI.CreateLabel(w, "", { font = "heading", size = 15, color = "goldLight" })
        w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -10)
        w.title:SetHeight(20)
        local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)
        w.scroll = UI.CreateScrollFrame(w)
        w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -38)
        w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -10, 10)
        w.rows = {}
        logWin = w
    end
    local w = logWin
    w.title:SetText(L.ACH_RECENT)
    local byId = {}
    for _, e in ipairs(Ach.Catalog()) do byId[e.id] = e end
    local log = Ach.Db().log
    local n = 0
    for i = #log, 1, -1 do
        local e = byId[log[i][1]]
        if e then
            n = n + 1
            local r = w.rows[n]
            if not r then
                r = CreateFrame("Frame", nil, w.scroll.child)
                r:SetHeight(26)
                r.l = UI.CreateLabel(r, "", { size = 12 })
                r.l:SetPoint("LEFT", r, "LEFT", 6, 0)
                r.l:SetPoint("RIGHT", r, "RIGHT", -110, 0)
                r.l:SetWordWrap(false)
                r.r = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT", color = "textDim" })
                r.r:SetPoint("RIGHT", r, "RIGHT", -6, 0)
                r.r:SetWidth(100)
                w.rows[n] = r
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", w.scroll.child, "TOPLEFT", 0, -(n - 1) * 26)
            r:SetPoint("TOPRIGHT", w.scroll.child, "TOPRIGHT", 0, -(n - 1) * 26)
            r.l:SetText(Ach.Text(e.name))
            r.r:SetText(DateText(log[i][2]))
            r:Show()
        end
    end
    for i = n + 1, #w.rows do w.rows[i]:Hide() end
    w.scroll:SetContentHeight(math.max(n * 26, 30))
    w:Show()
end

------------------------------------------------------------------------
-- Seite
------------------------------------------------------------------------

local HEAD_H, ROW_H = 26, 40

local function BuildPage(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.ACH_TITLE, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    title:SetHeight(20)
    local points = UI.CreateLabel(f, "", { size = 12, color = "gold" })
    points:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -24)
    points:SetHeight(16)

    local notify = UI.CreateCheckbox(f, L.ACH_NOTIFY,
        function() return Guild.Setting("achNotify") ~= false end,
        function(v) Guild.DB().settings.achNotify = v and true or false end)
    notify:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 0)
    notify:SetWidth(330)

    local recent = UI.CreateButton(f, L.ACH_RECENT, 150, 24, function() Ach.ShowLog() end)
    recent:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -28)
    local toggle = UI.CreateButton(f, L.ACH_TOGGLE, 150, 24, function() f.ToggleAll() end)
    toggle:SetPoint("RIGHT", recent, "LEFT", -6, 0)
    local test = UI.CreateButton(f, L.ACH_TEST, 110, 24, function() Ach.TestToast() end)
    test:SetPoint("RIGHT", toggle, "LEFT", -6, 0)

    local info = UI.CreateLabel(f, L.ACH_INFO, { size = 10, color = "textDim" })
    info:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -46)
    info:SetHeight(14)
    info:SetWordWrap(false)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -66)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local child = scroll.child

    local heads, rowPool, rowUsed = {}, {}, 0
    local open = nil
    local function Open()
        if not open then
            local db = Ach.Db()
            db.open = db.open or { dungeon = true }
            open = db.open
        end
        return open
    end

    local function Tip(self)
        if not G.GameTooltip or not self.r then return end
        local r, L2 = self.r, FW.L
        G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        G.GameTooltip:AddLine(Ach.Text(r.entry.name), 1, 0.82, 0)
        G.GameTooltip:AddLine(Ach.Text(r.entry.desc), 0.9, 0.9, 0.9, true)
        G.GameTooltip:AddLine(string.format(L2.ACH_PTS, r.entry.pts), 0.6, 0.8, 1)
        if r.done then
            G.GameTooltip:AddLine(r.ts and string.format(L2.ACH_DONE_ON, DateText(r.ts)) or L2.ACH_DONE, 0.4, 0.9, 0.4)
        else
            G.GameTooltip:AddLine(string.format(L2.ACH_PROGRESS, r.cur, r.goal), 0.7, 0.7, 0.7)
        end
        if r.who and #r.who > 0 then
            G.GameTooltip:AddLine(string.format(L2.ACH_WHO, table.concat(r.who, ", ")), 0.8, 0.8, 0.8, true)
        end
        G.GameTooltip:Show()
    end

    local function Row()
        rowUsed = rowUsed + 1
        local row = rowPool[rowUsed]
        if not row then
            row = CreateFrame("Frame", nil, child)
            row:SetHeight(ROW_H)
            row:EnableMouse(true)
            row.hl = row:CreateTexture(nil, "BACKGROUND")
            row.hl:SetAllPoints(row)
            row.hl:SetColorTexture(UI.Color("hover"))
            row.hl:Hide()
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(28, 28)
            row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.name = UI.CreateLabel(row, "", { size = 12 })
            row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -5)
            row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -150, -5)
            row.name:SetHeight(16)
            row.name:SetWordWrap(false)
            row.desc = UI.CreateLabel(row, "", { size = 10, color = "textDim" })
            row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -22)
            row.desc:SetPoint("TOPRIGHT", row, "TOPRIGHT", -150, -22)
            row.desc:SetHeight(14)
            row.desc:SetWordWrap(false)
            row.pts = UI.CreateLabel(row, "", { size = 12, justify = "RIGHT", color = "gold" })
            row.pts:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -5)
            row.pts:SetWidth(130)
            row.pts:SetHeight(16)
            row.prog = UI.CreateLabel(row, "", { size = 11, justify = "RIGHT" })
            row.prog:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -22)
            row.prog:SetWidth(130)
            row.prog:SetHeight(14)
            row:SetScript("OnEnter", function(self) self.hl:Show(); Tip(self) end)
            row:SetScript("OnLeave", function(self) self.hl:Hide(); if G.GameTooltip then G.GameTooltip:Hide() end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                local fn = scroll.scroll and scroll.scroll:GetScript("OnMouseWheel")
                if fn then fn(scroll.scroll, delta) end
            end)
            rowPool[rowUsed] = row
        end
        return row
    end

    local function Head(i)
        local h = heads[i]
        if not h then
            h = UI.CreateButton(child, "", 100, HEAD_H, function(self)
                local o = Open()
                o[self.catId] = (not o[self.catId]) or nil
                f.Render()
            end, "default")
            h.icon = h:CreateTexture(nil, "OVERLAY")
            h.icon:SetSize(HEAD_H - 6, HEAD_H - 6)
            h.icon:SetPoint("LEFT", h, "LEFT", 6, 0)
            h.label:ClearAllPoints()
            h.label:SetPoint("LEFT", h, "LEFT", HEAD_H + 6, 0)
            h.label:SetJustifyH("LEFT")
            heads[i] = h
        end
        return h
    end

    function f.ToggleAll()
        local o = Open()
        local any = false
        for _, c in ipairs(Ach.CATEGORIES) do if o[c[1]] then any = true end end
        for _, c in ipairs(Ach.CATEGORIES) do o[c[1]] = (not any) or nil end
        f.Render()
    end

    function f.Render()
        local results = Ach.Evaluate()
        local got, total, done, n = Ach.Points(results)
        points:SetText(string.format(L.ACH_POINTS, got, total) .. "   |   " .. string.format(L.ACH_DONE_N, done, n))
        local byCat = {}
        for _, r in ipairs(results) do
            byCat[r.entry.cat] = byCat[r.entry.cat] or {}
            table.insert(byCat[r.entry.cat], r)
        end
        local o = Open()
        local y, hi = 0, 0
        rowUsed = 0
        for _, c in ipairs(Ach.CATEGORIES) do
            local list = byCat[c[1]]
            if list then
                hi = hi + 1
                local h = Head(hi)
                h.catId = c[1]
                local d = 0
                for _, r in ipairs(list) do if r.done then d = d + 1 end end
                h.label:SetText((o[c[1]] and "- " or "+ ") .. (L["ACHC_" .. c[1]] or c[1]) .. "  (" .. d .. "/" .. #list .. ")")
                h.icon:SetTexture(ICON_PATH .. c[2])
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -y)
                h:Show()
                y = y + HEAD_H + 4
                if o[c[1]] then
                    -- erledigte zuletzt, offene nach Naehe zum Ziel zuerst
                    table.sort(list, function(a, b)
                        if a.done ~= b.done then return not a.done end
                        local pa, pb = a.cur / a.goal, b.cur / b.goal
                        if pa ~= pb then return pa > pb end
                        return a.entry.id < b.entry.id
                    end)
                    for _, r in ipairs(list) do
                        local row = Row()
                        row.r = r
                        row.icon:SetTexture(IconOf(r.entry.cat))
                        row.icon:SetDesaturated(not r.done)
                        row.name:SetText(Ach.Text(r.entry.name))
                        row.name:SetTextColor(UI.Color(r.done and "goldLight" or "text"))
                        row.desc:SetText(Ach.Text(r.entry.desc))
                        row.pts:SetText(string.format(L.ACH_PTS, r.entry.pts))
                        if r.done then
                            row.prog:SetText(r.ts and DateText(r.ts) or L.ACH_DONE)
                            row.prog:SetTextColor(UI.Color("success"))
                        else
                            row.prog:SetText(string.format(L.ACH_PROGRESS, r.cur, r.goal))
                            row.prog:SetTextColor(UI.Color("textDim"))
                        end
                        row.hl:Hide()
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -y)
                        row:Show()
                        y = y + ROW_H
                    end
                    y = y + 6
                end
            end
        end
        for i = hi + 1, #heads do heads[i]:Hide() end
        for i = rowUsed + 1, #rowPool do rowPool[i]:Hide() end
        scroll:SetContentHeight(math.max(y, 40))
    end

    f.Refresh = f.Render
    FW:On("GUILD_MODULE_ACH", function() if f:IsVisible() then f.Render() end end, f)
    FW:On("GUILD_MODULE_ROSTER", function() if f:IsVisible() then f.Render() end end, f)
    return f
end

if Guild.RegisterPage then
    Guild.RegisterPage("achievements", {
        order = 70,
        label = function() return FW.L.ACH_TAB end,
        build = BuildPage,
        refresh = function(f) f.Render() end,
    })
end

------------------------------------------------------------------------
-- Befehl
------------------------------------------------------------------------

G.SLASH_FWACH1 = "/fwach"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList["FWACH"] = function(msg)
    if msg == "test" then Ach.TestToast() return end
    if msg == "log" then Ach.ShowLog() return end
    local got, total, done, n = Ach.Points(Ach.Evaluate())
    FW:Print(string.format(FW.L.ACH_POINTS, got, total) .. " | " .. string.format(FW.L.ACH_DONE_N, done, n))
end
