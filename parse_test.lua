local json = require("json")

-- Use MTGJSON data
local file = io.open("atomiccards.json", "r")
if file then
    local content = file:read("*a")
    file:close()
    
    local parsed = json.parse(content)
    local commander = json.get_random_legendary_creature(parsed)
    
    print("Name: " .. (commander.name or "N/A"))
else
    print("could not open file")
end
