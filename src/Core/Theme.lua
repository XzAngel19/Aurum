-- src/Core/Theme.lua | Aurum
-- Paleta, acentos y helpers de theming
-- Extraído del bundle para desarrollo modular; Aurum.lua lo incluye inline

local Theme = {}

Theme.ACCENTS = {
    { "Aurum",   Color3.fromRGB(232, 196, 66) },
    { "Crimson", Color3.fromRGB(222, 72, 72) },
    { "Arctic",  Color3.fromRGB(88, 190, 236) },
    { "Emerald", Color3.fromRGB(78, 204, 122) },
    { "Violet",  Color3.fromRGB(172, 112, 240) },
    { "Mono",    Color3.fromRGB(205, 205, 205) },
}

Theme.THEME = {
    Background = Color3.fromRGB(11, 11, 11),
    Panel      = Color3.fromRGB(17, 17, 17),
    Element    = Color3.fromRGB(26, 26, 26),
    Text       = Color3.fromRGB(232, 232, 232),
    TextDim    = Color3.fromRGB(122, 122, 122),
    Font       = Enum.Font.Code,
    Accent     = Theme.ACCENTS[1][2],
}
Theme.THEME.AccentDim = Theme.THEME.Accent:Lerp(Theme.THEME.Background, 0.55)

Theme.Themed = {}
Theme.Refreshers = {}
Theme.Glows = {}

function Theme.accent(inst, prop, dim)
    inst[prop] = dim and Theme.THEME.AccentDim or Theme.THEME.Accent
    table.insert(Theme.Themed, { inst, prop, dim })
    return inst
end

function Theme.setAccent(color)
    Theme.THEME.Accent = color
    Theme.THEME.AccentDim = color:Lerp(Theme.THEME.Background, 0.55)
    for i = #Theme.Themed, 1, -1 do
        local t = Theme.Themed[i]
        if t[1].Parent == nil then table.remove(Theme.Themed, i)
        else pcall(function() t[1][t[2]] = t[3] and Theme.THEME.AccentDim or Theme.THEME.Accent end) end
    end
    for _, fn in ipairs(Theme.Refreshers) do pcall(fn) end
end

function Theme.addGlow(frame)
    Theme.accent(Instance.new("UIStroke", { Parent = frame, Color = Theme.THEME.Accent, Thickness = 1 }), "Color")
    for _, g in ipairs({ {3,0.6},{6,0.8},{10,0.9} }) do
        local layer = Instance.new("Frame")
        layer.BackgroundTransparency = 1
        layer.Size = UDim2.fromScale(1,1)
        layer.Parent = frame
        local s = Theme.accent(Instance.new("UIStroke", { Parent = layer, Color = Theme.THEME.Accent, Thickness = g[1], Transparency = g[2]}), "Color")
        table.insert(Theme.Glows, {s, g[2]})
    end
end

function Theme.setGlow(v)
    for _, g in ipairs(Theme.Glows) do g[1].Transparency = 1 - (1 - g[2]) * v end
end

return Theme
