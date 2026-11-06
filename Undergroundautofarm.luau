--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--// CONFIGURATION
local BASE_DEPTH = 6.5
local AIR_DEPTH = 1.0 
local BASE_FORWARD = 4
local MAX_EXTRA_STUDS = 6
local WALK_SPEED = 12
local RUN_SPEED = 28

--// STATE
local active = false
local targetIndex = 0
local targetPlayer = nil
local originalCameraSubject = nil
local smoothedOffset = 0
local actualDepth = 6.5

-- Persistent connection pointers (prevents RenderStepped stacking lag)
local farmRenderConn = nil
local returnLoopConn = nil
local playerRemovingConn = nil
local charAddedConn = nil
local charDiedConn = nil

--// GUI CONTAINER RESOLVER
local function getGuiContainer()
    if gethui then return gethui() end
    local canUseCore = pcall(function()
        local test = Instance.new("Folder")
        test.Parent = CoreGui
        test:Destroy()
    end)
    if canUseCore then return CoreGui end
    return player:WaitForChild("PlayerGui")
end

local guiContainer = getGuiContainer()
local GUI_NAME = "UndergroundGui"

local oldGui = guiContainer:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

--// MODERN GUI BUILD
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = guiContainer

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 260, 0, 90)
container.Position = UDim2.new(0.5, 0, 0.78, 0)
container.AnchorPoint = Vector2.new(0.5, 1)
container.BackgroundTransparency = 1
container.Active = true
container.Draggable = true
container.Parent = gui

local function applyModernStyle(obj)
    obj.BackgroundColor3 = Color3.fromRGB(140, 25, 25)
    obj.BorderSizePixel = 0
    obj.Font = Enum.Font.GothamBold
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.TextScaled = true
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.Parent = obj
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = obj
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 15, 15)
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = obj
end

local healthLabel = Instance.new("TextLabel")
healthLabel.Size = UDim2.new(1, 0, 0, 20)
healthLabel.Position = UDim2.new(0, 0, 0, 0)
healthLabel.BackgroundTransparency = 1
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextColor3 = Color3.fromRGB(180, 50, 50)
healthLabel.TextScaled = true
healthLabel.Text = "Health: [ - ]"
healthLabel.Visible = false
healthLabel.Parent = container

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 30)
status.Position = UDim2.new(0, 0, 0, 25)
applyModernStyle(status)
status.Text = "Inactive"
status.Parent = container

local actionFrame = Instance.new("Frame")
actionFrame.Size = UDim2.new(1, 0, 0, 30)
actionFrame.Position = UDim2.new(0, 0, 0, 60)
actionFrame.BackgroundTransparency = 1
actionFrame.Parent = container

local button = Instance.new("TextButton")
button.Size = UDim2.new(0.6, 0, 1, 0)
button.Position = UDim2.new(0.5, 0, 0, 0)
button.AnchorPoint = Vector2.new(0.5, 0)
applyModernStyle(button)
button.Text = "Enable"
button.Parent = actionFrame

local leftBtn = Instance.new("TextButton")
leftBtn.Size = UDim2.new(0.15, 0, 1, 0)
leftBtn.Position = UDim2.new(0, 0, 0, 0)
applyModernStyle(leftBtn)
leftBtn.Text = "<"
leftBtn.Visible = false
leftBtn.Parent = actionFrame

local rightBtn = Instance.new("TextButton")
rightBtn.Size = UDim2.new(0.15, 0, 1, 0)
rightBtn.Position = UDim2.new(1, 0, 0, 0)
rightBtn.AnchorPoint = Vector2.new(1, 0)
applyModernStyle(rightBtn)
rightBtn.Text = ">"
rightBtn.Visible = false
rightBtn.Parent = actionFrame

--// POSITIONING & TARGETING LOGIC
local function getSafeSpawn()
    local spawnCFrame = CFrame.new(0, 5, 0)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            spawnCFrame = obj.CFrame + Vector3.new(0, 5, 0)
            break
        end
    end
    return spawnCFrame
end

local function returnToSurface()
    if returnLoopConn then
        returnLoopConn:Disconnect()
        returnLoopConn = nil
    end

    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end
    
    local spawnCFrame = getSafeSpawn()
    if originalCameraSubject then
        camera.CameraSubject = originalCameraSubject
        camera.CameraType = Enum.CameraType.Custom
    end
    
    rootPart.Anchored = true
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    
    local frames = 0
    returnLoopConn = RunService.RenderStepped:Connect(function()
        frames = frames + 1
        rootPart.CFrame = spawnCFrame
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        
        local myHum = character:FindFirstChildOfClass("Humanoid")
        if myHum then
            camera.CameraSubject = myHum
            camera.CameraType = Enum.CameraType.Custom
        end
        
        if frames >= 10 then 
            rootPart.Anchored = false 
            if returnLoopConn then
                returnLoopConn:Disconnect()
                returnLoopConn = nil
            end
        end
    end)
end

local function getTargets()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 and p.Character:IsDescendantOf(workspace) then
                table.insert(t, p)
            end
        end
    end
    return t
end

local function updateStatus()
    local list = getTargets()
    if #list == 0 then
        targetPlayer = nil
        status.Text = "No Targets"
        healthLabel.Text = "Health: [ - ]"
        return
    end
    if targetIndex < 1 then targetIndex = #list end
    if targetIndex > #list then targetIndex = 1 end
    targetPlayer = list[targetIndex]
    status.Text = "[ " .. targetIndex .. " / " .. #list .. " ] " .. targetPlayer.Name
end

local function goNext()
    local list = getTargets()
    if #list == 0 then 
        targetPlayer = nil 
        status.Text = "No Targets" 
        healthLabel.Text = "Health: [ - ]"
        return 
    end
    targetIndex = targetIndex + 1
    if targetIndex > #list then targetIndex = 1 end
    smoothedOffset = 0
    updateStatus()
end

local function goPrev()
    local list = getTargets()
    if #list == 0 then 
        targetPlayer = nil 
        status.Text = "No Targets" 
        healthLabel.Text = "Health: [ - ]"
        return 
    end
    targetIndex = targetIndex - 1
    if targetIndex < 1 then targetIndex = #list end
    smoothedOffset = 0
    updateStatus()
end

local function deactivate()
    active = false
    button.Text = "Enable"
    leftBtn.Visible = false
    rightBtn.Visible = false
    healthLabel.Visible = false
    status.Text = "Inactive"
    
    if farmRenderConn then
        farmRenderConn:Disconnect()
        farmRenderConn = nil
    end

    if originalCameraSubject then 
        camera.CameraSubject = originalCameraSubject 
    end
    
    returnToSurface()
end

local function activate()
    active = true
    button.Text = "Disable"
    local char = player.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        originalCameraSubject = char.Humanoid
    end
    leftBtn.Visible = true
    rightBtn.Visible = true
    healthLabel.Visible = true
    targetIndex = 1
    updateStatus()

    if farmRenderConn then
        farmRenderConn:Disconnect()
    end

    farmRenderConn = RunService.RenderStepped:Connect(function()
        if not active or not targetPlayer then return end
        
        local myChar = player.Character
        if not myChar then return end
        
        local targetChar = targetPlayer.Character
        local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        
        if not targetRoot or not targetHum or targetHum.Health <= 0 or not targetChar:IsDescendantOf(workspace) then
            goNext()
            return
        end
        
        healthLabel.Text = "Health: [ " .. math.floor(targetHum.Health) .. " ]"
        
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if myRoot then
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end

            local velocity = targetRoot.AssemblyLinearVelocity
            local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            local speed = horizontalVelocity.Magnitude
            local moveDirection = speed > 0.5 and horizontalVelocity.Unit or targetRoot.CFrame.LookVector
            
            local movingOffset = 0
            if speed > WALK_SPEED then
                movingOffset = math.clamp((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0, 1) * MAX_EXTRA_STUDS
            elseif speed > 0.5 then
                movingOffset = math.clamp(speed / WALK_SPEED, 0, 1) * (MAX_EXTRA_STUDS * 0.3)
            end
            
            local lerpSpeed = movingOffset > smoothedOffset and 0.15 or 0.05
            smoothedOffset = smoothedOffset + (movingOffset - smoothedOffset) * lerpSpeed
            
            local targetDepth = BASE_DEPTH
            if targetHum.FloorMaterial == Enum.Material.Air or targetHum:GetState() == Enum.HumanoidStateType.Freefall then
                targetDepth = AIR_DEPTH 
            end
            
            actualDepth = actualDepth + (targetDepth - actualDepth) * 0.2
            
            local pos = targetRoot.Position + (moveDirection * (BASE_FORWARD + smoothedOffset)) - Vector3.new(0, actualDepth, 0)
            local lookTarget = Vector3.new(pos.X, targetRoot.Position.Y, pos.Z)
            
            myRoot:PivotTo(CFrame.lookAt(pos, lookTarget))
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
            
            camera.CameraSubject = targetHum
        end
    end)
end

button.MouseButton1Click:Connect(function()
    if not active then
        activate()
    else
        deactivate()
    end
end)

button.MouseButton2Click:Connect(function()
    if active then deactivate() end
end)

rightBtn.MouseButton1Click:Connect(function() if active then goNext() end end)
leftBtn.MouseButton1Click:Connect(function() if active then goPrev() end end)

if playerRemovingConn then playerRemovingConn:Disconnect() end
playerRemovingConn = Players.PlayerRemoving:Connect(function(p) 
    if p == targetPlayer then goNext() end 
end)

local function hookDeath(character)
    if charDiedConn then charDiedConn:Disconnect() end
    local hum = character:WaitForChild("Humanoid")
    charDiedConn = hum.Died:Connect(function() 
        if active then deactivate() end 
    end)
end

if player.Character then hookDeath(player.Character) end
if charAddedConn then charAddedConn:Disconnect() end
charAddedConn = player.CharacterAdded:Connect(hookDeath)
