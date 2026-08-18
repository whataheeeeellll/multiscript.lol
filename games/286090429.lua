local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local HIGHLIGHT_TRANSPARENCY = 0.5
local FORCEFIELD_COLOR = Color3.fromRGB(0, 255, 0)

local MAX_DISTANCE = 500
local FOV_RADIUS = 150
local FOV_COLOR = Color3.fromRGB(255, 255, 255)
local FOV_THICKNESS = 2
local FOV_ANIMATION_SPEED = 0.15

local BODY_PARTS_PRIORITY = {
    "Head",
    "Torso",
    "HumanoidRootPart",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg"
}

local playerData = {}

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
end

local function cleanupPlayerData(player)
    local data = playerData[player]
    if not data then return end
    
    if data.highlight then data.highlight:Destroy() end
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

local aimbotEnabled = false
local aimConnection = nil
local currentTarget = nil
local currentTargetPart = nil

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
    
    local rayResult = workspace:Raycast(origin, direction * distance, rayParams)
    
    if not rayResult then
        return true
    end
    
    if rayResult.Instance:IsDescendantOf(targetCharacter) then
        return true
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

local function isSameTeam(player1, player2)
    if player1.Team and player2.Team then
        return player1.Team == player2.Team
    end
    return false
end

local function findTarget()
    local closestPlayer = nil
    local closestDistance = math.huge
    local closestPart = nil
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if isSameTeam(LocalPlayer, player) then continue end
        
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
        currentTargetPart = bestPart
    else
        currentTarget = nil
        currentTargetPart = nil
    end
end

local function enableAimbot()
    if aimbotEnabled then return end
    aimbotEnabled = true
    
    currentTarget, currentTargetPart = findTarget()
    
    aimConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not aimbotEnabled then return end
        
        if currentTarget then
            updateTargetPart()
        end
        
        if not currentTarget or not currentTargetPart then
            currentTarget, currentTargetPart = findTarget()
        end
        
        if currentTarget and currentTargetPart and currentTargetPart.Parent then
            local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, currentTargetPart.Position)
            Camera.CFrame = targetCFrame
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
