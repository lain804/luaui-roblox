local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local UILibrary = {}
UILibrary.__index = UILibrary

local Theme = {
    Background = Color3.fromRGB(15, 15, 15),
    Tab = Color3.fromRGB(25, 25, 25),
    TabActive = Color3.fromRGB(35, 35, 35),
    Element = Color3.fromRGB(20, 20, 20),
    ElementHover = Color3.fromRGB(30, 30, 30),
    Text = Color3.fromRGB(200, 200, 200),
    TextDim = Color3.fromRGB(120, 120, 120),
    Accent = Color3.fromRGB(255, 255, 255),
    Border = Color3.fromRGB(40, 40, 40)
}

local function env()
    return (getgenv and getgenv()) or _G
end

local function getEnvFunction(name)
    local e = env()
    return e[name] or rawget(_G, name)
end

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then return false, nil end
    local ok, result = pcall(fn, ...)
    return ok, result
end

local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[k] = v
    end
    return out
end

local function valueToText(value)
    if value == nil then
        return ""
    end

    if type(value) == "table" then
        local parts = {}

        for _, item in ipairs(value) do
            table.insert(parts, tostring(item))
        end

        if #parts == 0 then
            for key, item in pairs(value) do
                table.insert(parts, tostring(key) .. "=" .. tostring(item))
            end
        end

        return table.concat(parts, ", ")
    end

    return tostring(value)
end

local Controller = {}
Controller.__index = Controller

function Controller.new(tab, instance, data)
    data = data or {}
    local self = setmetatable({}, Controller)
    self.Tab = tab
    self.Library = tab.library
    self.Instance = instance
    self.Parent = instance.Parent
    self.Type = data.Type or instance.Name
    self.Flag = data.Flag
    self._get = data.Get
    self._set = data.Set
    self.Save = data.Save
    self.Cleanup = data.Cleanup
    self.OnHide = data.OnHide
    self.OnShow = data.OnShow
    self.Destroyed = false
    self.Hidden = false

    table.insert(tab.elements, self)
    return self
end

function Controller:Remove()
    if self.Destroyed then return end
    self.Destroyed = true

    if self.Flag and self.Library.controllers[self.Flag] == self then
        self.Library.controllers[self.Flag] = nil
    end

    if self.Cleanup then
        pcall(self.Cleanup)
    end

    if self.Instance then
        self.Instance:Destroy()
    end

    for i, item in ipairs(self.Tab.elements) do
        if item == self then
            table.remove(self.Tab.elements, i)
            break
        end
    end

    self.Tab:_RefreshCanvas()
end

function Controller:Destroy()
    self:Remove()
end

function Controller:Hide()
    if self.Destroyed or self.Hidden then return end
    self.Hidden = true
    if self.OnHide then
        pcall(self.OnHide)
    end
    self.Parent = self.Instance.Parent
    self.Instance.Parent = nil
    self.Tab:_RefreshCanvas()
end

function Controller:Show()
    if self.Destroyed or not self.Hidden then return end
    self.Hidden = false
    self.Instance.Parent = self.Parent or self.Tab.content
    if self.OnShow then
        pcall(self.OnShow)
    end
    self.Tab:_RefreshCanvas()
end

function Controller:SetValue(value, noCallback)
    if self._set then
        return self._set(value, noCallback)
    end
    return nil
end

function Controller:Set(value, noCallback)
    return self:SetValue(value, noCallback)
end

function Controller:GetValue()
    if self._get then
        return self._get()
    end
    return nil
end

function Controller:Get()
    return self:GetValue()
end

function Controller:SetText(value, noCallback)
    return self:SetValue(value, noCallback)
end

function Controller:GetText()
    return valueToText(self:GetValue())
end

function Controller:GetInstance()
    return self.Instance
end

local Tab = {}
Tab.__index = Tab

function Tab:_RefreshCanvas()
    if not self.content or not self.layout then return end
    task.defer(function()
        if self.content and self.layout then
            self.content.CanvasSize = UDim2.new(0, 0, 0, self.layout.AbsoluteContentSize.Y + 20)
        end
    end)
end

function Tab:Remove(target)
    if typeof(target) == "Instance" then
        target:Destroy()
        self:_RefreshCanvas()
        return
    end
    if type(target) == "table" and target.Remove then
        target:Remove()
    end
end

function Tab:Hide(target)
    if typeof(target) == "Instance" then
        target.Parent = nil
        self:_RefreshCanvas()
        return
    end
    if type(target) == "table" and target.Hide then
        target:Hide()
    end
end

function Tab:Show(target)
    if type(target) == "table" and target.Show then
        target:Show()
    end
end

function Tab:_BindFlag(flag, controller)
    if flag then
        self.library.controllers[flag] = controller
    end
end

function Tab:_GetSaved(flag, default)
    if flag and self.library.flags[flag] ~= nil then
        return self.library.flags[flag], true
    end
    return default, false
end

function Tab:_SaveFlag(flag, value)
    if not flag then return end
    self.library.flags[flag] = value
    if self.library.AutoSave then
        self.library:SaveConfig()
    end
end

function Tab:Button(args)
    args = args or {}
    local text = args.Text or "Button"
    local callback = args.Callback

    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Parent = self.content
    button.BackgroundColor3 = Theme.Element
    button.BorderColor3 = Theme.Border
    button.BorderSizePixel = 1
    button.Size = UDim2.new(0.94, 0, 0, args.Height or 30)
    button.AnchorPoint = Vector2.new(0.5, 0)
    button.Position = UDim2.new(0.5, 0, 0, 0)
    button.Font = Enum.Font.Code
    button.Text = text
    button.TextColor3 = Theme.Text
    button.TextSize = args.TextSize or 13
    button.AutoButtonColor = false

    local hovering = false

    button.MouseEnter:Connect(function()
        hovering = true
        button.BackgroundColor3 = Theme.ElementHover
    end)

    button.MouseLeave:Connect(function()
        hovering = false
        button.BackgroundColor3 = Theme.Element
    end)

    button.MouseButton1Down:Connect(function()
        button.BackgroundColor3 = Theme.Element
    end)

    button.MouseButton1Up:Connect(function()
        button.BackgroundColor3 = hovering and Theme.ElementHover or Theme.Element
    end)

    local controller

    button.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback, controller) end
    end)

    controller = Controller.new(self, button, {
        Type = "Button",
        Get = function() return button.Text end,
        Set = function(newText)
            button.Text = valueToText(newText)
        end
    })

    self:_RefreshCanvas()
    return controller
end

function Tab:Toggle(args)
    args = args or {}
    local text = args.Text or "Toggle"
    local callback = args.Callback
    local flag = args.Flag or args.Save

    local default = args.Default
    if default == nil then default = false end
    default = self:_GetSaved(flag, default)

    local frame = Instance.new("TextButton")
    frame.Name = "Toggle"
    frame.Parent = self.content
    frame.BackgroundColor3 = Theme.Element
    frame.BorderColor3 = Theme.Border
    frame.BorderSizePixel = 1
    frame.Size = UDim2.new(0.94, 0, 0, args.Height or 30)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, 0)
    frame.Text = ""
    frame.AutoButtonColor = false

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 0)
    label.Size = UDim2.new(1, -42, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Theme.Text
    label.TextSize = args.TextSize or 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggle = Instance.new("Frame")
    toggle.Parent = frame
    toggle.BackgroundColor3 = default and Theme.Accent or Theme.Background
    toggle.BorderColor3 = Theme.Border
    toggle.BorderSizePixel = 1
    toggle.Position = UDim2.new(1, -5, 0.5, 0)
    toggle.Size = UDim2.new(0, 20, 0, 20)
    toggle.AnchorPoint = Vector2.new(1, 0.5)

    local state = default

    local function setState(newState, noCallback)
        state = not not newState
        toggle.BackgroundColor3 = state and Theme.Accent or Theme.Background
        self:_SaveFlag(flag, state)
        if callback and not noCallback then
            task.spawn(callback, state)
        end
    end

    frame.MouseEnter:Connect(function()
        frame.BackgroundColor3 = Theme.ElementHover
    end)

    frame.MouseLeave:Connect(function()
        frame.BackgroundColor3 = Theme.Element
    end)

    frame.MouseButton1Click:Connect(function()
        setState(not state)
    end)

    local controller = Controller.new(self, frame, {
        Type = "Toggle",
        Flag = flag,
        Get = function() return state end,
        Set = setState
    })
    self:_BindFlag(flag, controller)

    if flag and self.library.loadedFlags[flag] ~= nil and args.CallOnLoad ~= false and callback then
        task.spawn(callback, state)
    end

    self:_RefreshCanvas()
    return controller
end

function Tab:Slider(args)
    args = args or {}
    local text = args.Text or "Slider"
    local min = args.Min or 0
    local max = args.Max or 100
    local default = args.Default
    if default == nil then default = min end
    if max == min then max = min + 1 end
    local callback = args.Callback
    local increment = args.Increment or 1
    local flag = args.Flag or args.Save

    default = self:_GetSaved(flag, default)
    default = tonumber(default) or min
    default = math.clamp(default, min, max)

    local frame = Instance.new("Frame")
    frame.Name = "Slider"
    frame.Parent = self.content
    frame.BackgroundColor3 = Theme.Element
    frame.BorderColor3 = Theme.Border
    frame.BorderSizePixel = 1
    frame.Size = UDim2.new(0.94, 0, 0, args.Height or 52)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, 0)

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 5)
    label.Size = UDim2.new(1, -74, 0, 20)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Theme.Text
    label.TextSize = args.TextSize or 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Parent = frame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -64, 0, 5)
    valueLabel.Size = UDim2.new(0, 56, 0, 20)
    valueLabel.Font = Enum.Font.Code
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Theme.Accent
    valueLabel.TextSize = args.TextSize or 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local sliderBg = Instance.new("Frame")
    sliderBg.Parent = frame
    sliderBg.BackgroundColor3 = Theme.Background
    sliderBg.BorderColor3 = Theme.Border
    sliderBg.BorderSizePixel = 1
    sliderBg.Position = UDim2.new(0, 4, 0, 33)
    sliderBg.Size = UDim2.new(1, -8, 0, 15)

    local sliderFill = Instance.new("Frame")
    sliderFill.Parent = sliderBg
    sliderFill.BackgroundColor3 = Theme.Accent
    sliderFill.BorderSizePixel = 0

    local sliderHandle = Instance.new("Frame")
    sliderHandle.Parent = sliderBg
    sliderHandle.BackgroundColor3 = Theme.Text
    sliderHandle.BorderSizePixel = 0
    sliderHandle.Size = UDim2.new(0, 6, 0, 21)

    local detector = Instance.new("TextButton")
    detector.Parent = sliderBg
    detector.BackgroundTransparency = 1
    detector.Position = UDim2.new(0, 0, 0, -4)
    detector.Size = UDim2.new(1, 0, 1, 8)
    detector.Text = ""
    detector.AutoButtonColor = false

    local value = default
    local dragging = false

    local function getAlpha(v)
        return math.clamp((v - min) / (max - min), 0, 1)
    end

    local function render()
        local alpha = getAlpha(value)
        valueLabel.Text = tostring(value)
        sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
        sliderHandle.Position = UDim2.new(alpha, -3, 0, -3)
    end

    local function setValue(newValue, noCallback)
        local numberValue = tonumber(newValue) or min
        numberValue = math.floor(numberValue / increment + 0.5) * increment
        value = math.clamp(numberValue, min, max)
        render()
        self:_SaveFlag(flag, value)
        if callback and not noCallback then
            task.spawn(callback, value)
        end
    end

    local function updateSlider(inputPos)
        local mouseX = inputPos.X
        local relativeX = math.clamp((mouseX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local rawValue = min + (max - min) * relativeX
        setValue(rawValue)
    end

    detector.MouseButton1Down:Connect(function()
        dragging = true
        updateSlider(UserInputService:GetMouseLocation())
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    render()

    local controller = Controller.new(self, frame, {
        Type = "Slider",
        Flag = flag,
        Get = function() return value end,
        Set = setValue
    })
    self:_BindFlag(flag, controller)

    if flag and self.library.loadedFlags[flag] ~= nil and args.CallOnLoad ~= false and callback then
        task.spawn(callback, value)
    end

    self:_RefreshCanvas()
    return controller
end

function Tab:Label(args)
    args = args or {}
    local text = valueToText(args.Text or "")
    local height = args.Height or 20

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = self.content
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.94, 0, 0, height)
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0, 0)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Theme.TextDim
    label.TextSize = args.TextSize or 12
    label.TextXAlignment = args.TextXAlignment or Enum.TextXAlignment.Left

    local controller = Controller.new(self, label, {
        Type = "Label",
        Set = function(newText)
            label.Text = valueToText(newText)
        end,
        Get = function()
            return label.Text
        end
    })

    self:_RefreshCanvas()
    return controller
end

function Tab:Separator(args)
    args = args or {}
    local container = Instance.new("Frame")
    container.Name = "SeparatorContainer"
    container.Parent = self.content
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(0.94, 0, 0, args.Height or 20)
    container.AnchorPoint = Vector2.new(0.5, 0)
    container.Position = UDim2.new(0.5, 0, 0, 0)

    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Parent = container
    separator.BackgroundColor3 = Theme.Border
    separator.BorderSizePixel = 0
    separator.Position = UDim2.new(0, 0, 0.5, 0)
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.AnchorPoint = Vector2.new(0, 0.5)

    local controller = Controller.new(self, container, {
        Type = "Separator"
    })

    self:_RefreshCanvas()
    return controller
end

function Tab:Dropdown(args)
    args = args or {}
    local text = args.Text or "Dropdown"
    local options = args.Options or {}
    local default = args.Default or {}
    local multiSelect = args.Multi or false
    local callback = args.Callback
    local flag = args.Flag or args.Save

    if type(default) ~= "table" then
        default = { default }
    else
        default = shallowCopy(default)
    end

    local saved, hadSaved = self:_GetSaved(flag, nil)
    if hadSaved then
        if type(saved) == "table" then
            default = saved
        else
            default = { saved }
        end
    end

    local selected = {}
    local selectedOrder = {}

    local function addSelected(option)
        if not selected[option] then
            table.insert(selectedOrder, option)
        end
        selected[option] = true
    end

    local function removeSelected(option)
        selected[option] = nil
        local index = table.find(selectedOrder, option)
        if index then
            table.remove(selectedOrder, index)
        end
    end

    local function clearSelected()
        table.clear(selected)
        table.clear(selectedOrder)
    end

    for _, def in ipairs(default) do
        if table.find(options, def) then
            addSelected(def)
            if not multiSelect then break end
        end
    end

    local frame = Instance.new("Frame")
    frame.Name = "Dropdown"
    frame.Parent = self.content
    frame.BackgroundColor3 = Theme.Element
    frame.BorderColor3 = Theme.Border
    frame.BorderSizePixel = 1
    frame.Size = UDim2.new(0.94, 0, 0, args.Height or 30)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, 0)
    frame.ZIndex = 5

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 0)
    label.Size = UDim2.new(0.37, -10, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Theme.Text
    label.TextSize = args.TextSize or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 6

    local button = Instance.new("TextButton")
    button.Parent = frame
    button.BackgroundColor3 = Theme.Background
    button.BorderColor3 = Theme.Border
    button.BorderSizePixel = 1
    button.AnchorPoint = Vector2.new(1, 0)
    button.Position = UDim2.new(1, -4, 0, 4)
    button.Size = UDim2.new(0.55, -4, 1, -8)
    button.Font = Enum.Font.Code
    button.TextColor3 = Theme.Text
    button.TextSize = args.TextSize or 13
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.ZIndex = 6

    local arrow = Instance.new("TextLabel")
    arrow.Parent = button
    arrow.BackgroundTransparency = 1
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -6, 0.5, 0)
    arrow.Size = UDim2.new(0, 15, 1, 0)
    arrow.Font = Enum.Font.Code
    arrow.Text = "v"
    arrow.TextColor3 = Theme.TextDim
    arrow.TextSize = 10
    arrow.ZIndex = 7

    local optionHeight = 25
    local maxHeight = 150
    local totalHeight = #options * optionHeight
    local dropdownHeight = math.min(totalHeight, maxHeight)

    local overlay = Instance.new("Frame")
    overlay.Name = "DropdownOverlay"
    overlay.Parent = self.library.MainFrame
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Visible = false
    overlay.ZIndex = 40

    local outsideButton = Instance.new("TextButton")
    outsideButton.Name = "OutsideClose"
    outsideButton.Parent = overlay
    outsideButton.BackgroundTransparency = 1
    outsideButton.BorderSizePixel = 0
    outsideButton.Position = UDim2.new(0, 0, 0, 0)
    outsideButton.Size = UDim2.new(1, 0, 1, 0)
    outsideButton.Text = ""
    outsideButton.AutoButtonColor = false
    outsideButton.ZIndex = 40

    local dropdown = Instance.new("Frame")
    dropdown.Name = "DropdownList"
    dropdown.Parent = overlay
    dropdown.BackgroundColor3 = Theme.Element
    dropdown.BorderColor3 = Theme.Border
    dropdown.BorderSizePixel = 1
    dropdown.AnchorPoint = Vector2.new(0, 0)
    dropdown.Position = UDim2.new(0, 0, 0, 0)
    dropdown.Size = UDim2.new(0, 0, 0, dropdownHeight)
    dropdown.Visible = false
    dropdown.ZIndex = 50

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Parent = dropdown
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Theme.Border
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, dropdownHeight))
    scrollFrame.ZIndex = 51

    local layout = Instance.new("UIListLayout")
    layout.Parent = scrollFrame
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local optionButtons = {}

    local function getSelectedTable()
        local list = {}
        for _, option in ipairs(selectedOrder) do
            if selected[option] then
                table.insert(list, option)
            end
        end
        return list
    end

    local function getSelectedText()
        local list = getSelectedTable()
        if #list == 0 then
            return "None"
        elseif #list == 1 then
            return list[1]
        else
            return list[1] .. " (+" .. (#list - 1) .. ")"
        end
    end

    local function repaintOptions()
        for option, optionButton in pairs(optionButtons) do
            optionButton.BackgroundColor3 = selected[option] and Theme.ElementHover or Theme.Background
            optionButton.TextColor3 = Theme.Text
        end
    end

    local function updateDisplay(noCallback)
        button.Text = "  " .. getSelectedText()
        repaintOptions()
        self:_SaveFlag(flag, multiSelect and getSelectedTable() or getSelectedTable()[1])
        if callback and not noCallback then
            task.spawn(callback, multiSelect and getSelectedTable() or getSelectedTable()[1])
        end
    end

    local closeDropdown

    local function setSelected(value, noCallback)
        clearSelected()
        local values = value
        if type(values) ~= "table" then
            values = { values }
        end
        for _, option in ipairs(values) do
            if table.find(options, option) then
                addSelected(option)
                if not multiSelect then break end
            end
        end
        updateDisplay(noCallback)
    end

    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Name = "Option" .. i
        optionButton.Parent = scrollFrame
        optionButton.BackgroundColor3 = selected[option] and Theme.ElementHover or Theme.Background
        optionButton.BorderSizePixel = 0
        optionButton.Size = UDim2.new(1, 0, 0, 23)
        optionButton.Font = Enum.Font.Code
        optionButton.Text = "  " .. option
        optionButton.TextColor3 = Theme.Text
        optionButton.TextSize = args.TextSize or 13
        optionButton.TextXAlignment = Enum.TextXAlignment.Left
        optionButton.AutoButtonColor = false
        optionButton.ZIndex = 52
        optionButtons[option] = optionButton

        optionButton.MouseButton1Click:Connect(function()
            if multiSelect then
                if selected[option] then
                    removeSelected(option)
                else
                    addSelected(option)
                end
            else
                clearSelected()
                addSelected(option)
                if closeDropdown then
                    closeDropdown()
                else
                    dropdown.Visible = false
                    arrow.Text = "v"
                end
            end
            updateDisplay()
        end)
    end

    local isOpen = false
    local outsideConnection = nil

    local function pointInside(gui, pos)
        if not gui or not gui.Parent then return false end
        local p = gui.AbsolutePosition
        local s = gui.AbsoluteSize
        return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
    end

    local function placeDropdown()
        local main = self.library.MainFrame
        if not main then return end

        local buttonPos = button.AbsolutePosition
        local buttonSize = button.AbsoluteSize
        local mainPos = main.AbsolutePosition

        local x = buttonPos.X - mainPos.X
        local aboveY = buttonPos.Y - dropdownHeight - 2
        local belowY = buttonPos.Y + buttonSize.Y + 2
        local finalY = aboveY >= 0 and aboveY or belowY

        dropdown.Size = UDim2.new(0, buttonSize.X, 0, dropdownHeight)
        dropdown.Position = UDim2.new(0, x, 0, finalY - mainPos.Y)
    end

    closeDropdown = function()
        if not isOpen then return end
        isOpen = false
        dropdown.Visible = false
        overlay.Visible = false
        arrow.Text = "v"
        if outsideConnection then
            outsideConnection:Disconnect()
            outsideConnection = nil
        end
    end

    outsideButton.MouseButton1Click:Connect(function()
        closeDropdown()
    end)

    local function openDropdown()
        if isOpen then return end
        isOpen = true
        placeDropdown()
        overlay.Visible = true
        dropdown.Visible = true
        arrow.Text = "^"
    end

    button.MouseButton1Click:Connect(function()
        if isOpen then
            closeDropdown()
        else
            openDropdown()
        end
    end)

    updateDisplay(true)

    local controller = Controller.new(self, frame, {
        Type = "Dropdown",
        Flag = flag,
        Get = function()
            return multiSelect and getSelectedTable() or getSelectedTable()[1]
        end,
        Set = setSelected,
        Cleanup = function()
            closeDropdown()
            if overlay then
                overlay:Destroy()
            end
        end,
        OnHide = closeDropdown
    })
    self:_BindFlag(flag, controller)

    if flag and self.library.loadedFlags[flag] ~= nil and args.CallOnLoad ~= false and callback then
        task.spawn(callback, multiSelect and getSelectedTable() or getSelectedTable()[1])
    end

    self:_RefreshCanvas()
    return controller
end


function UILibrary:_RefreshTabCanvas()
    if not self.TabContainer or not self.TabLayout then return end

    task.defer(function()
        if not self.TabContainer or not self.TabLayout then return end

        local contentWidth = self.TabLayout.AbsoluteContentSize.X + 2
        self.TabContainer.CanvasSize = UDim2.new(0, contentWidth, 0, 0)
    end)
end

function UILibrary:_ScrollTabIntoView(tab)
    if not tab or not tab.button or not self.TabContainer then return end

    task.defer(function()
        if not tab.button or not tab.button.Parent or not self.TabContainer then return end

        local container = self.TabContainer
        local button = tab.button

        local containerPos = container.AbsolutePosition
        local containerSize = container.AbsoluteSize
        local buttonPos = button.AbsolutePosition
        local buttonSize = button.AbsoluteSize
        local currentX = container.CanvasPosition.X

        local leftOverflow = buttonPos.X - containerPos.X
        local rightOverflow = (buttonPos.X + buttonSize.X) - (containerPos.X + containerSize.X)
        local targetX = currentX

        if leftOverflow < 0 then
            targetX = currentX + leftOverflow
        elseif rightOverflow > 0 then
            targetX = currentX + rightOverflow
        end

        local maxX = math.max(0, container.CanvasSize.X.Offset - containerSize.X)
        targetX = math.clamp(targetX, 0, maxX)
        container.CanvasPosition = Vector2.new(targetX, 0)
    end)
end

function UILibrary.new(args)
    args = args or {}
    local self = setmetatable({}, UILibrary)

    self.flags = {}
    self.loadedFlags = {}
    self.controllers = {}
    self.ConfigFile = args.ConfigFile or args.ConfigName or "UILibrary_Config.json"
    self.ConfigFolder = args.ConfigFolder
    self.AutoSave = args.AutoSave ~= false

    if self.ConfigFolder then
        local makefolder = getEnvFunction("makefolder")
        local isfolder = getEnvFunction("isfolder")
        if makefolder then
            local okFolder = true
            if isfolder then
                local ok, exists = safeCall(isfolder, self.ConfigFolder)
                okFolder = ok and exists
            else
                okFolder = false
            end
            if not okFolder then
                safeCall(makefolder, self.ConfigFolder)
            end
        end
        self.ConfigPath = self.ConfigFolder .. "/" .. self.ConfigFile
    else
        self.ConfigPath = self.ConfigFile
    end

    if args.AutoLoad ~= false then
        self:LoadConfig(false)
    end

    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = args.GuiName or "UILibrary"
    self.ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.ResetOnSpawn = false

    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.Parent = self.ScreenGui
    self.MainFrame.BackgroundColor3 = Theme.Background
    self.MainFrame.BorderColor3 = Theme.Border
    self.MainFrame.BorderSizePixel = 1
    self.MainFrame.Position = args.Position or UDim2.new(0, 100, 0, 100)
    self.MainFrame.Size = args.Size or UDim2.new(0, 650, 0, 450)
    self.MainFrame.Visible = true
    self.MainFrame.ClipsDescendants = false

    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Parent = self.MainFrame
    self.TitleBar.BackgroundColor3 = Theme.Tab
    self.TitleBar.BorderColor3 = Theme.Border
    self.TitleBar.BorderSizePixel = 1
    self.TitleBar.Size = UDim2.new(1, 0, 0, 30)
    self.TitleBar.ZIndex = 2

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Parent = self.TitleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.Size = UDim2.new(1, -20, 1, 0)
    titleLabel.Font = Enum.Font.Code
    titleLabel.Text = args.Title or "GUI"
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 3

    self.TabContainer = Instance.new("ScrollingFrame")
    self.TabContainer.Name = "TabContainer"
    self.TabContainer.Parent = self.MainFrame
    self.TabContainer.BackgroundColor3 = Theme.Tab
    self.TabContainer.BorderColor3 = Theme.Border
    self.TabContainer.BorderSizePixel = 1
    self.TabContainer.Position = UDim2.new(0, 0, 0, 30)
    self.TabContainer.Size = UDim2.new(1, 0, 0, 35)
    self.TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.TabContainer.CanvasPosition = Vector2.new(0, 0)
    self.TabContainer.ScrollBarThickness = args.TabScrollBarThickness or 4
    self.TabContainer.ScrollBarImageColor3 = Theme.Border
    self.TabContainer.ScrollingDirection = Enum.ScrollingDirection.X
    self.TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
    self.TabContainer.BackgroundTransparency = 0
    self.TabContainer.ClipsDescendants = true
    self.TabContainer.ZIndex = 2

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Parent = self.TabContainer
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, args.TabPadding or 0)
    self.TabLayout = tabLayout

    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self:_RefreshTabCanvas()
    end)

    self.TabContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_RefreshTabCanvas()
    end)

    self.ContentArea = Instance.new("Frame")
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Parent = self.MainFrame
    self.ContentArea.BackgroundColor3 = Theme.Background
    self.ContentArea.BorderSizePixel = 0
    self.ContentArea.Position = UDim2.new(0, 0, 0, 65)
    self.ContentArea.Size = UDim2.new(1, 0, 1, -65)
    self.ContentArea.ClipsDescendants = false
    self.ContentArea.ZIndex = 1

    self.tabs = {}
    self.currentTab = nil

    local dragging = false
    local dragStart = nil
    local startPos = nil

    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == (args.KeyCode or Enum.KeyCode.KeypadZero) then
            self.MainFrame.Visible = not self.MainFrame.Visible
        end
    end)

    return self
end

function UILibrary:GetFlag(flag)
    return self.flags[flag]
end

function UILibrary:SetFlag(flag, value, noCallback)
    self.flags[flag] = value
    local controller = self.controllers[flag]
    if controller and controller.Set then
        controller:Set(value, noCallback)
    end
    if self.AutoSave then
        self:SaveConfig()
    end
end

function UILibrary:SaveConfig()
    local writefile = getEnvFunction("writefile")
    if not writefile then
        warn("UILibrary: getgenv().writefile was not found")
        return false
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(self.flags)
    end)
    if not ok then
        warn("UILibrary: failed to encode config")
        return false
    end

    local wrote = safeCall(writefile, self.ConfigPath, encoded)
    if not wrote then
        warn("UILibrary: failed to write config to " .. tostring(self.ConfigPath))
        return false
    end

    return true
end

function UILibrary:LoadConfig(applyCallbacks)
    local readfile = getEnvFunction("readfile")
    local isfile = getEnvFunction("isfile")
    if not readfile then
        return false
    end

    if isfile then
        local ok, exists = safeCall(isfile, self.ConfigPath)
        if ok and not exists then
            return false
        end
    end

    local okRead, data = safeCall(readfile, self.ConfigPath)
    if not okRead or type(data) ~= "string" or data == "" then
        return false
    end

    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if not okDecode or type(decoded) ~= "table" then
        return false
    end

    self.flags = decoded
    self.loadedFlags = shallowCopy(decoded)

    if applyCallbacks then
        for flag, value in pairs(decoded) do
            local controller = self.controllers[flag]
            if controller and controller.Set then
                controller:Set(value, false)
            end
        end
    end

    return true
end

function UILibrary:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

function UILibrary:CreateTab(args)
    args = args or {}
    local name = args.Name or "Tab"

    local tab = setmetatable({
        library = self,
        name = name,
        button = nil,
        content = nil,
        elements = {},
        layout = nil
    }, Tab)

    tab.button = Instance.new("TextButton")
    tab.button.Name = name
    tab.button.Parent = self.TabContainer
    tab.button.BackgroundColor3 = Theme.Tab
    tab.button.BorderColor3 = Theme.Border
    tab.button.BorderSizePixel = 1
    tab.button.Size = UDim2.new(0, args.Width or 120, 1, -(self.TabContainer.ScrollBarThickness or 0))
    tab.button.Font = Enum.Font.Code
    tab.button.Text = name
    tab.button.TextColor3 = Theme.TextDim
    tab.button.TextSize = args.TextSize or 13
    tab.button.AutoButtonColor = false
    tab.button.LayoutOrder = #self.tabs + 1
    tab.button.ZIndex = 3

    tab.content = Instance.new("ScrollingFrame")
    tab.content.Name = name .. "Content"
    tab.content.Parent = self.ContentArea
    tab.content.BackgroundTransparency = 1
    tab.content.BorderSizePixel = 0
    tab.content.Size = UDim2.new(1, 0, 1, 0)
    tab.content.ScrollBarThickness = 8
    tab.content.ScrollBarImageColor3 = Theme.Border
    tab.content.CanvasSize = UDim2.new(0, 0, 0, 0)
    tab.content.Visible = false
    tab.content.ClipsDescendants = false
    tab.content.ZIndex = 1

    local layout = Instance.new("UIListLayout")
    layout.Parent = tab.content
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tab.layout = layout

    local padding = Instance.new("UIPadding")
    padding.Parent = tab.content
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tab:_RefreshCanvas()
    end)

    tab.button.MouseButton1Click:Connect(function()
        self:SwitchTab(name)
    end)

    tab.button.MouseEnter:Connect(function()
        if self.currentTab ~= name then
            tab.button.BackgroundColor3 = Theme.ElementHover
        end
    end)

    tab.button.MouseLeave:Connect(function()
        if self.currentTab ~= name then
            tab.button.BackgroundColor3 = Theme.Tab
        end
    end)

    function tab:RemoveTab()
        self.button:Destroy()
        self.content:Destroy()
        for i, item in ipairs(self.library.tabs) do
            if item == self then
                table.remove(self.library.tabs, i)
                break
            end
        end
        self.library:_RefreshTabCanvas()

        if self.library.currentTab == self.name then
            local first = self.library.tabs[1]
            if first then
                self.library:SwitchTab(first.name)
            else
                self.library.currentTab = nil
            end
        end
    end

    table.insert(self.tabs, tab)
    self:_RefreshTabCanvas()

    if #self.tabs == 1 then
        self:SwitchTab(name)
    end

    return tab
end

function UILibrary:SwitchTab(name)
    local selectedTab = nil

    for _, tab in pairs(self.tabs) do
        if tab.name == name then
            tab.content.Visible = true
            tab.button.BackgroundColor3 = Theme.TabActive
            tab.button.TextColor3 = Theme.Text
            self.currentTab = name
            selectedTab = tab
        else
            tab.content.Visible = false
            tab.button.BackgroundColor3 = Theme.Tab
            tab.button.TextColor3 = Theme.TextDim
        end
    end

    if selectedTab then
        self:_ScrollTabIntoView(selectedTab)
    end
end

return UILibrary