-- Load necessary services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Define colors
local Green = Color3.fromRGB(0, 255, 0)
local Red = Color3.fromRGB(255, 0, 0)

-- Aimbot settings
local player = Players.LocalPlayer
local aiming = false
local pcMod = false
local radius = 150
local useTeamCheck = true
local useWallCheck = true
local targetPart = "Head" -- Default target part (Head or Torso)
local lockOnTarget = false -- Lock onto target until death or out of radius
local currentTarget = nil -- Current locked target
local espEnabled = true -- Toggle for ESP functionality
local teleportEnabled = false -- Toggle for teleportation functionality

-- ESP settings
local esp = {}

-- Function to create a new drawing object
local function NewDrawing(className, properties)
    local drawing = Drawing.new(className)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

-- Aimbot circle drawing
local drawing = NewDrawing("Circle", {
    Color = Color3.new(1, 0, 0),
    Thickness = 2,
    Radius = radius,
    Filled = false,
    Visible = true
})

local screenSize = workspace.CurrentCamera.ViewportSize
drawing.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)

-- Function to check target visibility
local function isTargetVisible(targetPosition)
    if not useWallCheck then
        return true
    end
    local ray = Ray.new(Camera.CFrame.Position, (targetPosition - Camera.CFrame.Position).unit * 1000)
    local ignoreList = {player.Character}
    local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)

    if hit then
        local targetPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        return targetPlayer ~= nil
    end
    return false
end

-- Function to get the closest target in radius
local function getClosestTargetInRadius()
    local target = nil
    local shortestDistance = math.huge

    for _, playerModel in pairs(Players:GetPlayers()) do
        if playerModel ~= player and playerModel.Character then
            local character = playerModel.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPartInstance = character:FindFirstChild(targetPart)
            if humanoid and targetPartInstance and humanoid.Health > 0 then
                -- Team check
                if not useTeamCheck or (player.Team and playerModel.Team ~= player.Team) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPartInstance.Position)
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
                    if distanceToCenter <= radius and isTargetVisible(targetPartInstance.Position) then
                        local distance = (targetPartInstance.Position - Camera.CFrame.Position).magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            target = targetPartInstance
                        end
                    end
                end
            end
        end
    end

    return target
end

-- Function to aim at the target
local function aimAtTarget()
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        -- Check if the current target is within the radius
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
        if distanceToCenter <= radius and isTargetVisible(currentTarget.Position) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            drawing.Color = Color3.new(0, 1, 0)

            -- Teleport the player behind the target if enabled
            if teleportEnabled then
                local targetPosition = currentTarget.Position
                local behindTarget = targetPosition - (Camera.CFrame.LookVector * 5) -- Adjust the distance as needed
                local character = player.Character or player.CharacterAdded:Wait()
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                humanoidRootPart.CFrame = CFrame.new(behindTarget)
            end

            return
        else
            currentTarget = nil -- Target out of radius, reset
        end
    end

    -- Find a new target
    local target = getClosestTargetInRadius()
    if target then
        currentTarget = target
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        drawing.Color = Color3.new(0, 1, 0)

        -- Teleport the player behind the target if enabled
        if teleportEnabled then
            local targetPosition = currentTarget.Position
            local behindTarget = targetPosition - (Camera.CFrame.LookVector * 5) -- Adjust the distance as needed
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CFrame = CFrame.new(behindTarget)
        end
    else
        drawing.Color = Color3.new(1, 0, 0)
    end
end

-- Function to update the ESP
local function UpdateESP()
    if not espEnabled then
        for _, plr in pairs(esp) do
            plr.box.Visible = false
            plr.name.Visible = false
        end
        return
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local rootPart = plr.Character.HumanoidRootPart

            -- Determine the color based on the team
            local color = plr.TeamColor == Players.LocalPlayer.TeamColor and Green or Red

            if not esp[plr] then
                esp[plr] = {
                    box = NewDrawing("Square", {
                        Thickness = 2,
                        Color = color,
                        Filled = false
                    }),
                    name = NewDrawing("Text", {
                        Text = plr.Name,
                        Size = 14, -- Adjusted text size
                        Center = true,
                        Outline = true,
                        Color = color
                    })
                }
            else
                -- Update the color if the player's team changes
                esp[plr].box.Color = color
                esp[plr].name.Color = color
            end

            local box = esp[plr].box
            local name = esp[plr].name

            -- Box ESP
            local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local size = 2000 / vector.Z -- Adjust size based on distance
                box.Size = Vector2.new(size, size)
                box.Position = Vector2.new(vector.X - size / 2, vector.Y - size / 2)
                box.Visible = true

                -- Name display
                name.Position = Vector2.new(vector.X, vector.Y - size / 2 - 20)
                name.Visible = true
            else
                box.Visible = false
                name.Visible = false
            end
        else
            -- Remove ESP elements if the character is no longer valid
            if esp[plr] then
                esp[plr].box.Visible = false
                esp[plr].name.Visible = false
                esp[plr] = nil
            end
        end
    end
end

-- Create the GUI interface
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Background frame
local background = Instance.new("Frame")
background.Size = UDim2.new(0, 220, 0, 300)
background.Position = UDim2.new(0, 10, 0, 10)
background.BackgroundColor3 = Color3.new(0, 0, 0)
background.BorderSizePixel = 0
background.ZIndex = 10
background.Parent = screenGui

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = background

-- Neon outline with animation
local outline = Instance.new("UIStroke")
outline.Color = Color3.new(1, 1, 0)
outline.Thickness = 2
outline.Parent = background

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
local tween = TweenService:Create(outline, tweenInfo, {Color = Color3.new(1, 0.8, 0)})
tween:Play()

-- Drag bar for moving the GUI
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 20)
dragBar.Position = UDim2.new(0, 0, 1, 10)
dragBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
dragBar.BorderSizePixel = 0
dragBar.ZIndex = 11
dragBar.Parent = background

local dragBarCorner = Instance.new("UICorner")
dragBarCorner.CornerRadius = UDim.new(0, 8)
dragBarCorner.Parent = dragBar

-- Drag functionality
local dragging = false
local dragStartPos
local guiStartPos

local function updateDrag(input)
    local delta = input.Position - dragStartPos
    background.Position = UDim2.new(guiStartPos.X.Scale, guiStartPos.X.Offset + delta.X, guiStartPos.Y.Scale, guiStartPos.Y.Offset + delta.Y)
end

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStartPos = input.Position
        guiStartPos = background.Position
    end
end)

dragBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

dragBar.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(input)
    end
end)

-- Scrolling frame for buttons
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -20, 1, -60)
scrollingFrame.Position = UDim2.new(0, 10, 0, 40)
scrollingFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.ScrollBarThickness = 8
scrollingFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
scrollingFrame.ZIndex = 10
scrollingFrame.Parent = background

-- Layout for automatic button placement
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = scrollingFrame

-- Toggle Aim button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, 0, 0, 30)
toggleButton.Text = "Toggle Aim"
toggleButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.SciFi
toggleButton.ZIndex = 10
toggleButton.Parent = scrollingFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

toggleButton.MouseButton1Click:Connect(function()
    aiming = not aiming
    toggleButton.Text = aiming and "Aiming: ON" or "Aiming: OFF"
    if not aiming then
        drawing.Color = Color3.new(1, 0, 0)
        currentTarget = nil
    end
end)

-- Radius input
local radiusInput = Instance.new("TextBox")
radiusInput.Size = UDim2.new(1, 0, 0, 30)
radiusInput.Text = "Radius: " .. radius
radiusInput.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
radiusInput.TextColor3 = Color3.new(1, 1, 1)
radiusInput.Font = Enum.Font.SciFi
radiusInput.ZIndex = 10
radiusInput.Parent = scrollingFrame

local textBoxCorner = Instance.new("UICorner")
textBoxCorner.CornerRadius = UDim.new(0, 6)
textBoxCorner.Parent = radiusInput

radiusInput.FocusLost:Connect(function()
    local newRadius = tonumber(radiusInput.Text:match("%d+"))
    if newRadius and newRadius >= 1 and newRadius <= 500 then
        radius = newRadius
        drawing.Radius = radius
        radiusInput.Text = "Radius: " .. radius
    else
        radiusInput.Text = "Radius: " .. radius
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Error",
            Text = "Invalid radius. Please enter a number between 1 and 500.",
            Duration = 5
        })
    end
end)

-- Team Check button
local teamCheckButton = Instance.new("TextButton")
teamCheckButton.Size = UDim2.new(1, 0, 0, 30)
teamCheckButton.Text = "Team Check: " .. (useTeamCheck and "ON" or "OFF")
teamCheckButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
teamCheckButton.TextColor3 = Color3.new(1, 1, 1)
teamCheckButton.Font = Enum.Font.SciFi
teamCheckButton.ZIndex = 10
teamCheckButton.Parent = scrollingFrame

local teamCheckCorner = Instance.new("UICorner")
teamCheckCorner.CornerRadius = UDim.new(0, 6)
teamCheckCorner.Parent = teamCheckButton

teamCheckButton.MouseButton1Click:Connect(function()
    useTeamCheck = not useTeamCheck
    teamCheckButton.Text = "Team Check: " .. (useTeamCheck and "ON" or "OFF")
end)

-- Wall Check button
local wallCheckButton = Instance.new("TextButton")
wallCheckButton.Size = UDim2.new(1, 0, 0, 30)
wallCheckButton.Text = "Wall Check: " .. (useWallCheck and "ON" or "OFF")
wallCheckButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
wallCheckButton.TextColor3 = Color3.new(1, 1, 1)
wallCheckButton.Font = Enum.Font.SciFi
wallCheckButton.ZIndex = 10
wallCheckButton.Parent = scrollingFrame

local wallCheckCorner = Instance.new("UICorner")
wallCheckCorner.CornerRadius = UDim.new(0, 6)
wallCheckCorner.Parent = wallCheckButton

wallCheckButton.MouseButton1Click:Connect(function()
    useWallCheck = not useWallCheck
    wallCheckButton.Text = "Wall Check: " .. (useWallCheck and "ON" or "OFF")
end)

-- Target Part button
local targetPartButton = Instance.new("TextButton")
targetPartButton.Size = UDim2.new(1, 0, 0, 30)
targetPartButton.Text = "Target: " .. targetPart
targetPartButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
targetPartButton.TextColor3 = Color3.new(1, 1, 1)
targetPartButton.Font = Enum.Font.SciFi
targetPartButton.ZIndex = 10
targetPartButton.Parent = scrollingFrame

local targetPartCorner = Instance.new("UICorner")
targetPartCorner.CornerRadius = UDim.new(0, 6)
targetPartCorner.Parent = targetPartButton

targetPartButton.MouseButton1Click:Connect(function()
    targetPart = (targetPart == "Head" and "Torso" or "Head")
    targetPartButton.Text = "Target: " .. targetPart
    currentTarget = nil
end)

-- Lock On button
local lockOnButton = Instance.new("TextButton")
lockOnButton.Size = UDim2.new(1, 0, 0, 30)
lockOnButton.Text = "Lock On: " .. (lockOnTarget and "ON" or "OFF")
lockOnButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
lockOnButton.TextColor3 = Color3.new(1, 1, 1)
lockOnButton.Font = Enum.Font.SciFi
lockOnButton.ZIndex = 10
lockOnButton.Parent = scrollingFrame

local lockOnCorner = Instance.new("UICorner")
lockOnCorner.CornerRadius = UDim.new(0, 6)
lockOnCorner.Parent = lockOnButton

lockOnButton.MouseButton1Click:Connect(function()
    lockOnTarget = not lockOnTarget
    lockOnButton.Text = "Lock On: " .. (lockOnTarget and "ON" or "OFF")
    if not lockOnTarget then
        currentTarget = nil
    end
end)

-- PC Mod button
local pcModButton = Instance.new("TextButton")
pcModButton.Size = UDim2.new(1, 0, 0, 30)
pcModButton.Text = "PC Mod: OFF"
pcModButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
pcModButton.TextColor3 = Color3.new(1, 1, 1)
pcModButton.Font = Enum.Font.SciFi
pcModButton.ZIndex = 10
pcModButton.Parent = scrollingFrame

local pcModCorner = Instance.new("UICorner")
pcModCorner.CornerRadius = UDim.new(0, 6)
pcModCorner.Parent = pcModButton

pcModButton.MouseButton1Click:Connect(function()
    pcMod = not pcMod
    pcModButton.Text = "PC Mod: " .. (pcMod and "ON" or "OFF")
end)

-- Minimize button
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -35, 0, 5)
minimizeButton.Text = "-"
minimizeButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.SciFi
minimizeButton.ZIndex = 11
minimizeButton.Parent = background

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

-- K button for restoring the interface
local kButton = Instance.new("TextButton")
kButton.Size = UDim2.new(0, 40, 0, 40)
kButton.Position = UDim2.new(0, 10, 0, 10)
kButton.Text = "K"
kButton.BackgroundColor3 = Color3.new(0, 0, 0)
kButton.TextColor3 = Color3.new(1, 1, 0)
kButton.Font = Enum.Font.SciFi
kButton.TextSize = 20
kButton.Visible = false
kButton.ZIndex = 11
kButton.Parent = screenGui

local kCorner = Instance.new("UICorner")
kCorner.CornerRadius = UDim.new(0, 8)
kCorner.Parent = kButton

local kOutline = Instance.new("UIStroke")
kOutline.Color = Color3.new(1, 1, 0)
kOutline.Thickness = 2
kOutline.Parent = kButton

local kTween = TweenService:Create(kOutline, tweenInfo, {Color = Color3.new(1, 0.8, 0)})
kTween:Play()

-- Drag functionality for K button
local kDragging = false
local kDragStartPos
local kGuiStartPos

local function updateKDrag(input)
    local delta = input.Position - kDragStartPos
    kButton.Position = UDim2.new(kGuiStartPos.X.Scale, kGuiStartPos.X.Offset + delta.X, kGuiStartPos.Y.Scale, kGuiStartPos.Y.Offset + delta.Y)
end

kButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        kDragging = true
        kDragStartPos = input.Position
        kGuiStartPos = kButton.Position
    end
end)

kButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        kDragging = false
    end
end)

kButton.InputChanged:Connect(function(input)
    if kDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateKDrag(input)
    end
end)

-- Minimize/Restore logic
minimizeButton.MouseButton1Click:Connect(function()
    background.Visible = false
    minimizeButton.Visible = false
    kButton.Visible = true
end)

kButton.MouseButton1Click:Connect(function()
    background.Visible = true
    minimizeButton.Visible = true
    kButton.Visible = false
end)

-- ESP Toggle button
local espToggleButton = Instance.new("TextButton")
espToggleButton.Size = UDim2.new(1, 0, 0, 30)
espToggleButton.Text = "ESP: ON"
espToggleButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
espToggleButton.TextColor3 = Color3.new(1, 1, 1)
espToggleButton.Font = Enum.Font.SciFi
espToggleButton.ZIndex = 10
espToggleButton.Parent = scrollingFrame

local espToggleCorner = Instance.new("UICorner")
espToggleCorner.CornerRadius = UDim.new(0, 6)
espToggleCorner.Parent = espToggleButton

espToggleButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espToggleButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
end)

-- Teleport Toggle button
local teleportToggleButton = Instance.new("TextButton")
teleportToggleButton.Size = UDim2.new(1, 0, 0, 30)
teleportToggleButton.Text = "Teleport: OFF"
teleportToggleButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
teleportToggleButton.TextColor3 = Color3.new(1, 1, 1)
teleportToggleButton.Font = Enum.Font.SciFi
teleportToggleButton.ZIndex = 10
teleportToggleButton.Parent = scrollingFrame

local teleportToggleCorner = Instance.new("UICorner")
teleportToggleCorner.CornerRadius = UDim.new(0, 6)
teleportToggleCorner.Parent = teleportToggleButton

teleportToggleButton.MouseButton1Click:Connect(function()
    teleportEnabled = not teleportEnabled
    teleportToggleButton.Text = "Teleport: " .. (teleportEnabled and "ON" or "OFF")
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(character)
    -- Reinitialize references if needed
    currentTarget = nil
end)

-- Main loop for aiming and ESP
RunService.RenderStepped:Connect(function()
    if pcMod then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            aiming = true
            aimAtTarget()
        else
            aiming = false
            drawing.Color = Color3.new(1, 0, 0)
            currentTarget = nil
        end
    else
        if aiming then
            aimAtTarget()
        else
            drawing.Color = Color3.new(1, 0, 0)
            currentTarget = nil
        end
    end
    UpdateESP()
end)
