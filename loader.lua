if getgenv().multiscriptlolExecuted then
    return
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Loader = {}
Loader.__index = Loader

Loader.Notifications = {}

Loader.Config = {
    Mirrors = {
        "https://raw.githubusercontent.com/whataheeeeellll/Multigame-AimlockAndESP/main/games/",
        "https://cdn.jsdelivr.net/gh/whataheeeeellll/Multigame-AimlockAndESP@main/games/",
    }
}

function Loader:Notify(title, message, duration, color)
    duration = duration or 4
    color = color or Color3.fromRGB(140, 80, 255)
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LoaderNotification"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = game.CoreGui
    
    local offset = (#self.Notifications * 80)
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 280, 0, 70)
    Frame.Position = UDim2.new(1, 300, 1, -10 - offset)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    
    local Stroke = Instance.new("UIStroke", Frame)
    Stroke.Color = color
    Stroke.Thickness = 2
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 0, 30)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = title
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 15
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Frame
    
    local MessageLabel = Instance.new("TextLabel")
    MessageLabel.Size = UDim2.new(1, -20, 0, 25)
    MessageLabel.Position = UDim2.new(0, 10, 0, 35)
    MessageLabel.BackgroundTransparency = 1
    MessageLabel.Text = message
    MessageLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    MessageLabel.Font = Enum.Font.Gotham
    MessageLabel.TextSize = 12
    MessageLabel.TextXAlignment = Enum.TextXAlignment.Left
    MessageLabel.TextWrapped = true
    MessageLabel.Parent = Frame
    
    table.insert(self.Notifications, ScreenGui)
    
    Frame.Position = UDim2.new(1, 300, 1, -10 - offset)
    Frame.Transparency = 1
    
    TweenService:Create(Frame, TweenInfo.new(0.4), {
        Position = UDim2.new(1, -290, 1, -80 - offset),
        Transparency = 0
    }):Play()
    
    task.spawn(function()
        task.wait(duration)
        TweenService:Create(Frame, TweenInfo.new(0.4), {
            Position = UDim2.new(1, 300, 1, -80 - offset),
            Transparency = 1
        }):Play()
        task.wait(0.4)
        ScreenGui:Destroy()
        
        for i, notif in ipairs(self.Notifications) do
            if notif == ScreenGui then
                table.remove(self.Notifications, i)
                break
            end
        end
        
        for i, notif in ipairs(self.Notifications) do
            local f = notif:FindFirstChildOfClass("Frame")
            if f then
                local newOffset = (i - 1) * 80
                TweenService:Create(f, TweenInfo.new(0.3), {
                    Position = UDim2.new(1, -290, 1, -80 - newOffset)
                }):Play()
            end
        end
    end)
end

function Loader:HttpGet(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success and result then
        return result
    end
    
    local success2, result2 = pcall(function()
        return HttpService:GetAsync(url)
    end)
    
    if success2 and result2 then
        return result2
    end
    
    local success3, result3 = pcall(function()
        return syn and syn.request and syn.request({
            Url = url,
            Method = "GET"
        }).Body
    end)
    
    if success3 and result3 then
        return result3
    end
    
    return nil
end

function Loader:LoadScript(gameId)
    for _, mirror in ipairs(self.Config.Mirrors) do
        local url = mirror .. gameId .. ".lua"
        local result = self:HttpGet(url)
        
        if result and #result > 10 then
            return result, url
        end
    end
    return nil, nil
end

function Loader:Execute()
    local placeId = tostring(game.PlaceId)
    local gameId = tostring(game.GameId)
    
    local scriptContent = self:LoadScript(placeId)
    
    if not scriptContent then
        scriptContent = self:LoadScript(gameId)
    end
    
    if scriptContent then
        local success = pcall(function()
            loadstring(scriptContent)()
        end)
        
        if success then
            self:Notify("multiscript.lol", "Script has been found and successfully loaded", 4, Color3.fromRGB(0, 200, 0))
            getgenv().multiscriptlolExecuted = true
        else
            self:Notify("multiscript.lol", "Unexpected error", 4, Color3.fromRGB(255, 0, 0))
        end
    else
        self:Notify("multiscript.lol", "Script does not exist in repository for this game", 5, Color3.fromRGB(255, 80, 80))
    end
end

local loader = setmetatable({}, Loader)
loader:Execute()
