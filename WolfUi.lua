local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local function guiHost()
    local getters = {}
    if type(gethui) == "function" then
        getters[#getters + 1] = gethui
    end
    if type(get_hidden_gui) == "function" then
        getters[#getters + 1] = get_hidden_gui
    end
    getters[#getters + 1] = function() return game:GetService("CoreGui") end

    for _, getter in ipairs(getters) do
        local ok, host = pcall(getter)
        if ok and typeof(host) == "Instance" then
            local writable = pcall(function()
                local probe = Instance.new("Folder")
                probe.Name = "WolfUiProbe"
                probe.Parent = host
                probe:Destroy()
            end)
            if writable then return host, true end
        end
    end
    return playerGui, false
end

local Icons
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/AWLOID/Obscura/refs/heads/main/icons.lua"))()
    end)
    Icons = (ok and type(result) == "table") and result or {}
end

local function looksLikeSheet(sheet)
    if type(sheet) ~= "table" then return false end
    for _, data in pairs(sheet) do
        return type(data) == "table" and type(data[2]) == "table" and type(data[3]) == "table"
    end
    return false
end

local IconSheet = {}
do
    local order = {"48px", "24px", "16px"}
    for _, key in ipairs(order) do
        if looksLikeSheet(Icons[key]) then
            IconSheet = Icons[key]
            break
        end
    end
    if next(IconSheet) == nil then
        if looksLikeSheet(Icons) then
            IconSheet = Icons
        else
            for _, sheet in pairs(Icons) do
                if looksLikeSheet(sheet) then
                    IconSheet = sheet
                    break
                end
            end
        end
    end
end

local SIZE_INDEX, OFFSET_INDEX = 2, 3
do
    local seen = {[2] = {}, [3] = {}}
    local distinct = {[2] = 0, [3] = 0}
    local sampled = 0
    for _, data in pairs(IconSheet) do
        if type(data) == "table" and type(data[2]) == "table" and type(data[3]) == "table" then
            sampled = sampled + 1
            for _, index in ipairs({2, 3}) do
                local key = tostring(data[index][1]) .. "x" .. tostring(data[index][2])
                if not seen[index][key] then
                    seen[index][key] = true
                    distinct[index] = distinct[index] + 1
                end
            end
            if sampled >= 64 then break end
        end
    end
    if sampled > 1 and distinct[3] < distinct[2] then
        SIZE_INDEX, OFFSET_INDEX = 3, 2
    end
end

local function nameVariants(name)
    local lower = string.lower(name)
    local dashed = string.gsub(lower, "[%s_]", "-")
    local underscored = string.gsub(dashed, "%-", "_")
    local spaced = string.gsub(dashed, "%-", " ")
    local camel = string.gsub(dashed, "%-(%a)", function(c) return string.upper(c) end)
    local pascal = string.gsub(camel, "^%a", function(c) return string.upper(c) end)
    return {dashed, name, underscored, spaced, camel, pascal}
end

local function iconData(name)
    local data = IconSheet[name]
    if type(data) ~= "table" then return nil end
    local size, offset = data[SIZE_INDEX], data[OFFSET_INDEX]
    if type(size) ~= "table" or type(offset) ~= "table" then return nil end
    local asset = data[1]
    local image
    if type(asset) == "string" and string.find(asset, "://") then
        image = asset
    else
        image = "rbxassetid://" .. tostring(asset)
    end
    return image, Vector2.new(offset[1], offset[2]), Vector2.new(size[1], size[2])
end

local function resolveIcon(names)
    if type(names) == "string" then names = {names} end
    for _, name in ipairs(names or {}) do
        if type(name) == "string" then
            for _, variant in ipairs(nameVariants(name)) do
                local image, offset, size = iconData(variant)
                if image then return image, offset, size end
            end
        end
    end
    return nil
end

local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local Runtime = {Connections = {}, Updates = {}, Alive = false}

local function finite(value, fallback)
    local n = tonumber(value)
    if not n or n ~= n or math.abs(n) == math.huge then return fallback end
    return n
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    Runtime.Connections[#Runtime.Connections + 1] = connection
    return connection
end

local function step(callback)
    Runtime.Updates[#Runtime.Updates + 1] = {Callback = callback}
end

local function approach(a, b, k)
    return a + (b - a) * k
end

local function move(a, b, amount)
    if a < b then return math.min(a + amount, b) end
    return math.max(a - amount, b)
end

local function new(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function rect(parent, x, y, w, h, color, radius, class)
    local object = Instance.new(class or "Frame")
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(w, h)
    object.BorderSizePixel = 0
    object.BackgroundColor3 = color or white
    if object:IsA("TextButton") then
        object.Text = ""
        object.AutoButtonColor = false
        object.Font = Enum.Font.Gotham
        object.TextSize = 12
    end
    if radius and radius > 0 then
        new("UICorner", object, {CornerRadius = UDim.new(0, radius)})
    end
    object.Parent = parent
    return object
end

local function transparent(parent, x, y, w, h, class)
    local object = rect(parent, x, y, w, h, nil, nil, class)
    object.BackgroundTransparency = 1
    return object
end

local function text(parent, value, x, y, w, h, size, color, align, opts)
    opts = opts or {}
    local label = new("TextLabel", parent, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        Text = tostring(value or ""),
        Font = opts.Font or Enum.Font.Gotham,
        TextSize = size or 12,
        TextColor3 = color or white,
        TextXAlignment = (align == "center" and Enum.TextXAlignment.Center)
            or (align == "right" and Enum.TextXAlignment.Right)
            or Enum.TextXAlignment.Left,
        TextYAlignment = opts.Wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = opts.Wrap and true or false,
        TextTruncate = opts.Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        RichText = false,
        ZIndex = 2,
    })
    local api = {Object = label}
    function api:SetText(v) label.Text = tostring(v) end
    function api:GetText() return label.Text end
    function api:Color(v) label.TextColor3 = v end
    function api:Alpha(v) label.TextTransparency = 1 - v end
    function api:Width(v) label.Size = UDim2.fromOffset(v, label.Size.Y.Offset) end
    return api
end

local function iconLabel(parent, names, x, y, size, color, fallback)
    local image, offset, sheetSize = resolveIcon(names)
    local object, isImage
    if image then
        isImage = true
        object = new("ImageLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(size, size),
            Image = image,
            ImageRectOffset = offset,
            ImageRectSize = sheetSize,
            ImageColor3 = color or white,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
        })
    else
        isImage = false
        object = new("TextLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(size, size),
            Text = fallback or "*",
            Font = Enum.Font.GothamBold,
            TextSize = math.max(8, size - 4),
            TextColor3 = color or white,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2,
        })
    end
    local api = {Object = object, IsImage = isImage}
    function api:Color(v)
        if isImage then object.ImageColor3 = v else object.TextColor3 = v end
    end
    function api:Alpha(v)
        if isImage then object.ImageTransparency = 1 - v else object.TextTransparency = 1 - v end
    end
    return api
end

local themes = {
    {{15, 15, 18}, {17, 17, 21}, {92, 95, 122}, {20, 20, 25}, {22, 22, 28}, {50, 50, 65}},
    {{26, 26, 30}, {31, 31, 36}, {128, 128, 143}, {36, 36, 42}, {40, 40, 46}, {70, 70, 90}},
    {{8, 8, 8}, {10, 10, 10}, {150, 150, 150}, {15, 15, 15}, {22, 22, 22}, {50, 50, 50}},
}
for _, theme in ipairs(themes) do
    for i, rgb in ipairs(theme) do
        theme[i] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
end

local palette = {}
for i, color in ipairs(themes[1]) do palette[i] = color end

local accent = Color3.fromRGB(126, 139, 209)

local function paint(object, index)
    object.BackgroundColor3 = palette[index]
    step(function() object.BackgroundColor3 = palette[index] end)
    return object
end

local function muted(parent, value, x, y, w, h, size, align, opts)
    local api = text(parent, value, x, y, w, h, size, palette[3], align, opts)
    step(function() api:Color(palette[3]) end)
    return api
end

local WINDOW_W, WINDOW_H = 590, 350
local SIDEBAR_W, RAIL_W = 70, 30
local CONTENT_W = WINDOW_W - SIDEBAR_W - RAIL_W 
local PAD = 10
local W = CONTENT_W - PAD * 3 
local GAP = 10
local TAB_SLOT = 70

local Library = {
    Version = "3.0.0",
    Flags = {},
    Elements = {},
    Themes = themes,
    ThemeNames = {"Wolf", "Slate", "Black"},
    ScaleOptions = {100, 75, 50},
    Theme = 1,
    Scale = 100,
    Accent = accent,
    AccentAlpha = 1,
    Window = nil,
}

local state = {
    Theme = 1,
    Tab = nil,
    Scale = 100,
    Accent = accent,
    AccentAlpha = 1,
}

local changeListeners = {}
local unloadListeners = {}

local function attributeName(key)
    local name = string.gsub(tostring(key), "[^%w_]", "_")
    if string.match(name, "^%d") then name = "_" .. name end
    return name
end

local function fireChange(flag, value)
    Library.Flags[flag] = value
    local window = Library.Window
    if window then
        if type(value) ~= "table" and typeof(value) ~= "EnumItem" then
            local key = attributeName(flag)
            pcall(function() window.Gui:SetAttribute(key, value) end)
            if window.Events then
                pcall(function() window.Events:SetAttribute(key, value) end)
            end
        end
        window.Changed:Fire(flag, value)
    end
    for _, listener in ipairs(changeListeners) do
        task.spawn(listener, flag, value)
    end
end

function Library:OnChange(callback)
    changeListeners[#changeListeners + 1] = callback
end

function Library:OnUnload(callback)
    unloadListeners[#unloadListeners + 1] = callback
end

function Library:SetFlag(flag, value)
    local element = self.Elements[flag]
    if element and element.Set then
        element:Set(value)
    else
        fireChange(flag, value)
    end
end

function Library:GetFlag(flag)
    return self.Flags[flag]
end

function Library:SetTheme(index)
    index = math.clamp(math.floor(finite(index, 1)), 1, #themes)
    state.Theme = index
    self.Theme = index
    fireChange("Theme", index)
end

function Library:SetAccent(color, alpha)
    if typeof(color) == "Color3" then
        state.Accent = color
        self.Accent = color
        fireChange("Accent", color)
    end
    if alpha ~= nil then
        alpha = math.clamp(finite(alpha, state.AccentAlpha), 0, 1)
        state.AccentAlpha = alpha
        self.AccentAlpha = alpha
        fireChange("AccentAlpha", alpha)
    end
end

local function snapScale(value)
    value = finite(value, 100)
    local best, delta = Library.ScaleOptions[1], math.huge
    for _, option in ipairs(Library.ScaleOptions) do
        local d = math.abs(option - value)
        if d < delta then best, delta = option, d end
    end
    return best
end

local KEY_SHORT = {
    LeftShift = "LSHIFT", RightShift = "RSHIFT",
    LeftControl = "LCTRL", RightControl = "RCTRL",
    LeftAlt = "LALT", RightAlt = "RALT",
    CapsLock = "CAPS", Backspace = "BACK", Return = "ENTER",
    Space = "SPACE", Escape = "ESC", Delete = "DEL",
    PageUp = "PGUP", PageDown = "PGDN", Insert = "INS",
    MouseButton1 = "MOUSE1", MouseButton2 = "MOUSE2", MouseButton3 = "MOUSE3",
}

local function keyName(key)
    if key == nil then return "NONE" end
    if typeof(key) == "EnumItem" then
        local name = KEY_SHORT[key.Name] or key.Name
        return string.upper(name)
    end
    return "NONE"
end

local function keyFromName(name)
    if type(name) ~= "string" or name == "" or string.upper(name) == "NONE" then return nil end
    local upper = string.upper(name)
    for full, short in pairs(KEY_SHORT) do
        if upper == short or upper == string.upper(full) then name = full; break end
    end
    for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
        if string.upper(item.Name) == upper then return item end
    end
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    if ok and key then return key end
    ok, key = pcall(function() return Enum.UserInputType[name] end)
    if ok and key then return key end
    return nil
end

local Tab = {}
Tab.__index = Tab

local Window = {}
Window.__index = Window

local function createPopup(window, anchor, w, h, animateHeight)
    local object = rect(window.PopupLayer, 0, 0, w, h, palette[1], 5, "CanvasGroup")
    object.Name = "Popup"
    object.Visible = false
    object.Active = true
    object.ClipsDescendants = true
    object.GroupTransparency = 1

    local data = {
        Object = object,
        Anchor = anchor,
        Width = w,
        Height = h,
        Alpha = 0,
        CurrentHeight = animateHeight and 1 or h,
        AnimateHeight = animateHeight and true or false,
    }
    window.Popups[#window.Popups + 1] = data

    function data:Open(anchorOverride)
        if anchorOverride then self.Anchor = anchorOverride end
        window.Opened = self
    end
    function data:Close()
        if window.Opened == self then window.Opened = nil end
    end
    function data:Toggle(anchorOverride)
        if window.Opened == self then
            window.Opened = nil
        else
            self:Open(anchorOverride)
        end
    end
    return data
end

function Library:CreateWindow(opts)
    opts = opts or {}

    if Library.Window then
        Library:Unload()
    end

    Runtime.Connections, Runtime.Updates, Runtime.Alive = {}, {}, true
    Library:SetScriptName(opts.Folder or opts.ScriptName or opts.Name)

    local previous = playerGui:FindFirstChild(opts.GuiName or "WolfUI")
    if previous then previous:Destroy() end

    state.Theme = math.clamp(math.floor(finite(opts.Theme, 1)), 1, #themes)
    state.Scale = snapScale(opts.Scale or 100)
    state.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or Color3.fromRGB(126, 139, 209)
    state.AccentAlpha = math.clamp(finite(opts.AccentAlpha, 1), 0, 1)
    state.Tab = nil
    accent = state.Accent
    for i, color in ipairs(themes[state.Theme]) do palette[i] = color end
    Library.Theme, Library.Scale = state.Theme, state.Scale
    Library.Accent, Library.AccentAlpha = state.Accent, state.AccentAlpha

    local window = setmetatable({
        Tabs = {},
        TabList = {},
        Popups = {},
        Opened = nil,
        Keybinds = {},
        Notifications = {},
        Current = nil,
        RailCount = 0,
        Drag = nil,
        Position = Vector2.new(0, 0),
        Viewport = Vector2.new(1280, 720),
        Initialized = false,
        BoundToScreen = opts.BoundToScreen == true,
        SettingsPanels = {},
        SettingsStack = {},
    }, Window)
    Library.Window = window

    local host, protected = guiHost()
    if host ~= playerGui then
        local stale = host:FindFirstChild(opts.GuiName or "WolfUI")
        if stale then stale:Destroy() end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = opts.GuiName or "WolfUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = opts.DisplayOrder or 10000
    
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(function() syn.protect_gui(gui) end)
    elseif type(protectgui) == "function" then
        pcall(function() protectgui(gui) end)
    end
    gui.Parent = host

    window.Gui = gui
    window.Host = host
    window.Protected = protected

    local events = new("Folder", playerGui, {Name = opts.GuiName or "WolfUI"})
    window.Events = events
    window.Changed = new("BindableEvent", events, {Name = "Changed"})
    window.TabChanged = new("BindableEvent", events, {Name = "TabChanged"})
    window.ButtonPressed = new("BindableEvent", events, {Name = "ButtonPressed"})

    local frame = paint(rect(gui, 0, 0, WINDOW_W, WINDOW_H, palette[1], 5), 1)
    frame.Name = "Window"
    frame.Active = true
    frame.ClipsDescendants = true
    window.Frame = frame

    local scale = new("UIScale", frame, {Scale = 1})
    window.UIScale = scale

    local popupLayer = transparent(gui, 0, 0, WINDOW_W, WINDOW_H)
    popupLayer.Name = "Popups"
    popupLayer.ZIndex = 10
    window.PopupLayer = popupLayer
    window.PopupScale = new("UIScale", popupLayer, {Scale = 1})

    local function layout()
        local camera = workspace.CurrentCamera
        if camera then
            window.Viewport = camera.ViewportSize
            window.CameraViewport = camera.ViewportSize
        end
        local viewport = gui.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then viewport = window.Viewport end
        window.Viewport = viewport
        local s = math.min(state.Scale / 100, (viewport.X - 16) / WINDOW_W, (viewport.Y - 16) / WINDOW_H)
        s = math.max(0.01, math.min(1, s))
        scale.Scale = s
        window.PopupScale.Scale = s
        if not window.Initialized then
            window.Position = (viewport - Vector2.new(WINDOW_W * s, WINDOW_H * s)) / 2
            window.Initialized = true
        end
        if window.BoundToScreen then
            window.Position = Vector2.new(
                math.clamp(window.Position.X, 0, math.max(0, viewport.X - WINDOW_W * s)),
                math.clamp(window.Position.Y, 0, math.max(0, viewport.Y - WINDOW_H * s))
            )
        end
        frame.Position = UDim2.fromOffset(window.Position.X, window.Position.Y)
        popupLayer.Position = frame.Position
        if window.LayoutAccess then window:LayoutAccess() end
    end
    window.Layout = layout
    layout()

    local function primary(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function finishDrag(cancelled)
        local drag = window.Drag
        if not drag then return end
        window.Drag = nil
        if drag.StateConnection then drag.StateConnection:Disconnect() end
        for scroll, enabled in pairs(drag.Scrolls) do
            if scroll.Parent then scroll.ScrollingEnabled = enabled end
        end
        if drag.Finish then task.spawn(drag.Finish, cancelled == true, drag) end
    end
    window.CancelDrag = function() finishDrag(true) end

    local function draggable(object, onMove, onEnd, options)
        options = options or {}
        object.Active = true
        local began = connect(object.InputBegan, function(input)
            if not primary(input) or window.Drag or (not frame.Visible and not options.Always) then return end
            if options.CanStart and not options.CanStart(input) then return end
            local scrolls = {}
            local parent = object.Parent
            while parent and parent ~= gui do
                if parent:IsA("ScrollingFrame") then
                    scrolls[parent] = parent.ScrollingEnabled
                    parent.ScrollingEnabled = false
                end
                parent = parent.Parent
            end
            local drag = {Input = input, Object = object, Move = onMove, Finish = onEnd, Scrolls = scrolls}
            window.Drag = drag
            drag.StateConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
                if window.Drag ~= drag then return end
                if input.UserInputState == Enum.UserInputState.Cancel then finishDrag(true) end
            end)
            onMove(Vector2.new(input.Position.X, input.Position.Y), true)
        end)
        local destroyed = connect(object.Destroying, function()
            if window.Drag and window.Drag.Object == object then finishDrag(true) end
        end)
        return {began, destroyed}
    end
    window.Draggable = draggable

    connect(UIS.InputChanged, function(input)
        local drag = window.Drag
        if not drag then return end
        if not drag.Object.Parent then finishDrag(true); return end
        local same = input == drag.Input
        local mouse = drag.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if same or mouse then
            drag.Move(Vector2.new(input.Position.X, input.Position.Y), false)
        end
    end)

    connect(UIS.InputEnded, function(input)
        local drag = window.Drag
        if not drag then return end
        local same = input == drag.Input
        local mouse = drag.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1
        if same or mouse then
            local point = mouse and UIS:GetMouseLocation() or Vector2.new(input.Position.X, input.Position.Y)
            drag.Move(point, false)
            finishDrag(false)
        end
    end)

    connect(UIS.WindowFocusReleased, function() finishDrag(true) end)

    local sidebar = paint(rect(frame, 0, 0, SIDEBAR_W, WINDOW_H, palette[2]), 2)
    sidebar.Name = "Sidebar"
    window.Sidebar = sidebar

    local logoHit = transparent(sidebar, 0, 0, SIDEBAR_W, TAB_SLOT, "TextButton")
    local logoIcon = iconLabel(logoHit, opts.Icon or {"dog", "paw-print", "moon"},
        (SIDEBAR_W - 22) / 2, 24, 22, accent, string.sub(opts.Name or "W", 1, 1))
    step(function()
        logoIcon:Color(accent)
        logoIcon:Alpha(state.AccentAlpha)
    end)

    local dragStart, windowStart
    draggable(logoHit, function(point, initial)
        if initial then
            dragStart = point
            windowStart = window.Position
        end
        window.Position = windowStart + point - dragStart
        layout()
        windowStart = window.Position
        dragStart = point
    end)

    local tabHolder = new("ScrollingFrame", sidebar, {
        Name = "Tabs",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, TAB_SLOT),
        Size = UDim2.fromOffset(SIDEBAR_W, WINDOW_H - TAB_SLOT),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        Active = true,
    })
    window.TabHolder = tabHolder

    local scroll = new("ScrollingFrame", frame, {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(SIDEBAR_W, 0),
        Size = UDim2.fromOffset(CONTENT_W, WINDOW_H),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 10,
        ScrollBarImageColor3 = palette[4],
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        Active = true,
    })
    window.Scroll = scroll
    step(function() scroll.ScrollBarImageColor3 = palette[4] end)

    local rail = transparent(frame, WINDOW_W - RAIL_W, 0, RAIL_W, WINDOW_H)
    rail.Name = "Rail"
    window.Rail = rail

    local function inside(point, object)
        if not object then return false end
        local p, s = object.AbsolutePosition, object.AbsoluteSize
        return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
    end

    connect(UIS.InputBegan, function(input)
        if primary(input) and window.Opened then
            local point = Vector2.new(input.Position.X, input.Position.Y)
            if not inside(point, window.Opened.Object) and not inside(point, window.Opened.Anchor) then
                window.Opened = nil
            end
        end
    end)
    connect(scroll:GetPropertyChangedSignal("CanvasPosition"), function() window.Opened = nil end)

    function window:AddRailButton(config)
        config = config or {}
        local y = 10 + self.RailCount * 20
        self.RailCount = self.RailCount + 1
        local hit = transparent(rail, 10, y, 10, 10, "TextButton")
        local icon = iconLabel(hit, config.Icon or {"circle"}, 0, 0, 10, palette[3], config.Fallback or "*")
        local hover, tint = false, palette[3]
        connect(hit.MouseEnter, function() hover = true end)
        connect(hit.MouseLeave, function() hover = false end)
        step(function(dt, k)
            tint = tint:Lerp(hover and white or palette[3], k)
            icon:Color(tint)
        end)
        if config.Callback then
            connect(hit.Activated, function() config.Callback(hit) end)
        end
        return hit
    end

    local themeButton = window:AddRailButton({
        Icon = {"sun-moon", "sun", "palette", "moon"},
        Fallback = "T",
        Callback = function()
            Library:SetTheme(state.Theme % #themes + 1)
        end,
    })

    local settingsButton = window:AddRailButton({
        Icon = {"settings", "settings-2", "sliders-horizontal"},
        Fallback = "S",
    })

    local settingsPopup = createPopup(window, settingsButton, 200, 72, false)
    muted(settingsPopup.Object, "Menu scale", 10, 6, 180, 14, 11)
    local scaleButtons = {}
    for index, option in ipairs(Library.ScaleOptions) do
        local x = 10 + (index - 1) * 63
        local button = paint(rect(settingsPopup.Object, x, 26, 54, 31, palette[4], 3, "TextButton"), 4)
        local caption = text(button, tostring(option) .. "%", 0, 0, 54, 31, 11, palette[3], "center")
        connect(button.Activated, function()
            window:SetScale(option)
        end)
        local hover, a, tint = false, 0, palette[3]
        connect(button.MouseEnter, function() hover = true end)
        connect(button.MouseLeave, function() hover = false end)
        step(function(dt, k)
            local active = state.Scale == option
            a = approach(a, active and 1 or 0, k)
            button.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 1 or 0)
            tint = tint:Lerp(active and white or palette[3], k)
            caption:Color(tint)
        end)
        scaleButtons[index] = button
    end
    connect(settingsButton.Activated, function() settingsPopup:Toggle(settingsButton) end)

    window:InitializeAccess(opts)

    local notifyHolder = transparent(gui, 0, 0, 250, WINDOW_H)
    notifyHolder.Name = "Notifications"
    notifyHolder.Position = UDim2.new(1, -258, 0, 8)
    notifyHolder.Size = UDim2.new(0, 250, 1, -16)
    notifyHolder.ZIndex = 30
    window.NotifyHolder = notifyHolder

    connect(UIS.InputBegan, function(input, processed)
        
        if window.PendingKeybind then
            local pending = window.PendingKeybind
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                    pending:Set(nil)
                else
                    pending:Set(input.KeyCode)
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                pending:Set(input.UserInputType)
            else
                return
            end
            window.PendingKeybind = nil
            return
        end

        if processed or UIS:GetFocusedTextBox() then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            if window.Opened then window.Opened = nil; return end
            local panel = window.SettingsStack[#window.SettingsStack]
            if panel then panel:Close(); return end
        end

        local hit = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
        for _, bind in ipairs(window.Keybinds) do
            if bind.Key ~= nil and bind.Key == hit then
                bind:Fire()
            end
        end

        if input.KeyCode == (window.ToggleKey or Enum.KeyCode.RightShift) then
            window:SetVisible(not frame.Visible)
        elseif input.KeyCode == Enum.KeyCode.F1 or input.KeyCode == Enum.KeyCode.F2 then
            local options = Library.ScaleOptions
            local sorted = {}
            for _, option in ipairs(options) do sorted[#sorted + 1] = option end
            table.sort(sorted)
            local current = 1
            for i, option in ipairs(sorted) do
                if option == state.Scale then current = i end
            end
            local target = sorted[math.clamp(current + (input.KeyCode == Enum.KeyCode.F1 and 1 or -1), 1, #sorted)]
            window:SetScale(target)
        end
    end)

    window.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

    connect(gui.Destroying, function()
        if Library.Window == window then Library:Unload() end
    end)
    connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
        window.CancelDrag()
        layout()
    end)

    local fps, fpsTimer, fpsFrames = 60, 0, 0

    connect(RunService.RenderStepped, function(dt)
        if not Runtime.Alive then return end
        local elapsed = dt
        dt = math.min(dt, 0.1)
        local k = 1 - math.exp(-24 * dt)

        local theme = themes[state.Theme] or themes[1]
        for i, target in ipairs(theme) do
            palette[i] = palette[i]:Lerp(target, k)
        end
        accent = accent:Lerp(state.Accent, k)

        fpsFrames = fpsFrames + 1
        fpsTimer = fpsTimer + elapsed
        if fpsTimer >= 0.5 then
            for i = #Runtime.Connections, 1, -1 do
                if not Runtime.Connections[i].Connected then table.remove(Runtime.Connections, i) end
            end
            fps = math.floor(fpsFrames / fpsTimer + 0.5)
            fpsFrames, fpsTimer = 0, 0
        end

        local camera = workspace.CurrentCamera
        if camera and camera.ViewportSize ~= window.CameraViewport then
            window.CancelDrag()
            layout()
        end

        window:UpdateAccess(fps, elapsed)

        for index = #window.Notifications, 1, -1 do
            local notif = window.Notifications[index]
            notif.Life = notif.Life - elapsed
            local target = (notif.Life > 0) and 1 or 0
            notif.Alpha = move(notif.Alpha, target, 5 * dt)
            notif.Object.GroupTransparency = 1 - notif.Alpha
            notif.Object.BackgroundColor3 = palette[2]
            notif.Bar.BackgroundColor3 = accent
            notif.Icon:Color(accent)
            notif.Object.Position = UDim2.fromOffset(math.floor(260 * (1 - notif.Alpha) + 0.5), notif.Y)
            if notif.Life <= 0 and notif.Alpha <= 0.01 then
                notif.Object:Destroy()
                table.remove(window.Notifications, index)
            end
        end
        local offset = 0
        for _, notif in ipairs(window.Notifications) do
            notif.Y = offset
            offset = offset + notif.Height + 8
        end

        if not frame.Visible then
            return
        end

        for _, update in ipairs(Runtime.Updates) do
            if not update.Owner or update.Owner.Parent then
                update.Callback(dt, k)
            end
        end

        for _, tab in ipairs(window.TabList) do
            local active = window.Current == tab
            tab.Alpha = move(tab.Alpha, active and 1 or 0, 8 * dt)
            local page = tab.Page
            page.Visible = active
            if page.Visible then
                page.GroupTransparency = 1 - tab.Alpha
            end
        end

        for _, pop in ipairs(window.Popups) do
            local show = window.Opened == pop
            pop.Alpha = move(pop.Alpha, show and 1 or 0, 9 * dt)
            if pop.AnimateHeight then
                pop.CurrentHeight = approach(pop.CurrentHeight, show and pop.Height or 1, math.min(16 * dt, 1))
            else
                pop.CurrentHeight = pop.Height
            end
            local object = pop.Object
            object.Visible = pop.Alpha > 0.01 and pop.Anchor ~= nil and pop.Anchor.Parent ~= nil
            object.GroupTransparency = 1 - pop.Alpha
            object.BackgroundColor3 = palette[1]
            object.Size = UDim2.fromOffset(pop.Width, math.max(1, pop.CurrentHeight))
            if object.Visible then
                local s = math.max(0.001, window.PopupScale.Scale)
                local origin = (pop.Anchor.AbsolutePosition - popupLayer.AbsolutePosition) / s
                local minX, minY = -window.Position.X / s, -window.Position.Y / s
                local maxX = (window.Viewport.X - window.Position.X) / s - pop.Width
                local maxY = (window.Viewport.Y - window.Position.Y) / s - pop.Height
                object.Position = UDim2.fromOffset(
                    math.clamp(origin.X, minX, math.max(minX, maxX)),
                    math.clamp(origin.Y, minY, math.max(minY, maxY))
                )
            end
        end
    end)

    return window
end

function Window:SetVisible(value)
    if Library.Window ~= self or not self.Gui.Parent then return end
    self.Frame.Visible = value and true or false
    self.PopupLayer.Visible = self.Frame.Visible
    if not self.Frame.Visible then
        self.Opened = nil
        self.CancelDrag()
        self.PendingKeybind = nil
        self:CloseSettings()
    end
    self:LayoutAccess()
end

function Window:SetScale(value)
    local snapped = snapScale(value)
    state.Scale = snapped
    Library.Scale = snapped
    self.CancelDrag()
    self.Layout()
    fireChange("Scale", snapped)
    return snapped
end

function Window:SetTheme(index)
    Library:SetTheme(index)
end

function Window:SelectTab(name)
    local tab = type(name) == "table" and name or self.Tabs[name]
    if not tab or self.Current == tab then return end
    if tab.Window ~= self then return end
    self.CancelDrag()
    self:CloseSettings()
    self.Opened = nil
    if self.Current then self.Current.Page.Visible = false end
    self.Current = tab
    tab.Page.Visible = true
    state.Tab = tab.Name
    self.Scroll.CanvasSize = UDim2.fromOffset(0, tab.Height + PAD * 2)
    self.Scroll.CanvasPosition = Vector2.new(0, 0)
    fireChange("Tab", tab.Name)
    self.TabChanged:Fire(tab.Name)
end

function Window:CreateTab(opts)
    opts = opts or {}
    local name = opts.Name or ("Tab" .. tostring(#self.TabList + 1))
    assert(not self.Tabs[name], "Duplicate tab name: " .. tostring(name))
    local index = #self.TabList + 1

    local page = new("CanvasGroup", self.Scroll, {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(PAD, PAD),
        Size = UDim2.fromOffset(W, 1),
        Visible = false,
        GroupTransparency = 1,
    })

    local tab = setmetatable({
        Name = name,
        Title = opts.Title or name,
        Window = self,
        Page = page,
        Alpha = 0,
        Height = 0,
        Cursor = {X = 0, Y = 0, RowHeight = 0},
        Elements = {},
    }, Tab)

    self.Tabs[name] = tab
    self.TabList[index] = tab

    local top = (index - 1) * TAB_SLOT
    local hit = rect(self.TabHolder, 0, top, SIDEBAR_W, TAB_SLOT, palette[4], nil, "TextButton")
    hit.Name = name
    hit.BackgroundTransparency = 1
    local icon = iconLabel(hit, opts.Icon or {"circle"}, (SIDEBAR_W - 16) / 2, 21.6, 16, palette[3],
        opts.Fallback or string.sub(name, 1, 1))
    local title = text(hit, opts.Title or name, 0, 41.3, SIDEBAR_W, 15, 11, palette[3], "center")
    self.TabHolder.CanvasSize = UDim2.fromOffset(0, index * TAB_SLOT)

    connect(hit.Activated, function() self:SelectTab(tab) end)

    local alpha, tint = 0, palette[3]
    step(function(dt, k)
        local active = self.Current == tab
        alpha = approach(alpha, active and 1 or 0, k)
        tint = tint:Lerp(active and accent or palette[3], k)
        hit.BackgroundColor3 = palette[4]
        hit.BackgroundTransparency = 1 - alpha
        icon:Color(tint)
        title:Color(tint)
        icon:Alpha(1 - alpha * (1 - state.AccentAlpha))
        title:Alpha(1 - alpha * (1 - state.AccentAlpha))
    end)

    tab.Button = hit

    if not self.Current then
        self:SelectTab(tab)
    end
    return tab
end

function Window:Destroy()
    if Library.Window == self then Library:Unload() end
end

function Window:Center()
    self.CancelDrag()
    self.Initialized = false
    self.Layout()
end

function Window:SetPosition(x, y)
    self.CancelDrag()
    self.Position = Vector2.new(finite(x, self.Position.X), finite(y, self.Position.Y))
    self.Layout()
end

function Tab:_width(value)
    local width = self.ContentWidth or W
    local fraction = finite(value, 1)
    if fraction <= 0 or fraction >= 1 then return width end
    local columns = math.max(1, math.floor(1 / fraction + 0.5))
    return math.min(width, math.max(105, math.floor((width - GAP * (columns - 1)) / columns)))
end

function Tab:_place(w, h)
    local width = self.ContentWidth or W
    local cursor = self.Cursor
    if cursor.X > 0 and cursor.X + w > width + 0.5 then
        cursor.Y = cursor.Y + cursor.RowHeight + GAP
        cursor.X = 0
        cursor.RowHeight = 0
    end
    local x, y = cursor.X, cursor.Y
    cursor.X = cursor.X + w + GAP
    cursor.RowHeight = math.max(cursor.RowHeight, h)
    if cursor.X >= width then
        cursor.Y = cursor.Y + cursor.RowHeight + GAP
        cursor.X = 0
        cursor.RowHeight = 0
    end
    return x, y
end

function Tab:_newline()
    local cursor = self.Cursor
    if cursor.X > 0 then
        cursor.Y = cursor.Y + cursor.RowHeight + GAP
        cursor.X = 0
        cursor.RowHeight = 0
    end
end

function Tab:_grow()
    if self.Reflowing or not self.Page.Parent then return end
    self.Reflowing = true
    self.LayoutItems = self.LayoutItems or {}
    self.LayoutSeen = self.LayoutSeen or setmetatable({}, {__mode = "k"})
    for _, item in ipairs(self.Page:GetChildren()) do
        if item:IsA("GuiObject") and not self.LayoutSeen[item] then
            self.LayoutSeen[item] = true
            self.LayoutItems[#self.LayoutItems + 1] = item
            connect(item:GetPropertyChangedSignal("Visible"), function() self:_grow() end)
            connect(item:GetPropertyChangedSignal("Size"), function() self:_grow() end)
        end
    end
    self.Cursor = {X = 0, Y = 0, RowHeight = 0}
    local height = 0
    for i = #self.LayoutItems, 1, -1 do
        if self.LayoutItems[i].Parent ~= self.Page then table.remove(self.LayoutItems, i) end
    end
    for _, item in ipairs(self.LayoutItems) do
        if item.Visible then
            local x, y = self:_place(item.Size.X.Offset, item.Size.Y.Offset)
            item.Position = UDim2.fromOffset(x, y)
            height = math.max(height, y + item.Size.Y.Offset)
        end
    end
    self.Height = height
    self.Page.Size = UDim2.fromOffset(self.ContentWidth or W, math.max(1, height))
    if self.Scroll then
        self.Scroll.CanvasSize = UDim2.fromOffset(0, height + PAD * 2)
    elseif self.Window.Current == self then
        self.Window.Scroll.CanvasSize = UDim2.fromOffset(0, height + PAD * 2)
    end
    self.Reflowing = false
    if self.OnGrow then self:OnGrow(height) end
end

function Tab:_card(w, h, name)
    local x, y = self:_place(w, h)
    local card = paint(rect(self.Page, x, y, w, h, palette[2], 5), 2)
    card.Name = name or "Element"
    self:_grow()
    return card
end

local function baseApi(tab, card, flag)
    local api = {Object = card, Flag = flag, Tab = tab}
    function api:SetVisible(value) card.Visible = value and true or false end
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        card:Destroy()
        tab:_grow()
    end
    if flag then
        Library.Elements[flag] = api
    end
    tab.Elements[#tab.Elements + 1] = api
    return api
end

function Tab:AddSection(nameOrOpts)
    local opts = type(nameOrOpts) == "table" and nameOrOpts or {Name = nameOrOpts}
    self:_newline()
    local width = self.ContentWidth or W
    local x, y = self:_place(width, 16)
    local api = muted(self.Page, string.upper(tostring(opts.Name or "Section")), x, y, width, 16, 11, nil,
        {Font = Enum.Font.GothamBold})
    self:_newline()
    self:_grow()
    return api
end

function Tab:AddDivider()
    self:_newline()
    local width = self.ContentWidth or W
    local x, y = self:_place(width, 1)
    local line = paint(rect(self.Page, x, y + 0, width, 1, palette[4]), 4)
    self:_newline()
    self:_grow()
    return {Object = line}
end

function Tab:AddLabel(opts)
    opts = type(opts) == "table" and opts or {Text = opts}
    local w = self:_width(opts.Width)
    local x, y = self:_place(w, 16)
    local api
    if opts.Muted then
        api = muted(self.Page, opts.Text or "", x, y, w, 16, opts.Size or 12, opts.Align)
    else
        api = text(self.Page, opts.Text or "", x, y, w, 16, opts.Size or 12, white, opts.Align)
    end
    self:_grow()
    return api
end

function Tab:AddParagraph(opts)
    opts = opts or {}
    local w = self:_width(opts.Width)
    local body = tostring(opts.Text or "")
    local bounds = TextService:GetTextSize(body, 11, Enum.Font.Gotham, Vector2.new(w - 20, 10000))
    local hasTitle = opts.Name ~= nil
    local height = (hasTitle and 28 or 10) + math.max(14, bounds.Y) + 10
    local card = self:_card(w, height, opts.Name or "Paragraph")
    if hasTitle then
        text(card, opts.Name, 10, 10, w - 20, 14, 12, white)
    end
    local paragraph = muted(card, body, 10, hasTitle and 28 or 10, w - 20, math.max(14, bounds.Y), 11, nil, {Wrap = true})
    local api = baseApi(self, card, nil)
    function api:SetText(value)
        local bodyText = tostring(value or "")
        local measured = TextService:GetTextSize(bodyText, 11, Enum.Font.Gotham, Vector2.new(w - 20, 10000))
        local bodyHeight = math.max(14, measured.Y)
        paragraph:SetText(bodyText)
        paragraph.Object.Size = UDim2.fromOffset(w - 20, bodyHeight)
        card.Size = UDim2.fromOffset(w, (hasTitle and 28 or 10) + bodyHeight + 10)
        self.Tab:_grow()
    end
    return api
end

local function toHex(color)
    return string.format("%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
end

local function fromHex(value)
    if type(value) ~= "string" then return nil end
    local hex = string.gsub(value, "[^%x]", "")
    if #hex == 3 then
        hex = string.gsub(hex, "(%x)", "%1%1")
    end
    if #hex ~= 6 then return nil end
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if not r or not g or not b then return nil end
    return Color3.fromRGB(r, g, b)
end

local DEFAULT_PRESETS = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(255, 64, 64),
    Color3.fromRGB(255, 200, 0),
    Color3.fromRGB(0, 225, 120),
    Color3.fromRGB(0, 150, 255),
}

local function attachColorPicker(tab, parent, x, y, size, opts)
    opts = opts or {}
    local window = tab.Window
    local flag = opts.Flag or ((opts.Name or "Color") .. "." .. tostring(tab.Name))
    local color = typeof(opts.Default) == "Color3" and opts.Default or state.Accent
    local alphaValue = opts.Alpha ~= nil and math.clamp(finite(opts.Alpha, 1), 0, 1) or 1
    local useAlpha = opts.UseAlpha ~= false

    local anchor = transparent(parent, x, y, size, size, "TextButton")
    anchor.ZIndex = 3
    local dot = rect(anchor, 0, 0, size, size, color, math.floor(size / 2), nil)
    dot.ZIndex = 3
    new("UIStroke", dot, {Color = palette[5], Thickness = 1, Transparency = 0.35})

    local PW = 200
    local INNER = PW - 20
    local SV_H = 110
    local BAR_H = UIS.TouchEnabled and 22 or 8
    local SV_TOP = 10
    local HUE_TOP = SV_TOP + SV_H + 10
    local ALPHA_TOP = HUE_TOP + BAR_H + 8
    local ROW_TOP = (useAlpha and (ALPHA_TOP + BAR_H) or (HUE_TOP + BAR_H)) + 12
    local POP_H = ROW_TOP + 20 + 10

    local pop = createPopup(window, anchor, PW, POP_H, false)
    local host = pop.Object

    local hue, saturation, value = color:ToHSV()

    local sv = rect(host, 10, SV_TOP, INNER, SV_H, white, 4, "TextButton")
    local svGradient = new("UIGradient", sv, {Color = ColorSequence.new(white, Color3.fromHSV(hue, 1, 1))})
    local shade = rect(sv, 0, 0, INNER, SV_H, black, 4)
    new("UIGradient", shade, {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    })
    local svDot = rect(sv, 0, 0, 10, 10, color, 5)
    svDot.ZIndex = 3
    new("UIStroke", svDot, {Color = white, Thickness = 2})

    local hueBar = rect(host, 10, HUE_TOP, INNER, BAR_H, white, 4, "TextButton")
    local stops = {}
    for i = 0, 6 do
        stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))
    end
    new("UIGradient", hueBar, {Color = ColorSequence.new(stops)})
    local hueThumb = rect(hueBar, 0, -3, 6, BAR_H + 6, white, 3)
    hueThumb.ZIndex = 3
    new("UIStroke", hueThumb, {Color = palette[1], Thickness = 1})

    local alphaBar, alphaThumb
    if useAlpha then
        alphaBar = rect(host, 10, ALPHA_TOP, INNER, BAR_H, color, 4, "TextButton")
        new("UIGradient", alphaBar, {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
        })
        alphaThumb = rect(alphaBar, 0, -3, 6, BAR_H + 6, white, 3)
        alphaThumb.ZIndex = 3
        new("UIStroke", alphaThumb, {Color = palette[1], Thickness = 1})
    end

    local preview = rect(host, 10, ROW_TOP, 22, 20, color, 3)
    new("UIStroke", preview, {Color = palette[5], Thickness = 1, Transparency = 0.35})

    local hexBox = new("TextBox", host, {
        Position = UDim2.fromOffset(38, ROW_TOP),
        Size = UDim2.fromOffset(72, 20),
        BackgroundColor3 = palette[4],
        BorderSizePixel = 0,
        Text = "#" .. toHex(color),
        PlaceholderText = "#RRGGBB",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = white,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 2,
    })
    new("UICorner", hexBox, {CornerRadius = UDim.new(0, 3)})

    local api = {Flag = flag, Anchor = anchor, Popup = pop}

    local function push()
        local result = Color3.fromHSV(hue, saturation, value)
        Library.Flags[flag] = result
        fireChange(flag, result)
        if useAlpha then
            Library.Flags[flag .. ".Alpha"] = alphaValue
            fireChange(flag .. ".Alpha", alphaValue)
        end
        if opts.Callback then
            task.spawn(opts.Callback, result, alphaValue)
        end
    end

    function api:Get()
        return Color3.fromHSV(hue, saturation, value), alphaValue
    end

    function api:Set(newColor, newAlpha)
        if typeof(newColor) == "Color3" then
            hue, saturation, value = newColor:ToHSV()
        end
        if newAlpha ~= nil then
            alphaValue = math.clamp(finite(newAlpha, alphaValue), 0, 1)
        end
        push()
    end

    local presets = type(opts.Presets) == "table" and opts.Presets or DEFAULT_PRESETS
    for index = 1, math.min(5, #presets) do
        local swatch = presets[index]
        if typeof(swatch) == "Color3" then
            local button = rect(host, 118 + (index - 1) * 15, ROW_TOP + 4, 12, 12, swatch, 3, "TextButton")
            button.ZIndex = 2
            new("UIStroke", button, {Color = palette[5], Thickness = 1, Transparency = 0.5})
            connect(button.Activated, function()
                hue, saturation, value = swatch:ToHSV()
                push()
            end)
        end
    end

    local editing = false
    connect(hexBox.Focused, function() editing = true end)
    connect(hexBox.FocusLost, function()
        editing = false
        local parsed = fromHex(hexBox.Text)
        if parsed then
            hue, saturation, value = parsed:ToHSV()
            push()
        end
        hexBox.Text = "#" .. toHex(Color3.fromHSV(hue, saturation, value))
    end)

    connect(anchor.Activated, function() pop:Toggle(anchor) end)

    window.Draggable(sv, function(point)
        saturation = math.clamp((point.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        value = 1 - math.clamp((point.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        push()
    end)
    window.Draggable(hueBar, function(point)
        hue = math.clamp((point.X - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1)
        push()
    end)
    if useAlpha then
        window.Draggable(alphaBar, function(point)
            alphaValue = math.clamp(
                (point.X - alphaBar.AbsolutePosition.X) / math.max(1, alphaBar.AbsoluteSize.X), 0, 1)
            push()
        end)
    end

    local svX, svY = INNER * saturation, SV_H * (1 - value)
    local hueX, alphaX = INNER * hue, INNER * alphaValue
    local lastHue = nil

    step(function(dt, k)
        svX = approach(svX, math.clamp(INNER * saturation, 5, INNER - 5), k)
        svY = approach(svY, math.clamp(SV_H * (1 - value), 5, SV_H - 5), k)
        hueX = approach(hueX, math.clamp(INNER * hue, 0, INNER - 6), k)
        svDot.Position = UDim2.fromOffset(svX - 5, svY - 5)
        hueThumb.Position = UDim2.fromOffset(hueX, -3)
        if useAlpha then
            alphaX = approach(alphaX, math.clamp(INNER * alphaValue, 0, INNER - 6), k)
            alphaThumb.Position = UDim2.fromOffset(alphaX, -3)
        end
        if hue ~= lastHue then
            svGradient.Color = ColorSequence.new(white, Color3.fromHSV(hue, 1, 1))
            lastHue = hue
        end
        local current = Color3.fromHSV(hue, saturation, value)
        dot.BackgroundColor3 = current
        dot.BackgroundTransparency = useAlpha and (1 - alphaValue) or 0
        svDot.BackgroundColor3 = current
        preview.BackgroundColor3 = current
        hexBox.BackgroundColor3 = palette[4]
        if alphaBar then alphaBar.BackgroundColor3 = current end
        if not editing then
            local hexText = "#" .. toHex(current)
            if hexBox.Text ~= hexText then hexBox.Text = hexText end
        end
    end)

    Library.Flags[flag] = color
    if useAlpha then
        Library.Flags[flag .. ".Alpha"] = alphaValue
        Library.Elements[flag .. ".Alpha"] = {
            Object = anchor,
            Get = function() return alphaValue end,
            Set = function(_, a) api:Set(nil, finite(a, alphaValue)) end,
        }
    end
    Library.Elements[flag] = api
    if opts.Callback then task.spawn(opts.Callback, color, alphaValue) end
    return api
end

function Tab:AddColorPicker(opts)
    opts = opts or {}
    local name = opts.Name or "Color"
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)
    local title = text(card, name, 10, 10, w - 44, 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, w - 20, 14, 11)
    end
    local picker = attachColorPicker(self, card, w - 24, 14.5, 14, opts)
    local api = baseApi(self, card, picker.Flag)
    api.Get = function(_) return picker:Get() end
    api.Set = function(_, color, alpha) picker:Set(color, alpha) end
    api.SetName = function(_, value) title:SetText(value) end
    step(function(dt, k) title:Color(palette[3]:Lerp(white, 0.35)) end)
    return api
end

local function attachKeybind(tab, parent, x, y, w, h, opts)
    opts = opts or {}
    local window = tab.Window
    local flag = opts.Flag or ((tab.Name or "TAB") .. "." .. (opts.Name or "Keybind"))
    local key = opts.Default
    if type(key) == "string" then key = keyFromName(key) end

    local button = paint(rect(parent, x, y, w, h, palette[1], 3, "TextButton"), 1)
    button.ZIndex = 3
    local caption = text(button, keyName(key), 0, 0, w, h, 10, palette[3], "center")

    local bind = {Key = key, Flag = flag, Object = button}

    function bind:Fire()
        if not button.Parent then return end
        if opts.Callback then task.spawn(opts.Callback, self.Key) end
        if opts.Toggle then opts.Toggle() end
    end

    function bind:Set(value)
        if type(value) == "string" then value = keyFromName(value) end
        if value ~= nil and typeof(value) ~= "EnumItem" then return end
        self.Key = value
        caption:SetText(keyName(value))
        Library.Flags[flag] = value and value.Name or "NONE"
        fireChange(flag, Library.Flags[flag])
    end

    function bind:Get() return self.Key end

    window.Keybinds[#window.Keybinds + 1] = bind

    connect(button.Activated, function()
        window.PendingKeybind = bind
        caption:SetText("...")
    end)

    local hover, tint = false, palette[3]
    connect(button.MouseEnter, function() hover = true end)
    connect(button.MouseLeave, function() hover = false end)
    step(function(dt, k)
        local waiting = window.PendingKeybind == bind
        caption:SetText(waiting and "..." or keyName(bind.Key))
        tint = tint:Lerp((hover or waiting) and white or palette[3], k)
        caption:Color(tint)
        button.BackgroundColor3 = palette[1]:Lerp(palette[4], waiting and 1 or 0)
    end)

    Library.Flags[flag] = key and key.Name or "NONE"
    Library.Elements[flag] = bind
    return bind
end

function Tab:AddKeybind(opts)
    opts = opts or {}
    local name = opts.Name or "Keybind"
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)
    local title = text(card, name, 10, 10, w - 66, 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, w - 20, 14, 11)
    end
    local bind = attachKeybind(self, card, w - 56, 14.5, 46, 14, opts)
    local api = baseApi(self, card, bind.Flag)
    api.Get = function(_) return bind:Get() end
    api.Set = function(_, value) bind:Set(value) end
    api.SetName = function(_, value) title:SetText(value) end
    step(function() title:Color(palette[3]:Lerp(white, 0.35)) end)
    return api
end

function Tab:AddToggle(opts)
    opts = opts or {}
    local name = opts.Name or "Toggle"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)

    local value = opts.Default and true or false

    local box = paint(rect(card, w - 24, 14.5, 14, 14, palette[1], 3), 1)
    local fill = rect(box, 7, 7, 0, 0, accent, 3)
    local mark = iconLabel(box, {"check"}, 1, 1, 12, black, "v")

    local edge = w - 24
    local function claim(width)
        edge = edge - 10 - width
        return edge
    end

    local colorPicker, keybind
    if opts.ColorPicker then
        local config = type(opts.ColorPicker) == "table" and opts.ColorPicker or {}
        config.Flag = config.Flag or (flag .. ".Color")
        config.Name = config.Name or name
        colorPicker = attachColorPicker(self, card, claim(14), 14.5, 14, config)
    end

    local title = text(card, name, 10, 10, math.max(40, edge - 20), 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, w - 20, 14, 11)
    end

    local api = baseApi(self, card, flag)

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        local nextValue = newValue and true or false
        if nextValue == value then return end
        value = nextValue
        push(not silent)
    end
    function api:Toggle() self:Set(not value) end
    function api:SetName(v) title:SetText(v) end

    if opts.Keybind ~= nil then
        local config = type(opts.Keybind) == "table" and opts.Keybind or {Default = opts.Keybind}
        config.Flag = config.Flag or (flag .. ".Key")
        config.Name = config.Name or name
        config.Toggle = function() api:Toggle() end
        local kx = claim(46)
        keybind = attachKeybind(self, card, kx, 14.5, 46, 14, config)
        title:Width(math.max(40, kx - 20))
    end

    local hit = transparent(card, 0, 0, w, 43, "TextButton")
    hit.ZIndex = 1
    connect(hit.Activated, function() api:Set(not value) end)

    local a, tint = value and 1 or 0, palette[3]
    step(function(dt, k)
        a = approach(a, value and 1 or 0, k)
        fill.Position = UDim2.fromOffset(7 * (1 - a), 7 * (1 - a))
        fill.Size = UDim2.fromOffset(14 * a, 14 * a)
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - a * state.AccentAlpha
        mark:Alpha(a)
        tint = tint:Lerp(value and white or palette[3], k)
        title:Color(tint)
    end)

    push(false)
    if opts.Callback and value then task.spawn(opts.Callback, value) end
    api.ColorPicker = colorPicker
    api.Keybind = keybind
    return api
end

local function makeSlider(tab, parent, x, y, w, opts)
    opts = opts or {}
    local name = opts.Name or "Slider"
    local flag = opts.Flag or ((tab and tab.Name or "TAB") .. "." .. name)
    local min = finite(opts.Min, 0)
    local max = finite(opts.Max, 100)
    if min > max then min, max = max, min end
    local decimals = math.clamp(math.floor(finite(opts.Decimals, 0)), 0, 6)
    local increment = math.abs(finite(opts.Step, 10 ^ -decimals))
    if increment == 0 then increment = 10 ^ -decimals end
    local suffix = opts.Suffix or ""

    local card = paint(rect(parent, x, y, w, 58, palette[2], 5), 2)
    card.Name = name
    local title = text(card, name, 10, 10, w - 70, 14, 12, white)
    if opts.Description then
        muted(card, opts.Description, 10, 22, w - 20, 14, 11)
    end
    local valueLabel = text(card, "", w - 55, 10, 45, 14, 12, white, "right")

    local track = paint(rect(card, 10, 38, w - 20, 10, palette[1], 3), 1)
    local fillClip = transparent(track, 0, 0, 0, 10)
    fillClip.ClipsDescendants = true
    local fill = rect(fillClip, 0, 0, w - 20, 10, accent, 3)
    new("UIGradient", fill, {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0),
        }),
    })
    local thumb = rect(track, 0, 0, 10, 10, white, 3)

    local value = math.clamp(finite(opts.Default, min), min, max)

    local function quantize(raw)
        if raw >= max then return max end
        if raw <= min then return min end
        local snapped = min + math.floor((raw - min) / increment + 0.5) * increment
        return math.clamp(snapped, min, max)
    end

    value = quantize(value)
    local api = {Flag = flag, Object = card}

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        local nextValue = quantize(finite(newValue, value))
        if value == nextValue then return end
        value = nextValue
        push(not silent)
    end
    function api:SetName(v) title:SetText(v) end
    function api:SetVisible(v) card.Visible = v and true or false end

    local hit = transparent(card, 10, 33, w - 20, 20, "TextButton")
    hit.ZIndex = 3
    tab.Window.Draggable(hit, function(point)
        local ratio = math.clamp(
            (point.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        api:Set(min + (max - min) * ratio)
    end, function(cancelled)
        if opts.OnRelease then opts.OnRelease(value, cancelled) end
    end)
    connect(hit.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
            api:Set(value - increment)
        elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
            api:Set(value + increment)
        end
    end)

    local span = math.max(1e-6, max - min)
    local a = (value - min) / span
    step(function(dt, k)
        a = approach(a, (value - min) / span, k)
        fillClip.Size = UDim2.fromOffset((w - 20) * a, 10)
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - state.AccentAlpha
        thumb.Position = UDim2.fromOffset(math.clamp((w - 20) * a, 5, w - 25) - 5, 0)
        valueLabel:SetText(string.format("%." .. tostring(decimals) .. "f", value) .. suffix)
    end)

    Library.Elements[flag] = api
    push(false)
    if opts.Callback then task.spawn(opts.Callback, value) end
    return api
end

function Tab:AddSlider(opts)
    opts = opts or {}
    local w = self:_width(opts.Width)
    local x, y = self:_place(w, 58)
    local api = makeSlider(self, self.Page, x, y, w, opts)
    self:_grow()
    self.Elements[#self.Elements + 1] = api
    return api
end

function Tab:AddDropdown(opts)
    opts = opts or {}
    local name = opts.Name or "Dropdown"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local multiple = opts.Multiple and true or false
    local options = {}
    for _, option in ipairs(opts.Options or {"One", "Two", "Three"}) do
        options[#options + 1] = tostring(option)
    end

    local w = self:_width(opts.Width)
    local card = self:_card(w, 79, name)
    text(card, name, 10, 10, w - 20, 14, 12, white)
    muted(card, opts.Description or "", 10, 22, w - 20, 14, 11)

    local controlW = w - 20
    local control = paint(rect(card, 10, 38, controlW, 31, palette[4], 3, "TextButton"), 4)
    local preview = muted(control, "", 10, 0, controlW - 40, 31, 11)
    local arrow = iconLabel(control, {"chevron-down", "chevrons-down", "arrow-down"},
        controlW - 22, 11.5, 10, palette[3], "v")
    step(function() arrow:Color(palette[3]) end)

    local ROW_H = 31
    local maxRows = math.max(1, math.floor(finite(opts.MaxRows, 5)))
    local pop = createPopup(self.Window, control, controlW, math.min(#options, maxRows) * ROW_H, true)
    local list = new("ScrollingFrame", pop.Object, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.fromOffset(0, #options * ROW_H),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollingEnabled = #options > maxRows,
        Active = true,
    })

    local selection = multiple and {} or 1

    local rows = {}
    local api = baseApi(self, card, flag)

    local function previewText()
        if multiple then
            local parts = {}
            for index, option in ipairs(options) do
                if selection[index] then parts[#parts + 1] = option end
            end
            return #parts > 0 and table.concat(parts, ", ") or "-"
        end
        return options[selection] or "-"
    end

    local function selectedValue()
        if not multiple then return options[selection], selection end
        local names = {}
        for index, option in ipairs(options) do
            if selection[index] then names[#names + 1] = option end
        end
        return names, table.clone(selection)
    end

    local function push(fire)
        if multiple then
            local copy = {}
            for index in pairs(selection) do copy[index] = true end
            Library.Flags[flag] = copy
        else
            Library.Flags[flag] = selection
        end
        Library.Flags[flag .. ".Text"] = previewText()
        preview:SetText(previewText())
        fireChange(flag, Library.Flags[flag])
        if fire and opts.Callback then
            task.spawn(opts.Callback, selectedValue())
        end
    end

    local function buildRows()
        for _, row in ipairs(rows) do
            row.Object:Destroy()
        end
        rows = {}
        list.CanvasSize = UDim2.fromOffset(0, #options * ROW_H)
        list.ScrollingEnabled = #options > maxRows
        pop.Height = math.max(ROW_H, math.min(#options, maxRows) * ROW_H)

        for index, option in ipairs(options) do
            local row = rect(list, 0, (index - 1) * ROW_H, controlW, ROW_H, palette[5], nil, "TextButton")
            row.BackgroundTransparency = 1
            local mark = iconLabel(row, {"check"}, 0, 9.5, 12, accent, "v")
            local title = text(row, option, 10, 0, controlW - 20, ROW_H, 11, palette[3])
            local entry = {Object = row, Mark = mark, Title = title, Alpha = 0, Index = index}
            rows[#rows + 1] = entry

            connect(row.Activated, function()
                if multiple then
                    selection[index] = not selection[index] or nil
                else
                    selection = index
                    pop:Close()
                end
                push(true)
            end)
        end
    end

    step(function(dt, k)
        for _, entry in ipairs(rows) do
            local selected
            if multiple then
                selected = selection[entry.Index] and true or false
            else
                selected = selection == entry.Index
            end
            entry.Alpha = approach(entry.Alpha, selected and 1 or 0, k)
            entry.Object.BackgroundColor3 = palette[5]
            entry.Object.BackgroundTransparency = 1 - entry.Alpha
            entry.Title.Object.Position = UDim2.fromOffset(10 + 20 * entry.Alpha, 0)
            entry.Title:Color(palette[3]:Lerp(white, entry.Alpha))
            entry.Mark.Object.Position = UDim2.fromOffset(10 * entry.Alpha, 9.5)
            entry.Mark:Color(accent)
            entry.Mark:Alpha(entry.Alpha * state.AccentAlpha)
        end
    end)

    connect(control.Activated, function() pop:Toggle(control) end)

    function api:Get() return selectedValue() end
    function api:Set(value, silent)
        if multiple then
            local next_ = {}
            if type(value) == "table" then
                for key, flagValue in pairs(value) do
                    if type(flagValue) == "boolean" and flagValue then
                        local index = tonumber(key)
                        if index and options[index] then next_[index] = true end
                    elseif type(flagValue) == "number" and options[flagValue] then
                        next_[flagValue] = true
                    elseif type(flagValue) == "string" then
                        for index, option in ipairs(options) do
                            if option == flagValue then next_[index] = true end
                        end
                    end
                end
            end
            selection = next_
        else
            if type(value) == "string" then
                local found = nil
                for index, option in ipairs(options) do
                    if option == value then
                        found = index
                        break
                    end
                end
                value = found or selection
            end
            selection = math.clamp(math.floor(finite(value, 1)), 1, math.max(1, #options))
        end
        push(not silent)
    end
    function api:SetOptions(list_)
        options = {}
        for _, option in ipairs(list_ or {}) do options[#options + 1] = tostring(option) end
        if multiple then
            selection = {}
        else
            selection = math.min(selection, math.max(1, #options))
        end
        buildRows()
        push(false)
    end
    function api:GetOptions() return table.clone(options) end

    buildRows()
    api:Set(opts.Default or (multiple and {} or 1), true)
    if opts.Callback then task.spawn(opts.Callback, selectedValue()) end
    return api
end

function Tab:AddTextBox(opts)
    opts = opts or {}
    local name = opts.Name or "Text field"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local withTitle = opts.ShowName and true or false
    local height = withTitle and 58 or 31
    local card = self:_card(w, height, name)
    if withTitle then
        text(card, name, 10, 10, w - 20, 14, 12, white)
    end

    local box = new("TextBox", card, {
        Name = "Input",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, withTitle and 27 or 0),
        Size = UDim2.fromOffset(w - 20, 31),
        Text = tostring(opts.Default or ""),
        PlaceholderText = opts.Placeholder or name,
        PlaceholderColor3 = palette[3],
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = white,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        MultiLine = false,
        ClipsDescendants = true,
        ZIndex = 2,
    })
    step(function() box.PlaceholderColor3 = palette[3] end)

    local maxLength = math.max(1, math.floor(finite(opts.MaxLength, 96)))
    local api = baseApi(self, card, flag)

    local function push(fire)
        Library.Flags[flag] = box.Text
        fireChange(flag, box.Text)
        if fire and opts.Callback then task.spawn(opts.Callback, box.Text) end
    end

    local committed
    local function normalize(value)
        value = tostring(value or "")
        local length = utf8.len(value)
        if length and length > maxLength then
            local offset = utf8.offset(value, maxLength + 1)
            value = string.sub(value, 1, offset - 1)
        end
        return value
    end
    committed = normalize(box.Text)
    box.Text = committed
    connect(box:GetPropertyChangedSignal("Text"), function()
        if box.Text == committed then return end
        local length = utf8.len(box.Text)
        if length and length > maxLength then
            local offset = utf8.offset(box.Text, maxLength + 1)
            if offset then
                box.Text = string.sub(box.Text, 1, offset - 1)
                return
            end
        end
        committed = box.Text
        push(true)
    end)

    if opts.OnEnter then
        connect(box.FocusLost, function(enter)
            if enter then task.spawn(opts.OnEnter, box.Text) end
        end)
    end

    function api:Get() return box.Text end
    function api:Set(value, silent)
        local nextValue = normalize(value)
        if nextValue == committed then return end
        committed = nextValue
        box.Text = nextValue
        push(not silent)
    end
    function api:SetName(value) box.PlaceholderText = tostring(value) end

    push(false)
    return api
end

function Tab:AddButton(opts)
    opts = opts or {}
    local name = opts.Name or "Button"
    local w = self:_width(opts.Width)
    local compact = opts.Compact and true or false
    local card = self:_card(w, compact and 31 or (opts.Description and 79 or 68), name)

    local control
    if compact then
        control = paint(rect(card, 0, 0, w, 31, palette[4], 5, "TextButton"), 4)
    else
        text(card, name, 10, 10, w - 20, 14, 12, white)
        if opts.Description then
            muted(card, opts.Description, 10, 22, w - 20, 14, 11)
        end
        control = paint(rect(card, 10, opts.Description and 38 or 27, w - 20, 31, palette[4], 3, "TextButton"), 4)
    end

    local controlW = compact and w or (w - 20)
    local caption = text(control, opts.Text or name, 0, 0, controlW, 31, 11, white, "center")
    if opts.Icon then
        local icon = iconLabel(control, opts.Icon, 10, 10, 11, white, "*")
        caption.Object.Position = UDim2.fromOffset(8, 0)
    end

    local api = baseApi(self, card, nil)
    function api:SetText(value) caption:SetText(value) end

    local flash, color, hover = 0, palette[4], false
    connect(control.MouseEnter, function() hover = true end)
    connect(control.MouseLeave, function() hover = false end)
    function api:Press()
        if self.Destroyed or not card.Parent then return false end
        flash = 1 / 9
        if self.Tab.Window then self.Tab.Window.ButtonPressed:Fire(self.Tab.Name .. "." .. name) end
        if opts.Callback then task.spawn(opts.Callback) end
        return true
    end
    connect(control.Activated, function() api:Press() end)

    step(function(dt, k)
        flash = math.max(0, flash - dt)
        local target = palette[4]
        if flash > 0 then
            target = palette[6]
        elseif hover then
            target = palette[5]
        end
        color = color:Lerp(target, math.min(1, 10 * dt))
        control.BackgroundColor3 = color
    end)
    return api
end

function Library:Notify(opts)
    opts = type(opts) == "table" and opts or {Text = opts}
    local window = self.Window
    if not window then return end

    local body = tostring(opts.Text or "")
    local title = opts.Title
    local width = 250
    local bounds = TextService:GetTextSize(body, 11, Enum.Font.Gotham, Vector2.new(width - 46, 10000))
    local height = (title and 26 or 10) + math.max(14, bounds.Y) + 10

    local object = rect(window.NotifyHolder, 260, 0, width, height, palette[2], 5, "CanvasGroup")
    object.Name = "Notification"
    object.GroupTransparency = 1
    object.ClipsDescendants = true

    local bar = rect(object, 0, 0, 2, height, accent, nil)
    local icon = iconLabel(object, opts.Icon or {"bell", "info", "circle"}, 12, title and 10 or 10, 14, accent, "!")
    if title then
        text(object, title, 34, 8, width - 46, 14, 12, white)
    end
    muted(object, body, 34, title and 26 or 10, width - 46, math.max(14, bounds.Y), 11, nil, {Wrap = true})

    local notif = {
        Object = object,
        Bar = bar,
        Icon = icon,
        Height = height,
        Alpha = 0,
        Y = 0,
        Life = math.max(0, finite(opts.Duration, 4)),
    }
    window.Notifications[#window.Notifications + 1] = notif
    return notif
end

function Library:SetWatermark(opts)
    local window = self.Window
    if not window then return end
    opts = type(opts) == "table" and opts or {Text = opts, Enabled = true}
    local config = window.WatermarkConfig
    if opts.Text ~= nil then config.Text = tostring(opts.Text) end
    if opts.ShowFPS ~= nil then config.ShowFPS = opts.ShowFPS and true or false end
    if opts.Enabled ~= nil then config.Enabled = opts.Enabled == true end
    if opts.ShowClock ~= nil then config.ShowClock = opts.ShowClock == true end
    if opts.Transparency ~= nil then config.Transparency = math.clamp(finite(opts.Transparency, config.Transparency), 0, 0.95) end
    window:LayoutAccess()
    return config
end

local function serialize(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", R = value.R, G = value.G, B = value.B}
    end
    if typeof(value) == "EnumItem" then
        return {__type = "Key", Name = value.Name}
    end
    if type(value) == "table" then
        local indices = {}
        for key, flagValue in pairs(value) do
            if type(key) == "number" and flagValue then indices[#indices + 1] = key end
        end
        table.sort(indices)
        return {__type = "Set", Values = indices}
    end
    return value
end

local function deserialize(value)
    if type(value) == "table" then
        if value.__type == "Color3" then
            return Color3.new(value.R or 0, value.G or 0, value.B or 0)
        elseif value.__type == "Key" then
            return keyFromName(value.Name)
        elseif value.__type == "Set" then
            local set = {}
            for _, index in ipairs(value.Values or {}) do set[index] = true end
            return set
        end
    end
    return value
end

function Library:GetConfig()
    local config = {__version = self.Version, Flags = {}, Theme = state.Theme, Scale = state.Scale}
    for flag, value in pairs(self.Flags) do
        config.Flags[flag] = serialize(value)
    end
    config.Accent = serialize(state.Accent)
    config.AccentAlpha = state.AccentAlpha
    if self.Window then config.Interface = self.Window:GetInterfaceConfig() end
    return config
end

function Library:LoadConfig(config)
    if type(config) ~= "table" then return false, "config is not a table" end
    if config.Flags ~= nil and type(config.Flags) ~= "table" then return false, "Flags must be a table" end
    local errors = {}
    local function apply(label, callback)
        local ok, err = pcall(callback)
        if not ok then errors[#errors + 1] = tostring(label) .. ": " .. tostring(err) end
    end
    apply("Theme", function() if config.Theme then self:SetTheme(config.Theme) end end)
    apply("Accent", function()
        self:SetAccent(config.Accent and deserialize(config.Accent), config.AccentAlpha)
    end)
    apply("Scale", function() if config.Scale and self.Window then self.Window:SetScale(config.Scale) end end)
    local flags = {}
    for flag in pairs(config.Flags or {}) do flags[#flags + 1] = flag end
    table.sort(flags, function(a, b) return tostring(a) < tostring(b) end)
    for _, flag in ipairs(flags) do
        apply(flag, function()
            local element = self.Elements[flag]
            local value = deserialize(config.Flags[flag])
            if element and element.Set then element:Set(value) else self.Flags[flag] = value end
        end)
    end
    apply("Interface", function()
        if config.Interface and self.Window then self.Window:LoadInterfaceConfig(config.Interface) end
    end)
    if #errors > 0 then return false, table.concat(errors, "\n") end
    return true
end

local ROOT = "WolfUi"
local LEGACY_ROOT = "WolfLib"
local scriptFolder = "Default"

local function safeName(value)
    local name = string.gsub(tostring(value or ""), "[^%w%-%. ]", "_")
    name = string.gsub(name, "^ +", "")
    name = string.gsub(name, " +$", "")
    if name == "" or name == "." or name == ".." then name = "Default" end
    return string.sub(name, 1, 40)
end

local function fileSupport()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function folderSupport()
    return type(isfolder) == "function" and type(makefolder) == "function"
end

local function ensureFolder(path)
    if not folderSupport() then return false end
    local built = nil
    for part in string.gmatch(path, "[^/]+") do
        built = built and (built .. "/" .. part) or part
        local ok, exists = pcall(isfolder, built)
        if not ok then return false end
        if not exists then
            if not pcall(makefolder, built) then return false end
        end
    end
    return true
end

local function migrateLegacy(target)
    if not fileSupport() or type(listfiles) ~= "function" then return end
    pcall(function()
        if folderSupport() and not isfolder(LEGACY_ROOT) then return end
        for _, path in ipairs(listfiles(LEGACY_ROOT)) do
            local name = string.match(path, "([^/\\]+%.json)$")
            if name then
                local destination = target .. "/" .. name
                local exists = type(isfile) == "function" and isfile(destination)
                if not exists then
                    writefile(destination, readfile(path))
                end
            end
        end
    end)
end

function Library:SetScriptName(value)
    scriptFolder = safeName(value)
    self.ScriptName = scriptFolder
    self.Folder = ROOT .. "/" .. scriptFolder
    self.ConfigFolder = self.Folder .. "/configs"
    if ensureFolder(self.ConfigFolder) then
        migrateLegacy(self.ConfigFolder)
    end
    return self.Folder
end

function Library:GetFolder()
    return ROOT .. "/" .. scriptFolder
end

function Library:GetConfigFolder()
    return ROOT .. "/" .. scriptFolder .. "/configs"
end

local function resolvePath(path)
    local clean = string.gsub(tostring(path or ""), "\\", "/")
    clean = string.gsub(clean, "^/+", "")
    local parts = {}
    for part in string.gmatch(clean, "[^/]+") do
        if part == ".." or string.find(part, "[%z%c:]") then return nil, "invalid relative path" end
        if part ~= "." then parts[#parts + 1] = part end
    end
    return ROOT .. "/" .. scriptFolder .. "/" .. table.concat(parts, "/")
end

function Library:WriteFile(path, content)
    if not fileSupport() then return false, "executor has no file API" end
    local full, err = resolvePath(path)
    if not full then return false, err end
    local folder = string.match(full, "^(.*)/[^/]+$")
    if folder then ensureFolder(folder) end
    return pcall(writefile, full, tostring(content))
end

function Library:ReadFile(path)
    if not fileSupport() then return nil, "executor has no file API" end
    local full, err = resolvePath(path)
    if not full then return nil, err end
    local ok, result = pcall(readfile, full)
    if not ok then return nil, result end
    return result
end

function Library:DeleteFile(path)
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    local full, err = resolvePath(path)
    if not full then return false, err end
    return pcall(delfile, full)
end

function Library:ListFiles(subFolder)
    local names = {}
    if type(listfiles) ~= "function" then return names end
    local folder = self:GetFolder()
    if subFolder then
        local err
        folder, err = resolvePath(subFolder)
        if not folder then return names, err end
    end
    pcall(function()
        for _, path in ipairs(listfiles(folder)) do
            names[#names + 1] = string.match(path, "([^/\\]+)$") or path
        end
    end)
    table.sort(names)
    return names
end

function Library:SaveConfigFile(name)
    if not fileSupport() then return false, "executor has no file API" end
    local folder = self:GetConfigFolder()
    local ok, err = pcall(function()
        ensureFolder(folder)
        writefile(folder .. "/" .. safeName(name or "default") .. ".json",
            HttpService:JSONEncode(self:GetConfig()))
    end)
    return ok, err
end

function Library:LoadConfigFile(name)
    if not fileSupport() then return false, "executor has no file API" end
    local path = self:GetConfigFolder() .. "/" .. safeName(name or "default") .. ".json"
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok then return false, result end
    return self:LoadConfig(result)
end

function Library:ListConfigs()
    local names = {}
    if type(listfiles) ~= "function" then return names end
    pcall(function()
        for _, path in ipairs(listfiles(self:GetConfigFolder())) do
            local name = string.match(path, "([^/\\]+)%.json$")
            if name then names[#names + 1] = name end
        end
    end)
    table.sort(names)
    return names
end

function Library:DeleteConfigFile(name)
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    return pcall(delfile,
        self:GetConfigFolder() .. "/" .. safeName(name or "default") .. ".json")
end

function Library:Unload()
    if self.Unloading then return end
    self.Unloading = true
    if self.Window and self.Window.CancelDrag then self.Window.CancelDrag() end
    if self.Window then
        for _, button in ipairs(table.clone(self.Window.QuickButtons or {})) do button:Destroy() end
        for _, panel in ipairs(table.clone(self.Window.SettingsPanels or {})) do panel:Destroy() end
    end
    Runtime.Alive = false
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    Runtime.Connections, Runtime.Updates = {}, {}
    if self.Window and self.Window.Gui then
        pcall(function() self.Window.Gui:Destroy() end)
    end
    if self.Window and self.Window.Events then
        pcall(function() self.Window.Events:Destroy() end)
    end
    self.Window = nil
    self.Elements = {}
    self.Flags = {}
    for _, listener in ipairs(unloadListeners) do
        pcall(listener)
    end
    unloadListeners = {}
    changeListeners = {}
    self.Unloading = false
end

function Library:Demo()
    local window = self:CreateWindow({Name = "Wolf", Icon = {"dog", "paw-print", "moon"}})

    local assist = window:CreateTab({Name = "ASSIST", Icon = {"crosshair", "target"}})
    assist:AddSection("Aimbot")
    assist:AddToggle({
        Name = "Enable aimbot", Description = "Демо-тумблер",
        Flag = "demo_aim", Default = true, Width = 0.5,
        ColorPicker = {Flag = "demo_aim_color"},
        Keybind = Enum.KeyCode.E,
    })
    assist:AddToggle({Name = "Silent aim", Flag = "demo_silent", Width = 0.5})
    assist:AddSlider({
        Name = "Field of view", Flag = "demo_fov",
        Min = 0, Max = 500, Default = 120, Suffix = " px", Width = 0.5,
    })
    assist:AddSlider({
        Name = "Smoothness", Flag = "demo_smooth",
        Min = 1, Max = 100, Default = 35, Width = 0.5,
    })
    assist:AddDropdown({
        Name = "Target part", Flag = "demo_part",
        Options = {"Head", "Torso", "Nearest"}, Default = "Head",
    })

    local visuals = window:CreateTab({Name = "VISUALS", Icon = {"eye", "scan-eye"}})
    visuals:AddSection("ESP")
    visuals:AddToggle({Name = "Boxes", Flag = "demo_boxes", Default = true, Width = 0.5})
    visuals:AddToggle({Name = "Names", Flag = "demo_names", Width = 0.5})
    visuals:AddColorPicker({
        Name = "Box color", Flag = "demo_box_color",
        Default = Color3.fromRGB(126, 139, 209),
    })
    visuals:AddKeybind({Name = "Toggle ESP", Flag = "demo_esp_key", Default = Enum.KeyCode.X})

    local misc = window:CreateTab({Name = "MISC", Icon = {"settings", "sliders-horizontal"}})
    misc:AddParagraph({
        Name = "Это демо",
        Text = "Библиотека загрузилась и работает. RightShift — скрыть/показать меню, " ..
            "F1/F2 — масштаб 100/75/50. Иконку в сайдбаре можно тянуть мышью или пальцем.",
    })
    misc:AddTextBox({Name = "Ник", Placeholder = "введите текст", ShowName = true})
    misc:AddButton({
        Name = "Уведомление", Text = "Показать",
        Callback = function()
            Library:Notify({
                Title = "WolfLib",
                Text = "Всё работает, версия " .. tostring(Library.Version),
                Duration = 4,
            })
        end,
    })

    local controls = window:CreateTab({Name = "CONTROLS", Icon = {"sliders-horizontal"}})
    controls:AddNumberInput({Name = "Количество", Min = 0, Max = 100, Default = 10, Width = 0.5})
    controls:AddProgressBar({Name = "Прогресс", Default = 65, Width = 0.5})
    controls:AddSegmented({Name = "Качество", Options = {"Низкое", "Среднее", "Высокое"}, Default = 2})
    controls:AddRadioGroup({Name = "Режим", Options = {"Автоматически", "Вручную"}})

    self:SetWatermark({Text = "WolfLib " .. tostring(self.Version), ShowFPS = true})
    self:Notify({Title = "WolfLib", Text = "Демо-меню создано", Duration = 5})
    return window
end

Library.Runtime = Runtime
Library.Palette = palette
Library.Icons = IconSheet

local function numberOptions(opts)
    local low, high = finite(opts.Min, 0), finite(opts.Max, 100)
    if low > high then low, high = high, low end
    local increment = math.abs(finite(opts.Step, 1))
    if increment == 0 then increment = 1 end
    return low, high, increment
end

function Tab:AddNumberInput(opts)
    opts = opts or {}
    local low, high, increment = numberOptions(opts)
    local w = math.max(180, self:_width(opts.Width))
    local name = opts.Name or "Number"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local card = self:_card(w, 78, name)
    local title = text(card, name, 10, 8, w - 20, 16, 12, white)
    local minus = paint(rect(card, 8, 32, 36, 36, palette[4], 4, "TextButton"), 4)
    text(minus, "−", 0, 0, 36, 36, 18, white, "center")
    local plus = paint(rect(card, w - 44, 32, 36, 36, palette[4], 4, "TextButton"), 4)
    text(plus, "+", 0, 0, 36, 36, 18, white, "center")
    local box = new("TextBox", card, {
        Position = UDim2.fromOffset(48, 32), Size = UDim2.fromOffset(w - 96, 36),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = white,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center,
    })
    local value
    local api = baseApi(self, card, flag)
    function api:Get() return value end
    function api:Set(raw, silent)
        local n = math.clamp(finite(raw, value or low), low, high)
        if n > low and n < high then n = low + math.floor((n - low) / increment + 0.5) * increment end
        n = math.clamp(n, low, high)
        local changed = value ~= n
        value = n
        box.Text = string.format("%.10g", n)
        if changed then
            fireChange(flag, n)
            if not silent and opts.Callback then task.spawn(opts.Callback, n) end
        end
    end
    function api:SetName(v) title:SetText(v) end
    connect(minus.Activated, function() api:Set(value - increment) end)
    connect(plus.Activated, function() api:Set(value + increment) end)
    connect(box.FocusLost, function() api:Set((string.gsub(box.Text, ",", "."))) end)
    api:Set(opts.Default or low, true)
    return api
end

function Tab:AddProgressBar(opts)
    opts = opts or {}
    local low, high = numberOptions(opts)
    local w = self:_width(opts.Width)
    local name = opts.Name or "Progress"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local card = self:_card(w, 56, name)
    local title = text(card, name, 10, 8, w - 70, 16, 12, white)
    local caption = text(card, "", w - 60, 8, 50, 16, 11, white, "right")
    local track = paint(rect(card, 10, 34, w - 20, 12, palette[4], 4), 4)
    local fill = rect(track, 0, 0, 0, 12, accent, 4)
    local value, shown = nil, 0
    local api = baseApi(self, card, flag)
    function api:Get() return value end
    function api:Set(raw, silent)
        local n = math.clamp(finite(raw, value or low), low, high)
        if n == value then return end
        value = n
        fireChange(flag, value)
        if not silent and opts.Callback then task.spawn(opts.Callback, value) end
    end
    function api:SetName(v) title:SetText(v) end
    api:Set(opts.Default or low, true)
    step(function(_, k)
        local ratio = high == low and 1 or (value - low) / (high - low)
        shown = approach(shown, ratio, k)
        fill.Size = UDim2.new(shown, 0, 1, 0)
        fill.BackgroundColor3 = typeof(opts.Color) == "Color3" and opts.Color or accent
        caption:SetText(tostring(math.floor(ratio * 100 + 0.5)) .. "%")
    end)
    return api
end

local function choiceControl(tab, opts, vertical)
    opts = opts or {}
    local name = opts.Name or (vertical and "Radio group" or "Segmented")
    local flag = opts.Flag or (tab.Name .. "." .. name)
    local w = tab:_width(opts.Width)
    local options, buttons, selection = {}, {}, nil
    local card = tab:_card(w, 76, name)
    local title = text(card, name, 10, 8, w - 20, 16, 12, white)
    local api = baseApi(tab, card, flag)
    function api:Get() return options[selection], selection end
    function api:GetOptions() return table.clone(options) end
    function api:Set(value, silent)
        local index = nil
        if type(value) == "string" then
            for i, option in ipairs(options) do if option == value then index = i; break end end
        else
            index = finite(value, nil)
        end
        if index then index = math.floor(index) end
        if not index or not options[index] then index = #options > 0 and 1 or nil end
        if selection == index then return end
        selection = index
        fireChange(flag, index or 0)
        if not silent and opts.Callback then task.spawn(opts.Callback, self:Get()) end
    end
    function api:SetName(value) title:SetText(value) end
    function api:SetOptions(values)
        local old = options[selection]
        for _, entry in ipairs(buttons) do
            entry.Connection:Disconnect()
            entry.Object:Destroy()
        end
        options, buttons = {}, {}
        for _, value in ipairs(type(values) == "table" and values or {}) do
            options[#options + 1] = tostring(value)
        end
        local columns = vertical and 1 or math.max(1, math.min(#options, math.floor((w - 20) / 80)))
        local rows = math.max(1, math.ceil(#options / columns))
        local bw = (w - 20 - (columns - 1) * 6) / columns
        card.Size = UDim2.fromOffset(w, 32 + rows * 38 + 6)
        for i, option in ipairs(options) do
            local x = 10 + ((i - 1) % columns) * (bw + 6)
            local y = 32 + math.floor((i - 1) / columns) * 38
            local button = rect(card, x, y, bw, 32, palette[4], 4, "TextButton")
            local label = text(button, option, vertical and 28 or 6, 0,
                bw - (vertical and 34 or 12), 32, 11, white, vertical and nil or "center")
            local dot = vertical and rect(button, 10, 11, 10, 10, palette[3], 5) or nil
            buttons[i] = {Object = button, Label = label, Dot = dot,
                Connection = connect(button.Activated, function() api:Set(i) end)}
        end
        selection = nil
        self:Set(old or 1, true)
        if #options == 0 then fireChange(flag, 0) end
        tab:_grow()
    end
    step(function()
        for i, entry in ipairs(buttons) do
            entry.Object.BackgroundColor3 = i == selection and palette[6] or palette[4]
            entry.Label:Color(i == selection and white or palette[3])
            if entry.Dot then entry.Dot.BackgroundColor3 = i == selection and accent or palette[3] end
        end
    end)
    api:SetOptions(opts.Options or {"One", "Two", "Three"})
    api:Set(opts.Default or 1, true)
    return api
end

function Tab:AddSegmented(opts) return choiceControl(self, opts, false) end
function Tab:AddRadioGroup(opts) return choiceControl(self, opts, true) end

local function isPrimary(input)
    return input and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch)
end

local function pointInside(point, object)
    local p, size = object.AbsolutePosition, object.AbsoluteSize
    return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + size.X and point.Y <= p.Y + size.Y
end

local function shown(object)
    while object do
        if object:IsA("GuiObject") and not object.Visible then return false end
        object = object.Parent
    end
    return true
end

local function disconnectAll(connections)
    for _, connection in ipairs(connections or {}) do connection:Disconnect() end
end

local function removeValue(list, value)
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) end end
end

local function clampPoint(point, size, viewport)
    return Vector2.new(math.clamp(point.X, 0, math.max(0, viewport.X - size.X)),
        math.clamp(point.Y, 0, math.max(0, viewport.Y - size.Y)))
end

function Window:BindFloatingInput(button, opts)
    local gesture
    local connections = self.Draggable(button, function(point, initial)
        if initial then
            gesture = {Start = point, Point = point, Moved = false,
                Origin = opts.GetPosition and opts.GetPosition() or Vector2.new(0, 0)}
        end
        if not gesture then return end
        gesture.Point = point
        local delta = point - gesture.Start
        if delta.X * delta.X + delta.Y * delta.Y >= (opts.DragThreshold or 7) ^ 2 then gesture.Moved = true end
        if gesture.Moved and opts.Move then opts.Move(gesture.Origin + delta) end
    end, function(cancelled)
        local completed = gesture
        gesture = nil
        if not completed then return end
        if completed.Moved then
            if opts.Drop then opts.Drop(cancelled) end
        elseif not cancelled and pointInside(completed.Point, button) then
            if opts.Click then opts.Click() end
        end
    end, {Always = true, CanStart = function()
        return button.Parent and shown(button) and (not opts.CanStart or opts.CanStart())
    end})
    connections[#connections + 1] = connect(button.Activated, function(input)
        if isPrimary(input) then return end
        if button.Parent and shown(button) and (not opts.CanStart or opts.CanStart()) then
            if opts.Click then opts.Click() end
        end
    end)
    return connections
end

function Window:SetBoundsEnabled(value)
    self.BoundToScreen = value == true
    self.CancelDrag()
    self.Layout()
end

function Window:Toggle()
    if not self.Frame.Visible then
        local p, size, v = self.Position, self.Frame.AbsoluteSize, self.Viewport
        if p.X + size.X < 40 or p.Y + size.Y < 40 or p.X > v.X - 40 or p.Y > v.Y - 40 then self:Center() end
    end
    self:SetVisible(not self.Frame.Visible)
end

function Window:InitializeAccess(opts)
    self.AccessPosition = Vector2.new(8, 8)
    self.AccessConfig = {Mode = "Watermark", Transparency = 0.12, ButtonSize = 48}
    self.WatermarkConfig = {Enabled = true, Text = opts.Name or "Wolf", ShowFPS = true,
        ShowClock = false, Transparency = 0.12}
    self.QuickButtons, self.QuickButtonIds = {}, {}
    self.QuickConfig = {ButtonSize = 56, Gap = 8, Side = "Left"}
    self.QuickPage = 1
    self.QuickLayer = transparent(self.Gui, 0, 0, 0, 0)
    self.QuickLayer.Size = UDim2.fromScale(1, 1)
    self.QuickLayer.ZIndex = 15
    self.QuickLayer.Name = "QuickActions"

    local watermark = rect(self.Gui, 8, 8, 240, 42, palette[2], 8, "CanvasGroup")
    watermark.ZIndex = 25
    watermark.Name = "Watermark"
    self.Watermark = watermark
    self.WatermarkBar = rect(watermark, 0, 6, 3, 30, accent, 2)
    self.WatermarkText = text(watermark, self.WatermarkConfig.Text, 12, 5, 190, 16, 12, white)
    self.WatermarkDetail = text(watermark, "", 12, 23, 190, 13, 10, palette[3])
    local waterHit = transparent(watermark, 0, 0, 240, 42, "TextButton")
    waterHit.Size = UDim2.fromScale(1, 1)
    waterHit.ZIndex = 4
    self.WatermarkHit = waterHit
    local reopen = rect(self.Gui, 8, 8, 48, 48, palette[2], 8, "CanvasGroup")
    reopen.Name, reopen.ZIndex = "Reopen", 25
    self.Reopen = reopen
    self.ReopenIcon = iconLabel(reopen, opts.Icon or "dog", 13, 7, 22, accent, "W")
    self.ReopenCaption = text(reopen, "MENU", 0, 31, 48, 12, 8, white, "center")
    local reopenHit = transparent(reopen, 0, 0, 48, 48, "TextButton")
    reopenHit.Size, reopenHit.ZIndex = UDim2.fromScale(1, 1), 4
    self.ReopenHit = reopenHit
    local center = rect(self.Gui, 0, 0, 44, 44, palette[2], 22, "TextButton")
    center.ZIndex, center.Name, center.BackgroundTransparency = 25, "CenterTap", 0.8
    self.CenterHit = center
    self.CenterIcon = text(center, "W", 0, 0, 44, 44, 14, white, "center")

    local function accessGesture(hit)
        self:BindFloatingInput(hit, {
            GetPosition = function() return self.AccessPosition end,
            Move = function(position)
                self.AccessPosition = clampPoint(position, hit.Parent.AbsoluteSize, self.Viewport)
                self:LayoutAccess()
            end,
            Click = function() self:Toggle() end,
        })
    end
    accessGesture(waterHit)
    accessGesture(reopenHit)
    self:BindFloatingInput(center, {Click = function() self:Toggle() end})

    local pager = rect(self.Gui, 0, 0, 160, 30, palette[2], 6)
    pager.Name, pager.ZIndex = "QuickPages", 25
    self.QuickPager = pager
    self.QuickPagerText = text(pager, "", 34, 0, 92, 30, 11, white, "center")
    local prev = transparent(pager, 0, 0, 34, 30, "TextButton")
    local nextButton = transparent(pager, 126, 0, 34, 30, "TextButton")
    self.QuickPrevious, self.QuickNext = prev, nextButton
    text(prev, "‹", 0, 0, 34, 30, 22, white, "center")
    text(nextButton, "›", 0, 0, 34, 30, 22, white, "center")
    connect(prev.Activated, function() self:SetQuickPage(self.QuickPage - 1) end)
    connect(nextButton.Activated, function() self:SetQuickPage(self.QuickPage + 1) end)
    self:SetOpener(opts.Opener or {Mode = "Watermark"})
    if opts.Watermark then Library:SetWatermark(opts.Watermark) end
end

function Window:SetOpener(opts)
    opts = type(opts) == "table" and opts or {Mode = opts}
    local config = self.AccessConfig
    if opts.Mode ~= nil then
        assert(opts.Mode == "Watermark" or opts.Mode == "Button" or opts.Mode == "CenterTap", "Unknown opener mode")
        config.Mode = opts.Mode
    end
    if opts.Transparency ~= nil then config.Transparency = math.clamp(finite(opts.Transparency, 0.12), 0, 0.95) end
    if opts.ButtonSize ~= nil then config.ButtonSize = math.clamp(finite(opts.ButtonSize, 48), 32, 120) end
    if typeof(opts.Position) == "Vector2" then self.AccessPosition = opts.Position end
    self:LayoutAccess()
    return table.clone(config)
end

function Library:SetOpener(opts)
    if self.Window then return self.Window:SetOpener(opts) end
end

function Window:LayoutAccess()
    if not self.AccessConfig then return end
    local viewport, config = self.Viewport, self.AccessConfig
    local size = math.min(config.ButtonSize, viewport.X, viewport.Y)
    self.Reopen.Size = UDim2.fromOffset(size, size)
    self.ReopenIcon.Object.Position = UDim2.fromOffset((size - 22) / 2, math.max(2, size / 2 - 17))
    self.ReopenCaption.Object.Position = UDim2.fromOffset(0, size - 15)
    self.ReopenCaption:Width(size)
    local useWatermark = config.Mode == "Watermark" and self.WatermarkConfig.Enabled
    self.Watermark.Visible = useWatermark
    self.Reopen.Visible = config.Mode == "Button" or (config.Mode == "Watermark" and not useWatermark)
    self.CenterHit.Visible = config.Mode == "CenterTap"
    local active = useWatermark and self.Watermark or self.Reopen
    self.AccessPosition = clampPoint(self.AccessPosition, active.AbsoluteSize, viewport)
    local pos = UDim2.fromOffset(self.AccessPosition.X, self.AccessPosition.Y)
    self.Watermark.Position, self.Reopen.Position = pos, pos
    self.CenterHit.Position = UDim2.fromOffset(math.max(0, viewport.X / 2 - 22), math.max(0, viewport.Y / 2 - 22))
    self:LayoutQuickButtons()
    self:LayoutSettings()
end

function Window:UpdateAccess(fps)
    local config = self.WatermarkConfig
    local details = {self.Frame.Visible and "MENU OPEN" or "TAP TO OPEN"}
    if config.ShowFPS then details[#details + 1] = tostring(fps) .. " FPS" end
    if config.ShowClock then details[#details + 1] = os.date("%H:%M") end
    local detail = table.concat(details, "  ·  ")
    local width = math.max(TextService:GetTextSize(config.Text, 12, Enum.Font.Gotham, Vector2.new(800, 16)).X,
        TextService:GetTextSize(detail, 10, Enum.Font.Gotham, Vector2.new(800, 16)).X) + 28
    width = math.min(self.Viewport.X, math.clamp(width, 140, 380))
    if width ~= self.Watermark.Size.X.Offset then
        self.Watermark.Size = UDim2.fromOffset(width, math.min(42, self.Viewport.Y))
        self.WatermarkText:Width(math.max(1, width - 24))
        self.WatermarkDetail:Width(math.max(1, width - 24))
        self:LayoutAccess()
    end
    self.WatermarkText:SetText(config.Text)
    self.WatermarkDetail:SetText(detail)
    self.WatermarkDetail:Color(palette[3])
    self.Watermark.BackgroundColor3 = palette[2]
    self.WatermarkBar.BackgroundColor3 = accent
    self.Watermark.GroupTransparency = config.Transparency
    self.Reopen.BackgroundColor3 = palette[2]
    self.Reopen.GroupTransparency = self.AccessConfig.Transparency
    self.ReopenIcon:Color(accent)
    self.CenterHit.BackgroundColor3 = palette[2]
    self.CenterIcon:Color(accent)
    self.QuickPager.BackgroundColor3 = palette[2]
    for _, item in ipairs(self.QuickButtons) do item:Render() end
    local panel = self.SettingsStack[#self.SettingsStack]
    if panel then
        local ignored, parent = {}, panel.ParentPanel
        while parent do ignored[parent.Object] = true; parent = parent.ParentPanel end
        local object, visible = panel.Anchor, panel.Anchor.Parent ~= nil
        while object and visible do
            if object:IsA("GuiObject") and not object.Visible and not ignored[object] then visible = false end
            object = object.Parent
        end
        if not visible then panel:Close() end
        panel.Object.BackgroundColor3 = palette[1]
    end
end

function Window:SetQuickButtonLayout(opts)
    opts = opts or {}
    if opts.ButtonSize ~= nil then self.QuickConfig.ButtonSize = math.clamp(finite(opts.ButtonSize, 56), 32, 128) end
    if opts.Gap ~= nil then self.QuickConfig.Gap = math.clamp(finite(opts.Gap, 8), 2, 32) end
    if opts.Side ~= nil then
        assert(opts.Side == "Left" or opts.Side == "Right", "Side must be Left or Right")
        self.QuickConfig.Side = opts.Side
    end
    self:LayoutQuickButtons()
end

function Window:SetQuickPage(page)
    self.CancelDrag()
    self.QuickPage = math.clamp(math.floor(finite(page, 1)), 1, self.QuickPageCount or 1)
    self:LayoutQuickButtons()
end

function Window:LayoutQuickButtons(priority)
    if not self.QuickButtons then return end
    local v, config = self.Viewport, self.QuickConfig
    local margin = math.min(8, v.X / 8, v.Y / 8)
    local top = math.min(64, v.Y * 0.2)
    local bottom = math.min(44, v.Y * 0.15)
    local gap = config.Gap
    local size = math.max(1, math.min(config.ButtonSize, v.X - margin * 2, v.Y - top - bottom - margin))
    local columns = math.max(1, math.floor((v.X - margin * 2 + gap) / (size + gap)))
    local rows = math.max(1, math.floor((v.Y - top - bottom - margin + gap) / (size + gap)))
    local capacity = columns * rows
    local items = {}
    for _, item in ipairs(self.QuickButtons) do
        if not item.Destroyed and item.Visible then items[#items + 1] = item end
        if not item.Destroyed then item.Object.Visible = false end
    end
    self.QuickPageCount = math.max(1, math.ceil(#items / capacity))
    self.QuickPage = math.clamp(self.QuickPage, 1, self.QuickPageCount)
    self.QuickPager.Visible = self.QuickPageCount > 1
    local pagerWidth = math.min(160, v.X)
    self.QuickPager.Size = UDim2.fromOffset(pagerWidth, math.min(30, bottom))
    self.QuickPager.Position = UDim2.fromOffset((v.X - pagerWidth) / 2, v.Y - math.min(30, bottom) - margin)
    self.QuickPagerText:SetText(tostring(self.QuickPage) .. " / " .. tostring(self.QuickPageCount))
    local arrowWidth = math.min(34, pagerWidth / 3)
    self.QuickPrevious.Size = UDim2.fromOffset(arrowWidth, math.min(30, bottom))
    self.QuickNext.Size = self.QuickPrevious.Size
    self.QuickNext.Position = UDim2.fromOffset(pagerWidth - arrowWidth, 0)
    self.QuickPagerText.Object.Position = UDim2.fromOffset(arrowWidth, 0)
    self.QuickPagerText:Width(pagerWidth - arrowWidth * 2)
    local first = (self.QuickPage - 1) * capacity + 1
    local page = {}
    for i = first, math.min(#items, first + capacity - 1) do page[#page + 1] = items[i] end
    if priority then
        for _, item in ipairs(page) do
            if item == priority then removeValue(page, priority); table.insert(page, 1, priority); break end
        end
    end
    local occupied = {}
    local function slotPoint(slot)
        local column, row = math.floor((slot - 1) / rows), (slot - 1) % rows
        local x = margin + column * (size + gap)
        if config.Side == "Right" then x = v.X - margin - size - column * (size + gap) end
        return Vector2.new(x, top + row * (size + gap))
    end
    for _, item in ipairs(page) do
        local best, distance = nil, math.huge
        for slot = 1, capacity do
            if not occupied[slot] then
                if not item.Preferred then best = slot; break end
                local d = slot
                if item.Preferred then
                    local point = slotPoint(slot)
                    local dx, dy = point.X - item.Preferred.X * v.X, point.Y - item.Preferred.Y * v.Y
                    d = dx * dx + dy * dy
                end
                if d < distance then best, distance = slot, d end
            end
        end
        if best then
            occupied[best] = true
            local position = slotPoint(best)
            local dragging = self.Drag and self.Drag.Object == item.Hit
            if not dragging then item.Position = position end
            item.Object.Size = UDim2.fromOffset(size, size)
            if not dragging then item.Object.Position = UDim2.fromOffset(position.X, position.Y) end
            item.Object.Visible = true
            item.Caption.Object.Size = UDim2.new(1, -8, 0, 18)
            item.Caption.Object.Position = UDim2.new(0, 4, 1, -21)
            item.StateLabel.Object.Size = UDim2.new(1, 0, 0, 18)
            item.StateLabel.Object.Position = UDim2.fromOffset(0, 5)
            if item.Icon then item.Icon.Object.Position = UDim2.fromOffset((size - 18) / 2, 6) end
        end
    end
end

function Window:ArrangeQuickButtons()
    self.CancelDrag()
    for _, item in ipairs(self.QuickButtons) do item.Preferred = nil end
    self:LayoutQuickButtons()
end

function Window:CreateQuickButton(opts)
    opts = opts or {}
    assert(Library.Window == self, "Window is unloaded")
    local mode = opts.Mode or "Button"
    assert(mode == "Toggle" or mode == "Button", "Quick button Mode must be Toggle or Button")
    self.QuickSerial = (self.QuickSerial or 0) + 1
    local id = tostring(opts.Id or opts.Flag or ("quick_" .. tostring(self.QuickSerial)))
    assert(not self.QuickButtonIds[id], "Duplicate quick button Id: " .. id)
    local target = opts.Target or (opts.TargetFlag and Library.Elements[opts.TargetFlag])
    if opts.TargetFlag then assert(target, "Unknown TargetFlag: " .. tostring(opts.TargetFlag)) end
    if target then
        assert((mode == "Toggle" and target.Get and target.Set) or (mode == "Button" and target.Press), "Target does not support this mode")
        if mode == "Toggle" then assert(type(target:Get()) == "boolean", "Toggle Target must return a boolean") end
    end
    if opts.Flag and not target then assert(not Library.Elements[opts.Flag], "Duplicate quick button Flag") end
    local object = rect(self.QuickLayer, 0, 0, 56, 56, palette[2], opts.Round and 28 or 9, "CanvasGroup")
    object.Name = id
    local hit = transparent(object, 0, 0, 56, 56, "TextButton")
    hit.Size, hit.ZIndex = UDim2.fromScale(1, 1), 4
    local api = {Object = object, Hit = hit, Window = self, Id = id, Mode = mode, Target = target,
        Flag = opts.Flag, Visible = opts.Visible ~= false, Enabled = opts.Enabled ~= false,
        Value = opts.Default == true, Transparency = math.clamp(finite(opts.Transparency, 0.1), 0, 0.95),
        Cooldown = math.max(0, finite(opts.Cooldown, 0)), LastPress = -math.huge,
        Position = Vector2.new(0, 0), Connections = {}, Busy = false, Locked = opts.Locked == true,
        Color = typeof(opts.Color) == "Color3" and opts.Color or nil}
    api.Caption = text(object, opts.Text or opts.Name or id, 4, 34, 48, 18, 10, white, "center")
    api.StateLabel = text(object, "", 0, 5, 56, 18, 11, white, "center")
    if opts.Icon and mode == "Button" then api.Icon = iconLabel(object, opts.Icon, 19, 6, 18, white, "▶") end
    api.Stroke = new("UIStroke", object, {Thickness = 1, Color = palette[6], Transparency = 0.3})
    function api:Get()
        if self.Target and not self.Target.Destroyed then return self.Target:Get() end
        return self.Value
    end
    function api:Set(value, silent)
        if self.Destroyed or self.Mode ~= "Toggle" then return false end
        value = value == true
        if self.Target then
            if self.Target.Destroyed then return false end
            self.Target:Set(value, silent)
        elseif self.Value ~= value then
            self.Value = value
            if self.Flag then fireChange(self.Flag, value) end
            if not silent and opts.Callback then task.spawn(opts.Callback, value) end
        end
        self:Render()
        return true
    end
    function api:Press()
        if self.Destroyed or not self.Enabled or self.Busy or (self.Target and self.Target.Destroyed) then return false end
        local now = os.clock()
        if now - self.LastPress < self.Cooldown then return false end
        self.LastPress = now
        if self.Mode == "Toggle" then return self:Set(not self:Get()) end
        self.Busy = true
        task.spawn(function()
            local ok, err = pcall(function()
                if target then target:Press() elseif opts.Callback then opts.Callback() end
            end)
            self.Busy = false
            if not ok and not self.Destroyed and Library.Window == self.Window then
                Library:Notify({Title = "Ошибка действия", Text = tostring(err)})
            end
        end)
        return true
    end
    function api:SetVisible(value)
        if self.Destroyed then return end
        self.Visible = value == true
        if self.VisibilityControl and not self.VisibilityControl.Destroyed and self.VisibilityControl:Get() ~= self.Visible then
            self.VisibilityControl:Set(self.Visible)
        end
        if not self.Visible and self.Window.Drag and self.Window.Drag.Object == hit then self.Window.CancelDrag() end
        self.Window:LayoutQuickButtons()
    end
    function api:Show() self:SetVisible(true) end
    function api:Hide() self:SetVisible(false) end
    function api:SetEnabled(value) self.Enabled = value == true; self:Render() end
    function api:SetLocked(value) self.Locked = value == true end
    function api:SetColor(color) if typeof(color) == "Color3" then self.Color = color end end
    function api:SetText(value) self.Caption:SetText(value) end
    function api:SetTransparency(value) self.Transparency = math.clamp(finite(value, self.Transparency), 0, 0.95) end
    function api:SetPosition(x, y)
        if self.Destroyed then return end
        local v = self.Window.Viewport
        self.Preferred = Vector2.new(math.clamp(finite(x, 0) / math.max(1, v.X), 0, 1),
            math.clamp(finite(y, 0) / math.max(1, v.Y), 0, 1))
        self.Window:LayoutQuickButtons(self)
    end
    function api:Render()
        if self.Destroyed then return end
        local active = self.Mode == "Toggle" and self:Get() == true
        object.BackgroundColor3 = active and palette[6] or palette[2]
        object.GroupTransparency = self.Transparency
        self.Stroke.Color = active and (self.Color or accent) or palette[6]
        self.StateLabel:Color(self.Enabled and (active and (self.Color or accent) or white) or palette[3])
        self.StateLabel:SetText(not self.Enabled and "OFFLINE" or (self.Busy and "…" or
            (self.Mode == "Toggle" and (active and (opts.OnText or "ON") or (opts.OffText or "OFF")) or "▶")))
        if self.Icon then
            self.Icon.Object.Visible = self.Enabled and not self.Busy
            self.StateLabel.Object.Visible = not self.Icon.Object.Visible
            self.Icon:Color(self.Color or accent)
        end
    end
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self.Window.Drag and self.Window.Drag.Object == hit then self.Window.CancelDrag() end
        disconnectAll(self.Connections)
        if self.Flag and Library.Elements[self.Flag] == self then Library.Elements[self.Flag], Library.Flags[self.Flag] = nil, nil end
        self.Window.QuickButtonIds[self.Id] = nil
        removeValue(self.Window.QuickButtons, self)
        object:Destroy()
        if not Library.Unloading then self.Window:LayoutQuickButtons() end
    end
    api.Connections = self:BindFloatingInput(hit, {
        GetPosition = function() return api.Position end,
        Move = function(position)
            if api.Locked then return end
            api.Position = clampPoint(position, object.AbsoluteSize, self.Viewport)
            object.Position = UDim2.fromOffset(api.Position.X, api.Position.Y)
        end,
        Drop = function(cancelled)
            if not api.Destroyed then
                if not cancelled then api:SetPosition(api.Position.X, api.Position.Y) else self:LayoutQuickButtons() end
                if not cancelled and not api.Locked and opts.OnDragEnd then task.spawn(opts.OnDragEnd, api.Position) end
            end
        end,
        Click = function() api:Press() end,
    })
    api.Connections[#api.Connections + 1] = connect(object.Destroying, function() api:Destroy() end)
    if target and target.Object then
        api.Connections[#api.Connections + 1] = connect(target.Object.Destroying, function() api:Destroy() end)
    end
    self.QuickButtons[#self.QuickButtons + 1], self.QuickButtonIds[id] = api, api
    if opts.Flag and not target and mode == "Toggle" then Library.Elements[opts.Flag] = api; fireChange(opts.Flag, api.Value) end
    if typeof(opts.Position) == "Vector2" then api:SetPosition(opts.Position.X, opts.Position.Y) end
    self:LayoutQuickButtons()
    api:Render()
    return api
end

function Library:CreateQuickButton(opts)
    assert(self.Window, "CreateWindow must be called first")
    return self.Window:CreateQuickButton(opts)
end

function Tab:AddQuickButton(opts)
    opts = opts or {}
    local config = table.clone(opts.Button or {})
    config.Id = config.Id or ((opts.Flag or self.Name .. "." .. (opts.Name or "Quick")) .. ".Quick")
    config.Visible = opts.Default == true
    local quick = self.Window:CreateQuickButton(config)
    local row = self:AddToggle({Name = opts.Name or "Quick button", Description = opts.Description,
        Flag = opts.Flag, Width = opts.Width, Default = opts.Default,
        Callback = function(value)
            quick:SetVisible(value)
            if opts.Callback then opts.Callback(value) end
        end})
    row.QuickButton = quick
    quick.VisibilityControl = row
    connect(row.Object.Destroying, function() quick:Destroy() end)
    return row
end

function Window:CloseSettings()
    self.Opened = nil
    self.SettingsStack = {}
    self:LayoutSettings()
end

function Window:LayoutSettings()
    if not self.SettingsPanels then return end
    local top = self.SettingsStack[#self.SettingsStack]
    for _, panel in ipairs(self.SettingsPanels) do
        if not panel.Destroyed then
            panel.Object.Visible = self.Frame.Visible and panel == top
            local size = panel.RequestedWidth
            local s = math.max(0.01, math.min(1, (self.Viewport.X - 16) / size, (self.Viewport.Y - 16) / 100))
            local height = math.min(panel.MaxHeight, math.max(96, panel.Height + 58), math.max(40, (self.Viewport.Y - 16) / s))
            panel.Scale.Scale = s
            panel.Object.Size = UDim2.fromOffset(size, height)
            panel.Scroll.Size = UDim2.new(1, 0, 1, -40)
            local root = self.Gui.AbsolutePosition
            local anchor = panel.Anchor.AbsolutePosition - root
            local pos = clampPoint(Vector2.new(anchor.X + 30, anchor.Y), Vector2.new(size * s, height * s), self.Viewport)
            panel.Object.Position = UDim2.fromOffset(pos.X, pos.Y)
        end
    end
    self.PopupScale.Scale = top and top.Scale.Scale or self.UIScale.Scale
    if self.SettingsShield then self.SettingsShield.Visible = self.Frame.Visible and top ~= nil end
end

function Window:CreateSettings(owner, opts)
    opts = opts or {}
    assert(owner and owner.Object and owner.Tab, "Settings require an element owner")
    if owner.Settings and not owner.Settings.Destroyed then return owner.Settings end
    local card = owner.Object
    local gear = transparent(card, 5, 5, 32, 32, "TextButton")
    gear.Name, gear.ZIndex = "Settings", 8
    iconLabel(gear, {"settings", "settings-2"}, 7, 7, 18, white, "⚙")
    local originalLabels = {}
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("TextLabel") and child.Position.X.Offset <= 12 then
            originalLabels[child] = {Position = child.Position, Size = child.Size}
            child.Position = UDim2.fromOffset(child.Position.X.Offset + 34, child.Position.Y.Offset)
            child.Size = UDim2.fromOffset(math.max(1, child.Size.X.Offset - 34), child.Size.Y.Offset)
        end
    end
    local width = math.clamp(finite(opts.Width, 340), 220, 700)
    local object = rect(self.Gui, 0, 0, width, 250, palette[1], 8, "CanvasGroup")
    object.Name, object.ZIndex, object.Visible = "ElementSettings", 18, false
    object.Active = true
    if not self.SettingsShield then
        local shield = transparent(self.Gui, 0, 0, 0, 0, "TextButton")
        shield.Size, shield.ZIndex, shield.Visible = UDim2.fromScale(1, 1), 17, false
        self.SettingsShield = shield
        connect(shield.Activated, function() self:CloseSettings() end)
    end
    self.PopupLayer.ZIndex = 22
    local title = text(object, opts.Name or card.Name, 12, 0, width - 56, 38, 12, white)
    local close = transparent(object, width - 40, 0, 40, 38, "TextButton")
    text(close, "×", 0, 0, 40, 38, 22, white, "center")
    local scroll = new("ScrollingFrame", object, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40),
        CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y, Active = true})
    local page = transparent(scroll, 10, 8, width - 24, 1)
    local panel = setmetatable({Name = owner.Tab.Name .. "." .. (owner.Flag or card.Name) .. ".Settings",
        Window = self, Object = object, Anchor = gear, Owner = owner, Page = page, Scroll = scroll,
        ContentWidth = width - 24, RequestedWidth = width, MaxHeight = math.max(100, finite(opts.Height, 380)),
        Height = 0, Cursor = {X = 0, Y = 0, RowHeight = 0}, Elements = {}, Connections = {},
        RootTab = owner.Tab.RootTab or owner.Tab,
        ParentPanel = owner.Tab.IsSettings and owner.Tab or owner.Tab.SettingsContext, IsSettings = true,
        Scale = new("UIScale", object, {Scale = 1})}, {__index = Tab})
    function panel:OnGrow() self.Window:LayoutSettings() end
    function panel:Open()
        if self.Destroyed or not card.Parent then return end
        if self.Window.Current ~= self.RootTab then self.Window:SelectTab(self.RootTab) end
        self.Window:SetVisible(true)
        self.Window.CancelDrag()
        self.Window.Opened = nil
        local stack, cursor = {self}, self.ParentPanel
        while cursor do table.insert(stack, 1, cursor); cursor = cursor.ParentPanel end
        self.Window.SettingsStack = stack
        self.Window:LayoutSettings()
    end
    function panel:Close()
        local stack = self.Window.SettingsStack
        for i, item in ipairs(stack) do
            if item == self then for j = #stack, i, -1 do table.remove(stack, j) end; break end
        end
        self.Window.CancelDrag()
        self.Window.Opened = nil
        self.Window:LayoutSettings()
    end
    function panel:Toggle()
        if self.Object.Visible then self:Close() else self:Open() end
    end
    function panel:SetTitle(value) title:SetText(value) end
    function panel:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self:Close()
        for _, element in ipairs(table.clone(self.Elements)) do if element.Destroy then element:Destroy() end end
        disconnectAll(self.Connections)
        removeValue(self.Window.SettingsPanels, self)
        object:Destroy()
        gear:Destroy()
        for label, original in pairs(originalLabels) do
            if label.Parent == card then label.Position, label.Size = original.Position, original.Size end
        end
        if owner.Settings == self then owner.Settings = nil end
    end
    panel.Connections = {
        connect(gear.Activated, function() panel:Toggle() end),
        connect(close.Activated, function() panel:Close() end),
        connect(card.Destroying, function() panel:Destroy() end),
        connect(object.Destroying, function() panel:Destroy() end),
        connect(scroll:GetPropertyChangedSignal("CanvasPosition"), function() self.Opened = nil end),
    }
    self.SettingsPanels[#self.SettingsPanels + 1] = panel
    owner.Settings, owner.SettingsGear = panel, gear
    return panel
end

function Tab:AddGroup(opts)
    opts = opts or {}
    local width = self:_width(opts.Width)
    local card = self:_card(width, 38, opts.Name or "Group")
    card.ClipsDescendants = true
    local hit = transparent(card, 0, 0, width, 38, "TextButton")
    local title = text(hit, opts.Name or "Group", 12, 0, width - 44, 38, 12, white)
    local arrow = text(hit, "", width - 28, 0, 20, 38, 15, white, "center")
    local page = transparent(card, 10, 42, width - 20, 1)
    local group = setmetatable({Name = self.Name .. "." .. (opts.Name or "Group"), Window = self.Window,
        Object = card, Page = page, ContentWidth = width - 20, Height = 0, Elements = {},
        Cursor = {X = 0, Y = 0, RowHeight = 0}, Expanded = opts.Expanded ~= false, Flag = opts.Flag, IsGroup = true,
        SettingsContext = self.IsSettings and self or self.SettingsContext,
        RootTab = self.RootTab or self}, {__index = Tab})
    function group:OnGrow()
        page.Visible = self.Expanded
        card.Size = UDim2.fromOffset(width, self.Expanded and (self.Height + 52) or 38)
        arrow:SetText(self.Expanded and "−" or "+")
    end
    function group:Get() return self.Expanded end
    function group:Set(value, silent)
        self.Expanded = value == true
        self:OnGrow()
        if self.Flag then fireChange(self.Flag, self.Expanded) end
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Expanded) end
    end
    function group:SetExpanded(value) self:Set(value) end
    function group:SetTitle(value) title:SetText(value) end
    connect(hit.Activated, function() group:Set(not group.Expanded) end)
    connect(card.Destroying, function()
        for _, element in ipairs(table.clone(group.Elements)) do if element.Destroy then element:Destroy() end end
    end)
    if opts.Flag then Library.Elements[opts.Flag] = group end
    group:Set(group.Expanded, true)
    return group
end

function Tab:AddStatus(opts)
    opts = opts or {}
    local width = self:_width(opts.Width)
    local card = self:_card(width, 42, opts.Name or "Status")
    text(card, opts.Name or "Status", 10, 0, width * 0.5 - 10, 42, 12, white)
    local label = text(card, opts.Default or "Ready", width * 0.5, 0, width * 0.5 - 10, 42, 11, accent, "right")
    local api = baseApi(self, card, opts.Flag)
    local value = tostring(opts.Default or "Ready")
    function api:Get() return value end
    function api:Set(nextValue)
        value = tostring(nextValue or "")
        label:SetText(value)
        if self.Flag then fireChange(self.Flag, value) end
    end
    function api:SetColor(color) if typeof(color) == "Color3" then label:Color(color) end end
    api:Set(value)
    return api
end

function Window:GetInterfaceConfig()
    local buttons = {}
    for _, button in ipairs(self.QuickButtons) do
        buttons[button.Id] = {Visible = button.Visible, Enabled = button.Enabled, Locked = button.Locked, Transparency = button.Transparency,
            Position = button.Preferred and {X = button.Preferred.X, Y = button.Preferred.Y} or nil}
    end
    return {BoundToScreen = self.BoundToScreen, Opener = table.clone(self.AccessConfig),
        Watermark = table.clone(self.WatermarkConfig), QuickLayout = table.clone(self.QuickConfig), QuickButtons = buttons,
        QuickPage = self.QuickPage,
        WindowPosition = {X = self.Position.X / math.max(1, self.Viewport.X), Y = self.Position.Y / math.max(1, self.Viewport.Y)},
        AccessPosition = {X = self.AccessPosition.X / math.max(1, self.Viewport.X), Y = self.AccessPosition.Y / math.max(1, self.Viewport.Y)}}
end

function Window:LoadInterfaceConfig(config)
    assert(type(config) == "table", "Interface config must be a table")
    if config.BoundToScreen ~= nil then self:SetBoundsEnabled(config.BoundToScreen) end
    if config.Watermark then Library:SetWatermark(config.Watermark) end
    if config.Opener then self:SetOpener(config.Opener) end
    if type(config.AccessPosition) == "table" then
        self.AccessPosition = Vector2.new(finite(config.AccessPosition.X, 0) * self.Viewport.X,
            finite(config.AccessPosition.Y, 0) * self.Viewport.Y)
    end
    if config.QuickLayout then self:SetQuickButtonLayout(config.QuickLayout) end
    if type(config.WindowPosition) == "table" then
        self:SetPosition(finite(config.WindowPosition.X, 0) * self.Viewport.X,
            finite(config.WindowPosition.Y, 0) * self.Viewport.Y)
    end
    for id, data in pairs(config.QuickButtons or {}) do
        local button = self.QuickButtonIds[id]
        if button and type(data) == "table" then
            if data.Visible ~= nil then button:SetVisible(data.Visible) end
            if data.Enabled ~= nil then button:SetEnabled(data.Enabled) end
            if data.Locked ~= nil then button:SetLocked(data.Locked) end
            if data.Transparency ~= nil then button:SetTransparency(data.Transparency) end
            if type(data.Position) == "table" then
                button.Preferred = Vector2.new(math.clamp(finite(data.Position.X, 0), 0, 1), math.clamp(finite(data.Position.Y, 0), 0, 1))
            else button.Preferred = nil end
        end
    end
    self:LayoutAccess()
    if config.QuickPage then self:SetQuickPage(config.QuickPage) end
end

for name, factory in pairs(Tab) do
    if string.sub(name, 1, 3) == "Add" and type(factory) == "function" then
        Tab[name] = function(self, ...)
            local connectionStart, updateStart = #Runtime.Connections, #Runtime.Updates
            local popupStart, bindStart = #self.Window.Popups, #self.Window.Keybinds
            local before = table.clone(Library.Elements)
            local api = factory(self, ...)
            local object = api and api.Object
            if not object then return api end
            api.Tab = self
            api.Kind = name
            api.OwnedQuickButtons = api.OwnedQuickButtons or {}
            local ownedConnections, ownedUpdates, ownedPopups, ownedBinds, ownedFlags = {}, {}, {}, {}, {}
            for i = connectionStart + 1, #Runtime.Connections do ownedConnections[Runtime.Connections[i]] = true end
            for i = updateStart + 1, #Runtime.Updates do
                local entry = Runtime.Updates[i]
                entry.Owner = entry.Owner or object
                ownedUpdates[entry] = true
            end
            for i = popupStart + 1, #self.Window.Popups do ownedPopups[self.Window.Popups[i]] = true end
            for i = bindStart + 1, #self.Window.Keybinds do ownedBinds[self.Window.Keybinds[i]] = true end
            for flag, element in pairs(Library.Elements) do
                if before[flag] ~= element then ownedFlags[flag] = element end
            end
            local cleaned = false
            local function cleanup()
                if cleaned then return end
                cleaned = true
                api.Destroyed = true
                if api.Settings then api.Settings:Destroy() end
                if api.QuickButton then api.QuickButton:Destroy() end
                for _, quick in ipairs(api.OwnedQuickButtons) do quick:Destroy() end
                if api.IsGroup then
                    for _, element in ipairs(table.clone(api.Elements)) do
                        if element.Destroy then element:Destroy() end
                    end
                end
                local window = self.Window
                if window.Drag and (window.Drag.Object == object or window.Drag.Object:IsDescendantOf(object)) then
                    window.CancelDrag()
                end
                for i = #Runtime.Connections, 1, -1 do
                    local c = Runtime.Connections[i]
                    if ownedConnections[c] then c:Disconnect(); table.remove(Runtime.Connections, i) end
                end
                for i = #Runtime.Updates, 1, -1 do
                    if ownedUpdates[Runtime.Updates[i]] then table.remove(Runtime.Updates, i) end
                end
                for i = #window.Popups, 1, -1 do
                    local pop = window.Popups[i]
                    if ownedPopups[pop] then
                        pop:Close()
                        pop.Object:Destroy()
                        table.remove(window.Popups, i)
                    end
                end
                for i = #window.Keybinds, 1, -1 do
                    local bind = window.Keybinds[i]
                    if ownedBinds[bind] then
                        if window.PendingKeybind == bind then window.PendingKeybind = nil end
                        table.remove(window.Keybinds, i)
                    end
                end
                for flag, element in pairs(ownedFlags) do
                    if Library.Elements[flag] == element then
                        Library.Elements[flag], Library.Flags[flag], Library.Flags[flag .. ".Text"] = nil, nil, nil
                    end
                end
                for i = #self.Elements, 1, -1 do
                    if self.Elements[i] == api then table.remove(self.Elements, i) end
                end
                task.defer(function() self:_grow() end)
            end
            local destroyConnection = connect(object.Destroying, cleanup)
            ownedConnections[destroyConnection] = true
            function api:Destroy()
                if cleaned then return end
                cleanup()
                object:Destroy()
                self.Tab:_grow()
            end
            function api:SetVisible(value)
                if cleaned then return end
                object.Visible = value == true
                if not object.Visible then
                    if self.Settings then self.Settings:Close() end
                    for pop in pairs(ownedPopups) do pop:Close() end
                    if self.Tab.Window.Drag and self.Tab.Window.Drag.Object:IsDescendantOf(object) then
                        self.Tab.Window.CancelDrag()
                    end
                end
                self.Tab:_grow()
            end
            function api:CreateSettings(options)
                if cleaned then return nil end
                return self.Tab.Window:CreateSettings(self, options)
            end
            function api:CreateQuickButton(options)
                assert(not cleaned, "Element is destroyed")
                options = table.clone(options or {})
                options.Target = self
                options.Mode = options.Mode or (self.Kind == "AddToggle" and "Toggle" or "Button")
                options.Text = options.Text or object.Name
                local quick = self.Tab.Window:CreateQuickButton(options)
                self.OwnedQuickButtons[#self.OwnedQuickButtons + 1] = quick
                return quick
            end
            local options = select(1, ...)
            if type(options) == "table" and options.Settings then
                local settingsOptions = type(options.Settings) == "table" and options.Settings or {}
                local panel = api:CreateSettings(settingsOptions)
                local build = type(options.Settings) == "function" and options.Settings or settingsOptions.Build
                if build then
                    local ok, err = pcall(build, panel, api)
                    if not ok then api:Destroy(); error(err, 0) end
                end
            end
            return api
        end
    end
end

return Library
