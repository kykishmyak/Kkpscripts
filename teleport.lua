-- Load necessary services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Define colors
local Blue = Color3.fromRGB(0, 0, 255)

-- Teleport settings
local player = Players.LocalPlayer

-- Create the GUI interface
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Background frame
local background = Instance.new("Frame")
background.Size = UDim2.new(0, 220, 0, 150)
background.Position = UDim2.new(0, 10, 0, 10)
background.BackgroundColor3 = Color3.new(0, 0, 0.5) -- Dark blue background
background.BorderSizePixel = 0
background.ZIndex = 10
background.Parent = screenGui

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = background

-- Neon outline with animation
local outline = Instance.new("UIStroke")
outline.Color = Blue
outline.Thickness = 2
outline.Parent = background

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
local tween = TweenService:Create(outline, tweenInfo, {Color = Color3.new(0, 1, 1)})
tween:Play()

-- Drag bar for moving the GUI
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 20)
dragBar.Position = UDim2.new(0, 0, 0, 0)
dragBar.BackgroundColor3 = Color3.new(0, 0, 0.5) -- Dark blue background
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

-- TextBox for entering the player's name
local nameInput = Instance.new("TextBox")
nameInput.Size = UDim2.new(1, -20, 0, 30)
nameInput.Position = UDim2.new(0, 10, 0, 40)
nameInput.BackgroundColor3 = Color3.new(0, 0, 0.3) -- Slightly lighter blue
nameInput.TextColor3 = Color3.new(1, 1, 1)
nameInput.PlaceholderText = "Enter Player Name or Display Name"
nameInput.Font = Enum.Font.SciFi
nameInput.ZIndex = 10
nameInput.Parent = background

local textBoxCorner = Instance.new("UICorner")
textBoxCorner.CornerRadius = UDim.new(0, 6)
textBoxCorner.Parent = nameInput

-- Teleport button
local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1, -20, 0, 30)
teleportButton.Position = UDim2.new(0, 10, 0, 80)
teleportButton.Text = "Teleport"
teleportButton.BackgroundColor3 = Color3.new(0, 0, 0.3) -- Slightly lighter blue
teleportButton.TextColor3 = Color3.new(1, 1, 1)
teleportButton.Font = Enum.Font.SciFi
teleportButton.ZIndex = 10
teleportButton.Parent = background

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = teleportButton

-- Function to find the best matching player
local function findBestMatchingPlayer(targetName)
    local bestMatch = nil
    local bestMatchLength = 0

    for _, player in pairs(Players:GetPlayers()) do
        local displayName = player.DisplayName:lower()
        local name = player.Name:lower()
        if displayName:find(targetName:lower()) or name:find(targetName:lower()) then
            local matchLength = math.max(#displayName, #name)
            if matchLength > bestMatchLength then
                bestMatch = player
                bestMatchLength = matchLength
            end
        end
    end

    return bestMatch
end

-- Function to teleport to the player
local function teleportToPlayer(targetPlayer)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 5, 0)) -- Teleport slightly above the target
    else
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Error",
            Text = "Player not found or not in game.",
            Duration = 5
        })
    end
end

-- Connect the teleport button
teleportButton.MouseButton1Click:Connect(function()
    local targetName = nameInput.Text
    if targetName and targetName ~= "" then
        local targetPlayer = findBestMatchingPlayer(targetName)
        if targetPlayer then
            teleportToPlayer(targetPlayer)
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Error",
                Text = "No matching player found.",
                Duration = 5
            })
        end
    else
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Error",
            Text = "Please enter a valid player name or display name.",
            Duration = 5
        })
    end
end)
