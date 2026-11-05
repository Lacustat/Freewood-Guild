-- Freewood-Guild: Favoriten und Favoritengruppen. Pro Charakter oder accountweit. Gruppen koennen eingeladen werden.
-- UNGEPRUEFT im Spiel (Einladen: C_PartyInfo.InviteUnit).

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local Fav = {}
Guild.Fav = Fav

local MAX_GROUPS = 20
local MAX_NAMES = 200

------------------------------------------------------------------------
-- Daten
------------------------------------------------------------------------

-- scope: "char" (nur dieser Charakter) oder "account"
function Fav.Store(scope)
    local db = Guild.DB().fav
    db.chars = db.chars or {}
    db.account = db.account or {}
    local s
    if scope == "char" then
        local k = Guild.SelfKey() or "?"
        db.chars[k] = db.chars[k] or {}
        s = db.chars[k]
    else
        s = db.account
    end
    s.favs = s.favs or {}
    s.groups = s.groups or {}
    return s
end

local function IndexOf(list, name)
    local key = Guild.Key(name)
    for i, n in ipairs(list) do
        if Guild.Key(n) == key then return i end
    end
    return nil
end

function Fav.Has(scope, name)
    return IndexOf(Fav.Store(scope).favs, name) ~= nil
end

function Fav.Add(scope, name)
    if type(name) ~= "string" or name == "" then return false end
    local s = Fav.Store(scope)
    if IndexOf(s.favs, name) then return false end
    if #s.favs >= MAX_NAMES then return false end
    s.favs[#s.favs + 1] = Guild.Display(name)
    table.sort(s.favs, function(a, b) return string.lower(a) < string.lower(b) end)
    FW:Fire("GUILD_MODULE_FAV")
    return true
end

function Fav.Remove(scope, name)
    local s = Fav.Store(scope)
    local i = IndexOf(s.favs, name)
    if i then table.remove(s.favs, i) end
    for _, g in ipairs(s.groups) do
        local j = IndexOf(g.members, name)
        if j then table.remove(g.members, j) end
    end
    FW:Fire("GUILD_MODULE_FAV")
    return i ~= nil
end

function Fav.NewGroup(scope, title)
    title = type(title) == "string" and string.gsub(title, "^%s*(.-)%s*$", "%1") or ""
    if title == "" then return nil end
    local s = Fav.Store(scope)
    if #s.groups >= MAX_GROUPS then return nil end
    for i, g in ipairs(s.groups) do
        if string.lower(g.title) == string.lower(title) then return i end
    end
    s.groups[#s.groups + 1] = { title = string.sub(title, 1, 30), members = {} }
    FW:Fire("GUILD_MODULE_FAV")
    return #s.groups
end

function Fav.DeleteGroup(scope, gi)
    local s = Fav.Store(scope)
    if s.groups[gi] then
        table.remove(s.groups, gi)
        FW:Fire("GUILD_MODULE_FAV")
        return true
    end
    return false
end

function Fav.AddToGroup(scope, gi, name)
    local s = Fav.Store(scope)
    local g = s.groups[gi]
    if not g or type(name) ~= "string" or name == "" then return false end
    if #g.members >= 40 then return false end
    Fav.Add(scope, name)
    if IndexOf(g.members, name) then return false end
    g.members[#g.members + 1] = Guild.Display(name)
    table.sort(g.members, function(a, b) return string.lower(a) < string.lower(b) end)
    FW:Fire("GUILD_MODULE_FAV")
    return true
end

function Fav.RemoveFromGroup(scope, gi, name)
    local s = Fav.Store(scope)
    local g = s.groups[gi]
    if not g then return false end
    local i = IndexOf(g.members, name)
    if i then table.remove(g.members, i); FW:Fire("GUILD_MODULE_FAV") end
    return i ~= nil
end

-- Namen einer Gruppe (gi = nil: alle Favoriten)
function Fav.Names(scope, gi)
    local s = Fav.Store(scope)
    if gi and s.groups[gi] then return s.groups[gi].members end
    return s.favs
end

------------------------------------------------------------------------
-- Einladen
------------------------------------------------------------------------

function Guild.Invite(name)
    if type(name) ~= "string" or name == "" then return false end
    local pi = G.C_PartyInfo
    if pi and pi.InviteUnit then
        return pcall(pi.InviteUnit, name)
    elseif G.InviteUnit then
        return pcall(G.InviteUnit, name)
    end
    return false
end

function Guild.Whisper(name)
    if type(name) ~= "string" or name == "" then return end
    if G.ChatFrame_OpenChat then
        pcall(G.ChatFrame_OpenChat, "/w " .. name .. " ")
    elseif FW.ChatLog and FW.ChatLog.OpenWhisper then
        FW.ChatLog.OpenWhisper(name)
    end
end

-- Gruppe einladen: nur online Mitglieder, nicht man selbst, mit Abstand. Rueckgabe: eingeladen, offline
function Fav.InviteGroup(scope, gi)
    local names = Fav.Names(scope, gi)
    local selfKey = Guild.SelfKey()
    local list, offline = {}, 0
    for _, n in ipairs(names) do
        local key = Guild.Key(n)
        if key ~= selfKey then
            local row = Guild.rowByKey[key]
            if row and row.online then list[#list + 1] = row.full else offline = offline + 1 end
        end
    end
    for i, full in ipairs(list) do
        if i == 1 then
            Guild.Invite(full)
        elseif Guild.Share and Guild.Share.After then
            Guild.Share.After((i - 1) * 0.6, function() Guild.Invite(full) end)
        else
            Guild.Invite(full)
        end
    end
    return #list, offline
end

------------------------------------------------------------------------
-- Seite "Favoriten"
------------------------------------------------------------------------

local function Build(content)
    local L = FW.L
    local UI = FW.UI
    local W = Guild.Widgets
    local f = CreateFrame("Frame", nil, content)
    f.scope = "char"
    f.group = nil

    local scopeChar = UI.CreateButton(f, L.FAV_SCOPE_CHAR, 170, 24, function() f.scope = "char"; f.group = nil; f.Refresh() end)
    scopeChar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local scopeAcc = UI.CreateButton(f, L.FAV_SCOPE_ACCOUNT, 170, 24, function() f.scope = "account"; f.group = nil; f.Refresh() end)
    scopeAcc:SetPoint("LEFT", scopeChar, "RIGHT", 6, 0)

    -- links: Gruppen
    local gScroll = UI.CreateScrollFrame(f)
    gScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    gScroll:SetSize(220, 300)
    local gButtons = {}
    local newEdit = W.Edit(f, 150, 24)
    newEdit:SetPoint("TOPLEFT", gScroll, "BOTTOMLEFT", 0, -8)
    local newBtn = UI.CreateButton(f, L.FAV_NEW_GROUP, 64, 24, function()
        local i = Fav.NewGroup(f.scope, newEdit:GetText())
        if i then f.group = i; newEdit:SetText("") end
        f.Refresh()
    end)
    newBtn:SetPoint("LEFT", newEdit, "RIGHT", 6, 0)
    gScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 44)

    -- rechts: Mitglieder der Gruppe
    local title = UI.CreateLabel(f, "", { font = "heading", size = 15, color = "goldLight" })
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -36)
    local info = UI.CreateLabel(f, "", { size = 11, color = "textDim" })
    info:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -58)
    local inviteBtn = UI.CreateButton(f, L.FAV_INVITE_GROUP, 170, 24, function()
        local n, off = Fav.InviteGroup(f.scope, f.group)
        FW:Print(string.format(L.FAV_INVITED, n, off))
    end, "primary")
    inviteBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -34)
    local delBtn = UI.CreateButton(f, L.FAV_DELETE_GROUP, 130, 24, function()
        if f.group then Fav.DeleteGroup(f.scope, f.group); f.group = nil; f.Refresh() end
    end)
    delBtn:SetPoint("RIGHT", inviteBtn, "LEFT", -6, 0)

    local addEdit = W.Edit(f, 180, 24)
    addEdit:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -82)
    local addBtn = UI.CreateButton(f, L.FAV_ADD_NAME, 120, 24, function()
        local n = addEdit:GetText()
        if n and n ~= "" then
            if f.group then Fav.AddToGroup(f.scope, f.group, n) else Fav.Add(f.scope, n) end
            addEdit:SetText("")
        end
    end)
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 6, 0)

    local mScroll = UI.CreateScrollFrame(f)
    mScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -114)
    mScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local mRows = {}
    local ROW = 26

    local function GetRow(i)
        local r = mRows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, mScroll.child)
        r:SetHeight(ROW)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(8, 8)
        r.dot:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.name = UI.CreateLabel(r, "", { size = 12 })
        r.name:SetPoint("LEFT", r, "LEFT", 20, 0)
        r.name:SetWidth(180)
        r.name:SetWordWrap(false)
        r.info = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
        r.info:SetPoint("LEFT", r, "LEFT", 206, 0)
        r.info:SetWidth(110)
        r.info:SetWordWrap(false)
        r.del = UI.CreateButton(r, "X", 24, 22, function() if r.who then
            if f.group then Fav.RemoveFromGroup(f.scope, f.group, r.who) else Fav.Remove(f.scope, r.who) end
        end end)
        r.del:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        r.inv = UI.CreateButton(r, L.CHAN_INVITE, 80, 22, function() if r.who and r.full then Guild.Invite(r.full) end end)
        r.inv:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
        r.wsp = UI.CreateButton(r, L.CHAN_WHISPER, 80, 22, function() if r.who then Guild.Whisper(r.full or r.who) end end)
        r.wsp:SetPoint("RIGHT", r.inv, "LEFT", -4, 0)
        mRows[i] = r
        return r
    end

    function f.Refresh()
        local s = Fav.Store(f.scope)
        scopeChar:SetStyle(f.scope == "char" and "primary" or "default")
        scopeAcc:SetStyle(f.scope == "account" and "primary" or "default")
        if f.group and not s.groups[f.group] then f.group = nil end
        -- Gruppenknoepfe
        local entries = { { title = L.FAV_ALL, index = nil } }
        for i, g in ipairs(s.groups) do entries[#entries + 1] = { title = g.title .. " (" .. #g.members .. ")", index = i } end
        for i, e in ipairs(entries) do
            local b = gButtons[i]
            if not b then
                b = UI.CreateButton(gScroll.child, "", 200, 24, nil)
                gButtons[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", gScroll.child, "TOPLEFT", 0, -(i - 1) * 28)
            b:SetLabel(e.title)
            b:SetScript("OnClick", function() f.group = e.index; f.Refresh() end)
            b:SetStyle(e.index == f.group and "primary" or "default")
            b:Show()
        end
        for i = #entries + 1, #gButtons do gButtons[i]:Hide() end
        gScroll:SetContentHeight(#entries * 28)

        local names = Fav.Names(f.scope, f.group)
        title:SetText(f.group and s.groups[f.group].title or L.FAV_ALL)
        info:SetText(string.format(L.FAV_COUNT, #names))
        if f.group then delBtn:Show() else delBtn:Hide() end
        inviteBtn:SetStyle(#names > 0 and "primary" or "default")
        for i, n in ipairs(names) do
            local r = GetRow(i)
            local row = Guild.Row(n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", mScroll.child, "TOPLEFT", 0, -(i - 1) * ROW)
            r:SetPoint("TOPRIGHT", mScroll.child, "TOPRIGHT", 0, -(i - 1) * ROW)
            r.who, r.full = n, row and row.full or nil
            local rr, gg, bb = 0.9, 0.89, 0.84
            if row and FW.ChatLog then rr, gg, bb = FW.ChatLog.ClassColor(row.class) end
            r.name:SetTextColor(rr, gg, bb)
            r.name:SetText(n)
            if row and row.online then
                r.dot:SetColorTexture(UI.Color("success"))
                r.info:SetText(row.level > 0 and ("Lv " .. row.level .. "  " .. row.zone) or row.zone)
            else
                r.dot:SetColorTexture(UI.Color("textDim"))
                r.info:SetText(row and L.GUILD_OFFLINE or L.FAV_NOT_IN_GUILD)
            end
            r:Show()
        end
        for i = #names + 1, #mRows do mRows[i]:Hide() end
        mScroll:SetContentHeight(#names * ROW)
    end

    FW:On("GUILD_MODULE_FAV", function() if f:IsVisible() then f.Refresh() end end, f)
    FW:On("GUILD_MODULE_ROSTER", function() if f:IsVisible() then f.Refresh() end end, f)
    Fav.frame = f
    return f
end

Guild.RegisterPage("favorites", {
    order = 20,
    label = function() return FW.L.FAV_TAB end,
    build = Build,
    refresh = function(f) f.Refresh() end,
})
