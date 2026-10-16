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
    local ICON_URL = "https://raw.githubusercontent.com/AWLOID/Obscura/refs/heads/main/icons.lua"
    local ICON_FOLDER = "WolfUi"
    local ICON_CACHE = ICON_FOLDER .. "/icons.lua"
    local canFile = type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function"

    local function evaluate(code)
        local ok, result = pcall(function() return loadstring(code)() end)
        if ok and type(result) == "table" then return result end
        return nil
    end

    if canFile then
        local okRead, cached = pcall(function()
            if isfile(ICON_CACHE) then return readfile(ICON_CACHE) end
            return nil
        end)
        if okRead and type(cached) == "string" and #cached > 0 then
            Icons = evaluate(cached)
        end
    end

    if not Icons then
        local okGet, fetched = pcall(function() return game:HttpGet(ICON_URL) end)
        if okGet and type(fetched) == "string" then
            Icons = evaluate(fetched)
            if Icons and canFile then
                pcall(function()
                    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(ICON_FOLDER) then
                        makefolder(ICON_FOLDER)
                    end
                    writefile(ICON_CACHE, fetched)
                end)
            end
        end
    end

    Icons = Icons or {}
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

function Runtime.Env()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then return env end
    end
    return _G
end

Runtime.Owners = setmetatable({}, {__mode = "k"})
Runtime.FadePool = {}
Runtime.Disabled = setmetatable({}, {__mode = "k"})

function Runtime.GetOwner()
    return Runtime.Owners[coroutine.running()] or Runtime.Owner
end

function Runtime.Number(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

function Runtime.IsEnabled(object)
    if not object or not object.Parent then return false end
    while object and object ~= game do
        if Runtime.Disabled[object] then return false end
        object = object.Parent
    end
    return true
end

function Runtime.SetProperty(object, property, value)
    if object[property] ~= value then object[property] = value end
end

local Maid = {}
Maid.__index = Maid
local liveMaids = setmetatable({}, {__mode = "k"})

function Maid.new(parent)
    local self = setmetatable({_tasks = {}, _children = {}, _nextId = 0, Destroyed = false, Parent = parent}, Maid)
    liveMaids[self] = true
    Runtime.Stats.Maids = Runtime.Stats.Maids + 1
    if parent and parent._children then
        if parent.Destroyed then self:Destroy() else parent._children[self] = true end
    end
    return self
end

local function cleanTask(item)
    local kind = typeof(item)
    if kind == "RBXScriptConnection" then
        if item.Connected then item:Disconnect() end
    elseif kind == "Instance" then
        if item:IsA("Tween") then item:Cancel() end
        item:Destroy()
    elseif kind == "function" then
        item()
    elseif kind == "thread" then
        if item ~= coroutine.running() and coroutine.status(item) ~= "dead" then pcall(task.cancel, item) end
    elseif kind == "table" then
        if item.Destroy then item:Destroy()
        elseif item.Disconnect then item:Disconnect()
        elseif item.Cancel then item:Cancel() end
    end
end

function Maid:Add(item, key)
    if self.Destroyed or self._cleaning then pcall(cleanTask, item) return item end
    if key ~= nil then
        local previous = self._tasks[key]
        if previous ~= nil and previous ~= item then pcall(cleanTask, previous) end
        self._tasks[key] = item
    else
        repeat self._nextId = self._nextId + 1 until self._tasks[self._nextId] == nil
        self._tasks[self._nextId] = item
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
    assert(type(callback) == "function", "Connect requires a callback")
    local connection = signal:Connect(function(...)
        if not self.Destroyed then Runtime.InvokeOwned(self, callback, ...) end
    end)
    self:Add(connection)
    Runtime.Stats.Connections = Runtime.Stats.Connections + 1
    return connection
end

function Maid:Once(signal, callback)
    local connection
    local fired = false
    connection = signal:Connect(function(...)
        if fired or self.Destroyed then return end
        fired = true
        connection:Disconnect()
        self._tasks[connection] = nil
        Runtime.InvokeOwned(self, callback, ...)
    end)
    self:Add(connection, connection)
    Runtime.Stats.Connections = Runtime.Stats.Connections + 1
    return connection
end

function Maid:_schedule(delay, fn, ...)
    if self.Destroyed or self._cleaning or type(fn) ~= "function" then return nil end
    local thread
    thread = coroutine.create(function(...)
        if not self.Destroyed then Runtime.InvokeOwned(self, fn, ...) end
        self._tasks[thread] = nil
    end)
    self:Add(thread, thread)
    if delay == nil then task.spawn(thread, ...)
    else task.delay(math.max(0, Runtime.Number(delay, 0)), thread, ...) end
    return thread
end

function Maid:Spawn(fn, ...)
    return self:_schedule(nil, fn, ...)
end

function Maid:Delay(seconds, fn, ...)
    return self:_schedule(seconds, fn, ...)
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
    if self._cleaning then return end
    self._cleaning = true
    local tasks = self._tasks
    self._tasks = {}
    self.UiObjects = nil
    local children = self._children
    self._children = {}
    for child in pairs(children) do pcall(child.Destroy, child) end
    for _, item in pairs(tasks) do
        if typeof(item) == "RBXScriptConnection" then pcall(cleanTask, item) end
    end
    for _, item in pairs(tasks) do
        if typeof(item) ~= "RBXScriptConnection" then pcall(cleanTask, item) end
    end
    self._nextId = 0
    self._cleaning = false
end
Maid.DoCleaning = Maid.Clean

function Maid:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Parent and self.Parent._children then self.Parent._children[self] = nil end
    self.Parent = nil
    self:Clean()
    liveMaids[self] = nil
    Runtime.Stats.MaidsDestroyed = Runtime.Stats.MaidsDestroyed + 1
end

function Runtime.RestoreOwner(thread, previous, ok, ...)
    Runtime.Owners[thread] = previous
    if not ok then error((...), 0) end
    return ...
end

local function withOwner(maid, fn, ...)
    local thread = coroutine.running()
    local previous = Runtime.Owners[thread]
    Runtime.Owners[thread] = maid
    return Runtime.RestoreOwner(thread, previous, pcall(fn, ...))
end

function Runtime.CallbackResult(ok, ...)
    if not ok then
        local problem = tostring((...))
        Runtime.Stats.CallbackErrors = (Runtime.Stats.CallbackErrors or 0) + 1
        Runtime.Stats.LastCallbackError = problem
        warn("WolfUi callback: " .. problem)
    end
    return ok, ...
end

function Runtime.InvokeOwned(owner, callback, ...)
    if owner and owner.Destroyed then return false, "owner destroyed" end
    return Runtime.CallbackResult(pcall(withOwner, owner, callback, ...))
end

function Runtime.Spawn(callback, ...)
    if type(callback) ~= "function" or Runtime.Unloading then return nil end
    local owner = Runtime.GetOwner() or Runtime.Root
    if owner then return owner:Spawn(callback, ...) end
    return task.spawn(function(...) Runtime.InvokeOwned(nil, callback, ...) end, ...)
end

local function connect(signal, callback, owner)
    owner = owner or Runtime.GetOwner() or Runtime.Root
    if owner then return owner:Connect(signal, callback) end
    local connection = signal:Connect(function(...)
        Runtime.InvokeOwned(nil, callback, ...)
    end)
    Runtime.Connections[#Runtime.Connections + 1] = connection
    Runtime.Stats.Connections = Runtime.Stats.Connections + 1
    return connection
end

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
    for maid in pairs(liveMaids) do
        for key, item in pairs(maid._tasks) do
            if typeof(item) == "RBXScriptConnection" and not item.Connected then
                maid._tasks[key] = nil
                Runtime.Stats.Disconnected = Runtime.Stats.Disconnected + 1
            end
        end
    end
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
    local owner = Runtime.GetOwner() or Runtime.Root
    if owner then
        owner:Add(function()
            update.Alive, update.Callback, update.Object = false, nil, nil
        end)
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
    for index = 1, count do
        local update = collection[index]
        if update then
            local object = update.Object
            if update.Alive and update.Callback and (not object or object.Parent) then
                if not object or isRendered(object, renderCache) then
                    local ok, err = pcall(update.Callback, dt, k)
                    if not ok then
                        update.Alive = false
                        Runtime.Stats.UpdateErrors = (Runtime.Stats.UpdateErrors or 0) + 1
                        Runtime.Stats.LastUpdateError = tostring(err)
                        warn("WolfUi: disabled failed UI update: " .. tostring(err))
                    end
                end
            else
                update.Alive = false
            end
        end
        if not Runtime.Alive then return end
    end
    local writeIndex = 1
    local total = #collection
    for index = 1, total do
        local update = collection[index]
        if update and update.Alive then
            collection[writeIndex] = update
            writeIndex = writeIndex + 1
        end
    end
    for index = writeIndex, total do collection[index] = nil end
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
        for property, value in pairs(values) do
            object[property] = value
        end
        fadeValues[object] = nil
        table.clear(values)
        if #Runtime.FadePool < 512 then Runtime.FadePool[#Runtime.FadePool + 1] = values end
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
        local destroying
        destroying = connect(root.Destroying, function()
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

local function fadeTargetList(targets, alpha, visibilityCache)
    if alpha >= 1 then return end
    for _, target in ipairs(targets) do
        local object = target.Object
        if object.Parent and (not visibilityCache or isRendered(object, visibilityCache)) then
            local values = fadeValues[object]
            for _, property in ipairs(target.Properties) do
                local current = object[property]
                if current < 1 then
                    if not values then
                        values = table.remove(Runtime.FadePool) or {}
                        fadeValues[object] = values
                    end
                    if values[property] == nil then values[property] = current end
                    object[property] = 1 - (1 - current) * alpha
                end
            end
        end
    end
end

local function fadeGroup(root, alpha)
    if alpha >= 1 then return end
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
    elseif class == "UIStroke" then
        object.LineJoinMode = Enum.LineJoinMode.Round
        for index = 1, 6 do
            if props and palette[index] and props.Color == palette[index] then
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
    function api:Alpha(v)
        Runtime.SetProperty(label, "TextTransparency", 1 - math.clamp(Runtime.Number(v, 1), 0, 1))
    end
    function api:Width(v) label.Size = UDim2.fromOffset(math.max(0, roundPixel(v)), label.Size.Y.Offset) end
    function api:SetFont(font)
        if typeof(font) == "EnumItem" then label.Font = font end
    end
    function api:SetSize(v) label.TextSize = math.max(6, tonumber(v) or label.TextSize) end
    return api
end

local function iconLabel(parent, names, x, y, size, color, fallback)
    local image, offset, sheetSize, tinted, customColor = resolveIcon(names)
    local object, isImage
    local themed = color == nil or color == white
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
        if not object.Parent then return end
        local replacement = iconLabel(object.Parent, value, 0, 0, size, color, fallback)
        replacement.Object.Position, replacement.Object.Size = object.Position, object.Size
        replacement.Object.ZIndex, replacement.Object.Visible = object.ZIndex, object.Visible
        replacement.Object.Rotation = object.Rotation
        local alpha = 1 - (isImage and object.ImageTransparency or object.TextTransparency)
        replacement:Alpha(alpha)
        object:Destroy()
        object, isImage = replacement.Object, replacement.IsImage
        self.Object, self.IsImage, self.Tinted = object, isImage, replacement.Tinted
    end
    return api
end

local themes = {
    {{9, 9, 9}, {17, 17, 17}, {158, 158, 158}, {23, 23, 23}, {43, 43, 43}, {66, 66, 66}, {242, 242, 242}},
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

local accent = Color3.fromRGB(255, 255, 255)

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
local W = CONTENT_W - PAD * 2
local GAP = 10
local TAB_SLOT = 70

local MINI_GAP = 8
local MINI_MARGIN = 12
local DRAG_THRESHOLD = 6
local SUB_MAX_HEIGHT = 176

local INTERNAL_FLAGS = {
    Scale = true, Accent = true, AccentAlpha = true,
    FadeAnimations = true, ScaleAnimations = true, Tab = true,
    ScrollBarThickness = true,
}

local Library = {
    Version = "7.0.0",
    Capabilities = table.freeze({Layout = 2, Groups = 1, NotificationCenter = 1, CardNotifications = 1, ConditionalColors = 1, ConfigRestore = 2, ESPPreview = 1}),
    Design = table.freeze({CardRadius = 8, PopupRadius = 8, ControlRadius = 3,
        CardTransparency = 0.20, StrokeTransparency = 0.65, Gap = 10, Padding = 10}),
    NotificationOptions = {Width = 250, MaxVisible = 5, Position = "Right", Gap = 8, PauseOnHover = true},
    Flags = {},
    Elements = {},
    NoSaveFlags = {},
    Themes = table.freeze({table.freeze(table.clone(themes[1]))}),
    ThemeNames = table.freeze({"Black"}),
    Font = UI_FONT,
    FontBold = UI_FONT_BOLD,
    FadeAnimations = true,
    FadeDuration = 0.24,
    TabDuration = 0.2,
    TabSlide = 10,
    ScaleAnimations = true,
    ScaleDuration = 0.22,
    ScaleOptions = {100, 75, 50},
    ScrollBarThickness = 3,
    Theme = 1,
    Scale = 75,
    Accent = accent,
    AccentAlpha = 1,
    Configs = {
        Enabled = false,
        Encrypted = false,
        RestoreAccent = false,
        Backups = 3,
        Verify = true,
        PerGame = false,
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

local flagWatchers = {}
local changeListeners = {}
local unloadListeners = {}

local function attributeName(key)
    local name = string.gsub(tostring(key), "[^%w_]", "_")
    if string.match(name, "^%d") then name = "_" .. name end
    return name
end

local function fireChange(flag, value)
    Library.Flags[flag] = value
    local watchers = flagWatchers[flag]
    for _, watcher in ipairs(watchers and table.clone(watchers) or {}) do
        if watcher.Connected then
            local ok, err = pcall(watcher.Callback, value)
            if not ok then warn("WolfUi dependency: " .. tostring(err)) end
        end
    end
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
        pcall(function() window.Changed:Fire(flag, value) end)
    end
    for _, listener in ipairs(changeListeners) do
        Runtime.Spawn(listener, flag, value)
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
    self.FadeAnimations = enabled ~= false
    if duration ~= nil then self.FadeDuration = math.clamp(tonumber(duration) or 0.24, 0.08, 2) end
    fireChange("FadeAnimations", self.FadeAnimations)
    return self.FadeAnimations
end

function Library:GetFadeAnimations()
    return self.FadeAnimations ~= false, self.FadeDuration
end

function Library:SetFadeDuration(duration)
    return self:SetFadeAnimations(self.FadeAnimations ~= false, duration)
end

function Library:SetScaleAnimations(enabled, duration)
    self.ScaleAnimations = enabled ~= false
    if duration ~= nil then self.ScaleDuration = math.clamp(tonumber(duration) or 0.22, 0.08, 2) end
    fireChange("ScaleAnimations", self.ScaleAnimations)
    return self.ScaleAnimations
end

function Library:GetScaleAnimations()
    return self.ScaleAnimations ~= false, self.ScaleDuration
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

function Library:WatchFlag(flag, callback)
    assert(type(flag) == "string" and type(callback) == "function", "WatchFlag requires a flag and callback")
    local watcher = {Connected = true, Callback = callback}
    local list = flagWatchers[flag] or {}; flagWatchers[flag] = list
    list[#list + 1] = watcher
    function watcher:Disconnect()
        if not self.Connected then return end
        self.Connected = false
        for index, item in ipairs(list) do if item == self then table.remove(list,index) break end end
        if #list == 0 then flagWatchers[flag] = nil end
    end
    watcher.Destroy = watcher.Disconnect
    local owner = Runtime.GetOwner() or self.Maid
    if owner then owner:Add(watcher) end
    Runtime.InvokeOwned(owner, callback, self.Flags[flag])
    return watcher
end

function Library:BindVisibility(element, flag, predicate)
    return self:WatchFlag(flag, function(value)
        local visible
        if predicate then visible = predicate(value) else visible = value == true end
        if element.SetVisible then element:SetVisible(visible)
        else (element.Object or element).Visible = visible end
    end)
end

function Library:SetConfigAliases(aliases)
    self.ConfigAliases = {}
    for old, current in pairs(aliases or {}) do
        if type(old) == "string" and type(current) == "string" then self.ConfigAliases[old] = current end
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

function Library:SetAccent(color, alpha)
    if typeof(color) == "Color3" then
        state.Accent = color
        self.Accent = color
        Runtime.ThemeDirty = true
        fireChange("Accent", color)
    end
    if alpha then
        alpha = math.clamp(Runtime.Number(alpha, state.AccentAlpha), 0, 1)
        state.AccentAlpha = alpha
        self.AccentAlpha = alpha
        Runtime.ThemeDirty = true
        fireChange("AccentAlpha", alpha)
    end
end

function Library:ResetAppearance()
    self:SetAccent(Color3.fromRGB(255, 255, 255), 1)
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
        if key == "MinScale" or key == "MaxScale" then
            self.Limits[key] = math.max(0.01, Runtime.Number(value, self.Limits[key]))
        elseif key == "Margin" then
            self.Limits[key] = math.max(0, Runtime.Number(value, self.Limits[key]))
        else self.Limits[key] = value end
    end
    if self.Limits.MinScale > self.Limits.MaxScale then
        self.Limits.MinScale, self.Limits.MaxScale = self.Limits.MaxScale, self.Limits.MinScale
    end
    if self.Window then self.Window.Layout() end
    return self.Limits
end

function Library:SetScrollBarThickness(thickness)
    self.ScrollBarThickness = math.clamp(math.floor(tonumber(thickness) or 3), 0, 12)
    if self.Window and self.Window.LayoutScrollBar then self.Window.LayoutScrollBar() end
    fireChange("ScrollBarThickness", self.ScrollBarThickness)
    return self.ScrollBarThickness
end

function Library:GetScrollBarThickness()
    return self.ScrollBarThickness
end

function Library:SetScaleOptions(list)
    local options = {}
    for _, value in ipairs(list or {}) do
        local number = Runtime.Number(value)
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
    value = Runtime.Number(value, 100)
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
    if typeof(name) == "EnumItem" then
        if name.EnumType == Enum.KeyCode or name.EnumType == Enum.UserInputType then return name end
        return nil
    end
    if type(name) ~= "string" or name == "" then return nil end
    local normalized = string.upper(name)
    if normalized == "NONE" then return nil end
    if not Runtime.KeyNames then
        local names = {}
        for _, item in ipairs(Enum.UserInputType:GetEnumItems()) do names[string.upper(item.Name)] = item end
        for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do names[string.upper(item.Name)] = item end
        for short, long in pairs(KEY_LONG) do names[short] = names[string.upper(long)] end
        Runtime.KeyNames = names
    end
    return Runtime.KeyNames[normalized]
end

local Tab = {}
Tab.__index = Tab

local Window = {}
Window.__index = Window

local function createPopup(window, anchor, w, h, animateHeight, parentPopup)
    local object = rect(window.PopupLayer, 0, 0, w, h, palette[2], 8, "Frame")
    object.BackgroundTransparency = 0.24
    new("UIGradient", object, {
        Rotation = 110,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
    })
    new("UIStroke", object, {Color = Color3.fromRGB(100, 100, 100), Thickness = 1, Transparency = 0.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
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
    data.Maid = Maid.new(Runtime.GetOwner() or Library.Maid)
    function data:Destroy()
        if self.Destroyed then return end
        if self:IsActive() then window.Opened = self.Parent end
        self.Destroyed = true
        for index, popup in ipairs(window.Popups) do
            if popup == self then table.remove(window.Popups, index) break end
        end
        self.Maid:Destroy()
        if self.Object then self.Object:Destroy() end
    end

    function data:IsActive()
        if self.Destroyed or not isRendered(self.Anchor) or not Runtime.IsEnabled(self.Anchor) then return false end
        local current = window.Opened
        while current do
            if current == self then return true end
            current = current.Parent
        end
        return false
    end
    function data:Open(anchorOverride)
        if anchorOverride then self.Anchor = anchorOverride end
        if self.Destroyed or not isRendered(self.Anchor) or not Runtime.IsEnabled(self.Anchor) then return end
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
    data.Maid:Add(function() data:Destroy() end)
    return data
end
function Runtime.StepNotifications(window, elapsed, dt)
        for index = #window.Notifications, 1, -1 do
            local notif = window.Notifications[index]
            if notif.Destroyed then
                table.remove(window.Notifications, index)
            else
            if not notif.Sticky and not (notif.Hover and Library.NotificationOptions.PauseOnHover) then
                notif.Life = math.max(0, notif.Life - elapsed)
            end
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
                    roundPixel(notif.Width * math.clamp(notif.Life / math.max(0.01, notif.Duration or 4), 0, 1)), 2)
            end
            notif.Object.Position = UDim2.fromOffset(roundPixel((notif.Width + 10) * (1 - notif.Alpha) * (Library.NotificationOptions.Position == "Left" and -1 or 1)), roundPixel(notif.Y))
            if notif.Life <= 0 and notif.Alpha <= 0.01 then
                if notif.Maid then notif.Maid:Destroy() else notif.Object:Destroy() end
                if notif.Id and window.NotificationIds[notif.Id] == notif then window.NotificationIds[notif.Id] = nil end
                notif.Destroyed = true
                table.remove(window.Notifications, index)
            end
            end
        end
        local offset = 0
        for _, notif in ipairs(window.Notifications) do
            notif.TargetY = offset
            offset = offset + notif.Height + Library.NotificationOptions.Gap
        end

end

function Runtime.StartRenderer(window, frame, scale, popupLayer, blurSize, invalidateTooltip)
    local fpsTimer, fpsFrames = 0, 0

    local sweepTimer = 0
    connect(RunService.RenderStepped, function(dt)
        if not Runtime.Alive or window.Destroyed then return end
        if not window.Gui or not window.Gui.Parent then Library:Unload() return end
        restoreFades()
        sweepTimer = sweepTimer + dt
        if sweepTimer >= Runtime.SweepInterval then
            sweepTimer = 0
            sweepConnections()
        end
        local elapsed = math.max(0, Runtime.Number(dt, 0))
        dt = math.min(elapsed, 0.1)
        local now = os.clock()
        local performance = Library.Performance or {}
        local idleRate = window.Visible
            and math.clamp(tonumber(performance.IdleUpdateRate) or 12, 4, 60)
            or math.clamp(tonumber(performance.HiddenUpdateRate) or 6, 2, 30)
        window.UpdateAccumulator = (window.UpdateAccumulator or 0) + dt
        local active = now <= (window.ActiveUntil or 0) or Runtime.ThemeDirty or window.Drag ~= nil
            or window.Animating == true
            or math.abs(window.Alpha - (window.Visible and 1 or 0)) > 0.001
        local runUi = active or window.UpdateAccumulator >= 1 / idleRate
        local uiDt = active and dt or math.min(window.UpdateAccumulator, 0.1)
        if runUi then window.UpdateAccumulator = 0 end
        local k = motionFactor(18, dt)
        if window.GlassBlur then
            local camera = workspace.CurrentCamera
            if window.GlassBlur.Parent ~= camera then window.GlassBlur.Parent = camera end
            local amount = math.clamp(window.Alpha, 0, 1)
            window.GlassBlur.Size = blurSize * amount
            window.GlassBlur.Enabled = amount > 0.01 and camera ~= nil
        end

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
        fpsTimer = fpsTimer + elapsed
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
        if viewportChanged then
            window.LayoutMini()
            window.LayoutNotifications()
            invalidateTooltip()
        end
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
        if not Runtime.Alive or window.Destroyed then return end

        Runtime.StepNotifications(window, elapsed, dt)

        window.Alpha = fadeAlpha(window.Alpha, window.Visible and 1 or 0, dt)
        frame.Visible = window.Visible or window.Alpha > 0
        window.PopupLayer.Visible = frame.Visible
        if not frame.Visible then return end
        local mainTransitioning = window.Alpha < 0.999

        if runUi then
            window.Animating = false
            local uiK = motionFactor(18, uiDt)
            table.clear(renderCache)
            runUpdates(Runtime.Updates, uiDt, uiK, renderCache)
            if not Runtime.Alive or window.Destroyed then return end

            for _, tab in ipairs(window.TabList) do
                local tabActive = window.Current == tab
                tab.Alpha = transitionAlpha(tab.Alpha, tabActive and 1 or 0,
                    uiDt, Library.TabDuration)
                tab.Slide = approach(tab.Slide or 0, tabActive and 0 or (tab.ExitSlide or 0),
                    motionFactor(4.25 / math.max(0.08, Library.TabDuration), uiDt))
                if math.abs(tab.Alpha - (tabActive and 1 or 0)) > 0.001
                    or math.abs(tab.Slide or 0) > 0.01 and tabActive then
                    window.Animating = true
                end
                local page = tab.Page
                page.Visible = tab.Alpha > 0.001
                page.Interactable = tabActive and window.Visible
                if page.Visible then
                    page.Position = UDim2.fromOffset(PAD + tab.Slide, PAD)
                    fadeGroup(page, tab.Alpha)
                elseif not tabActive then
                    tab.Slide = 0
                    page.Position = UDim2.fromOffset(PAD, PAD)
                end
            end

            for _, pop in ipairs(window.Popups) do
                local show = pop:IsActive() and window.Visible
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
                    if math.abs(pop.Alpha - (show and 1 or 0)) > 0.001
                        or pop.AnimateHeight and math.abs(pop.CurrentHeight - (show and pop.Height or 1)) > 0.1 then
                        window.Animating = true
                    end
                    object.Visible = pop.Alpha > 0 and pop.Anchor ~= nil
                    object.Interactable = show and window.Visible
                    if object.Visible then
                        fadeGroup(object, pop.Alpha * window.Alpha)
                        object.BackgroundColor3 = palette[2]
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
        if not runUi then
            for _, tab in ipairs(window.TabList) do
                if tab.Page.Visible then fadeGroup(tab.Page, tab.Alpha) end
            end
            for _, pop in ipairs(window.Popups) do
                if pop.Object.Visible then fadeGroup(pop.Object, pop.Alpha * window.Alpha) end
            end
        end
        local hiddenAmount = 1 - math.clamp(window.Alpha, 0, 1)
        local revealOffset = hiddenAmount * hiddenAmount * 6 * window.ScaleCurrent
        local animatedPosition = UDim2.fromOffset(window.Position.X, window.Position.Y + revealOffset)
        frame.Position = animatedPosition
        popupLayer.Position = animatedPosition
        if mainTransitioning then
            local targets = fadeTargets(frame)
            local visibilityCache = window.RenderCache
            table.clear(visibilityCache)
            fadeTargetList(targets, window.Alpha, visibilityCache)
        end
    end)

end

function Library:CreateWindow(opts)
    opts = opts or {}

    if Library.Window then
        Library:Unload()
    end

    local requested = opts.Size
    local sizeX, sizeY
    if typeof(requested) == "Vector2" then sizeX, sizeY = requested.X, requested.Y
    elseif type(requested) == "table" then sizeX, sizeY = requested.X or requested[1], requested.Y or requested[2] end
    WINDOW_W = math.clamp(math.floor(tonumber(sizeX or opts.Width) or 590), 480, 1040)
    WINDOW_H = math.clamp(math.floor(tonumber(sizeY or opts.Height) or 350), 300, 780)
    CONTENT_W, W = WINDOW_W - SIDEBAR_W - RAIL_W, WINDOW_W - SIDEBAR_W - RAIL_W - PAD * 2
    if type(opts.Notifications) == "table" then self:SetNotificationOptions(opts.Notifications) end

    Runtime.Connections, Runtime.Updates, Runtime.Overlay, Runtime.Alive, Runtime.Owner = {}, {}, {}, true, nil
    Runtime.ThemeDirty = true
    Library.Maid = Maid.new()
    Runtime.Root = Library.Maid
    Runtime.Unloading = false
    Library.Destroyed = false
    local configOptions = opts.Configs
    if configOptions == true then configOptions = {Enabled = true} end
    if type(configOptions) ~= "table" then configOptions = {Enabled = false} end
    self.Configs = {
        Enabled = configOptions.Enabled ~= false and opts.Configs ~= nil,
        Encrypted = configOptions.Encrypted == true or configOptions.Encryption == true,
        Key = tostring(configOptions.Key or "1"),
        RestoreAccent = configOptions.RestoreAccent == true,
        Backups = math.clamp(math.floor(tonumber(configOptions.Backups) or 3), 0, 10),
        Verify = configOptions.Verify ~= false,
        PerGame = configOptions.PerGame == true,
    }
    Library:SetScriptName(opts.Folder or opts.ScriptName or opts.Name)
    self.FadeAnimations, self.ScaleAnimations = true, true
    if opts.FadeDuration ~= nil then self:SetFadeDuration(opts.FadeDuration) end
    if opts.ScaleDuration ~= nil then self:SetScaleDuration(opts.ScaleDuration) end
    if type(opts.Performance) == "table" then self:SetPerformanceOptions(opts.Performance) end

    do
        local registry = Runtime.Env()
        registry.__WolfUiWindows = registry.__WolfUiWindows or {}
        local guiKey = opts.GuiName or "WolfUI"
        local other = registry.__WolfUiWindows[guiKey]
        if other and other ~= Library and type(other.Unload) == "function" then
            pcall(other.Unload, other)
        end
        registry.__WolfUiWindows[guiKey] = Library
    end

    local previous = playerGui:FindFirstChild(opts.GuiName or "WolfUI")
    if previous then previous:Destroy() end

    state.Theme = 1
    state.Scale = math.clamp(tonumber(opts.Scale) or 75, 20, 400)
    state.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or Color3.fromRGB(255, 255, 255)
    state.AccentAlpha = math.clamp(tonumber(opts.AccentAlpha) or 1, 0, 1)
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
        NotificationIds = {},
        Size = Vector2.new(WINDOW_W, WINDOW_H),
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

    local frame = paint(rect(gui, 0, 0, WINDOW_W, WINDOW_H, palette[1], 12, "Frame"), 1)
    frame.Name = "Window"
    frame.ZIndex = 2
    frame.Active = true
    frame.ClipsDescendants = true
    window.Frame = frame
    frame.BackgroundTransparency = 0.22
    new("UIGradient", frame, {
        Rotation = 110,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
    })
    local glassEdge = new("UIStroke", frame, {
        Color = Color3.fromRGB(128, 128, 128), Thickness = 1, Transparency = 0.58,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    new("UIGradient", glassEdge, {
        Rotation = 100,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.5, 0.4),
            NumberSequenceKeypoint.new(1, 0.65),
        }),
    })
    local blurSize = 14
    do
        local effect = Instance.new("BlurEffect")
        effect.Name = "WolfUIFrost"
        effect.Size, effect.Enabled = 0, false
        window.GlassBlur = effect
        Library.Maid:Add(effect)
    end
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
            if not primary(input) or window.Drag or window.Dialog or not Runtime.IsEnabled(object) then return end
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
        if not Runtime.IsEnabled(drag.Object) or not isRendered(drag.Object) or window.Dialog then
            cancelDrag()
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
    sidebar.BackgroundTransparency = 1
    local sidebarSurface = paint(rect(sidebar, 4, 4, SIDEBAR_W - 8, WINDOW_H - 8, palette[2], 8), 2)
    sidebarSurface.Name = "Surface"
    sidebarSurface.BackgroundTransparency = 0.24
    new("UIGradient", sidebarSurface, {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205)),
    })
    new("UIStroke", sidebarSurface, {Color = palette[5], Thickness = 1, Transparency = 0.55,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
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

    local scrollTrack = rect(frame, WINDOW_W - RAIL_W, 0, Library.ScrollBarThickness, WINDOW_H, palette[2])
    scrollTrack.Name = "ScrollTrack"
    scrollTrack.ZIndex = 2
    local scrollThumb = rect(scrollTrack, 0, 0, Library.ScrollBarThickness, WINDOW_H, palette[5])
    scrollThumb.Name = "ScrollThumb"
    scrollThumb.ZIndex = 3
    scrollTrack.BackgroundTransparency = 1
    scrollThumb.BackgroundTransparency = 1
    window.ScrollTrack = scrollTrack
    window.ScrollThumb = scrollThumb

    local function layoutScrollBar()
        local thickness = math.max(0, roundPixel(Library.ScrollBarThickness))
        scrollTrack.Position = UDim2.fromOffset(WINDOW_W - RAIL_W + (RAIL_W - thickness) / 2, 0)
        scrollTrack.Size = UDim2.fromOffset(thickness, WINDOW_H)
        scrollThumb.Size = UDim2.new(1, 0, scrollThumb.Size.Y.Scale, 0)
    end
    window.LayoutScrollBar = layoutScrollBar
    layoutScrollBar()

    step(function()
        local canvasHeight = scroll.CanvasSize.Y.Offset
        local viewHeight = scroll.AbsoluteSize.Y
        local visible = Library.ScrollBarThickness > 0 and canvasHeight > viewHeight and viewHeight > 0
        scrollTrack.Visible = visible
        if not visible then return end
        local ratio = math.clamp(viewHeight / math.max(1, canvasHeight), 0, 1)
        local thumbHeight = math.max(20, roundPixel(viewHeight * ratio))
        local maxScroll = math.max(1, canvasHeight - viewHeight)
        local travel = math.max(0, viewHeight - thumbHeight)
        local posY = travel * math.clamp(scroll.CanvasPosition.Y / maxScroll, 0, 1)
        scrollThumb.Size = UDim2.fromOffset(scrollTrack.AbsoluteSize.X, thumbHeight)
        scrollThumb.Position = UDim2.fromOffset(0, roundPixel(posY))
        scrollTrack.BackgroundColor3 = palette[2]
        scrollThumb.BackgroundColor3 = palette[5]
    end, scroll)

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
            connect(hit.Activated, function() Runtime.InvokeOwned(Runtime.GetOwner(), config.Callback, hit) end)
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
                    Runtime.Spawn(function()
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
    local tooltipText = text(tooltip, "", 6, 4, 10, 12, 11, white, nil, {Wrap = true})
    local tooltipHeight = 20

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
            if type(wm.OnMove) == "function" then Runtime.Spawn(wm.OnMove, wm.Position) end
        elseif window.OpenConfig.Mode == "watermark" and wm.Enabled and wm.Toggle ~= false then
            window:SetVisible(not window.Visible)
        elseif type(wm.OnClick) == "function" then
            Runtime.Spawn(wm.OnClick)
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

        if window.Visible and window.TooltipText and window.TooltipObject
            and window.TooltipObject.Parent then
            local caption = window.TooltipText
            if caption ~= tooltipCaption then
                tooltipCaption = caption
                local bounds = TextService:GetTextSize(caption, 11, UI_FONT,
                    Vector2.new(math.max(40, math.min(220, viewport.X - 24)), 10000))
                tooltipWidth = bounds.X + 12
                tooltipHeight = bounds.Y + 8
                tooltipText:SetText(caption)
                tooltipText.Object.Size = UDim2.fromOffset(roundPixel(bounds.X + 2), roundPixel(bounds.Y))
                tooltip.Size = UDim2.fromOffset(roundPixel(tooltipWidth), roundPixel(tooltipHeight))
            end
            tooltip.Visible = true
            tooltip.BackgroundColor3 = palette[1]
            local anchor = window.TooltipObject
            local origin = anchor.AbsolutePosition
            local anchorSize = anchor.AbsoluteSize
            local x = origin.X + anchorSize.X * 0.5 - tooltipWidth * 0.5
            local aboveY = origin.Y - tooltipHeight - 6
            local belowY = origin.Y + anchorSize.Y + 6
            -- Keep touch hints attached to the control. Prefer below when there
            -- is room; otherwise place above. Never clamp a tooltip to a remote
            -- position near the top of the window.
            local y
            if belowY + tooltipHeight <= viewport.Y - 6 then
                y = belowY
            elseif aboveY >= 6 then
                y = aboveY
            else
                y = math.clamp(belowY, 6, math.max(6, viewport.Y - tooltipHeight - 6))
            end
            tooltip.Position = UDim2.fromOffset(
                math.clamp(x, 6, math.max(6, viewport.X - tooltipWidth - 6)),
                math.clamp(y, 6, math.max(6, viewport.Y - tooltipHeight - 6))
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
    local notifyScale = new("UIScale", notifyHolder, {Scale = 1})
    function window.LayoutNotifications()
        local config, widest, total = Library.NotificationOptions, Library.NotificationOptions.Width, 0
        for _, notif in ipairs(window.Notifications) do
            widest = math.max(widest, notif.Width)
            total = total + notif.Height + config.Gap
        end
        local factor = math.min(1, math.max(0.2, (window.Viewport.X - 16) / widest))
        notifyScale.Scale = factor
        notifyHolder.Size = UDim2.fromOffset(widest, math.max(1, (window.Viewport.Y - 16) / factor))
        notifyHolder.Position = config.Position == "Left" and UDim2.fromOffset(8, 8)
            or UDim2.new(1, -widest * factor - 8, 0, 8)
        while #window.Notifications > 1 and total - config.Gap > (window.Viewport.Y - 16) / factor do
            local oldest = window.Notifications[1]
            total = total - oldest.Height - config.Gap
            oldest:Destroy()
        end
    end
    window.LayoutNotifications()

    connect(UIS.InputBegan, function(input, processed)

        if window.Dialog then return end
        if window.PendingKeybind then
            local pending = window.PendingKeybind
            if processed or UIS:GetFocusedTextBox() then return end
            if not Runtime.IsEnabled(pending.Object) then pending:Cancel() return end
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
        if not Runtime.Unloading and Library.Window == window then Library:Unload() end
    end)

    Runtime.StartRenderer(window, frame, scale, popupLayer, blurSize, function() tooltipCaption = nil end)

    return window
end

function Window:SetVisible(value)
    if self.Destroyed then return end
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
        if self.PendingKeybind and self.PendingKeybind.Cancel then self.PendingKeybind:Cancel() end
        self.PendingKeybind = nil
    end
    if self.UpdateOpenVisibility then self.UpdateOpenVisibility() end
end

function Window:GetSize() return self.Size end

function Window:Center()
    self.Position = (self.Viewport - self.Size * self.ScaleCurrent) / 2
    self.Layout()
    self:Wake()
    return self
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
    local snapped = exact and Runtime.Number(value, state.Scale) or snapScale(value)
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
    if self.Destroyed or not tab or tab.Destroyed or tab.Window ~= self or self.Current == tab then return end
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
    if previous then previous.ScrollPosition = self.Scroll.CanvasPosition.Y end
    self.Opened = nil
    self.Current = tab
    self.MainFadeDirty = true
    if self.Wake then self:Wake() end
    state.Tab = tab.Name
    self.Scroll.CanvasSize = UDim2.fromOffset(0, tab.Height + PAD * 2)
    self.Scroll.CanvasPosition = Vector2.new(0, math.clamp(tab.ScrollPosition or 0, 0,
        math.max(0, tab.Height + PAD * 2 - self.Scroll.AbsoluteSize.Y)))
    fireChange("Tab", tab.Name)
    self.TabChanged:Fire(tab.Name)
end

function Window:CreateTab(opts)
    if self.Destroyed then return nil, "window destroyed" end
    opts = opts or {}
    local name = tostring(opts.Name or ("Tab" .. tostring(#self.TabList + 1)))
    if self.Tabs[name] then error("WolfUi: duplicate tab name '" .. name .. "'", 2) end
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

    tab.Maid = Maid.new(Library.Maid)
    self.Tabs[name] = tab
    self.TabList[index] = tab

    local top = (index - 1) * TAB_SLOT
    local hit = rect(self.TabHolder, 6, top + 2, SIDEBAR_W - 12, TAB_SLOT - 4, palette[4], 6, "TextButton")
    hit.Name = name
    hit.BackgroundTransparency = 1
    local icon = iconLabel(hit, opts.Icon or {"circle"}, (SIDEBAR_W - 12 - 16) / 2, 19.6, 16, palette[3],
        opts.Fallback or string.sub(name, 1, 1))
    local title = text(hit, opts.Title or name, 0, 39.3, SIDEBAR_W - 12, 15, 11, palette[3], "center")
    self.TabHolder.CanvasSize = UDim2.fromOffset(0, index * TAB_SLOT)

    connect(hit.Activated, function() self:SelectTab(tab) end, tab.Maid)
    if opts.Tooltip then self:Tooltip(hit, opts.Tooltip) end

    local hover = false
    connect(hit.MouseEnter, function() hover = true end, tab.Maid)
    connect(hit.MouseLeave, function() hover = false end, tab.Maid)

    local alpha, hoverAlpha, tint = 0, 0, palette[3]
    local update = step(function(dt, k)
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
    tab.Maid:Add(function() update.Alive, update.Callback, update.Object = false, nil, nil end)

    tab.Button = hit
    tab.Icon = icon
    tab.TitleLabel = title
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
            other.Button.Position = UDim2.fromOffset(6, (i - 1) * TAB_SLOT + 2)
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
    if not fraction or fraction <= 0 or fraction >= 1 then return total end
    local columns = math.clamp(math.floor(1 / fraction + 0.5), 1, math.max(1, math.floor((total + GAP) / (70 + GAP))))
    return math.floor((total - GAP * (columns - 1)) / columns)
end

function Tab:_place(w, h)
    local total = self:_pageWidth()
    local cursor = self.Cursor
    self.LayoutItems = self.LayoutItems or {}
    local item = {Width = w, Height = h, Break = self.LayoutBreak == true}
    self.LayoutBreak = false
    self.LayoutItems[#self.LayoutItems + 1] = item
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
    item.X, item.Y = x, y
    return x, y
end

function Tab:_newline()
    self.LayoutBreak = true
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
    if (self.LayoutDepth or 0) > 0 then self.LayoutDirty = true return end
    self.Page.Size = UDim2.fromOffset(self:_pageWidth(), math.max(1, height))
    if self.OnResize then Runtime.InvokeOwned(self.Maid, self.OnResize, height) end
    if self.Window and self.Window.Current == self then
        self.Window.Scroll.CanvasSize = UDim2.fromOffset(0, height + PAD * 2)
    end
end
function Tab:_card(w, h, name)
    local x, y = self:_place(w, h)
    local card = paint(rect(self.Page, x, y, w, h, palette[2], Library.Design.CardRadius), 2)
    card.BackgroundTransparency = Library.Design.CardTransparency
    new("UIGradient", card, {
        Rotation = 100,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(218, 218, 218)),
    })
    new("UIStroke", card, {Color = palette[5], Thickness = 1, Transparency = Library.Design.StrokeTransparency,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    card.Name = name or "Element"
    local record = self:_track(card)
    if Runtime.GetOwner() then
        local owner = Runtime.GetOwner()
        owner.UiObjects = owner.UiObjects or {}
        owner.UiObjects[card] = true
        owner:Add(card)
        if record then self:_watchLayout(record, owner) end
    end
    self:_grow()
    return card
end

function Tab:_track(object, maid)
    if not object or object.Parent ~= self.Page then return end
    local record
    for _, item in ipairs(self.LayoutItems or {}) do
        if item.Object == object then
            item.Width, item.Height = object.Size.X.Offset, object.Size.Y.Offset
            return item
        end
        if not item.Object and item.X == object.Position.X.Offset and item.Y == object.Position.Y.Offset then
            record = item
        end
    end
    if not record then return end
    record.Object = object
    if maid then self:_watchLayout(record, maid) end
    return record
end

function Tab:_watchLayout(record, maid)
    if record.Watched then return end
    record.Watched = true
    local object = record.Object
    maid:Connect(object:GetPropertyChangedSignal("Visible"), function() self:Reflow() end)
    maid:Connect(object:GetPropertyChangedSignal("Size"), function()
        record.Height = object.Size.Y.Offset
        record.Width = object.Size.X.Offset
        self:Reflow()
    end)
    maid:Add(function()
        record.Removed = true
        record.Object = nil
        for index, item in ipairs(self.LayoutItems or {}) do
            if item == record then table.remove(self.LayoutItems, index) break end
        end
        if Runtime.Alive and not self.Destroyed then self:Reflow() end
    end)
end

function Tab:BeginUpdate()
    self.LayoutDepth = (self.LayoutDepth or 0) + 1
    return self
end

function Tab:EndUpdate()
    self.LayoutDepth = math.max(0, (self.LayoutDepth or 0) - 1)
    if self.LayoutDepth == 0 then self:Reflow() end
    return self
end

function Tab:Batch(callback)
    self:BeginUpdate()
    local ok, result = pcall(callback, self)
    self:EndUpdate()
    if not ok then error(result, 0) end
    return result
end

function Tab:Reflow()
    if self.Destroyed or self.Reflowing then return end
    if (self.LayoutDepth or 0) > 0 then self.LayoutDirty = true return end
    self.LayoutDirty, self.Reflowing = false, true
    local cursor, total = {X = 0, Y = 0, RowHeight = 0}, self:_pageWidth()
    for _, item in ipairs(self.LayoutItems or {}) do
        local object = item.Object
        if not item.Removed and (not object or object.Parent and object.Visible) then
            if cursor.X > 0 and (item.Break or cursor.X + item.Width > total + 0.5) then
                cursor.Y = cursor.Y + cursor.RowHeight + GAP
                cursor.X, cursor.RowHeight = 0, 0
            end
            item.X, item.Y = cursor.X, cursor.Y
            if object then object.Position = UDim2.fromOffset(item.X, item.Y) end
            cursor.X = cursor.X + item.Width + GAP
            cursor.RowHeight = math.max(cursor.RowHeight, item.Height)
            if cursor.X >= total then
                cursor.Y = cursor.Y + cursor.RowHeight + GAP
                cursor.X, cursor.RowHeight = 0, 0
            end
        end
    end
    self.Cursor = cursor
    self:_grow()
    if self.Window and self.Window.Current == self then
        local scroll = self.Window.Scroll
        local maximum = math.max(0, self.Height + PAD * 2 - scroll.AbsoluteSize.Y)
        if scroll.CanvasPosition.Y > maximum then scroll.CanvasPosition = Vector2.new(0, maximum) end
    end
    self.Reflowing = false
    if self.Window and self.Window.Wake then self.Window:Wake() end
end

function Tab:ScrollTo(element)
    if not self.Window or self.IsSubMenu or self.IsGroup then return false end
    local object = type(element) == "table" and element.Object or element
    if not object or object.Parent ~= self.Page then return false end
    self.Window:SelectTab(self)
    self.Window.Scroll.CanvasPosition = Vector2.new(0, math.clamp(object.Position.Y.Offset, 0,
        math.max(0, self.Height + PAD * 2 - self.Window.Scroll.AbsoluteSize.Y)))
    return true
end

local function baseApi(tab, card, flag)
    local api = {Object = card, Flag = flag, Tab = tab}
    function api:SetVisible(value) card.Visible = value and true or false end
    function api:Destroy() card:Destroy() end
    if flag then
        Library.Elements[flag] = api
    end
    tab.Elements[#tab.Elements + 1] = api
    if Runtime.GetOwner() then
        Runtime.GetOwner():Add(function()
            if flag and Library.Elements[flag] == api then Library.Elements[flag] = nil end
            for index, element in ipairs(tab.Elements) do
                if element == api then table.remove(tab.Elements, index) break end
            end
        end)
    end
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
    local stroke = new("UIStroke", button, {Color = palette[5], Thickness = 1, Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})

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
        if self.Destroyed or not self.Enabled or not Runtime.IsEnabled(button) then return end
        flash = 1 / 9
        if config.OnPress then
            Runtime.InvokeOwned(Runtime.GetOwner(), config.OnPress, self)
            return
        end
        if self.Mode == "Toggle" then
            self.Active = not self.Active
        end
        if config.Callback then Runtime.Spawn(config.Callback, self.Active) end
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
        if self.Update then self.Update.Alive, self.Update.Callback, self.Update.Object = false, nil, nil end
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
    local corner = button:FindFirstChildOfClass("UICorner")
    local geometryWidth, geometryHeight, geometryCaption
    local savedX, savedY, shownPosition = nil, nil, mini.Target
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
        if geometryWidth ~= width or geometryHeight ~= height or geometryCaption ~= caption then
        geometryWidth, geometryHeight, geometryCaption = width, height, caption
        if corner then corner.CornerRadius = UDim.new(0, math.max(3, math.floor(size / 4))) end
        local iconSize = math.floor(caption and size * 0.42 or size * 0.5)
        icon.Object.Position = UDim2.fromOffset(math.floor((width - iconSize) / 2), caption and math.floor(height * 0.16) or math.floor((height - iconSize) / 2))
        icon.Object.Size = UDim2.fromOffset(iconSize, iconSize)
        button.Size = UDim2.fromOffset(width, height)
        if label then
            label:Alpha(1 - mini.Transparency)
            label.Object.Position = UDim2.fromOffset(2, math.floor(height * 0.56))
            label.Object.Size = UDim2.fromOffset(width - 4, math.floor(height * 0.32))
        end
        end
        stroke.Color = palette[5]:Lerp(accent, alpha)
        tint = tint:Lerp(mini.Active and white or palette[3], k)
        icon:Color(tint)
        if label then label:Color(tint) end
        local target = mini.Target
        if mini.Custom and (savedX ~= mini.Position.X or savedY ~= mini.Position.Y) then
            savedX, savedY = mini.Position.X, mini.Position.Y
            window.MiniPositions[mini.Key] = {X = savedX, Y = savedY}
        end
        if window.Drag and window.Drag.Object == button then shownPosition = target
        else shownPosition = shownPosition:Lerp(target, k) end
        if (shownPosition - target).Magnitude < 0.5 then shownPosition = target end
        button.Position = UDim2.fromOffset(roundPixel(shownPosition.X), roundPixel(shownPosition.Y))
    end
    mini.Update = overlayStep(updateMini)
    if Runtime.GetOwner() then
        Runtime.GetOwner():Add(function() mini:Destroy() end)
    end
    window.LayoutMini()
    updateMini(0, 1)

    return mini
end

function Window:AddMiniButton(config)
    return createMiniButton(self, config or {})
end

function Window:Tooltip(object, message)
    if not object or message == nil or message == "" then return end
    local token, touch = 0, nil
    local tooltipOwner = Runtime.GetOwner() or Library.Maid
    connect(object.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        token = token + 1
        touch = input
        local thisToken, origin = token, input.Position
        tooltipOwner:Delay(0.55, function()
            if token == thisToken and object.Parent and self.Visible
                and (input.Position - origin).Magnitude < DRAG_THRESHOLD then
                self.TooltipText, self.TooltipObject = tostring(message), object
                self:Wake()
            end
        end)
    end)
    connect(UIS.InputEnded, function(input)
        if input == touch then
            touch = nil
            token = token + 1
            if self.TooltipObject == object then self.TooltipText, self.TooltipObject = nil, nil end
        end
    end)
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
    local inset = 8
    local holder = new("ScrollingFrame", pop.Object, {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, inset),
        Size = UDim2.fromOffset(width, 37 - inset * 2),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollingEnabled = false,
        Active = true,
    })
    local page = transparent(holder, inset, 0, width - inset * 2 - 4, 1)

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
        Maid = pop.Maid,
        Object = pop.Object,
    }, Tab)

    connect(holder:GetPropertyChangedSignal("CanvasPosition"), function() window:Wake() end)
    menu.OnResize = function(height)
        local total = math.max(31, height + inset * 2)
        local shown = math.min(maxHeight, total)
        pop.Height = shown
        local viewHeight = math.max(1, shown - inset * 2)
        holder.Size = UDim2.fromOffset(width, viewHeight)
        holder.CanvasSize = UDim2.fromOffset(0, height)
        holder.ScrollingEnabled = height > viewHeight
        holder.CanvasPosition = Vector2.new(0,
            math.clamp(holder.CanvasPosition.Y, 0, math.max(0, height - viewHeight)))
    end

    function menu:Open(anchorOverride) if self.Enabled ~= false then pop:Open(anchorOverride or anchor) end end
    function menu:Close() pop:Close() end
    function menu:Toggle(anchorOverride) if self.Enabled ~= false then pop:Toggle(anchorOverride or anchor) end end
    function menu:IsOpen() return pop:IsActive() end
    function menu:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        pop:Destroy()
    end
    function menu:SetVisible(value) if value then self:Open() else self:Close() end end
    function menu:GetVisible() return self:IsOpen() end
    function menu:SetEnabled(value)
        self.Enabled = value ~= false
        pop.Object.Interactable = self.Enabled
        Runtime.Disabled[pop.Object] = not self.Enabled or nil
        if not self.Enabled then self:Close() end
        return self.Enabled
    end
    function menu:GetEnabled() return self.Enabled ~= false end
    function menu:SetValue(value) return self:SetVisible(value) end
    pop.Maid:Add(function() menu.Destroyed = true end)

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
    if opts.IncludeScrollBarSlider == true then
        addElements({
            {
                Type = "Slider",
                Name = opts.ScrollBarSliderName or "Scrollbar Size",
                Flag = "ScrollBarThickness",
                Min = 0,
                Max = 12,
                Default = Library.ScrollBarThickness,
                Suffix = "px",
                Callback = function(value) Library:SetScrollBarThickness(value) end,
            },
        })
    end
    addElements(opts.Items or opts.Elements)
    if type(opts.Build) == "function" then
        local _, built = Runtime.InvokeOwned(Runtime.GetOwner(), opts.Build, menu)
        if type(built) == "table" and built[1] ~= nil then addElements(built) end
    end
    menu.Icon = icon
    menu.AnchorObject = anchor
    return menu
end

function Tab:AddGroup(opts)
    opts = type(opts) == "table" and opts or {Name = opts}
    local parent, w = self, self:_width(opts.Width)
    local card = self:_card(w, 36, opts.Name or "Group")
    card.ClipsDescendants = true
    local header = transparent(card, 0, 0, w, 36, "TextButton")
    local title = text(header, opts.Name or "Group", 10, 0, w - 44, 36, 12, white, nil, {Bold = true})
    local arrow = iconLabel(header, {"chevron-right"}, w - 26, 11, 14, palette[3], ">")
    local body = transparent(card, 10, 36, w - 20, 1)
    local group = setmetatable({Object = card, Page = body, Window = self.Window,
        Name = opts.Name or "Group", Width = w - 20, Height = 0, Elements = {},
        Cursor = {X = 0, Y = 0, RowHeight = 0}, Maid = Runtime.GetOwner(),
        IsGroup = true, Collapsed = opts.Collapsed == true, TargetHeight = 36}, Tab)
    local shown = 36
    local function sizeTarget()
        group.TargetHeight = group.Collapsed and 36 or 36 + math.max(0, group.Height) + 4
        if group.Collapsed then self.Window.Opened = nil end
        body.Visible = not group.Collapsed
        body.Interactable = not group.Collapsed
        self.Window:Wake()
    end
    group.OnResize = sizeTarget
    function group:SetCollapsed(value, instant)
        self.Collapsed = value == true
        sizeTarget()
        if instant then
            shown = self.TargetHeight
            card.Size = UDim2.fromOffset(w, roundPixel(shown))
            parent:_track(card)
            parent:Reflow()
        end
        return self
    end
    function group:GetCollapsed() return self.Collapsed end
    function group:Toggle() return self:SetCollapsed(not self.Collapsed) end
    function group:SetName(value) title:SetText(value) end
    function group:SetVisible(value) card.Visible = value == true end
    function group:Destroy()
        for i = #self.Elements, 1, -1 do
            local element = self.Elements[i]
            if element.Destroy then element:Destroy() end
        end
    end
    connect(header.Activated, function() group:Toggle() end)
    step(function(dt)
        if group.Destroyed then return end
        local nextHeight = approach(shown, group.TargetHeight, motionFactor(24, dt))
        if math.abs(nextHeight - group.TargetHeight) < 0.5 then nextHeight = group.TargetHeight end
        if math.abs(nextHeight - shown) > 0.001 then
            shown = nextHeight
            card.Size = UDim2.fromOffset(w, roundPixel(shown))
        end
        arrow.Object.Rotation = group.Collapsed and 0 or 90
        if shown ~= group.TargetHeight then group.Window.Animating = true end
    end, card)
    self.Elements[#self.Elements + 1] = group
    if Runtime.GetOwner() then
        Runtime.GetOwner():Add(function()
            for index, element in ipairs(parent.Elements) do
                if element == group then table.remove(parent.Elements, index) break end
            end
        end)
    end
    if type(opts.Build) == "function" then group:Batch(opts.Build) end
    group:SetCollapsed(group.Collapsed, true)
    return group
end

function Tab:AddSpacer(opts)
    opts = type(opts) == "table" and opts or {Height = opts}
    local w, height = self:_width(opts.Width), math.max(1, roundPixel(tonumber(opts.Height) or 8))
    local x, y = self:_place(w, height)
    local object = transparent(self.Page, x, y, w, height)
    self:_grow()
    return baseApi(self, object, nil)
end

function Tab:AddStat(opts)
    opts = opts or {}
    local w = self:_width(opts.Width)
    local card = self:_card(w, 78, opts.Name or "Stat")
    local title = muted(card, opts.Name or "Value", 10, 9, w - 20, 14, 11)
    local value = text(card, tostring(opts.Value or "0"), 10, 27, w - 20, 24, 20, white, nil, {Bold = true})
    local detail = muted(card, opts.Description or "", 10, 57, w - 20, 13, 10)
    local api = baseApi(self, card, nil)
    function api:Set(newValue, description)
        value:SetText(newValue)
        if description ~= nil then detail:SetText(description) end
    end
    function api:Get() return value:GetText() end
    function api:SetValue(newValue, silent, description) return self:Set(newValue, description) end
    function api:SetName(name) title:SetText(name) end
    function api:SetDescription(caption) detail:SetText(caption) end
    return api
end

function Tab:AddNotice(opts)
    opts = type(opts) == "table" and opts or {Text = opts}
    local w = self:_width(opts.Width)
    local body = tostring(opts.Text or "")
    local measured = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(w - 46, 10000))
    local h = math.max(42, (opts.Name and 28 or 10) + measured.Y + 10)
    local card = self:_card(w, h, opts.Name or "Notice")
    local icon = iconLabel(card, opts.Icon or {"info"}, 10, 12, 16, accent, "i")
    if opts.Name then text(card, opts.Name, 36, 9, w - 46, 14, 12, white) end
    local caption = muted(card, body, 36, opts.Name and 28 or 10, w - 46,
        math.max(14, measured.Y), 11, nil, {Wrap = true})
    local api = baseApi(self, card, nil)
    function api:SetText(value)
        body = tostring(value or "")
        local bounds = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(w - 46, 10000))
        caption:SetText(body)
        caption.Object.Size = UDim2.fromOffset(w - 46, math.max(14, bounds.Y))
        card.Size = UDim2.fromOffset(w, math.max(42, (opts.Name and 28 or 10) + bounds.Y + 10))
    end
    step(function() icon:Color(accent) end, card)
    return api
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
    function api:SetText(value)
        body = tostring(value or "")
        local measured = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(w - 20, 10000))
        paragraph:SetText(body)
        paragraph.Object.Size = UDim2.fromOffset(w - 20, math.max(14, measured.Y))
        card.Size = UDim2.fromOffset(w, (hasTitle and 28 or 10) + math.max(14, measured.Y) + 10)
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
    local hex = string.match(value, "^%s*#?(%x+)%s*$")
    if not hex then return nil end
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
    local alphaValue = opts.Alpha ~= nil and math.clamp(Runtime.Number(opts.Alpha, 1), 0, 1) or 1
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

    local api = {Flag = flag, Anchor = anchor, Popup = pop, Object = anchor}
    function api:SetVisible(visible)
        anchor.Visible = visible == true
        if not anchor.Visible then pop:Close() end
    end
    if Runtime.GetOwner() then
        Runtime.GetOwner():Add(function() if Library.Elements[flag] == api then Library.Elements[flag] = nil end end)
    end

    local function push(silent)
        local result = Color3.fromHSV(hue, saturation, value)
        color = result
        dot.BackgroundColor3 = result
        dot.BackgroundTransparency = useAlpha and (1 - alphaValue) or 0
        Library.Flags[flag] = result
        fireChange(flag, result)
        if useAlpha then
            Library.Flags[flag .. ".Alpha"] = alphaValue
            fireChange(flag .. ".Alpha", alphaValue)
        end
        if not silent and opts.Callback then
            Runtime.Spawn(opts.Callback, result, alphaValue)
        end
    end

    function api:Get()
        return Color3.fromHSV(hue, saturation, value), alphaValue
    end

    function api:Set(newColor, newAlpha, silent)
        if typeof(newColor) == "Color3" then
            hue, saturation, value = newColor:ToHSV()
        end
        if newAlpha ~= nil then
            alphaValue = math.clamp(Runtime.Number(newAlpha, alphaValue), 0, 1)
        end
        push(silent)
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
    local lastHue, lastHexColor = nil, nil
    local hexText = "#" .. toHex(color)

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
            if current ~= lastHexColor then
                lastHexColor, hexText = current, "#" .. toHex(current)
            end
            if hexBox.Text ~= hexText then hexBox.Text = hexText end
        end
    end, preview)

    Library.Flags[flag] = color
    if useAlpha then Library.Flags[flag .. ".Alpha"] = alphaValue end
    Library.Elements[flag] = api
    if useAlpha then
        Library.Elements[flag .. ".Alpha"] = {
            Flag = flag .. ".Alpha",
            Get = function() return alphaValue end,
            Set = function(_, newAlpha) api:Set(nil, tonumber(newAlpha)) end,
        }
    end
    if opts.Callback then Runtime.Spawn(opts.Callback, color, alphaValue) end
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
    api.Set = function(_, color, alpha, silent) picker:Set(color, alpha, silent) end
    api.Picker = picker
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

    local bind = {Key = key, Flag = flag, Object = button}

    function bind:Fire()
        if self.Destroyed or not Runtime.IsEnabled(button) then return end
        if opts.Callback then Runtime.Spawn(opts.Callback, self.Key) end
        if opts.Toggle then Runtime.InvokeOwned(Runtime.GetOwner(), opts.Toggle) end
    end

    function bind:Set(value, silent)
        if self.Destroyed then return end
        if type(value) == "string" then value = keyFromName(value) end
        if value ~= nil and (typeof(value) ~= "EnumItem"
            or value.EnumType ~= Enum.KeyCode and value.EnumType ~= Enum.UserInputType) then return end
        self.Key = value
        caption:SetText(keyName(value))
        Library.Flags[flag] = value and keyName(value) or "NONE"
        fireChange(flag, Library.Flags[flag])
    end

    function bind:Get() return self.Key end
    function bind:Cancel()
        if window.PendingKeybind == self then window.PendingKeybind = nil end
        caption:SetText(keyName(self.Key))
    end

    window.Keybinds[#window.Keybinds + 1] = bind
    if Runtime.GetOwner() then
        Runtime.GetOwner():Add(function()
            local index = table.find(window.Keybinds, bind)
            if index then table.remove(window.Keybinds, index) end
            if window.PendingKeybind == bind then window.PendingKeybind = nil end
        end)
    end

    connect(button.Activated, function()
        if not Runtime.IsEnabled(button) then return end
        if window.PendingKeybind then window.PendingKeybind:Cancel() end
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
    api.Set = function(_, value, silent) bind:Set(value, silent) end
    api.Keybind = bind
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
    local accessories, colorPickers = {}, {}
    local title, description
    local function layoutAccessories()
        local right = w - 24
        for _, item in ipairs(accessories) do
            local object = item.Object
            if object.Visible then
                right = right - 10 - item.Width
                object.Position = UDim2.fromOffset(right,14.5)
            end
        end
        edge = right
        if title then title.Object.Size = UDim2.fromOffset(math.max(20,right-20),14) end
        if description then description.Object.Size = UDim2.fromOffset(math.max(20,right-20),14) end
    end
    local function accessory(object, width)
        accessories[#accessories+1] = {Object=object,Width=width}
        connect(object:GetPropertyChangedSignal("Visible"),layoutAccessories)
        layoutAccessories()
    end
    local function addColor(config)
        config = table.clone(config)
        config.Flag = config.Flag or (flag .. ".Color" .. tostring(#colorPickers+1))
        config.Name = config.Name or name
        local picker = attachColorPicker(self,card,0,14.5,14,config)
        colorPickers[#colorPickers+1] = picker
        accessory(picker.Anchor,14)
        if config.VisibleWhen then Library:BindVisibility(picker,config.VisibleWhen,config.Predicate) end
        return picker
    end

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if mini and mini.Config.ShowWhenActive then mini:SetVisible(value) end
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, value) end
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
        colorPicker = addColor(config)
    end
    for _, config in ipairs(opts.ColorPickers or {}) do addColor(config) end

    if opts.Keybind ~= nil then
        local config = type(opts.Keybind) == "table" and opts.Keybind or {Default = opts.Keybind}
        config.Flag = config.Flag or (flag .. ".Key")
        config.Name = config.Name or name
        config.Toggle = function() api:Toggle() end
        keybind = attachKeybind(self, card, 0, 14.5, 46, 14, config)
        accessory(keybind.Object or keybind.Button,46)
    end

    if opts.Settings ~= nil then
        local config = type(opts.Settings) == "table" and opts.Settings or {Build = opts.Settings}
        config.Name = config.Name or name
        settings = attachSettings(self, card, 0, 14.5, 14, config)
        accessory(settings.AnchorObject,14)
    end

    title = text(card, name, 10, 10, math.max(40, edge - 20), 14, 12, palette[3])
    if opts.Description then
        description = muted(card, opts.Description, 10, 22, math.max(40, edge - 20), 14, 11)
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
    if opts.Callback and value then Runtime.Spawn(opts.Callback, value) end
    api.ColorPicker = colorPicker
    api.ColorPickers = colorPickers
    api.LayoutAccessories = layoutAccessories
    layoutAccessories()
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
    local min = Runtime.Number(opts.Min, 0)
    local max = Runtime.Number(opts.Max, 100)
    if max < min then min, max = max, min end
    local decimals = math.clamp(math.floor(Runtime.Number(opts.Decimals, 0)), 0, 10)
    local suffix = tostring(opts.Suffix or "")
    local valueFormat = "%." .. tostring(decimals) .. "f"
    local lastCaptionValue

    local card = paint(rect(parent, x, y, w, 58, palette[2], Library.Design.CardRadius), 2)
    card.BackgroundTransparency = Library.Design.CardTransparency
    new("UIStroke", card, {Color = palette[5], Thickness = 1,
        Transparency = Library.Design.StrokeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
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

    local value = math.clamp(Runtime.Number(opts.Default, min), min, max)

    local function quantize(raw)
        if decimals <= 0 then return math.floor(raw + 0.5) end
        local m = 10 ^ decimals
        return math.floor(raw * m + 0.5) / m
    end

    value = math.clamp(quantize(value), min, max)
    local api = {Flag = flag, Object = card}

    local function push(fire)
        Library.Flags[flag] = value
        fireChange(flag, value)
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        value = math.clamp(quantize(Runtime.Number(newValue, value)), min, max)
        push(not silent)
    end
    function api:SetVisible(v) card.Visible = v and true or false end
    function api:Destroy() card:Destroy() end
    function api:SetRange(newMin, newMax)
        min = Runtime.Number(newMin, min)
        max = Runtime.Number(newMax, max)
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
        local nextValue = math.clamp(quantize(min + (max - min) * ratio), min, max)
        if nextValue ~= value then api:Set(nextValue) end
    end, function(cancelled)
        dragging = false
        if not cancelled and type(opts.OnRelease) == "function" then Runtime.Spawn(opts.OnRelease, value) end
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
        if lastCaptionValue ~= value then
            lastCaptionValue = value
            valueLabel:SetText(string.format(valueFormat, value) .. suffix)
        end
    end, card)

    Library.Elements[flag] = api
    push(false)
    if opts.Callback then Runtime.Spawn(opts.Callback, value) end
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
        return names, table.clone(selection)
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
        local caption = previewText()
        Library.Flags[flag .. ".Text"] = caption
        preview:SetText(caption)
        fireChange(flag, Library.Flags[flag])
        if fire and opts.Callback then
            Runtime.Spawn(opts.Callback, selectedValue())
        end
    end

    local rowsOwner = Runtime.GetOwner() or Library.Maid
    local function updateAvailability()
        local available = enabled and #options > 0
        control.Active = available
        control.Interactable = available
        if not available then pop:Close() end
    end

    local function buildRows()
        list.CanvasSize = UDim2.fromOffset(0, #options * ROW_H)
        local visibleRows = math.min(#options, maxRows)
        if tonumber(opts.MaxRows) == 0 then visibleRows = #options end
        list.ScrollingEnabled = #options > visibleRows
        pop.Height = math.max(ROW_H, visibleRows * ROW_H)
        list.CanvasPosition = Vector2.new(0, math.clamp(list.CanvasPosition.Y, 0,
            math.max(0, #options * ROW_H - pop.Height)))
        updateAvailability()
        for index = #rows, #options + 33, -1 do
            rows[index].Maid:Destroy()
            rows[index] = nil
        end
        for index, entry in ipairs(rows) do
            entry.Object.Visible = index <= #options
            entry.Hovered = false
        end
        for index, option in ipairs(options) do
            local entry = rows[index]
            if not entry then
                local rowMaid = Maid.new(rowsOwner)
                entry = withOwner(rowMaid, function()
                    local row = rect(list, 0, (index - 1) * ROW_H,
                        controlW, ROW_H, palette[5], 5, "TextButton")
                    row.BackgroundTransparency = 1
                    rowMaid:Add(row)
                    local edgeFill = rect(row, 0, 5, controlW, ROW_H - 5, palette[5])
                    edgeFill.BackgroundTransparency = 1
                    local result = {Object = row, Fill = edgeFill,
                        Corner = row:FindFirstChildOfClass("UICorner"),
                        Mark = iconLabel(row, {"check"}, 0, 9.5, 12, accent, "v"),
                        Title = text(row, option, 10, 0, controlW - 20, ROW_H, 11, palette[3]),
                        Alpha = 0, Hover = 0, Hovered = false, Index = index, Maid = rowMaid}
                    connect(row.MouseEnter, function() result.Hovered = true end)
                    connect(row.MouseLeave, function() result.Hovered = false end)
                    connect(row.Activated, function()
                        if not enabled or not Runtime.IsEnabled(card) or not options[index] then return end
                        if multiple then selection[index] = not selection[index] or nil
                        else selection = index; pop:Close() end
                        push(true)
                    end)
                    return result
                end)
                rows[index] = entry
            end
            local firstRow, lastRow = index == 1, index == #options
            entry.Object.Visible = true
            entry.Title:SetText(option)
            entry.Corner.CornerRadius = UDim.new(0, (firstRow or lastRow) and 5 or 0)
            entry.Fill.Visible = firstRow ~= lastRow
            entry.Fill.Position = UDim2.fromOffset(0, firstRow and 5 or 0)
        end
    end

    step(function(dt, k)
        for index = 1, #options do
            local entry = rows[index]
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
            selection = math.clamp(math.floor(Runtime.Number(value, 1)), 1, math.max(1, #options))
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
        for _, option in ipairs(type(list_) == "table" and list_ or {}) do options[#options + 1] = tostring(option) end
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
        updateAvailability()
        return enabled
    end
    function api:GetEnabled() return enabled end
    function api:HasOptions() return #options > 0 end

    buildRows()
    push(false)
    if opts.Callback then Runtime.Spawn(opts.Callback, selectedValue()) end
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
    local suppressText = nil
    local numeric = opts.Numeric == true
    local lastPublished = nil

    local function normalize(value)
        local result = tostring(value == nil and "" or value)
        if numeric then
            result = string.gsub(result, "[^%d%.%-]", "")
            local negative = string.sub(result, 1, 1) == "-"
            result = string.gsub(result, "%-", "")
            local dot = string.find(result, ".", 1, true)
            if dot then
                result = string.sub(result, 1, dot) .. string.gsub(string.sub(result, dot + 1), "%.", "")
            end
            if negative then result = "-" .. result end
        end
        if maxLength > 0 then
            local length = utf8.len(result)
            if length and length > maxLength then
                local offset = utf8.offset(result, maxLength + 1)
                if offset then result = string.sub(result, 1, offset - 1) end
            elseif not length then
                result = string.sub(result, 1, maxLength)
            end
        end
        return result
    end

    local function push(fire)
        lastPublished = box.Text
        Library.Flags[flag] = box.Text
        fireChange(flag, box.Text)
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, box.Text) end
    end

    box.Text = normalize(box.Text)
    connect(box:GetPropertyChangedSignal("Text"), function()
        local cleaned = normalize(box.Text)
        if cleaned ~= box.Text then box.Text = cleaned end
        if suppressText ~= nil and box.Text == suppressText then return end
        suppressText = nil
        if lastPublished ~= box.Text then push(true) end
    end)

    connect(box.FocusLost, function(enterPressed)
        if enterPressed and opts.OnEnter then Runtime.Spawn(opts.OnEnter, box.Text) end
        if opts.OnFocusLost then Runtime.Spawn(opts.OnFocusLost, box.Text, enterPressed) end
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
        if self.Destroyed then return end
        local newText = normalize(value)
        suppressText = newText
        lastPublished = newText
        box.Text = newText
        if silent then Library.Flags[flag] = newText else push(true) end
    end
    function api:Focus()
        if not self.Destroyed and Runtime.IsEnabled(card) and isRendered(card) then box:CaptureFocus() end
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
    local enabled = opts.Enabled ~= false
    local card = self:_card(w, compact and 31 or 68, name)

    local control, title
    if compact then
        control = paint(rect(card, 0, 0, w, 31, palette[4], 8, "TextButton"), 4)
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
    local loading = false
    local buttonOwner = Runtime.GetOwner()
    function api:SetText(value)
        captionText = tostring(value)
        if not loading then caption:SetText(captionText) end
    end
    function api:SetLoading(value, message)
        loading = value == true
        caption:SetText(loading and tostring(message or opts.LoadingText or "Loading...") or captionText)
        control.Interactable = enabled and not loading
        if self.Tab and self.Tab.Window then self.Tab.Window:Wake() end
        return self
    end
    function api:GetLoading() return loading end
    function api:SetIcon(value)
        if icon then icon:SetIcon(value) end
    end
    if title then bindTitle(api, title, opts) end
    function api:SetEnabled(value)
        enabled = value ~= false
        control.Active = enabled
        pcall(function() control.Interactable = enabled and not loading end)
        if not enabled then hover = false end
        return enabled
    end
    function api:GetEnabled() return enabled end
    function api:Press()
        if self.Destroyed or not enabled or loading then return false end
        flash = 1 / 9
        if self.Tab and self.Tab.Window then self.Tab.Window.ButtonPressed:Fire(self.Tab.Name .. "." .. name) end
        if opts.Callback then
            if opts.AutoLoading then
                self:SetLoading(true)
                buttonOwner:Spawn(function()
                    local ok, err = pcall(opts.Callback)
                    if not self.Destroyed then self:SetLoading(false) end
                    if not ok then warn("WolfUi button '" .. name .. "': " .. tostring(err)) end
                end)
            else Runtime.Spawn(opts.Callback) end
        end
        return true
    end

    if opts.Tooltip then self.Window:Tooltip(control, opts.Tooltip) end

    local mini
    if opts.MiniButton ~= nil and opts.MiniButton ~= false then
        local config = type(opts.MiniButton) == "table" and opts.MiniButton or {}
        config.Name = config.Name or name
        config.Key = config.Key or (self.Name .. "." .. name)
        config.Icon = config.Icon or opts.Icon or {"play", "circle"}
        config.Mode = "Action"
        config.OnPress = function() api:Press() end
        mini = self.Window:AddMiniButton(config)
    end
    api.Mini = mini

    connect(control.MouseEnter, function() hover = enabled and not loading end)
    connect(control.MouseLeave, function() hover = false end)
    connect(control.Activated, function()
        api:Press()
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
        caption:Alpha(enabled and not loading and 1 or 0.38)
        if icon then icon:Alpha(enabled and not loading and 1 or 0.38) end
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
            if opts.OnShow then Runtime.Spawn(opts.OnShow, value) end
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
    if min and max and max < min then min, max = max, min end
    local stepSize = math.abs(Runtime.Number(opts.Step, 1))
    if stepSize == 0 then stepSize = 1 end
    local decimals = math.clamp(math.floor(Runtime.Number(opts.Decimals, 0)), 0, 10)
    local suffix = opts.Suffix or ""
    local value = tonumber(opts.Default) or min or 0
    if min then value = math.max(min, value) end
    if max then value = math.min(max, value) end

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
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, value) end
    end

    function api:Get() return value end
    function api:Set(newValue, silent)
        local raw = quantize(Runtime.Number(newValue, value))
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
    if opts.Callback then Runtime.Spawn(opts.Callback, value) end
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
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, options[selection], selection) end
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
    if opts.Callback then Runtime.Spawn(opts.Callback, options[selection], selection) end
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
        value = math.clamp(Runtime.Number(newValue, 0), 0, 1)
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
    local rowsOwner = Runtime.GetOwner() or Library.Maid
    local rowsMaid
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
        if fire and opts.Callback then Runtime.Spawn(opts.Callback, copy) end
    end

    local function rebuild()
        if rowsMaid then rowsMaid:Destroy() end
        rowsMaid = Maid.new(rowsOwner)
        rows = {}
        withOwner(rowsMaid, function()
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
            rowsMaid:Add(row)
            rows[#rows + 1] = row
        end
        holder.CanvasSize = UDim2.fromOffset(0, #items * ROW_H)
        end)
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
        for _, item in ipairs(type(list) == "table" and list or {}) do items[#items + 1] = tostring(item) end
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

function Tab:AddPlayerList(opts)
    opts = opts or {}
    local name = opts.Name or "Игроки"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width or 370)
    local listH = math.max(140, math.floor(tonumber(opts.Height) or 360))
    local rowH = math.max(56, math.floor(tonumber(opts.RowHeight) or 64))
    local includeSelf = opts.IncludeSelf == true
    local getRole = type(opts.GetRole) == "function" and opts.GetRole or function() return "" end
    local onWatch = type(opts.OnWatch) == "function" and opts.OnWatch or function() end
    local onTeleport = type(opts.OnTeleport) == "function" and opts.OnTeleport or function() end
    local onFling = type(opts.OnFling) == "function" and opts.OnFling or function() end

    local card = self:_card(w, 54 + listH + 12, name)
    local api = baseApi(self, card, flag)
    local title = text(card, name, 10, 9, math.max(40, w - 70), 15, 12, white)
    local countLabel = text(card, "0", w - 58, 9, 48, 15, 10, palette[3], "right")

    local search = new("TextBox", card, {
        BackgroundColor3 = palette[4],
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 29),
        Size = UDim2.fromOffset(math.max(80, w - 20), 26),
        ClearTextOnFocus = false,
        PlaceholderText = opts.Placeholder or "Найти игрока...",
        PlaceholderColor3 = palette[3],
        Text = "",
        TextColor3 = white,
        Font = UI_FONT,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    })
    new("UICorner", search, {CornerRadius = UDim.new(0, 5)})
    new("UIPadding", search, {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 8)})

    local holder = new("ScrollingFrame", card, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 61),
        Size = UDim2.fromOffset(math.max(80, w - 20), listH),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = palette[5],
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        Active = true,
        ClipsDescendants = true,
        ZIndex = 2,
    })

    local empty = muted(holder, opts.Empty or "Игроки не найдены", 8, 0, math.max(60, w - 36), rowH - 4, 11)
    local rows = {}
    local listMaid = Maid.new(Runtime.GetOwner() or Library.Maid)
    local rowsMaid = Maid.new(listMaid)
    local filterText = ""

    local function roleText(player)
        local ok, value = pcall(getRole, player)
        if ok and value ~= nil then
            local result = tostring(value)
            if result ~= "" then return result end
        end
        return "Неизвестно"
    end

    local thumbCache = {}
    local function thumbnail(player)
        local id = tonumber(player.UserId) or 0
        if thumbCache[id] then return thumbCache[id] end
        local image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=48&h=48"
        task.spawn(function()
            local ok, content, ready = pcall(function()
                return Players:GetUserThumbnailAsync(
                    id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and ready and type(content) == "string" and content ~= "" then
                thumbCache[id] = content
                if rows[player] and rows[player].Parent then
                    local avatar = rows[player]:FindFirstChild("Avatar")
                    if avatar and avatar:IsA("ImageLabel") then avatar.Image = content end
                end
            end
        end)
        thumbCache[id] = image
        return image
    end

    local ACTION_W = 28
    local ACTION_H = 30
    local ACTION_GAP = 4
    local ACTION_COUNT = 3
    local ACTIONS_W = ACTION_W * ACTION_COUNT + ACTION_GAP * (ACTION_COUNT - 1)

    local function actionButton(row, x, iconNames, fallback, tooltip, callback, player)
        local y = math.floor((rowH - 4 - ACTION_H) * 0.5)
        local button = rect(row, x, y, ACTION_W, ACTION_H, palette[4], 5, "TextButton")
        button.BackgroundTransparency = 0.08
        button.AutoButtonColor = false
        button.ZIndex = 8
        button.ClipsDescendants = true

        local iconSize = 14
        local icon = iconLabel(button, iconNames,
            math.floor((ACTION_W - iconSize) * 0.5),
            math.floor((ACTION_H - iconSize) * 0.5),
            iconSize, palette[3], fallback)
        icon.Object.ZIndex = 9

        connect(button.Activated, function()
            if player and player.Parent then Runtime.Spawn(callback, player) end
        end, rowsMaid)

        local hover = false
        connect(button.MouseEnter, function() hover = true end, rowsMaid)
        connect(button.MouseLeave, function() hover = false end, rowsMaid)
        step(function()
            button.BackgroundColor3 = palette[4]:Lerp(palette[5], hover and 0.8 or 0)
            icon:Color(palette[3]:Lerp(white, hover and 1 or 0))
        end, button)

        if tooltip then self.Window:Tooltip(button, tooltip) end
        return button
    end

    local function clearRows()
        rowsMaid:Destroy()
        rowsMaid = Maid.new(listMaid)
        table.clear(rows)
    end

    local function rebuild()
        clearRows()
        local playersList = {}
        local needle = string.lower(filterText)

        for _, p in ipairs(Players:GetPlayers()) do
            if (includeSelf or p ~= Players.LocalPlayer) and
                (needle == "" or string.find(string.lower(p.Name), needle, 1, true)
                    or string.find(string.lower(p.DisplayName), needle, 1, true)) then
                playersList[#playersList + 1] = p
            end
        end

        table.sort(playersList, function(a, b)
            return string.lower(a.DisplayName) < string.lower(b.DisplayName)
        end)

        empty.Object.Visible = #playersList == 0
        countLabel:SetText(tostring(#playersList))

        local rowWidth = math.max(80, w - 22)
        local avatarSize = math.min(40, rowH - 16)
        local actionStart = math.max(avatarSize + 120, rowWidth - ACTIONS_W - 6)
        local infoX = 12 + avatarSize
        local infoW = math.max(70, actionStart - infoX - 8)

        for index, p in ipairs(playersList) do
            local y = (index - 1) * rowH
            local row = rect(holder, 0, y, rowWidth - 4, rowH - 4, palette[4], 6)
            row.Name = "PlayerRow_" .. tostring(p.UserId)
            row.ZIndex = 3
            row.ClipsDescendants = true
            rows[p] = row

            local avatar = new("ImageLabel", row, {
                Name = "Avatar",
                BackgroundColor3 = palette[1],
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(7, math.floor((rowH - 4 - avatarSize) * 0.5)),
                Size = UDim2.fromOffset(avatarSize, avatarSize),
                Image = thumbnail(p),
                ScaleType = Enum.ScaleType.Crop,
                ZIndex = 5,
            })
            new("UICorner", avatar, {CornerRadius = UDim.new(1, 0)})

            local display = text(row, p.DisplayName, infoX, 8, infoW, 16, 11, white)
            display.Object.ZIndex = 6
            display.Object.TextTruncate = Enum.TextTruncate.AtEnd

            local username = p.DisplayName ~= p.Name and ("@" .. p.Name) or p.Name
            local tag = text(row, username, infoX, 25, infoW, 12, 8, palette[3])
            tag.Object.ZIndex = 6
            tag.Object.TextTruncate = Enum.TextTruncate.AtEnd

            local role = text(row, roleText(p), infoX, 39, infoW, 12, 9, palette[3])
            role.Object.ZIndex = 6
            role.Object.TextTruncate = Enum.TextTruncate.AtEnd

            actionButton(row, actionStart, {"eye", "view"}, "Н", "Наблюдать", onWatch, p)
            actionButton(row, actionStart + ACTION_W + ACTION_GAP, {"move", "send", "navigation"}, "Т", "Телепорт", onTeleport, p)
            actionButton(row, actionStart + (ACTION_W + ACTION_GAP) * 2, {"zap", "flame"}, "Ф", "Флинг", onFling, p)

            rowsMaid:Add(row)
        end

        holder.CanvasSize = UDim2.fromOffset(0, math.max(0, #playersList * rowH))
    end

    connect(search:GetPropertyChangedSignal("Text"), function()
        filterText = search.Text or ""
        rebuild()
    end, listMaid)
    connect(Players.PlayerAdded, function() rebuild() end, listMaid)
    connect(Players.PlayerRemoving, function() rebuild() end, listMaid)

    local roleClock = 0
    step(function(dt)
        roleClock = roleClock + dt
        if roleClock >= 0.75 then
            roleClock = 0
            rebuild()
        end
    end, card)

    function api:GetFilter() return filterText end
    function api:SetFilter(value)
        filterText = tostring(value or "")
        search.Text = filterText
        rebuild()
    end
    function api:Refresh() rebuild() end
    function api:GetPlayers()
        local result = {}
        for p in pairs(rows) do result[#result + 1] = p end
        return result
    end
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        listMaid:Destroy()
        card:Destroy()
    end

    rebuild()
    return api
end

function Tab:AddPlayerDropdown(opts)
    opts = opts or {}
    local function names(excluded)
        local list = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= excluded and (opts.IncludeSelf ~= false or player ~= Players.LocalPlayer) then
                list[#list + 1] = player.Name
            end
        end
        table.sort(list)
        return list
    end

    local api = self:AddDropdown({
        Name = opts.Name or "Игрок",
        Description = opts.Description,
        Flag = opts.Flag,
        Options = names(),
        Multiple = opts.Multiple,
        MaxRows = opts.MaxRows,
        Width = opts.Width,
        Callback = opts.Callback,
    })

    function api:Refresh(excluded) self:SetOptions(names(excluded)) end
    connect(Players.PlayerAdded, function() api:Refresh() end)
    connect(Players.PlayerRemoving, function(leaving) api:Refresh(leaving) end)

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
    cards = "AddCardGrid",
    cardgrid = "AddCardGrid",
    cardselector = "AddCardGrid",
    cardpicker = "AddCardGrid",
    skins = "AddCardGrid",
}

local RARITY_COLORS = {
    common = Color3.fromRGB(176, 195, 217),
    uncommon = Color3.fromRGB(94, 152, 217),
    rare = Color3.fromRGB(75, 105, 255),
    mythical = Color3.fromRGB(136, 71, 255),
    epic = Color3.fromRGB(136, 71, 255),
    legendary = Color3.fromRGB(211, 44, 230),
    ancient = Color3.fromRGB(235, 75, 75),
    covert = Color3.fromRGB(235, 75, 75),
    contraband = Color3.fromRGB(228, 174, 57),
    gold = Color3.fromRGB(228, 174, 57),
}
Library.RarityColors = RARITY_COLORS

local function resolveColor(value, fallback)
    if typeof(value) == "Color3" then return value end
    if type(value) == "string" then
        local key = string.lower(value)
        if key == "accent" then return accent end
        if key == "text" then return white end
        if key == "muted" then return palette[3] end
        if RARITY_COLORS[key] then return RARITY_COLORS[key] end
        if string.match(value, "^#?%x%x%x%x%x%x$") then return fromHex(value) or fallback end
    end
    return fallback
end

local function normalizeKeywords(value)
    if type(value) == "table" then
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = tostring(item) end
        return table.concat(parts, " ")
    elseif value ~= nil then
        return tostring(value)
    end
    return nil
end

local function foldText(value)
    value = string.lower(tostring(value or ""))
    local ok, result = pcall(function()
        return (string.gsub(value, utf8.charpattern, function(ch)
            local code = utf8.codepoint(ch)
            if code >= 0x410 and code <= 0x42F then return utf8.char(code + 32) end
            if code == 0x401 then return utf8.char(0x451) end
            return ch
        end))
    end)
    return ok and result or value
end

local function scaleTypeOf(value)
    if typeof(value) == "EnumItem" then return value end
    local key = string.lower(tostring(value or "fit"))
    if key == "crop" or key == "fill" then return Enum.ScaleType.Crop end
    if key == "stretch" then return Enum.ScaleType.Stretch end
    return Enum.ScaleType.Fit
end

function Library:CreateCheckMark(parent,x,y,size,color)
    return iconLabel(parent,{"check"},x,y,size,color,"v")
end

function Tab:AddCardGrid(opts)
    opts = opts or {}
    local window = self.Window
    local name = opts.Name or "Cards"
    local flag = opts.Flag or (self.Name .. "." .. name)
    local w = self:_width(opts.Width)
    local columns = math.max(1, math.floor(tonumber(opts.Columns) or 3))
    local gap = math.max(0, math.floor(tonumber(opts.Gap) or 8))
    local tileH = math.max(36, math.floor(tonumber(opts.CardHeight or opts.TileHeight) or 96))
    local radius = math.max(4, math.floor(tonumber(opts.CornerRadius) or 7))
    local titleSize = math.clamp(math.floor(tonumber(opts.TitleSize) or 11), 8, 16)
    local titleAlign = opts.TitleAlign or "center"
    local imageOnly = opts.ImageOnly == true
    local showTitles = not imageOnly and opts.ShowTitles ~= false
    local showCheck = opts.ShowCheck ~= false and (not imageOnly or opts.ShowCheck == true)
    local showOrder = not imageOnly and opts.ShowOrder == true
    local checkShape = string.lower(tostring(opts.CheckShape or "square"))
    local checkStyle = string.lower(tostring(opts.CheckStyle or "always"))
    local checkPosition = string.lower(tostring(opts.CheckPosition or "topright"))
    local strokeThickness = math.clamp(tonumber(opts.StrokeThickness) or 1.5, 1, 3)
    local imagePadding = math.max(0, math.floor(tonumber(opts.ImagePadding) or (imageOnly and 0 or 4)))
    local imageBackground = opts.ImageBackground ~= false
    local useCardColor = opts.UseCardColor == true
    local single = string.lower(tostring(opts.Mode or "multi")) == "single"
    local maxSelected = tonumber(opts.MaxSelected or opts.Max or opts.Limit)
    if single then maxSelected = 1 end
    if maxSelected then maxSelected = math.max(1, math.floor(maxSelected)) end
    local minSelected = math.max(0, math.floor(tonumber(opts.MinSelected) or 0))
    local replaceOnLimit = opts.ReplaceOnLimit
    if replaceOnLimit == nil then replaceOnLimit = single end
    local showHeader = opts.ShowHeader
    if showHeader == nil then showHeader = opts.Name ~= nil end
    if imageOnly then showHeader = false end
    local showCounter = showHeader and opts.ShowCounter ~= false and w >= 130

    local defs = {}
    local function normalize(source, index)
        local def = {}
        if type(source) == "table" then
            for key, value in pairs(source) do def[key] = value end
        else
            def.Name = tostring(source)
        end
        def.Name = tostring(def.Name or def.Title or def.Id or ("Card " .. tostring(index)))
        def.Id = tostring(def.Id or def.Name)
        return def
    end
    local function setDefs(list)
        defs = {}
        local used = {}
        for index, source in ipairs(list or {}) do
            local def = normalize(source, index)
            local base, suffix = def.Id, 1
            while used[def.Id] do
                suffix = suffix + 1
                def.Id = base .. "#" .. suffix
            end
            used[def.Id] = true
            defs[#defs + 1] = def
        end
    end
    setDefs(opts.Cards or opts.Items or opts.Options)

    local contentW = math.max(1, w - 20)
    gap = math.min(math.max(gap, math.ceil(strokeThickness) + 1), math.max(0, contentW - 1))
    local minTileW = math.min(56, contentW)
    columns = math.min(columns, math.max(1, math.floor((contentW + gap) / (minTileW + gap))))
    local tileW = math.floor((contentW - gap * (columns - 1)) / columns)
    radius = math.min(radius, math.floor(math.min(tileW, tileH) / 2))
    local gridWidth = columns * tileW + (columns - 1) * gap
    local gridInset = math.floor((contentW - gridWidth) / 2)
    local gridY = 10
    if showHeader then gridY = opts.Description and 44 or 30 end
    local totalRows = math.max(1, math.ceil(#defs / columns))
    local visibleRows = math.max(1, math.floor(tonumber(opts.Rows)
        or math.min(totalRows, math.max(1, math.floor(tonumber(opts.MaxRows) or 2)))))
    local gridH = visibleRows * tileH + (visibleRows - 1) * gap
    local card = self:_card(w, gridY + gridH + 10, name)
    local api = baseApi(self, card, flag)

    local title, counter
    if showHeader then
        title = text(card, name, 10, 10, math.max(1, w - (showCounter and 90 or 20)), 14, 12, white)
        if opts.Description then muted(card, opts.Description, 10, 26, w - 20, 14, 11) end
        bindTitle(api, title, opts)
    end
    if showCounter then counter = muted(card, "", w - 80, 10, 70, 14, 11, "right") end

    local PAD_IN = math.ceil(strokeThickness / 2) + 1
    local grid = new("ScrollingFrame", card, {
        Name = "Grid",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10 - PAD_IN, gridY - PAD_IN),
        Size = UDim2.fromOffset(contentW + PAD_IN * 2, gridH + PAD_IN * 2),
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 2,
    })
    local empty = muted(grid, tostring(opts.EmptyText or "Nothing found"), 0, 0,
        contentW + PAD_IN * 2, gridH + PAD_IN * 2, 11, "center")
    empty.Object.Visible = false

    connect(grid:GetPropertyChangedSignal("CanvasPosition"), function() window:Wake() end)
    local entries, byId = {}, {}
    local selected, order = {}, {}
    local filterText = ""
    local owner = Runtime.GetOwner()
    local tilesMaid
    local counterFlash = 0

    local function orderIndex(id)
        for index, value in ipairs(order) do
            if value == id then return index end
        end
    end
    local function snapshot()
        local copy = {}
        for index, id in ipairs(order) do copy[index] = id end
        return copy
    end
    local function selectedDefs()
        local list = {}
        for _, id in ipairs(order) do
            if byId[id] then list[#list + 1] = byId[id].Def end
        end
        return list
    end

    local function push(fire, def, isSelected)
        local copy = snapshot()
        Library.Flags[flag] = copy
        fireChange(flag, copy)
        if fire then
            if def and type(def.Callback) == "function" then Runtime.Spawn(def.Callback, isSelected, def) end
            if opts.Callback then Runtime.Spawn(opts.Callback, copy, def, isSelected) end
        end
    end

    local function reject(id, reason)
        local entry = byId[id]
        if entry then entry.Shake = 1 end
        counterFlash = 1
        if reason == "max" then
            if opts.OnLimit then Runtime.Spawn(opts.OnLimit, maxSelected, entry and entry.Def) end
            if opts.LimitNotify then
                local ok, message = pcall(string.format, tostring(opts.LimitText or "You can select up to %d"), maxSelected)
                Library:Notify({Title = name, Text = ok and message or tostring(opts.LimitText), Type = "warning", Duration = 2})
            end
        elseif reason == "min" then
            if opts.OnMinimum then Runtime.Spawn(opts.OnMinimum, minSelected, entry and entry.Def) end
        elseif reason == "locked" then
            if opts.OnLocked then Runtime.Spawn(opts.OnLocked, entry and entry.Def) end
        end
        if window.Wake then window:Wake(0.5) end
    end

    local function addSelection(id, force)
        local entry = byId[id]
        if not entry or selected[id] then return false end
        if not force and (entry.Def.Disabled or entry.Def.Locked) then
            reject(id, "locked")
            return false
        end
        local replaced
        if maxSelected and #order >= maxSelected then
            if replaceOnLimit then
                replaced = table.remove(order, 1)
                selected[replaced] = nil
            else
                if not force then reject(id, "max") end
                return false
            end
        end
        selected[id] = true
        order[#order + 1] = id
        return true, replaced
    end

    local function removeSelection(id, force)
        if not selected[id] then return false end
        if not force and #order <= minSelected then
            reject(id, "min")
            return false
        end
        selected[id] = nil
        local index = orderIndex(id)
        if index then table.remove(order, index) end
        return true
    end

    local function toggleId(id)
        local entry = byId[id]
        if not entry then return end
        if opts.OnCardClick then Runtime.Spawn(opts.OnCardClick, entry.Def, selected[id] == true) end
        if selected[id] then
            if removeSelection(id) then push(true, entry.Def, false) end
        else
            local ok, replaced = addSelection(id)
            if ok then
                local old = replaced and byId[replaced]
                if old and type(old.Def.Callback) == "function" then Runtime.Spawn(old.Def.Callback, false, old.Def) end
                push(true, entry.Def, true)
            end
        end
    end

    local function matches(def, query)
        if def.Hidden == true then return false end
        if query == "" then return true end
        if type(opts.Filter) == "function" then
            local ok, result = pcall(opts.Filter, def, query)
            if ok then return result and true or false end
        end
        local hay = foldText(def.Name .. " " .. tostring(def.Description or def.Subtitle or "") .. " "
            .. (normalizeKeywords(def.Keywords or def.Tags) or "") .. " " .. tostring(def.Rarity or ""))
        for word in string.gmatch(query, "%S+") do
            if not string.find(hay, word, 1, true) then return false end
        end
        return true
    end

    local function layout(instant)
        local query = foldText(filterText)
        local index = 0
        for _, entry in ipairs(entries) do
            local visible = matches(entry.Def, query)
            local wasVisible = entry.Tile.Visible
            entry.Tile.Visible = visible
            if visible then
                entry.OffscreenSettled = false
                entry.TX = PAD_IN + gridInset + (index % columns) * (tileW + gap)
                entry.TY = PAD_IN + math.floor(index / columns) * (tileH + gap)
                if instant or not entry.Placed or not wasVisible then
                    entry.X, entry.Y, entry.Placed = entry.TX, entry.TY, true
                    if not instant then entry.Scale = 0.85 end
                end
                index = index + 1
            end
        end
        local rows = math.max(1, math.ceil(index / columns))
        local canvasH = index == 0 and 0 or (PAD_IN * 2 + rows * tileH + (rows - 1) * gap)
        grid.CanvasSize = UDim2.fromOffset(0, canvasH)
        grid.CanvasPosition = Vector2.new(0, math.clamp(grid.CanvasPosition.Y, 0,
            math.max(0, canvasH - grid.Size.Y.Offset)))
        empty.Object.Visible = index == 0
        if window.Wake then window:Wake(0.5) end
    end

    local function buildTile(def)
        local tile = rect(grid, 0, 0, tileW, tileH, palette[4], radius, "TextButton")
        tile.Name = def.Id
        tile.ZIndex = 3
        tile.BackgroundTransparency = 1
        local surface = rect(tile, 0, 0, tileW, tileH, palette[4], radius, "CanvasGroup")
        surface.Name = "RoundedContent"
        surface.BackgroundTransparency = 1
        surface.Active = false
        surface.Visible = false
        surface.ZIndex = 3
        local body = rect(surface, 0, 0, tileW, tileH, palette[4])
        body.Name = "Background"
        body.BackgroundTransparency = 0.16
        body.ZIndex = 3
        new("UIGradient", body, {
            Rotation = 105,
            Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220)),
        })
        local stroke = new("UIStroke", tile, {Thickness = 1, Transparency = 0.45})
        stroke.Color = palette[5]
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        local uiScale = new("UIScale", tile, {Scale = 1})

        local inset = imageOnly and 4 or 6
        local subtitle = def.Description or def.Subtitle
        if tileH < 54 then subtitle = nil end
        local textH = showTitles and (subtitle and 32 or 20) or 0
        local imgW = math.max(1, tileW - inset * 2)
        local imageH = math.max(1, tileH - inset * 2 - textH)
        local innerRadius = math.min(math.max(0, radius - inset), math.floor(math.min(imgW, imageH) / 2))
        local rarity = resolveColor(def.Color or def.Rarity, nil)

        local holder
        if imageBackground then
            holder = rect(surface, inset, inset, imgW, imageH, palette[1], innerRadius)
            holder.BackgroundTransparency = 0.35
        else
            holder = rect(surface, inset, inset, imgW, imageH, palette[1], innerRadius)
            holder.BackgroundTransparency = 1
        end
        holder.ZIndex = 3
        holder.ClipsDescendants = true
        if rarity and opts.RarityGlow ~= false then
            local glow = rect(holder, 0, 0, imgW, imageH, rarity, innerRadius)
            glow.ZIndex = 3
            new("UIGradient", glow, {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0.6),
                }),
            })
            local line = rect(holder, innerRadius, math.max(0, imageH - 2),
                math.max(0, imgW - innerRadius * 2), math.min(2, imageH), rarity, 1)
            line.ZIndex = 4
        end

        local image, iconApi
        local imageId = directIcon(def.Image or def.Photo or def.Thumbnail)
        if imageId then
            local pad = math.min(imagePadding, math.floor((math.min(imgW, imageH) - 1) / 2))
            local imageW, imageHeight = imgW - pad * 2, imageH - pad * 2
            local rotation = tonumber(def.ImageRotation) or 0
            if rotation % 180 ~= 0 then
                local guard = math.ceil(innerRadius * (1 - 1 / math.sqrt(2)))
                pad = math.min(math.max(pad, guard), math.floor((math.min(imgW, imageH) - 1) / 2))
                imageW, imageHeight = imgW - pad * 2, imageH - pad * 2
                local radians = math.rad(rotation)
                local c, sn = math.abs(math.cos(radians)), math.abs(math.sin(radians))
                local factor = math.min(1, imageW / (imageW * c + imageHeight * sn),
                    imageHeight / (imageW * sn + imageHeight * c))
                imageW = math.max(1, math.floor(imageW * factor))
                imageHeight = math.max(1, math.floor(imageHeight * factor))
            end
            image = new("ImageLabel", holder, {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset((imgW - imageW) / 2, (imageH - imageHeight) / 2),
                Size = UDim2.fromOffset(imageW, imageHeight),
                Image = imageId,
                ImageColor3 = resolveColor(def.ImageColor, pureWhite),
                ScaleType = scaleTypeOf(def.ImageScale or opts.ImageScale),
                Rotation = rotation,
                ZIndex = 5,
            })
            local imageRadius = math.min(math.max(0, innerRadius - pad), math.min(imageW, imageHeight) / 2)
            if imageRadius > 0 then
                new("UICorner", image, {CornerRadius = UDim.new(0, imageRadius)})
            end
            if typeof(def.ImageRectOffset) == "Vector2" then image.ImageRectOffset = def.ImageRectOffset end
            if typeof(def.ImageRectSize) == "Vector2" then image.ImageRectSize = def.ImageRectSize end
        else
            local iconSize = math.floor(math.min(imgW, imageH) * 0.5)
            iconApi = iconLabel(holder, def.Icon or opts.DefaultIcon or {"image", "package", "box"},
                (imgW - iconSize) / 2, (imageH - iconSize) / 2, iconSize, palette[3],
                string.upper(string.sub(def.Name, 1, 1)))
            iconApi.Object.ZIndex = 5
        end

        local titleLabel, subLabel
        if showTitles then
            titleLabel = text(surface, def.Name, inset, inset + imageH + 4, imgW, 14, titleSize, palette[3], titleAlign,
                {Bold = opts.BoldTitles == true})
            titleLabel.Object.ZIndex = 4
            if subtitle then
                subLabel = text(surface, subtitle, inset, inset + imageH + 17, imgW, 12, 10, palette[3], titleAlign)
                subLabel.Object.ZIndex = 4
            end
        end

        if def.Badge and not imageOnly then
            local caption = tostring(def.Badge)
            local bw = math.max(1, math.min(imgW - 8, TextService:GetTextSize(caption, 9, UI_FONT_BOLD, Vector2.new(1000, 14)).X + 10))
            local badge = rect(surface, 10, 10, bw, 14, resolveColor(def.BadgeColor, rarity or accent), 3)
            badge.ZIndex = 6
            local badgeText = text(badge, caption, 0, 0, bw, 14, 9, pureWhite, "center", {Bold = true})
            badgeText.Object.ZIndex = 7
            badgeText:Color(resolveColor(def.BadgeTextColor, pureWhite))
        end

        local check, checkStroke, checkFill, checkMark, orderLabel
        if showCheck then
            local size = 14
            local cx = string.find(checkPosition, "left", 1, true) and 10 or (tileW - 10 - size)
            local cy = string.find(checkPosition, "bottom", 1, true) and math.max(10, inset + imageH - 4 - size) or 10
            local round = checkShape == "circle" and 7 or 3
            check = rect(surface, cx, cy, size, size, palette[1], round)
            check.ZIndex = 6
            check.BackgroundTransparency = 0.15
            checkStroke = new("UIStroke", check, {Thickness = 1, Transparency = 0.3})
            checkStroke.Color = palette[5]
            checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            checkFill = rect(check, 7, 7, 0, 0, accent, round)
            checkFill.ZIndex = 7
            if showOrder then
                orderLabel = text(check, "", 0, 0, size, size, 9, pureWhite, "center", {Bold = true})
                orderLabel.Object.ZIndex = 8
                orderLabel:Color(pureWhite)
            else
                checkMark = iconLabel(check, {"check"}, 1, 1, 12, black, "v")
                checkMark.Object.ZIndex = 8
            end
        end

        local lock
        if def.Locked or def.Disabled then
            lock = iconLabel(surface, def.LockIcon or opts.LockIcon or {"lock", "lock-keyhole"},
                (tileW - 16) / 2, inset + (imageH - 16) / 2, 16, white, "x")
            lock.Object.ZIndex = 9
        end

        local entry = {
            Def = def, Id = def.Id, Tile = tile, Surface = surface, Body = body, Stroke = stroke, UIScale = uiScale,
            Image = image, IconApi = iconApi, Title = titleLabel, Sub = subLabel,
            SubColor = resolveColor(def.SubtitleColor, opts.RaritySubtitle and rarity or nil),
            Check = check, CheckStroke = checkStroke, CheckFill = checkFill, CheckMark = checkMark,
            Order = orderLabel, Lock = lock, Rarity = rarity,
            Sel = selected[def.Id] and 1 or 0, Hov = 0, Scale = 1, Shake = 0,
            X = 0, Y = 0, TX = 0, TY = 0,
        }
        connect(tile.MouseEnter, function() entry.Hovered = true end)
        connect(tile.MouseLeave, function() entry.Hovered = false; entry.Pressed = false end)
        connect(tile.MouseButton1Down, function() entry.Pressed = true end)
        connect(tile.MouseButton1Up, function() entry.Pressed = false end)
        connect(tile.Activated, function()
            entry.Pressed = false
            toggleId(def.Id)
        end)
        if def.OnRightClick or opts.OnRightClick then
            connect(tile.MouseButton2Click, function()
                local callback = def.OnRightClick or opts.OnRightClick
                Runtime.Spawn(callback, def, selected[def.Id] == true)
            end)
        end
        if def.Tooltip then window:Tooltip(tile, def.Tooltip) end
        return entry
    end

    local function rebuild()
        if tilesMaid then tilesMaid:Destroy() end
        tilesMaid = Maid.new(owner)
        entries, byId = {}, {}
        withOwner(tilesMaid, function()
            for _, def in ipairs(defs) do
                local entry = buildTile(def)
                tilesMaid:Add(entry.Tile)
                entries[#entries + 1] = entry
                byId[def.Id] = entry
            end
        end)
        for index = #order, 1, -1 do
            if not byId[order[index]] then
                selected[order[index]] = nil
                table.remove(order, index)
            end
        end
        layout(true)
    end

    step(function(dt, k)
        local tintBase = resolveColor(opts.SelectedColor, accent)
        local fast = motionFactor(24, dt)
        local busy = false
        if counter then
            counterFlash = math.max(0, counterFlash - dt * 2)
            local count = #order
            local caption
            if type(opts.CounterFormat) == "function" then
                local ok, result = pcall(opts.CounterFormat, count, maxSelected)
                caption = ok and tostring(result) or ""
            elseif type(opts.CounterFormat) == "string" then
                local ok, result = pcall(string.format, opts.CounterFormat, count, maxSelected or 0)
                caption = ok and result or ""
            elseif maxSelected then
                caption = string.format("%d/%d", count, maxSelected)
            else
                caption = tostring(count)
            end
            counter:SetText(caption)
            local full = maxSelected ~= nil and count >= maxSelected
            counter:Color(palette[3]:Lerp(tintBase, full and 1 or 0):Lerp(Color3.fromRGB(240, 100, 100), counterFlash))
            if counterFlash > 0 then busy = true end
        end
        local viewportTop = grid.CanvasPosition.Y - 8
        local viewportBottom = grid.CanvasPosition.Y + grid.Size.Y.Offset + 8
        for _, e in ipairs(entries) do
            if e.Tile.Visible and math.min(e.Y, e.TY) + tileH >= viewportTop
                and math.max(e.Y, e.TY) <= viewportBottom then
                if not e.Surface.Visible then e.Surface.Visible = true end
                e.OffscreenSettled = false
                local isSel = selected[e.Id] == true
                local locked = e.Def.Disabled or e.Def.Locked
                e.Sel = approach(e.Sel, isSel and 1 or 0, k)
                e.Hov = approach(e.Hov, (e.Hovered and not locked) and 1 or 0, k)
                e.Scale = approach(e.Scale, e.Pressed and 0.94 or 1, fast)
                e.X = approach(e.X, e.TX, k)
                e.Y = approach(e.Y, e.TY, k)
                local shakeX = 0
                if e.Shake > 0 then
                    e.Shake = math.max(0, e.Shake - dt * 3)
                    shakeX = math.sin(e.Shake * 38) * 4 * e.Shake
                    busy = true
                end
                if math.abs(e.X - e.TX) > 0.5 or math.abs(e.Y - e.TY) > 0.5 or math.abs(e.Scale - 1) > 0.005 then
                    busy = true
                end
                e.Tile.Position = UDim2.fromOffset(
                    roundPixel(e.X + shakeX + tileW * (1 - e.Scale) / 2),
                    roundPixel(e.Y + tileH * (1 - e.Scale) / 2))
                e.UIScale.Scale = e.Scale
                local tint = (useCardColor and e.Rarity) or tintBase
                e.Body.BackgroundColor3 = palette[4]:Lerp(palette[5], e.Hov * 0.7)
                    :Lerp(tint, e.Sel * 0.16 * state.AccentAlpha)
                e.Stroke.Color = palette[5]:Lerp(tint, e.Sel)
                e.Stroke.Transparency = 0.4 * (1 - e.Sel)
                e.Stroke.Thickness = 1 + (strokeThickness - 1) * e.Sel
                local dim = locked and 0.45 or 1
                if e.Title then
                    e.Title:Color(palette[3]:Lerp(white, math.max(e.Sel, e.Hov * 0.6)))
                    e.Title:Alpha(dim)
                end
                if e.Sub then
                    e.Sub:Color(e.SubColor or palette[3])
                    e.Sub:Alpha(dim)
                end
                if e.Image then e.Image.ImageTransparency = 1 - dim end
                if e.IconApi then
                    e.IconApi:Color(palette[3]:Lerp(white, math.max(e.Sel, e.Hov)))
                    e.IconApi:Alpha(dim)
                end
                if e.Check then
                    local a = e.Sel
                    e.CheckFill.Position = UDim2.fromOffset(roundPixel(7 * (1 - a)), roundPixel(7 * (1 - a)))
                    e.CheckFill.Size = UDim2.fromOffset(roundPixel(14 * a), roundPixel(14 * a))
                    e.CheckFill.BackgroundColor3 = tint
                    e.CheckFill.BackgroundTransparency = 1 - a * state.AccentAlpha
                    e.CheckStroke.Color = palette[5]:Lerp(tint, a)
                    if e.CheckMark then e.CheckMark:Alpha(a) end
                    if e.Order then
                        local position = orderIndex(e.Id)
                        e.Order:SetText(position and tostring(position) or "")
                        e.Order:Alpha(a)
                    end
                    e.Check.Visible = checkStyle ~= "selected" or a > 0.01 or e.Hov > 0.01
                end
            elseif e.Tile.Visible then
                if e.Surface.Visible then e.Surface.Visible = false end
                e.X, e.Y = e.TX, e.TY
                e.Scale, e.Hov, e.Shake = 1, 0, 0
                e.Sel = selected[e.Id] and 1 or 0
                if not e.OffscreenSettled then
                    e.Tile.Position = UDim2.fromOffset(e.TX, e.TY)
                    e.UIScale.Scale = 1
                    e.OffscreenSettled = true
                end
            end
        end
        if busy and window.Wake then window:Wake(0.15) end
    end, card)

    function api:Get() return snapshot() end
    function api:GetSelected() return selectedDefs() end
    function api:IsSelected(id) return selected[tostring(id)] == true end
    function api:Select(id, silent)
        id = tostring(id)
        local ok = addSelection(id)
        if ok then push(not silent, byId[id].Def, true) end
        return ok == true
    end
    function api:Deselect(id, silent)
        id = tostring(id)
        local ok = removeSelection(id, true)
        if ok then push(not silent, byId[id] and byId[id].Def, false) end
        return ok
    end
    function api:ToggleCard(id) toggleId(tostring(id)) end
    function api:Set(value, silent)
        selected, order = {}, {}
        local list = {}
        if type(value) == "table" then
            if value[1] ~= nil then
                for _, item in ipairs(value) do list[#list + 1] = tostring(item) end
            else
                for key, item in pairs(value) do
                    if item == true then list[#list + 1] = tostring(key) end
                end
            end
        elseif value ~= nil then
            list[1] = tostring(value)
        end
        for _, id in ipairs(list) do addSelection(id, true) end
        push(not silent)
    end
    function api:Clear(silent)
        selected, order = {}, {}
        push(not silent)
    end
    function api:SelectAll(silent)
        for _, e in ipairs(entries) do
            if maxSelected and #order >= maxSelected then break end
            if not (e.Def.Disabled or e.Def.Locked) and not selected[e.Id] then addSelection(e.Id, true) end
        end
        push(not silent)
    end
    function api:SetMax(value)
        maxSelected = tonumber(value) and math.max(1, math.floor(tonumber(value))) or nil
        while maxSelected and #order > maxSelected do
            selected[table.remove(order)] = nil
        end
        push(false)
        return maxSelected
    end
    function api:GetMax() return maxSelected end
    function api:SetMin(value) minSelected = math.max(0, math.floor(tonumber(value) or 0)) end
    function api:SetReplaceOnLimit(value) replaceOnLimit = value == true end
    function api:SetCards(list)
        setDefs(list)
        rebuild()
        push(false)
    end
    function api:GetCards() return defs end
    function api:GetCard(id)
        local entry = byId[tostring(id)]
        return entry and entry.Def
    end
    function api:AddCard(def, index)
        local list = {}
        for i, item in ipairs(defs) do list[i] = item end
        local position = math.clamp(math.floor(tonumber(index) or (#list + 1)), 1, #list + 1)
        table.insert(list, position, def)
        self:SetCards(list)
        return defs[position]
    end
    function api:RemoveCard(id)
        id = tostring(id)
        local list = {}
        for _, item in ipairs(defs) do
            if item.Id ~= id then list[#list + 1] = item end
        end
        self:SetCards(list)
    end
    function api:UpdateCard(id, changes)
        local entry = byId[tostring(id)]
        if not entry or type(changes) ~= "table" then return nil end
        for key, value in pairs(changes) do entry.Def[key] = value end
        entry.Def.Id = tostring(id)
        rebuild()
        return entry.Def
    end
    function api:SetCardDisabled(id, value) return self:UpdateCard(id, {Disabled = value and true or false}) end
    function api:SetCardHidden(id, value) return self:UpdateCard(id, {Hidden = value and true or false}) end
    function api:SetFilter(value)
        filterText = tostring(value or "")
        layout(false)
    end
    function api:GetFilter() return filterText end
    function api:ScrollTo(id)
        local entry = byId[tostring(id)]
        if entry and entry.Tile.Visible then
            local maxY = math.max(0, grid.CanvasSize.Y.Offset - grid.Size.Y.Offset)
            grid.CanvasPosition = Vector2.new(0, math.clamp(entry.TY - PAD_IN, 0, maxY))
        end
    end
    api.Grid = grid

    rebuild()
    local defaults = opts.Default
    if defaults == nil then
        defaults = {}
        for _, def in ipairs(defs) do
            if def.Selected or def.Default then defaults[#defaults + 1] = def.Id end
        end
    end
    api:Set(defaults, true)
    if opts.Callback and #order > 0 then Runtime.Spawn(opts.Callback, snapshot()) end
    return api
end

function Tab:AddCards(opts) return self:AddCardGrid(opts) end
function Tab:AddCardSelector(opts) return self:AddCardGrid(opts) end

function Window:AddSearch() return nil end
function Library:AddSearch() return nil end
function Library:GetSearch() return nil end
function Library:AddTheme() return nil end
function Library:SetTheme()
    state.Theme, self.Theme = 1, 1
    return "Black"
end
function Library:GetTheme() return "Black", 1 end
function Library:GetThemes() return {"Black"} end
function Library:SetPaletteColor() return nil end

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
    local heading = self:AddSection(opts.Name or "Configs")

    if not Library:HasDefaults() then
        (Runtime.GetOwner() or Library.Maid):Delay(0, function()
            if not Library:HasDefaults() then Library:CaptureDefaults() end
        end)
    end

    local nameFlag = self.Name .. ".ConfigName"
    local pickerFlag = self.Name .. ".ConfigPick"

    local function say(message)
        Library:Notify({Title = "Configs", Text = tostring(message)})
    end

    local function guard(callback)
        return function(...)
            local ok, err = Library:Safe(callback, ...)
            if not ok then say(string.match(tostring(err), "^[^\n]*") or "error") end
        end
    end

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

    local selectionButtons = {}
    local controls = {heading, nameBox, picker}
    local managerEnabled = true

    local function refresh()
        picker:SetOptions(Library:ListConfigs())
        local available = picker:HasOptions()
        for _, button in ipairs(selectionButtons) do button:SetEnabled(available and managerEnabled) end
        return available
    end

    local function chosen()
        local value = nameBox:Get()
        if value == nil or value == "" then value = picker:Get() end
        if value == nil or value == "" then value = "default" end
        return value
    end

    local function needsSelection(button)
        selectionButtons[#selectionButtons + 1] = button
        controls[#controls + 1] = button
        return button
    end

    controls[#controls + 1] = self:AddButton({
        Name = "Save config",
        AutoLoading = true,
        Text = "Save",
        Compact = true,
        Width = 0.33,
        Callback = guard(function()
            local name = chosen()
            local ok, result = Library:SaveConfigFile(name)
            if ok then refresh() end
            say(ok and ("Saved: " .. tostring(name)) or result)
        end),
    })

    needsSelection(self:AddButton({
        Name = "Load config",
        AutoLoading = true,
        Text = "Load",
        Compact = true,
        Width = 0.33,
        Callback = guard(function()
            local name = chosen()
            local ok, detail = Library:LoadConfigFile(name)
            if not ok then say(detail) return end
            local extra = ""
            if type(detail) == "table" then
                extra = string.format(" (%d applied", detail.Applied or 0)
                if (detail.Unknown or 0) > 0 then extra = extra .. string.format(", %d unknown", detail.Unknown) end
                extra = extra .. ")"
                if detail.Recovered then extra = extra .. " restored from backup " .. tostring(detail.Recovered) end
                if detail.Tampered then extra = extra .. ", file edited outside" end
            end
            say("Loaded: " .. tostring(name) .. extra)
        end),
    }))

    needsSelection(self:AddButton({
        Name = "Delete config",
        Text = "Delete",
        Compact = true,
        Width = 0.33,
        Callback = guard(function()
            local name = chosen()
            Library:Dialog({
                Title = "Delete config?",
                Text = "This will permanently delete the " .. tostring(name) .. " config and its backups.",
                ConfirmText = "Delete",
                CancelText = "Cancel",
                Confirm = guard(function()
                    local ok, result = Library:DeleteConfigFile(name)
                    if ok then refresh() end
                    say(ok and ("Deleted: " .. tostring(name)) or result)
                end),
            })
        end),
    }))

    controls[#controls + 1] = self:AddButton({
        Name = "Refresh configs",
        Text = "Refresh",
        Compact = true,
        Width = 0.33,
        Callback = guard(function()
            refresh()
        end),
    })

    refresh()

    return {
        Refresh = refresh,
        Name = nameBox,
        Picker = picker,
        Heading = heading,
        Controls = controls,
        SetValue = function(_, value, silent) return nameBox:Set(value, silent) end,
        Get = function() return nameBox:Get() end,
        SetVisible = function(_, visible)
            for _, control in ipairs(controls) do control:SetVisible(visible) end
        end,
        SetEnabled = function(_, enabled)
            managerEnabled = enabled ~= false
            for _, control in ipairs(controls) do control:SetEnabled(enabled) end
            if enabled ~= false then refresh() end
        end,
    }
end

Library.CardNotificationVersion="5.9.3"
Library.CardNotificationRevision="7.0.0"
function Library:NotifyCards(opts)
    opts=opts or {}
    local window=self.Window
    if not window or not window.Gui or not window.Gui.Parent then return nil end
    local maid=Maid.new(Library.Maid)
    local ok,result=pcall(function()
    local api={Maid=maid,Destroyed=false,Closing=false,Selected=nil,Cards={}}
    local width,height=296,142
    local colors=Library.Palette or palette
    local tweenService=game:GetService("TweenService")
    local panel=rect(window.Gui,0,0,width,height,colors[2],10,"CanvasGroup")
    panel.Name="CardNotification"
    panel.AnchorPoint=Vector2.new(0,0)
    panel.ZIndex=80
    panel.GroupTransparency=1
    panel.BackgroundTransparency=0.20
    panel.ClipsDescendants=true
    maid:Add(panel)
    api.Object=panel
    local scale=new("UIScale",panel,{Scale=1})
    new("UIStroke",panel,{Color=colors[5],Thickness=1,Transparency=0.56})
    new("UIGradient",panel,{Rotation=105,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(220,220,220))})
    local function label(parent,caption,x,y,w,h,size,color,bold)
        return new("TextLabel",parent,{BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Text=tostring(caption),
            Font=bold and UI_FONT_BOLD or UI_FONT,TextSize=size,TextColor3=color or white,
            TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=82})
    end
    label(panel,opts.Title or "Map vote",10,8,151,16,11,colors[3],true)
    local subtitle=label(panel,opts.Text or "Choose a map",10,25,width-20,13,9,colors[3])
    subtitle.TextTransparency=0.36
    local control=rect(panel,171,8,82,22,colors[4],6)
    control.ZIndex=85;control.BackgroundTransparency=0.16
    local value=label(control,"10",21,0,40,22,11,colors[3],true)
    value.TextXAlignment=Enum.TextXAlignment.Center;value.ZIndex=87
    local countValue=math.clamp(math.floor(tonumber(opts.Value) or 10),1,100)
    local minus=rect(control,0,0,21,22,colors[4],6,"TextButton")
    local plus=rect(control,61,0,21,22,colors[4],6,"TextButton")
    for _,button in ipairs({minus,plus}) do button.ZIndex=88;button.TextColor3=colors[3];button.TextSize=14;button.BackgroundTransparency=1 end
    minus.Text="−";plus.Text="+"
    api.ValueLabel=value
    function api:SetValue(number,silent)
        if self.Destroyed or self.Closing then return end
        countValue=math.clamp(math.floor(tonumber(number) or 10),1,100)
        self.Value=countValue;value.Text=tostring(countValue)
        if not silent and opts.ValueChanged then Runtime.InvokeOwned(maid, opts.ValueChanged, countValue, self) end
    end
    maid:Connect(minus.Activated,function() api:SetValue(countValue-1) end)
    maid:Connect(plus.Activated,function() api:SetValue(countValue+1) end)
    api:SetValue(countValue,true)
    local close=rect(panel,width-33,7,23,23,colors[4],6,"TextButton")
    close.ZIndex=89;close.BackgroundTransparency=1;close.Text="×";close.TextSize=17;close.TextColor3=colors[3]
    local cells={}
    local function applySelected()
        for _,cell in ipairs(cells) do
            local on=cell.Def and tostring(cell.Def.Id)==api.Selected
            cell.Edge.Transparency=on and 0 or 0.4
            cell.Edge.Color=on and colors[3] or colors[5]
            local tint=Library.Accent or colors[3]
            cell.Edge.Color=on and tint or colors[5]
            cell.CheckFill.BackgroundColor3=tint
            cell.CheckFill.BackgroundTransparency=on and (1-(Library.AccentAlpha or 1)) or 1
            cell.CheckFill.Size=UDim2.fromOffset(on and 14 or 0,on and 14 or 0)
            cell.CheckFill.Position=UDim2.fromOffset(on and 0 or 7,on and 0 or 7)
            cell.CheckMark:Alpha(on and 1 or 0)
            cell.CheckStroke.Color=on and tint or colors[5]
        end
    end
    for index=1,3 do
        local x=10+(index-1)*94
        local group=rect(panel,x,44,88,88,colors[4],7,"CanvasGroup")
        group.ZIndex=82;group.ClipsDescendants=true;group.BackgroundTransparency=0.16
        new("UIGradient",group,{Rotation=105,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(220,220,220))})
        local cellScale=new("UIScale",group,{Scale=1})
        local edge=new("UIStroke",group,{Color=colors[5],Thickness=1,Transparency=0.55})
        local image=new("ImageLabel",group,{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(76,60),
            BackgroundColor3=colors[1],BackgroundTransparency=0.35,BorderSizePixel=0,
            Image="",ScaleType=Enum.ScaleType.Crop,ZIndex=83})
        new("UICorner",image,{CornerRadius=UDim.new(0,3)})
        local placeholder=label(group,"",6,21,76,30,18,colors[3],true)
        placeholder.TextXAlignment=Enum.TextXAlignment.Center
        local title=label(group,"",6,71,76,14,9,colors[3],false)
        title.TextXAlignment=Enum.TextXAlignment.Center;title.ZIndex=85
        local pill=rect(group,10,9,20,17,colors[2],5);pill.BackgroundTransparency=0.1;pill.ZIndex=85
        local count=label(pill,"0",0,0,20,17,9,colors[3],true);count.ZIndex=86;count.TextXAlignment=Enum.TextXAlignment.Center
        local check=rect(group,64,10,14,14,colors[1],3)
        check.ZIndex=85;check.BackgroundTransparency=0.15
        local checkStroke=new("UIStroke",check,{Color=colors[5],Thickness=1,Transparency=0.3})
        checkStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        local checkFill=rect(check,7,7,0,0,Library.Accent or colors[3],3);checkFill.ZIndex=86
        local checkMark=Library:CreateCheckMark(check,1,1,12,Color3.new(0,0,0))
        checkMark.Object.ZIndex=87;checkMark:Alpha(0)
        local button=new("TextButton",group,{Text="",BackgroundTransparency=1,AutoButtonColor=false,
            Size=UDim2.fromScale(1,1),ZIndex=90})
        local cell={Group=group,Image=image,Placeholder=placeholder,Title=title,Count=count,Check=check,CheckFill=checkFill,CheckMark=checkMark,CheckStroke=checkStroke,Edge=edge}
        cells[index]=cell
        local function hover(on)
            if api.Destroyed or api.Closing then return end
            local tween=tweenService:Create(cellScale,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=on and 0.97 or 1})
            maid:Add(tween,"hover"..index);tween:Play()
        end
        maid:Connect(button.MouseEnter,function() hover(true) end)
        maid:Connect(button.MouseLeave,function() hover(false) end)
        maid:Connect(button.Activated,function()
            if api.Destroyed or api.Closing or not cell.Def or cell.Def.Disabled then return end
            local selected=true
            if opts.ToggleSelection==true and api.Selected==tostring(cell.Def.Id) then selected=false end
            if selected then api:SetSelected(cell.Def.Id) else api:SetSelected(nil) end
            if opts.Callback then Runtime.InvokeOwned(maid, opts.Callback, cell.Def.Id, cell.Def, api, selected) end
            if not api.Destroyed and opts.CloseOnSelect==true then api:Close("selected") end
        end)
    end
    function api:SetCards(cards)
        if self.Destroyed or self.Closing then return end
        self.Cards={}
        for index,cell in ipairs(cells) do
            local def=cards and cards[index]
            cell.Def=def
            cell.Group.Visible=def~=nil
            if def then
                self.Cards[index]=def
                if cell.Image.Image~=tostring(def.Image or "") then cell.Image.Image=tostring(def.Image or "") end
                cell.Placeholder.Visible=not def.Image or def.Image==""
                if cell.Title.Text~=tostring(def.Name or def.Title or "Map") then cell.Title.Text=tostring(def.Name or def.Title or "Map") end
                if cell.Placeholder.Text~=tostring(def.Name or "?"):sub(1,2):upper() then cell.Placeholder.Text=tostring(def.Name or "?"):sub(1,2):upper() end
                if cell.Count.Text~=tostring(def.Count or 0) then cell.Count.Text=tostring(def.Count or 0) end
            end
        end
        applySelected()
    end
    function api:SetSelected(id)
        if self.Destroyed then return end
        local selected=id~=nil and tostring(id) or nil
        if self.Selected==selected then return end
        self.Selected=selected
        applySelected()
    end
    function api:SetText(value)
        if not self.Destroyed then
            local caption=tostring(value or "")
            if subtitle.Text~=caption then subtitle.Text=caption end
        end
    end
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        maid:Destroy()
    end
    maid:Add(function() api.Destroyed = true end)
    function api:Close(reason)
        if self.Destroyed or self.Closing then return end
        self.Closing=true
        if opts.OnClose then Runtime.InvokeOwned(maid, opts.OnClose, reason or "manual", self) end
        if self.Destroyed then return end
        panel.Interactable = false
        local tween=tweenService:Create(panel,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=1,Position=panel.Position+UDim2.fromOffset(0,8)})
        maid:Add(tween,"fade")
        maid:Once(tween.Completed,function() self:Destroy() end)
        tween:Play()
    end
    maid:Connect(close.Activated,function() api:Close("manual") end)
    local targetPosition
    local function layout()
        local view=window.Gui.AbsoluteSize
        if view.X<=0 or view.Y<=0 then view=window.Viewport end
        local factor=math.min(1,math.max(0.1,(view.X-24)/width),math.max(0.1,(view.Y-24)/height))
        scale.Scale=factor
        targetPosition=UDim2.new(0,12,0,math.max(12,math.min(66,view.Y-height*factor-12)))
        panel.Position=targetPosition
    end
    maid:Connect(window.Gui:GetPropertyChangedSignal("AbsoluteSize"),layout)
    layout()
    panel.Position=targetPosition+UDim2.fromOffset(0,12)
    api:SetCards(opts.Cards or {})
    local tween=tweenService:Create(panel,TweenInfo.new(0.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{GroupTransparency=0,Position=targetPosition})
    maid:Add(tween,"fade");tween:Play()
    return api
    end)
    if not ok then maid:Destroy();error(result,0) end
    return result
end

function Library:SetNotificationOptions(opts)
    opts = opts or {}
    local config = self.NotificationOptions
    if opts.Width ~= nil then config.Width = math.clamp(roundPixel(tonumber(opts.Width) or 250), 220, 360) end
    if opts.MaxVisible ~= nil then config.MaxVisible = math.clamp(math.floor(tonumber(opts.MaxVisible) or 5), 1, 12) end
    if opts.Gap ~= nil then config.Gap = math.clamp(roundPixel(tonumber(opts.Gap) or 8), 4, 24) end
    if opts.Position ~= nil then config.Position = opts.Position == "Left" and "Left" or "Right" end
    if opts.PauseOnHover ~= nil then config.PauseOnHover = opts.PauseOnHover ~= false end
    local window = self.Window
    if window and window.LayoutNotifications then window.LayoutNotifications() end
    if window then
        while #window.Notifications > config.MaxVisible do window.Notifications[1]:Destroy() end
    end
    return self
end

function Library:GetNotifications()
    local list = {}
    for _, notification in ipairs(self.Window and self.Window.Notifications or {}) do
        if not notification.Destroyed then list[#list + 1] = notification end
    end
    return list
end

function Library:ClearNotifications(instant)
    local notifications = self:GetNotifications()
    for _, notification in ipairs(notifications) do
        if instant then notification:Destroy() else notification:Close() end
    end
end

function Library:Notify(opts)
    opts = type(opts) == "table" and opts or {Text = opts}
    local window = self.Window
    if not window or not window.Gui or not window.Gui.Parent then return end
    local config, id = self.NotificationOptions, opts.Id and tostring(opts.Id) or nil
    local existing = id and window.NotificationIds[id]
    if existing and not existing.Destroyed then
        existing:Update(opts)
        return existing
    end
    while #window.Notifications >= config.MaxVisible do window.Notifications[1]:Destroy() end
    local width, body = config.Width, tostring(opts.Text or "")
    local title = opts.Title and tostring(opts.Title) or ""
    local bounds = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(width - 58, 10000))
    local maximumBody = math.max(14, math.min(160, window.Viewport.Y - 90))
    local height = (title ~= "" and 26 or 10) + math.min(maximumBody, math.max(14, bounds.Y)) + 10
    local object = rect(window.NotifyHolder, width + 10, 0, width, height, palette[2], 8, "TextButton")
    object.Name = "Notification"
    object.BackgroundTransparency = 0.20
    object.ClipsDescendants = true
    new("UIStroke", object, {Color = palette[5], Thickness = 1, Transparency = 0.65})
    local bar = rect(object, 0, 0, 2, height, accent)
    local progress = rect(object, 0, height - 2, width, 2, accent)
    progress.BackgroundTransparency = 0.35
    local icon = iconLabel(object, {"info", "bell"}, 12, 10, 14, accent, "!")
    local titleLabel = text(object, title, 34, 8, width - 58, 14, 12, white)
    titleLabel.Object.Visible = title ~= ""
    local bodyLabel = muted(object, body, 34, title ~= "" and 26 or 10, width - 58,
        height - (title ~= "" and 26 or 10) - 10, 11, nil, {Wrap = true})
    local close = transparent(object, width - 24, 4, 20, 22, "TextButton")
    iconLabel(close, {"x"}, 4, 5, 12, palette[3], "x")
    local targetY = 0
    for _, item in ipairs(window.Notifications) do targetY = targetY + item.Height + config.Gap end
    local notif = {Object = object, Bar = bar, Progress = progress, Icon = icon,
        Id = id, Width = width, Height = height, Alpha = 0, Y = targetY, TargetY = targetY,
        Life = 4, Duration = 4, Sticky = false, Hover = false, Destroyed = false}
    local maid = Maid.new(Library.Maid)
    notif.Maid = maid
    maid:Add(object)
    maid:Add(function()
        notif.Destroyed = true
        if id and window.NotificationIds[id] == notif then window.NotificationIds[id] = nil end
    end)
    function notif:Close()
        if self.Destroyed then return end
        self.Life, self.Sticky, self.Hover = 0, false, false
    end
    function notif:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self.Id and window.NotificationIds[self.Id] == self then window.NotificationIds[self.Id] = nil end
        for index, item in ipairs(window.Notifications) do
            if item == self then table.remove(window.Notifications, index) break end
        end
        maid:Destroy()
    end
    function notif:SetText(value)
        if self.Destroyed then return end
        body = tostring(value or "")
        bodyLabel:SetText(body)
        local measured = TextService:GetTextSize(body, 11, UI_FONT, Vector2.new(width - 58, 10000))
        local hasTitle = title ~= ""
        self.Height = (hasTitle and 26 or 10) + math.min(maximumBody, math.max(14, measured.Y)) + 10
        object.Size = UDim2.fromOffset(width, self.Height)
        bodyLabel.Object.Position = UDim2.fromOffset(34, hasTitle and 26 or 10)
        bodyLabel.Object.Size = UDim2.fromOffset(width - 58, self.Height - (hasTitle and 26 or 10) - 10)
        bar.Size = UDim2.fromOffset(2, self.Height)
        progress.Position = UDim2.fromOffset(0, self.Height - 2)
        if window.LayoutNotifications then window.LayoutNotifications() end
    end
    function notif:Update(changes)
        if self.Destroyed then return self end
        changes = changes or {}
        if changes.Title ~= nil then
            title = tostring(changes.Title)
            titleLabel:SetText(title)
            titleLabel.Object.Visible = title ~= ""
        end
        if changes.Text ~= nil or changes.Title ~= nil then self:SetText(changes.Text or body) end
        if self.Destroyed then return self end
        if changes.Type ~= nil or changes.Icon ~= nil then
            local kind = string.lower(tostring(changes.Type or "info"))
            local definitions = {
                info = {"info", "bell"}, success = {"check-circle", "check"},
                warning = {"alert-triangle", "alert-circle"}, error = {"x-circle", "alert-octagon"},
            }
            self.Icon:SetIcon(changes.Icon or definitions[kind] or definitions.info)
            local colors = {success = Color3.fromRGB(110, 220, 140),
                warning = Color3.fromRGB(240, 200, 90), error = Color3.fromRGB(240, 100, 100)}
            self.Color = colors[kind]
        end
        if typeof(changes.Color) == "Color3" then self.Color = changes.Color end
        if changes.Sticky ~= nil then self.Sticky = changes.Sticky == true end
        self.Duration = math.max(0.5, tonumber(changes.Duration) or self.Duration)
        self.Life = self.Duration
        if changes.Callback ~= nil then self.Callback = changes.Callback end
        if changes.CloseOnClick ~= nil then self.CloseOnClick = changes.CloseOnClick ~= false end
        window:Wake()
        return self
    end
    notif.CloseOnClick = opts.CloseOnClick ~= false
    maid:Connect(object.MouseEnter, function() notif.Hover = true end)
    maid:Connect(object.MouseLeave, function() notif.Hover = false end)
    maid:Connect(close.Activated, function() notif:Close() end)
    maid:Connect(object.Activated, function()
        if notif.Destroyed then return end
        if notif.Callback then Runtime.Spawn(notif.Callback, notif) end
        if notif.CloseOnClick then notif:Close() end
    end)
    window.Notifications[#window.Notifications + 1] = notif
    if id then window.NotificationIds[id] = notif end
    notif:Update({Type = opts.Type or "info", Icon = opts.Icon, Title = title, Text = body,
        Color = opts.Color, Duration = opts.Duration, Sticky = opts.Sticky, Callback = opts.Callback})
    if window.LayoutNotifications then window.LayoutNotifications() end
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
    if window.Dialog then window.Dialog:Destroy() end
    local maid = Maid.new(Library.Maid)
    local api = {Maid = maid, Destroyed = false, Closing = false}
    local width = math.clamp(roundPixel(tonumber(opts.Width) or 300), 220, 520)
    local body = tostring(opts.Text or "")
    local bounds = TextService:GetTextSize(body, 12, UI_FONT, Vector2.new(width - 40, 10000))
    local bodyHeight = math.min(240, math.max(16, bounds.Y))
    local height = 44 + bodyHeight + 63
    local shade = rect(window.Gui, 0, 0, 10, 10, black)
    shade.Size, shade.BackgroundTransparency, shade.ZIndex, shade.Active = UDim2.fromScale(1, 1), 1, 90, true
    maid:Add(shade)
    api.Object = shade
    local card = rect(shade, 0, 0, width, height, palette[2], 10, "CanvasGroup")
    card.AnchorPoint, card.Position, card.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 91
    card.GroupTransparency, card.BackgroundTransparency, card.ClipsDescendants = 1, 0.20, true
    new("UIStroke", card, {Color = palette[5], Thickness = 1, Transparency = 0.55})
    local scale = new("UIScale", card, {Scale = 1})
    local function layout()
        local view = window.Gui.AbsoluteSize
        if view.X <= 0 or view.Y <= 0 then view = window.Viewport end
        scale.Scale = math.min(1, math.max(0.2, (view.X - 24) / width), math.max(0.2, (view.Y - 24) / height))
    end
    maid:Connect(window.Gui:GetPropertyChangedSignal("AbsoluteSize"), layout)
    layout()
    text(card, opts.Title or "Confirm action", 20, 16, width - 40, 16, 13, white, nil, {Bold = true})
    local holder = new("ScrollingFrame", card, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 44), Size = UDim2.fromOffset(width - 40, bodyHeight),
        CanvasSize = UDim2.fromOffset(0, bounds.Y), ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never, Active = true})
    muted(holder, body, 0, 0, width - 40, math.max(16, bounds.Y), 12, nil, {Wrap = true})
    local tweenService = game:GetService("TweenService")
    local function animate(target, duration)
        local panelTween = tweenService:Create(card, TweenInfo.new(duration, Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out), {GroupTransparency = target})
        local shadeTween = tweenService:Create(shade, TweenInfo.new(duration), {BackgroundTransparency = 0.5 + 0.5 * target})
        maid:Add(panelTween, "panelTween"); maid:Add(shadeTween, "shadeTween")
        panelTween:Play(); shadeTween:Play()
        return panelTween
    end
    function api:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if window.Dialog == self then window.Dialog = nil end
        maid:Destroy()
    end
    function api:Close()
        if self.Destroyed or self.Closing then return end
        self.Closing = true
        card.Interactable = false
        local tween = animate(1, 0.16)
        maid:Once(tween.Completed, function() self:Destroy() end)
    end
    local labels = type(opts.Buttons) == "table" and opts.Buttons
        or {opts.ConfirmText or "Confirm", opts.CancelText or "Cancel"}
    if #labels == 0 then labels = {"Close"} end
    local count = math.min(4, #labels)
    local buttonW = math.floor((width - 40 - 8 * (count - 1)) / count)
    local function choose(index)
        if api.Destroyed or api.Closing or not Runtime.IsEnabled(shade) then return end
        api:Close()
        if index == 1 and opts.Confirm then Runtime.Spawn(opts.Confirm) end
        if index == 2 and opts.Cancel then Runtime.Spawn(opts.Cancel) end
        if opts.Callback then Runtime.Spawn(opts.Callback, index, tostring(labels[index])) end
    end
    for index = 1, count do
        local button = paint(rect(card, 20 + (index - 1) * (buttonW + 8), height - 47,
            buttonW, 31, palette[4], 4, "TextButton"), 4)
        text(button, tostring(labels[index]), 0, 0, buttonW, 31, 11, white, "center")
        maid:Connect(button.MouseEnter, function() button.BackgroundColor3 = palette[5] end)
        maid:Connect(button.MouseLeave, function() button.BackgroundColor3 = palette[4] end)
        maid:Connect(button.Activated, function() choose(index) end)
    end
    maid:Connect(UIS.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.Escape and window.Dialog == api then
            if count >= 2 then choose(2) else api:Close() end
        end
    end)
    maid:Add(function()
        api.Destroyed = true
        if window.Dialog == api then window.Dialog = nil end
    end)
    if window.CancelDrag then window.CancelDrag() end
    if window.PendingKeybind then window.PendingKeybind:Cancel() end
    window.Opened, window.Dialog = nil, api
    animate(0, 0.20)
    local close = api.Close
    api.Close = function() close(api) end
    return api
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
    config.ScrollBarThickness = self.ScrollBarThickness
    if self.Configs and self.Configs.RestoreAccent == true then
        config.Accent = serialize(state.Accent)
        config.AccentAlpha = state.AccentAlpha
    end
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
    if self.MigrateConfig then
        local migrated, problem = self:MigrateConfig(config)
        if not migrated then return false, problem end
        config = migrated
    end
    if config.Flags ~= nil and type(config.Flags) ~= "table" then return false,"Flags is not a table" end
    local staged, report = {}, {Applied=0, Unknown=0, Skipped=0, Errors={}}
    report.Migrated = config.__migrated
    for savedFlag, raw in pairs(config.Flags or {}) do
        local flag = self.ConfigAliases and self.ConfigAliases[savedFlag] or savedFlag
        if type(flag) ~= "string" or self.NoSaveFlags[flag] or INTERNAL_FLAGS[flag] then report.Skipped=report.Skipped+1
        elseif flag == savedFlag or config.Flags[flag] == nil then
            local ok, value = pcall(deserialize,raw)
            if not ok then report.Errors[#report.Errors+1]=flag..": "..tostring(value)
            else
                local kind = typeof(value)
                if kind == "number" and (value~=value or value==math.huge or value==-math.huge) then
                    report.Errors[#report.Errors+1]=flag..": invalid number"
                elseif string.sub(flag,-6)==".Alpha" and (kind~="number" or value<0 or value>1) then
                    report.Errors[#report.Errors+1]=flag..": opacity must be between 0 and 1"
                else
                local element = self.Elements[flag]
                if element and element.Get then
                    local good, current = pcall(element.Get,element)
                    local expected, kind = good and typeof(current), typeof(value)
                    if good and (expected=="boolean" or expected=="number" or expected=="Color3" or expected=="table") and kind~=expected then
                        report.Errors[#report.Errors+1]=flag..": expected "..expected
                    elseif kind=="number" and (value~=value or value==math.huge or value==-math.huge) then
                        report.Errors[#report.Errors+1]=flag..": invalid number"
                    else staged[flag]=value end
                else staged[flag]=value end
                end
            end
        end
    end
    self.LastConfigReport=report
    if #report.Errors>0 then return false,table.concat(report.Errors,"; ") end
    if config.FadeDuration ~= nil then self:SetFadeDuration(config.FadeDuration) end
    if config.ScaleDuration ~= nil then self:SetScaleDuration(config.ScaleDuration) end
    if config.ScrollBarThickness ~= nil then self:SetScrollBarThickness(config.ScrollBarThickness) end
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
    if config.Accent and self.Configs and self.Configs.RestoreAccent == true then
        self:SetAccent(deserialize(config.Accent), config.AccentAlpha)
    end
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
        self.Window.LayoutMini()
    end
    for flag,value in pairs(staged) do self.Flags[flag]=value end
    local flags={};for flag in pairs(staged) do flags[#flags+1]=flag end;table.sort(flags)
    for _,flag in ipairs(flags) do
        local value,element=staged[flag],self.Elements[flag]
        if element and element.Set then
            local ok,err=pcall(function()
                if typeof(value)=="Color3" then element:Set(value,staged[flag..".Alpha"])
                else element:Set(value) end
            end)
            if ok then report.Applied=report.Applied+1
            else report.Errors[#report.Errors+1]=flag..": "..tostring(err) end
        else report.Unknown=report.Unknown+1;fireChange(flag,value) end
    end
    if #report.Errors>0 then return false,table.concat(report.Errors,"; ") end
    return true,report

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
    local folder = ROOT .. "/" .. scriptFolder .. "/configs"
    if self.Configs and self.Configs.PerGame == true then
        folder = folder .. "/" .. safeName(tostring(game.PlaceId))
    end
    return folder
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
        RestoreAccent = options.RestoreAccent == true,
        Backups = math.clamp(math.floor(tonumber(options.Backups) or 3), 0, 10),
        Verify = options.Verify ~= false,
        PerGame = options.PerGame == true,
    }
    if self.Configs.Enabled then self:SetScriptName(self.ScriptName or scriptFolder) end
    return self.Configs
end

function Library:GetConfigOptions()
    return self.Configs
end

do
    local listeners = {}
    local Cfg = {Defaults = nil, Saved = {}, AutoSave = nil}

    local function emit(kind, name, detail)
        for _, listener in ipairs(listeners) do
            Runtime.Spawn(function() pcall(listener, kind, name, detail) end)
        end
        if Library.Log then Library:Log(kind .. ": " .. tostring(name), "config") end
    end

    local function canonical(value)
        local kind = type(value)
        if kind == "table" then
            local keys = {}
            for key in pairs(value) do keys[#keys + 1] = key end
            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta ~= tb then return ta < tb end
                if ta == "number" or ta == "string" then return a < b end
                return tostring(a) < tostring(b)
            end)
            local parts = {}
            for _, key in ipairs(keys) do
                parts[#parts + 1] = canonical(key) .. "=" .. canonical(value[key])
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif kind == "number" then
            return string.format("%.14g", value)
        elseif kind == "string" then
            return string.format("%q", value)
        end
        return tostring(value)
    end

    local function versionParts(text)
        local parts = {}
        for number in string.gmatch(tostring(text or ""), "%d+") do parts[#parts + 1] = tonumber(number) end
        return parts
    end

    local function compareVersions(a, b)
        local x, y = versionParts(a), versionParts(b)
        for index = 1, math.max(#x, #y) do
            local left, right = x[index] or 0, y[index] or 0
            if left ~= right then return left < right and -1 or 1 end
        end
        return 0
    end

    Library.CompareVersions = compareVersions

    local function backupLimit(self)
        local value = self.Configs and self.Configs.Backups
        if value == nil then return 3 end
        return math.clamp(math.floor(tonumber(value) or 3), 0, 10)
    end

    local function backupPath(path, index)
        return path .. ".bak" .. tostring(index)
    end

    local function candidates(self, base)
        local folder = self:GetConfigFolder()
        local preferred = configExtension()
        local alternate = preferred == SECURE_EXTENSION and JSON_EXTENSION or SECURE_EXTENSION
        return {
            folder .. "/" .. base .. preferred,
            folder .. "/" .. base .. alternate,
            LEGACY_ROOT .. "/" .. base .. JSON_EXTENSION,
        }
    end

    local function findPath(self, base)
        for _, path in ipairs(candidates(self, base)) do
            if pathExists(path) then return path end
        end
        return nil
    end

    local function readTable(self, path)
        local raw = readfile(path)
        local json = decodeConfig(raw, self.Configs.Key)
        local decoded = HttpService:JSONDecode(json)
        if type(decoded) ~= "table" then error("config is not a table", 0) end
        return decoded, #raw
    end

    local function removeFile(path)
        if type(delfile) ~= "function" then return false end
        if not pathExists(path) then return false end
        return (pcall(delfile, path))
    end

    local function countKeys(map)
        local count = 0
        for _ in pairs(map or {}) do count = count + 1 end
        return count
    end

    local function rotateBackups(self, path)
        local limit = backupLimit(self)
        if limit <= 0 or not pathExists(path) then return end
        local okRead, current = pcall(readfile, path)
        if not okRead then return end
        for index = limit, 2, -1 do
            local older = backupPath(path, index - 1)
            if pathExists(older) then
                local okOlder, content = pcall(readfile, older)
                if okOlder then pcall(writefile, backupPath(path, index), content) end
            end
        end
        pcall(writefile, backupPath(path, 1), current)
    end

    local function buildMeta(self, previous, config, options, base)
        previous = type(previous) == "table" and previous or {}
        local note = previous.Note
        if options.Note ~= nil then note = tostring(options.Note) end
        return {
            Name = base,
            Created = tonumber(previous.Created) or os.time(),
            Modified = os.time(),
            Game = tostring(game.PlaceId),
            Library = self.Version,
            Note = note,
            Flags = countKeys(config.Flags),
            Checksum = configHash(canonical(config.Flags or {})),
        }
    end

    local function writeConfig(self, base, config, options)
        options = options or {}
        local folder = self:GetConfigFolder()
        if not ensureFolder(folder) then return false, "cannot create config folder" end
        local extension = configExtension()
        local path = folder .. "/" .. base .. extension
        local previous
        if pathExists(path) then
            local okPrevious, data = pcall(readTable, self, path)
            if okPrevious and type(data.Meta) == "table" then previous = data.Meta end
        end
        config.Meta = buildMeta(self, previous, config, options, base)
        local json = HttpService:JSONEncode(config)
        local content = self.Configs.Encrypted and encodeConfig(json, self.Configs.Key) or json
        if self.Configs.Verify ~= false then
            local temp = path .. ".tmp"
            local okTemp, tempError = pcall(writefile, temp, content)
            if not okTemp then return false, tostring(tempError) end
            local okBack, back = pcall(readfile, temp)
            local good = okBack and back == content
            if good then
                good = pcall(function()
                    local decoded = HttpService:JSONDecode(decodeConfig(back, self.Configs.Key))
                    if type(decoded) ~= "table" then error("not a table", 0) end
                end)
            end
            removeFile(temp)
            if not good then return false, "verification failed, existing config left untouched" end
        end
        local existed = pathExists(path)
        local oldContent
        if existed then
            local okRead, previousContent = pcall(readfile, path)
            if not okRead then return false, "cannot read existing config before write" end
            oldContent = previousContent
        end
        rotateBackups(self, path)
        local okWrite, writeError = pcall(writefile, path, content)
        if okWrite and self.Configs.Verify ~= false then
            local okRead, written = pcall(readfile, path)
            okWrite = okRead and written == content
            if not okWrite then writeError = "destination verification failed" end
        end
        if not okWrite then
            local restored
            if existed then
                restored = pcall(writefile, path, oldContent)
                if restored then
                    local readable, bytes = pcall(readfile, path)
                    restored = readable and bytes == oldContent
                end
            else restored = removeFile(path) or not pathExists(path) end
            return false, tostring(writeError) .. (restored and "; previous state restored" or "; rollback failed")
        end
        local alternate = folder .. "/" .. base .. (extension == SECURE_EXTENSION and JSON_EXTENSION or SECURE_EXTENSION)
        removeFile(alternate)
        Cfg.Saved[base] = canonical(config.Flags or {})
        return true, path
    end

    local function packConfig(config, key)
        local json = HttpService:JSONEncode(config)
        if key ~= nil and tostring(key) ~= "" then
            return "WOLF1E:" .. encodeConfig(json, tostring(key))
        end
        return "WOLF1:" .. base64Encode(json)
    end

    local function unpackConfig(text, key)
        if type(text) ~= "string" or text == "" then return nil, "empty config string" end
        text = string.gsub(text, "^%s+", "")
        text = string.gsub(text, "%s+$", "")
        local json
        if string.sub(text, 1, 7) == "WOLF1E:" then
            local ok, result = pcall(decodeConfig, string.sub(text, 8), key)
            if not ok then return nil, tostring(result) end
            json = result
        elseif string.sub(text, 1, 6) == "WOLF1:" then
            json = base64Decode(string.sub(text, 7))
        else
            json = text
        end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(decoded) ~= "table" then return nil, "config string is damaged" end
        return decoded
    end

    local function enabled(self)
        if not self.Configs or not self.Configs.Enabled then return false, "configs are disabled" end
        if not fileSupport() then return false, "executor has no file API" end
        return true
    end

    function Library:OnConfigEvent(callback)
        assert(type(callback) == "function", "OnConfigEvent requires a callback")
        listeners[#listeners + 1] = callback
        return {
            Disconnect = function()
                for index, item in ipairs(listeners) do
                    if item == callback then table.remove(listeners, index) break end
                end
            end,
        }
    end

    function Library:AddConfigMigration(version, callback)
        assert(type(callback) == "function", "AddConfigMigration requires a callback")
        self.ConfigMigrations = self.ConfigMigrations or {}
        local list = self.ConfigMigrations
        list[#list + 1] = {Version = tostring(version), Callback = callback}
        table.sort(list, function(a, b) return compareVersions(a.Version, b.Version) < 0 end)
    end

    function Library:MigrateConfig(config)
        if type(config) ~= "table" then return config end
        local saved = config.__version or "0"
        local applied = {}
        for _, step in ipairs(self.ConfigMigrations or {}) do
            if compareVersions(saved, step.Version) < 0 then
                local ok, result = pcall(step.Callback, config)
                if ok then
                    if type(result) == "table" then config = result end
                    applied[#applied + 1] = step.Version
                    config.__version = step.Version
                else
                    local problem = "migration " .. step.Version .. " failed: " .. tostring(result)
                    if self.Log then self:Log(problem, "error") end
                    return nil, problem
                end
            end
        end
        if #applied > 0 then config.__migrated = applied end
        return config
    end

    function Library:ConfigExists(name)
        if not self.Configs or not self.Configs.Enabled then return false end
        return findPath(self, safeName(name or "default")) ~= nil
    end

    function Library:GetConfigPath(name)
        local base = safeName(name or "default")
        return findPath(self, base) or (self:GetConfigFolder() .. "/" .. base .. configExtension())
    end

    function Library:SaveConfigFile(name, options)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        if type(options) ~= "table" then options = {} end
        local base = safeName(name or "default")
        local ok, result, detail = pcall(function()
            return writeConfig(self, base, self:GetConfig(), options)
        end)
        if not ok then return false, tostring(result) end
        if result ~= true then return false, detail end
        emit("save", base, detail)
        return true, detail
    end

    function Library:LoadConfigFile(name, options)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        options = type(options) == "table" and options or {}
        local base = safeName(name or "default")
        local path = findPath(self, base)
        if not path then return false, "config not found: " .. base end
        local okRead, decoded = pcall(readTable, self, path)
        local recovered
        if not okRead and options.Recover ~= false then
            for index = 1, backupLimit(self) do
                local candidate = backupPath(path, index)
                if pathExists(candidate) then
                    local okBackup, data = pcall(readTable, self, candidate)
                    if okBackup then
                        decoded = data
                        okRead = true
                        recovered = index
                        break
                    end
                end
            end
        end
        if not okRead then return false, tostring(decoded) end
        local meta = type(decoded.Meta) == "table" and decoded.Meta or nil
        local tampered = meta ~= nil and meta.Checksum ~= nil
            and meta.Checksum ~= configHash(canonical(decoded.Flags or {}))
        if options.NoUndo ~= true then pcall(self.Snapshot, self, "__undo") end
        local applied, loaded, detail = pcall(self.LoadConfig, self, decoded)
        if not applied then return false, tostring(loaded) end
        if loaded == true and type(detail) == "table" then
            detail.Recovered = recovered
            detail.Tampered = tampered == true
        end
        if loaded == true then emit("load", base, detail) end
        return loaded, detail
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

    function Library:GetConfigInfo(name)
        local base = safeName(name or "default")
        local info = {Name = base, Exists = false}
        if not self.Configs or not self.Configs.Enabled or not fileSupport() then return info end
        local path = findPath(self, base)
        if not path then return info end
        info.Exists = true
        info.Path = path
        info.Encrypted = string.sub(path, -#SECURE_EXTENSION) == SECURE_EXTENSION
        local ok, decoded, size = pcall(readTable, self, path)
        if not ok then
            info.Valid = false
            info.Error = tostring(decoded)
            return info
        end
        local meta = type(decoded.Meta) == "table" and decoded.Meta or {}
        info.Valid = true
        info.Size = size
        info.Version = decoded.__version
        info.Created = meta.Created
        info.Modified = meta.Modified
        info.Game = meta.Game
        info.Note = meta.Note
        info.Flags = meta.Flags or countKeys(decoded.Flags)
        if meta.Checksum ~= nil then
            info.ChecksumOk = meta.Checksum == configHash(canonical(decoded.Flags or {}))
        end
        local backups = 0
        for index = 1, 10 do
            if pathExists(backupPath(path, index)) then backups = backups + 1 end
        end
        info.Backups = backups
        return info
    end

    function Library:ListConfigsDetailed()
        local result = {}
        for _, name in ipairs(self:ListConfigs()) do
            result[#result + 1] = self:GetConfigInfo(name)
        end
        table.sort(result, function(a, b)
            local left, right = a.Modified or 0, b.Modified or 0
            if left ~= right then return left > right end
            return a.Name < b.Name
        end)
        return result
    end

    function Library:DeleteConfigFile(name)
        if not self.Configs or not self.Configs.Enabled then return false, "configs are disabled" end
        if type(delfile) ~= "function" then return false, "executor has no delfile" end
        local base = safeName(name or "default")
        local deleted, lastError = false, nil
        for _, path in ipairs(candidates(self, base)) do
            if pathExists(path) then
                local ok, err = pcall(delfile, path)
                if ok and not pathExists(path) then
                    deleted = true
                    for index = 1, 10 do removeFile(backupPath(path, index)) end
                    removeFile(path .. ".tmp")
                else lastError = err or "file still exists after delete" end
            end
        end
        if deleted and not lastError then
            Cfg.Saved[base] = nil
            emit("delete", base)
            return true
        end
        return false, lastError or ("config not found: " .. base)
    end

    function Library:CopyConfigFile(from, to, overwrite)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        local fromBase, toBase = safeName(from), safeName(to)
        if fromBase == toBase then return false, "source and target names are the same" end
        local source = findPath(self, fromBase)
        if not source then return false, "config not found: " .. fromBase end
        if not overwrite and findPath(self, toBase) then return false, "config already exists: " .. toBase end
        local okRead, decoded = pcall(readTable, self, source)
        if not okRead then return false, tostring(decoded) end
        local meta = type(decoded.Meta) == "table" and decoded.Meta or {}
        local ok, result, detail = pcall(writeConfig, self, toBase, decoded, {Note = meta.Note})
        if not ok then return false, tostring(result) end
        if result ~= true then return false, detail end
        emit("copy", toBase, fromBase)
        return true, detail
    end

    function Library:RenameConfigFile(from, to, overwrite)
        if type(delfile) ~= "function" then return false, "executor has no delfile" end
        local fromBase, toBase = safeName(from), safeName(to)
        local copied, detail = self:CopyConfigFile(fromBase, toBase, overwrite)
        if not copied then return false, detail end
        local wasAutoLoad = self:GetAutoLoad() == fromBase
        local savedSnapshot = Cfg.Saved[fromBase]
        local removed, removeError = self:DeleteConfigFile(fromBase)
        if not removed then return false, removeError end
        if savedSnapshot ~= nil then
            Cfg.Saved[toBase] = savedSnapshot
            Cfg.Saved[fromBase] = nil
        end
        if wasAutoLoad then self:SetAutoLoad(toBase) end
        emit("rename", toBase, fromBase)
        return true, detail
    end

    function Library:ConvertConfigs()
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        local converted, failed = 0, {}
        for _, name in ipairs(self:ListConfigs()) do
            local base = safeName(name)
            local path = findPath(self, base)
            if path then
                local okRead, decoded = pcall(readTable, self, path)
                if okRead then
                    local meta = type(decoded.Meta) == "table" and decoded.Meta or {}
                    local ok, result = pcall(writeConfig, self, base, decoded, {Note = meta.Note})
                    if ok and result == true then converted = converted + 1 else failed[#failed + 1] = base end
                else
                    failed[#failed + 1] = base
                end
            end
        end
        emit("convert", converted, failed)
        return true, {Converted = converted, Failed = failed}
    end

    function Library:ListBackups(name)
        local base = safeName(name or "default")
        local list = {}
        if not self.Configs or not self.Configs.Enabled or not fileSupport() then return list end
        local path = findPath(self, base)
        if not path then return list end
        for index = 1, 10 do
            local candidate = backupPath(path, index)
            if pathExists(candidate) then
                local entry = {Index = index, Path = candidate}
                local ok, data, size = pcall(readTable, self, candidate)
                entry.Valid = ok
                if ok then
                    entry.Size = size
                    if type(data.Meta) == "table" then entry.Modified = data.Meta.Modified end
                end
                list[#list + 1] = entry
            end
        end
        return list
    end

    function Library:RestoreBackup(name, index, load)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        local base = safeName(name or "default")
        local path = findPath(self, base)
        if not path then return false, "config not found: " .. base end
        index = math.floor(tonumber(index) or 1)
        local candidate = backupPath(path, index)
        if not pathExists(candidate) then return false, "backup not found: " .. tostring(index) end
        local okRead, data = pcall(readTable, self, candidate)
        if not okRead then return false, tostring(data) end
        local okRaw, raw = pcall(readfile, candidate)
        if not okRaw then return false, tostring(raw) end
        local oldRead, oldRaw = pcall(readfile, path)
        if not oldRead then return false, "cannot read current config before restore" end
        rotateBackups(self, path)
        local okWrite, writeError = pcall(writefile, path, raw)
        if okWrite and self.Configs.Verify ~= false then
            local verified, bytes = pcall(readfile, path)
            okWrite = verified and bytes == raw
            if not okWrite then writeError = "backup destination verification failed" end
        end
        if not okWrite then
            local rollback = pcall(writefile, path, oldRaw)
            if rollback then
                local readable, bytes = pcall(readfile, path)
                rollback = readable and bytes == oldRaw
            end
            return false, tostring(writeError) .. (rollback and "; previous state restored" or "; rollback failed")
        end
        Cfg.Saved[base] = nil
        emit("restore-backup", base, index)
        if load then return self:LoadConfigFile(base) end
        return true, path
    end

    function Library:ClearBackups(name)
        local base = safeName(name or "default")
        local path = findPath(self, base)
        if not path then return 0 end
        local removed = 0
        for index = 1, 10 do
            if removeFile(backupPath(path, index)) then removed = removed + 1 end
        end
        return removed
    end

    function Library:ExportConfig(key)
        return packConfig(self:GetConfig(), key)
    end

    function Library:ImportConfig(text, key)
        local decoded, problem = unpackConfig(text, key)
        if not decoded then return false, problem end
        pcall(self.Snapshot, self, "__undo")
        emit("import", "string")
        return self:LoadConfig(decoded)
    end

    function Library:ExportConfigFile(name, key)
        local usable, reason = enabled(self)
        if not usable then return nil, reason end
        local base = safeName(name or "default")
        local path = findPath(self, base)
        if not path then return nil, "config not found: " .. base end
        local ok, decoded = pcall(readTable, self, path)
        if not ok then return nil, tostring(decoded) end
        return packConfig(decoded, key)
    end

    function Library:ImportConfigAs(name, text, key, options)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        options = type(options) == "table" and options or {}
        local decoded, problem = unpackConfig(text, key)
        if not decoded then return false, problem end
        local base = safeName(name or "imported")
        if not options.Overwrite and findPath(self, base) then return false, "config already exists: " .. base end
        local meta = type(decoded.Meta) == "table" and decoded.Meta or {}
        local ok, result, detail = pcall(writeConfig, self, base, decoded, {Note = options.Note or meta.Note})
        if not ok then return false, tostring(result) end
        if result ~= true then return false, detail end
        emit("import", base, detail)
        if options.Load then return self:LoadConfigFile(base) end
        return true, detail
    end

    function Library:ValidateConfig(config)
        local report = {Valid = true, Errors = {}, Warnings = {}, Unknown = {}, Known = 0}
        if type(config) ~= "table" then
            report.Valid = false
            report.Errors[1] = "config is not a table"
            return report
        end
        if config.Flags ~= nil and type(config.Flags) ~= "table" then
            report.Valid = false
            report.Errors[1] = "Flags is not a table"
            return report
        end
        if config.__version ~= nil and compareVersions(config.__version, self.Version) > 0 then
            report.Warnings[#report.Warnings + 1] = "saved by a newer library version " .. tostring(config.__version)
        end
        local meta = type(config.Meta) == "table" and config.Meta or nil
        if meta and meta.Checksum ~= nil and meta.Checksum ~= configHash(canonical(config.Flags or {})) then
            report.Warnings[#report.Warnings + 1] = "file was edited outside the library"
        end
        for savedFlag, raw in pairs(config.Flags or {}) do
            local flag = self.ConfigAliases and self.ConfigAliases[savedFlag] or savedFlag
            if type(flag) == "string" and not self.NoSaveFlags[flag] and not INTERNAL_FLAGS[flag] then
                local element = self.Elements[flag]
                if not element then
                    report.Unknown[#report.Unknown + 1] = flag
                else
                    report.Known = report.Known + 1
                    local okValue, value = pcall(deserialize, raw)
                    if not okValue then
                        report.Errors[#report.Errors + 1] = flag .. ": unreadable value"
                    elseif element.Get then
                        local good, current = pcall(element.Get, element)
                        local expected = good and typeof(current)
                        local kind = typeof(value)
                        if good and (expected == "boolean" or expected == "number" or expected == "Color3" or expected == "table") and kind ~= expected then
                            report.Errors[#report.Errors + 1] = flag .. ": expected " .. expected .. ", got " .. kind
                        end
                    end
                end
            end
        end
        table.sort(report.Unknown)
        report.Valid = #report.Errors == 0
        return report
    end

    function Library:DiffConfig(left, right)
        local function flagsOf(source)
            if type(source) == "string" then
                local usable, reason = enabled(self)
                if not usable then return nil, reason end
                local path = findPath(self, safeName(source))
                if not path then return nil, "config not found: " .. source end
                local ok, decoded = pcall(readTable, self, path)
                if not ok then return nil, tostring(decoded) end
                return decoded.Flags or {}
            elseif type(source) == "table" then
                if type(source.Flags) == "table" then return source.Flags end
                return source
            end
            return self:GetConfig().Flags
        end
        local a, errorLeft = flagsOf(left)
        if not a then return nil, errorLeft end
        local b, errorRight = flagsOf(right)
        if not b then return nil, errorRight end
        local result = {Added = {}, Removed = {}, Changed = {}, Same = 0}
        for flag, value in pairs(b) do
            if a[flag] == nil then
                result.Added[#result.Added + 1] = flag
            elseif canonical(a[flag]) ~= canonical(value) then
                result.Changed[#result.Changed + 1] = {Flag = flag, From = a[flag], To = value}
            else
                result.Same = result.Same + 1
            end
        end
        for flag in pairs(a) do
            if b[flag] == nil then result.Removed[#result.Removed + 1] = flag end
        end
        table.sort(result.Added)
        table.sort(result.Removed)
        table.sort(result.Changed, function(x, y) return x.Flag < y.Flag end)
        result.Total = #result.Added + #result.Removed + #result.Changed
        return result
    end

    function Library:DiffConfigFile(name)
        return self:DiffConfig(name, nil)
    end

    function Library:HasUnsavedChanges(name)
        local base = safeName(name or "default")
        local current = canonical(self:GetConfig().Flags or {})
        if Cfg.Saved[base] ~= nil then return Cfg.Saved[base] ~= current end
        local diff = self:DiffConfig(base, nil)
        if not diff then return true end
        return diff.Total > 0
    end

    local function autoloadFile(self)
        return self:GetConfigFolder() .. "/autoload.txt"
    end

    function Library:SetAutoLoad(name)
        local usable, reason = enabled(self)
        if not usable then return false, reason end
        if not ensureFolder(self:GetConfigFolder()) then return false, "cannot create config folder" end
        local value = (name == nil or name == "") and "" or safeName(name)
        local ok, err = pcall(writefile, autoloadFile(self), value)
        if not ok then return false, tostring(err) end
        emit("autoload-set", value == "" and "(none)" or value)
        return true, value ~= "" and value or nil
    end

    function Library:GetAutoLoad()
        if not self.Configs or not self.Configs.Enabled or not fileSupport() then return nil end
        local path = autoloadFile(self)
        if not pathExists(path) then return nil end
        local ok, content = pcall(readfile, path)
        if not ok then return nil end
        content = string.gsub(content, "^%s+", "")
        content = string.gsub(content, "%s+$", "")
        if content == "" then return nil end
        return content
    end

    function Library:RunAutoLoad(options)
        options = type(options) == "table" and options or {}
        local name = options.Name or self:GetAutoLoad()
        if not name then return false, "no autoload config set" end
        if not Cfg.Defaults then self:CaptureDefaults() end
        local ok, detail = self:LoadConfigFile(name, options)
        if ok == true then
            emit("autoload", name)
            if options.Notify ~= false and self.Window then
                pcall(function() self:Notify({Title = "Configs", Text = "Autoloaded: " .. tostring(name)}) end)
            end
        end
        return ok, detail
    end

    function Library:CaptureDefaults()
        Cfg.Defaults = self:GetConfig().Flags
        return true
    end

    function Library:HasDefaults()
        return Cfg.Defaults ~= nil
    end

    function Library:ResetToDefaults()
        if not Cfg.Defaults then return false, "defaults were not captured" end
        pcall(self.Snapshot, self, "__undo")
        local ok, detail = self:LoadConfig({Flags = Cfg.Defaults, __version = self.Version})
        if ok == true then emit("reset", "defaults") end
        return ok, detail
    end

    function Library:UndoConfigLoad()
        local ok, detail = self:RestoreSnapshot("__undo")
        if ok == true then emit("undo", "__undo") end
        return ok, detail
    end

    function Library:SetAutoSave(enabledState, interval, name)
        local previous = Cfg.AutoSave
        if previous then
            previous.Active = false
            if previous.Maid then previous.Maid:Destroy() end
            Cfg.AutoSave = nil
        end
        if not enabledState then return false end
        if not Runtime.Alive or not Library.Maid then return false end
        local job = {Active = true, Maid = Maid.new(Library.Maid)}
        Cfg.AutoSave = job
        job.Maid:Add(function() job.Active = false end)
        local period = math.max(5, tonumber(interval) or 60)
        local slot = safeName(name or "autosave")
        job.Maid:Spawn(function()
            while job.Active and Runtime.Alive == true do
                task.wait(period)
                if job.Active and Runtime.Alive == true then
                    local okConfig, config = pcall(Library.GetConfig, Library)
                    if okConfig then
                        local current = canonical(config.Flags or {})
                        if Cfg.Saved[slot] ~= current then
                            local ok, result = Library:SaveConfigFile(slot, {Note = "autosave"})
                            if Library.Log then Library:Log("autosave " .. tostring(ok) .. ": " .. tostring(result), "config") end
                        end
                    end
                end
            end
        end)
        return true
    end
    Runtime.ResetConfigs = function()
        Library:SetAutoSave(false)
        Cfg.Defaults = nil
        table.clear(Cfg.Saved)
        table.clear(listeners)
    end
end

function Library:Unload()
    if Runtime.Unloading or self.Destroyed then return end
    Runtime.Unloading = true
    Runtime.Alive = false
    self.Destroyed = true
    if self.SetAutoSave then self:SetAutoSave(false) end
    local window = self.Window
    if window then
        window.Destroyed = true
        if window.CancelDrag then pcall(window.CancelDrag) end
        if window.PendingKeybind then pcall(window.PendingKeybind.Cancel, window.PendingKeybind) end
        window.PendingKeybind, window.Opened = nil, nil
        window.TooltipObject, window.TooltipText = nil, nil
    end
    restoreFades()
    do
        local registry = Runtime.Env().__WolfUiWindows
        if registry then
            for key, owner in pairs(registry) do
                if owner == self then registry[key] = nil end
            end
        end
    end
    if self.Window then
        for _, tab in ipairs(self.Window.TabList or {}) do
            for _, element in ipairs(tab.Elements or {}) do
                if element.Maid then pcall(element.Maid.Destroy, element.Maid) end
            end
        end
        local popups = self.Window.Popups or {}
        for index = #popups, 1, -1 do
            local popup = popups[index]
            if popup and popup.Maid then pcall(popup.Maid.Destroy, popup.Maid) end
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
    if window then
        for _, tab in ipairs(window.TabList or {}) do
            tab.Destroyed = true
            table.clear(tab.Elements)
            if tab.LayoutItems then table.clear(tab.LayoutItems) end
        end
        for _, key in ipairs({"Tabs", "TabList", "Popups", "Notifications", "NotificationIds", "Keybinds", "Mini", "RenderCache"}) do
            if window[key] then table.clear(window[key]) end
        end
        window.Dialog, window.GlassBlur, window.Drag = nil, nil, nil
    end
    self.Window = nil
    self.Maid, Runtime.Root = nil, nil
    table.clear(Runtime.FadePool)
    table.clear(Runtime.Disabled)
    table.clear(themedBackgrounds)
    table.clear(themedLabels)
    self.Elements = {}
    self.NoSaveFlags = {}
    self.Flags = {}
    for object in pairs(fadeCaches) do fadeCaches[object] = nil end
    for _, listener in ipairs(unloadListeners) do
        pcall(listener)
    end
    unloadListeners = {}
    changeListeners = {}
    flagWatchers = {}
    if Runtime.ResetConfigs then Runtime.ResetConfigs() end
    Runtime.Unloading = false
end

function Runtime.CloseOwned(window, object)
    if not window or not object then return end
    local current = window.Opened
    while current do
        local anchor = current.Anchor
        if anchor and (anchor == object or anchor:IsDescendantOf(object)) then current:Close() end
        current = current.Parent
    end
    local pending = window.PendingKeybind
    if pending and pending.Object and (pending.Object == object or pending.Object:IsDescendantOf(object)) then
        pending:Cancel()
    end
    local drag = window.Drag
    if drag and (drag.Object == object or drag.Object:IsDescendantOf(object)) then window.CancelDrag() end
    local focused = UIS:GetFocusedTextBox()
    if focused and (focused == object or focused:IsDescendantOf(object)) then focused:ReleaseFocus() end
end

function Runtime.CompleteApi(api, maid, window)
    if type(api) ~= "table" or api._ApiCompleted then return api end
    api._ApiCompleted = true
    local object = api.Object
    if not api.SetValue then
        function api:SetValue(value, silent, extra)
            if self.Destroyed then return end
            if self.Picker or self._ColorPicker then
                return self:Set(value, extra, silent)
            end
            local setter = self.Set or self.SetText or self.SetImage or self.SetActive or self.SetCollapsed
            if setter then return setter(self, value, silent) end
            self.Value = value
            return self
        end
    end
    if not api.GetValue then
        function api:GetValue()
            local getter = self.Get or self.GetText or self.GetCollapsed
            if getter then return getter(self) end
            return self.Value
        end
    end
    if not api.GetVisible then
        function api:GetVisible() return not self.Destroyed and (not object or object.Visible) end
    end
    local oldVisible = api.SetVisible
    function api:SetVisible(value)
        if self.Destroyed then return end
        if not value then Runtime.CloseOwned(window, object) end
        if oldVisible then oldVisible(self, value)
        elseif object then object.Visible = value and true or false end
        if window and window.Wake then window:Wake() end
    end
    local oldEnabled = api.SetEnabled
    local enabled = true
    if api.GetEnabled then enabled = api:GetEnabled() ~= false
    elseif object then enabled = not Runtime.Disabled[object] end
    function api:SetEnabled(value)
        if self.Destroyed then return false end
        enabled = value ~= false
        if object then
            Runtime.Disabled[object] = not enabled or nil
            object.Interactable = enabled
            if not enabled then Runtime.CloseOwned(window, object) end
        end
        if oldEnabled then oldEnabled(self, enabled) end
        if window and window.Wake then window:Wake() end
        return enabled
    end
    if not api.GetEnabled then
        function api:GetEnabled() return not self.Destroyed and enabled end
    end
    if maid and object then
        maid:Connect(object.Destroying, function()
            if not api._Destroying and api.Destroy then api:Destroy() end
        end)
        maid:Add(function()
            Runtime.Disabled[object] = nil
            Runtime.CloseOwned(window, object)
            api.Destroyed = true
        end)
    end
    return api
end

local function ownElement(tab, api, maid)
    if type(api) ~= "table" then maid:Destroy() return api end
    api.Maid = maid
    local object = api.Object
    local window = tab and tab.Window or Library.Window
    if object then
        if not maid.UiObjects or not maid.UiObjects[object] then maid:Add(object) end
        local record = tab and tab:_track(object)
        if record then tab:_watchLayout(record, maid) end
    end
    maid:Add(function()
        api.Destroyed = true
        if api.Flag and Library.Elements[api.Flag] == api then
            Library.Elements[api.Flag] = nil
            Library.NoSaveFlags[api.Flag] = nil
        end
        if tab and tab.Elements then
            for index = #tab.Elements, 1, -1 do
                if tab.Elements[index] == api then table.remove(tab.Elements, index) end
            end
        end
    end)
    local original = api.Destroy
    function api:Destroy()
        if self._Destroying or maid.Destroyed then return end
        self._Destroying = true
        Runtime.CloseOwned(window, object)
        if original then pcall(original, self) end
        maid:Destroy()
        self.Destroyed = true
        self._Destroying = false
    end
    function api:GetMaid() return maid end
    Runtime.CompleteApi(api, maid, window)
    for name, method in pairs(api) do
        if type(method) == "function" and (string.sub(name, 1, 3) == "Set"
            or name == "Press" or name == "Toggle" or name == "Focus" or name == "Refresh"
            or name == "Add" or name == "Remove" or name == "Clear" or name == "Select"
            or name == "Deselect" or name == "SelectAll" or name == "ToggleCard"
            or name == "AddCard" or name == "RemoveCard" or name == "UpdateCard") then
            api[name] = function(self, ...)
                if self.Destroyed or maid.Destroyed then return nil end
                return withOwner(maid, method, self, ...)
            end
        end
    end
    return api
end

do
    local colorFactory, keyFactory, miniFactory = attachColorPicker, attachKeybind, createMiniButton
    attachColorPicker = function(tab, ...)
        local maid = Maid.new(Runtime.GetOwner() or tab.Maid or Library.Maid)
        local ok, api = pcall(withOwner, maid, colorFactory, tab, ...)
        if not ok then maid:Destroy(); error(api, 0) end
        api._ColorPicker = true
        local alphaFlag = api.Flag .. ".Alpha"
        local proxy = Library.Elements[alphaFlag]
        if proxy then
            proxy.SetValue = function(_, value, silent) return api:Set(nil, value, silent) end
            proxy.GetValue = proxy.Get
            proxy.SetVisible = function(_, value) return api:SetVisible(value) end
            proxy.SetEnabled = function(_, value) return api:SetEnabled(value) end
            proxy.Destroy = function() return api:Destroy() end
            maid:Add(function()
                proxy.Destroyed = true
                if Library.Elements[alphaFlag] == proxy then Library.Elements[alphaFlag] = nil end
            end)
        end
        return ownElement(nil, api, maid)
    end
    attachKeybind = function(tab, ...)
        local maid = Maid.new(Runtime.GetOwner() or tab.Maid or Library.Maid)
        local ok, api = pcall(withOwner, maid, keyFactory, tab, ...)
        if not ok then maid:Destroy(); error(api, 0) end
        return ownElement(nil, api, maid)
    end
    createMiniButton = function(window, config)
        local maid = Maid.new(Runtime.GetOwner() or Library.Maid)
        local ok, api = pcall(withOwner, maid, miniFactory, window, config)
        if not ok then maid:Destroy(); error(api, 0) end
        api.Set = api.SetActive
        return ownElement(nil, api, maid)
    end
end

for name, fn in pairs(Tab) do
    if type(fn) == "function" and string.sub(name, 1, 3) == "Add"
        and name ~= "AddElements" and name ~= "AddSelect" and name ~= "AddColor" and name ~= "AddInput"
        and name ~= "AddCards" and name ~= "AddCardSelector" then
        Tab[name] = function(self, ...)
            if self.Destroyed then return nil, "tab destroyed" end
            local maid = Maid.new(Runtime.GetOwner() or self.Maid or Library.Maid)
            local results = table.pack(pcall(withOwner, maid, fn, self, ...))
            if not results[1] then maid:Destroy(); error(results[2], 0) end
            results[2] = ownElement(self, results[2], maid)
            return table.unpack(results, 2, results.n)
        end
    end
end

Library.Maid = nil
Library.MaidClass = Maid
Library.TabClass = Tab
Library.WindowClass = Window
Library.NewMaid = Maid.new

function Library:SetMemoryOptions(opts)
    opts = opts or {}
    if opts.SweepInterval ~= nil then Runtime.SweepInterval = math.max(0.25, tonumber(opts.SweepInterval) or 3) end
end

function Library:Collect(full)
    local dropped = sweepConnections(true)
    local collected, problem = pcall(collectgarbage, full and "collect" or "step")
    local stats = self:GetMemoryStats()
    stats.Dropped = dropped
    stats.Collected = collected
    if not collected then stats.CollectionError = tostring(problem) end
    return stats
end

function Library:GetMemoryStats()
    local window = self.Window
    local live, connections, pendingTasks = 0, 0, 0
    for maid in pairs(liveMaids) do
        live = live + 1
        for _, item in pairs(maid._tasks) do
            if typeof(item) == "RBXScriptConnection" and item.Connected then connections = connections + 1
            elseif typeof(item) == "thread" and coroutine.status(item) ~= "dead" then pendingTasks = pendingTasks + 1 end
        end
    end
    for _, connection in ipairs(Runtime.Connections) do
        if connection.Connected then connections = connections + 1 end
    end
    local elements = 0
    for _ in pairs(self.Elements or {}) do elements = elements + 1 end
    local instances = 0
    if window and window.Gui and window.Gui.Parent then instances = #window.Gui:GetDescendants() end
    local fadeCount = 0
    for _ in pairs(fadeCaches) do fadeCount = fadeCount + 1 end
    return {
        LuaKB = collectgarbage("count"),
        Connections = connections,
        PendingTasks = pendingTasks,
        CallbackErrors = Runtime.Stats.CallbackErrors or 0,
        LastCallbackError = Runtime.Stats.LastCallbackError,
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
        UpdateErrors = Runtime.Stats.UpdateErrors or 0,
        LastUpdateError = Runtime.Stats.LastUpdateError,
    }
end

function Library:MemoryReport()
    local s = self:GetMemoryStats()
    return string.format(
        "WolfUi memory: %.0f KB lua | %d instances | %d elements | %d conns (%d total, %d swept) | %d updates | %d maids (%d freed) | %d popups | %d notifs",
        s.LuaKB, s.Instances, s.Elements, s.Connections, s.ConnectionsTotal, s.ConnectionsSwept,
        s.Updates + s.OverlayUpdates, s.Maids, s.MaidsDestroyed, s.Popups, s.Notifications)
end

do
    local Extra = {Snapshots = {}, Journal = {}, AutoSave = nil}

    local function record(kind, message)
        local journal = Extra.Journal
        journal[#journal + 1] = {Time = os.clock(), Kind = kind, Message = tostring(message)}
        while #journal > 200 do table.remove(journal, 1) end
    end

    function Library:Log(message, kind)
        record(kind or "info", message)
    end

    function Library:GetLog()
        local copy = {}
        for index, entry in ipairs(Extra.Journal) do copy[index] = entry end
        return copy
    end

    function Library:ClearLog()
        Extra.Journal = {}
    end

    function Library:Safe(callback, ...)
        if type(callback) ~= "function" then return false, "callback is not a function" end
        local packed = table.pack(xpcall(callback, function(err)
            return debug.traceback(tostring(err), 2)
        end, ...))
        if packed[1] then return true, table.unpack(packed, 2, packed.n) end
        record("error", packed[2])
        warn("WolfUi: " .. tostring(packed[2]))
        return false, packed[2]
    end

    function Library:Debounce(callback, delay)
        assert(type(callback) == "function", "Debounce requires a callback")
        delay = math.max(0, Runtime.Number(delay, 0.25))
        local owner = Runtime.GetOwner() or self.Maid
        local pending
        return function(...)
            if self.Destroyed or owner and owner.Destroyed then return end
            if pending and coroutine.status(pending) ~= "dead" then
                pcall(task.cancel, pending)
                if owner then owner._tasks[pending] = nil end
            end
            owner = owner or Runtime.GetOwner() or self.Maid
            if owner then
                pending = owner:Delay(delay, callback, ...)
            else
                pending = task.delay(delay, function(...) self:Safe(callback, ...) end, ...)
            end
        end
    end

    function Library:Throttle(callback, interval)
        interval = math.max(0, tonumber(interval) or 0.1)
        local last = -math.huge
        return function(...)
            local now = os.clock()
            if now - last < interval then return false end
            last = now
            return Library:Safe(callback, ...)
        end
    end

    function Library:Snapshot(name)
        name = tostring(name or "default")
        Extra.Snapshots[name] = {Time = os.time(), Config = self:GetConfig()}
        record("snapshot", name)
        return name
    end

    function Library:RestoreSnapshot(name)
        name = tostring(name or "default")
        local item = Extra.Snapshots[name]
        if not item then return false, "snapshot not found: " .. name end
        record("restore", name)
        return self:LoadConfig(item.Config)
    end

    function Library:ListSnapshots()
        local names = {}
        for name in pairs(Extra.Snapshots) do names[#names + 1] = name end
        table.sort(names)
        return names
    end

    function Library:DeleteSnapshot(name)
        name = tostring(name or "default")
        local existed = Extra.Snapshots[name] ~= nil
        Extra.Snapshots[name] = nil
        return existed
    end

    function Library:Diagnostics()
        local env = Runtime.Env()
        local names = {
            "gethui", "get_hidden_gui", "cloneref", "loadstring", "getgenv", "identifyexecutor",
            "isfile", "readfile", "writefile", "delfile", "makefolder", "isfolder", "listfiles",
            "setclipboard", "queue_on_teleport", "request", "http_request",
        }
        local capabilities, missing = {}, {}
        for _, name in ipairs(names) do
            local value = env[name]
            if value == nil then value = _G[name] end
            capabilities[name] = value ~= nil
            if value == nil then missing[#missing + 1] = name end
        end
        local executor = "unknown"
        local identify = env.identifyexecutor or _G.identifyexecutor
        if type(identify) == "function" then
            local ok, first, second = pcall(identify)
            if ok and first then executor = tostring(first) .. (second and (" " .. tostring(second)) or "") end
        end
        local window = self.Window
        local host = "none"
        if window and window.Gui and window.Gui.Parent then host = tostring(window.Gui.Parent.Name) end
        local flagCount, elementCount = 0, 0
        for _ in pairs(self.Flags or {}) do flagCount = flagCount + 1 end
        for _ in pairs(self.Elements or {}) do elementCount = elementCount + 1 end
        return {
            Version = self.Version,
            Executor = executor,
            Host = host,
            Window = window ~= nil,
            Flags = flagCount,
            Elements = elementCount,
            Snapshots = #self:ListSnapshots(),
            LogEntries = #Extra.Journal,
            Capabilities = capabilities,
            Missing = missing,
            Memory = self:GetMemoryStats(),
        }
    end

    function Library:DiagnosticsReport()
        local info = self:Diagnostics()
        local lines = {
            string.format("WolfUi %s | executor: %s | host: %s", tostring(info.Version), info.Executor, info.Host),
            string.format("window: %s | flags: %d | elements: %d | snapshots: %d | log: %d",
                tostring(info.Window), info.Flags, info.Elements, info.Snapshots, info.LogEntries),
            "missing: " .. (#info.Missing > 0 and table.concat(info.Missing, ", ") or "nothing"),
            self:MemoryReport(),
        }
        return table.concat(lines, "\n")
    end

    function Library:CopyDiagnostics()
        local text = self:DiagnosticsReport()
        local env = Runtime.Env()
        local copy = env.setclipboard or _G.setclipboard
        if type(copy) == "function" then
            local ok = pcall(copy, text)
            return ok, text
        end
        return false, text
    end
end

do
    local createWindow = Library.CreateWindow
    Library.CreateWindow = function(self, ...)
        local ok, result = pcall(createWindow, self, ...)
        if not ok then
            self:Unload()
            error(result, 0)
        end
        return result
    end
    for _, name in ipairs({"Notify", "NotifyCards", "Dialog"}) do
        local factory = Library[name]
        Library[name] = function(self, ...)
            local api = factory(self, ...)
            if api then
                Runtime.CompleteApi(api, api.Maid, self.Window)
                if not api.GetMaid then api.GetMaid = function() return api.Maid end end
            end
            return api
        end
    end
end

do
    local Preview = {}
    Preview.__index = Preview
    local set = Runtime.SetProperty

    function Library.ComputeESPPreviewLayout(position, size, screen, width, height, gap, scale)
        local margin = 8
        width, height = math.max(1, width), math.max(1, height)
        scale = math.max(0.01, scale)
        local right = math.max(0, screen.X - position.X - size.X - gap - margin)
        local left = math.max(0, position.X - gap - margin)
        local fit = math.min(scale, math.max(0, screen.Y - margin * 2) / height)
        local side = right >= width * fit and "Right" or (left > right and "Left" or "Right")
        local room = side == "Right" and right or left
        local amount = math.min(fit, room / width)

        -- The preview is a visual control, not a layout-dependent decoration.
        -- On narrow screens it must remain reachable instead of disappearing.
        if amount < 0.55 then
            side = "Overlay"
            amount = math.min(fit, (screen.X - margin * 2) / width,
                (screen.Y - margin * 2) / height)
        end
        -- Keep a small but usable instance even while the window is being
        -- resized/animated and AbsoluteSize briefly reports a tiny viewport.
        if amount <= 0 then
            amount = math.min(scale, 0.32)
            side = "Overlay"
        end
        local minAmount = math.min(0.32, fit > 0 and fit or 0.32)
        if fit > 0 then amount = math.max(amount, minAmount) end

        local w, h = width * amount, height * amount
        local x, y = position.X + size.X + gap, position.Y + (size.Y - h) * 0.5
        if side == "Left" then
            x = position.X - gap - w
        elseif side == "Overlay" then
            x = position.X + size.X - w - margin
            y = position.Y + margin
        end
        return math.clamp(x, margin, math.max(margin, screen.X - margin - w)),
            math.clamp(y, margin, math.max(margin, screen.Y - margin - h)), amount, side
    end

    function Preview:GetMaid() return self.Maid end
    function Preview:GetValue() return self.State end
    function Preview:GetVisible() return self.Visible end
    function Preview:GetEnabled() return self.Enabled end
    function Preview:GetModel() return self.Model end
    function Preview:GetPart(name) return self.Parts[name] end
    function Preview:GetSize() return self.Size2D end

    function Preview:SetValue(value)
        if not self.Destroyed and type(value) == "table" then self.State = value; self.Dirty = true end
        return self
    end
    Preview.SetState = Preview.SetValue

    function Preview:SetVisible(value)
        if not self.Destroyed then
            self.Visible = value == true
            if not self.Visible then
                self.Object.Visible = false
                self.Holder.Visible = false
                self.Drag = nil
            else
                -- Rebuild immediately when a visible preview has no model. The
                -- render loop will handle layout; this only removes the startup
                -- race where the preview could remain on its waiting state.
                if self.Character and not self.Model then
                    self:Refresh(true)
                end
            end
        end
        return self
    end

    function Preview:SetEnabled(value)
        if not self.Destroyed then self.Enabled = value == true; self.Drag = nil end
        return self
    end

    function Preview:SetRenderer(callback)
        if not self.Destroyed then self.Renderer = type(callback) == "function" and callback or nil end
        return self
    end

    function Preview:SetStateProvider(callback)
        if not self.Destroyed then self.StateProvider = type(callback) == "function" and callback or nil end
        return self
    end

    function Preview:SetRotation(yaw, pitch)
        if self.Destroyed then return self end
        self.Yaw = Runtime.Number(yaw, self.Yaw) % 360
        self.Pitch = math.clamp(Runtime.Number(pitch, self.Pitch), -70, 70)
        self.CameraDirty = true
        return self
    end

    function Preview:SetPosition(value)
        if not self.Destroyed and typeof(value) == "Vector2" then
            self.Pan = Vector2.new(math.clamp(Runtime.Number(value.X, 0), -1, 1), math.clamp(Runtime.Number(value.Y, 0), -1, 1))
            self.CameraDirty = true
        end
        return self
    end

    function Preview:SetZoom(value)
        if not self.Destroyed then
            self.Zoom = math.clamp(Runtime.Number(value, self.Zoom or 1), 0.5, 2)
            self.CameraDirty = true
            if self.ZoomValue then
                self.ZoomValue.Text = string.format("%.1fx", self.Zoom)
            end
        end
        return self
    end

    function Preview:GetZoom()
        return self.Zoom or 1
    end

    function Preview:ResetView()
        return self:SetRotation(0, 0):SetPosition(Vector2.zero):SetZoom(1)
    end

    function Preview:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self.Drag, self.Renderer, self.StateProvider, self.Character = nil, nil, nil, nil
        self.Maid:Destroy()
        self.Model, self.World, self.Camera, self.Window = nil, nil, nil, nil
        self.StaticPose = nil
        table.clear(self.Parts)
        table.clear(self.Corners)
        self.State = {}
    end

    function Preview:ClearModel()
        if self.Model then self.Model:Destroy(); self.Model = nil end
        table.clear(self.Parts)
        table.clear(self.Corners)
        table.clear(self.StaticPose or {})
        self.StaticPose = {}
        self.BodyBounds, self.FullBounds = nil, nil
        self.Overlay.Visible = false
        self.Status.Text = "Waiting for character"
        self.Status.Visible = true
    end

    function Preview:FreezePose(model, root)
        local graph = {}
        for _, object in ipairs(model:GetDescendants()) do
            if object:IsA("Animator") or object:IsA("AnimationController") or object:IsA("Animation") then
                object:Destroy()
            elseif object:IsA("Humanoid") then
                object.AutoRotate = false
            elseif object:IsA("Bone") then
                object.Transform = CFrame.new()
            elseif object:IsA("JointInstance") or object:IsA("WeldConstraint") then
                local first, second = object.Part0, object.Part1
                if first and second and first:IsDescendantOf(model) and second:IsDescendantOf(model) then
                    local left, right
                    if object:IsA("WeldConstraint") then
                        left, right = first.CFrame:Inverse() * second.CFrame, CFrame.new()
                    else
                        left, right = object.C0, object.C1
                        if object:IsA("Motor6D") then object.Transform = CFrame.new() end
                    end
                    local edge = {first, second, left, right}
                    if not graph[first] then graph[first] = {} end
                    if not graph[second] then graph[second] = {} end
                    graph[first][#graph[first] + 1] = edge
                    graph[second][#graph[second] + 1] = edge
                end
            end
        end
        local queue, visited, index = {root}, {[root] = true}, 1
        while index <= #queue do
            local part = queue[index]
            index = index + 1
            for _, edge in ipairs(graph[part] or {}) do
                local first, second = edge[1], edge[2]
                if part == first and not visited[second] then
                    second.CFrame = first.CFrame * edge[3] * edge[4]:Inverse()
                    visited[second] = true
                    queue[#queue + 1] = second
                elseif part == second and not visited[first] then
                    first.CFrame = second.CFrame * edge[4] * edge[3]:Inverse()
                    visited[first] = true
                    queue[#queue + 1] = first
                end
            end
        end
    end

    function Preview:IsAppearanceChange(object)
        local current = object
        while current and current ~= self.Character do
            if current:IsA("Tool") then return false end
            current = current.Parent
        end
        -- Ignore executor visual artifacts: they can be recreated every frame,
        -- otherwise causing endless clone rebuilds and animation snapshots.
        local name = object.Name or ""
        if string.sub(name, 1, 7) == "Waraku_" or string.sub(name, 1, 7) == "Preview" then return false end
        if object:IsA("Highlight") or object:IsA("Adornment") or object:IsA("ParticleEmitter")
            or object:IsA("Beam") or object:IsA("Trail") then return false end
        return object:IsA("BasePart") or object:IsA("Accessory") or object:IsA("Clothing")
            or object:IsA("ShirtGraphic") or object:IsA("CharacterMesh") or object:IsA("DataModelMesh")
            or object:IsA("Decal") or object:IsA("SurfaceAppearance") or object:IsA("JointInstance")
    end

    function Preview:Rebuild()
        if self.Destroyed then return false end
        local character = self.Character
        if not character or not character.Parent then self:ClearModel(); return false end
        local archived = character.Archivable
        local ok, clone = pcall(function()
            character.Archivable = true
            return character:Clone()
        end)
        pcall(function() character.Archivable = archived end)
        if not ok or not clone then
            self:ClearModel()
            self.Status.Text = "Character unavailable"
            self.LastError = tostring(clone)
            return false
        end
        local ready, problem = pcall(function()
            for _, object in ipairs(clone:GetDescendants()) do
                if object:IsA("LuaSourceContainer") or object:IsA("Tool") or object:IsA("Sound")
                    or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                    or object:IsA("Highlight") or object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
                    object:Destroy()
                elseif object:IsA("BasePart") then
                    object.Anchored = true
                    object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
                    object.LocalTransparencyModifier = 0
                    object.AssemblyLinearVelocity = Vector3.zero
                    object.AssemblyAngularVelocity = Vector3.zero
                end
            end
            local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso") or clone:FindFirstChild("UpperTorso")
            if not root then error("Character has no root part") end
            clone:PivotTo(root.CFrame:Inverse() * clone:GetPivot())
            -- Reconstruct a neutral joint pose from Motor6D C0/C1 instead of
            -- retaining the live animation transforms copied by :Clone().
            self:FreezePose(clone, root)
            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            local bounds, size = clone:GetBoundingBox()
            clone:PivotTo(CFrame.new(-bounds.Position) * clone:GetPivot())
            self:ClearModel()
            self.Model = clone
            clone.Name = "ESPPreviewCharacter"
            clone.Parent = self.World
            self.ModelSize = size
            -- Freeze the final post-normalization pose as a snapshot.  Anchoring
            -- alone is not enough for every avatar rig: Motor6D/SkinnedMesh
            -- runtimes can still rewrite transforms.  Restoring this snapshot
            -- each preview frame guarantees that gameplay movement never leaks
            -- into the visual sample.
            self.StaticPose = {}
            for _, object in ipairs(clone:GetDescendants()) do
                if object:IsA("BasePart") then
                    self.StaticPose[object] = object.CFrame
                end
            end
            for _, object in ipairs(clone:GetDescendants()) do
                if object:IsA("BasePart") then
                    if object.Parent == clone then self.Parts[object.Name] = object end
                    if object.Name ~= "HumanoidRootPart" and object.Transparency < 1 then
                        local entry = {Body = object.Parent == clone, Points = {}}
                        for x = -1, 1, 2 do
                            for y = -1, 1, 2 do
                                for z = -1, 1, 2 do
                                    entry.Points[#entry.Points + 1] = object.CFrame:PointToWorldSpace(object.Size * Vector3.new(x, y, z) * 0.5)
                                end
                            end
                        end
                        self.Corners[#self.Corners + 1] = entry
                    end
                end
            end
            self.Status.Visible = false
            self.Overlay.Visible = true
            self.CameraDirty = true
        end)
        if not ready then
            clone:Destroy()
            self:ClearModel()
            self.Status.Text = "Character unavailable"
            self.LastError = tostring(problem)
        end
        return ready
    end

    function Preview:Refresh(immediate)
        if self.Destroyed then return self end
        if immediate == true or (self.Visible and not self.Model and self.Character) then
            self.RebuildAt = nil
            self:Rebuild()
        else
            self.RebuildAt = os.clock() + 0.12
        end
        return self
    end

    function Preview:SetCharacter(character)
        if self.Destroyed then return self end
        if character ~= nil and (typeof(character) ~= "Instance" or not character:IsA("Model")) then return self end
        if self.CharacterMaid then self.CharacterMaid:Destroy() end
        self.CharacterMaid = Maid.new(self.Maid)
        self.Character = character
        self:ClearModel()
        if character then
            self.CharacterMaid:Connect(character.DescendantAdded, function(object)
                if self:IsAppearanceChange(object) then self:Refresh() end
            end)
            self.CharacterMaid:Connect(character.DescendantRemoving, function(object)
                if self:IsAppearanceChange(object) then self:Refresh() end
            end)
            self.CharacterMaid:Connect(character.AncestryChanged, function(_, parent)
                if not parent then self:ClearModel() else self:Refresh() end
            end)
        end
        return self:Refresh(self.Visible == true)
    end

    function Preview:UpdateCamera()
        if not self.Model then return end
        local size = self:GetSize()
        local radius = self.ModelSize.Magnitude * 0.5
        local vertical = math.rad(self.Camera.FieldOfView) * 0.5
        local horizontal = math.atan(math.tan(vertical) * size.X / size.Y)
        local distance = radius / math.sin(math.min(vertical, horizontal)) * 1.18 / self.Zoom
        local orbit = CFrame.Angles(0, math.rad(self.Yaw), 0) * CFrame.Angles(math.rad(self.Pitch), 0, 0)
        local offset = orbit:VectorToWorldSpace(Vector3.new(0, 0, -distance))
        local target = orbit:VectorToWorldSpace(Vector3.new(self.Pan.X * radius, self.Pan.Y * radius, 0))
        self.Camera.CFrame = CFrame.lookAt(target + offset, target)
        self.FocalLength = size.Y * 0.5 / math.tan(vertical)
        self.CameraDirty = false
        self.BodyBounds, self.FullBounds = nil, nil
    end

    function Preview:Project(position)
        if self.Destroyed or not self.Camera then return nil end
        local point = self.Camera.CFrame:PointToObjectSpace(position)
        if point.Z >= -0.01 then return nil end
        local size = self:GetSize()
        return Vector2.new(size.X * 0.5 - point.X * self.FocalLength / point.Z,
            size.Y * 0.5 + point.Y * self.FocalLength / point.Z)
    end

    function Preview:GetBounds(accessories, padding)
        if not self.Model then return nil end
        if self.CameraDirty then self:UpdateCamera() end
        local cached
        if accessories then cached = self.FullBounds else cached = self.BodyBounds end
        if not cached then
            local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
            for _, entry in ipairs(self.Corners) do
                if accessories or entry.Body then
                    for _, corner in ipairs(entry.Points) do
                        local point = self:Project(corner)
                        if point then
                            x1, y1 = math.min(x1, point.X), math.min(y1, point.Y)
                            x2, y2 = math.max(x2, point.X), math.max(y2, point.Y)
                        end
                    end
                end
            end
            if x1 == math.huge then return nil end
            cached = {Vector2.new(x1, y1), Vector2.new(x2, y2), Vector2.new((x1 + x2) * 0.5, (y1 + y2) * 0.5)}
            if accessories then self.FullBounds = cached else self.BodyBounds = cached end
        end
        padding = math.clamp(Runtime.Number(padding, 0), 0, 32)
        if padding == 0 then return cached[1], cached[2], cached[3] end
        local offset = Vector2.new(padding, padding)
        return cached[1] - offset, cached[2] + offset, cached[3]
    end

    function Preview:Step(dt)
        if self.Destroyed or self.Rendering then return end
        local window = self.Window
        if not window or window.Destroyed or not self.Holder or not self.Holder.Parent then return end
        local screen = window.Viewport
        local menuScale = Runtime.Number(window.UIScale.Scale, window.ScaleCurrent or 1)
        local layout = window.Frame.Position
        local size = window.Frame.Size
        local origin = Vector2.new(layout.X.Scale * screen.X + layout.X.Offset, layout.Y.Scale * screen.Y + layout.Y.Offset)
        local menuSize = Vector2.new(size.X.Scale * screen.X + size.X.Offset, size.Y.Scale * screen.Y + size.Y.Offset) * menuScale
        local anchor = window.Frame.AnchorPoint or Vector2.zero
        origin = origin - Vector2.new(menuSize.X * anchor.X, menuSize.Y * anchor.Y)
        local x, y, scale, side = Library.ComputeESPPreviewLayout(origin,
            menuSize, screen, self.Width, self.Height, self.Gap, menuScale)
        self.Side = side
        local visible = self.Visible and window.Visible and not window.Destroyed and scale > 0
        set(self.Object, "Visible", visible)
        set(self.Holder, "Visible", visible)
        if not visible then self.Drag = nil; return end
        set(self.Holder, "Size", UDim2.fromOffset(self.Width * scale, self.Height * scale))
        set(self.Holder, "Position", UDim2.fromOffset(x + self.Width * scale * 0.5, y + self.Height * scale * 0.5))
        set(self.Scale, "Scale", scale)
        local alpha = math.clamp(window.Alpha or 1, 0, 1)
        set(self.Object, "BackgroundColor3", window.Frame.BackgroundColor3)
        set(self.Object, "BackgroundTransparency", window.Frame.BackgroundTransparency)
        set(self.Header, "TextTransparency", 1 - alpha)
        if self.MenuBorder then
            set(self.Border, "Color", self.MenuBorder.Color)
            set(self.Border, "Transparency", self.MenuBorder.Transparency)
            set(self.Border, "Thickness", self.MenuBorder.Thickness)
        end
        local now = os.clock()
        if self.RebuildAt and now >= self.RebuildAt then self.RebuildAt = nil; self:Rebuild() end
        if self.CameraDirty then self:UpdateCamera() end
        -- Force a lightweight render invalidation after resize/open. Some
        -- ViewportFrame/WorldModel combinations otherwise keep a stale first
        -- frame until a camera property changes.
        if self.Camera and self.Object.Visible and self._lastViewportSize ~= screen then
            self._lastViewportSize = screen
            local fov = self.Camera.FieldOfView
            self.Camera.FieldOfView = fov + 0.001
            self.Camera.FieldOfView = fov
        end
        -- Hard-lock the preview snapshot. This prevents animation controllers,
        -- avatar physics and any copied Motor6D state from mirroring live input.
        if self.Model and self.StaticPose then
            for part, cf in pairs(self.StaticPose) do
                if part.Parent then
                    if part.CFrame ~= cf then part.CFrame = cf end
                    if part.AssemblyLinearVelocity ~= Vector3.zero then
                        part.AssemblyLinearVelocity = Vector3.zero
                    end
                    if part.AssemblyAngularVelocity ~= Vector3.zero then
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
        self.Elapsed = self.Elapsed + dt
        if not self.Drag and self.Elapsed < self.Interval then fadeGroup(self.Canvas, alpha); return end
        local elapsed = self.Elapsed
        self.Elapsed = 0
        self.Rendering = true
        if self.StateProvider then
            local ok, state = pcall(self.StateProvider, self)
            if self.Destroyed then self.Rendering = false; return end
            if ok and type(state) == "table" then self.State = state elseif not ok then self.LastError = tostring(state) end
        end
        if self.Model and self.Renderer then
            local ok, problem = pcall(self.Renderer, self, elapsed, self.State)
            if self.Destroyed then self.Rendering = false; return end
            self.Overlay.Visible = ok
            if not ok then self.LastError = tostring(problem) end
        end
        self.Rendering = false
        fadeGroup(self.Canvas, alpha)
    end

    function Preview:BindInput()
        self.Maid:Connect(self.InputSurface.InputBegan, function(input)
            if not self.Enabled or not self.Object.Visible or self.Window.Dialog or self.Window.Opened then return end
            local kind = input.UserInputType
            if self.Drag then
                if kind == Enum.UserInputType.Touch and self.Drag.Kind == kind and input ~= self.Drag.Input then
                    self.Drag.Secondary = input
                    self.Drag.SecondaryPosition = Vector2.new(input.Position.X, input.Position.Y)
                    self.Drag.Move = true
                    local p1 = self.Drag.Input.Position
                    local p2 = input.Position
                    self.Drag.PinchDistance = math.max(1, (Vector2.new(p1.X, p1.Y) - Vector2.new(p2.X, p2.Y)).Magnitude)
                    self.Drag.PinchZoom = self.Zoom
                    self.Drag.PinchMid = (Vector2.new(p1.X, p1.Y) + Vector2.new(p2.X, p2.Y)) * 0.5
                end
                return
            end
            if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.MouseButton2 and kind ~= Enum.UserInputType.Touch then return end
            self.Drag = {Input = input, Kind = kind, Last = Vector2.new(input.Position.X, input.Position.Y),
                Move = kind == Enum.UserInputType.MouseButton2 or self.MoveMode}
        end)
        self.Maid:Connect(UIS.InputChanged, function(input)
            local drag = self.Drag
            if not drag then return end
            if not self.Enabled or not self.Object.Visible or self.Window.Dialog or self.Window.Opened then self.Drag = nil; return end
            local secondary = input == drag.Secondary
            if drag.Kind == Enum.UserInputType.Touch then
                if input ~= drag.Input and not secondary then return end
            elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local position = Vector2.new(input.Position.X, input.Position.Y)
            if drag.Kind == Enum.UserInputType.Touch and drag.Secondary then
                -- Two-finger gesture: pinch controls zoom while the midpoint
                -- continues to pan the preview.
                local p1 = Vector2.new(drag.Input.Position.X, drag.Input.Position.Y)
                local p2 = Vector2.new(drag.Secondary.Position.X, drag.Secondary.Position.Y)
                local distance = math.max(1, (p1 - p2).Magnitude)
                local midpoint = (p1 + p2) * 0.5
                if drag.PinchDistance and drag.PinchDistance > 1 then
                    self:SetZoom((drag.PinchZoom or self.Zoom) * distance / drag.PinchDistance)
                end
                local deltaMid = (midpoint - (drag.PinchMid or midpoint)) / math.max(0.01, self.Scale.Scale)
                drag.PinchMid = midpoint
                self:SetPosition(self.Pan + Vector2.new(deltaMid.X / self.Size2D.X, deltaMid.Y / self.Size2D.Y) * 2)
                if secondary then drag.SecondaryPosition = position else drag.Last = position end
            else
                local delta = (position - (secondary and drag.SecondaryPosition or drag.Last)) / math.max(0.01, self.Scale.Scale)
                if secondary then drag.SecondaryPosition = position else drag.Last = position end
                if drag.Move then
                    self:SetPosition(self.Pan + Vector2.new(delta.X / self.Size2D.X, delta.Y / self.Size2D.Y) * 2)
                else
                    self:SetRotation(self.Yaw - delta.X * 0.6, self.Pitch + delta.Y * 0.4)
                end
            end
        end)
        self.Maid:Connect(UIS.InputEnded, function(input)
            local drag = self.Drag
            if drag and drag.Secondary and (input == drag.Input or input == drag.Secondary) then
                if input == drag.Input then
                    drag.Input = drag.Secondary
                    drag.Last = drag.SecondaryPosition
                end
                drag.Secondary, drag.SecondaryPosition, drag.Move = nil, nil, false
                drag.PinchDistance, drag.PinchZoom, drag.PinchMid = nil, nil, nil
                return
            end
            if drag and (input == drag.Input or drag.Kind ~= Enum.UserInputType.Touch and input.UserInputType == drag.Kind) then self.Drag = nil end
        end)
        self.Maid:Connect(UIS.WindowFocusReleased, function() self.Drag = nil end)

        -- Mouse wheel zoom.  Keep this separate from drag state so zoom remains
        -- responsive even while the preview is being rotated.
        self.Maid:Connect(self.InputSurface.InputChanged, function(input)
            if self.Enabled and self.Object.Visible and not self.Window.Dialog and not self.Window.Opened
                and input.UserInputType == Enum.UserInputType.MouseWheel then
                self:SetZoom(self.Zoom * (1.1 ^ math.clamp(input.Position.Z, -4, 4)))
            end
        end)

        -- Explicit +/- controls make zoom usable on touch devices where a mouse
        -- wheel is unavailable.  They sit above the transparent input surface.
        local minus = rect(self.Object, self.Width - 52, 4, 22, 22, palette[4], 5, "TextButton")
        minus.Name, minus.ZIndex, minus.Text = "PreviewZoomOut", 22, "−"
        minus.TextColor3, minus.TextSize, minus.Font = white, 13, UI_FONT_BOLD
        minus.AutoButtonColor = false
        local plus = rect(self.Object, self.Width - 27, 4, 22, 22, palette[4], 5, "TextButton")
        plus.Name, plus.ZIndex, plus.Text = "PreviewZoomIn", 22, "+"
        plus.TextColor3, plus.TextSize, plus.Font = white, 13, UI_FONT_BOLD
        plus.AutoButtonColor = false
        local zoomValue = new("TextLabel", self.Object, {
            Name = "PreviewZoomValue",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(self.Width - 101, 4),
            Size = UDim2.fromOffset(45, 22),
            Text = "1.0x",
            TextColor3 = white,
            TextTransparency = 0.15,
            Font = UI_FONT,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 22,
        })
        self.ZoomOut, self.ZoomIn, self.ZoomValue = minus, plus, zoomValue
        self.Maid:Connect(minus.MouseButton1Click, function()
            if self.Enabled and self.Object.Visible and not self.Destroyed then self:SetZoom(self.Zoom - 0.1) end
        end)
        self.Maid:Connect(plus.MouseButton1Click, function()
            if self.Enabled and self.Object.Visible and not self.Destroyed then self:SetZoom(self.Zoom + 0.1) end
        end)
        self.Maid:Connect(minus.MouseEnter, function()
            if not self.Destroyed then minus.BackgroundColor3 = palette[5] end
        end)
        self.Maid:Connect(minus.MouseLeave, function()
            if not self.Destroyed then minus.BackgroundColor3 = palette[4] end
        end)
        self.Maid:Connect(plus.MouseEnter, function()
            if not self.Destroyed then plus.BackgroundColor3 = palette[5] end
        end)
        self.Maid:Connect(plus.MouseLeave, function()
            if not self.Destroyed then plus.BackgroundColor3 = palette[4] end
        end)
    end

    function Window:CreateESPPreview(options)
        options = type(options) == "table" and options or {}
        assert(not self.Destroyed and self.Gui and self.Gui.Parent, "CreateESPPreview requires a live window")
        local maid = Maid.new(Library.Maid)
        local preview = setmetatable({Window = self, Maid = maid, Width = math.clamp(Runtime.Number(options.Width, 180), 120, 420),
            Height = math.clamp(Runtime.Number(options.Height, 250), 160, 600), Gap = math.clamp(Runtime.Number(options.Gap, 16), 4, 60),
            Visible = options.Visible ~= false, Enabled = options.Enabled ~= false, State = {}, Parts = {}, Corners = {},
            Yaw = 0, Pitch = 0, Zoom = 1, Pan = Vector2.zero, StaticPose = {}, Elapsed = 0, FocalLength = 1,
            Interval = 1 / math.clamp(Runtime.Number(options.UpdateRate, 30), 1, 60)}, Preview)
        preview.Size2D = Vector2.new(preview.Width, preview.Height - 32)
        local ok, problem = pcall(function()
            local holder = transparent(self.Gui, 0, 0, preview.Width, preview.Height)
            holder.Name, holder.AnchorPoint, holder.ZIndex = "WolfUiESPPreviewAnchor", Vector2.new(0.5, 0.5), 1
            preview.Holder = holder
            maid:Add(holder)
            local panel = rect(holder, 0, 0, preview.Width, preview.Height, self.Frame.BackgroundColor3, 12)
            preview.Object = panel
            panel.Name, panel.ZIndex, panel.Visible = "WolfUiESPPreview", 1, false
            panel.BackgroundTransparency = self.Frame.BackgroundTransparency
            maid:Add(panel)
            preview.Scale = new("UIScale", panel, {Scale = 1})
            preview.MenuBorder = self.Frame:FindFirstChildOfClass("UIStroke")
            if preview.MenuBorder then
                preview.Border = preview.MenuBorder:Clone()
                preview.Border.Parent = panel
            else
                preview.Border = new("UIStroke", panel, {Color = Color3.fromRGB(128, 128, 128), Thickness = 1, Transparency = 0.58})
            end
            local gradient = self.Frame:FindFirstChildOfClass("UIGradient")
            if gradient then local copy = gradient:Clone(); copy.Parent = panel end
            preview.Header = text(panel, options.Title or "ESP preview", 12, 0, math.max(70, preview.Width - 112), 32, 12).Object
            preview.Canvas = transparent(panel, 0, 32, preview.Width, preview.Size2D.Y)
            preview.Canvas.ClipsDescendants = true
            local viewport = new("ViewportFrame", preview.Canvas, {Name = "Character", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1),
                BorderSizePixel = 0, Active = true, Ambient = Color3.fromRGB(180, 180, 180),
                LightColor = Color3.fromRGB(220, 220, 220), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 1})
            preview.Viewport = viewport
            preview.Camera = new("Camera", viewport, {FieldOfView = 35})
            viewport.CurrentCamera = preview.Camera
            preview.World = new("WorldModel", viewport, {Name = "PreviewWorld"})
            preview.Overlay = new("Frame", preview.Canvas, {Name = "ESP", BackgroundTransparency = 1, BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Active = false, ZIndex = 2})
            preview.InputSurface = transparent(preview.Canvas, 0, 0, preview.Width, preview.Size2D.Y, "TextButton")
            preview.InputSurface.Name, preview.InputSurface.ZIndex = "ModelInput", 20
            preview.Status = text(preview.Canvas, "Waiting for character", 12, preview.Size2D.Y * 0.5 - 16, preview.Width - 24, 32, 11, white, "center").Object
            preview:BindInput()
            preview:SetRenderer(options.Render or options.Renderer):SetStateProvider(options.StateProvider):SetValue(options.State or {})
            preview:SetCharacter(options.Character or player.Character)
            if options.Character == nil then
                maid:Connect(player.CharacterAdded, function(character) preview:SetCharacter(character) end)
                maid:Connect(player.CharacterRemoving, function(character) if preview.Character == character then preview:SetCharacter(nil) end end)
                maid:Connect(player.CharacterAppearanceLoaded, function(character) if preview.Character == character then preview:Refresh() end end)
            end
            maid:Connect(panel.Destroying, function() preview:Destroy() end)
            maid:Connect(holder.Destroying, function() preview:Destroy() end)
            maid:Add(function() preview:Destroy() end)
            maid:Connect(RunService.RenderStepped, function(dt) preview:Step(dt) end)
        end)
        if not ok then preview:Destroy(); error(problem, 0) end
        return preview
    end

    function Library:CreateESPPreview(options)
        assert(self.Window, "CreateESPPreview requires a window")
        return self.Window:CreateESPPreview(options)
    end
    Library.ESPPreviewRevision = "chams-stable-16-preview-glow-zoom"
end


Library.Runtime = Runtime
Library.Palette = palette
Library.Icons = IconSheet

return Library
