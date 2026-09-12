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

local function directIcon(value)
    if type(value) == "number" then
        if value <= 0 then return nil end
        return "rbxassetid://" .. tostring(math.floor(value))
    end
    if type(value) ~= "string" then return nil end
    local normalized = string.match(value, "^%s*(.-)%s*$")
    if string.match(normalized, "^%d+$") then return "rbxassetid://" .. normalized end
    if string.find(normalized, "://", 1, true) then return normalized end
    return nil
end

local function resolveIcon(value)
    if type(value) == "table" and (value.Id ~= nil or value.AssetId ~= nil or value.Image ~= nil
        or value.Url ~= nil or value.URL ~= nil) then
        local image = directIcon(value.Id or value.AssetId or value.Image or value.Url or value.URL)
        if image then
            local offset = typeof(value.RectOffset) == "Vector2" and value.RectOffset or Vector2.zero
            local size = typeof(value.RectSize) == "Vector2" and value.RectSize or Vector2.zero
            local tint = value.Tint == true
            local color = typeof(value.Color) == "Color3" and value.Color or nil
            return image, offset, size, tint, color
        end
    end

    local image = directIcon(value)
    if image then return image, Vector2.zero, Vector2.zero, false, nil end

    local names = type(value) == "table" and value or {value}
    for _, name in ipairs(names) do
        local direct = directIcon(name)
        if direct then return direct, Vector2.zero, Vector2.zero, false, nil end
        if type(name) == "string" then
            for _, variant in ipairs(nameVariants(name)) do
                local atlasImage, offset, size = iconData(variant)
                if atlasImage then return atlasImage, offset, size, true, nil end
            end
        end
    end
    return nil
end

local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local Runtime = {Connections = {}, Updates = {}, Overlay = {}, Alive = false}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    Runtime.Connections[#Runtime.Connections + 1] = connection
    return connection
end

local function isRendered(object)
    if not object or not object.Parent then return false end
    local current = object
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function addUpdate(collection, callback, object)
    local update = {Callback = callback, Object = object}
    collection[#collection + 1] = update
    return update
end

local function step(callback, object)
    return addUpdate(Runtime.Updates, callback, object)
end

local function overlayStep(callback, object)
    return addUpdate(Runtime.Overlay, callback, object)
end

local function runUpdates(collection, dt, k)
    local count = #collection
    local writeIndex = 1
    for readIndex = 1, count do
        local update = collection[readIndex]
        local object = update.Object
        if not object or object.Parent then
            collection[writeIndex] = update
            writeIndex = writeIndex + 1
            if not object or isRendered(object) then
                update.Callback(dt, k)
            end
        end
    end
    for index = count, writeIndex, -1 do
        collection[index] = nil
    end
end

local function approach(a, b, k)
    return a + (b - a) * k
end

local function motionFactor(speed, dt)
    return 1 - math.exp(-math.max(0, speed) * math.min(dt, 0.1))
end

local function roundPixel(value)
    value = tonumber(value) or 0
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

local fadeValues = setmetatable({}, {__mode = "k"})
local fadeCaches = setmetatable({}, {__mode = "k"})

local function restoreFades()
    for object, values in pairs(fadeValues) do
        if object.Parent then
            for property, value in pairs(values) do
                object[property] = value
            end
        end
        fadeValues[object] = nil
    end
end

local function fadeProperties(object)
    local properties = {}
    if object:IsA("GuiObject") then properties[#properties + 1] = "BackgroundTransparency" end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        properties[#properties + 1] = "TextTransparency"
        properties[#properties + 1] = "TextStrokeTransparency"
    elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
        properties[#properties + 1] = "ImageTransparency"
    elseif object:IsA("UIStroke") then
        properties[#properties + 1] = "Transparency"
    end
    if object:IsA("ScrollingFrame") then
        properties[#properties + 1] = "ScrollBarImageTransparency"
    end
    return properties
end

local function fadeTargets(root)
    local cache = fadeCaches[root]
    if not cache then
        cache = {Dirty = true, Targets = {}}
        fadeCaches[root] = cache
        connect(root.DescendantAdded, function() cache.Dirty = true end)
        connect(root.DescendantRemoving, function() cache.Dirty = true end)
    end
    if cache.Dirty then
        local objects = root:GetDescendants()
        objects[#objects + 1] = root
        cache.Targets = {}
        for _, object in ipairs(objects) do
            local properties = fadeProperties(object)
            if #properties > 0 then
                cache.Targets[#cache.Targets + 1] = {Object = object, Properties = properties}
            end
        end
        cache.Dirty = false
    end
    return cache.Targets
end

local function fadeGroup(root, alpha)
    if alpha >= 1 then return end
    for _, target in ipairs(fadeTargets(root)) do
        local object = target.Object
        if object == root or object.Parent then
            local values = fadeValues[object] or {}
            for _, property in ipairs(target.Properties) do
                if values[property] == nil then values[property] = object[property] end
                object[property] = 1 - (1 - object[property]) * alpha
            end
            fadeValues[object] = values
        end
    end
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
    object.Position = UDim2.fromOffset(roundPixel(x), roundPixel(y))
    object.Size = UDim2.fromOffset(math.max(0, roundPixel(w)), math.max(0, roundPixel(h)))
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
        Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
        Size = UDim2.fromOffset(math.max(0, roundPixel(w)), math.max(0, roundPixel(h))),
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
    function api:Width(v) label.Size = UDim2.fromOffset(math.max(0, roundPixel(v)), label.Size.Y.Offset) end
    return api
end

local function iconLabel(parent, names, x, y, size, color, fallback)
    local image, offset, sheetSize, tinted, customColor = resolveIcon(names)
    local object, isImage
    if image then
        isImage = true
        object = new("ImageLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
            Size = UDim2.fromOffset(roundPixel(size), roundPixel(size)),
            Image = image,
            ImageRectOffset = offset,
            ImageRectSize = sheetSize,
            ImageColor3 = customColor or (tinted and (color or white) or white),
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 2,
        })
    else
        isImage = false
        object = new("TextLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
            Size = UDim2.fromOffset(roundPixel(size), roundPixel(size)),
            Text = fallback or "*",
            Font = Enum.Font.GothamBold,
            TextSize = math.max(8, size - 4),
            TextColor3 = color or white,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2,
        })
    end
    local api = {Object = object, IsImage = isImage, Tinted = tinted == true}
    function api:Color(v)
        if isImage then
            if self.Tinted then object.ImageColor3 = v end
        else
            object.TextColor3 = v
        end
    end
    function api:Alpha(v)
        if isImage then object.ImageTransparency = 1 - v else object.TextTransparency = 1 - v end
    end
    function api:SetIcon(value)
        local replacement = iconLabel(object.Parent, value, 0, 0, size, color, fallback)
        replacement.Object.Position, replacement.Object.Size = object.Position, object.Size
        object:Destroy()
        object, isImage = replacement.Object, replacement.IsImage
        self.Object, self.IsImage, self.Tinted = object, isImage, replacement.Tinted
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
    step(function() object.BackgroundColor3 = palette[index] end, object)
    return object
end

local function muted(parent, value, x, y, w, h, size, align, opts)
    local api = text(parent, value, x, y, w, h, size, palette[3], align, opts)
    step(function() api:Color(palette[3]) end, api.Object)
    return api
end

local WINDOW_W, WINDOW_H = 590, 350
local SIDEBAR_W, RAIL_W = 70, 30
local CONTENT_W = WINDOW_W - SIDEBAR_W - RAIL_W
local PAD = 10
local W = CONTENT_W - PAD * 3
local GAP = 10
local TAB_SLOT = 70

local MINI_GAP = 8
local MINI_MARGIN = 12
local DRAG_THRESHOLD = 6
local SUB_MAX_HEIGHT = 220

local Library = {
    Version = "4.2.0",
    Flags = {},
    Elements = {},
    NoSaveFlags = {},
    Themes = themes,
    ThemeNames = {"Wolf", "Slate", "Black"},
    FadeAnimations = true,
    FadeDuration = 0.16,
    ScaleAnimations = true,
    ScaleDuration = 0.18,
    ScaleOptions = {100, 75, 50},
    Theme = 1,
    Scale = 100,
    Accent = accent,
    AccentAlpha = 1,

    Limits = {
        ClampWindow = true,
        Margin = 24,
        MinScale = 0.2,
        MaxScale = 4,
        FitViewport = true,
        SnapScale = true,
    },
    Window = nil,
    KeySystem = {Enabled = false},
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

local function fadeAlpha(current, target, dt)
    if not Library.FadeAnimations then return target end
    local nextValue = approach(current, target, motionFactor(5 / Library.FadeDuration, dt))
    if math.abs(target - nextValue) < 0.001 then return target end
    return nextValue
end

function Library:SetFadeAnimations(enabled, duration)
    self.FadeAnimations = enabled == true
    if duration ~= nil then self.FadeDuration = math.clamp(tonumber(duration) or 0.16, 0.05, 2) end
    if not self.FadeAnimations then
        restoreFades()
        local window = self.Window
        if window then
            window.Alpha = window.Visible and 1 or 0
            window.Frame.Visible = window.Visible
            window.PopupLayer.Visible = window.Visible
            for _, tab in ipairs(window.TabList) do
                tab.Alpha = window.Current == tab and 1 or 0
                tab.Page.Visible = tab.Alpha == 1
            end
            for _, pop in ipairs(window.Popups) do
                pop.Alpha = pop:IsActive() and 1 or 0
                pop.Object.Visible = pop.Alpha == 1 and pop.Anchor ~= nil
            end
        end
    end
    fireChange("FadeAnimations", self.FadeAnimations)
    return self.FadeAnimations
end

function Library:GetFadeAnimations()
    return self.FadeAnimations, self.FadeDuration
end

function Library:SetScaleAnimations(enabled, duration)
    self.ScaleAnimations = enabled == true
    if duration ~= nil then self.ScaleDuration = math.clamp(tonumber(duration) or 0.18, 0.05, 2) end
    local window = self.Window
    if window and not self.ScaleAnimations then
        window.ScaleCurrent = window.ScaleTarget
        window.UIScale.Scale = window.ScaleCurrent
        window.PopupScale.Scale = window.ScaleCurrent
        window.Layout()
    end
    fireChange("ScaleAnimations", self.ScaleAnimations)
    return self.ScaleAnimations
end

function Library:GetScaleAnimations()
    return self.ScaleAnimations, self.ScaleDuration
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

function Library:RegisterTheme(name, colors)
    assert(type(name) == "string" and name ~= "", "Theme name required")
    assert(type(colors) == "table", "Theme palette required")
    local paletteColors = colors.Palette or colors
    local theme = {}
    for i = 1, 6 do
        local color = paletteColors[i]
        if typeof(color) == "table" then color = Color3.fromRGB(color[1], color[2], color[3]) end
        assert(typeof(color) == "Color3", "Theme requires six colors")
        theme[i] = color
    end
    local index = table.find(self.ThemeNames, name) or (#themes + 1)
    themes[index], self.ThemeNames[index] = theme, name
    return index
end

local function themeIndex(value)
    if type(value) == "table" then
        return Library:RegisterTheme(value.Name or "Custom", value)
    end
    return math.clamp(math.floor(tonumber(value) or table.find(Library.ThemeNames, value) or 1), 1, #themes)
end

function Library:SetTheme(value)
    local index = themeIndex(value)
    state.Theme, self.Theme = index, index
    if type(value) == "table" and value.Accent then self:SetAccent(value.Accent, value.AccentAlpha) end
    fireChange("Theme", index)
    return index
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

function Library:SetLimits(opts)
    if type(opts) ~= "table" then return self.Limits end
    for key, value in pairs(opts) do
        self.Limits[key] = value
    end
    if self.Window then self.Window.Layout() end
    return self.Limits
end

function Library:SetScaleOptions(list)
    local options = {}
    for _, value in ipairs(list or {}) do
        local number = tonumber(value)
        if number and number > 0 then options[#options + 1] = math.floor(number) end
    end
    if #options == 0 then return self.ScaleOptions end
    self.ScaleOptions = options
    if self.Window and self.Window.RebuildScaleButtons then
        self.Window.RebuildScaleButtons()
    end
    return self.ScaleOptions
end

local function snapScale(value)
    value = tonumber(value) or 100
    if Library.Limits and Library.Limits.SnapScale == false then
        return math.clamp(value, 5, 400)
    end
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
    if type(name) ~= "string" or name == "" or name == "NONE" then return nil end
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

local function createPopup(window, anchor, w, h, animateHeight, parentPopup)
    local object = rect(window.PopupLayer, 0, 0, w, h, palette[1], 5, "Frame")
    object.Name = "Popup"
    object.Visible = false
    object.Active = true
    object.ClipsDescendants = true

    local depth = parentPopup and (parentPopup.Depth + 1) or 0
    object.ZIndex = 1 + depth * 2

    local data = {
        Object = object,
        Anchor = anchor,
        Width = w,
        Height = h,
        Alpha = 0,
        Depth = depth,
        Parent = parentPopup,
        CurrentHeight = animateHeight and 1 or h,
        AnimateHeight = animateHeight and true or false,
    }
    window.Popups[#window.Popups + 1] = data

    function data:IsActive()
        local current = window.Opened
        while current do
            if current == self then return true end
            current = current.Parent
        end
        return false
    end
    function data:Open(anchorOverride)
        if anchorOverride then self.Anchor = anchorOverride end
        window.Opened = self
    end
    function data:Close()
        if self:IsActive() then window.Opened = self.Parent end
    end
    function data:Toggle(anchorOverride)
        if window.Opened == self then
            window.Opened = self.Parent
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

    Runtime.Connections, Runtime.Updates, Runtime.Overlay, Runtime.Alive = {}, {}, {}, true
    Library:SetScriptName(opts.Folder or opts.ScriptName or opts.Name)
    if opts.FadeAnimations ~= nil or opts.FadeDuration ~= nil then
        self:SetFadeAnimations(opts.FadeAnimations == nil and self.FadeAnimations or opts.FadeAnimations, opts.FadeDuration)
    end
    if opts.ScaleAnimations ~= nil or opts.ScaleDuration ~= nil then
        self:SetScaleAnimations(opts.ScaleAnimations == nil and self.ScaleAnimations or opts.ScaleAnimations, opts.ScaleDuration)
    end

    local previous = playerGui:FindFirstChild(opts.GuiName or "WolfUI")
    if previous then previous:Destroy() end

    state.Theme = themeIndex(opts.Theme or 1)
    state.Scale = snapScale(opts.Scale or 100)
    local themeAccent = type(opts.Theme) == "table" and opts.Theme.Accent
    state.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or (typeof(themeAccent) == "Color3" and themeAccent or Color3.fromRGB(126, 139, 209))
    state.AccentAlpha = opts.AccentAlpha or 1
    state.Tab = nil
    accent = state.Accent
    for i, color in ipairs(themes[state.Theme]) do palette[i] = color end
    Library.Theme, Library.Scale = state.Theme, state.Scale
    Library.Accent, Library.AccentAlpha = state.Accent, state.AccentAlpha

    local defaultIcon = {"dog", "paw-print", "moon"}
    local mainIcon = opts.MainIcon or opts.Icon or defaultIcon
    local watermarkIconValue = opts.WatermarkIcon or mainIcon
    local openIcon = opts.OpenIcon or opts.OpenButtonIcon or mainIcon

    local window = setmetatable({
        Visible = true,
        Alpha = 1,
        Tabs = {},
        TabList = {},
        Popups = {},
        Opened = nil,
        Keybinds = {},
        Notifications = {},
        Current = nil,
        RailCount = 0,
        Mini = {},
        MiniPositions = {},
        FPS = 60,
        Ping = 0,
        Drag = nil,
        Position = Vector2.new(0, 0),
        Viewport = Vector2.new(1280, 720),
        ScaleCurrent = 1,
        ScaleTarget = 1,
        Initialized = false,
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

    local frame = paint(rect(gui, 0, 0, WINDOW_W, WINDOW_H, palette[1], 5, "Frame"), 1)
    frame.Name = "Window"
    frame.Active = true
    frame.ClipsDescendants = true
    window.Frame = frame

    local scale = new("UIScale", frame, {Scale = 1})
    window.UIScale = scale

    local popupLayer = transparent(gui, 0, 0, WINDOW_W, WINDOW_H, "Frame")
    popupLayer.Name = "Popups"
    popupLayer.ZIndex = 10
    window.PopupLayer = popupLayer
    window.PopupScale = new("UIScale", popupLayer, {Scale = 1})

    local function targetScale()
        local camera = workspace.CurrentCamera
        if camera then window.Viewport = camera.ViewportSize end
        local viewport = window.Viewport
        local limits = Library.Limits
        local s = state.Scale / 100
        if limits.FitViewport ~= false then
            s = math.min(s, (viewport.X - 16) / WINDOW_W, (viewport.Y - 16) / WINDOW_H)
        end
        return math.clamp(s, tonumber(limits.MinScale) or 0.2, tonumber(limits.MaxScale) or 4)
    end

    local function layout(immediate)
        window.ScaleTarget = targetScale()
        local viewport = window.Viewport
        if not window.Initialized or immediate or not Library.ScaleAnimations then
            window.ScaleCurrent = window.ScaleTarget
        end
        local s = window.ScaleCurrent
        scale.Scale = s
        window.PopupScale.Scale = s
        if not window.Initialized then
            window.Position = (viewport - Vector2.new(WINDOW_W * s, WINDOW_H * s)) / 2
            window.Initialized = true
        end

        local limitsClamp = Library.Limits
        if limitsClamp.ClampWindow ~= false then
            local keep = tonumber(limitsClamp.Margin) or 24
            window.Position = Vector2.new(
                math.clamp(window.Position.X, keep - WINDOW_W * s, math.max(keep - WINDOW_W * s, viewport.X - keep)),
                math.clamp(window.Position.Y, keep - WINDOW_H * s, math.max(keep - WINDOW_H * s, viewport.Y - keep))
            )
        end
        window.Position = Vector2.new(math.floor(window.Position.X + 0.5), math.floor(window.Position.Y + 0.5))
        frame.Position = UDim2.fromOffset(window.Position.X, window.Position.Y)
        popupLayer.Position = frame.Position
    end
    window.Layout = layout
    function window.StepScale(dt)
        local previousViewport = window.Viewport
        local target = targetScale()
        window.ScaleTarget = target
        local current = window.ScaleCurrent
        local changed = false
        if not Library.ScaleAnimations then
            changed = current ~= target
            window.ScaleCurrent = target
        elseif math.abs(target - current) > 0.0005 then
            local duration = math.max(0.05, Library.ScaleDuration)
            local nextScale = approach(current, target, motionFactor(5 / duration, dt))
            if math.abs(target - nextScale) < 0.0005 then nextScale = target end
            window.Position = window.Position + Vector2.new(WINDOW_W, WINDOW_H) * ((current - nextScale) / 2)
            window.ScaleCurrent = nextScale
            changed = true
        else
            window.ScaleCurrent = target
        end
        if changed or window.Viewport ~= previousViewport then layout(false) end
    end
    layout(true)

    local function primary(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function cancelDrag()
        local drag = window.Drag
        window.Drag = nil
        if drag and drag.Finish then drag.Finish(true, drag.Moved) end
    end
    window.CancelDrag = cancelDrag

    local dragTargets = setmetatable({}, {__mode = "k"})
    local function topTarget(point)
        local ok, objects = pcall(function() return host:GetGuiObjectsAtPosition(point.X, point.Y) end)
        if not ok then return nil end
        for _, hit in ipairs(objects) do
            local current = hit
            while current and current ~= gui do
                if dragTargets[current] then return current end
                current = current.Parent
            end
        end
    end
    local function draggable(object, onMove, onEnd, threshold)
        object.Active = true
        dragTargets[object] = true
        connect(object.InputBegan, function(input)
            if not primary(input) or window.Drag then return end
            local point = Vector2.new(input.Position.X, input.Position.Y)
            local top = topTarget(point)
            if top and top ~= object then return end
            window.Drag = {Input = input, Object = object, Start = point,
                Move = onMove, Finish = onEnd, Moved = false, Threshold = threshold or 0}
            onMove(point, true)
        end)
        connect(object.Destroying, function()
            if window.Drag and window.Drag.Object == object then cancelDrag() end
        end)
    end
    window.Draggable = draggable

    local function updateDrag(input)
        local drag = window.Drag
        if not drag then return end
        if input ~= drag.Input and not (drag.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if (point - drag.Start).Magnitude >= drag.Threshold then drag.Moved = true end
        if drag.Moved then drag.Move(point, false) end
    end
    connect(UIS.InputChanged, updateDrag)
    connect(UIS.InputEnded, function(input)
        local drag = window.Drag
        if not drag or input ~= drag.Input then return end
        if input.UserInputType == Enum.UserInputType.Touch then updateDrag(input) end
        window.Drag = nil
        if drag.Finish then drag.Finish(false, drag.Moved) end
    end)
    connect(UIS.WindowFocusReleased, cancelDrag)

    local sidebar = paint(rect(frame, 0, 0, SIDEBAR_W, WINDOW_H, palette[2]), 2)
    sidebar.Name = "Sidebar"
    window.Sidebar = sidebar

    local logoHit = transparent(sidebar, 0, 0, SIDEBAR_W, TAB_SLOT, "TextButton")
    local logoIcon = iconLabel(logoHit, mainIcon,
        (SIDEBAR_W - 22) / 2, 24, 22, accent, string.sub(opts.Name or "W", 1, 1))
    step(function()
        logoIcon:Color(accent)
        logoIcon:Alpha(state.AccentAlpha)
    end, logoHit)

    window.LogoIcon = logoIcon
    window.Icon = mainIcon
    window.MainIcon = mainIcon
    window.WatermarkIconValue = watermarkIconValue
    window.OpenIcon = openIcon
    window.IconFallback = string.sub(opts.Name or "W", 1, 1)

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

    local scroll = new("ScrollingFrame", frame, {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(SIDEBAR_W, 0),
        Size = UDim2.fromOffset(CONTENT_W, WINDOW_H),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0,
        ScrollBarImageColor3 = palette[4],
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        Active = true,
    })
    window.Scroll = scroll

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

            local current = window.Opened
            while current do
                if inside(point, current.Object) or inside(point, current.Anchor) then break end
                current = current.Parent
            end
            window.Opened = current
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
        end, hit)
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
    local scaleHolder = transparent(settingsPopup.Object, 10, 26, 180, 31)
    local scaleButtons = {}

    local function rebuildScaleButtons()
        for _, old in ipairs(scaleButtons) do old:Destroy() end
        scaleButtons = {}
        local options = Library.ScaleOptions
        local count = math.max(1, #options)
        local perRow = math.min(3, count)
        local rows = math.ceil(count / perRow)
        local buttonW = math.floor((180 - (perRow - 1) * 9) / perRow)
        for index, option in ipairs(options) do
            local row = math.floor((index - 1) / perRow)
            local column = (index - 1) % perRow
            local button = paint(rect(scaleHolder, column * (buttonW + 9), row * 40, buttonW, 31,
                palette[4], 3, "TextButton"), 4)
            local caption = text(button, tostring(option) .. "%", 0, 0, buttonW, 31, 11, palette[3], "center")
            connect(button.Activated, function() window:SetScale(option) end)
            local hover, a, tint = false, 0, palette[3]
            connect(button.MouseEnter, function() hover = true end)
            connect(button.MouseLeave, function() hover = false end)
            step(function(dt, k)
                local active = state.Scale == option
                a = approach(a, active and 1 or 0, k)
                button.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 1 or 0)
                tint = tint:Lerp(active and white or palette[3], k)
                caption:Color(tint)
            end, button)
            scaleButtons[#scaleButtons + 1] = button
        end
        scaleHolder.Size = UDim2.fromOffset(180, rows * 40 - 9)

        settingsPopup.Height = 26 + rows * 40 - 9 + 15
    end
    window.RebuildScaleButtons = rebuildScaleButtons
    rebuildScaleButtons()
    connect(settingsButton.Activated, function() settingsPopup:Toggle(settingsButton) end)

    local miniLayer = new("Frame", gui, {
        Name = "Floating",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 40,
    })
    window.MiniLayer = miniLayer
    window.MiniDock = {X = MINI_MARGIN, Y = 120}

    local function layoutMini()
        local viewport = window.Viewport
        local dock = window.MiniDock
        local x, y, columnWidth = dock.X, dock.Y, 0
        for _, mini in ipairs(window.Mini) do
            if not mini.Destroyed and mini.Enabled then
                local width, height = mini.Width, mini.Height
                do
                    if y > dock.Y and y + height > viewport.Y - MINI_MARGIN then
                        x = x + columnWidth + MINI_GAP
                        y = dock.Y
                        columnWidth = 0
                    end
                    if x + width > viewport.X - MINI_MARGIN then
                        x = MINI_MARGIN
                    end
                    mini.Slot = Vector2.new(x, y)
                    y = y + height + MINI_GAP
                    columnWidth = math.max(columnWidth, width)
                end
                local target = mini.Custom and mini.Position or mini.Slot
                target = Vector2.new(
                    math.clamp(target.X, MINI_MARGIN, math.max(MINI_MARGIN, viewport.X - width - MINI_MARGIN)),
                    math.clamp(target.Y, MINI_MARGIN, math.max(MINI_MARGIN, viewport.Y - height - MINI_MARGIN))
                )
                if mini.Custom then mini.Position = target end
                mini.Target = target
            end
        end
    end
    window.LayoutMini = layoutMini

    local reopen = rect(miniLayer, 8, 8, 32, 32, palette[2], 5, "TextButton")
    reopen.Name = "Open"
    reopen.Visible = false
    reopen.ZIndex = 41
    local reopenStroke = new("UIStroke", reopen, {Color = palette[5], Thickness = 1, Transparency = 0.4})
    local reopenIcon = iconLabel(reopen, openIcon, 5, 5, 22, accent,
        string.sub(opts.Name or "W", 1, 1))
    window.Reopen = reopen
    window.ReopenIcon = reopenIcon

    local watermark = rect(gui, 8, 8, 160, 22, palette[2], 5, "TextButton")
    watermark.Name = "Watermark"
    watermark.Visible = false
    watermark.ZIndex = 42
    watermark.BackgroundTransparency = 1
    watermark.ClipsDescendants = true
    local watermarkText = text(watermark, "", 28, 0, 144, 22, 11, white)
    local watermarkIcon = iconLabel(watermark, watermarkIconValue, 7, 3, 16, accent, window.IconFallback)
    window.WatermarkIcon = watermarkIcon
    window.Watermark = watermark
    window.WatermarkText = watermarkText
    window.WatermarkConfig = {
        Enabled = false,
        Text = opts.Name or "Wolf",
        ShowFPS = false,
        ShowPing = false,
        ShowTime = false,
        Transparency = 0,
        Toggle = true,
        AlwaysVisible = false,
        Position = Vector2.new(8, 8),
    }
    local initialOpenMode = string.lower(tostring(type(opts.OpenMode) == "table" and opts.OpenMode.Mode or opts.OpenMode or "button"))
    if initialOpenMode ~= "watermark" then initialOpenMode = "button" end
    window.OpenConfig = {
        Mode = initialOpenMode,
        AlwaysVisible = opts.OpenAlways ~= false,
        Size = math.max(24, math.floor(tonumber(opts.OpenSize) or 32)),
        Width = math.max(24, math.floor(tonumber(opts.OpenWidth or opts.OpenSize) or 32)),
        Height = math.max(24, math.floor(tonumber(opts.OpenHeight or opts.OpenSize) or 32)),
        Transparency = 0,
        AnimationDuration = 0.18,
        Position = Vector2.new(8, 8),
    }

    function window.UpdateOpenVisibility()
        window.OpenerDirty = true
    end

    local tooltip = rect(gui, 0, 0, 10, 20, palette[1], 3)
    tooltip.Name = "Tooltip"
    tooltip.Visible = false
    tooltip.ZIndex = 60
    new("UIStroke", tooltip, {Color = palette[5], Thickness = 1, Transparency = 0.4})
    local tooltipText = text(tooltip, "", 6, 0, 10, 20, 11, white)

    local function floating(object, config, onPress, onDrop)
        local startPoint, startPos
        draggable(object, function(point, initial)
            if initial then
                startPoint = point
                startPos = Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
                return
            end
            local target = startPos + point - startPoint
            local size, viewport = object.AbsoluteSize, window.Viewport
            local margin = onDrop and MINI_MARGIN or 0
            target = Vector2.new(
                math.floor(math.clamp(target.X, margin, math.max(margin, viewport.X - size.X - margin)) + 0.5),
                math.floor(math.clamp(target.Y, margin, math.max(margin, viewport.Y - size.Y - margin)) + 0.5)
            )
            config.Position = target
            if onDrop then config.Custom, config.Target = true, target end
            object.Position = UDim2.fromOffset(roundPixel(target.X), roundPixel(target.Y))
        end, function(cancelled, moved)
            if cancelled then return end
            if moved then
                if onDrop then onDrop() end
            elseif onPress then onPress() end
        end, DRAG_THRESHOLD)
    end
    window.Floating = floating

    floating(reopen, window.OpenConfig, function()
        window:SetVisible(not window.Visible)
    end)
    connect(watermark.Activated, function()
        if window.OpenConfig.Mode == "watermark" and window.WatermarkConfig.Enabled
            and window.WatermarkConfig.Toggle ~= false then
            window:SetVisible(not window.Visible)
        end
    end)

    local watermarkCaption = nil
    local watermarkWidth = 160
    local tooltipCaption = nil
    local tooltipWidth = 0
    local openerBlend = initialOpenMode == "watermark" and 1 or 0
    window.OpenerBlend = openerBlend

    overlayStep(function(dt, k)
        local viewport = window.Viewport
        local oc = window.OpenConfig
        local wm = window.WatermarkConfig
        local hidden = not window.Visible
        local watermarkMode = oc.Mode == "watermark"
        local targetBlend = watermarkMode and 1 or 0
        openerBlend = approach(openerBlend, targetBlend,
            motionFactor(5 / math.max(0.05, tonumber(oc.AnimationDuration) or 0.18), dt))
        if math.abs(openerBlend - targetBlend) < 0.001 then openerBlend = targetBlend end
        window.OpenerBlend = openerBlend

        if wm.Enabled or openerBlend > 0 then
            local parts = {tostring(wm.Text or "")}
            if wm.ShowFPS then parts[#parts + 1] = tostring(window.FPS) .. " fps" end
            if wm.ShowPing then parts[#parts + 1] = tostring(window.Ping) .. " ms" end
            if wm.ShowTime then parts[#parts + 1] = os.date("%H:%M:%S") end
            local caption = table.concat(parts, "  |  ")
            if caption ~= watermarkCaption then
                watermarkCaption = caption
                watermarkText:SetText(caption)
                local bounds = TextService:GetTextSize(caption, 11, Enum.Font.Gotham, Vector2.new(4000, 22))
                watermarkWidth = math.max(60, bounds.X + 38)
                watermark.Size = UDim2.fromOffset(roundPixel(watermarkWidth), 22)
                watermarkText:Width(math.max(40, bounds.X + 2))
            end
        end

        local buttonSize = Vector2.new(oc.Width, oc.Height)
        local watermarkSize = Vector2.new(watermarkWidth, 22)
        local buttonPosition = Vector2.new(
            math.clamp(oc.Position.X, 0, math.max(0, viewport.X - buttonSize.X)),
            math.clamp(oc.Position.Y, 0, math.max(0, viewport.Y - buttonSize.Y))
        )
        local watermarkPosition = Vector2.new(
            math.clamp(wm.Position.X, 0, math.max(0, viewport.X - watermarkSize.X)),
            math.clamp(wm.Position.Y, 0, math.max(0, viewport.Y - watermarkSize.Y))
        )
        oc.Position, wm.Position = buttonPosition, watermarkPosition

        local currentSize = buttonSize:Lerp(watermarkSize, openerBlend)
        local currentPosition = buttonPosition:Lerp(watermarkPosition, openerBlend)
        local buttonAvailable = hidden or oc.AlwaysVisible
        local watermarkAvailable = wm.Enabled == true
        local transitioning = openerBlend > 0.001 and openerBlend < 0.999
        local showOpener = window.KeyLocked ~= true and (transitioning
            or (watermarkMode and watermarkAvailable) or (not watermarkMode and buttonAvailable))

        reopen.Visible = showOpener
        watermark.Visible = showOpener and openerBlend > 0.001
        reopen.Interactable = showOpener and not watermarkMode
        watermark.Interactable = showOpener and watermarkMode
        if showOpener then
            reopen.Position = UDim2.fromOffset(roundPixel(currentPosition.X), roundPixel(currentPosition.Y))
            reopen.Size = UDim2.fromOffset(roundPixel(currentSize.X), roundPixel(currentSize.Y))
            watermark.Position = reopen.Position
            watermark.Size = reopen.Size
            reopen.BackgroundColor3 = palette[2]
            local buttonTransparency = math.clamp(tonumber(oc.Transparency) or 0, 0, 1)
            local watermarkTransparency = math.clamp(tonumber(wm.Transparency) or 0, 0, 1)
            local transparency = buttonTransparency + (watermarkTransparency - buttonTransparency) * openerBlend
            reopen.BackgroundTransparency = transparency
            watermark.BackgroundTransparency = 1
            reopenStroke.Color = palette[5]
            reopenIcon:Color(accent)
            watermarkIcon:Color(accent)
            local buttonIconSize = math.min(buttonSize.X, buttonSize.Y) * 0.68
            local buttonIconPosition = Vector2.new(
                (buttonSize.X - buttonIconSize) / 2,
                (buttonSize.Y - buttonIconSize) / 2
            )
            local iconPosition = buttonIconPosition:Lerp(Vector2.new(7, 3), openerBlend)
            local iconSize = buttonIconSize + (16 - buttonIconSize) * openerBlend
            reopenIcon.Object.Position = UDim2.fromOffset(roundPixel(iconPosition.X), roundPixel(iconPosition.Y))
            reopenIcon.Object.Size = UDim2.fromOffset(roundPixel(iconSize), roundPixel(iconSize))
            reopenIcon:Alpha((1 - openerBlend) * state.AccentAlpha * (1 - buttonTransparency))
            watermarkIcon:Alpha(openerBlend * state.AccentAlpha * (1 - watermarkTransparency))
            watermarkText:Alpha(openerBlend * (1 - watermarkTransparency))
            reopenStroke.Transparency = 0.4 + 0.6 * transparency
        end

        if window.Visible and window.TooltipText and window.TooltipObject
            and window.TooltipObject.Parent then
            local caption = window.TooltipText
            if caption ~= tooltipCaption then
                tooltipCaption = caption
                local bounds = TextService:GetTextSize(caption, 11, Enum.Font.Gotham, Vector2.new(4000, 20))
                tooltipWidth = bounds.X + 12
                tooltipText:SetText(caption)
                tooltipText:Width(bounds.X + 2)
                tooltip.Size = UDim2.fromOffset(roundPixel(tooltipWidth), 20)
            end
            tooltip.Visible = true
            tooltip.BackgroundColor3 = palette[1]
            local origin = window.TooltipObject.AbsolutePosition
            tooltip.Position = UDim2.fromOffset(
                math.clamp(origin.X, 0, math.max(0, viewport.X - tooltipWidth)),
                math.clamp(origin.Y - 24, 0, math.max(0, viewport.Y - 20))
            )
        else
            tooltip.Visible = false
        end
    end)

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

        local hit = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
        for _, bind in ipairs(window.Keybinds) do
            if bind.Key ~= nil and bind.Key == hit then
                bind:Fire()
            end
        end

        if input.KeyCode == (window.ToggleKey or Enum.KeyCode.RightShift) then
            window:SetVisible(not window.Visible)
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

    window.ToggleKey = type(opts.ToggleKey) == "string" and keyFromName(opts.ToggleKey) or opts.ToggleKey or Enum.KeyCode.RightShift
    Library:SetOpenMode(type(opts.OpenMode) == "table" and opts.OpenMode or {Mode = opts.OpenMode or "button"})

    connect(gui.Destroying, function()
        Runtime.Alive = false
    end)

    local fpsTimer, fpsFrames = 0, 0

    connect(RunService.RenderStepped, function(dt)
        if not Runtime.Alive then return end
        restoreFades()
        dt = math.min(dt, 0.1)
        local k = motionFactor(18, dt)

        local theme = themes[state.Theme] or themes[1]
        for i, target in ipairs(theme) do
            palette[i] = palette[i]:Lerp(target, k)
        end
        accent = accent:Lerp(state.Accent, k)

        fpsFrames = fpsFrames + 1
        fpsTimer = fpsTimer + dt
        if fpsTimer >= 0.5 then
            window.FPS = math.floor(fpsFrames / fpsTimer + 0.5)
            fpsFrames, fpsTimer = 0, 0
            pcall(function()
                local stats = game:GetService("Stats")
                window.Ping = math.floor(
                    stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
            end)
        end

        local camera = workspace.CurrentCamera
        local viewportChanged = camera and camera.ViewportSize ~= window.Viewport
        window.StepScale(dt)
        if viewportChanged then window.LayoutMini() end

        runUpdates(Runtime.Overlay, dt, k)

        for index = #window.Notifications, 1, -1 do
            local notif = window.Notifications[index]
            notif.Life = notif.Life - dt
            local target = (notif.Life > 0) and 1 or 0
            notif.Alpha = fadeAlpha(notif.Alpha, target, dt)
            notif.Y = approach(notif.Y, notif.TargetY, motionFactor(20, dt))
            fadeGroup(notif.Object, notif.Alpha)
            notif.Object.BackgroundColor3 = palette[2]
            notif.Bar.BackgroundColor3 = accent
            notif.Icon:Color(accent)
            notif.Object.Position = UDim2.fromOffset(roundPixel(260 * (1 - notif.Alpha)), roundPixel(notif.Y))
            if notif.Life <= 0 and notif.Alpha <= 0.01 then
                notif.Object:Destroy()
                table.remove(window.Notifications, index)
            end
        end
        local offset = 0
        for _, notif in ipairs(window.Notifications) do
            notif.TargetY = offset
            offset = offset + notif.Height + 8
        end

        window.Alpha = fadeAlpha(window.Alpha, window.Visible and 1 or 0, dt)
        frame.Visible = window.Visible or window.Alpha > 0
        window.PopupLayer.Visible = frame.Visible
        if not frame.Visible then return end

        runUpdates(Runtime.Updates, dt, k)

        for _, tab in ipairs(window.TabList) do
            local active = window.Current == tab
            tab.Alpha = fadeAlpha(tab.Alpha, active and 1 or 0, dt)
            local page = tab.Page
            page.Visible = tab.Alpha > 0
            page.Interactable = active and window.Visible
            if page.Visible then
                fadeGroup(page, tab.Alpha)
            end
        end

        for _, pop in ipairs(window.Popups) do
            local show = pop:IsActive()
            local object = pop.Object
            if not show and pop.Alpha == 0 then
                object.Visible = false
                object.Interactable = false
                if pop.AnimateHeight then pop.CurrentHeight = 1 end
            else
                pop.Alpha = fadeAlpha(pop.Alpha, show and 1 or 0, dt)
                if pop.AnimateHeight then
                    pop.CurrentHeight = approach(pop.CurrentHeight, show and pop.Height or 1, motionFactor(16, dt))
                else
                    pop.CurrentHeight = pop.Height
                end
                object.Visible = pop.Alpha > 0 and pop.Anchor ~= nil
                object.Interactable = show and window.Visible
                if object.Visible then
                    fadeGroup(object, pop.Alpha)
                    object.BackgroundColor3 = palette[1]
                    object.Size = UDim2.fromOffset(roundPixel(pop.Width), math.max(1, roundPixel(pop.CurrentHeight)))
                    local s = math.max(0.001, scale.Scale)
                    local origin = (pop.Anchor.AbsolutePosition - window.Position) / s
                    local minX, minY = -window.Position.X / s, -window.Position.Y / s
                    local maxX = (window.Viewport.X - window.Position.X) / s - pop.Width
                    local maxY = (window.Viewport.Y - window.Position.Y) / s - pop.Height
                    object.Position = UDim2.fromOffset(
                        roundPixel(math.clamp(origin.X, minX, math.max(minX, maxX))),
                        roundPixel(math.clamp(origin.Y, minY, math.max(minY, maxY)))
                    )
                end
            end
        end
        fadeGroup(frame, window.Alpha)
        fadeGroup(popupLayer, window.Alpha)
    end)

    if opts.KeySystem ~= nil then
        self:SetKeySystem(opts.KeySystem)
    elseif self.KeySystem and self.KeySystem.Enabled then
        self:ShowKeySystem()
    end

    return window
end

function Window:SetVisible(value)
    if value == true and self.KeyLocked then return false end
    self.Visible = value == true
    if not Library.FadeAnimations then self.Alpha = self.Visible and 1 or 0 end
    self.Frame.Visible = self.Visible or self.Alpha > 0
    self.Frame.Interactable = self.Visible
    self.PopupLayer.Visible = self.Frame.Visible
    self.PopupLayer.Interactable = self.Visible
    if not self.Visible then
        self.Opened = nil
        self.CancelDrag()
        self.PendingKeybind = nil
    end
    if self.UpdateOpenVisibility then self.UpdateOpenVisibility() end
end

function Window:GetVisible()
    return self.Visible
end

function Window:SetFadeAnimations(enabled, duration)
    return Library:SetFadeAnimations(enabled, duration)
end

function Window:SetScaleAnimations(enabled, duration)
    return Library:SetScaleAnimations(enabled, duration)
end

function Window:SetWatermark(options)
    return Library:SetWatermark(options)
end

function Window:SetOpenMode(options)
    return Library:SetOpenMode(options)
end

function Window:SetKeySystem(options)
    return Library:SetKeySystem(options)
end

function Window:SetScale(value, exact)
    local snapped = exact and (tonumber(value) or state.Scale) or snapScale(value)
    state.Scale = snapped
    Library.Scale = snapped
    self.Layout()
    fireChange("Scale", snapped)
    return snapped
end

function Window:SetMainIcon(value)
    self.Icon = value
    self.MainIcon = value
    self.LogoIcon:SetIcon(value)
    return value
end

function Window:SetWatermarkIcon(value)
    self.WatermarkIconValue = value
    self.WatermarkIcon:SetIcon(value)
    return value
end

function Window:SetOpenIcon(value)
    self.OpenIcon = value
    self.ReopenIcon:SetIcon(value)
    return value
end

function Window:SetIcon(value)
    self:SetMainIcon(value)
    self:SetWatermarkIcon(value)
    self:SetOpenIcon(value)
    return value
end

function Library:SetMainIcon(value)
    if self.Window then return self.Window:SetMainIcon(value) end
end

function Library:SetWatermarkIcon(value)
    if self.Window then return self.Window:SetWatermarkIcon(value) end
end

function Library:SetOpenIcon(value)
    if self.Window then return self.Window:SetOpenIcon(value) end
end

function Library:SetIcon(value)
    if self.Window then return self.Window:SetIcon(value) end
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

    local page = new("Frame", self.Scroll, {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(PAD, PAD),
        Size = UDim2.fromOffset(W, 1),
        Visible = false,
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
    end, hit)

    tab.Button = hit

    if not self.Current then
        self:SelectTab(tab)
    end
    return tab
end

function Window:Destroy()
    Library:Unload()
end

function Tab:_pageWidth()
    return self.Width or W
end

function Tab:_width(value)
    local total = self:_pageWidth()
    local fraction = tonumber(value)
    if not fraction or fraction >= 1 then return total end
    local columns = math.max(1, math.floor(1 / fraction + 0.5))
    return math.floor((total - GAP * (columns - 1)) / columns)
end

function Tab:_place(w, h)
    local total = self:_pageWidth()
    local cursor = self.Cursor
    if cursor.X > 0 and cursor.X + w > total + 0.5 then
        cursor.Y = cursor.Y + cursor.RowHeight + GAP
        cursor.X = 0
        cursor.RowHeight = 0
    end
    local x, y = cursor.X, cursor.Y
    cursor.X = cursor.X + w + GAP
    cursor.RowHeight = math.max(cursor.RowHeight, h)
    if cursor.X >= total then
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
    self.Page.Size = UDim2.fromOffset(self:_pageWidth(), math.max(1, height))
    if self.OnResize then self.OnResize(height) end
    if self.Window and self.Window.Current == self then
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

local function bindTitle(api, title, opts)
    if not api or not title then return api end
    opts = opts or {}
    local label = title.Object
    local basePosition = label.Position
    local baseSize = label.Size
    local badgeObject, badgeText
    local badgeColor, badgeUsesAccent = accent, true

    local function ensureBadge()
        if badgeObject then return end
        badgeObject = rect(label.Parent, 0, 0, 30, 14, accent, 4)
        badgeObject.Name = "Badge"
        badgeObject.ZIndex = label.ZIndex + 1
        badgeText = text(badgeObject, "", 0, 0, 30, 14, 9, white, "center",
            {Font = Enum.Font.GothamBold})
        step(function()
            if badgeObject.Visible then
                badgeObject.BackgroundColor3 = badgeUsesAccent and accent or badgeColor
                badgeObject.BackgroundTransparency = 0.22
            end
        end, badgeObject)
    end

    local function setBadge(value)
        local config = type(value) == "table" and value or {Text = value}
        local caption = config.Text or config.Name or config.Label
        if value == nil or value == false or caption == nil or tostring(caption) == "" then
            if badgeObject then badgeObject.Visible = false end
            label.Position = basePosition
            label.Size = baseSize
            return
        end
        ensureBadge()
        caption = tostring(caption)
        if config.Uppercase ~= false then caption = string.upper(caption) end
        local textColor = typeof(config.TextColor) == "Color3" and config.TextColor or white
        badgeColor = typeof(config.Color) == "Color3" and config.Color
            or (typeof(opts.BadgeColor) == "Color3" and opts.BadgeColor or accent)
        badgeUsesAccent = typeof(config.Color) ~= "Color3" and typeof(opts.BadgeColor) ~= "Color3"
        local bounds = TextService:GetTextSize(caption, 9, Enum.Font.GothamBold, Vector2.new(1000, 14))
        local width = math.clamp(bounds.X + 10, 24, math.max(24, math.min(76, baseSize.X.Offset)))
        local nameBounds = TextService:GetTextSize(label.Text, label.TextSize, label.Font,
            Vector2.new(math.max(1, baseSize.X.Offset), baseSize.Y.Offset))
        local badgeX = math.min(nameBounds.X + 7, math.max(0, baseSize.X.Offset - width))
        badgeObject.Position = UDim2.fromOffset(basePosition.X.Offset + badgeX, basePosition.Y.Offset)
        badgeObject.Size = UDim2.fromOffset(width, 14)
        badgeText.Object.Size = UDim2.fromOffset(width, 14)
        badgeText:SetText(caption)
        badgeText:Color(textColor)
        badgeObject.Visible = true
        label.Position = basePosition
        label.Size = UDim2.fromOffset(math.max(8, badgeX - 5), baseSize.Y.Offset)
    end

    function api:SetName(value)
        title:SetText(value)
        if badgeObject and badgeObject.Visible then setBadge(api.BadgeValue) end
    end
    function api:SetBadge(value)
        api.BadgeValue = value
        setBadge(value)
        api.Badge = badgeObject
        return api
    end
    api:SetBadge(opts.Badge or opts.Tag)
    return api
end

local function createMiniButton(window, config)
    config = config or {}
    local size = math.max(24, math.floor(tonumber(config.Size) or 44))
    local mode = (config.Mode == "Action" or config.Mode == "Button") and "Action" or "Toggle"
    local key = tostring(config.Key or config.Flag or config.Name or ("Mini" .. tostring(#window.Mini + 1)))
    local baseKey, suffix = key, 1
    local function keyExists(value)
        for _, existing in ipairs(window.Mini) do if existing.Key == value then return true end end
        return false
    end
    while keyExists(key) do suffix = suffix + 1; key = baseKey .. "#" .. suffix end
    local radius = math.max(3, math.floor(size / 4))

    local button = rect(window.MiniLayer, MINI_MARGIN, MINI_MARGIN, size, size, palette[2], radius, "TextButton")
    button.Name = "Mini"
    button.Visible = false
    button.ZIndex = 2
    local stroke = new("UIStroke", button, {Color = palette[5], Thickness = 1, Transparency = 0.4})

    local caption = config.Text or config.Short
    local iconSize = math.floor(caption and size * 0.42 or size * 0.5)
    local iconY = caption and math.floor(size * 0.16) or math.floor((size - iconSize) / 2)
    local icon = iconLabel(button, config.Icon or {"circle"}, math.floor((size - iconSize) / 2), iconY,
        iconSize, white, config.Fallback or string.sub(tostring(config.Name or "M"), 1, 1))
    local label = text(button, caption or "", 2, math.floor(size * 0.56), size - 4, math.floor(size * 0.32),
        math.max(8, math.floor(size * 0.2)), palette[3], "center")
    label.Object.Visible = caption ~= nil

    local mini = {
        Object = button,
        Key = key,
        Mode = mode,
        Size = size,
        Width = math.max(24, math.floor(tonumber(config.Width) or size)),
        Height = math.max(24, math.floor(tonumber(config.Height) or size)),
        Transparency = math.clamp(tonumber(config.Transparency) or 0, 0, 1),
        Enabled = config.Enabled ~= false,
        Active = config.Active and true or false,
        Custom = false,
        Position = Vector2.new(MINI_MARGIN, MINI_MARGIN),
        Slot = Vector2.new(MINI_MARGIN, MINI_MARGIN),
        Target = Vector2.new(MINI_MARGIN, MINI_MARGIN),
        Config = config,
    }
    window.Mini[#window.Mini + 1] = mini

    local saved = window.MiniPositions[key]
    if type(saved) == "table" and tonumber(saved.X) and tonumber(saved.Y) then
        mini.Custom = true
        mini.Position = Vector2.new(tonumber(saved.X), tonumber(saved.Y))
        mini.Target = mini.Position
    end

    local flash = 0

    function mini:Press()
        if self.Destroyed or not self.Enabled then return end
        flash = 1 / 9
        if config.OnPress then
            config.OnPress(self)
            return
        end
        if self.Mode == "Toggle" then
            self.Active = not self.Active
        end
        if config.Callback then task.spawn(config.Callback, self.Active) end
    end

    function mini:Get() return self.Active end
    function mini:SetActive(value) self.Active = value and true or false end
    function mini:SetVisible(value)
        local enabled = value and true or false
        if self.Enabled == enabled then return end
        self.Enabled = enabled
        if not self.Enabled and window.Drag and window.Drag.Object == button then window.CancelDrag() end
        window.LayoutMini()
    end
    function mini:SetSize(width, height)
        self.Width = math.max(24, math.floor(tonumber(width) or self.Width))
        self.Height = math.max(24, math.floor(tonumber(height) or tonumber(width) or self.Height))
        self.Size = math.min(self.Width, self.Height)
        window.LayoutMini()
    end
    function mini:SetWidth(value) self:SetSize(value, self.Height) end
    function mini:SetHeight(value) self:SetSize(self.Width, value) end
    function mini:SetTransparency(value)
        self.Transparency = math.clamp(tonumber(value) or 0, 0, 1)
    end
    function mini:Show() self:SetVisible(true) end
    function mini:Hide() self:SetVisible(false) end
    function mini:SetText(value)
        caption = value ~= nil and tostring(value) or nil
        label:SetText(caption or "")
        label.Object.Visible = caption ~= nil
    end
    function mini:SetPosition(x, y)
        self.Custom = true
        self.Position = Vector2.new(tonumber(x) or MINI_MARGIN, tonumber(y) or MINI_MARGIN)
        window.LayoutMini()
        button.Position = UDim2.fromOffset(roundPixel(self.Position.X), roundPixel(self.Position.Y))
        window.MiniPositions[self.Key] = {X = self.Position.X, Y = self.Position.Y}
    end
    function mini:Reset()
        if window.Drag and window.Drag.Object == button then window.CancelDrag() end
        self.Custom = false
        window.MiniPositions[self.Key] = nil
        window.LayoutMini()
        button.Position = UDim2.fromOffset(roundPixel(self.Target.X), roundPixel(self.Target.Y))
    end
    function mini:Destroy()
        if self.Destroyed then return end
        self.Destroyed, self.Enabled = true, false
        local updateIndex = table.find(Runtime.Overlay, self.Update)
        if updateIndex then table.remove(Runtime.Overlay, updateIndex) end
        for index, item in ipairs(window.Mini) do
            if item == self then
                table.remove(window.Mini, index)
                break
            end
        end
        button:Destroy()
        window.LayoutMini()
    end

    window.Floating(button, mini, function() mini:Press() end, function()
        window.MiniPositions[mini.Key] = {X = mini.Position.X, Y = mini.Position.Y}
    end)

    local hover = false
    connect(button.MouseEnter, function() hover = true end)
    connect(button.MouseLeave, function() hover = false end)

    local alpha, tint = mini.Active and 1 or 0, palette[3]
    local function updateMini(dt, k)
        if mini.Destroyed then return end
        if config.Sync then
            local ok, value = pcall(config.Sync)
            if ok then mini.Active = value and true or false end
        end
        button.Visible = mini.Enabled and true or false
        if not mini.Enabled then return end
        flash = math.max(0, flash - dt)
        alpha = approach(alpha, mini.Active and 1 or 0, k)
        local base = palette[2]:Lerp(palette[5], hover and 0.6 or 0)
        if flash > 0 then base = palette[6] end
        button.BackgroundColor3 = base:Lerp(accent, alpha * 0.55 * state.AccentAlpha)
        button.BackgroundTransparency = mini.Transparency
        stroke.Transparency = 0.4 + 0.6 * mini.Transparency
        icon:Alpha(1 - mini.Transparency)
        local width, height = mini.Width, mini.Height
        local size = math.min(width, height)
        local iconSize = math.floor(caption and size * 0.42 or size * 0.5)
        icon.Object.Position = UDim2.fromOffset(math.floor((width - iconSize) / 2), caption and math.floor(height * 0.16) or math.floor((height - iconSize) / 2))
        icon.Object.Size = UDim2.fromOffset(iconSize, iconSize)
        button.Size = UDim2.fromOffset(width, height)
        if label then
            label:Alpha(1 - mini.Transparency)
            label.Object.Position = UDim2.fromOffset(2, math.floor(height * 0.56))
            label.Object.Size = UDim2.fromOffset(width - 4, math.floor(height * 0.32))
        end
        stroke.Color = palette[5]:Lerp(accent, alpha)
        tint = tint:Lerp(mini.Active and white or palette[3], k)
        icon:Color(tint)
        if label then label:Color(tint) end
        local target = mini.Target
        if mini.Custom then window.MiniPositions[mini.Key] = {X = mini.Position.X, Y = mini.Position.Y} end
        button.Position = UDim2.fromOffset(math.floor(target.X + 0.5), math.floor(target.Y + 0.5))
    end
    mini.Update = overlayStep(updateMini)
    window.LayoutMini()
    updateMini(0, 1)

    return mini
end

function Window:AddMiniButton(config)
    return createMiniButton(self, config or {})
end

function Window:Tooltip(object, message)
    if not object or message == nil or message == "" then return end
    local window = self
    connect(object.MouseEnter, function()
        window.TooltipText = tostring(message)
        window.TooltipObject = object
    end)
    connect(object.MouseLeave, function()
        if window.TooltipObject == object then
            window.TooltipText = nil
            window.TooltipObject = nil
        end
    end)
end

local function createSubMenu(window, anchor, opts)
    opts = opts or {}
    local width = math.max(160, math.floor(tonumber(opts.Width) or 240))
    local maxHeight = math.clamp(math.floor(tonumber(opts.MaxHeight) or SUB_MAX_HEIGHT), 140, 360)
    local pop = createPopup(window, anchor, width, 41, false, opts.ParentPopup)
    local holder = new("ScrollingFrame", pop.Object, {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(width, 41),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = palette[5],
        ScrollBarImageTransparency = 0.25,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollingEnabled = false,
        Active = true,
    })
    local page = transparent(holder, PAD, PAD, width - PAD * 2 - 5, 1)

    local menu = setmetatable({
        Name = opts.Name or "Settings",
        Title = opts.Name or "Settings",
        Window = window,
        Page = page,
        Width = width - PAD * 2 - 5,
        Popup = pop,
        ParentPopup = pop,
        Anchor = anchor,
        Cursor = {X = 0, Y = 0, RowHeight = 0},
        Elements = {},
        Height = 0,
        IsSubMenu = true,
    }, Tab)

    menu.OnResize = function(height)
        local total = math.max(31, height + PAD * 2)
        local shown = math.min(maxHeight, total)
        pop.Height = shown
        holder.Size = UDim2.fromOffset(width, shown)
        holder.CanvasSize = UDim2.fromOffset(0, total)
        holder.ScrollingEnabled = total > shown
        holder.ScrollBarImageColor3 = palette[5]
    end

    function menu:Open(anchorOverride) pop:Open(anchorOverride or anchor) end
    function menu:Close() pop:Close() end
    function menu:Toggle(anchorOverride) pop:Toggle(anchorOverride or anchor) end
    function menu:IsOpen() return pop:IsActive() end

    return menu
end

local function attachSettings(tab, parent, x, y, size, opts)
    opts = opts or {}
    local anchor = transparent(parent, x, y, size, size, "TextButton")
    anchor.ZIndex = 3
    local icon = iconLabel(anchor, opts.Icon or {"settings", "settings-2", "cog", "sliders-horizontal"},
        0, 0, size, palette[3], "*")
    local menu = createSubMenu(tab.Window, anchor, {
        Width = opts.Width,
        MaxHeight = opts.MaxHeight,
        Name = opts.Name or "Settings",
        ParentPopup = tab.ParentPopup,
    })
    connect(anchor.Activated, function() menu:Toggle(anchor) end)
    local hover, tint = false, palette[3]
    connect(anchor.MouseEnter, function() hover = true end)
    connect(anchor.MouseLeave, function() hover = false end)
    step(function(dt, k)
        tint = tint:Lerp((hover or menu:IsOpen()) and white or palette[3], k)
        icon:Color(tint)
    end, anchor)
    menu.Controls = {}
    local function addElements(items)
        if type(items) ~= "table" then return end
        local controls = menu:AddElements(items)
        for key, control in pairs(controls) do menu.Controls[key] = control end
    end
    addElements(opts.Items or opts.Elements)
    if type(opts.Build) == "function" then
        local built = opts.Build(menu)
        if type(built) == "table" and built[1] ~= nil then addElements(built) end
    end
    menu.Icon = icon
    menu.AnchorObject = anchor
    return menu
end

function Tab:AddSection(nameOrOpts)
    local opts = type(nameOrOpts) == "table" and nameOrOpts or {Name = nameOrOpts}
    self:_newline()
    local total = self:_pageWidth()
    local x, y = self:_place(total, 16)
    local api = muted(self.Page, string.upper(tostring(opts.Name or "Section")), x, y, total, 16, 11, nil,
        {Font = Enum.Font.GothamBold})
    self:_newline()
    self:_grow()
    return api
end

function Tab:AddDivider()
    self:_newline()
    local total = self:_pageWidth()
    local x, y = self:_place(total, 1)
    local line = paint(rect(self.Page, x, y + 0, total, 1, palette[4]), 4)
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
    local alphaValue = opts.Alpha ~= nil and math.clamp(opts.Alpha, 0, 1) or 1
    local useAlpha = opts.UseAlpha ~= false

    local anchor = transparent(parent, x, y, size, size, "TextButton")
    anchor.ZIndex = 3
    local dot = rect(anchor, 0, 0, size, size, color, math.floor(size / 2), nil)
    dot.ZIndex = 3
    new("UIStroke", dot, {Color = palette[5], Thickness = 1, Transparency = 0.35})

    local PW = 200
    local INNER = PW - 20
    local SV_H = 110
    local BAR_H = 8
    local SV_TOP = 10
    local HUE_TOP = SV_TOP + SV_H + 10
    local ALPHA_TOP = HUE_TOP + BAR_H + 8
    local ROW_TOP = (useAlpha and (ALPHA_TOP + BAR_H) or (HUE_TOP + BAR_H)) + 12

    local presets = {}
    for _, swatch in ipairs(type(opts.Presets) == "table" and opts.Presets or DEFAULT_PRESETS) do
        if typeof(swatch) == "Color3" then presets[#presets + 1] = swatch end
    end
    local presetsPerRow = math.max(1, math.floor((PW - 118) / 15))
    local presetRows = math.max(1, math.ceil(#presets / presetsPerRow))
    local POP_H = ROW_TOP + 20 + (presetRows - 1) * 15 + 10

    local pop = createPopup(window, anchor, PW, POP_H, false, tab.ParentPopup)
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
            alphaValue = math.clamp(newAlpha, 0, 1)
        end
        push()
    end

    for index, swatch in ipairs(presets) do
        local row = math.floor((index - 1) / presetsPerRow)
        local column = (index - 1) % presetsPerRow
        local button = rect(host, 118 + column * 15, ROW_TOP + 4 + row * 15,
            12, 12, swatch, 3, "TextButton")
        button.ZIndex = 2
        new("UIStroke", button, {Color = palette[5], Thickness = 1, Transparency = 0.5})
        connect(button.Activated, function()
            hue, saturation, value = swatch:ToHSV()
            push()
        end)
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
        svDot.Position = UDim2.fromOffset(roundPixel(svX - 5), roundPixel(svY - 5))
        hueThumb.Position = UDim2.fromOffset(roundPixel(hueX), -3)
        if useAlpha then
            alphaX = approach(alphaX, math.clamp(INNER * alphaValue, 0, INNER - 6), k)
            alphaThumb.Position = UDim2.fromOffset(roundPixel(alphaX), -3)
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
    end, preview)

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
    bindTitle(api, title, opts)
    step(function() title:Color(palette[3]:Lerp(white, 0.35)) end, card)
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
    end, button)

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
    bindTitle(api, title, opts)
    step(function() title:Color(palette[3]:Lerp(white, 0.35)) end, card)
    return api
end

function Tab:AddToggle(opts)
    opts = opts or {}
    local name = opts.Name or "Toggle"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)

    local value = opts.Default and true or false
    local api = baseApi(self, card, flag)

    local box = paint(rect(card, w - 24, 14.5, 14, 14, palette[1], 3), 1)
    local fill = rect(box, 7, 7, 0, 0, accent, 3)
    local mark = iconLabel(box, {"check"}, 1, 1, 12, black, "v")

    local edge = w - 24
    local function claim(width)
        edge = edge - 10 - width
        return edge
    end

    local colorPicker, keybind, settings, mini

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if mini and mini.Config.ShowWhenActive then mini:SetVisible(value) end
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        value = newValue and true or false
        push(not silent)
    end
    function api:Toggle() self:Set(not value) end

    if opts.ColorPicker then
        local config = type(opts.ColorPicker) == "table" and opts.ColorPicker or {}
        config.Flag = config.Flag or (flag .. ".Color")
        config.Name = config.Name or name
        colorPicker = attachColorPicker(self, card, claim(14), 14.5, 14, config)
    end

    if opts.Keybind ~= nil then
        local config = type(opts.Keybind) == "table" and opts.Keybind or {Default = opts.Keybind}
        config.Flag = config.Flag or (flag .. ".Key")
        config.Name = config.Name or name
        config.Toggle = function() api:Toggle() end
        keybind = attachKeybind(self, card, claim(46), 14.5, 46, 14, config)
    end

    if opts.Settings ~= nil then
        local config = type(opts.Settings) == "table" and opts.Settings or {Build = opts.Settings}
        config.Name = config.Name or name
        settings = attachSettings(self, card, claim(14), 14.5, 14, config)
    end

    local title = text(card, name, 10, 10, math.max(40, edge - 20), 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, math.max(40, edge - 20), 14, 11)
    end
    bindTitle(api, title, opts)

    if opts.MiniButton ~= nil and opts.MiniButton ~= false then
        local config = type(opts.MiniButton) == "table" and opts.MiniButton or {}
        config.Name = config.Name or name
        config.Key = config.Key or flag
        config.Icon = config.Icon or opts.Icon or {"zap", "circle"}
        config.Mode = "Toggle"
        config.OnPress = function() api:Toggle() end
        config.Sync = function() return value end
        config.Enabled = config.Enabled ~= false
        mini = self.Window:AddMiniButton(config)
        if config.ShowWhenActive then
            mini:SetVisible(value)
        end
    end

    local hit = transparent(card, 0, 0, w, 43, "TextButton")
    hit.ZIndex = 1
    connect(hit.Activated, function() api:Set(not value) end)
    if opts.Tooltip then self.Window:Tooltip(hit, opts.Tooltip) end

    local a, tint = value and 1 or 0, palette[3]
    step(function(dt, k)
        a = approach(a, value and 1 or 0, k)
        fill.Position = UDim2.fromOffset(roundPixel(7 * (1 - a)), roundPixel(7 * (1 - a)))
        fill.Size = UDim2.fromOffset(roundPixel(14 * a), roundPixel(14 * a))
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - a * state.AccentAlpha
        mark:Alpha(a)
        tint = tint:Lerp(value and white or palette[3], k)
        title:Color(tint)
    end, card)

    push(false)
    if opts.Callback and value then task.spawn(opts.Callback, value) end
    api.ColorPicker = colorPicker
    api.Keybind = keybind
    api.Settings = settings
    api.Menu = settings
    api.Mini = mini
    return api
end

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
    function api:SetVisible(v) card.Visible = v and true or false end
    bindTitle(api, title, opts)

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
        fillClip.Size = UDim2.fromOffset(roundPixel((w - 20) * a), 10)
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - state.AccentAlpha
        thumb.Position = UDim2.fromOffset(roundPixel(math.clamp((w - 20) * a, 5, w - 25) - 5), 0)
        valueLabel:SetText(string.format("%." .. tostring(decimals) .. "f", value) .. suffix)
    end, card)

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
    local title = text(card, name, 10, 10, w - 20, 14, 12, white)
    muted(card, opts.Description or "", 10, 22, w - 20, 14, 11)

    local controlW = w - 20
    local control = paint(rect(card, 10, 38, controlW, 31, palette[4], 3, "TextButton"), 4)
    local preview = muted(control, "", 10, 0, controlW - 40, 31, 11)
    local arrow = iconLabel(control, {"chevron-down", "chevrons-down", "arrow-down"},
        controlW - 22, 11.5, 10, palette[3], "v")
    step(function() arrow:Color(palette[3]) end, control)

    local ROW_H = 31

    local maxRows = math.floor(tonumber(opts.MaxRows) or 5)
    if maxRows <= 0 then maxRows = math.max(1, #options) end
    local pop = createPopup(self.Window, control, controlW, math.min(#options, maxRows) * ROW_H, true, self.ParentPopup)
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
    bindTitle(api, title, opts)

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
        local visibleRows = math.min(#options, maxRows)
        if tonumber(opts.MaxRows) == 0 then visibleRows = #options end
        list.ScrollingEnabled = #options > visibleRows
        pop.Height = math.max(ROW_H, visibleRows * ROW_H)

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
            entry.Title.Object.Position = UDim2.fromOffset(roundPixel(10 + 20 * entry.Alpha), 0)
            entry.Title:Color(palette[3]:Lerp(white, entry.Alpha))
            entry.Mark.Object.Position = UDim2.fromOffset(roundPixel(10 * entry.Alpha), 10)
            entry.Mark:Color(accent)
            entry.Mark:Alpha(entry.Alpha * state.AccentAlpha)
        end
    end, pop.Object)

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

function Tab:AddTextBox(opts)
    opts = opts or {}
    local name = opts.Name or "Text field"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local withTitle = opts.ShowName == true
    local height = withTitle and 58 or 31
    local card = self:_card(w, height, name)
    local title
    if withTitle then
        title = text(card, name, 10, 10, w - 20, 14, 12, white)
    end

    local box = new("TextBox", card, {
        Name = "Input",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, withTitle and 27 or 0),
        Size = UDim2.fromOffset(w - 20, 31),
        Text = tostring(opts.Default or ""),
        PlaceholderText = tostring(opts.Placeholder or name),
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
    step(function()
        box.PlaceholderColor3 = palette[3]
    end, box)

    local maxLength = math.max(0, math.floor(tonumber(opts.MaxLength) or 0))
    local api = baseApi(self, card, flag)

    local function push(fire)
        Library.Flags[flag] = box.Text
        fireChange(flag, box.Text)
        if fire and opts.Callback then task.spawn(opts.Callback, box.Text) end
    end

    connect(box:GetPropertyChangedSignal("Text"), function()
        local length = maxLength > 0 and utf8.len(box.Text) or nil
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
        connect(box.FocusLost, function(enterPressed)
            if enterPressed then task.spawn(opts.OnEnter, box.Text) end
        end)
    end

    function api:Get()
        return box.Text
    end

    function api:Set(value, silent)
        box.Text = tostring(value or "")
        if silent then Library.Flags[flag] = box.Text end
    end

    if title then
        bindTitle(api, title, opts)
    else
        function api:SetName(value) box.PlaceholderText = tostring(value) end
    end

    if opts.NoSave then Library.NoSaveFlags[flag] = true end
    push(false)
    return api
end

function Tab:AddButton(opts)
    opts = opts or {}
    local name = opts.Name or "Button"
    local w = self:_width(opts.Width)
    local compact = opts.Compact and true or false
    local card = self:_card(w, compact and 31 or 68, name)

    local control, title
    if compact then
        control = paint(rect(card, 0, 0, w, 31, palette[4], 5, "TextButton"), 4)
    else
        title = text(card, name, 10, 10, w - 20, 14, 12, white)
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
    if title then bindTitle(api, title, opts) end

    if opts.Tooltip then self.Window:Tooltip(control, opts.Tooltip) end

    local mini
    if opts.MiniButton ~= nil and opts.MiniButton ~= false then
        local config = type(opts.MiniButton) == "table" and opts.MiniButton or {}
        config.Name = config.Name or name
        config.Key = config.Key or (self.Name .. "." .. name)
        config.Icon = config.Icon or opts.Icon or {"play", "circle"}
        config.Mode = "Action"
        config.OnPress = function()
            if opts.Callback then task.spawn(opts.Callback) end
        end
        mini = self.Window:AddMiniButton(config)
    end
    api.Mini = mini

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
    end, control)
    return api
end

function Tab:AddMiniButton(opts)
    opts = opts or {}
    local name = opts.Name or "Quick button"
    local flag = opts.Flag or (self.Name .. "." .. name .. ".Shown")
    local mode = (opts.Mode == "Action" or opts.Mode == "Button") and "Action" or "Toggle"

    local mini = self.Window:AddMiniButton({
        Name = name,
        Key = opts.Key or flag,
        Icon = opts.Icon or {"zap", "circle"},
        Text = opts.Text,
        Mode = mode,
        Size = opts.Size,
        Width = opts.ButtonWidth,
        Height = opts.ButtonHeight or opts.Height,
        Enabled = opts.Default ~= false,
        Active = opts.Active,
        Transparency = opts.Transparency,
        Callback = opts.Callback,
    })

    local api = self:AddToggle({
        Name = name,
        Description = opts.Description or (mode == "Toggle" and "On-screen toggle" or "On-screen action"),
        Flag = flag,
        Default = opts.Default ~= false,
        Width = opts.Width,
        Badge = opts.Badge or opts.Tag,
        BadgeColor = opts.BadgeColor,
        Tooltip = opts.Tooltip,
        Settings = opts.Settings,
        Callback = function(value)
            mini:SetVisible(value)
            if opts.OnShow then task.spawn(opts.OnShow, value) end
        end,
    })
    api.Mini = mini
    return api
end

function Tab:AddSettings(opts)
    opts = opts or {}
    local name = opts.Name or "Settings"
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)
    local title = text(card, name, 10, 10, w - 44, 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, w - 44, 14, 11)
    end
    local menu = attachSettings(self, card, w - 24, 14.5, 14, opts)
    local api = baseApi(self, card, nil)
    api.Menu = menu
    bindTitle(api, title, opts)
    step(function() title:Color(palette[3]:Lerp(white, 0.35)) end, card)
    return api
end

function Tab:AddStepper(opts)
    opts = opts or {}
    local name = opts.Name or "Value"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)

    local min = tonumber(opts.Min)
    local max = tonumber(opts.Max)
    local stepSize = tonumber(opts.Step) or 1
    local decimals = math.max(0, math.floor(tonumber(opts.Decimals) or 0))
    local suffix = opts.Suffix or ""
    local value = tonumber(opts.Default) or min or 0

    local title = text(card, name, 10, 10, math.max(30, w - 116), 14, 12, palette[3])
    if opts.Description then
        muted(card, opts.Description, 10, 22, math.max(30, w - 116), 14, 11)
    end
    local minus = paint(rect(card, w - 100, 11.5, 20, 20, palette[4], 3, "TextButton"), 4)
    text(minus, "-", 0, 0, 20, 20, 14, white, "center")
    local valueLabel = text(card, "", w - 76, 11.5, 46, 20, 12, white, "center")
    local plus = paint(rect(card, w - 30, 11.5, 20, 20, palette[4], 3, "TextButton"), 4)
    text(plus, "+", 0, 0, 20, 20, 14, white, "center")

    local api = baseApi(self, card, flag)

    local function quantize(raw)
        if decimals <= 0 then return math.floor(raw + 0.5) end
        local m = 10 ^ decimals
        return math.floor(raw * m + 0.5) / m
    end

    local function push(fire)
        Library.Flags[flag] = value
        valueLabel:SetText(string.format("%." .. tostring(decimals) .. "f", value) .. suffix)
        fireChange(flag, value)
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        local raw = quantize(tonumber(newValue) or value)
        if min then raw = math.max(raw, min) end
        if max then raw = math.min(raw, max) end
        value = raw
        push(not silent)
    end
    bindTitle(api, title, opts)

    connect(minus.Activated, function() api:Set(value - stepSize) end)
    connect(plus.Activated, function() api:Set(value + stepSize) end)

    local hoverMinus, hoverPlus = false, false
    connect(minus.MouseEnter, function() hoverMinus = true end)
    connect(minus.MouseLeave, function() hoverMinus = false end)
    connect(plus.MouseEnter, function() hoverPlus = true end)
    connect(plus.MouseLeave, function() hoverPlus = false end)
    step(function()
        minus.BackgroundColor3 = palette[4]:Lerp(palette[5], hoverMinus and 1 or 0)
        plus.BackgroundColor3 = palette[4]:Lerp(palette[5], hoverPlus and 1 or 0)
        title:Color(palette[3]:Lerp(white, 0.35))
    end, card)

    push(false)
    if opts.Callback then task.spawn(opts.Callback, value) end
    return api
end

function Tab:AddSegmented(opts)
    opts = opts or {}
    local name = opts.Name or "Mode"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local options = {}
    for _, option in ipairs(opts.Options or {"One", "Two"}) do
        options[#options + 1] = tostring(option)
    end
    if #options == 0 then options = {"-"} end

    local withTitle = opts.Name ~= nil
    local card = self:_card(w, withTitle and 68 or 41, name)
    local title
    if withTitle then
        title = text(card, name, 10, 10, w - 20, 14, 12, white)
        if opts.Description then
            muted(card, opts.Description, 10, 22, w - 20, 14, 11)
        end
    end

    local rowY = withTitle and 27 or 5
    local gap = 6
    local total = w - 20
    local cellW = math.floor((total - gap * (#options - 1)) / #options)
    local selection = 1
    local cells = {}
    local api = baseApi(self, card, flag)
    if title then bindTitle(api, title, opts) end

    local function push(fire)
        Library.Flags[flag] = options[selection]
        Library.Flags[flag .. ".Index"] = selection
        fireChange(flag, options[selection])
        if fire and opts.Callback then task.spawn(opts.Callback, options[selection], selection) end
    end

    function api:Get() return options[selection], selection end
    function api:Set(value, silent)
        if type(value) == "string" then
            for index, option in ipairs(options) do
                if option == value then selection = index end
            end
        else
            selection = math.clamp(math.floor(tonumber(value) or 1), 1, #options)
        end
        push(not silent)
    end

    for index, option in ipairs(options) do
        local cell = paint(rect(card, 10 + (index - 1) * (cellW + gap), rowY, cellW, 31,
            palette[4], 3, "TextButton"), 4)
        local caption = text(cell, option, 0, 0, cellW, 31, 11, palette[3], "center")
        connect(cell.Activated, function()
            selection = index
            push(true)
        end)
        local hover, a, tint = false, 0, palette[3]
        connect(cell.MouseEnter, function() hover = true end)
        connect(cell.MouseLeave, function() hover = false end)
        step(function(dt, k)
            local active = selection == index
            a = approach(a, active and 1 or 0, k)
            cell.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 1 or 0)
                :Lerp(accent, a * 0.55 * state.AccentAlpha)
            tint = tint:Lerp(active and white or palette[3], k)
            caption:Color(tint)
        end, cell)
        cells[index] = cell
    end

    if opts.Default ~= nil then
        api:Set(opts.Default, true)
    end
    push(false)
    if opts.Callback then task.spawn(opts.Callback, options[selection], selection) end
    return api
end

function Tab:AddProgressBar(opts)
    opts = opts or {}
    local name = opts.Name or "Progress"
    local w = self:_width(opts.Width)
    local card = self:_card(w, 43, name)
    local title = text(card, name, 10, 8, w - 70, 14, 12, white)
    local valueLabel = muted(card, "0%", w - 55, 8, 45, 14, 11, "right")
    local track = paint(rect(card, 10, 27, w - 20, 8, palette[1], 3), 1)
    local fillClip = transparent(track, 0, 0, 0, 8)
    fillClip.ClipsDescendants = true
    local fill = rect(fillClip, 0, 0, w - 20, 8, accent, 3)

    local value = math.clamp(tonumber(opts.Default) or 0, 0, 1)
    local shown = value
    local api = baseApi(self, card, opts.Flag)

    function api:Get() return value end
    function api:Set(newValue)
        value = math.clamp(tonumber(newValue) or 0, 0, 1)
        if opts.Flag then Library.Flags[opts.Flag] = value end
    end
    bindTitle(api, title, opts)
    function api:SetText(v) valueLabel:SetText(tostring(v)) end

    step(function(dt, k)
        shown = approach(shown, value, k)
        fillClip.Size = UDim2.fromOffset(roundPixel((w - 20) * shown), 8)
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - state.AccentAlpha
        if opts.ShowPercent ~= false then
            valueLabel:SetText(tostring(math.floor(shown * 100 + 0.5)) .. "%")
        end
    end, card)
    return api
end

function Tab:AddImage(opts)
    opts = opts or {}
    local w = self:_width(opts.Width)
    local height = math.max(20, math.floor(tonumber(opts.Height) or 120))
    local card = self:_card(w, height, opts.Name or "Image")
    local image = new("ImageLabel", card, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(w, height),
        Image = tostring(opts.Image or opts.Asset or ""),
        ScaleType = opts.Fill and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
        ZIndex = 2,
    })
    new("UICorner", image, {CornerRadius = UDim.new(0, 5)})
    local api = baseApi(self, card, nil)
    function api:SetImage(value) image.Image = tostring(value or "") end
    return api
end

function Tab:AddList(opts)
    opts = opts or {}
    local name = opts.Name or "List"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local listH = math.max(31, math.floor(tonumber(opts.Height) or 93))
    local withInput = opts.Input ~= false
    local card = self:_card(w, 28 + (withInput and 41 or 0) + listH + 10, name)

    local title = text(card, name, 10, 10, w - 20, 14, 12, white)

    local items = {}
    for _, item in ipairs(opts.Items or {}) do items[#items + 1] = tostring(item) end

    local api = baseApi(self, card, flag)
    bindTitle(api, title, opts)
    local rows = {}
    local ROW_H = 31

    local listY = 28 + (withInput and 41 or 0)
    local holder = new("ScrollingFrame", card, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, listY),
        Size = UDim2.fromOffset(w - 20, listH),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = palette[4],
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        Active = true,
        ZIndex = 2,
    })
    step(function() holder.ScrollBarImageColor3 = palette[4] end, holder)

    local empty = muted(holder, opts.Empty or "empty", 10, 0, w - 40, ROW_H, 11)

    local function push(fire)
        local copy = {}
        for index, item in ipairs(items) do copy[index] = item end
        Library.Flags[flag] = copy
        fireChange(flag, copy)
        if fire and opts.Callback then task.spawn(opts.Callback, copy) end
    end

    local function rebuild()
        for _, row in ipairs(rows) do row:Destroy() end
        rows = {}
        empty.Object.Visible = #items == 0
        for index, item in ipairs(items) do
            local row = paint(rect(holder, 0, (index - 1) * ROW_H, w - 26, ROW_H - 4, palette[4], 3), 4)
            local caption = text(row, item, 8, 0, w - 60, ROW_H - 4, 11, white)
            local remove = transparent(row, w - 52, 4, 19, 19, "TextButton")
            local icon = iconLabel(remove, {"x", "trash-2"}, 3, 3, 13, palette[3], "x")
            connect(remove.Activated, function()
                table.remove(items, index)
                rebuild()
                push(true)
            end)
            local hover = false
            connect(remove.MouseEnter, function() hover = true end)
            connect(remove.MouseLeave, function() hover = false end)
            step(function(dt, k)
                icon:Color(palette[3]:Lerp(white, hover and 1 or 0))
                caption:Color(white)
            end, row)
            rows[#rows + 1] = row
        end
        holder.CanvasSize = UDim2.fromOffset(0, #items * ROW_H)
    end

    if withInput then
        local box = new("TextBox", card, {
            BackgroundColor3 = palette[4],
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 28),
            Size = UDim2.fromOffset(w - 62, 31),
            Text = "",
            PlaceholderText = opts.Placeholder or "Add item",
            PlaceholderColor3 = palette[3],
            ClearTextOnFocus = false,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = white,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
        new("UICorner", box, {CornerRadius = UDim.new(0, 3)})
        new("UIPadding", box, {PaddingLeft = UDim.new(0, 8)})
        step(function()
            box.BackgroundColor3 = palette[4]
            box.PlaceholderColor3 = palette[3]
        end, box)
        local add = paint(rect(card, w - 46, 28, 36, 31, palette[4], 3, "TextButton"), 4)
        local addIcon = iconLabel(add, {"plus"}, 12, 9, 13, white, "+")
        local function commit()
            local value = box.Text
            if value ~= "" then
                items[#items + 1] = value
                box.Text = ""
                rebuild()
                push(true)
            end
        end
        connect(add.Activated, commit)
        connect(box.FocusLost, function(enter)
            if enter then commit() end
        end)
        local hover = false
        connect(add.MouseEnter, function() hover = true end)
        connect(add.MouseLeave, function() hover = false end)
        step(function()
            add.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 1 or 0)
            addIcon:Color(white)
        end, add)
    end

    function api:Get()
        local copy = {}
        for index, item in ipairs(items) do copy[index] = item end
        return copy
    end
    function api:Set(list, silent)
        items = {}
        for _, item in ipairs(list or {}) do items[#items + 1] = tostring(item) end
        rebuild()
        push(not silent)
    end
    function api:Add(value)
        items[#items + 1] = tostring(value)
        rebuild()
        push(true)
    end
    function api:Remove(value)
        for index, item in ipairs(items) do
            if item == tostring(value) then
                table.remove(items, index)
                break
            end
        end
        rebuild()
        push(true)
    end
    function api:Has(value)
        for _, item in ipairs(items) do
            if item == tostring(value) then return true end
        end
        return false
    end
    function api:Clear() self:Set({}) end

    rebuild()
    push(false)
    return api
end

function Tab:AddPlayerDropdown(opts)
    opts = opts or {}
    local function names()
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if opts.IncludeSelf ~= false or player ~= Players.LocalPlayer then
                list[#list + 1] = player.Name
            end
        end
        table.sort(list)
        return list
    end

    local api = self:AddDropdown({
        Name = opts.Name or "Player",
        Description = opts.Description,
        Flag = opts.Flag,
        Options = names(),
        Multiple = opts.Multiple,
        MaxRows = opts.MaxRows,
        Width = opts.Width,
        Callback = opts.Callback,
    })

    function api:Refresh() self:SetOptions(names()) end
    connect(Players.PlayerAdded, function() api:Refresh() end)
    connect(Players.PlayerRemoving, function() api:Refresh() end)

    function api:GetPlayer()
        local value = api:Get()
        if type(value) == "table" then
            local found = {}
            for _, playerName in ipairs(value) do
                local player = Players:FindFirstChild(playerName)
                if player then found[#found + 1] = player end
            end
            return found
        end
        return Players:FindFirstChild(tostring(value))
    end
    return api
end

local elementMethods = {
    section = "AddSection",
    divider = "AddDivider",
    label = "AddLabel",
    paragraph = "AddParagraph",
    toggle = "AddToggle",
    slider = "AddSlider",
    range = "AddSlider",
    stepper = "AddStepper",
    segmented = "AddSegmented",
    tabs = "AddSegmented",
    dropdown = "AddDropdown",
    select = "AddDropdown",
    playerdropdown = "AddPlayerDropdown",
    playerselect = "AddPlayerDropdown",
    colorpicker = "AddColorPicker",
    color = "AddColorPicker",
    keybind = "AddKeybind",
    hotkey = "AddKeybind",
    textbox = "AddTextBox",
    input = "AddTextBox",
    button = "AddButton",
    minibutton = "AddMiniButton",
    settings = "AddSettings",
    progressbar = "AddProgressBar",
    progress = "AddProgressBar",
    image = "AddImage",
    list = "AddList",
    configmanager = "AddConfigManager",
    configs = "AddConfigManager",
}

function Tab:AddElements(items)
    assert(type(items) == "table", "WolfUi: AddElements expects a table")
    local controls = {}
    for index, definition in ipairs(items) do
        assert(type(definition) == "table", "WolfUi: every element definition must be a table")
        local kind = string.lower(tostring(definition.Type or definition.Kind or definition.Control or ""))
        kind = string.gsub(kind, "[%s_%-]", "")
        local method = elementMethods[kind]
        assert(method and type(self[method]) == "function", "WolfUi: unsupported element type " .. tostring(kind))
        local control = self[method](self, definition)
        controls[index] = control
        local key = definition.Key or definition.Id or definition.Flag
        if key ~= nil then controls[key] = control end
    end
    return controls
end

function Tab:AddSelect(opts)
    return self:AddDropdown(opts)
end

function Tab:AddColor(opts)
    return self:AddColorPicker(opts)
end

function Tab:AddInput(opts)
    return self:AddTextBox(opts)
end

function Tab:AddConfigManager(opts)
    opts = opts or {}
    self:AddSection(opts.Name or "Configs")

    local nameFlag = self.Name .. ".ConfigName"
    local pickerFlag = self.Name .. ".ConfigPick"
    local nameBox = self:AddTextBox({
        Name = opts.NameLabel or "Config name",
        Flag = nameFlag,
        Placeholder = opts.Placeholder or "default",
        Width = 0.5,
        NoSave = true,
    })
    local picker = self:AddDropdown({
        Name = opts.ListLabel or "Saved configs",
        Flag = pickerFlag,
        Options = Library:ListConfigs(),
        Width = 0.5,
    })
    Library.NoSaveFlags[pickerFlag] = true
    Library.NoSaveFlags[pickerFlag .. ".Text"] = true

    local function refresh()
        picker:SetOptions(Library:ListConfigs())
    end

    local function chosen()
        local value = nameBox:Get()
        if value == nil or value == "" then value = picker:Get() end
        if value == nil or value == "" then value = "default" end
        return value
    end

    self:AddButton({
        Name = "Save config",
        Text = "Save",
        Compact = true,
        Width = 0.33,
        Callback = function()
            local name = chosen()
            local ok, result = Library:SaveConfigFile(name)
            if ok then refresh() end
            Library:Notify({
                Title = "Configs",
                Text = ok and ("Saved: " .. tostring(name)) or tostring(result),
            })
        end,
    })
    self:AddButton({
        Name = "Load config",
        Text = "Load",
        Compact = true,
        Width = 0.33,
        Callback = function()
            local name = chosen()
            local ok, result = Library:LoadConfigFile(name)
            Library:Notify({
                Title = "Configs",
                Text = ok and ("Loaded: " .. tostring(name)) or tostring(result),
            })
        end,
    })
    self:AddButton({
        Name = "Delete config",
        Text = "Delete",
        Compact = true,
        Width = 0.33,
        Callback = function()
            local name = chosen()
            Library:Dialog({
                Title = "Delete config?",
                Text = "This will permanently delete " .. tostring(name) .. ".json.",
                ConfirmText = "Delete",
                CancelText = "Cancel",
                Confirm = function()
                    local ok, result = Library:DeleteConfigFile(name)
                    if ok then refresh() end
                    Library:Notify({
                        Title = "Configs",
                        Text = ok and ("Deleted: " .. tostring(name)) or tostring(result),
                    })
                end,
            })
        end,
    })
    self:AddButton({
        Name = "Refresh configs",
        Text = "Refresh",
        Compact = true,
        Callback = refresh,
    })

    return {
        Refresh = refresh,
        Name = nameBox,
        Picker = picker,
    }
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

    local object = rect(window.NotifyHolder, 260, 0, width, height, palette[2], 5, "Frame")
    object.Name = "Notification"
    object.ClipsDescendants = true

    local bar = rect(object, 0, 0, 2, height, accent, nil)
    local icon = iconLabel(object, opts.Icon or {"bell", "info", "circle"}, 12, title and 10 or 10, 14, accent, "!")
    if title then
        text(object, title, 34, 8, width - 46, 14, 12, white)
    end
    muted(object, body, 34, title and 26 or 10, width - 46, math.max(14, bounds.Y), 11, nil, {Wrap = true})

    local targetY = 0
    for _, existing in ipairs(window.Notifications) do
        targetY = targetY + existing.Height + 8
    end

    local notif = {
        Object = object,
        Bar = bar,
        Icon = icon,
        Height = height,
        Alpha = 0,
        Y = targetY,
        TargetY = targetY,
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
    if opts.ShowPing ~= nil then config.ShowPing = opts.ShowPing and true or false end
    if opts.ShowTime ~= nil then config.ShowTime = opts.ShowTime and true or false end
    if opts.Transparency ~= nil then
        config.Transparency = math.clamp(tonumber(opts.Transparency) or 0, 0, 1)
    end
    if opts.Toggle ~= nil then config.Toggle = opts.Toggle and true or false end
    if opts.AlwaysVisible ~= nil then config.AlwaysVisible = opts.AlwaysVisible and true or false end
    if opts.Icon ~= nil then window:SetWatermarkIcon(opts.Icon) end
    if typeof(opts.Position) == "Vector2" then config.Position = opts.Position end
    if opts.X ~= nil and opts.Y ~= nil then
        config.Position = Vector2.new(tonumber(opts.X) or 8, tonumber(opts.Y) or 8)
    end
    config.Enabled = opts.Enabled ~= false
    window.UpdateOpenVisibility()
    return config
end

function Library:SetOpenMode(opts)
    local window = self.Window
    if not window then return end
    opts = type(opts) == "table" and opts or {Mode = opts}
    local config = window.OpenConfig
    if opts.Mode ~= nil then
        local mode = string.lower(tostring(opts.Mode))
        assert(mode == "button" or mode == "watermark", "WolfUi: open mode must be button or watermark")
        if window.Drag and window.Drag.Object == window.Reopen and mode ~= "button" then window.CancelDrag() end
        config.Mode = mode
        if mode == "watermark" then window.WatermarkConfig.Enabled = true; window.WatermarkConfig.Toggle = true end
    end
    if opts.Size ~= nil then
        config.Size = math.max(24, math.floor(tonumber(opts.Size) or 32))
        config.Width, config.Height = config.Size, config.Size
    end
    if opts.Width ~= nil then config.Width = math.max(24, math.floor(tonumber(opts.Width) or config.Width)) end
    if opts.Height ~= nil then config.Height = math.max(24, math.floor(tonumber(opts.Height) or config.Height)) end
    if opts.Transparency ~= nil then
        config.Transparency = math.clamp(tonumber(opts.Transparency) or 0, 0, 1)
    end
    if opts.Icon ~= nil then window:SetOpenIcon(opts.Icon) end
    if opts.OpenIcon ~= nil then window:SetOpenIcon(opts.OpenIcon) end
    if opts.AlwaysVisible ~= nil then config.AlwaysVisible = opts.AlwaysVisible and true or false end
    if opts.AnimationDuration ~= nil then
        config.AnimationDuration = math.clamp(tonumber(opts.AnimationDuration) or 0.18, 0.05, 1)
    end
    if typeof(opts.Position) == "Vector2" then config.Position = opts.Position end
    if opts.X ~= nil and opts.Y ~= nil then
        config.Position = Vector2.new(tonumber(opts.X) or 8, tonumber(opts.Y) or 8)
    end
    window.UpdateOpenVisibility()
    return config
end

function Library:SetToggleKey(key)
    local window = self.Window
    if not window then return end
    if type(key) == "string" then key = keyFromName(key) end
    window.ToggleKey = key
    return key
end

function Library:GetElement(flag)
    return self.Elements[flag]
end

function Library:GetMiniButtons()
    local window = self.Window
    return window and window.Mini or {}
end

local function keyResult(result, message, data)
    if type(result) == "table" then
        local success = result.Success
        if success == nil then success = result.Valid end
        if success == nil then success = result.Authorized end
        return success == true, result.Message or result.Error or message, result.Data or result
    end
    return result == true, message, data
end

local function requestFunction()
    local environment = type(getgenv) == "function" and getgenv() or _G
    local requester = environment.request or environment.http_request
    if not requester and type(environment.syn) == "table" then requester = environment.syn.request end
    return type(requester) == "function" and requester or nil
end

local function keyContext(key)
    local player = Players.LocalPlayer
    return {
        Key = key,
        UserId = player and player.UserId or 0,
        Username = player and player.Name or "",
        DisplayName = player and player.DisplayName or "",
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        GameId = game.GameId,
    }
end

function Library:SetKeySystem(options)
    if options == nil or options == false then
        self.KeySystem = {Enabled = false}
        self:HideKeySystem(true)
        if self.Window then self.Window:SetVisible(true) end
        return self.KeySystem
    end
    if type(options) ~= "table" then options = {Key = tostring(options)} end
    local config = {}
    for key, value in pairs(options) do config[key] = value end
    config.Enabled = config.Enabled ~= false
    self.KeySystem = config
    if self.Window then
        if config.Enabled then
            self:ShowKeySystem()
        else
            self:HideKeySystem(true)
            self.Window:SetVisible(true)
        end
    end
    return config
end

Library.ConfigureKeySystem = Library.SetKeySystem

function Library:ValidateKey(rawKey)
    local config = self.KeySystem or {}
    if config.Enabled == false then return true, "Key system disabled" end
    local key = tostring(rawKey or "")
    if config.Trim ~= false then key = string.match(key, "^%s*(.-)%s*$") end
    if key == "" then return false, config.EmptyMessage or "Enter a key" end
    local context = keyContext(key)

    if type(config.Validate) == "function" then
        local ok, result, message, data = pcall(config.Validate, key, context)
        if not ok then return false, config.ErrorMessage or tostring(result) end
        return keyResult(result, message, data)
    end

    local server = config.Server or config.Endpoint or config.Url
    if server ~= nil then
        server = type(server) == "table" and server or {Url = server}
        local requestData
        if type(server.BuildRequest) == "function" then
            local ok, built = pcall(server.BuildRequest, key, context)
            if not ok then return false, config.ErrorMessage or tostring(built) end
            requestData = built
        else
            local url = tostring(server.Url or server.Endpoint or "")
            local method = string.upper(tostring(server.Method or "POST"))
            local headers = {['Content-Type'] = "application/json"}
            for name, value in pairs(server.Headers or {}) do headers[name] = value end
            local payload = {key = key, userId = context.UserId, username = context.Username,
                placeId = context.PlaceId, jobId = context.JobId, gameId = context.GameId}
            if type(server.Payload) == "function" then
                local ok, result = pcall(server.Payload, key, context)
                if not ok then return false, config.ErrorMessage or tostring(result) end
                payload = result
            elseif type(server.Payload) == "table" then
                payload = server.Payload
            end
            if method == "GET" and server.AppendKey ~= false then
                local divider = string.find(url, "?", 1, true) and "&" or "?"
                url = url .. divider .. tostring(server.KeyParameter or "key") .. "=" .. HttpService:UrlEncode(key)
            end
            local body
            if method ~= "GET" then
                local ok, result = pcall(function() return HttpService:JSONEncode(payload) end)
                if not ok then return false, config.ErrorMessage or tostring(result) end
                body = result
            end
            requestData = {
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            }
        end

        if type(requestData) == "table" then requestData.Url = requestData.Url or requestData.URL or requestData.url end
        if type(requestData) ~= "table" or tostring(requestData.Url or "") == "" then
            return false, config.ErrorMessage or "Key server URL is missing"
        end

        local response
        if type(server.Request) == "function" then
            local ok, result = pcall(server.Request, requestData, key, context)
            if not ok then return false, config.ErrorMessage or tostring(result) end
            response = result
        else
            local requester = requestFunction()
            if requester then
                local ok, result = pcall(requester, requestData)
                if not ok then return false, config.ErrorMessage or tostring(result) end
                response = result
            elseif string.upper(tostring(requestData.Method or "GET")) == "GET" then
                local ok, result = pcall(function() return game:HttpGet(requestData.Url, true) end)
                if not ok then return false, config.ErrorMessage or tostring(result) end
                response = {StatusCode = 200, Body = result}
            else
                return false, config.ErrorMessage or "HTTP requests are unavailable"
            end
        end

        local body = type(response) == "table" and (response.Body or response.body) or response
        local status = type(response) == "table" and tonumber(response.StatusCode or response.Status or response.status_code) or 200
        local decoded
        if type(body) == "string" then pcall(function() decoded = HttpService:JSONDecode(body) end) end
        if type(server.ParseResponse) == "function" then
            local ok, result, message, data = pcall(server.ParseResponse, response, decoded, context)
            if not ok then return false, config.ErrorMessage or tostring(result) end
            return keyResult(result, message, data)
        end
        if status and (status < 200 or status >= 300) then
            return false, (type(decoded) == "table" and (decoded.message or decoded.error))
                or server.FailureMessage or "Key verification failed"
        end
        if type(decoded) == "table" then
            local valid = decoded.valid
            if valid == nil then valid = decoded.success end
            if valid == nil then valid = decoded.authorized end
            if valid == nil then valid = decoded.Valid end
            if valid == nil then valid = decoded.Success end
            return valid == true, decoded.message or decoded.Message
                or (valid == true and "Access granted" or "Invalid key"), decoded
        end
        return body == true or body == "true" or body == "ok" or body == "success",
            server.FailureMessage or "Invalid key", body
    end

    local caseSensitive = config.CaseSensitive ~= false
    local function equal(candidate)
        candidate = tostring(candidate or "")
        if caseSensitive then return candidate == key end
        return string.lower(candidate) == string.lower(key)
    end
    if config.Key ~= nil and equal(config.Key) then return true, "Access granted" end
    for index, candidate in pairs(config.Keys or {}) do
        if equal(type(index) ~= "number" and candidate == true and index or candidate) then
            return true, "Access granted"
        end
    end
    return false, config.InvalidMessage or "Invalid key"
end

function Library:HideKeySystem(authorized)
    local window = self.Window
    if not window then return end
    if authorized ~= nil then window.KeyLocked = not authorized end
    if window.KeyGate and window.KeyGate.Object then window.KeyGate.Object:Destroy() end
    window.KeyGate = nil
    if window.UpdateOpenVisibility then window.UpdateOpenVisibility() end
end

function Library:ShowKeySystem()
    local window = self.Window
    local config = self.KeySystem or {}
    if not window or config.Enabled == false then return end
    self:HideKeySystem(false)
    window.KeyLocked = true
    window.Visible = false
    window.Alpha = 0
    window.Frame.Visible = false
    window.PopupLayer.Visible = false

    local shade = rect(window.Gui, 0, 0, 10, 10, black)
    shade.Name = "KeySystem"
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundTransparency = 0.18
    shade.ZIndex = 100
    shade.Active = true

    local width = math.clamp(math.floor(tonumber(config.Width) or 340), 260, 460)
    local hasLink = config.GetKeyUrl ~= nil or config.Link ~= nil or type(config.OnGetKey) == "function"
    local height = hasLink and 222 or 181
    local card = paint(rect(shade, 0, 0, width, height, palette[2], 7), 2)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.ZIndex = 101
    new("UIStroke", card, {Color = palette[5], Thickness = 1, Transparency = 0.25})

    text(card, config.Title or "Key verification", 18, 16, width - 36, 18, 14, white)
    muted(card, config.Description or "Enter your access key to continue", 18, 38, width - 36, 18, 11)
    local input = new("TextBox", card, {
        Name = "KeyInput",
        BackgroundColor3 = palette[4],
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 68),
        Size = UDim2.fromOffset(width - 36, 34),
        Text = tostring(config.DefaultKey or ""),
        PlaceholderText = tostring(config.Placeholder or "Enter key"),
        PlaceholderColor3 = palette[3],
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = white,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
    })
    new("UICorner", input, {CornerRadius = UDim.new(0, 4)})
    new("UIPadding", input, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})

    local submit = paint(rect(card, 18, 112, width - 36, 34, palette[4], 4, "TextButton"), 4)
    submit.ZIndex = 102
    local submitText = text(submit, config.ButtonText or "Verify key", 0, 0, width - 36, 34, 12, white, "center")
    local status = muted(card, "", 18, 153, width - 36, 18, 11, "center")
    local linkButton
    if hasLink then
        linkButton = transparent(card, 18, 181, width - 36, 25, "TextButton")
        linkButton.ZIndex = 102
        local linkText = text(linkButton, config.LinkText or "Get a key", 0, 0, width - 36, 25, 11, accent, "center")
        step(function() linkText:Color(accent) end, linkButton)
        connect(linkButton.Activated, function()
            if type(config.OnGetKey) == "function" then
                task.spawn(config.OnGetKey, config.GetKeyUrl or config.Link)
            elseif type(setclipboard) == "function" then
                setclipboard(tostring(config.GetKeyUrl or config.Link))
                status:SetText(config.CopiedMessage or "Link copied")
            end
        end)
    end

    local busy = false
    local attempts = 0
    local lastAttempt = 0
    local gate = {Object = shade, Card = card, Input = input, Button = submit, Authorized = false}
    window.KeyGate = gate

    local function authorize(data)
        if window.KeyGate ~= gate then return end
        gate.Authorized = true
        window.KeyLocked = false
        if type(config.OnSuccess) == "function" then task.spawn(config.OnSuccess, input.Text, data) end
        shade:Destroy()
        window.KeyGate = nil
        if config.OpenOnSuccess == false then window:SetVisible(false) else window:SetVisible(true) end
        window.UpdateOpenVisibility()
    end

    local function submitKey()
        if busy or window.KeyGate ~= gate then return end
        local maximum = math.max(0, math.floor(tonumber(config.MaxAttempts) or 0))
        if maximum > 0 and attempts >= maximum then
            status:SetText(config.LockedMessage or "Too many attempts")
            return
        end
        local cooldown = math.max(0, tonumber(config.Cooldown) or 0.5)
        if os.clock() - lastAttempt < cooldown then return end
        lastAttempt = os.clock()
        attempts = attempts + 1
        busy = true
        submitText:SetText(config.CheckingText or "Checking...")
        status:SetText("")
        task.spawn(function()
            local valid, message, data = Library:ValidateKey(input.Text)
            if window.KeyGate ~= gate then return end
            busy = false
            submitText:SetText(config.ButtonText or "Verify key")
            if valid then
                status:Color(accent)
                status:SetText(message or config.SuccessMessage or "Access granted")
                authorize(data)
            else
                status:Color(Color3.fromRGB(235, 105, 105))
                status:SetText(message or config.InvalidMessage or "Invalid key")
                if type(config.OnFailure) == "function" then
                    task.spawn(config.OnFailure, input.Text, message, attempts)
                end
            end
        end)
    end

    gate.Submit = submitKey
    gate.Authorize = authorize
    connect(submit.Activated, submitKey)
    connect(input.FocusLost, function(enterPressed) if enterPressed then submitKey() end end)
    step(function()
        card.BackgroundColor3 = palette[2]
        input.BackgroundColor3 = palette[4]
        input.PlaceholderColor3 = palette[3]
        submit.BackgroundColor3 = palette[4]
    end, card)
    return gate
end

function Library:Dialog(opts)
    local window = self.Window
    if not window then return end
    opts = type(opts) == "table" and opts or {Text = opts}

    local width = math.max(220, math.floor(tonumber(opts.Width) or 300))
    local body = tostring(opts.Text or "")
    local bounds = TextService:GetTextSize(body, 12, Enum.Font.Gotham, Vector2.new(width - 40, 10000))
    local height = 44 + math.max(16, bounds.Y) + 12 + 31 + 20

    local shade = rect(window.Gui, 0, 0, 10, 10, black)
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundTransparency = 0.5
    shade.ZIndex = 80
    shade.Active = true

    local card = rect(shade, 0, 0, width, height, palette[2], 5)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.ZIndex = 81
    new("UIStroke", card, {Color = palette[5], Thickness = 1, Transparency = 0.4})

    text(card, opts.Title or "Confirm action", 20, 16, width - 40, 16, 13, white)
    muted(card, body, 20, 44, width - 40, math.max(16, bounds.Y), 12, nil, {Wrap = true})

    local function close()
        shade:Destroy()
    end

    local labels = opts.Buttons or {opts.ConfirmText or "Confirm", opts.CancelText or "Cancel"}
    local count = math.max(1, #labels)
    local buttonW = math.floor((width - 40 - 10 * (count - 1)) / count)
    for index, label in ipairs(labels) do
        local button = paint(rect(card, 20 + (index - 1) * (buttonW + 10), height - 51,
            buttonW, 31, palette[4], 3, "TextButton"), 4)
        button.ZIndex = 82
        local caption = text(button, tostring(label), 0, 0, buttonW, 31, 12, white, "center")
        local hover = false
        connect(button.MouseEnter, function() hover = true end)
        connect(button.MouseLeave, function() hover = false end)
        overlayStep(function()
            button.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 1 or 0)
            caption:Color(white)
            card.BackgroundColor3 = palette[2]
        end, button)
        connect(button.Activated, function()
            close()
            if index == 1 and opts.Confirm then task.spawn(opts.Confirm) end
            if index == 2 and opts.Cancel then task.spawn(opts.Cancel) end
            if opts.Callback then task.spawn(opts.Callback, index, tostring(label)) end
        end)
    end

    return {Object = shade, Close = close}
end

local function serialize(value, seen)
    if typeof(value) == "Color3" then
        return {__type = "Color3", R = value.R, G = value.G, B = value.B}
    end
    if typeof(value) == "EnumItem" then
        return {__type = "Key", Name = value.Name}
    end
    if type(value) == "table" then
        seen = seen or {}
        if seen[value] then error("config contains a recursive table", 2) end
        seen[value] = true

        local indices = {}
        local isSet = next(value) ~= nil
        for key, item in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or item ~= true then
                isSet = false
                break
            end
            indices[#indices + 1] = key
        end
        if isSet then
            table.sort(indices)
            seen[value] = nil
            return {__type = "Set", Values = indices}
        end

        local count, maximum, isArray = 0, 0, true
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                isArray = false
                break
            end
            count = count + 1
            maximum = math.max(maximum, key)
        end
        if isArray and count == maximum then
            local values = {}
            for index = 1, maximum do values[index] = serialize(value[index], seen) end
            seen[value] = nil
            return {__type = "Array", Values = values}
        end

        local entries = {}
        for key, item in pairs(value) do
            entries[#entries + 1] = {Key = serialize(key, seen), Value = serialize(item, seen)}
        end
        seen[value] = nil
        return {__type = "Map", Entries = entries}
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
        elseif value.__type == "Array" then
            local array = {}
            for index, item in ipairs(value.Values or {}) do array[index] = deserialize(item) end
            return array
        elseif value.__type == "Map" then
            local map = {}
            for _, entry in ipairs(value.Entries or {}) do
                map[deserialize(entry.Key)] = deserialize(entry.Value)
            end
            return map
        end

        local copy = {}
        for key, item in pairs(value) do copy[key] = deserialize(item) end
        return copy
    end
    return value
end

function Library:GetConfig()
    local config = {__version = self.Version, Flags = {}, Theme = state.Theme, Scale = state.Scale}
    for flag, value in pairs(self.Flags) do
        if not self.NoSaveFlags[flag] then
            config.Flags[flag] = serialize(value)
        end
    end
    config.FadeAnimations, config.FadeDuration = self.FadeAnimations, self.FadeDuration
    config.ScaleAnimations, config.ScaleDuration = self.ScaleAnimations, self.ScaleDuration
    config.ThemePalette = {}
    for i, color in ipairs(themes[state.Theme]) do config.ThemePalette[i] = serialize(color) end
    config.ThemeName = self.ThemeNames[state.Theme]
    config.Accent = serialize(state.Accent)
    config.AccentAlpha = state.AccentAlpha
    if self.Window then
        config.MiniStyle = {}
        for _, mini in ipairs(self.Window.Mini) do
            config.MiniStyle[mini.Key] = {Width = mini.Width, Height = mini.Height, Transparency = mini.Transparency}
        end
        config.Mini = {}
        for key, position in pairs(self.Window.MiniPositions) do
            config.Mini[key] = {X = position.X, Y = position.Y}
        end
    end
    return config
end

function Library:LoadConfig(config)
    if type(config) ~= "table" then return false, "config is not a table" end
    if config.FadeAnimations ~= nil then self:SetFadeAnimations(config.FadeAnimations, config.FadeDuration) end
    if config.ScaleAnimations ~= nil then self:SetScaleAnimations(config.ScaleAnimations, config.ScaleDuration) end
    if type(config.ThemePalette) == "table" then
        local colors = {}
        for i, color in ipairs(config.ThemePalette) do colors[i] = deserialize(color) end
        self:SetTheme(self:RegisterTheme(config.ThemeName or "Custom", colors))
    elseif config.Theme then self:SetTheme(config.Theme) end
    if type(config.MiniStyle) == "table" and self.Window then
        for _, mini in ipairs(self.Window.Mini) do
            local style = config.MiniStyle[mini.Key]
            if type(style) == "table" then
                mini:SetSize(style.Width, style.Height)
                mini:SetTransparency(style.Transparency)
            end
        end
    end
    if config.Accent then self:SetAccent(deserialize(config.Accent), config.AccentAlpha) end
    if config.Scale and self.Window then self.Window:SetScale(config.Scale) end
    if type(config.Mini) == "table" and self.Window then
        for key, position in pairs(config.Mini) do
            if type(position) == "table" and tonumber(position.X) and tonumber(position.Y) then
                self.Window.MiniPositions[key] = {X = tonumber(position.X), Y = tonumber(position.Y)}
            end
        end
        for _, mini in ipairs(self.Window.Mini) do
            local saved = self.Window.MiniPositions[mini.Key]
            if saved then
                mini.Custom = true
                mini.Position = Vector2.new(saved.X, saved.Y)
            end
        end
    end
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

local ROOT = "WolfUi"
local LEGACY_ROOT = "WolfLib"
local CONFIG_EXTENSION = ".json"
local scriptFolder = "Default"

local function safeName(value)
    local name = string.gsub(tostring(value or ""), "[^%w%-%. ]", "_")
    name = string.gsub(name, "^ +", "")
    name = string.gsub(name, " +$", "")
    if name == "" then name = "Default" end
    return string.sub(name, 1, 40)
end

local function fileSupport()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function folderSupport()
    return type(isfolder) == "function" and type(makefolder) == "function"
end

local function pathExists(path)
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, path)
        if ok then return exists end
    end
    if type(readfile) == "function" then
        return pcall(readfile, path)
    end
    return false
end

local function ensureFolder(path)
    if not folderSupport() then return false end
    local built
    for part in string.gmatch(path, "[^/]+") do
        built = built and (built .. "/" .. part) or part
        local ok, exists = pcall(isfolder, built)
        if not ok then return false end
        if not exists and not pcall(makefolder, built) then return false end
    end
    return true
end

local function migrateLegacyConfigs(target)
    if not fileSupport() or type(listfiles) ~= "function" then return end
    pcall(function()
        if folderSupport() and not isfolder(LEGACY_ROOT) then return end
        for _, path in ipairs(listfiles(LEGACY_ROOT)) do
            local name = string.match(path, "([^/\\]+)%.json$")
            if name then
                local destination = target .. "/" .. safeName(name) .. CONFIG_EXTENSION
                if not pathExists(destination) then
                    pcall(function()
                        local json = readfile(path)
                        HttpService:JSONDecode(json)
                        writefile(destination, json)
                    end)
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
        migrateLegacyConfigs(self.ConfigFolder)
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
    local clean = string.gsub(tostring(path or ""), "^/+", "")
    return ROOT .. "/" .. scriptFolder .. "/" .. clean
end

function Library:WriteFile(path, content)
    if not fileSupport() then return false, "executor has no file API" end
    local full = resolvePath(path)
    local folder = string.match(full, "^(.*)/[^/]+$")
    if folder then ensureFolder(folder) end
    return pcall(writefile, full, tostring(content))
end

function Library:ReadFile(path)
    if not fileSupport() then return nil, "executor has no file API" end
    local ok, result = pcall(readfile, resolvePath(path))
    if not ok then return nil, result end
    return result
end

function Library:DeleteFile(path)
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    return pcall(delfile, resolvePath(path))
end

function Library:ListFiles(subFolder)
    local names = {}
    if type(listfiles) ~= "function" then return names end
    local folder = subFolder and resolvePath(subFolder) or self:GetFolder()
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
    local base = safeName(name or "default")
    local ok, result = pcall(function()
        if not ensureFolder(folder) then error("cannot create config folder", 0) end
        local json = HttpService:JSONEncode(self:GetConfig())
        writefile(folder .. "/" .. base .. CONFIG_EXTENSION, json)
        return folder .. "/" .. base .. CONFIG_EXTENSION
    end)
    return ok, result
end

function Library:LoadConfigFile(name)
    if not fileSupport() then return false, "executor has no file API" end
    local folder = self:GetConfigFolder()
    local base = safeName(name or "default")
    local path = folder .. "/" .. base .. CONFIG_EXTENSION
    local legacyPath = LEGACY_ROOT .. "/" .. base .. CONFIG_EXTENSION
    local ok, decoded = pcall(function()
        local source = pathExists(path) and path or legacyPath
        if not pathExists(source) then error("config not found: " .. base, 0) end
        return HttpService:JSONDecode(readfile(source))
    end)
    if not ok then return false, decoded end
    local applied, loaded, loadError = pcall(self.LoadConfig, self, decoded)
    if not applied then return false, loaded end
    return loaded, loadError
end

function Library:ListConfigs()
    local names = {}
    local seen = {}
    if type(listfiles) ~= "function" then return names end

    local function collect(folder)
        pcall(function()
            for _, path in ipairs(listfiles(folder)) do
                local name = string.match(path, "([^/\\]+)%.json$")
                if name and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end)
    end

    collect(self:GetConfigFolder())
    collect(LEGACY_ROOT)
    table.sort(names)
    return names
end

function Library:DeleteConfigFile(name)
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    local base = safeName(name or "default")
    local paths = {
        self:GetConfigFolder() .. "/" .. base .. CONFIG_EXTENSION,
        LEGACY_ROOT .. "/" .. base .. CONFIG_EXTENSION,
    }
    local deleted
    local lastError
    for _, path in ipairs(paths) do
        if pathExists(path) then
            local ok, err = pcall(delfile, path)
            if ok then
                deleted = true
            else
                lastError = err
            end
        end
    end
    if deleted then return true end
    return false, lastError or ("config not found: " .. base)
end

function Library:Unload()
    Runtime.Alive = false
    restoreFades()
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    Runtime.Connections, Runtime.Updates, Runtime.Overlay = {}, {}, {}
    if self.Window and self.Window.Gui then
        pcall(function() self.Window.Gui:Destroy() end)
    end
    if self.Window and self.Window.Events then
        pcall(function() self.Window.Events:Destroy() end)
    end
    self.Window = nil
    self.Elements = {}
    self.NoSaveFlags = {}
    for _, listener in ipairs(unloadListeners) do
        pcall(listener)
    end
    unloadListeners = {}
    changeListeners = {}
end

Library.Runtime = Runtime
Library.Palette = palette
Library.Icons = IconSheet

return Library
