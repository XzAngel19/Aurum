-- examples/custom_module.lua | Aurum
-- Plantilla para crear tu propio módulo sin tocar el core
-- Uso runtime:
--   local Mod = loadstring(game:HttpGet("URL/a/este/archivo"))()
--   getgenv().Aurum.RegisterModule(Mod)
-- Uso build-time:
--   copia a src/Modules/Utility/MiModulo.lua y requiérelo en src/main.lua

local Mod = {}
Mod.Name = "ExampleMod" -- cambia esto, debe ser único

function Mod.Init(Aurum)
    -- Aurum.* está disponible aquí (UI, Registry, Notify, etc.)
    local Pages = Aurum.GetPages() -- Aim/Visuals/World/Player/Utility/Settings
    local sec = Aurum.Section(Pages.Utility.left, "Example Mod")

    -- Estado local del módulo (no uses variables globales)
    local enabled = false
    local power = 50

    -- Toggle con keybind + color picker
    Aurum.Toggle(sec, "Enabled", {
        id = "example.enabled", -- ID estable para configs (no lo cambies después de publicar)
        default = false,
        keybind = true,
        color = Color3.fromRGB(172, 112, 240), -- color inicial del picker
        callback = function(v)
            enabled = v
            Aurum.Notify("example", v and "activado" or "desactivado", 2)
        end
    })

    -- Slider con sufijo y decimals
    Aurum.Slider(sec, "Power", 0, 100, 50, {
        id = "example.power",
        suffix = "%",
        decimals = 0,
        callback = function(v) power = v end
    })

    -- Dropdown
    Aurum.Dropdown(sec, "Mode", { "Safe", "Aggressive", "Legit" }, "Safe", {
        id = "example.mode",
        callback = function(v) print("[example] mode", v) end
    })

    -- Botón
    Aurum.Button(sec, "Do Something", function()
        Aurum.Notify("example", "power="..power.." mode="..Aurum.GetRegistry()["example.mode"].get(), 3)
    end)

    -- Loop del módulo (ej: cada Heartbeat)
    -- IMPORTANTE: usá Aurum.Connections o tu propia tabla para poder desconectar en Unload
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not enabled then return end
        --[[ tu lógica aquí
        -- ejemplo: hacer que el personaje brille cuando enabled
        local char = game.Players.LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Material = Enum.Material.Neon
                end
            end
        end
        --]]
    end)
    table.insert(Aurum._featureConns, conn)

    -- Tip: si tu módulo crea Drawings/Highlights, guardalos y destrúilos en Unload
    -- function Mod.Unload() ... end  -- opcional si necesitas limpieza custom
end

return Mod
