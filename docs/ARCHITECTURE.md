# Aurum — Arquitectura

Este documento explica cómo está organizado Aurum para que puedas **agregar módulos sin romper el bundle** y entender por qué el menú es estable.

---

## Principios

1. **UI es solo UI** — los toggles/sliders no contienen lógica de juego; solo escriben en `Registry`.
2. **Módulos escuchan Registry** — cada feature (Aim, ESP, Fly) lee `R("id", fallback)` en cada `RenderStepped`/`Heartbeat`. Así, configs y settings cambian el comportamiento sin reiniciar.
3. **IDs estables** — todo control tiene `id` explícito (`aim.assist.fov`). Cambiar el texto visible no rompe `settings.json` ni `configs/*.json`.
4. **Fallbacks graceful** — si `Drawing` o `hookmetamethod` no existen, el código usa `Frame`/`Highlight` o muestra `Notify` y sigue funcionando.
5. **Bundle = src/** — `Aurum.lua` es un archivo generado (ver `scripts/build.lua`). Editá en `src/` y regenerá.

---

## Capas

```
┌─────────────────────────────────────────┐
│  ScreenGui + TopBar + MainWindow        │  ← UI/Layout
│  Pages (Aim/Visuals/World/Player/...)  │
│  Sections → Toggles/Sliders/Dropdowns  │  ← Components
├─────────────────────────────────────────┤
│  Registry (id → {get,set})              │  ← estado reactivo
│  Bindings (keybinds) + Storage          │
├─────────────────────────────────────────┤
│  Utils (isAlive, getTargetPart, etc.)  │  ← Lib
│  Drawing (Drawing ↔ Frame)              │
├─────────────────────────────────────────┤
│  Modules (Aim/Visuals/World/Player)    │  ← lógica de juego
│    └─ cada Init() bindea RenderStepped │
├─────────────────────────────────────────┤
│  Overlay Windows (Preview, Watermark...)│
└─────────────────────────────────────────┘
```

---

## Ciclo de vida

1. **Bootstrap** — `src/main.lua` (o bundle) crea `ScreenGui`, `Theme`, `Storage`, `Registry`, `Bindings`.
2. **Construcción UI** — `makeWindow` + `Section` + `Toggle/Slider/Dropdown` registran entradas en `Registry` con `menu=false` (game) o `menu=true` (settings).
3. **Init Módulos** — `Aurum.Modules.Aim.Init()` etc. se suscriben a `RunService.RenderStepped` y leen `R("id")` cada frame. No guardan estado duplicado.
4. **Input** — `UIS.InputBegan` maneja captura de keybinds (`listening`) y dispara `Bindings[].fn`.
5. **Persistencia** — `collect(true)` guarda settings; `collect(false)` guarda configs. `apply()` restaura via `Registry[id].set()`. `changed()` auto-guarda settings si `autosave`.

---

## Registry — el corazón

```lua
register("visuals.esp.box", {
    get = function() return enabled end,
    set = function(v) enabled = v; refreshUI() end,
    menu = false, -- false = config, true = settings
    name = "Box", tab = "Visuals", frame = row
})

-- leer
local v = Registry["visuals.esp.box"].get() -- o helper R("visuals.esp.box", true)

-- escribir (dispara UI + callback + autosave si menu=true)
Registry["visuals.esp.box"].set(true)
changed("visuals.esp.box")
```

**Color pickers** registran `id..".color1"` (y `.color2` para HealthBar). El toggle y su color son entradas separadas pero comparten `changed(id)` para que un `saveConfig` capture ambos.

---

## Cómo fluye un feature (ej: ESP)

```
Usuario mueve slider "Fade Distance" → Slider.set() → changed("visuals.esp.fade_distance")
    → Registry["visuals.esp.fade_distance"].get() ahora retorna 250
    → próximo RenderStepped de Visuals.Init() lee R("visuals.esp.fade_distance") == 250
    → recalcula alpha = 1 - (dist - fadeDist)/infoDist
    → actualiza Drawing.Text.Transparency
```

No hay eventos; es **polling por frame**. Es más simple y evita leaks de conexiones.

---

## Drawing vs Frame

- `hasDrawing` se detecta al inicio: `type(Drawing)=="table" and Drawing.new`.
- ESP crea `Drawing.new("Line")` / `Text` si existe, si no crea `Frame` + `TextLabel` en `ScreenGui`.
- FOV, Crosshair, Snapline, ESP comparten la misma abstracción (ver `src/Lib/Drawing.lua`).

---

## Configs vs Settings

| Aspecto | Settings (`menu=true`) | Configs (`menu=false`) |
|---|---|---|
| Qué guarda | UI preferences: accent, scale, blur, watermark, keybinds de UI | Game features: aim.fov, visuals.esp.box, player.movement.fly |
| Dónde | `Aurum/settings.json` | `Aurum/configs/<nombre>.json` |
| Cuándo | auto-save 1s después de cambiar si `autosave` | manual Save/Load en ventana Configs |
| Autoload | no | `Aurum/autoload.txt` guarda el nombre; se carga al iniciar |

---

## Agregar un módulo — checklist

- [ ] Elegí `Pages.<Tab>.left/right` o creá tu propia página con `Aurum.GetPages()` y una nueva tab en rail (copiá el loop de `MAIN_TABS`).
- [ ] Creá una `Section`: `local sec = Aurum.Section(Pages.Utility.left, "Mi Mod")`
- [ ] Agregá controles con `id` único: `Aurum.Toggle(sec, "Godmode", {id="mymod.godmode", keybind=true})`
- [ ] En `Mod.Init`, suscribite a `RunService.Heartbeat` y leé con `R("mymod.godmode")`.
- [ ] Probá en Studio sin executor (debe funcionar con fallback).
- [ ] Documentá `id`s en `docs/` y bump `VERSION` si rompés compatibilidad.
