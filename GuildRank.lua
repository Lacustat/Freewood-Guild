-- Freewood-Guild: Level-Ranking. Wer levelt am schnellsten? Wertung = Gesamt-EP geteilt durch Spielzeit (EP pro Stunde).
-- Oben die vier Besten als Highlight (Leuchten, VS), darunter die Tabelle. Mit "Folgen" gibt es Hinweise bei Platzwechsel.
-- Die EP-Tabelle ist die aus Vanilla (Guild.XP_NEXT); Forever kann abweichen. UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local R = {}
Guild.Rank = R

local TOP = 4
local WATCH = 10                 -- so viele Plaetze werden beobachtet
local CHECK_EVERY = 60

local function Show(frame, on)
    if on then frame:Show() else frame:Hide() end
end

------------------------------------------------------------------------
-- Rangliste berechnen
------------------------------------------------------------------------

function R.List()
    local out = {}
    local db = Guild.DB()
    for _, row in ipairs(Guild.rows) do
        local sh = db.members[row.key]
        if sh and sh.played and sh.played > 0 and (row.level or 0) > 0 then
            local xp = (sh.level == row.level) and sh.xp or 0
            local total = Guild.TotalXP(row.level, xp)
            local hours = sh.played / 3600
            out[#out + 1] = {
                name = row.name, key = row.key, class = row.class, level = row.level,
                frac = (sh.level == row.level) and Guild.XPFraction(sh.level, sh.xp, sh.xpmax) or nil,
                played = sh.played, total = total, score = total / math.max(hours, 0.05),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.level ~= b.level then return a.level > b.level end
        return string.lower(a.name) < string.lower(b.name)
    end)
    for i, e in ipairs(out) do e.pos = i end
    return out
end

local function FormatScore(s)
    s = tonumber(s) or 0
    if s >= 1000 then return string.format("%.1fk", s / 1000) end
    return string.format("%d", math.floor(s))
end
R.FormatScore = FormatScore

-- Kopf an Kopf: Abstand der ersten beiden unter 5 Prozent
function R.CloseBattle(list)
    list = list or R.List()
    if #list >= 2 and list[1].score > 0 then
        return (list[1].score - list[2].score) / list[1].score < 0.05
    end
    return false
end

------------------------------------------------------------------------
-- Folgen: Hinweis bei Platzwechsel
------------------------------------------------------------------------

local lastCheck = -1000

function R.Check(force)
    local now = G.GetTime and G.GetTime() or 0
    if not force and now - lastCheck < CHECK_EVERY then return nil end
    lastCheck = now
    local list = R.List()
    local db = Guild.DB()
    local prev = db.rankSnap
    local cur = {}
    for i = 1, math.min(#list, WATCH) do cur[i] = list[i].key end
    local msgs = {}
    if type(prev) == "table" and #prev > 0 then
        local prevPos = {}
        for i, k in ipairs(prev) do prevPos[k] = i end
        for i, k in ipairs(cur) do
            local p = prevPos[k]
            if p == nil or p > i then
                local e = list[i]
                if p then
                    msgs[#msgs + 1] = string.format(FW.L.RANK_MOVED, e.name, i, p)
                else
                    msgs[#msgs + 1] = string.format(FW.L.RANK_ENTERED, e.name, i)
                end
            end
        end
    end
    db.rankSnap = cur
    if Guild.Setting("follow") and #msgs > 0 and Guild.Toast then
        local shown = {}
        for i = 1, math.min(#msgs, 2) do shown[i] = msgs[i] end
        Guild.Toast(FW.L.RANK_TOAST .. "\n" .. table.concat(shown, "\n"))
    end
    return msgs
end

FW:On("GUILD_MODULE_DATA", function() pcall(R.Check, false) end)
FW:On("GUILD_MODULE_ROSTER", function() pcall(R.Check, false) end)

------------------------------------------------------------------------
-- Seite
------------------------------------------------------------------------

local MEDAL = { { 1, 0.82, 0.2 }, { 0.78, 0.8, 0.85 }, { 0.8, 0.5, 0.25 }, { 0.5, 0.65, 0.9 } }

local function Build(content)
    local L = FW.L
    local UI = FW.UI
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.RANK_TITLE, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local follow = UI.CreateCheckbox(f, L.RANK_FOLLOW,
        function() return Guild.Setting("follow") == true end,
        function(v) Guild.DB().settings.follow = v and true or false end)
    follow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -150, 2)
    follow:SetWidth(240)
    local info = UI.CreateLabel(f, L.RANK_INFO, { size = 11, color = "textDim" })
    info:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -26)
    info:SetWordWrap(false)

    ------------------------------------------------------------------
    -- Highlight: die Besten vier
    ------------------------------------------------------------------
    local arena = UI.CreatePanel(f, "bgDeep", "bronze")
    arena:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -48)
    arena:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -48)
    arena:SetHeight(176)
    local battle = UI.CreateLabel(arena, "", { font = "heading", size = 13, color = "danger", justify = "CENTER", flags = "OUTLINE" })
    battle:SetPoint("TOP", arena, "TOP", 0, -6)

    local cards = {}
    local vs = {}
    for i = 1, TOP do
        local c = UI.CreatePanel(arena, "card", "gold")
        c:SetHeight(116)
        c.glow = c:CreateTexture(nil, "BACKGROUND")
        c.glow:SetPoint("TOPLEFT", c, "TOPLEFT", -6, 6)
        c.glow:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 6, -6)
        c.glow:SetColorTexture(MEDAL[i][1], MEDAL[i][2], MEDAL[i][3], 0.25)
        c.glow:SetBlendMode("ADD")
        c.place = UI.CreateLabel(c, tostring(i), { font = "heading", size = 26, flags = "OUTLINE", justify = "CENTER" })
        c.place:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -8)
        c.place:SetTextColor(MEDAL[i][1], MEDAL[i][2], MEDAL[i][3])
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(30, 30)
        c.icon:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -8)
        c.name = UI.CreateLabel(c, "", { font = "heading", size = 14, justify = "CENTER" })
        c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -48)
        c.name:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -48)
        c.name:SetWordWrap(false)
        c.lv = UI.CreateLabel(c, "", { size = 12, justify = "CENTER", color = "textDim" })
        c.lv:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -68)
        c.lv:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -68)
        c.score = UI.CreateLabel(c, "", { font = "heading", size = 13, justify = "CENTER", color = "goldLight" })
        c.score:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -86)
        c.score:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -86)
        c.barBg = c:CreateTexture(nil, "ARTWORK")
        c.barBg:SetColorTexture(UI.Color("bgDeep"))
        c.barBg:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 8, 8)
        c.barBg:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 8)
        c.barBg:SetHeight(8)
        c.barFill = c:CreateTexture(nil, "OVERLAY")
        c.barFill:SetColorTexture(MEDAL[i][1], MEDAL[i][2], MEDAL[i][3], 1)
        c.barFill:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 8, 8)
        c.barFill:SetHeight(8)
        cards[i] = c
        if i < TOP then
            local v = UI.CreateLabel(arena, "VS", { font = "heading", size = 20, flags = "OUTLINE", justify = "CENTER" })
            v:SetTextColor(UI.Color("danger"))
            vs[i] = v
        end
    end

    local function LayoutArena()
        local w = arena:GetWidth()
        if not w or w < 300 then w = 900 end
        local gap = 54
        local cw = math.floor((w - 24 - gap * (TOP - 1)) / TOP)
        for i = 1, TOP do
            local c = cards[i]
            c:SetWidth(cw)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", arena, "TOPLEFT", 12 + (i - 1) * (cw + gap), -34)
            if vs[i] then
                vs[i]:ClearAllPoints()
                vs[i]:SetPoint("CENTER", c, "RIGHT", gap / 2, 0)
            end
        end
    end
    arena:SetScript("OnSizeChanged", LayoutArena)

    -- Leuchten pulsiert
    local t = 0
    arena:SetScript("OnUpdate", function(_, elapsed)
        t = t + (elapsed or 0)
        local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
        for i = 1, TOP do
            local c = cards[i]
            if c:IsShown() then
                local base = (i <= 2) and 0.28 or 0.14
                c.glow:SetAlpha(base + pulse * ((i <= 2) and 0.32 or 0.14))
            end
        end
        for i = 1, TOP - 1 do
            if vs[i] and vs[i]:IsShown() then vs[i]:SetAlpha(0.65 + pulse * 0.35) end
        end
        if battle:IsShown() then battle:SetAlpha(0.55 + pulse * 0.45) end
    end)

    ------------------------------------------------------------------
    -- Tabelle
    ------------------------------------------------------------------
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -232)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -232)
    head:SetHeight(22)
    local heads = {}
    local HCOL = { { "#", 0.05 }, { L.GUILD_COL_NAME, 0.3 }, { L.GUILD_COL_LEVEL, 0.1 }, { L.GUILD_COL_XP, 0.25 }, { L.GUILD_COL_PLAYED, 0.15 }, { L.RANK_COL_SCORE, 0.15 } }
    local function LayoutCols(totalW)
        local x = 0
        local pos = {}
        for i, c in ipairs(HCOL) do
            local w = math.floor(totalW * c[2])
            pos[i] = { x, w }
            x = x + w
        end
        return pos
    end
    for i, c in ipairs(HCOL) do
        heads[i] = UI.CreateLabel(head, c[1], { size = 11, color = "textDim" })
    end

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -256)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local rows = {}
    local RH = 22

    local function GetRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, scroll.child)
        r:SetHeight(RH)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.cells = {}
        for k = 1, #HCOL do r.cells[k] = UI.CreateLabel(r, "", { size = 12 }); r.cells[k]:SetWordWrap(false) end
        r.barBg = r:CreateTexture(nil, "ARTWORK")
        r.barBg:SetColorTexture(UI.Color("card"))
        r.barFill = r:CreateTexture(nil, "OVERLAY")
        r.barFill:SetColorTexture(UI.Color("bronze"))
        rows[i] = r
        return r
    end

    function f.Refresh()
        local list = R.List()
        local w = f:GetWidth()
        if not w or w < 300 then w = 900 end
        w = w - 14
        local pos = LayoutCols(w)
        for i, h in ipairs(heads) do
            h:ClearAllPoints()
            h:SetPoint("LEFT", head, "LEFT", pos[i][1] + 4, 0)
        end
        LayoutArena()
        -- Highlight
        local close = R.CloseBattle(list)
        battle:SetText(close and L.RANK_BATTLE or "")
        Show(battle, close)
        for i = 1, TOP do
            local e, c = list[i], cards[i]
            if e then
                c:Show()
                c.name:SetText(e.name)
                if FW.ChatLog then c.name:SetTextColor(FW.ChatLog.ClassColor(e.class)) end
                c.lv:SetText(string.format(L.RANK_LEVEL, e.level))
                c.score:SetText(FormatScore(e.score) .. " " .. L.RANK_UNIT)
                if FW.ChatLog and e.class and FW.ChatLog.ICON_COORDS[e.class] then
                    c.icon:SetTexture(FW.ChatLog.ICON_FILE)
                    c.icon:SetTexCoord(unpack(FW.ChatLog.ICON_COORDS[e.class]))
                    c.icon:Show()
                else
                    c.icon:Hide()
                end
                local cw = c:GetWidth()
                c.barFill:SetWidth(math.max(1, (cw - 16) * (e.frac or 0)))
            else
                c:Hide()
            end
            if vs[i] then Show(vs[i], list[i] ~= nil and list[i + 1] ~= nil) end
        end
        -- Tabelle
        local n = math.min(#list, 150)
        for i = 1, n do
            local e = list[i]
            local r = GetRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * RH)
            r:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * RH)
            r.bg:SetColorTexture(UI.Color(i % 2 == 0 and "card" or "bgDeep", 0.5))
            local vals = { tostring(i), e.name, tostring(e.level), "", Guild.FormatPlayed(e.played), FormatScore(e.score) }
            for k = 1, #HCOL do
                local cell = r.cells[k]
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", r, "LEFT", pos[k][1] + 4, 0)
                cell:SetWidth(pos[k][2] - 8)
                cell:SetText(vals[k])
                cell:SetTextColor(UI.Color("text"))
            end
            if FW.ChatLog then r.cells[2]:SetTextColor(FW.ChatLog.ClassColor(e.class)) end
            if i <= TOP then r.cells[1]:SetTextColor(MEDAL[i][1], MEDAL[i][2], MEDAL[i][3]) end
            r.barBg:ClearAllPoints()
            r.barBg:SetPoint("LEFT", r, "LEFT", pos[4][1] + 4, 0)
            r.barBg:SetSize(pos[4][2] - 10, 10)
            r.barFill:ClearAllPoints()
            r.barFill:SetPoint("LEFT", r.barBg, "LEFT", 0, 0)
            r.barFill:SetHeight(10)
            r.barFill:SetWidth(math.max(1, (pos[4][2] - 10) * (e.frac or 0)))
            Show(r.barFill, e.frac ~= nil)
            r:Show()
        end
        for i = n + 1, #rows do rows[i]:Hide() end
        scroll:SetContentHeight(n * RH + 4)
        info:SetText(#list == 0 and L.RANK_EMPTY or L.RANK_INFO)
    end

    FW:On("GUILD_MODULE_DATA", function() if f:IsVisible() then f.Refresh() end end, f)
    FW:On("GUILD_MODULE_ROSTER", function() if f:IsVisible() then f.Refresh() end end, f)
    R.frame = f
    return f
end

Guild.RegisterPage("ranking", {
    order = 30,
    label = function() return FW.L.RANK_TAB end,
    build = Build,
    refresh = function(f) f.Refresh() end,
})
