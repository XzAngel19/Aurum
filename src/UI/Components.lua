-- src/UI/Components.lua | Aurum
-- Section / Toggle / Slider / Dropdown / Button / Keybind
-- En el bundle Aurum.lua estas funciones están inline para no depender de require.
-- Este archivo sirve como referencia modular y para autocompletado en tu editor.

--[[

local UI = {}

function UI.Section(parent, title) ... end
function UI.Toggle(parent, text, opts) -- opts: {id, default, keybind, color, callback, menu} end
function UI.Slider(parent, text, min, max, default, opts) -- opts: {id, decimals, suffix, callback, menu} end
function UI.Dropdown(parent, text, options, default, opts) -- opts: {id, callback, menu} end
function UI.Button(parent, text, callback, opts) end
function UI.Keybind(parent, text, defaultKey, callback, opts) end
function UI.Info(parent, text) end

return UI

-- Ejemplo de uso desde un módulo custom:

local sec = Aurum.Section(Pages.Visuals.left, "Mi Sección")
Aurum.Toggle(sec, "Godmode", {
    id = "mymod.godmode",
    default = false,
    keybind = true,
    color = Color3.fromRGB(255, 80, 80),
    callback = function(v) print("godmode", v) end
})

--]]

-- placeholder para que el repo compile sin errores si alguien hace require
return {}
