-- Freewood-Guild: Dungeon-Browser (Seite im Gilden-Fenster). Zeigt, wer in der Gilde nach einer Gruppe sucht, je Dungeon mit
-- Rollen, dazu einen Gruppenvorschlag mit "Einladen" und drei Haken (Zeile im Gildenchat, Einladungen von Gildenmitgliedern
-- und von Freunden bei laufender Suche annehmen). Alles UNGEPRUEFT im Spiel.
--
-- Inhalt: Hilfen, Zeilen, Seite

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Dungeon or not Guild.RegisterPage then
    return
end

local G = _G
local UI = FW.UI
local Dung = Guild.Dungeon
if not UI then return end

local ROW_H = 40

local function Show(frame, on)
    if on then frame:Show() else frame:Hide() end
end

local function AgoText(seconds)
    local L = FW.L
    seconds = math.max(0, seconds or 0)
    if seconds < 60 then return L.GUILD_AGO_NOW end
    return string.format(L.GUILD_AGO_MIN, math.floor(seconds / 60))
end

local function MissingText(missing)
    local L = FW.L
    local n = { T = 0, H = 0, D = 0 }
    for _, r in ipairs(missing) do n[r] = n[r] + 1 end
    local out = {}
    if n.T > 0 then out[#out + 1] = L.DUNG_ROLE_T end
    if n.H > 0 then out[#out + 1] = L.DUNG_ROLE_H end
    if n.D > 0 then out[#out + 1] = n.D .. "x " .. L.DUNG_ROLE_D end
    return table.concat(out, ", ")
end

local function PlanText(plan)
    local L = FW.L
    local parts = {}
    local function Add(e, role)
        if e then parts[#parts + 1] = e.name .. " (" .. role .. ")" end
    end
    Add(plan.T, L.DUNG_ROLE_T)
    Add(plan.H, L.DUNG_ROLE_H)
    for _, e in ipairs(plan.D) do Add(e, L.DUNG_ROLE_D) end
    if #parts == 0 then return L.DUNG_NO_PLAN end
    local text = table.concat(parts, ", ")
    if #plan.missing > 0 then text = text .. "  -  " .. string.format(L.DUNG_MISSING, MissingText(plan.missing)) end
    return text
end

------------------------------------------------------------------------
-- Seite
------------------------------------------------------------------------

local function BuildPage(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)

    local title = UI.CreateLabel(f, L.DUNG_TITLE, { font = "heading", size = 16, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    title:SetHeight(20)

    local function Box(text, key, y, after)
        local c = UI.CreateCheckbox(f, text,
            function() return Guild.Setting(key) == true end,
            function(v)
                Guild.DB().settings[key] = v and true or false
                if after then pcall(after) end
            end)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
        c:SetWidth(520)
        return c
    end
    Box(L.DUNG_SET_CHAT, "dungChat", -24)
    Box(L.DUNG_SET_AUTO_GUILD, "dungAutoGuild", -46)
    Box(L.DUNG_SET_AUTO_FRIENDS, "dungAutoFriends", -68)
    Box(L.DUNG_SET_WIN, "dungWin", -90, function() if Guild.DungeonWin and Guild.DungeonWin.Refresh then Guild.DungeonWin.Refresh() end end)

    -- Erklaerung als goldenes "i" aus dem Core (0.10.0)
    if UI.CreateInfoIcon then UI.CreateInfoIcon(f, L.DUNG_TITLE, L.DUNG_INFO):SetPoint("LEFT", title, "RIGHT", 6, 0) end

    local empty = UI.CreateLabel(f, L.DUNG_EMPTY, { size = 12, color = "textDim" })
    empty:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -130)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -120)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local rows = {}

    local function GetRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, scroll.child)
        r:SetHeight(ROW_H - 4)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.line1 = UI.CreateLabel(r, "", { font = "heading", size = 13 })
        r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", 8, -5)
        r.line1:SetPoint("RIGHT", r, "RIGHT", -140, 0)
        r.line1:SetWordWrap(false)
        r.line2 = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
        r.line2:SetPoint("TOPLEFT", r, "TOPLEFT", 8, -23)
        r.line2:SetPoint("RIGHT", r, "RIGHT", -140, 0)
        r.line2:SetWordWrap(false)
        r.btn = UI.CreateButton(r, L.DUNG_INVITE, 120, 22, function()
            if r.plan then
                local n = Dung.InviteAll(r.plan)
                FW:Print(string.format(L.DUNG_INVITED, n))
            end
        end, "primary")
        r.btn:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        rows[i] = r
        return r
    end

    function f.Refresh()
        local list = Dung.List()
        local groups = Dung.SuggestByLabel(list)
        local i = 0
        for _, g in ipairs(groups) do
            -- Kopfzeile: Dungeon mit Vorschlag
            i = i + 1
            local h = GetRow(i)
            h.bg:SetColorTexture(UI.Color("bgDeep", 0.9))
            h.line1:SetText(g.label)
            h.line1:SetTextColor(UI.Color("goldLight"))
            h.line2:SetText(L.DUNG_PLAN .. PlanText(g.plan))
            h.line2:SetTextColor(UI.Color("text"))
            h.plan = g.plan
            local canInvite = g.plan.inviter and g.plan.inviter.self and g.plan.count > 1
            if g.plan.inviter and not g.plan.inviter.self and g.plan.count > 1 then
                h.line2:SetText(L.DUNG_PLAN .. PlanText(g.plan) .. "  -  " .. string.format(L.DUNG_INVITER, g.plan.inviter.name))
            end
            Show(h.btn, canInvite and true or false)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * ROW_H)
            h:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * ROW_H)
            h:Show()
            for _, e in ipairs(g.members) do
                i = i + 1
                local r = GetRow(i)
                r.bg:SetColorTexture(UI.Color("card", 0.8))
                r.plan = nil
                Show(r.btn, false)
                local name = ((e.members and #e.members > 1) and table.concat(e.members, " + ") or e.name) .. (e.self and (" " .. L.DUNG_YOU) or "")
                r.line1:SetText(name)
                if e.class and FW.ChatLog then
                    r.line1:SetTextColor(FW.ChatLog.ClassColor(e.class))
                else
                    r.line1:SetTextColor(UI.Color("text"))
                end
                local what
                if (e.size or 1) > 1 then
                    what = string.format(L.DUNG_GROUP_LINE, e.size, e.have.T, e.have.H, e.have.D, Dung.RoleWords(e.roles))
                else
                    what = string.format(L.DUNG_SOLO_LINE, Dung.RoleWords(e.roles))
                end
                r.line2:SetText(what .. "  -  " .. AgoText(Dung.NowClock() - e.since))
                r.line2:SetTextColor(UI.Color("textDim"))
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * ROW_H)
                r:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * ROW_H)
                r:Show()
            end
        end
        for k = i + 1, #rows do rows[k].plan = nil; rows[k]:Hide() end
        scroll:SetContentHeight(i * ROW_H + 4)
        Show(empty, i == 0)
    end

    FW:On("GUILD_MODULE_DUNGEON", function() if f:IsVisible() then f.Refresh() end end, f)
    FW:On("GUILD_MODULE_ROSTER", function() if f:IsVisible() then f.Refresh() end end, f)
    Guild.DungeonFrame = f
    return f
end

Guild.RegisterPage("dungeon", {
    order = 35,
    label = function() return FW.L.DUNG_TAB end,
    build = BuildPage,
    refresh = function(f) f.Refresh() end,
})
