local PO_FILENAME = "finnish.po"
local LANG_CODE = "fi"

LoadPOFile(PO_FILENAME, LANG_CODE)

_G = GLOBAL

mods = _G.rawget(_G, "mods")
if not mods then
	mods = {}
	_G.rawset(_G, "mods", mods)
end
_G.mods = mods

-- Mod attributes
mods.FinLoc = {
	modinfo = modinfo,
	StorePath = MODROOT,
	MainPoFile = PO_FILENAME,
	SelectedLanguage = LANG_CODE
}
modimport("scripts/patch.lua")

-- Function for splitting a string into a table
function split(str, sep)
    local fields, first = {}, 1
    str = str .. sep

    for i = 1, #str do
        if str:sub(i, i) == sep then
        fields[#fields + 1] = str:sub(first, i - 1)
            first = i + 1
        end
    end
    return fields
end

local STRINGS_NEW = _G.LanguageTranslator.languages[LANG_CODE] or {}
local TABLE = {}

-- Function for recursively populating the global string table 
function buildTable(stringsNode, str)
    for i, v in pairs(stringsNode) do
        if type(v) == "table" then
            buildTable(stringsNode[i], str .. "." .. i)
        else
            local val = STRINGS_NEW[str .. "." .. i]

            if val then
                TABLE[v] = val
            end
        end
    end
end
buildTable(_G.STRINGS, "STRINGS")

-- Function for fetching / constructing translated strings from the global string table
function translateFromTable(s)
    -- Check if the string is present in the global string table, and if it is, return it
    local tmp = TABLE[s]
    if tmp then return tmp end

    -- Function to check if the string is acceptable after a player's nickname
    local function isAcceptableAfterNick(x)
        return x == ' ' or x == ',' or x == '.' or x == '!' or x == '?' or x == '\''
    end

    -- Replacing strings with a single placeholder (%s)
    local function replaceSinglePlaceholder(s, n)
        local ret, nickLen = nil, n + 1

        for i = 1, n do
            if i == 1 or s:sub(i - 1, i - 1) == ' ' then
                for j = math.min(n, i + nickLen - 2), i, -1 do
                    if j == n or isAcceptableAfterNick(s:sub(j + 1, j + 1)) then
                        local pattern = s:sub(1, i - 1) .. "%s" .. s:sub(j + 1)
                        local x = TABLE[pattern]

                        if x then
                            x = x:gsub("%%s", s:sub(i, j))

                            if j - i + 1 < nickLen then
                                nickLen = j - i + 1
                                ret = x
                            end
                        end
                    end
                end
            end
        end
        return ret
    end

    -- Replacing strings with double placeholders (%s)
    local function replaceDoublePlaceholders(s, n)
        local ret, nickLen = nil, n + 1

        for i = 1, n do
            if i == 1 or s:sub(i - 1, i - 1) == ' ' then
                for j = math.min(n, i + nickLen - 2), i, -1 do
                    if j == n or isAcceptableAfterNick(s:sub(j + 1, j + 1)) then
                        for k = j + 2, n do
                            if s:sub(k - 1, k - 1) == ' ' then
                                for l = k, n do
                                    if l == n or isAcceptableAfterNick(s:sub(l + 1, l + 1)) then
                                        local pattern = s:sub(1, i - 1) .. "%s" .. s:sub(j + 1, k - 1) .. "%s" .. s:sub(l + 1)
                                        local x = TABLE[pattern]

                                        if x then
                                            local attacker = s:sub(k, l)
                                            attacker = TABLE[attacker] or attacker
                                            x = x:gsub("%%s", s:sub(i, j), 1):gsub("%%s", attacker)

                                            if j - i + 1 < nickLen then
                                                nickLen = j - i + 1
                                                ret = x
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return ret
    end
    local n = s:len()
    local ret = replaceSinglePlaceholder(s, n)
    if ret then return ret end

    ret = replaceDoublePlaceholders(s, n)
    return ret or s
end

-- Function for constructing the final translation
function translateMessage(message)
    -- Split multi-line strings into a table
    local messages = split(message, '\n') or {message}
    local ret = ""

    -- Translate each line's string one by one
    for i = 1, #messages do
        local translated = translateFromTable(messages[i])

        if i == 1 then
            ret = translated
        elseif translated ~= messages[i] then
            ret = ret .. "\n" .. translated
        else
            ret = ret .. translateFromTable("\n" .. messages[i])
        end
    end
    return ret
end
  
-- Function for applying the translations
function runTranslatingEngine()
    if _G.rawget(_G, "Networking_Talk") then
        local OldNetworking_Talk = _G.Networking_Talk

        function Networking_Talk(guid, message, ...)
            message = translateMessage(message)
            if OldNetworking_Talk then OldNetworking_Talk(guid, message, ...) end
        end
        _G.Networking_Talk = Networking_Talk
    end
    local deathAnnouncement = _G.Networking_DeathAnnouncement
    local deathSeparator = _G.STRINGS.UI.HUD.DEATH_ANNOUNCEMENT_1
    local deathPossibleEnds = { _G.STRINGS.UI.HUD.DEATH_ANNOUNCEMENT_2_DEFAULT,
                                _G.STRINGS.UI.HUD.DEATH_ANNOUNCEMENT_2_MALE,
                                _G.STRINGS.UI.HUD.DEATH_ANNOUNCEMENT_2_FEMALE,
                                _G.STRINGS.UI.HUD.DEATH_ANNOUNCEMENT_2_ROBOT,
                                "." }
    
    _G.Networking_DeathAnnouncement = function(message, ...)		
        if deathSeparator then
            local k, l = message:find(deathSeparator)

            if k and l then
                for i = 1, #deathPossibleEnds do			
                    if deathPossibleEnds[i] and message:sub(-deathPossibleEnds[i]:len()) == deathPossibleEnds[i] then
                        local victim = message:sub(1, k - 2)
                        local attacker = message:sub(l + 2, -deathPossibleEnds[i]:len() - 1)
                        deathAnnouncement(victim .. " " ..
                                            (TABLE[deathSeparator] or deathSeparator) .. " " ..
                                            (TABLE[attacker] or attacker)..
                                            (TABLE[deathPossibleEnds[i]] or deathPossibleEnds[i]),
                                            ...)
                        return
                    end
                end
            end
        end
        deathAnnouncement(message, ...)
    end
    local resurrectAnnouncement = _G.Networking_ResurrectAnnouncement
    local resSeparator = _G.STRINGS.UI.HUD.REZ_ANNOUNCEMENT
    
    _G.Networking_ResurrectAnnouncement = function(message, ...)
        if resSeparator then
            local k, l = message:find(resSeparator)
            
            if k and l then
                local victim = message:sub(1, k - 2)
                local attacker = message:sub(l + 2)
                resurrectAnnouncement(victim .. " " ..
                                        (TABLE[resSeparator] or resSeparator) .. " " ..
                                        (TABLE[attacker] or attacker),
                                        ...)
                return
            end
        end
        resurrectAnnouncement(message, ...)
    end
end	
runTranslatingEngine()
