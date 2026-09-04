# Agregar módulos a Aurum

## Opción 1 — Runtime (sin tocar el repo)

Ideal para compartir un módulo con amigos sin forkar.

```lua
-- 1. Inyectá Aurum
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/main/Aurum.lua"))()

-- 2. Cargá tu módulo y regístralo
local MyMod = loadstring(game:HttpGet("https://raw.githubusercontent.com/tu/repo/main/mi_mod.lua"))()
getgenv().Aurum.RegisterModule(MyMod)
```

`mi_mod.lua` debe retornar una tabla con `Name` e `Init`:

```lua
local Mod = {}
Mod.Name = "InfiniteAmmo"

function Mod.Init(Aurum)
    local Pages = Aurum.GetPages()
    local sec = Aurum.Section(Pages.Player.right, "Infinity")

    local enabled = false
    Aurum.Toggle(sec, "Infinite Ammo", {
        id = "player.infammo.enabled",  -- ID estable, único global
        default = false,
        keybind = true,
        callback = function(v) enabled = v end
    })

    game:GetService("RunService").Heartbeat:Connect(function()
        if not enabled then return end
        -- ejemplo: busca el Tool actual y recarga
        local char = game.Players.LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            local ammo = tool:FindFirstChild("Ammo")
            if ammo then ammo.Value = 999 end
        end
    end)

    Aurum.Notify("InfiniteAmmo", "módulo cargado", 3)
end

return Mod
```

**IDs:** usa `dominio.feature.propiedad` en minúsculas con puntos. Ej: `mygame.godmode.enabled`. Evitá `misc.*`.

**Keybinds:** si pasas `keybind=true`, el toggle muestra `[+]` y se bindea automáticamente. El usuario puede rebindar clickeando; se guarda en `settings.json` si `menu=true` o en `configs/*.json` si `menu=false`.

**Configs:** todo lo que registres con `Aurum.Toggle/Slider/Dropdown` se guarda automáticamente al hacer "Save" en la ventana Configs. No necesitas código extra.

---

## Opción 2 — Build-time (dentro del repo)

Para contribuir al menú oficial.

```bash
git clone https://github.com/XzAngel19/Aurum
cd Aurum
# crea tu módulo
mkdir -p src/Modules/Utility
cp examples/custom_module.lua src/Modules/Utility/MyMod.lua
# editalo

# agrega el require en src/main.lua (o crea src/Modules/init.lua)
# local MyMod = require(src.Modules.Utility.MyMod)
# table.insert(Aurum.Modules, MyMod) -- o Aurum.RegisterModule(MyMod)

# regenera el bundle
lua scripts/build.lua
# o: python scripts/build.py

git add src/ Aurum.lua
git commit -m "feat: añade MyMod"
git push origin tu-rama
```

---

## API disponible en `Aurum`

```lua
Aurum.Section(parent, title)
Aurum.Toggle(parent, text, opts)
Aurum.Slider(parent, text, min, max, default, opts)
Aurum.Dropdown(parent, text, options, default, opts)
Aurum.Button(parent, text, callback, opts)
Aurum.Keybind(parent, text, defaultKey, callback, opts)
Aurum.CreateWindow(name, pos, size, title, visible)
Aurum.Notify(title, text, duration)
Aurum.SetAccent(Color3)
Aurum.SetMenuOpen(bool)
Aurum.GetRegistry() -- tabla id -> {get,set}
Aurum.GetWindows()  -- {Main, Preview, Watermark, ...}
Aurum.GetPages()    -- {Aim={left,right,frame}, ...}
Aurum.RegisterModule(mod)
Aurum.Unload()
Aurum.Theme, Aurum.Storage, Aurum.Utils
```

---

## Consejos

- **No uses `spawn`/`wait` legacy** — usa `task.spawn`/`task.wait` y `task.delay`.
- **Siempre `pcall` exploits** — `if type(hookmetamethod)=="function" then pcall(...) end`.
- **Limpieza** — guardá conexiones en `Aurum.Connections` o `Aurum._featureConns` para que `Unload` las desconecte.
- **Performance** — no crees `Drawing` en cada frame; crea una vez y reutilizá (`hideDrawingSet`/`show`).
- **Testing** — probá sin executor (Studio) y con executor sin Drawing para validar fallbacks.
