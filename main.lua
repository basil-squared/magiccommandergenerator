local https = require('ssl.https')
local ltn12 = require("ltn12")
local io = require("io")
local mtgjson_url = "https://mtgjson.com/api/v5/AtomicCards.json"
local output_filename = "atomiccards.json"
-- function that just grabs the size of a file
-- i use it to see if i need to redownload a file
local function get_local_size(filename)
    local file = io.open(filename, "rb")
    if not file then return 0 end
    local size = file:seek("end")
    file:close()
    return size or 0
end

-- fetches the total size of the file to be downloaded so progress can be displayed
local _, _, headers = https.request {
    method = "HEAD",
    url = mtgjson_url
}

local total_size = tonumber(headers["content-length"]) or 0
local downloaded_size = 0
file = io.open(output_filename, "w")
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
if local_size > 0 and local_size == total_size then
    print("sizes are identical, skipping download")
else
    print("downloading MTGJson to fetch cards.. please wait..")
    local success, code, response, status = https.request {
        url = mtgjson_url,
        sink = progress_sink
    }
end
-- opens the file so we dont have to do this twice
