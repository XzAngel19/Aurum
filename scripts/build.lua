-- scripts/build.lua | Aurum
-- Concatena src/ → Aurum.lua (bundle inyectable)
-- Uso: lua scripts/build.lua
-- Nota: actualmente Aurum.lua ya es el bundle pre-generado.
-- Este script es un placeholder para un build real con amalgamación.
-- Si trabajas modular (src/), implementá aquí la lógica de require inlining.

local srcFiles = {
    "src/Core/Theme.lua",
    "src/Core/Storage.lua",
    "src/Lib/Utils.lua",
    "src/Lib/Drawing.lua",
    "src/UI/Factory.lua",
    "src/UI/Components.lua",
    -- "src/Modules/Aim/AimAssist.lua",
    -- "src/Modules/Visuals/ESP.lua",
    -- etc.
}

print("[aurum] build.lua: placeholder")
print("  Aurum.lua actual es el bundle ya generado (2476 líneas, 135KB).")
print("  Para un build real, este script debería leer src/ y concatenar respetando orden.")
print("  Ejemplo de orden:")
for i, f in ipairs(srcFiles) do
    print(string.format("   %02d %s", i, f))
end
print("")
print("  Mientras tanto, si editas src/, copia manualmente los cambios a Aurum.lua")
print("  o ejecuta: cat src/Core/*.lua src/Lib/*.lua src/UI/*.lua src/Modules/**/*.lua > /tmp/combined && wc -l /tmp/combined")
