-- loader.lua | Aurum v1.1 - Universal
-- Uso en executor: loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/arena/01a06a0a-aurum/loader.lua"))()
-- Este loader es universal (Synapse, KRNL, Fluxus, Delta, Hydrogen, Script-Ware) y hace fallback a filesystem.

local BASE = "https://raw.githubusercontent.com/XzAngel19/Aurum/arena/01a06a0a-aurum/Aurum.lua"
local FALLBACK = "https://raw.githubusercontent.com/XzAngel19/Aurum/arena/01a06a0a-aurum/Aurum.lua" -- alias

-- http universal: prueba game:HttpGet, syn.request, http_request, request, fluxus.request
local function httpGet(url)
    -- 1. game:HttpGet
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res)=="string" and #res>100 then return res end
    -- 2. syn.request / http_request / request
    local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or (getgenv and getgenv().request)
    if type(req)=="function" then
        local ok2, out = pcall(req, {Url=url, Method="GET"})
        if ok2 and out and (out.Body or out.body) then
            local body = out.Body or out.body
            if type(body)=="string" and #body>100 then return body end
        end
        -- algunos executors retornan directamente string
        if ok2 and type(out)=="string" and #out>100 then return out end
    end
    -- 3. http.request (KRNL)
    if type(http)=="table" and type(http.request)=="function" then
        local ok3, out = pcall(http.request, {Url=url, Method="GET"})
        if ok3 and out and out.Body then return out.Body end
    end
    return nil
end

local function loadAurum()
    local src = httpGet(BASE)
    if not src or #src < 100 then src = httpGet(FALLBACK) end
    if not src or #src < 100 then
        warn("[aurum] loader: remoto falló, probando filesystem local...")
        if type(readfile)=="function" and type(isfile)=="function" then
            if isfile("Aurum/Aurum.lua") then src = readfile("Aurum/Aurum.lua")
            elseif isfile("Aurum.lua") then src = readfile("Aurum.lua")
            elseif isfile("aurum/Aurum.lua") then src = readfile("aurum/Aurum.lua")
            end
        end
    end
    if not src or #src < 100 then
        error("[aurum] no se pudo cargar Aurum.lua (remoto + local fallaron). Verifica tu executor y la URL: "..BASE)
    end
    local fn, err = loadstring(src)
    if not fn then error("[aurum] loadstring falló: "..tostring(err)) end
    -- marca de origen para debugging
    if type(getgenv)=="function" then pcall(function() getgenv().AURUM_SRC = src:sub(1,64) end) end
    return fn()
end

return loadAurum()
