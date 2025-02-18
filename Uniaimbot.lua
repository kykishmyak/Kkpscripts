local player = game.Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local aiming = false
local radius = 150
local useTeamCheck = true
local useWallCheck = true
local targetPart = "Head" -- Целевая часть по умолчанию (Head или Torso)
local lockOnTarget = false -- Зафиксировать цель до её смерти или выхода из радиуса
local currentTarget = nil -- Текущая зафиксированная цель

local drawing = Drawing.new("Circle")
drawing.Color = Color3.new(1, 0, 0)
drawing.Thickness = 2
drawing.Radius = radius
drawing.Filled = false
drawing.Visible = true

local screenSize = workspace.CurrentCamera.ViewportSize
drawing.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)

-- Функция проверки видимости цели
local function isTargetVisible(targetPosition)
    if not useWallCheck then
        return true
    end
    local ray = Ray.new(camera.CFrame.Position, (targetPosition - camera.CFrame.Position).unit * 1000)
    local ignoreList = {player.Character}
    local hit, position = game.Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)

    if hit then
        local targetPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
        return targetPlayer ~= nil
    end
    return false
end

local function getClosestTargetInRadius()
    local target = nil
    local shortestDistance = math.huge

    for _, playerModel in pairs(game.Players:GetPlayers()) do
        if playerModel ~= player and playerModel.Character then
            local character = playerModel.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPartInstance = character:FindFirstChild(targetPart)
            if humanoid and targetPartInstance and humanoid.Health > 0 then
                -- Проверка на команду
                if not useTeamCheck or (player.Team and playerModel.Team ~= player.Team) then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPartInstance.Position)
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
                    if distanceToCenter <= radius and isTargetVisible(targetPartInstance.Position) then
                        local distance = (targetPartInstance.Position - camera.CFrame.Position).magnitude
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

local function aimAtTarget()
    if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChild("Humanoid") and currentTarget.Parent.Humanoid.Health > 0 then
        -- Проверка, находится ли текущая цель в радиусе
        local screenPos, onScreen = camera:WorldToViewportPoint(currentTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
        if distanceToCenter <= radius and isTargetVisible(currentTarget.Position) then
            camera.CFrame = CFrame.new(camera.CFrame.Position, currentTarget.Position)
            drawing.Color = Color3.new(0, 1, 0)
            return
        else
            currentTarget = nil -- Цель вне радиуса, сброс
        end
    end

    -- Поиск новой цели
    local target = getClosestTargetInRadius()
    if target then
        currentTarget = target
        camera.CFrame = CFrame.new(camera.CFrame.Position, target.Position)
        drawing.Color = Color3.new(0, 1, 0)
    else
        drawing.Color = Color3.new(1, 0, 0)
    end
end

-- Создание интерфейса
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Фон
local background = Instance.new("Frame")
background.Size = UDim2.new(0, 220, 0, 300) -- Увеличена высота для новой кнопки
background.Position = UDim2.new(0, 10, 0, 10)
background.BackgroundColor3 = Color3.new(0, 0, 0)
background.BorderSizePixel = 0
background.Parent = screenGui

-- Закругленные углы
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = background

-- Неоновая обводка с анимацией
local outline = Instance.new("UIStroke")
outline.Color = Color3.new(1, 1, 0)
outline.Thickness = 2
outline.Parent = background

-- Анимация обводки
local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
local tween = TweenService:Create(outline, tweenInfo, {Color = Color3.new(1, 0.8, 0)}) -- Темно-желтый к ярко-желтому
tween:Play()

-- Панель перетаскивания (для перетаскивания интерфейса)
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 20) -- Увеличена высота для удобства перетаскивания
dragBar.Position = UDim2.new(0, 0, 0, 0) -- Перемещено вверх интерфейса
dragBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
dragBar.BorderSizePixel = 0
dragBar.Parent = background

-- Закругленные углы для панели перетаскивания
local dragBarCorner = Instance.new("UICorner")
dragBarCorner.CornerRadius = UDim.new(0, 8)
dragBarCorner.Parent = dragBar

-- Перетаскивание интерфейса
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

-- ScrollingFrame для кнопок
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -20, 1, -60)
scrollingFrame.Position = UDim2.new(0, 10, 0, 40)
scrollingFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.ScrollBarThickness = 8
scrollingFrame.CanvasSize = UDim2.new(0, 0, 2, 0) -- Установите высоту CanvasSize для прокрутки
scrollingFrame.Parent = background

-- Layout для автоматического размещения кнопок
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = scrollingFrame

-- Кнопка переключения прицеливания
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, 0, 0, 30)
toggleButton.Text = "Toggle Aim"
toggleButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.SciFi
toggleButton.Parent = scrollingFrame

-- Закругленные углы для кнопок
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

toggleButton.MouseButton1Click:Connect(function()
    aiming = not aiming
    toggleButton.Text = aiming and "Aiming: ON" or "Aiming: OFF"
    if not aiming then
        drawing.Color = Color3.new(1, 0, 0)
        currentTarget = nil -- Сброс цели при отключении прицеливания
    end
end)

-- Ввод радиуса
local radiusInput = Instance.new("TextBox")
radiusInput.Size = UDim2.new(1, 0, 0, 30)
radiusInput.Text = "Radius: " .. radius
radiusInput.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
radiusInput.TextColor3 = Color3.new(1, 1, 1)
radiusInput.Font = Enum.Font.SciFi
radiusInput.Parent = scrollingFrame

-- Закругленные углы для текстового поля
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

-- Кнопка переключения проверки команды
local teamCheckButton = Instance.new("TextButton")
teamCheckButton.Size = UDim2.new(1, 0, 0, 30)
teamCheckButton.Text = "Team Check: " .. (useTeamCheck and "ON" or "OFF")
teamCheckButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
teamCheckButton.TextColor3 = Color3.new(1, 1, 1)
teamCheckButton.Font = Enum.Font.SciFi
teamCheckButton.Parent = scrollingFrame

-- Закругленные углы для кнопки проверки команды
local teamCheckCorner = Instance.new("UICorner")
teamCheckCorner.CornerRadius = UDim.new(0, 6)
teamCheckCorner.Parent = teamCheckButton

teamCheckButton.MouseButton1Click:Connect(function()
    useTeamCheck = not useTeamCheck
    teamCheckButton.Text = "Team Check: " .. (useTeamCheck and "ON" or "OFF")
end)

-- Кнопка переключения проверки стен
local wallCheckButton = Instance.new("TextButton")
wallCheckButton.Size = UDim2.new(1, 0, 0, 30)
wallCheckButton.Text = "Wall Check: " .. (useWallCheck and "ON" or "OFF")
wallCheckButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
wallCheckButton.TextColor3 = Color3.new(1, 1, 1)
wallCheckButton.Font = Enum.Font.SciFi
wallCheckButton.Parent = scrollingFrame

-- Закругленные углы для кнопки проверки стен
local wallCheckCorner = Instance.new("UICorner")
wallCheckCorner.CornerRadius = UDim.new(0, 6)
wallCheckCorner.Parent = wallCheckButton

wallCheckButton.MouseButton1Click:Connect(function()
    useWallCheck = not useWallCheck
    wallCheckButton.Text = "Wall Check: " .. (useWallCheck and "ON" or "OFF")
end)

-- Выбор целевой части (Head или Torso)
local targetPartButton = Instance.new("TextButton")
targetPartButton.Size = UDim2.new(1, 0, 0, 30)
targetPartButton.Text = "Target: " .. targetPart
targetPartButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
targetPartButton.TextColor3 = Color3.new(1, 1, 1)
targetPartButton.Font = Enum.Font.SciFi
targetPartButton.Parent = scrollingFrame

-- Закругленные углы для кнопки выбора целевой части
local targetPartCorner = Instance.new("UICorner")
targetPartCorner.CornerRadius = UDim.new(0, 6)
targetPartCorner.Parent = targetPartButton

targetPartButton.MouseButton1Click:Connect(function()
    targetPart = (targetPart == "Head" and "Torso" or "Head")
    targetPartButton.Text = "Target: " .. targetPart
    currentTarget = nil -- Сброс цели при изменении целевой части
end)

-- Кнопка фиксации цели
local lockOnButton = Instance.new("TextButton")
lockOnButton.Size = UDim2.new(1, 0, 0, 30)
lockOnButton.Text = "Lock On: " .. (lockOnTarget and "ON" or "OFF")
lockOnButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
lockOnButton.TextColor3 = Color3.new(1, 1, 1)
lockOnButton.Font = Enum.Font.SciFi
lockOnButton.Parent = scrollingFrame

-- Закругленные углы для кнопки фиксации цели
local lockOnCorner = Instance.new("UICorner")
lockOnCorner.CornerRadius = UDim.new(0, 6)
lockOnCorner.Parent = lockOnButton

lockOnButton.MouseButton1Click:Connect(function()
    lockOnTarget = not lockOnTarget
    lockOnButton.Text = "Lock On: " .. (lockOnTarget and "ON" or "OFF")
    if not lockOnTarget then
        currentTarget = nil -- Сброс цели при отключении фиксации
    end
end)

-- Кнопка свертывания
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -35, 0, 5) -- Перемещено вверх, чтобы избежать наложения
minimizeButton.Text = "-"
minimizeButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.SciFi
minimizeButton.Parent = background

-- Закругленные углы для кнопки свертывания
local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

-- Кнопка восстановления интерфейса (K)
local kButton = Instance.new("TextButton")
kButton.Size = UDim2.new(0, 40, 0, 40)
kButton.Position = UDim2.new(0, 10, 0, 10)
kButton.Text = "K"
kButton.BackgroundColor3 = Color3.new(0, 0, 0)
kButton.TextColor3 = Color3.new(1, 1, 0)
kButton.Font = Enum.Font.SciFi
kButton.TextSize = 20
kButton.Visible = false
kButton.Parent = screenGui

-- Закругленные углы для кнопки K
local kCorner = Instance.new("UICorner")
kCorner.CornerRadius = UDim.new(0, 8)
kCorner.Parent = kButton

-- Неоновая обводка для кнопки K
local kOutline = Instance.new("UIStroke")
kOutline.Color = Color3.new(1, 1, 0)
kOutline.Thickness = 2
kOutline.Parent = kButton

-- Анимация обводки кнопки K
local kTween = TweenService:Create(kOutline, tweenInfo, {Color = Color3.new(1, 0.8, 0)})
kTween:Play()

-- Перетаскивание кнопки K
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

-- Логика свертывания/восстановления
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

-- Кнопка для скрытия круга
local hideCircleButton = Instance.new("TextButton")
hideCircleButton.Size = UDim2.new(1, 0, 0, 30)
hideCircleButton.Text = "Hide Circle"
hideCircleButton.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
hideCircleButton.TextColor3 = Color3.new(1, 1, 1)
hideCircleButton.Font = Enum.Font.SciFi
hideCircleButton.Parent = scrollingFrame

-- Закругленные углы для кнопки скрытия круга
local hideCircleCorner = Instance.new("UICorner")
hideCircleCorner.CornerRadius = UDim.new(0, 6)
hideCircleCorner.Parent = hideCircleButton

hideCircleButton.MouseButton1Click:Connect(function()
    drawing.Visible = not drawing.Visible
    hideCircleButton.Text = drawing.Visible and "Hide Circle" or "Show Circle"
end)

-- Основной цикл для прицеливания
game:GetService("RunService").RenderStepped:Connect(function()
    if aiming then
        aimAtTarget()
    end
end)
