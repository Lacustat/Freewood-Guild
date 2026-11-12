-- Freewood-Guild: Probe "Wer in der Gilde kann dieses Rezept?" (Blizzards Gilden-Rezeptabfrage).
--
-- Blizzard bietet im Berufefenster den Knopf "Gildenhandwerker anzeigen". Dahinter stecken
--   C_GuildInfo.QueryGuildMembersForRecipe(skillLineID, recipeID, recipeLevel)  -> Abfrage an den Server
--   Ereignis GUILD_RECIPE_KNOWN_BY_MEMBERS, dann GetGuildRecipeInfoPostQuery() -> skillLineID, recipeID, Anzahl
--   GetGuildRecipeMember(i) -> Anzeigename, voller Name, Klasse, online
-- Das waere eine Quelle fuer Berufe/Rezepte von Mitgliedern OHNE dieses Addon. Ob Forever das anbietet und was es
-- liefert, prueft dieser Befehl (/fwguild gildenrezepte): er zeigt, welche Funktionen es gibt, und fragt bei geoeffnetem
-- eigenem Berufefenster drei gelernte und zwei nicht gelernte Rezepte ab. Ergebnis im Chat und in
-- FreewoodGuildDB.recipeQuery. Es wird nichts in der Gildenuebersicht gespeichert. UNGEPRUEFT im Spiel.

local ADDON, NS = ...

local FW = _G.Freewood
local Guild = NS and NS.Guild
if not FW or not Guild then
    return
end

local G = _G
local Q = {}
Guild.RecipeQuery = Q

local TIMEOUT = 5
local MAX_NAMES = 40
local MAX_LOG = 30

local function Secret(v) return Guild.Secret(v) end

local queue, waiting, token = {}, nil, 0

function Q.Log()
    local db = Guild.DB()
    db.recipeQuery = db.recipeQuery or {}
    return db.recipeQuery
end

local function Out(text)
    FW:Print(text)
    local log = Q.Log()
    log[#log + 1] = text
    while #log > MAX_LOG do table.remove(log, 1) end
end

-- Welche Funktionen gibt es?
function Q.Availability()
    local gi = G.C_GuildInfo
    local list = {
        { "C_GuildInfo.QueryGuildMembersForRecipe", gi and gi.QueryGuildMembersForRecipe },
        { "GetGuildRecipeInfoPostQuery", G.GetGuildRecipeInfoPostQuery },
        { "GetGuildRecipeMember", G.GetGuildRecipeMember },
        { "C_TradeSkillUI.IsTradeSkillGuild", G.C_TradeSkillUI and G.C_TradeSkillUI.IsTradeSkillGuild },
    }
    local out, all = {}, true
    for _, e in ipairs(list) do
        local has = type(e[2]) == "function"
        if not has then all = false end
        out[#out + 1] = (has and "+ " or "- ") .. e[1]
    end
    return out, all
end

-- Alle Funktionen, die nach Gilde und Beruf/Rezept klingen (Suche nach einem Weg in die Gilden-Berufsansicht)
function Q.Scan()
    local found = {}
    local function Look(tbl, prefix)
        if type(tbl) ~= "table" then return end
        local ok = pcall(function()
            for k, v in pairs(tbl) do
                if type(k) == "string" and type(v) == "function" then
                    local l = string.lower(k)
                    if string.find(l, "guild", 1, true) and (string.find(l, "recipe", 1, true) or string.find(l, "trade", 1, true)
                        or string.find(l, "skill", 1, true) or string.find(l, "profession", 1, true) or string.find(l, "craft", 1, true)) then
                        found[#found + 1] = prefix .. k
                    end
                end
            end
        end)
        return ok
    end
    Look(G, "")
    Look(G.C_GuildInfo, "C_GuildInfo.")
    Look(G.C_TradeSkillUI, "C_TradeSkillUI.")
    -- zusaetzlich jede Funktion von C_TradeSkillUI mit "Guild" im Namen
    local ts = G.C_TradeSkillUI
    if type(ts) == "table" then
        pcall(function()
            for k, v in pairs(ts) do
                if type(k) == "string" and type(v) == "function" and string.find(string.lower(k), "guild", 1, true) then
                    local name = "C_TradeSkillUI." .. k
                    local dup = false
                    for _, f in ipairs(found) do if f == name then dup = true end end
                    if not dup then found[#found + 1] = name end
                end
            end
        end)
    end
    table.sort(found)
    return found
end

-- Rezepte fuer die Abfrage aus dem offenen eigenen Berufefenster: { skillLineID, { {id, learned}, ... } }
function Q.Pick()
    local ts = G.C_TradeSkillUI
    if not ts or not ts.GetBaseProfessionInfo or not ts.GetAllRecipeIDs or not ts.GetRecipeInfo then return nil, "kein Berufefenster-Zugriff" end
    local okB, bi = pcall(ts.GetBaseProfessionInfo)
    if not okB or type(bi) ~= "table" or not bi.professionID or bi.professionID == 0 then
        return nil, "kein Berufefenster offen"
    end
    if ts.IsTradeSkillLinked then
        local okL, linked = pcall(ts.IsTradeSkillLinked)
        if okL and linked then return nil, "das offene Fenster ist ein verlinkter Beruf, bitte den eigenen oeffnen" end
    end
    local okA, all = pcall(ts.GetAllRecipeIDs)
    if not okA or type(all) ~= "table" then return nil, "keine Rezepte" end
    local learned, other = {}, {}
    for _, rid in ipairs(all) do
        local ok, info = pcall(ts.GetRecipeInfo, rid)
        if ok and type(info) == "table" then
            if info.learned then
                if #learned < 3 then learned[#learned + 1] = { rid, true, info.name } end
            elseif #other < 2 then
                other[#other + 1] = { rid, false, info.name }
            end
        end
        if #learned >= 3 and #other >= 2 then break end
    end
    local picks = {}
    for _, p in ipairs(learned) do picks[#picks + 1] = p end
    for _, p in ipairs(other) do picks[#picks + 1] = p end
    return bi.parentProfessionID or bi.professionID, picks, bi.professionName
end

local Next

local function Report(skill, recipe, n, label)
    local names = {}
    local getMember = G.GetGuildRecipeMember
    local online = 0
    if getMember then
        for i = 1, math.min(tonumber(n) or 0, MAX_NAMES) do
            local ok, display, full, _, on = pcall(getMember, i)
            if ok and type(display) == "string" and not Secret(display) then
                names[#names + 1] = display .. (on and "" or " (offline)")
                if on then online = online + 1 end
            end
        end
    end
    Out(string.format("Gildenrezept %s (%s): %s Mitglieder, %d online%s", tostring(label or recipe), tostring(recipe),
        tostring(n), online, #names > 0 and (" | " .. table.concat(names, ", ")) or ""))
end

function Q.OnEvent(...)
    local f = G.GetGuildRecipeInfoPostQuery
    local ok, skill, recipe, n
    if f then ok, skill, recipe, n = pcall(f) end
    local raw = {}
    for i = 1, select("#", ...) do raw[#raw + 1] = tostring((select(i, ...))) end
    Out("Ereignis GUILD_RECIPE_KNOWN_BY_MEMBERS (Werte: " .. table.concat(raw, ",") .. ") | Ergebnis: " ..
        tostring(skill) .. ", " .. tostring(recipe) .. ", " .. tostring(n))
    if not waiting or not ok then return end
    local w = waiting
    if w.recipe ~= recipe then return end
    waiting = nil
    Report(skill, recipe, n, w.label)
    Next()
end

Next = function()
    if waiting then return end
    local job = table.remove(queue, 1)
    if not job then return end
    local gi = G.C_GuildInfo
    local ok, updated = pcall(gi.QueryGuildMembersForRecipe, job.skill, job.recipe, job.level)
    if not ok then
        Out("Abfrage " .. tostring(job.label) .. ": Fehler " .. tostring(updated))
        return Next()
    end
    if not updated then
        Out("Abfrage " .. tostring(job.label) .. " (" .. (job.learned and "gelernt" or "nicht gelernt") .. "): vom Spiel abgelehnt")
        return Next()
    end
    job.recipe = updated
    waiting = job
    token = token + 1
    local my = token
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(TIMEOUT, function()
            if waiting and token == my then
                local f = G.GetGuildRecipeInfoPostQuery
                local ok, a, b, c = false
                if f then ok, a, b, c = pcall(f) end
                Out("Abfrage " .. tostring(job.label) .. " (Stufe " .. tostring(job.level) .. "): keine Antwort in " .. TIMEOUT ..
                    " s | Ergebnisfunktion: " .. tostring(a) .. ", " .. tostring(b) .. ", " .. tostring(c))
                waiting = nil
                Next()
            end
        end)
    end
end

-- Befehl /fwguild gildenrezepte
function Q.Run()
    local lines, all = Q.Availability()
    Out("Gilden-Rezeptabfrage, Funktionen (+ vorhanden, - fehlt):")
    for _, l in ipairs(lines) do Out(l) end
    local scan = Q.Scan()
    Out("Gilde/Beruf-Funktionen im Spiel (" .. #scan .. "): " .. (#scan > 0 and table.concat(scan, ", ") or "keine"))
    local ts = G.C_TradeSkillUI
    if ts and ts.IsTradeSkillGuild then
        local okG, isG = pcall(ts.IsTradeSkillGuild)
        Out("Gilden-Berufsansicht gerade offen: " .. tostring(okG and isG))
    end
    if not all then
        Out("Nicht alle Funktionen vorhanden: die Abfrage ist hier nicht moeglich.")
        return false
    end
    if not Guild.InGuild() then Out("Nicht in einer Gilde."); return false end
    local skill, picks, profName = Q.Pick()
    if not skill then
        Out("Zum Abfragen: erst den eigenen Beruf oeffnen (" .. tostring(picks) .. "), dann den Befehl nochmal.")
        return false
    end
    Out("Beruf " .. tostring(profName or skill) .. " (" .. tostring(skill) .. "): " .. #picks .. " Abfragen")
    queue, waiting = {}, nil
    for i, p in ipairs(picks) do
        queue[#queue + 1] = { skill = skill, recipe = p[1], learned = p[2], label = p[3] or p[1] }
        if i == 1 then
            -- erstes Rezept zusaetzlich mit Stufe 0 (Blizzard gibt die Stufe der Rezeptansicht mit)
            queue[#queue + 1] = { skill = skill, recipe = p[1], learned = p[2], label = p[3] or p[1], level = 0 }
        end
    end
    Next()
    return true
end

FW:RegisterEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS", function(...) pcall(Q.OnEvent, ...) end, Q)

function Q.PrintLog()
    local log = Q.Log()
    if #log == 0 then FW:Print("Gilden-Rezeptabfrage: noch keine Ergebnisse. /fwguild gildenrezepte") return end
    for i = math.max(1, #log - 11), #log do FW:Print(log[i]) end
end
