-- Im making a json thing too!

-- localize hot functions so lua doesnt do global lookups every time
local sfind             = string.find
local ssub              = string.sub
local sbyte             = string.byte
local sformat           = string.format
local tinsert           = table.insert
local tconcat           = table.concat

-- byte constants so we dont allocate strings just to compare one character
local BYTE_QUOTE        = sbyte('"')
local BYTE_BACKSLASH    = sbyte('\\')
local BYTE_LBRACE       = sbyte('{')
local BYTE_RBRACE       = sbyte('}')
local BYTE_LBRACKET     = sbyte('[')
local BYTE_RBRACKET     = sbyte(']')
local BYTE_COLON        = sbyte(':')
local BYTE_COMMA        = sbyte(',')
local BYTE_t            = sbyte('t')
local BYTE_f            = sbyte('f')
local BYTE_n            = sbyte('n')
local BYTE_MINUS        = sbyte('-')
local BYTE_0            = sbyte('0')
local BYTE_9            = sbyte('9')

local escape_characters = {
    ['"']  = '"',
    ['\\'] = '\\',
    ['/']  = '/',
    ['b']  = '\b',
    ['f']  = '\f',
    ['n']  = '\n',
    ['r']  = '\r',
    ['t']  = '\t'
}

-- progress tracking state (set by parse())
local progress_callback = nil
local progress_total    = 0
local progress_last_pct = -1

local function maybe_report_progress(position)
    if progress_callback and progress_total > 0 then
        local pct = math.floor((position / progress_total) * 100)
        if pct > progress_last_pct then
            progress_last_pct = pct
            progress_callback(position, progress_total, pct)
        end
    end
end

local function parse_string(str, pos)
    pos = pos + 1 -- skips over opening quote...

    -- bulk search: find the next quote or backslash instead of going char by char
    local chunks = {}
    local chunk_start = pos

    while pos <= #str do
        -- jump to the next interesting character (" or \)
        local found = sfind(str, '[\"\\\\]', pos)
        if not found then
            error("End of file without closing quote")
        end

        local b = sbyte(str, found)
        if b == BYTE_QUOTE then
            -- grab everything from chunk_start to here and we're done
            tinsert(chunks, ssub(str, chunk_start, found - 1))
            return tconcat(chunks), found + 1
        elseif b == BYTE_BACKSLASH then
            -- grab the plain text before the escape
            tinsert(chunks, ssub(str, chunk_start, found - 1))
            -- look at the escaped character
            local esc_char = ssub(str, found + 1, found + 1)
            if escape_characters[esc_char] then
                tinsert(chunks, escape_characters[esc_char])
            elseif esc_char == 'u' then
                -- FUCK unicode bro
                error("Unicode not supported ok...?")
            else
                error("you're full of shit that isnt REAL! " .. esc_char)
            end
            pos = found + 2
            chunk_start = pos
        end
    end
    error("End of file without closing quote")
end

local function skip_whitespace(str, position)
    local next_pos = sfind(str, "[^ \t\r\n]", position)
    return next_pos or (#str + 1)
end

-- forward declare so parse_object and parse_array can see it
local parse_value

local function parse_object(str, position)
    --recursion recursion recursion recursion
    local obj = {}
    position = position + 1
    while true do
        position = skip_whitespace(str, position)
        if sbyte(str, position) == BYTE_RBRACE then
            return obj, position + 1 -- empty
        end
        -- get key (has to be string)
        local key
        key, position = parse_string(str, position)
        position = skip_whitespace(str, position)
        -- skip over colon
        if sbyte(str, position) ~= BYTE_COLON then error("Expected ':") end
        position = position + 1

        -- now we get the value burrp
        local value
        value, position = parse_value(str, position)

        -- store on that thang
        obj[key] = value

        --lets see if it sa comma or we gotta end it here
        position = skip_whitespace(str, position)
        local b = sbyte(str, position)
        if b == BYTE_RBRACE then
            return obj, position + 1
        elseif b == BYTE_COMMA then
            position = position + 1 -- skip it and thus the snake eats itself once more
        else
            error("You ruined it. (expected , or })")
        end
    end
end

local function parse_array(str, position)
    local arr = {}
    local index = 1         -- starts at one because lua does
    position = position + 1 -- skip past the opening '['
    while true do
        position = skip_whitespace(str, position)

        -- is it empty?
        if sbyte(str, position) == BYTE_RBRACKET then
            return arr, position + 1
        end
        local value
        value, position = parse_value(str, position)

        arr[index] = value
        index = index + 1
        position = skip_whitespace(str, position)
        local b = sbyte(str, position)
        if b == BYTE_RBRACKET then
            return arr, position + 1
        elseif b == BYTE_COMMA then
            position = position + 1
        else
            error("expected a fucjing , or ] in array at position " .. position)
        end
    end
end

local function parse_number(str, position)
    -- search for first character that isnt a number
    local end_pos = sfind(str, "[^%d%.%-+eE]", position)
    -- if nil, we go to the end of the piece of text
    end_pos = end_pos or (#str + 1)
    -- get the string that represents the 'number'
    local num_str = ssub(str, position, end_pos - 1)

    local number = tonumber(num_str)
    if not number then
        error("invalid number " .. position .. ": " .. num_str)
    end
    return number, end_pos
end

parse_value = function(str, position)
    position = skip_whitespace(str, position)

    -- report progress (throttled to 1% increments)
    maybe_report_progress(position)

    local b = sbyte(str, position)
    if b == BYTE_LBRACE then
        return parse_object(str, position) -- objects
    elseif b == BYTE_LBRACKET then
        return parse_array(str, position)  -- array
    elseif b == BYTE_QUOTE then
        return parse_string(str, position) -- strings
    elseif (b >= BYTE_0 and b <= BYTE_9) or b == BYTE_MINUS then
        return parse_number(str, position) -- numbers
    elseif b == BYTE_t and ssub(str, position, position + 3) == "true" then
        return true, position + 4
    elseif b == BYTE_f and ssub(str, position, position + 4) == "false" then
        return false, position + 5
    elseif b == BYTE_n and ssub(str, position, position + 3) == "null" then
        return nil, position + 4
    else
        error("Invalid JSON Data at position " .. position)
    end
end

-- heres my encodeer type shit haha
-- needed to write the legendaries cache

local encode_value -- forward declare

local function encode_string(s)
    -- escape special characters
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    s = s:gsub('\b', '\\b')
    s = s:gsub('\f', '\\f')
    return '"' .. s .. '"'
end

local function is_array(t)
    -- check if a table is an array (sequential integer keys starting at 1)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count == #t
end

encode_value = function(val)
    local t = type(val)
    if val == nil then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return encode_string(val)
    elseif t == "table" then
        local parts = {}
        if is_array(val) then
            for i = 1, #val do
                tinsert(parts, encode_value(val[i]))
            end
            return "[" .. tconcat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                tinsert(parts, encode_string(tostring(k)) .. ":" .. encode_value(v))
            end
            return "{" .. tconcat(parts, ",") .. "}"
        end
    else
        error("Cannot encode type: " .. t)
    end
end

-- functons related to legendaries

local function has_value(array, target)
    if not array then return false end
    for _, value in ipairs(array) do
        if value == target then return true end
    end
    return false
end

local function get_random_legendary_creature(parsed_json)
    local legendaries = {}

    -- mtgjson usually puts everything in a 'data' object at the root
    local cards = parsed_json.data or parsed_json

    for _, versions in pairs(cards) do
        -- we just look at the first version of the card
        local card = versions[1]

        if card then
            -- check if its a legendary creature
            local is_legendary = has_value(card.supertypes, "Legendary")
            local is_creature = has_value(card.types, "Creature")

            if is_legendary and is_creature then
                tinsert(legendaries, card)
            end
        end
    end

    -- if none found then something is super wrong
    if #legendaries == 0 then
        error("couldnt find any legendaries... you sure this is the right json?")
    end

    -- gotta seed the random or it'll be the same guy every time
    math.randomseed(os.time())
    local random_index = math.random(1, #legendaries)

    return legendaries[random_index]
end

-- expose this bad boy to the world
return {
    parse = function(str, on_progress)
        -- set up progress tracking
        progress_callback = on_progress
        progress_total = #str
        progress_last_pct = -1

        local result, _ = parse_value(str, 1)

        -- clean up
        progress_callback = nil
        progress_total = 0
        progress_last_pct = -1

        return result
    end,
    encode = encode_value,
    get_random_legendary_creature = get_random_legendary_creature
}
