local CodeInfoCache = {}
--[[
{
    "macroid": {
        {
            type: "cast",               cast/stopmacro/use/castsequence/showtooltip/fallback
            body: "[mod:alt] X; Y"
        },
        ...
    }
}
--]]

local function trim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

local function lastIndexOf(str, match, maxIndex)
    local index = string.find(str, match)

    if index ~= nil then
        local nextIndex = string.find(str, match, index + 1)
        while nextIndex and (not maxIndex or nextIndex < maxIndex) do
            index = nextIndex
            nextIndex = string.find(str, match, index + 1)
        end
    end

    return index
end

local function Char(str, index)
    if string.len(str) >= index then
        return string.sub(str, index, index)
    end
end

local function ParseSpaces(parsingContext)
    local result = false

    while Char(parsingContext.Code, parsingContext.Index) == " " do
        result = true
        parsingContext.Index = parsingContext.Index + 1
    end

    return result
end

local function ParseEndOfLine(parsingContext)
    local result = false

    while Char(parsingContext.Code, parsingContext.Index) == "\n" do
        result = true
        parsingContext.Index = parsingContext.Index + 1
        ParseSpaces(parsingContext)
    end

    return result
end

local function ParseWord(parsingContext)
    local result = false
    local word = ""

    local character = Char(parsingContext.Code, parsingContext.Index)
    while string.match(character, "[a-z]") or string.match(character, "[A-Z]") or string.match(character, "[0-9]") or character == "_" do
        word = word .. character
        result = true
        parsingContext.Index = parsingContext.Index + 1
        character = Char(parsingContext.Code, parsingContext.Index)
    end
    
    return result, word
end

local function GrabRemainingLineCode(parsingContext)
    local code = ""
    local character = Char(parsingContext.Code, parsingContext.Index)
    local appendToCode = true -- ignore comments trailing lines of code

    while character ~= nil and character ~= "\n" do
        if character == "#" then
            appendToCode = false
        end

        if appendToCode then
            code = code .. character
        end

        parsingContext.Index = parsingContext.Index + 1
        character = Char(parsingContext.Code, parsingContext.Index)
    end

    return code
end

local function ParseCastCommand(parsingContext)
    local castCode = trim(GrabRemainingLineCode(parsingContext))
    table.insert(
        CodeInfoCache[parsingContext.MacroId],
        {
            Type = "cast",
            Body = castCode
        })
end

local function ParseCastsequenceCommand(parsingContext)
    local body = trim(GrabRemainingLineCode(parsingContext))
    table.insert(
        CodeInfoCache[parsingContext.MacroId],
        {
            Type = "castsequence",
            Body = body
        })
end

local function ParseStopmacroCommand(parsingContext)
    local condition = trim(GrabRemainingLineCode(parsingContext))
    table.insert(
        CodeInfoCache[parsingContext.MacroId],
        {
            Type = "stopmacro",
            Body = condition + "TRUE"
        })
end

local function ParseCommand(parsingContext)
    local result = false

    if Char(parsingContext.Code, parsingContext.Index) == "/" then
        parsingContext.Index = parsingContext.Index + 1
        local wordResult, word = ParseWord(parsingContext)

        if wordResult then
            word = string.lower(word)
            result = true
            ParseSpaces(parsingContext)

            if word == "cast" or word == "use" then
                ParseCastCommand(parsingContext)
            elseif word == "castsequence" then
                ParseCastsequenceCommand(parsingContext)
            elseif word == "stopmacro" then
                ParseStopmacroCommand(parsingContext)
            end
        end
    end
        
    GrabRemainingLineCode(parsingContext)
    ParseEndOfLine(parsingContext)

    return result
end

local function ParseShowtooltip(parsingContext)
    if Char(parsingContext.Code, parsingContext.Index) == "#" then
        parsingContext.Index = parsingContext.Index + 1
        local wordResult, word = ParseWord(parsingContext)

        if wordResult and string.lower(word) == "showtooltip" then
            local body = trim(GrabRemainingLineCode(parsingContext))
            if string.len(body) > 0 then
                table.insert(
                    CodeInfoCache[parsingContext.MacroId],
                    {
                        Type = "showtooltip",
                        Body = body
                    })
                return true
            end
        end
    end

    return false
end

local function AddFallbackAbility(macroId)
    local codeInfo = CodeInfoCache[macroId]
    local codeInfoLength = #codeInfo

    for i=1, codeInfoLength do
        if codeInfo[i].Type == "showtooltip" then
            break
        elseif codeInfo[i].Type == "cast" or codeInfo[i].Type == "use" then
            local endOfAbility = string.find(codeInfo[i].Body, ";")
            endOfAbility = endOfAbility and (endOfAbility - 1)
            local endOfConditions = (lastIndexOf(codeInfo[i].Body, "%]", endOfAbility) or 0) + 1

            local abilityName = trim(string.sub(codeInfo[i].Body, endOfConditions, endOfAbility))

            table.insert(
                codeInfo,
                {
                    Type = "fallbackAbility",
                    Body = abilityName
                })
            break
        elseif codeInfo[i].Type == "castsequence" then
            local endOfSequence = string.find(codeInfo[i].Body, ";")
            endOfSequence = endOfSequence and (endOfSequence - 1)
            local endOfConditions = (lastIndexOf(codeInfo[i].Body, "%]", endOfSequence) or 0) + 1

            local sequence = trim(string.sub(codeInfo[i].Body, endOfConditions, endOfSequence))

            table.insert(
                codeInfo,
                {
                    Type = "fallbackSequence",
                    Body = sequence
                })
            break
        elseif codeInfo[i].Type == "stopmacro" then
            -- ignore
        end
    end
end

local function CalculateMacroInfo(macro)
    local parsingContext = { MacroId = macro.Id, Index = 1, Code = macro.Code }
    CodeInfoCache[macro.Id] = {}

    -- skip to start of code
    ParseSpaces(parsingContext)
    ParseEndOfLine(parsingContext)

    if parsingContext.Index < string.len(parsingContext.Code) then
        if not ParseShowtooltip(parsingContext) then
            while parsingContext.Index <= string.len(parsingContext.Code) do
                ParseCommand(parsingContext)
            end
        end
    end

    AddFallbackAbility(macro.Id)

    return CodeInfoCache[macro.Id]
end

MegaMacroCodeInfo = {}

function MegaMacroCodeInfo.Get(macro)
    return CodeInfoCache[macro.Id] or CalculateMacroInfo(macro)
end

function MegaMacroCodeInfo.Clear(macroId)
    
    CodeInfoCache[macroId] = nil
end

function MegaMacroCodeInfo.ClearAll()
    CodeInfoCache = {}
end