-- Test 0.12.0: Oberflaeche der Verwaltung baut ohne Fehler, Knoepfe oeffnen die Bestaetigung (texlua tests/admin_ui_test.lua)
local function Proxy()
    return setmetatable({}, { __index = function(_, k)
        if k == "scroll" or k == "child" or k == "label" or k == "edit" then return Proxy() end
        return function(self, ...)
            if k == "GetStringHeight" or k == "GetWidth" or k == "GetHeight" or k == "GetFrameLevel" then return 20 end
            if k == "IsVisible" or k == "IsShown" then return true end
            if k == "HasFocus" then return false end
            if k == "GetText" then return "" end
            return Proxy()
        end
    end })
end
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.UISpecialFrames = {}
_G.InCombatLockdown = function() return false end
_G.IsGuildLeader = function() return true end
for _, f in ipairs({ "CanGuildPromote", "CanGuildDemote", "CanGuildInvite", "CanGuildRemove", "CanEditPublicNote", "CanEditMOTD", "CanEditGuildInfo" }) do
    _G[f] = function() return true end
end
_G.GuildControlGetNumRanks = function() return 4 end
_G.GuildControlGetRankName = function(i) return "R" .. i end
_G.GetGuildInfo = function() return "Legion", "R1", 0 end
_G.C_GuildInfo = { CanViewOfficerNote = function() return true end, CanEditOfficerNote = function() return true end,
    GetMOTD = function() return "m" end, GetInfoText = function() return "i" end }
_G.C_Timer = { After = function(_, fn) end }
local clicks, pages = {}, {}
local UI = setmetatable({
    CreateButton = function(_, text, _, _, cb) local b = Proxy(); if text then clicks[text] = cb end; return b end,
    Color = function() return 1, 1, 1 end,
}, { __index = function() return function() return Proxy() end end })
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), UI = UI }
local on = {}
function FW:On(e, fn) on[e] = fn end
function FW:Fire() end
function FW:RegisterEvent() end
_G.Freewood = FW
local edits = {}
local W = { Edit = function() local e = Proxy(); edits[#edits + 1] = e; return e end }
local toasts = {}
local me = { key = "ich", full = "Ich Selbst", name = "Ich Selbst", rankOrder = 1, guid = "G0", note = "", onote = "" }
local m = { key = "neu", full = "Neu Ling", name = "Neu Ling", rankOrder = 3, guid = "G3", note = "n", onote = "o", level = 20, rank = "R3", zone = "Brachland", online = true }
local Guild = { Widgets = W, rows = { me, m }, rowByKey = { ich = me, neu = m }, Secret = function() return false end,
    RequestRoster = function() end, InGuild = function() return true end, Toast = function(t) toasts[#toasts + 1] = t end,
    SelfKey = function() return "ich" end, RegisterPage = function(id, def) pages[id] = def end }
local NS = { Guild = Guild }
assert(loadfile("GuildAdmin.lua"))("Freewood-Guild", NS)
assert(loadfile("GuildAdminUI.lua"))("Freewood-Guild", NS)
eq(pages.admin ~= nil and pages.admin.order, 15, "Seite Verwaltung angemeldet")
local f = pages.admin.build(Proxy())
pages.admin.refresh(f)
eq(type(f.Refresh), "function", "Seite baut")
-- Mitglied verwalten
local d = Guild.AdminUI.OpenMember(m)
eq(d.row, m, "Fenster zeigt das Mitglied")
d.rankWanted = 4
d.UpdateRank()
clicks["GADM_RANK_SET"]()
clicks["GADM_REMOVE"]()
clicks["GADM_LEADER"]()
clicks["GADM_LEAVE"]()
clicks["GADM_DISBAND"]()
clicks["GADM_RANK_ADD"]()
eq(#edits > 4, true, "Eingabefelder angelegt")
print(string.format("admin_ui_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
