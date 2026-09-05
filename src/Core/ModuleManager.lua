-- src/Core/ModuleManager.lua | Aurum v1.1 - DSL declarativo (menos genérico, más eficaz)
-- Reemplaza el RegisterModule genérico por un sistema opinado por dominio.
--
-- Uso:
--   Aurum.Module("Visuals:GunChams", {
--     Config = { Enabled = false, Color = Color3.fromRGB(255,80,80) },
--     OnInit = function(self)
--       local sec = self:Section("Gun Chams")
--       self:Toggle(sec, "Enabled", "Enabled", {keybind=true, color=self.Config.Color})
--     end,
--     OnEnable = function(self) self._conn = RunService.RenderStepped:Connect(...) end,
--     OnDisable = function(self) self._conn:Disconnect() end,
--   })
--
-- Ventajas vs el sistema previo genérico:
--  1) ID auto-generado: "visuals.gunchams.enabled" (tab.modulo.key) -> no colisiones, no olvidas el id.
--  2) Auto-sección balanceada por altura (left vs right).
--  3) Config schema tipado: Config defaults se usan para Slider/Dropdown y se persisten automáticamente.
--  4) Lifecycle: OnEnable/OnDisable se llaman automáticamente cuando Enabled cambia o al autoload.
--  5) Auto-discovery: si el executor tiene filesystem, escanea Aurum/src/Modules/**/*.lua y carga sin registro manual.
--  6) Menos boilerplate: self:Toggle/Slider/Dropdown vs Aurum.Toggle(parent, text, {id=..., callback=...})

local ModuleManager = {}
ModuleManager._modules = {}
ModuleManager._order = {}

-- Esta función se define en Aurum.lua ya parcheado, aquí solo para referencia en src/.
-- Ver Aurum.lua líneas ~2100 para implementación real.

return ModuleManager
