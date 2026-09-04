-- src/Modules/Aim/AimAssist.lua | Aurum
-- Lógica de Aim Assist (FOV, Team/Wall, Smoothness, Target Part, Priority)
-- Este archivo documenta el algoritmo; la implementación vive en Aurum.lua para el bundle.
-- Si trabajas modular, copia esta lógica a tu fork y requiérela desde src/main.lua

local Module = {}
Module.Name = "AimAssist"

--[[
function Module.Init(Aurum)
    local R = function(id, fb) local e=Aurum.Registry[id] if e then local ok,v=pcall(e.get) if ok then return v end end return fb end
    local findTarget = function() ... end -- ver Aurum.lua línea ~1300
    -- FOV circle: Drawing.new("Circle") si hasDrawing else Frame+UICorner
    -- RenderStepped: if R("aim.assist.enabled") then target=findTarget(); Camera.CFrame:Lerp(CFrame.new(pos, tpos), 1 - R("aim.assist.smoothness"))
end
--]]

return Module
