-- src/Modules/Visuals/ESP.lua | Aurum
-- ESP Box (Corner/Full/3D) + HealthBar + Skeleton + Chams + Tracers
-- Documentación del algoritmo; implementación en Aurum.lua líneas ~1500-1800

local Module = {}
Module.Name = "ESP"

--[[
Estados soportados:
- Box Style: Corner (8 mini-líneas 20% del ancho), Full (4 lados), 3D (12 aristas del bounding box)
- HealthBar: barra vertical a la izquierda del box, color1 para fill, outline negro
- Skeleton: 12 joints R15 o 5 joints R6, Drawing.Line por segmento
- Chams: Highlight con FillTransparency 0.6, Adornee = Character
- Fade: alpha = 1 - (dist - FadeDistance)/(InfoDistance - FadeDistance)
- Fallback sin Drawing: Frame con UIStroke + TextLabel
--]]

return Module
