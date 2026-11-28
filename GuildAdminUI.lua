-- Freewood-Guild: Oberflaeche der Verwaltung (seit 0.12.0)
--   * Fenster "Mitglied verwalten" (Rechtsklick in der Mitgliederliste > "Verwalten..."): Notizen, Rang, Entfernen, Gildenleitung.
--   * Bestaetigungsfenster: der Knopf "Ja" ist mit dem sicheren Knopf (GuildAdmin.lua) belegt, er fuehrt den Chatbefehl aus.
--   * Unterseite "Verwaltung": Nachricht des Tages, Gildeninformation, Einladen, Raenge (Gildenmeister), Protokoll, Verlassen/Aufloesen.
-- UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
local A = Guild and Guild.Admin
if not FW or not Guild or not A then
    return
end

local G = _G
local UI = FW.UI
local W = Guild.Widgets
local AU = {}
Guild.AdminUI = AU

local function Show(frame, on)
    if on then frame:Show() else frame:Hide() end
end

local function Dialog(name, w, h, title)
    local f = UI.CreatePanel(G.UIParent, "bgDeep", "gold")
    f:SetSize(w, h)
    f:SetPoint("CENTER", G.UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.title = UI.CreateLabel(f, title or "", { font = "heading", size = 14, color = "goldLight" })
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.title:SetPoint("RIGHT", f, "RIGHT", -40, 0)
    f.title:SetWordWrap(false)
    local close = UI.CreateButton(f, "x", 24, 24, function() f:Hide() end, "ghost")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    f:Hide()
    if name then
        G[name] = f
        if type(G.UISpecialFrames) == "table" then table.insert(G.UISpecialFrames, name) end
    end
    return f
end

------------------------------------------------------------------------
-- Bestaetigung mit sicherem Knopf
------------------------------------------------------------------------

local confirm
-- opts = { title, text, macro, requireText, onDone }
function AU.Confirm(opts)
    local L = FW.L
    if not confirm then
        confirm = Dialog("FreewoodGuildConfirm", 400, 170, "")
        confirm:SetFrameStrata("FULLSCREEN")
        confirm.text = UI.CreateLabel(confirm, "", { size = 12, justifyV = "TOP" })
        confirm.text:SetPoint("TOPLEFT", confirm, "TOPLEFT", 14, -40)
        confirm.text:SetPoint("RIGHT", confirm, "RIGHT", -14, 0)
        confirm.text:SetWordWrap(true)
        confirm.input = W.Edit(confirm, 372, 24)
        confirm.input:SetPoint("BOTTOMLEFT", confirm, "BOTTOMLEFT", 14, 48)
        confirm.yes = UI.CreateButton(confirm, L.GADM_YES, 120, 26, function() end, "primary")
        confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
        confirm.no = UI.CreateButton(confirm, L.GADM_NO, 120, 26, function() confirm:Hide() end)
        confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 14)
        confirm.hint = UI.CreateLabel(confirm, "", { size = 11, color = "textDim", justify = "CENTER" })
        confirm.hint:SetPoint("BOTTOM", confirm.yes, "TOP", 60, 6)
        confirm:SetScript("OnHide", function() A.Disarm() end)
        FW:On("GUILD_ADMIN_COMBAT", function(on) if on and confirm:IsShown() then confirm:Hide() end end, confirm)
    end
    local c = confirm
    c.opts = opts
    c.title:SetText(opts.title or "")
    c.text:SetText(opts.text or "")
    Show(c.input, opts.requireText ~= nil)
    c.input:SetText("")
    local function Update()
        A.Disarm()
        local ready = not A.InCombat() and type(opts.macro) == "string"
        if ready and opts.requireText then
            ready = (c.input:GetText() or ""):lower() == tostring(opts.requireText):lower()
        end
        c.yes:SetButtonEnabled(ready)
        if A.InCombat() then
            c.hint:SetText(L.GADM_COMBAT)
        elseif opts.requireText and not ready then
            c.hint:SetText(string.format(L.GADM_TYPE_TO_CONFIRM, opts.requireText))
        else
            c.hint:SetText("")
        end
        if ready then
            A.Arm(c.yes, opts.macro, function()
                c:Hide()
                if opts.onDone then pcall(opts.onDone) end
            end)
        end
    end
    c.input.onChange = function() Update() end
    c:SetHeight(opts.requireText and 200 or 170)
    c:Show()
    Update()
    return c
end

------------------------------------------------------------------------
-- Fenster "Mitglied verwalten"
------------------------------------------------------------------------

local member
local function NoteBlock(parent, y, labelKey)
    local L = FW.L
    local lab = UI.CreateLabel(parent, L[labelKey], { size = 12, color = "gold" })
    lab:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    local edit = W.Edit(parent, 300, 24)
    edit:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -4)
    edit.edit:SetMaxLetters(A.NOTE_MAX)
    local save = UI.CreateButton(parent, L.GADM_SAVE, 90, 24, nil)
    save:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local ro = UI.CreateLabel(parent, "", { size = 12, color = "textDim" })
    ro:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 2, -8)
    ro:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    ro:SetWordWrap(false)
    return { label = lab, edit = edit, save = save, ro = ro }
end

local function SetNoteBlock(b, text, canEdit, visible)
    Show(b.label, visible); Show(b.edit, visible and canEdit); Show(b.save, visible and canEdit)
    Show(b.ro, visible and not canEdit)
    b.edit:SetText(text or "")
    b.ro:SetText((text and text ~= "") and text or "-")
end

function AU.OpenMember(row)
    local L = FW.L
    if not row then return end
    if not member then
        local f = Dialog("FreewoodGuildMember", 440, 370, "")
        f.info = UI.CreateLabel(f, "", { size = 12, color = "textDim" })
        f.info:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
        f.info:SetPoint("RIGHT", f, "RIGHT", -14, 0)
        f.info:SetWordWrap(false)
        f.pub = NoteBlock(f, -62, "GADM_NOTE_PUBLIC")
        f.off = NoteBlock(f, -120, "GADM_NOTE_OFFICER")
        f.rankLabel = UI.CreateLabel(f, L.GADM_RANK, { size = 12, color = "gold" })
        f.rankLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -178)
        f.rankDD = UI.CreateDropdown(f, 200, 24, {
            getOptions = function()
                local out = {}
                for _, c in ipairs(A.RankChoices(f.row)) do
                    out[#out + 1] = { value = c.order, text = c.name .. (c.allowed and "" or (" " .. L.GADM_NOT_ALLOWED)) }
                end
                return out
            end,
            textOf = function(v) return A.RankName(v) end,
            onChange = function(v) f.rankWanted = v; f.UpdateRank() end,
        })
        f.rankDD:SetPoint("TOPLEFT", f.rankLabel, "BOTTOMLEFT", 0, -4)
        f.rankSet = UI.CreateButton(f, L.GADM_RANK_SET, 130, 24, function()
            local row2, order = f.row, f.rankWanted
            local macro = A.RankMacro(row2, order)
            if not macro then return end
            AU.Confirm({ title = L.GADM_RANK, macro = macro,
                text = string.format(L.GADM_RANK_CONFIRM, row2.name, A.RankName(row2.rankOrder), A.RankName(order)) })
        end)
        f.rankSet:SetPoint("LEFT", f.rankDD, "RIGHT", 8, 0)
        f.rankRO = UI.CreateLabel(f, "", { size = 12, color = "textDim" })
        f.rankRO:SetPoint("TOPLEFT", f.rankLabel, "BOTTOMLEFT", 2, -8)
        f.remove = UI.CreateButton(f, L.GADM_REMOVE, 190, 26, function()
            local r = f.row
            AU.Confirm({ title = L.GADM_REMOVE, macro = A.Macro("remove", r.full),
                text = string.format(L.GADM_REMOVE_CONFIRM, r.name), onDone = function() f:Hide() end })
        end)
        f.remove:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 50)
        f.leader = UI.CreateButton(f, L.GADM_LEADER, 190, 26, function()
            local r = f.row
            AU.Confirm({ title = L.GADM_LEADER, macro = A.Macro("leader", r.full), requireText = r.name,
                text = string.format(L.GADM_LEADER_CONFIRM, r.name) })
        end)
        f.leader:SetPoint("LEFT", f.remove, "RIGHT", 10, 0)
        f.hint = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
        f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 18)
        f.hint:SetPoint("RIGHT", f, "RIGHT", -14, 0)
        f.hint:SetWordWrap(true)

        f.pub.save:SetScript("OnClick", function()
            if A.SetNote(f.row, f.pub.edit:GetText(), true) then Guild.Toast(L.GADM_NOTE_SAVED) else Guild.Toast(L.GADM_FAILED) end
        end)
        f.off.save:SetScript("OnClick", function()
            if A.SetNote(f.row, f.off.edit:GetText(), false) then Guild.Toast(L.GADM_NOTE_SAVED) else Guild.Toast(L.GADM_FAILED) end
        end)
        f.pub.edit.onEnter = function() f.pub.save:Click() end
        f.off.edit.onEnter = function() f.off.save:Click() end

        function f.UpdateRank()
            local r = A.RightsFor(f.row)
            local ok = r.rank and f.rankWanted and f.rankWanted ~= f.row.rankOrder and A.RankMacro(f.row, f.rankWanted) ~= nil
            if ok then
                for _, c in ipairs(A.RankChoices(f.row)) do if c.order == f.rankWanted and not c.allowed then ok = false end end
            end
            f.rankSet:SetButtonEnabled(ok and not A.InCombat())
        end

        function f.Fill()
            local row2 = f.row
            local fresh = Guild.rowByKey and Guild.rowByKey[row2.key]
            if fresh then row2 = fresh; f.row = fresh end
            local r = A.RightsFor(row2)
            f.title:SetText(row2.name)
            local list = {}
            local function Add(p) if p and p ~= "" then list[#list + 1] = p end end
            Add((row2.level or 0) > 0 and (L.GADM_LEVEL .. " " .. row2.level) or nil)
            Add(row2.className)
            Add(row2.rank)
            Add(row2.online and (row2.zone ~= "" and row2.zone or L.GUILD_F_ONLINE) or L.GUILD_OFFLINE)
            f.info:SetText(table.concat(list, "  ·  "))
            SetNoteBlock(f.pub, row2.note, r.publicNote, true)
            SetNoteBlock(f.off, row2.onote, r.officerNote, r.viewOfficer)
            Show(f.rankDD, r.rank); Show(f.rankSet, r.rank); Show(f.rankRO, not r.rank)
            f.rankRO:SetText(row2.rank ~= "" and row2.rank or "-")
            f.rankWanted = row2.rankOrder
            f.rankDD:SetValue(row2.rankOrder)
            f.UpdateRank()
            Show(f.remove, r.remove); Show(f.leader, r.leader)
            local combat = A.InCombat()
            f.remove:SetButtonEnabled(not combat); f.leader:SetButtonEnabled(not combat)
            if combat then f.hint:SetText(L.GADM_COMBAT)
            elseif not A.HasAnyRight() then f.hint:SetText(L.GADM_NO_RIGHTS)
            else f.hint:SetText(L.GADM_SECURE_HINT) end
        end
        FW:On("GUILD_MODULE_ROSTER", function() if f:IsShown() then f.Fill() end end, f)
        FW:On("GUILD_ADMIN_COMBAT", function() if f:IsShown() then f.Fill() end end, f)
        member = f
    end
    member.row = row
    member:Show()
    member.Fill()
    return member
end

------------------------------------------------------------------------
-- Unterseite "Verwaltung"
------------------------------------------------------------------------

local function Heading(parent, text, x, y)
    local t = UI.CreateLabel(parent, text, { font = "heading", size = 14, color = "goldLight" })
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local d = UI.CreateDivider(parent)
    d:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 22)
    d:SetWidth(420)
    return t
end

local function BuildAdmin(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    local scroll = UI.CreateScrollFrame(f)
    scroll:SetAllPoints(f)
    local c = scroll.child
    c:SetWidth(900)
    local LX, RX = 0, 450

    -- Links: Nachricht des Tages
    Heading(c, L.GADM_MOTD, LX, 0)
    f.motd = W.Edit(c, 420, 24)
    f.motd:SetPoint("TOPLEFT", c, "TOPLEFT", LX, -32)
    f.motd.edit:SetMaxLetters(A.MOTD_MAX)
    f.motdSave = UI.CreateButton(c, L.GADM_SAVE, 100, 24, function()
        if A.SetMOTD(f.motd:GetText()) then Guild.Toast(L.GADM_MOTD_SAVED) else Guild.Toast(L.GADM_FAILED) end
    end)
    f.motdSave:SetPoint("TOPLEFT", f.motd, "BOTTOMLEFT", 0, -6)
    f.motdRO = UI.CreateLabel(c, "", { size = 12, justifyV = "TOP" })
    f.motdRO:SetPoint("TOPLEFT", c, "TOPLEFT", LX + 2, -34)
    f.motdRO:SetWidth(416)
    f.motdRO:SetWordWrap(true)

    -- Gildeninformation
    Heading(c, L.GADM_INFO, LX, -100)
    f.info = UI.CreateTextArea(c, 420, 120)
    f.info:SetPoint("TOPLEFT", c, "TOPLEFT", LX, -132)
    f.info.edit:SetMaxLetters(A.INFO_MAX)
    f.infoSave = UI.CreateButton(c, L.GADM_SAVE, 100, 24, function()
        if A.SetInfo(f.info:GetText()) then Guild.Toast(L.GADM_INFO_SAVED) else Guild.Toast(L.GADM_FAILED) end
    end)
    f.infoSave:SetPoint("TOPLEFT", f.info, "BOTTOMLEFT", 0, -6)

    -- Einladen
    Heading(c, L.GADM_INVITE, LX, -300)
    f.inv = W.Edit(c, 300, 24)
    f.inv:SetPoint("TOPLEFT", c, "TOPLEFT", LX, -332)
    f.invBtn = UI.CreateButton(c, L.GADM_INVITE_BTN, 110, 24, function()
        local name = A.CleanName(f.inv:GetText())
        if not name then return end
        AU.Confirm({ title = L.GADM_INVITE, macro = A.Macro("invite", name), text = string.format(L.GADM_INVITE_CONFIRM, name),
            onDone = function() f.inv:SetText("") end })
    end)
    f.invBtn:SetPoint("LEFT", f.inv, "RIGHT", 8, 0)
    f.inv.onEnter = function() f.invBtn:Click() end
    f.invHint = UI.CreateLabel(c, L.GADM_INVITE_HINT, { size = 11, color = "textDim" })
    f.invHint:SetPoint("TOPLEFT", f.inv, "BOTTOMLEFT", 0, -6)
    f.invHint:SetWidth(420)
    f.invHint:SetWordWrap(true)

    -- Verlassen / Aufloesen
    Heading(c, L.GADM_GUILD, LX, -400)
    f.leave = UI.CreateButton(c, L.GADM_LEAVE, 160, 26, function()
        local gname = A.GuildName()
        AU.Confirm({ title = L.GADM_LEAVE, macro = A.Macro("leave"), text = string.format(L.GADM_LEAVE_CONFIRM, gname) })
    end)
    f.leave:SetPoint("TOPLEFT", c, "TOPLEFT", LX, -432)
    f.disband = UI.CreateButton(c, L.GADM_DISBAND, 160, 26, function()
        local gname = A.GuildName()
        AU.Confirm({ title = L.GADM_DISBAND, macro = A.Macro("disband"), requireText = gname ~= "" and gname or "AUFLOESEN",
            text = string.format(L.GADM_DISBAND_CONFIRM, gname) })
    end)
    f.disband:SetPoint("LEFT", f.leave, "RIGHT", 10, 0)

    -- Rechts: Raenge
    Heading(c, L.GADM_RANKS, RX, 0)
    f.rankRows = {}
    f.selRank = 2
    local function RankRow(i)
        local r = f.rankRows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, c)
        r:SetSize(430, 26)
        r:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -32 - (i - 1) * 28)
        r.sel = UI.CreateButton(r, tostring(i), 28, 24, function() f.selRank = i; f.Refresh() end)
        r.sel:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.name = W.Edit(r, 180, 24)
        r.name:SetPoint("LEFT", r.sel, "RIGHT", 4, 0)
        r.name.onEnter = function(t)
            if A.RenameRank(i, t) then Guild.Toast(L.GADM_RANK_RENAMED) else Guild.Toast(L.GADM_FAILED) end
        end
        r.ro = UI.CreateLabel(r, "", { size = 12 })
        r.ro:SetPoint("LEFT", r.sel, "RIGHT", 8, 0)
        r.count = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
        r.count:SetPoint("LEFT", r.sel, "RIGHT", 192, 0)
        r.up = UI.CreateButton(r, "^", 26, 24, function() A.Shift(i, true) end)
        r.up:SetPoint("LEFT", r.sel, "RIGHT", 240, 0)
        r.down = UI.CreateButton(r, "v", 26, 24, function() A.Shift(i, false) end)
        r.down:SetPoint("LEFT", r.up, "RIGHT", 2, 0)
        r.del = UI.CreateButton(r, "x", 26, 24, function()
            if A.DeleteRank(i) then Guild.Toast(L.GADM_RANK_DELETED) end
        end)
        r.del:SetPoint("LEFT", r.down, "RIGHT", 2, 0)
        f.rankRows[i] = r
        return r
    end
    f.addRank = UI.CreateButton(c, L.GADM_RANK_ADD, 130, 24, function() A.AddRank() end)
    f.blizzRanks = UI.CreateButton(c, L.GADM_RANK_BLIZZ, 170, 24, function() A.OpenBlizzardRanks() end)
    f.flagHead = UI.CreateLabel(c, "", { size = 12, color = "gold" })
    f.flags = {}
    for i = 1, A.FLAG_COUNT do
        local cb = UI.CreateCheckbox(c, A.FlagLabel(i),
            function() return A.RankFlags(f.selRank)[i] == true end,
            function(v) A.SetRankFlag(f.selRank, i, v) end)
        cb:SetWidth(210)
        f.flags[i] = cb
    end

    -- Protokoll
    f.logHead = Heading(c, L.GADM_LOG, RX, -600)
    f.logBtn = UI.CreateButton(c, L.GADM_LOG_LOAD, 120, 24, function() A.QueryLog() end)
    f.logText = UI.CreateLabel(c, "", { size = 11, justifyV = "TOP" })
    f.logText:SetWidth(430)
    f.logText:SetWordWrap(true)

    f.hint = UI.CreateLabel(c, "", { size = 11, color = "textDim" })
    f.hint:SetWidth(420)
    f.hint:SetWordWrap(true)

    function f.Refresh()
        local inGuild = Guild.InGuild()
        local leader = A.IsLeader()
        local combat = A.InCombat()
        -- Nachricht des Tages
        local canMotd = A.CanEditMOTD()
        if not f.motd.edit:HasFocus() then f.motd:SetText(A.GetMOTD()) end
        f.motdRO:SetText(A.GetMOTD() ~= "" and A.GetMOTD() or "-")
        Show(f.motd, canMotd); Show(f.motdSave, canMotd); Show(f.motdRO, not canMotd)
        -- Info
        local canInfo = A.CanEditInfo()
        if not f.info.edit:HasFocus() then f.info:SetText(A.GetInfo()) end
        f.info.edit:EnableMouse(canInfo)
        f.info.edit:EnableKeyboard(canInfo)
        Show(f.infoSave, canInfo)
        -- Einladen
        local canInv = A.CanInvite()
        Show(f.inv, canInv); Show(f.invBtn, canInv); Show(f.invHint, canInv)
        f.invBtn:SetButtonEnabled(not combat)
        -- Gilde
        Show(f.leave, inGuild); Show(f.disband, inGuild and leader)
        f.leave:SetButtonEnabled(not combat); f.disband:SetButtonEnabled(not combat)
        -- Raenge
        local n = A.NumRanks()
        if f.selRank > n then f.selRank = math.max(2, n) end
        for i = 1, math.max(n, #f.rankRows) do
            local r = RankRow(i)
            if i <= n then
                r:Show()
                r.sel:SetStyle(i == f.selRank and "primary" or "default")
                local canName = leader
                Show(r.name, canName); Show(r.ro, not canName)
                if not r.name.edit:HasFocus() then r.name:SetText(A.RankName(i)) end
                r.ro:SetText(A.RankName(i))
                r.count:SetText(tostring(A.MembersInRank(i)))
                Show(r.up, leader and i >= 2); Show(r.down, leader and i >= 2); Show(r.del, leader and i >= 2)
                r.up:SetButtonEnabled(A.CanShift(i, true)); r.down:SetButtonEnabled(A.CanShift(i, false))
                r.del:SetButtonEnabled(A.CanDeleteRank(i))
            else
                r:Hide()
            end
        end
        local y = -32 - n * 28 - 6
        f.addRank:ClearAllPoints(); f.addRank:SetPoint("TOPLEFT", c, "TOPLEFT", RX, y)
        f.blizzRanks:ClearAllPoints(); f.blizzRanks:SetPoint("LEFT", f.addRank, "RIGHT", 8, 0)
        Show(f.addRank, leader); f.addRank:SetButtonEnabled(A.CanAddRank())
        Show(f.blizzRanks, leader)
        y = y - 34
        local editFlags = leader and A.EditableRank(f.selRank)
        f.flagHead:ClearAllPoints(); f.flagHead:SetPoint("TOPLEFT", c, "TOPLEFT", RX, y)
        f.flagHead:SetText(string.format(L.GADM_RIGHTS_OF, A.RankName(f.selRank)))
        Show(f.flagHead, leader and n > 0)
        y = y - 22
        for i, cb in ipairs(f.flags) do
            local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", c, "TOPLEFT", RX + col * 215, y - line * 24)
            Show(cb, editFlags)
            if cb.Refresh then cb:Refresh() end
        end
        if editFlags then y = y - math.ceil(A.FLAG_COUNT / 2) * 24 - 10 end
        -- Protokoll
        f.logHead:ClearAllPoints(); f.logHead:SetPoint("TOPLEFT", c, "TOPLEFT", RX, y - 10)
        f.logBtn:ClearAllPoints(); f.logBtn:SetPoint("TOPLEFT", c, "TOPLEFT", RX, y - 42)
        local lines = {}
        for i, e in ipairs(A.LogLines()) do
            if i > 60 then break end
            lines[#lines + 1] = "|cff9d9d9d" .. A.FormatAgo(e.ago) .. "|r  " .. e.text
        end
        f.logText:SetText(#lines > 0 and table.concat(lines, "\n") or L.GADM_LOG_EMPTY)
        f.logText:ClearAllPoints(); f.logText:SetPoint("TOPLEFT", c, "TOPLEFT", RX, y - 74)
        local logH = f.logText:GetStringHeight() or 100
        -- Hinweis
        f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", c, "TOPLEFT", LX, -476)
        if not inGuild then f.hint:SetText(L.GADM_NO_GUILD)
        elseif combat then f.hint:SetText(L.GADM_COMBAT)
        elseif not A.HasAnyRight() then f.hint:SetText(L.GADM_NO_RIGHTS)
        else f.hint:SetText(L.GADM_SECURE_HINT) end
        scroll:SetContentHeight(math.max(540, -(y - 74) + logH + 20))
    end

    local pending = false
    local function Later()
        if f:IsVisible() and not pending then
            pending = true
            if G.C_Timer and G.C_Timer.After then
                G.C_Timer.After(0.3, function() pending = false; if f:IsVisible() then f.Refresh() end end)
            else
                pending = false; f.Refresh()
            end
        end
    end
    FW:On("GUILD_MODULE_ROSTER", Later, f)
    FW:On("GUILD_ADMIN_CHANGED", Later, f)
    FW:On("GUILD_ADMIN_COMBAT", Later, f)
    f:SetScript("OnShow", function() A.QueryLog(); f.Refresh() end)
    AU.page = f
    return f
end

Guild.RegisterPage("admin", {
    order = 15,
    label = function() return FW.L.GADM_TAB end,
    build = BuildAdmin,
    refresh = function(f) f.Refresh() end,
})
