-- src/Lib/Drawing.lua | Aurum
-- Abstracción Drawing (exploit) ↔ Frame fallback
-- Uso: local Draw = require(path.Drawing); Draw.Circle(...)

local DrawingLib = {}
DrawingLib.hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"

-- Crea un círculo FOV (retorna {circle, outline} con API .Visible .Position .Radius .Color)
function DrawingLib.createFOVCircle(parentGui, strokeColor)
    if DrawingLib.hasDrawing then
        local c = Drawing.new("Circle")
        c.Thickness = 1; c.NumSides = 64; c.Filled = false; c.Transparency = 1; c.Color = strokeColor
        local o = Drawing.new("Circle")
        o.Thickness = 3; o.NumSides = 64; o.Filled = false; o.Transparency = 0.35; o.Color = Color3.new(0,0,0)
        return { circle = c, outline = o, isDrawing = true }
    else
        local UIScale = parentGui:FindFirstChildOfClass("UIScale")
        local function mk(z)
            local f = Instance.new("Frame")
            f.BackgroundTransparency = 1; f.AnchorPoint = Vector2.new(0.5,0.5); f.Size = UDim2.fromOffset(100,100)
            f.ZIndex = z; f.Visible = false; f.Parent = parentGui
            Instance.new("UICorner", { CornerRadius = UDim.new(1,0), Parent = f })
            Instance.new("UIStroke", { Parent = f, Color = z==9999 and strokeColor or Color3.new(0,0,0), Thickness = z==9999 and 1 or 3, Transparency = z==9999 and 0 or 0.4 })
            return f
        end
        return { circle = mk(9999), outline = mk(9998), isDrawing = false }
    end
end

-- Crea un set de líneas para ESP Box (8 líneas + outline)
function DrawingLib.createESPSet()
    if DrawingLib.hasDrawing then
        local set = { isDrawing = true, boxLines = {}, boxOutlines = {} }
        for i=1,8 do local l=Drawing.new("Line") l.Visible=false l.Thickness=1.5 l.Color=Color3.fromRGB(235,235,235) table.insert(set.boxLines,l) end
        for i=1,8 do local l=Drawing.new("Line") l.Visible=false l.Thickness=3 l.Color=Color3.new(0,0,0) l.Transparency=0.5 table.insert(set.boxOutlines,l) end
        set.healthBar = Drawing.new("Line"); set.healthBar.Visible=false; set.healthBar.Thickness=3
        set.healthOutline = Drawing.new("Line"); set.healthOutline.Visible=false; set.healthOutline.Thickness=5; set.healthOutline.Color=Color3.new(0,0,0)
        set.nameText = Drawing.new("Text"); set.nameText.Visible=false; set.nameText.Center=true; set.nameText.Outline=true
        set.distText = Drawing.new("Text"); set.distText.Visible=false; set.distText.Center=true; set.distText.Outline=true
        set.tracer = Drawing.new("Line"); set.tracer.Visible=false
        set.skeletonLines = {}
        for i=1,12 do local l=Drawing.new("Line") l.Visible=false l.Thickness=1.5 table.insert(set.skeletonLines,l) end
        return set
    end
    return nil
end

return DrawingLib
