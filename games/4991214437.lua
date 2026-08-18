local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildWhichIsA("Terrain")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if Terrain then
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 1
end

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.FogStart = 9e9
Lighting.Ambient = Color3.fromRGB(255, 255, 255)
Lighting.Brightness = 2
Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0
Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
Lighting.ClockTime = 12
Lighting.ExposureCompensation = 0.5

settings().Rendering.QualityLevel = 1

for _, v in pairs(game:GetDescendants()) do
    if v:IsA("BasePart") then
        v.CastShadow = false
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0

    elseif v:IsA("Decal") then
        v.Transparency = 1

    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
        v.Lifetime = NumberRange.new(0)
    end
end

for _, v in pairs(Lighting:GetDescendants()) do
    if v:IsA("PostEffect") then
        v.Enabled = false
    end
end

workspace.DescendantAdded:Connect(function(child)
    task.spawn(function()
        if child:IsA("Sparkles")
            or child:IsA("Smoke")
            or child:IsA("Fire")
            or child:IsA("Beam") then

            RunService.Heartbeat:Wait()
            child:Destroy()

        elseif child:IsA("BasePart") then
            child.CastShadow = false
        end
    end)
end)

local playerData = {}

local HIGHLIGHT_TRANSPARENCY = 0.5
local FORCEFIELD_COLOR = Color3.fromRGB(0, 255, 0)

local function getTeamColor(player)
    if player.Team and player.Team.TeamColor then
        return player.Team.TeamColor.Color
    end
    return Color3.fromRGB(128, 128, 128)
end

local function hasForceField(character)
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("ForceField") then
            return true
        end
    end
    return false
end

local function getColorForCharacter(character, player)
    if hasForceField(character) then
        return FORCEFIELD_COLOR
    end
    return getTeamColor(player)
end

local function updateHighlightColor(player)
    local data = playerData[player]
    if not data then return end
    if not data.highlight then return end
    
    local character = player.Character
    if not character then return end
    
    local color = getColorForCharacter(character, player)
    
    data.highlight.OutlineColor = color
    data.highlight.FillColor = color
    
    if data.nametag then
        local nameLabel = data.nametag:FindFirstChild("Name")
        if nameLabel then
            nameLabel.TextColor3 = color
        end
    end
end

local function createNametag(character, player)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Nametag"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 1.5, 0)
    billboard.MaxDistance = 9e9
    billboard.Parent = character

    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if head then
        billboard.Adornee = head
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = getColorForCharacter(character, player)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = player.DisplayName
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = billboard

    return billboard
end

local function cleanupPlayerData(player)
    local data = playerData[player]
    if not data then return end
    
    if data.highlight then data.highlight:Destroy() end
    if data.nametag then data.nametag:Destroy() end
    if data.descendantAddedConn then data.descendantAddedConn:Disconnect() end
    if data.descendantRemovingConn then data.descendantRemovingConn:Disconnect() end
    if data.teamConn then data.teamConn:Disconnect() end
    if data.destroyingConn then data.destroyingConn:Disconnect() end
    
    playerData[player] = nil
end

local function createESP(player, character)
    cleanupPlayerData(player)
    
    local color = getColorForCharacter(character, player)

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP"
    highlight.FillTransparency = HIGHLIGHT_TRANSPARENCY
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = color
    highlight.FillColor = color
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character

    local nametag = createNametag(character, player)

    local descendantAddedConn = character.DescendantAdded:Connect(function(child)
        if child:IsA("ForceField") then
            task.wait()
            updateHighlightColor(player)
        end
    end)

    local descendantRemovingConn = character.DescendantRemoving:Connect(function(child)
        if child:IsA("ForceField") then
            task.wait()
            updateHighlightColor(player)
        end
    end)

    local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
        updateHighlightColor(player)
    end)

    local destroyingConn = character.Destroying:Connect(function()
        cleanupPlayerData(player)
    end)

    playerData[player] = {
        highlight = highlight,
        nametag = nametag,
        descendantAddedConn = descendantAddedConn,
        descendantRemovingConn = descendantRemovingConn,
        teamConn = teamConn,
        destroyingConn = destroyingConn,
        character = character
    }
end

local function onPlayerAdded(player)
    if player == LocalPlayer then return end

    local function onCharacterAdded(character)
        task.wait(0.1)
        createESP(player, character)
    end

    player.CharacterAdded:Connect(onCharacterAdded)

    if player.Character then
        onCharacterAdded(player.Character)
    end
end

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    cleanupPlayerData(player)
end)

local FOV_RADIUS = 150
local FOV_COLOR = Color3.fromRGB(255, 255, 255)
local FOV_THICKNESS = 2
local FOV_ANIMATION_SPEED = 0.15

local fovCircle = Instance.new("ScreenGui")
fovCircle.Name = "FOVCircle"
fovCircle.ResetOnSpawn = false
fovCircle.IgnoreGuiInset = true
fovCircle.Parent = LocalPlayer:WaitForChild("PlayerGui")

local fovContainer = Instance.new("Frame")
fovContainer.Name = "FOVContainer"
fovContainer.Size = UDim2.new(0, FOV_RADIUS * 2, 0, FOV_RADIUS * 2)
fovContainer.AnchorPoint = Vector2.new(0.5, 0.5)
fovContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
fovContainer.BackgroundTransparency = 1
fovContainer.Parent = fovCircle

local fovCircleDraw = Instance.new("Frame")
fovCircleDraw.Name = "FOVCircleDraw"
fovCircleDraw.Size = UDim2.new(1, 0, 1, 0)
fovCircleDraw.Position = UDim2.new(0, 0, 0, 0)
fovCircleDraw.BackgroundTransparency = 1
fovCircleDraw.BorderSizePixel = 0
fovCircleDraw.Parent = fovContainer

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircleDraw

local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = FOV_THICKNESS
fovStroke.Color = FOV_COLOR
fovStroke.Transparency = 0
fovStroke.Parent = fovCircleDraw

fovCircle.Enabled = false
fovStroke.Transparency = 1

local fovTween = nil

local function showFOVCircle()
    if fovTween then
        fovTween:Cancel()
    end
    
    fovCircle.Enabled = true
    
    fovTween = TweenService:Create(fovStroke, TweenInfo.new(FOV_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0
    })
    
    fovTween:Play()
end

local function hideFOVCircle()
    if fovTween then
        fovTween:Cancel()
    end
    
    fovTween = TweenService:Create(fovStroke, TweenInfo.new(FOV_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Transparency = 1
    })
    
    fovTween:Play()
    
    fovTween.Completed:Connect(function()
        if fovStroke.Transparency >= 0.99 then
            fovCircle.Enabled = false
        end
    end)
end

local aimbotEnabled = false
local aimConnection = nil
local currentTarget = nil
local currentTargetPart = nil

local MAX_DISTANCE = 500
local SMOOTHNESS = 0.1

local BODY_PARTS_PRIORITY = {
    "Head",
    "Torso",
    "HumanoidRootPart",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg"
}

local function isAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end
    return true
end

local function isCharacterValid(character)
    if not character then return false end
    if not character.Parent then return false end
    return true
end

local function isOnScreen(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local screenSize = Camera.ViewportSize
    if screenPos.X < 0 or screenPos.X > screenSize.X then return false end
    if screenPos.Y < 0 or screenPos.Y > screenSize.Y then return false end
    
    return true
end

local function isInFOV(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
    
    return distanceFromCenter <= FOV_RADIUS
end

local function isInRange(targetPart)
    if not targetPart then return false end
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    return distance <= MAX_DISTANCE
end

local function hasLineOfSight(targetPart, targetCharacter)
    if not targetPart or not targetPart.Parent then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - origin)
    local distance = direction.Magnitude
    direction = direction.Unit
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    
    local ignoreList = {}
    
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    
    if targetCharacter and targetCharacter.Parent then
        table.insert(ignoreList, targetCharacter)
    end
    
    rayParams.FilterDescendantsInstances = ignoreList
    
    local currentPos = origin
    local remainingDist = distance
    local maxIterations = 100
    local iterations = 0
    
    while remainingDist > 0.01 and iterations < maxIterations do
        iterations = iterations + 1
        
        local rayResult = workspace:Raycast(currentPos, direction * remainingDist, rayParams)
        
        if not rayResult then
            return true
        end
        
        local hitPart = rayResult.Instance
        local hitPos = rayResult.Position
        
        if hitPart:IsDescendantOf(targetCharacter) then
            return true
        end
        
        if hitPart.CanCollide then
            return false
        end
        
        local hitDist = (hitPos - currentPos).Magnitude
        currentPos = hitPos + direction * 0.01
        remainingDist = remainingDist - hitDist - 0.01
    end
    
    return true
end

local function hasGunScript(character)
    if not character or not character.Parent then return false end
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            local gunScript = child:FindFirstChild("GunScript")
            if gunScript and gunScript:IsA("LocalScript") then
                task.spawn(function()
                    local startTime = tick()
                    local found = false
                    
                    while tick() - startTime < 1 and not found do
                        task.wait(0.1)
                        
                        local attachmentFolder = child:FindFirstChild("AttachmentFolder")
                        if attachmentFolder then
                            for _, item in pairs(attachmentFolder:GetChildren()) do
                                local stats = item:FindFirstChild("Stats")
                                if stats then
                                    local aimSway = stats:FindFirstChild("AimSway")
                                    if aimSway and aimSway:IsA("NumberValue") then
                                        aimSway.Value = 0
                                        found = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)
                return true
            end
        end
    end
    return false
end

local function getPartPriority(partName)
    for index, priorityName in ipairs(BODY_PARTS_PRIORITY) do
        if partName == priorityName then
            return index
        end
    end
    return #BODY_PARTS_PRIORITY + 1
end

local function findBestTargetPart(character)
    if not isCharacterValid(character) or not isAlive(character) then
        return nil
    end
    
    if hasForceField(character) then
        return nil
    end
    
    local bestPart = nil
    local bestPriority = #BODY_PARTS_PRIORITY + 1
    
    for _, partName in ipairs(BODY_PARTS_PRIORITY) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") and part.Parent then
            if isOnScreen(part) and isInFOV(part) and isInRange(part) and hasLineOfSight(part, character) then
                local priority = getPartPriority(partName)
                if priority < bestPriority then
                    bestPriority = priority
                    bestPart = part
                end
            end
        end
    end
    
    if not bestPart then
        for _, child in pairs(character:GetChildren()) do
            if child:IsA("BasePart") and child.Parent then
                if isOnScreen(child) and isInFOV(child) and isInRange(child) and hasLineOfSight(child, character) then
                    return child
                end
            end
        end
    end
    
    return bestPart
end

local function findTarget()
    if not hasGunScript(LocalPlayer.Character or {}) then return nil, nil end
    
    local closestPlayer = nil
    local closestDistance = math.huge
    local closestPart = nil
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not isCharacterValid(character) then continue end
        if not isAlive(character) then continue end
        if hasForceField(character) then continue end
        
        local bestPart = findBestTargetPart(character)
        if not bestPart then continue end
        
        local screenPos = Camera:WorldToViewportPoint(bestPart.Position)
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        if distance < closestDistance and distance <= FOV_RADIUS then
            closestDistance = distance
            closestPlayer = player
            closestPart = bestPart
        end
    end
    
    return closestPlayer, closestPart
end

local function isPartStillValid(character, part)
    if not character or not character.Parent then return false end
    if not part or not part.Parent then return false end
    if not isAlive(character) then return false end
    if hasForceField(character) then return false end
    if not isOnScreen(part) then return false end
    if not isInFOV(part) then return false end
    if not isInRange(part) then return false end
    if not hasLineOfSight(part, character) then return false end
    return true
end

local function updateTargetPart()
    if not currentTarget or not currentTarget.Character then
        currentTarget = nil
        currentTargetPart = nil
        return
    end
    
    local character = currentTarget.Character
    
    if not isCharacterValid(character) or not isAlive(character) or hasForceField(character) then
        currentTarget = nil
        currentTargetPart = nil
        return
    end
    
    local bestPart = findBestTargetPart(character)
    
    if bestPart then
        if not currentTargetPart or not currentTargetPart.Parent then
            currentTargetPart = bestPart
        else
            local currentPriority = getPartPriority(currentTargetPart.Name)
            local bestPriority = getPartPriority(bestPart.Name)
            
            if bestPriority < currentPriority then
                currentTargetPart = bestPart
            elseif bestPriority == currentPriority and bestPart ~= currentTargetPart then
                currentTargetPart = bestPart
            end
        end
    else
        currentTarget = nil
        currentTargetPart = nil
    end
end

local function onHumanoidDied(player)
    if currentTarget == player then
        currentTarget = nil
        currentTargetPart = nil
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        local function onCharacterAdded(character)
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.Died:Connect(function()
                    onHumanoidDied(player)
                end)
            end
        end
        
        player.CharacterAdded:Connect(onCharacterAdded)
        if player.Character then
            onCharacterAdded(player.Character)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.Died:Connect(function()
                onHumanoidDied(player)
            end)
        end
    end)
end)

local function updateFOVVisibility()
    local hasWeapon = hasGunScript(LocalPlayer.Character or {})
    
    if hasWeapon then
        showFOVCircle()
    else
        hideFOVCircle()
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    updateFOVVisibility()
    
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            updateFOVVisibility()
        end
    end)
    
    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            updateFOVVisibility()
        end
    end)
end)

if LocalPlayer.Character then
    updateFOVVisibility()
    
    LocalPlayer.Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            updateFOVVisibility()
        end
    end)
    
    LocalPlayer.Character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            updateFOVVisibility()
        end
    end)
end

local function enableAimbot()
    if aimbotEnabled then return end
    aimbotEnabled = true
    
    currentTarget, currentTargetPart = findTarget()
    
    aimConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not aimbotEnabled then return end
        
        if not hasGunScript(LocalPlayer.Character or {}) then
            currentTarget = nil
            currentTargetPart = nil
            return
        end
        
        if currentTarget then
            updateTargetPart()
        end
        
        if not currentTarget or not currentTargetPart then
            currentTarget, currentTargetPart = findTarget()
        end
        
        if currentTarget and currentTargetPart and currentTargetPart.Parent then
            local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, currentTargetPart.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, SMOOTHNESS)
        end
    end)
end

local function disableAimbot()
    aimbotEnabled = false
    currentTarget = nil
    currentTargetPart = nil
    
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        enableAimbot()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        disableAimbot()
    end
end)
