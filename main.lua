local https = require('ssl.https')
local ltn12 = require("ltn12")
local io = require("io")
local json = require("json")
local mtgjson_url = "https://mtgjson.com/api/v5/AtomicCards.json"
local output_filename = "atomiccards.json"
local cache_filename = "legendaries_cache.json"

-- function that just grabs the size of a file
-- i use it to see if i need to redownload a file
local function get_local_size(filename)
    local file = io.open(filename, "rb")
    if not file then return 0 end
    local size = file:seek("end")
    file:close()
    return size or 0
end

-- gets the modification time of a file (returns 0 if it doesnt exist)
local function get_mod_time(filename)
    local lfs_ok, lfs = pcall(require, "lfs")
    if lfs_ok then
        local attr = lfs.attributes(filename)
        return attr and attr.modification or 0
    end
    -- fallback: use os.execute + stat
    local handle = io.popen('stat -f "%m" ' .. filename .. ' 2>/dev/null')
    if handle then
        local result = handle:read("*a")
        handle:close()
        return tonumber(result) or 0
    end
    return 0
end

-- checks if the legendaries cache is fresh (exists and is newer than atomiccards.json)
local function is_cache_valid()
    local cache_size = get_local_size(cache_filename)
    if cache_size == 0 then return false end

    local source_time = get_mod_time(output_filename)
    local cache_time = get_mod_time(cache_filename)

    return cache_time > 0 and cache_time >= source_time
end

-- fetches the total size of the file to be downloaded so progress can be displayed
local _, _, headers = https.request {
    method = "HEAD",
    url = mtgjson_url
}

local total_size = tonumber(headers["content-length"]) or 0
local downloaded_size = 0
local file
local function progress_sink(chunk, err)
    if chunk then
        downloaded_size = downloaded_size + #chunk
        if total_size > 0 then
            local percent = (downloaded_size / total_size) * 100
            io.write(string.format("\rFetching JSON... %.1f%% (%d / %d bytes)", percent, downloaded_size, total_size))
            io.flush()
        else
            io.write(string.format("\rDownloaded %d bytes of mtgjson", downloaded_size))
            io.flush()
        end
        file:write(chunk)
        return 1
    end
    return nil, err
end
-- little check just to be sure
if total_size == 0 then
    print("Server did not provide content length, cant show progress :(")
end

local local_size = get_local_size(output_filename)
local need_download = true

if local_size > 0 and local_size == total_size then
    print("sizes are identical, skipping download")
    need_download = false
end

if need_download then
    print("downloading MTGJson to fetch cards.. please wait..")
    file = io.open(output_filename, "w") -- only writing if we're downloading
    if not file then
        error("Couldnt open " .. output_filename .. " for writing!")
    end
    local success, code, response, status = https.request {
        url = mtgjson_url,
        sink = progress_sink
    }
    if file then file:close() end
    print("\nDownload finished!")
end
-- now the fun part: get a commander


local commander = nil

if is_cache_valid() then
    -- cache hit! load the small file instead of parsing 127MB
    print("Loading from cache... (skipping big parse)")
    local cache_file = io.open(cache_filename, "r")
    if cache_file then
        local cache_content = cache_file:read("*a")
        cache_file:close()
        local legendaries = json.parse(cache_content)
        if legendaries and #legendaries > 0 then
            math.randomseed(os.time())
            commander = legendaries[math.random(1, #legendaries)]
        end
    end
end

if not commander then
    -- cache miss: parse the big json, extract legendaries, and save the cache
    local read_file = io.open(output_filename, "r")
    if not read_file then
        print("\nCouldn't open the JSON file to parse it!")
        return
    end

    print("\nReading JSON database... this might take a second...")
    local content = read_file:read("*a")
    read_file:close()

    print("Parsing JSON...")
    local parsed_data = json.parse(content, function(pos, total, pct)
        io.write(string.format("\rParsing JSON... %d%% (%d / %d bytes)", pct, pos, total))
        io.flush()
    end)
    print("\rParsing JSON... done!                              ")

    print("Finding a commander...")
    commander = json.get_random_legendary_creature(parsed_data)

    -- save the legendaries cache so next time is instant
    print("Saving legendaries cache for next time...")
    -- re-extract all legendaries for the cache
    local legendaries = {}
    local cards = parsed_data.data or parsed_data
    for _, versions in pairs(cards) do
        local card = versions[1]
        if card then
            local function has_value(arr, target)
                if not arr then return false end
                for _, v in ipairs(arr) do
                    if v == target then return true end
                end
                return false
            end
            if has_value(card.supertypes, "Legendary") and has_value(card.types, "Creature") then
                table.insert(legendaries, card)
            end
        end
    end

    local cache_file = io.open(cache_filename, "w")
    if cache_file then
        cache_file:write(json.encode(legendaries))
        cache_file:close()
        print("Cached " .. #legendaries .. " legendary creatures!")
    end
end

-- display the commander
if commander then
    print("\n==============================================")
    print("YOUR RANDOMLY GENERATED COMMANDER IS:")
    print("==============================================")
    print("Name: " .. (commander.name or "N/A"))
    print("Mana Cost: " .. (commander.manaCost or "N/A"))
    print("Type: " .. (commander.type or "N/A"))

    -- printing everything in a pretty way
    if commander.text then
        print("\nEffects:")
        print("--------------------")
        print(commander.text)
        print("--------------------")
    end

    -- the flavor text! yay
    if commander.flavorText then
        print("\nFlavor Text:")
        print("*" .. commander.flavorText .. "*")
    end

    -- giving a scryfall link for more info
    if commander.identifiers and commander.identifiers.scryfallId then
        print("\nScryfall Link: https://scryfall.com/card/" .. commander.identifiers.scryfallId)
    end
    print("==============================================")
else
    print("\nSomething went wrong, couldn't find a commander!")
end
