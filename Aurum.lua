--[[
    aurum | client-side UI + framework + features
    build: release 1.1 | arquitectura modular
    RightShift (rebindable) -> open / close menu
    END                 -> hide / show entire UI
    Top bar tabs        -> toggle overlay windows
    Header search box   -> filter options across tabs
    Arquitectura:
      - Core: Theme / Storage / Registry / Bindings / Notify
      - UI  : Factory + Components + Layout
      - Lib : Utils / Drawing abstraction / Raycast
      - Modules: Aim / Visuals / World / Player / Utility
      - API : getgenv().Aurum para agregar modulos en runtime
    Inyeccion: loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Aurum/main/Aurum.lua"))()
]]

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local Lighting        = game:GetService("Lighting")
local HttpService     = game:GetService("HttpService")
local Stats           = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local Workspace       = game:GetService("Workspace")
local VirtualUser     = game:GetService("VirtualUser")
local VIM             = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local NAME, BUILD, VERSION = "aurum", "release", "1.1"

local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
local hasHookMM = type(hookmetamethod) == "function" and type(getrawmetatable) == "function" and type(checkcaller) == "function"
local executorName = "unknown"
pcall(function() if type(identifyexecutor) == "function" then executorName = identifyexecutor() end end)

--------------------------------------------------------------------
-- Theme / accent system
--------------------------------------------------------------------
local ACCENTS = {
    { "Aurum",   Color3.fromRGB(232, 196, 66) },
    { "Crimson", Color3.fromRGB(222, 72, 72) },
    { "Arctic",  Color3.fromRGB(88, 190, 236) },
    { "Emerald", Color3.fromRGB(78, 204, 122) },
    { "Violet",  Color3.fromRGB(172, 112, 240) },
    { "Mono",    Color3.fromRGB(205, 205, 205) },
}
local ACCENT_NAMES = {}
for _, a in ipairs(ACCENTS) do table.insert(ACCENT_NAMES, a[1]) end

local THEME = {
    Background = Color3.fromRGB(11, 11, 11),
    Panel      = Color3.fromRGB(17, 17, 17),
    Element    = Color3.fromRGB(26, 26, 26),
    Text       = Color3.fromRGB(232, 232, 232),
    TextDim    = Color3.fromRGB(122, 122, 122),
    Font       = Enum.Font.Code,
    Accent     = ACCENTS[1][2],
}
THEME.AccentDim = THEME.Accent:Lerp(THEME.Background, 0.55)

local Themed, Refreshers = {}, {}
local function accent(inst, prop, dim)
    inst[prop] = dim and THEME.AccentDim or THEME.Accent
    table.insert(Themed, { inst, prop, dim })
    return inst
end
local function setAccent(color)
    THEME.Accent = color
    THEME.AccentDim = color:Lerp(THEME.Background, 0.55)
    for i = #Themed, 1, -1 do
        local t = Themed[i]
        if t[1].Parent == nil then
            table.remove(Themed, i)
        else
            pcall(function() t[1][t[2]] = t[3] and THEME.AccentDim or THEME.Accent end)
        end
    end
    for _, fn in ipairs(Refreshers) do pcall(fn) end
end

--------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------
local FOLDER = NAME
local hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"
    and type(delfile) == "function"
if hasFS then
    pcall(function()
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        if not isfolder(FOLDER .. "/configs") then makefolder(FOLDER .. "/configs") end
    end)
end
local memStore = {}
local Storage = {}
function Storage.write(path, str)
    if hasFS then writefile(FOLDER .. "/" .. path, str) else memStore[path] = str end
end
function Storage.read(path)
    if hasFS then
        local p = FOLDER .. "/" .. path
        if isfile(p) then return readfile(p) end
        return nil
    end
    return memStore[path]
end
function Storage.delete(path)
    if hasFS then
        local p = FOLDER .. "/" .. path
        if isfile(p) then delfile(p) end
    else
        memStore[path] = nil
    end
end
function Storage.listConfigs()
    local names = {}
    if hasFS then
        for _, f in ipairs(listfiles(FOLDER .. "/configs")) do
            local n = f:match("([^/\\]+)%.json$")
            if n then table.insert(names, n) end
        end
    else
        for k in pairs(memStore) do
            local n = k:match("^configs/(.+)%.json$")
            if n then table.insert(names, n) end
        end
    end
    table.sort(names)
    return names
end

--------------------------------------------------------------------
-- ScreenGui, scale, dim, blur
--------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
    local ok = pcall(function()
        ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local UIScaleObj = Instance.new("UIScale")
UIScaleObj.Scale = 1
UIScaleObj.Parent = ScreenGui

local Dim = Instance.new("Frame")
Dim.Name = "Dim"
Dim.BackgroundColor3 = Color3.new(0, 0, 0)
Dim.BackgroundTransparency = 0.55
Dim.BorderSizePixel = 0
Dim.Size = UDim2.fromScale(1, 1)
Dim.Visible = false
Dim.ZIndex = 1
Dim.Parent = ScreenGui

local Blur = Instance.new("BlurEffect")
Blur.Name = NAME .. "_blur"
Blur.Size = 0
Blur.Parent = Lighting

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local orderCounter = 0
local function nextOrder() orderCounter += 1 return orderCounter end

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function label(text, color, size, parent, props)
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Text = text, TextColor3 = color or THEME.Text,
        Font = THEME.Font, TextSize = size or 11,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    if props then for k, v in pairs(props) do l[k] = v end end
    return l
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or THEME.Accent, Thickness = thickness or 1,
        Transparency = transparency or 0, Parent = parent,
    })
end

local Glows = {}
local function addGlow(frame)
    accent(stroke(frame, nil, 1, 0), "Color")
    for _, g in ipairs({ { 3, 0.6 }, { 6, 0.8 }, { 10, 0.9 } }) do
        local layer = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = frame })
        local s = accent(stroke(layer, nil, g[1], g[2]), "Color")
        table.insert(Glows, { s, g[2] })
    end
end
local function setGlow(v)
    for _, g in ipairs(Glows) do g[1].Transparency = 1 - (1 - g[2]) * v end
end

local Connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local Windows, WindowOrder = {}, 1

local function fitToScreen(win)
    if win.AbsoluteSize.X == 0 then return end
    local scale = UIScaleObj.Scale
    local vp = ScreenGui.AbsoluteSize / scale
    local w, h = win.AbsoluteSize.X / scale, win.AbsoluteSize.Y / scale
    if win.AutomaticSize == Enum.AutomaticSize.None and h > vp.Y - 30 then
        h = vp.Y - 30
        win.Size = UDim2.new(0, w, 0, h)
    end
    local px, py = win.AbsolutePosition.X / scale, win.AbsolutePosition.Y / scale
    win.Position = UDim2.fromOffset(
        math.clamp(px, 0, math.max(0, vp.X - w)),
        math.clamp(py, 62, math.max(62, vp.Y - h))
    )
end
local function fitAll()
    for _, w in pairs(Windows) do fitToScreen(w) end
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
        end
    end)
    bind(UIS.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = (input.Position - dragStart) / UIScaleObj.Scale
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    bind(UIS.InputEnded, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            fitToScreen(frame)
        end
    end)
end

local function makeWindow(name, position, size, title, visible)
    WindowOrder += 1
    local win = create("Frame", {
        Name = name, BackgroundColor3 = THEME.Background, BorderSizePixel = 0,
        Position = position, Size = size, Visible = visible ~= false,
        ZIndex = WindowOrder, Parent = ScreenGui,
    })
    addGlow(win)
    makeDraggable(win)
    win.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            WindowOrder += 1
            win.ZIndex = WindowOrder
        end
    end)
    local content = win
    if title then
        accent(label("//", nil, 11, win, {
            Position = UDim2.new(0, 8, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 14, 0, 20),
        }), "TextColor3")
        label(title:lower(), THEME.Text, 11, win, {
            Position = UDim2.new(0, 22, 0, 0), AutomaticSize = Enum.AutomaticSize.None,
            Size = UDim2.new(1, -44, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local x = create("TextButton", {
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "x", TextColor3 = THEME.TextDim,
            Font = THEME.Font, TextSize = 12, Size = UDim2.new(0, 18, 0, 20), Position = UDim2.new(1, -20, 0, 0), Parent = win,
        })
        x.MouseEnter:Connect(function() x.TextColor3 = THEME.Accent end)
        x.MouseLeave:Connect(function() x.TextColor3 = THEME.TextDim end)
        x.MouseButton1Click:Connect(function() win.Visible = false end)
        local line = accent(create("Frame", {
            BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 1), Parent = win,
        }), "BackgroundColor3")
        create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1),
            }), Parent = line,
        })
        content = create("Frame", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 21), Size = UDim2.new(1, 0, 1, -21), Parent = win,
        })
    end
    Windows[name] = win
    return win, content
end

--------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------
local Registry = {}
local S = { blur = true, blurAmount = 12, dim = false, notifications = true, autosave = true,
    preview = true, wmFps = true, wmPing = true, wmTime = true }
local saveSettings
local saveQueued = false

local function register(id, e) Registry[id] = e return e end
local function changed(id)
    local e = Registry[id]
    if e and e.menu and S.autosave and not saveQueued then
        saveQueued = true
        task.delay(1, function()
            saveQueued = false
            if saveSettings then saveSettings(true) end
        end)
    end
end
local function collect(menu)
    local out = {}
    for id, e in pairs(Registry) do
        if (e.menu == true) == menu then out[id] = e.get() end
    end
    return out
end
local function apply(data)
    for id, v in pairs(data) do
        local e = Registry[id]
        if e then pcall(e.set, v) end
    end
end
local function idFor(parent, text)
    return (((parent:GetAttribute("Path") or "misc") .. "." .. text):lower():gsub("%s+", "_"))
end

--------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------
local openPopup
local function closePopup()
    if openPopup then openPopup.frame.Visible = false openPopup = nil end
end
local function showPopup(frame, anchor, width, height)
    closePopup()
    local scale = UIScaleObj.Scale
    local vp = ScreenGui.AbsoluteSize / scale
    local w = width or anchor.AbsoluteSize.X / scale
    local x = anchor.AbsolutePosition.X / scale
    local y = (anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y) / scale + 2
    -- clamp to screen
    x = math.clamp(x, 4, math.max(4, vp.X - w - 4))
    y = math.clamp(y, 28, math.max(28, vp.Y - height - 4))
    frame.Position = UDim2.fromOffset(x, y)
    frame.Size = UDim2.fromOffset(w, height)
    frame.Visible = true
    openPopup = { frame = frame, anchor = anchor }
end

local PALETTE = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), Color3.fromRGB(232, 196, 66), Color3.fromRGB(230, 70, 70),
    Color3.fromRGB(235, 150, 40), Color3.fromRGB(240, 230, 80), Color3.fromRGB(80, 210, 100), Color3.fromRGB(70, 210, 220),
    Color3.fromRGB(70, 130, 240), Color3.fromRGB(170, 100, 240), Color3.fromRGB(240, 110, 190), Color3.fromRGB(140, 140, 140),
}
local palettePopup = create("Frame", {
    BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Visible = false, ZIndex = 200000, Parent = ScreenGui,
}, {
    create("UIGridLayout", { CellSize = UDim2.fromOffset(14, 14), CellPadding = UDim2.fromOffset(3, 3), FillDirectionMaxCells = 6, SortOrder = Enum.SortOrder.LayoutOrder }),
    create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
})
accent(stroke(palettePopup, nil, 1, 0.2), "Color")
local paletteFn
for i, c in ipairs(PALETTE) do
    local b = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = c, BorderSizePixel = 0, LayoutOrder = i, Parent = palettePopup })
    stroke(b, Color3.new(0, 0, 0), 1, 0.5)
    create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = b })
    b.MouseButton1Click:Connect(function()
        if paletteFn then paletteFn(c) end
        closePopup()
    end)
end
local function openPalette(anchor, fn)
    paletteFn = fn
    showPopup(palettePopup, anchor, 106, 38)
end

bind(UIS.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not openPopup then return end
    local p = UIS:GetMouseLocation()
    local function inside(g)
        local ap, as = g.AbsolutePosition, g.AbsoluteSize
        return p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
    end
    if not inside(openPopup.frame) and not inside(openPopup.anchor) then closePopup() end
end)

--------------------------------------------------------------------
-- Keybind infrastructure
--------------------------------------------------------------------
local Bindings = {}
local listening
local refreshKeybindList = function() end
local KEY_SHORT = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", CapsLock = "Caps", Insert = "Ins", Delete = "Del",
    PageUp = "PgUp", PageDown = "PgDn", Backquote = "`", Return = "Enter",
}
local function keyName(k)
    local n = KEY_SHORT[k.Name] or k.Name
    if #n > 6 then n = n:sub(1, 6) end
    return n
end
local function startListening(b)
    listening = b
    b.refresh()
end

--------------------------------------------------------------------
-- Components
--------------------------------------------------------------------
local Sections = {}

local function Section(parent, title)
    local frame = create("Frame", {
        BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = parent,
    })
    accent(stroke(frame, nil, 1, 0.35), "Color", true)
    accent(label("//", nil, 11, frame, {
        Position = UDim2.new(0, 6, 0, 3), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 14, 0, 14),
    }), "TextColor3")
    label(title:lower(), THEME.Text, 11, frame, {
        Position = UDim2.new(0, 20, 0, 3), AutomaticSize = Enum.AutomaticSize.None,
        Size = UDim2.new(1, -26, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local line = accent(create("Frame", {
        BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 19), Size = UDim2.new(1, -12, 0, 1), Parent = frame,
    }), "BackgroundColor3")
    create("UIGradient", {
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = line,
    })
    local content = create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 24), Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = frame,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
        create("UIPadding", { PaddingBottom = UDim.new(0, 8) }),
    })
    content:SetAttribute("Path", (parent:GetAttribute("Path") or "x") .. "." .. title)
    content:SetAttribute("Tab", parent:GetAttribute("Tab"))
    table.insert(Sections, { frame = frame, content = content })
    return content
end

local function Toggle(parent, text, opts)
    opts = opts or {}
    local id = opts.id or idFor(parent, text)
    local enabled = opts.default == true
    local row = create("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 16), LayoutOrder = nextOrder(), Parent = parent,
    })
    local box = create("Frame", {
        BackgroundColor3 = THEME.Background, BorderSizePixel = 0,
        Size = UDim2.fromOffset(9, 9), Position = UDim2.new(0, 2, 0.5, -5), Parent = row,
    })
    local boxStroke = stroke(box, THEME.AccentDim, 1, 0)
    local fill = accent(create("Frame", {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0), Parent = box,
    }), "BackgroundColor3")

    local rightX, binding = -2, nil
    if opts.keybind then
        local kb = create("TextButton", {
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "[+]", TextColor3 = THEME.TextDim,
            Font = THEME.Font, TextSize = 10, Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(1, -52, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
        })
        binding = { key = nil, name = text, id = id .. ".key" }
        binding.active = function() return enabled end
        binding.refresh = function()
            if listening == binding then
                kb.Text, kb.TextColor3 = "[...]", THEME.Text
            else
                kb.Text = binding.key and ("[" .. keyName(binding.key) .. "]") or "[+]"
                kb.TextColor3 = binding.key and THEME.Accent or THEME.TextDim
            end
            refreshKeybindList()
        end
        kb.MouseButton1Click:Connect(function() startListening(binding) end)
        table.insert(Bindings, binding)
        table.insert(Refreshers, binding.refresh)
        register(binding.id, {
            get = function() return binding.key and binding.key.Name or "" end,
            set = function(v)
                local ok, kc = pcall(function() return Enum.KeyCode[v] end)
                binding.key = (ok and v ~= "") and kc or nil
                binding.refresh()
            end,
            menu = opts.menu,
        })
        rightX = -56
    end
    if opts.color then
        local colors = typeof(opts.color) == "Color3" and { opts.color } or opts.color
        for i, c in ipairs(colors) do
            local sw = create("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundColor3 = c, BorderSizePixel = 0,
                Size = UDim2.fromOffset(20, 7), Position = UDim2.new(1, rightX - 20, 0.5, -3), Parent = row,
            })
            stroke(sw, Color3.new(0, 0, 0), 1, 0.4)
            sw.MouseButton1Click:Connect(function()
                openPalette(sw, function(col) sw.BackgroundColor3 = col changed(id) end)
            end)
            register(id .. ".color" .. i, {
                get = function() return sw.BackgroundColor3:ToHex() end,
                set = function(v) sw.BackgroundColor3 = Color3.fromHex(v) end,
                menu = opts.menu,
            })
            rightX -= 24
        end
    end
    local txt = label(text, THEME.TextDim, 11, row, {
        Position = UDim2.new(0, 17, 0, 0), AutomaticSize = Enum.AutomaticSize.None,
        Size = UDim2.new(1, rightX - 21, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local function refresh()
        TweenService:Create(fill, TweenInfo.new(0.12), { Size = enabled and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 0) }):Play()
        boxStroke.Color = enabled and THEME.Accent or THEME.AccentDim
        txt.TextColor3 = enabled and THEME.Text or THEME.TextDim
        if binding then refreshKeybindList() end
    end
    local entry = register(id, {
        get = function() return enabled end,
        set = function(v)
            enabled = v == true
            refresh()
            if opts.callback then task.spawn(opts.callback, enabled) end
        end,
        name = text, frame = row, menu = opts.menu, tab = parent:GetAttribute("Tab"),
    })
    row.MouseButton1Click:Connect(function() entry.set(not enabled) changed(id) end)
    if binding then binding.fn = function() entry.set(not enabled) changed(id) end end
    table.insert(Refreshers, refresh)
    refresh()
    return entry
end

local function Slider(parent, text, min, max, default, opts)
    opts = opts or {}
    local decimals, suffix = opts.decimals or 0, opts.suffix or ""
    local id = opts.id or idFor(parent, text)
    local value = default or min
    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 27), LayoutOrder = nextOrder(), Parent = parent })
    label(text, THEME.Text, 11, holder, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.65, 0, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local val = accent(label("", nil, 11, holder, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.35, -2, 0, 14),
        Position = UDim2.new(0.65, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
    }), "TextColor3")
    local bar = create("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = THEME.Background, BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 5), Position = UDim2.new(0, 2, 0, 18), Parent = holder,
    })
    accent(stroke(bar, nil, 1, 0.4), "Color", true)
    local fill = accent(create("Frame", { BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = bar }), "BackgroundColor3")
    local knob = accent(create("Frame", {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 9), Parent = bar,
    }), "BackgroundColor3")

    local function set(v)
        local m = 10 ^ decimals
        value = math.clamp(math.floor(v * m + 0.5) / m, min, max)
        local a = (value - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        val.Text = (decimals > 0 and string.format("%." .. decimals .. "f", value) or tostring(value)) .. suffix
        if opts.callback then task.spawn(opts.callback, value) end
    end
    local dragging = false
    local function fromX(x)
        set(min + math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * (max - min))
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true fromX(input.Position.X) end
    end)
    bind(UIS.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then fromX(input.Position.X) end
    end)
    bind(UIS.InputEnded, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false changed(id) end
    end)
    set(value)
    return register(id, { get = function() return value end, set = set, name = text, frame = holder, menu = opts.menu, tab = parent:GetAttribute("Tab") })
end

local function Dropdown(parent, text, options, default, opts)
    opts = opts or {}
    local id = opts.id or idFor(parent, text)
    local current = default or options[1]
    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 33), LayoutOrder = nextOrder(), Parent = parent })
    label(text, THEME.Text, 11, holder, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
    local box = create("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = THEME.Element, BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 0, 16), Parent = holder,
    })
    accent(stroke(box, nil, 1, 0.4), "Color", true)
    local curLbl = label(current, THEME.Text, 11, box, {
        Position = UDim2.new(0, 6, 0, 0), AutomaticSize = Enum.AutomaticSize.None,
        Size = UDim2.new(1, -24, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    accent(label("v", nil, 11, box, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 12, 1, 0),
        Position = UDim2.new(1, -16, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
    }), "TextColor3")
    local popup = create("Frame", {
        BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Visible = false, ZIndex = 200000, Parent = ScreenGui,
    }, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
    accent(stroke(popup, nil, 1, 0.2), "Color")

    local function set(v)
        if not table.find(options, v) then return end
        current = v
        curLbl.Text = v
        if opts.callback then task.spawn(opts.callback, v) end
    end
    for i, opt in ipairs(options) do
        local b = create("TextButton", {
            BackgroundColor3 = THEME.Element, BorderSizePixel = 0, AutoButtonColor = false,
            Text = "  " .. opt, TextColor3 = THEME.TextDim, Font = THEME.Font, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = i, Parent = popup,
        })
        b.MouseEnter:Connect(function() b.TextColor3 = THEME.Accent end)
        b.MouseLeave:Connect(function() b.TextColor3 = THEME.TextDim end)
        b.MouseButton1Click:Connect(function() set(opt) changed(id) closePopup() end)
    end
    box.MouseButton1Click:Connect(function()
        if openPopup and openPopup.frame == popup then closePopup() else showPopup(popup, box, nil, #options * 16) end
    end)
    return register(id, { get = function() return current end, set = set, name = text, frame = holder, menu = opts.menu, tab = parent:GetAttribute("Tab") })
end

local function Button(parent, text, callback, opts)
    opts = opts or {}
    local b = create("TextButton", {
        BackgroundColor3 = THEME.Element, BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, TextColor3 = THEME.Text, Font = THEME.Font, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
        Size = opts.size or UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(), Parent = parent,
    })
    local s = accent(stroke(b, nil, 1, 0.3), "Color", true)
    b.MouseEnter:Connect(function() b.TextColor3 = THEME.Accent s.Color = THEME.Accent s.Transparency = 0 end)
    b.MouseLeave:Connect(function() b.TextColor3 = THEME.Text s.Color = THEME.AccentDim s.Transparency = 0.3 end)
    if callback then b.MouseButton1Click:Connect(function() task.spawn(callback) end) end
    return b
end

local function Keybind(parent, text, defaultKey, callback, opts)
    opts = opts or {}
    local id = opts.id or idFor(parent, text)
    local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = nextOrder(), Parent = parent })
    label(text, THEME.Text, 11, row, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -60, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
    local kb = create("TextButton", {
        BackgroundTransparency = 1, AutoButtonColor = false, Text = "", TextColor3 = THEME.TextDim,
        Font = THEME.Font, TextSize = 10, Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -56, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local binding = { key = defaultKey, name = text, id = id, fn = callback, active = opts.active }
    binding.refresh = function()
        if listening == binding then
            kb.Text, kb.TextColor3 = "[...]", THEME.Text
        else
            kb.Text = binding.key and ("[" .. keyName(binding.key) .. "]") or "[none]"
            kb.TextColor3 = binding.key and THEME.Accent or THEME.TextDim
        end
        refreshKeybindList()
    end
    kb.MouseButton1Click:Connect(function() startListening(binding) end)
    table.insert(Bindings, binding)
    table.insert(Refreshers, binding.refresh)
    binding.refresh()
    register(id, {
        get = function() return binding.key and binding.key.Name or "" end,
        set = function(v)
            local ok, kc = pcall(function() return Enum.KeyCode[v] end)
            binding.key = (ok and v ~= "") and kc or nil
            binding.refresh()
        end,
        name = text, frame = row, menu = opts.menu, tab = parent:GetAttribute("Tab"),
    })
    return binding
end

local function Info(parent, text)
    return label(text, THEME.TextDim, 11, parent, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 14),
        LayoutOrder = nextOrder(), TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

--------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------
local NotifHolder = create("Frame", {
    BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -12),
    Size = UDim2.new(0, 210, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 150000, Parent = ScreenGui,
}, {
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }),
})
local function Notify(title, text, duration)
    if not S.notifications then return end
    duration = duration or 4
    local n = create("Frame", {
        BackgroundColor3 = THEME.Background, BorderSizePixel = 0, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 38), LayoutOrder = nextOrder(), Parent = NotifHolder,
    })
    local ns = accent(stroke(n, nil, 1, 1), "Color")
    accent(label("//", nil, 11, n, { Position = UDim2.new(0, 6, 0, 3), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 14, 0, 14) }), "TextColor3")
    label(title, THEME.Text, 11, n, {
        Position = UDim2.new(0, 20, 0, 3), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -66, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local timer = label("", THEME.TextDim, 10, n, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 40, 0, 14), Position = UDim2.new(1, -46, 0, 3), TextXAlignment = Enum.TextXAlignment.Right,
    })
    label(text, THEME.TextDim, 10, n, {
        Position = UDim2.new(0, 6, 0, 18), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -12, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local bar = accent(create("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), Parent = n }), "BackgroundColor3")
    TweenService:Create(n, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(ns, TweenInfo.new(0.2), { Transparency = 0.1 }):Play()
    local start, conn = os.clock(), nil
    conn = RunService.RenderStepped:Connect(function()
        local left = duration - (os.clock() - start)
        if left <= 0 or not n.Parent then
            conn:Disconnect()
            if n.Parent then n:Destroy() end
            return
        end
        timer.Text = ("%.1fs"):format(left)
        bar.Size = UDim2.new(left / duration, 0, 0, 2)
    end)
end

--------------------------------------------------------------------
-- TOP BAR
--------------------------------------------------------------------
local TopBar = create("Frame", {
    Name = "TopBar", BackgroundColor3 = THEME.Background, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 24), ZIndex = 100000, Parent = ScreenGui,
})
accent(create("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = TopBar }), "BackgroundColor3")
local TabHolder = create("Frame", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -340, 1, -1), Position = UDim2.new(0, 10, 0, 1),
    ClipsDescendants = true, Parent = TopBar,
}, {
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
accent(label(NAME, nil, 13, TabHolder, { LayoutOrder = 0 }), "TextColor3")
label("   //   ", THEME.TextDim, 12, TabHolder, { LayoutOrder = 1 })
local MenuHint = label("", THEME.TextDim, 11, TopBar, {
    AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 110, 1, -1), Position = UDim2.new(1, -320, 0, 1), TextXAlignment = Enum.TextXAlignment.Right,
})
local Clock = label("", THEME.Text, 12, TopBar, {
    AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 190, 1, -1), Position = UDim2.new(1, -200, 0, 1), TextXAlignment = Enum.TextXAlignment.Right,
})

--------------------------------------------------------------------
-- MAIN WINDOW
--------------------------------------------------------------------
local Main = makeWindow("Main", UDim2.new(0.5, -455, 0.5, -280), UDim2.new(0, 640, 0, 560))

local function updateBlur()
    local target = (ScreenGui.Enabled and Main.Visible and S.blur) and S.blurAmount or 0
    TweenService:Create(Blur, TweenInfo.new(0.25), { Size = target }):Play()
end
local function setMenuOpen(open)
    Main.Visible = open
    if Windows.Preview then Windows.Preview.Visible = open and S.preview end
    Dim.Visible = open and S.dim
    updateBlur()
    if not open then closePopup() end
    refreshKeybindList()
end

local header = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = Main })
accent(label(NAME, nil, 14, header, { Position = UDim2.new(0, 12, 0, 0) }), "TextColor3")
label("//", THEME.TextDim, 12, header, { Position = UDim2.new(0, 60, 0, 0) })
label("build: " .. BUILD, THEME.Text, 11, header, { Position = UDim2.new(0, 80, 0, 0) })
label("//", THEME.TextDim, 12, header, { Position = UDim2.new(0, 178, 0, 0) })
local headerDate = label("", THEME.Text, 11, header, { Position = UDim2.new(0, 198, 0, 0) })
local Search = create("TextBox", {
    BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Size = UDim2.new(0, 142, 0, 18), Position = UDim2.new(1, -182, 0, 5),
    Text = "", PlaceholderText = "search options...", PlaceholderColor3 = THEME.TextDim, TextColor3 = THEME.Text,
    Font = THEME.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
    TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
}, { create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }) })
accent(stroke(Search, nil, 1, 0.4), "Color", true)
local closeBtn = create("TextButton", {
    BackgroundTransparency = 1, AutoButtonColor = false, Text = "x", TextColor3 = THEME.TextDim, Font = THEME.Font, TextSize = 13,
    Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -26, 0, 3), Parent = header,
})
closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = THEME.Accent end)
closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = THEME.TextDim end)
closeBtn.MouseButton1Click:Connect(function() setMenuOpen(false) end)
local headerLine = accent(create("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 1), Parent = Main }), "BackgroundColor3")
create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0.9) }), Parent = headerLine })

local RAIL_W = 100
local rail = create("Frame", {
    BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 29), Size = UDim2.new(0, RAIL_W, 1, -50), Parent = Main,
}, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingTop = UDim.new(0, 6) }) })
accent(create("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, RAIL_W, 0, 29), Size = UDim2.new(0, 1, 1, -50), Parent = Main }), "BackgroundColor3", true)

local footer = create("Frame", { BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), Parent = Main })
accent(create("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = footer }), "BackgroundColor3", true)
local footerLeft = label("", THEME.TextDim, 10, footer, { Position = UDim2.new(0, 10, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.6, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
label(NAME .. " v" .. VERSION .. " / " .. BUILD, THEME.TextDim, 10, footer, {
    AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.4, -10, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
})

local pageHolder = create("Frame", {
    BackgroundTransparency = 1, Position = UDim2.new(0, RAIL_W + 8, 0, 35), Size = UDim2.new(1, -(RAIL_W + 14), 1, -58), Parent = Main,
})
local function makeColumn(parent, side, tab)
    local sf = create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(0.5, -3, 1, 0), Position = side == "left" and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 3, 0, 0),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2, Parent = parent,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
        create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 4) }),
    })
    accent(sf, "ScrollBarImageColor3")
    sf:SetAttribute("Path", tab)
    sf:SetAttribute("Tab", tab)
    return sf
end

local MAIN_TABS = { "Aim", "Visuals", "World", "Player", "Utility", "Settings" }
local Pages, TabButtons, currentPage = {}, {}, nil
local function selectPage(name)
    currentPage = name
    for n, page in pairs(Pages) do
        local active = n == name
        page.frame.Visible = active
        local tb = TabButtons[n]
        tb.label.TextColor3 = active and THEME.Text or THEME.TextDim
        tb.index.TextColor3 = active and THEME.Accent or THEME.TextDim
        tb.indicator.Visible = active
        tb.button.BackgroundTransparency = active and 0 or 1
    end
end
for i, name in ipairs(MAIN_TABS) do
    local btn = create("TextButton", {
        BackgroundColor3 = THEME.Element, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Parent = rail,
    })
    local ind = accent(create("Frame", { BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, 0), Visible = false, Parent = btn }), "BackgroundColor3")
    local idx = label(string.format("%02d", i), THEME.TextDim, 10, btn, { Position = UDim2.new(0, 10, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 18, 1, 0) })
    local l = label(name:lower(), THEME.TextDim, 11, btn, { Position = UDim2.new(0, 30, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -34, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
    TabButtons[name] = { button = btn, label = l, index = idx, indicator = ind }
    local frame = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pageHolder })
    Pages[name] = { frame = frame, left = makeColumn(frame, "left", name), right = makeColumn(frame, "right", name) }
    btn.MouseButton1Click:Connect(function() selectPage(name) end)
    btn.MouseEnter:Connect(function() if currentPage ~= name then l.TextColor3 = THEME.Text end end)
    btn.MouseLeave:Connect(function() if currentPage ~= name then l.TextColor3 = THEME.TextDim end end)
end
table.insert(Refreshers, function() if currentPage then selectPage(currentPage) end end)

local function applySearch(q)
    q = q:lower()
    local tabMatches = {}
    for _, e in pairs(Registry) do
        if e.frame and e.name then
            local ok = q == "" or e.name:lower():find(q, 1, true) ~= nil
            e.frame.Visible = ok
            if ok and e.tab then tabMatches[e.tab] = true end
        end
    end
    for _, s in ipairs(Sections) do
        local any = false
        for _, c in ipairs(s.content:GetChildren()) do
            if c:IsA("GuiObject") and c.Visible then any = true break end
        end
        s.frame.Visible = any
    end
    if q ~= "" and not tabMatches[currentPage] then
        for _, t in ipairs(MAIN_TABS) do
            if tabMatches[t] then selectPage(t) break end
        end
    end
end
Search:GetPropertyChangedSignal("Text"):Connect(function() applySearch(Search.Text) end)

local WHITE, BLACK = Color3.fromRGB(235, 235, 235), Color3.fromRGB(0, 0, 0)
local GREEN, ORANGE = Color3.fromRGB(80, 210, 100), Color3.fromRGB(235, 160, 40)

do -- Aim
    local P = Pages.Aim
    local a = Section(P.left, "Aim Assist")
    Toggle(a, "Enabled", { id="aim.assist.enabled", keybind=true })
    Toggle(a, "Team Check", { id="aim.assist.team_check", default=true })
    Toggle(a, "Wall Check", { id="aim.assist.wall_check", default=true })
    Toggle(a, "Show FOV", { id="aim.assist.show_fov", default=true, color=WHITE })
    Slider(a, "FOV", 10, 500, 120, { id="aim.assist.fov" })
    Slider(a, "Smoothness", 0, 1, 0.35, { id="aim.assist.smoothness", decimals=2 })
    Dropdown(a, "Target Part", { "Head", "Torso", "Closest", "Random" }, "Head", { id="aim.assist.target_part" })
    Dropdown(a, "Priority", { "Distance", "Health", "Crosshair" }, "Crosshair", { id="aim.assist.priority" })
    local s = Section(P.right, "Silent")
    Toggle(s, "Enabled", { id="aim.silent.enabled", keybind=true })
    Slider(s, "Hit Chance", 0, 100, 100, { id="aim.silent.hit_chance", suffix="%" })
    Toggle(s, "Auto Wall", { id="aim.silent.auto_wall" })
    local t = Section(P.right, "Trigger")
    Toggle(t, "Enabled", { id="aim.trigger.enabled", keybind=true })
    Slider(t, "Delay", 0, 500, 60, { id="aim.trigger.delay", suffix="ms" })
    Toggle(t, "Team Check", { id="aim.trigger.team_check", default=true })
end
do -- Visuals
    local P = Pages.Visuals
    local esp = Section(P.left, "ESP")
    Toggle(esp, "Enabled", { id="visuals.esp.enabled", default=true })
    Toggle(esp, "Box", { id="visuals.esp.box", default=true, color=WHITE, keybind=true })
    Dropdown(esp, "Box Style", { "Corner", "Full", "3D" }, "Corner", { id="visuals.esp.box_style" })
    Toggle(esp, "Health Bar", { id="visuals.esp.health_bar", default=true, color={GREEN, THEME.Accent} })
    Toggle(esp, "Skeleton", { id="visuals.esp.skeleton", default=true, color=THEME.Accent, keybind=true })
    Toggle(esp, "Name", { id="visuals.esp.name", default=true, color=WHITE })
    Toggle(esp, "Distance", { id="visuals.esp.distance", color=WHITE })
    Toggle(esp, "Weapon", { id="visuals.esp.weapon", color=WHITE })
    Toggle(esp, "State", { id="visuals.esp.state", default=true, color=WHITE })
    Toggle(esp, "Tracers", { id="visuals.esp.tracers", color=WHITE, keybind=true })
    Toggle(esp, "Off-screen Arrows", { id="visuals.esp.arrows", color=WHITE })
    Toggle(esp, "Chams", { id="visuals.esp.chams", color=THEME.Accent, keybind=true })
    local ch = Section(P.left, "Crosshair")
    Toggle(ch, "Enabled", { id="visuals.crosshair.enabled", default=true, color=ORANGE, keybind=true })
    Toggle(ch, "Outline", { id="visuals.crosshair.outline", default=true, color=BLACK })
    Slider(ch, "Length", 1, 30, 6, { id="visuals.crosshair.length" })
    Slider(ch, "Thickness", 1, 6, 1, { id="visuals.crosshair.thickness" })
    Slider(ch, "Gap", 0, 20, 3, { id="visuals.crosshair.gap" })
    Toggle(ch, "Center Dot", { id="visuals.crosshair.dot" })
    Toggle(ch, "Dynamic", { id="visuals.crosshair.dynamic" })
    local st = Section(P.right, "ESP Settings")
    Dropdown(st, "Filter", { "health", "distance", "name", "team" }, "health", { id="visuals.esp.filter" })
    Slider(st, "Min Health", 0, 100, 5, { id="visuals.esp.min_health" })
    Slider(st, "Info Distance", 0, 2000, 150, { id="visuals.esp.info_distance" })
    Slider(st, "Fade Distance", 0, 2000, 120, { id="visuals.esp.fade_distance" })
    Slider(st, "Fade Speed", 0.1, 5, 1.2, { id="visuals.esp.fade_speed", decimals=1 })
    Slider(st, "Text Size", 8, 20, 13, { id="visuals.esp.text_size" })
    Dropdown(st, "Font", { "Code", "Plex", "Monospace", "System" }, "Code", { id="visuals.esp.font" })
    Toggle(st, "Local Player", { id="visuals.esp.local_player" })
    local sn = Section(P.right, "Snapline")
    Toggle(sn, "Enabled", { id="visuals.snapline.enabled", default=true, color=ORANGE })
    Toggle(sn, "Outline", { id="visuals.snapline.outline", default=true, color=BLACK })
    Slider(sn, "Thickness", 1, 5, 1, { id="visuals.snapline.thickness" })
    Dropdown(sn, "Origin", { "Bottom", "Center", "Top", "Mouse" }, "Bottom", { id="visuals.snapline.origin" })
end
do -- World
    local P = Pages.World
    local l = Section(P.left, "Lighting")
    Toggle(l, "Fullbright", { id="world.lighting.fullbright", keybind=true })
    Toggle(l, "Custom Ambient", { id="world.lighting.custom_ambient", color=Color3.fromRGB(120, 120, 160) })
    Slider(l, "Time of Day", 0, 24, 14, { id="world.lighting.time", decimals=1 })
    Slider(l, "Brightness", 0, 10, 2, { id="world.lighting.brightness", decimals=1 })
    Slider(l, "Saturation", -1, 1, 0, { id="world.lighting.saturation", decimals=2 })
    local s = Section(P.left, "Skybox")
    Toggle(s, "Enabled", { id="world.skybox.enabled", keybind=true })
    Dropdown(s, "Skybox", { "Night", "Space", "Sunset", "Clouds", "Void" }, "Night", { id="world.skybox.skybox" })
    local r = Section(P.right, "Removals")
    Toggle(r, "No Fog", { id="world.removals.no_fog" })
    Toggle(r, "No Shadows", { id="world.removals.no_shadows" })
    Toggle(r, "No Post Effects", { id="world.removals.no_post" })
    Toggle(r, "No Particles", { id="world.removals.no_particles" })
    local c = Section(P.right, "Camera")
    Toggle(c, "Custom FOV", { id="world.camera.custom_fov" })
    Slider(c, "FOV", 30, 120, 70, { id="world.camera.fov" })
    Toggle(c, "Third Person", { id="world.camera.third_person", keybind=true })
    Toggle(c, "Free Cam", { id="world.camera.freecam", keybind=true })
end
do -- Player
    local P = Pages.Player
    local m = Section(P.left, "Movement")
    Toggle(m, "Speed", { id="player.movement.speed", keybind=true })
    Slider(m, "Speed Value", 16, 200, 32, { id="player.movement.speed_value" })
    Toggle(m, "Jump Power", { id="player.movement.jump", keybind=true })
    Slider(m, "Jump Value", 50, 300, 50, { id="player.movement.jump_value" })
    Toggle(m, "Fly", { id="player.movement.fly", keybind=true })
    Slider(m, "Fly Speed", 1, 20, 3, { id="player.movement.fly_speed" })
    Toggle(m, "Noclip", { id="player.movement.noclip", keybind=true })
    local x = Section(P.right, "Misc")
    Toggle(x, "Infinite Jump", { id="player.misc.inf_jump" })
    Toggle(x, "Anti AFK", { id="player.misc.anti_afk", default=true })
    Toggle(x, "Spin", { id="player.misc.spin", keybind=true })
    Slider(x, "Spin Speed", 1, 50, 10, { id="player.misc.spin_speed" })
    Toggle(x, "Auto Respawn", { id="player.misc.auto_respawn" })
end
do -- Utility
    local P = Pages.Utility
    local w = Section(P.left, "Windows")
    Toggle(w, "Player List", { id="ui.players", menu=true, callback=function(v) Windows.Players.Visible=v end })
    Toggle(w, "Performance", { id="ui.perf", menu=true, callback=function(v) Windows.Perf.Visible=v end })
    Toggle(w, "Lua Console", { id="ui.lua", menu=true, callback=function(v) Windows.Lua.Visible=v end })
    Toggle(w, "Themes", { id="ui.themes", menu=true, callback=function(v) Windows.Themes.Visible=v end })
    Toggle(w, "Configs", { id="ui.config", menu=true, callback=function(v) Windows.Config.Visible=v end })
    local sm = Section(P.left, "Streamer")
    Toggle(sm, "Hide Name", { id="player.streamer.hide_name" })
    Toggle(sm, "Hide Avatar", { id="player.streamer.hide_avatar" })
    local q = Section(P.right, "Quick Actions")
    Button(q, "Test Notification", function() Notify(NAME, "notification test " .. os.date("%H:%M:%S"), 4) end)
    Button(q, "Copy Job ID", function()
        if type(setclipboard) == "function" then setclipboard(game.JobId) Notify(NAME, "job id copied", 3)
        else Notify(NAME, "clipboard unavailable", 3) end
    end)
    Button(q, "Rejoin Server", function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end)
    local si = Section(P.right, "Server")
    Info(si, "place: " .. tostring(game.PlaceId))
    Info(si, "job: " .. (game.JobId ~= "" and game.JobId:sub(1, 18) .. "..." or "studio"))
    local playersInfo = Info(si, "players: -")
    task.spawn(function()
        while si.Parent do
            playersInfo.Text = ("players: %d / %d"):format(#Players:GetPlayers(), Players.MaxPlayers)
            task.wait(2)
        end
    end)
end
local MenuBinding
do -- Settings
    local P = Pages.Settings
    local menu = Section(P.left, "Menu")
    MenuBinding = Keybind(menu, "Menu Key", Enum.KeyCode.RightShift, function() setMenuOpen(not Main.Visible) end,
        { id="ui.menu_key", menu=true, active=function() return Main.Visible end })
    Dropdown(menu, "Accent", ACCENT_NAMES, "Aurum", { id="ui.accent", menu=true, callback=function(v)
        for _, a in ipairs(ACCENTS) do if a[1]==v then setAccent(a[2]) end end
    end })
    Slider(menu, "UI Scale", 0.7, 1.4, 1, { id="ui.scale", menu=true, decimals=2, callback=function(v)
        UIScaleObj.Scale=v task.defer(fitAll)
    end })
    Slider(menu, "Glow", 0, 100, 60, { id="ui.glow", menu=true, suffix="%", callback=function(v) setGlow(v/100) end })
    Toggle(menu, "Background Blur", { id="ui.blur", menu=true, default=true, callback=function(v) S.blur=v updateBlur() end })
    Slider(menu, "Blur Amount", 0, 30, 12, { id="ui.blur_amount", menu=true, callback=function(v) S.blurAmount=v updateBlur() end })
    Toggle(menu, "Dim Screen", { id="ui.dim", menu=true, callback=function(v) S.dim=v Dim.Visible=Main.Visible and v end })
    Toggle(menu, "Notifications", { id="ui.notifications", menu=true, default=true, callback=function(v) S.notifications=v end })
    local ov = Section(P.right, "Overlays")
    Toggle(ov, "Watermark", { id="ui.watermark", menu=true, default=true, callback=function(v) Windows.Watermark.Visible=v end })
    Toggle(ov, "Keybind List", { id="ui.keybinds", menu=true, default=true, callback=function(v) Windows.Keybinds.Visible=v end })
    Toggle(ov, "Target HUD", { id="ui.target", menu=true, default=true, callback=function(v) Windows.Target.Visible=v end })
    Toggle(ov, "Preview Window", { id="ui.preview", menu=true, default=true, callback=function(v) S.preview=v if Windows.Preview then Windows.Preview.Visible=Main.Visible and v end end })
    Toggle(ov, "Watermark: FPS", { id="ui.wm_fps", menu=true, default=true, callback=function(v) S.wmFps=v end })
    Toggle(ov, "Watermark: Ping", { id="ui.wm_ping", menu=true, default=true, callback=function(v) S.wmPing=v end })
    Toggle(ov, "Watermark: Time", { id="ui.wm_time", menu=true, default=true, callback=function(v) S.wmTime=v end })
    local sv = Section(P.right, "Storage")
    Info(sv, "storage: " .. (hasFS and ("file ("..FOLDER.."/)") or "memory (session only)"))
    Toggle(sv, "Auto-save Settings", { id="ui.autosave", menu=true, default=true, callback=function(v) S.autosave=v end })
    Button(sv, "Save Settings", function() saveSettings(false) end)
    Button(sv, "Load Settings", function()
        local raw = Storage.read("settings.json")
        if raw then apply(HttpService:JSONDecode(raw)) Notify(NAME,"settings loaded",3) else Notify(NAME,"no saved settings",3) end
    end)
    local DEFAULTS
    task.defer(function() DEFAULTS=collect(true) end)
    Button(sv, "Reset Settings", function() if DEFAULTS then apply(DEFAULTS) Notify(NAME,"settings reset",3) end end)
    Button(sv, "Unload " .. NAME, function()
        for _,c in ipairs(Connections) do c:Disconnect() end
        Blur:Destroy() ScreenGui:Destroy()
        if Aurum and Aurum._unload then Aurum._unload() end
    end)
end
selectPage("Visuals")

--------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------
local Utils = {}
function Utils.isAlive(plr)
    local c = plr.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end
function Utils.getTargetPart(plr, pref)
    local c = plr.Character
    if not c then return nil end
    if pref=="Head" then return c:FindFirstChild("Head") end
    if pref=="Torso" then return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart") end
    if pref=="Closest" then
        local best, bestDist = nil, math.huge
        local camPos = Camera.CFrame.Position
        for _, part in ipairs(c:GetChildren()) do
            if part:IsA("BasePart") then
                local d = (part.Position - camPos).Magnitude
                if d < bestDist then bestDist=d best=part end
            end
        end
        return best
    end
    if pref=="Random" then
        local parts={}
        for _,p in ipairs(c:GetChildren()) do if p:IsA("BasePart") then table.insert(parts,p) end end
        return parts[math.random(1,#parts)]
    end
    return c:FindFirstChild("HumanoidRootPart")
end
function Utils.isVisible(origin, targetPart)
    if not targetPart then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    params.IgnoreWater = true
    local dir = targetPart.Position - origin
    local res = Workspace:Raycast(origin, dir, params)
    if not res then return true end
    return res.Instance:IsDescendantOf(targetPart.Parent)
end
function Utils.isOnScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return on, Vector2.new(v.X, v.Y), v.Z
end
function Utils.distance(a,b) return (a-b).Magnitude end

-- preview
do
    local _, content = makeWindow("Preview", UDim2.new(0.5, 195, 0.5, -280), UDim2.new(0, 260, 0, 560), "Preview")
    local vp = create("ViewportFrame", {
        BackgroundColor3 = Color3.fromRGB(8, 8, 8), BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4),
        Ambient = Color3.fromRGB(110, 110, 110), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), Parent = content,
    })
    accent(stroke(vp, nil, 1, 0.6), "Color", true)
    local cam = Instance.new("Camera") cam.Parent = vp vp.CurrentCamera = cam
    cam.CFrame = CFrame.new(Vector3.new(0, 0, 8), Vector3.new(0, 0, 0))
    local model, basePivot
    local function setupCharacter(char)
        if model then model:Destroy() model=nil end
        if not char then return end
        task.wait(0.5)
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        if not ok or not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do if d:IsA("BaseScript") or d:IsA("Sound") then d:Destroy() end end
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        clone.Parent = vp
        local bbox = clone:GetBoundingBox()
        clone:PivotTo(clone:GetPivot() - bbox.Position)
        basePivot = clone:GetPivot()
        model = clone
    end
    task.spawn(setupCharacter, LocalPlayer.Character)
    bind(LocalPlayer.CharacterAdded, function(c) task.spawn(setupCharacter, c) end)
    bind(RunService.RenderStepped, function()
        if model and basePivot and vp.Visible then
            model:PivotTo(CFrame.Angles(0, os.clock()*0.6, 0) * basePivot)
        end
    end)
    local box = create("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.fromOffset(150, 330), Parent = content,
    })
    stroke(box, BLACK, 2, 0.35)
    stroke(box, WHITE, 1, 0)
    local hb = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0,
        Position = UDim2.new(0, -6, 0, 0), Size = UDim2.new(0, 3, 1, 0), Parent = box,
    })
    create("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = hb })
    label(LocalPlayer.DisplayName, WHITE, 11, box, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, -16),
        TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4,
    })
    label("[running]", WHITE, 10, box, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 60, 0, 14), Position = UDim2.new(1, 6, 0, 0), TextStrokeTransparency = 0.4,
    })
    label("12m", WHITE, 10, box, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, 2),
        TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4,
    })
end

local currentFps = 0
do
    local frames, last = 0, os.clock()
    bind(RunService.RenderStepped, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            currentFps = math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
        end
    end)
end
local function getPing()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v+0.5) or 0
end

--------------------------------------------------------------------
-- FEATURE MODULES
--------------------------------------------------------------------
local Aurum = {}
Aurum.Version = VERSION
Aurum.Build = BUILD
Aurum.Name = NAME
Aurum.Theme = THEME
Aurum.Storage = Storage
Aurum.Registry = Registry
Aurum.Windows = Windows
Aurum.Notify = Notify
Aurum.Utils = Utils
Aurum.Connections = Connections
Aurum.Modules = {}
Aurum._featureConns = {}

local function R(id, fallback)
    local e = Registry[id]
    if e then local ok,val = pcall(e.get) if ok then return val end end
    return fallback
end

-- AIM MODULE
do
    local Aim = {}
    Aim.Name = "Aim"
    local fovCircle, fovOutline
    local lastTrigger = 0
    local silentHooked = false

    local function getFOV() return R("aim.assist.fov", 120) end
    local function getSmooth() return R("aim.assist.smoothness", 0.35) end
    local function isTeamCheck() return R("aim.assist.team_check", true) end
    local function isWallCheck() return R("aim.assist.wall_check", true) end
    local function shouldShowFOV() return R("aim.assist.show_fov", true) end
    local function targetPartPref() return R("aim.assist.target_part", "Head") end
    local function priority() return R("aim.assist.priority", "Crosshair") end

    local function findTarget()
        local best, bestScore = nil, math.huge
        local camPos = Camera.CFrame.Position
        local mousePos = UIS:GetMouseLocation()
        local fov = getFOV()
        local prio = priority()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and Utils.isAlive(plr) then
                if isTeamCheck() and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then continue end
                local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local minH = R("visuals.esp.min_health", 0)
                    if hum.Health < minH then continue end
                end
                local part = Utils.getTargetPart(plr, targetPartPref())
                if not part then continue end
                local on, screenPos, depth = Utils.isOnScreen(part.Position)
                if not on or depth < 0 then continue end
                local dist2D = (screenPos - mousePos).Magnitude
                if dist2D > fov then continue end
                if isWallCheck() and not Utils.isVisible(camPos, part) then continue end
                local score
                if prio == "Distance" then score = Utils.distance(camPos, part.Position)
                elseif prio == "Health" then score = hum and hum.Health or 0
                else score = dist2D end
                if prio=="Health" then
                    if bestScore==math.huge or score < bestScore then bestScore=score best=plr end
                else
                    if score < bestScore then bestScore=score best=plr end
                end
            end
        end
        return best
    end
    local function getTargetPosition(plr)
        local part = Utils.getTargetPart(plr, targetPartPref())
        return part and part.Position or nil
    end
    local function ensureFOVDraw()
        if hasDrawing then
            if not fovCircle then
                fovCircle = Drawing.new("Circle")
                fovCircle.Thickness = 1
                fovCircle.NumSides = 64
                fovCircle.Filled = false
                fovCircle.Transparency = 1
                fovOutline = Drawing.new("Circle")
                fovOutline.Thickness = 3
                fovOutline.NumSides = 64
                fovOutline.Filled = false
                fovOutline.Transparency = 0.35
                fovOutline.Color = Color3.new(0,0,0)
            end
        else
            if not fovCircle then
                fovCircle = create("Frame", {
                    BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,0.5),
                    Size=UDim2.fromOffset(getFOV()*2, getFOV()*2), Position=UDim2.fromScale(0.5,0.5),
                    Visible=false, ZIndex=9999, Parent=ScreenGui
                })
                stroke(fovCircle, Color3.fromHex(R("aim.assist.show_fov.color1","EBEBEB") or "EBEBEB"), 1, 0)
                create("UICorner", { CornerRadius=UDim.new(1,0), Parent=fovCircle })
                fovOutline = create("Frame", {
                    BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,0.5),
                    Size=UDim2.fromOffset(getFOV()*2+4, getFOV()*2+4), Position=UDim2.fromScale(0.5,0.5),
                    Visible=false, ZIndex=9998, Parent=ScreenGui
                })
                stroke(fovOutline, Color3.new(0,0,0), 3, 0.4)
                create("UICorner", { CornerRadius=UDim.new(1,0), Parent=fovOutline })
            end
        end
    end
    local function updateFOVVisual()
        local enabled = R("aim.assist.enabled", false)
        local show = shouldShowFOV()
        ensureFOVDraw()
        local fov = getFOV()
        local pos = UIS:GetMouseLocation()
        local colorHex = R("aim.assist.show_fov.color1", nil)
        local col = WHITE
        if colorHex and type(colorHex)=="string" then pcall(function() col = Color3.fromHex(colorHex) end) end
        if hasDrawing then
            fovCircle.Visible = enabled and show
            fovOutline.Visible = enabled and show
            if fovCircle.Visible then
                fovCircle.Position = Vector2.new(pos.X, pos.Y)
                fovOutline.Position = Vector2.new(pos.X, pos.Y)
                fovCircle.Radius = fov
                fovOutline.Radius = fov
                fovCircle.Color = col
            end
        else
            fovCircle.Visible = enabled and show
            fovOutline.Visible = enabled and show
            if fovCircle.Visible then
                fovCircle.Size = UDim2.fromOffset(fov*2, fov*2)
                fovOutline.Size = UDim2.fromOffset(fov*2+6, fov*2+6)
                local scale = UIScaleObj.Scale
                fovCircle.Position = UDim2.fromOffset(pos.X/scale, pos.Y/scale)
                fovOutline.Position = UDim2.fromOffset(pos.X/scale, pos.Y/scale)
                local s = fovCircle:FindFirstChildOfClass("UIStroke")
                if s then s.Color = col end
            end
        end
    end
    local function setupSilentHook()
        if silentHooked or not hasHookMM then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and R("aim.silent.enabled", false) then
                local chance = R("aim.silent.hit_chance", 100)
                if math.random(1,100) <= chance then
                    local target = findTarget()
                    if target then
                        local tpos = getTargetPosition(target)
                        if tpos and method == "Raycast" then
                            local origin, direction = ...
                            if origin and direction and type(direction)=="Vector3" then
                                local newDir = (tpos - origin).Unit * direction.Magnitude
                                return oldNamecall(self, origin, newDir, select(3, ...))
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        silentHooked = true
        Notify(NAME, "silent aim hook activo", 3)
    end
    function Aim.Init()
        ensureFOVDraw()
        local camConn = bind(RunService.RenderStepped, function(dt)
            updateFOVVisual()
            if R("aim.assist.enabled", false) then
                local target = findTarget()
                if target then
                    local tpos = getTargetPosition(target)
                    if tpos and Camera then
                        local smooth = getSmooth()
                        local curCF = Camera.CFrame
                        local goal = CFrame.new(curCF.Position, tpos)
                        local alpha = 1 - smooth
                        alpha = math.clamp(alpha, 0.05, 1) * math.clamp(dt*60, 0.5, 2)
                        Camera.CFrame = curCF:Lerp(goal, math.clamp(alpha, 0,1))
                    end
                end
            end
            if R("aim.trigger.enabled", false) then
                local target = findTarget()
                if target then
                    local now = os.clock()*1000
                    local delay = R("aim.trigger.delay", 60)
                    if now - lastTrigger >= delay then
                        local part = Utils.getTargetPart(target, targetPartPref())
                        if part then
                            local on, spos = Utils.isOnScreen(part.Position)
                            if on then
                                local mpos = UIS:GetMouseLocation()
                                if (spos - mpos).Magnitude < 12 then
                                    lastTrigger = now
                                    pcall(function()
                                        if type(mouse1click) == "function" then mouse1click()
                                        elseif type(mouse1press) == "function" then mouse1press() task.wait(0.05) mouse1release()
                                        elseif VIM then VIM:SendMouseButtonEvent(mpos.X, mpos.Y, 0, true, game, 0) VIM:SendMouseButtonEvent(mpos.X, mpos.Y, 0, false, game, 0)
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end)
        table.insert(Aurum._featureConns, camConn)
        if hasHookMM then pcall(setupSilentHook)
        else
            local toggle = Registry["aim.silent.enabled"]
            if toggle then
                local origSet = toggle.set
                toggle.set = function(v) origSet(v) if v then Notify(NAME, "silent aim requiere hookmetamethod", 4) end end
            end
        end
    end
    Aurum.Modules.Aim = Aim
end

-- VISUALS MODULE
do
    local Visuals = {}
    Visuals.Name = "Visuals"
    local espCache = {}
    local drawingsCache = {}
    local crosshairParts = {}
    local snapLine, snapOutline

    local function getESPEnabled() return R("visuals.esp.enabled", true) end
    local function getBoxEnabled() return R("visuals.esp.box", true) end
    local function getBoxStyle() return R("visuals.esp.box_style", "Corner") end
    local function getHealthBar() return R("visuals.esp.health_bar", true) end
    local function getSkeleton() return R("visuals.esp.skeleton", true) end
    local function getName() return R("visuals.esp.name", true) end
    local function getDistance() return R("visuals.esp.distance", false) end
    local function getWeapon() return R("visuals.esp.weapon", false) end
    local function getState() return R("visuals.esp.state", true) end
    local function getTracers() return R("visuals.esp.tracers", false) end
    local function getChams() return R("visuals.esp.chams", false) end
    local function getColor(id, fallback)
        local hex = R(id..".color1", nil)
        if hex and type(hex)=="string" then local ok,c = pcall(Color3.fromHex, hex) if ok then return c end end
        return fallback or THEME.Accent
    end
    local function ensureHighlight(plr)
        local char = plr.Character
        if not char then return nil end
        local hl = char:FindFirstChild(NAME.."_HL")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = NAME.."_HL"
            hl.Adornee = char
            hl.Parent = char
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.6
            hl.OutlineTransparency = 0
        end
        return hl
    end
    local function createDrawingSet()
        if not hasDrawing then return nil end
        local set = {}
        set.boxLines = {}
        for i=1,8 do local l = Drawing.new("Line") l.Visible=false l.Thickness=1.5 l.Transparency=1 l.Color=WHITE table.insert(set.boxLines,l) end
        set.boxOutlines = {}
        for i=1,8 do local l = Drawing.new("Line") l.Visible=false l.Thickness=3 l.Transparency=0.5 l.Color=BLACK table.insert(set.boxOutlines,l) end
        set.healthBar = Drawing.new("Line") set.healthBar.Visible=false set.healthBar.Thickness=3
        set.healthOutline = Drawing.new("Line") set.healthOutline.Visible=false set.healthOutline.Thickness=5 set.healthOutline.Color=BLACK
        set.nameText = Drawing.new("Text") set.nameText.Visible=false set.nameText.Center=true set.nameText.Outline=true set.nameText.Size=13
        set.distText = Drawing.new("Text") set.distText.Visible=false set.distText.Center=true set.distText.Outline=true set.distText.Size=13
        set.tracer = Drawing.new("Line") set.tracer.Visible=false set.tracer.Thickness=1
        set.skeletonLines = {}
        for i=1,6 do local l = Drawing.new("Line") l.Visible=false l.Thickness=1.5 table.insert(set.skeletonLines,l) end
        return set
    end
    local function hideDrawingSet(set)
        for _,l in ipairs(set.boxLines) do l.Visible=false end
        for _,l in ipairs(set.boxOutlines) do l.Visible=false end
        set.healthBar.Visible=false set.healthOutline.Visible=false set.nameText.Visible=false set.distText.Visible=false set.tracer.Visible=false
        for _,l in ipairs(set.skeletonLines) do l.Visible=false end
    end
    local function createFrameSet()
        local set = {}
        set.box = create("Frame", { BackgroundTransparency=1, Visible=false, Parent=ScreenGui })
        stroke(set.box, WHITE, 1, 0)
        create("UIStroke", { Color=BLACK, Thickness=2, Transparency=0.4, Parent=set.box })
        set.healthBG = create("Frame", { BackgroundColor3=Color3.fromRGB(20,20,20), BorderSizePixel=0, Visible=false, Parent=ScreenGui })
        set.healthFill = create("Frame", { BackgroundColor3=GREEN, BorderSizePixel=0, Size=UDim2.fromScale(1,1), Parent=set.healthBG })
        set.tracer = create("Frame", { BackgroundColor3=WHITE, BorderSizePixel=0, Visible=false, AnchorPoint=Vector2.new(0.5,0), Parent=ScreenGui })
        set.nameLabel = create("TextLabel", { BackgroundTransparency=1, Visible=false, Text="", TextColor3=WHITE, Font=THEME.Font, TextSize=13, TextStrokeTransparency=0.4, Parent=ScreenGui })
        return set
    end
    local function hideFrameSet(set)
        if set.box then set.box.Visible=false end
        if set.healthBG then set.healthBG.Visible=false end
        if set.tracer then set.tracer.Visible=false end
        if set.nameLabel then set.nameLabel.Visible=false end
    end
    local R15_JOINTS = {
        {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
    }
    local R6_JOINTS = { {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"}, {"Torso","Left Leg"}, {"Torso","Right Leg"} }
    local function drawSkeleton(plr, set)
        if not getSkeleton() then return end
        local char = plr.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local isR15 = humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
        local joints = isR15 and R15_JOINTS or R6_JOINTS
        local col = getColor("visuals.esp.skeleton", THEME.Accent)
        for i, pair in ipairs(joints) do
            local a = char:FindFirstChild(pair[1])
            local b = char:FindFirstChild(pair[2])
            if a and b and set.skeletonLines and set.skeletonLines[i] then
                local ap, aon = Camera:WorldToViewportPoint(a.Position)
                local bp, bon = Camera:WorldToViewportPoint(b.Position)
                local line = set.skeletonLines[i]
                if aon and bon then
                    line.From = Vector2.new(ap.X, ap.Y)
                    line.To = Vector2.new(bp.X, bp.Y)
                    line.Color = col
                    line.Visible = true
                else line.Visible = false end
            end
        end
    end
    local function ensureCrosshair()
        if #crosshairParts>0 then return end
        for i=1,4 do
            local f = create("Frame", { BackgroundColor3=ORANGE, BorderSizePixel=0, Visible=false, AnchorPoint=Vector2.new(0.5,0.5), ZIndex=9999, Parent=ScreenGui })
            stroke(f, BLACK, 1, 0.3)
            table.insert(crosshairParts, f)
        end
        local dot = create("Frame", { BackgroundColor3=ORANGE, BorderSizePixel=0, Visible=false, Size=UDim2.fromOffset(3,3), AnchorPoint=Vector2.new(0.5,0.5), ZIndex=9999, Parent=ScreenGui })
        create("UICorner", { CornerRadius=UDim.new(1,0), Parent=dot })
        table.insert(crosshairParts, dot)
    end
    local function updateCrosshair()
        ensureCrosshair()
        local enabled = R("visuals.crosshair.enabled", true)
        if not enabled then for _,p in ipairs(crosshairParts) do p.Visible=false end return end
        local length = R("visuals.crosshair.length", 6)
        local thickness = R("visuals.crosshair.thickness", 1)
        local gap = R("visuals.crosshair.gap", 3)
        local color = getColor("visuals.crosshair", ORANGE)
        local outline = R("visuals.crosshair.outline", true)
        local dotEnabled = R("visuals.crosshair.dot", false)
        local dynamic = R("visuals.crosshair.dynamic", false)
        local center = Vector2.new(ScreenGui.AbsoluteSize.X/2, ScreenGui.AbsoluteSize.Y/2)
        if dynamic then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local move = hum and hum.MoveDirection.Magnitude or 0
            gap = gap + move*6
            length = length + move*2
        end
        local parts = {
            {pos=Vector2.new(center.X - gap - length/2, center.Y), size=Vector2.new(length, thickness)},
            {pos=Vector2.new(center.X + gap + length/2, center.Y), size=Vector2.new(length, thickness)},
            {pos=Vector2.new(center.X, center.Y - gap - length/2), size=Vector2.new(thickness, length)},
            {pos=Vector2.new(center.X, center.Y + gap + length/2), size=Vector2.new(thickness, length)},
        }
        for i=1,4 do
            local p = crosshairParts[i]
            p.Visible=true
            p.BackgroundColor3=color
            p.Size=UDim2.fromOffset(parts[i].size.X, parts[i].size.Y)
            p.Position=UDim2.fromOffset(parts[i].pos.X, parts[i].pos.Y)
            local s = p:FindFirstChildOfClass("UIStroke")
            if s then s.Enabled = outline s.Color = getColor("visuals.crosshair.outline", BLACK) end
        end
        local dot = crosshairParts[5]
        dot.Visible = dotEnabled
        dot.BackgroundColor3 = color
        dot.Position = UDim2.fromOffset(center.X, center.Y)
    end
    local function ensureSnapline()
        if snapLine then return end
        if hasDrawing then
            snapLine = Drawing.new("Line") snapLine.Visible=false snapLine.Thickness=1
            snapOutline = Drawing.new("Line") snapOutline.Visible=false snapOutline.Thickness=3 snapOutline.Color=BLACK snapOutline.Transparency=0.4
        else
            snapLine = create("Frame", { BackgroundColor3=ORANGE, BorderSizePixel=0, Visible=false, AnchorPoint=Vector2.new(0,0.5), ZIndex=9998, Parent=ScreenGui })
            snapOutline = create("Frame", { BackgroundColor3=BLACK, BorderSizePixel=0, Visible=false, AnchorPoint=Vector2.new(0,0.5), ZIndex=9997, Parent=ScreenGui })
            snapOutline.BackgroundTransparency=0.6
        end
    end
    local function updateSnapline(targetPos)
        ensureSnapline()
        local enabled = R("visuals.snapline.enabled", true)
        if not enabled or not targetPos then
            if hasDrawing then snapLine.Visible=false snapOutline.Visible=false else snapLine.Visible=false snapOutline.Visible=false end
            return
        end
        local originMode = R("visuals.snapline.origin", "Bottom")
        local thickness = R("visuals.snapline.thickness", 1)
        local color = getColor("visuals.snapline", ORANGE)
        local outline = R("visuals.snapline.outline", true)
        local vp = ScreenGui.AbsoluteSize
        local origin
        if originMode=="Bottom" then origin = Vector2.new(vp.X/2, vp.Y)
        elseif originMode=="Center" then origin = Vector2.new(vp.X/2, vp.Y/2)
        elseif originMode=="Top" then origin = Vector2.new(vp.X/2, 0)
        elseif originMode=="Mouse" then origin = UIS:GetMouseLocation()
        else origin = Vector2.new(vp.X/2, vp.Y) end
        local on, screenPos = Utils.isOnScreen(targetPos)
        if not on then if hasDrawing then snapLine.Visible=false snapOutline.Visible=false else snapLine.Visible=false snapOutline.Visible=false end return end
        if hasDrawing then
            snapLine.Visible=true snapOutline.Visible=outline
            snapLine.From = origin snapLine.To = screenPos snapLine.Color = color snapLine.Thickness = thickness
            snapOutline.From = origin snapOutline.To = screenPos snapOutline.Thickness = thickness+2
        else
            local vec = screenPos - origin
            local len = vec.Magnitude
            local ang = math.deg(math.atan2(vec.Y, vec.X))
            snapLine.Visible=true snapOutline.Visible=outline
            snapLine.BackgroundColor3=color snapLine.Size=UDim2.fromOffset(len, thickness) snapLine.Position=UDim2.fromOffset(origin.X, origin.Y) snapLine.Rotation=ang
            snapOutline.Size=UDim2.fromOffset(len, thickness+2) snapOutline.Position=UDim2.fromOffset(origin.X, origin.Y) snapOutline.Rotation=ang
        end
    end
    local function updateESP()
        if not getESPEnabled() then
            for plr,set in pairs(drawingsCache) do hideDrawingSet(set) end
            for plr,data in pairs(espCache) do if data.highlight then data.highlight.Enabled=false end if data.frameSet then hideFrameSet(data.frameSet) end end
            return
        end
        local camPos = Camera.CFrame.Position
        local infoDist = R("visuals.esp.info_distance", 150)
        local fadeDist = R("visuals.esp.fade_distance", 120)
        local textSize = R("visuals.esp.text_size", 13)
        local localPlayerEnabled = R("visuals.esp.local_player", false)
        local minHealth = R("visuals.esp.min_health", 5)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer and not localPlayerEnabled then
                local dset = drawingsCache[plr] if dset then hideDrawingSet(dset) end
                local edata = espCache[plr] if edata then if edata.highlight then edata.highlight.Enabled=false end if edata.frameSet then hideFrameSet(edata.frameSet) end end
            else
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not char or not hum or not root or hum.Health<=0 then
                    local dset = drawingsCache[plr] if dset then hideDrawingSet(dset) end
                else
                    if hum.Health >= minHealth then
                        local dist = Utils.distance(camPos, root.Position)
                        local alpha = 1
                        if dist > fadeDist then alpha = math.clamp(1 - (dist - fadeDist)/math.max(1, infoDist - fadeDist), 0, 1) end
                        if alpha > 0.05 then
                            local cf, size = char:GetBoundingBox()
                            local min, max = cf.Position - size/2, cf.Position + size/2
                            local corners = {
                                Vector3.new(min.X, min.Y, min.Z), Vector3.new(max.X, min.Y, min.Z),
                                Vector3.new(max.X, min.Y, max.Z), Vector3.new(min.X, min.Y, max.Z),
                                Vector3.new(min.X, max.Y, min.Z), Vector3.new(max.X, max.Y, min.Z),
                                Vector3.new(max.X, max.Y, max.Z), Vector3.new(min.X, max.Y, max.Z),
                            }
                            local screenCorners = {}
                            local onScreenCount=0
                            for i, wc in ipairs(corners) do local v, on = Camera:WorldToViewportPoint(wc) screenCorners[i]={pos=Vector2.new(v.X,v.Y), on=on, depth=v.Z} if on and v.Z>0 then onScreenCount+=1 end end
                            local minX, minY = math.huge, math.huge
                            local maxX, maxY = -math.huge, -math.huge
                            for _, sc in ipairs(screenCorners) do if sc.on and sc.depth>0 then minX=math.min(minX, sc.pos.X) minY=math.min(minY, sc.pos.Y) maxX=math.max(maxX, sc.pos.X) maxY=math.max(maxY, sc.pos.Y) end end
                            local boxValid = onScreenCount>=1 and minX < maxX and minY < maxY
                            local boxW, boxH = maxX-minX, maxY-minY
                            if boxValid then
                                if boxW < 10 then boxW=10 end
                                if boxH < 20 then boxH=20 end
                                if getChams() then
                                    local hl = ensureHighlight(plr)
                                    if hl then hl.Enabled=true hl.FillColor=getColor("visuals.esp.chams", THEME.Accent) hl.OutlineColor=THEME.Accent hl.FillTransparency=0.6 end
                                    if not espCache[plr] then espCache[plr]={} end espCache[plr].highlight=hl
                                else
                                    local edata = espCache[plr] if edata and edata.highlight then edata.highlight.Enabled=false end
                                end
                                if hasDrawing then
                                    local set = drawingsCache[plr] if not set then set=createDrawingSet() drawingsCache[plr]=set end
                                    hideDrawingSet(set)
                                    if getBoxEnabled() then
                                        local style = getBoxStyle()
                                        local col = getColor("visuals.esp.box", WHITE)
                                        if style=="Full" then
                                            local pts = {Vector2.new(minX, minY), Vector2.new(maxX, minY), Vector2.new(maxX, maxY), Vector2.new(minX, maxY)}
                                            for i=1,4 do local a=pts[i] local b=pts[i%4+1] local line=set.boxLines[i] local ol=set.boxOutlines[i] line.From=a line.To=b line.Color=col line.Transparency=alpha line.Visible=true ol.From=a ol.To=b ol.Visible=true ol.Transparency=alpha*0.5 end
                                        elseif style=="Corner" then
                                            local len = math.clamp(boxW*0.2, 4, 12)
                                            local corners2D = {
                                                {pos=Vector2.new(minX, minY), dir1=Vector2.new(1,0), dir2=Vector2.new(0,1)},
                                                {pos=Vector2.new(maxX, minY), dir1=Vector2.new(-1,0), dir2=Vector2.new(0,1)},
                                                {pos=Vector2.new(maxX, maxY), dir1=Vector2.new(-1,0), dir2=Vector2.new(0,-1)},
                                                {pos=Vector2.new(minX, maxY), dir1=Vector2.new(1,0), dir2=Vector2.new(0,-1)},
                                            }
                                            local idx=1
                                            for _,c in ipairs(corners2D) do for _,dir in ipairs({c.dir1,c.dir2}) do if idx<=8 then local a=c.pos local b=a+dir*len local line=set.boxLines[idx] local ol=set.boxOutlines[idx] line.From=a line.To=b line.Color=col line.Transparency=alpha line.Visible=true ol.From=a ol.To=b ol.Visible=true ol.Transparency=alpha*0.5 idx+=1 end end end
                                        elseif style=="3D" then
                                            local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
                                            for i, e in ipairs(edges) do if i<=8 then local a=screenCorners[e[1]] local b=screenCorners[e[2]] local line=set.boxLines[i] local ol=set.boxOutlines[i] if a.on and b.on and a.depth>0 and b.depth>0 then line.From=a.pos line.To=b.pos line.Color=getColor("visuals.esp.box", WHITE) line.Transparency=alpha line.Visible=true ol.From=a.pos ol.To=b.pos ol.Visible=true ol.Transparency=alpha*0.5 else line.Visible=false ol.Visible=false end end end
                                        end
                                    end
                                    if getHealthBar() and hum then
                                        local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                        local col1 = getColor("visuals.esp.health_bar", GREEN)
                                        local barX = minX - 6
                                        local barY = minY
                                        local barH = boxH
                                        local fillH = barH * pct
                                        set.healthOutline.From = Vector2.new(barX, barY) set.healthOutline.To = Vector2.new(barX, barY+barH) set.healthOutline.Visible=true set.healthOutline.Transparency=alpha
                                        set.healthBar.From = Vector2.new(barX, barY+barH - fillH) set.healthBar.To = Vector2.new(barX, barY+barH) set.healthBar.Color=col1 set.healthBar.Transparency=alpha set.healthBar.Visible=true
                                    end
                                    local infoParts={}
                                    if getName() then table.insert(infoParts, plr.DisplayName) end
                                    if getState() then local state="running" if hum:GetState()==Enum.HumanoidStateType.Jumping then state="jumping" elseif hum:GetState()==Enum.HumanoidStateType.Freefall then state="falling" elseif hum.MoveDirection.Magnitude<0.1 then state="idle" end table.insert(infoParts, "["..state.."]") end
                                    if getWeapon() then local tool=char:FindFirstChildOfClass("Tool") if tool then table.insert(infoParts, tool.Name) end end
                                    if #infoParts>0 then set.nameText.Text=table.concat(infoParts,"  ") set.nameText.Position=Vector2.new((minX+maxX)/2, minY-14) set.nameText.Color=getColor("visuals.esp.name", WHITE) set.nameText.Size=textSize set.nameText.Transparency=alpha set.nameText.Visible=true end
                                    if getDistance() then set.distText.Text=string.format("%.0fm", dist) set.distText.Position=Vector2.new((minX+maxX)/2, maxY+2) set.distText.Color=getColor("visuals.esp.distance", WHITE) set.distText.Size=textSize-1 set.distText.Transparency=alpha set.distText.Visible=true end
                                    if getTracers() then local origin=Vector2.new(ScreenGui.AbsoluteSize.X/2, ScreenGui.AbsoluteSize.Y) local target=Vector2.new((minX+maxX)/2, maxY) set.tracer.From=origin set.tracer.To=target set.tracer.Color=getColor("visuals.esp.tracers", WHITE) set.tracer.Transparency=alpha set.tracer.Visible=true set.tracer.Thickness=1 end
                                    if getSkeleton() then drawSkeleton(plr, set) end
                                else
                                    local edata = espCache[plr] if not edata then edata={} espCache[plr]=edata end if not edata.frameSet then edata.frameSet=createFrameSet() end local fset=edata.frameSet hideFrameSet(fset)
                                    if getBoxEnabled() then fset.box.Visible=true fset.box.Position=UDim2.fromOffset(minX, minY) fset.box.Size=UDim2.fromOffset(boxW, boxH) local s=fset.box:FindFirstChildOfClass("UIStroke") if s then s.Color=getColor("visuals.esp.box", WHITE) s.Transparency=1-alpha end end
                                    if getHealthBar() and hum then fset.healthBG.Visible=true fset.healthBG.Position=UDim2.fromOffset(minX-6, minY) fset.healthBG.Size=UDim2.fromOffset(3, boxH) fset.healthFill.Size=UDim2.new(1,0, math.clamp(hum.Health/hum.MaxHealth,0,1),0) fset.healthFill.Position=UDim2.new(0,0, 1 - math.clamp(hum.Health/hum.MaxHealth,0,1),0) fset.healthFill.BackgroundColor3=getColor("visuals.esp.health_bar", GREEN) end
                                    if getName() then fset.nameLabel.Visible=true fset.nameLabel.Text=plr.DisplayName.." ["..string.format("%.0f", dist).."m]" fset.nameLabel.Position=UDim2.fromOffset((minX+maxX)/2-50, minY-14) fset.nameLabel.Size=UDim2.fromOffset(100,14) fset.nameLabel.TextColor3=getColor("visuals.esp.name", WHITE) fset.nameLabel.TextTransparency=1-alpha end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    function Visuals.Init()
        local conn = bind(RunService.RenderStepped, function()
            updateESP() updateCrosshair()
            local camPos = Camera.CFrame.Position
            local best, bestD = nil, math.huge
            for _, plr in ipairs(Players:GetPlayers()) do if plr~=LocalPlayer and Utils.isAlive(plr) then local part = Utils.getTargetPart(plr, "Head") if part then local on,_=Utils.isOnScreen(part.Position) if on then local d=Utils.distance(camPos, part.Position) if d<bestD then bestD=d best=plr end end end end end
            if best then local part=Utils.getTargetPart(best,"Head") if part then updateSnapline(part.Position) else updateSnapline(nil) end else updateSnapline(nil) end
        end)
        table.insert(Aurum._featureConns, conn)
        bind(Players.PlayerRemoving, function(plr) local set=drawingsCache[plr] if set then hideDrawingSet(set) drawingsCache[plr]=nil end local ed=espCache[plr] if ed then if ed.highlight then pcall(function() ed.highlight:Destroy() end) end if ed.frameSet then pcall(function() ed.frameSet.holder:Destroy() end) end espCache[plr]=nil end end)
    end
    Aurum.Modules.Visuals = Visuals
end

-- WORLD MODULE
do
    local World = {}
    World.Name = "World"
    local original = {}
    local colorCorr, sky, freecamConn, freecamPos, freecamCF
    local function saveOriginal()
        if not original.saved then original.Ambient=Lighting.Ambient original.Brightness=Lighting.Brightness original.ClockTime=Lighting.ClockTime original.FogEnd=Lighting.FogEnd original.GlobalShadows=Lighting.GlobalShadows original.ExposureCompensation=Lighting.ExposureCompensation original.saved=true end
    end
    function World.Init()
        saveOriginal()
        local function applyLighting()
            saveOriginal()
            local fb = R("world.lighting.fullbright", false)
            local customAmb = R("world.lighting.custom_ambient", false)
            local t = R("world.lighting.time", 14)
            local br = R("world.lighting.brightness", 2)
            local sat = R("world.lighting.saturation", 0)
            if fb then Lighting.Ambient=Color3.new(1,1,1) Lighting.Brightness=3 Lighting.ClockTime=14 Lighting.FogEnd=100000 Lighting.GlobalShadows=false
            else
                if customAmb then local hex=R("world.lighting.custom_ambient.color1", nil) if hex then pcall(function() Lighting.Ambient=Color3.fromHex(hex) end) end else Lighting.Ambient=original.Ambient end
                Lighting.Brightness=br Lighting.ClockTime=t Lighting.GlobalShadows=original.GlobalShadows
                if not R("world.removals.no_fog", false) then Lighting.FogEnd=original.FogEnd end
            end
            if not colorCorr then colorCorr=Lighting:FindFirstChild(NAME.."_CC") if not colorCorr then colorCorr=Instance.new("ColorCorrectionEffect") colorCorr.Name=NAME.."_CC" colorCorr.Parent=Lighting end end
            colorCorr.Saturation=sat colorCorr.TintColor=Color3.new(1,1,1)
        end
        task.spawn(function() while ScreenGui.Parent do applyLighting() task.wait(0.3) end end)
        local skies = {
            Night = {"rbxassetid://12064107","rbxassetid://12064152","rbxassetid://12064180","rbxassetid://12064186","rbxassetid://12064196","rbxassetid://12064214"},
            Space = {"rbxassetid://166509999","rbxassetid://166510102","rbxassetid://166510131","rbxassetid://166510057","rbxassetid://166510084","rbxassetid://166510020"},
            Sunset = {"rbxassetid://149827002","rbxassetid://149827045","rbxassetid://149827082","rbxassetid://149827115","rbxassetid://149827130","rbxassetid://149827180"},
            Clouds = {"rbxassetid://252760981","rbxassetid://252761237","rbxassetid://252761237","rbxassetid://252761237","rbxassetid://252761237","rbxassetid://252761237"},
            Void = {"rbxassetid://0","rbxassetid://0","rbxassetid://0","rbxassetid://0","rbxassetid://0","rbxassetid://0"},
        }
        local function applySky()
            local enabled=R("world.skybox.enabled", false)
            local choice=R("world.skybox.skybox", "Night")
            if not enabled then if sky then pcall(function() sky:Destroy() sky=nil end) end return end
            if not sky then sky=Instance.new("Sky") sky.Name=NAME.."_Sky" sky.Parent=Lighting end
            local s=skies[choice] or skies.Night
            sky.SkyboxBk=s[1] sky.SkyboxFt=s[2] sky.SkyboxLf=s[3] sky.SkyboxRt=s[4] sky.SkyboxUp=s[5] sky.SkyboxDn=s[6] sky.SunTextureId="" sky.MoonTextureId="" sky.StarCount=3000
        end
        task.spawn(function() while ScreenGui.Parent do applySky() task.wait(0.5) end end)
        task.spawn(function()
            while ScreenGui.Parent do
                if R("world.removals.no_fog", false) then Lighting.FogEnd=100000 end
                if R("world.removals.no_shadows", false) then Lighting.GlobalShadows=false end
                if R("world.removals.no_post", false) then for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("BlurEffect") and v.Name~=NAME.."_blur" then v.Enabled=false end end end
                if R("world.removals.no_particles", false) then for _,v in ipairs(Workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end end end
                task.wait(1)
            end
        end)
        local origFOV = Camera.FieldOfView
        bind(RunService.RenderStepped, function()
            if R("world.camera.custom_fov", false) then Camera.FieldOfView=R("world.camera.fov", 70)
            else if math.abs(Camera.FieldOfView - origFOV) < 1 then Camera.FieldOfView=origFOV end end
        end)
        task.spawn(function() while ScreenGui.Parent do if R("world.camera.third_person", false) then LocalPlayer.CameraMode=Enum.CameraMode.Classic LocalPlayer.CameraMinZoomDistance=8 LocalPlayer.CameraMaxZoomDistance=50 end task.wait(0.5) end end)
        local function enableFreecam(enable)
            if enable then
                freecamPos=Camera.CFrame.Position freecamCF=Camera.CFrame Camera.CameraType=Enum.CameraType.Scriptable
                freecamConn=bind(RunService.RenderStepped, function(dt)
                    local move=Vector3.zero
                    local speed=R("player.movement.fly_speed",3)*15
                    if UIS:IsKeyDown(Enum.KeyCode.W) then move+=freecamCF.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move-=freecamCF.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move-=freecamCF.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move+=freecamCF.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then move+=Vector3.new(0,1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move-=Vector3.new(0,1,0) end
                    local mouseDelta=UIS:GetMouseDelta()
                    freecamCF=freecamCF * CFrame.Angles(0, -mouseDelta.X*0.002, 0) * CFrame.Angles(-mouseDelta.Y*0.002,0,0)
                    freecamPos+=move*dt*speed
                    Camera.CFrame=CFrame.new(freecamPos) * freecamCF.Rotation
                end)
                UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
            else
                if freecamConn then freecamConn:Disconnect() freecamConn=nil end
                Camera.CameraType=Enum.CameraType.Custom UIS.MouseBehavior=Enum.MouseBehavior.Default
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then Camera.CameraSubject=LocalPlayer.Character.Humanoid end
            end
        end
        local fcToggle=Registry["world.camera.freecam"]
        if fcToggle then local orig=fcToggle.set fcToggle.set=function(v) orig(v) enableFreecam(v) end end
    end
    Aurum.Modules.World = World
end

-- PLAYER MODULE
do
    local PlayerMod = {}
    PlayerMod.Name = "Player"
    local flyConn, noclipConn, spinConn, infJumpConn, afkConn
    local flyVel, flyGyro
    local originalWalk
    local function getHum() local c=LocalPlayer.Character return c and c:FindFirstChildOfClass("Humanoid") end
    local function getRoot() local c=LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
    local function applySpeed()
        local hum=getHum() if not hum then return end
        if R("player.movement.speed", false) then local v=R("player.movement.speed_value",32) if hum.WalkSpeed~=v then hum.WalkSpeed=v end end
    end
    local function applyJump()
        local hum=getHum() if not hum then return end
        if R("player.movement.jump", false) then local v=R("player.movement.jump_value",50) if hum.UseJumpPower then hum.JumpPower=v else hum.JumpHeight=v/10 end end
    end
    local function startFly()
        if flyConn then flyConn:Disconnect() end
        local root=getRoot() if not root then return end
        flyVel=Instance.new("BodyVelocity") flyVel.Name=NAME.."_FlyVel" flyVel.Velocity=Vector3.zero flyVel.MaxForce=Vector3.new(1e9,1e9,1e9) flyVel.PType=Enum.PType.Force flyVel.Parent=root
        flyGyro=Instance.new("BodyGyro") flyGyro.Name=NAME.."_FlyGyro" flyGyro.MaxTorque=Vector3.new(1e9,1e9,1e9) flyGyro.P=9e4 flyGyro.CFrame=root.CFrame flyGyro.Parent=root
        flyConn=bind(RunService.Heartbeat, function()
            if not R("player.movement.fly", false) then
                if flyVel then pcall(function() flyVel:Destroy() flyVel=nil end) end
                if flyGyro then pcall(function() flyGyro:Destroy() flyGyro=nil end) end
                if flyConn then flyConn:Disconnect() flyConn=nil end
                return
            end
            local camCF=Camera.CFrame
            local dir=Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
            local speed=R("player.movement.fly_speed",3)*12
            if dir.Magnitude>0 then dir=dir.Unit*speed else dir=Vector3.zero end
            flyVel.Velocity=dir flyGyro.CFrame=camCF
        end)
        Notify(NAME, "fly: on (WASD + Space/Ctrl)", 3)
    end
    local function stopFly()
        if flyConn then flyConn:Disconnect() flyConn=nil end
        if flyVel then pcall(function() flyVel:Destroy() end) flyVel=nil end
        if flyGyro then pcall(function() flyGyro:Destroy() end) flyGyro=nil end
    end
    local function startNoclip()
        if noclipConn then noclipConn:Disconnect() end
        noclipConn=bind(RunService.Stepped, function()
            if not R("player.movement.noclip", false) then return end
            local char=LocalPlayer.Character if char then for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") and v.CanCollide then v.CanCollide=false end end end
        end)
    end
    local function stopNoclip() if noclipConn then noclipConn:Disconnect() noclipConn=nil end end
    local function startSpin()
        if spinConn then spinConn:Disconnect() end
        spinConn=bind(RunService.Heartbeat, function()
            local root=getRoot() if root then local speed=R("player.misc.spin_speed",10) root.CFrame=root.CFrame * CFrame.Angles(0, math.rad(speed*4), 0) end
        end)
    end
    local function stopSpin() if spinConn then spinConn:Disconnect() spinConn=nil end end
    local function setupInfJump()
        if infJumpConn then infJumpConn:Disconnect() end
        infJumpConn=bind(UIS.JumpRequest, function() if R("player.misc.inf_jump", false) then local hum=getHum() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)
    end
    local function setupAntiAFK()
        if afkConn then afkConn:Disconnect() end
        if R("player.misc.anti_afk", true) then
            afkConn=bind(LocalPlayer.Idled, function() pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) Notify(NAME,"anti afk: activado",2) end)
        end
    end
    function PlayerMod.Init()
        originalWalk=getHum() and getHum().WalkSpeed or 16
        bind(RunService.Heartbeat, function()
            if R("player.movement.speed", false) then applySpeed() end
            if R("player.movement.jump", false) then applyJump() end
            if R("player.misc.auto_respawn", false) then local hum=getHum() if hum and hum.Health<=0 then task.wait(1) pcall(function() hum.Health=hum.MaxHealth end) end end
        end)
        local flyToggle=Registry["player.movement.fly"]
        if flyToggle then local orig=flyToggle.set flyToggle.set=function(v) orig(v) if v then startFly() else stopFly() end end if flyToggle.get() then startFly() end end
        local noclipToggle=Registry["player.movement.noclip"]
        if noclipToggle then local orig=noclipToggle.set noclipToggle.set=function(v) orig(v) if v then startNoclip() else stopNoclip() end end if noclipToggle.get() then startNoclip() end end
        local spinToggle=Registry["player.misc.spin"]
        if spinToggle then local orig=spinToggle.set spinToggle.set=function(v) orig(v) if v then startSpin() else stopSpin() end end end
        setupInfJump() setupAntiAFK()
        local antiAfkToggle=Registry["player.misc.anti_afk"]
        if antiAfkToggle then local orig=antiAfkToggle.set antiAfkToggle.set=function(v) orig(v) setupAntiAFK() end end
        bind(LocalPlayer.CharacterAdded, function() task.wait(1) if R("player.movement.fly", false) then startFly() end if R("player.movement.noclip", false) then startNoclip() end end)
    end
    Aurum.Modules.Player = PlayerMod
end

do
    local Utility = {}
    Utility.Name = "Utility"
    function Utility.Init() end
    Aurum.Modules.Utility = Utility
end

--------------------------------------------------------------------
-- CONFIG WINDOW
--------------------------------------------------------------------
do
    local _, content = makeWindow("Config", UDim2.new(1, -330, 1, -400), UDim2.new(0, 300, 0, 340), "Configs", false)
    local nameBox = create("TextBox", {
        BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 0, 6),
        Text = "", PlaceholderText = "config name...", PlaceholderColor3 = THEME.TextDim, TextColor3 = THEME.Text,
        Font = THEME.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = content,
    }, { create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }) })
    accent(stroke(nameBox, nil, 1, 0.4), "Color", true)
    local listFrame = create("Frame", {
        BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Size = UDim2.new(1, -8, 1, -104), Position = UDim2.new(0, 4, 0, 30), Parent = content,
    })
    accent(stroke(listFrame, nil, 1, 0.4), "Color", true)
    local list = create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = listFrame,
    }, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
    accent(list, "ScrollBarImageColor3")
    local entries, selected = {}, nil
    local autoloadName = Storage.read("autoload.txt")
    if autoloadName == "" then autoloadName = nil end
    local function refresh()
        for n, e in pairs(entries) do
            local sel = n == selected
            e.stroke.Transparency = sel and 0 or 1
            e.button.BackgroundTransparency = sel and 0 or 1
            e.tag.Visible = n == autoloadName
        end
    end
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        entries = {}
        for i, n in ipairs(Storage.listConfigs()) do
            local b = create("TextButton", {
                BackgroundColor3 = THEME.Element, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
                Text = "  " .. n, TextColor3 = THEME.Text, Font = THEME.Font, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -2, 0, 16), LayoutOrder = i, Parent = list,
            })
            local s = accent(stroke(b, nil, 1, 1), "Color")
            local tag = accent(label("(autoload)  ", nil, 10, b, {
                AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Visible = false,
            }), "TextColor3")
            entries[n] = { button = b, stroke = s, tag = tag }
            b.MouseButton1Click:Connect(function() selected = n nameBox.Text = n refresh() end)
        end
        if selected and not entries[selected] then selected = nil end
        refresh()
    end
    local function targetName()
        local n = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[^%w%s%-_%.]", "")
        if n == "" then n = selected end
        return n
    end
    local function saveConfig(n)
        if not n or n == "" then Notify(NAME, "enter a config name", 3) return end
        Storage.write("configs/" .. n .. ".json", HttpService:JSONEncode(collect(false)))
        selected = n
        rebuild()
        Notify(NAME, "saved config '" .. n .. "'", 3)
    end
    local function loadConfig(n)
        if not n then Notify(NAME, "select a config", 3) return end
        local raw = Storage.read("configs/" .. n .. ".json")
        if not raw then Notify(NAME, "config not found", 3) return end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and type(data) == "table" then apply(data) Notify(NAME, "loaded config '" .. n .. "'", 3)
        else Notify(NAME, "config is corrupted", 3) end
    end
    local grid = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 62), Position = UDim2.new(0, 4, 1, -68), Parent = content,
    }, {
        create("UIGridLayout", { CellSize = UDim2.new(0.5, -2, 0, 18), CellPadding = UDim2.new(0, 4, 0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    Button(grid, "Save", function() saveConfig(targetName()) end)
    Button(grid, "Load", function() loadConfig(selected or targetName()) end)
    Button(grid, "Overwrite", function()
        if not selected then Notify(NAME, "select a config to overwrite", 3) return end
        saveConfig(selected)
    end)
    Button(grid, "Delete", function()
        if not selected then Notify(NAME, "select a config", 3) return end
        Storage.delete("configs/" .. selected .. ".json")
        if autoloadName == selected then autoloadName = nil Storage.delete("autoload.txt") end
        Notify(NAME, "deleted '" .. selected .. "'", 3)
        selected = nil
        rebuild()
    end)
    Button(grid, "Refresh", function() rebuild() Notify(NAME, "config list refreshed", 2) end)
    Button(grid, "Set Autoload", function()
        if not selected then Notify(NAME, "select a config", 3) return end
        if autoloadName == selected then
            autoloadName = nil
            Storage.delete("autoload.txt")
            Notify(NAME, "autoload cleared", 3)
        else
            autoloadName = selected
            Storage.write("autoload.txt", selected)
            Notify(NAME, "'" .. selected .. "' will autoload", 3)
        end
        refresh()
    end)
    rebuild()
end

--------------------------------------------------------------------
-- TARGET HUD
--------------------------------------------------------------------
do
    local _, content = makeWindow("Target", UDim2.new(0.5, -105, 1, -210), UDim2.new(0, 210, 0, 78), "Target")
    local avatar = create("ImageLabel", {
        BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 8, 0, 8), Parent = content,
    })
    accent(stroke(avatar, nil, 1, 0.3), "Color", true)
    task.spawn(function()
        pcall(function()
            avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
    end)
    local nameLbl = accent(label(LocalPlayer.DisplayName, nil, 11, content, {
        Position = UDim2.new(0, 56, 0, 6), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -62, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
    }), "TextColor3")
    local infoLbl = label("12m  //  [running]", THEME.TextDim, 10, content, {
        Position = UDim2.new(0, 56, 0, 19), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -62, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local bar = create("Frame", {
        BackgroundColor3 = THEME.Element, BorderSizePixel = 0, Size = UDim2.new(1, -64, 0, 14), Position = UDim2.new(0, 56, 0, 34), Parent = content,
    })
    accent(stroke(bar, nil, 1, 0.2), "Color")
    local fill = accent(create("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = bar }), "BackgroundColor3")
    local hp = label("100 / 100", Color3.fromRGB(20, 20, 20), 10, bar, {
        AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
    })
    bind(RunService.Heartbeat, function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth>0 then
            fill.Size = UDim2.new(math.clamp(hum.Health/hum.MaxHealth,0,1),0,1,0)
            hp.Text = ("%d / %d"):format(math.floor(hum.Health), hum.MaxHealth)
            local state = hum:GetState().Name:lower()
            infoLbl.Text = "self  //  ["..state.."]"
            nameLbl.Text = LocalPlayer.DisplayName
        end
    end)
end

--------------------------------------------------------------------
-- WATERMARK
--------------------------------------------------------------------
local wmSegments = {}
do
    local w = makeWindow("Watermark", UDim2.new(1, -300, 0, 76), UDim2.new(0, 0, 0, 24))
    w.AutomaticSize = Enum.AutomaticSize.X
    local row = create("Frame", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = w,
    }, {
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
    })
    local function seg(text, color, o) return label(text, color, 11, row, { LayoutOrder = o }) end
    local function sep(o) return label("  //  ", THEME.TextDim, 11, row, { LayoutOrder = o }) end
    accent(seg(NAME, nil, 11, 1), "TextColor3")
    sep(2)
    seg("build: " .. BUILD, THEME.Text, 3)
    wmSegments.fps  = { sep = sep(4), lbl = seg("fps: 0", THEME.Text, 5) }
    wmSegments.ping = { sep = sep(6), lbl = seg("ping: 0", THEME.Text, 7) }
    wmSegments.time = { sep = sep(8), lbl = seg("00:00", THEME.Text, 9) }
    task.spawn(function()
        while w.Parent do
            wmSegments.fps.lbl.Text = "fps: " .. currentFps
            wmSegments.ping.lbl.Text = "ping: " .. getPing() .. "ms"
            wmSegments.time.lbl.Text = os.date("%H:%M:%S")
            for k, s in pairs(wmSegments) do
                local on = (k=="fps" and S.wmFps) or (k=="ping" and S.wmPing) or (k=="time" and S.wmTime)
                s.sep.Visible = on
                s.lbl.Visible = on
            end
            task.wait(0.5)
        end
    end)
end

--------------------------------------------------------------------
-- KEYBIND LIST
--------------------------------------------------------------------
do
    local win = makeWindow("Keybinds", UDim2.new(1, -190, 0, 120), UDim2.new(0, 170, 0, 0))
    win.AutomaticSize = Enum.AutomaticSize.Y
    accent(label("//", nil, 11, win, { Position = UDim2.new(0, 8, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 14, 0, 20) }), "TextColor3")
    label("keybinds", THEME.Text, 11, win, { Position = UDim2.new(0, 22, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -30, 0, 20) })
    local line = accent(create("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 1), Parent = win }), "BackgroundColor3")
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = line })
    local list = create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 23), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = win,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
        create("UIPadding", { PaddingBottom = UDim.new(0, 6) }),
    })
    local empty = label("no keys bound", THEME.TextDim, 10, list, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0 })
    local rows = {}
    refreshKeybindList = function()
        for _, r in ipairs(rows) do r:Destroy() end
        rows = {}
        local count = 0
        for i, b in ipairs(Bindings) do
            if b.key then
                count += 1
                local r = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = i, Parent = list })
                local active = b.active and b.active() or false
                label(b.name:lower(), active and THEME.Text or THEME.TextDim, 10, r, {
                    AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -52, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
                })
                label("[" .. keyName(b.key) .. "]", active and THEME.Accent or THEME.TextDim, 10, r, {
                    AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(1, -50, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
                })
                table.insert(rows, r)
            end
        end
        empty.Visible = count == 0
    end
    refreshKeybindList()
end

--------------------------------------------------------------------
-- PLAYER LIST
--------------------------------------------------------------------
do
    local win, content = makeWindow("Players", UDim2.new(1, -330, 0, 130), UDim2.new(0, 300, 0, 250), "Players", false)
    local list = create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = content,
    }, { create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
    accent(list, "ScrollBarImageColor3")
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local plrs = Players:GetPlayers()
        table.sort(plrs, function(a,b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        for i, p in ipairs(plrs) do
            local isMe = p==LocalPlayer
            local row = create("TextButton", {
                BackgroundColor3 = THEME.Element, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
                Size = UDim2.new(1, -4, 0, 18), LayoutOrder = i, Parent = list,
            })
            local s = accent(stroke(row, nil, 1, isMe and 0.2 or 0.7), "Color", true)
            label(p.DisplayName, isMe and THEME.Accent or THEME.Text, 11, row, {
                Position = UDim2.new(0, 6, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, -6, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
            })
            label("@" .. p.Name .. (p.Team and ("  " .. p.Team.Name) or ""), THEME.TextDim, 10, row, {
                AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            row.MouseEnter:Connect(function() s.Transparency=0 end)
            row.MouseLeave:Connect(function() s.Transparency=isMe and 0.2 or 0.7 end)
            row.MouseButton1Click:Connect(function()
                if type(setclipboard)=="function" then setclipboard(p.Name) Notify(NAME,"copied @"..p.Name,2) end
            end)
        end
    end
    bind(Players.PlayerAdded, function() task.defer(rebuild) end)
    bind(Players.PlayerRemoving, function() task.defer(rebuild) end)
    win:GetPropertyChangedSignal("Visible"):Connect(function() if win.Visible then rebuild() end end)
    rebuild()
end

--------------------------------------------------------------------
-- PERFORMANCE
--------------------------------------------------------------------
do
    local win, content = makeWindow("Perf", UDim2.new(1, -330, 0, 400), UDim2.new(0, 300, 0, 112), "Performance", false)
    local rows = {}
    local function statRow(name, i)
        local r = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 4 + (i-1)*16), Parent = content })
        label(name, THEME.TextDim, 11, r, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, 0, 1, 0) })
        local v = label("-", THEME.Text, 11, r, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
        rows[name]=v
    end
    statRow("fps",1) statRow("ping",2) statRow("memory",3) statRow("network in",4) statRow("network out",5)
    task.spawn(function()
        while win.Parent do
            if win.Visible then
                rows.fps.Text = tostring(currentFps)
                rows.ping.Text = getPing() .. " ms"
                rows.memory.Text = ("%d mb"):format(Stats:GetTotalMemoryUsageMb())
                local ok1,inK = pcall(function() return Stats.DataReceiveKbps end)
                local ok2,outK = pcall(function() return Stats.DataSendKbps end)
                rows["network in"].Text = ok1 and ("%.1f kb/s"):format(inK) or "-"
                rows["network out"].Text = ok2 and ("%.1f kb/s"):format(outK) or "-"
            end
            task.wait(0.5)
        end
    end)
end

--------------------------------------------------------------------
-- LUA CONSOLE
--------------------------------------------------------------------
do
    local _, content = makeWindow("Lua", UDim2.new(0.5, -200, 1, -280), UDim2.new(0, 400, 0, 230), "Lua Console", false)
    local editorFrame = create("Frame", {
        BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Size = UDim2.new(1, -8, 1, -34), Position = UDim2.new(0, 4, 0, 4), Parent = content,
    })
    accent(stroke(editorFrame, nil, 1, 0.4), "Color", true)
    local scroll = create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Parent = editorFrame,
    })
    accent(scroll, "ScrollBarImageColor3")
    local editor = create("TextBox", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Text = "", PlaceholderText = "-- write lua here", PlaceholderColor3 = THEME.TextDim, TextColor3 = THEME.Text,
        Font = THEME.Font, TextSize = 11, MultiLine = true, TextWrapped = true, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = scroll,
    }, { create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }) })
    local btns = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 1, -24), Parent = content,
    }, { create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -3, 0, 18), CellPadding = UDim2.new(0, 4, 0, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
    Button(btns, "Execute", function()
        local compile = loadstring or load
        if type(compile)~="function" then Notify(NAME,"loadstring unavailable",3) return end
        local fn, err = compile(editor.Text)
        if not fn then Notify("lua error", tostring(err):sub(1,60),5) return end
        local ok, rerr = pcall(fn)
        if ok then Notify(NAME,"executed",2) else Notify("lua error", tostring(rerr):sub(1,60),5) end
    end)
    Button(btns, "Clear", function() editor.Text="" end)
    Button(btns, "Copy", function()
        if type(setclipboard)=="function" then setclipboard(editor.Text) Notify(NAME,"copied to clipboard",2) end
    end)
end

--------------------------------------------------------------------
-- THEMES
--------------------------------------------------------------------
do
    local _, content = makeWindow("Themes", UDim2.new(1, -330, 0, 530), UDim2.new(0, 300, 0, 100), "Themes", false)
    local grid = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4), Parent = content,
    }, { create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -3, 0, 30), CellPadding = UDim2.new(0, 4, 0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
    for i, a in ipairs(ACCENTS) do
        local b = create("TextButton", {
            BackgroundColor3 = THEME.Element, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, Parent = grid,
        })
        local s = stroke(b, a[2], 1, 0.6)
        create("Frame", { BackgroundColor3 = a[2], BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, -8), Position = UDim2.new(0, 4, 0, 4), Parent = b })
        label(a[1]:lower(), THEME.Text, 11, b, { Position = UDim2.new(0, 14, 0, 0), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -18, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
        b.MouseEnter:Connect(function() s.Transparency=0 end)
        b.MouseLeave:Connect(function() s.Transparency=0.6 end)
        b.MouseButton1Click:Connect(function()
            local e = Registry["ui.accent"]
            if e then e.set(a[1]) changed("ui.accent") end
            Notify(NAME,"accent: "..a[1]:lower(),2)
        end)
    end
end

--------------------------------------------------------------------
-- TOP BAR TABS
--------------------------------------------------------------------
local TAB_ORDER = {
    { "Watermark", "watermark" }, { "Keybinds", "keybinds" }, { "Target", "target hud" }, { "Players", "players" },
    { "Perf", "perf" }, { "Lua", "lua" }, { "Themes", "themes" }, { "Config", "configs" },
}
local WINDOW_IDS = {
    Watermark="ui.watermark", Keybinds="ui.keybinds", Target="ui.target", Players="ui.players",
    Perf="ui.perf", Lua="ui.lua", Themes="ui.themes", Config="ui.config",
}
local tabButtons = {}
local function refreshTab(name)
    local btn, win = tabButtons[name], Windows[name]
    if not (btn and win) then return end
    TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = win.Visible and THEME.Accent or THEME.TextDim }):Play()
end
for i, info in ipairs(TAB_ORDER) do
    local name, text = info[1], info[2]
    local btn = create("TextButton", {
        BackgroundTransparency = 1, AutoButtonColor = false, Text = text, TextColor3 = THEME.TextDim,
        Font = THEME.Font, TextSize = 12, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = i*2, Parent = TabHolder,
    })
    tabButtons[name]=btn
    btn.MouseButton1Click:Connect(function()
        Windows[name].Visible = not Windows[name].Visible
        refreshTab(name)
    end)
    btn.MouseEnter:Connect(function() if not Windows[name].Visible then btn.TextColor3 = THEME.Text end end)
    btn.MouseLeave:Connect(function() refreshTab(name) end)
    if i < #TAB_ORDER then label("   /   ", THEME.TextDim, 12, TabHolder, { LayoutOrder = i*2+1 }) end
    refreshTab(name)
end
table.insert(Refreshers, function() for n in pairs(tabButtons) do refreshTab(n) end end)
for name, id in pairs(WINDOW_IDS) do
    local win = Windows[name]
    win:GetPropertyChangedSignal("Visible"):Connect(function()
        refreshTab(name)
        local e = Registry[id]
        if e and e.get() ~= win.Visible then e.set(win.Visible) changed(id) end
    end)
end

--------------------------------------------------------------------
-- Settings persistence
--------------------------------------------------------------------
saveSettings = function(silent)
    local ok, err = pcall(function()
        Storage.write("settings.json", HttpService:JSONEncode(collect(true)))
    end)
    if not silent then
        Notify(NAME, ok and "settings saved" or ("save failed: " .. tostring(err)), 3)
    end
end

--------------------------------------------------------------------
-- Input
--------------------------------------------------------------------
bind(UIS.InputBegan, function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if listening then
        local b = listening
        listening = nil
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
            b.key = nil
        else
            b.key = input.KeyCode
        end
        b.refresh()
        changed(b.id)
        return
    end
    if input.KeyCode == Enum.KeyCode.End then
        ScreenGui.Enabled = not ScreenGui.Enabled
        updateBlur()
        return
    end
    if gpe and not (MenuBinding and input.KeyCode == MenuBinding.key) then return end
    for _, b in ipairs(Bindings) do
        if b.key == input.KeyCode and b.fn then task.spawn(b.fn) end
    end
end)

--------------------------------------------------------------------
-- Clock
--------------------------------------------------------------------
task.spawn(function()
    while ScreenGui.Parent do
        Clock.Text = os.date("%I:%M %p  %m/%d/%Y")
        headerDate.Text = os.date("%d.%m.%Y")
        MenuHint.Text = ("[%s] menu"):format(MenuBinding and MenuBinding.key and keyName(MenuBinding.key) or "none")
        local count = 0
        for _, e in pairs(Registry) do if e.frame and e.tab==currentPage then count+=1 end end
        footerLeft.Text = ("tab: %s  //  %d options  //  %s"):format(
            (currentPage or "-"):lower(), count, hasFS and "storage: file" or "storage: memory")
        task.wait(1)
    end
end)
bind(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), function() task.defer(fitAll) end)


--------------------------------------------------------------------
-- ModuleManager v2 (Aurum-specific, menos generico, mas eficaz)
--------------------------------------------------------------------
-- Propuesta: en lugar de RegisterModule genérico, usamos DSL declarativo:
-- Aurum.Module("Visuals:MyESP", { Tab="Visuals", Section="My ESP", Config={Enabled=true}, OnInit=function(self) ... end })
-- Ventajas:
--   - Auto-crea Sección y registra Config schema para configs/settings
--   - Auto-maneja Enable/Disable lifecycle (conecta/desconecta loops)
--   - Auto-descubre archivos en Aurum/src/Modules/**/*.lua si el executor tiene filesystem
--   - Menos boilerplate: self:Toggle/Slider/Dropdown ya bindeados a Config

local ModuleManager = {}
ModuleManager._modules = {}
ModuleManager._order = {}

function ModuleManager.Define(id, def)
    assert(type(id)=="string" and id:find(":"), "Module id debe ser 'Tab:Nombre' ej: 'Visuals:MyESP'")
    assert(type(def)=="table", "def debe ser tabla")
    local tabName, modName = id:match("^([^:]+):(.+)$")
    def._id = id
    def._tab = tabName
    def._name = modName
    def.Config = def.Config or {}
    def.OnInit = def.OnInit or function() end
    def.OnEnable = def.OnEnable or function() end
    def.OnDisable = def.OnDisable or function() end
    -- helper para crear controles bindeados a Config
    function def:Toggle(parent, text, key, opts)
        opts = opts or {}
        opts.id = opts.id or (self._tab:lower().."."..self._name:lower().."."..key:lower():gsub("%s+","_"))
        -- si Config tiene default, úsalo
        if self.Config[key] ~= nil and opts.default == nil then opts.default = self.Config[key] end
        local entry = Toggle(parent, text, opts)
        -- sync Config <-> Registry
        local reg = Registry[opts.id]
        if reg then
            local origSet = reg.set
            reg.set = function(v) origSet(v) self.Config[key]=v end
        end
        return entry
    end
    function def:Slider(parent, text, key, min, max, defVal, opts)
        opts = opts or {}
        opts.id = opts.id or (self._tab:lower().."."..self._name:lower().."."..key:lower():gsub("%s+","_"))
        if self.Config[key] ~= nil and defVal == nil then defVal = self.Config[key] end
        return Slider(parent, text, min, max, defVal, opts)
    end
    function def:Dropdown(parent, text, key, options, defVal, opts)
        opts = opts or {}
        opts.id = opts.id or (self._tab:lower().."."..self._name:lower().."."..key:lower():gsub("%s+","_"))
        return Dropdown(parent, text, options, defVal, opts)
    end
    -- auto-sección: si no se provee parent, crea en Tab correspondiente
    function def:Section(title)
        local pages = Pages
        local tab = pages[self._tab]
        if not tab then error("Tab '"..self._tab.."' no existe. Tabs: Aim, Visuals, World, Player, Utility, Settings") end
        -- elige columna con menos altura (balancea)
        local leftH = tab.left.AbsoluteSize.Y
        local rightH = tab.right.AbsoluteSize.Y
        local col = leftH <= rightH and tab.left or tab.right
        return Section(col, title or self._name)
    end

    ModuleManager._modules[id] = def
    table.insert(ModuleManager._order, id)
    -- auto-init si la UI ya está lista (Pages existe)
    if Pages and Pages[def._tab] then
        local ok, err = pcall(def.OnInit, def)
        if not ok then warn("[aurum] Module "..id.." OnInit error: "..tostring(err)) end
        -- si Config.Enabled es true, llama OnEnable
        if def.Config.Enabled then pcall(def.OnEnable, def) end
    end
    return def
end

-- Auto-discovery filesystem (si el executor lo permite)
function ModuleManager.AutoLoadFromFS()
    if not hasFS then return end
    local root = FOLDER.."/src/Modules"
    if not isfolder(root) then return end
    for _, file in ipairs(listfiles(root)) do
        if file:match("%.lua$") then
            local ok, mod = pcall(function() return loadstring(readfile(file))() end)
            if ok and type(mod)=="table" and mod._id then
                print("[aurum] auto-loaded module "..mod._id.." from "..file)
            end
        end
    end
    -- recursivo una profundidad
    for _, folder in ipairs(listfiles(root)) do
        if isfolder(folder) then
            for _, file in ipairs(listfiles(folder)) do
                if file:match("%.lua$") then
                    pcall(function() loadstring(readfile(file))() end)
                end
            end
        end
    end
end

Aurum.Module = function(id, def) return ModuleManager.Define(id, def) end
Aurum.ModulesV2 = ModuleManager

-- Ejemplo (comentado) - cómo se vería un módulo NO genérico con este DSL:
--[[
Aurum.Module("Visuals:GunChams", {
    Config = { Enabled = false, Color = Color3.fromRGB(255, 80, 80), ThroughWalls = true },
    OnInit = function(self)
        local sec = self:Section("Gun Chams")
        self:Toggle(sec, "Enabled", "Enabled", { keybind=true, color=self.Config.Color })
        self:Toggle(sec, "Through Walls", "ThroughWalls")
        -- el resto de sliders/dropdowns...
    end,
    OnEnable = function(self)
        -- conecta RenderStepped
        self._conn = RunService.RenderStepped:Connect(function() ... end)
    end,
    OnDisable = function(self)
        if self._conn then self._conn:Disconnect() end
    end
})
--]]


--------------------------------------------------------------------
-- API Aurum
--------------------------------------------------------------------
function Aurum.CreateWindow(name, pos, size, title, visible) return makeWindow(name, pos, size, title, visible) end
function Aurum.Section(parent, title) return Section(parent, title) end
function Aurum.Toggle(parent, text, opts) return Toggle(parent, text, opts) end
function Aurum.Slider(parent, text, min, max, def, opts) return Slider(parent, text, min, max, def, opts) end
function Aurum.Dropdown(parent, text, opts, def, o) return Dropdown(parent, text, opts, def, o) end
function Aurum.Button(parent, text, cb, opts) return Button(parent, text, cb, opts) end
function Aurum.Keybind(parent, text, def, cb, opts) return Keybind(parent, text, def, cb, opts) end
function Aurum.Notify(...) return Notify(...) end
function Aurum.SetAccent(c) return setAccent(c) end
function Aurum.SetMenuOpen(v) return setMenuOpen(v) end
function Aurum.GetRegistry() return Registry end
function Aurum.GetWindows() return Windows end
function Aurum.GetPages() return Pages end
function Aurum.RegisterModule(mod)
    if not mod or not mod.Name then error("modulo requiere Name") end
    if Aurum.Modules[mod.Name] then warn("[aurum] modulo "..mod.Name.." ya existe, sobrescribiendo") end
    Aurum.Modules[mod.Name]=mod
    if type(mod.Init)=="function" then
        local ok, err = pcall(mod.Init, Aurum)
        if not ok then warn("[aurum] error init modulo "..mod.Name..": "..tostring(err)) Notify(NAME, "error modulo "..mod.Name, 4) else Notify(NAME, "modulo "..mod.Name.." cargado", 3) end
    end
end
function Aurum.Unload()
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _,c in ipairs(Aurum._featureConns) do pcall(function() c:Disconnect() end) end
    pcall(function() Blur:Destroy() end)
    pcall(function() ScreenGui:Destroy() end)
end
Aurum._unload = Aurum.Unload
getgenv().Aurum = Aurum
_G.Aurum = Aurum

--------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------
for _, mod in pairs(Aurum.Modules) do if type(mod.Init)=="function" then pcall(mod.Init, Aurum) end end

do
    local raw = Storage.read("settings.json")
    if raw then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and type(data)=="table" then apply(data) end
    end
    local al = Storage.read("autoload.txt")
    if al and al~="" then
        local cfg = Storage.read("configs/"..al..".json")
        if cfg then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, cfg)
            if ok and type(data)=="table" then
                apply(data)
                task.delay(0.6, function() Notify(NAME, "autoloaded config '"..al.."'", 4) end)
            end
        end
    end
end

setMenuOpen(true)
task.defer(fitAll)
refreshKeybindList()
task.delay(0.2, function()
    Notify(NAME, ("loaded v%s  //  [%s] toggles menu"):format(VERSION, MenuBinding.key and keyName(MenuBinding.key) or "none"), 5)
end)
print(("[%s] loaded v%s (%s) - menu: %s, hide all: END | executor: %s | drawing: %s | hookmm: %s"):format(NAME, VERSION, BUILD, MenuBinding.key and MenuBinding.key.Name or "none", tostring(executorName), tostring(hasDrawing), tostring(hasHookMM)))

return Aurum
