-- src/UI/Factory.lua | Aurum
-- Helpers base para construir UI (create, label, stroke, glow, draggable, window)

local Factory = {}
local Theme = require(script.Parent.Parent.Core.Theme)

function Factory.create(class, props, children)
    local inst = Instance.new(class)
    for k,v in pairs(props or {}) do inst[k]=v end
    for _,c in ipairs(children or {}) do c.Parent=inst end
    return inst
end

function Factory.label(text, color, size, parent, props)
    local l = Factory.create("TextLabel", {
        BackgroundTransparency=1, Text=text, TextColor3=color or Theme.THEME.Text,
        Font=Theme.THEME.Font, TextSize=size or 11,
        AutomaticSize=Enum.AutomaticSize.X, Size=UDim2.new(0,0,1,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=parent,
    })
    if props then for k,v in pairs(props) do l[k]=v end end
    return l
end

function Factory.stroke(parent, color, thickness, transparency)
    return Factory.create("UIStroke", { Color=color or Theme.THEME.Accent, Thickness=thickness or 1, Transparency=transparency or 0, Parent=parent })
end

return Factory
