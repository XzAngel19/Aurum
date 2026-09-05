# Aurum → Vape V4 Level — Roadmap

Tu feedback: "se ve mas como un external, con funciones muy simples pero yo quisiera que sea como VapeV4 que sea asi de bueno en todas las maneras."
Este doc es el brief perfecto para pasarle a un modelo más potente (Claude 4.5 Opus, GPT-5, Gemini 2.5 Pro) y que lo ejecute sin perder tu diseño Aurum.

---

## 1) Qué le falta para ser Vape V4

### Vape es 3 cosas a la vez:
- **Legit** (parece que no cheateas): aim assist suave, autoclicker con randomización, reach sutil, anti-cheat bypass.
- **Blatant** (si quieres reventar): Scaffold, Fly, Speed, LongJump, Phase, Blink — todo con bypass por juego.
- **Utility/Visuals premium**: ArrayList, Watermark minimal, TargetHUD con animación, Text GUI ordenable, Profiles con cloud, Search que también busca keybinds.

Aurum hoy es **universal-genérico** (funciona en cualquier juego pero sin exploits específicos). Vape es **universal + per-game modules** (detecta el PlaceId y carga un pack: BedWars, Arsenal, Da Hood, etc.)

---

## 2) Ideas para pedirle al próximo modelo

Copia/pega este prompt al modelo potente:

```
Eres el lead de Aurum, un cheat universal inspirado en Vape V4 pero con identidad Aurum (gold #E8C442, dark #0B0B0B, Code font, glow sutil).
Tu rama es arena/01a06a0a-aurum. Tu base es Aurum.lua (2610 líneas, arquitectura Registry+ModuleManager v2).

OBJETIVO: Llevar Aurum de "external simple" a "Vape V4 killer" sin romper su diseño.

PRIORIDAD 1 — Combat Legit (lo que más vende Vape):
- AimAssist mejorado: Curve smoothing (no linear Lerp), FOV dinámico que se cierra al disparar, Auto-adjust por ping, Visible check con Whitelist.
- SilentAim per-game: si PlaceId == 6872265039 (BedWars) hookea Remotes específicos (SwordHit, BowHit), si no usa Raycast genérico. HitChance con curva normal, no uniforme.
- AutoClicker: 8-14 CPS con random jitter, BreakBlocks, Inventory check, solo cuando mouse está presionado y target no es nil.
- Reach: 3-6 studs, solo en air, con raycast extendido + AntiCheat check (no atraviesa paredes si WallCheck).
- Velocity: 100% -> 0% slider, con modos JumpReset, Matrix, Hypixel, Vulcan. Test en 3 anticheats.
- Criticals: packet mode.

PRIORIDAD 2 — Blatant (para highlights):
- Scaffold: Expand 1-6, Tower, Safewalk, AutoSprint break, Rotation spoof.
- Speed: WatchDog, Vulcan, Verus, Matrix — cada uno con timer + strafe.
- Fly: Verus, Vulcan, WatchDog, Creative. Auto-disable al tocar suelo si el server es strict.
- LongJump, HighJump, Step, NoFall, Blink.

PRIORIDAD 3 — Visuals Vape-level:
- ArrayList: lista derecha ordenada por longitud, animación slide, hide cuando menú abierto, custom font.
- Watermark: "aurum v1.1 | user | 144 fps | 42ms | 14:32" con blur + gold line, draggable.
- TargetHUD: 3 estilos (Aurum, Vape, Exhibition), health bar con animación lerp, muestra armor, ping, distance.
- ESP: modo Vape (box con esquinas + health number + distance + offscreen arrow con triángulo), Chams con material (ForceField, Neon) y through walls.
- World: Fullbright con Time 12h + Exposure 1.5, Ambience con Color3 lerpeado, Custom FOV con Hand FOV.
- SelfDestruct / Panic: tecla que unload + borra traces.

PRIORIDAD 4 — Sistema:
- Profiles: Save/Load/Delete/Rename + Cloud (opcional: usa GitHub Gist API si el executor permite http).
- Text GUI: search, keybind list, targethud, arraylist todo con la misma Theme API.
- Configs por juego: Aurum/configs/BedWars.json, Aurum/configs/Universal.json + AutoLoad por PlaceId.
- ModuleManager v2 ya está: usa Aurum.Module("Combat:KillAura", {Config, OnInit}) — no toques la API, extiéndela con .OnRender, .OnTick.
- Performance: ESP con octree, no iterar todos los players cada frame si >20, usa CollectionService.

DISEÑO: No cambies el layout 640x560 + rail 100 + header/footer. Solo añade: perfiles arriba del rail, arraylist fuera del Main (derecha), y un botón "Profiles" en header. Mantén Mono/Gold, añade rounded 4px + acrylic blur opcional.

ENTREGA: Actualiza Aurum.lua (mantén IDs estables), añade src/Modules/Combat/*.lua, src/Modules/Blatant/*.lua, y actualiza README con tabla "PlaceId → Pack".
TEST: Cada módulo debe tener pcall y Notify si el juego lo bloquea. No crashear si Drawing no existe.

NO hagas: no reescribas toda la UI, no cambies la branch, no borres configs viejas.
```

---

## 3) Diseño — de Aurum oscuro a Vape minimal sin perder identidad

- **Mantener:** TopBar tabs con `/` separador, rail 01-06 con indicador gold 2px, header `aurum // build: release`, glow triple capa, Notify con bar dorada.
- **Añadir estilo Vape:**
  - **Rounded:** `UICorner 6` en Main, Windows y Sections (actual es 0). Deja el glow cuadrado por detrás para contraste.
  - **Acrylic:** `BackgroundTransparency 0.05` + `Blur 12` cuando `S.blur`, pero con `GroupTransparency` si el executor soporta `gethui()`.
  - **ArrayList:** fuera del Main, `Position 1,-10, 0,40` alineado derecha, `UIListLayout Vertical`, `TextLabel` con `TextXAlignment Right`, sorting por `TextBounds.X`.
  - **Text GUI:** ya tienes Watermark/Keybinds/Target — hazlos draggables y guardables ( `Watermark.Position` en settings).
  - **Profiles bar:** arriba del rail, 20px alto, con `Profile: Default ▼` + `+` button. Guarda en `Aurum/profiles/`.

---

## 4) Qué pedirle exactamente al modelo potente (checklist rápido)

- [ ] Scaffold + Speed + Fly con bypass por anticheat (elige 2 anticheats para testear)
- [ ] KillAura / AimAssist con raycast + rotation spoof + legit curve
- [ ] AutoClicker con jitter + Reach
- [ ] ArrayList + Watermark + TargetHUD Vape-style
- [ ] Per-game packs: detecta `game.PlaceId` y carga `src/Games/<PlaceId>.lua` si existe
- [ ] Profiles + Cloud (si no puede cloud, local con lista)
- [ ] No romper IDs estables ni el loader de tu rama

Si quieres, puedo dejar este doc listo y tú solo se lo reenvías al próximo modelo con el repo.

---

## 5) Prompt corto para el próximo modelo (si no quieres el largo)

```
Toma Aurum rama arena/01a06a0a-aurum. Hazlo nivel Vape V4: 
- Añade Combat (KillAura, SilentAim per-game, AutoClicker 8-14 CPS, Reach 3-6, Velocity con modos, Criticals)
- Añade Blatant (Scaffold Expand, Speed WatchDog/Vulcan, Fly Vulcan/Verus)
- Mejora Visuals (ArrayList derecha, TargetHUD 3 estilos, ESP Vape, Chams material)
- Sistema Profiles + per-game configs por PlaceId
- Mantén diseño Aurum dark/gold, no cambies Main 640x560, solo añade rounded+acrylic opcional
- Usa Aurum.Module DSL, mantén IDs estables, todo con pcall+fallback sin Drawing
Entrega Aurum.lua actualizado + src/Modules nuevos.
```

