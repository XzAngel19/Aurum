-- src/Modules/World/Lighting.lua | Aurum
-- Fullbright, Custom Ambient, Time, Brightness, Saturation, Skybox, Removals, Camera
-- Implementación en Aurum.lua líneas ~1900+

local Module = {}
Module.Name = "World"

--[[
Fullbright: Ambient 1,1,1 + Brightness 3 + FogEnd 1e5 + GlobalShadows false
Custom Ambient: Color3.fromHex(id .. ".color1")
Saturation: ColorCorrectionEffect.Saturation
Skybox: Lighting.Sky con 6 caras por preset
Removals: loops cada 1s desactivando Fog/Shadows/PostEffects/Particles
Camera: Custom FOV (Camera.FieldOfView), ThirdPerson (CameraMinZoomDistance), FreeCam (CameraType Scriptable)
--]]

return Module
