local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "WolfUi must run on the client")
local playerGui = player:WaitForChild("PlayerGui")
local WHITE = Color3.fromRGB(238, 240, 247)
local FONT = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold
local themes = {
    {Color3.fromRGB(17, 19, 25), Color3.fromRGB(24, 27, 35), Color3.fromRGB(158, 166, 185), Color3.fromRGB(32, 36, 46), Color3.fromRGB(42, 47, 59), Color3.fromRGB(65, 73, 94)},
    {Color3.fromRGB(26, 29, 35), Color3.fromRGB(34, 38, 46), Color3.fromRGB(180, 187, 202), Color3.fromRGB(43, 48, 58), Color3.fromRGB(55, 61, 73), Color3.fromRGB(77, 86, 107)},
    {Color3.fromRGB(10, 11, 14), Color3.fromRGB(17, 18, 23), Color3.fromRGB(166, 170, 182), Color3.fromRGB(27, 29, 36), Color3.fromRGB(38, 41, 49), Color3.fromRGB(59, 63, 76)},
}
local Library = {Version = "4.0.0", Flags = {}, Elements = {}, Theme = 1, Scale = 100,
    Themes = themes, ThemeNames = {"Wolf", "Slate", "Black"}, ScaleOptions = {100, 110, 125},
    Accent = Color3.fromRGB(144, 159, 235), AccentAlpha = 1, Window = nil,
    Runtime = {Alive = false}, _Changes = {}, _Unloads = {}}
local Window, Tab, Element = {}, {}, {}
Window.__index, Tab.__index, Element.__index = Window, Tab, Element
local function finite(value, fallback)
    local n = tonumber(value)
    if not n or n ~= n or math.abs(n) == math.huge then return fallback end
    return n
end
local function round(value) return math.floor(value + 0.5) end
local function clone(value)
    if type(value) ~= "table" or typeof(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = clone(v) end; return out
end
local function remove(list, item)
    for i = #list, 1, -1 do if list[i] == item then table.remove(list, i) end end
end
local function invoke(callback, ...)
    if type(callback) ~= "function" then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(callback, table.unpack(args, 1, args.n))
        if not ok then warn("WolfUi callback: " .. tostring(err)) end
    end)
end
local Scope = {}; Scope.__index = Scope
local function scope(parent)
    local s = setmetatable({Alive = true, Connections = {}, Children = {}, Styles = {}, Parent = parent}, Scope)
    if parent then parent.Children[#parent.Children + 1] = s end
    return s
end
function Scope:Connect(signal, callback)
    local c = signal:Connect(function(...) if self.Alive then callback(...) end end)
    self.Connections[#self.Connections + 1] = c
    return c
end
function Scope:Refresh()
    for _, style in ipairs(self.Styles) do
        if style.Object.Parent then style.Object[style.Property] = style.Value() end
    end
    for _, child in ipairs(self.Children) do child:Refresh() end
end
function Scope:Destroy()
    if not self.Alive then return end
    self.Alive = false
    for _, child in ipairs(table.clone(self.Children)) do child:Destroy() end
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    self.Connections, self.Children, self.Styles = {}, {}, {}
    if self.Parent then remove(self.Parent.Children, self) end
end
local function style(s, object, property, value)
    local get = type(value) == "function" and value or function() return Library.Themes[Library.Theme][value] end
    object[property] = get()
    s.Styles[#s.Styles + 1] = {Object = object, Property = property, Value = get}
end
local function make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function frame(parent, radius, class)
    local object = make(class or "Frame", parent, {BorderSizePixel = 0, BackgroundTransparency = 1})
    if object:IsA("TextButton") then object.Text = ""; object.AutoButtonColor = false end
    if radius then make("UICorner", object, {CornerRadius = UDim.new(0, radius)}) end
    return object
end
local function label(parent, value, size, bold)
    return make("TextLabel", parent, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = tostring(value or ""), Font = bold and BOLD or FONT, TextSize = size or 14,
        TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
        TextWrapped = false, TextScaled = false, RichText = false, ZIndex = 2})
end
local function button(parent, value, s, radius)
    local object = frame(parent, radius or 6, "TextButton")
    object.BackgroundTransparency = 0
    object.Text, object.Font, object.TextSize, object.TextColor3 = value or "", FONT, 14, WHITE
    style(s, object, "BackgroundColor3", 4)
    s:Connect(object.MouseEnter, function() if object.Parent then object.BackgroundColor3 = themes[Library.Theme][5] end end)
    s:Connect(object.MouseLeave, function() if object.Parent then object.BackgroundColor3 = themes[Library.Theme][4] end end)
    return object
end
local function place(object, x, y, w, h)
    object.Position, object.Size = UDim2.fromOffset(round(x), round(y)), UDim2.fromOffset(round(w), round(h))
end
local function scroll(parent)
    return make("ScrollingFrame", parent, {BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never, ScrollingEnabled = true, Active = true, ClipsDescendants = true})
end
local function primary(input)
    return input and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
end
local function point(input) return Vector2.new(input.Position.X, input.Position.Y) end
local function shown(object)
    if not object or not object.Parent then return false end
    while object do
        if object:IsA("GuiObject") and not object.Visible then return false end
        object = object.Parent
    end
    return true
end
local function inside(p, object)
    local pos, size = object.AbsolutePosition, object.AbsoluteSize
    return p.X >= pos.X and p.Y >= pos.Y and p.X <= pos.X + size.X and p.Y <= pos.Y + size.Y
end
local function clampPoint(p, size, viewport)
    return Vector2.new(round(math.clamp(p.X, 0, math.max(0, viewport.X - size.X))),
        round(math.clamp(p.Y, 0, math.max(0, viewport.Y - size.Y))))
end
local function fire(flag, value)
    if flag == nil then return end
    Library.Flags[flag] = clone(value)
    local w = Library.Window
    if w and w.Alive then
        w.Changed:Fire(flag, clone(value))
        if type(value) ~= "table" and typeof(value) ~= "EnumItem" then
            local name = tostring(flag):gsub("[^%w_]", "_")
            if name:match("^%d") then name = "_" .. name end
            pcall(function() w.Gui:SetAttribute(name, value); w.Events:SetAttribute(name, value) end)
        end
    end
    for _, listener in ipairs(Library._Changes) do if listener.Connected then invoke(listener.Callback, flag, clone(value)) end end
end
local function listen(list, callback)
    assert(type(callback) == "function", "Callback must be a function")
    local entry = {Connected = true, Callback = callback}
    function entry:Disconnect() self.Connected = false; remove(list, self) end
    list[#list + 1] = entry
    return entry
end
function Library:OnChange(callback) return listen(self._Changes, callback) end
function Library:OnUnload(callback) return listen(self._Unloads, callback) end
function Library:GetFlag(flag) return clone(self.Flags[flag]) end
function Library:SetFlag(flag, value)
    local element = self.Elements[flag]
    if element and element.Set then return element:Set(value) end
    fire(flag, value)
end
function Library:SetTheme(index)
    self.Theme = math.clamp(math.floor(finite(index, 1)), 1, #themes)
    if self.Window then self.Window.Scope:Refresh(); self.Window:RefreshControls() end
    fire("Theme", self.Theme)
end
function Library:SetAccent(color, alpha)
    if typeof(color) == "Color3" then self.Accent = color; fire("Accent", color) end
    if alpha ~= nil then self.AccentAlpha = math.clamp(finite(alpha, 1), 0, 1); fire("AccentAlpha", self.AccentAlpha) end
    if self.Window then self.Window.Scope:Refresh(); self.Window:RefreshControls() end
end

function Window:BindDrag(object, s, config)
    s:Connect(object.InputBegan, function(input)
        if not primary(input) or self.Drag or not shown(object) then return end
        if config.CanStart and not config.CanStart() then return end
        self.CenterGesture = nil
        local drag = {Input = input, Object = object, Start = point(input), Point = point(input), Moved = false,
            Config = config, Scrolls = {}, Origin = config.GetPosition and config.GetPosition() or Vector2.new(0, 0)}
        if config.LockScroll then
            local parent = object.Parent
            while parent and parent ~= self.Gui do
                if parent:IsA("ScrollingFrame") then drag.Scrolls[parent] = parent.ScrollingEnabled; parent.ScrollingEnabled = false end
                parent = parent.Parent
            end
        end
        self.Drag = drag
        drag.Connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
            if self.Drag == drag and input.UserInputState == Enum.UserInputState.Cancel then self:EndDrag(true) end
        end)
        if config.Begin then config.Begin(drag.Point) end
        if config.Immediate and config.Move then config.Move(drag.Point, drag) end
    end)
    s:Connect(object.Destroying, function() if self.Drag and self.Drag.Object == object then self:EndDrag(true) end end)
    if config.Click and object:IsA("GuiButton") then
        s:Connect(object.Activated, function(input)
            if primary(input) then return end
            if shown(object) and (not config.CanStart or config.CanStart()) then config.Click() end
        end)
    end
end
function Window:MoveDrag(p)
    local drag = self.Drag
    if not drag then return end
    if not shown(drag.Object) then self:EndDrag(true); return end
    drag.Point = p
    local delta = p - drag.Start
    if delta.X * delta.X + delta.Y * delta.Y >= 49 then drag.Moved = true end
    if (drag.Moved or drag.Config.Immediate) and drag.Config.Move then drag.Config.Move(p, drag) end
end
function Window:EndDrag(cancelled)
    local drag = self.Drag
    if not drag then return end
    self.Drag = nil
    if drag.Connection then drag.Connection:Disconnect() end
    for object, enabled in pairs(drag.Scrolls) do if object.Parent then object.ScrollingEnabled = enabled end end
    if drag.Config.Finish then drag.Config.Finish(cancelled == true, drag) end
    if not cancelled and not drag.Moved and drag.Config.Click and shown(drag.Object) and inside(drag.Point, drag.Object) then drag.Config.Click() end
end

local function guiHost()
    for _, getter in ipairs({type(gethui) == "function" and gethui or function() return nil end,
        function() return game:GetService("CoreGui") end}) do
        local ok, host = pcall(getter)
        if ok and typeof(host) == "Instance" then
            local writable = pcall(function() local probe = Instance.new("Folder"); probe.Parent = host; probe:Destroy() end)
            if writable then return host, true end
        end
    end
    return playerGui, false
end
function Library:CreateWindow(opts)
    opts = opts or {}
    if self.Window then self:Unload() end
    self.Theme = math.clamp(math.floor(finite(opts.Theme, 1)), 1, #themes)
    self.Scale = math.clamp(finite(opts.Scale, 100), 100, 150)
    self.Accent = typeof(opts.Accent) == "Color3" and opts.Accent or Color3.fromRGB(144, 159, 235)
    self.AccentAlpha = math.clamp(finite(opts.AccentAlpha, 1), 0, 1)
    self:SetScriptName(opts.Folder or opts.ScriptName or opts.Name or "Wolf")
    local w = setmetatable({Alive = true, Scope = scope(), Tabs = {}, TabList = {}, Controls = {}, QuickButtons = {},
        QuickButtonIds = {}, SettingsPanels = {}, SettingsStack = {}, Notifications = {}, Keybinds = {}, ActiveTouches = {},
        Position = Vector2.new(0, 0), Viewport = Vector2.new(1280, 720), BoundToScreen = opts.BoundToScreen == true,
        RequestedSize = Vector2.new(finite(opts.Width, 640), finite(opts.Height, 480)),
        ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift, Initialized = false, Name = opts.Name or "Wolf"}, Window)
    self.Window, self.Runtime.Alive = w, true
    local host, protected = guiHost()
    local gui = make("ScreenGui", nil, {Name = opts.GuiName or "WolfUI", ResetOnSpawn = false,
        IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = opts.DisplayOrder or 10000})
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
    if type(syn) == "table" and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, gui) end
    gui.Parent = host
    w.Gui, w.Host, w.Protected = gui, host, protected
    w.Events = make("Folder", playerGui, {Name = opts.GuiName or "WolfUI"})
    for _, name in ipairs({"Changed", "TabChanged", "ButtonPressed"}) do w[name] = make("BindableEvent", w.Events, {Name = name}) end
    w.Frame = frame(gui, 10); w.Frame.BackgroundTransparency = 0; w.Frame.Active = true; w.Frame.ClipsDescendants = true
    style(w.Scope, w.Frame, "BackgroundColor3", 1)
    local border = make("UIStroke", w.Frame, {Thickness = 1, Transparency = 0.45}); style(w.Scope, border, "Color", 6)
    w.Header = frame(w.Frame, nil, "TextButton"); w.Header.Name = "DragHandle"
    w.Title = label(w.Header, w.Name, 17, true)
    w.CloseButton = button(w.Frame, "×", w.Scope)
    w.Scope:Connect(w.CloseButton.Activated, function() w:SetVisible(false) end)
    w.Sidebar = frame(w.Frame); style(w.Scope, w.Sidebar, "BackgroundColor3", 2); w.Sidebar.BackgroundTransparency = 0
    w.TabHolder = scroll(w.Sidebar); w.TabHolder.ScrollBarThickness = 0
    w.Scroll = scroll(w.Frame); style(w.Scope, w.Scroll, "ScrollBarImageColor3", 6)
    w:BindDrag(w.Header, w.Scope, {GetPosition = function() return w.Position end,
        Move = function(p, drag) w.Position = drag.Origin + p - drag.Start; w:LayoutPosition() end})
    w.CancelDrag = function() w:EndDrag(true) end
    w:InitializeAccess(opts)
    w.Scope:Connect(UIS.InputChanged, function(input)
        local drag = w.Drag
        if drag and (input == drag.Input or (drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
            w:MoveDrag(point(input))
        end
        local gesture = w.CenterGesture
        if gesture and (input == gesture.Input or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = point(input) - gesture.Start
            if d.X * d.X + d.Y * d.Y > 64 then w.CenterGesture = nil end
        end
    end)
    w.Scope:Connect(UIS.InputEnded, function(input)
        w.ActiveTouches[input] = nil
        local drag = w.Drag
        if drag and (input == drag.Input or (drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
            w:MoveDrag(input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:GetMouseLocation() or point(input))
            w:EndDrag(false)
        end
        if w.CenterGesture and input == w.CenterGesture.Input then
            local gesture = w.CenterGesture
            local elapsed = os.clock() - gesture.Time
            local delta = point(input) - gesture.Start
            w.CenterGesture = nil
            if elapsed <= 0.35 and delta.X * delta.X + delta.Y * delta.Y <= 64 then w:Toggle() end
        end
    end)
    w.Scope:Connect(UIS.WindowFocusReleased, function() w.CenterGesture = nil; w.ActiveTouches = {}; w:EndDrag(true) end)
    w.Scope:Connect(UIS.InputBegan, function(input, processed) w:InputBegan(input, processed) end)
    w.Scope:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function() w:EndDrag(true); w:Layout() end)
    w.Scope:Connect(gui.Destroying, function() if Library.Window == w then Library:Unload() end end)
    local elapsed, frames = 0, 0
    w.Scope:Connect(RunService.RenderStepped, function(dt)
        elapsed, frames = elapsed + dt, frames + 1
        if elapsed >= 0.5 then w:UpdateAccess(math.floor(frames / elapsed + 0.5)); elapsed, frames = 0, 0 end
        for i = #w.Notifications, 1, -1 do
            local n = w.Notifications[i]; n.Remaining = n.Remaining - dt
            if n.Remaining <= 0 then n:Destroy() end
        end
    end)
    w:Layout(); w:UpdateAccess(60)
    return w
end
function Window:LayoutPosition()
    if self.BoundToScreen then self.Position = clampPoint(self.Position, self.Size, self.Viewport) end
    self.Position = Vector2.new(round(self.Position.X), round(self.Position.Y))
    self.Frame.Position = UDim2.fromOffset(self.Position.X, self.Position.Y)
    self:LayoutOverlays()
end
function Window:Layout()
    if not self.Alive then return end
    local v = self.Gui.AbsoluteSize
    if v.X <= 0 or v.Y <= 0 then v = workspace.CurrentCamera.ViewportSize end
    self.Viewport = v
    local width = math.max(1, math.min(self.RequestedSize.X * Library.Scale / 100, v.X - 16))
    local height = math.max(1, math.min(self.RequestedSize.Y, v.Y - 16))
    self.Size = Vector2.new(round(width), round(height))
    self.Frame.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
    local side = width < 500 and 68 or 92
    self.ContentWidth = math.max(1, width - side - 28)
    place(self.Header, 0, 0, math.max(1, width - 50), 48)
    place(self.Title, 16, 0, math.max(1, width - 86), 48)
    place(self.CloseButton, width - 44, 8, 34, 32)
    place(self.Sidebar, 0, 48, side, math.max(1, height - 48))
    self.TabHolder.Size = UDim2.fromScale(1, 1)
    place(self.Scroll, side, 48, width - side, math.max(1, height - 48))
    for i, tab in ipairs(self.TabList) do
        place(tab.Button, 6, (i - 1) * 48 + 8, side - 12, 40)
        tab.ContentWidth = self.ContentWidth; tab:Layout()
    end
    self.TabHolder.CanvasSize = UDim2.fromOffset(0, #self.TabList * 48 + 16)
    if not self.Initialized then self.Position = (v - self.Size) / 2; self.Initialized = true end
    self:LayoutPosition(); self:LayoutAccess(); self:LayoutQuickButtons()
end
function Window:SetVisible(value)
    if not self.Alive then return end
    self.Frame.Visible = value == true
    if not value then self:EndDrag(true); self:CloseSettings(); self:ClosePopup(); self.PendingKeybind = nil end
end
function Window:Toggle()
    local p, v = self.Position, self.Viewport
    if p.X + self.Size.X < 40 or p.Y + self.Size.Y < 40 or p.X > v.X - 40 or p.Y > v.Y - 40 then self:Center() end
    self:SetVisible(not self.Frame.Visible)
end
function Window:Center() self:EndDrag(true); self.Initialized = false; self:Layout() end
function Window:SetPosition(x, y) self:EndDrag(true); self.Position = Vector2.new(finite(x, 0), finite(y, 0)); self:LayoutPosition() end
function Window:SetBoundsEnabled(value) self.BoundToScreen = value == true; self:LayoutPosition() end
function Window:SetScale(value)
    Library.Scale = math.clamp(finite(value, 100), 100, 150)
    self:EndDrag(true); self:Layout(); fire("Scale", Library.Scale); return Library.Scale
end
function Window:SetTheme(value) Library:SetTheme(value) end
function Window:Destroy() if Library.Window == self then Library:Unload() end end
function Window:RefreshControls()
    for _, tab in ipairs(self.TabList) do tab.Button.TextColor3 = tab == self.Current and Library.Accent or themes[Library.Theme][3] end
    for _, element in ipairs(self.Controls) do if not element.Destroyed and element.Render then element:Render() end end
    for _, quick in ipairs(self.QuickButtons) do quick:Render() end
end
function Window:CreateTab(opts)
    opts = type(opts) == "table" and opts or {Name = opts}
    local name = tostring(opts.Name or ("Tab " .. tostring(#self.TabList + 1)))
    assert(not self.Tabs[name], "Duplicate tab: " .. name)
    local s = scope(self.Scope)
    local page = frame(self.Scroll); page.Position = UDim2.fromOffset(12, 12); page.Visible = false
    local tab = setmetatable({Window = self, Name = name, Page = page, Scope = s, Items = {}, Elements = {},
        ContentWidth = self.ContentWidth or 400, Height = 0}, Tab)
    tab.RootTab = tab
    tab.Button = button(self.TabHolder, opts.Title or name, s)
    tab.Button.TextSize = 12
    tab.Button.TextWrapped = true
    s:Connect(tab.Button.Activated, function() self:SelectTab(tab) end)
    self.Tabs[name], self.TabList[#self.TabList + 1] = tab, tab
    if not self.Current then self:SelectTab(tab) end
    self:Layout()
    return tab
end
function Window:SelectTab(name)
    local tab = type(name) == "table" and name or self.Tabs[name]
    if not tab or tab.Window ~= self then return end
    self:CloseSettings(); self:ClosePopup()
    self.Current = tab
    for _, item in ipairs(self.TabList) do
        item.Page.Visible = item == tab
        item.Button.TextColor3 = item == tab and Library.Accent or themes[Library.Theme][3]
    end
    self.Scroll.CanvasPosition = Vector2.new(0, 0)
    tab:Layout(); fire("Tab", tab.Name); self.TabChanged:Fire(tab.Name)
end
function Tab:Layout()
    if self.LayingOut or not self.Page.Parent then return end
    self.LayingOut = true
    local width, x, y, row = self.ContentWidth, 0, 0, 0
    local gap = 10
    for _, item in ipairs(self.Items) do
        if not item.Destroyed and item.Visible then
            local fraction = math.clamp(finite(item.Options.Width, 1), 0.25, 1)
            if width < 440 or item.Kind == "Section" or item.Kind == "Divider" then fraction = 1 end
            local w = math.min(width, math.max(1, math.floor((width + gap) * fraction - gap)))
            if x > 0 and x + w > width + 1 then x, y, row = 0, y + row + gap, 0 end
            item.Width = w
            if item.Resize then item:Resize(w) end
            if item.Accessories then item:LayoutAccessories(w) end
            place(item.Object, x, y, w, item.Height)
            row = math.max(row, item.Height); x = x + w + gap
        end
    end
    self.Height = y + row
    self.Page.Size = UDim2.fromOffset(width, math.max(1, self.Height))
    if self.Scroll then self.Scroll.CanvasSize = UDim2.fromOffset(0, self.Height + 24)
    elseif self.Window.Current == self then self.Window.Scroll.CanvasSize = UDim2.fromOffset(0, self.Height + 24) end
    self.LayingOut = false
    if self.OnLayout then self:OnLayout() end
end
local function element(tab, opts, kind, height)
    opts = opts or {}
    local s = scope(tab.Scope)
    local card = frame(tab.Page, 8); card.Name = opts.Name or kind; card.BackgroundTransparency = 0
    style(s, card, "BackgroundColor3", 2)
    local api = setmetatable({Tab = tab, Window = tab.Window, Scope = s, Object = card, Options = opts,
        Kind = kind, Height = height, Visible = true, Enabled = opts.Enabled ~= false, Flag = opts.Flag,
        OwnedQuickButtons = {}, AccessoryWidth = 0}, Element)
    tab.Items[#tab.Items + 1], tab.Elements[#tab.Elements + 1] = api, api
    tab.Window.Controls[#tab.Window.Controls + 1] = api
    s:Connect(card.Destroying, function() api:Destroy() end)
    return api
end
local function register(api, fallback)
    local flag = api.Options.Flag or (api.Tab.Name .. "." .. (api.Options.Name or fallback))
    assert(not Library.Elements[flag], "Duplicate Flag: " .. tostring(flag))
    api.Flag = flag; Library.Elements[flag] = api
end
local function heading(api)
    api.Title = label(api.Object, api.Options.Name or api.Kind, 14)
    api.Title.Position, api.Title.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20)
    if api.Options.Description then
        api.Description = label(api.Object, api.Options.Description, 13)
        style(api.Scope, api.Description, "TextColor3", 3)
        api.Description.Position, api.Description.Size = UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 20)
    end
end
local function finish(api)
    local opts = api.Options
    if opts.Settings then
        local options = type(opts.Settings) == "table" and opts.Settings or {}
        local panel = api:CreateSettings(options)
        local build = type(opts.Settings) == "function" and opts.Settings or options.Build
        if build then
            local ok, err = pcall(build, panel, api)
            if not ok then api:Destroy(); error(err, 0) end
        end
    end
    api.Tab:Layout()
    return api
end
function Element:SetVisible(value)
    if self.Destroyed then return end
    self.Visible = value == true; self.Object.Visible = self.Visible
    if not self.Visible then
        if self.Settings then self.Settings:Close() end
        if self.Window.Popup and self.Window.Popup.Owner == self then self.Window:ClosePopup() end
        if self.Window.Drag and self.Window.Drag.Object:IsDescendantOf(self.Object) then self.Window:EndDrag(true) end
    end
    self.Tab:Layout()
end
function Element:SetEnabled(value) self.Enabled = value == true; if self.Render then self:Render() end end
function Element:SetName(value) if self.Title then self.Title.Text = tostring(value) end end
function Element:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Settings then self.Settings:Destroy() end
    if self.Group then self.Group:Destroy() end
    for _, quick in ipairs(table.clone(self.OwnedQuickButtons)) do quick:Destroy() end
    if self.QuickButton then self.QuickButton:Destroy() end
    if self.Window.Popup and self.Window.Popup.Owner == self then self.Window:ClosePopup() end
    if self.Window.Drag and self.Window.Drag.Object:IsDescendantOf(self.Object) then self.Window:EndDrag(true) end
    if self.Flag and Library.Elements[self.Flag] == self then Library.Elements[self.Flag], Library.Flags[self.Flag] = nil, nil end
    if self.AlphaFlag then Library.Elements[self.AlphaFlag], Library.Flags[self.AlphaFlag] = nil, nil end
    for _, accessory in ipairs(self.Accessories or {}) do if accessory.Destroy then accessory:Destroy() end end
    self.Scope:Destroy(); self.Object:Destroy()
    remove(self.Tab.Items, self); remove(self.Tab.Elements, self); remove(self.Window.Controls, self)
    self.Tab:Layout()
end
function Element:CreateQuickButton(opts)
    opts = table.clone(opts or {}); opts.Target = self
    opts.Mode = opts.Mode or (self.Kind == "Toggle" and "Toggle" or "Button")
    opts.Text = opts.Text or self.Options.Name or self.Kind
    local quick = self.Window:CreateQuickButton(opts)
    self.OwnedQuickButtons[#self.OwnedQuickButtons + 1] = quick
    return quick
end

function Tab:AddSection(opts)
    opts = type(opts) == "table" and opts or {Name = opts}
    local api = element(self, opts, "Section", 30); api.Object.BackgroundTransparency = 1
    api.Title = label(api.Object, opts.Name or "Section", 13, true)
    api.Title.Size = UDim2.fromScale(1, 1); style(api.Scope, api.Title, "TextColor3", 3)
    api.SetText = Element.SetName; return finish(api)
end
function Tab:AddDivider()
    local api = element(self, {}, "Divider", 1); style(api.Scope, api.Object, "BackgroundColor3", 4)
    return finish(api)
end
function Tab:AddLabel(opts)
    opts = type(opts) == "table" and opts or {Text = opts}
    local api = element(self, opts, "Label", 24); api.Object.BackgroundTransparency = 1
    api.Title = label(api.Object, opts.Text, math.max(13, finite(opts.Size, 14)))
    api.Title.Size = UDim2.fromScale(1, 1)
    if opts.Muted then style(api.Scope, api.Title, "TextColor3", 3) end
    function api:SetText(value) self.Title.Text = tostring(value or "") end
    function api:GetText() return self.Title.Text end
    function api:Color(color) self.Title.TextColor3 = color end
    return finish(api)
end
function Tab:AddParagraph(opts)
    opts = opts or {}; local api = element(self, opts, "Paragraph", 60)
    if opts.Name then heading(api) end
    api.Body = label(api.Object, opts.Text, 14); api.Body.TextWrapped = true
    api.Body.TextTruncate, api.Body.TextYAlignment = Enum.TextTruncate.None, Enum.TextYAlignment.Top
    style(api.Scope, api.Body, "TextColor3", 3)
    function api:Resize(w)
        local y = self.Options.Name and 36 or 12
        local bounds = TextService:GetTextSize(self.Body.Text, 14, FONT, Vector2.new(math.max(1, w - 24), 10000))
        local h = math.max(20, bounds.Y + 4)
        place(self.Body, 12, y, math.max(1, w - 24), h); self.Height = y + h + 12
    end
    function api:SetText(value) self.Body.Text = tostring(value or ""); self.Tab:Layout() end
    return finish(api)
end
function Tab:AddToggle(opts)
    opts = opts or {}; local api = element(self, opts, "Toggle", opts.Description and 66 or 48)
    register(api, "Toggle"); heading(api); api.Value = opts.Default == true
    local hit = frame(api.Object, nil, "TextButton"); hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 3
    api.Hit = hit
    api.Switch = frame(api.Object, 11); api.Switch.ZIndex = 4; api.Switch.BackgroundTransparency = 0
    api.Thumb = frame(api.Switch, 8); api.Thumb.BackgroundTransparency = 0; api.Thumb.BackgroundColor3 = WHITE
    api.AccessoryWidth = 54
    function api:Resize(w)
        self.Height = self.Options.Description and 66 or 48
        place(self.Switch, w - 48, 13, 36, 22)
        self.Title.Size = UDim2.new(1, -(self.AccessoryWidth + 22), 0, 20)
        if self.SettingsGear then place(self.SettingsGear, w - self.AccessoryWidth, 7, 32, 34) end
    end
    function api:Render()
        self.Switch.BackgroundColor3 = self.Value and Library.Accent or themes[Library.Theme][5]
        place(self.Thumb, self.Value and 17 or 3, 3, 16, 16)
        self.Title.TextColor3 = self.Enabled and WHITE or themes[Library.Theme][3]
    end
    function api:Get() return self.Value end
    function api:Set(value, silent)
        if self.Destroyed then return end
        value = value == true; if value == self.Value then return end
        self.Value = value; fire(self.Flag, value); self:Render()
        for _, quick in ipairs(self.Window.QuickButtons) do if quick.Target == self then quick:Render() end end
        if not silent then invoke(opts.Callback, value) end
    end
    function api:Toggle() self:Set(not self.Value) end
    api.Scope:Connect(hit.Activated, function() if api.Enabled then api:Toggle() end end)
    api:Render(); fire(api.Flag, api.Value)
    if opts.Keybind then api.Keybind = api:AttachKeybind(opts.Keybind) end
    if opts.ColorPicker then api.ColorPicker = api:AttachColorPicker(opts.ColorPicker) end
    finish(api)
    if opts.FireOnInit ~= false then invoke(opts.Callback, api.Value) end
    return api
end
local function numbers(opts)
    local low, high = finite(opts.Min, 0), finite(opts.Max, 100)
    if low > high then low, high = high, low end
    local decimals = math.clamp(math.floor(finite(opts.Decimals, 0)), 0, 6)
    local increment = math.abs(finite(opts.Step, 10 ^ -decimals)); if increment == 0 then increment = 1 end
    local function quantize(raw, fallback)
        local n = math.clamp(finite(raw, fallback or low), low, high)
        if n <= low or n >= high then return n end
        return math.clamp(low + math.floor((n - low) / increment + 0.5) * increment, low, high)
    end
    return low, high, increment, decimals, quantize
end
function Tab:AddSlider(opts)
    opts = opts or {}; local api = element(self, opts, "Slider", opts.Description and 102 or 80)
    register(api, "Slider"); heading(api)
    local low, high, increment, decimals, quantize = numbers(opts)
    api.Value = quantize(opts.Default)
    api.ValueLabel = label(api.Object, "", 14); api.ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    api.Track = frame(api.Object, 3); api.Track.BackgroundTransparency = 0; style(api.Scope, api.Track, "BackgroundColor3", 5)
    api.Fill = frame(api.Track, 3); api.Fill.BackgroundTransparency = 0
    api.Thumb = frame(api.Track, 8); api.Thumb.BackgroundColor3 = WHITE; api.Thumb.BackgroundTransparency = 0
    api.Hit = frame(api.Object, nil, "TextButton"); api.Hit.ZIndex = 5
    function api:Resize(w)
        local y = self.Options.Description and 72 or 50
        self.Title.Size = UDim2.new(1, -116, 0, 20)
        place(self.ValueLabel, w - 108, 10, 96, 20)
        place(self.Track, 16, y, math.max(1, w - 32), 6)
        place(self.Hit, 8, y - 14, math.max(1, w - 16), 34)
    end
    function api:Render()
        local ratio = high == low and 0 or (self.Value - low) / (high - low)
        self.Fill.Size = UDim2.new(ratio, 0, 1, 0); self.Fill.BackgroundColor3 = Library.Accent
        self.Thumb.Size = UDim2.fromOffset(16, 16); self.Thumb.Position = UDim2.new(ratio, -8, 0, -5)
        self.ValueLabel.Text = string.format("%." .. decimals .. "f", self.Value) .. tostring(opts.Suffix or "")
    end
    function api:Get() return self.Value end
    function api:Set(value, silent)
        if self.Destroyed then return end
        value = quantize(value, self.Value); if value == self.Value then return end
        self.Value = value; fire(self.Flag, value); self:Render(); if not silent then invoke(opts.Callback, value) end
    end
    api.Window:BindDrag(api.Hit, api.Scope, {Immediate = true, LockScroll = true, CanStart = function() return api.Enabled end,
        Move = function(p) api:Set(low + (high - low) * math.clamp((p.X - api.Track.AbsolutePosition.X) / math.max(1, api.Track.AbsoluteSize.X), 0, 1)) end,
        Finish = function(cancelled) invoke(opts.OnRelease, api.Value, cancelled) end})
    api.Scope:Connect(api.Hit.InputBegan, function(input)
        if not api.Enabled then return end
        if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then api:Set(api.Value - increment)
        elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then api:Set(api.Value + increment) end
    end)
    api:Render(); fire(api.Flag, api.Value); return finish(api)
end
function Tab:AddButton(opts)
    opts = opts or {}; local api = element(self, opts, "Button", opts.Compact and 40 or (opts.Description and 104 or 82))
    if not opts.Compact then heading(api) end
    api.Control = button(api.Object, opts.Text or opts.Name or "Button", api.Scope)
    function api:Resize(w)
        if opts.Compact then place(self.Control, 0, 0, w, 40)
        else place(self.Control, 12, opts.Description and 60 or 38, math.max(1, w - 24), 34) end
    end
    function api:SetText(value) self.Control.Text = tostring(value) end
    function api:Press()
        if self.Destroyed or not self.Enabled or self.Busy then return false end
        self.Busy = true
        self.Window.ButtonPressed:Fire(self.Tab.Name .. "." .. (opts.Name or "Button"))
        task.spawn(function()
            local ok, err = pcall(function() if opts.Callback then opts.Callback() end end)
            self.Busy = false
            if not ok then warn("WolfUi action: " .. tostring(err)) end
        end)
        return true
    end
    api.Scope:Connect(api.Control.Activated, function() api:Press() end)
    return finish(api)
end

function Window:ClosePopup()
    local popup = self.Popup; self.Popup = nil
    if popup then
        if self.Drag and self.Drag.Object:IsDescendantOf(popup.Object) then self:EndDrag(true) end
        popup.Scope:Destroy(); popup.Object:Destroy()
    end
end
function Window:OpenPopup(owner, anchor, width, height)
    self:ClosePopup()
    local s = scope(owner.Scope)
    local object = frame(self.Gui, 8); object.BackgroundTransparency = 0; object.ZIndex = 40; object.Active = true
    style(s, object, "BackgroundColor3", 2)
    local border = make("UIStroke", object, {Thickness = 1}); style(s, border, "Color", 6)
    local popup = {Owner = owner, Anchor = anchor, Object = object, Scope = s, Width = width, Height = height}
    self.Popup = popup; self:LayoutOverlays(); return popup
end
function Window:LayoutOverlays()
    if not self.Viewport then return end
    for _, panel in ipairs(self.SettingsPanels) do if not panel.Destroyed then panel:LayoutPanel() end end
    local popup = self.Popup
    if popup and popup.Anchor.Parent then
        local root = self.Gui.AbsolutePosition
        local anchor = popup.Anchor.AbsolutePosition - root
        local width, height = math.min(popup.Width, self.Viewport.X - 16), math.min(popup.Height, self.Viewport.Y - 16)
        local y = anchor.Y + popup.Anchor.AbsoluteSize.Y + 6
        if y + height > self.Viewport.Y - 8 then y = anchor.Y - height - 6 end
        local pos = clampPoint(Vector2.new(anchor.X, y), Vector2.new(width, height), self.Viewport)
        place(popup.Object, pos.X, pos.Y, math.max(1, width), math.max(1, height))
    end
end
function Tab:AddDropdown(opts)
    opts = opts or {}; local api = element(self, opts, "Dropdown", opts.Description and 108 or 86)
    register(api, "Dropdown"); heading(api)
    api.Control = button(api.Object, "", api.Scope); api.Control.TextXAlignment = Enum.TextXAlignment.Left
    make("UIPadding", api.Control, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 28)})
    local arrow = label(api.Control, "⌄", 18); arrow.Position = UDim2.new(1, -18, 0, 0); arrow.Size = UDim2.fromOffset(18, 36)
    api.OptionsList, api.Selection = {}, opts.Multiple and {} or nil
    function api:Resize(w) place(self.Control, 12, opts.Description and 62 or 40, math.max(1, w - 24), 36) end
    function api:Get()
        if not opts.Multiple then return self.OptionsList[self.Selection], self.Selection end
        local names = {}; for i, value in ipairs(self.OptionsList) do if self.Selection[i] then names[#names + 1] = value end end
        return names, clone(self.Selection)
    end
    function api:GetOptions() return clone(self.OptionsList) end
    function api:Render()
        local value = self:Get()
        self.Control.Text = type(value) == "table" and (#value > 0 and table.concat(value, ", ") or "Выберите…") or value or "Нет вариантов"
        if self.Window.Popup and self.Window.Popup.Owner == self then
            for index, row in ipairs(self.Rows or {}) do
                local active = opts.Multiple and self.Selection[index] or self.Selection == index
                row.TextColor3 = active and Library.Accent or WHITE
            end
        end
    end
    function api:Set(value, silent)
        if self.Destroyed then return end
        local function indexOf(v)
            if type(v) == "number" and self.OptionsList[math.floor(v)] then return math.floor(v) end
            for i, item in ipairs(self.OptionsList) do if item == v then return i end end
        end
        if opts.Multiple then
            local selected = {}
            for key, v in pairs(type(value) == "table" and value or {}) do
                local i = type(v) == "boolean" and v and indexOf(tonumber(key)) or indexOf(v)
                if i then selected[i] = true end
            end
            self.Selection = selected
        else self.Selection = indexOf(value) or (#self.OptionsList > 0 and 1 or nil) end
        fire(self.Flag, self.Selection); self:Render()
        Library.Flags[self.Flag .. ".Text"] = self.Control.Text
        if not silent then invoke(opts.Callback, self:Get()) end
    end
    function api:SetOptions(values)
        local previous = self:Get(); self.OptionsList = {}
        for _, v in ipairs(values or {}) do self.OptionsList[#self.OptionsList + 1] = tostring(v) end
        if self.Window.Popup and self.Window.Popup.Owner == self then self.Window:ClosePopup() end
        self:Set(previous, true)
    end
    function api:Open()
        if not self.Enabled or self.Destroyed then return end
        if self.Window.Popup and self.Window.Popup.Owner == self then self.Window:ClosePopup(); return end
        local popup = self.Window:OpenPopup(self, self.Control, math.max(160, self.Control.AbsoluteSize.X),
            math.min(math.max(1, #self.OptionsList), math.max(1, finite(opts.MaxRows, 6))) * 38 + 12)
        local list = scroll(popup.Object); list.Position = UDim2.fromOffset(6, 6); list.Size = UDim2.new(1, -12, 1, -12)
        list.CanvasSize = UDim2.fromOffset(0, #self.OptionsList * 38); self.Rows = {}
        if #self.OptionsList == 0 then local empty = label(list, "Нет вариантов", 14); empty.Size = UDim2.new(1, 0, 0, 38) end
        for i, v in ipairs(self.OptionsList) do
            local row = button(list, v, popup.Scope, 4); row.Position = UDim2.fromOffset(0, (i - 1) * 38); row.Size = UDim2.new(1, -5, 0, 34)
            self.Rows[i] = row
            popup.Scope:Connect(row.Activated, function()
                if opts.Multiple then local nextValue = clone(self.Selection); nextValue[i] = not nextValue[i] or nil; self:Set(nextValue)
                else self:Set(i); self.Window:ClosePopup() end
            end)
        end
        self:Render()
    end
    api.Scope:Connect(api.Control.Activated, function() api:Open() end)
    api:SetOptions(opts.Options or {}); api:Set(opts.Default or (opts.Multiple and {} or 1), true)
    return finish(api)
end
local function textBox(parent, s)
    local box = make("TextBox", parent, {BackgroundTransparency = 0, BorderSizePixel = 0, Font = FONT, TextSize = 14,
        TextColor3 = WHITE, Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = false, MultiLine = false})
    make("UICorner", box, {CornerRadius = UDim.new(0, 6)})
    make("UIPadding", box, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
    style(s, box, "BackgroundColor3", 4); style(s, box, "PlaceholderColor3", 3)
    return box
end
function Tab:AddTextBox(opts)
    opts = opts or {}; local api = element(self, opts, "TextBox", opts.ShowName and 86 or 54)
    register(api, "Input"); if opts.ShowName then heading(api) end
    api.Box = textBox(api.Object, api.Scope); api.Box.PlaceholderText = opts.Placeholder or opts.Name or "Введите текст"
    local maximum = math.max(1, finite(opts.MaxLength, 256))
    local function normalize(value)
        value = tostring(value or ""); local length = utf8.len(value)
        if length and length > maximum then return value:sub(1, utf8.offset(value, maximum + 1) - 1) end
        return value
    end
    function api:Resize(w) place(self.Box, 10, opts.ShowName and 40 or 9, math.max(1, w - 20), 36) end
    function api:Get() return self.Value end
    function api:Set(value, silent)
        if self.Destroyed then return end
        value = normalize(value); if value == self.Value then if self.Box.Text ~= value then self.Box.Text = value end; return end
        self.Value = value; self.Box.Text = value; fire(self.Flag, value)
        if not silent then invoke(opts.Callback, value) end
    end
    api.Scope:Connect(api.Box:GetPropertyChangedSignal("Text"), function() if api.Box.Text ~= api.Value then api:Set(api.Box.Text) end end)
    api.Scope:Connect(api.Box.FocusLost, function(enter) if enter then invoke(opts.OnEnter, api.Value) end end)
    api:Set(opts.Default or "", true); return finish(api)
end
function Tab:AddNumberInput(opts)
    opts = opts or {}; local api = element(self, opts, "NumberInput", 86); register(api, "Number"); heading(api)
    local _, _, stepValue, _, quantize = numbers(opts)
    api.Box = textBox(api.Object, api.Scope); api.Box.TextXAlignment = Enum.TextXAlignment.Center
    local minus, plus = button(api.Object, "−", api.Scope), button(api.Object, "+", api.Scope)
    function api:Resize(w)
        place(minus, 10, 40, 34, 36); place(plus, w - 44, 40, 34, 36)
        place(self.Box, 50, 40, math.max(1, w - 100), 36)
    end
    function api:Get() return self.Value end
    function api:Set(value, silent)
        if self.Destroyed then return end
        local n = quantize(value, self.Value)
        local changed = n ~= self.Value; self.Value = n; self.Box.Text = string.format("%.10g", n)
        if changed then fire(self.Flag, n); if not silent then invoke(opts.Callback, n) end end
    end
    api.Scope:Connect(minus.Activated, function() if api.Enabled then api:Set(api.Value - stepValue) end end)
    api.Scope:Connect(plus.Activated, function() if api.Enabled then api:Set(api.Value + stepValue) end end)
    api.Scope:Connect(api.Box.FocusLost, function() api:Set((api.Box.Text:gsub(",", "."))) end)
    api:Set(opts.Default, true); return finish(api)
end
function Tab:AddProgressBar(opts)
    opts = opts or {}; local api = element(self, opts, "ProgressBar", 66); register(api, "Progress"); heading(api)
    local low, high = numbers(opts)
    local track = frame(api.Object, 4); track.BackgroundTransparency = 0; style(api.Scope, track, "BackgroundColor3", 4)
    local fill = frame(track, 4); fill.BackgroundTransparency = 0
    api.ValueLabel = label(api.Object, "", 14); api.ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    function api:Resize(w)
        self.Title.Size = UDim2.new(1, -86, 0, 20); place(self.ValueLabel, w - 72, 10, 60, 20); place(track, 12, 44, w - 24, 8)
    end
    function api:Get() return self.Value end
    function api:Render()
        local ratio = low == high and 1 or (self.Value - low) / (high - low)
        fill.Size = UDim2.new(ratio, 0, 1, 0); fill.BackgroundColor3 = typeof(opts.Color) == "Color3" and opts.Color or Library.Accent
        self.ValueLabel.Text = tostring(round(ratio * 100)) .. "%"
    end
    function api:Set(value, silent)
        if self.Destroyed then return end
        value = math.clamp(finite(value, self.Value or low), low, high)
        if value == self.Value then return end
        self.Value = value; self:Render(); fire(self.Flag, value); if not silent then invoke(opts.Callback, value) end
    end
    api:Set(opts.Default, true); return finish(api)
end
local function choice(tab, opts, vertical)
    opts = opts or {}; local api = element(tab, opts, vertical and "RadioGroup" or "Segmented", 88)
    register(api, api.Kind); heading(api); api.Rows, api.OptionsList = {}, {}
    function api:Get() return self.OptionsList[self.Selection], self.Selection end
    function api:GetOptions() return clone(self.OptionsList) end
    function api:Render()
        for i, row in ipairs(self.Rows) do row.TextColor3 = i == self.Selection and Library.Accent or WHITE end
    end
    function api:Resize(w)
        local columns = vertical and 1 or math.max(1, math.min(#self.Rows, math.floor((w - 24) / 100)))
        local cell = math.floor((w - 24 - (columns - 1) * 6) / columns)
        for i, row in ipairs(self.Rows) do place(row, 12 + ((i - 1) % columns) * (cell + 6), 40 + math.floor((i - 1) / columns) * 42, cell, 36) end
        self.Height = 50 + math.ceil(math.max(1, #self.Rows) / columns) * 42
    end
    function api:Set(value, silent)
        if self.Destroyed then return end
        local index = nil
        if type(value) == "number" then index = math.floor(finite(value, 1)) else
            for i, v in ipairs(self.OptionsList) do if v == value then index = i; break end end
        end
        if not index or not self.OptionsList[index] then index = #self.OptionsList > 0 and 1 or nil end
        self.Selection = index; self:Render(); fire(self.Flag, index or 0)
        if not silent then invoke(opts.Callback, self:Get()) end
    end
    function api:SetOptions(values)
        local current = self:Get()
        if self.RowScope then self.RowScope:Destroy() end
        for _, row in ipairs(self.Rows) do row:Destroy() end
        self.RowScope = scope(self.Scope); self.Rows, self.OptionsList = {}, {}
        for i, v in ipairs(values or {}) do
            self.OptionsList[i] = tostring(v)
            local row = button(self.Object, tostring(v), self.RowScope)
            self.Rows[i] = row; self.RowScope:Connect(row.Activated, function() if self.Enabled then self:Set(i) end end)
        end
        self:Set(current, true); self.Tab:Layout()
    end
    api:SetOptions(opts.Options or {}); api:Set(opts.Default or 1, true); return finish(api)
end
function Tab:AddSegmented(opts) return choice(self, opts, false) end
function Tab:AddRadioGroup(opts) return choice(self, opts, true) end
function Tab:AddStatus(opts)
    opts = opts or {}; local api = element(self, opts, "Status", 48); heading(api)
    api.ValueLabel = label(api.Object, opts.Default or "Готово", 14); api.ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    function api:Resize(w)
        place(self.Title, 12, 0, w * 0.5 - 12, 48); place(self.ValueLabel, w * 0.5, 0, w * 0.5 - 12, 48)
    end
    function api:Get() return self.ValueLabel.Text end
    function api:Set(value) if not self.Destroyed then self.ValueLabel.Text = tostring(value or ""); fire(self.Flag, self:Get()) end end
    function api:SetColor(color) self.ValueLabel.TextColor3 = color end
    if opts.Flag then register(api, "Status") end
    api:Set(opts.Default or "Готово"); return finish(api)
end

local keyAliases = {LSHIFT = "LeftShift", RSHIFT = "RightShift", LCTRL = "LeftControl", RCTRL = "RightControl",
    LALT = "LeftAlt", RALT = "RightAlt", BACK = "Backspace", ENTER = "Return", ESC = "Escape", DEL = "Delete",
    MOUSE1 = "MouseButton1", MOUSE2 = "MouseButton2", MOUSE3 = "MouseButton3"}
local function keyValue(value)
    if typeof(value) == "EnumItem" then return value end
    if type(value) ~= "string" or value:upper() == "NONE" then return nil end
    local name = keyAliases[value:upper()] or value
    for _, enum in ipairs({Enum.KeyCode, Enum.UserInputType}) do
        for _, item in ipairs(enum:GetEnumItems()) do if item.Name:upper() == name:upper() then return item end end
    end
    return nil
end
local function keyText(key)
    if not key then return "—" end
    for short, full in pairs(keyAliases) do if full == key.Name then return short end end
    return key.Name
end
function Element:LayoutAccessories(w)
    local total = 0; for _, accessory in ipairs(self.Accessories) do total = total + accessory.Width end
    local stacked = self.Kind == "Toggle" and w - total - 80 < 100
    local y = stacked and (self.Options.Description and 60 or 36) or 7
    if stacked then
        self.Height = y + 44
        place(self.Switch, w - 48, y + 6, 36, 22)
    end
    local edge = w - (self.Kind == "Toggle" and 56 or 12)
    local reserved = self.Kind == "Toggle" and 56 or 12
    for _, accessory in ipairs(self.Accessories or {}) do
        edge = edge - accessory.Width
        place(accessory.Control, edge, y, accessory.Width - 4, 34)
        reserved = reserved + accessory.Width
    end
    if self.Title and #self.Accessories > 0 then
        if self.ValueLabel and self.Kind ~= "Status" then
            place(self.ValueLabel, math.max(12, edge - 102), 10, 90, 20); reserved = reserved + 102
        end
        self.Title.Size = UDim2.new(1, -(stacked and 24 or reserved + 12), 0, 20)
    end
end
local function bindControl(owner, opts, control)
    opts = opts or {}; local s = scope(owner.Scope)
    local flag = opts.Flag or (owner.Flag or owner.Tab.Name .. "." .. owner.Options.Name) .. ".Key"
    local bind = {Key = keyValue(opts.Default), Flag = flag, Control = control, Scope = s, Owner = owner, Width = 68}
    assert(not Library.Elements[flag], "Duplicate key flag: " .. flag)
    function bind:Get() return self.Key end
    function bind:Set(value, silent)
        self.Key = keyValue(value); control.Text = keyText(self.Key); fire(flag, self.Key and self.Key.Name or "NONE")
        if not silent then invoke(opts.OnChanged, self.Key) end
    end
    function bind:Fire()
        if owner.Destroyed or not owner.Enabled then return end
        if opts.Toggle then opts.Toggle() end
        invoke(opts.Callback, self.Key)
    end
    function bind:Destroy()
        if self.Destroyed then return end; self.Destroyed = true
        if owner.Window.PendingKeybind == self then owner.Window.PendingKeybind = nil end
        remove(owner.Window.Keybinds, self); if Library.Elements[flag] == self then Library.Elements[flag], Library.Flags[flag] = nil, nil end
        s:Destroy()
    end
    Library.Elements[flag] = bind; owner.Window.Keybinds[#owner.Window.Keybinds + 1] = bind
    s:Connect(control.Activated, function()
        local old = owner.Window.PendingKeybind; if old then old.Control.Text = keyText(old.Key) end
        owner.Window.PendingKeybind = bind; control.Text = "…"
    end)
    bind:Set(bind.Key, true); return bind
end
function Element:AttachKeybind(options)
    local opts = type(options) == "table" and table.clone(options) or {Default = options}
    opts.Toggle = function() self:Toggle() end
    local control = button(self.Object, "", self.Scope); control.ZIndex = 5; control.TextSize = 12
    local bind = bindControl(self, opts, control)
    self.Accessories = self.Accessories or {}; self.Accessories[#self.Accessories + 1] = bind
    return bind
end
function Tab:AddKeybind(opts)
    opts = opts or {}; local api = element(self, opts, "Keybind", opts.Description and 68 or 48); heading(api)
    local control = button(api.Object, "", api.Scope)
    local config = table.clone(opts); config.Flag = config.Flag or (self.Name .. "." .. (opts.Name or "Keybind"))
    local bind = bindControl(api, config, control); api.Accessories = {bind}
    function api:Get() return bind:Get() end
    function api:Set(value, silent) bind:Set(value, silent) end
    api.Bind = bind; return finish(api)
end

local function hex(color) return string.format("#%02X%02X%02X", round(color.R * 255), round(color.G * 255), round(color.B * 255)) end
local function parseHex(value)
    value = tostring(value):gsub("#", ""):gsub("%s", "")
    if #value == 3 then value = value:gsub("(.)", "%1%1") end
    if not value:match("^%x%x%x%x%x%x$") then return nil end
    return Color3.fromRGB(tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16))
end
local function colorControl(owner, opts, control)
    local flag = opts.Flag or (owner.Flag or owner.Tab.Name .. "." .. owner.Options.Name) .. ".Color"
    local picker = {Flag = flag, Width = 36, Control = control,
        Color = typeof(opts.Default) == "Color3" and opts.Default or Library.Accent,
        Alpha = math.clamp(finite(opts.Alpha, 1), 0, 1), Owner = owner}
    assert(not Library.Elements[flag], "Duplicate color flag: " .. flag)
    function picker:Get() return self.Color, self.Alpha end
    function picker:Set(color, alpha, silent)
        if self.Destroyed then return end
        if typeof(color) == "Color3" then self.Color = color end
        if alpha ~= nil then self.Alpha = math.clamp(finite(alpha, self.Alpha), 0, 1) end
        control.BackgroundColor3 = self.Color
        fire(flag, self.Color); if opts.UseAlpha ~= false then fire(flag .. ".Alpha", self.Alpha) end
        if not silent then invoke(opts.Callback, self.Color, self.Alpha) end
    end
    function picker:Destroy()
        if self.Destroyed then return end; self.Destroyed = true
        Library.Elements[flag], Library.Flags[flag] = nil, nil
        Library.Elements[flag .. ".Alpha"], Library.Flags[flag .. ".Alpha"] = nil, nil
    end
    function picker:Open()
        if owner.Destroyed or not owner.Enabled then return end
        local window = owner.Window
        local popup = window:OpenPopup(owner, control, 280, opts.UseAlpha == false and 230 or 272)
        local content = scroll(popup.Object); content.Size = UDim2.fromScale(1, 1)
        content.CanvasSize = UDim2.fromOffset(0, popup.Height); content.ScrollBarThickness = 3
        local hue, saturation, value = self.Color:ToHSV()
        local sv = frame(content, 4, "TextButton"); sv.BackgroundTransparency = 0; sv.BackgroundColor3 = Color3.new(1, 1, 1)
        sv.Position = UDim2.fromOffset(12, 12); sv.Size = UDim2.new(1, -24, 0, 126)
        local gradient = make("UIGradient", sv, {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))})
        local shade = frame(sv); shade.Size = UDim2.fromScale(1, 1); shade.BackgroundTransparency = 0; shade.BackgroundColor3 = Color3.new(0, 0, 0)
        make("UIGradient", shade, {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})})
        local cursor = frame(sv, 5); cursor.Size = UDim2.fromOffset(10, 10); cursor.ZIndex = 3
        make("UIStroke", cursor, {Color = WHITE, Thickness = 2})
        local hueBar = frame(content, 4, "TextButton"); hueBar.BackgroundTransparency = 0; hueBar.BackgroundColor3 = WHITE
        hueBar.Position, hueBar.Size = UDim2.fromOffset(12, 152), UDim2.new(1, -24, 0, 24)
        local stops = {}; for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
        make("UIGradient", hueBar, {Color = ColorSequence.new(stops)})
        local hueCursor = frame(hueBar, 2); hueCursor.BackgroundColor3 = WHITE; hueCursor.BackgroundTransparency = 0; hueCursor.Size = UDim2.fromOffset(3, 24)
        local alphaBar, alphaCursor
        if opts.UseAlpha ~= false then
            alphaBar = frame(content, 4, "TextButton"); alphaBar.BackgroundTransparency = 0
            alphaBar.Position, alphaBar.Size = UDim2.fromOffset(12, 188), UDim2.new(1, -24, 0, 24)
            make("UIGradient", alphaBar, {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})})
            alphaCursor = frame(alphaBar, 2); alphaCursor.BackgroundTransparency = 0; alphaCursor.BackgroundColor3 = WHITE; alphaCursor.Size = UDim2.fromOffset(3, 24)
        end
        local box = textBox(content, popup.Scope); box.Position, box.Size = UDim2.fromOffset(12, opts.UseAlpha == false and 188 or 226), UDim2.new(1, -24, 0, 34)
        local function render()
            gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
            cursor.Position = UDim2.new(saturation, -5, 1 - value, -5)
            hueCursor.Position = UDim2.new(hue, -1, 0, 0)
            if alphaBar then alphaBar.BackgroundColor3 = picker.Color; alphaCursor.Position = UDim2.new(picker.Alpha, -1, 0, 0) end
            box.Text = hex(picker.Color)
        end
        local function update() picker:Set(Color3.fromHSV(hue, saturation, value)); render() end
        window:BindDrag(sv, popup.Scope, {Immediate = true, LockScroll = true, Move = function(p)
            saturation = math.clamp((p.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
            value = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1); update()
        end})
        window:BindDrag(hueBar, popup.Scope, {Immediate = true, LockScroll = true, Move = function(p)
            hue = math.clamp((p.X - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 1); update()
        end})
        if alphaBar then window:BindDrag(alphaBar, popup.Scope, {Immediate = true, LockScroll = true, Move = function(p)
            picker:Set(nil, math.clamp((p.X - alphaBar.AbsolutePosition.X) / math.max(1, alphaBar.AbsoluteSize.X), 0, 1)); render()
        end}) end
        popup.Scope:Connect(box.FocusLost, function()
            local parsed = parseHex(box.Text); if parsed then hue, saturation, value = parsed:ToHSV(); update() else render() end
        end)
        render()
    end
    Library.Elements[flag] = picker
    if opts.UseAlpha ~= false then Library.Elements[flag .. ".Alpha"] = {Set = function(_, a) picker:Set(nil, a) end, Get = function() return picker.Alpha end} end
    owner.Scope:Connect(control.Activated, function() picker:Open() end)
    picker:Set(picker.Color, picker.Alpha, true)
    return picker
end
function Element:AttachColorPicker(options)
    local opts = type(options) == "table" and table.clone(options) or {}
    local control = frame(self.Object, 6, "TextButton"); control.BackgroundTransparency = 0; control.ZIndex = 5
    local picker = colorControl(self, opts, control)
    self.Accessories = self.Accessories or {}; self.Accessories[#self.Accessories + 1] = picker
    return picker
end
function Tab:AddColorPicker(opts)
    opts = opts or {}; local api = element(self, opts, "ColorPicker", opts.Description and 68 or 48); heading(api)
    local config = table.clone(opts); config.Flag = config.Flag or (self.Name .. "." .. (opts.Name or "Color"))
    local control = frame(api.Object, 6, "TextButton"); control.BackgroundTransparency = 0
    local picker = colorControl(api, config, control); api.Accessories = {picker}
    function api:Get() return picker:Get() end
    function api:Set(color, alpha, silent) picker:Set(color, alpha, silent) end
    api.Picker = picker; finish(api); if opts.FireOnInit ~= false then invoke(opts.Callback, picker:Get()) end; return api
end

function Window:CloseSettings()
    self.SettingsStack = {}; self:ClosePopup()
    for _, panel in ipairs(self.SettingsPanels) do panel.Object.Visible = false end
    if self.SettingsShield then self.SettingsShield.Visible = false end
end
function Element:CreateSettings(opts)
    opts = opts or {}; if self.Settings and not self.Settings.Destroyed then return self.Settings end
    local window, owner = self.Window, self
    local control = button(self.Object, "", self.Scope); control.ZIndex = 6
    local hub = frame(control, 6); place(hub, 10, 11, 12, 12)
    make("UIStroke", hub, {Thickness = 2, Color = themes[Library.Theme][3]})
    for i = 0, 7 do
        local angle = i * math.pi / 4
        local tooth = frame(control, 1); tooth.BackgroundTransparency = 0; tooth.BackgroundColor3 = themes[Library.Theme][3]
        place(tooth, 14 + math.cos(angle) * 8, 15 + math.sin(angle) * 8, 4, 4); tooth.Rotation = i * 45
    end
    local accessory = {Control = control, Width = 38}
    self.Accessories = self.Accessories or {}; self.Accessories[#self.Accessories + 1] = accessory
    self.SettingsGear = control
    local s = scope(self.Scope)
    local object = frame(window.Gui, 10); object.BackgroundTransparency = 0; object.ZIndex = 35; object.Active = true; object.Visible = false
    style(s, object, "BackgroundColor3", 1)
    local stroke = make("UIStroke", object, {Thickness = 1}); style(s, stroke, "Color", 6)
    local title = label(object, opts.Name or self.Options.Name or "Настройки", 15, true)
    title.Position, title.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -60, 0, 44)
    local close = button(object, "×", s); close.Position, close.Size = UDim2.new(1, -40, 0, 7), UDim2.fromOffset(32, 30)
    local list = scroll(object); list.Position, list.Size = UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44)
    local page = frame(list); page.Position = UDim2.fromOffset(12, 12)
    local panel = setmetatable({Name = (self.Flag or self.Tab.Name .. "." .. (self.Options.Name or self.Kind)) .. ".Settings",
        Window = window, Owner = self, Scope = s, Object = object, Page = page, Scroll = list, Anchor = control,
        Items = {}, Elements = {}, Height = 0, RequestedWidth = finite(opts.Width, 340), MaxHeight = finite(opts.Height, 380),
        RootTab = self.Tab.RootTab, ParentPanel = self.Tab.PanelContext, ContentWidth = 316}, Tab)
    panel.PanelContext = panel
    if not window.SettingsShield then
        local shield = frame(window.Gui, nil, "TextButton"); shield.Size = UDim2.fromScale(1, 1); shield.ZIndex = 34; shield.Visible = false
        window.SettingsShield = shield; window.Scope:Connect(shield.Activated, function() window:CloseSettings() end)
    end
    function panel:LayoutPanel()
        if self.Destroyed then return end
        local v = self.Window.Viewport
        local width = math.max(1, math.min(self.RequestedWidth, v.X - 20))
        if self.ContentWidth ~= width - 24 then self.ContentWidth = math.max(1, width - 24); self:Layout() end
        local height = math.max(1, math.min(self.Height + 68, self.MaxHeight, v.Y - 20))
        local anchor = self.Anchor.AbsolutePosition - self.Window.Gui.AbsolutePosition
        local desired = Vector2.new(anchor.X + self.Anchor.AbsoluteSize.X + 8, anchor.Y)
        if desired.X + width > v.X then desired = Vector2.new(anchor.X - width - 8, anchor.Y) end
        local p = clampPoint(desired, Vector2.new(width, height), v)
        place(self.Object, p.X, p.Y, width, height)
    end
    function panel:OnLayout() self:LayoutPanel() end
    function panel:Open()
        if self.Destroyed or owner.Destroyed then return end
        window:EndDrag(true); window:SetVisible(true)
        if window.Current ~= self.RootTab then window:SelectTab(self.RootTab) end
        window:ClosePopup()
        local stack, parent = {self}, self.ParentPanel
        while parent do table.insert(stack, 1, parent); parent = parent.ParentPanel end
        window.SettingsStack = stack
        for _, p in ipairs(window.SettingsPanels) do p.Object.Visible = p == self end
        window.SettingsShield.Visible = true; self:LayoutPanel()
    end
    function panel:Close()
        window:EndDrag(true); window:ClosePopup()
        local index
        for i, p in ipairs(window.SettingsStack) do if p == self then index = i end end
        if index then for i = #window.SettingsStack, index, -1 do table.remove(window.SettingsStack, i) end end
        local top = window.SettingsStack[#window.SettingsStack]
        for _, p in ipairs(window.SettingsPanels) do p.Object.Visible = p == top end
        window.SettingsShield.Visible = top ~= nil
    end
    function panel:Toggle() if self.Object.Visible then self:Close() else self:Open() end end
    function panel:SetTitle(value) title.Text = tostring(value) end
    function panel:Destroy()
        if self.Destroyed then return end; self.Destroyed = true; self:Close()
        for _, child in ipairs(table.clone(self.Items)) do child:Destroy() end
        s:Destroy(); object:Destroy(); control:Destroy()
        remove(window.SettingsPanels, self); remove(owner.Accessories, accessory)
        if owner.Settings == self then owner.Settings = nil; owner.SettingsGear = nil end
        if not owner.Destroyed then owner.Tab:Layout() end
    end
    s:Connect(close.Activated, function() panel:Close() end)
    s:Connect(control.Activated, function() panel:Toggle() end)
    s:Connect(object.Destroying, function() panel:Destroy() end)
    s:Connect(list:GetPropertyChangedSignal("CanvasPosition"), function() window:ClosePopup() end)
    window.SettingsPanels[#window.SettingsPanels + 1] = panel
    self.Settings = panel; self.Tab:Layout(); return panel
end
function Tab:AddGroup(opts)
    opts = opts or {}; local api = element(self, opts, "Group", 44)
    api.Expanded = opts.Expanded ~= false
    local hit = button(api.Object, opts.Name or "Group", api.Scope); hit.TextXAlignment = Enum.TextXAlignment.Left
    make("UIPadding", hit, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
    local page = frame(api.Object); page.Position = UDim2.fromOffset(10, 48)
    local container = setmetatable({Name = self.Name .. "." .. (opts.Name or "Group"), Window = self.Window,
        Scope = scope(api.Scope), Page = page, Items = {}, Elements = {}, Height = 0, ContentWidth = 300,
        RootTab = self.RootTab, PanelContext = self.PanelContext}, Tab)
    function container:Destroy() for _, child in ipairs(table.clone(self.Items)) do child:Destroy() end; self.Scope:Destroy() end
    function container:OnLayout()
        api.Height = api.Expanded and self.Height + 60 or 44
        api.Tab:Layout()
    end
    api.Group = container
    function api:Resize(w)
        place(hit, 0, 0, w, 40); container.ContentWidth = math.max(1, w - 20); container:Layout()
        page.Visible = self.Expanded; self.Height = self.Expanded and container.Height + 60 or 44
        hit.Text = (self.Expanded and "−  " or "+  ") .. (opts.Name or "Group")
    end
    function api:Get() return self.Expanded end
    function api:Set(value, silent)
        self.Expanded = value == true; fire(self.Flag, self.Expanded); self.Tab:Layout()
        if not silent then invoke(opts.Callback, self.Expanded) end
    end
    api.SetExpanded = api.Set
    for name, factory in pairs(Tab) do
        if name:sub(1, 3) == "Add" then api[name] = function(_, ...) return factory(container, ...) end end
    end
    api.Scope:Connect(hit.Activated, function() api:Set(not api.Expanded) end)
    if opts.Flag then register(api, "Group"); fire(api.Flag, api.Expanded) end
    return finish(api)
end

function Window:InitializeAccess(opts)
    self.AccessConfig = {Mode = "Watermark", Transparency = 0.16, ButtonSize = 44}
    self.WatermarkConfig = {Enabled = true, Text = self.Name, ShowFPS = true, ShowClock = false, Transparency = 0.16}
    self.AccessPosition = Vector2.new(12, 12)
    self.QuickConfig = {ButtonSize = 56, Gap = 8, Side = "Right", Layout = "Free"}; self.QuickPage = 1
    self.Watermark = frame(self.Gui, 8, "TextButton"); self.Watermark.ZIndex = 25; self.Watermark.BackgroundTransparency = 0.16
    style(self.Scope, self.Watermark, "BackgroundColor3", 2)
    self.WatermarkText = label(self.Watermark, self.Name, 14, true)
    self.WatermarkText.Position, self.WatermarkText.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0)
    self.Reopen = frame(self.Gui, 9, "TextButton"); self.Reopen.ZIndex = 25; self.Reopen.BackgroundTransparency = 0.16
    style(self.Scope, self.Reopen, "BackgroundColor3", 2)
    self.Reopen.Text, self.Reopen.TextSize, self.Reopen.Font, self.Reopen.TextColor3 = "W", 20, BOLD, WHITE
    self.WatermarkHit, self.ReopenHit = self.Watermark, self.Reopen
    for _, object in ipairs({self.Watermark, self.Reopen}) do
        self:BindDrag(object, self.Scope, {GetPosition = function() return self.AccessPosition end,
            Move = function(p, drag) self.AccessPosition = clampPoint(drag.Origin + p - drag.Start, object.AbsoluteSize, self.Viewport); self:LayoutAccess() end,
            Click = function() self:Toggle() end})
    end
    self.QuickLayer = frame(self.Gui); self.QuickLayer.Size = UDim2.fromScale(1, 1); self.QuickLayer.ZIndex = 24
    self.QuickPager = frame(self.Gui, 6); self.QuickPager.ZIndex = 26; self.QuickPager.BackgroundTransparency = 0
    style(self.Scope, self.QuickPager, "BackgroundColor3", 2)
    self.QuickPrevious, self.QuickNext = button(self.QuickPager, "‹", self.Scope), button(self.QuickPager, "›", self.Scope)
    self.QuickPagerText = label(self.QuickPager, "", 13); self.QuickPagerText.TextXAlignment = Enum.TextXAlignment.Center
    self.Scope:Connect(self.QuickPrevious.Activated, function() self:SetQuickPage(self.QuickPage - 1) end)
    self.Scope:Connect(self.QuickNext.Activated, function() self:SetQuickPage(self.QuickPage + 1) end)
    self:SetOpener(opts.Opener or "Watermark")
    if opts.Watermark then Library:SetWatermark(opts.Watermark) end
end
function Window:SetOpener(opts)
    opts = type(opts) == "table" and opts or {Mode = opts}
    if opts.Mode then assert(opts.Mode == "Watermark" or opts.Mode == "Button" or opts.Mode == "CenterTap", "Invalid opener mode"); self.AccessConfig.Mode = opts.Mode end
    if opts.Transparency ~= nil then self.AccessConfig.Transparency = math.clamp(finite(opts.Transparency, 0), 0, 0.95) end
    if opts.ButtonSize ~= nil then self.AccessConfig.ButtonSize = math.clamp(finite(opts.ButtonSize, 44), 36, 96) end
    if typeof(opts.Position) == "Vector2" then self.AccessPosition = opts.Position end
    self.CenterGesture = nil; self:LayoutAccess(); return clone(self.AccessConfig)
end
function Library:SetOpener(opts) if self.Window then return self.Window:SetOpener(opts) end end
function Library:SetWatermark(opts)
    if not self.Window then return end
    opts = type(opts) == "table" and opts or {Text = opts}
    local c = self.Window.WatermarkConfig
    for _, key in ipairs({"Enabled", "ShowFPS", "ShowClock"}) do if opts[key] ~= nil then c[key] = opts[key] == true end end
    if opts.Text ~= nil then c.Text = tostring(opts.Text) end
    if opts.Transparency ~= nil then c.Transparency = math.clamp(finite(opts.Transparency, 0), 0, 0.95) end
    self.Window:UpdateAccess(self.Window.FPS or 60); return clone(c)
end
function Window:UpdateAccess(fps)
    self.FPS = fps
    local c = self.WatermarkConfig
    local parts = {c.Text}
    if c.ShowFPS then parts[#parts + 1] = tostring(fps) .. " FPS" end
    if c.ShowClock then parts[#parts + 1] = os.date("%H:%M") end
    self.WatermarkText.Text = table.concat(parts, "  ·  ")
    self.Watermark.BackgroundTransparency = c.Transparency
    self.Reopen.BackgroundTransparency = self.AccessConfig.Transparency
    self:LayoutAccess()
    for _, quick in ipairs(self.QuickButtons) do quick:Render() end
end
function Window:LayoutAccess()
    if not self.Watermark then return end
    local v = self.Viewport
    local width = TextService:GetTextSize(self.WatermarkText.Text, 14, BOLD, Vector2.new(1000, 24)).X + 28
    self.Watermark.Size = UDim2.fromOffset(math.min(v.X, math.max(110, round(width))), 36)
    local size = self.AccessConfig.ButtonSize
    self.Reopen.Size = UDim2.fromOffset(math.min(size, v.X), math.min(size, v.Y))
    self.Watermark.Visible = self.AccessConfig.Mode == "Watermark" and self.WatermarkConfig.Enabled
    self.Reopen.Visible = self.AccessConfig.Mode == "Button" or (self.AccessConfig.Mode == "Watermark" and not self.WatermarkConfig.Enabled)
    local active = self.Watermark.Visible and self.Watermark or self.Reopen
    self.AccessPosition = clampPoint(self.AccessPosition, active.AbsoluteSize, v)
    self.Watermark.Position, self.Reopen.Position = UDim2.fromOffset(self.AccessPosition.X, self.AccessPosition.Y), UDim2.fromOffset(self.AccessPosition.X, self.AccessPosition.Y)
end
function Window:InputBegan(input, processed)
    if input.UserInputType == Enum.UserInputType.Touch then self.ActiveTouches[input] = true end
    if primary(input) and self.CenterGesture then self.CenterGesture = nil; return end
    if self.PendingKeybind then
        local bind = self.PendingKeybind
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then bind:Set(nil) else bind:Set(input.KeyCode) end
            self.PendingKeybind = nil; return
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
            bind:Set(input.UserInputType); self.PendingKeybind = nil; return
        end
    end
    if primary(input) and self.Popup and not inside(point(input), self.Popup.Object) and not inside(point(input), self.Popup.Anchor) then self:ClosePopup() end
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == self.ToggleKey then self:Toggle(); return end
    if input.KeyCode == Enum.KeyCode.Escape then
        if self.Popup then self:ClosePopup() elseif #self.SettingsStack > 0 then self.SettingsStack[#self.SettingsStack]:Close() end
        return
    end
    local hit = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
    for _, bind in ipairs(self.Keybinds) do if bind.Key == hit then bind:Fire() end end
    if primary(input) and self.AccessConfig.Mode == "CenterTap" and not self.Drag then
        local touches = 0
        for _ in pairs(self.ActiveTouches) do touches = touches + 1 end
        if touches > 1 then return end
        local p = point(input)
        local center = self.Gui.AbsolutePosition + self.Viewport / 2
        local delta = p - center
        local blocked = self.Frame.Visible and inside(p, self.Frame)
        for _, q in ipairs(self.QuickButtons) do if q.Object.Visible and inside(p, q.Object) then blocked = true end end
        if not blocked and delta.X * delta.X + delta.Y * delta.Y <= 42 * 42 then self.CenterGesture = {Input = input, Start = p, Time = os.clock()} end
    end
end
function Window:SetQuickButtonLayout(opts)
    opts = opts or {}
    if opts.ButtonSize then self.QuickConfig.ButtonSize = math.clamp(finite(opts.ButtonSize, 56), 44, 96) end
    if opts.Gap then self.QuickConfig.Gap = math.clamp(finite(opts.Gap, 8), 4, 24) end
    if opts.Side then assert(opts.Side == "Left" or opts.Side == "Right", "Invalid side"); self.QuickConfig.Side = opts.Side end
    if opts.Layout then assert(opts.Layout == "Free" or opts.Layout == "Grid", "Invalid layout"); self.QuickConfig.Layout = opts.Layout end
    self:LayoutQuickButtons()
end
function Window:SetQuickPage(value)
    self:EndDrag(true); self.QuickPage = math.clamp(math.floor(finite(value, 1)), 1, self.QuickPageCount or 1); self:LayoutQuickButtons()
end
function Window:ArrangeQuickButtons()
    self:EndDrag(true); for _, q in ipairs(self.QuickButtons) do q.Preferred = nil end; self:LayoutQuickButtons()
end
function Window:LayoutQuickButtons(priority)
    if not self.QuickLayer then return end
    local v, c = self.Viewport, self.QuickConfig
    local top, bottom, margin = math.min(60, v.Y * 0.2), math.min(48, v.Y * 0.2), math.min(10, v.X / 10)
    local size = math.max(1, math.min(c.ButtonSize, v.X - 2 * margin, v.Y - top - bottom - 8))
    local columns = math.max(1, math.floor((v.X - 2 * margin + c.Gap) / (size + c.Gap)))
    local rows = math.max(1, math.floor((v.Y - top - bottom + c.Gap) / (size + c.Gap)))
    local capacity, active = columns * rows, {}
    for _, q in ipairs(self.QuickButtons) do if q.Visible and not q.Destroyed then active[#active + 1] = q end; q.Object.Visible = false end
    self.QuickPageCount = math.max(1, math.ceil(#active / capacity)); self.QuickPage = math.clamp(self.QuickPage, 1, self.QuickPageCount)
    self.QuickPager.Visible = self.QuickPageCount > 1
    local pw, ph = math.min(148, v.X), math.min(34, bottom)
    place(self.QuickPager, (v.X - pw) / 2, v.Y - ph - 4, pw, ph)
    local aw = math.min(34, pw / 3)
    place(self.QuickPrevious, 0, 0, aw, ph); place(self.QuickNext, pw - aw, 0, aw, ph); place(self.QuickPagerText, aw, 0, pw - aw * 2, ph)
    self.QuickPagerText.Text = self.QuickPage .. " / " .. self.QuickPageCount
    local page = {}; for i = (self.QuickPage - 1) * capacity + 1, math.min(#active, self.QuickPage * capacity) do page[#page + 1] = active[i] end
    if priority then for _, q in ipairs(page) do if q == priority then remove(page, q); table.insert(page, 1, q); break end end end
    local function slot(i)
        local col, row = math.floor((i - 1) / rows), (i - 1) % rows
        local x = margin + col * (size + c.Gap)
        if c.Side == "Right" then x = v.X - margin - size - col * (size + c.Gap) end
        return Vector2.new(round(x), round(top + row * (size + c.Gap)))
    end
    local positions, crowded = {}, false
    local function available(p)
        if self.QuickPager.Visible then
            local pager = self.QuickPager.Position
            if p.X < pager.X.Offset + pw and pager.X.Offset < p.X + size and p.Y < pager.Y.Offset + ph and pager.Y.Offset < p.Y + size then return false end
        end
        for _, used in ipairs(positions) do
            if p.X < used.X + size + 2 and used.X < p.X + size + 2 and p.Y < used.Y + size + 2 and used.Y < p.Y + size + 2 then return false end
        end
        return true
    end
    for i, q in ipairs(page) do
        local wanted = q.Preferred and clampPoint(Vector2.new(q.Preferred.X * v.X, q.Preferred.Y * v.Y), Vector2.new(size, size), v) or nil
        local chosen, distance = nil, math.huge
        if wanted and c.Layout == "Free" and available(wanted) then chosen = wanted end
        if not chosen then
            for j = 1, capacity do
                local p = slot(j)
                if available(p) then
                    local d = wanted and ((p.X - wanted.X) ^ 2 + (p.Y - wanted.Y) ^ 2) or j
                    if d < distance then chosen, distance = p, d end
                    if not wanted then break end
                end
            end
        end
        if not chosen then crowded = true; break end
        positions[i] = chosen
    end
    if crowded then for i = 1, #page do positions[i] = slot(i) end end
    for i, q in ipairs(page) do
        q.Object.Visible = true
        local dragging = self.Drag and self.Drag.Object == q.Hit
        if not dragging then q.Position = positions[i]; place(q.Object, q.Position.X, q.Position.Y, size, size) end
    end
end
function Window:CreateQuickButton(opts)
    opts = opts or {}; assert(self.Alive, "Window is unloaded")
    local mode = opts.Mode or "Button"; assert(mode == "Button" or mode == "Toggle", "Invalid quick mode")
    local target = opts.Target or (opts.TargetFlag and Library.Elements[opts.TargetFlag])
    if opts.TargetFlag then assert(target, "Unknown TargetFlag") end
    if target then assert(mode == "Toggle" and target.Get and target.Set and type(target:Get()) == "boolean" or mode == "Button" and target.Press, "Incompatible target") end
    self.QuickSerial = (self.QuickSerial or 0) + 1
    local id = tostring(opts.Id or opts.Flag or "quick_" .. self.QuickSerial); assert(not self.QuickButtonIds[id], "Duplicate quick Id")
    if opts.Flag and not target then assert(not Library.Elements[opts.Flag], "Duplicate quick Flag") end
    local s = scope(self.Scope)
    local object = frame(self.QuickLayer, opts.Round and 28 or 9, "TextButton"); object.BackgroundTransparency = opts.Transparency or 0.12
    local caption = label(object, opts.Text or opts.Name or id, 13, true); caption.TextXAlignment = Enum.TextXAlignment.Center
    caption.Size, caption.Position = UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4)
    local dot = frame(object, 3); place(dot, 7, 7, 6, 6); dot.BackgroundTransparency = 0
    local q = {Window = self, Scope = s, Object = object, Hit = object, Caption = caption, Dot = dot, Id = id, Mode = mode,
        Target = target, Flag = opts.Flag, Value = opts.Default == true, Visible = opts.Visible ~= false, Enabled = opts.Enabled ~= false,
        Locked = opts.Locked == true, Transparency = math.clamp(finite(opts.Transparency, 0.12), 0, 0.95),
        Color = typeof(opts.Color) == "Color3" and opts.Color or nil, Position = Vector2.new(0, 0), LastPress = -math.huge}
    function q:Get() if self.Target then return self.Target:Get() end; return self.Value end
    function q:Render()
        if self.Destroyed then return end
        local on = self.Mode == "Toggle" and self:Get() == true
        self.Object.BackgroundColor3 = on and themes[Library.Theme][5] or themes[Library.Theme][2]
        self.Object.BackgroundTransparency = self.Transparency
        self.Caption.TextColor3 = on and (self.Color or Library.Accent) or WHITE
        self.Caption.TextTransparency = self.Enabled and 0 or 0.45
        self.Dot.Visible = self.Mode == "Toggle"; self.Dot.BackgroundColor3 = on and (self.Color or Library.Accent) or themes[Library.Theme][6]
    end
    function q:Set(value, silent)
        if self.Destroyed or self.Mode ~= "Toggle" then return false end
        value = value == true
        if self.Target then if self.Target.Destroyed then return false end; self.Target:Set(value, silent)
        elseif self.Value ~= value then self.Value = value; fire(self.Flag, value); if not silent then invoke(opts.Callback, value) end end
        self:Render(); return true
    end
    function q:Press()
        if self.Destroyed or not self.Enabled or self.Busy or self.Target and (self.Target.Destroyed or self.Target.Enabled == false) then return false end
        if os.clock() - self.LastPress < math.max(0, finite(opts.Cooldown, 0)) then return false end
        self.LastPress = os.clock()
        if self.Mode == "Toggle" then return self:Set(not self:Get()) end
        if self.Target then return self.Target:Press() end
        self.Busy = true
        task.spawn(function()
            local ok, err = pcall(function() if opts.Callback then opts.Callback() end end); self.Busy = false
            if not ok then warn("WolfUi quick action: " .. tostring(err)) end
        end)
        return true
    end
    function q:SetVisible(value)
        if self.Destroyed then return end; self.Visible = value == true
        if self.VisibilityControl and not self.VisibilityControl.Destroyed and self.VisibilityControl:Get() ~= self.Visible then self.VisibilityControl:Set(self.Visible) end
        if not self.Visible and self.Window.Drag and self.Window.Drag.Object == object then self.Window:EndDrag(true) end
        self.Window:LayoutQuickButtons()
    end
    function q:Show() self:SetVisible(true) end
    function q:Hide() self:SetVisible(false) end
    function q:SetEnabled(v) self.Enabled = v == true; self:Render() end
    function q:SetLocked(v) self.Locked = v == true end
    function q:SetText(v) caption.Text = tostring(v) end
    function q:SetColor(v) if typeof(v) == "Color3" then self.Color = v; self:Render() end end
    function q:SetTransparency(v) self.Transparency = math.clamp(finite(v, 0), 0, 0.95); self:Render() end
    function q:SetPosition(x, y)
        local v = self.Window.Viewport
        self.Preferred = Vector2.new(math.clamp(finite(x, 0) / math.max(1, v.X), 0, 1), math.clamp(finite(y, 0) / math.max(1, v.Y), 0, 1))
        self.Window:LayoutQuickButtons(self)
    end
    function q:Destroy()
        if self.Destroyed then return end; self.Destroyed = true
        if self.Window.Drag and self.Window.Drag.Object == object then self.Window:EndDrag(true) end
        s:Destroy(); object:Destroy(); remove(self.Window.QuickButtons, self); self.Window.QuickButtonIds[id] = nil
        if self.Flag and Library.Elements[self.Flag] == self then Library.Elements[self.Flag], Library.Flags[self.Flag] = nil, nil end
        if self.Window.Alive then self.Window:LayoutQuickButtons() end
    end
    self.QuickButtons[#self.QuickButtons + 1], self.QuickButtonIds[id] = q, q
    self:BindDrag(object, s, {GetPosition = function() return q.Position end,
        Move = function(p, drag) if not q.Locked then q.Position = clampPoint(drag.Origin + p - drag.Start, object.AbsoluteSize, self.Viewport); object.Position = UDim2.fromOffset(q.Position.X, q.Position.Y) end end,
        Finish = function(cancelled, drag)
            if q.Destroyed or not drag.Moved then return end
            if not cancelled and not q.Locked then q:SetPosition(q.Position.X, q.Position.Y); invoke(opts.OnDragEnd, q.Position) else self:LayoutQuickButtons() end
        end,
        Click = function() q:Press() end})
    s:Connect(object.Destroying, function() q:Destroy() end)
    if target and target.Object then s:Connect(target.Object.Destroying, function() q:Destroy() end) end
    if opts.Flag and not target and mode == "Toggle" then Library.Elements[opts.Flag] = q; fire(opts.Flag, q.Value) end
    if typeof(opts.Position) == "Vector2" then q:SetPosition(opts.Position.X, opts.Position.Y) end
    self:LayoutQuickButtons(); q:Render(); return q
end
function Library:CreateQuickButton(opts) assert(self.Window, "CreateWindow first"); return self.Window:CreateQuickButton(opts) end
function Tab:AddQuickButton(opts)
    opts = opts or {}; local config = table.clone(opts.Button or {})
    config.Visible = opts.Default == true
    local quick = self.Window:CreateQuickButton(config)
    local row = self:AddToggle({Name = opts.Name or "Мини-кнопка", Description = opts.Description, Flag = opts.Flag,
        Default = opts.Default, Width = opts.Width, Callback = function(value) quick:SetVisible(value); invoke(opts.Callback, value) end})
    row.QuickButton, quick.VisibilityControl = quick, row
    return row
end

function Library:Notify(opts)
    local window = self.Window; if not window then return end
    opts = type(opts) == "table" and opts or {Text = opts}
    local s = scope(window.Scope)
    local object = frame(window.Gui, 8); object.ZIndex = 50; object.BackgroundTransparency = 0; style(s, object, "BackgroundColor3", 2)
    local title = label(object, opts.Title or "Wolf", 14, true); title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20)
    local body = label(object, opts.Text or "", 13); body.TextWrapped = true; body.TextTruncate = Enum.TextTruncate.None
    body.Position, body.Size = UDim2.fromOffset(12, 32), UDim2.new(1, -24, 1, -40)
    local n = {Object = object, Scope = s, Remaining = math.max(0, finite(opts.Duration, 4))}
    function n:Destroy()
        if self.Destroyed then return end; self.Destroyed = true; s:Destroy(); object:Destroy(); remove(window.Notifications, self)
    end
    window.Notifications[#window.Notifications + 1] = n
    local width = math.min(290, math.max(1, window.Viewport.X - 24))
    local height = math.max(66, TextService:GetTextSize(body.Text, 13, FONT, Vector2.new(math.max(1, width - 24), 10000)).Y + 44)
    place(object, window.Viewport.X - width - 12, math.max(0, window.Viewport.Y - height - 12), width, height)
    for i = #window.Notifications - 1, 1, -1 do window.Notifications[i]:Destroy() end
    return n
end

local function encode(value, seen)
    if typeof(value) == "Color3" then return {__type = "Color3", R = value.R, G = value.G, B = value.B} end
    if typeof(value) == "EnumItem" then return {__type = "Key", Name = value.Name} end
    if type(value) ~= "table" then return value end
    seen = seen or {}; assert(not seen[value], "Cyclic config value"); seen[value] = true
    local allSet, count = true, 0
    for k, v in pairs(value) do count = count + 1; if type(k) ~= "number" or type(v) ~= "boolean" then allSet = false end end
    local out = {}
    if allSet and count > 0 then
        out = {__type = "Set", Values = {}}
        for k, v in pairs(value) do if v then out.Values[#out.Values + 1] = k end end
        table.sort(out.Values)
    else for k, v in pairs(value) do out[k] = encode(v, seen) end end
    seen[value] = nil; return out
end
local function decode(value)
    if type(value) ~= "table" then return value end
    if value.__type == "Color3" then return Color3.new(finite(value.R, 0), finite(value.G, 0), finite(value.B, 0)) end
    if value.__type == "Key" then return keyValue(value.Name) end
    if value.__type == "Set" then local set = {}; for _, i in ipairs(value.Values or {}) do set[i] = true end; return set end
    local out = {}; for k, v in pairs(value) do out[k] = decode(v) end; return out
end
function Window:GetInterfaceConfig()
    local buttons = {}
    for _, q in ipairs(self.QuickButtons) do
        buttons[q.Id] = {Visible = q.Visible, Enabled = q.Enabled, Locked = q.Locked, Transparency = q.Transparency,
            Position = q.Preferred and {X = q.Preferred.X, Y = q.Preferred.Y} or nil}
    end
    return {BoundToScreen = self.BoundToScreen, Opener = clone(self.AccessConfig), Watermark = clone(self.WatermarkConfig),
        QuickLayout = clone(self.QuickConfig), QuickButtons = buttons, QuickPage = self.QuickPage,
        AccessPosition = {X = self.AccessPosition.X / math.max(1, self.Viewport.X), Y = self.AccessPosition.Y / math.max(1, self.Viewport.Y)}}
end
function Window:LoadInterfaceConfig(config)
    assert(type(config) == "table", "Interface must be a table")
    if config.Opener then self:SetOpener(config.Opener) end
    if config.Watermark then Library:SetWatermark(config.Watermark) end
    if config.BoundToScreen ~= nil then self:SetBoundsEnabled(config.BoundToScreen) end
    if config.QuickLayout then self:SetQuickButtonLayout(config.QuickLayout) end
    if type(config.AccessPosition) == "table" then
        self.AccessPosition = Vector2.new(finite(config.AccessPosition.X, 0) * self.Viewport.X, finite(config.AccessPosition.Y, 0) * self.Viewport.Y)
    end
    for id, data in pairs(config.QuickButtons or {}) do
        local q = self.QuickButtonIds[id]
        if q and type(data) == "table" then
            if data.Visible ~= nil then q:SetVisible(data.Visible) end
            if data.Enabled ~= nil then q:SetEnabled(data.Enabled) end
            if data.Locked ~= nil then q:SetLocked(data.Locked) end
            if data.Transparency ~= nil then q:SetTransparency(data.Transparency) end
            if type(data.Position) == "table" then q.Preferred = Vector2.new(finite(data.Position.X, 0), finite(data.Position.Y, 0)) else q.Preferred = nil end
        end
    end
    self:LayoutAccess(); self:LayoutQuickButtons(); if config.QuickPage then self:SetQuickPage(config.QuickPage) end
end
function Library:GetConfig()
    return {__version = self.Version, Theme = self.Theme, Scale = self.Scale, Accent = encode(self.Accent), AccentAlpha = self.AccentAlpha,
        Flags = encode(self.Flags), Interface = self.Window and self.Window:GetInterfaceConfig() or nil}
end
function Library:LoadConfig(config)
    if type(config) ~= "table" or config.Flags ~= nil and type(config.Flags) ~= "table" then return false, "Invalid config" end
    local errors = {}
    local function apply(name, action)
        local ok, err = pcall(action); if not ok then errors[#errors + 1] = name .. ": " .. tostring(err) end
    end
    if config.Theme then apply("Theme", function() self:SetTheme(config.Theme) end) end
    if config.Accent then apply("Accent", function() self:SetAccent(decode(config.Accent), config.AccentAlpha) end) end
    if config.Scale and self.Window then apply("Scale", function() self.Window:SetScale(config.Scale) end) end
    local flags = {}; for flag in pairs(config.Flags or {}) do flags[#flags + 1] = flag end; table.sort(flags)
    for _, flag in ipairs(flags) do apply(flag, function() self:SetFlag(flag, decode(config.Flags[flag])) end) end
    if self.Window and config.Interface then apply("Interface", function() self.Window:LoadInterfaceConfig(config.Interface) end) end
    if #errors > 0 then return false, table.concat(errors, "\n") end
    return true
end
local function safeName(value)
    local name = tostring(value or "default"):gsub("[^%w%-%. ]", "_"):gsub("^ +", ""):gsub(" +$", "")
    if name == "" or name == "." or name == ".." then name = "default" end
    return name:sub(1, 40)
end
local function ensureFolder(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    local current
    for part in path:gmatch("[^/]+") do current = current and current .. "/" .. part or part; if not isfolder(current) then makefolder(current) end end
end
function Library:SetScriptName(name)
    self.ScriptName = safeName(name or "Wolf")
    self.Folder, self.ConfigFolder = "WolfUi/" .. self.ScriptName, "WolfUi/" .. self.ScriptName .. "/configs"
    return self.Folder
end
function Library:GetFolder() return self.Folder or "WolfUi/Wolf" end
function Library:GetConfigFolder() return self:GetFolder() .. "/configs" end
local function resolvePath(path)
    local clean = tostring(path or ""):gsub("\\", "/"):gsub("^/+", "")
    local parts = {}
    for part in clean:gmatch("[^/]+") do
        if part == ".." or part:find("[%z%c:]") then return nil, "Invalid relative path" end
        if part ~= "." then parts[#parts + 1] = part end
    end
    return Library:GetFolder() .. "/" .. table.concat(parts, "/")
end
function Library:WriteFile(path, content)
    if type(writefile) ~= "function" then return false, "File API is unavailable" end
    local full, err = resolvePath(path); if not full then return false, err end
    return pcall(function() ensureFolder(full:match("^(.*)/[^/]+$")); writefile(full, tostring(content)) end)
end
function Library:ReadFile(path)
    if type(readfile) ~= "function" then return nil, "File API is unavailable" end
    local full, err = resolvePath(path); if not full then return nil, err end
    local ok, data = pcall(readfile, full); if ok then return data end; return nil, data
end
function Library:DeleteFile(path)
    if type(delfile) ~= "function" then return false, "File API is unavailable" end
    local full, err = resolvePath(path); if not full then return false, err end
    return pcall(delfile, full)
end
function Library:ListFiles(subfolder)
    local out = {}; if type(listfiles) ~= "function" then return out end
    local full, err = resolvePath(subfolder or ""); if not full then return out, err end
    local ok, data = pcall(listfiles, full)
    if ok then for _, path in ipairs(data) do out[#out + 1] = path:match("([^/\\]+)$") or path end end
    table.sort(out); return out
end
function Library:SaveConfigFile(name)
    local ok, json = pcall(function() return HttpService:JSONEncode(self:GetConfig()) end)
    if not ok then return false, json end
    return self:WriteFile("configs/" .. safeName(name) .. ".json", json)
end
function Library:LoadConfigFile(name)
    if not name then return false, "Select a config" end
    local source, err = self:ReadFile("configs/" .. safeName(name) .. ".json"); if not source then return false, err end
    local ok, config = pcall(function() return HttpService:JSONDecode(source) end)
    if not ok then return false, config end
    return self:LoadConfig(config)
end
function Library:ListConfigs()
    local out = {}; for _, name in ipairs(self:ListFiles("configs")) do local value = name:match("^(.*)%.json$"); if value then out[#out + 1] = value end end; return out
end
function Library:DeleteConfigFile(name)
    if not name then return false, "Select a config" end
    return self:DeleteFile("configs/" .. safeName(name) .. ".json")
end
function Library:Unload()
    local w = self.Window; if not w or not w.Alive then return end
    w.Alive = false; self.Runtime.Alive = false; w:EndDrag(true); w:ClosePopup()
    for _, q in ipairs(table.clone(w.QuickButtons)) do q:Destroy() end
    for _, item in ipairs(table.clone(w.Controls)) do item:Destroy() end
    w.Scope:Destroy(); w.Gui:Destroy(); w.Events:Destroy()
    self.Window, self.Flags, self.Elements = nil, {}, {}
    for _, listener in ipairs(self._Unloads) do if listener.Connected then invoke(listener.Callback) end end
    self._Changes, self._Unloads = {}, {}
end
function Library:Demo()
    local w = self:CreateWindow({Name = "Wolf"})
    local tab = w:CreateTab({Name = "Основное"})
    local control = tab:AddToggle({Name = "Функция", Flag = "demo_enabled", Settings = function(panel)
        panel:AddSlider({Name = "Параметр", Flag = "demo_value", Min = 0, Max = 100, Default = 50})
    end})
    tab:AddQuickButton({Name = "Мини-кнопка", Flag = "demo_quick", Button = {Id = "demo_shortcut", Text = "WOLF", Mode = "Toggle", Target = control}})
    tab:AddButton({Name = "Уведомление", Text = "Показать", Callback = function() self:Notify({Title = "Wolf", Text = "Интерфейс готов"}) end})
    return w
end

return Library
