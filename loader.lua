-- loader.lua | Aurum
-- Inyección rápida (executor)
-- Uso: loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/main/Aurum.lua"))()

local BASE = "https://raw.githubusercontent.com/XzAngel19/Aurum/main/Aurum.lua"

local function loadAurum()
    local ok, src = pcall(function()
        return game:HttpGet(BASE)
    end)
    if not ok or not src or #src < 100 then
        warn("[aurum] loader: no se pudo descargar Aurum.lua, intentando archivo local...")
        -- fallback: intenta leer desde archivo local si el executor tiene filesystem
        if type(readfile) == "function" and type(isfile) == "function" and isfile("Aurum/Aurum.lua") then
            src = readfile("Aurum/Aurum.lua")
        elseif isfile and isfile("Aurum.lua") then
            src = readfile("Aurum.lua")
        else
            error("[aurum] no se encontró Aurum.lua ni remoto ni local")
        end
    end
    local fn, err = loadstring(src)
    if not fn then error("[aurum] loadstring falló: "..tostring(err)) end
    return fn()
end

return loadAurum()
