# Aurum — Framework UI + Módulos

> **Base estable, diseño terminado, funciones ahora sí funcionan.**
> Este repo convierte tu snippet original (solo diseño) en un menú **inyectable en una línea**, **modular** y con **todas las funciones del mock implementadas** (ESP, Aim, World, Player, etc.).

![aurum](https://img.shields.io/badge/aurum-v1.1-gold?style=flat-square) ![build](https://img.shields.io/badge/build-release-232323?style=flat-square) ![luau](https://img.shields.io/badge/luau-roblox-00A2FF?style=flat-square)

---

## ⚡ Inyección rápida

### Opción A — Remote (una línea)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/arena/01a06a0a-aurum/Aurum.lua"))()
```

### Opción B — Loader local
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/arena/01a06a0a-aurum/loader.lua"))()
-- o si ya tienes el repo clonado en el executor:
-- loadstring(readfile("Aurum/Aurum.lua"))()
```

### Opción C — Desde archivo (Synapse / Script-Ware / KRNL)
```lua
-- guarda Aurum.lua en Aurum/ y ejecuta:
loadstring(readfile("Aurum/Aurum.lua"))()
```

**Teclas:** `INSERT` (rebindable en Settings → Menu Key) abre/cierra menú • `END` oculta todo • Top bar tabs togglea ventanas flotantes • Header search filtra opciones.

---

## 📦 Qué cambió respecto a tu snippet

| Antes | Ahora |
|---|---|
| Solo diseño, ningún toggle hacía nada | **Todos los toggles/sliders/dropdowns tienen lógica real** |
| Un archivo monolítico de 800 líneas | **Arquitectura modular (`src/`) + bundle `Aurum.lua` listo para inyectar** |
| IDs frágiles `aim.aim_assist.enabled` autogenerados sin control | **IDs estables explícitos** (`visuals.esp.box`, `world.camera.freecam`, etc.) — configs no se rompen al reordenar UI |
| Sin API para agregar módulos | **`Aurum.RegisterModule()`** y helpers `Aurum.Section/Toggle/Slider/...`** |
| Sin ESP/Aim real | **ESP (Drawing + Highlight fallback), Aim Assist + Silent + Trigger, Crosshair, Snapline, Fullbright, Fly/Noclip, etc.** |
| Almacenamiento solo memoria | **File system (writefile/readfile) + fallback memoria + configs JSON + autoload** |

---

## 🗂️ Arquitectura

```
Aurum.lua              ← bundle inyectable (generado desde src/)
loader.lua             ← loader remoto con fallback local
src/
  Core/
    Theme.lua          ← paleta, acentos, setAccent(), glows
    Storage.lua        ← abstracción filesystem ↔ memoria
    Registry.lua       ← collect/apply, autosave, changed()
    Notify.lua         ← sistema de notificaciones
  UI/
    Factory.lua        ← create(), label(), stroke(), makeWindow(), makeDraggable()
    Components.lua     ← Section(), Toggle(), Slider(), Dropdown(), Button(), Keybind()
    Layout.lua         ← TopBar, MainWindow, Rail, Pages, Search
  Lib/
    Utils.lua          ← isAlive(), getTargetPart(), isVisible(), isOnScreen()
    Drawing.lua        ← abstracción Drawing ↔ Frame fallback
  Modules/
    Aim/
      AimAssist.lua    ← FOV, Team/Wall check, Smoothness, Target Part, Priority
      Silent.lua       ← hookmetamethod Raycast (chance, auto wall)
      Trigger.lua      ← delay + raycast bajo crosshair
    Visuals/
      ESP.lua          ← Box (Corner/Full/3D), HealthBar, Skeleton, Name/Distance/Weapon/State, Tracers, Arrows, Chams
      Crosshair.lua    ← length/thickness/gap/outline/dot/dynamic
      Snapline.lua     ← origin Bottom/Center/Top/Mouse
    World/
      Lighting.lua     ← Fullbright, Custom Ambient, Time, Brightness, Saturation
      Skybox.lua       ← Night/Space/Sunset/Clouds/Void
      Removals.lua     ← NoFog/NoShadows/NoPost/NoParticles
      Camera.lua       ← Custom FOV, Third Person, FreeCam
    Player/
      Movement.lua     ← Speed, JumpPower (loop + restore)
      Fly.lua          ← BodyVelocity + BodyGyro, WASD + Space/Ctrl
      Noclip.lua       ← Stepped CanCollide=false
      Misc.lua         ← Infinite Jump, AntiAFK (VirtualUser), Spin, AutoRespawn
    Utility/
      Windows.lua      ← toggles para PlayerList/Perf/Lua/Themes/Configs
      Streamer.lua     ← Hide Name/Avatar
  main.lua             ← bootstrap que inicializa UI y registra módulos
scripts/
  build.lua            ← concatena src/ → Aurum.lua
docs/
  ARCHITECTURE.md      ← guía profunda
  ADDING_MODULES.md    ← cómo crear tu propio módulo
examples/
  custom_module.lua    ← plantilla
```

### Flujo de arranque

```
loader.lua
  └─> Aurum.lua (bundle)
        ├─> Theme / Storage / ScreenGui
        ├─> Registry + Bindings + Notify
        ├─> UI Factory + Components → Pages + Sections (con IDs estables)
        ├─> Utils + Drawing abstraction
        ├─> Modules.Init()  (Aim/Visuals/World/Player)  ← se suscriben a RenderStepped/Heartbeat vía Registry
        ├─> Windows (Preview, Watermark, Keybinds, TargetHUD, etc.)
        ├─> Input (keybind capture + END hide)
        └─> Storage.apply(settings.json) + autoload config → Notify "loaded"
```

---

## 🧩 Funciones implementadas (todas las del mock)

### Aim
- **Aim Assist** — busca target dentro de FOV, respeta Team Check / Wall Check (Raycast), soporta Target Part (Head/Torso/Closest/Random) y Priority (Distance/Health/Crosshair), Smoothness lerp por dt, FOV circle (Drawing o Frame fallback) con color pickers.
- **Silent Aim** — hook `__namecall` Raycast/FindPartOnRay si el executor expone `hookmetamethod`; Hit Chance %, Auto Wall toggle, aviso si el executor no lo soporta.
- **Trigger Bot** — si un target está <12px del mouse, espera `Delay` ms y dispara vía `mouse1click` / `VirtualInputManager`.

### Visuals
- **ESP** — Box estilos Corner/Full/3D, Health Bar (2 colores), Skeleton (R15/R6 joints), Name/Distance/Weapon/State, Tracers, Off-screen Arrows, Chams (Highlight). Fading por distancia (`Fade Distance` + `Info Distance`), `Min Health` filter, `Text Size`/`Font` (mapeado a Drawing.Font), `Local Player` toggle, `Filter` dropdown. Usa **Drawing** si existe, fallback a **Frame + UIStroke** si no.
- **Crosshair** — 4 líneas + dot central, outline, gap/length/thickness, dynamic (se expande con MoveDirection).
- **Snapline** — línea desde Bottom/Center/Top/Mouse al target más cercano, thickness + outline.

### World
- **Lighting** — Fullbright (Ambient 1,1,1 + Brightness 3 + FogEnd 1e5), Custom Ambient (color picker), Time of Day, Brightness, Saturation (ColorCorrectionEffect).
- **Skybox** — Night/Space/Sunset/Clouds/Void (Sky instance, 6 caras).
- **Removals** — No Fog (FogEnd 1e5), No Shadows (GlobalShadows false), No Post Effects (Bloom/DoF/SunRays disabled), No Particles (ParticleEmitter/Trail disabled).
- **Camera** — Custom FOV, Third Person (CameraMode Classic, Min/MaxZoom), Free Cam (CameraType Scriptable + WASD + Space/Ctrl + mouse delta).

### Player
- **Movement** — Speed (WalkSpeed loop), Jump Power, Fly (BodyVelocity + BodyGyro, respeta Fly Speed), Noclip (Stepped CanCollide false).
- **Misc** — Infinite Jump (JumpRequest), Anti AFK (VirtualUser:CaptureController), Spin (CFrame.Angles por Heartbeat, Spin Speed), Auto Respawn.
- **Streamer** — Hide Name/Avatar (desactiva BillboardGui).

### Utility
- Quick Actions (Test Notification, Copy JobId, Rejoin via TeleportService), Server info, PlayerList/Perf/Lua/Themes/Configs windows (toggle desde Utility → Windows), Themes (6 acentos), Configs (Save/Load/Overwrite/Delete/Refresh/Set Autoload con JSON).

### Settings
- Accent, UI Scale (UIScale + fitAll), Glow, Background Blur (BlurEffect.Size), Dim Screen, Notifications, Overlays toggles (Watermark/Keybinds/Target/Preview + FPS/Ping/Time), Auto-save Settings, Save/Load/Reset, Unload.

---

## 🔧 Agregar un módulo

### Mínimo (1 archivo)

```lua
-- examples/custom_module.lua
local Mod = {}
Mod.Name = "MyCoolMod"

function Mod.Init(Aurum)
    -- Accedé a páginas ya creadas:
    local Pages = Aurum.GetPages() -- {Aim={left,right,frame}, Visuals, ...}
    local sec = Aurum.Section(Pages.Utility.left, "My Cool Mod")

    local enabled = false
    Aurum.Toggle(sec, "Enabled", {
        id = "mycool.enabled",
        default = false,
        keybind = true,
        color = Color3.fromRGB(255, 100, 100),
        callback = function(v)
            enabled = v
            Aurum.Notify("mycool", v and "activado" or "desactivado", 2)
        end
    })

    Aurum.Slider(sec, "Power", 0, 100, 50, {
        id = "mycool.power",
        suffix = "%",
        callback = function(v) print("power", v) end
    })

    -- loop propio:
    game:GetService("RunService").Heartbeat:Connect(function()
        if not enabled then return end
        -- tu lógica...
    end)
end

return Mod
```

### Registrarlo en runtime (sin tocar el repo)

```lua
local Aurum = getgenv().Aurum -- después de inyectar
local MyMod = loadstring(game:HttpGet("https://raw.githubusercontent.com/tu/repo/main/examples/custom_module.lua"))()
Aurum.RegisterModule(MyMod)
-- ya aparece en Utility y persiste en configs via su id "mycool.*"
```

### Registrarlo en build-time (dentro del repo)

1. Poné tu archivo en `src/Modules/Utility/MyCoolMod.lua`
2. Agregalo a `src/Modules/init.lua` o requirílo en `src/main.lua`:
   ```lua
   local MyCoolMod = require(path.to.MyCoolMod)
   Aurum.RegisterModule(MyCoolMod)
   ```
3. Ejecutá `lua scripts/build.lua` → regenera `Aurum.lua`
4. Pusheá y el loader ya sirve la nueva versión.

Ver `docs/ADDING_MODULES.md` para detalles de Registry, configs y keybinds.

---

## 💾 Configs & Settings

- `Aurum/settings.json` — guarda **solo** opciones con `menu=true` (Settings + toggles de Overlay). Auto-save cada 1s si `Auto-save Settings` está activo.
- `Aurum/configs/<nombre>.json` — guarda **todo** menos `menu=true` (game features). Se crean desde la ventana **Configs** (Save/Load/Overwrite/Delete/Refresh/Set Autoload).
- `Aurum/autoload.txt` — nombre de config que se carga al iniciar.

IDs estables → renombrar texto de un toggle no rompe configs viejas (mientras el `id` no cambie).

---

## 🛠️ Desarrollo local

```bash
git clone https://github.com/XzAngel19/Aurum
cd Aurum

# editar src/...
# regenerar bundle
lua scripts/build.lua   # o: python scripts/build.py
# probar en Studio: pega Aurum.lua en un LocalScript con "LoadStringEnabled" o inyecta con tu executor

# estructura de ramas:
# main  ← estable
# arena/* ← feature branches (esta sesión)
```

---

## 🛡️ Compatibilidad

- **Executors:** Synapse X, Script-Ware, KRNL, Fluxus, Delta, Hydrogen, etc. Detecta `Drawing`, `hookmetamethod`, `gethui`, `identifyexecutor` y hace fallback a `Frame`/`Highlight` si no están.
- **Juegos:** genérico. No asume armas ni anti-cheats específicos. Los hooks son `pcall`ed; si un juego protege `WalkSpeed` o `Raycast`, la feature se desactiva gracefully con Notify.
- **Studio:** funciona sin executor (usa PlayerGui fallback, no file system, sin Drawing/hook).

---

## 📜 Licencia

MIT — podés forkar, rebrandear y vender, pero mantené el crédito `aurum`.

---

Hecho con Aurum — `v1.1` `release`.
