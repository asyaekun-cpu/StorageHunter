local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove previous GUI
local old = playerGui:FindFirstChild("SH_Client_V1")
if old then old:Destroy() end

local active = true
local espEnabled = false
local collectEnabled = false
local savedPosition = nil
local highlights = {}
local connections = {}

local function character()
    return player.Character
end

local function root()
    local c = character()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "SH_Client_V1"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(280, 390)
main.Position = UDim2.new(0.5, -140, 0.5, -195)
main.BackgroundColor3 = Color3.fromRGB(22, 25, 35)
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius =
    UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 42)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "STORAGE HUNTER V1"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = main

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(10, 48)
scroll.Size = UDim2.new(1, -20, 1, -95)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 3
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.Parent = scroll

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 10, 1, -39)
status.Size = UDim2.new(1, -20, 0, 30)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(180, 220, 255)
status.TextSize = 11
status.TextWrapped = true
status.Parent = main

local function notify(msg)
    status.Text = tostring(msg)
    print("[StorageHunter] " .. tostring(msg))
end

local function button(label, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -5, 0, 38)
    b.BackgroundColor3 = Color3.fromRGB(43, 49, 68)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.Text = label
    b.Parent = scroll

    Instance.new("UICorner", b).CornerRadius =
        UDim.new(0, 8)

    b.MouseButton1Click:Connect(function()
        if active then callback(b) end
    end)
    return b
end

-- ESP: Name-based candidate detection only
local keywords = {
    "rare", "legendary", "epic", "mythic",
    "valuable", "gold", "diamond",
    "treasure", "antique", "collectible"
}

local function isCandidate(obj)
    if not obj:IsA("BasePart") and
       not obj:IsA("Model") then
        return false
    end

    local name = obj.Name:lower()
    for _, word in ipairs(keywords) do
        if name:find(word, 1, true) then
            return true
        end
    end
    return false
end

local function clearESP()
    for obj, highlight in pairs(highlights) do
        pcall(function() highlight:Destroy() end)
        highlights[obj] = nil
    end
end

local function refreshESP()
    clearESP()
    if not espEnabled then return end

    local count = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if count >= 100 then break end

        if isCandidate(obj) and
           not obj:IsDescendantOf(character() or playerGui) then

            local h = Instance.new("Highlight")
            h.Name = "SH_ESP"
            h.FillColor = Color3.fromRGB(255, 200, 0)
            h.OutlineColor = Color3.new(1, 1, 1)
            h.FillTransparency = 0.65
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

            local ok = pcall(function()
                h.Adornee = obj
                h.Parent = gui
            end)

            if ok then
                highlights[obj] = h
                count = count + 1
            else
                h:Destroy()
            end
        end
    end

    notify("ESP candidates: " .. count)
end

button("ESP ITEM: OFF", function(b)
    espEnabled = not espEnabled
    b.Text = "ESP ITEM: " .. (espEnabled and "ON" or "OFF")
    refreshESP()
end)

button("REFRESH ESP", refreshESP)

-- Save and teleport to own saved position
button("SAVE POSITION", function()
    local r = root()
    if not r then
        notify("Character not ready")
        return
    end

    savedPosition = r.CFrame
    notify("Position saved")
end)

button("TELEPORT SAVED POSITION", function()
    local r = root()
    if not r or not savedPosition then
        notify("Save position first")
        return
    end

    local ok = pcall(function()
        r.CFrame = savedPosition
    end)

    notify(ok and "Teleport attempted" or "Teleport failed")
end)

-- Collect using existing ProximityPrompts
local function nearestPrompt()
    local r = root()
    if not r then return nil end

    local best, bestDistance = nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            local pos

            if parent:IsA("Attachment") then
                pos = parent.WorldPosition
            elseif parent:IsA("BasePart") then
                pos = parent.Position
            end

            if pos then
                local distance = (r.Position - pos).Magnitude
                if distance <= obj.MaxActivationDistance
                   and distance < bestDistance then
                    best = obj
                    bestDistance = distance
                end
            end
        end
    end

    return best
end

button("AUTO COLLECT: OFF", function(b)
    if type(fireproximityprompt) ~= "function" then
        notify("Executor lacks fireproximityprompt")
        return
    end

    collectEnabled = not collectEnabled
    b.Text = "AUTO COLLECT: " ..
        (collectEnabled and "ON" or "OFF")

    notify(collectEnabled and
        "Nearby prompts enabled" or "Collect stopped")
end)

-- No guessed server endpoints
button("AUTO BID / AUCTION", function()
    notify("Unavailable: auction interface unknown")
end)

button("AUTO SELL", function()
    notify("Unavailable: selling interface unknown")
end)

button("AUTO FARM MONEY", function()
    notify("Unavailable: earning mechanism unknown")
end)

-- Background collect loop
task.spawn(function()
    while active do
        if collectEnabled and
           type(fireproximityprompt) == "function" then
            local prompt = nearestPrompt()
            if prompt then
                pcall(function()
                    fireproximityprompt(prompt)
                end)
            end
        end
        task.wait(1.5)
    end
end)

-- Minimize button
local minimized = false
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(38, 38)
toggle.Position = UDim2.new(1, -43, 0, 2)
toggle.Text = "-"
toggle.TextSize = 24
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.BackgroundTransparency = 1
toggle.Parent = main

toggle.MouseButton1Click:Connect(function()
    minimized = not minimized
    scroll.Visible = not minimized
    status.Visible = not minimized
    main.Size = minimized and
        UDim2.fromOffset(280, 44) or
        UDim2.fromOffset(280, 390)
    toggle.Text = minimized and "+" or "-"
end)

-- Stop and remove GUI
local close = button("STOP SCRIPT / CLOSE GUI", function()
    active = false
    collectEnabled = false
    espEnabled = false
    clearESP()
    disconnectAll()
    gui:Destroy()
end)

close.BackgroundColor3 = Color3.fromRGB(150, 45, 45)

notify("V1 loaded. No game remotes assumed.")
