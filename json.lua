-- Im making a json thing too!

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

local function parse_string(str, position)
    local ret = {} -- this will be better for performance. you'll see
    pos = pos + 1  -- skips over opening quote...

    while pos <= #str do
        local char = str:sub(pos, pos)
        if char == '"' then
            -- unescaped closing quote lets close the thingy now
            return table.concat(ret), pos + 1
        elseif char == '\\' then
            -- escape char look at next character
            pos = pos + 1
            local esc_char = str:sub(pos, pos)
            if escape_characters[esc_char] then
                table.insert(ret, escape_characters[esc_char])
            elseif esc_char == 'u' then
                -- FUCK unicode bro
                error("Unicode not supported ok...?")
            else
                error("you're full of shit that isnt REAL! " .. esc_char)
            end
        else
            table.insert(ret, char)
        end
        pos = pos + 1
    end
    error("End of file without closing quote")
end

local function skip_whitespace(str, position)
end
local function parse_object(str, position)
end
local function parse_array(str, position)
end
local function parse_number(str, position)
end

local function parse_value(str, position)
    pos = skip_whitespace(str, position)
    local char = str:sub(position, position)
    if char == '{' then
        return parse_object(str, position) -- objects
    elseif char == '[' then
        return parse_array(str, position) -- array
    elseif char == '"' then
        return parse_string(str, position) -- strings
    elseif char:match("[%d%-]") then
        return parse_number(str, position) -- numbers
    elseif str:sub(position, position + 3) == "true" then
        return true, position + 4
    elseif str:sub(position, position + 4) == "false" then
        return false, position + 5
    elseif str:sub(position, position + 3) == "null" then
        return nil, position + 4
    else
        error("Invalid JSON Data")
    end
end
