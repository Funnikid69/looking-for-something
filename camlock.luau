--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

--// CONFIGURATION
local MAX_TARGET_DISTANCE = 85
local CAM_SMOOTHNESS = 0.38
local CHAR_SMOOTHNESS = 0.45
local AIM_HEIGHT_OFFSET = 0.2

local KILLER_CLASSES = {
    ["slasher"]         = true,
    ["jason"]           = true,
    ["coolkid"]         = true,
    ["c00lkidd"]        = true,
    ["coolkidrework"]   = true,
    ["1x4"]             = true,
    ["1x1x1x1"]         = true,
    ["noli"]            = true,
    ["swordsmaster"]    = true,
    ["guest666"]        = true,
    ["2011x"]           = true,
    ["johndoe"]         = true,
    ["azure"]           = true,
    ["doombringer"]     = true,
}

--// STATE
local isLocked = false
local currentLockedTarget = nil
local playerRemovingConn = nil

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
local GUI_NAME = "KillerCamlockUI"

local oldGui = guiContainer:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

--// GUI CREATION
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = guiContainer

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 190, 0, 92)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 30)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(150, 15, 15)
header.BorderSizePixel = 0
header.Font = Enum.Font.GothamBold
header.Text = "Killers Aimbot"
header.TextColor3 = Color3.fromRGB(245, 245, 245)
header.TextSize = 13
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header

local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 5, 5)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 20, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 5, 5)),
})
headerGradient.Parent = header

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(1, 0, 0, 52)
toggleButton.Position = UDim2.new(0, 0, 0, 36)
toggleButton.BackgroundColor3 = Color3.fromRGB(120, 10, 10)
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Text = "Aimbot : Off"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 14
toggleButton.AutoButtonColor = false
toggleButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = toggleButton

local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 3, 3)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(140, 15, 15)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 20)),
})
buttonGradient.Parent = toggleButton

-- Billboard Target Dot
local targetDotGui = Instance.new("BillboardGui")
targetDotGui.Name = "CamlockTargetDot"
targetDotGui.Size = UDim2.new(0, 9, 0, 9)
targetDotGui.AlwaysOnTop = true
targetDotGui.Active = false
targetDotGui.ResetOnSpawn = false
targetDotGui.Enabled = false
targetDotGui.Parent = screenGui

local dotFrame = Instance.new("Frame")
dotFrame.Size = UDim2.new(1, 0, 1, 0)
dotFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dotFrame.BorderSizePixel = 0
dotFrame.Parent = targetDotGui

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dotFrame

local dotStroke = Instance.new("UIStroke")
dotStroke.Thickness = 1.2
dotStroke.Color = Color3.fromRGB(0, 0, 0)
dotStroke.Transparency = 0.4
dotStroke.Parent = dotFrame

--// TARGET & ROLE VALIDATION
local function getCharacterKey(charObj)
    if not charObj then return "" end
    local charType = charObj:GetAttribute("Character")
        or charObj:GetAttribute("CharacterType")
        or charObj:GetAttribute("Role")
        or charObj.Name
    local key = string.lower(tostring(charType))

    if key == "c00lkidd" or key == "coolkidd" then key = "coolkid" end
    if key == "1x1x1x1" then key = "1x4" end
    return key
end

local function isLocalPlayerKiller()
    local myChar = player.Character
    if not myChar then return false end
    local key = getCharacterKey(myChar)
    return KILLER_CLASSES[key] == true
end

-- Validates all players
local function isTargetAliveAndValid(p)
    if not p or not p.Parent or not p.Character or p == player then return false end
    local tChar = p.Character
    if not tChar:IsDescendantOf(workspace) then return false end

    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tHum or not tRoot or tHum.Health <= 0 then return false end

    return true
end

local function getLockedOrClosestTarget()
    if currentLockedTarget and isTargetAliveAndValid(currentLockedTarget) then
        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tRoot = currentLockedTarget.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and tRoot then
            local dist = (myRoot.Position - tRoot.Position).Magnitude
            if dist <= MAX_TARGET_DISTANCE then
                return currentLockedTarget.Character
            end
        end
    end

    currentLockedTarget = nil

    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local shortestDist = MAX_TARGET_DISTANCE

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isTargetAliveAndValid(p) then
            local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local dist = (myRoot.Position - tRoot.Position).Magnitude
                if dist <= shortestDist then
                    shortestDist = dist
                    closest = p
                end
            end
        end
    end

    currentLockedTarget = closest
    return closest and closest.Character or nil
end

if playerRemovingConn then playerRemovingConn:Disconnect() end
playerRemovingConn = Players.PlayerRemoving:Connect(function(leavingPlayer)
    if currentLockedTarget == leavingPlayer then
        currentLockedTarget = nil
        targetDotGui.Enabled = false
        targetDotGui.Adornee = nil
    end
end)

--// CAMLOCK LOOP MANAGEMENT
local function disableLock()
    isLocked = false
    currentLockedTarget = nil
    targetDotGui.Enabled = false
    targetDotGui.Adornee = nil
    pcall(function()
        RunService:UnbindFromRenderStep("StandaloneKillerCamlockLoop")
    end)
    toggleButton.Text = "Aimbot : Off"
end

local function enableLock()
    isLocked = true
    pcall(function()
        RunService:UnbindFromRenderStep("StandaloneKillerCamlockLoop")
    end)
    RunService:BindToRenderStep("StandaloneKillerCamlockLoop", Enum.RenderPriority.Camera.Value, function()
        if not isLocked then return end

        if not isLocalPlayerKiller() then
            toggleButton.Text = "Not a Killer"
            currentLockedTarget = nil
            targetDotGui.Enabled = false
            targetDotGui.Adornee = nil
            return
        end

        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not myRoot or not myHum or myHum.Health <= 0 then
            targetDotGui.Enabled = false
            return
        end

        local targetChar = getLockedOrClosestTarget()
        if not targetChar then
            toggleButton.Text = "Aimbot : No target"
            targetDotGui.Enabled = false
            targetDotGui.Adornee = nil
            return
        end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not targetHum or targetHum.Health <= 0 then
            currentLockedTarget = nil
            toggleButton.Text = "Aimbot : No target"
            targetDotGui.Enabled = false
            targetDotGui.Adornee = nil
            return
        end

        toggleButton.Text = "Aimbot : On - Locked"

        local adorneePart = targetChar:FindFirstChild("UpperTorso")
            or targetChar:FindFirstChild("Torso")
            or targetRoot
        targetDotGui.Adornee = adorneePart
        targetDotGui.Enabled = true

        local currentCamera = workspace.CurrentCamera
        if not currentCamera then return end

        local myPos = myRoot.Position
        local targetPos = targetRoot.Position
        local aimTarget = targetPos + Vector3.new(0, AIM_HEIGHT_OFFSET, 0)

        local camPos = currentCamera.CFrame.Position
        local toAim = (aimTarget - camPos)

        if toAim.Magnitude > 0.2 then
            local targetCamCF = CFrame.lookAt(camPos, aimTarget)
            currentCamera.CFrame = currentCamera.CFrame:Lerp(targetCamCF, CAM_SMOOTHNESS)

            local flatDiff = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
            if flatDiff.Magnitude > 0.4 then
                local charGoalCF = CFrame.lookAt(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
                myRoot.CFrame = myRoot.CFrame:Lerp(charGoalCF, CHAR_SMOOTHNESS)
            end
        end
    end)
end

toggleButton.MouseButton1Click:Connect(function()
    if isLocked then
        disableLock()
    else
        enableLock()
    end
end)
