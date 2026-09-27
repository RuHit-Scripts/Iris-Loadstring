-- Iris v2.5.1 (SirMallard/Iris) — single-file loadstring build. Generated; do not hand-edit.
local __modules = {}
local __cache = {}
__require = function(name, ...)
	if __cache[name] ~= nil then return __cache[name] end
	local fn = __modules[name]
	assert(fn, "Iris module missing: " .. tostring(name))
	local ok, val = pcall(fn, ...)
	if not ok then error("[Iris bundle] " .. name .. ": " .. tostring(val), 0) end
	if type(val) == "function" then
		local ok2, val2 = pcall(val, ...)
		if not ok2 then error("[Iris bundle factory] " .. name .. ": " .. tostring(val2), 0) end
		val = val2
	end
	__cache[name] = val
	return val
end
-- ===== module: init =====
__modules["init"] = function()

local Iris = {}

local Internal = __require("Internal", Iris)

Iris.Disabled = false

Iris.Args = {}

Iris.Events = {}

function Iris.Init(parentInstance, eventConnection)
    assert(Internal._shutdown == false, "Iris.Init() cannot be called once shutdown.")
    assert(Internal._started == false or allowMultipleInits == true, "Iris.Init() can only be called once.")

    if Internal._started then
        return Iris
    end

    if parentInstance == nil then
        -- coalesce to playerGui
        parentInstance = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
    if eventConnection == nil then
        -- coalesce to Heartbeat
        eventConnection = game:GetService("RunService").Heartbeat
    end
    Internal.parentInstance = parentInstance
    Internal._started = true

    Internal._generateRootInstance()
    Internal._generateSelectionImageObject()

    for _, callback in pairs(Internal._initFunctions) do
        callback()
    end

    -- spawns the connection to call "Internal._cycle()" within.
    task.spawn(function()
        if typeof(eventConnection) == "function" then
            while Internal._started do
                local deltaTime = eventConnection()
                Internal._cycle(deltaTime)
            end
        elseif eventConnection ~= nil and eventConnection ~= false then
            Internal._eventConnection = eventConnection:Connect(function(...)
                Internal._cycle(...)
            end)
        end
    end)

    return Iris
end

function Iris.Shutdown()
    Internal._started = false
    Internal._shutdown = true

    if Internal._eventConnection then
        Internal._eventConnection:Disconnect()
    end
    Internal._eventConnection = nil

    if Internal._rootWidget then
        if Internal._rootWidget.Instance then
            Internal._widgets["Root"].Discard(Internal._rootWidget)
        end
        Internal._rootInstance = nil
    end

    if Internal.SelectionImageObject then
        Internal.SelectionImageObject:Destroy()
    end

    for _, connection in pairs(Internal._connections) do
        connection:Disconnect()
    end
end

function Iris:Connect(callback)
    if Internal._started == false then
        warn("Iris:Connect() was called before calling Iris.Init(); always initialise Iris first.")
    end
    local connectionIndex = #Internal._connectedFunctions + 1
    Internal._connectedFunctions[connectionIndex] = callback
    return function()
        Internal._connectedFunctions[connectionIndex] = nil
    end
end

function Iris.Append(userInstance)
    local parentWidget = Internal._GetParentWidget()

    if Internal._config.Parent then
        widgetInstanceParent = Internal._config.Parent
    else
        widgetInstanceParent = Internal._widgets[parentWidget.type].ChildAdded(parentWidget, { type = "userInstance" })
    end
    userInstance.Parent = widgetInstanceParent
end

function Iris.End()
    if Internal._stackIndex == 1 then
        error("Too many calls to Iris.End().", 2)
    end

    Internal._IDStack[Internal._stackIndex] = nil
    Internal._stackIndex = Internal._stackIndex - 1
end

function Iris.ForceRefresh()
    Internal._globalRefreshRequested = true
end

function Iris.UpdateGlobalConfig(deltaStyle)
    for index, style in pairs(deltaStyle) do
        Internal._rootConfig[index] = style
    end
    Iris.ForceRefresh()
end

function Iris.PushConfig(deltaStyle)
    local ID = Iris.State(-1)
    if ID.value == -1 then
        ID:set(deltaStyle)
    else
        -- compare tables
        if Internal._deepCompare(ID:get(), deltaStyle) == false then
            -- refresh local
            ID:set(deltaStyle)
            Internal._refreshStack[Internal._refreshLevel] = true
            Internal._refreshCounter = Internal._refreshCounter + 1
        end
    end
    Internal._refreshLevel = Internal._refreshLevel + 1
    Internal._config = setmetatable(deltaStyle, {
        __index = Internal._config,
    })
end

function Iris.PopConfig()
    Internal._refreshLevel = Internal._refreshLevel - 1
    if Internal._refreshStack[Internal._refreshLevel] == true then
        Internal._refreshCounter = Internal._refreshCounter - 1
        Internal._refreshStack[Internal._refreshLevel] = nil
    end

    Internal._config = getmetatable(Internal._config).__index
end

Iris.TemplateConfig = __require("config")
Iris.UpdateGlobalConfig(Iris.TemplateConfig.colorDark) -- use colorDark and sizeDefault themes by default
Iris.UpdateGlobalConfig(Iris.TemplateConfig.sizeDefault)
Iris.UpdateGlobalConfig(Iris.TemplateConfig.utilityDefault)
Internal._globalRefreshRequested = false -- UpdatingGlobalConfig changes this to true, leads to Root being generated twice.

function Iris.PushId(ID)
    assert(typeof(ID) == "string", "The ID argument to Iris.PushId() to be a string.")

    Internal._newID = true
    table.insert(Internal._pushedIds, ID)
end

function Iris.PopId()
    if #Internal._pushedIds == 0 then
        return
    end

    table.remove(Internal._pushedIds)
end

function Iris.SetNextWidgetID(ID)
    Internal._nextWidgetId = ID
end

function Iris.State(initialValue)
    local ID = Internal._getID(2)
    if Internal._states[ID] then
        return Internal._states[ID]
    end
    local newState = {
        ID = ID,
        value = initialValue,
        lastChangeTick = Iris.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    }
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState
    return newState
end

function Iris.WeakState(initialValue)
    local ID = Internal._getID(2)
    if Internal._states[ID] then
        if next(Internal._states[ID].ConnectedWidgets) == nil then
            Internal._states[ID] = nil
        else
            return Internal._states[ID]
        end
    end
    local newState = {
        ID = ID,
        value = initialValue,
        lastChangeTick = Iris.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    }
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState
    return newState
end

function Iris.VariableState(variable, callback)
    local ID = Internal._getID(2)
    local state = Internal._states[ID]

    if state then
        if variable ~= state.value then
            state:set(variable)
        end
        return state
    end

    local newState = {
        ID = ID,
        value = variable,
        lastChangeTick = Iris.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    }
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState

    newState:onChange(callback)

    return newState
end

function Iris.TableState(tab, key, callback)
    local value = tab[key]
    local ID = Internal._getID(2)
    local state = Internal._states[ID]

    -- If the table values changes, then we update the state to match.
    if state then
        if value ~= state.value then
            state:set(value)
        end
        return state
    end

    local newState = {
        ID = ID,
        value = value,
        lastChangeTick = Iris.Internal._cycleTick,
        ConnectedWidgets = {},
        ConnectedFunctions = {},
    }
    setmetatable(newState, Internal.StateClass)
    Internal._states[ID] = newState

    -- When a change happens to the state, we update the table value.
    newState:onChange(function()
        if callback ~= nil then
            if callback(newState.value) then
                tab[key] = newState.value
            end
        else
            tab[key] = newState.value
        end
    end)
    return newState
end

function Iris.ComputedState(firstState, onChangeCallback)
    local ID = Internal._getID(2)

    if Internal._states[ID] then
        return Internal._states[ID]
    else
        local newState = {
            ID = ID,
            value = onChangeCallback(firstState.value),
            lastChangeTick = Iris.Internal._cycleTick,
            ConnectedWidgets = {},
            ConnectedFunctions = {},
        }
        setmetatable(newState, Internal.StateClass)
        Internal._states[ID] = newState

        firstState:onChange(function(newValue)
            newState:set(onChangeCallback(newValue))
        end)
        return newState
    end
end

__require("widgets.init", Internal)
__require("API", Iris)

return Iris

end
-- ===== module: config =====
__modules["config"] = function()
local TemplateConfig = {
    colorDark = { -- Dear, ImGui default dark
        TextColor = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0,
        TextDisabledColor = Color3.fromRGB(128, 128, 128),
        TextDisabledTransparency = 0,

        -- Dear ImGui uses 110, 110, 125
        -- The Roblox window selection highlight is 67, 191, 254
        BorderColor = Color3.fromRGB(110, 110, 125),
        BorderTransparency = 0.5,
        BorderActiveColor = Color3.fromRGB(160, 160, 175), -- does not exist in Dear ImGui
        BorderActiveTransparency = 0.3,

        WindowBgColor = Color3.fromRGB(15, 15, 15),
        WindowBgTransparency = 0.06,
        PopupBgColor = Color3.fromRGB(20, 20, 20),
        PopupBgTransparency = 0.06,

        ScrollbarGrabColor = Color3.fromRGB(79, 79, 79),
        ScrollbarGrabTransparency = 0,

        TitleBgColor = Color3.fromRGB(10, 10, 10),
        TitleBgTransparency = 0,
        TitleBgActiveColor = Color3.fromRGB(41, 74, 122),
        TitleBgActiveTransparency = 0,
        TitleBgCollapsedColor = Color3.fromRGB(0, 0, 0),
        TitleBgCollapsedTransparency = 0.5,

        MenubarBgColor = Color3.fromRGB(36, 36, 36),
        MenubarBgTransparency = 0,

        FrameBgColor = Color3.fromRGB(41, 74, 122),
        FrameBgTransparency = 0.46,
        FrameBgHoveredColor = Color3.fromRGB(66, 150, 250),
        FrameBgHoveredTransparency = 0.46,
        FrameBgActiveColor = Color3.fromRGB(66, 150, 250),
        FrameBgActiveTransparency = 0.33,

        ButtonColor = Color3.fromRGB(66, 150, 250),
        ButtonTransparency = 0.6,
        ButtonHoveredColor = Color3.fromRGB(66, 150, 250),
        ButtonHoveredTransparency = 0,
        ButtonActiveColor = Color3.fromRGB(15, 135, 250),
        ButtonActiveTransparency = 0,

        ImageColor = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0,

        SliderGrabColor = Color3.fromRGB(66, 150, 250),
        SliderGrabTransparency = 0,
        SliderGrabActiveColor = Color3.fromRGB(66, 150, 250),
        SliderGrabActiveTransparency = 0,

        HeaderColor = Color3.fromRGB(66, 150, 250),
        HeaderTransparency = 0.69,
        HeaderHoveredColor = Color3.fromRGB(66, 150, 250),
        HeaderHoveredTransparency = 0.2,
        HeaderActiveColor = Color3.fromRGB(66, 150, 250),
        HeaderActiveTransparency = 0,

        TabColor = Color3.fromRGB(46, 89, 148),
        TabTransparency = 0.14,
        TabHoveredColor = Color3.fromRGB(66, 150, 250),
        TabHoveredTransparency = 0.2,
        TabActiveColor = Color3.fromRGB(51, 105, 173),
        TabActiveTransparency = 0,

        SelectionImageObjectColor = Color3.fromRGB(255, 255, 255),
        SelectionImageObjectTransparency = 0.8,
        SelectionImageObjectBorderColor = Color3.fromRGB(255, 255, 255),
        SelectionImageObjectBorderTransparency = 0,

        TableBorderStrongColor = Color3.fromRGB(79, 79, 89),
        TableBorderStrongTransparency = 0,
        TableBorderLightColor = Color3.fromRGB(59, 59, 64),
        TableBorderLightTransparency = 0,
        TableRowBgColor = Color3.fromRGB(0, 0, 0),
        TableRowBgTransparency = 1,
        TableRowBgAltColor = Color3.fromRGB(255, 255, 255),
        TableRowBgAltTransparency = 0.94,
        TableHeaderColor = Color3.fromRGB(48, 48, 51),
        TableHeaderTransparency = 0,

        NavWindowingHighlightColor = Color3.fromRGB(255, 255, 255),
        NavWindowingHighlightTransparency = 0.3,
        NavWindowingDimBgColor = Color3.fromRGB(204, 204, 204),
        NavWindowingDimBgTransparency = 0.65,

        SeparatorColor = Color3.fromRGB(110, 110, 128),
        SeparatorTransparency = 0.5,

        CheckMarkColor = Color3.fromRGB(66, 150, 250),
        CheckMarkTransparency = 0,

        PlotLinesColor = Color3.fromRGB(156, 156, 156),
        PlotLinesTransparency = 0,
        PlotLinesHoveredColor = Color3.fromRGB(255, 110, 89),
        PlotLinesHoveredTransparency = 0,
        PlotHistogramColor = Color3.fromRGB(230, 179, 0),
        PlotHistogramTransparency = 0,
        PlotHistogramHoveredColor = Color3.fromRGB(255, 153, 0),
        PlotHistogramHoveredTransparency = 0,

        ResizeGripColor = Color3.fromRGB(66, 150, 250),
        ResizeGripTransparency = 0.8,
        ResizeGripHoveredColor = Color3.fromRGB(66, 150, 250),
        ResizeGripHoveredTransparency = 0.33,
        ResizeGripActiveColor = Color3.fromRGB(66, 150, 250),
        ResizeGripActiveTransparency = 0.05,
    },
    colorLight = { -- Dear, ImGui default light
        TextColor = Color3.fromRGB(0, 0, 0),
        TextTransparency = 0,
        TextDisabledColor = Color3.fromRGB(153, 153, 153),
        TextDisabledTransparency = 0,

        -- Dear ImGui uses 0, 0, 0, 77
        -- The Roblox window selection highlight is 67, 191, 254
        BorderColor = Color3.fromRGB(64, 64, 64),
        BorderActiveColor = Color3.fromRGB(64, 64, 64), -- does not exist in Dear ImGui

        -- BorderTransparency will be problematic for non UIStroke border implimentations
        -- will not be implimented because of this
        BorderTransparency = 0.5,
        BorderActiveTransparency = 0.2,

        WindowBgColor = Color3.fromRGB(240, 240, 240),
        WindowBgTransparency = 0,
        PopupBgColor = Color3.fromRGB(255, 255, 255),
        PopupBgTransparency = 0.02,

        TitleBgColor = Color3.fromRGB(245, 245, 245),
        TitleBgTransparency = 0,
        TitleBgActiveColor = Color3.fromRGB(209, 209, 209),
        TitleBgActiveTransparency = 0,
        TitleBgCollapsedColor = Color3.fromRGB(255, 255, 255),
        TitleBgCollapsedTransparency = 0.5,

        MenubarBgColor = Color3.fromRGB(219, 219, 219),
        MenubarBgTransparency = 0,

        ScrollbarGrabColor = Color3.fromRGB(176, 176, 176),
        ScrollbarGrabTransparency = 0.2,

        FrameBgColor = Color3.fromRGB(255, 255, 255),
        FrameBgTransparency = 0.6,
        FrameBgHoveredColor = Color3.fromRGB(66, 150, 250),
        FrameBgHoveredTransparency = 0.6,
        FrameBgActiveColor = Color3.fromRGB(66, 150, 250),
        FrameBgActiveTransparency = 0.33,

        ButtonColor = Color3.fromRGB(66, 150, 250),
        ButtonTransparency = 0.6,
        ButtonHoveredColor = Color3.fromRGB(66, 150, 250),
        ButtonHoveredTransparency = 0,
        ButtonActiveColor = Color3.fromRGB(15, 135, 250),
        ButtonActiveTransparency = 0,

        ImageColor = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0,

        HeaderColor = Color3.fromRGB(66, 150, 250),
        HeaderTransparency = 0.31,
        HeaderHoveredColor = Color3.fromRGB(66, 150, 250),
        HeaderHoveredTransparency = 0.2,
        HeaderActiveColor = Color3.fromRGB(66, 150, 250),
        HeaderActiveTransparency = 0,

        TabColor = Color3.fromRGB(195, 203, 213),
        TabTransparency = 0.07,
        TabHoveredColor = Color3.fromRGB(66, 150, 250),
        TabHoveredTransparency = 0.2,
        TabActiveColor = Color3.fromRGB(152, 186, 255),
        TabActiveTransparency = 0,

        SliderGrabColor = Color3.fromRGB(61, 133, 224),
        SliderGrabTransparency = 0,
        SliderGrabActiveColor = Color3.fromRGB(117, 138, 204),
        SliderGrabActiveTransparency = 0,

        SelectionImageObjectColor = Color3.fromRGB(0, 0, 0),
        SelectionImageObjectTransparency = 0.8,
        SelectionImageObjectBorderColor = Color3.fromRGB(0, 0, 0),
        SelectionImageObjectBorderTransparency = 0,

        TableBorderStrongColor = Color3.fromRGB(145, 145, 163),
        TableBorderStrongTransparency = 0,
        TableBorderLightColor = Color3.fromRGB(173, 173, 189),
        TableBorderLightTransparency = 0,
        TableRowBgColor = Color3.fromRGB(0, 0, 0),
        TableRowBgTransparency = 1,
        TableRowBgAltColor = Color3.fromRGB(77, 77, 77),
        TableRowBgAltTransparency = 0.91,
        TableHeaderColor = Color3.fromRGB(199, 222, 250),
        TableHeaderTransparency = 0,

        NavWindowingHighlightColor = Color3.fromRGB(179, 179, 179),
        NavWindowingHighlightTransparency = 0.3,
        NavWindowingDimBgColor = Color3.fromRGB(51, 51, 51),
        NavWindowingDimBgTransparency = 0.8,

        SeparatorColor = Color3.fromRGB(99, 99, 99),
        SeparatorTransparency = 0.38,

        CheckMarkColor = Color3.fromRGB(66, 150, 250),
        CheckMarkTransparency = 0,

        PlotLinesColor = Color3.fromRGB(99, 99, 99),
        PlotLinesTransparency = 0,
        PlotLinesHoveredColor = Color3.fromRGB(255, 110, 89),
        PlotLinesHoveredTransparency = 0,
        PlotHistogramColor = Color3.fromRGB(230, 179, 0),
        PlotHistogramTransparency = 0,
        PlotHistogramHoveredColor = Color3.fromRGB(255, 153, 0),
        PlotHistogramHoveredTransparency = 0,

        ResizeGripColor = Color3.fromRGB(89, 89, 89),
        ResizeGripTransparency = 0.83,
        ResizeGripHoveredColor = Color3.fromRGB(66, 150, 250),
        ResizeGripHoveredTransparency = 0.33,
        ResizeGripActiveColor = Color3.fromRGB(66, 150, 250),
        ResizeGripActiveTransparency = 0.05,
    },

    sizeDefault = { -- Dear, ImGui default
        ItemWidth = UDim.new(1, 0),
        ContentWidth = UDim.new(0.65, 0),
        ContentHeight = UDim.new(0, 0),

        WindowPadding = Vector2.new(8, 8),
        WindowResizePadding = Vector2.new(6, 6),
        FramePadding = Vector2.new(4, 3),
        ItemSpacing = Vector2.new(8, 4),
        ItemInnerSpacing = Vector2.new(4, 4),
        CellPadding = Vector2.new(4, 2),
        DisplaySafeAreaPadding = Vector2.new(0, 0),
        SeparatorTextPadding = Vector2.new(20, 3),
        IndentSpacing = 21,

        TextFont = Font.fromEnum(Enum.Font.Code),
        TextSize = 13,
        FrameBorderSize = 0,
        FrameRounding = 0,
        GrabRounding = 0,
        WindowRounding = 0, -- these don't actually work but it's nice to have them.
        WindowBorderSize = 1,
        WindowTitleAlign = Enum.LeftRight.Left,
        PopupBorderSize = 1,
        PopupRounding = 0,
        ScrollbarSize = 7,
        GrabMinSize = 10,
        SeparatorTextBorderSize = 3,
        ImageBorderSize = 2,
    },
    sizeClear = { -- easier to read and manuveure
        ItemWidth = UDim.new(1, 0),
        ContentWidth = UDim.new(0.65, 0),
        ContentHeight = UDim.new(0, 0),

        WindowPadding = Vector2.new(12, 8),
        WindowResizePadding = Vector2.new(8, 8),
        FramePadding = Vector2.new(6, 4),
        ItemSpacing = Vector2.new(8, 8),
        ItemInnerSpacing = Vector2.new(8, 8),
        CellPadding = Vector2.new(4, 4),
        DisplaySafeAreaPadding = Vector2.new(8, 8),
        SeparatorTextPadding = Vector2.new(24, 6),
        IndentSpacing = 25,

        TextFont = Font.fromEnum(Enum.Font.Ubuntu),
        TextSize = 15,
        FrameBorderSize = 1,
        FrameRounding = 4,
        GrabRounding = 4,
        WindowRounding = 4,
        WindowBorderSize = 1,
        WindowTitleAlign = Enum.LeftRight.Center,
        PopupBorderSize = 1,
        PopupRounding = 4,
        ScrollbarSize = 9,
        GrabMinSize = 14,
        SeparatorTextBorderSize = 4,
        ImageBorderSize = 4,
    },

    utilityDefault = {
        UseScreenGUIs = true,
        IgnoreGuiInset = false,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
        Parent = nil,
        RichText = false,
        TextWrapped = false,
        DisplayOrderOffset = 127,
        ZIndexOffset = 0,

        MouseDoubleClickTime = 0.30, -- Time for a double-click, in seconds.
        MouseDoubleClickMaxDist = 6.0, -- Distance threshold to stay in to validate a double-click, in pixels.

        HoverColor = Color3.fromRGB(255, 255, 0),
        HoverTransparency = 0.1,
    },
}

return TemplateConfig

end
-- ===== module: Internal =====
__modules["Internal"] = function()

return function(Iris)

    local Internal = {}

    Internal._version = [[ 2.5.1 ]]

    Internal._started = false -- has Iris.connect been called yet
    Internal._shutdown = false
    Internal._cycleTick = 0 -- increments for each call to Cycle, used to determine the relative age and freshness of generated widgets
    Internal._deltaTime = 0

    -- Refresh
    Internal._globalRefreshRequested = false -- refresh means that all GUI is destroyed and regenerated, usually because a style change was made and needed to be propogated to all UI
    Internal._refreshCounter = 0 -- if true, when _Insert is called, the widget called will be regenerated
    Internal._refreshLevel = 1
    Internal._refreshStack = table.create(16)

    -- Widgets & Instances
    Internal._widgets = {}
    Internal._stackIndex = 1 -- Points to the index that IDStack is currently in, when computing cycle
    Internal._rootInstance = nil
    Internal._rootWidget = {
        ID = "R",
        type = "Root",
        Instance = Internal._rootInstance,
        ZIndex = 0,
        ZOffset = 0,
    }
    Internal._lastWidget = Internal._rootWidget -- widget which was most recently rendered

    -- Config
    Internal._rootConfig = {} -- root style which all widgets derive from
    Internal._config = Internal._rootConfig

    -- ID
    Internal._IDStack = { "R" }
    Internal._usedIDs = {} -- hash of IDs which are already used in a cycle, value is the # of occurances so that getID can assign a unique ID for each occurance
    Internal._pushedIds = {}
    Internal._newID = false
    Internal._nextWidgetId = nil

    -- State
    Internal._states = {} -- Iris.States

    -- Callback
    Internal._postCycleCallbacks = {}
    Internal._connectedFunctions = {} -- functions which run each Iris cycle, connected by the user
    Internal._connections = {}
    Internal._initFunctions = {}

    -- Error
    Internal._fullErrorTracebacks = game:GetService("RunService"):IsStudio()

    Internal._cycleCoroutine = coroutine.create(function()
        while Internal._started do
            for _, callback in pairs(Internal._connectedFunctions) do
                debug.profilebegin("Iris/Connection")
                local status, _error= pcall(callback)
                debug.profileend()
                if not status then
                    -- any error reserts the _stackIndex for the next frame and yields the error.
                    Internal._stackIndex = 1
                    coroutine.yield(false, _error)
                end
            end
            -- after all callbacks, we yield so it only runs once a frame.
            coroutine.yield(true)
        end
    end)

    local StateClass = {}
    StateClass.__index = StateClass

    function StateClass:get() -- you can also simply use .value
        return self.value
    end

    function StateClass:set(newValue, force)
        if newValue == self.value and force ~= true then
            -- no need to update on no change.
            return self.value
        end
        self.value = newValue
        self.lastChangeTick = Iris.Internal._cycleTick
        for _, thisWidget in pairs(self.ConnectedWidgets) do
            if thisWidget.lastCycleTick ~= -1 then
                Internal._widgets[thisWidget.type].UpdateState(thisWidget)
            end
        end

        for _, callback in pairs(self.ConnectedFunctions) do
            callback(newValue)
        end
        return self.value
    end

    function StateClass:onChange(callback)
        local connectionIndex = #self.ConnectedFunctions + 1
        self.ConnectedFunctions[connectionIndex] = callback
        return function()
            self.ConnectedFunctions[connectionIndex] = nil
        end
    end

    function StateClass:changed()
        return self.lastChangeTick + 1 == Internal._cycleTick
    end

    Internal.StateClass = StateClass

    function Internal._cycle(deltaTime)
        if Iris.Disabled then
            return -- Stops all rendering, effectively freezes the current frame with no interaction.
        end

        Internal._rootWidget.lastCycleTick = Internal._cycleTick
        if Internal._rootInstance == nil or Internal._rootInstance.Parent == nil then
            Iris.ForceRefresh()
        end

        for _, widget in pairs(Internal._lastVDOM) do
            if widget.lastCycleTick ~= Internal._cycleTick and (widget.lastCycleTick ~= -1) then
                -- a widget which used to be rendered was not called last frame, so we discard it.
                Internal._DiscardWidget(widget)
            end
        end

        -- represents all widgets created last frame. We keep the _lastVDOM to reuse widgets from the previous frame
        -- rather than creating a new instance every frame.
        setmetatable(Internal._lastVDOM, { __mode = "kv" })
        Internal._lastVDOM = Internal._VDOM
        Internal._VDOM = Internal._generateEmptyVDOM()

        -- anything that wnats to run before the frame.
        task.spawn(function()
            for _, callback in pairs(Internal._postCycleCallbacks) do
                callback()
            end
        end)

        if Internal._globalRefreshRequested then
            -- rerender every widget
            Internal._generateSelectionImageObject()
            Internal._globalRefreshRequested = false
            for _, widget in pairs(Internal._lastVDOM) do
                Internal._DiscardWidget(widget)
            end
            Internal._generateRootInstance()
            Internal._lastVDOM = Internal._generateEmptyVDOM()
        end

        -- update counters
        Internal._cycleTick = Internal._cycleTick + 1
        Internal._deltaTime = deltaTime
        table.clear(Internal._usedIDs)

        --     error("Iris Parent Instance is too small")
        local compatibleParent = (Internal.parentInstance:IsA("GuiBase2d") or Internal.parentInstance:IsA("BasePlayerGui"))
        if compatibleParent == false then
            error("The Iris parent instance will not display any GUIs.")
        end

        -- any pcall to protect from an error.
        if Internal._fullErrorTracebacks then
            for _, callback in pairs(Internal._connectedFunctions) do
                callback()
            end
        else

            -- each frame we check on our thread status.
            local coroutineStatus = coroutine.status(Internal._cycleCoroutine)
            if coroutineStatus == "suspended" then
                -- suspended means it yielded, either because it was a complete success
                -- or it caught an error in the code. We run it again for this frame.
                local _, success, result = coroutine.resume(Internal._cycleCoroutine)
                if success == false then
                    -- Connected function code errored
                    error(result, 0)
                end
            elseif coroutineStatus == "running" then
                -- still running (probably because of an asynchronous method inside a connection).
                error("Iris cycleCoroutine took to long to yield. Connected functions should not yield.")
            else
                -- should never reach this (nothing you can do).
                error("unrecoverable state")
            end
        end

        if Internal._stackIndex ~= 1 then
            -- has to be larger than 1 because of the check that it isnt below 1 in Iris.End
            Internal._stackIndex = 1
            error("Too few calls to Iris.End().", 0)
        end

        -- Errors if the end user forgot to pop all their ids as they would leak over into the next frame
        -- could also just clear, but that might be confusing behaviour.
        if #Internal._pushedIds ~= 0 then
            error("Too few calls to Iris.PopId().", 0)
        end

    end

    function Internal._NoOp() end

    --  Widget

    function Internal.WidgetConstructor(type, widgetClass)
        local Fields = {
            All = {
                Required = {
                    "Generate", -- generates the instance.
                    "Discard",
                    "Update",

                    -- not methods !
                    "Args",
                    "Events",
                    "hasChildren",
                    "hasState",
                },
                Optional = {},
            },
            IfState = {
                Required = {
                    "GenerateState",
                    "UpdateState",
                },
                Optional = {},
            },
            IfChildren = {
                Required = {
                    "ChildAdded", -- returns the parent of the child widget.
                },
                Optional = {
                    "ChildDiscarded",
                },
            },
        }

        -- we ensure all essential functions and properties are present, otherwise the code will break later.
        -- some functions will only be needed if the widget has children or has state.
        local thisWidget = {}
        for _, field in pairs(Fields.All.Required) do
            assert(widgetClass[field] ~= nil, string.format("field %s is missing from widget %s, it is required for all widgets", field, type))
            thisWidget[field] = widgetClass[field]
        end

        for _, field in pairs(Fields.All.Optional) do
            if widgetClass[field] == nil then
                -- assign a dummy function which does nothing.
                thisWidget[field] = Internal._NoOp
            else
                thisWidget[field] = widgetClass[field]
            end
        end

        if widgetClass.hasState then
            for _, field in pairs(Fields.IfState.Required) do
                assert(widgetClass[field] ~= nil, string.format("field %s is missing from widget %s, it is required for all widgets with state", field, type))
                thisWidget[field] = widgetClass[field]
            end
            for _, field in pairs(Fields.IfState.Optional) do
                if widgetClass[field] == nil then
                    thisWidget[field] = Internal._NoOp
                else
                    thisWidget[field] = widgetClass[field]
                end
            end
        end

        if widgetClass.hasChildren then
            for _, field in pairs(Fields.IfChildren.Required) do
                assert(widgetClass[field] ~= nil, string.format("field %s is missing from widget %s, it is required for all widgets with children", field, type))
                thisWidget[field] = widgetClass[field]
            end
            for _, field in pairs(Fields.IfChildren.Optional) do
                if widgetClass[field] == nil then
                    thisWidget[field] = Internal._NoOp
                else
                    thisWidget[field] = widgetClass[field]
                end
            end
        end

        -- an internal table of all widgets to the widget class.
        Internal._widgets[type] = thisWidget
        -- allowing access to the index for each widget argument.
        Iris.Args[type] = thisWidget.Args

        local ArgNames = {}
        for index, argument in pairs(thisWidget.Args) do
            ArgNames[argument] = index
        end
        thisWidget.ArgNames = ArgNames

        for index, _ in pairs(thisWidget.Events) do
            if Iris.Events[index] == nil then
                Iris.Events[index] = function()
                    return Internal._EventCall(Internal._lastWidget, index)
                end
            end
        end
    end

    function Internal._Insert(widgetType, args, states)
        local ID = Internal._getID(3)

        -- fetch the widget class which contains all the functions for the widget.
        local thisWidgetClass = Internal._widgets[widgetType]

        if Internal._VDOM[ID] then
            -- widget already created once this frame, so we can append to it.
            return Internal._ContinueWidget(ID, widgetType)
        end

        local arguments = {}
        if args ~= nil then
            if type(args) ~= "table" then
                args = { args }
            end

            -- convert the arguments to a key-value dictionary so arguments can be referred to by their name and not index.
            for index, argument in pairs(args) do
                assert(index > 0, string.format("Widget Arguments must be a positive number, not %s of type %s for %s.", index, typeof(index), argument))
                arguments[thisWidgetClass.ArgNames[index]] = argument
            end
        end
        -- prevents tampering with the arguments which are used to check for changes.
        table.freeze(arguments)

        local lastWidget = Internal._lastVDOM[ID]
        if lastWidget and widgetType == lastWidget.type then
            -- found a matching widget from last frame.
            if Internal._refreshCounter > 0 then
                -- we are redrawing every widget.
                Internal._DiscardWidget(lastWidget)
                lastWidget = nil
            end
        end
        local thisWidget = (lastWidget == nil and Internal._GenNewWidget(widgetType, arguments, states, ID) or lastWidget)

        local parentWidget = thisWidget.parentWidget

        if thisWidget.type ~= "Window" and thisWidget.type ~= "Tooltip" then
            if thisWidget.ZIndex ~= parentWidget.ZOffset then
                parentWidget.ZUpdate = true
            end

            if parentWidget.ZUpdate then
                thisWidget.ZIndex = parentWidget.ZOffset
                if thisWidget.Instance then
                    thisWidget.Instance.ZIndex = thisWidget.ZIndex
                    thisWidget.Instance.LayoutOrder = thisWidget.ZIndex
                end
            end
        end

        -- since rows are not instances, but will be removed if not updated, we have to add specific table code.
        if parentWidget.type == "Table" then
            local Table = parentWidget
            Table._rowCycles[Table._rowIndex] = Internal._cycleTick
        end

        if Internal._deepCompare(thisWidget.providedArguments, arguments) == false then
            -- the widgets arguments have changed, the widget should update to reflect changes.
            -- providedArguments is the frozen table which will not change.
            -- the arguments can be altered internally, which happens for the input widgets.
            thisWidget.arguments = Internal._deepCopy(arguments)
            thisWidget.providedArguments = arguments
            thisWidgetClass.Update(thisWidget)
        end

        thisWidget.lastCycleTick = Internal._cycleTick
        parentWidget.ZOffset = parentWidget.ZOffset + 1
        if thisWidgetClass.hasChildren then
            local thisParent = thisWidget
            -- a parent widget, so we increase our depth.
            thisParent.ZOffset = 0
            thisParent.ZUpdate = false
            Internal._stackIndex = Internal._stackIndex + 1
            Internal._IDStack[Internal._stackIndex] = thisWidget.ID
        end

        Internal._VDOM[ID] = thisWidget
        Internal._lastWidget = thisWidget


        return thisWidget
    end

    function Internal._GenNewWidget(widgetType, arguments, states, ID)
        local parentId = Internal._IDStack[Internal._stackIndex]
        local parentWidget = Internal._VDOM[parentId]
        local thisWidgetClass = Internal._widgets[widgetType]

        -- widgets are just tables with properties.
        local thisWidget = {}
        setmetatable(thisWidget, thisWidget)

        thisWidget.ID = ID
        thisWidget.type = widgetType
        thisWidget.parentWidget = parentWidget
        thisWidget.trackedEvents = {}
        -- thisWidget.UID = HttpService:GenerateGUID(false):sub(0, 8)

        -- widgets have lots of space to ensure they are always visible.
        thisWidget.ZIndex = parentWidget.ZOffset

        thisWidget.Instance = thisWidgetClass.Generate(thisWidget)
        -- tooltips set their parent in the generation method, so we need to udpate it here
        parentWidget = thisWidget.parentWidget

        if Internal._config.Parent then
            thisWidget.Instance.Parent = Internal._config.Parent
        else
            thisWidget.Instance.Parent = Internal._widgets[parentWidget.type].ChildAdded(parentWidget, thisWidget)
        end

        -- we can modify the arguments table, but keep a frozen copy to compare for user-end changes.
        thisWidget.providedArguments = arguments
        thisWidget.arguments = Internal._deepCopy(arguments)
        thisWidgetClass.Update(thisWidget)

        local eventMTParent
        if thisWidgetClass.hasState then
            local stateWidget = thisWidget
            if states then
                for index, state in pairs(states) do
                    if not (type(state) == "table" and getmetatable(state) == Internal.StateClass) then
                        -- generate a new state.
                        states[index] = Internal._widgetState(stateWidget, index, state)
                    end
                    states[index].lastChangeTick = Internal._cycleTick
                end

                stateWidget.state = states
                for _, state in pairs(states) do
                    state.ConnectedWidgets[stateWidget.ID] = stateWidget
                end
            else
                stateWidget.state = {}
            end

            thisWidgetClass.GenerateState(stateWidget)
            thisWidgetClass.UpdateState(stateWidget)

            -- the state MT can't be itself because state has to explicitly only contain stateClass objects
            stateWidget.stateMT = {}
            setmetatable(stateWidget.state, stateWidget.stateMT)

            stateWidget.__index = stateWidget.state
            eventMTParent = stateWidget.stateMT
        else
            eventMTParent = thisWidget
        end

        eventMTParent.__index = function(_, eventName)
            return function()
                return Internal._EventCall(thisWidget, eventName)
            end
        end
        return thisWidget
    end

    function Internal._ContinueWidget(ID, widgetType)
        local thisWidgetClass = Internal._widgets[widgetType]
        local thisWidget = Internal._VDOM[ID]

        if thisWidgetClass.hasChildren then
            -- a parent widget so we increase our depth.
            Internal._stackIndex = Internal._stackIndex + 1
            Internal._IDStack[Internal._stackIndex] = thisWidget.ID
        end

        Internal._lastWidget = thisWidget
        return thisWidget
    end

    function Internal._DiscardWidget(widgetToDiscard)
        local widgetParent = widgetToDiscard.parentWidget
        if widgetParent then
            Internal._widgets[widgetParent.type].ChildDiscarded(widgetParent, widgetToDiscard)
        end

        -- using the widget class discard function.
        Internal._widgets[widgetToDiscard.type].Discard(widgetToDiscard)

        -- mark as discarded
        widgetToDiscard.lastCycleTick = -1
    end

    function Internal._widgetState(thisWidget, stateName, initialValue)
        local ID = thisWidget.ID .. stateName
        if Internal._states[ID] then
            Internal._states[ID].ConnectedWidgets[thisWidget.ID] = thisWidget
            Internal._states[ID].lastChangeTick = Internal._cycleTick
            return Internal._states[ID]
        else
            local newState = {
                ID = ID,
                value = initialValue,
                lastChangeTick = Internal._cycleTick,
                ConnectedWidgets = { [thisWidget.ID] = thisWidget },
                ConnectedFunctions = {},
            }
            setmetatable(newState, Internal.StateClass)
            Internal._states[ID] = newState
            return newState
        end
    end

    function Internal._EventCall(thisWidget, eventName)
        local Events = Internal._widgets[thisWidget.type].Events
        local Event = Events[eventName]
        assert(Event ~= nil, string.format("widget %s has no event of name %s", thisWidget.type, eventName))

        if thisWidget.trackedEvents[eventName] == nil then
            Event.Init(thisWidget)
            thisWidget.trackedEvents[eventName] = true
        end
        return Event.Get(thisWidget)
    end

    function Internal._GetParentWidget()
        return Internal._VDOM[Internal._IDStack[Internal._stackIndex]]
    end

    -- Generate

    function Internal._generateEmptyVDOM()
        return {
            ["R"] = Internal._rootWidget,
        }
    end

    function Internal._generateRootInstance()
        -- unsafe to call before Internal.connect
        Internal._rootInstance = Internal._widgets["Root"].Generate(Internal._widgets["Root"])
        Internal._rootInstance.Parent = Internal.parentInstance
        Internal._rootWidget.Instance = Internal._rootInstance
    end

    function Internal._generateSelectionImageObject()
        if Internal.SelectionImageObject then
            Internal.SelectionImageObject:Destroy()
        end

        local SelectionImageObject = Instance.new("Frame")
        SelectionImageObject.Position = UDim2.fromOffset(-1, -1)
        SelectionImageObject.Size = UDim2.new(1, 2, 1, 2)
        SelectionImageObject.BackgroundColor3 = Internal._config.SelectionImageObjectColor
        SelectionImageObject.BackgroundTransparency = Internal._config.SelectionImageObjectTransparency
        SelectionImageObject.BorderSizePixel = 0

        Internal._utility.UIStroke(SelectionImageObject, 1, Internal._config.SelectionImageObjectBorderColor, Internal._config.SelectionImageObjectBorderTransparency)
        Internal._utility.UICorner(SelectionImageObject, 2)

        Internal.SelectionImageObject = SelectionImageObject
    end

    -- Utility

    function Internal._getID(levelsToIgnore)
        if Internal._nextWidgetId then
            local ID = Internal._nextWidgetId
            Internal._nextWidgetId = nil
            return ID
        end

        local i = 1 + (levelsToIgnore or 1)
        local ID = ""
        local levelInfo = debug.info(i, "l")
        while levelInfo ~= -1 and levelInfo ~= nil do
            ID = ID .. "+" .. levelInfo
            i = i + 1
            levelInfo = debug.info(i, "l")
        end

        local discriminator = Internal._usedIDs[ID]
        if discriminator then
            Internal._usedIDs[ID] = Internal._usedIDs[ID] + 1
            discriminator = discriminator + 1
        else
            Internal._usedIDs[ID] = 1
            discriminator = 1
        end

        if #Internal._pushedIds == 0 then
            return ID .. ":" .. discriminator
        elseif Internal._newID then
            Internal._newID = false
            return ID .. "::" .. table.concat(Internal._pushedIds, "\\")
        else
            return ID .. ":" .. discriminator .. ":" .. table.concat(Internal._pushedIds, "\\")
        end
    end

    function Internal._deepCompare(t1, t2)
        -- unoptimized ?
        for i, v1 in pairs(t1) do
            local v2 = t2[i]
            if type(v1) == "table" then
                if v2 and type(v2) == "table" then
                    if Internal._deepCompare(v1, v2) == false then
                        return false
                    end
                else
                    return false
                end
            else
                if type(v1) ~= type(v2) or v1 ~= v2 then
                    return false
                end
            end
        end

        return true
    end

    function Internal._deepCopy(t)
        local copy = table.clone(t)

        for k, v in pairs(t) do
            if type(v) == "table" then
                copy[k] = Internal._deepCopy(v)
            end
        end

        return copy
    end

    -- VDOM
    Internal._lastVDOM = Internal._generateEmptyVDOM()
    Internal._VDOM = Internal._generateEmptyVDOM()

    Iris.Internal = Internal
    Iris._config = Internal._config
    return Internal
end

end
-- ===== module: widgets.init =====
__modules["widgets.init"] = function()

local widgets = {}

return function(Iris)
    widgets.GuiService = game:GetService("GuiService")
    widgets.RunService = game:GetService("RunService")
    widgets.UserInputService = game:GetService("UserInputService")
    widgets.ContextActionService = game:GetService("ContextActionService")
    widgets.TextService = game:GetService("TextService")

    widgets.ICONS = {
        BLANK_SQUARE = "rbxassetid://83265623867126",
        RIGHT_POINTING_TRIANGLE = "rbxassetid://105541346271951",
        DOWN_POINTING_TRIANGLE = "rbxassetid://95465797476827",
        MULTIPLICATION_SIGN = "rbxassetid://133890060015237", -- best approximation for a close X which roblox supports, needs to be scaled about 2x
        BOTTOM_RIGHT_CORNER = "rbxassetid://125737344915000", -- used in window resize icon in bottom right
        CHECKMARK = "rbxassetid://109638815494221",
        BORDER = "rbxassetid://133803690460269",
        ALPHA_BACKGROUND_TEXTURE = "rbxassetid://114090016039876", -- used for color4 alpha
        UNKNOWN_TEXTURE = "rbxassetid://95045813476061",
    }

    widgets.IS_STUDIO = widgets.RunService:IsStudio()
    function widgets.getTime()
        -- time() always returns 0 in the context of plugins
        if widgets.IS_STUDIO then
            return os.clock()
        else
            return time()
        end
    end

    -- acts as an offset where the absolute position of the base frame is not zero, such as IgnoreGuiInset or for stories
    widgets.GuiOffset = (Iris._config.IgnoreGuiInset and -widgets.GuiService:GetGuiInset() or Vector2.zero)
    -- the registered mouse position always ignores the topbar, so needs a separate variable offset
    widgets.MouseOffset = (Iris._config.IgnoreGuiInset and Vector2.zero or widgets.GuiService:GetGuiInset())

    -- the topbar inset changes updates a frame later.

    connection = widgets.GuiService:GetPropertyChangedSignal("TopbarInset"):Once(function()
        widgets.MouseOffset = (Iris._config.IgnoreGuiInset and Vector2.zero or widgets.GuiService:GetGuiInset())
        widgets.GuiOffset = (Iris._config.IgnoreGuiInset and -widgets.GuiService:GetGuiInset() or Vector2.zero)
        connection:Disconnect()
    end)
    -- in case the topbar doesn't change, we cancel the event.
    task.delay(5, function()
        connection:Disconnect()
    end)

    function widgets.getMouseLocation()
        return widgets.UserInputService:GetMouseLocation() - widgets.MouseOffset
    end

    function widgets.isPosInsideRect(pos, rectMin, rectMax)
        return pos.X >= rectMin.X and pos.X <= rectMax.X and pos.Y >= rectMin.Y and pos.Y <= rectMax.Y
    end

    function widgets.findBestWindowPosForPopup(refPos, size, outerMin, outerMax)
        local CURSOR_OFFSET_DIST = 20

        if refPos.X + size.X + CURSOR_OFFSET_DIST > outerMax.X then
            if refPos.Y + size.Y + CURSOR_OFFSET_DIST > outerMax.Y then
                -- placed to the top
                refPos = refPos + Vector2.new(0, -(CURSOR_OFFSET_DIST + size.Y))
            else
                -- placed to the bottom
                refPos = refPos + Vector2.new(0, CURSOR_OFFSET_DIST)
            end
        else
            -- placed to the right
            refPos = refPos + Vector2.new(CURSOR_OFFSET_DIST)
        end

        return Vector2.new(math.max(math.min(refPos.X + size.X, outerMax.X) - size.X, outerMin.X), math.max(math.min(refPos.Y + size.Y, outerMax.Y) - size.Y, outerMin.Y))
    end

    function widgets.getScreenSizeForWindow(thisWidget) -- possible parents are GuiBase2d, CoreGui, PlayerGui
        if thisWidget.Instance:IsA("GuiBase2d") then
            return thisWidget.Instance.AbsoluteSize
        else
            local rootParent = thisWidget.Instance.Parent
            if rootParent:IsA("GuiBase2d") then
                return rootParent.AbsoluteSize
            else
                if rootParent.Parent:IsA("GuiBase2d") then
                    return rootParent.AbsoluteSize
                else
                    return workspace.CurrentCamera.ViewportSize
                end
            end
        end
    end

    function widgets.extend(superClass, subClass)
        local newClass = table.clone(superClass)
        for index, value in pairs(subClass) do
            newClass[index] = value
        end
        return newClass
    end

    function widgets.UIPadding(Parent, PxPadding)
        local UIPaddingInstance = Instance.new("UIPadding")
        UIPaddingInstance.PaddingLeft = UDim.new(0, PxPadding.X)
        UIPaddingInstance.PaddingRight = UDim.new(0, PxPadding.X)
        UIPaddingInstance.PaddingTop = UDim.new(0, PxPadding.Y)
        UIPaddingInstance.PaddingBottom = UDim.new(0, PxPadding.Y)
        UIPaddingInstance.Parent = Parent
        return UIPaddingInstance
    end

    function widgets.UIListLayout(Parent, FillDirection, Padding)
        local UIListLayoutInstance = Instance.new("UIListLayout")
        UIListLayoutInstance.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayoutInstance.Padding = Padding
        UIListLayoutInstance.FillDirection = FillDirection
        UIListLayoutInstance.Parent = Parent
        return UIListLayoutInstance
    end

    function widgets.UIStroke(Parent, Thickness, Color, Transparency)
        local UIStrokeInstance = Instance.new("UIStroke")
        UIStrokeInstance.Thickness = Thickness
        UIStrokeInstance.Color = Color
        UIStrokeInstance.Transparency = Transparency
        UIStrokeInstance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStrokeInstance.LineJoinMode = Enum.LineJoinMode.Round
        UIStrokeInstance.Parent = Parent
        return UIStrokeInstance
    end

    function widgets.UICorner(Parent, PxRounding)
        local UICornerInstance = Instance.new("UICorner")
        UICornerInstance.CornerRadius = UDim.new(PxRounding and 0 or 1, PxRounding or 0)
        UICornerInstance.Parent = Parent
        return UICornerInstance
    end

    function widgets.UISizeConstraint(Parent, MinSize, MaxSize)
        local UISizeConstraintInstance = Instance.new("UISizeConstraint")
        UISizeConstraintInstance.MinSize = MinSize or UISizeConstraintInstance.MinSize -- made these optional
        UISizeConstraintInstance.MaxSize = MaxSize or UISizeConstraintInstance.MaxSize
        UISizeConstraintInstance.Parent = Parent
        return UISizeConstraintInstance
    end

    -- below uses Iris

    function widgets.applyTextStyle(thisInstance)
        thisInstance.FontFace = Iris._config.TextFont
        thisInstance.TextSize = Iris._config.TextSize
        thisInstance.TextColor3 = Iris._config.TextColor
        thisInstance.TextTransparency = Iris._config.TextTransparency
        thisInstance.TextXAlignment = Enum.TextXAlignment.Left
        thisInstance.TextYAlignment = Enum.TextYAlignment.Center
        thisInstance.RichText = Iris._config.RichText
        thisInstance.TextWrapped = Iris._config.TextWrapped

        thisInstance.AutoLocalize = false
    end

    function widgets.applyInteractionHighlights(Property, Button, Highlightee, Colors)
        local exitedButton = false
        widgets.applyMouseEnter(Button, function()
            Highlightee[Property .. "Color3"] = Colors.HoveredColor
            Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency

            exitedButton = false
        end)

        widgets.applyMouseLeave(Button, function()
            Highlightee[Property .. "Color3"] = Colors.Color
            Highlightee[Property .. "Transparency"] = Colors.Transparency

            exitedButton = true
        end)

        widgets.applyInputBegan(Button, function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) then
                return
            end
            Highlightee[Property .. "Color3"] = Colors.ActiveColor
            Highlightee[Property .. "Transparency"] = Colors.ActiveTransparency
        end)

        widgets.applyInputEnded(Button, function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) or exitedButton then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Highlightee[Property .. "Color3"] = Colors.HoveredColor
                Highlightee[Property .. "Transparency"] = Colors.HoveredTransparency
            end
            if input.UserInputType == Enum.UserInputType.Gamepad1 then
                Highlightee[Property .. "Color3"] = Colors.Color
                Highlightee[Property .. "Transparency"] = Colors.Transparency
            end
        end)

        Button.SelectionImageObject = Iris.SelectionImageObject
    end

    function widgets.applyInteractionHighlightsWithMultiHighlightee(Property, Button, Highlightees)
        local exitedButton = false
        widgets.applyMouseEnter(Button, function()
            for _, Highlightee in pairs(Highlightees) do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency

                exitedButton = false
            end
        end)

        widgets.applyMouseLeave(Button, function()
            for _, Highlightee in pairs(Highlightees) do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency

                exitedButton = true
            end
        end)

        widgets.applyInputBegan(Button, function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) then
                return
            end
            for _, Highlightee in pairs(Highlightees) do
                Highlightee[1][Property .. "Color3"] = Highlightee[2].ActiveColor
                Highlightee[1][Property .. "Transparency"] = Highlightee[2].ActiveTransparency
            end
        end)

        widgets.applyInputEnded(Button, function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Gamepad1) or exitedButton then
                return
            end
            for _, Highlightee in pairs(Highlightees) do
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Highlightee[1][Property .. "Color3"] = Highlightee[2].HoveredColor
                    Highlightee[1][Property .. "Transparency"] = Highlightee[2].HoveredTransparency
                end
                if input.UserInputType == Enum.UserInputType.Gamepad1 then
                    Highlightee[1][Property .. "Color3"] = Highlightee[2].Color
                    Highlightee[1][Property .. "Transparency"] = Highlightee[2].Transparency
                end
            end
        end)

        Button.SelectionImageObject = Iris.SelectionImageObject
    end

    function widgets.applyFrameStyle(thisInstance, noPadding, noCorner)
        -- padding, border, and rounding
        -- optimized to only use what instances are needed, based on style
        local FrameBorderSize = Iris._config.FrameBorderSize
        local FrameRounding = Iris._config.FrameRounding
        thisInstance.BorderSizePixel = 0

        if FrameBorderSize > 0 then
            widgets.UIStroke(thisInstance, FrameBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)
        end
        if FrameRounding > 0 and not noCorner then
            widgets.UICorner(thisInstance, FrameRounding)
        end
        if not noPadding then
            widgets.UIPadding(thisInstance, Iris._config.FramePadding)
        end
    end

    function widgets.applyButtonClick(thisInstance, callback)
        thisInstance.MouseButton1Click:Connect(function()
            callback()
        end)
    end

    function widgets.applyButtonDown(thisInstance, callback)
        thisInstance.MouseButton1Down:Connect(function(x, y)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseEnter(thisInstance, callback)
        thisInstance.MouseEnter:Connect(function(x, y)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseMoved(thisInstance, callback)
        thisInstance.MouseMoved:Connect(function(x, y)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyMouseLeave(thisInstance, callback)
        thisInstance.MouseLeave:Connect(function(x, y)
            local position = Vector2.new(x, y) - widgets.MouseOffset
            callback(position.X, position.Y)
        end)
    end

    function widgets.applyInputBegan(thisInstance, callback)
        thisInstance.InputBegan:Connect(function(...)
            callback(...)
        end)
    end

    function widgets.applyInputEnded(thisInstance, callback)
        thisInstance.InputEnded:Connect(function(...)
            callback(...)
        end)
    end

    function widgets.discardState(thisWidget)
        for _, state in pairs(thisWidget.state) do
            state.ConnectedWidgets[thisWidget.ID] = nil
        end
    end

    function widgets.registerEvent(event, callback)
        table.insert(Iris._initFunctions, function()
            table.insert(Iris._connections, widgets.UserInputService[event]:Connect(callback))
        end)
    end

    widgets.EVENTS = {
        hover = function(pathToHovered)
            return {
                ["Init"] = function(thisWidget)
                    local hoveredGuiObject = pathToHovered(thisWidget)
                    widgets.applyMouseEnter(hoveredGuiObject, function()
                        thisWidget.isHoveredEvent = true
                    end)
                    widgets.applyMouseLeave(hoveredGuiObject, function()
                        thisWidget.isHoveredEvent = false
                    end)
                    thisWidget.isHoveredEvent = false
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.isHoveredEvent
                end,
            }
        end,

        click = function(pathToClicked)
            return {
                ["Init"] = function(thisWidget)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastClickedTick = -1

                    widgets.applyButtonClick(clickedGuiObject, function()
                        thisWidget.lastClickedTick = Iris._cycleTick + 1
                    end)
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastClickedTick == Iris._cycleTick
                end,
            }
        end,

        rightClick = function(pathToClicked)
            return {
                ["Init"] = function(thisWidget)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastRightClickedTick = -1

                    clickedGuiObject.MouseButton2Click:Connect(function()
                        thisWidget.lastRightClickedTick = Iris._cycleTick + 1
                    end)
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastRightClickedTick == Iris._cycleTick
                end,
            }
        end,

        doubleClick = function(pathToClicked)
            return {
                ["Init"] = function(thisWidget)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastClickedTime = -1
                    thisWidget.lastClickedPosition = Vector2.zero
                    thisWidget.lastDoubleClickedTick = -1

                    widgets.applyButtonDown(clickedGuiObject, function(x, y)
                        local currentTime = widgets.getTime()
                        local isTimeValid = currentTime - thisWidget.lastClickedTime < Iris._config.MouseDoubleClickTime
                        if isTimeValid and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude < Iris._config.MouseDoubleClickMaxDist then
                            thisWidget.lastDoubleClickedTick = Iris._cycleTick + 1
                        else
                            thisWidget.lastClickedTime = currentTime
                            thisWidget.lastClickedPosition = Vector2.new(x, y)
                        end
                    end)
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastDoubleClickedTick == Iris._cycleTick
                end,
            }
        end,

        ctrlClick = function(pathToClicked)
            return {
                ["Init"] = function(thisWidget)
                    local clickedGuiObject = pathToClicked(thisWidget)
                    thisWidget.lastCtrlClickedTick = -1

                    widgets.applyButtonClick(clickedGuiObject, function()
                        if widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                            thisWidget.lastCtrlClickedTick = Iris._cycleTick + 1
                        end
                    end)
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastCtrlClickedTick == Iris._cycleTick
                end,
            }
        end,
    }

    Iris._utility = widgets

    __require("widgets.Root", Iris, widgets)
    __require("widgets.Window", Iris, widgets)

    __require("widgets.Menu", Iris, widgets)

    __require("widgets.Format", Iris, widgets)

    __require("widgets.Text", Iris, widgets)
    __require("widgets.Button", Iris, widgets)
    __require("widgets.Checkbox", Iris, widgets)
    __require("widgets.RadioButton", Iris, widgets)
    __require("widgets.Image", Iris, widgets)

    __require("widgets.Tree", Iris, widgets)
    __require("widgets.Tab", Iris, widgets)

    __require("widgets.Input", Iris, widgets)
    __require("widgets.Combo", Iris, widgets)
    __require("widgets.Plot", Iris, widgets)

    __require("widgets.Table", Iris, widgets)
end

end
-- ===== module: widgets.Root =====
__modules["widgets.Root"] = function()

return function(Iris, widgets)
    local NumNonWindowChildren = 0

    Iris.WidgetConstructor("Root", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget)
            local Root = Instance.new("Folder")
            Root.Name = "Iris_Root"

            local PseudoWindowScreenGui
            if Iris._config.UseScreenGUIs then
                PseudoWindowScreenGui = Instance.new("ScreenGui")
                PseudoWindowScreenGui.ResetOnSpawn = false
                PseudoWindowScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                PseudoWindowScreenGui.ScreenInsets = Iris._config.ScreenInsets
                PseudoWindowScreenGui.IgnoreGuiInset = Iris._config.IgnoreGuiInset
                PseudoWindowScreenGui.DisplayOrder = Iris._config.DisplayOrderOffset
            else
                PseudoWindowScreenGui = Instance.new("Frame")
                PseudoWindowScreenGui.AnchorPoint = Vector2.new(0.5, 0.5)
                PseudoWindowScreenGui.Position = UDim2.fromScale(0.5, 0.5)
                PseudoWindowScreenGui.Size = UDim2.fromScale(1, 1)
                PseudoWindowScreenGui.BackgroundTransparency = 1
                PseudoWindowScreenGui.ZIndex = Iris._config.DisplayOrderOffset
            end
            PseudoWindowScreenGui.Name = "PseudoWindowScreenGui"
            PseudoWindowScreenGui.Parent = Root

            local PopupScreenGui
            if Iris._config.UseScreenGUIs then
                PopupScreenGui = Instance.new("ScreenGui")
                PopupScreenGui.ResetOnSpawn = false
                PopupScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                PopupScreenGui.DisplayOrder = Iris._config.DisplayOrderOffset + 1024 -- room for 1024 regular windows before overlap
                PopupScreenGui.ScreenInsets = Iris._config.ScreenInsets
                PopupScreenGui.IgnoreGuiInset = Iris._config.IgnoreGuiInset
            else
                PopupScreenGui = Instance.new("Frame")
                PopupScreenGui.AnchorPoint = Vector2.new(0.5, 0.5)
                PopupScreenGui.Position = UDim2.fromScale(0.5, 0.5)
                PopupScreenGui.Size = UDim2.fromScale(1, 1)
                PopupScreenGui.BackgroundTransparency = 1
                PopupScreenGui.ZIndex = Iris._config.DisplayOrderOffset + 1024
            end
            PopupScreenGui.Name = "PopupScreenGui"
            PopupScreenGui.Parent = Root

            local TooltipContainer = Instance.new("Frame")
            TooltipContainer.Name = "TooltipContainer"
            TooltipContainer.AutomaticSize = Enum.AutomaticSize.XY
            TooltipContainer.Size = UDim2.fromOffset(0, 0)
            TooltipContainer.BackgroundTransparency = 1
            TooltipContainer.BorderSizePixel = 0

            widgets.UIListLayout(TooltipContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.PopupBorderSize))

            TooltipContainer.Parent = PopupScreenGui

            local MenuBarContainer = Instance.new("Frame")
            MenuBarContainer.Name = "MenuBarContainer"
            MenuBarContainer.AutomaticSize = Enum.AutomaticSize.Y
            MenuBarContainer.Size = UDim2.fromScale(1, 0)
            MenuBarContainer.BackgroundTransparency = 1
            MenuBarContainer.BorderSizePixel = 0

            MenuBarContainer.Parent = PopupScreenGui

            local PseudoWindow = Instance.new("Frame")
            PseudoWindow.Name = "PseudoWindow"
            PseudoWindow.AutomaticSize = Enum.AutomaticSize.XY
            PseudoWindow.Size = UDim2.new(0, 0, 0, 0)
            PseudoWindow.Position = UDim2.fromOffset(0, 22)
            PseudoWindow.BackgroundTransparency = Iris._config.WindowBgTransparency
            PseudoWindow.BackgroundColor3 = Iris._config.WindowBgColor
            PseudoWindow.BorderSizePixel = Iris._config.WindowBorderSize
            PseudoWindow.BorderColor3 = Iris._config.BorderColor

            PseudoWindow.Selectable = false
            PseudoWindow.SelectionGroup = true
            PseudoWindow.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
            PseudoWindow.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

            PseudoWindow.Visible = false

            widgets.UIPadding(PseudoWindow, Iris._config.WindowPadding)
            widgets.UIListLayout(PseudoWindow, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))

            PseudoWindow.Parent = PseudoWindowScreenGui

            return Root
        end,
        Update = function(thisWidget)
            if NumNonWindowChildren > 0 then
                local Root = thisWidget.Instance
                local PseudoWindowScreenGui = Root.PseudoWindowScreenGui
                local PseudoWindow = PseudoWindowScreenGui.PseudoWindow
                PseudoWindow.Visible = true
            end
        end,
        Discard = function(thisWidget)
            NumNonWindowChildren = 0
            thisWidget.Instance:Destroy()
        end,
        ChildAdded = function(thisWidget, thisChild)
            local Root = thisWidget.Instance

            if thisChild.type == "Window" then
                return thisWidget.Instance
            elseif thisChild.type == "Tooltip" then
                return Root.PopupScreenGui.TooltipContainer
            elseif thisChild.type == "MenuBar" then
                return Root.PopupScreenGui.MenuBarContainer
            else
                local PseudoWindowScreenGui = Root.PseudoWindowScreenGui
                local PseudoWindow = PseudoWindowScreenGui.PseudoWindow

                NumNonWindowChildren = NumNonWindowChildren + 1
                PseudoWindow.Visible = true

                return PseudoWindow
            end
        end,
        ChildDiscarded = function(thisWidget, thisChild)
            if thisChild.type ~= "Window" and thisChild.type ~= "Tooltip" and thisChild.type ~= "MenuBar" then
                NumNonWindowChildren = NumNonWindowChildren - 1
                if NumNonWindowChildren == 0 then
                    local Root = thisWidget.Instance
                    local PseudoWindowScreenGui = Root.PseudoWindowScreenGui
                    local PseudoWindow = PseudoWindowScreenGui.PseudoWindow
                    PseudoWindow.Visible = false
                end
            end
        end,
    })
end

end
-- ===== module: widgets.Window =====
__modules["widgets.Window"] = function()

return function(Iris, widgets)
    local function relocateTooltips()
        if Iris._rootInstance == nil then
            return
        end
        local PopupScreenGui = Iris._rootInstance:FindFirstChild("PopupScreenGui")
        local TooltipContainer = PopupScreenGui.TooltipContainer
        local mouseLocation = widgets.getMouseLocation()
        local newPosition = widgets.findBestWindowPosForPopup(mouseLocation, TooltipContainer.AbsoluteSize, Iris._config.DisplaySafeAreaPadding, PopupScreenGui.AbsoluteSize)
        TooltipContainer.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
    end

    widgets.registerEvent("InputChanged", function()
        if not Iris._started then
            return
        end
        relocateTooltips()
    end)

    Iris.WidgetConstructor("Tooltip", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {},
        Generate = function(thisWidget)
            thisWidget.parentWidget = Iris._rootWidget -- only allow root as parent

            local Tooltip = Instance.new("Frame")
            Tooltip.Name = "Iris_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.Y
            Tooltip.Size = UDim2.new(Iris._config.ContentWidth, UDim.new(0, 0))
            Tooltip.BorderSizePixel = 0
            Tooltip.BackgroundTransparency = 1

            local TooltipText = Instance.new("TextLabel")
            TooltipText.Name = "TooltipText"
            TooltipText.AutomaticSize = Enum.AutomaticSize.XY
            TooltipText.Size = UDim2.fromOffset(0, 0)
            TooltipText.BackgroundColor3 = Iris._config.PopupBgColor
            TooltipText.BackgroundTransparency = Iris._config.PopupBgTransparency

            widgets.applyTextStyle(TooltipText)
            widgets.UIStroke(TooltipText, Iris._config.PopupBorderSize, Iris._config.BorderActiveColor, Iris._config.BorderActiveTransparency)
            widgets.UIPadding(TooltipText, Iris._config.WindowPadding)
            if Iris._config.PopupRounding > 0 then
                widgets.UICorner(TooltipText, Iris._config.PopupRounding)
            end

            TooltipText.Parent = Tooltip

            return Tooltip
        end,
        Update = function(thisWidget)
            local Tooltip = thisWidget.Instance
            local TooltipText = Tooltip.TooltipText
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Iris.Tooltip().", 5)
            end
            TooltipText.Text = thisWidget.arguments.Text
            relocateTooltips()
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    local windowDisplayOrder = 0 -- incremental count which is used for determining focused windows ZIndex

    local isDragging = false

    local isResizing = false
    local isInsideResize = false -- is cursor inside of the focused window resize outer padding
    local isInsideWindow = false -- is cursor inside of the focused window
    local resizeFromTopBottom = Enum.TopBottom.Top
    local resizeFromLeftRight = Enum.LeftRight.Left

    local anyFocusedWindow = false -- is there any focused window?

    local windowWidgets = {} -- array of widget objects of type window

    local function quickSwapWindows()
        -- ctrl + tab swapping functionality
        if Iris._config.UseScreenGUIs == false then
            return
        end

        local lowest = 0xFFFF

        for _, widget in pairs(windowWidgets) do
            if widget.state.isOpened.value and not widget.arguments.NoNav then
                if widget.Instance:IsA("ScreenGui") then
                    local value = widget.Instance.DisplayOrder
                    if value < lowest then
                        lowest = value
                        lowestWidget = widget
                    end
                end
            end
        end

        if not lowestWidget then
            return
        end

        if lowestWidget.state.isUncollapsed.value == false then
            lowestWidget.state.isUncollapsed:set(true)
        end
        Iris.SetFocusedWindow(lowestWidget)
    end

    local function fitSizeToWindowBounds(thisWidget, intentedSize)
        local windowSize = Vector2.new(thisWidget.state.position.value.X, thisWidget.state.position.value.Y)
        local minWindowSize = (Iris._config.TextSize + 2 * Iris._config.FramePadding.Y) * 2
        local usableSize = widgets.getScreenSizeForWindow(thisWidget)
        local safeAreaPadding = Vector2.new(Iris._config.WindowBorderSize + Iris._config.DisplaySafeAreaPadding.X, Iris._config.WindowBorderSize + Iris._config.DisplaySafeAreaPadding.Y)

        local maxWindowSize = (usableSize - windowSize - safeAreaPadding)
        return Vector2.new(math.clamp(intentedSize.X, minWindowSize, math.max(maxWindowSize.X, minWindowSize)), math.clamp(intentedSize.Y, minWindowSize, math.max(maxWindowSize.Y, minWindowSize)))
    end

    local function fitPositionToWindowBounds(thisWidget, intendedPosition)
        local thisWidgetInstance = thisWidget.Instance
        local usableSize = widgets.getScreenSizeForWindow(thisWidget)
        local safeAreaPadding = Vector2.new(Iris._config.WindowBorderSize + Iris._config.DisplaySafeAreaPadding.X, Iris._config.WindowBorderSize + Iris._config.DisplaySafeAreaPadding.Y)

        return Vector2.new(
            math.clamp(intendedPosition.X, safeAreaPadding.X, math.max(safeAreaPadding.X, usableSize.X - thisWidgetInstance.WindowButton.AbsoluteSize.X - safeAreaPadding.X)),
            math.clamp(intendedPosition.Y, safeAreaPadding.Y, math.max(safeAreaPadding.Y, usableSize.Y - thisWidgetInstance.WindowButton.AbsoluteSize.Y - safeAreaPadding.Y))
        )
    end

    Iris.SetFocusedWindow = function(thisWidget)
        if focusedWindow == thisWidget then
            return
        end

        if anyFocusedWindow and focusedWindow ~= nil then
            if windowWidgets[focusedWindow.ID] then
                local Window = focusedWindow.Instance
                local WindowButton = Window.WindowButton
                local Content = WindowButton.Content
                local TitleBar = Content.TitleBar
                -- update appearance to unfocus
                if focusedWindow.state.isUncollapsed.value then
                    TitleBar.BackgroundColor3 = Iris._config.TitleBgColor
                    TitleBar.BackgroundTransparency = Iris._config.TitleBgTransparency
                else
                    TitleBar.BackgroundColor3 = Iris._config.TitleBgCollapsedColor
                    TitleBar.BackgroundTransparency = Iris._config.TitleBgCollapsedTransparency
                end
                WindowButton.UIStroke.Color = Iris._config.BorderColor
            end

            anyFocusedWindow = false
            focusedWindow = nil
        end

        if thisWidget ~= nil then
            -- update appearance to focus
            anyFocusedWindow = true
            focusedWindow = thisWidget
            local Window = thisWidget.Instance
            local WindowButton = Window.WindowButton
            local Content = WindowButton.Content
            local TitleBar = Content.TitleBar

            TitleBar.BackgroundColor3 = Iris._config.TitleBgActiveColor
            TitleBar.BackgroundTransparency = Iris._config.TitleBgActiveTransparency
            WindowButton.UIStroke.Color = Iris._config.BorderActiveColor

            windowDisplayOrder = windowDisplayOrder + 1
            if thisWidget.usesScreenGuis then
                Window.DisplayOrder = windowDisplayOrder + Iris._config.DisplayOrderOffset
            else
                Window.ZIndex = windowDisplayOrder + Iris._config.DisplayOrderOffset
            end

            if thisWidget.state.isUncollapsed.value == false then
                thisWidget.state.isUncollapsed:set(true)
            end

            local firstSelectedObject = widgets.GuiService.SelectedObject
            if firstSelectedObject then
                if TitleBar.Visible then
                    widgets.GuiService:Select(TitleBar)
                else
                    widgets.GuiService:Select(thisWidget.ChildContainer)
                end
            end
        end
    end

    widgets.registerEvent("InputBegan", function(input)
        if not Iris._started then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local inWindow = false
            local position = widgets.getMouseLocation()
            for _, window in pairs(windowWidgets) do
                local Window = window.Instance
                if not Window then
do end
                end
                local WindowButton = Window.WindowButton
                local ResizeBorder = WindowButton.ResizeBorder
                if ResizeBorder and widgets.isPosInsideRect(position, ResizeBorder.AbsolutePosition - widgets.GuiOffset, ResizeBorder.AbsolutePosition - widgets.GuiOffset + ResizeBorder.AbsoluteSize) then
                    inWindow = true
                    break
                end
            end

            if not inWindow then
                Iris.SetFocusedWindow(nil)
            end
        end

        if input.KeyCode == Enum.KeyCode.Tab and (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            quickSwapWindows()
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 and isInsideResize and not isInsideWindow and anyFocusedWindow and focusedWindow then
            local midWindow = focusedWindow.state.position.value + (focusedWindow.state.size.value / 2)
            local cursorPosition = widgets.getMouseLocation() - midWindow

            -- check which axis its closest to, then check which side is closest with math.sign
            if math.abs(cursorPosition.X) * focusedWindow.state.size.value.Y >= math.abs(cursorPosition.Y) * focusedWindow.state.size.value.X then
                resizeFromTopBottom = Enum.TopBottom.Center
                resizeFromLeftRight = (math.sign(cursorPosition.X) == -1 and Enum.LeftRight.Left or Enum.LeftRight.Right)
            else
                resizeFromLeftRight = Enum.LeftRight.Center
                resizeFromTopBottom = (math.sign(cursorPosition.Y) == -1 and Enum.TopBottom.Top or Enum.TopBottom.Bottom)
            end
            isResizing = true
            resizeWindow = focusedWindow
        end
    end)

    widgets.registerEvent("TouchTapInWorld", function(_, gameProcessedEvent)
        if not Iris._started then
            return
        end
        if not gameProcessedEvent then
            Iris.SetFocusedWindow(nil)
        end
    end)

    widgets.registerEvent("InputChanged", function(input)
        if not Iris._started then
            return
        end
        if isDragging and dragWindow then
            local mouseLocation
            if input.UserInputType == Enum.UserInputType.Touch then
                local location = input.Position
                mouseLocation = Vector2.new(location.X, location.Y)
            else
                mouseLocation = widgets.getMouseLocation()
            end
            local Window = dragWindow.Instance
            local dragInstance = Window.WindowButton
            local intendedPosition = mouseLocation - moveDeltaCursorPosition
            local newPos = fitPositionToWindowBounds(dragWindow, intendedPosition)

            -- state shouldnt be used like this, but calling :set would run the entire UpdateState function for the window, which is slow.
            dragInstance.Position = UDim2.fromOffset(newPos.X, newPos.Y)
            dragWindow.state.position.value = newPos
        end
        if isResizing and resizeWindow and resizeWindow.arguments.NoResize ~= true then
            local Window = resizeWindow.Instance
            local resizeInstance = Window.WindowButton
            local windowPosition = Vector2.new(resizeInstance.Position.X.Offset, resizeInstance.Position.Y.Offset)
            local windowSize = Vector2.new(resizeInstance.Size.X.Offset, resizeInstance.Size.Y.Offset)

            local mouseDelta
            if input.UserInputType == Enum.UserInputType.Touch then
                mouseDelta = input.Delta
            else
                mouseDelta = widgets.getMouseLocation() - lastCursorPosition
            end

            local intendedPosition = windowPosition + Vector2.new((resizeFromLeftRight == Enum.LeftRight.Left and mouseDelta.X or 0), (resizeFromTopBottom == Enum.TopBottom.Top and mouseDelta.Y or 0))

            local intendedSize = windowSize
                + Vector2.new(
                    (resizeFromLeftRight == Enum.LeftRight.Left and -mouseDelta.X or (resizeFromLeftRight == Enum.LeftRight.Right and mouseDelta.X or 0)),
                    (resizeFromTopBottom == Enum.TopBottom.Top and -mouseDelta.Y or (resizeFromTopBottom == Enum.TopBottom.Bottom and mouseDelta.Y or 0))
                )

            local newSize = fitSizeToWindowBounds(resizeWindow, intendedSize)
            local newPosition = fitPositionToWindowBounds(resizeWindow, intendedPosition)

            resizeInstance.Size = UDim2.fromOffset(newSize.X, newSize.Y)
            resizeWindow.state.size.value = newSize
            resizeInstance.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
            resizeWindow.state.position.value = newPosition
        end

        lastCursorPosition = widgets.getMouseLocation()
    end)

    widgets.registerEvent("InputEnded", function(input, _)
        if not Iris._started then
            return
        end
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isDragging and dragWindow then
            local Window = dragWindow.Instance
            local dragInstance = Window.WindowButton
            isDragging = false
            dragWindow.state.position:set(Vector2.new(dragInstance.Position.X.Offset, dragInstance.Position.Y.Offset))
        end
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isResizing and resizeWindow then
            local Window = resizeWindow.Instance
            isResizing = false
            resizeWindow.state.size:set(Window.WindowButton.AbsoluteSize)
        end

        if input.KeyCode == Enum.KeyCode.ButtonX then
            quickSwapWindows()
        end
    end)

    Iris.WidgetConstructor("Window", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Title"] = 1,
            ["NoTitleBar"] = 2,
            ["NoBackground"] = 3,
            ["NoCollapse"] = 4,
            ["NoClose"] = 5,
            ["NoMove"] = 6,
            ["NoScrollbar"] = 7,
            ["NoResize"] = 8,
            ["NoNav"] = 9,
            ["NoMenu"] = 10,
        },
        Events = {
            ["closed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastClosedTick == Iris._cycleTick
                end,
            },
            ["opened"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastOpenedTick == Iris._cycleTick
                end,
            },
            ["collapsed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastCollapsedTick == Iris._cycleTick
                end,
            },
            ["uncollapsed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUncollapsedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                local Window = thisWidget.Instance
                return Window.WindowButton
            end),
        },
        Generate = function(thisWidget)
            thisWidget.parentWidget = Iris._rootWidget -- only allow root as parent

            thisWidget.usesScreenGuis = Iris._config.UseScreenGUIs
            windowWidgets[thisWidget.ID] = thisWidget

            local Window
            if thisWidget.usesScreenGuis then
                Window = Instance.new("ScreenGui")
                Window.ResetOnSpawn = false
                Window.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                Window.DisplayOrder = Iris._config.DisplayOrderOffset
                Window.ScreenInsets = Iris._config.ScreenInsets
                Window.IgnoreGuiInset = Iris._config.IgnoreGuiInset
            else
                Window = Instance.new("Frame")
                Window.AnchorPoint = Vector2.new(0.5, 0.5)
                Window.Position = UDim2.fromScale(0.5, 0.5)
                Window.Size = UDim2.fromScale(1, 1)
                Window.BackgroundTransparency = 1
                Window.ZIndex = Iris._config.DisplayOrderOffset
            end
            Window.Name = "Iris_Window"

            local WindowButton = Instance.new("TextButton")
            WindowButton.Name = "WindowButton"
            WindowButton.Size = UDim2.fromOffset(0, 0)
            WindowButton.BackgroundTransparency = 1
            WindowButton.BorderSizePixel = 0
            WindowButton.Text = ""
            WindowButton.AutoButtonColor = false
            WindowButton.ClipsDescendants = false
            WindowButton.Selectable = false

            WindowButton.SelectionImageObject = Iris.SelectionImageObject
            WindowButton.SelectionGroup = true
            WindowButton.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
            WindowButton.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

            widgets.UIStroke(WindowButton, Iris._config.WindowBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)

            WindowButton.Parent = Window

            widgets.applyInputBegan(WindowButton, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Iris.SetFocusedWindow(thisWidget)
                end
                if not thisWidget.arguments.NoMove and input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragWindow = thisWidget
                    isDragging = true
                    moveDeltaCursorPosition = widgets.getMouseLocation() - thisWidget.state.position.value
                end
            end)

            local Content = Instance.new("Frame")
            Content.Name = "Content"
            Content.AnchorPoint = Vector2.new(0.5, 0.5)
            Content.Position = UDim2.fromScale(0.5, 0.5)
            Content.Size = UDim2.fromScale(1, 1)
            Content.BackgroundTransparency = 1
            Content.ClipsDescendants = true
            Content.Parent = WindowButton

            local UIListLayout = widgets.UIListLayout(Content, Enum.FillDirection.Vertical, UDim.new(0, 0))
            UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "WindowContainer"
            ChildContainer.Size = UDim2.fromScale(1, 1)
            ChildContainer.BackgroundColor3 = Iris._config.WindowBgColor
            ChildContainer.BackgroundTransparency = Iris._config.WindowBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Iris._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Iris._config.ScrollbarGrabColor
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            ChildContainer.LayoutOrder = thisWidget.ZIndex + 0xFFFF
            ChildContainer.ClipsDescendants = true

            widgets.UIPadding(ChildContainer, Iris._config.WindowPadding)

            ChildContainer.Parent = Content

            local UIFlexItem = Instance.new("UIFlexItem")
            UIFlexItem.FlexMode = Enum.UIFlexMode.Fill
            UIFlexItem.ItemLineAlignment = Enum.ItemLineAlignment.End
            UIFlexItem.Parent = ChildContainer

            ChildContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                -- "wrong" use of state here, for optimization
                thisWidget.state.scrollDistance.value = ChildContainer.CanvasPosition.Y
            end)

            widgets.applyInputBegan(ChildContainer, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Iris.SetFocusedWindow(thisWidget)
                end
            end)

            local TerminatingFrame = Instance.new("Frame")
            TerminatingFrame.Name = "TerminatingFrame"
            TerminatingFrame.Size = UDim2.fromOffset(0, Iris._config.WindowPadding.Y + Iris._config.FramePadding.Y)
            TerminatingFrame.BackgroundTransparency = 1
            TerminatingFrame.BorderSizePixel = 0
            TerminatingFrame.LayoutOrder = 0x7FFFFFF0

            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y)).VerticalAlignment = Enum.VerticalAlignment.Top

            TerminatingFrame.Parent = ChildContainer

            local TitleBar = Instance.new("Frame")
            TitleBar.Name = "TitleBar"
            TitleBar.AutomaticSize = Enum.AutomaticSize.Y
            TitleBar.Size = UDim2.fromScale(1, 0)
            TitleBar.BorderSizePixel = 0
            TitleBar.ClipsDescendants = true

            TitleBar.Parent = Content

            widgets.UIPadding(TitleBar, Vector2.new(Iris._config.FramePadding.X))
            widgets.UIListLayout(TitleBar, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyInputBegan(TitleBar, function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    if not thisWidget.arguments.NoMove then
                        dragWindow = thisWidget
                        isDragging = true
                        local location = input.Position
                        moveDeltaCursorPosition = Vector2.new(location.X, location.Y) - thisWidget.state.position.value
                    end
                end
            end)

            local TitleButtonSize = Iris._config.TextSize + ((Iris._config.FramePadding.Y - 1) * 2)

            local CollapseButton = Instance.new("TextButton")
            CollapseButton.Name = "CollapseButton"
            CollapseButton.AutomaticSize = Enum.AutomaticSize.None
            CollapseButton.AnchorPoint = Vector2.new(0, 0.5)
            CollapseButton.Size = UDim2.fromOffset(TitleButtonSize, TitleButtonSize)
            CollapseButton.Position = UDim2.fromScale(0, 0.5)
            CollapseButton.BackgroundTransparency = 1
            CollapseButton.BorderSizePixel = 0
            CollapseButton.AutoButtonColor = false
            CollapseButton.Text = ""

            widgets.UICorner(CollapseButton)

            CollapseButton.Parent = TitleBar

            widgets.applyButtonClick(CollapseButton, function()
                thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
            end)

            widgets.applyInteractionHighlights("Background", CollapseButton, CollapseButton, {
                Color = Iris._config.ButtonColor,
                Transparency = 1,
                HoveredColor = Iris._config.ButtonHoveredColor,
                HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                ActiveColor = Iris._config.ButtonActiveColor,
                ActiveTransparency = Iris._config.ButtonActiveTransparency,
            })

            local CollapseArrow = Instance.new("ImageLabel")
            CollapseArrow.Name = "Arrow"
            CollapseArrow.AnchorPoint = Vector2.new(0.5, 0.5)
            CollapseArrow.Size = UDim2.fromOffset(math.floor(0.7 * TitleButtonSize), math.floor(0.7 * TitleButtonSize))
            CollapseArrow.Position = UDim2.fromScale(0.5, 0.5)
            CollapseArrow.BackgroundTransparency = 1
            CollapseArrow.BorderSizePixel = 0
            CollapseArrow.Image = widgets.ICONS.MULTIPLICATION_SIGN
            CollapseArrow.ImageColor3 = Iris._config.TextColor
            CollapseArrow.ImageTransparency = Iris._config.TextTransparency
            CollapseArrow.Parent = CollapseButton

            local CloseButton = Instance.new("TextButton")
            CloseButton.Name = "CloseButton"
            CloseButton.AutomaticSize = Enum.AutomaticSize.None
            CloseButton.AnchorPoint = Vector2.new(1, 0.5)
            CloseButton.Size = UDim2.fromOffset(TitleButtonSize, TitleButtonSize)
            CloseButton.Position = UDim2.fromScale(1, 0.5)
            CloseButton.BackgroundTransparency = 1
            CloseButton.BorderSizePixel = 0
            CloseButton.Text = ""
            CloseButton.AutoButtonColor = false
            CloseButton.LayoutOrder = 2

            widgets.UICorner(CloseButton)

            widgets.applyButtonClick(CloseButton, function()
                thisWidget.state.isOpened:set(false)
            end)

            widgets.applyInteractionHighlights("Background", CloseButton, CloseButton, {
                Color = Iris._config.ButtonColor,
                Transparency = 1,
                HoveredColor = Iris._config.ButtonHoveredColor,
                HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                ActiveColor = Iris._config.ButtonActiveColor,
                ActiveTransparency = Iris._config.ButtonActiveTransparency,
            })

            CloseButton.Parent = TitleBar

            local CloseIcon = Instance.new("ImageLabel")
            CloseIcon.Name = "Icon"
            CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            CloseIcon.Size = UDim2.fromOffset(math.floor(0.7 * TitleButtonSize), math.floor(0.7 * TitleButtonSize))
            CloseIcon.Position = UDim2.fromScale(0.5, 0.5)
            CloseIcon.BackgroundTransparency = 1
            CloseIcon.BorderSizePixel = 0
            CloseIcon.Image = widgets.ICONS.MULTIPLICATION_SIGN
            CloseIcon.ImageColor3 = Iris._config.TextColor
            CloseIcon.ImageTransparency = Iris._config.TextTransparency
            CloseIcon.Parent = CloseButton

            -- allowing fractional titlebar title location dosent seem useful, as opposed to Enum.LeftRight.

            local Title = Instance.new("TextLabel")
            Title.Name = "Title"
            Title.AutomaticSize = Enum.AutomaticSize.XY
            Title.BorderSizePixel = 0
            Title.BackgroundTransparency = 1
            Title.LayoutOrder = 1
            Title.ClipsDescendants = true

            widgets.UIPadding(Title, Vector2.new(0, Iris._config.FramePadding.Y))
            widgets.applyTextStyle(Title)
            Title.TextXAlignment = Enum.TextXAlignment[Iris._config.WindowTitleAlign.Name]

            local TitleFlexItem = Instance.new("UIFlexItem")
            TitleFlexItem.FlexMode = Enum.UIFlexMode.Fill
            TitleFlexItem.ItemLineAlignment = Enum.ItemLineAlignment.Center

            TitleFlexItem.Parent = Title

            Title.Parent = TitleBar

            local ResizeButtonSize = Iris._config.TextSize + Iris._config.FramePadding.X

            local LeftResizeGrip = Instance.new("ImageButton")
            LeftResizeGrip.Name = "LeftResizeGrip"
            LeftResizeGrip.AnchorPoint = Vector2.yAxis
            LeftResizeGrip.Rotation = 180
            LeftResizeGrip.Position = UDim2.fromScale(0, 1)
            LeftResizeGrip.Size = UDim2.fromOffset(ResizeButtonSize, ResizeButtonSize)
            LeftResizeGrip.BackgroundTransparency = 1
            LeftResizeGrip.BorderSizePixel = 0
            LeftResizeGrip.Image = widgets.ICONS.BOTTOM_RIGHT_CORNER
            LeftResizeGrip.ImageColor3 = Iris._config.ResizeGripColor
            LeftResizeGrip.ImageTransparency = 1
            LeftResizeGrip.AutoButtonColor = false
            LeftResizeGrip.ZIndex = 3
            LeftResizeGrip.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", LeftResizeGrip, LeftResizeGrip, {
                Color = Iris._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            widgets.applyButtonDown(LeftResizeGrip, function()
                if not anyFocusedWindow or not (focusedWindow == thisWidget) then
                    Iris.SetFocusedWindow(thisWidget)
                    -- mitigating wrong focus when clicking on buttons inside of a window without clicking the window itself
                end
                isResizing = true
                resizeFromTopBottom = Enum.TopBottom.Bottom
                resizeFromLeftRight = Enum.LeftRight.Left
                resizeWindow = thisWidget
            end)

            -- each border uses an image, allowing it to have a visible borde which is larger than the UI
            local RightResizeGrip = Instance.new("ImageButton")
            RightResizeGrip.Name = "RightResizeGrip"
            RightResizeGrip.AnchorPoint = Vector2.one
            RightResizeGrip.Rotation = 90
            RightResizeGrip.Position = UDim2.fromScale(1, 1)
            RightResizeGrip.Size = UDim2.fromOffset(ResizeButtonSize, ResizeButtonSize)
            RightResizeGrip.BackgroundTransparency = 1
            RightResizeGrip.BorderSizePixel = 0
            RightResizeGrip.Image = widgets.ICONS.BOTTOM_RIGHT_CORNER
            RightResizeGrip.ImageColor3 = Iris._config.ResizeGripColor
            RightResizeGrip.ImageTransparency = Iris._config.ResizeGripTransparency
            RightResizeGrip.AutoButtonColor = false
            RightResizeGrip.ZIndex = 3
            RightResizeGrip.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", RightResizeGrip, RightResizeGrip, {
                Color = Iris._config.ResizeGripColor,
                Transparency = Iris._config.ResizeGripTransparency,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            widgets.applyButtonDown(RightResizeGrip, function()
                if not anyFocusedWindow or not (focusedWindow == thisWidget) then
                    Iris.SetFocusedWindow(thisWidget)
                    -- mitigating wrong focus when clicking on buttons inside of a window without clicking the window itself
                end
                isResizing = true
                resizeFromTopBottom = Enum.TopBottom.Bottom
                resizeFromLeftRight = Enum.LeftRight.Right
                resizeWindow = thisWidget
            end)

            local LeftResizeBorder = Instance.new("ImageButton")
            LeftResizeBorder.Name = "LeftResizeBorder"
            LeftResizeBorder.AnchorPoint = Vector2.new(1, .5)
            LeftResizeBorder.Position = UDim2.fromScale(0, .5)
            LeftResizeBorder.Size = UDim2.new(0, Iris._config.WindowResizePadding.X, 1, 2 * Iris._config.WindowBorderSize)
            LeftResizeBorder.Transparency = 1
            LeftResizeBorder.Image = widgets.ICONS.BORDER
            LeftResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            LeftResizeBorder.ScaleType = Enum.ScaleType.Slice
            LeftResizeBorder.SliceCenter = Rect.new(0, 0, 1, 1)
            LeftResizeBorder.ImageRectOffset = Vector2.new(2, 2)
            LeftResizeBorder.ImageRectSize = Vector2.new(2, 1)
            LeftResizeBorder.ImageTransparency = 1
            LeftResizeBorder.AutoButtonColor = false
            LeftResizeBorder.ZIndex = 4

            LeftResizeBorder.Parent = WindowButton

            local RightResizeBorder = Instance.new("ImageButton")
            RightResizeBorder.Name = "RightResizeBorder"
            RightResizeBorder.AnchorPoint = Vector2.new(0, .5)
            RightResizeBorder.Position = UDim2.fromScale(1, .5)
            RightResizeBorder.Size = UDim2.new(0, Iris._config.WindowResizePadding.X, 1, 2 * Iris._config.WindowBorderSize)
            RightResizeBorder.Transparency = 1
            RightResizeBorder.Image = widgets.ICONS.BORDER
            RightResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            RightResizeBorder.ScaleType = Enum.ScaleType.Slice
            RightResizeBorder.SliceCenter = Rect.new(1, 0, 2, 1)
            RightResizeBorder.ImageRectOffset = Vector2.new(1, 2)
            RightResizeBorder.ImageRectSize = Vector2.new(2, 1)
            RightResizeBorder.ImageTransparency = 1
            RightResizeBorder.AutoButtonColor = false
            RightResizeBorder.ZIndex = 4

            RightResizeBorder.Parent = WindowButton

            local TopResizeBorder = Instance.new("ImageButton")
            TopResizeBorder.Name = "TopResizeBorder"
            TopResizeBorder.AnchorPoint = Vector2.new(.5, 1)
            TopResizeBorder.Position = UDim2.fromScale(.5, 0)
            TopResizeBorder.Size = UDim2.new(1, 2 * Iris._config.WindowBorderSize, 0, Iris._config.WindowResizePadding.Y)
            TopResizeBorder.Transparency = 1
            TopResizeBorder.Image = widgets.ICONS.BORDER
            TopResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            TopResizeBorder.ScaleType = Enum.ScaleType.Slice
            TopResizeBorder.SliceCenter = Rect.new(0, 0, 1, 1)
            TopResizeBorder.ImageRectOffset = Vector2.new(2, 2)
            TopResizeBorder.ImageRectSize = Vector2.new(1, 2)
            TopResizeBorder.ImageTransparency = 1
            TopResizeBorder.AutoButtonColor = false
            TopResizeBorder.ZIndex = 4

            TopResizeBorder.Parent = WindowButton

            local BottomResizeBorder = Instance.new("ImageButton")
            BottomResizeBorder.Name = "BottomResizeBorder"
            BottomResizeBorder.AnchorPoint = Vector2.new(.5, 0)
            BottomResizeBorder.Position = UDim2.fromScale(.5, 1)
            BottomResizeBorder.Size = UDim2.new(1, 2 * Iris._config.WindowBorderSize, 0, Iris._config.WindowResizePadding.Y)
            BottomResizeBorder.Transparency = 1
            BottomResizeBorder.Image = widgets.ICONS.BORDER
            BottomResizeBorder.ResampleMode = Enum.ResamplerMode.Pixelated
            BottomResizeBorder.ScaleType = Enum.ScaleType.Slice
            BottomResizeBorder.SliceCenter = Rect.new(0, 1, 1, 2)
            BottomResizeBorder.ImageRectOffset = Vector2.new(2, 1)
            BottomResizeBorder.ImageRectSize = Vector2.new(1, 2)
            BottomResizeBorder.ImageTransparency = 1
            BottomResizeBorder.AutoButtonColor = false
            BottomResizeBorder.ZIndex = 4

            BottomResizeBorder.Parent = WindowButton

            widgets.applyInteractionHighlights("Image", LeftResizeBorder, LeftResizeBorder, {
                Color = Iris._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", RightResizeBorder, RightResizeBorder, {
                Color = Iris._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", TopResizeBorder, TopResizeBorder, {
                Color = Iris._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            widgets.applyInteractionHighlights("Image", BottomResizeBorder, BottomResizeBorder, {
                Color = Iris._config.ResizeGripColor,
                Transparency = 1,
                HoveredColor = Iris._config.ResizeGripHoveredColor,
                HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
                ActiveColor = Iris._config.ResizeGripActiveColor,
                ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
            })

            local ResizeBorder = Instance.new("Frame")
            ResizeBorder.Name = "ResizeBorder"
            ResizeBorder.Position = UDim2.fromOffset(-Iris._config.WindowResizePadding.X, -Iris._config.WindowResizePadding.Y)
            ResizeBorder.Size = UDim2.new(1, Iris._config.WindowResizePadding.X * 2, 1, Iris._config.WindowResizePadding.Y * 2)
            ResizeBorder.BackgroundTransparency = 1
            ResizeBorder.BorderSizePixel = 0
            ResizeBorder.Active = false
            ResizeBorder.Selectable = false
            ResizeBorder.ClipsDescendants = false
            ResizeBorder.Parent = WindowButton

            widgets.applyMouseEnter(ResizeBorder, function()
                if focusedWindow == thisWidget then
                    isInsideResize = true
                end
            end)
            widgets.applyMouseLeave(ResizeBorder, function()
                if focusedWindow == thisWidget then
                    isInsideResize = false
                end
            end)
            widgets.applyInputBegan(ResizeBorder, function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end
                if thisWidget.state.isUncollapsed.value then
                    Iris.SetFocusedWindow(thisWidget)
                end
            end)

            widgets.applyMouseEnter(WindowButton, function()
                if focusedWindow == thisWidget then
                    isInsideWindow = true
                end
            end)
            widgets.applyMouseLeave(WindowButton, function()
                if focusedWindow == thisWidget then
                    isInsideWindow = false
                end
            end)

            thisWidget.ChildContainer = ChildContainer
            return Window
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.size == nil then
                thisWidget.state.size = Iris._widgetState(thisWidget, "size", Vector2.new(400, 300))
            end
            if thisWidget.state.position == nil then
                thisWidget.state.position = Iris._widgetState(thisWidget, "position", (anyFocusedWindow and focusedWindow and focusedWindow.state.position.value + Vector2.new(15, 45) or Vector2.new(150, 250)))
            end
            thisWidget.state.position.value = fitPositionToWindowBounds(thisWidget, thisWidget.state.position.value)
            thisWidget.state.size.value = fitSizeToWindowBounds(thisWidget, thisWidget.state.size.value)

            if thisWidget.state.isUncollapsed == nil then
                thisWidget.state.isUncollapsed = Iris._widgetState(thisWidget, "isUncollapsed", true)
            end
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Iris._widgetState(thisWidget, "isOpened", true)
            end
            if thisWidget.state.scrollDistance == nil then
                thisWidget.state.scrollDistance = Iris._widgetState(thisWidget, "scrollDistance", 0)
            end
        end,
        Update = function(thisWidget)
            local Window = thisWidget.Instance
            local ChildContainer = thisWidget.ChildContainer
            local WindowButton = Window.WindowButton
            local Content = WindowButton.Content
            local TitleBar = Content.TitleBar
            local Title = TitleBar.Title
            local MenuBar = Content:FindFirstChild("Iris_MenuBar")
            local LeftResizeGrip = WindowButton.LeftResizeGrip
            local RightResizeGrip = WindowButton.RightResizeGrip
            local LeftResizeBorder = WindowButton.LeftResizeBorder
            local RightResizeBorder = WindowButton.RightResizeBorder
            local TopResizeBorder = WindowButton.TopResizeBorder
            local BottomResizeBorder = WindowButton.BottomResizeBorder

            if thisWidget.arguments.NoResize ~= true then
                LeftResizeGrip.Visible = true
                RightResizeGrip.Visible = true
                LeftResizeBorder.Visible = true
                RightResizeBorder.Visible = true
                TopResizeBorder.Visible = true
                BottomResizeBorder.Visible = true
            else
                LeftResizeGrip.Visible = false
                RightResizeGrip.Visible = false
                LeftResizeBorder.Visible = false
                RightResizeBorder.Visible = false
                TopResizeBorder.Visible = false
                BottomResizeBorder.Visible = false
            end
            if thisWidget.arguments.NoScrollbar then
                ChildContainer.ScrollBarThickness = 0
            else
                ChildContainer.ScrollBarThickness = Iris._config.ScrollbarSize
            end
            if thisWidget.arguments.NoTitleBar then
                TitleBar.Visible = false
            else
                TitleBar.Visible = true
            end
            if MenuBar then
                if thisWidget.arguments.NoMenu then
                    MenuBar.Visible = false
                else
                    MenuBar.Visible = true
                end
            end
            if thisWidget.arguments.NoBackground then
                ChildContainer.BackgroundTransparency = 1
            else
                ChildContainer.BackgroundTransparency = Iris._config.WindowBgTransparency
            end

            -- TitleBar buttons
            if thisWidget.arguments.NoCollapse then
                TitleBar.CollapseButton.Visible = false
            else
                TitleBar.CollapseButton.Visible = true
            end
            if thisWidget.arguments.NoClose then
                TitleBar.CloseButton.Visible = false
            else
                TitleBar.CloseButton.Visible = true
            end

            Title.Text = thisWidget.arguments.Title or ""
        end,
        UpdateState = function(thisWidget)
            local stateSize = thisWidget.state.size.value
            local statePosition = thisWidget.state.position.value
            local stateIsUncollapsed = thisWidget.state.isUncollapsed.value
            local stateIsOpened = thisWidget.state.isOpened.value
            local stateScrollDistance = thisWidget.state.scrollDistance.value

            local Window = thisWidget.Instance
            local ChildContainer = thisWidget.ChildContainer
            local WindowButton = Window.WindowButton
            local Content = WindowButton.Content
            local TitleBar = Content.TitleBar
            local MenuBar = Content:FindFirstChild("Iris_MenuBar")
            local LeftResizeGrip = WindowButton.LeftResizeGrip
            local RightResizeGrip = WindowButton.RightResizeGrip
            local LeftResizeBorder = WindowButton.LeftResizeBorder
            local RightResizeBorder = WindowButton.RightResizeBorder
            local TopResizeBorder = WindowButton.TopResizeBorder
            local BottomResizeBorder = WindowButton.BottomResizeBorder

            WindowButton.Size = UDim2.fromOffset(stateSize.X, stateSize.Y)
            WindowButton.Position = UDim2.fromOffset(statePosition.X, statePosition.Y)

            if stateIsOpened then
                if thisWidget.usesScreenGuis then
                    Window.Enabled = true
                    WindowButton.Visible = true
                else
                    Window.Visible = true
                    WindowButton.Visible = true
                end
                thisWidget.lastOpenedTick = Iris._cycleTick + 1
            else
                if thisWidget.usesScreenGuis then
                    Window.Enabled = false
                    WindowButton.Visible = false
                else
                    Window.Visible = false
                    WindowButton.Visible = false
                end
                thisWidget.lastClosedTick = Iris._cycleTick + 1
            end

            if stateIsUncollapsed then
                TitleBar.CollapseButton.Arrow.Image = widgets.ICONS.DOWN_POINTING_TRIANGLE
                if MenuBar then
                    MenuBar.Visible = not thisWidget.arguments.NoMenu
                end
                ChildContainer.Visible = true
                if thisWidget.arguments.NoResize ~= true then
                    LeftResizeGrip.Visible = true
                    RightResizeGrip.Visible = true
                    LeftResizeBorder.Visible = true
                    RightResizeBorder.Visible = true
                    TopResizeBorder.Visible = true
                    BottomResizeBorder.Visible = true
                end
                WindowButton.AutomaticSize = Enum.AutomaticSize.None
                thisWidget.lastUncollapsedTick = Iris._cycleTick + 1
            else
                local collapsedHeight = TitleBar.AbsoluteSize.Y -- Iris._config.TextSize + Iris._config.FramePadding.Y * 2
                TitleBar.CollapseButton.Arrow.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE

                if MenuBar then
                    MenuBar.Visible = false
                end
                ChildContainer.Visible = false
                LeftResizeGrip.Visible = false
                RightResizeGrip.Visible = false
                LeftResizeBorder.Visible = false
                RightResizeBorder.Visible = false
                TopResizeBorder.Visible = false
                BottomResizeBorder.Visible = false
                WindowButton.Size = UDim2.fromOffset(stateSize.X, collapsedHeight)
                thisWidget.lastCollapsedTick = Iris._cycleTick + 1
            end

            if stateIsOpened and stateIsUncollapsed then
                Iris.SetFocusedWindow(thisWidget)
            else
                TitleBar.BackgroundColor3 = Iris._config.TitleBgCollapsedColor
                TitleBar.BackgroundTransparency = Iris._config.TitleBgCollapsedTransparency
                WindowButton.UIStroke.Color = Iris._config.BorderColor

                Iris.SetFocusedWindow(nil)
            end

            -- cant update canvasPosition in this cycle because scrollingframe isint ready to be changed
            if stateScrollDistance and stateScrollDistance ~= 0 then
                local callbackIndex = #Iris._postCycleCallbacks + 1
                local desiredCycleTick = Iris._cycleTick + 1
                Iris._postCycleCallbacks[callbackIndex] = function()
                    if Iris._cycleTick >= desiredCycleTick then
                        if thisWidget.lastCycleTick ~= -1 then
                            ChildContainer.CanvasPosition = Vector2.new(0, stateScrollDistance)
                        end
                        Iris._postCycleCallbacks[callbackIndex] = nil
                    end
                end
            end
        end,
        ChildAdded = function(thisWidget, thisChid)
            local Window = thisWidget.Instance
            local WindowButton = Window.WindowButton
            local Content = WindowButton.Content
            if thisChid.type == "MenuBar" then
                local ChildContainer = thisWidget.ChildContainer
                thisChid.Instance.ZIndex = ChildContainer.ZIndex + 1
                thisChid.Instance.LayoutOrder = ChildContainer.LayoutOrder - 1
                return Content
            end
            return thisWidget.ChildContainer
        end,
        Discard = function(thisWidget)
            if focusedWindow == thisWidget then
                focusedWindow = nil
                anyFocusedWindow = false
            end
            if dragWindow == thisWidget then
                dragWindow = nil
                isDragging = false
            end
            if resizeWindow == thisWidget then
                resizeWindow = nil
                isResizing = false
            end
            windowWidgets[thisWidget.ID] = nil
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })
end

end
-- ===== module: widgets.Menu =====
__modules["widgets.Menu"] = function()

return function(Iris, widgets)
    local AnyMenuOpen = false
    local ActiveMenu = nil
    local MenuStack = {}

    local function EmptyMenuStack(menuIndex)
        for index = #MenuStack, menuIndex and menuIndex + 1 or 1, -1 do
            local widget = MenuStack[index]
            widget.state.isOpened:set(false)

            widget.Instance.BackgroundColor3 = Iris._config.HeaderColor
            widget.Instance.BackgroundTransparency = 1

            table.remove(MenuStack, index)
        end

        if #MenuStack == 0 then
            AnyMenuOpen = false
            ActiveMenu = nil
        end
    end

    local function UpdateChildContainerTransform(thisWidget)
        local submenu = thisWidget.parentWidget.type == "Menu"

        local Menu = thisWidget.Instance
        local ChildContainer = thisWidget.ChildContainer
        ChildContainer.Size = UDim2.fromOffset(Menu.AbsoluteSize.X, 0)
        if ChildContainer.Parent == nil then
            return
        end

        local menuPosition = Menu.AbsolutePosition - widgets.GuiOffset
        local menuSize = Menu.AbsoluteSize
        local containerSize = ChildContainer.AbsoluteSize
        local borderSize = Iris._config.PopupBorderSize
        local screenSize = ChildContainer.Parent.AbsoluteSize

        local x = menuPosition.X
        local y
        local anchor = Vector2.zero

        if submenu then
            if menuPosition.X + containerSize.X > screenSize.X then
                anchor = Vector2.xAxis
            else
                x = menuPosition.X + menuSize.X
            end
        end

        if menuPosition.Y + containerSize.Y > screenSize.Y then
            -- too low.
            y = menuPosition.Y - borderSize + (submenu and menuSize.Y or 0)
            anchor = anchor + Vector2.yAxis
        else
            y = menuPosition.Y + borderSize + (submenu and 0 or menuSize.Y)
        end

        ChildContainer.Position = UDim2.fromOffset(x, y)
        ChildContainer.AnchorPoint = anchor
    end

    widgets.registerEvent("InputBegan", function(inputObject)
        if not Iris._started then
            return
        end
        if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.MouseButton2 then
            return
        end
        if AnyMenuOpen == false then
            return
        end
        if ActiveMenu == nil then
            return
        end

        -- this only checks if we clicked outside all the menus. If we clicked in any menu, then the hover function handles this.
        local isInMenu = false
        local MouseLocation = widgets.getMouseLocation()
        for _, menu in pairs(MenuStack) do
            for _, container in pairs({ menu.ChildContainer, menu.Instance }) do
                local rectMin = container.AbsolutePosition - widgets.GuiOffset
                local rectMax = rectMin + container.AbsoluteSize
                if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
                    isInMenu = true
                    break
                end
            end
            if isInMenu then
                break
            end
        end

        if not isInMenu then
            EmptyMenuStack()
        end
    end)

    Iris.WidgetConstructor("MenuBar", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget)
            local MenuBar = Instance.new("Frame")
            MenuBar.Name = "Iris_MenuBar"
            MenuBar.AutomaticSize = Enum.AutomaticSize.Y
            MenuBar.Size = UDim2.fromScale(1, 0)
            MenuBar.BackgroundColor3 = Iris._config.MenubarBgColor
            MenuBar.BackgroundTransparency = Iris._config.MenubarBgTransparency
            MenuBar.BorderSizePixel = 0
            MenuBar.ClipsDescendants = true

            widgets.UIPadding(MenuBar, Vector2.new(Iris._config.WindowPadding.X, 1))
            widgets.UIListLayout(MenuBar, Enum.FillDirection.Horizontal, UDim.new()).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyFrameStyle(MenuBar, true, true)

            return MenuBar
        end,
        Update = function(_thisWidget)

        end,
        ChildAdded = function(thisWidget, _thisChild)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("Menu", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
            ["opened"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastOpenedTick == Iris._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastClosedTick == Iris._cycleTick
                end,
            },
        },
        Generate = function(thisWidget)

            thisWidget.ButtonColors = {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderHoveredColor,
                ActiveTransparency = Iris._config.HeaderHoveredTransparency,
            }
            if thisWidget.parentWidget.type == "Menu" then
                -- this Menu is a sub-Menu
                Menu = Instance.new("TextButton")
                Menu.Name = "Menu"
                Menu.AutomaticSize = Enum.AutomaticSize.Y
                Menu.Size = UDim2.fromScale(1, 0)
                Menu.BackgroundColor3 = Iris._config.HeaderColor
                Menu.BackgroundTransparency = 1
                Menu.BorderSizePixel = 0
                Menu.Text = ""
                Menu.AutoButtonColor = false

                local UIPadding = widgets.UIPadding(Menu, Iris._config.FramePadding)
                UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
                widgets.UIListLayout(Menu, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Menu

                local frameSize = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y
                local padding = math.round(0.2 * frameSize)
                local iconSize = frameSize - 2 * padding

                local Icon = Instance.new("ImageLabel")
                Icon.Name = "Icon"
                Icon.Size = UDim2.fromOffset(iconSize, iconSize)
                Icon.BackgroundTransparency = 1
                Icon.BorderSizePixel = 0
                Icon.ImageColor3 = Iris._config.TextColor
                Icon.ImageTransparency = Iris._config.TextTransparency
                Icon.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE
                Icon.LayoutOrder = 1

                Icon.Parent = Menu
            else
                Menu = Instance.new("TextButton")
                Menu.Name = "Menu"
                Menu.AutomaticSize = Enum.AutomaticSize.XY
                Menu.Size = UDim2.fromScale(0, 0)
                Menu.BackgroundColor3 = Iris._config.HeaderColor
                Menu.BackgroundTransparency = 1
                Menu.BorderSizePixel = 0
                Menu.Text = ""
                Menu.AutoButtonColor = false
                Menu.ClipsDescendants = true

                widgets.applyTextStyle(Menu)
                widgets.UIPadding(Menu, Vector2.new(Iris._config.ItemSpacing.X, Iris._config.FramePadding.Y))
            end
            widgets.applyInteractionHighlights("Background", Menu, Menu, thisWidget.ButtonColors)

            widgets.applyButtonClick(Menu, function()
                local openMenu = (#MenuStack <= 1 and not thisWidget.state.isOpened.value or true)
                thisWidget.state.isOpened:set(openMenu)

                AnyMenuOpen = openMenu
                ActiveMenu = openMenu and thisWidget or nil
                -- the hovering should handle all of the menus after the first one.
                if #MenuStack <= 1 then
                    if openMenu then
                        table.insert(MenuStack, thisWidget)
                    else
                        table.remove(MenuStack)
                    end
                end
            end)

            widgets.applyMouseEnter(Menu, function()
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= thisWidget then
                    local parentMenu = thisWidget.parentWidget
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    thisWidget.state.isOpened:set(true)
                    ActiveMenu = thisWidget
                    AnyMenuOpen = true
                    table.insert(MenuStack, thisWidget)
                end
            end)

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "MenuContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.XY
            ChildContainer.Size = UDim2.fromOffset(0, 0)
            ChildContainer.BackgroundColor3 = Iris._config.PopupBgColor
            ChildContainer.BackgroundTransparency = Iris._config.PopupBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Iris._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Iris._config.ScrollbarGrabColor
            ChildContainer.ScrollBarThickness = Iris._config.ScrollbarSize
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            ChildContainer.ZIndex = 6
            ChildContainer.LayoutOrder = 6
            ChildContainer.ClipsDescendants = true

            -- Unfortunatley, ScrollingFrame does not work with UICorner

            widgets.UIStroke(ChildContainer, Iris._config.WindowBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)
            widgets.UIPadding(ChildContainer, Vector2.new(2, Iris._config.WindowPadding.Y - Iris._config.ItemSpacing.Y))

            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, 1)).VerticalAlignment = Enum.VerticalAlignment.Top

            local RootPopupScreenGui = Iris._rootInstance and Iris._rootInstance:FindFirstChild("PopupScreenGui")
            ChildContainer.Parent = RootPopupScreenGui

            thisWidget.ChildContainer = ChildContainer
            return Menu
        end,
        Update = function(thisWidget)
            local Menu = thisWidget.Instance

            if thisWidget.parentWidget.type == "Menu" then
                TextLabel = Menu.TextLabel
            else
                TextLabel = Menu
            end
            TextLabel.Text = thisWidget.arguments.Text or "Menu"
        end,
        ChildAdded = function(thisWidget, _thisChild)
            UpdateChildContainerTransform(thisWidget)
            return thisWidget.ChildContainer
        end,
        ChildDiscarded = function(thisWidget, _thisChild)
            UpdateChildContainerTransform(thisWidget)
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Iris._widgetState(thisWidget, "isOpened", false)
            end
        end,
        UpdateState = function(thisWidget)
            local ChildContainer = thisWidget.ChildContainer

            if thisWidget.state.isOpened.value then
                thisWidget.lastOpenedTick = Iris._cycleTick + 1
                thisWidget.ButtonColors.Transparency = Iris._config.HeaderTransparency
                ChildContainer.Visible = true

                UpdateChildContainerTransform(thisWidget)
            else
                thisWidget.lastClosedTick = Iris._cycleTick + 1
                thisWidget.ButtonColors.Transparency = 1
                ChildContainer.Visible = false
            end
        end,
        Discard = function(thisWidget)
            -- properly handle removing a menu if open and deleted
            if AnyMenuOpen then
                local parentMenu = thisWidget.parentWidget
                local parentIndex = table.find(MenuStack, parentMenu)
                if parentIndex then
                    EmptyMenuStack(parentIndex)
                    if #MenuStack ~= 0 then
                        ActiveMenu = parentMenu
                        AnyMenuOpen = true
                    end
                end
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end,
    })

    Iris.WidgetConstructor("MenuItem", {
        hasState = false,
        hasChildren = false,
        Args = {
            Text = 1,
            KeyCode = 2,
            ModifierKey = 3,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local MenuItem = Instance.new("TextButton")
            MenuItem.Name = "Iris_MenuItem"
            MenuItem.AutomaticSize = Enum.AutomaticSize.Y
            MenuItem.Size = UDim2.fromScale(1, 0)
            MenuItem.BackgroundTransparency = 1
            MenuItem.BorderSizePixel = 0
            MenuItem.Text = ""
            MenuItem.AutoButtonColor = false

            local UIPadding = widgets.UIPadding(MenuItem, Iris._config.FramePadding)
            UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
            widgets.UIListLayout(MenuItem, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X))

            widgets.applyInteractionHighlights("Background", MenuItem, MenuItem, {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderHoveredColor,
                ActiveTransparency = Iris._config.HeaderHoveredTransparency,
            })

            widgets.applyButtonClick(MenuItem, function()
                EmptyMenuStack()
            end)

            widgets.applyMouseEnter(MenuItem, function()
                local parentMenu = thisWidget.parentWidget
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= parentMenu then
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    ActiveMenu = parentMenu
                    AnyMenuOpen = true
                end
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = MenuItem

            local Shortcut = Instance.new("TextLabel")
            Shortcut.Name = "Shortcut"
            Shortcut.AutomaticSize = Enum.AutomaticSize.XY
            Shortcut.BackgroundTransparency = 1
            Shortcut.BorderSizePixel = 0
            Shortcut.LayoutOrder = 1

            widgets.applyTextStyle(Shortcut)

            Shortcut.Text = ""
            Shortcut.TextColor3 = Iris._config.TextDisabledColor
            Shortcut.TextTransparency = Iris._config.TextDisabledTransparency

            Shortcut.Parent = MenuItem

            return MenuItem
        end,
        Update = function(thisWidget)
            local MenuItem = thisWidget.Instance
            local TextLabel = MenuItem.TextLabel
            local Shortcut = MenuItem.Shortcut

            TextLabel.Text = thisWidget.arguments.Text
            if thisWidget.arguments.KeyCode then
                if thisWidget.arguments.ModifierKey then
                    Shortcut.Text = thisWidget.arguments.ModifierKey.Name .. " + " .. thisWidget.arguments.KeyCode.Name
                else
                    Shortcut.Text = thisWidget.arguments.KeyCode.Name
                end
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("MenuToggle", {
        hasState = true,
        hasChildren = false,
        Args = {
            Text = 1,
            KeyCode = 2,
            ModifierKey = 3,
        },
        Events = {
            ["checked"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastCheckedTick == Iris._cycleTick
                end,
            },
            ["unchecked"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUncheckedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local MenuToggle = Instance.new("TextButton")
            MenuToggle.Name = "Iris_MenuToggle"
            MenuToggle.AutomaticSize = Enum.AutomaticSize.Y
            MenuToggle.Size = UDim2.fromScale(1, 0)
            MenuToggle.BackgroundTransparency = 1
            MenuToggle.BorderSizePixel = 0
            MenuToggle.Text = ""
            MenuToggle.AutoButtonColor = false

            local UIPadding = widgets.UIPadding(MenuToggle, Iris._config.FramePadding)
            UIPadding.PaddingTop = UIPadding.PaddingTop - UDim.new(0, 1)
            widgets.UIListLayout(MenuToggle, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            widgets.applyInteractionHighlights("Background", MenuToggle, MenuToggle, {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderHoveredColor,
                ActiveTransparency = Iris._config.HeaderHoveredTransparency,
            })

            widgets.applyButtonClick(MenuToggle, function()
                thisWidget.state.isChecked:set(not thisWidget.state.isChecked.value)
                EmptyMenuStack()
            end)

            widgets.applyMouseEnter(MenuToggle, function()
                local parentMenu = thisWidget.parentWidget
                if AnyMenuOpen and ActiveMenu and ActiveMenu ~= parentMenu then
                    local parentIndex = table.find(MenuStack, parentMenu)

                    EmptyMenuStack(parentIndex)
                    ActiveMenu = parentMenu
                    AnyMenuOpen = true
                end
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = MenuToggle

            local Shortcut = Instance.new("TextLabel")
            Shortcut.Name = "Shortcut"
            Shortcut.AutomaticSize = Enum.AutomaticSize.XY
            Shortcut.BackgroundTransparency = 1
            Shortcut.BorderSizePixel = 0
            Shortcut.LayoutOrder = 1

            widgets.applyTextStyle(Shortcut)

            Shortcut.Text = ""
            Shortcut.TextColor3 = Iris._config.TextDisabledColor
            Shortcut.TextTransparency = Iris._config.TextDisabledTransparency

            Shortcut.Parent = MenuToggle

            local frameSize = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y
            local padding = math.round(0.2 * frameSize)
            local iconSize = frameSize - 2 * padding

            local Icon = Instance.new("ImageLabel")
            Icon.Name = "Icon"
            Icon.Size = UDim2.fromOffset(iconSize, iconSize)
            Icon.BackgroundTransparency = 1
            Icon.BorderSizePixel = 0
            Icon.ImageColor3 = Iris._config.TextColor
            Icon.ImageTransparency = Iris._config.TextTransparency
            Icon.Image = widgets.ICONS.CHECKMARK
            Icon.LayoutOrder = 2

            Icon.Parent = MenuToggle

            return MenuToggle
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.isChecked == nil then
                thisWidget.state.isChecked = Iris._widgetState(thisWidget, "isChecked", false)
            end
        end,
        Update = function(thisWidget)
            local MenuToggle = thisWidget.Instance
            local TextLabel = MenuToggle.TextLabel
            local Shortcut = MenuToggle.Shortcut

            TextLabel.Text = thisWidget.arguments.Text
            if thisWidget.arguments.KeyCode then
                if thisWidget.arguments.ModifierKey then
                    Shortcut.Text = thisWidget.arguments.ModifierKey.Name .. " + " .. thisWidget.arguments.KeyCode.Name
                else
                    Shortcut.Text = thisWidget.arguments.KeyCode.Name
                end
            end
        end,
        UpdateState = function(thisWidget)
            local MenuItem = thisWidget.Instance
            local Icon = MenuItem.Icon

            if thisWidget.state.isChecked.value then
                Icon.ImageTransparency = Iris._config.TextTransparency
                thisWidget.lastCheckedTick = Iris._cycleTick + 1
            else
                Icon.ImageTransparency = 1
                thisWidget.lastUncheckedTick = Iris._cycleTick + 1
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })
end

end
-- ===== module: widgets.Format =====
__modules["widgets.Format"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("Separator", {
        hasState = false,
        hasChildren = false,
        Args = {},
        Events = {},
        Generate = function(thisWidget)
            local Separator = Instance.new("Frame")
            Separator.Name = "Iris_Separator"
            if thisWidget.parentWidget.type == "SameLine" then
                Separator.Size = UDim2.new(0, 1, Iris._config.ItemWidth.Scale, Iris._config.ItemWidth.Offset)
            else
                Separator.Size = UDim2.new(Iris._config.ItemWidth.Scale, Iris._config.ItemWidth.Offset, 0, 1)
            end
            Separator.BackgroundColor3 = Iris._config.SeparatorColor
            Separator.BackgroundTransparency = Iris._config.SeparatorTransparency
            Separator.BorderSizePixel = 0

            widgets.UIListLayout(Separator, Enum.FillDirection.Vertical, UDim.new(0, 0))
            -- this is to prevent a bug of AutomaticLayout edge case when its parent has automaticLayout enabled

            return Separator
        end,
        Update = function(_thisWidget) end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("Indent", {
        hasState = false,
        hasChildren = true,
        Args = {
            ["Width"] = 1,
        },
        Events = {},
        Generate = function(_thisWidget)
            local Indent = Instance.new("Frame")
            Indent.Name = "Iris_Indent"
            Indent.AutomaticSize = Enum.AutomaticSize.Y
            Indent.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            Indent.BackgroundTransparency = 1
            Indent.BorderSizePixel = 0

            widgets.UIListLayout(Indent, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
            widgets.UIPadding(Indent, Vector2.zero)

            return Indent
        end,
        Update = function(thisWidget)
            local Indent = thisWidget.Instance

            Indent.UIPadding.PaddingLeft = UDim.new(0, (thisWidget.arguments.Width and thisWidget.arguments.Width or Iris._config.IndentSpacing))
        end,
        ChildAdded = function(thisWidget, _thisChild)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("SameLine", {
        hasState = false,
        hasChildren = true,
        Args = {
            ["Width"] = 1,
            ["VerticalAlignment"] = 2,
            ["HorizontalAlignment"] = 3,
        },
        Events = {},
        Generate = function(_thisWidget)
            local SameLine = Instance.new("Frame")
            SameLine.Name = "Iris_SameLine"
            SameLine.AutomaticSize = Enum.AutomaticSize.Y
            SameLine.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            SameLine.BackgroundTransparency = 1
            SameLine.BorderSizePixel = 0

            widgets.UIListLayout(SameLine, Enum.FillDirection.Horizontal, UDim.new(0, 0))

            return SameLine
        end,
        Update = function(thisWidget)
            local Sameline = thisWidget.Instance
            local UIListLayout = Sameline.UIListLayout

            UIListLayout.Padding = UDim.new(0, (thisWidget.arguments.Width and thisWidget.arguments.Width or Iris._config.ItemSpacing.X))
            if thisWidget.arguments.VerticalAlignment then
                UIListLayout.VerticalAlignment = thisWidget.arguments.VerticalAlignment
            else
                UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
            end
            if thisWidget.arguments.HorizontalAlignment then
                UIListLayout.HorizontalAlignment = thisWidget.arguments.HorizontalAlignment
            else
                UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            end
        end,
        ChildAdded = function(thisWidget, _thisChild)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("Group", {
        hasState = false,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(_thisWidget)
            local Group = Instance.new("Frame")
            Group.Name = "Iris_Group"
            Group.AutomaticSize = Enum.AutomaticSize.XY
            Group.Size = UDim2.fromOffset(0, 0)
            Group.BackgroundTransparency = 1
            Group.BorderSizePixel = 0
            Group.ClipsDescendants = false

            widgets.UIListLayout(Group, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))

            return Group
        end,
        Update = function(_thisWidget) end,
        ChildAdded = function(thisWidget, _thisChild)
            return thisWidget.Instance
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })
end

end
-- ===== module: widgets.Text =====
__modules["widgets.Text"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("Text", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Wrapped"] = 2,
            ["Color"] = 3,
            ["RichText"] = 4,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget)
            local Text = Instance.new("TextLabel")
            Text.Name = "Iris_Text"
            Text.AutomaticSize = Enum.AutomaticSize.XY
            Text.Size = UDim2.fromOffset(0, 0)
            Text.BackgroundTransparency = 1
            Text.BorderSizePixel = 0

            widgets.applyTextStyle(Text)
            widgets.UIPadding(Text, Vector2.new(0, 2))

            return Text
        end,
        Update = function(thisWidget)
            local Text = thisWidget.Instance
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Iris.Text().", 5)
            end
            if thisWidget.arguments.Wrapped ~= nil then
                Text.TextWrapped = thisWidget.arguments.Wrapped
            else
                Text.TextWrapped = Iris._config.TextWrapped
            end
            if thisWidget.arguments.Color then
                Text.TextColor3 = thisWidget.arguments.Color
            else
                Text.TextColor3 = Iris._config.TextColor
            end
            if thisWidget.arguments.RichText ~= nil then
                Text.RichText = thisWidget.arguments.RichText
            else
                Text.RichText = Iris._config.RichText
            end

            Text.Text = thisWidget.arguments.Text
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("SeparatorText", {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget)
            local SeparatorText = Instance.new("Frame")
            SeparatorText.Name = "Iris_SeparatorText"
            SeparatorText.AutomaticSize = Enum.AutomaticSize.Y
            SeparatorText.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            SeparatorText.BackgroundTransparency = 1
            SeparatorText.BorderSizePixel = 0
            SeparatorText.ClipsDescendants = true

            widgets.UIPadding(SeparatorText, Vector2.new(0, Iris._config.SeparatorTextPadding.Y))
            widgets.UIListLayout(SeparatorText, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemSpacing.X))

            SeparatorText.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = SeparatorText

            local Left = Instance.new("Frame")
            Left.Name = "Left"
            Left.AnchorPoint = Vector2.new(1, 0.5)
            Left.Size = UDim2.fromOffset(Iris._config.SeparatorTextPadding.X - Iris._config.ItemSpacing.X, Iris._config.SeparatorTextBorderSize)
            Left.BackgroundColor3 = Iris._config.SeparatorColor
            Left.BackgroundTransparency = Iris._config.SeparatorTransparency
            Left.BorderSizePixel = 0

            Left.Parent = SeparatorText

            local Right = Instance.new("Frame")
            Right.Name = "Right"
            Right.AnchorPoint = Vector2.new(1, 0.5)
            Right.Size = UDim2.new(1, 0, 0, Iris._config.SeparatorTextBorderSize)
            Right.BackgroundColor3 = Iris._config.SeparatorColor
            Right.BackgroundTransparency = Iris._config.SeparatorTransparency
            Right.BorderSizePixel = 0
            Right.LayoutOrder = 2

            Right.Parent = SeparatorText

            return SeparatorText
        end,
        Update = function(thisWidget)
            local SeparatorText = thisWidget.Instance
            local TextLabel = SeparatorText.TextLabel
            if thisWidget.arguments.Text == nil then
                error("Text argument is required for Iris.SeparatorText().", 5)
            end
            TextLabel.Text = thisWidget.arguments.Text
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })
end

end
-- ===== module: widgets.Button =====
__modules["widgets.Button"] = function()

return function(Iris, widgets)
    local abstractButton = {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Size"] = 2,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                return thisWidget.Instance
            end),
            ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget)
                return thisWidget.Instance
            end),
            ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget)
                return thisWidget.Instance
            end),
            ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(_thisWidget)
            local Button = Instance.new("TextButton")
            Button.AutomaticSize = Enum.AutomaticSize.XY
            Button.Size = UDim2.fromOffset(0, 0)
            Button.BackgroundColor3 = Iris._config.ButtonColor
            Button.BackgroundTransparency = Iris._config.ButtonTransparency
            Button.AutoButtonColor = false

            widgets.applyTextStyle(Button)
            Button.TextXAlignment = Enum.TextXAlignment.Center

            widgets.applyFrameStyle(Button)

            widgets.applyInteractionHighlights("Background", Button, Button, {
                Color = Iris._config.ButtonColor,
                Transparency = Iris._config.ButtonTransparency,
                HoveredColor = Iris._config.ButtonHoveredColor,
                HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                ActiveColor = Iris._config.ButtonActiveColor,
                ActiveTransparency = Iris._config.ButtonActiveTransparency,
            })

            return Button
        end,
        Update = function(thisWidget)
            local Button = thisWidget.Instance
            Button.Text = thisWidget.arguments.Text or "Button"
            Button.Size = thisWidget.arguments.Size or UDim2.fromOffset(0, 0)
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    }
    widgets.abstractButton = abstractButton

    Iris.WidgetConstructor("Button", widgets.extend(abstractButton, {
            Generate = function(thisWidget)
                local Button = abstractButton.Generate(thisWidget)
                Button.Name = "Iris_Button"

                return Button
            end,
        })
    )

    Iris.WidgetConstructor("SmallButton", widgets.extend(abstractButton, {
            Generate = function(thisWidget)
                local SmallButton = abstractButton.Generate(thisWidget)
                SmallButton.Name = "Iris_SmallButton"

                local uiPadding = SmallButton.UIPadding
                uiPadding.PaddingLeft = UDim.new(0, 2)
                uiPadding.PaddingRight = UDim.new(0, 2)
                uiPadding.PaddingTop = UDim.new(0, 0)
                uiPadding.PaddingBottom = UDim.new(0, 0)

                return SmallButton
            end,
        })
    )
end

end
-- ===== module: widgets.Checkbox =====
__modules["widgets.Checkbox"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("Checkbox", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
        },
        Events = {
            ["checked"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastCheckedTick == Iris._cycleTick
                end,
            },
            ["unchecked"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUncheckedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local Checkbox = Instance.new("TextButton")
            Checkbox.Name = "Iris_Checkbox"
            Checkbox.AutomaticSize = Enum.AutomaticSize.XY
            Checkbox.Size = UDim2.fromOffset(0, 0)
            Checkbox.BackgroundTransparency = 1
            Checkbox.BorderSizePixel = 0
            Checkbox.Text = ""
            Checkbox.AutoButtonColor = false

            widgets.UIListLayout(Checkbox, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local checkboxSize = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

            local Box = Instance.new("Frame")
            Box.Name = "Box"
            Box.Size = UDim2.fromOffset(checkboxSize, checkboxSize)
            Box.BackgroundColor3 = Iris._config.FrameBgColor
            Box.BackgroundTransparency = Iris._config.FrameBgTransparency

            widgets.applyFrameStyle(Box, true)
            widgets.UIPadding(Box, Vector2.new(math.floor(checkboxSize / 10), math.floor(checkboxSize / 10)))

            widgets.applyInteractionHighlights("Background", Checkbox, Box, {
                Color = Iris._config.FrameBgColor,
                Transparency = Iris._config.FrameBgTransparency,
                HoveredColor = Iris._config.FrameBgHoveredColor,
                HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                ActiveColor = Iris._config.FrameBgActiveColor,
                ActiveTransparency = Iris._config.FrameBgActiveTransparency,
            })

            Box.Parent = Checkbox

            local Checkmark = Instance.new("ImageLabel")
            Checkmark.Name = "Checkmark"
            Checkmark.Size = UDim2.fromScale(1, 1)
            Checkmark.BackgroundTransparency = 1
            Checkmark.Image = widgets.ICONS.CHECKMARK
            Checkmark.ImageColor3 = Iris._config.CheckMarkColor
            Checkmark.ImageTransparency = 1
            Checkmark.ScaleType = Enum.ScaleType.Fit

            Checkmark.Parent = Box

            widgets.applyButtonClick(Checkbox, function()
                thisWidget.state.isChecked:set(not thisWidget.state.isChecked.value)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)
            TextLabel.Parent = Checkbox

            return Checkbox
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.isChecked == nil then
                thisWidget.state.isChecked = Iris._widgetState(thisWidget, "checked", false)
            end
        end,
        Update = function(thisWidget)
            local Checkbox = thisWidget.Instance
            Checkbox.TextLabel.Text = thisWidget.arguments.Text or "Checkbox"
        end,
        UpdateState = function(thisWidget)
            local Checkbox = thisWidget.Instance
            local Box = Checkbox.Box
            local Checkmark = Box.Checkmark
            if thisWidget.state.isChecked.value then
                Checkmark.ImageTransparency = Iris._config.CheckMarkTransparency
                thisWidget.lastCheckedTick = Iris._cycleTick + 1
            else
                Checkmark.ImageTransparency = 1
                thisWidget.lastUncheckedTick = Iris._cycleTick + 1
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })
end

end
-- ===== module: widgets.RadioButton =====
__modules["widgets.RadioButton"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("RadioButton", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Index"] = 2,
        },
        Events = {
            ["selected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastSelectedTick == Iris._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUnselectedTick == Iris._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.state.index.value == thisWidget.arguments.Index
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local RadioButton = Instance.new("TextButton")
            RadioButton.Name = "Iris_RadioButton"
            RadioButton.AutomaticSize = Enum.AutomaticSize.XY
            RadioButton.Size = UDim2.fromOffset(0, 0)
            RadioButton.BackgroundTransparency = 1
            RadioButton.BorderSizePixel = 0
            RadioButton.Text = ""
            RadioButton.AutoButtonColor = false

            widgets.UIListLayout(RadioButton, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local buttonSize = Iris._config.TextSize + 2 * (Iris._config.FramePadding.Y - 1)
            local Button = Instance.new("Frame")
            Button.Name = "Button"
            Button.Size = UDim2.fromOffset(buttonSize, buttonSize)
            Button.BackgroundColor3 = Iris._config.FrameBgColor
            Button.BackgroundTransparency = Iris._config.FrameBgTransparency
            Button.Parent = RadioButton

            widgets.UICorner(Button)
            widgets.UIPadding(Button, Vector2.new(math.max(1, math.floor(buttonSize / 5)), math.max(1, math.floor(buttonSize / 5))))

            local Circle = Instance.new("Frame")
            Circle.Name = "Circle"
            Circle.Size = UDim2.fromScale(1, 1)
            Circle.BackgroundColor3 = Iris._config.CheckMarkColor
            Circle.BackgroundTransparency = Iris._config.CheckMarkTransparency
            widgets.UICorner(Circle)

            Circle.Parent = Button

            widgets.applyInteractionHighlights("Background", RadioButton, Button, {
                Color = Iris._config.FrameBgColor,
                Transparency = Iris._config.FrameBgTransparency,
                HoveredColor = Iris._config.FrameBgHoveredColor,
                HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                ActiveColor = Iris._config.FrameBgActiveColor,
                ActiveTransparency = Iris._config.FrameBgActiveTransparency,
            })

            widgets.applyButtonClick(RadioButton, function()
                thisWidget.state.index:set(thisWidget.arguments.Index)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)
            TextLabel.Parent = RadioButton

            return RadioButton
        end,
        Update = function(thisWidget)
            local RadioButton = thisWidget.Instance
            local TextLabel = RadioButton.TextLabel

            TextLabel.Text = thisWidget.arguments.Text or "Radio Button"
            if thisWidget.state then
                thisWidget.state.index.lastChangeTick = Iris._cycleTick
                Iris._widgets[thisWidget.type].UpdateState(thisWidget)
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", thisWidget.arguments.Index)
            end
        end,
        UpdateState = function(thisWidget)
            local RadioButton = thisWidget.Instance
            local Button = RadioButton.Button
            local Circle = Button.Circle

            if thisWidget.state.index.value == thisWidget.arguments.Index then
                -- only need to hide the circle
                Circle.BackgroundTransparency = Iris._config.CheckMarkTransparency
                thisWidget.lastSelectedTick = Iris._cycleTick + 1
            else
                Circle.BackgroundTransparency = 1
                thisWidget.lastUnselectedTick = Iris._cycleTick + 1
            end
        end,
    })
end

end
-- ===== module: widgets.Image =====
__modules["widgets.Image"] = function()

return function(Iris, widgets)
    local abstractImage = {
        hasState = false,
        hasChildren = false,
        Args = {
            ["Image"] = 1,
            ["Size"] = 2,
            ["Rect"] = 3,
            ["ScaleType"] = 4,
            ["ResampleMode"] = 5,
            ["TileSize"] = 6,
            ["SliceCenter"] = 7,
            ["SliceScale"] = 8,
        },
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    }

    Iris.WidgetConstructor("Image", widgets.extend(abstractImage, {
            Events = {
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                    return thisWidget.Instance
                end),
            },
            Generate = function(_thisWidget)
                local Image = Instance.new("ImageLabel")
                Image.Name = "Iris_Image"
                Image.BackgroundTransparency = 1
                Image.BorderSizePixel = 0
                Image.ImageColor3 = Iris._config.ImageColor
                Image.ImageTransparency = Iris._config.ImageTransparency

                widgets.applyFrameStyle(Image, true)

                return Image
            end,
            Update = function(thisWidget)
                local Image = thisWidget.Instance

                Image.Image = thisWidget.arguments.Image or widgets.ICONS.UNKNOWN_TEXTURE
                Image.Size = thisWidget.arguments.Size
                if thisWidget.arguments.ScaleType then
                    Image.ScaleType = thisWidget.arguments.ScaleType
                    if thisWidget.arguments.ScaleType == Enum.ScaleType.Tile and thisWidget.arguments.TileSize then
                        Image.TileSize = thisWidget.arguments.TileSize
                    elseif thisWidget.arguments.ScaleType == Enum.ScaleType.Slice then
                        if thisWidget.arguments.SliceCenter then
                            Image.SliceCenter = thisWidget.arguments.SliceCenter
                        end
                        if thisWidget.arguments.SliceScale then
                            Image.SliceScale = thisWidget.arguments.SliceScale
                        end
                    end
                end

                if thisWidget.arguments.Rect then
                    Image.ImageRectOffset = thisWidget.arguments.Rect.Min
                    Image.ImageRectSize = Vector2.new(thisWidget.arguments.Rect.Width, thisWidget.arguments.Rect.Height)
                end

                if thisWidget.arguments.ResampleMode then
                    Image.ResampleMode = thisWidget.arguments.ResampleMode
                end
            end,
        })
    )

    Iris.WidgetConstructor("ImageButton", widgets.extend(abstractImage, {
            Events = {
                ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                    return thisWidget.Instance
                end),
                ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget)
                    return thisWidget.Instance
                end),
                ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget)
                    return thisWidget.Instance
                end),
                ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget)
                    return thisWidget.Instance
                end),
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                    return thisWidget.Instance
                end),
            },
            Generate = function(_thisWidget)
                local Button = Instance.new("ImageButton")
                Button.Name = "Iris_ImageButton"
                Button.AutomaticSize = Enum.AutomaticSize.XY
                Button.BackgroundColor3 = Iris._config.FrameBgColor
                Button.BackgroundTransparency = Iris._config.FrameBgTransparency
                Button.BorderSizePixel = 0
                Button.Image = ""
                Button.ImageTransparency = 1
                Button.AutoButtonColor = false

                widgets.applyFrameStyle(Button, true)
                widgets.UIPadding(Button, Vector2.new(Iris._config.ImageBorderSize, Iris._config.ImageBorderSize))

                local Image = Instance.new("ImageLabel")
                Image.Name = "ImageLabel"
                Image.BackgroundTransparency = 1
                Image.BorderSizePixel = 0
                Image.ImageColor3 = Iris._config.ImageColor
                Image.ImageTransparency = Iris._config.ImageTransparency
                Image.Parent = Button

                widgets.applyInteractionHighlights("Background", Button, Button, {
                    Color = Iris._config.FrameBgColor,
                    Transparency = Iris._config.FrameBgTransparency,
                    HoveredColor = Iris._config.FrameBgHoveredColor,
                    HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                    ActiveColor = Iris._config.FrameBgActiveColor,
                    ActiveTransparency = Iris._config.FrameBgActiveTransparency,
                })

                return Button
            end,
            Update = function(thisWidget)
                local Button = thisWidget.Instance
                local Image = Button.ImageLabel

                Image.Image = thisWidget.arguments.Image or widgets.ICONS.UNKNOWN_TEXTURE
                Image.Size = thisWidget.arguments.Size
                if thisWidget.arguments.ScaleType then
                    Image.ScaleType = thisWidget.arguments.ScaleType
                    if thisWidget.arguments.ScaleType == Enum.ScaleType.Tile and thisWidget.arguments.TileSize then
                        Image.TileSize = thisWidget.arguments.TileSize
                    elseif thisWidget.arguments.ScaleType == Enum.ScaleType.Slice then
                        if thisWidget.arguments.SliceCenter then
                            Image.SliceCenter = thisWidget.arguments.SliceCenter
                        end
                        if thisWidget.arguments.SliceScale then
                            Image.SliceScale = thisWidget.arguments.SliceScale
                        end
                    end
                end

                if thisWidget.arguments.Rect then
                    Image.ImageRectOffset = thisWidget.arguments.Rect.Min
                    Image.ImageRectSize = Vector2.new(thisWidget.arguments.Rect.Width, thisWidget.arguments.Rect.Height)
                end

                if thisWidget.arguments.ResampleMode then
                    Image.ResampleMode = thisWidget.arguments.ResampleMode
                end
            end,
        })
    )
end

end
-- ===== module: widgets.Tree =====
__modules["widgets.Tree"] = function()

return function(Iris, widgets)
    local abstractTree = {
        hasState = true,
        hasChildren = true,
        Events = {
            ["collapsed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastCollapsedTick == Iris._cycleTick
                end,
            },
            ["uncollapsed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUncollapsedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
        ChildAdded = function(thisWidget, _thisChild)
            local ChildContainer = thisWidget.ChildContainer

            ChildContainer.Visible = thisWidget.state.isUncollapsed.value

            return ChildContainer
        end,
        UpdateState = function(thisWidget)
            local isUncollapsed = thisWidget.state.isUncollapsed.value
            local Tree = thisWidget.Instance
            local ChildContainer = thisWidget.ChildContainer
            local Header = Tree.Header
            local Button = Header.Button
            local Arrow = Button.Arrow

            Arrow.Image = (isUncollapsed and widgets.ICONS.DOWN_POINTING_TRIANGLE or widgets.ICONS.RIGHT_POINTING_TRIANGLE)
            if isUncollapsed then
                thisWidget.lastUncollapsedTick = Iris._cycleTick + 1
            else
                thisWidget.lastCollapsedTick = Iris._cycleTick + 1
            end

            ChildContainer.Visible = isUncollapsed
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.isUncollapsed == nil then
                thisWidget.state.isUncollapsed = Iris._widgetState(thisWidget, "isUncollapsed", thisWidget.arguments.DefaultOpen or false)
            end
        end,
    }

    Iris.WidgetConstructor(
        "Tree",
        widgets.extend(abstractTree, {
            Args = {
                ["Text"] = 1,
                ["SpanAvailWidth"] = 2,
                ["NoIndent"] = 3,
                ["DefaultOpen"] = 4,
            },
            Generate = function(thisWidget)
                local Tree = Instance.new("Frame")
                Tree.Name = "Iris_Tree"
                Tree.AutomaticSize = Enum.AutomaticSize.Y
                Tree.Size = UDim2.new(Iris._config.ItemWidth, UDim.new(0, 0))
                Tree.BackgroundTransparency = 1
                Tree.BorderSizePixel = 0

                widgets.UIListLayout(Tree, Enum.FillDirection.Vertical, UDim.new(0, 0))

                local ChildContainer = Instance.new("Frame")
                ChildContainer.Name = "TreeContainer"
                ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
                ChildContainer.Size = UDim2.fromScale(1, 0)
                ChildContainer.BackgroundTransparency = 1
                ChildContainer.BorderSizePixel = 0
                ChildContainer.LayoutOrder = 1
                ChildContainer.Visible = false
                -- ChildContainer.ClipsDescendants = true

                widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
                widgets.UIPadding(ChildContainer, Vector2.zero).PaddingTop = UDim.new(0, Iris._config.ItemSpacing.Y)

                ChildContainer.Parent = Tree

                local Header = Instance.new("Frame")
                Header.Name = "Header"
                Header.AutomaticSize = Enum.AutomaticSize.Y
                Header.Size = UDim2.fromScale(1, 0)
                Header.BackgroundTransparency = 1
                Header.BorderSizePixel = 0
                Header.Parent = Tree

                local Button = Instance.new("TextButton")
                Button.Name = "Button"
                Button.BackgroundTransparency = 1
                Button.BorderSizePixel = 0
                Button.Text = ""
                Button.AutoButtonColor = false

                widgets.applyInteractionHighlights("Background", Button, Header, {
                    Color = Color3.fromRGB(0, 0, 0),
                    Transparency = 1,
                    HoveredColor = Iris._config.HeaderHoveredColor,
                    HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                    ActiveColor = Iris._config.HeaderActiveColor,
                    ActiveTransparency = Iris._config.HeaderActiveTransparency,
                })

                widgets.UIPadding(Button, Vector2.zero).PaddingLeft = UDim.new(0, Iris._config.FramePadding.X)
                widgets.UIListLayout(Button, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.FramePadding.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                Button.Parent = Header

                local Arrow = Instance.new("ImageLabel")
                Arrow.Name = "Arrow"
                Arrow.Size = UDim2.fromOffset(Iris._config.TextSize, math.floor(Iris._config.TextSize * 0.7))
                Arrow.BackgroundTransparency = 1
                Arrow.BorderSizePixel = 0
                Arrow.ImageColor3 = Iris._config.TextColor
                Arrow.ImageTransparency = Iris._config.TextTransparency
                Arrow.ScaleType = Enum.ScaleType.Fit

                Arrow.Parent = Button

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.Size = UDim2.fromOffset(0, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.UIPadding(TextLabel, Vector2.zero).PaddingRight = UDim.new(0, 21)
                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Button

                widgets.applyButtonClick(Button, function()
                    thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
                end)

                thisWidget.ChildContainer = ChildContainer
                return Tree
            end,
            Update = function(thisWidget)
                local Tree = thisWidget.Instance
                local ChildContainer = thisWidget.ChildContainer
                local Header = Tree.Header
                local Button = Header.Button
                local TextLabel = Button.TextLabel
                local Padding = ChildContainer.UIPadding

                TextLabel.Text = thisWidget.arguments.Text or "Tree"
                if thisWidget.arguments.SpanAvailWidth then
                    Button.AutomaticSize = Enum.AutomaticSize.Y
                    Button.Size = UDim2.fromScale(1, 0)
                else
                    Button.AutomaticSize = Enum.AutomaticSize.XY
                    Button.Size = UDim2.fromScale(0, 0)
                end

                if thisWidget.arguments.NoIndent then
                    Padding.PaddingLeft = UDim.new(0, 0)
                else
                    Padding.PaddingLeft = UDim.new(0, Iris._config.IndentSpacing)
                end
            end,
        })
    )

    Iris.WidgetConstructor(
        "CollapsingHeader",
        widgets.extend(abstractTree, {
            Args = {
                ["Text"] = 1,
                ["DefaultOpen"] = 2
            },
            Generate = function(thisWidget)
                local CollapsingHeader = Instance.new("Frame")
                CollapsingHeader.Name = "Iris_CollapsingHeader"
                CollapsingHeader.AutomaticSize = Enum.AutomaticSize.Y
                CollapsingHeader.Size = UDim2.new(Iris._config.ItemWidth, UDim.new(0, 0))
                CollapsingHeader.BackgroundTransparency = 1
                CollapsingHeader.BorderSizePixel = 0

                widgets.UIListLayout(CollapsingHeader, Enum.FillDirection.Vertical, UDim.new(0, 0))

                local ChildContainer = Instance.new("Frame")
                ChildContainer.Name = "CollapsingHeaderContainer"
                ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
                ChildContainer.Size = UDim2.fromScale(1, 0)
                ChildContainer.BackgroundTransparency = 1
                ChildContainer.BorderSizePixel = 0
                ChildContainer.LayoutOrder = 1
                ChildContainer.Visible = false
                -- ChildContainer.ClipsDescendants = true

                widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
                widgets.UIPadding(ChildContainer, Vector2.zero).PaddingTop = UDim.new(0, Iris._config.ItemSpacing.Y)

                ChildContainer.Parent = CollapsingHeader

                local Header = Instance.new("Frame")
                Header.Name = "Header"
                Header.AutomaticSize = Enum.AutomaticSize.Y
                Header.Size = UDim2.fromScale(1, 0)
                Header.BackgroundTransparency = 1
                Header.BorderSizePixel = 0
                Header.Parent = CollapsingHeader

                local Button = Instance.new("TextButton")
                Button.Name = "Button"
                Button.AutomaticSize = Enum.AutomaticSize.Y
                Button.Size = UDim2.fromScale(1, 0)
                Button.BackgroundColor3 = Iris._config.HeaderColor
                Button.BackgroundTransparency = Iris._config.HeaderTransparency
                Button.BorderSizePixel = 0
                Button.Text = ""
                Button.AutoButtonColor = false
                Button.ClipsDescendants = true

                widgets.UIPadding(Button, Iris._config.FramePadding) -- we add a custom padding because it extends on both sides
                widgets.applyFrameStyle(Button, true)
                widgets.UIListLayout(Button, Enum.FillDirection.Horizontal, UDim.new(0, 2 * Iris._config.FramePadding.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                widgets.applyInteractionHighlights("Background", Button, Button, {
                    Color = Iris._config.HeaderColor,
                    Transparency = Iris._config.HeaderTransparency,
                    HoveredColor = Iris._config.HeaderHoveredColor,
                    HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                    ActiveColor = Iris._config.HeaderActiveColor,
                    ActiveTransparency = Iris._config.HeaderActiveTransparency,
                })

                Button.Parent = Header

                local Arrow = Instance.new("ImageLabel")
                Arrow.Name = "Arrow"
                Arrow.AutomaticSize = Enum.AutomaticSize.Y
                Arrow.Size = UDim2.fromOffset(Iris._config.TextSize, math.ceil(Iris._config.TextSize * 0.8))
                Arrow.BackgroundTransparency = 1
                Arrow.BorderSizePixel = 0
                Arrow.ImageColor3 = Iris._config.TextColor
                Arrow.ImageTransparency = Iris._config.TextTransparency
                Arrow.ScaleType = Enum.ScaleType.Fit

                Arrow.Parent = Button

                local TextLabel = Instance.new("TextLabel")
                TextLabel.Name = "TextLabel"
                TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                TextLabel.Size = UDim2.fromOffset(0, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.BorderSizePixel = 0

                widgets.UIPadding(TextLabel, Vector2.zero).PaddingRight = UDim.new(0, 21)
                widgets.applyTextStyle(TextLabel)

                TextLabel.Parent = Button

                widgets.applyButtonClick(Button, function()
                    thisWidget.state.isUncollapsed:set(not thisWidget.state.isUncollapsed.value)
                end)

                thisWidget.ChildContainer = ChildContainer
                return CollapsingHeader
            end,
            Update = function(thisWidget)
                local Tree = thisWidget.Instance
                local Header = Tree.Header
                local Button = Header.Button
                local TextLabel = Button.TextLabel

                TextLabel.Text = thisWidget.arguments.Text or "Collapsing Header"
            end,
        })
    )
end

end
-- ===== module: widgets.Tab =====
__modules["widgets.Tab"] = function()

return function(Iris, widgets)
    local function openTab(TabBar, Index)
        if TabBar.state.index.value > 0 then
            return
        end

        TabBar.state.index:set(Index)
    end

    local function closeTab(TabBar, Index)
        if TabBar.state.index.value ~= Index then
            return
        end

        -- search left for open tabs
        for i = Index - 1, 1, -1 do
            if TabBar.Tabs[i].state.isOpened.value == true then
                TabBar.state.index:set(i)
                return
            end
        end

        -- search right for open tabs
        for i = Index, #TabBar.Tabs do
            if TabBar.Tabs[i].state.isOpened.value == true then
                TabBar.state.index:set(i)
                return
            end
        end

        -- no open tabs, so wait for one
        TabBar.state.index:set(0)
    end

    Iris.WidgetConstructor("TabBar", {
        hasState = true,
        hasChildren = true,
        Args = {},
        Events = {},
        Generate = function(thisWidget)
            local TabBar = Instance.new("Frame")
            TabBar.Name = "Iris_TabBar"
            TabBar.AutomaticSize = Enum.AutomaticSize.Y
            TabBar.Size = UDim2.fromScale(1, 0)
            TabBar.BackgroundTransparency = 1
            TabBar.BorderSizePixel = 0

            widgets.UIListLayout(TabBar, Enum.FillDirection.Vertical, UDim.new()).VerticalAlignment = Enum.VerticalAlignment.Bottom

            local Bar = Instance.new("Frame")
            Bar.Name = "Bar"
            Bar.AutomaticSize = Enum.AutomaticSize.Y
            Bar.Size = UDim2.fromScale(1, 0)
            Bar.BackgroundTransparency = 1
            Bar.BorderSizePixel = 0

            widgets.UIListLayout(Bar, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X))

            Bar.Parent = TabBar

            local Underline = Instance.new("Frame")
            Underline.Name = "Underline"
            Underline.Size = UDim2.new(1, 0, 0, 1)
            Underline.BackgroundColor3 = Iris._config.TabActiveColor
            Underline.BackgroundTransparency = Iris._config.TabActiveTransparency
            Underline.BorderSizePixel = 0
            Underline.LayoutOrder = 1

            Underline.Parent = TabBar

            local ChildContainer = Instance.new("Frame")
            ChildContainer.Name = "TabContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
            ChildContainer.Size = UDim2.fromScale(1, 0)
            ChildContainer.BackgroundTransparency = 1
            ChildContainer.BorderSizePixel = 0
            ChildContainer.LayoutOrder = 2
            ChildContainer.ClipsDescendants = true

            ChildContainer.Parent = TabBar

            thisWidget.ChildContainer = ChildContainer
            thisWidget.Tabs = {}

            return TabBar
        end,
        Update = function(_thisWidget) end,
        ChildAdded = function(thisWidget, thisChild)
            assert(thisChild.type == "Tab", "Only Iris.Tab can be parented to Iris.TabBar.")
            local TabBar = thisWidget.Instance
            thisChild.ChildContainer.Parent = thisWidget.ChildContainer
            thisChild.Index = #thisWidget.Tabs + 1
            thisWidget.state.index.ConnectedWidgets[thisChild.ID] = thisChild
            table.insert(thisWidget.Tabs, thisChild)

            return TabBar.Bar
        end,
        ChildDiscarded = function(thisWidget, thisChild)
            local Index = thisChild.Index
            table.remove(thisWidget.Tabs, Index)

            for i = Index, #thisWidget.Tabs do
                thisWidget.Tabs[i].Index = i
            end

            closeTab(thisWidget, Index)
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", 1)
            end
        end,
        UpdateState = function(_thisWidget)
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
        end,
    })

    Iris.WidgetConstructor("Tab", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
            ["Hideable"] = 2,
        },
        Events = {
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                return thisWidget.Instance
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
            ["selected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastSelectedTick == Iris._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUnselectedTick == Iris._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.state.index.value == thisWidget.Index
                end,
            },
            ["opened"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastOpenedTick == Iris._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastClosedTick == Iris._cycleTick
                end,
            },
        },
        Generate = function(thisWidget)
            local Tab = Instance.new("TextButton")
            Tab.Name = "Iris_Tab"
            Tab.AutomaticSize = Enum.AutomaticSize.XY
            Tab.BackgroundColor3 = Iris._config.TabColor
            Tab.BackgroundTransparency = Iris._config.TabTransparency
            Tab.BorderSizePixel = 0
            Tab.Text = ""
            Tab.AutoButtonColor = false

            thisWidget.ButtonColors = {
                Color = Iris._config.TabColor,
                Transparency = Iris._config.TabTransparency,
                HoveredColor = Iris._config.TabHoveredColor,
                HoveredTransparency = Iris._config.TabHoveredTransparency,
                ActiveColor = Iris._config.TabActiveColor,
                ActiveTransparency = Iris._config.TabActiveTransparency,
            }

            widgets.UIPadding(Tab, Vector2.new(Iris._config.FramePadding.X, 0))
            widgets.applyFrameStyle(Tab, true, true)
            widgets.UIListLayout(Tab, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center
            widgets.applyInteractionHighlights("Background", Tab, Tab, thisWidget.ButtonColors)
            widgets.applyButtonClick(Tab, function()
                thisWidget.state.index:set(thisWidget.Index)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)
            widgets.UIPadding(TextLabel, Vector2.new(0, Iris._config.FramePadding.Y))

            TextLabel.Parent = Tab

            local ButtonSize = Iris._config.TextSize + ((Iris._config.FramePadding.Y - 1) * 2)

            local CloseButton = Instance.new("TextButton")
            CloseButton.Name = "CloseButton"
            CloseButton.Size = UDim2.fromOffset(ButtonSize, ButtonSize)
            CloseButton.BackgroundTransparency = 1
            CloseButton.BorderSizePixel = 0
            CloseButton.Text = ""
            CloseButton.AutoButtonColor = false
            CloseButton.LayoutOrder = 1

            widgets.UICorner(CloseButton)
            widgets.applyButtonClick(CloseButton, function()
                thisWidget.state.isOpened:set(false)
                closeTab(thisWidget.parentWidget, thisWidget.Index)
            end)

            widgets.applyInteractionHighlights("Background", CloseButton, CloseButton, {
                Color = Iris._config.TabColor,
                Transparency = 1,
                HoveredColor = Iris._config.ButtonHoveredColor,
                HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                ActiveColor = Iris._config.ButtonActiveColor,
                ActiveTransparency = Iris._config.ButtonActiveTransparency,
            })

            CloseButton.Parent = Tab

            local Icon = Instance.new("ImageLabel")
            Icon.Name = "Icon"
            Icon.AnchorPoint = Vector2.new(0.5, 0.5)
            Icon.Position = UDim2.fromScale(0.5, 0.5)
            Icon.Size = UDim2.fromOffset(math.floor(0.7 * ButtonSize), math.floor(0.7 * ButtonSize))
            Icon.BackgroundTransparency = 1
            Icon.BorderSizePixel = 0
            Icon.Image = widgets.ICONS.MULTIPLICATION_SIGN
            Icon.ImageTransparency = 1

            widgets.applyInteractionHighlights("Image", Tab, Icon, {
                Color = Iris._config.TextColor,
                Transparency = 1,
                HoveredColor = Iris._config.TextColor,
                HoveredTransparency = Iris._config.TextTransparency,
                ActiveColor = Iris._config.TextColor,
                ActiveTransparency = Iris._config.TextTransparency,
            })
            Icon.Parent = CloseButton

            local ChildContainer = Instance.new("Frame")
            ChildContainer.Name = "TabContainer"
            ChildContainer.AutomaticSize = Enum.AutomaticSize.Y
            ChildContainer.Size = UDim2.fromScale(1, 0)
            ChildContainer.BackgroundTransparency = 1
            ChildContainer.BorderSizePixel = 0

            ChildContainer.ClipsDescendants = true
            widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
            widgets.UIPadding(ChildContainer, Vector2.new(0, Iris._config.ItemSpacing.Y)).PaddingBottom = UDim.new()

            thisWidget.ChildContainer = ChildContainer

            return Tab
        end,
        Update = function(thisWidget)
            local Tab = thisWidget.Instance
            local TextLabel = Tab.TextLabel
            local CloseButton = Tab.CloseButton

            TextLabel.Text = thisWidget.arguments.Text
            CloseButton.Visible = (thisWidget.arguments.Hideable == true and true or false)
        end,
        ChildAdded = function(thisWidget, _thisChild)
            return thisWidget.ChildContainer
        end,
        GenerateState = function(thisWidget)
            thisWidget.state.index = thisWidget.parentWidget.state.index
            thisWidget.state.index.ConnectedWidgets[thisWidget.ID] = thisWidget

            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Iris._widgetState(thisWidget, "isOpened", true)
            end
        end,
        UpdateState = function(thisWidget)
            local Tab = thisWidget.Instance
            local Container = thisWidget.ChildContainer

            if thisWidget.state.isOpened.lastChangeTick == Iris._cycleTick then
                if thisWidget.state.isOpened.value == true then
                    thisWidget.lastOpenedTick = Iris._cycleTick + 1
                    openTab(thisWidget.parentWidget, thisWidget.Index)
                    Tab.Visible = true
                else
                    thisWidget.lastClosedTick = Iris._cycleTick + 1
                    closeTab(thisWidget.parentWidget, thisWidget.Index)
                    Tab.Visible = false
                end
            end

            if thisWidget.state.index.lastChangeTick == Iris._cycleTick then
                if thisWidget.state.index.value == thisWidget.Index then
                    thisWidget.ButtonColors.Color = Iris._config.TabActiveColor
                    thisWidget.ButtonColors.Transparency = Iris._config.TabActiveTransparency
            Tab.BackgroundColor3 = Iris._config.TabActiveColor
                    Tab.BackgroundTransparency = Iris._config.TabActiveTransparency
                    Container.Visible = true
                    thisWidget.lastSelectedTick = Iris._cycleTick + 1
                else
                    thisWidget.ButtonColors.Color = Iris._config.TabColor
                    thisWidget.ButtonColors.Transparency = Iris._config.TabTransparency
                    Tab.BackgroundColor3 = Iris._config.TabColor
                    Tab.BackgroundTransparency = Iris._config.TabTransparency
                    Container.Visible = false
                    thisWidget.lastUnselectedTick = Iris._cycleTick + 1
                end
            end
        end,
        Discard = function(thisWidget)
            if thisWidget.state.isOpened.value == true then
                closeTab(thisWidget.parentWidget, thisWidget.Index)
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end
    })
end

end
-- ===== module: widgets.Input =====
__modules["widgets.Input"] = function()

return function(Iris, widgets)
    local numberChanged = {
        ["Init"] = function(_thisWidget) end,
        ["Get"] = function(thisWidget)
            return thisWidget.lastNumberChangedTick == Iris._cycleTick
        end,
    }

    local function getValueByIndex(value, index, arguments)
        local val = value
        if typeof(val) == "number" then
            return val
        elseif typeof(val) == "Vector2" then
            if index == 1 then
                return val.X
            elseif index == 2 then
                return val.Y
            end
        elseif typeof(val) == "Vector3" then
            if index == 1 then
                return val.X
            elseif index == 2 then
                return val.Y
            elseif index == 3 then
                return val.Z
            end
        elseif typeof(val) == "UDim" then
            if index == 1 then
                return val.Scale
            elseif index == 2 then
                return val.Offset
            end
        elseif typeof(val) == "UDim2" then
            if index == 1 then
                return val.X.Scale
            elseif index == 2 then
                return val.X.Offset
            elseif index == 3 then
                return val.Y.Scale
            elseif index == 4 then
                return val.Y.Offset
            end
        elseif typeof(val) == "Color3" then
            local color = (arguments.UseHSV and { val:ToHSV() } or { val.R, val.G, val.B })
            if index == 1 then
                return color[1]
            elseif index == 2 then
                return color[2]
            elseif index == 3 then
                return color[3]
            end
        elseif typeof(val) == "Rect" then
            if index == 1 then
                return val.Min.X
            elseif index == 2 then
                return val.Min.Y
            elseif index == 3 then
                return val.Max.X
            elseif index == 4 then
                return val.Max.Y
            end
        elseif typeof(val) == "table" then
            return val[index]
        end

        error(string.format("Incorrect datatype or value: %s %s %s.", value, typeof(value), index))
    end

    local function updateValueByIndex(value, index, newValue, arguments)
        local val = value
        if typeof(val) == "number" then
            return newValue
        elseif typeof(val) == "Vector2" then
            if index == 1 then
                return Vector2.new(newValue, val.Y)
            elseif index == 2 then
                return Vector2.new(val.X, newValue)
            end
        elseif typeof(val) == "Vector3" then
            if index == 1 then
                return Vector3.new(newValue, val.Y, val.Z)
            elseif index == 2 then
                return Vector3.new(val.X, newValue, val.Z)
            elseif index == 3 then
                return Vector3.new(val.X, val.Y, newValue)
            end
        elseif typeof(val) == "UDim" then
            if index == 1 then
                return UDim.new(newValue, val.Offset)
            elseif index == 2 then
                return UDim.new(val.Scale, newValue)
            end
        elseif typeof(val) == "UDim2" then
            if index == 1 then
                return UDim2.new(UDim.new(newValue, val.X.Offset), val.Y)
            elseif index == 2 then
                return UDim2.new(UDim.new(val.X.Scale, newValue), val.Y)
            elseif index == 3 then
                return UDim2.new(val.X, UDim.new(newValue, val.Y.Offset))
            elseif index == 4 then
                return UDim2.new(val.X, UDim.new(val.Y.Scale, newValue))
            end
        elseif typeof(val) == "Rect" then
            if index == 1 then
                return Rect.new(Vector2.new(newValue, val.Min.Y), val.Max)
            elseif index == 2 then
                return Rect.new(Vector2.new(val.Min.X, newValue), val.Max)
            elseif index == 3 then
                return Rect.new(val.Min, Vector2.new(newValue, val.Max.Y))
            elseif index == 4 then
                return Rect.new(val.Min, Vector2.new(val.Max.X, newValue))
            end
        elseif typeof(val) == "Color3" then
            if arguments.UseHSV then
                local h = val:ToHSV()
                if index == 1 then
                    return Color3.fromHSV(newValue, s, v)
                elseif index == 2 then
                    return Color3.fromHSV(h, newValue, v)
                elseif index == 3 then
                    return Color3.fromHSV(h, s, newValue)
                end
            end
            if index == 1 then
                return Color3.new(newValue, val.G, val.B)
            elseif index == 2 then
                return Color3.new(val.R, newValue, val.B)
            elseif index == 3 then
                return Color3.new(val.R, val.G, newValue)
            end
        end

        error(string.format("Incorrect datatype or value %s %s %s.", value, typeof(value), index))
    end

    local defaultIncrements = {
        Num = { 1 },
        Vector2 = { 1, 1 },
        Vector3 = { 1, 1, 1 },
        UDim = { 0.01, 1 },
        UDim2 = { 0.01, 1, 0.01, 1 },
        Color3 = { 1, 1, 1 },
        Color4 = { 1, 1, 1, 1 },
        Rect = { 1, 1, 1, 1 },
    }

    local defaultMin = {
        Num = { 0 },
        Vector2 = { 0, 0 },
        Vector3 = { 0, 0, 0 },
        UDim = { 0, 0 },
        UDim2 = { 0, 0, 0, 0 },
        Rect = { 0, 0, 0, 0 },
    }

    local defaultMax = {
        Num = { 100 },
        Vector2 = { 100, 100 },
        Vector3 = { 100, 100, 100 },
        UDim = { 1, 960 },
        UDim2 = { 1, 960, 1, 960 },
        Rect = { 960, 960, 960, 960 },
    }

    local defaultPrefx = {
        Num = { "" },
        Vector2 = { "X: ", "Y: " },
        Vector3 = { "X: ", "Y: ", "Z: " },
        UDim = { "", "" },
        UDim2 = { "", "", "", "" },
        Color3_RGB = { "R: ", "G: ", "B: " },
        Color3_HSV = { "H: ", "S: ", "V: " },
        Color4_RGB = { "R: ", "G: ", "B: ", "T: " },
        Color4_HSV = { "H: ", "S: ", "V: ", "T: " },
        Rect = { "X: ", "Y: ", "X: ", "Y: " },
    }

    local defaultSigFigs = {
        Num = { 0 },
        Vector2 = { 0, 0 },
        Vector3 = { 0, 0, 0 },
        UDim = { 3, 0 },
        UDim2 = { 3, 0, 3, 0 },
        Color3 = { 0, 0, 0 },
        Color4 = { 0, 0, 0, 0 },
        Rect = { 0, 0, 0, 0 },
    }

    local function generateAbstract(inputType, dataType, components, defaultValue)
        return {
            hasState = true,
            hasChildren = false,
            Args = {
                ["Text"] = 1,
                ["Increment"] = 2,
                ["Min"] = 3,
                ["Max"] = 4,
                ["Format"] = 5,
            },
            Events = {
                ["numberChanged"] = numberChanged,
                ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                    return thisWidget.Instance
                end),
            },
            GenerateState = function(thisWidget)
                if thisWidget.state.number == nil then
                    thisWidget.state.number = Iris._widgetState(thisWidget, "number", defaultValue)
                end
                if thisWidget.state.editingText == nil then
                    thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", 0)
                end
            end,
            Update = function(thisWidget)
                local Input = thisWidget.Instance
                local TextLabel = Input.TextLabel
                TextLabel.Text = thisWidget.arguments.Text or string.format("Input %s", dataType)

                if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
                    thisWidget.arguments.Format = { thisWidget.arguments.Format }
                elseif not thisWidget.arguments.Format then
                    -- we calculate the format for the s.f. using the max, min and increment arguments.
                    local format = {}
                    for index = 1, components do
                        local sigfigs = defaultSigFigs[dataType][index]

                        if thisWidget.arguments.Increment then
                            local value = getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if thisWidget.arguments.Max then
                            local value = getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if thisWidget.arguments.Min then
                            local value = getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments)
                            sigfigs = math.max(sigfigs, math.ceil(-math.log10(value == 0 and 1 or value)), sigfigs)
                        end

                        if sigfigs > 0 then
                            -- we know it's a float.
                            format[index] = string.format("%%.%sf", sigfigs)
                        else
                            format[index] = "%d"
                        end
                    end

                    thisWidget.arguments.Format = format
                    thisWidget.arguments.Prefix = defaultPrefx[dataType]
                end

                if inputType == "Input" and dataType == "Num" then
                    Input.SubButton.Visible = not thisWidget.arguments.NoButtons
                    Input.AddButton.Visible = not thisWidget.arguments.NoButtons
                    local InputField = Input.InputField1
                    local rightPadding = (thisWidget.arguments.NoButtons and 0 or (2 * Iris._config.ItemInnerSpacing.X) + (2 * (Iris._config.TextSize + 2 * Iris._config.FramePadding.Y)))
                    InputField.Size = UDim2.new(UDim.new(Iris._config.ContentWidth.Scale, Iris._config.ContentWidth.Offset - rightPadding), Iris._config.ContentHeight)
                end

                if inputType == "Slider" then
                    for index = 1, components do
                        local SliderField = Input:FindFirstChild("SliderField" .. tostring(index))
                        local GrabBar = SliderField.GrabBar

                        local increment = thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments) or defaultIncrements[dataType][index]
                        local min = thisWidget.arguments.Min and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments) or defaultMin[dataType][index]
                        local max = thisWidget.arguments.Max and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments) or defaultMax[dataType][index]

                        local grabScaleSize = 1 / math.floor((1 + max - min) / increment)

                        GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
                    end

                    local callbackIndex = #Iris._postCycleCallbacks + 1
                    local desiredCycleTick = Iris._cycleTick + 1
                    Iris._postCycleCallbacks[callbackIndex] = function()
                        if Iris._cycleTick >= desiredCycleTick then
                            if thisWidget.lastCycleTick ~= -1 then
                                thisWidget.state.number.lastChangeTick = Iris._cycleTick
                                Iris._widgets[string.format("Slider%s", dataType)].UpdateState(thisWidget)
                            end
                            Iris._postCycleCallbacks[callbackIndex] = nil
                        end
                    end
                end
            end,
            Discard = function(thisWidget)
                thisWidget.Instance:Destroy()
                widgets.discardState(thisWidget)
            end,
        }
    end

    local function focusLost(thisWidget, InputField, index, dataType)
        local newValue = tonumber(InputField.Text:match("-?%d*%.?%d*"))
        local state = thisWidget.state.number
        local widget = thisWidget
        if dataType == "Color4" and index == 4 then
            state = widget.state.transparency
        elseif dataType == "Color3" or dataType == "Color4" then
            state = widget.state.color
        end
        if newValue ~= nil then
            if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
                newValue = newValue / 255
            end
            if thisWidget.arguments.Min ~= nil then
                newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments))
            end
            if thisWidget.arguments.Max ~= nil then
                newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments))
            end

            if thisWidget.arguments.Increment then
                newValue = math.round(newValue / getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments)) * getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments)
            end

            state:set(updateValueByIndex(state.value, index, newValue, thisWidget.arguments))
            thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
        end

        local value = getValueByIndex(state.value, index, thisWidget.arguments)
        if dataType == "Color3" or dataType == "Color4" and not widget.arguments.UseFloats then
            value = math.round(value * 255)
        end

        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
        if thisWidget.arguments.Prefix then
            format = thisWidget.arguments.Prefix[index] .. format
        end
        InputField.Text = string.format(format, value)

        thisWidget.state.editingText:set(0)
        InputField:ReleaseFocus(true)
    end

    do
        local function generateButtons(thisWidget, parent, textHeight)
            local SubButton = widgets.abstractButton.Generate(thisWidget)
            SubButton.Name = "SubButton"
            SubButton.Size = UDim2.fromOffset(Iris._config.TextSize + 2 * Iris._config.FramePadding.Y, Iris._config.TextSize)
            SubButton.Text = "-"
            SubButton.TextXAlignment = Enum.TextXAlignment.Center
            SubButton.ZIndex = 5
            SubButton.LayoutOrder = 5
            SubButton.Parent = parent

            widgets.applyButtonClick(SubButton, function()
                local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local changeValue = (thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments) or 1) * (isCtrlHeld and 100 or 1)
                local newValue = thisWidget.state.number.value - changeValue
                if thisWidget.arguments.Min ~= nil then
                    newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments))
                end
                if thisWidget.arguments.Max ~= nil then
                    newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments))
                end
                thisWidget.state.number:set(newValue)
                thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
            end)

            local AddButton = widgets.abstractButton.Generate(thisWidget)
            AddButton.Name = "AddButton"
            AddButton.Size = UDim2.fromOffset(Iris._config.TextSize + 2 * Iris._config.FramePadding.Y, Iris._config.TextSize)
            AddButton.Text = "+"
            AddButton.TextXAlignment = Enum.TextXAlignment.Center
            AddButton.ZIndex = 6
            AddButton.LayoutOrder = 6
            AddButton.Parent = parent

            widgets.applyButtonClick(AddButton, function()
                local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local changeValue = (thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, 1, thisWidget.arguments) or 1) * (isCtrlHeld and 100 or 1)
                local newValue = thisWidget.state.number.value + changeValue
                if thisWidget.arguments.Min ~= nil then
                    newValue = math.max(newValue, getValueByIndex(thisWidget.arguments.Min, 1, thisWidget.arguments))
                end
                if thisWidget.arguments.Max ~= nil then
                    newValue = math.min(newValue, getValueByIndex(thisWidget.arguments.Max, 1, thisWidget.arguments))
                end
                thisWidget.state.number:set(newValue)
                thisWidget.lastNumberChangedTick = Iris._cycleTick + 1
            end)

            return 2 * Iris._config.ItemInnerSpacing.X + 2 * textHeight
        end

        local function generateField(thisWidget, index, componentWidth, dataType)
            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField" .. tostring(index)
            InputField.AutomaticSize = Enum.AutomaticSize.Y
            InputField.Size = UDim2.new(componentWidth, Iris._config.ContentHeight)
            InputField.BackgroundColor3 = Iris._config.FrameBgColor
            InputField.BackgroundTransparency = Iris._config.FrameBgTransparency
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClearTextOnFocus = false
            InputField.ZIndex = index
            InputField.LayoutOrder = index
            InputField.ClipsDescendants = true

            widgets.applyFrameStyle(InputField)
            widgets.applyTextStyle(InputField)
            widgets.UISizeConstraint(InputField, Vector2.xAxis)

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            return InputField
        end

        function generateInputScalar(dataType, components, defaultValue)
            local input = generateAbstract("Input", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget)
                    local Input = Instance.new("Frame")
                    Input.Name = "Iris_Input" .. dataType
                    Input.AutomaticSize = Enum.AutomaticSize.Y
                    Input.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
                    Input.BackgroundTransparency = 1
                    Input.BorderSizePixel = 0

                    widgets.UIListLayout(Input, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we add plus and minus buttons if there is only one box. This can be disabled through the argument.
                    local rightPadding = 0
                    local textHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

                    if components == 1 then
                        rightPadding = generateButtons(thisWidget, Input, textHeight)
                    end

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Iris._config.ContentWidth.Scale / components, (Iris._config.ContentWidth.Offset - (Iris._config.ItemInnerSpacing.X * (components - 1)) - rightPadding) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Iris._config.ItemInnerSpacing.X * (components - 1)) + rightPadding)
                    local lastComponentWidth = Iris._config.ContentWidth - totalWidth

                    -- we handle each component individually since they don't need to interact with each other.
                    for index = 1, components do
                        generateField(thisWidget, index, (index == components and lastComponentWidth or componentWidth), dataType).Parent = Input
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 7

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Input

                    return Input
                end,
                UpdateState = function(thisWidget)
                    local Input = thisWidget.Instance

                    for index = 1, components do
                        local InputField = Input:FindFirstChild("InputField" .. tostring(index))
                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end
                        InputField.Text = string.format(format, getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments))
                    end
                end,
            })
        end
    end

    do
        local PreviouseMouseXPosition = 0
        local AnyActiveDrag = false
        local ActiveDrag = nil
        local ActiveIndex = 0
        local ActiveDataType = ""

        local function updateActiveDrag()
            local currentMouseX = widgets.getMouseLocation().X
            local mouseXDelta = currentMouseX - PreviouseMouseXPosition
            PreviouseMouseXPosition = currentMouseX
            if AnyActiveDrag == false then
                return
            end
            if ActiveDrag == nil then
                return
            end

            local state = ActiveDrag.state.number
            if ActiveDataType == "Color3" or ActiveDataType == "Color4" then
                local Drag = ActiveDrag
                state = Drag.state.color
                if ActiveIndex == 4 then
                    state = Drag.state.transparency
                end
            end

            local increment = ActiveDrag.arguments.Increment and getValueByIndex(ActiveDrag.arguments.Increment, ActiveIndex, ActiveDrag.arguments) or defaultIncrements[ActiveDataType][ActiveIndex]
            increment = increment * (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) and 10 or 1
            increment = increment * (widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)) and 0.1 or 1
            -- we increase the speed for Color3 and Color4 since it's too slow because the increment argument needs to be low.
            increment = increment * (ActiveDataType == "Color3" or ActiveDataType == "Color4") and 5 or 1
            local value = getValueByIndex(state.value, ActiveIndex, ActiveDrag.arguments)
            local newValue = value + (mouseXDelta * increment)

            if ActiveDrag.arguments.Min ~= nil then
                newValue = math.max(newValue, getValueByIndex(ActiveDrag.arguments.Min, ActiveIndex, ActiveDrag.arguments))
            end
            if ActiveDrag.arguments.Max ~= nil then
                newValue = math.min(newValue, getValueByIndex(ActiveDrag.arguments.Max, ActiveIndex, ActiveDrag.arguments))
            end

            state:set(updateValueByIndex(state.value, ActiveIndex, newValue, ActiveDrag.arguments))
            ActiveDrag.lastNumberChangedTick = Iris._cycleTick + 1
        end

        local function DragMouseDown(thisWidget, dataTypes, index, x, y)
            local currentTime = widgets.getTime()
            local isTimeValid = currentTime - thisWidget.lastClickedTime < Iris._config.MouseDoubleClickTime
            local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if (isTimeValid and (Vector2.new(x, y) - thisWidget.lastClickedPosition).Magnitude < Iris._config.MouseDoubleClickMaxDist) or isCtrlHeld then
                thisWidget.state.editingText:set(index)
            else
                thisWidget.lastClickedTime = currentTime
                thisWidget.lastClickedPosition = Vector2.new(x, y)

                AnyActiveDrag = true
                ActiveDrag = thisWidget
                ActiveIndex = index
                ActiveDataType = dataTypes
                updateActiveDrag()
            end
        end

        widgets.registerEvent("InputChanged", function()
            if not Iris._started then
                return
            end
            updateActiveDrag()
        end)

        widgets.registerEvent("InputEnded", function(inputObject)
            if not Iris._started then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveDrag then
                AnyActiveDrag = false
                ActiveDrag = nil
                ActiveIndex = 0
            end
        end)

        local function generateField(thisWidget, index, componentSize, dataType)
            local DragField = Instance.new("TextButton")
            DragField.Name = "DragField" .. tostring(index)
            DragField.AutomaticSize = Enum.AutomaticSize.Y
            DragField.Size = componentSize
            DragField.BackgroundColor3 = Iris._config.FrameBgColor
            DragField.BackgroundTransparency = Iris._config.FrameBgTransparency
            DragField.Text = ""
            DragField.AutoButtonColor = false
            DragField.LayoutOrder = index
            DragField.ClipsDescendants = true

            widgets.applyFrameStyle(DragField)
            widgets.applyTextStyle(DragField)
            widgets.UISizeConstraint(DragField, Vector2.xAxis)

            DragField.TextXAlignment = Enum.TextXAlignment.Center

            widgets.applyInteractionHighlights("Background", DragField, DragField, {
                Color = Iris._config.FrameBgColor,
                Transparency = Iris._config.FrameBgTransparency,
                HoveredColor = Iris._config.FrameBgHoveredColor,
                HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                ActiveColor = Iris._config.FrameBgActiveColor,
                ActiveTransparency = Iris._config.FrameBgActiveTransparency,
            })

            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.Size = UDim2.fromScale(1, 1)
            InputField.BackgroundTransparency = 1
            InputField.ClearTextOnFocus = false
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClipsDescendants = true
            InputField.Visible = false

            widgets.applyFrameStyle(InputField, true)
            widgets.applyTextStyle(InputField)

            InputField.Parent = DragField

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            widgets.applyButtonDown(DragField, function(x, y)
                DragMouseDown(thisWidget, dataType, index, x, y)
            end)

            return DragField
        end

        function generateDragScalar(dataType, components, defaultValue)
            local input = generateAbstract("Drag", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget)
                    thisWidget.lastClickedTime = -1
                    thisWidget.lastClickedPosition = Vector2.zero

                    local Drag = Instance.new("Frame")
                    Drag.Name = "Iris_Drag" .. dataType
                    Drag.AutomaticSize = Enum.AutomaticSize.Y
                    Drag.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
                    Drag.BackgroundTransparency = 1
                    Drag.BorderSizePixel = 0

                    widgets.UIListLayout(Drag, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we add a color box if it is Color3 or Color4.
                    local rightPadding = 0
                    local textHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

                    if dataType == "Color3" or dataType == "Color4" then
                        rightPadding = rightPadding + Iris._config.ItemInnerSpacing.X + textHeight
                        local ColorBox = Instance.new("ImageLabel")
                        ColorBox.Name = "ColorBox"
                        ColorBox.Size = UDim2.fromOffset(textHeight, textHeight)
                        ColorBox.BorderSizePixel = 0
                        ColorBox.Image = widgets.ICONS.ALPHA_BACKGROUND_TEXTURE
                        ColorBox.ImageTransparency = 1
                        ColorBox.LayoutOrder = 5

                        widgets.applyFrameStyle(ColorBox, true)

                        ColorBox.Parent = Drag
                    end

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Iris._config.ContentWidth.Scale / components, (Iris._config.ContentWidth.Offset - (Iris._config.ItemInnerSpacing.X * (components - 1)) - rightPadding) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Iris._config.ItemInnerSpacing.X * (components - 1)) + rightPadding)
                    local lastComponentWidth = Iris._config.ContentWidth - totalWidth

                    for index = 1, components do
                        generateField(thisWidget, index, (index == components and UDim2.new(lastComponentWidth, Iris._config.ContentHeight) or UDim2.new(componentWidth, Iris._config.ContentHeight)), dataType).Parent = Drag
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 6

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Drag

                    return Drag
                end,
                UpdateState = function(thisWidget)
                    local Drag = thisWidget.Instance

                    local widget = thisWidget
                    for index = 1, components do
                        local state = thisWidget.state.number
                        if dataType == "Color3" or dataType == "Color4" then
                            state = widget.state.color
                            if index == 4 then
                                state = widget.state.transparency
                            end
                        end
                        local DragField = Drag:FindFirstChild("DragField" .. tostring(index))
                        local InputField = DragField.InputField
                        local value = getValueByIndex(state.value, index, thisWidget.arguments)
                        if (dataType == "Color3" or dataType == "Color4") and not widget.arguments.UseFloats then
                            value = math.round(value * 255)
                        end

                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end
                        DragField.Text = string.format(format, value)
                        InputField.Text = tostring(value)

                        if thisWidget.state.editingText.value == index then
                            InputField.Visible = true
                            InputField:CaptureFocus()
                            DragField.TextTransparency = 1
                        else
                            InputField.Visible = false
                            DragField.TextTransparency = Iris._config.TextTransparency
                        end
                    end

                    if dataType == "Color3" or dataType == "Color4" then
                        local ColorBox = Drag.ColorBox

                        ColorBox.BackgroundColor3 = widget.state.color.value

                        if dataType == "Color4" then
                            ColorBox.ImageTransparency = 1 - widget.state.transparency.value
                        end
                    end
                end,
            })
        end

        function generateColorDragScalar(dataType, ...)
            local defaultValues = { ... }
            local input = generateDragScalar(dataType, dataType == "Color4" and 4 or 3, defaultValues[1])

            return widgets.extend(input, {
                Args = {
                    ["Text"] = 1,
                    ["UseFloats"] = 2,
                    ["UseHSV"] = 3,
                    ["Format"] = 4,
                },
                Update = function(thisWidget)
                    local Input = thisWidget.Instance
                    local TextLabel = Input.TextLabel
                    TextLabel.Text = thisWidget.arguments.Text or string.format("Drag %s", dataType)

                    if thisWidget.arguments.Format and typeof(thisWidget.arguments.Format) ~= "table" then
                        thisWidget.arguments.Format = { thisWidget.arguments.Format }
                    elseif not thisWidget.arguments.Format then
                        if thisWidget.arguments.UseFloats then
                            thisWidget.arguments.Format = { "%.3f" }
                        else
                            thisWidget.arguments.Format = { "%d" }
                        end

                        thisWidget.arguments.Prefix = defaultPrefx[dataType .. (thisWidget.arguments.UseHSV and "_HSV" or "_RGB")]
                    end

                    thisWidget.arguments.Min = { 0, 0, 0, 0 }
                    thisWidget.arguments.Max = { 1, 1, 1, 1 }
                    thisWidget.arguments.Increment = { 0.001, 0.001, 0.001, 0.001 }

                    -- since the state values have changed display, we call an update. The check is because state is not
                    -- initialised on creation, so it would error otherwise.
                    if thisWidget.state then
                        thisWidget.state.color.lastChangeTick = Iris._cycleTick
                        if dataType == "Color4" then
                            thisWidget.state.transparency.lastChangeTick = Iris._cycleTick
                        end
                        Iris._widgets[thisWidget.type].UpdateState(thisWidget)
                    end
                end,
                GenerateState = function(thisWidget)
                    if thisWidget.state.color == nil then
                        thisWidget.state.color = Iris._widgetState(thisWidget, "color", defaultValues[1])
                    end
                    if dataType == "Color4" then
                        if thisWidget.state.transparency == nil then
                            thisWidget.state.transparency = Iris._widgetState(thisWidget, "transparency", defaultValues[2])
                        end
                    end
                    if thisWidget.state.editingText == nil then
                        thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", false)
                    end
                end,
            })
        end
    end

    do
        local AnyActiveSlider = false
        local ActiveSlider = nil
        local ActiveIndex = 0
        local ActiveDataType = ""

        local function updateActiveSlider()
            if AnyActiveSlider == false then
                return
            end
            if ActiveSlider == nil then
                return
            end

            local Slider = ActiveSlider.Instance
            local SliderField = Slider:FindFirstChild("SliderField" .. tostring(ActiveIndex))
            local GrabBar = SliderField.GrabBar

            local increment = ActiveSlider.arguments.Increment and getValueByIndex(ActiveSlider.arguments.Increment, ActiveIndex, ActiveSlider.arguments) or defaultIncrements[ActiveDataType][ActiveIndex]
            local min = ActiveSlider.arguments.Min and getValueByIndex(ActiveSlider.arguments.Min, ActiveIndex, ActiveSlider.arguments) or defaultMin[ActiveDataType][ActiveIndex]
            local max = ActiveSlider.arguments.Max and getValueByIndex(ActiveSlider.arguments.Max, ActiveIndex, ActiveSlider.arguments) or defaultMax[ActiveDataType][ActiveIndex]

            local GrabWidth = GrabBar.AbsoluteSize.X
            local Offset = widgets.getMouseLocation().X - (SliderField.AbsolutePosition.X - widgets.GuiOffset.X + GrabWidth / 2)
            local Ratio = Offset / (SliderField.AbsoluteSize.X - GrabWidth)
            local Positions = math.floor((max - min) / increment)
            local newValue = math.clamp(math.round(Ratio * Positions) * increment + min, min, max)

            ActiveSlider.state.number:set(updateValueByIndex(ActiveSlider.state.number.value, ActiveIndex, newValue, ActiveSlider.arguments))
            ActiveSlider.lastNumberChangedTick = Iris._cycleTick + 1
        end

        local function SliderMouseDown(thisWidget, dataType, index)
            local isCtrlHeld = widgets.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or widgets.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if isCtrlHeld then
                thisWidget.state.editingText:set(index)
            else
                AnyActiveSlider = true
                ActiveSlider = thisWidget
                ActiveIndex = index
                ActiveDataType = dataType
                updateActiveSlider()
            end
        end

        widgets.registerEvent("InputChanged", function()
            if not Iris._started then
                return
            end
            updateActiveSlider()
        end)

        widgets.registerEvent("InputEnded", function(inputObject)
            if not Iris._started then
                return
            end
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveSlider then
                AnyActiveSlider = false
                ActiveSlider = nil
                ActiveIndex = 0
                ActiveDataType = ""
            end
        end)

        local function generateField(thisWidget, index, componentSize, dataType)
            local SliderField = Instance.new("TextButton")
            SliderField.Name = "SliderField" .. tostring(index)
            SliderField.AutomaticSize = Enum.AutomaticSize.Y
            SliderField.Size = componentSize
            SliderField.BackgroundColor3 = Iris._config.FrameBgColor
            SliderField.BackgroundTransparency = Iris._config.FrameBgTransparency
            SliderField.Text = ""
            SliderField.AutoButtonColor = false
            SliderField.LayoutOrder = index
            SliderField.ClipsDescendants = true

            widgets.applyFrameStyle(SliderField)
            widgets.applyTextStyle(SliderField)
            widgets.UISizeConstraint(SliderField, Vector2.xAxis)

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.Size = UDim2.fromScale(1, 1)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 10
            OverlayText.ClipsDescendants = true

            widgets.applyTextStyle(OverlayText)

            OverlayText.TextXAlignment = Enum.TextXAlignment.Center

            OverlayText.Parent = SliderField

            widgets.applyInteractionHighlights("Background", SliderField, SliderField, {
                Color = Iris._config.FrameBgColor,
                Transparency = Iris._config.FrameBgTransparency,
                HoveredColor = Iris._config.FrameBgHoveredColor,
                HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                ActiveColor = Iris._config.FrameBgActiveColor,
                ActiveTransparency = Iris._config.FrameBgActiveTransparency,
            })

            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.Size = UDim2.fromScale(1, 1)
            InputField.BackgroundTransparency = 1
            InputField.ClearTextOnFocus = false
            InputField.TextTruncate = Enum.TextTruncate.AtEnd
            InputField.ClipsDescendants = true
            InputField.Visible = false

            widgets.applyFrameStyle(InputField, true)
            widgets.applyTextStyle(InputField)

            InputField.Parent = SliderField

            InputField.FocusLost:Connect(function()
                focusLost(thisWidget, InputField, index, dataType)
            end)

            InputField.Focused:Connect(function()
                -- this highlights the entire field
                InputField.CursorPosition = #InputField.Text + 1
                InputField.SelectionStart = 1

                thisWidget.state.editingText:set(index)
            end)

            widgets.applyButtonDown(SliderField, function()
                SliderMouseDown(thisWidget, dataType, index)
            end)

            local GrabBar = Instance.new("Frame")
            GrabBar.Name = "GrabBar"
            GrabBar.AnchorPoint = Vector2.new(0.5, 0.5)
            GrabBar.Position = UDim2.fromScale(0, 0.5)
            GrabBar.BackgroundColor3 = Iris._config.SliderGrabColor
            GrabBar.Transparency = Iris._config.SliderGrabTransparency
            GrabBar.BorderSizePixel = 0
            GrabBar.ZIndex = 5

            widgets.applyInteractionHighlights("Background", SliderField, GrabBar, {
                Color = Iris._config.SliderGrabColor,
                Transparency = Iris._config.SliderGrabTransparency,
                HoveredColor = Iris._config.SliderGrabColor,
                HoveredTransparency = Iris._config.SliderGrabTransparency,
                ActiveColor = Iris._config.SliderGrabActiveColor,
                ActiveTransparency = Iris._config.SliderGrabActiveTransparency,
            })

            if Iris._config.GrabRounding > 0 then
                widgets.UICorner(GrabBar, Iris._config.GrabRounding)
            end

            widgets.UISizeConstraint(GrabBar, Vector2.new(Iris._config.GrabMinSize, 0))

            GrabBar.Parent = SliderField

            return SliderField
        end

        function generateSliderScalar(dataType, components, defaultValue)
            local input = generateAbstract("Slider", dataType, components, defaultValue)

            return widgets.extend(input, {
                Generate = function(thisWidget)
                    local Slider = Instance.new("Frame")
                    Slider.Name = "Iris_Slider" .. dataType
                    Slider.AutomaticSize = Enum.AutomaticSize.Y
                    Slider.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
                    Slider.BackgroundTransparency = 1
                    Slider.BorderSizePixel = 0

                    widgets.UIListLayout(Slider, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

                    -- we divide the total area evenly between each field. This includes accounting for any additional boxes and the offset.
                    -- 4 pixels shorter, all for the sake of flush.
                    local componentWidth = UDim.new(Iris._config.ContentWidth.Scale / components, (Iris._config.ContentWidth.Offset - (Iris._config.ItemInnerSpacing.X * (components - 1))) / components)
                    local totalWidth = UDim.new(componentWidth.Scale * (components - 1), (componentWidth.Offset * (components - 1)) + (Iris._config.ItemInnerSpacing.X * (components - 1)))
                    local lastComponentWidth = Iris._config.ContentWidth - totalWidth

                    for index = 1, components do
                        generateField(thisWidget, index, (index == components and UDim2.new(lastComponentWidth, Iris._config.ContentHeight) or UDim2.new(componentWidth, Iris._config.ContentHeight)), dataType).Parent = Slider
                    end

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Name = "TextLabel"
                    TextLabel.AutomaticSize = Enum.AutomaticSize.XY
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.BorderSizePixel = 0
                    TextLabel.LayoutOrder = 5

                    widgets.applyTextStyle(TextLabel)

                    TextLabel.Parent = Slider

                    return Slider
                end,
                UpdateState = function(thisWidget)
                    local Slider = thisWidget.Instance

                    for index = 1, components do
                        local SliderField = Slider:FindFirstChild("SliderField" .. tostring(index))
                        local InputField = SliderField.InputField
                        local OverlayText = SliderField.OverlayText
                        local GrabBar = SliderField.GrabBar

                        local value = getValueByIndex(thisWidget.state.number.value, index, thisWidget.arguments)
                        local format = thisWidget.arguments.Format[index] or thisWidget.arguments.Format[1]
                        if thisWidget.arguments.Prefix then
                            format = thisWidget.arguments.Prefix[index] .. format
                        end

                        OverlayText.Text = string.format(format, value)
                        InputField.Text = tostring(value)

                        local increment = thisWidget.arguments.Increment and getValueByIndex(thisWidget.arguments.Increment, index, thisWidget.arguments) or defaultIncrements[dataType][index]
                        local min = thisWidget.arguments.Min and getValueByIndex(thisWidget.arguments.Min, index, thisWidget.arguments) or defaultMin[dataType][index]
                        local max = thisWidget.arguments.Max and getValueByIndex(thisWidget.arguments.Max, index, thisWidget.arguments) or defaultMax[dataType][index]

                        local SliderWidth = SliderField.AbsoluteSize.X
                        local PaddedWidth = SliderWidth - GrabBar.AbsoluteSize.X
                        local Ratio = (value - min) / (max - min)
                        local Positions = math.floor((max - min) / increment)
                        local ClampedRatio = math.clamp(math.floor((Ratio * Positions)) / Positions, 0, 1)
                        local PaddedRatio = ((PaddedWidth / SliderWidth) * ClampedRatio) + ((1 - (PaddedWidth / SliderWidth)) / 2)

                        GrabBar.Position = UDim2.fromScale(PaddedRatio, 0.5)

                        if thisWidget.state.editingText.value == index then
                            InputField.Visible = true
                            OverlayText.Visible = false
                            GrabBar.Visible = false
                            InputField:CaptureFocus()
                        else
                            InputField.Visible = false
                            OverlayText.Visible = true
                            GrabBar.Visible = true
                        end
                    end
                end,
            })
        end

        function generateEnumSliderScalar(enum, item)
            local input = generateSliderScalar("Enum", 1, item.Value)
            local valueToName = { string }

            for _, enumItem in pairs(enum:GetEnumItems()) do
                valueToName[enumItem.Value] = enumItem.Name
            end

            return widgets.extend(input, {
                Args = {
                    ["Text"] = 1,
                },
                Update = function(thisWidget)
                    local Input = thisWidget.Instance
                    local TextLabel = Input.TextLabel
                    TextLabel.Text = thisWidget.arguments.Text or "Input Enum"

                    thisWidget.arguments.Increment = 1
                    thisWidget.arguments.Min = 0
                    thisWidget.arguments.Max = #enum:GetEnumItems() - 1

                    local SliderField = Input:FindFirstChild("SliderField1")
                    local GrabBar = SliderField.GrabBar

                    local grabScaleSize = 1 / math.floor(#enum:GetEnumItems())

                    GrabBar.Size = UDim2.fromScale(grabScaleSize, 1)
                end,
                GenerateState = function(thisWidget)
                    if thisWidget.state.number == nil then
                        thisWidget.state.number = Iris._widgetState(thisWidget, "number", item.Value)
                    end
                    if thisWidget.state.enumItem == nil then
                        thisWidget.state.enumItem = Iris._widgetState(thisWidget, "enumItem", item)
                    end
                    if thisWidget.state.editingText == nil then
                        thisWidget.state.editingText = Iris._widgetState(thisWidget, "editingText", false)
                    end
                end,
            })
        end
    end

    do
        local inputNum = generateInputScalar("Num", 1, 0)
        inputNum.Args["NoButtons"] = 6
        Iris.WidgetConstructor("InputNum", inputNum)
    end
    Iris.WidgetConstructor("InputVector2", generateInputScalar("Vector2", 2, Vector2.zero))
    Iris.WidgetConstructor("InputVector3", generateInputScalar("Vector3", 3, Vector3.zero))
    Iris.WidgetConstructor("InputUDim", generateInputScalar("UDim", 2, UDim.new()))
    Iris.WidgetConstructor("InputUDim2", generateInputScalar("UDim2", 4, UDim2.new()))
    Iris.WidgetConstructor("InputRect", generateInputScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

    Iris.WidgetConstructor("DragNum", generateDragScalar("Num", 1, 0))
    Iris.WidgetConstructor("DragVector2", generateDragScalar("Vector2", 2, Vector2.zero))
    Iris.WidgetConstructor("DragVector3", generateDragScalar("Vector3", 3, Vector3.zero))
    Iris.WidgetConstructor("DragUDim", generateDragScalar("UDim", 2, UDim.new()))
    Iris.WidgetConstructor("DragUDim2", generateDragScalar("UDim2", 4, UDim2.new()))
    Iris.WidgetConstructor("DragRect", generateDragScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

    Iris.WidgetConstructor("InputColor3", generateColorDragScalar("Color3", Color3.fromRGB(0, 0, 0)))
    Iris.WidgetConstructor("InputColor4", generateColorDragScalar("Color4", Color3.fromRGB(0, 0, 0), 0))

    Iris.WidgetConstructor("SliderNum", generateSliderScalar("Num", 1, 0))
    Iris.WidgetConstructor("SliderVector2", generateSliderScalar("Vector2", 2, Vector2.zero))
    Iris.WidgetConstructor("SliderVector3", generateSliderScalar("Vector3", 3, Vector3.zero))
    Iris.WidgetConstructor("SliderUDim", generateSliderScalar("UDim", 2, UDim.new()))
    Iris.WidgetConstructor("SliderUDim2", generateSliderScalar("UDim2", 4, UDim2.new()))
    Iris.WidgetConstructor("SliderRect", generateSliderScalar("Rect", 4, Rect.new(0, 0, 0, 0)))

    Iris.WidgetConstructor("InputText", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["TextHint"] = 2,
            ["ReadOnly"] = 3,
            ["MultiLine"] = 4,
        },
        Events = {
            ["textChanged"] = {
                ["Init"] = function(thisWidget)
                    thisWidget.lastTextChangedTick = 0
                end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastTextChangedTick == Iris._cycleTick
                end,
            },
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local InputText = Instance.new("Frame")
            InputText.Name = "Iris_InputText"
            InputText.AutomaticSize = Enum.AutomaticSize.Y
            InputText.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            InputText.BackgroundTransparency = 1
            InputText.BorderSizePixel = 0
            widgets.UIListLayout(InputText, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local InputField = Instance.new("TextBox")
            InputField.Name = "InputField"
            InputField.AutomaticSize = Enum.AutomaticSize.Y
            InputField.Size = UDim2.new(Iris._config.ContentWidth, Iris._config.ContentHeight)
            InputField.BackgroundColor3 = Iris._config.FrameBgColor
            InputField.BackgroundTransparency = Iris._config.FrameBgTransparency
            InputField.Text = ""
            InputField.TextYAlignment = Enum.TextYAlignment.Top
            InputField.PlaceholderColor3 = Iris._config.TextDisabledColor
            InputField.ClearTextOnFocus = false
            InputField.ClipsDescendants = true

            widgets.applyFrameStyle(InputField)
            widgets.applyTextStyle(InputField)
            widgets.UISizeConstraint(InputField, Vector2.xAxis) -- prevents sizes beaking when getting too small.
            -- InputField.UIPadding.PaddingLeft = UDim.new(0, Iris._config.ItemInnerSpacing.X)
            -- InputField.UIPadding.PaddingRight = UDim.new(0, 0)
            InputField.Parent = InputText

            InputField.FocusLost:Connect(function()
                thisWidget.state.text:set(InputField.Text)
                thisWidget.lastTextChangedTick = Iris._cycleTick + 1
            end)

            local frameHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = InputText

            return InputText
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.text == nil then
                thisWidget.state.text = Iris._widgetState(thisWidget, "text", "")
            end
        end,
        Update = function(thisWidget)
            local InputText = thisWidget.Instance
            local TextLabel = InputText.TextLabel
            local InputField = InputText.InputField

            TextLabel.Text = thisWidget.arguments.Text or "Input Text"
            InputField.PlaceholderText = thisWidget.arguments.TextHint or ""
            InputField.TextEditable = not thisWidget.arguments.ReadOnly
            InputField.MultiLine = thisWidget.arguments.MultiLine or false
        end,
        UpdateState = function(thisWidget)
            local InputText = thisWidget.Instance
            local InputField = InputText.InputField

            InputField.Text = thisWidget.state.text.value
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })
end

end
-- ===== module: widgets.Combo =====
__modules["widgets.Combo"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("Selectable", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Index"] = 2,
            ["NoClick"] = 3,
        },
        Events = {
            ["selected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastSelectedTick == Iris._cycleTick
                end,
            },
            ["unselected"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastUnselectedTick == Iris._cycleTick
                end,
            },
            ["active"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.state.index.value == thisWidget.arguments.Index
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                local Selectable = thisWidget.Instance
                return Selectable.SelectableButton
            end),
            ["rightClicked"] = widgets.EVENTS.rightClick(function(thisWidget)
                local Selectable = thisWidget.Instance
                return Selectable.SelectableButton
            end),
            ["doubleClicked"] = widgets.EVENTS.doubleClick(function(thisWidget)
                local Selectable = thisWidget.Instance
                return Selectable.SelectableButton
            end),
            ["ctrlClicked"] = widgets.EVENTS.ctrlClick(function(thisWidget)
                local Selectable = thisWidget.Instance
                return Selectable.SelectableButton
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                local Selectable = thisWidget.Instance
                return Selectable.SelectableButton
            end),
        },
        Generate = function(thisWidget)
            local Selectable = Instance.new("Frame")
            Selectable.Name = "Iris_Selectable"
            Selectable.Size = UDim2.new(Iris._config.ItemWidth, UDim.new(0, Iris._config.TextSize + 2 * Iris._config.FramePadding.Y - Iris._config.ItemSpacing.Y))
            Selectable.BackgroundTransparency = 1
            Selectable.BorderSizePixel = 0

            local SelectableButton = Instance.new("TextButton")
            SelectableButton.Name = "SelectableButton"
            SelectableButton.Size = UDim2.new(1, 0, 0, Iris._config.TextSize + 2 * Iris._config.FramePadding.Y)
            SelectableButton.Position = UDim2.fromOffset(0, -bit32.rshift(Iris._config.ItemSpacing.Y, 1)) -- divide by 2
            SelectableButton.BackgroundColor3 = Iris._config.HeaderColor
            SelectableButton.ClipsDescendants = true

            widgets.applyFrameStyle(SelectableButton)
            widgets.applyTextStyle(SelectableButton)
            widgets.UISizeConstraint(SelectableButton, Vector2.xAxis)

            thisWidget.ButtonColors = {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderActiveColor,
                ActiveTransparency = Iris._config.HeaderActiveTransparency,
            }

            widgets.applyInteractionHighlights("Background", SelectableButton, SelectableButton, thisWidget.ButtonColors)

            widgets.applyButtonClick(SelectableButton, function()
                if thisWidget.arguments.NoClick ~= true then
                    if type(thisWidget.state.index.value) == "boolean" then
                        thisWidget.state.index:set(not thisWidget.state.index.value)
                    else
                        thisWidget.state.index:set(thisWidget.arguments.Index)
                    end
                end
            end)

            SelectableButton.Parent = Selectable

            return Selectable
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.index == nil then
                if thisWidget.arguments.Index ~= nil then
                    error("A shared state index is required for Iris.Selectables() with an Index argument.", 5)
                end
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", false)
            end
        end,
        Update = function(thisWidget)
            local Selectable = thisWidget.Instance
            local SelectableButton = Selectable.SelectableButton
            SelectableButton.Text = thisWidget.arguments.Text or "Selectable"
        end,
        UpdateState = function(thisWidget)
            local Selectable = thisWidget.Instance
            local SelectableButton = Selectable.SelectableButton

            if thisWidget.state.index.value == thisWidget.arguments.Index or thisWidget.state.index.value == true then
                thisWidget.ButtonColors.Transparency = Iris._config.HeaderTransparency
                SelectableButton.BackgroundTransparency = Iris._config.HeaderTransparency
                thisWidget.lastSelectedTick = Iris._cycleTick + 1
            else
                thisWidget.ButtonColors.Transparency = 1
                SelectableButton.BackgroundTransparency = 1
                thisWidget.lastUnselectedTick = Iris._cycleTick + 1
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })

    local AnyOpenedCombo = false
    local ComboOpenedTick = -1
    local OpenedCombo = nil
    local CachedContentSize = 0

    local function UpdateChildContainerTransform(thisWidget)
        local Combo = thisWidget.Instance
        local PreviewContainer = Combo.PreviewContainer
        local ChildContainer = thisWidget.ChildContainer

        local previewPosition = PreviewContainer.AbsolutePosition - widgets.GuiOffset
        local previewSize = PreviewContainer.AbsoluteSize
        local borderSize = Iris._config.PopupBorderSize
        local screenSize = ChildContainer.Parent.AbsoluteSize

        local absoluteContentSize = thisWidget.UIListLayout.AbsoluteContentSize.Y
        CachedContentSize = absoluteContentSize

        local contentsSize = absoluteContentSize + 2 * Iris._config.WindowPadding.Y

        local x = previewPosition.X
        local y = previewPosition.Y + previewSize.Y + borderSize
        local anchor = Vector2.zero
        local distanceToScreen = screenSize.Y - y

        -- Only extend upwards if we cannot fully extend downwards, and we are on the bottom half of the screen.
        --  i.e. there is more space upwards than there is downwards.
        if contentsSize > distanceToScreen and y > (screenSize.Y / 2) then
            y = previewPosition.Y - borderSize
            anchor = Vector2.yAxis
            distanceToScreen = y -- from 0 to the current position
        end

        ChildContainer.AnchorPoint = anchor
        ChildContainer.Position = UDim2.fromOffset(x, y)

        local height = math.min(contentsSize, distanceToScreen)
        ChildContainer.Size = UDim2.fromOffset(PreviewContainer.AbsoluteSize.X, height)
    end

    table.insert(Iris._postCycleCallbacks, function()
        if AnyOpenedCombo and OpenedCombo then
            local contentSize = OpenedCombo.UIListLayout.AbsoluteContentSize.Y
            if contentSize ~= CachedContentSize then
                UpdateChildContainerTransform(OpenedCombo)
            end
        end
    end)

    local function UpdateComboState(input)
        if not Iris._started then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseButton2 and input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseWheel then
            return
        end
        if AnyOpenedCombo == false or not OpenedCombo then
            return
        end
        if ComboOpenedTick == Iris._cycleTick then
            return
        end

        local MouseLocation = widgets.getMouseLocation()
        local Combo = OpenedCombo.Instance
        local PreviewContainer = Combo.PreviewContainer
        local ChildContainer = OpenedCombo.ChildContainer
        local rectMin = PreviewContainer.AbsolutePosition - widgets.GuiOffset
        local rectMax = PreviewContainer.AbsolutePosition - widgets.GuiOffset + PreviewContainer.AbsoluteSize
        if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
            return
        end

        rectMin = ChildContainer.AbsolutePosition - widgets.GuiOffset
        rectMax = ChildContainer.AbsolutePosition - widgets.GuiOffset + ChildContainer.AbsoluteSize
        if widgets.isPosInsideRect(MouseLocation, rectMin, rectMax) then
            return
        end

        OpenedCombo.state.isOpened:set(false)
    end

    widgets.registerEvent("InputBegan", UpdateComboState)

    widgets.registerEvent("InputChanged", UpdateComboState)

    Iris.WidgetConstructor("Combo", {
        hasState = true,
        hasChildren = true,
        Args = {
            ["Text"] = 1,
            ["NoButton"] = 2,
            ["NoPreview"] = 3,
        },
        Events = {
            ["opened"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastOpenedTick == Iris._cycleTick
                end,
            },
            ["closed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastClosedTick == Iris._cycleTick
                end,
            },
            ["changed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastChangedTick == Iris._cycleTick
                end,
            },
            ["clicked"] = widgets.EVENTS.click(function(thisWidget)
                local Combo = thisWidget.Instance
                return Combo.PreviewContainer
            end),
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local frameHeight = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y

            local Combo = Instance.new("Frame")
            Combo.Name = "Iris_Combo"
            Combo.AutomaticSize = Enum.AutomaticSize.Y
            Combo.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            Combo.BackgroundTransparency = 1
            Combo.BorderSizePixel = 0

            widgets.UIListLayout(Combo, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local PreviewContainer = Instance.new("TextButton")
            PreviewContainer.Name = "PreviewContainer"
            PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            PreviewContainer.Size = UDim2.new(Iris._config.ContentWidth, UDim.new(0, 0))
            PreviewContainer.BackgroundTransparency = 1
            PreviewContainer.Text = ""
            PreviewContainer.AutoButtonColor = false
            PreviewContainer.ZIndex = 2

            widgets.applyFrameStyle(PreviewContainer, true)
            widgets.UIListLayout(PreviewContainer, Enum.FillDirection.Horizontal, UDim.new(0, 0))
            widgets.UISizeConstraint(PreviewContainer, Vector2.new(frameHeight))

            PreviewContainer.Parent = Combo

            local PreviewLabel = Instance.new("TextLabel")
            PreviewLabel.Name = "PreviewLabel"
            PreviewLabel.AutomaticSize = Enum.AutomaticSize.Y
            PreviewLabel.Size = UDim2.new(UDim.new(1, 0), Iris._config.ContentHeight)
            PreviewLabel.BackgroundColor3 = Iris._config.FrameBgColor
            PreviewLabel.BackgroundTransparency = Iris._config.FrameBgTransparency
            PreviewLabel.BorderSizePixel = 0
            PreviewLabel.ClipsDescendants = true

            widgets.applyTextStyle(PreviewLabel)
            widgets.UIPadding(PreviewLabel, Iris._config.FramePadding)

            PreviewLabel.Parent = PreviewContainer

            local DropdownButton = Instance.new("TextLabel")
            DropdownButton.Name = "DropdownButton"
            DropdownButton.Size = UDim2.new(0, frameHeight, Iris._config.ContentHeight.Scale, math.max(Iris._config.ContentHeight.Offset, frameHeight))
            DropdownButton.BackgroundColor3 = Iris._config.ButtonColor
            DropdownButton.BackgroundTransparency = Iris._config.ButtonTransparency
            DropdownButton.BorderSizePixel = 0
            DropdownButton.Text = ""

            local padding = math.round(frameHeight * 0.2)
            local dropdownSize = frameHeight - 2 * padding

            local Dropdown = Instance.new("ImageLabel")
            Dropdown.Name = "Dropdown"
            Dropdown.AnchorPoint = Vector2.new(0.5, 0.5)
            Dropdown.Size = UDim2.fromOffset(dropdownSize, dropdownSize)
            Dropdown.Position = UDim2.fromScale(0.5, 0.5)
            Dropdown.BackgroundTransparency = 1
            Dropdown.BorderSizePixel = 0
            Dropdown.ImageColor3 = Iris._config.TextColor
            Dropdown.ImageTransparency = Iris._config.TextTransparency

            Dropdown.Parent = DropdownButton

            DropdownButton.Parent = PreviewContainer

            -- so this deviates from ImGui, but its a good UX change
            widgets.applyInteractionHighlightsWithMultiHighlightee("Background", PreviewContainer, {
                {
                    PreviewLabel,
                    {
                        Color = Iris._config.FrameBgColor,
                        Transparency = Iris._config.FrameBgTransparency,
                        HoveredColor = Iris._config.FrameBgHoveredColor,
                        HoveredTransparency = Iris._config.FrameBgHoveredTransparency,
                        ActiveColor = Iris._config.FrameBgActiveColor,
                        ActiveTransparency = Iris._config.FrameBgActiveTransparency,
                    },
                },
                {
                    DropdownButton,
                    {
                        Color = Iris._config.ButtonColor,
                        Transparency = Iris._config.ButtonTransparency,
                        HoveredColor = Iris._config.ButtonHoveredColor,
                        HoveredTransparency = Iris._config.ButtonHoveredTransparency,
                        -- Use hovered for active
                        ActiveColor = Iris._config.ButtonHoveredColor,
                        ActiveTransparency = Iris._config.ButtonHoveredTransparency,
                    },
                },
            })

            widgets.applyButtonClick(PreviewContainer, function()
                if AnyOpenedCombo and OpenedCombo ~= thisWidget then
                    return
                end
                thisWidget.state.isOpened:set(not thisWidget.state.isOpened.value)
            end)

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.X
            TextLabel.Size = UDim2.fromOffset(0, frameHeight)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = Combo

            local ChildContainer = Instance.new("ScrollingFrame")
            ChildContainer.Name = "ComboContainer"
            ChildContainer.BackgroundColor3 = Iris._config.PopupBgColor
            ChildContainer.BackgroundTransparency = Iris._config.PopupBgTransparency
            ChildContainer.BorderSizePixel = 0

            ChildContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ChildContainer.ScrollBarImageTransparency = Iris._config.ScrollbarGrabTransparency
            ChildContainer.ScrollBarImageColor3 = Iris._config.ScrollbarGrabColor
            ChildContainer.ScrollBarThickness = Iris._config.ScrollbarSize
            ChildContainer.CanvasSize = UDim2.fromScale(0, 0)
            ChildContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            ChildContainer.TopImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.MidImage = widgets.ICONS.BLANK_SQUARE
            ChildContainer.BottomImage = widgets.ICONS.BLANK_SQUARE

            -- appear over everything else
            ChildContainer.ClipsDescendants = true

            -- Unfortunatley, ScrollingFrame does not work with UICorner

            widgets.UIStroke(ChildContainer, Iris._config.WindowBorderSize, Iris._config.BorderColor, Iris._config.BorderTransparency)
            widgets.UIPadding(ChildContainer, Vector2.new(2, Iris._config.WindowPadding.Y))
            widgets.UISizeConstraint(ChildContainer, Vector2.new(100))

            local ChildContainerUIListLayout = widgets.UIListLayout(ChildContainer, Enum.FillDirection.Vertical, UDim.new(0, Iris._config.ItemSpacing.Y))
            ChildContainerUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

            local RootPopupScreenGui = Iris._rootInstance and Iris._rootInstance:WaitForChild("PopupScreenGui")
            ChildContainer.Parent = RootPopupScreenGui

            thisWidget.ChildContainer = ChildContainer
            thisWidget.UIListLayout = ChildContainerUIListLayout
            return Combo
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.index == nil then
                thisWidget.state.index = Iris._widgetState(thisWidget, "index", "No Selection")
            end
            if thisWidget.state.isOpened == nil then
                thisWidget.state.isOpened = Iris._widgetState(thisWidget, "isOpened", false)
            end

            thisWidget.state.index:onChange(function()
                thisWidget.lastChangedTick = Iris._cycleTick + 1
                if thisWidget.state.isOpened.value then
                    thisWidget.state.isOpened:set(false)
                end
            end)
        end,
        Update = function(thisWidget)
            local Iris_Combo = thisWidget.Instance
            local PreviewContainer = Iris_Combo.PreviewContainer
            local PreviewLabel = PreviewContainer.PreviewLabel
            local DropdownButton = PreviewContainer.DropdownButton
            local TextLabel = Iris_Combo.TextLabel

            TextLabel.Text = thisWidget.arguments.Text or "Combo"

            if thisWidget.arguments.NoButton then
                DropdownButton.Visible = false
                PreviewLabel.Size = UDim2.new(UDim.new(1, 0), PreviewLabel.Size.Height)
            else
                DropdownButton.Visible = true
                local DropdownButtonSize = Iris._config.TextSize + 2 * Iris._config.FramePadding.Y
                PreviewLabel.Size = UDim2.new(UDim.new(1, -DropdownButtonSize), PreviewLabel.Size.Height)
            end

            if thisWidget.arguments.NoPreview then
                PreviewLabel.Visible = false
                PreviewContainer.Size = UDim2.new(0, 0, 0, 0)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.XY
            else
                PreviewLabel.Visible = true
                PreviewContainer.Size = UDim2.new(Iris._config.ContentWidth, Iris._config.ContentHeight)
                PreviewContainer.AutomaticSize = Enum.AutomaticSize.Y
            end
        end,
        UpdateState = function(thisWidget)
            local Combo = thisWidget.Instance
            local ChildContainer = thisWidget.ChildContainer
            local PreviewContainer = Combo.PreviewContainer
            local PreviewLabel = PreviewContainer.PreviewLabel
            local DropdownButton = PreviewContainer.DropdownButton
            local Dropdown = DropdownButton.Dropdown

            if thisWidget.state.isOpened.value then
                AnyOpenedCombo = true
                OpenedCombo = thisWidget
                ComboOpenedTick = Iris._cycleTick
                thisWidget.lastOpenedTick = Iris._cycleTick + 1

                -- ImGui also does not do this, and the Arrow is always facing down
                Dropdown.Image = widgets.ICONS.RIGHT_POINTING_TRIANGLE
                ChildContainer.Visible = true

                UpdateChildContainerTransform(thisWidget)
            else
                if AnyOpenedCombo then
                    AnyOpenedCombo = false
                    OpenedCombo = nil
                    thisWidget.lastClosedTick = Iris._cycleTick + 1
                end
                Dropdown.Image = widgets.ICONS.DOWN_POINTING_TRIANGLE
                ChildContainer.Visible = false
            end

            local stateIndex = thisWidget.state.index.value
            PreviewLabel.Text = (typeof(stateIndex) == "EnumItem" and stateIndex.Name or tostring(stateIndex))
        end,
        ChildAdded = function(thisWidget, _thisChild)
            UpdateChildContainerTransform(thisWidget)
            return thisWidget.ChildContainer
        end,
        Discard = function(thisWidget)
            -- If we are discarding the current combo active, we need to hide it
            if OpenedCombo and OpenedCombo == thisWidget then
                OpenedCombo = nil
                AnyOpenedCombo = false
            end

            thisWidget.Instance:Destroy()
            thisWidget.ChildContainer:Destroy()
            widgets.discardState(thisWidget)
        end,
    })
end

end
-- ===== module: widgets.Plot =====
__modules["widgets.Plot"] = function()

return function(Iris, widgets)
    Iris.WidgetConstructor("ProgressBar", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Format"] = 2,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
            ["changed"] = {
                ["Init"] = function(_thisWidget) end,
                ["Get"] = function(thisWidget)
                    return thisWidget.lastChangedTick == Iris._cycleTick
                end,
            },
        },
        Generate = function(_thisWidget)
            local ProgressBar = Instance.new("Frame")
            ProgressBar.Name = "Iris_ProgressBar"
            ProgressBar.AutomaticSize = Enum.AutomaticSize.Y
            ProgressBar.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            ProgressBar.BackgroundTransparency = 1

            widgets.UIListLayout(ProgressBar, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Bar = Instance.new("Frame")
            Bar.Name = "Bar"
            Bar.AutomaticSize = Enum.AutomaticSize.Y
            Bar.Size = UDim2.new(Iris._config.ContentWidth, Iris._config.ContentHeight)
            Bar.BackgroundColor3 = Iris._config.FrameBgColor
            Bar.BackgroundTransparency = Iris._config.FrameBgTransparency
            Bar.BorderSizePixel = 0
            Bar.ClipsDescendants = true

            widgets.applyFrameStyle(Bar, true)

            Bar.Parent = ProgressBar

            local Progress = Instance.new("TextLabel")
            Progress.Name = "Progress"
            Progress.AutomaticSize = Enum.AutomaticSize.Y
            Progress.Size = UDim2.new(UDim.new(0, 0), Iris._config.ContentHeight)
            Progress.BackgroundColor3 = Iris._config.PlotHistogramColor
            Progress.BackgroundTransparency = Iris._config.PlotHistogramTransparency
            Progress.BorderSizePixel = 0

            widgets.applyTextStyle(Progress)
            widgets.UIPadding(Progress, Iris._config.FramePadding)
            widgets.UICorner(Progress, Iris._config.FrameRounding)

            Progress.Text = ""
            Progress.Parent = Bar

            local Value = Instance.new("TextLabel")
            Value.Name = "Value"
            Value.AutomaticSize = Enum.AutomaticSize.XY
            Value.Size = UDim2.new(UDim.new(0, 0), Iris._config.ContentHeight)
            Value.BackgroundTransparency = 1
            Value.BorderSizePixel = 0
            Value.ZIndex = 1

            widgets.applyTextStyle(Value)
            widgets.UIPadding(Value, Iris._config.FramePadding)

            Value.Parent = Bar

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.AnchorPoint = Vector2.new(0, 0.5)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.LayoutOrder = 1

            widgets.applyTextStyle(TextLabel)
            widgets.UIPadding(Value, Iris._config.FramePadding)

            TextLabel.Parent = ProgressBar

            return ProgressBar
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.progress == nil then
                thisWidget.state.progress = Iris._widgetState(thisWidget, "Progress", 0)
            end
        end,
        Update = function(thisWidget)
            local Progress = thisWidget.Instance
            local TextLabel = Progress.TextLabel
            local Bar = Progress.Bar
            local Value = Bar.Value

            if thisWidget.arguments.Format ~= nil and typeof(thisWidget.arguments.Format) == "string" then
                Value.Text = thisWidget.arguments.Format
            end

            TextLabel.Text = thisWidget.arguments.Text or "Progress Bar"
        end,
        UpdateState = function(thisWidget)
            local ProgressBar = thisWidget.Instance
            local Bar = ProgressBar.Bar
            local Progress = Bar.Progress
            local Value = Bar.Value

            local progress = math.clamp(thisWidget.state.progress.value, 0, 1)
            local totalWidth = Bar.AbsoluteSize.X
            local textWidth = Value.AbsoluteSize.X
            if totalWidth * (1 - progress) < textWidth then
                Value.AnchorPoint = Vector2.xAxis
                Value.Position = UDim2.fromScale(1, 0)
            else
                Value.AnchorPoint = Vector2.zero
                Value.Position = UDim2.fromScale(progress, 0)
            end

            Progress.Size = UDim2.new(UDim.new(progress, 0), Progress.Size.Height)
            if thisWidget.arguments.Format ~= nil and typeof(thisWidget.arguments.Format) == "string" then
                Value.Text = thisWidget.arguments.Format
            else
                Value.Text = string.format("%d%%", progress * 100)
            end
            thisWidget.lastChangedTick = Iris._cycleTick + 1
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end,
    })

    local function createLine(parent, index)
        local Block = Instance.new("Frame")
        Block.Name = tostring(index)
        Block.AnchorPoint = Vector2.new(0.5, 0.5)
        Block.BackgroundColor3 = Iris._config.PlotLinesColor
        Block.BackgroundTransparency = Iris._config.PlotLinesTransparency
        Block.BorderSizePixel = 0

        Block.Parent = parent

        return Block
    end

    local function clearLine(thisWidget)
        if thisWidget.HoveredLine then
            thisWidget.HoveredLine.BackgroundColor3 = Iris._config.PlotLinesColor
            thisWidget.HoveredLine.BackgroundTransparency = Iris._config.PlotLinesTransparency
            thisWidget.HoveredLine = false
            thisWidget.state.hovered:set(nil)
        end
    end

    local function updateLine(thisWidget, silent)
        local PlotLines = thisWidget.Instance
        local Background = PlotLines.Background
        local Plot = Background.Plot

        local mousePosition = widgets.getMouseLocation()

        local position = Plot.AbsolutePosition - widgets.GuiOffset
        local scale = (mousePosition.X - position.X) / Plot.AbsoluteSize.X
        local index = math.ceil(scale * #thisWidget.Lines)
        local line = thisWidget.Lines[index]

        if line then
            if line ~= thisWidget.HoveredLine and not silent then
                clearLine(thisWidget)
            end
            local start = thisWidget.state.values.value[index]
            local stop = thisWidget.state.values.value[index + 1]
            if start and stop then
                if math.floor(start) == start and math.floor(stop) == stop then
                    thisWidget.Tooltip.Text = ("%d: %d\n%d: %d"):format(index, start, index + 1, stop)
                else
                    thisWidget.Tooltip.Text = ("%d: %.3f\n%d: %.3f"):format(index, start, index + 1, stop)
                end
            end
            thisWidget.HoveredLine = line
            line.BackgroundColor3 = Iris._config.PlotLinesHoveredColor
            line.BackgroundTransparency = Iris._config.PlotLinesHoveredTransparency
            if silent then
                thisWidget.state.hovered.value = { start, stop }
            else
                thisWidget.state.hovered:set({ start, stop })
            end
        end
    end

    Iris.WidgetConstructor("PlotLines", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Height"] = 2,
            ["Min"] = 3,
            ["Max"] = 4,
            ["TextOverlay"] = 5,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local PlotLines = Instance.new("Frame")
            PlotLines.Name = "Iris_PlotLines"
            PlotLines.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            PlotLines.BackgroundTransparency = 1
            PlotLines.BorderSizePixel = 0

            widgets.UIListLayout(PlotLines, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Background = Instance.new("Frame")
            Background.Name = "Background"
            Background.Size = UDim2.new(Iris._config.ContentWidth, UDim.new(1, 0))
            Background.BackgroundColor3 = Iris._config.FrameBgColor
            Background.BackgroundTransparency = Iris._config.FrameBgTransparency
            widgets.applyFrameStyle(Background)

            Background.Parent = PlotLines

            local Plot = Instance.new("Frame")
            Plot.Name = "Plot"
            Plot.Size = UDim2.fromScale(1, 1)
            Plot.BackgroundTransparency = 1
            Plot.BorderSizePixel = 0
            Plot.ClipsDescendants = true

            Plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                thisWidget.state.values.lastChangeTick = Iris._cycleTick
                Iris._widgets.PlotLines.UpdateState(thisWidget)
            end)

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.AutomaticSize = Enum.AutomaticSize.XY
            OverlayText.AnchorPoint = Vector2.new(0.5, 0)
            OverlayText.Size = UDim2.fromOffset(0, 0)
            OverlayText.Position = UDim2.fromScale(0.5, 0)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 2

            widgets.applyTextStyle(OverlayText)

            OverlayText.Parent = Plot

            local Tooltip = Instance.new("TextLabel")
            Tooltip.Name = "Iris_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.XY
            Tooltip.Size = UDim2.fromOffset(0, 0)
            Tooltip.BackgroundColor3 = Iris._config.PopupBgColor
            Tooltip.BackgroundTransparency = Iris._config.PopupBgTransparency
            Tooltip.BorderSizePixel = 0
            Tooltip.Visible = false

            widgets.applyTextStyle(Tooltip)
            widgets.UIStroke(Tooltip, Iris._config.PopupBorderSize, Iris._config.BorderActiveColor, Iris._config.BorderActiveTransparency)
            widgets.UIPadding(Tooltip, Iris._config.WindowPadding)
            if Iris._config.PopupRounding > 0 then
                widgets.UICorner(Tooltip, Iris._config.PopupRounding)
            end

            local popup = Iris._rootInstance and Iris._rootInstance:FindFirstChild("PopupScreenGui")
            Tooltip.Parent = popup and popup:FindFirstChild("TooltipContainer")

            thisWidget.Tooltip = Tooltip

            widgets.applyMouseMoved(Plot, function()
                updateLine(thisWidget)
            end)

            widgets.applyMouseLeave(Plot, function()
                clearLine(thisWidget)
            end)

            Plot.Parent = Background

            thisWidget.Lines = {}
            thisWidget.HoveredLine = false

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.Size = UDim2.fromOffset(0, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.ZIndex = 3
            TextLabel.LayoutOrder = 3

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = PlotLines

            return PlotLines
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.values == nil then
                thisWidget.state.values = Iris._widgetState(thisWidget, "values", { 0, 1 })
            end
            if thisWidget.state.hovered == nil then
                thisWidget.state.hovered = Iris._widgetState(thisWidget, "hovered", nil)
            end
        end,
        Update = function(thisWidget)
            local PlotLines = thisWidget.Instance
            local TextLabel = PlotLines.TextLabel
            local Background = PlotLines.Background
            local Plot = Background.Plot
            local OverlayText = Plot.OverlayText

            TextLabel.Text = thisWidget.arguments.Text or "Plot Lines"
            OverlayText.Text = thisWidget.arguments.TextOverlay or ""
            PlotLines.Size = UDim2.new(1, 0, 0, thisWidget.arguments.Height or 0)
        end,
        UpdateState = function(thisWidget)
            if thisWidget.state.hovered.lastChangeTick == Iris._cycleTick then
                if thisWidget.state.hovered.value then
                    thisWidget.Tooltip.Visible = true
                else
                    thisWidget.Tooltip.Visible = false
                end
            end

            if thisWidget.state.values.lastChangeTick == Iris._cycleTick then
                local PlotLines = thisWidget.Instance
                local Background = PlotLines.Background
                local Plot = Background.Plot

                local values = thisWidget.state.values.value
                local count = #values - 1
                local numLines = #thisWidget.Lines

                local min = thisWidget.arguments.Min or math.huge
                local max = thisWidget.arguments.Max or -math.huge

                if min == nil or max == nil then
                    for _, value in pairs(values) do
                        min = math.min(min, value)
                        max = math.max(max, value)
                    end
                end

                -- add or remove blocks depending on how many are needed
                if numLines < count then
                    for index = numLines + 1, count do
                        table.insert(thisWidget.Lines, createLine(Plot, index))
                    end
                elseif numLines > count then
                    for _ = count + 1, numLines do
                        local line = table.remove(thisWidget.Lines)
                        if line then
                            line:Destroy()
                        end
                    end
                end

                local range = max - min
                local size = Plot.AbsoluteSize

                for index = 1, count do
                    local start = values[index]
                    local stop = values[index + 1]
                    local a = size * Vector2.new((index - 1) / count, (max - start) / range)
                    local b = size * Vector2.new(index / count, (max - stop) / range)
                    local position = (a + b) / 2

                    thisWidget.Lines[index].Size = UDim2.fromOffset((b - a).Magnitude + 1, 1)
                    thisWidget.Lines[index].Position = UDim2.fromOffset(position.X, position.Y)
                    thisWidget.Lines[index].Rotation = math.atan2(b.Y - a.Y, b.X - a.X) * (180 / math.pi)
                end

                -- only update the hovered block if it exists.
                if thisWidget.HoveredLine then
                    updateLine(thisWidget, true)
                end
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            thisWidget.Tooltip:Destroy()
            widgets.discardState(thisWidget)
        end,
    })

    local function createBlock(parent, index)
        local Block = Instance.new("Frame")
        Block.Name = tostring(index)
        Block.BackgroundColor3 = Iris._config.PlotHistogramColor
        Block.BackgroundTransparency = Iris._config.PlotHistogramTransparency
        Block.BorderSizePixel = 0

        Block.Parent = parent

        return Block
    end

    local function clearBlock(thisWidget)
        if thisWidget.HoveredBlock then
            thisWidget.HoveredBlock.BackgroundColor3 = Iris._config.PlotHistogramColor
            thisWidget.HoveredBlock.BackgroundTransparency = Iris._config.PlotHistogramTransparency
            thisWidget.HoveredBlock = false
            thisWidget.state.hovered:set(nil)
        end
    end

    local function updateBlock(thisWidget, silent)
        local PlotHistogram = thisWidget.Instance
        local Background = PlotHistogram.Background
        local Plot = Background.Plot

        local mousePosition = widgets.getMouseLocation()

        local position = Plot.AbsolutePosition - widgets.GuiOffset
        local scale = (mousePosition.X - position.X) / Plot.AbsoluteSize.X
        local index = math.ceil(scale * #thisWidget.Blocks)
        local block = thisWidget.Blocks[index]

        if block then
            if block ~= thisWidget.HoveredBlock and not silent then
                clearBlock(thisWidget)
            end
            local value = thisWidget.state.values.value[index]
            if value then
                thisWidget.Tooltip.Text = (math.floor(value) == value and ("%d: %d"):format(index, value) or ("%d: %.3f"):format(index, value))
            end
            thisWidget.HoveredBlock = block
            block.BackgroundColor3 = Iris._config.PlotHistogramHoveredColor
            block.BackgroundTransparency = Iris._config.PlotHistogramHoveredTransparency
            if silent then
                thisWidget.state.hovered.value = value
            else
                thisWidget.state.hovered:set(value)
            end
        end
    end

    Iris.WidgetConstructor("PlotHistogram", {
        hasState = true,
        hasChildren = false,
        Args = {
            ["Text"] = 1,
            ["Height"] = 2,
            ["Min"] = 3,
            ["Max"] = 4,
            ["TextOverlay"] = 5,
            ["BaseLine"] = 6,
        },
        Events = {
            ["hovered"] = widgets.EVENTS.hover(function(thisWidget)
                return thisWidget.Instance
            end),
        },
        Generate = function(thisWidget)
            local PlotHistogram = Instance.new("Frame")
            PlotHistogram.Name = "Iris_PlotHistogram"
            PlotHistogram.Size = UDim2.new(Iris._config.ItemWidth, UDim.new())
            PlotHistogram.BackgroundTransparency = 1
            PlotHistogram.BorderSizePixel = 0

            widgets.UIListLayout(PlotHistogram, Enum.FillDirection.Horizontal, UDim.new(0, Iris._config.ItemInnerSpacing.X)).VerticalAlignment = Enum.VerticalAlignment.Center

            local Background = Instance.new("Frame")
            Background.Name = "Background"
            Background.Size = UDim2.new(Iris._config.ContentWidth, UDim.new(1, 0))
            Background.BackgroundColor3 = Iris._config.FrameBgColor
            Background.BackgroundTransparency = Iris._config.FrameBgTransparency
            widgets.applyFrameStyle(Background)

            local UIPadding = (Background).UIPadding
            UIPadding.PaddingRight = UDim.new(0, Iris._config.FramePadding.X - 1)

            Background.Parent = PlotHistogram

            local Plot = Instance.new("Frame")
            Plot.Name = "Plot"
            Plot.Size = UDim2.fromScale(1, 1)
            Plot.BackgroundTransparency = 1
            Plot.BorderSizePixel = 0
            Plot.ClipsDescendants = true

            local OverlayText = Instance.new("TextLabel")
            OverlayText.Name = "OverlayText"
            OverlayText.AutomaticSize = Enum.AutomaticSize.XY
            OverlayText.AnchorPoint = Vector2.new(0.5, 0)
            OverlayText.Size = UDim2.fromOffset(0, 0)
            OverlayText.Position = UDim2.fromScale(0.5, 0)
            OverlayText.BackgroundTransparency = 1
            OverlayText.BorderSizePixel = 0
            OverlayText.ZIndex = 2

            widgets.applyTextStyle(OverlayText)

            OverlayText.Parent = Plot

            local Tooltip = Instance.new("TextLabel")
            Tooltip.Name = "Iris_Tooltip"
            Tooltip.AutomaticSize = Enum.AutomaticSize.XY
            Tooltip.Size = UDim2.fromOffset(0, 0)
            Tooltip.BackgroundColor3 = Iris._config.PopupBgColor
            Tooltip.BackgroundTransparency = Iris._config.PopupBgTransparency
            Tooltip.BorderSizePixel = 0
            Tooltip.Visible = false

            widgets.applyTextStyle(Tooltip)
            widgets.UIStroke(Tooltip, Iris._config.PopupBorderSize, Iris._config.BorderActiveColor, Iris._config.BorderActiveTransparency)
            widgets.UIPadding(Tooltip, Iris._config.WindowPadding)
            if Iris._config.PopupRounding > 0 then
                widgets.UICorner(Tooltip, Iris._config.PopupRounding)
            end

            local popup = Iris._rootInstance and Iris._rootInstance:FindFirstChild("PopupScreenGui")
            Tooltip.Parent = popup and popup:FindFirstChild("TooltipContainer")

            thisWidget.Tooltip = Tooltip

            widgets.applyMouseMoved(Plot, function()
                updateBlock(thisWidget)
            end)

            widgets.applyMouseLeave(Plot, function()
                clearBlock(thisWidget)
            end)

            Plot.Parent = Background

            thisWidget.Blocks = {}
            thisWidget.HoveredBlock = false

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Name = "TextLabel"
            TextLabel.AutomaticSize = Enum.AutomaticSize.XY
            TextLabel.Size = UDim2.fromOffset(0, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.BorderSizePixel = 0
            TextLabel.ZIndex = 3
            TextLabel.LayoutOrder = 3

            widgets.applyTextStyle(TextLabel)

            TextLabel.Parent = PlotHistogram

            return PlotHistogram
        end,
        GenerateState = function(thisWidget)
            if thisWidget.state.values == nil then
                thisWidget.state.values = Iris._widgetState(thisWidget, "values", { 1 })
            end     
            if thisWidget.state.hovered == nil then
                thisWidget.state.hovered = Iris._widgetState(thisWidget, "hovered", nil)
            end     
        end,
        Update = function(thisWidget)
            local PlotLines = thisWidget.Instance
            local TextLabel = PlotLines.TextLabel
            local Background = PlotLines.Background
            local Plot = Background.Plot
            local OverlayText = Plot.OverlayText

            TextLabel.Text = thisWidget.arguments.Text or "Plot Histogram"
            OverlayText.Text = thisWidget.arguments.TextOverlay or ""
            PlotLines.Size = UDim2.new(1, 0, 0, thisWidget.arguments.Height or 0)
        end,
        UpdateState = function(thisWidget)
            if thisWidget.state.hovered.lastChangeTick == Iris._cycleTick then
                if thisWidget.state.hovered.value then
                    thisWidget.Tooltip.Visible = true
                else
                    thisWidget.Tooltip.Visible = false
                end
            end

            if thisWidget.state.values.lastChangeTick == Iris._cycleTick then
                local PlotHistogram = thisWidget.Instance
                local Background = PlotHistogram.Background
                local Plot = Background.Plot

                local values = thisWidget.state.values.value
                local count = #values
                local numBlocks = #thisWidget.Blocks

                local min = thisWidget.arguments.Min or math.huge
                local max = thisWidget.arguments.Max or -math.huge
                local baseline = thisWidget.arguments.BaseLine or 0

                if min == nil or max == nil then
                    for _, value in pairs(values) do
                        min = math.min(min or value, value)
                        max = math.max(max or value, value)
                    end
                end

                -- add or remove blocks depending on how many are needed
                if numBlocks < count then
                    for index = numBlocks + 1, count do
                        table.insert(thisWidget.Blocks, createBlock(Plot, index))                    
                    end
                elseif numBlocks > count then
                    for _ = count + 1, numBlocks do
                        local block= table.remove(thisWidget.Blocks)
                        if block then
                            block:Destroy()
                        end
                    end
                end

                local range = max - min
                local width = UDim.new(1 / count, -1)
                for index = 1, count do
                    local num = values[index]
                    if num >= 0 then
                        thisWidget.Blocks[index].Size = UDim2.new(width, UDim.new((num - baseline) / range))
                        thisWidget.Blocks[index].Position = UDim2.fromScale((index - 1) / count, (max - num) / range)
                    else
                        thisWidget.Blocks[index].Size = UDim2.new(width, UDim.new((baseline - num) / range))
                        thisWidget.Blocks[index].Position = UDim2.fromScale((index - 1) / count, (max - baseline) / range)
                    end
                end

                -- only update the hovered block if it exists.
                if thisWidget.HoveredBlock then
                    updateBlock(thisWidget, true)
                end
            end
        end,
        Discard = function(thisWidget)
            thisWidget.Instance:Destroy()
            thisWidget.Tooltip:Destroy()
            widgets.discardState(thisWidget)            
        end,
    })
end

end
-- ===== module: widgets.Table =====
__modules["widgets.Table"] = function()

-- Tables need an overhaul.

return function(Iris, widgets)
    local Tables = {}
    local TableMinWidths = {}
    local AnyActiveTable = false
    local ActiveTable = nil
    local ActiveColumn = 0
    local ActiveLeftWidth = -1
    local ActiveRightWidth = -1
    local MousePositionX = 0

    local function CalculateMinColumnWidth(thisWidget, index)
        local width = 0
        for _, row in pairs(thisWidget._cellInstances) do
            local cell = row[index]
            for _, child in pairs(cell:GetChildren()) do
                if child:IsA("GuiObject") then
                    width = math.max(width, child.AbsoluteSize.X)
                end
            end
        end

        thisWidget._minWidths[index] = width + 2 * Iris._config.CellPadding.X
    end

    table.insert(Iris._postCycleCallbacks, function()
        for _, thisWidget in pairs(Tables) do
            for rowIndex, cycleTick in pairs(thisWidget._rowCycles) do
                if cycleTick < Iris._cycleTick - 1 then
                    local Row = thisWidget._rowInstances[rowIndex]
                    local RowBorder = thisWidget._rowBorders[rowIndex - 1]
                    if Row ~= nil then
                        Row:Destroy()
                    end
                    if RowBorder ~= nil then
                        RowBorder:Destroy()
                    end
                    thisWidget._rowInstances[rowIndex] = nil
                    thisWidget._rowBorders[rowIndex - 1] = nil
                    thisWidget._cellInstances[rowIndex] = nil
                    thisWidget._rowCycles[rowIndex] = nil
                end
            end

            thisWidget._rowIndex = 1
            thisWidget._columnIndex = 1

            -- update the border container size to be the same, albeit *every* frame!
            local Table = thisWidget.Instance
            local BorderContainer = Table.BorderContainer
            BorderContainer.Size = UDim2.new(1, 0, 0, thisWidget._rowContainer.AbsoluteSize.Y)
            thisWidget._columnBorders[0].Size = UDim2.fromOffset(5, thisWidget._rowContainer.AbsoluteSize.Y)
        end

        for thisWidget, columns in pairs(TableMinWidths) do
            local refresh = false
            for column, _ in pairs(columns) do
                CalculateMinColumnWidth(thisWidget, column)
                refresh = true
            end
            if refresh then
                table.clear(columns)
                Iris._widgets["Table"].UpdateState(thisWidget)
            end
        end
    end)

    local function UpdateActiveColumn()
        if AnyActiveTable == false or ActiveTable == nil then
            return
        end

        local widths = ActiveTable.state.widths
        local NumColumns = ActiveTable.arguments.NumColumns
        local Table = ActiveTable.Instance
        local BorderContainer = Table.BorderContainer
        local Fixed = ActiveTable.arguments.FixedWidth
        local Padding = 2 * Iris._config.CellPadding.X

        if ActiveLeftWidth == -1 then
            ActiveLeftWidth = widths.value[ActiveColumn]
            if ActiveLeftWidth == 0 then
                ActiveLeftWidth = Padding / Table.AbsoluteSize.X
            end
            ActiveRightWidth = widths.value[ActiveColumn + 1] or -1
            if ActiveRightWidth == 0 then
                ActiveRightWidth = Padding / Table.AbsoluteSize.X
            end
        end

        local BorderX = Table.AbsolutePosition.X


        if ActiveColumn == 1 then
            LeftX = 0
        else
            LeftX = math.floor(BorderContainer:FindFirstChild(string.format("Border_%s", ActiveColumn - 1)).AbsolutePosition.X + 3 - BorderX)
        end
        if ActiveColumn >= NumColumns - 1 then
            RightX = Table.AbsoluteSize.X
        else
            RightX = math.floor(BorderContainer:FindFirstChild(string.format("Border_%s", ActiveColumn + 1)).AbsolutePosition.X + 3 - BorderX)
        end

        local TableX = BorderX - widgets.GuiOffset.X
        local DeltaX = math.clamp(widgets.getMouseLocation().X, LeftX + TableX + Padding, RightX + TableX - Padding) - MousePositionX
        local LeftOffset = (MousePositionX - TableX) - LeftX
        local LeftRatio = ActiveLeftWidth / LeftOffset

        if Fixed then
            widths.value[ActiveColumn] = math.clamp(math.round(ActiveLeftWidth + DeltaX), Padding, Table.AbsoluteSize.X - LeftX)
        else
            local Change = LeftRatio * DeltaX
            widths.value[ActiveColumn] = math.clamp(ActiveLeftWidth + Change, 0, (RightX - LeftX - Padding) / Table.AbsoluteSize.X)
            if ActiveColumn < NumColumns then
                widths.value[ActiveColumn + 1] = math.clamp(ActiveRightWidth - Change, 0, 1)
            end
        end

        widths:set(widths.value, true)
    end

    local function ColumnMouseDown(thisWidget, index)
        AnyActiveTable = true
        ActiveTable = thisWidget
        ActiveColumn = index
        ActiveLeftWidth = -1
        ActiveRightWidth = -1
        MousePositionX = widgets.getMouseLocation().X
    end

    widgets.registerEvent("InputChanged", function()
        if not Iris._started then
            return
        end
        UpdateActiveColumn()
    end)

    widgets.registerEvent("InputEnded", function(inputObject)
        if not Iris._started then
            return
        end
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and AnyActiveTable then
            AnyActiveTable = false
            ActiveTable = nil
            ActiveColumn = 0
            ActiveLeftWidth = -1
            ActiveRightWidth = -1
            MousePositionX = 0
        end
    end)

    local function GenerateCell(_thisWidget, index, width, header)

        if header then
            Cell = Instance.new("TextButton")
            Cell.Text = ""
            Cell.AutoButtonColor = false
        else
            Cell = (Instance.new("Frame"))
        end
        Cell.Name = string.format("Cell_%s", index)
        Cell.AutomaticSize = Enum.AutomaticSize.Y
        Cell.Size = UDim2.new(width, UDim.new())
        Cell.BackgroundTransparency = 1
        Cell.ZIndex = index
        Cell.LayoutOrder = index
        Cell.ClipsDescendants = true

        if header then
            widgets.applyInteractionHighlights("Background", Cell, Cell, {
                Color = Iris._config.HeaderColor,
                Transparency = 1,
                HoveredColor = Iris._config.HeaderHoveredColor,
                HoveredTransparency = Iris._config.HeaderHoveredTransparency,
                ActiveColor = Iris._config.HeaderActiveColor,
                ActiveTransparency = Iris._config.HeaderActiveTransparency,
            })
        end

        widgets.UIPadding(Cell, Iris._config.CellPadding)
        widgets.UIListLayout(Cell, Enum.FillDirection.Vertical, UDim.new())
        widgets.UISizeConstraint(Cell, Vector2.new(2 * Iris._config.CellPadding.X, 0))

        return Cell
    end

    local function GenerateColumnBorder(thisWidget, index, style)
        local Border = Instance.new("ImageButton")
        Border.Name = string.format("Border_%s", index)
        Border.Size = UDim2.new(0, 5, 1, 0)
        Border.BackgroundTransparency = 1
        Border.Image = ""
        Border.ImageTransparency = 1
        Border.AutoButtonColor = false
        Border.ZIndex = index
        Border.LayoutOrder = 2 * index

        local offset = (index == thisWidget.arguments.NumColumns and 3 or 2)

        local Line = Instance.new("Frame")
        Line.Name = "Line"
        Line.Size = UDim2.new(0, 1, 1, 0)
        Line.Position = UDim2.fromOffset(offset, 0)
        Line.BackgroundColor3 = Iris._config[string.format("TableBorder%sColor", style)]
        Line.BackgroundTransparency = Iris._config[string.format("TableBorder%sTransparency", style)]
        Line.BorderSizePixel = 0

        Line.Parent = Border

        local Hover = Instance.new("Frame")
        Hover.Name = "Hover"
        Hover.Position = UDim2.fromOffset(offset, 0)
        Hover.Size = UDim2.new(0, 1, 1, 0)
        Hover.BackgroundColor3 = Iris._config[string.format("TableBorder%sColor", style)]
        Hover.BackgroundTransparency = Iris._config[string.format("TableBorder%sTransparency", style)]
        Hover.BorderSizePixel = 0

        Hover.Visible = thisWidget.arguments.Resizable

        Hover.Parent = Border

        widgets.applyInteractionHighlights("Background", Border, Hover, {
            Color = Iris._config.ResizeGripColor,
            Transparency = 1,
            HoveredColor = Iris._config.ResizeGripHoveredColor,
            HoveredTransparency = Iris._config.ResizeGripHoveredTransparency,
            ActiveColor = Iris._config.ResizeGripActiveColor,
            ActiveTransparency = Iris._config.ResizeGripActiveTransparency,
        })

        widgets.applyButtonDown(Border, function()
            if thisWidget.arguments.Resizable then
                ColumnMouseDown(thisWidget, index)
            end
        end)

        return Border
    end

    -- creates a new row and all columns, and adds all to the table's row and cell instance tables, but does not parent
    local function GenerateRow(thisWidget, index)
        local Row = Instance.new("Frame")
        Row.Name = string.format("Row_%s", index)
        Row.AutomaticSize = Enum.AutomaticSize.Y
        Row.Size = UDim2.fromScale(1, 0)
        if index == 0 then
            Row.BackgroundColor3 = Iris._config.TableHeaderColor
            Row.BackgroundTransparency = Iris._config.TableHeaderTransparency
        elseif thisWidget.arguments.RowBackground == true then
            if (index % 2) == 0 then
                Row.BackgroundColor3 = Iris._config.TableRowBgAltColor
                Row.BackgroundTransparency = Iris._config.TableRowBgAltTransparency
            else
                Row.BackgroundColor3 = Iris._config.TableRowBgColor
                Row.BackgroundTransparency = Iris._config.TableRowBgTransparency
            end
        else
            Row.BackgroundTransparency = 1
        end
        Row.BorderSizePixel = 0
        Row.ZIndex = 2 * index - 1
        Row.LayoutOrder = 2 * index - 1
        Row.ClipsDescendants = true

        widgets.UIListLayout(Row, Enum.FillDirection.Horizontal, UDim.new())

        thisWidget._cellInstances[index] = table.create(thisWidget.arguments.NumColumns)
        for columnIndex = 1, thisWidget.arguments.NumColumns do
            local Cell = GenerateCell(thisWidget, columnIndex, thisWidget._widths[columnIndex], index == 0)
            Cell.Parent = Row
            thisWidget._cellInstances[index][columnIndex] = Cell
        end

        thisWidget._rowInstances[index] = Row

        return Row
    end

    local function GenerateRowBorder(_thisWidget, index, style)
        local Border = Instance.new("Frame")
        Border.Name = string.format("Border_%s", index)
        Border.Size = UDim2.fromScale(1, 0)
        Border.BackgroundTransparency = 1
        Border.ZIndex = 2 * index
        Border.LayoutOrder = 2 * index

        local Line = Instance.new("Frame")
        Line.Name = "Line"
        Line.AnchorPoint = Vector2.new(0, 0.5)
        Line.Size = UDim2.new(1, 0, 0, 1)
        Line.BackgroundColor3 = Iris._config[string.format("TableBorder%sColor", style)]
        Line.BackgroundTransparency = Iris._config[string.format("TableBorder%sTransparency", style)]
        Line.BorderSizePixel = 0

        Line.Parent = Border

        return Border
    end

    Iris.WidgetConstructor("Table", {
        hasState = true,
        hasChildren = true,
        Args = {
            NumColumns = 1,
            Header = 2,
            RowBackground = 3,
            OuterBorders = 4,
            InnerBorders = 5,
            Resizable = 6,
            FixedWidth = 7,
            ProportionalWidth = 8,
            LimitTableWidth = 9,
        },
        Events = {},
        Generate = function(thisWidget)
            Tables[thisWidget.ID] = thisWidget
            TableMinWidths[thisWidget] = {}

            local Table = Instance.new("Frame")
            Table.Name = "Iris_Table"
            Table.AutomaticSize = Enum.AutomaticSize.Y
            Table.Size = UDim2.fromScale(1, 0)
            Table.BackgroundTransparency = 1

            local RowContainer = Instance.new("Frame")
            RowContainer.Name = "RowContainer"
            RowContainer.AutomaticSize = Enum.AutomaticSize.Y
            RowContainer.Size = UDim2.fromScale(1, 0)
            RowContainer.BackgroundTransparency = 1
            RowContainer.ZIndex = 1

            widgets.UISizeConstraint(RowContainer)
            widgets.UIListLayout(RowContainer, Enum.FillDirection.Vertical, UDim.new())

            RowContainer.Parent = Table
			thisWidget._rowContainer = RowContainer

            local BorderContainer = Instance.new("Frame")
            BorderContainer.Name = "BorderContainer"
            BorderContainer.Size = UDim2.fromScale(1, 1)
            BorderContainer.BackgroundTransparency = 1
            BorderContainer.ZIndex = 2
            BorderContainer.ClipsDescendants = true

            widgets.UISizeConstraint(BorderContainer)            
            widgets.UIListLayout(BorderContainer, Enum.FillDirection.Horizontal, UDim.new())
            widgets.UIStroke(BorderContainer, 1, Iris._config.TableBorderStrongColor, Iris._config.TableBorderStrongTransparency)

            BorderContainer.Parent = Table

            thisWidget._columnIndex = 1
            thisWidget._rowIndex = 1
            thisWidget._rowInstances = {}
            thisWidget._cellInstances = {}
            thisWidget._rowBorders = {}
            thisWidget._columnBorders = {}
            thisWidget._rowCycles = {}

            local callbackIndex = #Iris._postCycleCallbacks + 1
            local desiredCycleTick = Iris._cycleTick + 1
            Iris._postCycleCallbacks[callbackIndex] = function()
                if Iris._cycleTick >= desiredCycleTick then
                    if thisWidget.lastCycleTick ~= -1 then
                        thisWidget.state.widths.lastChangeTick = Iris._cycleTick
                        Iris._widgets["Table"].UpdateState(thisWidget)
                    end
                    Iris._postCycleCallbacks[callbackIndex] = nil
                end
            end

            return Table
        end,
        GenerateState = function(thisWidget)
            local NumColumns = thisWidget.arguments.NumColumns
            if thisWidget.state.widths == nil then
                local Widths = table.create(NumColumns, 1 / NumColumns)
                thisWidget.state.widths = Iris._widgetState(thisWidget, "widths", Widths)
            end
            thisWidget._widths = table.create(NumColumns, UDim.new())
            thisWidget._minWidths = table.create(NumColumns, 0)

            local Table = thisWidget.Instance
            local BorderContainer = Table.BorderContainer

            thisWidget._cellInstances[-1] = table.create(NumColumns)
            for index = 1, NumColumns do
                local Border = GenerateColumnBorder(thisWidget, index, "Light")
                Border.Visible = thisWidget.arguments.InnerBorders
                thisWidget._columnBorders[index] = Border
                Border.Parent = BorderContainer

                local Cell = GenerateCell(thisWidget, index, thisWidget._widths[index], false)
                local UISizeConstraint = Cell:FindFirstChild("UISizeConstraint")
                UISizeConstraint.MinSize = Vector2.new(
                    2 * Iris._config.CellPadding.X + ((index > 1 and -2 or 0)) + ((index < NumColumns and -3 or 0)),
                    0
                )
                Cell.LayoutOrder = 2 * index - 1
                thisWidget._cellInstances[-1][index] = Cell
                Cell.Parent = BorderContainer
            end

            local TableColumnBorder = GenerateColumnBorder(thisWidget, NumColumns, "Strong")
            thisWidget._columnBorders[0] = TableColumnBorder
            TableColumnBorder.Parent = Table
        end,
        Update = function(thisWidget)
            local NumColumns = thisWidget.arguments.NumColumns
            assert(NumColumns >= 1, "Iris.Table must have at least one column.")

            if thisWidget._widths ~= nil and #thisWidget._widths ~= NumColumns then
                -- disallow changing the number of columns. It's too much effort
                thisWidget.arguments.NumColumns = #thisWidget._widths
                warn("NumColumns cannot change once set. See documentation.")
            end

            for rowIndex, row in pairs(thisWidget._rowInstances) do
                if rowIndex == 0 then
                    row.BackgroundColor3 = Iris._config.TableHeaderColor
                    row.BackgroundTransparency = Iris._config.TableHeaderTransparency
                elseif thisWidget.arguments.RowBackground == true then
                    if (rowIndex % 2) == 0 then
                        row.BackgroundColor3 = Iris._config.TableRowBgAltColor
                        row.BackgroundTransparency = Iris._config.TableRowBgAltTransparency
                    else
                        row.BackgroundColor3 = Iris._config.TableRowBgColor
                        row.BackgroundTransparency = Iris._config.TableRowBgTransparency
                    end
                else
                    row.BackgroundTransparency = 1
                end
            end

            for _, Border in pairs(thisWidget._rowBorders) do
                Border.Visible = thisWidget.arguments.InnerBorders
            end

            for _, Border in pairs(thisWidget._columnBorders) do
                Border.Visible = thisWidget.arguments.InnerBorders or thisWidget.arguments.Resizable
            end

            for _, border in pairs(thisWidget._columnBorders) do
                local hover = border:FindFirstChild("Hover")
                if hover then
                    hover.Visible = thisWidget.arguments.Resizable
                end
            end

            if thisWidget._columnBorders[NumColumns] ~= nil then
                thisWidget._columnBorders[NumColumns].Visible =
                    not thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.InnerBorders)
                thisWidget._columnBorders[0].Visible =
                    thisWidget.arguments.LimitTableWidth and (thisWidget.arguments.Resizable or thisWidget.arguments.OuterBorders)
            end

            -- the header border visibility must be updated after settings all borders
            -- visiblity or not
            local HeaderRow = thisWidget._rowInstances[0]
            local HeaderBorder = thisWidget._rowBorders[0]
            if HeaderRow ~= nil then
                HeaderRow.Visible = thisWidget.arguments.Header
            end
            if HeaderBorder ~= nil then
                HeaderBorder.Visible = thisWidget.arguments.Header and thisWidget.arguments.InnerBorders
            end

            local Table = thisWidget.Instance
            local BorderContainer = Table.BorderContainer
            BorderContainer.UIStroke.Enabled = thisWidget.arguments.OuterBorders

            for index = 1, thisWidget.arguments.NumColumns do
                TableMinWidths[thisWidget][index] = true
            end

            if thisWidget._widths ~= nil then
                Iris._widgets["Table"].UpdateState(thisWidget)
            end
        end,
        UpdateState = function(thisWidget)
            local Table = thisWidget.Instance
            local BorderContainer = Table.BorderContainer
            local RowContainer = Table.RowContainer
            local NumColumns = thisWidget.arguments.NumColumns
            local ColumnWidths = thisWidget.state.widths.value
            local MinWidths = thisWidget._minWidths

            local Fixed = thisWidget.arguments.FixedWidth
            local Proportional = thisWidget.arguments.ProportionalWidth

            if not thisWidget.arguments.Resizable then
                if Fixed then
                    if Proportional then
                        for index = 1, NumColumns do
                            ColumnWidths[index] = MinWidths[index]
                        end
                    else
                        local maxWidth = 0
                        for _, width in pairs(MinWidths) do
                            maxWidth = math.max(maxWidth, width)
                        end
                        for index = 1, NumColumns do
                            ColumnWidths[index] = maxWidth
                        end
                    end
                else
                    if Proportional then
                        local TotalWidth = 0
                        for _, width in pairs(MinWidths) do
                            TotalWidth = TotalWidth + width
                        end
                        local Ratio = 1 / TotalWidth
                        for index = 1, NumColumns do
                            ColumnWidths[index] = Ratio * MinWidths[index]
                        end
                    else
                        local width = 1 / NumColumns
                        for index = 1, NumColumns do
                            ColumnWidths[index] = width
                        end
                    end
                end
            end

            local Position = UDim.new()
            for index = 1, NumColumns do
                local ColumnWidth = ColumnWidths[index]

                local Width = UDim.new(
                    (Fixed and 0 or math.clamp(ColumnWidth, 0, 1)),
                    (Fixed and math.max(ColumnWidth, 0) or 0)
                )
                thisWidget._widths[index] = Width
                Position = Position + Width
                for _, row in pairs(thisWidget._cellInstances) do
                    row[index].Size = UDim2.new(Width, UDim.new())
                end

                thisWidget._cellInstances[-1][index].Size = UDim2.new(Width + UDim.new(0,
                    ((index > 1 and -2 or 0)) - 3
                ), UDim.new())
            end

            local Width = Position.Offset
            if not thisWidget.arguments.FixedWidth or not thisWidget.arguments.LimitTableWidth then
                Width = math.huge
            end

            BorderContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            RowContainer.UISizeConstraint.MaxSize = Vector2.new(Width, math.huge)
            thisWidget._columnBorders[0].Position = UDim2.fromOffset(Width - 3, 0)
        end,
        ChildAdded = function(thisWidget, _)
            local rowIndex = thisWidget._rowIndex
            local columnIndex = thisWidget._columnIndex
            -- determine if the row exists yet
            local Row = thisWidget._rowInstances[rowIndex]
            thisWidget._rowCycles[rowIndex] = Iris._cycleTick
            TableMinWidths[thisWidget][columnIndex] = true

            if Row ~= nil then
                return thisWidget._cellInstances[rowIndex][columnIndex]
            end

            Row = GenerateRow(thisWidget, rowIndex)
            if rowIndex == 0 then
                Row.Visible = thisWidget.arguments.Header
            end
            Row.Parent = thisWidget._rowContainer

            if rowIndex > 0 then
                local Border = GenerateRowBorder(thisWidget, rowIndex - 1, (rowIndex == 1 and "Strong" or "Light"))
                Border.Visible = thisWidget.arguments.InnerBorders and ((rowIndex == 1 and (thisWidget.arguments.Header and thisWidget.arguments.InnerBorders) and (thisWidget._rowInstances[0] ~= nil) or true))
                thisWidget._rowBorders[rowIndex - 1] = Border
                Border.Parent = thisWidget._rowContainer
            end

            return thisWidget._cellInstances[rowIndex][columnIndex]
        end,
        ChildDiscarded = function(thisWidget, thisChild)
            local Cell = thisChild.Instance.Parent

            if Cell ~= nil then
                local columnIndex = tonumber(Cell.Name:sub(6))

                if columnIndex then
                    TableMinWidths[thisWidget][columnIndex] = true
                end
            end
        end,
        Discard = function(thisWidget)
            Tables[thisWidget.ID] = nil
            TableMinWidths[thisWidget] = nil
            thisWidget.Instance:Destroy()
            widgets.discardState(thisWidget)
        end
    })
end

end
-- ===== module: API =====
__modules["API"] = function()

return function(Iris)
    -- basic wrapper for nearly every widget, saves space.
    local function wrapper(name)
        return function(arguments, states)
            return Iris.Internal._Insert(name, arguments, states)
        end
    end

    Iris.Window = wrapper("Window")

    Iris.SetFocusedWindow = Iris.Internal.SetFocusedWindow

    Iris.Tooltip = wrapper("Tooltip")

    Iris.MenuBar = wrapper("MenuBar")

    Iris.Menu = wrapper("Menu")

    Iris.MenuItem = wrapper("MenuItem")

    Iris.MenuToggle = wrapper("MenuToggle")

    Iris.Separator = wrapper("Separator")

    Iris.Indent = wrapper("Indent")

    Iris.SameLine = wrapper("SameLine")

    Iris.Group = wrapper("Group")

    Iris.Text = wrapper("Text")

    Iris.TextWrapped = function(arguments)
        arguments[2] = true
        return Iris.Internal._Insert("Text", arguments)
    end

    Iris.TextColored = function(arguments)
        arguments[3] = arguments[2]
        arguments[2] = nil
        return Iris.Internal._Insert("Text", arguments)
    end

    Iris.SeparatorText = wrapper("SeparatorText")

    Iris.InputText = wrapper("InputText")

    Iris.Button = wrapper("Button")

    Iris.SmallButton = wrapper("SmallButton")

    Iris.Checkbox = wrapper("Checkbox")

    Iris.RadioButton = wrapper("RadioButton")

    Iris.Image = wrapper("Image")

    Iris.ImageButton = wrapper("ImageButton")

    Iris.Tree = wrapper("Tree")

    Iris.CollapsingHeader = wrapper("CollapsingHeader")

    Iris.TabBar = wrapper("TabBar")

    Iris.Tab = wrapper("Tab")

    Iris.InputNum = wrapper("InputNum")

    Iris.InputVector2 = wrapper("InputVector2")

    Iris.InputVector3 = wrapper("InputVector3")

    Iris.InputUDim = wrapper("InputUDim")

    Iris.InputUDim2 = wrapper("InputUDim2")

    Iris.InputRect = wrapper("InputRect")

    Iris.DragNum = wrapper("DragNum")

    Iris.DragVector2 = wrapper("DragVector2")

    Iris.DragVector3 = wrapper("DragVector3")

    Iris.DragUDim = wrapper("DragUDim")

    Iris.DragUDim2 = wrapper("DragUDim2")

    Iris.DragRect = wrapper("DragRect")

    Iris.InputColor3 = wrapper("InputColor3")

    Iris.InputColor4 = wrapper("InputColor4")

    Iris.SliderNum = wrapper("SliderNum")

    Iris.SliderVector2 = wrapper("SliderVector2")

    Iris.SliderVector3 = wrapper("SliderVector3")

    Iris.SliderUDim = wrapper("SliderUDim")

    Iris.SliderUDim2 = wrapper("SliderUDim2")

    Iris.SliderRect = wrapper("SliderRect")

    Iris.Selectable = wrapper("Selectable")

    Iris.Combo = wrapper("Combo")

    Iris.ComboArray = function(arguments, states, selectionArray)
        local defaultState
        if states == nil then
            defaultState = Iris.State(selectionArray[1])
        else
            defaultState = states
        end
        local thisWidget = Iris.Internal._Insert("Combo", arguments, defaultState)
        local sharedIndex = thisWidget.state.index
        for _, Selection in pairs(selectionArray) do
            Iris.Internal._Insert("Selectable", { Selection, Selection }, { index = sharedIndex })
        end
        Iris.End()

        return thisWidget
    end

    Iris.ComboEnum = function(arguments, states, enumType)
        local defaultState
        if states == nil then
            defaultState = Iris.State(enumType:GetEnumItems()[1])
        else
            defaultState = states
        end
        local thisWidget = Iris.Internal._Insert("Combo", arguments, defaultState)
        local sharedIndex = thisWidget.state.index
        for _, Selection in pairs(enumType:GetEnumItems()) do
            Iris.Internal._Insert("Selectable", { Selection.Name, Selection }, { index = sharedIndex })
        end
        Iris.End()

        return thisWidget
    end

    Iris.InputEnum = Iris.ComboEnum

    Iris.ProgressBar = wrapper("ProgressBar")

    Iris.PlotLines = wrapper("PlotLines")

    Iris.PlotHistogram = wrapper("PlotHistogram")

    Iris.Table = wrapper("Table")

    Iris.NextColumn = function()
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.NextColumn() can only called when directly within a table.")

        local columnIndex = Table._columnIndex
        if columnIndex == Table.arguments.NumColumns then
            Table._columnIndex = 1
            Table._rowIndex = Table._rowIndex + 1
        else
            Table._columnIndex = Table._columnIndex + 1
        end
        return Table._columnIndex
    end

    Iris.NextRow = function()
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.NextRow() can only called when directly within a table.")
        Table._columnIndex = 1
        Table._rowIndex = Table._rowIndex + 1
        return Table._rowIndex
    end

    Iris.SetColumnIndex = function(index)
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.SetColumnIndex() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), string.format("The index must be between 1 and %s, inclusive.", Table.arguments.NumColumns))
        Table._columnIndex = index
    end

    Iris.SetRowIndex = function(index)
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.SetRowIndex() can only called when directly within a table.")
        assert(index >= 1, "The index must be greater or equal to 1.")
        Table._rowIndex = index
    end

    Iris.NextHeaderColumn = function()
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.NextHeaderColumn() can only called when directly within a table.")

        Table._rowIndex = 0
        Table._columnIndex = (Table._columnIndex % Table.arguments.NumColumns) + 1

        return Table._columnIndex
    end

    Iris.SetHeaderColumnIndex = function(index)
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.SetHeaderColumnIndex() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), string.format("The index must be between 1 and %s, inclusive.", Table.arguments.NumColumns))

        Table._rowIndex = 0
        Table._columnIndex = index
    end

    Iris.SetColumnWidth = function(index, width)
        local Table = Iris.Internal._GetParentWidget()
        assert(Table ~= nil, "Iris.SetColumnWidth() can only called when directly within a table.")
        assert((index >= 1) and (index <= Table.arguments.NumColumns), string.format("The index must be between 1 and %s, inclusive.", Table.arguments.NumColumns))

        local oldValue = Table.state.widths.value[index]
        Table.state.widths.value[index] = width
        Table.state.widths:set(Table.state.widths.value, width ~= oldValue)
    end
end

end
return __require("init")