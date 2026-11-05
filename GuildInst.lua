-- Freewood-Guild: Instanz-Uebersicht. Wer hat welchen Boss getoetet?
-- Quellen: ENCOUNTER_END, Todesmeldungen im Kampfprotokoll (vorsichtig) und gesperrte Instanzen (RequestRaidInfo).
-- Jeder Spieler mit dem Addon meldet seine Boss-Kills an die Gilde (Art "K").
-- UNGEPRUEFT im Spiel. Die Boss- und Instanzliste ist eine feste Grundliste (Vanilla); was das Spiel sonst meldet, kommt dynamisch dazu.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild or not Guild.Share then
    return
end

local G = _G
local Share = Guild.Share
local Inst = {}
Guild.Inst = Inst

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end
local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end

------------------------------------------------------------------------
-- Grundliste: { id, Name EN, Name DE, Bosse (EN) }
------------------------------------------------------------------------

Inst.LIST = {
    { "RFC", "Ragefire Chasm", "Flammenschlund", { "Oggleflint", "Taragaman the Hungerer", "Jergosh the Invoker", "Bazzalan" } },
    { "WC", "Wailing Caverns", "Die Höhlen des Wehklagens", { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis", "Verdan the Everliving", "Mutanus the Devourer" } },
    { "DM", "The Deadmines", "Die Todesminen", { "Rhahk'Zor", "Miner Johnson", "Sneed's Shredder", "Gilnid", "Mr. Smite", "Captain Greenskin", "Edwin VanCleef", "Cookie" } },
    { "SFK", "Shadowfang Keep", "Burg Schattenfang", { "Rethilgore", "Razorclaw the Butcher", "Baron Silverlaine", "Commander Springvale", "Odo the Blindwatcher", "Fenrus the Devourer", "Wolf Master Nandos", "Archmage Arugal" } },
    { "BFD", "Blackfathom Deeps", "Die Tiefschwarze Grotte", { "Ghamoo-ra", "Lady Sarevess", "Gelihast", "Baron Aquanis", "Twilight Lord Kelris", "Old Serra'kis", "Aku'mai" } },
    { "STOCK", "The Stockade", "Das Verlies", { "Targorr the Dread", "Kam Deepfury", "Hamhock", "Bazil Thredd", "Dextren Ward" } },
    { "GNOM", "Gnomeregan", "Gnomeregan", { "Grubbis", "Viscous Fallout", "Electrocutioner 6000", "Crowd Pummeler 9-60", "Dark Iron Ambassador", "Mekgineer Thermaplugg" } },
    { "RFK", "Razorfen Kraul", "Kral der Klingenhauer", { "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk", "Agathelos the Raging", "Charlga Razorflank" } },
    { "SM", "Scarlet Monastery", "Scharlachrotes Kloster", { "Interrogator Vishas", "Bloodmage Thalnos", "Houndmaster Loksey", "Arcanist Doan", "Herod", "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" } },
    { "RFD", "Razorfen Downs", "Hügel der Klingenhauer", { "Tuten'kash", "Mordresh Fire Eye", "Glutton", "Ragglesnout", "Amnennar the Coldbringer" } },
    { "ULD", "Uldaman", "Uldaman", { "Revelosh", "Ironaya", "Obsidian Sentinel", "Ancient Stone Keeper", "Galgann Firehammer", "Grimlok", "Archaedas" } },
    { "ZF", "Zul'Farrak", "Zul'Farrak", { "Antu'sul", "Theka the Martyr", "Witch Doctor Zum'rah", "Nekrum Gutchewer", "Shadowpriest Sezz'ziz", "Sergeant Bly", "Hydromancer Velratha", "Gahz'rilla", "Chief Ukorz Sandscalp" } },
    { "MARA", "Maraudon", "Maraudon", { "Noxxion", "Razorlash", "Lord Vyletongue", "Celebras the Cursed", "Landslide", "Tinkerer Gizlock", "Rotgrip", "Princess Theradras" } },
    { "ST", "The Temple of Atal'Hakkar", "Der Tempel von Atal'Hakkar", { "Atal'alarion", "Dreamscythe", "Weaver", "Avatar of Hakkar", "Jammal'an the Prophet", "Ogom the Wretched", "Morphaz", "Hazzas", "Shade of Eranikus" } },
    { "BRD", "Blackrock Depths", "Schwarzfelstiefen", { "High Interrogator Gerstahn", "Lord Roccor", "Houndmaster Grebmar", "Pyromancer Loregrain", "Lord Incendius", "Warder Stilgiss", "Fineous Darkvire", "Bael'Gar", "General Angerforge", "Golem Lord Argelmach", "Hurley Blackbreath", "Ribbly Screwspigot", "Plugger Spazzring", "Ambassador Flamelash", "The Seven", "Magmus", "Emperor Dagran Thaurissan" } },
    { "LBRS", "Lower Blackrock Spire", "Untere Schwarzfelsspitze", { "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb", "Urok Doomhowl", "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak" } },
    { "UBRS", "Upper Blackrock Spire", "Obere Schwarzfelsspitze", { "Pyroguard Emberseer", "Solakar Flamewreath", "Jed Runewatcher", "Goraluk Anvilcrack", "Warchief Rend Blackhand", "The Beast", "Lord Valthalak", "General Drakkisath" } },
    { "DME", "Dire Maul", "Düsterbruch", { "Pusillin", "Zevrim Thornhoof", "Hydrospawn", "Lethtendris", "Alzzin the Wildshaper", "Tendris Warpwood", "Illyanna Ravenoak", "Magister Kalendris", "Immol'thar", "Prince Tortheldrin", "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik", "Captain Kromcrush", "Cho'Rush the Observer", "King Gordok" } },
    { "STRAT", "Stratholme", "Stratholme", { "Skul", "Hearthsinger Forresten", "The Unforgiven", "Timmy the Cruel", "Malor the Zealous", "Cannon Master Willey", "Archivist Galford", "Balnazzar", "Baroness Anastari", "Nerub'enkan", "Maleki the Pallid", "Magistrate Barthilas", "Ramstein the Gorger", "Baron Rivendare" } },
    { "SCHOLO", "Scholomance", "Scholomance", { "Kirtonos the Herald", "Jandice Barov", "Rattlegore", "Marduk Blackpool", "Vectus", "Ras Frostwhisper", "Instructor Malicia", "Doctor Theolen Krastinov", "Lorekeeper Polkelt", "The Ravenian", "Lord Alexei Barov", "Lady Illucia Barov", "Darkmaster Gandling" } },
    { "ONY", "Onyxia's Lair", "Onyxias Hort", { "Onyxia" } },
    { "MC", "Molten Core", "Geschmolzener Kern", { "Lucifron", "Magmadar", "Gehennas", "Garr", "Shazzrah", "Baron Geddon", "Sulfuron Harbinger", "Golemagg the Incinerator", "Majordomo Executus", "Ragnaros" } },
    { "BWL", "Blackwing Lair", "Pechschwingenhort", { "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Broodlord Lashlayer", "Firemaw", "Ebonroc", "Flamegor", "Chromaggus", "Nefarian" } },
    { "ZG", "Zul'Gurub", "Zul'Gurub", { "High Priestess Jeklik", "High Priest Venoxis", "High Priestess Mar'li", "Bloodlord Mandokir", "High Priest Thekal", "Gahz'ranka", "High Priestess Arlokk", "Jin'do the Hexxer", "Hakkar" } },
    { "AQ20", "Ruins of Ahn'Qiraj", "Ruinen von Ahn'Qiraj", { "Kurinnaxx", "General Rajaxx", "Moam", "Buru the Gorger", "Ayamiss the Hunter", "Ossirian the Unscarred" } },
    { "AQ40", "Temple of Ahn'Qiraj", "Tempel von Ahn'Qiraj", { "The Prophet Skeram", "Battleguard Sartura", "Fankriss the Unyielding", "Viscidus", "Princess Huhuran", "Emperor Vek'lor", "Emperor Vek'nilash", "Ouro", "C'Thun" } },
    { "NAXX", "Naxxramas", "Naxxramas", { "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer", "Heigan the Unclean", "Loatheb", "Instructor Razuvious", "Gothik the Harvester", "Patchwerk", "Grobbulus", "Gluth", "Thaddius", "Sapphiron", "Kel'Thuzad" } },
}

local byId, byName = {}, {}
local function Index()
    if next(byId) then return end
    for _, d in ipairs(Inst.LIST) do
        local e = { id = d[1], en = d[2], de = d[3], bosses = d[4], idx = {} }
        for i, b in ipairs(e.bosses) do e.idx[string.lower(b)] = i end
        byId[e.id] = e
        byName[string.lower(e.en)] = e
        byName[string.lower(e.de)] = e
    end
end

function Inst.Get(id) Index(); return byId[id] end

function Inst.DisplayName(e)
    if type(e) == "string" then return e end
    local de = G.GetLocale and G.GetLocale() == "deDE"
    return de and e.de or e.en
end

-- englischer Boss-Name -> deutscher Name (ueber die Namenslisten aus CodexData, wenn geladen)
local deMap
local function BuildDeMap()
    if deMap then return deMap end
    local map = { toEn = {}, toDe = {} }
    local c = FW.Codex
    if c and c.Seed and c.Seed.Load then pcall(c.Seed.Load) end
    local S = G.FreewoodCodexSeed
    if type(S) == "table" and type(S.ue) == "table" and type(S.ud) == "table" then
        for id, en in pairs(S.ue) do
            local de = S.ud[id]
            if type(en) == "string" and type(de) == "string" then
                map.toEn[string.lower(de)] = en
                map.toDe[string.lower(en)] = de
            end
        end
        deMap = map
    end
    return map
end

function Inst.BossDisplay(name)
    if G.GetLocale and G.GetLocale() == "deDE" then
        local m = BuildDeMap()
        return m.toDe[string.lower(name)] or name
    end
    return name
end

-- findet zu Instanzname (DE/EN) und Boss-Name (DE/EN) die Grundliste. Rueckgabe: Instanz-Eintrag oder nil, Boss (EN) oder Name
function Inst.Canon(instName, bossName)
    Index()
    local e = instName and byName[string.lower(instName)] or nil
    local boss = bossName
    if type(boss) == "string" then
        local lo = string.lower(boss)
        local m = BuildDeMap()
        local en = m.toEn[lo]
        if en then boss = en; lo = string.lower(en) end
        if e and e.idx[lo] then boss = e.bosses[e.idx[lo]] end
        if not e then
            -- Instanz unbekannt: Boss in allen Listen suchen
            for _, d in ipairs(Inst.LIST) do
                local i = Index and byId[d[1]].idx[lo]
                if i then e = byId[d[1]]; boss = e.bosses[i]; break end
            end
        end
    end
    return e, boss
end

------------------------------------------------------------------------
-- Speicher: Guild.DB().members[key].kills[instanzId][boss] = true
------------------------------------------------------------------------

function Guild.NameOfKey(key)
    local row = Guild.rowByKey and Guild.rowByKey[key]
    if row and row.name then return row.name end
    return Guild.Display(key)
end

local function Rec(key)
    local m = Guild.DB().members
    local r = m[key]
    if not r then r = {}; m[key] = r end
    return r
end

function Inst.AddKill(key, instId, boss)
    if not key or not instId or not boss then return false end
    local r = Rec(key)
    r.kills = r.kills or {}
    r.kills[instId] = r.kills[instId] or {}
    if r.kills[instId][boss] then return false end
    r.kills[instId][boss] = true
    return true
end

-- eigener Kill aus einem Ereignis
function Inst.RecordOwn(instName, bossName)
    if Secret(instName) or Secret(bossName) or type(bossName) ~= "string" or bossName == "" then return false end
    local e, boss = Inst.Canon(instName, bossName)
    local id = e and e.id or ("*" .. (type(instName) == "string" and instName ~= "" and instName or "?"))
    local me = Guild.SelfKey()
    if not me then return false end
    local new = Inst.AddKill(me, id, boss)
    if new then
        Inst.Changed()
        Inst.ScheduleSend()
    end
    return new
end

function Inst.Changed()
    FW:Fire("GUILD_MODULE_INST")
end

-- Alle Kills eines Spielers als Liste { {instId, boss}, ... }
function Inst.KillsOf(key)
    local out = {}
    local r = Guild.DB().members[key or ""]
    if r and r.kills then
        for inst, bosses in pairs(r.kills) do
            for boss in pairs(bosses) do out[#out + 1] = { inst, boss } end
        end
    end
    return out
end

-- Wer hat diesen Boss getoetet? Rueckgabe: Liste Anzeigenamen
function Inst.Killers(instId, boss)
    local out = {}
    for key, r in pairs(Guild.DB().members) do
        if r.kills and r.kills[instId] and r.kills[instId][boss] then
            out[#out + 1] = Guild.NameOfKey(key)
        end
    end
    table.sort(out)
    return out
end

-- Alle Instanzen: Grundliste plus dynamische Zusaetze (Eintraege mit Stern)
function Inst.AllInstances()
    Index()
    local out = {}
    for _, d in ipairs(Inst.LIST) do out[#out + 1] = byId[d[1]] end
    local extra = {}
    for _, r in pairs(Guild.DB().members) do
        if r.kills then
            for id, bosses in pairs(r.kills) do
                if not byId[id] then
                    local e = extra[id]
                    if not e then
                        e = { id = id, en = string.gsub(id, "^%*", ""), de = string.gsub(id, "^%*", ""), bosses = {}, idx = {}, dynamic = true }
                        extra[id] = e
                    end
                    for boss in pairs(bosses) do
                        if not e.idx[string.lower(boss)] then
                            e.bosses[#e.bosses + 1] = boss
                            e.idx[string.lower(boss)] = #e.bosses
                        end
                    end
                end
            end
        end
    end
    local list = {}
    for _, e in pairs(extra) do table.sort(e.bosses); list[#list + 1] = e end
    table.sort(list, function(a, b) return a.en < b.en end)
    for _, e in ipairs(list) do out[#out + 1] = e end
    return out
end

-- Kills, die ueber das Wissen der Gilde hinaus bekannt sind: Zaehler pro Instanz
function Inst.Count(e, key)
    local n, total = 0, #e.bosses
    for _, boss in ipairs(e.bosses) do
        if key then
            local r = Guild.DB().members[key]
            if r and r.kills and r.kills[e.id] and r.kills[e.id][boss] then n = n + 1 end
        else
            local any = false
            for _, r in pairs(Guild.DB().members) do
                if r.kills and r.kills[e.id] and r.kills[e.id][boss] then any = true break end
            end
            if any then n = n + 1 end
        end
    end
    return n, total
end

------------------------------------------------------------------------
-- Teilen: K|<Teil>|<Teile>|<Text>, Text = "ID^1,2,3#ID2^4#*Name^Boss~Boss"
------------------------------------------------------------------------

local MAX_PIECES = 8
local rbuf = {}

function Inst.Encode(key)
    Index()
    local r = Guild.DB().members[key or ""]
    if not (r and r.kills) then return "" end
    local parts = {}
    local ids = {}
    for id in pairs(r.kills) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = byId[id]
        local items = {}
        if e then
            for boss in pairs(r.kills[id]) do
                local i = e.idx[string.lower(boss)]
                if i then items[#items + 1] = i end
            end
            table.sort(items)
            if #items > 0 then parts[#parts + 1] = id .. "^" .. table.concat(items, ",") end
        else
            local names = {}
            for boss in pairs(r.kills[id]) do names[#names + 1] = string.gsub(boss, "[%^#~|%c]", "") end
            table.sort(names)
            if #names > 0 then parts[#parts + 1] = string.gsub(id, "[%^#~|%c]", "") .. "^" .. table.concat(names, "~") end
        end
    end
    return table.concat(parts, "#")
end

function Inst.Decode(text)
    Index()
    local out = {}
    for chunk in string.gmatch(text or "", "[^#]+") do
        local id, rest = string.match(chunk, "^([^%^]+)%^(.*)$")
        if id and rest then
            local e = byId[id]
            if e then
                for n in string.gmatch(rest, "%d+") do
                    local boss = e.bosses[tonumber(n)]
                    if boss then out[id] = out[id] or {}; out[id][boss] = true end
                end
            elseif string.sub(id, 1, 1) == "*" and #id <= 40 then
                local count = 0
                for boss in string.gmatch(rest, "[^~]+") do
                    count = count + 1
                    if count > 40 then break end
                    out[id] = out[id] or {}
                    out[id][string.sub(boss, 1, 40)] = true
                end
            end
        end
    end
    return out
end

function Inst.Send()
    if not Guild.InGuild() then return false end
    local me = Guild.SelfKey()
    if not me then return false end
    local text = Inst.Encode(me)
    Inst.lastSend = Clock()
    if text == "" then return false end
    local pieces = Share.Split(text, 190)
    if #pieces > MAX_PIECES then return false end
    for i, p in ipairs(pieces) do
        Share.Queue(string.format("K|%d|%d|%s", i, #pieces, p), "GUILD")
    end
    return true
end

function Inst.ScheduleSend()
    if Inst.sendPending then return end
    Inst.sendPending = true
    Share.After(15, function() Inst.sendPending = false; Inst.Send() end)
end

Share.handlers["K"] = function(key, body, channel, sender)
    local idx, n, chunk = string.match(body, "^(%d+)|(%d+)|(.*)$")
    idx, n = tonumber(idx), tonumber(n)
    if not idx or not n or n < 1 or n > MAX_PIECES or idx < 1 or idx > n then return end
    local buf = rbuf[key]
    if idx == 1 or not buf or buf.n ~= n then buf = { n = n, parts = {}, got = 0 }; rbuf[key] = buf end
    if not buf.parts[idx] then buf.got = buf.got + 1 end
    buf.parts[idx] = chunk
    if buf.got == n then
        rbuf[key] = nil
        local kills = Inst.Decode(table.concat(buf.parts))
        local r = Rec(key)
        r.kills = kills
        Inst.Changed()
    end
end

table.insert(Share.startHooks, function() Share.After(40 + math.random() * 20, Inst.Send) end)
table.insert(Share.requestHooks, function() Share.After(10 + math.random() * 30, Inst.Send) end)
table.insert(Share.sendAllHooks, Inst.Send)

------------------------------------------------------------------------
-- Aufzeichnen
------------------------------------------------------------------------

local function CurrentInstanceName()
    if not G.GetInstanceInfo then return nil end
    local ok, name = pcall(G.GetInstanceInfo)
    if ok and type(name) == "string" and not Secret(name) then return name end
    return nil
end

function Inst.ImportSaved()
    if not (G.GetNumSavedInstances and G.GetSavedInstanceInfo and G.GetSavedInstanceEncounter) then return 0 end
    local ok, num = pcall(G.GetNumSavedInstances)
    if not ok or type(num) ~= "number" then return 0 end
    local added = 0
    for i = 1, num do
        local ok2, name, _, _, _, locked, _, _, _, _, _, numEnc = pcall(G.GetSavedInstanceInfo, i)
        if ok2 and type(name) == "string" and not Secret(name) and locked and type(numEnc) == "number" then
            for j = 1, numEnc do
                local ok3, boss, _, killed = pcall(G.GetSavedInstanceEncounter, i, j)
                if ok3 and killed and type(boss) == "string" and not Secret(boss) then
                    if Inst.RecordOwn(name, boss) then added = added + 1 end
                end
            end
        end
    end
    return added
end

local owner = {}
local registered = false
local function Register()
    if registered then return end
    registered = true
    FW:RegisterEvent("ENCOUNTER_END", function(_, id, name, difficulty, size, success)
        if success == 1 or success == true then
            Inst.RecordOwn(CurrentInstanceName(), name)
        end
    end, owner)
    FW:RegisterEvent("UPDATE_INSTANCE_INFO", function() pcall(Inst.ImportSaved) end, owner)
    FW:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
        if not G.CombatLogGetCurrentEventInfo then return end
        local ok, _, sub, _, _, _, _, _, _, destName = pcall(G.CombatLogGetCurrentEventInfo)
        if not ok or Secret(sub) or Secret(destName) then return end
        if sub ~= "UNIT_DIED" or type(destName) ~= "string" then return end
        local inst = CurrentInstanceName()
        if not inst then return end
        -- nur Bosse aus der Grundliste zaehlen, damit nicht jeder Mob eintragen wird
        local e, boss = Inst.Canon(inst, destName)
        if e and e.idx[string.lower(boss)] then Inst.RecordOwn(inst, destName) end
    end, owner)
    Share.After(25, function()
        if G.RequestRaidInfo then pcall(G.RequestRaidInfo) end
    end)
end
table.insert(Share.startHooks, Register)

------------------------------------------------------------------------
-- Seite
------------------------------------------------------------------------

local UI = FW.UI
local W = Guild.Widgets
if UI and W and Guild.RegisterPage then
    local ROW_H = 26

    local function Build(content)
        local L = FW.L
        local f = CreateFrame("Frame", nil, content)
        f.selected = "RFC"
        f.player = nil

        local dd = UI.CreateDropdown(f, 220, 24, {
            getOptions = function()
                local list = { { value = "", text = L.INST_ALL_PLAYERS } }
                local names = {}
                for key, r in pairs(Guild.DB().members) do
                    if r.kills and next(r.kills) then names[#names + 1] = key end
                end
                table.sort(names)
                for _, k in ipairs(names) do list[#list + 1] = { value = k, text = Guild.NameOfKey(k) } end
                return list
            end,
            textOf = function(v) return (v and v ~= "") and Guild.NameOfKey(v) or L.INST_ALL_PLAYERS end,
            onChange = function(v) f.player = (v and v ~= "") and v or nil; f.Refresh() end,
        })
        dd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        dd:SetValue("")
        local info = UI.CreateLabel(f, L.INST_INFO, { size = 11, color = "textDim" })
        info:SetPoint("LEFT", dd, "RIGHT", 10, 0)
        info:SetWordWrap(false)
        local mine = UI.CreateButton(f, L.INST_MINE, 160, 24, function() Inst.ImportSaved(); if G.RequestRaidInfo then pcall(G.RequestRaidInfo) end; f.Refresh() end)
        mine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

        local left = UI.CreateScrollFrame(f)
        left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
        left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        left:SetWidth(230)
        local right = UI.CreateScrollFrame(f)
        right:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -34)
        right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        local rtitle = UI.CreateLabel(right.child, "", { font = "heading", size = 15, color = "goldLight" })
        rtitle:SetPoint("TOPLEFT", right.child, "TOPLEFT", 4, -2)
        local empty = UI.CreateLabel(f, L.INST_NONE, { size = 12, color = "textDim" })
        empty:SetPoint("TOPLEFT", f, "TOPLEFT", 248, -70)

        local dBtns, bRows = {}, {}

        local function Tip(self)
            if not G.GameTooltip or not self.e then return end
            G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            G.GameTooltip:AddLine(Inst.BossDisplay(self.boss), 1, 0.82, 0)
            local names = Inst.Killers(self.e.id, self.boss)
            if #names == 0 then
                G.GameTooltip:AddLine(L.INST_NOBODY, 0.7, 0.7, 0.7)
            else
                G.GameTooltip:AddLine(string.format(L.INST_KILLED_BY, #names), 0.4, 0.9, 0.4)
                local line = {}
                for i, n in ipairs(names) do
                    line[#line + 1] = n
                    if #line == 4 or i == #names then
                        G.GameTooltip:AddLine(table.concat(line, ", "), 0.9, 0.9, 0.9, true)
                        line = {}
                    end
                end
            end
            G.GameTooltip:Show()
        end

        function f.Refresh()
            local all = Inst.AllInstances()
            for i, e in ipairs(all) do
                local b = dBtns[i]
                if not b then
                    b = UI.CreateButton(left.child, "", 216, 24, nil)
                    b.label:SetJustifyH("LEFT")
                    dBtns[i] = b
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", left.child, "TOPLEFT", 0, -(i - 1) * 27)
                local n, total = Inst.Count(e, f.player)
                b:SetLabel(string.format("%s  %d/%d", Inst.DisplayName(e), n, total))
                b:SetStyle(e.id == f.selected and "primary" or "default")
                b:SetScript("OnClick", function() f.selected = e.id; f.Refresh() end)
                b:Show()
            end
            for i = #all + 1, #dBtns do dBtns[i]:Hide() end
            left:SetContentHeight(#all * 27 + 4)

            local cur
            for _, e in ipairs(all) do if e.id == f.selected then cur = e end end
            cur = cur or all[1]
            rtitle:SetText(cur and Inst.DisplayName(cur) or "")
            local bosses = cur and cur.bosses or {}
            for i, boss in ipairs(bosses) do
                local r = bRows[i]
                if not r then
                    r = CreateFrame("Frame", nil, right.child)
                    r:SetHeight(ROW_H - 2)
                    r:EnableMouse(true)
                    r.bg = r:CreateTexture(nil, "BACKGROUND")
                    r.bg:SetAllPoints()
                    r.bg:SetColorTexture(UI.Color("card", 0.7))
                    r.name = UI.CreateLabel(r, "", { size = 12 })
                    r.name:SetPoint("LEFT", r, "LEFT", 8, 0)
                    r.name:SetPoint("RIGHT", r, "RIGHT", -150, 0)
                    r.name:SetWordWrap(false)
                    r.count = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT" })
                    r.count:SetPoint("RIGHT", r, "RIGHT", -8, 0)
                    r:SetScript("OnEnter", Tip)
                    r:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
                    bRows[i] = r
                end
                r.e, r.boss = cur, boss
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", right.child, "TOPLEFT", 0, -26 - (i - 1) * ROW_H)
                r:SetPoint("TOPRIGHT", right.child, "TOPRIGHT", 0, -26 - (i - 1) * ROW_H)
                local names = Inst.Killers(cur.id, boss)
                local killed
                if f.player then
                    local rec = Guild.DB().members[f.player]
                    killed = rec and rec.kills and rec.kills[cur.id] and rec.kills[cur.id][boss]
                    r.count:SetText(killed and L.INST_DONE or L.INST_OPEN)
                    r.count:SetTextColor(UI.Color(killed and "success" or "textDim"))
                else
                    killed = #names > 0
                    r.count:SetText(#names > 0 and string.format(L.INST_COUNT, #names) or L.INST_OPEN)
                    r.count:SetTextColor(UI.Color(#names > 0 and "success" or "textDim"))
                end
                r.name:SetText(Inst.BossDisplay(boss))
                r.name:SetTextColor(UI.Color(killed and "text" or "textDim"))
                r:Show()
            end
            for i = #bosses + 1, #bRows do bRows[i]:Hide() end
            right:SetContentHeight(#bosses * ROW_H + 34)
            if empty then empty:Hide() end
        end

        FW:On("GUILD_MODULE_INST", function() if f:IsVisible() then f.Refresh() end end, f)
        FW:On("GUILD_MODULE_DATA", function() if f:IsVisible() then f.Refresh() end end, f)
        Inst.frame = f
        return f
    end

    Guild.RegisterPage("instances", {
        order = 60,
        label = function() return FW.L.INST_TAB end,
        build = Build,
        refresh = function(f) f.Refresh() end,
    })
end
