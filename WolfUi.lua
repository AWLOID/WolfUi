-- =============================================================================
-- WolfLib v2.0.2 — UI library for Roblox (один файл, без зависимостей)
--
-- ЭТО БИБЛИОТЕКА. Сама она меню не рисует: последняя строка файла — return
-- Library. Меню появляется только когда твой скрипт вызовет CreateWindow.
-- Быстрая проверка одной строкой (можно вставить прямо в исполнитель):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/AWLOID/WolfUi/refs/heads/main/WolfUi.lua"))():Demo()
--
-- ВАЖНО: документация ниже — строчные комментарии, по два дефиса на каждой
-- строке. Блочных комментариев в файле нет намеренно: если при заливке на
-- GitHub потеряется начало файла, остаток всё равно останется валидным Lua.
--
-- Геометрия и палитра 1:1 с оригинальным меню Wolf (590x350, сайдбар 70,
-- правая полоса 30, карточки palette[2] r5). Отличия от растрового
-- оригинала только там, где просили: иконки Lucide и настоящие TextLabel
-- (работает кириллица).
--
-- -----------------------------------------------------------------------------
-- БЫСТРЫЙ СТАРТ
-- -----------------------------------------------------------------------------
--   local url = "https://raw.githubusercontent.com/AWLOID/WolfUi/refs/heads/main/WolfUi.lua"
--   local Library = loadstring(game:HttpGet(url))()
--
--   local Window = Library:CreateWindow({ Name = "Wolf", Icon = "dog" })
--   local Tab    = Window:CreateTab({ Name = "ASSIST", Icon = "crosshair" })
--
--   Tab:AddToggle({
--       Name = "Enable aimbot", Description = "Главный выключатель",
--       Flag = "aim_enabled", Default = true,
--       Keybind = Enum.KeyCode.E,             -- бинд прямо на тумблере
--       ColorPicker = { Flag = "aim_color" }, -- палитра прямо на тумблере
--       Callback = function(value) print(value) end,
--   })
--
-- -----------------------------------------------------------------------------
-- ЭЛЕМЕНТЫ (все принимают Width = 1 / 0.5 / 0.33 / 0.25)
-- -----------------------------------------------------------------------------
--   Tab:AddSection("Aimbot")
--   Tab:AddDivider()
--   Tab:AddLabel({ Text = "...", Muted, Size, Align })
--   Tab:AddParagraph({ Name = "...", Text = "многострочный текст" })
--   Tab:AddToggle({ Name, Description, Default, Flag, Keybind, ColorPicker, Callback })
--   Tab:AddSlider({ Name, Description, Min, Max, Default, Decimals, Suffix, Flag, Callback })
--   Tab:AddDropdown({ Name, Description, Options, Default, Multiple, MaxRows, Flag, Callback })
--   Tab:AddColorPicker({ Name, Description, Default, Alpha, UseAlpha, Flag, Callback })
--   Tab:AddKeybind({ Name, Description, Default, Flag, Callback })
--   Tab:AddTextBox({ Name, Placeholder, Default, MaxLength, ShowName, OnEnter, Flag, Callback })
--   Tab:AddButton({ Name, Text, Icon, Compact, Description, Callback })
--
-- Любой элемент возвращает api: api:Get(), api:Set(value), api:SetName(text),
-- api:SetVisible(bool). Дропдаун ещё api:SetOptions(list).
--
-- -----------------------------------------------------------------------------
-- БИБЛИОТЕКА
-- -----------------------------------------------------------------------------
--   Library.Version                      -- "2.0.2"
--   Library:Demo()                       -- готовое меню одной строкой (проверка)
--   Library.Flags[flag]                  -- текущее значение любого элемента
--   Library:SetFlag(flag, value) / Library:GetFlag(flag)
--   Library:OnChange(function(flag, value) end)
--   Library:Notify({ Title, Text, Duration, Icon })
--   Library:SetWatermark({ Text = "Wolf", ShowFPS = true })
--   Library:SetTheme(1..3)  Library:SetAccent(Color3, alpha)
--   Library:GetConfig() / Library:LoadConfig(table)
--   Library:SaveConfigFile(name) / LoadConfigFile(name) / ListConfigs() / DeleteConfigFile(name)
--   Library:Unload()
--   Window:SelectTab("ASSIST")  Window:SetVisible(bool)  Window:SetScale(100|75|50)
--   Window:AddRailButton({ Icon, Fallback, Callback })
--
-- События (совместимость со старым скриптом), внутри PlayerGui.WolfUI:
--   Changed.Event -> (flag, value) | TabChanged.Event -> (tab) | ButtonPressed.Event -> (name)
--
-- Масштаб меню: только 100 / 75 / 50 (при загрузке 100, больше 100 не бывает).
-- Бинды: RightShift — скрыть/показать, F1/F2 — переключение масштаба.
-- =============================================================================

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

----------------------------------------------------------------------
-- 1. Иконки Lucide
----------------------------------------------------------------------
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

-- В разных сборках icons.lua порядок {size, offset} различается.
-- Размер ячейки одинаков у всех иконок, смещение уникально — по этому и определяем.
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

----------------------------------------------------------------------
-- 2. Рантайм и примитивы
----------------------------------------------------------------------
local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local Runtime = {Connections = {}, Updates = {}, Alive = false}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    Runtime.Connections[#Runtime.Connections + 1] = connection
    return connection
end

local function step(callback)
    Runtime.Updates[#Runtime.Updates + 1] = callback
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

----------------------------------------------------------------------
-- 3. Темы, состояние, библиотека
----------------------------------------------------------------------
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

-- геометрия оригинала
local WINDOW_W, WINDOW_H = 590, 350
local SIDEBAR_W, RAIL_W = 70, 30
local CONTENT_W = WINDOW_W - SIDEBAR_W - RAIL_W -- 490
local PAD = 10
local W = CONTENT_W - PAD * 3 -- 460, 10 из которых занимает скроллбар
local GAP = 10
local TAB_SLOT = 70

local Library = {
    Version = "2.0.2",
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
            pcall(function() window.Gui:SetAttribute(attributeName(flag), value) end)
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
    index = math.clamp(math.floor(tonumber(index) or 1), 1, #themes)
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
    if alpha then
        alpha = math.clamp(alpha, 0, 1)
        state.AccentAlpha = alpha
        self.AccentAlpha = alpha
        fireChange("AccentAlpha", alpha)
    end
end

local function snapScale(value)
    value = tonumber(value) or 100
    local best, delta = Library.ScaleOptions[1], math.huge
    for _, option in ipairs(Library.ScaleOptions) do
        local d = math.abs(option - value)
        if d < delta then best, delta = option, d end
    end
    return best
end

----------------------------------------------------------------------
-- 4. Клавиши
----------------------------------------------------------------------
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
    if type(name) ~= "string" or name == "" or name == "NONE" then return nil end
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    if ok and key then return key end
    ok, key = pcall(function() return Enum.UserInputType[name] end)
    if ok and key then return key end
    return nil
end

----------------------------------------------------------------------
-- 5. Окно
----------------------------------------------------------------------
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

    local previous = playerGui:FindFirstChild(opts.GuiName or "WolfUI")
    if previous then previous:Destroy() end

    state.Theme = math.clamp(tonumber(opts.Theme) or 1, 1, #themes)
    state.Scale = snapScale(opts.Scale or 100)
    state.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or Color3.fromRGB(126, 139, 209)
    state.AccentAlpha = opts.AccentAlpha or 1
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
    }, Window)
    Library.Window = window

    local gui = new("ScreenGui", playerGui, {
        Name = opts.GuiName or "WolfUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = opts.DisplayOrder or 50,
    })
    window.Gui = gui
    window.Changed = new("BindableEvent", gui, {Name = "Changed"})
    window.TabChanged = new("BindableEvent", gui, {Name = "TabChanged"})
    window.ButtonPressed = new("BindableEvent", gui, {Name = "ButtonPressed"})

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

    ------------------------------------------------------------------
    -- масштаб / позиция
    ------------------------------------------------------------------
    local function layout()
        local camera = workspace.CurrentCamera
        if camera then window.Viewport = camera.ViewportSize end
        local viewport = window.Viewport
        local s = math.min(state.Scale / 100, (viewport.X - 16) / WINDOW_W, (viewport.Y - 16) / WINDOW_H)
        s = math.max(0.35, math.min(1, s))
        scale.Scale = s
        window.PopupScale.Scale = s
        if not window.Initialized then
            window.Position = (viewport - Vector2.new(WINDOW_W * s, WINDOW_H * s)) / 2
            window.Initialized = true
        end
        window.Position = Vector2.new(
            math.clamp(window.Position.X, 0, math.max(0, viewport.X - WINDOW_W * s)),
            math.clamp(window.Position.Y, 0, math.max(0, viewport.Y - WINDOW_H * s))
        )
        frame.Position = UDim2.fromOffset(window.Position.X, window.Position.Y)
        popupLayer.Position = frame.Position
    end
    window.Layout = layout
    layout()

    local function primary(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function draggable(object, onMove, onEnd)
        connect(object.InputBegan, function(input)
            if not primary(input) then return end
            window.Drag = {Input = input, Move = onMove, Finish = onEnd}
            onMove(Vector2.new(input.Position.X, input.Position.Y), true)
        end)
    end
    window.Draggable = draggable

    connect(UIS.InputChanged, function(input)
        local drag = window.Drag
        if not drag then return end
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
        local touch = drag.Input.UserInputType == Enum.UserInputType.Touch
            and input.UserInputType == Enum.UserInputType.Touch
        if same or mouse or touch then
            local finish = drag.Finish
            window.Drag = nil
            if finish then finish() end
        end
    end)

    connect(UIS.WindowFocusReleased, function()
        local drag = window.Drag
        window.Drag = nil
        if drag and drag.Finish then drag.Finish() end
    end)

    ------------------------------------------------------------------
    -- сайдбар
    ------------------------------------------------------------------
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

    ------------------------------------------------------------------
    -- контент
    ------------------------------------------------------------------
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

    ------------------------------------------------------------------
    -- попапы: закрытие по клику вне
    ------------------------------------------------------------------
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

    ------------------------------------------------------------------
    -- правая полоса: тема и настройки (как в оригинале)
    ------------------------------------------------------------------
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

    -- попап настроек: только 100 / 75 / 50
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

    ------------------------------------------------------------------
    -- кнопка возврата (когда меню скрыто)
    ------------------------------------------------------------------
    local reopen = rect(gui, 8, 8, 32, 32, palette[2], 5, "TextButton")
    reopen.Name = "Reopen"
    reopen.Visible = false
    local reopenIcon = iconLabel(reopen, opts.Icon or {"dog", "paw-print", "moon"}, 5, 5, 22, accent,
        string.sub(opts.Name or "W", 1, 1))
    window.Reopen = reopen
    connect(reopen.Activated, function() window:SetVisible(true) end)

    ------------------------------------------------------------------
    -- ватермарка
    ------------------------------------------------------------------
    local watermark = paint(rect(gui, 8, 8, 160, 22, palette[2], 5), 2)
    watermark.Name = "Watermark"
    watermark.Visible = false
    local watermarkText = text(watermark, "", 8, 0, 144, 22, 11, white)
    window.Watermark = watermark
    window.WatermarkText = watermarkText
    window.WatermarkConfig = {Enabled = false, Text = opts.Name or "Wolf", ShowFPS = false}

    ------------------------------------------------------------------
    -- уведомления
    ------------------------------------------------------------------
    local notifyHolder = transparent(gui, 0, 0, 250, WINDOW_H)
    notifyHolder.Name = "Notifications"
    notifyHolder.Position = UDim2.new(1, -258, 0, 8)
    notifyHolder.Size = UDim2.new(0, 250, 1, -16)
    notifyHolder.ZIndex = 30
    window.NotifyHolder = notifyHolder

    ------------------------------------------------------------------
    -- бинды и цикл отрисовки
    ------------------------------------------------------------------
    connect(UIS.InputBegan, function(input, processed)
        -- захват клавиши для keybind-элементов
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
        Runtime.Alive = false
    end)

    local fps, fpsTimer, fpsFrames = 60, 0, 0

    connect(RunService.RenderStepped, function(dt)
        if not Runtime.Alive then return end
        dt = math.min(dt, 0.1)
        local k = math.min(24 * dt, 1)

        local theme = themes[state.Theme] or themes[1]
        for i, target in ipairs(theme) do
            palette[i] = palette[i]:Lerp(target, k)
        end
        accent = accent:Lerp(state.Accent, k)

        fpsFrames = fpsFrames + 1
        fpsTimer = fpsTimer + dt
        if fpsTimer >= 0.5 then
            fps = math.floor(fpsFrames / fpsTimer + 0.5)
            fpsFrames, fpsTimer = 0, 0
        end

        local camera = workspace.CurrentCamera
        if camera and camera.ViewportSize ~= window.Viewport then layout() end

        -- ватермарка
        local wm = window.WatermarkConfig
        watermark.Visible = wm.Enabled and frame.Visible
        if watermark.Visible then
            local caption = wm.Text
            if wm.ShowFPS then caption = caption .. "  |  " .. tostring(fps) .. " fps" end
            watermarkText:SetText(caption)
            local size = TextService:GetTextSize(caption, 11, Enum.Font.Gotham, Vector2.new(400, 22))
            watermark.Size = UDim2.fromOffset(math.clamp(size.X + 18, 60, 260), 22)
            watermarkText:Width(math.clamp(size.X + 2, 40, 244))
            watermark.BackgroundColor3 = palette[2]
        end

        -- уведомления
        for index = #window.Notifications, 1, -1 do
            local notif = window.Notifications[index]
            notif.Life = notif.Life - dt
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
            reopen.BackgroundColor3 = palette[2]
            reopenIcon:Color(accent)
            reopenIcon:Alpha(state.AccentAlpha)
            return
        end

        for _, update in ipairs(Runtime.Updates) do
            update(dt, k)
        end

        -- страницы вкладок
        for _, tab in ipairs(window.TabList) do
            local active = window.Current == tab
            tab.Alpha = move(tab.Alpha, active and 1 or 0, 8 * dt)
            local page = tab.Page
            page.Visible = tab.Alpha > 0.01
            if page.Visible then
                page.GroupTransparency = 1 - tab.Alpha
            end
        end

        -- попапы (позиционирование как в оригинале — поверх анкера)
        for _, pop in ipairs(window.Popups) do
            local show = window.Opened == pop
            pop.Alpha = move(pop.Alpha, show and 1 or 0, 9 * dt)
            if pop.AnimateHeight then
                pop.CurrentHeight = approach(pop.CurrentHeight, show and pop.Height or 1, math.min(16 * dt, 1))
            else
                pop.CurrentHeight = pop.Height
            end
            local object = pop.Object
            object.Visible = pop.Alpha > 0.01 and pop.Anchor ~= nil
            object.GroupTransparency = 1 - pop.Alpha
            object.BackgroundColor3 = palette[1]
            object.Size = UDim2.fromOffset(pop.Width, math.max(1, pop.CurrentHeight))
            if object.Visible then
                local s = math.max(0.001, scale.Scale)
                local origin = (pop.Anchor.AbsolutePosition - window.Position) / s
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

----------------------------------------------------------------------
-- 6. Методы окна
----------------------------------------------------------------------
function Window:SetVisible(value)
    self.Frame.Visible = value and true or false
    self.PopupLayer.Visible = self.Frame.Visible
    self.Reopen.Visible = not self.Frame.Visible
    if not self.Frame.Visible then
        self.Opened = nil
        self.Drag = nil
        self.PendingKeybind = nil
    end
end

function Window:SetScale(value)
    local snapped = snapScale(value)
    state.Scale = snapped
    Library.Scale = snapped
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
    self.Opened = nil
    self.Current = tab
    state.Tab = tab.Name
    self.Scroll.CanvasSize = UDim2.fromOffset(0, tab.Height + PAD * 2)
    self.Scroll.CanvasPosition = Vector2.new(0, 0)
    fireChange("Tab", tab.Name)
    self.TabChanged:Fire(tab.Name)
end

function Window:CreateTab(opts)
    opts = opts or {}
    local name = opts.Name or ("Tab" .. tostring(#self.TabList + 1))
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

    -- кнопка вкладки в сайдбаре (геометрия оригинала: 70x70, иконка + подпись)
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
    Library:Unload()
end

----------------------------------------------------------------------
-- 7. Раскладка внутри вкладки
----------------------------------------------------------------------
function Tab:_width(value)
    local fraction = tonumber(value)
    if not fraction or fraction >= 1 then return W end
    local columns = math.max(1, math.floor(1 / fraction + 0.5))
    return math.floor((W - GAP * (columns - 1)) / columns)
end

function Tab:_place(w, h)
    local cursor = self.Cursor
    if cursor.X > 0 and cursor.X + w > W + 0.5 then
        cursor.Y = cursor.Y + cursor.RowHeight + GAP
        cursor.X = 0
        cursor.RowHeight = 0
    end
    local x, y = cursor.X, cursor.Y
    cursor.X = cursor.X + w + GAP
    cursor.RowHeight = math.max(cursor.RowHeight, h)
    if cursor.X >= W then
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
    local cursor = self.Cursor
    local height = cursor.Y + cursor.RowHeight
    self.Height = height
    self.Page.Size = UDim2.fromOffset(W, math.max(1, height))
    if self.Window.Current == self then
        self.Window.Scroll.CanvasSize = UDim2.fromOffset(0, height + PAD * 2)
    end
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
    function api:Destroy() card:Destroy() end
    if flag then
        Library.Elements[flag] = api
    end
    tab.Elements[#tab.Elements + 1] = api
    return api
end

----------------------------------------------------------------------
-- 8. Оформление: заголовок секции, разделитель, текст
----------------------------------------------------------------------
function Tab:AddSection(nameOrOpts)
    local opts = type(nameOrOpts) == "table" and nameOrOpts or {Name = nameOrOpts}
    self:_newline()
    local x, y = self:_place(W, 16)
    local api = muted(self.Page, string.upper(tostring(opts.Name or "Section")), x, y, W, 16, 11, nil,
        {Font = Enum.Font.GothamBold})
    self:_newline()
    self:_grow()
    return api
end

function Tab:AddDivider()
    self:_newline()
    local x, y = self:_place(W, 1)
    local line = paint(rect(self.Page, x, y + 0, W, 1, palette[4]), 4)
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
    function api:SetText(value) paragraph:SetText(value) end
    return api
end

----------------------------------------------------------------------
-- 9. Палитра цвета (используется и как элемент, и как аддон тумблера)
----------------------------------------------------------------------
local function attachColorPicker(tab, parent, x, y, size, opts)
    opts = opts or {}
    local window = tab.Window
    local flag = opts.Flag or ((opts.Name or "Color") .. "." .. tostring(tab.Name))
    local color = typeof(opts.Default) == "Color3" and opts.Default or state.Accent
    local alphaValue = opts.Alpha ~= nil and math.clamp(opts.Alpha, 0, 1) or 1
    local useAlpha = opts.UseAlpha ~= false

    local anchor = transparent(parent, x, y, size, size, "TextButton")
    anchor.ZIndex = 3
    local dot = rect(anchor, 0, 0, size, size, color, math.floor(size / 2), nil)
    dot.ZIndex = 3

    -- геометрия оригинала: 180x140, SV 140x100, hue 10x100, alpha 160x10
    local pop = createPopup(window, anchor, 180, useAlpha and 140 or 120, false)
    local host = pop.Object

    local hue, saturation, value = color:ToHSV()

    local sv = rect(host, 10, 10, 140, 100, white, 3, "TextButton")
    local svGradient = new("UIGradient", sv, {Color = ColorSequence.new(white, Color3.fromHSV(hue, 1, 1))})
    local shade = rect(sv, 0, 0, 140, 100, black, 3)
    new("UIGradient", shade, {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    })
    local svDot = transparent(sv, 0, 0, 6, 6)
    svDot.ZIndex = 3
    new("UICorner", svDot, {CornerRadius = UDim.new(1, 0)})
    new("UIStroke", svDot, {Color = white, Thickness = 2})

    local hueBar = rect(host, 160, 10, 10, 100, white, 3, "TextButton")
    local stops = {}
    for i = 0, 6 do
        stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))
    end
    new("UIGradient", hueBar, {Rotation = 90, Color = ColorSequence.new(stops)})
    local hueThumb = rect(hueBar, 0, 0, 10, 10, white, 3)
    hueThumb.ZIndex = 3

    local alphaBar, alphaGradient, alphaThumb
    if useAlpha then
        alphaBar = rect(host, 10, 120, 160, 10, white, 3, "TextButton")
        alphaGradient = new("UIGradient", alphaBar,
            {Color = ColorSequence.new(black, Color3.fromHSV(hue, 1, 1))})
        alphaThumb = rect(alphaBar, 0, 0, 10, 10, white, 3)
        alphaThumb.ZIndex = 3
    end

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
            alphaValue = math.clamp(newAlpha, 0, 1)
        end
        push()
    end

    connect(anchor.Activated, function() pop:Toggle(anchor) end)

    window.Draggable(sv, function(point)
        saturation = math.clamp((point.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        value = 1 - math.clamp((point.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        push()
    end)
    window.Draggable(hueBar, function(point)
        hue = math.clamp((point.Y - hueBar.AbsolutePosition.Y) / math.max(1, hueBar.AbsoluteSize.Y), 0, 1)
        push()
    end)
    if useAlpha then
        window.Draggable(alphaBar, function(point)
            alphaValue = math.clamp(
                (point.X - alphaBar.AbsolutePosition.X) / math.max(1, alphaBar.AbsoluteSize.X), 0, 1)
            push()
        end)
    end

    local svX, svY = 140 * saturation, 100 * (1 - value)
    local hueY, alphaX = 100 * hue, 160 * alphaValue
    local lastHue = nil

    step(function(dt, k)
        svX = approach(svX, math.clamp(140 * saturation, 4, 136), k)
        svY = approach(svY, math.clamp(100 * (1 - value), 4, 96), k)
        hueY = approach(hueY, math.clamp(100 * hue, 0, 90), k)
        svDot.Position = UDim2.fromOffset(svX - 3, svY - 3)
        hueThumb.Position = UDim2.fromOffset(0, hueY)
        if useAlpha then
            alphaX = approach(alphaX, math.clamp(160 * alphaValue, 0, 150), k)
            alphaThumb.Position = UDim2.fromOffset(alphaX, 0)
        end
        if hue ~= lastHue then
            svGradient.Color = ColorSequence.new(white, Color3.fromHSV(hue, 1, 1))
            if alphaGradient then
                alphaGradient.Color = ColorSequence.new(black, Color3.fromHSV(hue, 1, 1))
            end
            lastHue = hue
        end
        local current = Color3.fromHSV(hue, saturation, value)
        dot.BackgroundColor3 = current
        dot.BackgroundTransparency = useAlpha and (1 - alphaValue) or 0
    end)

    Library.Flags[flag] = color
    if useAlpha then Library.Flags[flag .. ".Alpha"] = alphaValue end
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

----------------------------------------------------------------------
-- 10. Keybind (элемент и аддон)
----------------------------------------------------------------------
local function attachKeybind(tab, parent, x, y, w, h, opts)
    opts = opts or {}
    local window = tab.Window
    local flag = opts.Flag or ((tab.Name or "TAB") .. "." .. (opts.Name or "Keybind"))
    local key = opts.Default
    if type(key) == "string" then key = keyFromName(key) end

    local button = paint(rect(parent, x, y, w, h, palette[1], 3, "TextButton"), 1)
    button.ZIndex = 3
    local caption = text(button, keyName(key), 0, 0, w, h, 10, palette[3], "center")

    local bind = {Key = key, Flag = flag}

    function bind:Fire()
        if opts.Callback then task.spawn(opts.Callback, self.Key) end
        if opts.Toggle then opts.Toggle() end
    end

    function bind:Set(value)
        if type(value) == "string" then value = keyFromName(value) end
        self.Key = value
        caption:SetText(keyName(value))
        Library.Flags[flag] = value and keyName(value) or "NONE"
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
        tint = tint:Lerp((hover or waiting) and white or palette[3], k)
        caption:Color(tint)
        button.BackgroundColor3 = palette[1]:Lerp(palette[4], waiting and 1 or 0)
    end)

    Library.Flags[flag] = key and keyName(key) or "NONE"
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

----------------------------------------------------------------------
-- 11. Toggle
----------------------------------------------------------------------
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

    -- аддоны справа налево, как в оригинале (палитра шла на w-48)
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
        value = newValue and true or false
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

----------------------------------------------------------------------
-- 12. Slider
----------------------------------------------------------------------
local function makeSlider(tab, parent, x, y, w, opts)
    opts = opts or {}
    local name = opts.Name or "Slider"
    local flag = opts.Flag or ((tab and tab.Name or "TAB") .. "." .. name)
    local min = tonumber(opts.Min) or 0
    local max = tonumber(opts.Max) or 100
    local decimals = math.max(0, math.floor(tonumber(opts.Decimals) or 0))
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

    local value = math.clamp(tonumber(opts.Default) or min, min, max)

    local function quantize(raw)
        if decimals <= 0 then return math.floor(raw + 0.5) end
        local m = 10 ^ decimals
        return math.floor(raw * m + 0.5) / m
    end

    local api = {Flag = flag, Object = card}

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        value = math.clamp(quantize(tonumber(newValue) or min), min, max)
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
    end, opts.OnRelease)

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

----------------------------------------------------------------------
-- 13. Dropdown
----------------------------------------------------------------------
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
    local maxRows = math.max(1, math.floor(tonumber(opts.MaxRows) or 5))
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
    if multiple then
        if type(opts.Default) == "table" then
            for _, index in ipairs(opts.Default) do selection[index] = true end
        end
    else
        selection = math.clamp(tonumber(opts.Default) or 1, 1, math.max(1, #options))
    end

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
        return names, selection
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
                    if type(key) == "number" and flagValue then
                        next_[key] = true
                    elseif type(flagValue) == "number" then
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
            selection = math.clamp(tonumber(value) or 1, 1, math.max(1, #options))
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
    function api:GetOptions() return options end

    buildRows()
    push(false)
    if opts.Callback then task.spawn(opts.Callback, selectedValue()) end
    return api
end

----------------------------------------------------------------------
-- 14. TextBox
----------------------------------------------------------------------
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

    local maxLength = math.max(1, math.floor(tonumber(opts.MaxLength) or 96))
    local api = baseApi(self, card, flag)

    local function push(fire)
        Library.Flags[flag] = box.Text
        fireChange(flag, box.Text)
        if fire and opts.Callback then task.spawn(opts.Callback, box.Text) end
    end

    connect(box:GetPropertyChangedSignal("Text"), function()
        local length = utf8.len(box.Text)
        if length and length > maxLength then
            local offset = utf8.offset(box.Text, maxLength + 1)
            if offset then
                box.Text = string.sub(box.Text, 1, offset - 1)
                return
            end
        end
        push(true)
    end)

    if opts.OnEnter then
        connect(box.FocusLost, function(enter)
            if enter then task.spawn(opts.OnEnter, box.Text) end
        end)
    end

    function api:Get() return box.Text end
    function api:Set(value, silent)
        box.Text = tostring(value or "")
        if silent then Library.Flags[flag] = box.Text end
    end
    function api:SetName(value) box.PlaceholderText = tostring(value) end

    push(false)
    return api
end

----------------------------------------------------------------------
-- 15. Button
----------------------------------------------------------------------
function Tab:AddButton(opts)
    opts = opts or {}
    local name = opts.Name or "Button"
    local w = self:_width(opts.Width)
    local compact = opts.Compact and true or false
    local card = self:_card(w, compact and 31 or 68, name)

    local control
    if compact then
        control = paint(rect(card, 0, 0, w, 31, palette[4], 5, "TextButton"), 4)
    else
        text(card, name, 10, 10, w - 20, 14, 12, white)
        if opts.Description then
            muted(card, opts.Description, 10, 22, w - 20, 14, 11)
        end
        control = paint(rect(card, 10, 27, w - 20, 31, palette[4], 3, "TextButton"), 4)
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
    connect(control.Activated, function()
        flash = 1 / 9
        if self.Window then self.Window.ButtonPressed:Fire(self.Name .. "." .. name) end
        if opts.Callback then task.spawn(opts.Callback) end
    end)

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

----------------------------------------------------------------------
-- 16. Уведомления и ватермарка
----------------------------------------------------------------------
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
        Life = tonumber(opts.Duration) or 4,
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
    config.Enabled = opts.Enabled ~= false
    return config
end

----------------------------------------------------------------------
-- 17. Конфиги
----------------------------------------------------------------------
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
    return config
end

function Library:LoadConfig(config)
    if type(config) ~= "table" then return false, "config is not a table" end
    if config.Theme then self:SetTheme(config.Theme) end
    if config.Accent then self:SetAccent(deserialize(config.Accent), config.AccentAlpha) end
    if config.Scale and self.Window then self.Window:SetScale(config.Scale) end
    for flag, raw in pairs(config.Flags or {}) do
        local element = self.Elements[flag]
        local value = deserialize(raw)
        if element and element.Set then
            pcall(function() element:Set(value) end)
        else
            self.Flags[flag] = value
        end
    end
    return true
end

local FOLDER = "WolfLib"

local function fileSupport()
    return type(writefile) == "function" and type(readfile) == "function"
end

function Library:SaveConfigFile(name)
    if not fileSupport() then return false, "executor has no file API" end
    name = tostring(name or "default")
    local ok, err = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(FOLDER) then
            makefolder(FOLDER)
        end
        writefile(FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(self:GetConfig()))
    end)
    return ok, err
end

function Library:LoadConfigFile(name)
    if not fileSupport() then return false, "executor has no file API" end
    name = tostring(name or "default")
    local path = FOLDER .. "/" .. name .. ".json"
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
        for _, path in ipairs(listfiles(FOLDER)) do
            local name = string.match(path, "([^/\\]+)%.json$")
            if name then names[#names + 1] = name end
        end
    end)
    table.sort(names)
    return names
end

function Library:DeleteConfigFile(name)
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    return pcall(function() delfile(FOLDER .. "/" .. tostring(name) .. ".json") end)
end

----------------------------------------------------------------------
-- 18. Выгрузка
----------------------------------------------------------------------
function Library:Unload()
    Runtime.Alive = false
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    Runtime.Connections, Runtime.Updates = {}, {}
    if self.Window and self.Window.Gui then
        pcall(function() self.Window.Gui:Destroy() end)
    end
    self.Window = nil
    self.Elements = {}
    for _, listener in ipairs(unloadListeners) do
        pcall(listener)
    end
    unloadListeners = {}
    changeListeners = {}
end

----------------------------------------------------------------------
-- Демо-меню: проверка, что библиотека загрузилась и рисует.
-- Одной строкой:
--   loadstring(game:HttpGet(URL))():Demo()
----------------------------------------------------------------------
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
            "F1/F2 — масштаб 100/75/50. Иконку в сайдбаре можно тянуть мышью.",
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

    self:SetWatermark({Text = "WolfLib " .. tostring(self.Version), ShowFPS = true})
    self:Notify({Title = "WolfLib", Text = "Демо-меню создано", Duration = 5})
    return window
end

-- Подсказка в консоль: чаще всего "меню не появилось" значит, что запустили
-- саму библиотеку, а не скрипт, который вызывает CreateWindow.
pcall(function()
    print("[WolfLib] v" .. tostring(Library.Version) ..
        " загружена. Это библиотека, меню появится после Library:CreateWindow(...)." ..
        " Быстрая проверка: Library:Demo()")
end)

Library.Runtime = Runtime
Library.Palette = palette
Library.Icons = IconSheet

return Library
