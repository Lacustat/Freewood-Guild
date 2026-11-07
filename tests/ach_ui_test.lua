-- Test: Seite, Hinweisfenster und Liste der Gildenerfolge (texlua tests/ach_ui_test.lua)
local function Proxy()
    return setmetatable({}, { __index = function(_, k)
        if k == "scroll" or k == "child" or k == "label" then return Proxy() end
        return function(self, ...)
            if k == "GetStringHeight" or k == "GetWidth" or k == "GetHeight" then return 20 end
            if k == "IsVisible" or k == "IsShown" then return true end
            return Proxy()
        end
    end })
end
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. m .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.time = function() return 1000000 end
_G.date = os.date
_G.SlashCmdList = {}
local clicks, pages, scripts = {}, {}, {}
local UI = setmetatable({
    CreateButton = function(_, text, _, _, cb) clicks[text] = cb; local b = Proxy(); return b end,
    CreateCheckbox = function() return Proxy() end,
    Color = function() return 1, 1, 1 end,
}, { __index = function() return function() return Proxy() end end })
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), UI = UI, Util = { IsSecret = function() return false end } }
local events = {}
function FW:On(e, fn) events[e] = fn end
function FW:Print() end
_G.Freewood = FW
local queue = {}
local Ach = { queue = queue, CATEGORIES = { { "dungeon", "A" }, { "bosses", "B" } }, Text = function(s) return tostring(s[1]) end,
    Db = function() return { log = { { "X1", 1000 } }, done = {}, open = { dungeon = true } } end,
    Catalog = function() return { { id = "X1", cat = "dungeon", pts = 10, name = { "N" }, desc = { "D" } } } end,
    Evaluate = function() return {
        { entry = { id = "X1", cat = "dungeon", pts = 10, name = { "N1" }, desc = { "D1" } }, cur = 1, goal = 3, done = false },
        { entry = { id = "X2", cat = "dungeon", pts = 15, name = { "N2" }, desc = { "D2" } }, cur = 3, goal = 3, done = true, ts = 999000, who = { "Anna" } },
        { entry = { id = "X3", cat = "bosses", pts = 5, name = { "N3" }, desc = { "D3" } }, cur = 0, goal = 10, done = false },
    } end,
    Points = function() return 15, 30, 1, 3 end }
local Guild = { Ach = Ach, Setting = function() return true end, DB = function() return { settings = {} } end,
    RegisterPage = function(id, def) pages[id] = def end }
assert(loadfile("GuildAchUI.lua"))("Freewood-Guild", { Guild = Guild })
local page = pages.achievements
eq(page ~= nil and page.order, 70, "Seite angemeldet")
local f = page.build(Proxy())
page.refresh(f)
f.ToggleAll(); f.Render(); f.ToggleAll(); f.Render()
clicks["ACH_RECENT"](); clicks["ACH_TEST"](); clicks["ACH_TOGGLE"]()
-- Hinweisfenster
Ach.Notify({ id = "X1", cat = "dungeon", pts = 10, name = { "N1" }, desc = { "D1" } })
Ach.ShowLog()
eq(type(Ach.Notify), "function", "Notify vorhanden"); eq(type(SlashCmdList.FWACH), "function", "Befehl")
SlashCmdList.FWACH(""); SlashCmdList.FWACH("test"); SlashCmdList.FWACH("log")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
