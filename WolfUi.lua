local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")

local UI_FONT = Enum.Font.Gotham
local UI_FONT_BOLD = Enum.Font.GothamBold

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

-- BuilderIcons: Roblox's built-in vector icon font. No HTTP request or asset id needed.
-- Use it by passing an icon value as "builder:name" / "bi:name" or {BuilderIcon = "name", Bold = true}.
local BuilderIconsFont = {}
do
    local okRegular, regular = pcall(Font.new,
        "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json",
        Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    local okBold, bold = pcall(Font.new,
        "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json",
        Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    BuilderIconsFont.Regular = okRegular and regular or UI_FONT
    BuilderIconsFont.Bold = okBold and bold or UI_FONT_BOLD
end

local function builderIconName(value)
    if type(value) == "table" then
        local name = value.BuilderIcon or value.Builder
        if type(name) == "string" and name ~= "" then
            return name, value.Bold == true
        end
        return nil
    end
    if type(value) ~= "string" then return nil end
    local name = string.match(value, "^[Bb]uilder:%s*(.+)$") or string.match(value, "^[Bb][Ii]:%s*(.+)$")
    if type(name) == "string" and name ~= "" then return name, false end
    return nil
end

-- Searches a list of icon candidates (as used everywhere Icon = {...} appears) for the
-- first entry requesting a BuilderIcons glyph, so it can take priority over the atlas.
local function builderIconFromList(value)
    if type(value) ~= "table" or (value.Id ~= nil or value.AssetId ~= nil or value.Image ~= nil
        or value.Url ~= nil or value.URL ~= nil) then
        return builderIconName(value)
    end
    local isNameList = value[1] ~= nil
    if isNameList then
        for _, entry in ipairs(value) do
            local name, bold = builderIconName(entry)
            if name then return name, bold end
        end
        return nil
    end
    return builderIconName(value)
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

local pureWhite, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local white = pureWhite
local foregroundLabels = setmetatable({}, {__mode = "k"})
local foregroundIcons = setmetatable({}, {__mode = "k"})

local Runtime = {Connections = {}, Updates = {}, Overlay = {}, Alive = false, Owner = nil, ThemeDirty = true,
    Stats = {Connections = 0, Disconnected = 0, Maids = 0, MaidsDestroyed = 0, Sweeps = 0, LastSweep = 0},
    SweepInterval = 3, MaxDeadConnections = 64}

-- ============================================================================
-- Memory core: Maid (ownership container)
-- Every element, popup, notification and tab owns a Maid. Destroying the owner
-- disconnects its connections, destroys its instances, cancels its threads and
-- calls its cleanup callbacks. Maids nest: destroying a parent destroys children.
-- ============================================================================
local Maid = {}
Maid.__index = Maid
local liveMaids = setmetatable({}, {__mode = "k"})

function Maid.new(parent)
    local self = setmetatable({_tasks = {}, _children = setmetatable({}, {__mode = "k"}), Destroyed = false}, Maid)
    liveMaids[self] = true
    Runtime.Stats.Maids = Runtime.Stats.Maids + 1
    if parent and parent.Add then parent._children[self] = true end
    return self
end

local function cleanTask(item)
    local kind = typeof(item)
    if kind == "RBXScriptConnection" then
        if item.Connected then item:Disconnect() end
    elseif kind == "Instance" then
        item:Destroy()
    elseif kind == "function" then
        item()
    elseif kind == "thread" then
        if coroutine.status(item) ~= "dead" then pcall(task.cancel, item) end
    elseif kind == "table" then
        if item.Destroy then item:Destroy()
        elseif item.Disconnect then item:Disconnect()
        elseif item.Cancel then item:Cancel() end
    end
end

function Maid:Add(item, key)
    if self.Destroyed then cleanTask(item) return item end
    if key ~= nil then
        local previous = self._tasks[key]
        if previous ~= nil and previous ~= item then pcall(cleanTask, previous) end
        self._tasks[key] = item
    else
        self._tasks[#self._tasks + 1] = item
    end
    return item
end
Maid.Give = Maid.Add

function Maid:Remove(key)
    local item = self._tasks[key]
    if item ~= nil then
        self._tasks[key] = nil
        pcall(cleanTask, item)
    end
end

function Maid:Connect(signal, callback)
    local connection = signal:Connect(callback)
    self:Add(connection)
    return connection
end

function Maid:Once(signal, callback)
    local connection
    connection = signal:Connect(function(...)
        if connection.Connected then connection:Disconnect() end
        callback(...)
    end)
    self:Add(connection)
    return connection
end

function Maid:Spawn(fn, ...)
    return self:Add(task.spawn(fn, ...))
end

function Maid:Delay(seconds, fn, ...)
    return self:Add(task.delay(seconds, fn, ...))
end

function Maid:Extend()
    return Maid.new(self)
end

function Maid:Count()
    local count = 0
    for _ in pairs(self._tasks) do count = count + 1 end
    return count
end

function Maid:Clean()
    local tasks = self._tasks
    self._tasks = {}
    for child in pairs(self._children) do
        child:Destroy()
    end
    self._children = setmetatable({}, {__mode = "k"})
    -- Disconnect signals first so callbacks cannot fire while instances are torn down.
    for _, item in pairs(tasks) do
        if typeof(item) == "RBXScriptConnection" then pcall(cleanTask, item) end
    end
    for _, item in pairs(tasks) do
        if typeof(item) ~= "RBXScriptConnection" then pcall(cleanTask, item) end
    end
end
Maid.DoCleaning = Maid.Clean

function Maid:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:Clean()
    liveMaids[self] = nil
    Runtime.Stats.MaidsDestroyed = Runtime.Stats.MaidsDestroyed + 1
end

-- Runs `fn` with `maid` as the ambient owner: every connect()/step()/popup made inside
-- is attached to that maid automatically. Nesting is safe.
local function withOwner(maid, fn, ...)
    local previous = Runtime.Owner
    Runtime.Owner = maid
    local results = table.pack(pcall(fn, ...))
    Runtime.Owner = previous
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

local function connect(signal, callback, owner)
    local connection = signal:Connect(callback)
    owner = owner or Runtime.Owner
    if owner then
        owner:Add(connection)
    else
        Runtime.Connections[#Runtime.Connections + 1] = connection
    end
    Runtime.Stats.Connections = Runtime.Stats.Connections + 1
    return connection
end

-- Drops already-disconnected connections from the global list so it never grows
-- with recreated rows / notifications. Cheap: one pass over an array of handles.
local function sweepConnections(force)
    local list = Runtime.Connections
    local count = #list
    local writeIndex = 1
    for readIndex = 1, count do
        local connection = list[readIndex]
        if connection.Connected then
            list[writeIndex] = connection
            writeIndex = writeIndex + 1
        else
            Runtime.Stats.Disconnected = Runtime.Stats.Disconnected + 1
        end
    end
    for index = count, writeIndex, -1 do list[index] = nil end
    Runtime.Stats.Sweeps = Runtime.Stats.Sweeps + 1
    Runtime.Stats.LastSweep = os.clock()
    return count - (writeIndex - 1)
end

local function isRendered(object, cache)
    if not object or not object.Parent then return false end
    local cached = cache and cache[object]
    if cached ~= nil then return cached == true end
    local visible = true
    if object:IsA("GuiObject") and not object.Visible then
        visible = false
    elseif object:IsA("LayerCollector") and not object.Enabled then
        visible = false
    elseif object.Parent and object.Parent ~= game then
        visible = isRendered(object.Parent, cache)
    end
    if cache then cache[object] = visible end
    return visible
end

local function addUpdate(collection, callback, object)
    local update = {Callback = callback, Object = object, Alive = true}
    collection[#collection + 1] = update
    local owner = Runtime.Owner
    if owner then
        -- Owner destruction kills the update even if it has no instance to watch.
        owner:Add(function() update.Alive = false end)
    end
    return update
end

local function step(callback, object)
    return addUpdate(Runtime.Updates, callback, object)
end

local function overlayStep(callback, object)
    return addUpdate(Runtime.Overlay, callback, object)
end

local function runUpdates(collection, dt, k, renderCache)
    local count = #collection
    local writeIndex = 1
    renderCache = renderCache or {}
    for readIndex = 1, count do
        local update = collection[readIndex]
        local object = update.Object
        if update.Alive and (not object or object.Parent) then
            collection[writeIndex] = update
            writeIndex = writeIndex + 1
            if not object or isRendered(object, renderCache) then
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

local function colorDelta(left, right)
    return math.max(math.abs(left.R - right.R), math.abs(left.G - right.G), math.abs(left.B - right.B))
end

local function roundPixel(value)
    value = tonumber(value) or 0
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

local fadeValues = setmetatable({}, {__mode = "k"})
local fadeCaches = setmetatable({}, {__mode = "k"})
local themedStrokes = setmetatable({}, {__mode = "k"})
local themedBackgrounds = setmetatable({}, {__mode = "k"})
local themedLabels = setmetatable({}, {__mode = "k"})
local palette = {}

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
    if object:IsA("ViewportFrame") then
        properties[#properties + 1] = "ImageTransparency"
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
        local added = connect(root.DescendantAdded, function() cache.Dirty = true end)
        local removing = connect(root.DescendantRemoving, function() cache.Dirty = true end)
        -- Short-lived roots (notifications) must not leak connections.
        local destroying
        destroying = root.Destroying:Connect(function()
            added:Disconnect()
            removing:Disconnect()
            if destroying then destroying:Disconnect() end
            fadeCaches[root] = nil
        end)
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

local function visibleFadeTargets(root)
    local targets = {}
    local function collect(object, visible)
        if object ~= root and object:IsA("GuiObject") then
            visible = visible and object.Visible
        end
        if not visible then return end
        local properties = fadeProperties(object)
        if #properties > 0 then
            targets[#targets + 1] = {Object = object, Properties = properties}
        end
        for _, child in ipairs(object:GetChildren()) do
            collect(child, visible)
        end
    end
    collect(root, true)
    return targets
end

local function fadeTargetList(targets, alpha)
    if alpha >= 1 then return end
    for _, target in ipairs(targets) do
        local object = target.Object
        if object.Parent then
            local values = fadeValues[object] or {}
            for _, property in ipairs(target.Properties) do
                if values[property] == nil then values[property] = object[property] end
                object[property] = 1 - (1 - object[property]) * alpha
            end
            fadeValues[object] = values
        end
    end
end

local function fadeGroup(root, alpha)
    fadeTargetList(fadeTargets(root), alpha)
end

local function new(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    if class == "ScrollingFrame" then
        object.ScrollBarThickness = 0
        object.ScrollBarImageTransparency = 1
        object.VerticalScrollBarInset = Enum.ScrollBarInset.None
        object.HorizontalScrollBarInset = Enum.ScrollBarInset.None
        object.TopImage = ""
        object.MidImage = ""
        object.BottomImage = ""
    elseif class == "UIStroke" and props and props.Color then
        for index = 1, 6 do
            if palette[index] and props.Color == palette[index] then
                themedStrokes[object] = index
                break
            end
        end
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
        object.Font = UI_FONT
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
    local themed = color == nil or color == white
    local label = new("TextLabel", parent, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
        Size = UDim2.fromOffset(math.max(0, roundPixel(w)), math.max(0, roundPixel(h))),
        Text = tostring(value or ""),
        Font = opts.Font or (opts.Bold and UI_FONT_BOLD) or UI_FONT,
        TextSize = size or 12,
        TextColor3 = color or white,
        TextXAlignment = (align == "center" and Enum.TextXAlignment.Center)
            or (align == "right" and Enum.TextXAlignment.Right)
            or Enum.TextXAlignment.Left,
        TextYAlignment = opts.Wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = opts.Wrap and true or false,
        TextTruncate = opts.Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        RichText = opts.RichText == true,
        ZIndex = 2,
    })
    if themed then foregroundLabels[label] = true end
    local api = {Object = label}
    function api:SetText(v)
        v = tostring(v)
        if label.Text ~= v then label.Text = v end
    end
    function api:GetText() return label.Text end
    function api:Color(v)
        foregroundLabels[label] = nil
        label.TextColor3 = v
    end
    function api:Alpha(v) label.TextTransparency = 1 - math.clamp(v, 0, 1) end
    function api:Width(v) label.Size = UDim2.fromOffset(math.max(0, roundPixel(v)), label.Size.Y.Offset) end
    function api:SetFont(font)
        if typeof(font) == "EnumItem" then label.Font = font end
    end
    function api:SetSize(v) label.TextSize = math.max(6, tonumber(v) or label.TextSize) end
    return api
end

local function iconLabel(parent, names, x, y, size, color, fallback)
    local builderName, builderBold = builderIconFromList(names)
    local image, offset, sheetSize, tinted, customColor
    if not builderName then
        image, offset, sheetSize, tinted, customColor = resolveIcon(names)
    end
    local object, isImage
    local themed = color == nil or color == white
    if builderName then
        isImage = false
        object = new("TextLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
            Size = UDim2.fromOffset(roundPixel(size), roundPixel(size)),
            Text = builderName,
            FontFace = builderBold and BuilderIconsFont.Bold or BuilderIconsFont.Regular,
            TextSize = size,
            TextColor3 = color or white,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2,
        })
        if themed then foregroundIcons[object] = true end
        local api = {Object = object, IsImage = false, Tinted = true, IsBuilderIcon = true}
        function api:Color(v)
            foregroundIcons[object] = nil
            object.TextColor3 = v
        end
        function api:Alpha(v) object.TextTransparency = 1 - math.clamp(v, 0, 1) end
        function api:SetIcon(value)
            local replacement = iconLabel(object.Parent, value, 0, 0, size, color, fallback)
            replacement.Object.Position, replacement.Object.Size = object.Position, object.Size
            object:Destroy()
            object, isImage = replacement.Object, replacement.IsImage
            self.Object, self.IsImage, self.Tinted, self.IsBuilderIcon =
                object, isImage, replacement.Tinted, replacement.IsBuilderIcon
        end
        return api
    end
    if image then
        isImage = true
        object = new("ImageLabel", parent, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(roundPixel(x), roundPixel(y)),
            Size = UDim2.fromOffset(roundPixel(size), roundPixel(size)),
            Image = image,
            ImageRectOffset = offset,
            ImageRectSize = sheetSize,
            ImageColor3 = customColor or (tinted and (color or white) or pureWhite),
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
            Font = UI_FONT_BOLD,
            TextSize = math.max(8, size - 4),
            TextColor3 = color or white,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2,
        })
    end
    if themed and (not isImage or tinted) then foregroundIcons[object] = true end
    local api = {Object = object, IsImage = isImage, Tinted = tinted == true}
    function api:Color(v)
        foregroundIcons[object] = nil
        if isImage then
            if self.Tinted then object.ImageColor3 = v end
        else
            object.TextColor3 = v
        end
    end
    function api:Alpha(v)
        v = math.clamp(v, 0, 1)
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

-- Palette slots: 1 window, 2 cards/sidebar, 3 muted text, 4 controls, 5 hover/stroke, 6 flash, 7 text
local themes = {
    {{8, 8, 8}, {10, 10, 10}, {150, 150, 150}, {15, 15, 15}, {22, 22, 22}, {50, 50, 50}, {255, 255, 255}},
}
local THEME_NAMES = {"Black"}
for _, theme in ipairs(themes) do
    for i, rgb in ipairs(theme) do
        theme[i] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
end

palette = {}
for i, color in ipairs(themes[1]) do palette[i] = color end
white = palette[7]

local accent = Color3.fromRGB(126, 139, 209)

local function paint(object, index)
    object.BackgroundColor3 = palette[index]
    themedBackgrounds[object] = index
    return object
end

local function muted(parent, value, x, y, w, h, size, align, opts)
    local api = text(parent, value, x, y, w, h, size, palette[3], align, opts)
    themedLabels[api.Object] = 3
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
local SUB_MAX_HEIGHT = 176

local INTERNAL_FLAGS = {
    Scale = true, Accent = true, AccentAlpha = true,
    FadeAnimations = true, ScaleAnimations = true, Tab = true,
}

local Library = {
    Version = "5.6.1",
    Flags = {},
    Elements = {},
    NoSaveFlags = {},
    Themes = themes,
    ThemeNames = THEME_NAMES,
    Font = UI_FONT,
    FontBold = UI_FONT_BOLD,
    FadeAnimations = true,
    FadeDuration = 0.24,
    TabDuration = 0.2,
    TabSlide = 10,
    ScaleAnimations = true,
    ScaleDuration = 0.22,
    ScaleOptions = {100, 75, 50},
    Theme = 1,
    Scale = 75,
    Accent = accent,
    AccentAlpha = 1,
    Configs = {
        Enabled = false,
        Encrypted = false,
    },
    Performance = {
        IdleUpdateRate = 12,
        HiddenUpdateRate = 6,
        ActiveDuration = 0.45,
    },

    Limits = {
        ClampWindow = true,
        Margin = 24,
        MinScale = 0.2,
        MaxScale = 4,
        FitViewport = true,
        SnapScale = true,
    },
    Window = nil,
}

local state = {
    Theme = 1,
    Tab = nil,
    Scale = 75,
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
        if window.Wake then window:Wake() end
        if type(value) ~= "table" and typeof(value) ~= "EnumItem" then
            local key = attributeName(flag)
            pcall(function() window.Gui:SetAttribute(key, value) end)
            if window.Events then
                pcall(function() window.Events:SetAttribute(key, value) end)
            end
        end
        -- BindableEvent rejects some table shapes (mixed keys); never let that break the UI.
        pcall(function() window.Changed:Fire(flag, value) end)
    end
    for _, listener in ipairs(changeListeners) do
        task.spawn(listener, flag, value)
    end
end

local function fadeAlpha(current, target, dt)
    if Library.FadeAnimations == false then return target end
    local duration = math.max(0.08, tonumber(Library.FadeDuration) or 0.24)
    local nextValue = approach(current, target, motionFactor(4.25 / duration, dt))
    if math.abs(target - nextValue) < 0.001 then return target end
    return nextValue
end

local function transitionAlpha(current, target, dt, duration)
    if Library.FadeAnimations == false then return target end
    local nextValue = approach(current, target,
        motionFactor(4.25 / math.max(0.08, tonumber(duration) or 0.2), dt))
    if math.abs(target - nextValue) < 0.001 then return target end
    return nextValue
end

function Library:SetFadeAnimations(enabled, duration)
    self.FadeAnimations = true
    if duration ~= nil then self.FadeDuration = math.clamp(tonumber(duration) or 0.24, 0.08, 2) end
    fireChange("FadeAnimations", self.FadeAnimations)
    return self.FadeAnimations
end

function Library:GetFadeAnimations()
    return true, self.FadeDuration
end

function Library:SetFadeDuration(duration)
    return self:SetFadeAnimations(self.FadeAnimations ~= false, duration)
end

function Library:SetScaleAnimations(enabled, duration)
    self.ScaleAnimations = true
    if duration ~= nil then self.ScaleDuration = math.clamp(tonumber(duration) or 0.22, 0.08, 2) end
    fireChange("ScaleAnimations", self.ScaleAnimations)
    return self.ScaleAnimations
end

function Library:GetScaleAnimations()
    return true, self.ScaleDuration
end

function Library:SetFont(font, boldFont)
    if typeof(font) == "EnumItem" then
        UI_FONT = font
        self.Font = font
    end
    if typeof(boldFont) == "EnumItem" then
        UI_FONT_BOLD = boldFont
        self.FontBold = boldFont
    end
    return UI_FONT, UI_FONT_BOLD
end

function Library:SetScaleDuration(duration)
    return self:SetScaleAnimations(self.ScaleAnimations ~= false, duration)
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

function Library:SetAccent(color, alpha)
    if typeof(color) == "Color3" then
        state.Accent = color
        self.Accent = color
        Runtime.ThemeDirty = true
        fireChange("Accent", color)
    end
    if alpha then
        alpha = math.clamp(alpha, 0, 1)
        state.AccentAlpha = alpha
        self.AccentAlpha = alpha
        Runtime.ThemeDirty = true
        fireChange("AccentAlpha", alpha)
    end
end

function Library:SetPerformanceOptions(opts)
    if type(opts) ~= "table" then return self.Performance end
    if opts.IdleUpdateRate ~= nil then
        self.Performance.IdleUpdateRate = math.clamp(tonumber(opts.IdleUpdateRate) or 12, 4, 60)
    end
    if opts.HiddenUpdateRate ~= nil then
        self.Performance.HiddenUpdateRate = math.clamp(tonumber(opts.HiddenUpdateRate) or 6, 2, 30)
    end
    if opts.ActiveDuration ~= nil then
        self.Performance.ActiveDuration = math.clamp(tonumber(opts.ActiveDuration) or 0.45, 0.1, 2)
    end
    if self.Window and self.Window.Wake then self.Window:Wake() end
    return self.Performance
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

local KEY_LONG = {}
for long, short in pairs(KEY_SHORT) do KEY_LONG[short] = long end

local function keyName(key)
    if key == nil then return "NONE" end
    if typeof(key) == "EnumItem" then
        local name = KEY_SHORT[key.Name] or key.Name
        return string.upper(name)
    end
    return "NONE"
end

local function keyFromName(name)
    if typeof(name) == "EnumItem" then return name end
    if type(name) ~= "string" or name == "" or string.upper(name) == "NONE" then return nil end
    local candidates = {name, KEY_LONG[string.upper(name)]}
    -- Case-insensitive lookup so saved names like "LSHIFT" or "q" resolve.
    for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
        if string.lower(item.Name) == string.lower(name) then
            candidates[#candidates + 1] = item.Name
            break
        end
    end
    for _, candidate in ipairs(candidates) do
        if candidate then
            local ok, key = pcall(function() return Enum.KeyCode[candidate] end)
            if ok and key then return key end
            ok, key = pcall(function() return Enum.UserInputType[candidate] end)
            if ok and key then return key end
        end
    end
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
    data.Maid = Maid.new(Runtime.Owner)
    function data:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if window.Opened == self then window.Opened = self.Parent end
        for index, popup in ipairs(window.Popups) do
            if popup == self then table.remove(window.Popups, index) break end
        end
        self.Maid:Destroy()
        if self.Object then self.Object:Destroy() end
    end

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
        if window.Wake then window:Wake() end
    end
    function data:Close()
        if self:IsActive() then window.Opened = self.Parent end
        if window.Wake then window:Wake() end
    end
    function data:Toggle(anchorOverride)
        if window.Opened == self then
            window.Opened = self.Parent
        else
            self:Open(anchorOverride)
        end
        if window.Wake then window:Wake() end
    end
    return data
end
function Library:CreateWindow(opts)
    opts = opts or {}

    if Library.Window then
        Library:Unload()
    end

    Runtime.Connections, Runtime.Updates, Runtime.Overlay, Runtime.Alive, Runtime.Owner = {}, {}, {}, true, nil
    Runtime.ThemeDirty = true
    Library.Maid = Maid.new()
    local configOptions = opts.Configs
    if configOptions == true then configOptions = {Enabled = true} end
    if type(configOptions) ~= "table" then configOptions = {Enabled = false} end
    self.Configs = {
        Enabled = configOptions.Enabled ~= false and opts.Configs ~= nil,
        Encrypted = configOptions.Encrypted == true or configOptions.Encryption == true,
        Key = tostring(configOptions.Key or "1"),
    }
    Library:SetScriptName(opts.Folder or opts.ScriptName or opts.Name)
    self.FadeAnimations, self.ScaleAnimations = true, true
    if opts.FadeDuration ~= nil then self:SetFadeDuration(opts.FadeDuration) end
    if opts.ScaleDuration ~= nil then self:SetScaleDuration(opts.ScaleDuration) end
    if type(opts.Performance) == "table" then self:SetPerformanceOptions(opts.Performance) end

    local previous = playerGui:FindFirstChild(opts.GuiName or "WolfUI")
    if previous then previous:Destroy() end

    state.Theme = 1
    state.Scale = math.clamp(tonumber(opts.Scale) or 75, 20, 400)
    state.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or Color3.fromRGB(126, 139, 209)
    state.AccentAlpha = opts.AccentAlpha or 1
    state.Tab = nil
    accent = state.Accent
    for i, color in ipairs(themes[state.Theme]) do palette[i] = color end
    white = palette[7] or pureWhite
    Library.Theme, Library.Scale = state.Theme, state.Scale
    Library.Accent, Library.AccentAlpha = state.Accent, state.AccentAlpha

    local windowIcon = opts.Icon or {"dog", "paw-print", "moon"}
    local menuSettings = opts.MenuSettings
    if menuSettings == true then menuSettings = {} end
    local menuSettingsEnabled = type(menuSettings) == "table" and menuSettings.Enabled ~= false

    local window = setmetatable({
        Visible = true,
        Alpha = 0,
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
        UpdateAccumulator = 0,
        RenderCache = {},
        MainFadeTargets = nil,
        MainFadeDirty = true,
        ActiveUntil = os.clock() + 1,
    }, Window)
    function window:Wake(duration)
        local activeDuration = tonumber(duration)
            or tonumber(Library.Performance and Library.Performance.ActiveDuration) or 0.45
        self.ActiveUntil = math.max(self.ActiveUntil or 0, os.clock() + activeDuration)
    end
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
    frame.ZIndex = 2
    frame.Active = true
    frame.ClipsDescendants = true
    window.Frame = frame
    connect(frame.DescendantAdded, function() window.MainFadeDirty = true end)
    connect(frame.DescendantRemoving, function() window.MainFadeDirty = true end)

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
        if not window.Initialized or immediate then
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
        if math.abs(target - current) > 0.0005 then
            local duration = math.max(0.08, Library.ScaleDuration)
            local nextScale = Library.ScaleAnimations == false and target
                or approach(current, target, motionFactor(4.25 / duration, dt))
            if math.abs(target - nextScale) < 0.0005 then nextScale = target end
            window.Position = window.Position + Vector2.new(WINDOW_W, WINDOW_H) * ((current - nextScale) / 2)
            window.ScaleCurrent = nextScale
            changed = true
        else
            window.ScaleCurrent = target
        end
        if changed or window.Viewport ~= previousViewport then layout(false) end
        return changed
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
        if not drag then
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local point = Vector2.new(input.Position.X, input.Position.Y)
                local function contains(object)
                    if not object or not object.Parent or not object.Visible then return false end
                    local origin, size = object.AbsolutePosition, object.AbsoluteSize
                    return point.X >= origin.X and point.Y >= origin.Y
                        and point.X <= origin.X + size.X and point.Y <= origin.Y + size.Y
                end
                if contains(frame) or contains(window.Reopen) or contains(window.Watermark) then
                    window:Wake(0.2)
                end
            end
            return
        end
        window:Wake(0.25)
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
    local logoSize = 28
    local logoIcon = iconLabel(logoHit, windowIcon,
        (SIDEBAR_W - logoSize) / 2, (TAB_SLOT - logoSize) / 2,
        logoSize, accent, string.sub(opts.Name or "W", 1, 1))
    step(function()
        logoIcon:Color(accent)
        logoIcon:Alpha(state.AccentAlpha)
    end, logoHit)

    window.LogoIcon = logoIcon
    window.Icon = windowIcon
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
        window:Wake()
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
        local hit = transparent(rail, 6, y - 4, 18, 18, "TextButton")
        local icon = iconLabel(hit, config.Icon or {"circle"}, 4, 4, 10, palette[3], config.Fallback or "*")
        local hover, tint = false, palette[3]
        connect(hit.MouseEnter, function() hover = true end)
        connect(hit.MouseLeave, function() hover = false end)
        step(function(_, k)
            tint = tint:Lerp(hover and white or palette[3], k)
            icon:Color(tint)
        end, hit)
        if config.Callback then
            connect(hit.Activated, function() config.Callback(hit) end)
        end
        return hit
    end

    window.RebuildScaleButtons = function() end
    if menuSettingsEnabled and menuSettings.Scale ~= false then
        local settingsButton = window:AddRailButton({
            Icon = menuSettings.Icon or {"settings", "settings-2", "sliders-horizontal"},
            Fallback = "S",
        })
        local settingsPopup = createPopup(window, settingsButton, 190, 57, false)
        local label = muted(settingsPopup.Object, "Menu scale", 10, 6, 170, 14, 11)
        local holder = transparent(settingsPopup.Object, 10, 26, 170, 25)
        local buttons = {}

        local function rebuildScaleButtons()
            for _, button in ipairs(buttons) do button:Destroy() end
            table.clear(buttons)
            local count = math.max(1, #Library.ScaleOptions)
            local gap = 6
            local buttonWidth = math.floor((170 - gap * (count - 1)) / count)
            for index, option in ipairs(Library.ScaleOptions) do
                local button = paint(rect(holder, (index - 1) * (buttonWidth + gap), 0,
                    buttonWidth, 25, palette[4], 3, "TextButton"), 4)
                local caption = text(button, tostring(option) .. "%", 0, 0, buttonWidth, 25,
                    10, palette[3], "center")
                local hovered, tint = false, palette[3]
                connect(button.MouseEnter, function() hovered = true end)
                connect(button.MouseLeave, function() hovered = false end)
                connect(button.Activated, function() window:SetScale(option) end)
                step(function(_, k)
                    local active = state.Scale == option
                    button.BackgroundColor3 = palette[4]:Lerp(palette[5], hovered and 1 or 0)
                        :Lerp(accent, active and 0.42 * state.AccentAlpha or 0)
                    tint = tint:Lerp(active and white or palette[3], k)
                    caption:Color(tint)
                end, button)
                buttons[#buttons + 1] = button
            end
            label.Object.Visible = count > 0
        end

        window.RebuildScaleButtons = rebuildScaleButtons
        rebuildScaleButtons()
        connect(settingsButton.Activated, function() settingsPopup:Toggle(settingsButton) end)
        window.MenuSettingsButton = settingsButton
        window.MenuSettingsPopup = settingsPopup
    end

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
    local reopenIcon = iconLabel(reopen, windowIcon, 5, 5, 22, accent,
        string.sub(opts.Name or "W", 1, 1))
    window.Reopen = reopen
    window.ReopenIcon = reopenIcon

    -- Watermark ----------------------------------------------------------------
    -- The watermark is a root frame holding one or more "capsules". Every capsule
    -- carries a set of blocks (icon/text pairs). Layout "solid" packs all blocks
    -- into one capsule, "split" gives each block (or each Group) its own capsule.
    local watermarkRoot = new("Frame", gui, {
        Name = "Watermark",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        Active = true,
        ZIndex = 42,
    })
    local watermarkScale = new("UIScale", watermarkRoot, {Scale = 1})
    window.Watermark = watermarkRoot

    window.WatermarkConfig = {
        Enabled = false,
        Transparency = 0,
        Toggle = true,
        AlwaysVisible = true,
        Draggable = true,
        Position = Vector2.new(8, 8),
        Anchor = "TopLeft",
        Layout = "solid",
        Direction = "horizontal",
        Height = 22,
        Padding = 8,
        Gap = 10,
        Spacing = 6,
        MinimumWidth = 32,
        Scale = 1,
        Shape = "capsule",
        Radius = 6,
        Background = nil,
        Stroke = true,
        StrokeColor = nil,
        StrokeTransparency = 0.4,
        StrokeThickness = 1,
        Gradient = false,
        GradientColor = nil,
        GradientRotation = 90,
        AccentLine = "none",
        AccentLineColor = nil,
        AccentLineThickness = 2,
        Separator = "none",
        SeparatorColor = nil,
        TextSize = 10,
        Font = nil,
        Bold = false,
        Uppercase = false,
        TextColor = nil,
        IconColor = nil,
        IconSize = 12,
        Dynamic = false,
        GoodColor = Color3.fromRGB(110, 220, 140),
        WarnColor = Color3.fromRGB(240, 200, 90),
        BadColor = Color3.fromRGB(240, 100, 100),
        FadeDuration = Library.FadeDuration,
        Blocks = {},
    }
    local defaultWatermarkBlocks = {
        {Id = "brand", Type = "Icon", Icon = windowIcon, Size = 16, UseWindowIcon = true},
        {Id = "fps", Type = "FPS", Icon = {"gauge", "activity", "monitor"}},
        {Id = "ping", Type = "Ping", Icon = {"wifi", "radio", "globe"}},
        {Id = "time", Type = "Time", Icon = {"clock-3", "clock"}},
    }
    local watermarkCapsules = {}
    local watermarkItems = {}
    local watermarkSequence = {}
    local watermarkAlpha = 0
    local gameName, gameNameRequested = nil, false

    local function copyWatermarkBlock(source, index)
        local block = {}
        for key, value in pairs(source or {}) do block[key] = value end
        block.Id = tostring(block.Id or block.Name or ("block_" .. tostring(index)))
        block.Type = string.lower(tostring(block.Type or "Text"))
        return block
    end

    -- Resolves a color option: Color3, "#RRGGBB", or keywords accent/text/muted/good/warn/bad/...
    local function watermarkColor(value, fallback)
        local wm = window.WatermarkConfig
        if typeof(value) == "Color3" then return value end
        if type(value) == "string" then
            local key = string.lower(value)
            if key == "accent" then return accent end
            if key == "text" or key == "white" then return white end
            if key == "muted" then return palette[3] end
            if key == "good" then return wm.GoodColor end
            if key == "warn" or key == "warning" then return wm.WarnColor end
            if key == "bad" or key == "error" then return wm.BadColor end
            if key == "background" or key == "card" then return palette[2] end
            if key == "window" then return palette[1] end
            if key == "control" then return palette[4] end
            if key == "stroke" then return palette[5] end
            local hex = string.match(value, "^#?(%x%x%x%x%x%x)$")
            if hex then
                return Color3.fromRGB(
                    tonumber(string.sub(hex, 1, 2), 16),
                    tonumber(string.sub(hex, 3, 4), 16),
                    tonumber(string.sub(hex, 5, 6), 16))
            end
        end
        return fallback
    end
    window.WatermarkColor = watermarkColor

    local function watermarkRadius(shape, radius, height)
        shape = string.lower(tostring(shape or "capsule"))
        if shape == "square" or shape == "none" then return 0 end
        if shape == "rounded" or shape == "card" then return math.max(0, math.floor(tonumber(radius) or 6)) end
        return math.floor(height / 2)
    end

    local function makeCapsule()
        local frame = rect(watermarkRoot, 0, 0, 10, 22, palette[2], nil, "Frame")
        frame.Name = "Capsule"
        frame.ClipsDescendants = true
        local corner = new("UICorner", frame, {CornerRadius = UDim.new(0, 11)})
        local stroke = new("UIStroke", frame, {Thickness = 1, Transparency = 0.4})
        stroke.Color = palette[5]
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        local gradient = new("UIGradient", frame, {Enabled = false, Rotation = 90})
        local line = rect(frame, 0, 0, 2, 22, accent)
        line.Name = "AccentLine"
        line.Visible = false
        line.ZIndex = 4
        return {
            Object = frame, Corner = corner, Stroke = stroke, Gradient = gradient, Line = line,
            Items = {}, Width = 0, Height = 22, Style = {}, Visible = false,
        }
    end

    local function rebuildWatermarkBlocks(blocks)
        local wm = window.WatermarkConfig
        local sources = {}
        for index, source in ipairs(blocks or {}) do sources[index] = copyWatermarkBlock(source, index) end
        for _, capsule in ipairs(watermarkCapsules) do capsule.Object:Destroy() end
        table.clear(watermarkCapsules)
        table.clear(watermarkItems)
        table.clear(watermarkSequence)
        table.clear(wm.Blocks)

        local layout = string.lower(tostring(wm.Layout or "solid"))
        local split = layout == "split" or layout == "separate" or layout == "capsules" or layout == "grouped"
        local height = math.max(14, math.floor(tonumber(wm.Height) or 22))
        local capsule, lastKey = nil, nil

        for index, block in ipairs(sources) do
            wm.Blocks[index] = block
            local kind = block.Type
            if kind == "spacer" and split then
                -- In split layouts a spacer only widens the distance between capsules.
                watermarkSequence[#watermarkSequence + 1] = {Gap = block}
                lastKey = nil
            else
                local key
                if split then
                    key = block.Group ~= nil and ("group:" .. tostring(block.Group)) or ("solo:" .. block.Id)
                elseif block.Separate then
                    key = "solo:" .. block.Id
                elseif block.Group ~= nil then
                    key = "group:" .. tostring(block.Group)
                else
                    key = "main"
                end
                if not capsule or key ~= lastKey then
                    capsule = makeCapsule()
                    capsule.Key = key
                    capsule.Style = block
                    watermarkCapsules[#watermarkCapsules + 1] = capsule
                    watermarkSequence[#watermarkSequence + 1] = {Capsule = capsule}
                    lastKey = key
                end

                local object = transparent(capsule.Object, 0, 0, 0, height)
                object.Name = block.Id
                object.ZIndex = 2
                local item = {Object = object, Block = block, Capsule = capsule, Width = 0, TextWidth = 0}
                local bold = block.Bold == true or (block.Bold == nil and wm.Bold == true)
                item.Font = (typeof(block.Font) == "EnumItem" and block.Font)
                    or (typeof(wm.Font) == "EnumItem" and wm.Font)
                    or (bold and UI_FONT_BOLD or UI_FONT)
                item.TextSize = math.max(6, math.floor(tonumber(block.TextSize) or tonumber(wm.TextSize) or 10))
                item.IconSize = math.max(6, math.floor(tonumber(block.IconSize or block.Size)
                    or tonumber(wm.IconSize) or 12))

                local iconValue = block.Icon
                if kind == "icon" and iconValue == nil then iconValue = windowIcon end
                if iconValue ~= nil and iconValue ~= false and kind ~= "spacer" and kind ~= "divider" then
                    item.Icon = iconLabel(object, iconValue, 0, 0, item.IconSize, accent,
                        block.Fallback or string.upper(string.sub(block.Id, 1, 1)))
                    item.Icon.Object.ZIndex = 3
                end
                if kind ~= "icon" and kind ~= "spacer" and kind ~= "divider" then
                    item.Label = text(object, "", 0, 0, 0, height, item.TextSize, palette[3], nil, {Font = item.Font})
                    item.Label.Object.ZIndex = 3
                end
                if kind == "divider" then
                    item.Line = rect(object, 0, 0, 1, height, palette[5])
                    item.Line.ZIndex = 3
                end

                local separator = string.lower(tostring(block.Separator or wm.Separator or "none"))
                if separator ~= "none" and separator ~= "false" and separator ~= "" then
                    item.SeparatorKind = separator
                    if separator == "line" then
                        item.Separator = rect(capsule.Object, 0, 0, 1, 10, palette[5])
                        item.SeparatorWidth = 1
                    elseif separator == "dot" then
                        item.Separator = rect(capsule.Object, 0, 0, 3, 3, palette[5], 2)
                        item.SeparatorWidth = 3
                    else
                        local glyph = separator == "slash" and "/"
                            or (separator == "pipe" and "|")
                            or (separator == "bullet" and "•")
                            or (separator == "arrow" and "›")
                            or separator
                        local sepLabel = text(capsule.Object, glyph, 0, 0, 10, height, item.TextSize, palette[3],
                            "center", {Font = item.Font})
                        item.Separator = sepLabel.Object
                        item.SeparatorLabel = sepLabel
                        item.SeparatorWidth = math.ceil(TextService:GetTextSize(glyph, item.TextSize, item.Font,
                            Vector2.new(100, height)).X)
                    end
                    item.Separator.ZIndex = 3
                    item.Separator.Visible = false
                end

                capsule.Items[#capsule.Items + 1] = item
                watermarkItems[#watermarkItems + 1] = item
            end
        end
        window.WatermarkItems = watermarkItems
        window.WatermarkCapsules = watermarkCapsules
        if window.Wake then window:Wake() end
    end
    window.RebuildWatermarkBlocks = rebuildWatermarkBlocks
    rebuildWatermarkBlocks(defaultWatermarkBlocks)

    local function watermarkValue(item, context)
        local block, kind = item.Block, item.Block.Type
        local value, numeric = block.Text, nil
        if type(value) == "function" then
            local ok, result = pcall(value, context, block)
            value = ok and result or ""
        elseif type(block.Update) == "function" then
            local ok, result = pcall(block.Update, context, block)
            value = ok and result or ""
        elseif value == nil then
            if kind == "fps" then
                numeric = context.FPS
                value = tostring(numeric) .. tostring(block.Suffix or " fps")
            elseif kind == "ping" then
                numeric = context.Ping
                value = tostring(numeric) .. tostring(block.Suffix or " ms")
            elseif kind == "time" or kind == "clock" then
                value = os.date(block.Format or "%H:%M:%S")
            elseif kind == "date" then
                value = os.date(block.Format or "%d.%m.%Y")
            elseif kind == "player" or kind == "name" then
                value = block.DisplayName == false and player.Name or player.DisplayName
            elseif kind == "players" or kind == "server" then
                local count = #Players:GetPlayers()
                value = tostring(count) .. (block.ShowMax ~= false and ("/" .. tostring(Players.MaxPlayers)) or "")
            elseif kind == "game" or kind == "place" then
                if gameName == nil and not gameNameRequested then
                    gameNameRequested = true
                    task.spawn(function()
                        local ok, info = pcall(function()
                            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
                        end)
                        gameName = (ok and type(info) == "table" and info.Name) or "Unknown"
                    end)
                end
                value = gameName or "..."
            elseif kind == "executor" then
                local ok, name = pcall(function()
                    if type(identifyexecutor) == "function" then return (identifyexecutor()) end
                    if type(getexecutorname) == "function" then return (getexecutorname()) end
                    return nil
                end)
                value = (ok and name) or "Unknown"
            elseif kind == "memory" then
                local ok, mb = pcall(function() return StatsService:GetTotalMemoryUsageMb() end)
                numeric = ok and math.floor(mb + 0.5) or 0
                value = tostring(numeric) .. tostring(block.Suffix or " mb")
            elseif kind == "version" then
                value = "v" .. tostring(Library.Version)
            else
                value = ""
            end
        end
        value = tostring(block.Prefix or "") .. tostring(value == nil and "" or value) .. tostring(block.SuffixText or "")
        if block.Uppercase == true or (block.Uppercase == nil and window.WatermarkConfig.Uppercase == true) then
            value = string.upper(value)
        end
        return value, numeric
    end

    local function watermarkDynamic(item, numeric)
        local block, wm = item.Block, window.WatermarkConfig
        local dynamic = block.Dynamic
        if dynamic == nil then dynamic = wm.Dynamic end
        if not dynamic or numeric == nil then return nil end
        local good = watermarkColor(block.GoodColor, wm.GoodColor)
        local warn = watermarkColor(block.WarnColor, wm.WarnColor)
        local bad = watermarkColor(block.BadColor, wm.BadColor)
        local kind = block.Type
        if kind == "fps" then
            local g, w = tonumber(block.Good) or 50, tonumber(block.Warn) or 30
            if numeric >= g then return good elseif numeric >= w then return warn end
            return bad
        elseif kind == "ping" then
            local g, w = tonumber(block.Good) or 80, tonumber(block.Warn) or 150
            if numeric <= g then return good elseif numeric <= w then return warn end
            return bad
        elseif kind == "memory" then
            local g, w = tonumber(block.Good) or 1200, tonumber(block.Warn) or 2200
            if numeric <= g then return good elseif numeric <= w then return warn end
            return bad
        end
        return nil
    end

    local ANCHORS = {
        topleft = Vector2.new(0, 0), top = Vector2.new(0.5, 0), topcenter = Vector2.new(0.5, 0),
        topright = Vector2.new(1, 0), left = Vector2.new(0, 0.5), center = Vector2.new(0.5, 0.5),
        right = Vector2.new(1, 0.5), bottomleft = Vector2.new(0, 1), bottom = Vector2.new(0.5, 1),
        bottomcenter = Vector2.new(0.5, 1), bottomright = Vector2.new(1, 1),
    }
    local function watermarkAnchor()
        local name = string.lower((string.gsub(tostring(window.WatermarkConfig.Anchor or "TopLeft"), "[%s_%-]", "")))
        return ANCHORS[name] or ANCHORS.topleft
    end
    -- Position is stored as an inward offset from the anchored corner, so the
    -- watermark keeps its place when the viewport changes.
    local function watermarkFrame(size, viewport)
        local a = watermarkAnchor()
        local base = Vector2.new((viewport.X - size.X) * a.X, (viewport.Y - size.Y) * a.Y)
        local sign = Vector2.new(a.X == 1 and -1 or 1, a.Y == 1 and -1 or 1)
        return base, sign
    end
    local function watermarkTopLeft(size, viewport)
        local wm = window.WatermarkConfig
        local base, sign = watermarkFrame(size, viewport)
        local topLeft = base + Vector2.new(wm.Position.X * sign.X, wm.Position.Y * sign.Y)
        topLeft = Vector2.new(
            math.clamp(topLeft.X, 0, math.max(0, viewport.X - size.X)),
            math.clamp(topLeft.Y, 0, math.max(0, viewport.Y - size.Y)))
        wm.Position = Vector2.new((topLeft.X - base.X) * sign.X, (topLeft.Y - base.Y) * sign.Y)
        return topLeft
    end

    local initialOpenMode = string.lower(tostring(type(opts.OpenMode) == "table" and opts.OpenMode.Mode or opts.OpenMode or "button"))
    if initialOpenMode ~= "watermark" then initialOpenMode = "button" end
    window.OpenConfig = {
        Mode = initialOpenMode,
        AlwaysVisible = opts.OpenAlways ~= false,
        Size = math.max(24, math.floor(tonumber(opts.OpenSize) or 32)),
        Width = math.max(24, math.floor(tonumber(opts.OpenWidth or opts.OpenSize) or 32)),
        Height = math.max(24, math.floor(tonumber(opts.OpenHeight or opts.OpenSize) or 32)),
        Transparency = 0,
        AnimationDuration = Library.FadeDuration,
        Position = Vector2.new(8, 8),
    }

    function window.UpdateOpenVisibility()
        window.OpenerDirty = true
        if window.Wake then window:Wake() end
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

    -- Drag the watermark anywhere; a plain click toggles the menu in watermark mode.
    local wmDragStart, wmDragOrigin
    draggable(watermarkRoot, function(point, initial)
        local wm = window.WatermarkConfig
        if initial then
            wmDragStart = point
            wmDragOrigin = Vector2.new(watermarkRoot.Position.X.Offset, watermarkRoot.Position.Y.Offset)
            return
        end
        if wm.Draggable == false then return end
        local size, viewport = watermarkRoot.AbsoluteSize, window.Viewport
        local base, sign = watermarkFrame(size, viewport)
        local topLeft = wmDragOrigin + point - wmDragStart
        topLeft = Vector2.new(
            math.clamp(topLeft.X, 0, math.max(0, viewport.X - size.X)),
            math.clamp(topLeft.Y, 0, math.max(0, viewport.Y - size.Y)))
        wm.Position = Vector2.new(roundPixel((topLeft.X - base.X) * sign.X), roundPixel((topLeft.Y - base.Y) * sign.Y))
    end, function(cancelled, moved)
        if cancelled then return end
        local wm = window.WatermarkConfig
        if moved then
            if type(wm.OnMove) == "function" then task.spawn(wm.OnMove, wm.Position) end
        elseif window.OpenConfig.Mode == "watermark" and wm.Enabled and wm.Toggle ~= false then
            window:SetVisible(not window.Visible)
        elseif type(wm.OnClick) == "function" then
            task.spawn(wm.OnClick)
        end
    end, DRAG_THRESHOLD)

    local reopenAlpha = 0
    local reopenHover = false
    connect(reopen.MouseEnter, function() reopenHover = true end)
    connect(reopen.MouseLeave, function() reopenHover = false end)
    local tooltipCaption, tooltipWidth = nil, 0

    overlayStep(function(dt)
        local viewport = window.Viewport
        local oc = window.OpenConfig
        local wm = window.WatermarkConfig
        local hidden = not window.Visible

        -- Reopen button ----------------------------------------------------------
        local buttonMode = oc.Mode ~= "watermark"
        local showButton = buttonMode and (hidden or oc.AlwaysVisible == true)
        local buttonTarget = showButton and 1 or 0
        reopenAlpha = approach(reopenAlpha, buttonTarget,
            motionFactor(4.25 / math.max(0.08, tonumber(oc.AnimationDuration) or Library.FadeDuration), dt))
        if math.abs(reopenAlpha - buttonTarget) < 0.001 then reopenAlpha = buttonTarget end
        reopen.Visible = reopenAlpha > 0.001
        reopen.Interactable = showButton
        if reopen.Visible then
            local size = Vector2.new(oc.Width, oc.Height)
            oc.Position = Vector2.new(
                math.clamp(oc.Position.X, 0, math.max(0, viewport.X - size.X)),
                math.clamp(oc.Position.Y, 0, math.max(0, viewport.Y - size.Y)))
            reopen.Position = UDim2.fromOffset(roundPixel(oc.Position.X), roundPixel(oc.Position.Y))
            reopen.Size = UDim2.fromOffset(roundPixel(size.X), roundPixel(size.Y))
            local transparency = math.clamp(tonumber(oc.Transparency) or 0, 0, 1)
            local visible = reopenAlpha * (1 - transparency)
            reopen.BackgroundColor3 = palette[2]:Lerp(palette[5], reopenHover and 0.6 or 0)
            reopen.BackgroundTransparency = 1 - visible
            reopenStroke.Color = palette[5]:Lerp(accent, reopenHover and 1 or 0)
            reopenStroke.Transparency = 1 - 0.6 * visible
            local iconSize = math.floor(math.min(size.X, size.Y) * 0.68)
            reopenIcon.Object.Position = UDim2.fromOffset(
                roundPixel((size.X - iconSize) / 2), roundPixel((size.Y - iconSize) / 2))
            reopenIcon.Object.Size = UDim2.fromOffset(iconSize, iconSize)
            reopenIcon:Color(accent)
            reopenIcon:Alpha(reopenAlpha * state.AccentAlpha)
        end

        -- Watermark --------------------------------------------------------------
        local showWatermark = wm.Enabled == true and (wm.AlwaysVisible ~= false or hidden)
        local wmTarget = showWatermark and 1 or 0
        watermarkAlpha = approach(watermarkAlpha, wmTarget,
            motionFactor(4.25 / math.max(0.08, tonumber(wm.FadeDuration) or Library.FadeDuration), dt))
        if math.abs(watermarkAlpha - wmTarget) < 0.001 then watermarkAlpha = wmTarget end
        if not showWatermark and window.Drag and window.Drag.Object == watermarkRoot then cancelDrag() end
        watermarkRoot.Visible = watermarkAlpha > 0.001
        watermarkRoot.Interactable = showWatermark
        if watermarkRoot.Visible then
            local height = math.max(14, math.floor(tonumber(wm.Height) or 22))
            local padding = math.max(0, math.floor(tonumber(wm.Padding) or 8))
            local gap = math.max(0, math.floor(tonumber(wm.Gap) or 10))
            local spacing = math.max(0, math.floor(tonumber(wm.Spacing) or 6))
            local vertical = string.lower(tostring(wm.Direction or "horizontal")) == "vertical"
            local opacity = math.clamp(1 - (tonumber(wm.Transparency) or 0), 0, 1)
            local alpha = watermarkAlpha
            local context = {
                FPS = window.FPS, Ping = window.Ping, Time = os.date("%H:%M:%S"),
                Player = player, Window = window, Library = Library,
            }
            local baseText = watermarkColor(wm.TextColor, palette[3])
            local baseIcon = watermarkColor(wm.IconColor, accent)

            for _, capsule in ipairs(watermarkCapsules) do
                local style = capsule.Style or {}
                local capPadding = math.max(0, math.floor(tonumber(style.Padding) or padding))
                local capGap = math.max(0, math.floor(tonumber(style.Gap) or gap))
                local x, lastGap, visibleCount = capPadding, 0, 0
                for _, item in ipairs(capsule.Items) do
                    local block = item.Block
                    local visible = block.Visible ~= false
                    if type(block.Visible) == "function" then
                        local ok, result = pcall(block.Visible, context, block)
                        visible = ok and result ~= false
                    end
                    item.Object.Visible = visible
                    if item.Separator then item.Separator.Visible = false end
                    if visible then
                        local kind = block.Type
                        local value, numeric = "", nil
                        if item.Label then value, numeric = watermarkValue(item, context) end
                        local iconShown = item.Icon ~= nil and block.IconVisible ~= false
                        local iconSize = iconShown and item.IconSize or 0
                        local labelWidth = 0
                        if item.Label then
                            if item.LastText ~= value then
                                item.LastText = value
                                local bounds = TextService:GetTextSize(value, item.TextSize, item.Font,
                                    Vector2.new(4000, height))
                                item.TextWidth = value == "" and 0 or math.ceil(bounds.X) + 1
                                item.Label:SetText(value)
                                item.Label:Width(item.TextWidth)
                            end
                            labelWidth = item.TextWidth
                        end

                        if visibleCount > 0 and item.Separator then
                            item.Separator.Visible = true
                            local sw = item.SeparatorWidth or 1
                            if item.SeparatorKind == "line" then
                                item.Separator.Size = UDim2.fromOffset(1, math.max(4, math.floor(height * 0.5)))
                                item.Separator.Position = UDim2.fromOffset(roundPixel(x), roundPixel(height * 0.25))
                            elseif item.SeparatorKind == "dot" then
                                item.Separator.Position = UDim2.fromOffset(roundPixel(x), roundPixel((height - 3) / 2))
                            else
                                item.Separator.Size = UDim2.fromOffset(sw, height)
                                item.Separator.Position = UDim2.fromOffset(roundPixel(x), 0)
                            end
                            local sepColor = watermarkColor(block.SeparatorColor or wm.SeparatorColor, palette[5])
                            if item.SeparatorLabel then
                                item.SeparatorLabel:Color(sepColor)
                                item.SeparatorLabel:Alpha(alpha)
                            else
                                item.Separator.BackgroundColor3 = sepColor
                                item.Separator.BackgroundTransparency = 1 - alpha
                            end
                            x = x + sw + capGap
                        end

                        local innerGap = (iconShown and item.Label and value ~= "") and (tonumber(block.InnerGap) or 4) or 0
                        local width
                        if kind == "spacer" then
                            width = math.max(0, tonumber(block.Width) or 8)
                        elseif kind == "divider" then
                            width = 1
                        else
                            width = math.max(0, tonumber(block.Width) or (iconSize + innerGap + labelWidth))
                        end
                        item.Width = width
                        item.Object.Position = UDim2.fromOffset(roundPixel(x), 0)
                        item.Object.Size = UDim2.fromOffset(roundPixel(width), height)

                        local dynamic = watermarkDynamic(item, numeric)
                        if item.Icon then
                            item.Icon.Object.Visible = iconShown
                            item.Icon.Object.Position = UDim2.fromOffset(0, roundPixel((height - iconSize) / 2))
                            item.Icon.Object.Size = UDim2.fromOffset(iconSize, iconSize)
                            local custom = block.IconColor or block.Color or wm.IconColor or dynamic
                            item.Icon:Color(watermarkColor(block.IconColor or block.Color, dynamic or baseIcon))
                            item.Icon:Alpha(alpha * math.clamp(tonumber(block.IconAlpha)
                                or (custom and 1 or state.AccentAlpha), 0, 1))
                        end
                        if item.Label then
                            item.Label.Object.Position = UDim2.fromOffset(iconSize + innerGap, 0)
                            item.Label.Object.Size = UDim2.fromOffset(labelWidth, height)
                            item.Label:Color(dynamic or watermarkColor(block.TextColor or block.Color, baseText))
                            item.Label:Alpha(alpha * math.clamp(tonumber(block.TextAlpha) or 1, 0, 1))
                        end
                        if item.Line then
                            item.Line.Size = UDim2.fromOffset(1, math.max(4, math.floor(height * 0.5)))
                            item.Line.Position = UDim2.fromOffset(0, roundPixel(height * 0.25))
                            item.Line.BackgroundColor3 = watermarkColor(block.Color,
                                watermarkColor(wm.SeparatorColor, palette[5]))
                            item.Line.BackgroundTransparency = 1 - alpha
                        end

                        lastGap = tonumber(block.Gap) or capGap
                        x = x + width + lastGap
                        visibleCount = visibleCount + 1
                    end
                end
                if visibleCount > 0 then
                    x = x - lastGap
                    local minWidth = math.max(0, tonumber(style.MinimumWidth) or tonumber(wm.MinimumWidth) or 0)
                    capsule.Width = math.max(minWidth, x + capPadding)
                    capsule.Height = height
                    capsule.Visible = true
                else
                    capsule.Visible = false
                end
                capsule.Object.Visible = capsule.Visible
            end

            -- Arrange capsules in a row or a column.
            local cx, cy, totalW, totalH, extra, placed = 0, 0, 0, 0, 0, 0
            for _, entry in ipairs(watermarkSequence) do
                if entry.Gap then
                    extra = extra + math.max(0, tonumber(entry.Gap.Width) or spacing)
                elseif entry.Capsule.Visible then
                    local capsule = entry.Capsule
                    if placed > 0 then
                        if vertical then cy = cy + spacing + extra else cx = cx + spacing + extra end
                    end
                    extra = 0
                    capsule.X, capsule.Y = cx, cy
                    if vertical then
                        cy = cy + capsule.Height
                        totalW = math.max(totalW, capsule.Width)
                    else
                        cx = cx + capsule.Width
                        totalH = math.max(totalH, capsule.Height)
                    end
                    placed = placed + 1
                end
            end
            if vertical then totalH = cy else totalW = cx end
            local anchorX = watermarkAnchor().X

            for _, capsule in ipairs(watermarkCapsules) do
                if capsule.Visible then
                    local style = capsule.Style or {}
                    local h = capsule.Height
                    local w = roundPixel(capsule.Width)
                    local px = vertical and (totalW - capsule.Width) * anchorX or capsule.X
                    capsule.Object.Position = UDim2.fromOffset(roundPixel(px), roundPixel(capsule.Y))
                    capsule.Object.Size = UDim2.fromOffset(w, h)
                    capsule.Corner.CornerRadius = UDim.new(0, watermarkRadius(style.Shape or wm.Shape,
                        style.Radius or wm.Radius, h))

                    local bg = watermarkColor(style.Background, watermarkColor(wm.Background, palette[2]))
                    local capOpacity = style.Transparency ~= nil
                        and math.clamp(1 - (tonumber(style.Transparency) or 0), 0, 1) or opacity
                    capsule.Object.BackgroundTransparency = 1 - capOpacity * alpha

                    local gradient = style.Gradient
                    if gradient == nil then gradient = wm.Gradient end
                    if gradient and gradient ~= false then
                        local from, to
                        if type(gradient) == "table" then
                            from = watermarkColor(gradient[1], bg)
                            to = watermarkColor(gradient[2], accent)
                        else
                            from = bg
                            to = bg:Lerp(watermarkColor(style.GradientColor or wm.GradientColor, accent), 0.35)
                        end
                        if capsule.GradientFrom ~= from or capsule.GradientTo ~= to then
                            capsule.GradientFrom, capsule.GradientTo = from, to
                            capsule.Gradient.Color = ColorSequence.new(from, to)
                        end
                        capsule.Gradient.Rotation = tonumber(style.GradientRotation or wm.GradientRotation) or 90
                        capsule.Gradient.Enabled = true
                        capsule.Object.BackgroundColor3 = pureWhite
                    else
                        capsule.Gradient.Enabled = false
                        capsule.Object.BackgroundColor3 = bg
                    end

                    local strokeOn = style.Stroke
                    if strokeOn == nil then strokeOn = wm.Stroke ~= false end
                    capsule.Stroke.Enabled = strokeOn and true or false
                    if strokeOn then
                        capsule.Stroke.Color = watermarkColor(style.StrokeColor or wm.StrokeColor, palette[5])
                        capsule.Stroke.Thickness = math.max(0, tonumber(style.StrokeThickness or wm.StrokeThickness) or 1)
                        local st = math.clamp(tonumber(style.StrokeTransparency or wm.StrokeTransparency) or 0.4, 0, 1)
                        capsule.Stroke.Transparency = 1 - (1 - st) * alpha
                    end

                    local lineMode = string.lower(tostring(style.AccentLine or wm.AccentLine or "none"))
                    if lineMode ~= "none" and lineMode ~= "false" and lineMode ~= "" then
                        local thickness = math.max(1, math.floor(tonumber(style.AccentLineThickness
                            or wm.AccentLineThickness) or 2))
                        capsule.Line.Visible = true
                        capsule.Line.BackgroundColor3 = watermarkColor(style.AccentLineColor or wm.AccentLineColor, accent)
                        capsule.Line.BackgroundTransparency = 1 - alpha * state.AccentAlpha
                        if lineMode == "left" then
                            capsule.Line.Position = UDim2.fromOffset(0, 0)
                            capsule.Line.Size = UDim2.fromOffset(thickness, h)
                        elseif lineMode == "right" then
                            capsule.Line.Position = UDim2.fromOffset(w - thickness, 0)
                            capsule.Line.Size = UDim2.fromOffset(thickness, h)
                        elseif lineMode == "top" then
                            capsule.Line.Position = UDim2.fromOffset(0, 0)
                            capsule.Line.Size = UDim2.fromOffset(w, thickness)
                        else
                            capsule.Line.Position = UDim2.fromOffset(0, h - thickness)
                            capsule.Line.Size = UDim2.fromOffset(w, thickness)
                        end
                    else
                        capsule.Line.Visible = false
                    end
                end
            end

            local scaleValue = math.clamp(tonumber(wm.Scale) or 1, 0.25, 4)
            watermarkScale.Scale = scaleValue
            local topLeft = watermarkTopLeft(Vector2.new(totalW * scaleValue, totalH * scaleValue), viewport)
            watermarkRoot.Position = UDim2.fromOffset(roundPixel(topLeft.X), roundPixel(topLeft.Y))
            watermarkRoot.Size = UDim2.fromOffset(roundPixel(totalW), roundPixel(totalH))
            window.WatermarkSize = Vector2.new(totalW, totalH)
        end

        -- Tooltip ----------------------------------------------------------------
        if window.Visible and window.TooltipText and window.TooltipObject
            and window.TooltipObject.Parent then
            local caption = window.TooltipText
            if caption ~= tooltipCaption then
                tooltipCaption = caption
                local bounds = TextService:GetTextSize(caption, 11, UI_FONT, Vector2.new(4000, 20))
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
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                -- Clicking elsewhere cancels the capture and restores the caption.
                pending:Set(pending.Key)
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

        local toggleKey = window.ToggleKey
        if toggleKey ~= false and hit == (toggleKey or Enum.KeyCode.RightShift) then
            window:SetVisible(not window.Visible)
            return
        end
        local scaleKeys = window.ScaleKeys
        if scaleKeys and (hit == scaleKeys.Up or hit == scaleKeys.Down) then
            local sorted = {}
            for _, option in ipairs(Library.ScaleOptions) do sorted[#sorted + 1] = option end
            table.sort(sorted)
            local current = 1
            for i, option in ipairs(sorted) do
                if option == state.Scale then current = i end
            end
            local target = sorted[math.clamp(current + (hit == scaleKeys.Up and 1 or -1), 1, #sorted)]
            window:SetScale(target)
        end
    end)

    if opts.ToggleKey == false then
        window.ToggleKey = false
    else
        window.ToggleKey = keyFromName(opts.ToggleKey) or Enum.KeyCode.RightShift
    end
    -- ScaleKeys = false disables F1/F2; ScaleKeys = {Up = "F1", Down = "F2"} remaps them.
    if opts.ScaleKeys == false then
        window.ScaleKeys = nil
    else
        local keys = type(opts.ScaleKeys) == "table" and opts.ScaleKeys or {}
        window.ScaleKeys = {
            Up = keyFromName(keys.Up) or Enum.KeyCode.F1,
            Down = keyFromName(keys.Down) or Enum.KeyCode.F2,
        }
    end
    Library:SetOpenMode(type(opts.OpenMode) == "table" and opts.OpenMode or {Mode = opts.OpenMode or "button"})
    if opts.Watermark ~= nil then Library:SetWatermark(opts.Watermark) end

    connect(gui.Destroying, function()
        Runtime.Alive = false
    end)

    local fpsTimer, fpsFrames = 0, 0

    local sweepTimer = 0
    connect(RunService.RenderStepped, function(dt)
        if not Runtime.Alive then return end
        restoreFades()
        sweepTimer = sweepTimer + dt
        if sweepTimer >= Runtime.SweepInterval then
            sweepTimer = 0
            sweepConnections()
        end
        dt = math.min(dt, 0.1)
        local now = os.clock()
        local performance = Library.Performance or {}
        local idleRate = window.Visible
            and math.clamp(tonumber(performance.IdleUpdateRate) or 12, 4, 60)
            or math.clamp(tonumber(performance.HiddenUpdateRate) or 6, 2, 30)
        window.UpdateAccumulator = (window.UpdateAccumulator or 0) + dt
        local active = now <= (window.ActiveUntil or 0) or Runtime.ThemeDirty or window.Drag ~= nil
        local runUi = active or window.UpdateAccumulator >= 1 / idleRate
        local uiDt = active and dt or math.min(window.UpdateAccumulator, 0.1)
        if runUi then window.UpdateAccumulator = 0 end
        local k = motionFactor(18, dt)

        if Runtime.ThemeDirty then
            local theme = themes[state.Theme] or themes[1]
            local moving = false
            for i, target in ipairs(theme) do
                local current = palette[i]
                if colorDelta(current, target) > 0.0005 then
                    current = current:Lerp(target, k)
                    if colorDelta(current, target) <= 0.0005 then current = target else moving = true end
                else
                    current = target
                end
                palette[i] = current
            end
            if colorDelta(accent, state.Accent) > 0.0005 then
                accent = accent:Lerp(state.Accent, k)
                if colorDelta(accent, state.Accent) <= 0.0005 then accent = state.Accent else moving = true end
            else
                accent = state.Accent
            end
            white = palette[7] or pureWhite
            for label in pairs(foregroundLabels) do
                if label.Parent then label.TextColor3 = white else foregroundLabels[label] = nil end
            end
            for icon in pairs(foregroundIcons) do
                if icon.Parent then
                    if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
                        icon.ImageColor3 = white
                    else
                        icon.TextColor3 = white
                    end
                else
                    foregroundIcons[icon] = nil
                end
            end
            for stroke, index in pairs(themedStrokes) do
                if stroke.Parent then stroke.Color = palette[index] else themedStrokes[stroke] = nil end
            end
            for object, index in pairs(themedBackgrounds) do
                if object.Parent then object.BackgroundColor3 = palette[index] else themedBackgrounds[object] = nil end
            end
            for label, index in pairs(themedLabels) do
                if label.Parent then label.TextColor3 = palette[index] else themedLabels[label] = nil end
            end
            Runtime.ThemeDirty = moving
        end

        fpsFrames = fpsFrames + 1
        fpsTimer = fpsTimer + dt
        if fpsTimer >= 0.5 then
            window.FPS = math.floor(fpsFrames / fpsTimer + 0.5)
            fpsFrames, fpsTimer = 0, 0
            pcall(function()
                window.Ping = math.floor(
                    StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
            end)
        end

        local camera = workspace.CurrentCamera
        local viewportChanged = camera and camera.ViewportSize ~= window.Viewport
        local scaleChanged = window.StepScale(dt)
        if viewportChanged then window.LayoutMini() end
        if viewportChanged or scaleChanged then
            runUi = true
            uiDt = dt
            window.UpdateAccumulator = 0
        end

        local renderCache = nil
        if runUi then
            renderCache = window.RenderCache
            table.clear(renderCache)
        end
        if runUi then runUpdates(Runtime.Overlay, uiDt, motionFactor(18, uiDt), renderCache) end

        for index = #window.Notifications, 1, -1 do
            local notif = window.Notifications[index]
            if not notif.Sticky then notif.Life = notif.Life - dt end
            local target = (notif.Life > 0) and 1 or 0
            notif.Alpha = fadeAlpha(notif.Alpha, target, dt)
            notif.Y = approach(notif.Y, notif.TargetY, motionFactor(20, dt))
            fadeGroup(notif.Object, notif.Alpha)
            local tint = notif.Color or accent
            notif.Object.BackgroundColor3 = palette[2]
            notif.Bar.BackgroundColor3 = tint
            notif.Icon:Color(tint)
            if notif.Progress then
                notif.Progress.BackgroundColor3 = tint
                notif.Progress.Visible = not notif.Sticky
                notif.Progress.Size = UDim2.fromOffset(
                    roundPixel(250 * math.clamp(notif.Life / math.max(0.01, notif.Duration or 4), 0, 1)), 2)
            end
            notif.Object.Position = UDim2.fromOffset(roundPixel(260 * (1 - notif.Alpha)), roundPixel(notif.Y))
            if notif.Life <= 0 and notif.Alpha <= 0.01 then
                if notif.Maid then notif.Maid:Destroy() else notif.Object:Destroy() end
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
        local mainTransitioning = window.Alpha < 0.999

        if runUi then
            local uiK = motionFactor(18, uiDt)
            runUpdates(Runtime.Updates, uiDt, uiK, renderCache)

            for _, tab in ipairs(window.TabList) do
                local tabActive = window.Current == tab
                tab.Alpha = transitionAlpha(tab.Alpha, tabActive and 1 or 0,
                    uiDt, Library.TabDuration)
                tab.Slide = approach(tab.Slide or 0, tabActive and 0 or (tab.ExitSlide or 0),
                    motionFactor(4.25 / math.max(0.08, Library.TabDuration), uiDt))
                local page = tab.Page
                page.Visible = tab.Alpha > 0.001
                page.Interactable = tabActive and window.Visible
                if page.Visible then
                    page.Position = UDim2.fromOffset(PAD + roundPixel(tab.Slide), PAD)
                    if not mainTransitioning then fadeGroup(page, tab.Alpha) end
                elseif not tabActive then
                    tab.Slide = 0
                    page.Position = UDim2.fromOffset(PAD, PAD)
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
                    pop.Alpha = fadeAlpha(pop.Alpha, show and 1 or 0, uiDt)
                    if pop.AnimateHeight then
                        pop.CurrentHeight = approach(pop.CurrentHeight, show and pop.Height or 1, motionFactor(16, uiDt))
                    else
                        pop.CurrentHeight = pop.Height
                    end
                    object.Visible = pop.Alpha > 0 and pop.Anchor ~= nil
                    object.Interactable = show and window.Visible
                    if object.Visible then
                        fadeGroup(object, pop.Alpha * window.Alpha)
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
        end
        local hiddenAmount = 1 - math.clamp(window.Alpha, 0, 1)
        local revealOffset = roundPixel(hiddenAmount * hiddenAmount * 6 * window.ScaleCurrent)
        local animatedPosition = UDim2.fromOffset(window.Position.X, window.Position.Y + revealOffset)
        frame.Position = animatedPosition
        popupLayer.Position = animatedPosition
        if mainTransitioning then
            if window.MainFadeDirty or not window.MainFadeTargets then
                window.MainFadeTargets = visibleFadeTargets(frame)
                window.MainFadeDirty = false
            end
            fadeTargetList(window.MainFadeTargets, window.Alpha)
        end
    end)

    return window
end

function Window:SetVisible(value)
    self.Visible = value == true
    if self.Wake then self:Wake() end
    self.Frame.Visible = self.Visible or self.Alpha > 0
    self.Frame.Interactable = self.Visible
    self.PopupLayer.Visible = self.Frame.Visible
    self.PopupLayer.Interactable = self.Visible
    self.MainFadeDirty = true
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

function Window:SetWatermarkBlocks(blocks)
    return Library:SetWatermarkBlocks(blocks)
end

function Window:GetWatermarkBlocks()
    return Library:GetWatermarkBlocks()
end

function Window:AddWatermarkBlock(block, index)
    return Library:AddWatermarkBlock(block, index)
end

function Window:SetWatermarkBlock(id, changes)
    return Library:SetWatermarkBlock(id, changes)
end

function Window:RemoveWatermarkBlock(id)
    return Library:RemoveWatermarkBlock(id)
end

function Window:SetOpenMode(options)
    return Library:SetOpenMode(options)
end

function Window:SetScale(value, exact)
    local snapped = exact and (tonumber(value) or state.Scale) or snapScale(value)
    state.Scale = snapped
    Library.Scale = snapped
    self.Layout()
    fireChange("Scale", snapped)
    return snapped
end

function Window:SetIcon(value)
    self.Icon = value
    self.LogoIcon:SetIcon(value)
    self.ReopenIcon:SetIcon(value)
    if self.WatermarkConfig and self.RebuildWatermarkBlocks then
        for _, block in ipairs(self.WatermarkConfig.Blocks) do
            if block.UseWindowIcon == true then block.Icon = value end
        end
        self.RebuildWatermarkBlocks(self.WatermarkConfig.Blocks)
    end
    return value
end

function Library:SetIcon(value)
    if self.Window then return self.Window:SetIcon(value) end
end

function Window:SelectTab(name)
    local tab = type(name) == "table" and name or self.Tabs[name]
    if not tab or self.Current == tab then return end
    local previous = self.Current
    local direction = 1
    if previous and tab.Index and previous.Index and tab.Index < previous.Index then direction = -1 end
    local slide = math.max(0, tonumber(Library.TabSlide) or 10)
    if previous then
        previous.ExitSlide = -direction * slide * 0.55
    else
        tab.Alpha = 1
    end
    tab.Slide = previous and (direction * slide * (1 - math.clamp(tab.Alpha or 0, 0, 1))) or 0
    tab.ExitSlide = 0
    self.Opened = nil
    self.Current = tab
    self.MainFadeDirty = true
    if self.Wake then self:Wake() end
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
        Index = index,
        Alpha = 0,
        Slide = 0,
        ExitSlide = 0,
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
    if opts.Tooltip then self:Tooltip(hit, opts.Tooltip) end

    local hover = false
    connect(hit.MouseEnter, function() hover = true end)
    connect(hit.MouseLeave, function() hover = false end)

    local alpha, hoverAlpha, tint = 0, 0, palette[3]
    step(function(dt, k)
        local active = self.Current == tab
        alpha = approach(alpha, active and 1 or 0, k)
        hoverAlpha = approach(hoverAlpha, (hover and not active) and 1 or 0, k)
        tint = tint:Lerp(active and accent or palette[3]:Lerp(white, hoverAlpha * 0.6), k)
        hit.BackgroundColor3 = palette[4]
        hit.BackgroundTransparency = 1 - math.max(alpha, hoverAlpha * 0.5)
        icon:Color(tint)
        title:Color(tint)
        icon:Alpha(1 - alpha * (1 - state.AccentAlpha))
        title:Alpha(1 - alpha * (1 - state.AccentAlpha))
    end, hit)

    tab.Button = hit
    tab.Icon = icon
    tab.TitleLabel = title
    tab.Maid = Maid.new(Library.Maid)
    tab.Maid:Add(page)
    tab.Maid:Add(hit)
    function tab:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        local window = self.Window
        for i = #self.Elements, 1, -1 do
            local element = self.Elements[i]
            if element and element.Destroy then pcall(element.Destroy, element) end
        end
        self.Elements = {}
        for i, other in ipairs(window.TabList) do
            if other == self then table.remove(window.TabList, i) break end
        end
        window.Tabs[self.Name] = nil
        for i, other in ipairs(window.TabList) do
            other.Index = i
            other.Button.Position = UDim2.fromOffset(0, (i - 1) * TAB_SLOT)
        end
        window.TabHolder.CanvasSize = UDim2.fromOffset(0, #window.TabList * TAB_SLOT)
        if window.Current == self then
            window.Current = nil
            if window.TabList[1] then window:SelectTab(window.TabList[1]) end
        end
        self.Maid:Destroy()
    end
    function tab:SetName(value)
        self.Title = tostring(value)
        title:SetText(self.Title)
    end
    function tab:SetIcon(value)
        icon:SetIcon(value)
    end

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
    local width = math.clamp(math.floor(tonumber(opts.Width) or 210), 150, 300)
    local maxHeight = math.clamp(math.floor(tonumber(opts.MaxHeight) or SUB_MAX_HEIGHT), 120, 260)
    local pop = createPopup(window, anchor, width, 37, false, opts.ParentPopup)
    local holder = new("ScrollingFrame", pop.Object, {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(width, 37),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollingEnabled = false,
        Active = true,
    })
    local inset = 8
    local page = transparent(holder, inset, inset, width - inset * 2 - 4, 1)

    local menu = setmetatable({
        Name = opts.Name or "Settings",
        Title = opts.Name or "Settings",
        Window = window,
        Page = page,
        Width = width - inset * 2 - 4,
        Popup = pop,
        ParentPopup = pop,
        Anchor = anchor,
        Cursor = {X = 0, Y = 0, RowHeight = 0},
        Elements = {},
        Height = 0,
        IsSubMenu = true,
    }, Tab)

    menu.OnResize = function(height)
        local total = math.max(31, height + inset * 2)
        local shown = math.min(maxHeight, total)
        pop.Height = shown
        holder.Size = UDim2.fromOffset(width, shown)
        holder.CanvasSize = UDim2.fromOffset(0, total)
        holder.ScrollingEnabled = total > shown
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
    local caption = string.upper(tostring(opts.Name or "Section"))
    local api = muted(self.Page, caption, x, y, total, 16, 11)
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

    local sv = rect(host, 10, SV_TOP, INNER, SV_H, pureWhite, 4, "TextButton")
    local svGradient = new("UIGradient", sv, {Color = ColorSequence.new(pureWhite, Color3.fromHSV(hue, 1, 1))})
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
    new("UIStroke", svDot, {Color = pureWhite, Thickness = 2})

    local hueBar = rect(host, 10, HUE_TOP, INNER, BAR_H, pureWhite, 4, "TextButton")
    local stops = {}
    for i = 0, 6 do
        stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))
    end
    new("UIGradient", hueBar, {Color = ColorSequence.new(stops)})
    local hueThumb = rect(hueBar, 0, -3, 6, BAR_H + 6, pureWhite, 3)
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
        alphaThumb = rect(alphaBar, 0, -3, 6, BAR_H + 6, pureWhite, 3)
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
            svGradient.Color = ColorSequence.new(pureWhite, Color3.fromHSV(hue, 1, 1))
            lastHue = hue
        end
        local current = Color3.fromHSV(hue, saturation, value)
        dot.BackgroundColor3 = current
        dot.BackgroundTransparency = useAlpha and (1 - alphaValue) or 0
        svDot.BackgroundColor3 = current
        preview.BackgroundColor3 = current
        hexBox.BackgroundColor3 = palette[4]
        hexBox.TextColor3 = white
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

    local hover = false
    connect(hit.MouseEnter, function() hover = true end)
    connect(hit.MouseLeave, function() hover = false end)

    local a, hoverAlpha, tint = value and 1 or 0, 0, palette[3]
    step(function(dt, k)
        a = approach(a, value and 1 or 0, k)
        hoverAlpha = approach(hoverAlpha, hover and 1 or 0, k)
        card.BackgroundColor3 = palette[2]:Lerp(palette[4], hoverAlpha * 0.6)
        box.BackgroundColor3 = palette[1]:Lerp(palette[5], hoverAlpha * 0.5)
        fill.Position = UDim2.fromOffset(roundPixel(7 * (1 - a)), roundPixel(7 * (1 - a)))
        fill.Size = UDim2.fromOffset(roundPixel(14 * a), roundPixel(14 * a))
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - a * state.AccentAlpha
        mark:Alpha(a)
        tint = tint:Lerp(value and white or palette[3]:Lerp(white, hoverAlpha * 0.35), k)
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
    function api:Destroy() card:Destroy() end
    function api:SetRange(newMin, newMax)
        min = tonumber(newMin) or min
        max = tonumber(newMax) or max
        if max < min then min, max = max, min end
        self:Set(value, true)
    end
    bindTitle(api, title, opts)

    local hit = transparent(card, 10, 33, w - 20, 20, "TextButton")
    hit.ZIndex = 3
    local dragging = false
    tab.Window.Draggable(hit, function(point)
        dragging = true
        local ratio = math.clamp(
            (point.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        api:Set(min + (max - min) * ratio)
    end, function(cancelled)
        dragging = false
        if not cancelled and type(opts.OnRelease) == "function" then task.spawn(opts.OnRelease, value) end
    end)
    if opts.Tooltip then tab.Window:Tooltip(hit, opts.Tooltip) end

    local hover = false
    connect(hit.MouseEnter, function() hover = true end)
    connect(hit.MouseLeave, function() hover = false end)

    local a, glow = (value - min) / math.max(1e-6, max - min), 0
    step(function(dt, k)
        local span = math.max(1e-6, max - min)
        a = approach(a, (value - min) / span, k)
        glow = approach(glow, (hover or dragging) and 1 or 0, k)
        fillClip.Size = UDim2.fromOffset(roundPixel((w - 20) * a), 10)
        fill.BackgroundColor3 = accent
        fill.BackgroundTransparency = 1 - state.AccentAlpha
        thumb.Position = UDim2.fromOffset(roundPixel(math.clamp((w - 20) * a, 5, w - 25) - 5), 0)
        thumb.BackgroundColor3 = white:Lerp(accent, glow * 0.35)
        track.BackgroundColor3 = palette[1]:Lerp(palette[4], glow * 0.6)
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
    local enabled = opts.Enabled ~= false
    local emptyText = tostring(opts.EmptyText or "No options available")
    local options = {}
    for _, option in ipairs(opts.Options or {"One", "Two", "Three"}) do
        options[#options + 1] = tostring(option)
    end

    local w = self:_width(opts.Width)
    local hasDescription = opts.Description ~= nil and tostring(opts.Description) ~= ""
    local controlY = hasDescription and 38 or 27
    local card = self:_card(w, controlY + 41, name)
    local title = text(card, name, 10, 10, w - 20, 14, 12, white)
    if hasDescription then
        muted(card, opts.Description, 10, 22, w - 20, 14, 11)
    end

    local controlW = w - 20
    local control = paint(rect(card, 10, controlY, controlW, 31, palette[4], 3, "TextButton"), 4)
    local preview = muted(control, "", 10, 0, controlW - 40, 31, 11)
    local arrow = iconLabel(control, {"chevron-down", "chevrons-down", "arrow-down"},
        controlW - 22, 11.5, 10, palette[3], "v")
    if opts.Tooltip then self.Window:Tooltip(control, opts.Tooltip) end

    local ROW_H = 31

    local maxRows = math.floor(tonumber(opts.MaxRows) or 5)
    if maxRows <= 0 then maxRows = math.max(1, #options) end
    local initialRows = math.max(1, math.min(#options, maxRows))
    local pop = createPopup(self.Window, control, controlW, initialRows * ROW_H, true, self.ParentPopup)
    local controlHover = false
    connect(control.MouseEnter, function() controlHover = true end)
    connect(control.MouseLeave, function() controlHover = false end)
    local controlGlow, arrowSpin = 0, 0
    step(function(dt, k)
        local open = pop:IsActive()
        local available = enabled and #options > 0
        controlGlow = approach(controlGlow, available and (controlHover or open) and 1 or 0, k)
        arrowSpin = approach(arrowSpin, open and 180 or 0, k)
        control.BackgroundColor3 = palette[4]:Lerp(palette[5], controlGlow)
        arrow:Color(palette[3]:Lerp(white, controlGlow * 0.6))
        arrow:Alpha(available and 1 or 0.3)
        arrow.Object.Rotation = arrowSpin
    end, control)
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

    local function optionIndex(value)
        if type(value) == "number" then
            local index = math.floor(value)
            if index >= 1 and index <= #options then return index end
        elseif type(value) == "string" then
            for index, option in ipairs(options) do
                if option == value then return index end
            end
        end
    end

    local function selectionFrom(value)
        local result = {}
        if type(value) ~= "table" then return result end
        for key, item in pairs(value) do
            local index = item == true and optionIndex(key) or optionIndex(item)
            if index then result[index] = true end
        end
        return result
    end

    local selection
    if multiple then
        selection = selectionFrom(opts.Default)
    else
        selection = optionIndex(opts.Default) or 1
    end

    local rows = {}
    local api = baseApi(self, card, flag)
    bindTitle(api, title, opts)

    local function previewText()
        if #options == 0 then return emptyText end
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
        elseif #options > 0 then
            Library.Flags[flag] = selection
        else
            Library.Flags[flag] = nil
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
        local available = enabled and #options > 0
        control.Active = available
        pcall(function() control.Interactable = available end)
        if not available then pop:Close() end

        for index, option in ipairs(options) do
            local firstRow = index == 1
            local lastRow = index == #options
            local row = rect(list, 0, (index - 1) * ROW_H,
                controlW, ROW_H, palette[5], (firstRow or lastRow) and 5 or nil, "TextButton")
            row.BackgroundTransparency = 1
            local edgeFill
            if firstRow ~= lastRow then
                edgeFill = rect(row, 0, firstRow and 5 or 0, controlW,
                    ROW_H - 5, palette[5])
                edgeFill.BackgroundTransparency = 1
            end
            local mark = iconLabel(row, {"check"}, 0, 9.5, 12, accent, "v")
            local title = text(row, option, 10, 0, controlW - 20, ROW_H, 11, palette[3])
            local entry = {Object = row, Fill = edgeFill, Mark = mark, Title = title,
                Alpha = 0, Hover = 0, Hovered = false, Index = index}
            rows[#rows + 1] = entry
            connect(row.MouseEnter, function() entry.Hovered = true end)
            connect(row.MouseLeave, function() entry.Hovered = false end)

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
            entry.Hover = approach(entry.Hover, entry.Hovered and 1 or 0, k)
            local shade = math.max(entry.Alpha, entry.Hover * 0.5)
            entry.Object.BackgroundColor3 = palette[5]
            entry.Object.BackgroundTransparency = 1 - shade
            if entry.Fill then
                entry.Fill.BackgroundColor3 = palette[5]
                entry.Fill.BackgroundTransparency = 1 - shade
            end
            entry.Title.Object.Position = UDim2.fromOffset(roundPixel(10 + 20 * entry.Alpha), 0)
            entry.Title:Color(palette[3]:Lerp(white, math.max(entry.Alpha, entry.Hover * 0.6)))
            entry.Mark.Object.Position = UDim2.fromOffset(roundPixel(10 * entry.Alpha), 10)
            entry.Mark:Color(accent)
            entry.Mark:Alpha(entry.Alpha * state.AccentAlpha)
        end
    end, pop.Object)

    connect(control.Activated, function()
        if enabled and #options > 0 then pop:Toggle(control) end
    end)

    function api:Get() return selectedValue() end
    function api:Set(value, silent)
        if multiple then
            selection = selectionFrom(value)
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
        local previousNames = {}
        if multiple then
            for index, option in ipairs(options) do
                if selection[index] then previousNames[option] = true end
            end
        else
            local previous = options[selection]
            if previous then previousNames[previous] = true end
        end
        options = {}
        for _, option in ipairs(list_ or {}) do options[#options + 1] = tostring(option) end
        if multiple then
            selection = {}
            for index, option in ipairs(options) do
                if previousNames[option] then selection[index] = true end
            end
        else
            selection = 1
            for index, option in ipairs(options) do
                if previousNames[option] then selection = index break end
            end
        end
        buildRows()
        push(false)
    end
    function api:GetOptions() return options end
    function api:SetEnabled(value)
        enabled = value ~= false
        buildRows()
        return enabled
    end
    function api:GetEnabled() return enabled end
    function api:HasOptions() return #options > 0 end

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
        box.TextColor3 = white
    end, box)

    local maxLength = math.max(0, math.floor(tonumber(opts.MaxLength) or 0))
    local api = baseApi(self, card, flag)
    local suppress = false
    local numeric = opts.Numeric == true

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
        if numeric then
            local cleaned = string.gsub(box.Text, "[^%d%.%-]", "")
            if cleaned ~= box.Text then
                box.Text = cleaned
                return
            end
        end
        if suppress then return end
        push(true)
    end)

    connect(box.FocusLost, function(enterPressed)
        if enterPressed and opts.OnEnter then task.spawn(opts.OnEnter, box.Text) end
        if opts.OnFocusLost then task.spawn(opts.OnFocusLost, box.Text, enterPressed) end
    end)

    local focused = false
    connect(box.Focused, function() focused = true end)
    connect(box.FocusLost, function() focused = false end)
    local focusGlow = 0
    step(function(dt, k)
        focusGlow = approach(focusGlow, focused and 1 or 0, k)
        card.BackgroundColor3 = palette[2]:Lerp(palette[4], focusGlow * 0.7)
    end, card)

    function api:Get()
        return box.Text
    end

    function api:Set(value, silent)
        local previous = box.Text
        suppress = silent == true
        box.Text = tostring(value == nil and "" or value)
        suppress = false
        if silent then
            Library.Flags[flag] = box.Text
        elseif box.Text == previous then
            -- Text did not change so the signal did not fire; still notify.
            push(true)
        end
    end
    function api:Focus() box:CaptureFocus() end

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
    local enabled = opts.Enabled ~= false
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
    local captionText = tostring(opts.Text or name)
    local caption = text(control, captionText, 0, 0, controlW, 31, 11, white, "center")
    local icon
    if opts.Icon then
        -- Icon sits just left of the centred caption and follows the caption width.
        icon = iconLabel(control, opts.Icon, 10, 10, 11, white, "*")
        local function placeIcon()
            local bounds = TextService:GetTextSize(caption.Object.Text, 11, caption.Object.Font, Vector2.new(4000, 31))
            local total = 11 + 6 + bounds.X
            local startX = math.max(10, math.floor((controlW - total) / 2))
            icon.Object.Position = UDim2.fromOffset(startX, 10)
            caption.Object.Position = UDim2.fromOffset(startX + 17, 0)
            caption.Object.Size = UDim2.fromOffset(math.max(10, controlW - startX - 17 - 10), 31)
            caption.Object.TextXAlignment = Enum.TextXAlignment.Left
        end
        placeIcon()
        connect(caption.Object:GetPropertyChangedSignal("Text"), placeIcon)
    end

    local flash, color, hover = 0, palette[4], false
    local api = baseApi(self, card, nil)
    function api:SetText(value) caption:SetText(value) end
    function api:SetIcon(value)
        if icon then icon:SetIcon(value) end
    end
    if title then bindTitle(api, title, opts) end
    function api:SetEnabled(value)
        enabled = value ~= false
        control.Active = enabled
        pcall(function() control.Interactable = enabled end)
        if not enabled then hover = false end
        return enabled
    end
    function api:GetEnabled() return enabled end

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

    connect(control.MouseEnter, function() hover = enabled end)
    connect(control.MouseLeave, function() hover = false end)
    connect(control.Activated, function()
        if not enabled then return end
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
        caption:Alpha(enabled and 1 or 0.38)
        if icon then icon:Alpha(enabled and 1 or 0.38) end
    end, control)
    api:SetEnabled(enabled)
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
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        Active = true,
        ZIndex = 2,
    })
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
            box.TextColor3 = white
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
    if not Library.Configs or not Library.Configs.Enabled then return nil, "configs are disabled" end
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
        EmptyText = opts.EmptyText or "No saved configs",
        Width = 0.5,
    })
    Library.NoSaveFlags[pickerFlag] = true
    Library.NoSaveFlags[pickerFlag .. ".Text"] = true

    local loadButton, deleteButton
    local function refresh()
        picker:SetOptions(Library:ListConfigs())
        local available = picker:HasOptions()
        if loadButton then loadButton:SetEnabled(available) end
        if deleteButton then deleteButton:SetEnabled(available) end
        return available
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
    loadButton = self:AddButton({
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
    deleteButton = self:AddButton({
        Name = "Delete config",
        Text = "Delete",
        Compact = true,
        Width = 0.33,
        Callback = function()
            local name = chosen()
            Library:Dialog({
                Title = "Delete config?",
                Text = "This will permanently delete the " .. tostring(name) .. " config.",
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

    refresh()

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
    local bounds = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(width - 46, 10000))
    local height = (title and 26 or 10) + math.max(14, bounds.Y) + 10

    local NOTIFY_TYPES = {
        info = {Icon = {"info", "bell", "circle"}, Color = nil},
        success = {Icon = {"check-circle", "circle-check", "check"}, Color = Color3.fromRGB(110, 220, 140)},
        warning = {Icon = {"alert-triangle", "triangle-alert", "alert-circle"}, Color = Color3.fromRGB(240, 200, 90)},
        error = {Icon = {"x-circle", "circle-x", "alert-octagon"}, Color = Color3.fromRGB(240, 100, 100)},
    }
    local kind = NOTIFY_TYPES[string.lower(tostring(opts.Type or "info"))] or NOTIFY_TYPES.info
    local color = typeof(opts.Color) == "Color3" and opts.Color or kind.Color

    local object = rect(window.NotifyHolder, 260, 0, width, height, palette[2], 5, "TextButton")
    object.Name = "Notification"
    object.ClipsDescendants = true
    new("UIStroke", object, {Color = palette[5], Thickness = 1, Transparency = 0.5})

    local bar = rect(object, 0, 0, 2, height, accent, nil)
    local progress = rect(object, 0, height - 2, width, 2, accent, nil)
    progress.BackgroundTransparency = 0.35
    local icon = iconLabel(object, opts.Icon or kind.Icon, 12, 10, 14, accent, "!")
    if title then
        text(object, title, 34, 8, width - 46, 14, 12, white)
    end
    muted(object, body, 34, title and 26 or 10, width - 46, math.max(14, bounds.Y), 11, nil, {Wrap = true})

    local targetY = 0
    for _, existing in ipairs(window.Notifications) do
        targetY = targetY + existing.Height + 8
    end

    local duration = math.max(0.5, tonumber(opts.Duration) or 4)
    local notif = {
        Object = object,
        Bar = bar,
        Progress = progress,
        Icon = icon,
        Color = color,
        Height = height,
        Alpha = 0,
        Y = targetY,
        TargetY = targetY,
        Life = duration,
        Duration = duration,
        Sticky = opts.Sticky == true,
    }
    function notif:Close() self.Life = 0; self.Sticky = false end
    function notif:SetText(value)
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("TextLabel") and child.TextWrapped then child.Text = tostring(value) end
        end
    end
    notif.Maid = Maid.new(Library.Maid)
    notif.Maid:Add(object)
    notif.Maid:Connect(object.Activated, function()
        if opts.Callback then task.spawn(opts.Callback) end
        if opts.CloseOnClick ~= false then notif:Close() end
    end)
    function notif:Destroy()
        self.Life = 0
        self.Sticky = false
        self.Maid:Destroy()
    end
    window.Notifications[#window.Notifications + 1] = notif
    return notif
end

local function watermarkBlockIndex(window, id)
    if not window or not window.WatermarkConfig then return nil end
    if type(id) == "number" then
        local index = math.floor(id)
        if window.WatermarkConfig.Blocks[index] then return index end
        return nil
    end
    local target = tostring(id or "")
    for index, block in ipairs(window.WatermarkConfig.Blocks) do
        if block.Id == target then return index end
    end
end

function Library:GetWatermarkBlocks()
    local window = self.Window
    return window and window.WatermarkConfig and window.WatermarkConfig.Blocks or {}
end

function Library:SetWatermarkBlocks(blocks)
    local window = self.Window
    if not window or type(blocks) ~= "table" then return nil end
    window.RebuildWatermarkBlocks(blocks)
    return window.WatermarkConfig.Blocks
end

function Library:AddWatermarkBlock(block, index)
    local window = self.Window
    if not window or type(block) ~= "table" then return nil end
    local blocks = window.WatermarkConfig.Blocks
    local position = math.clamp(math.floor(tonumber(index) or (#blocks + 1)), 1, #blocks + 1)
    table.insert(blocks, position, block)
    window.RebuildWatermarkBlocks(blocks)
    return window.WatermarkConfig.Blocks[position]
end

function Library:SetWatermarkBlock(id, changes)
    local window = self.Window
    local index = watermarkBlockIndex(window, id)
    if not index or type(changes) ~= "table" then return nil end
    local block = window.WatermarkConfig.Blocks[index]
    for key, value in pairs(changes) do block[key] = value end
    window.RebuildWatermarkBlocks(window.WatermarkConfig.Blocks)
    return window.WatermarkConfig.Blocks[index]
end

function Library:RemoveWatermarkBlock(id)
    local window = self.Window
    local index = watermarkBlockIndex(window, id)
    if not index then return false end
    table.remove(window.WatermarkConfig.Blocks, index)
    window.RebuildWatermarkBlocks(window.WatermarkConfig.Blocks)
    return true
end

-- Every option SetWatermark understands, with the type it expects.
-- "color" accepts Color3, "#RRGGBB" or keywords (accent, text, muted, good, warn, bad, ...).
local WATERMARK_SCHEMA = {
    Height = "number", Padding = "number", Gap = "number", MinimumWidth = "number",
    TextSize = "number", IconSize = "number", StrokeThickness = "number",
    Scale = "number", FadeDuration = "number",
    StrokeTransparency = "number",
    Toggle = "boolean", AlwaysVisible = "boolean", Draggable = "boolean", Stroke = "boolean",
    Bold = "boolean", Uppercase = "boolean", Dynamic = "boolean",
    Anchor = "string",
    Background = "color", StrokeColor = "color", TextColor = "color", IconColor = "color",
    GoodColor = "color", WarnColor = "color", BadColor = "color",
    Font = "font", OnClick = "function", OnMove = "function",
}

local function applyWatermarkOptions(window, config, opts)
    for key, kind in pairs(WATERMARK_SCHEMA) do
        local value = opts[key]
        if value ~= nil then
            if kind == "number" then
                config[key] = tonumber(value) or config[key]
            elseif kind == "boolean" then
                config[key] = value and true or false
            elseif kind == "string" then
                config[key] = tostring(value)
            elseif kind == "color" then
                if value == false then
                    config[key] = nil
                elseif typeof(value) == "Color3" or type(value) == "string" then
                    config[key] = value
                end
            elseif kind == "font" then
                if value == false then
                    config[key] = nil
                elseif typeof(value) == "EnumItem" then
                    config[key] = value
                end
            elseif kind == "function" then
                config[key] = type(value) == "function" and value or nil
            else
                config[key] = value
            end
        end
    end
    if opts.Transparency ~= nil then
        config.Transparency = math.clamp(tonumber(opts.Transparency) or 0, 0, 1)
    end
    if typeof(opts.Position) == "Vector2" then config.Position = opts.Position end
    if opts.X ~= nil or opts.Y ~= nil then
        config.Position = Vector2.new(tonumber(opts.X) or config.Position.X, tonumber(opts.Y) or config.Position.Y)
    end
end

function Library:SetWatermark(opts)
    local window = self.Window
    if not window then return end
    opts = type(opts) == "table" and opts or {Text = opts, Enabled = true}
    local config = window.WatermarkConfig

    applyWatermarkOptions(window, config, opts)
    config.Layout = "solid"
    config.Direction = "horizontal"
    config.Shape = "capsule"
    config.Radius = 6
    config.Spacing = 0
    config.Gradient = false
    config.GradientColor = nil
    config.AccentLine = "none"
    config.Separator = "none"

    if type(opts.Blocks) == "table" then self:SetWatermarkBlocks(opts.Blocks) end

    local function setVisible(id, value)
        local index = watermarkBlockIndex(window, id)
        if index then config.Blocks[index].Visible = value and true or false end
    end
    local function setIconVisible(id, value)
        local index = watermarkBlockIndex(window, id)
        if index then config.Blocks[index].IconVisible = value and true or false end
    end
    if opts.Text ~= nil then
        local textValue = tostring(opts.Text)
        local index = watermarkBlockIndex(window, "text")
        if index then
            config.Blocks[index].Text = textValue
            config.Blocks[index].Visible = textValue ~= ""
        elseif textValue ~= "" then
            local brand = watermarkBlockIndex(window, "brand")
            table.insert(config.Blocks, (brand or 0) + 1, {Id = "text", Type = "Text", Text = textValue})
        end
    end
    if opts.ShowIcon ~= nil then setVisible("brand", opts.ShowIcon) end
    if opts.ShowFPS ~= nil then setVisible("fps", opts.ShowFPS) end
    if opts.ShowPing ~= nil then setVisible("ping", opts.ShowPing) end
    if opts.ShowTime ~= nil then setVisible("time", opts.ShowTime) end
    if opts.ShowStatIcons ~= nil then
        setIconVisible("fps", opts.ShowStatIcons)
        setIconVisible("ping", opts.ShowStatIcons)
        setIconVisible("time", opts.ShowStatIcons)
    end
    if opts.ShowFPSIcon ~= nil then setIconVisible("fps", opts.ShowFPSIcon) end
    if opts.ShowPingIcon ~= nil then setIconVisible("ping", opts.ShowPingIcon) end
    if opts.ShowTimeIcon ~= nil then setIconVisible("time", opts.ShowTimeIcon) end

    window.RebuildWatermarkBlocks(config.Blocks)
    if opts.Enabled ~= nil then
        config.Enabled = opts.Enabled and true or false
    elseif not config.Enabled then
        config.Enabled = true
    end
    window.UpdateOpenVisibility()
    return config
end

function Library:GetWatermark()
    local window = self.Window
    return window and window.WatermarkConfig or nil
end

function Library:SetWatermarkEnabled(value)
    local window = self.Window
    if not window then return end
    window.WatermarkConfig.Enabled = value and true or false
    window.UpdateOpenVisibility()
    return window.WatermarkConfig.Enabled
end

function Library:ToggleWatermark()
    local window = self.Window
    if not window then return end
    return self:SetWatermarkEnabled(not window.WatermarkConfig.Enabled)
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
        if mode == "watermark" then
            window.WatermarkConfig.Enabled = true
            window.WatermarkConfig.Toggle = true
            window.WatermarkConfig.AlwaysVisible = true
        end
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
    if opts.AlwaysVisible ~= nil then config.AlwaysVisible = opts.AlwaysVisible and true or false end
    if opts.AnimationDuration ~= nil then
        config.AnimationDuration = math.clamp(tonumber(opts.AnimationDuration) or Library.FadeDuration, 0.08, 1)
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
    local config = {__version = self.Version, Flags = {}, Scale = state.Scale}
    for flag, value in pairs(self.Flags) do
        if not self.NoSaveFlags[flag] and not INTERNAL_FLAGS[flag] then
            config.Flags[flag] = serialize(value)
        end
    end
    config.FadeDuration = self.FadeDuration
    config.ScaleDuration = self.ScaleDuration
    config.Accent = serialize(state.Accent)
    config.AccentAlpha = state.AccentAlpha
    if self.Window then
        local wm = self.Window.WatermarkConfig
        config.Watermark = {}
        for key, value in pairs(wm) do
            local kind = typeof(value)
            if kind == "number" or kind == "string" or kind == "boolean" or kind == "Color3" then
                config.Watermark[key] = serialize(value)
            elseif kind == "Vector2" then
                config.Watermark[key] = {__type = "Vector2", X = value.X, Y = value.Y}
            end
        end
        config.OpenMode = {
            Mode = self.Window.OpenConfig.Mode,
            X = self.Window.OpenConfig.Position.X, Y = self.Window.OpenConfig.Position.Y,
        }
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
    if config.FadeDuration ~= nil then self:SetFadeDuration(config.FadeDuration) end
    if config.ScaleDuration ~= nil then self:SetScaleDuration(config.ScaleDuration) end
    if type(config.Watermark) == "table" and self.Window then
        local opts = {}
        for key, value in pairs(config.Watermark) do
            if type(value) == "table" and value.__type == "Vector2" then
                opts[key] = Vector2.new(tonumber(value.X) or 0, tonumber(value.Y) or 0)
            else
                opts[key] = deserialize(value)
            end
        end
        opts.Blocks = nil
        pcall(function() self:SetWatermark(opts) end)
    end
    if type(config.OpenMode) == "table" and self.Window then
        pcall(function() self:SetOpenMode(config.OpenMode) end)
    end
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
    if config.Scale and self.Window then self.Window:SetScale(config.Scale, true) end
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
local JSON_EXTENSION = ".json"
local SECURE_EXTENSION = ".wcfg"
local CONFIG_HEADER = "WCFG2:"
local CONFIG_KEY = "1"
local scriptFolder = "Default"

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Encode(value)
    return ((string.gsub(value, ".", function(character)
        local byte = string.byte(character)
        local bits = ""
        for index = 8, 1, -1 do
            bits = bits .. (byte % 2 ^ index - byte % 2 ^ (index - 1) > 0 and "1" or "0")
        end
        return bits
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
        if #bits < 6 then return "" end
        local valueAt = 0
        for index = 1, 6 do
            if string.sub(bits, index, index) == "1" then valueAt = valueAt + 2 ^ (6 - index) end
        end
        return string.sub(BASE64_ALPHABET, valueAt + 1, valueAt + 1)
    end) .. ({"", "==", "="})[#value % 3 + 1])
end

local function base64Decode(value)
    value = string.gsub(value, "[^" .. BASE64_ALPHABET .. "=]", "")
    return (string.gsub(value, ".", function(character)
        if character == "=" then return "" end
        local position = string.find(BASE64_ALPHABET, character, 1, true)
        if not position then return "" end
        local number = position - 1
        local bits = ""
        for index = 6, 1, -1 do
            bits = bits .. (number % 2 ^ index - number % 2 ^ (index - 1) > 0 and "1" or "0")
        end
        return bits
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
        if #bits ~= 8 then return "" end
        local number = 0
        for index = 1, 8 do
            if string.sub(bits, index, index) == "1" then number = number + 2 ^ (8 - index) end
        end
        return string.char(number)
    end))
end

local function xorByte(left, right)
    if bit32 and bit32.bxor then return bit32.bxor(left, right) end
    local result, place = 0, 1
    while left > 0 or right > 0 do
        local a, b = left % 2, right % 2
        if a ~= b then result = result + place end
        left, right, place = math.floor(left / 2), math.floor(right / 2), place * 2
    end
    return result
end

local function rotateLeft(byte, amount)
    amount = amount % 8
    if amount == 0 then return byte end
    return (byte * 2 ^ amount) % 256 + math.floor(byte / 2 ^ (8 - amount))
end

local function rotateRight(byte, amount)
    amount = amount % 8
    if amount == 0 then return byte end
    return math.floor(byte / 2 ^ amount) + (byte % 2 ^ amount) * 2 ^ (8 - amount)
end

local function configHash(value)
    local hash = 5381
    for index = 1, #value do hash = (hash * 33 + string.byte(value, index)) % 2147483647 end
    return string.format("%08x", hash)
end

local function configSeed(value)
    local seed = 97
    for index = 1, #value do seed = (seed * 131 + string.byte(value, index)) % 65521 end
    return seed
end

local function configSalt()
    local ok, guid = pcall(function() return HttpService:GenerateGUID(false) end)
    local value = ok and tostring(guid) or tostring(os.clock()) .. tostring(math.random())
    value = string.gsub(value, "[^%w]", "")
    return string.sub(value .. "0000000000000000", 1, 16)
end

local function transformConfig(value, key, salt, decode)
    local seed = configSeed(key .. salt)
    local output = table.create(#value)
    for index = 1, #value do
        local keyByte = string.byte(key, (index - 1) % #key + 1)
        seed = (seed * 73 + keyByte + index * 19) % 65521
        local shift = (seed + index) % 8
        local byte = string.byte(value, index)
        if decode then
            byte = xorByte(rotateRight(byte, shift), (keyByte + seed + index * 29) % 256)
        else
            byte = rotateLeft(xorByte(byte, (keyByte + seed + index * 29) % 256), shift)
        end
        output[index] = string.char(byte)
    end
    return table.concat(output)
end

local function encodeConfig(value, key)
    key = tostring(key or CONFIG_KEY)
    if key == "" then key = CONFIG_KEY end
    local salt = configSalt()
    local payload = configHash(value) .. "\0" .. value
    local mixed = string.reverse(transformConfig(payload, key, salt, false))
    return CONFIG_HEADER .. base64Encode(string.reverse(base64Encode(salt .. mixed)))
end

local function decodeConfig(value, key)
    if string.sub(value, 1, #CONFIG_HEADER) ~= CONFIG_HEADER then return value end
    key = tostring(key or CONFIG_KEY)
    if key == "" then key = CONFIG_KEY end
    local packed = base64Decode(string.sub(value, #CONFIG_HEADER + 1))
    packed = base64Decode(string.reverse(packed))
    if #packed < 17 then error("invalid encrypted config", 0) end
    local salt = string.sub(packed, 1, 16)
    local mixed = string.reverse(string.sub(packed, 17))
    local payload = transformConfig(mixed, key, salt, true)
    local separator = string.find(payload, "\0", 1, true)
    if not separator then error("invalid config key or damaged config", 0) end
    local checksum = string.sub(payload, 1, separator - 1)
    local json = string.sub(payload, separator + 1)
    if checksum ~= configHash(json) then error("invalid config key or damaged config", 0) end
    return json
end

local function configExtension()
    return Library.Configs and Library.Configs.Encrypted and SECURE_EXTENSION or JSON_EXTENSION
end

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
                local destination = target .. "/" .. safeName(name) .. JSON_EXTENSION
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
    if self.Configs and self.Configs.Enabled and ensureFolder(self.ConfigFolder) then
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

function Library:SetConfigOptions(options)
    if options == true then options = {Enabled = true} end
    if type(options) ~= "table" then options = {Enabled = false} end
    self.Configs = {
        Enabled = options.Enabled ~= false,
        Encrypted = options.Encrypted == true or options.Encryption == true,
        Key = tostring(options.Key or CONFIG_KEY),
    }
    if self.Configs.Enabled then self:SetScriptName(self.ScriptName or scriptFolder) end
    return self.Configs
end

function Library:GetConfigOptions()
    return self.Configs
end

function Library:SaveConfigFile(name)
    if not self.Configs or not self.Configs.Enabled then return false, "configs are disabled" end
    if not fileSupport() then return false, "executor has no file API" end
    local folder = self:GetConfigFolder()
    local base = safeName(name or "default")
    local ok, result = pcall(function()
        if not ensureFolder(folder) then error("cannot create config folder", 0) end
        local json = HttpService:JSONEncode(self:GetConfig())
        local extension = configExtension()
        local content = self.Configs.Encrypted and encodeConfig(json, self.Configs.Key) or json
        writefile(folder .. "/" .. base .. extension, content)
        return folder .. "/" .. base .. extension
    end)
    return ok, result
end

function Library:LoadConfigFile(name)
    if not self.Configs or not self.Configs.Enabled then return false, "configs are disabled" end
    if not fileSupport() then return false, "executor has no file API" end
    local folder = self:GetConfigFolder()
    local base = safeName(name or "default")
    local ok, decoded = pcall(function()
        local preferred = configExtension()
        local alternate = preferred == SECURE_EXTENSION and JSON_EXTENSION or SECURE_EXTENSION
        local paths = {
            folder .. "/" .. base .. preferred,
            folder .. "/" .. base .. alternate,
            LEGACY_ROOT .. "/" .. base .. JSON_EXTENSION,
        }
        local source
        for _, path in ipairs(paths) do
            if pathExists(path) then source = path; break end
        end
        if not source then error("config not found: " .. base, 0) end
        local json = decodeConfig(readfile(source), self.Configs.Key)
        return HttpService:JSONDecode(json)
    end)
    if not ok then return false, decoded end
    local applied, loaded, loadError = pcall(self.LoadConfig, self, decoded)
    if not applied then return false, loaded end
    return loaded, loadError
end

function Library:ListConfigs()
    local names = {}
    local seen = {}
    if not self.Configs or not self.Configs.Enabled then return names end
    if type(listfiles) ~= "function" then return names end

    local function collect(folder)
        pcall(function()
            for _, path in ipairs(listfiles(folder)) do
                local name = string.match(path, "([^/\\]+)%.json$")
                    or string.match(path, "([^/\\]+)%.wcfg$")
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
    if not self.Configs or not self.Configs.Enabled then return false, "configs are disabled" end
    if type(delfile) ~= "function" then return false, "executor has no delfile" end
    local base = safeName(name or "default")
    local paths = {
        self:GetConfigFolder() .. "/" .. base .. JSON_EXTENSION,
        self:GetConfigFolder() .. "/" .. base .. SECURE_EXTENSION,
        LEGACY_ROOT .. "/" .. base .. JSON_EXTENSION,
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
    if self.Window then
        for _, tab in ipairs(self.Window.TabList or {}) do
            for _, element in ipairs(tab.Elements or {}) do
                if element.Maid then pcall(element.Maid.Destroy, element.Maid) end
            end
        end
        for _, popup in ipairs(self.Window.Popups or {}) do
            if popup.Maid then pcall(popup.Maid.Destroy, popup.Maid) end
        end
        for _, notif in ipairs(self.Window.Notifications or {}) do
            if notif.Maid then pcall(notif.Maid.Destroy, notif.Maid) end
        end
    end
    if self.Maid then pcall(self.Maid.Destroy, self.Maid) end
    for maid in pairs(liveMaids) do pcall(maid.Destroy, maid) end
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    Runtime.Connections, Runtime.Updates, Runtime.Overlay, Runtime.Owner = {}, {}, {}, nil
    for object in pairs(fadeValues) do fadeValues[object] = nil end
    for object in pairs(themedStrokes) do themedStrokes[object] = nil end
    for object in pairs(foregroundLabels) do foregroundLabels[object] = nil end
    for object in pairs(foregroundIcons) do foregroundIcons[object] = nil end
    if self.Window and self.Window.Gui then
        pcall(function() self.Window.Gui:Destroy() end)
    end
    if self.Window and self.Window.Events then
        pcall(function() self.Window.Events:Destroy() end)
    end
    self.Window = nil
    self.Elements = {}
    self.NoSaveFlags = {}
    self.Flags = {}
    for object in pairs(fadeCaches) do fadeCaches[object] = nil end
    for _, listener in ipairs(unloadListeners) do
        pcall(listener)
    end
    unloadListeners = {}
    changeListeners = {}
end

-- ============================================================================
-- Element ownership: every Tab:Add* call runs inside its own Maid, so all
-- connections, update steps and popups created for the element are released
-- by element:Destroy(). Also unregisters the element from Library.Elements.
-- ============================================================================
local function ownElement(tab, api, maid)
    if type(api) ~= "table" then return api end -- section/divider: maid stays owned by the tab
    api.Maid = maid
    if api.Object then maid:Add(api.Object) end
    local original = api.Destroy
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self.Flag and Library.Elements[self.Flag] == self then Library.Elements[self.Flag] = nil end
        if tab and tab.Elements then
            for i, other in ipairs(tab.Elements) do
                if other == self then table.remove(tab.Elements, i) break end
            end
        end
        maid:Destroy()
        if original then pcall(original, self) end
    end
    function api:GetMaid() return maid end
    return api
end

for name, fn in pairs(Tab) do
    if type(fn) == "function" and string.sub(name, 1, 3) == "Add"
        and name ~= "AddElements" and name ~= "AddSelect" and name ~= "AddColor" and name ~= "AddInput" then
        Tab[name] = function(self, ...)
            local maid = Maid.new(self.Maid or Library.Maid)
            local ok, result = pcall(withOwner, maid, fn, self, ...)
            if not ok then
                maid:Destroy()
                error(result, 0)
            end
            return ownElement(self, result, maid)
        end
    end
end

Library.Maid = nil
Library.MaidClass = Maid
Library.NewMaid = Maid.new

function Library:SetMemoryOptions(opts)
    opts = opts or {}
    if opts.SweepInterval ~= nil then Runtime.SweepInterval = math.max(0.25, tonumber(opts.SweepInterval) or 3) end
end

-- Force a sweep + Lua GC step. Returns a stats snapshot.
function Library:Collect(full)
    local dropped = sweepConnections(true)
    if full then collectgarbage("collect") else collectgarbage("step") end
    local stats = self:GetMemoryStats()
    stats.Dropped = dropped
    return stats
end

function Library:GetMemoryStats()
    local window = self.Window
    local live = 0
    for _ in pairs(liveMaids) do live = live + 1 end
    local elements = 0
    for _ in pairs(self.Elements or {}) do elements = elements + 1 end
    local instances = 0
    if window and window.Gui and window.Gui.Parent then instances = #window.Gui:GetDescendants() end
    local fadeCount = 0
    for _ in pairs(fadeCaches) do fadeCount = fadeCount + 1 end
    return {
        LuaKB = collectgarbage("count"),
        Connections = #Runtime.Connections,
        ConnectionsTotal = Runtime.Stats.Connections,
        ConnectionsSwept = Runtime.Stats.Disconnected,
        Updates = #Runtime.Updates,
        OverlayUpdates = #Runtime.Overlay,
        Maids = live,
        MaidsDestroyed = Runtime.Stats.MaidsDestroyed,
        Elements = elements,
        Popups = window and #window.Popups or 0,
        Notifications = window and #window.Notifications or 0,
        Instances = instances,
        FadeCaches = fadeCount,
        Sweeps = Runtime.Stats.Sweeps,
    }
end

function Library:MemoryReport()
    local s = self:GetMemoryStats()
    return string.format(
        "WolfUi memory: %.0f KB lua | %d instances | %d elements | %d conns (%d total, %d swept) | %d updates | %d maids (%d freed) | %d popups | %d notifs",
        s.LuaKB, s.Instances, s.Elements, s.Connections, s.ConnectionsTotal, s.ConnectionsSwept,
        s.Updates + s.OverlayUpdates, s.Maids, s.MaidsDestroyed, s.Popups, s.Notifications)
end

Library.Runtime = Runtime
Library.Palette = palette
Library.Icons = IconSheet

-- Standalone BuilderIcons helper (same API as the module you can require on its own).
-- Use icon values "builder:name" / {BuilderIcon = "name"} anywhere the library accepts
-- an Icon, or call these directly to place a BuilderIcons glyph yourself.
Library.BuilderIcons = {
    Regular = BuilderIconsFont.Regular,
    Bold = BuilderIconsFont.Bold,
}
function Library.BuilderIcons:GetFont(bold)
    return bold and self.Bold or self.Regular
end
function Library.BuilderIcons:Create(parent, iconName, bold, size, color)
    local label = Instance.new("TextLabel")
    label.Name = "Icon_" .. iconName
    label.FontFace = self:GetFont(bold)
    label.Text = iconName
    label.TextSize = size or 18
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromOffset((size or 18) + 2, (size or 18) + 2)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end
function Library.BuilderIcons:Set(label, iconName, bold)
    label.Text = iconName
    label.FontFace = self:GetFont(bold)
end

return Library
