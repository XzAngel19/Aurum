-- src/Core/Storage.lua | Aurum
-- Abstracción filesystem ↔ memoria para settings/configs

local Storage = {}
local NAME = "aurum"
Storage.FOLDER = NAME
Storage.hasFS = type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
    and type(isfolder)=="function" and type(makefolder)=="function" and type(listfiles)=="function"
    and type(delfile)=="function"

if Storage.hasFS then
    pcall(function()
        if not isfolder(Storage.FOLDER) then makefolder(Storage.FOLDER) end
        if not isfolder(Storage.FOLDER.."/configs") then makefolder(Storage.FOLDER.."/configs") end
    end)
end

local memStore = {}

function Storage.write(path, str)
    if Storage.hasFS then writefile(Storage.FOLDER.."/"..path, str) else memStore[path]=str end
end
function Storage.read(path)
    if Storage.hasFS then
        local p = Storage.FOLDER.."/"..path
        if isfile(p) then return readfile(p) end
        return nil
    end
    return memStore[path]
end
function Storage.delete(path)
    if Storage.hasFS then
        local p = Storage.FOLDER.."/"..path
        if isfile(p) then delfile(p) end
    else memStore[path]=nil end
end
function Storage.listConfigs()
    local names={}
    if Storage.hasFS then
        for _, f in ipairs(listfiles(Storage.FOLDER.."/configs")) do
            local n = f:match("([^/\\]+)%.json$")
            if n then table.insert(names, n) end
        end
    else
        for k in pairs(memStore) do
            local n = k:match("^configs/(.+)%.json$")
            if n then table.insert(names, n) end
        end
    end
    table.sort(names)
    return names
end

return Storage
