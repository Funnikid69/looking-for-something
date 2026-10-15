--------------------------------------------------------------------------------
-- PART 1: CORE SETUP & RAYFIELD INITIALIZATION
--------------------------------------------------------------------------------

--// GAME ID CHECKER
local ALLOWED_PLACE_IDS = {
    [99585784721880] = true,
}

if not ALLOWED_PLACE_IDS[game.PlaceId] then
    game:GetService("Players").LocalPlayer:Kick("Incorrect Game! Current Place ID (" .. tostring(game.PlaceId) .. ") is not authorized.")
    return
end

--// RAYFIELD LIBRARY LOADER
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player = game.Players.LocalPlayer
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera

--// WINDOW SETUP (NOVASAKEN)
local Window = Rayfield:CreateWindow({
    Name = "Novasaken",
    LoadingTitle = "Novasaken",
    LoadingSubtitle = "by Chwaa",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "Novasaken"
    }
})

--// 6 ACTIVE TABS (PART 7 AUTO GEN TAB REMOVED)
local CombatTab = Window:CreateTab("Combat", 4483362458)
local AutoFarmTab = Window:CreateTab("Auto Farm", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local UtilityTab = Window:CreateTab("Movement & Misc", 4483362458)
local TeleportTab = Window:CreateTab("Teleporter", 4483362458)
local ItemsTab = Window:CreateTab("Items", 4483362458)

--// CHARACTER & STATE TRACKING
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    char = c
    hum = c:WaitForChild("Humanoid")
end)

--// GLOBAL CRATE SPAWN NOTIFICATION LISTENER
local function isCrateObject(obj)
    if not obj or not obj:IsDescendantOf(workspace) then return false end
    local name = obj.Name:lower()
    if name:find("crate") or name:find("chest") or name:find("box") then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then return true end
    end
    return false
end

workspace.DescendantAdded:Connect(function(descendant)
    if isCrateObject(descendant) then
        Rayfield:Notify({
            Title = "Crate Event",
            Content = "A Crate Has Spawned!",
            Duration = 4,
            Image = 4483362458,
        })
    end
end)

--// AUTO FARM SHARED VARIABLES
local autoFarmLowHpOn = false
local autoFarmAllOn = false
local lockInFrontOn = false
local stickToPersonOn = false
local targetHealthThreshold = 20
local hitDistanceOffset = 3

local currentLockedTarget = nil
local LowHpToggle
local AllPlayersToggle
--------------------------------------------------------------------------------
-- PART 2: AUTO-FARM SYSTEM
--------------------------------------------------------------------------------

local function isTargetAliveAndValid(p, maxHpConstraint)
    if not p or not p.Parent or not p.Character or p == player then return false end
    local tHum = p.Character:FindFirstChild("Humanoid")
    local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
    
    if not tHum or not tRoot or tHum.Health <= 0 or not p.Character:IsDescendantOf(workspace) then
        return false
    end

    if maxHpConstraint and tHum.Health > maxHpConstraint then
        return false
    end

    return true
end

local function getLowHpTarget(maxHp)
    local limitHp = maxHp or targetHealthThreshold

    if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget, limitHp) then
        return currentLockedTarget
    end

    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local lowestHp = limitHp
    local targetPlayer = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isTargetAliveAndValid(p, limitHp) then
            local tHum = p.Character.Humanoid
            if tHum.Health <= lowestHp then
                lowestHp = tHum.Health
                targetPlayer = p
            end
        end
    end

    currentLockedTarget = targetPlayer
    return targetPlayer
end

local function getAnyTarget()
    if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget, nil) then
        return currentLockedTarget
    end

    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closestDist = math.huge
    local targetPlayer = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isTargetAliveAndValid(p, nil) then
            local tRoot = p.Character.HumanoidRootPart
            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                targetPlayer = p
            end
        end
    end

    currentLockedTarget = targetPlayer
    return targetPlayer
end

local function positionAtTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not myRoot or not targetRoot then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local offset = hitDistanceOffset
    if lockInFrontOn then
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -offset) * CFrame.Angles(0, math.pi, 0)
    else
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, offset)
    end
end

RS.Stepped:Connect(function()
    if not autoFarmLowHpOn and not autoFarmAllOn then return end
    if not char or not hum or hum.Health <= 0 then return end

    local maxHpConstraint = autoFarmLowHpOn and targetHealthThreshold or nil
    local activeTarget = autoFarmLowHpOn and getLowHpTarget(targetHealthThreshold) or getAnyTarget()

    if activeTarget and isTargetAliveAndValid(activeTarget, maxHpConstraint) then
        positionAtTarget(activeTarget)
    else
        currentLockedTarget = nil
    end
end)

RS.Heartbeat:Connect(function()
    if not autoFarmLowHpOn and not autoFarmAllOn then return end

    if hum and hum.Health <= 30 then
        if autoFarmLowHpOn and LowHpToggle then LowHpToggle:Set(false) end
        if autoFarmAllOn and AllPlayersToggle then AllPlayersToggle:Set(false) end
        autoFarmLowHpOn = false
        autoFarmAllOn = false
        currentLockedTarget = nil
        return
    end

    local maxHpConstraint = autoFarmLowHpOn and targetHealthThreshold or nil
    local targetP = currentLockedTarget

    if not (targetP and isTargetAliveAndValid(targetP, maxHpConstraint)) then
        currentLockedTarget = nil
    end
end)

AutoFarmTab:CreateSection("Targeting Options")

AutoFarmTab:CreateToggle({
    Name = "Lock in Front of Person",
    CurrentValue = false,
    Callback = function(value)
        lockInFrontOn = value
    end,
})

AutoFarmTab:CreateToggle({
    Name = "Stick to Person?",
    CurrentValue = false,
    Callback = function(value)
        stickToPersonOn = value
        if not value then currentLockedTarget = nil end
    end,
})

AutoFarmTab:CreateDropdown({
    Name = "Position Offset (Hit Range)",
    Options = {"Close (~3 studs)", "Slightly Far (~5.5 studs)", "Far (~8 studs)"},
    CurrentOption = "Close (~3 studs)",
    Callback = function(option)
        local selected = typeof(option) == "table" and option[1] or option
        hitDistanceOffset = selected:find("Slightly Far") and 5.5 or (selected:find("Far") and 8 or 3)
    end,
})

AutoFarmTab:CreateSection("Auto Farm Automation")

LowHpToggle = AutoFarmTab:CreateToggle({
    Name = "Auto Farm Low Health Players",
    CurrentValue = false,
    Callback = function(value)
        if value and hum and hum.Health <= 30 then
            autoFarmLowHpOn = false
            task.spawn(function() if LowHpToggle then LowHpToggle:Set(false) end end)
            return
        end
        autoFarmLowHpOn = value
        if value and AllPlayersToggle then AllPlayersToggle:Set(false) end
        if not value then currentLockedTarget = nil end
    end,
})

AllPlayersToggle = AutoFarmTab:CreateToggle({
    Name = "Auto Farm All Players",
    CurrentValue = false,
    Callback = function(value)
        if value and hum and hum.Health <= 30 then
            autoFarmAllOn = false
            task.spawn(function() if AllPlayersToggle then AllPlayersToggle:Set(false) end end)
            return
        end
        autoFarmAllOn = value
        if value and LowHpToggle then LowHpToggle:Set(false) end
        if not value then currentLockedTarget = nil end
    end,
})

AutoFarmTab:CreateDropdown({
    Name = "Low HP Target Threshold",
    Options = {"10 HP", "20 HP", "30 HP", "50 HP"},
    CurrentOption = "20 HP",
    Callback = function(option)
        local selected = typeof(option) == "table" and option[1] or option
        local val = tonumber(string.match(selected, "%d+"))
        if val then 
            targetHealthThreshold = val 
            currentLockedTarget = nil
        end
    end,
})
--------------------------------------------------------------------------------
-- PART 3 (SECTION 1): ROLES, MINIONS & GENERATOR ESP
--------------------------------------------------------------------------------

local espOn = false
local minionEspOn = false
local zombieEspOn = false
local generatorEspOn = false
local itemEspOn = false
local crateEspOn = false

local activeESP = {}
local activeMinionESP = {}
local activeZombieESP = {}
local activeGenESP = {}
local activeItemESP = {}
local activeCrateESP = {}

local SURVIVOR_CLASSES = {
    ["guest1337"]     = "Guest 1337",
    ["shedletsky"]    = "Shedletsky",
    ["dusekkar"]      = "Dusekkar",
    ["martialartist"] = "Martial Artist",
    ["chance"]        = "Chance",
    ["twotime"]       = "TwoTime",
    ["007n7"]         = "007n7",
    ["elliot"]        = "Elliot",
    ["veeronica"]     = "Veeronica",
    ["janedoe"]       = "Jane Doe",
    ["messi"]         = "Messi",
    ["noob"]          = "Noob",
    ["taph"]          = "Taph",
    ["builderman"]    = "Builderman",
}

local KILLER_CLASSES = {
    ["slasher"]         = "Slasher",
    ["jason"]           = "Jason",
    ["c00lkidd"]        = "c00lkidd",
    ["1x1x1x1"]         = "1x1x1x1",
    ["noli"]            = "Noli",
    ["swordsmaster"]    = "Swordsmaster",
    ["guest666"]        = "Guest 666",
    ["2011x"]           = "2011x",
    ["johndoe"]         = "John Doe",
    ["azure"]           = "Azure",
    ["shedletskyfunny"] = "ShedletskyFunny",
}

local MAP_BLACKLIST = {
    ["map"]        = true,
    ["ingame"]     = true,
    ["workspace"]  = true,
    ["generators"] = true,
    ["generator"]  = true,
    ["spawns"]     = true,
    ["lobby"]      = true,
    ["terrain"]    = true,
}

local function getRoleInfo(targetChar)
    if not targetChar then return nil end
    local rawCharType = targetChar:GetAttribute("Character") or targetChar:GetAttribute("CharacterType") or targetChar.Name
    local charKey = string.lower(tostring(rawCharType))

    if charKey == "coolkid" then charKey = "c00lkidd" end
    if charKey == "1x4" then charKey = "1x1x1x1" end

    if SURVIVOR_CLASSES[charKey] then
        return Color3.fromRGB(0, 150, 255), "Survivor", SURVIVOR_CLASSES[charKey]
    elseif KILLER_CLASSES[charKey] then
        return Color3.fromRGB(255, 35, 35), "Killer", KILLER_CLASSES[charKey]
    end

    return Color3.fromRGB(0, 150, 255), "Survivor", targetChar.Name
end

local function removeESP(plr)
    if activeESP[plr] then
        if activeESP[plr].Highlight then activeESP[plr].Highlight:Destroy() end
        if activeESP[plr].Billboard then activeESP[plr].Billboard:Destroy() end
        if activeESP[plr].Connection then activeESP[plr].Connection:Disconnect() end
        activeESP[plr] = nil
    end
end

local function applyESP(plr)
    if plr == player then return end
    removeESP(plr)

    local function setupChar(targetChar)
        if not targetChar then return end
        local root = targetChar:WaitForChild("HumanoidRootPart", 5)
        local targetHum = targetChar:WaitForChild("Humanoid", 5)
        local head = targetChar:WaitForChild("Head", 5) or root
        if not root or not targetHum then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = targetChar
        highlight.Enabled = false
        highlight.Parent = targetChar

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Billboard"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 220, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Adornee = head
        billboard.Enabled = false
        billboard.Parent = targetChar

        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 13

        local conn = RS.RenderStepped:Connect(function()
            if not espOn or not targetChar:IsDescendantOf(workspace) or targetHum.Health <= 0 then
                highlight.Enabled = false
                billboard.Enabled = false
                return
            end

            local roleColor, roleName, className = getRoleInfo(targetChar)
            highlight.FillColor = roleColor
            label.TextColor3 = roleColor
            highlight.Enabled = true
            billboard.Enabled = true
            label.Text = string.format("%s [%s - %s] | %d HP", plr.Name, className, roleName, math.floor(targetHum.Health))
        end)

        activeESP[plr] = {
            Highlight = highlight,
            Billboard = billboard,
            Connection = conn
        }
    end

    if plr.Character then setupChar(plr.Character) end
    plr.CharacterAdded:Connect(setupChar)
end

--// C00LKIDD MINION ESP (ORANGE)
local function removeMinionESP(minion)
    if activeMinionESP[minion] then
        if activeMinionESP[minion].Highlight then activeMinionESP[minion].Highlight:Destroy() end
        if activeMinionESP[minion].Billboard then activeMinionESP[minion].Billboard:Destroy() end
        if activeMinionESP[minion].Connection then activeMinionESP[minion].Connection:Disconnect() end
        activeMinionESP[minion] = nil
    end
end

local function applyMinionESP(minion)
    if not minion or activeMinionESP[minion] then return end
    if not minion:IsDescendantOf(workspace) then return end

    local root = minion:WaitForChild("HumanoidRootPart", 3) or minion:FindFirstChildWhichIsA("BasePart")
    local hum = minion:FindFirstChildOfClass("Humanoid")
    local head = minion:FindFirstChild("Head") or root
    if not root then return end

    local minionColor = Color3.fromRGB(255, 130, 0)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Minion_Highlight"
    highlight.FillColor = minionColor
    highlight.FillTransparency = 0.4
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = minion
    highlight.Parent = minion

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Minion_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 180, 0, 26)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = head
    billboard.Parent = minion

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = minionColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 13
    label.Text = "c00lkidd Minion"

    local conn = RS.RenderStepped:Connect(function()
        if not minionEspOn or not minion:IsDescendantOf(workspace) or (hum and hum.Health <= 0) then
            removeMinionESP(minion)
        else
            highlight.Enabled = true
            billboard.Enabled = true
            label.Text = hum and string.format("c00lkidd Minion | %d HP", math.floor(hum.Health)) or "c00lkidd Minion"
        end
    end)

    activeMinionESP[minion] = {
        Highlight = highlight,
        Billboard = billboard,
        Connection = conn
    }
end

local function scanMinions()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "PizzaDeliveryRig" or obj.Name:find("PizzaDelivery")) then
            applyMinionESP(obj)
        end
    end
end

local function clearAllMinionESP()
    for minion, _ in pairs(activeMinionESP) do
        removeMinionESP(minion)
    end
end

--// 1X1X1X1 ZOMBIE MINION ESP (DARK GREEN)
local function removeZombieESP(zombie)
    if activeZombieESP[zombie] then
        if activeZombieESP[zombie].Highlight then activeZombieESP[zombie].Highlight:Destroy() end
        if activeZombieESP[zombie].Billboard then activeZombieESP[zombie].Billboard:Destroy() end
        if activeZombieESP[zombie].Connection then activeZombieESP[zombie].Connection:Disconnect() end
        activeZombieESP[zombie] = nil
    end
end

local function applyZombieESP(zombie)
    if not zombie or activeZombieESP[zombie] then return end
    if not zombie:IsDescendantOf(workspace) then return end

    local root = zombie:WaitForChild("HumanoidRootPart", 3) or zombie:FindFirstChildWhichIsA("BasePart")
    local hum = zombie:FindFirstChildOfClass("Humanoid")
    local head = zombie:FindFirstChild("Head") or root
    if not root then return end

    local darkGreenColor = Color3.fromRGB(0, 130, 45)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Zombie_Highlight"
    highlight.FillColor = darkGreenColor
    highlight.FillTransparency = 0.4
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = zombie
    highlight.Parent = zombie

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Zombie_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 180, 0, 26)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = head
    billboard.Parent = zombie

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = darkGreenColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 13
    label.Text = "1x1x1x1 Zombie"

    local conn = RS.RenderStepped:Connect(function()
        if not zombieEspOn or not zombie:IsDescendantOf(workspace) or (hum and hum.Health <= 0) then
            removeZombieESP(zombie)
        else
            highlight.Enabled = true
            billboard.Enabled = true
            label.Text = hum and string.format("1x1x1x1 Zombie | %d HP", math.floor(hum.Health)) or "1x1x1x1 Zombie"
        end
    end)

    activeZombieESP[zombie] = {
        Highlight = highlight,
        Billboard = billboard,
        Connection = conn
    }
end

local function scanZombies()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "1x1x1x1Zombie" or obj.Name:find("1x1x1x1Zombie")) then
            applyZombieESP(obj)
        end
    end
end

local function clearAllZombieESP()
    for zombie, _ in pairs(activeZombieESP) do
        removeZombieESP(zombie)
    end
end

--// GENERATOR ESP (YELLOW / WHITE)
local function removeGenESP(gen)
    if activeGenESP[gen] then
        if activeGenESP[gen].Highlight then activeGenESP[gen].Highlight:Destroy() end
        if activeGenESP[gen].Billboard then activeGenESP[gen].Billboard:Destroy() end
        if activeGenESP[gen].Connection then activeGenESP[gen].Connection:Disconnect() end
        activeGenESP[gen] = nil
    end
end

local function isGenFinished(genModel)
    if genModel:GetAttribute("Completed") == true or genModel:GetAttribute("Finished") == true or genModel:GetAttribute("Done") == true then
        return true
    end
    local progress = genModel:FindFirstChild("Progress")
    if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
        if progress.Value >= 100 then return true end
    end
    return false
end

local function applyGenESP(genModel)
    if not genModel or activeGenESP[genModel] then return end
    if not genModel:IsDescendantOf(workspace) then return end

    local mainPart = genModel:FindFirstChild("Main") or genModel.PrimaryPart or genModel:FindFirstChildWhichIsA("BasePart", true)
    if not mainPart then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Gen_Highlight"
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = genModel
    highlight.Parent = genModel

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Gen_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 160, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.Adornee = mainPart
    billboard.Parent = genModel

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 13

    local conn = RS.RenderStepped:Connect(function()
        if not generatorEspOn or not genModel:IsDescendantOf(workspace) then
            highlight.Enabled = false
            billboard.Enabled = false
            return
        end

        highlight.Enabled = true
        billboard.Enabled = true

        local completed = isGenFinished(genModel)
        if completed then
            local whiteColor = Color3.fromRGB(255, 255, 255)
            highlight.FillColor = whiteColor
            highlight.OutlineColor = whiteColor
            label.TextColor3 = whiteColor
            label.Text = "Generator [DONE]"
        else
            local yellowColor = Color3.fromRGB(255, 220, 0)
            highlight.FillColor = yellowColor
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            label.TextColor3 = yellowColor
            
            local progressVal = genModel:FindFirstChild("Progress")
            if progressVal and (progressVal:IsA("NumberValue") or progressVal:IsA("IntValue")) then
                label.Text = string.format("Generator [%d%%]", math.floor(progressVal.Value))
            else
                label.Text = "Generator"
            end
        end
    end)

    activeGenESP[genModel] = {
        Highlight = highlight,
        Billboard = billboard,
        Connection = conn
    }
end

local function scanGenerators()
    local map = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") and workspace.Map.Ingame:FindFirstChild("Map")
    local searchScope = map or workspace

    for _, obj in ipairs(searchScope:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "Generator" or obj.Name:find("Generator")) and obj:FindFirstChild("Main") then
            applyGenESP(obj)
        end
    end
end

local function clearAllGenESP()
    for gen, _ in pairs(activeGenESP) do
        removeGenESP(gen)
    end
end
--------------------------------------------------------------------------------
-- PART 3 (SECTION 2): CRATE, ITEM ESP & UI TOGGLES
--------------------------------------------------------------------------------

--// CRATE ESP (PURPLE)
local function isCrateValid(crate)
    if not crate or not crate:IsDescendantOf(workspace) then return false end
    local prompt = crate:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return false end
    return true
end

local function removeCrateESP(crate)
    if activeCrateESP[crate] then
        if activeCrateESP[crate].Highlight then activeCrateESP[crate].Highlight:Destroy() end
        if activeCrateESP[crate].Billboard then activeCrateESP[crate].Billboard:Destroy() end
        if activeCrateESP[crate].Connection then activeCrateESP[crate].Connection:Disconnect() end
        activeCrateESP[crate] = nil
    end
end

local function applyCrateESP(crate)
    if not crate or activeCrateESP[crate] then return end
    if not isCrateValid(crate) then return end

    local primaryAdornee = crate:IsA("BasePart") and crate or (crate:IsA("Model") and (crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true)))
    if not primaryAdornee then return end

    local purpleColor = Color3.fromRGB(170, 0, 255)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Crate_Highlight"
    highlight.FillColor = purpleColor
    highlight.FillTransparency = 0.45
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = crate
    highlight.Parent = crate

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Crate_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 160, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = primaryAdornee
    billboard.Parent = crate

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = purpleColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.Text = "Crate"

    local conn = RS.RenderStepped:Connect(function()
        if not crateEspOn or not isCrateValid(crate) then
            removeCrateESP(crate)
        end
    end)

    activeCrateESP[crate] = {
        Highlight = highlight,
        Billboard = billboard,
        Connection = conn
    }
end

local function scanCrates()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if (name:find("crate") or name:find("chest") or name:find("box")) and obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
            local targetModel = obj:IsA("Model") and obj or obj.Parent
            applyCrateESP(targetModel)
        end
    end
end

local function clearAllCrateESP()
    for crate, _ in pairs(activeCrateESP) do
        removeCrateESP(crate)
    end
end

--// ITEM ESP (GREEN)
local function resolveItemTarget(prompt)
    if not prompt or not prompt.Enabled then return nil end
    local parentObj = prompt.Parent
    if not parentObj or not parentObj:IsDescendantOf(workspace) then return nil end

    local actionText = prompt.ActionText:lower()
    local objectText = prompt.ObjectText:lower()
    local parentName = parentObj.Name:lower()

    if actionText:find("repair") or objectText:find("generator") or parentName:find("generator") then
        return nil
    end

    if parentName:find("crate") or objectText:find("crate") or actionText:find("crate") then
        return nil
    end

    local charModel = prompt:FindFirstAncestorOfClass("Model")
    if charModel and (Players:GetPlayerFromCharacter(charModel) or charModel:FindFirstChildOfClass("Humanoid")) then
        return nil
    end

    if charModel and charModel ~= workspace then
        local lowerModelName = charModel.Name:lower()
        if not MAP_BLACKLIST[lowerModelName] and not charModel:FindFirstChild("Progress") and not charModel:FindFirstChild("Remotes") then
            return charModel
        end
    end

    if parentObj:IsA("BasePart") then
        return parentObj
    end

    return nil
end

local function removeItemESP(item)
    if activeItemESP[item] then
        if activeItemESP[item].Highlight then activeItemESP[item].Highlight:Destroy() end
        if activeItemESP[item].Billboard then activeItemESP[item].Billboard:Destroy() end
        activeItemESP[item] = nil
    end
end

local function applyItemESP(target)
    if not target or activeItemESP[target] then return end
    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return end

    local primaryAdornee = target:IsA("BasePart") and target or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)))
    if not primaryAdornee then return end

    local itemName = (prompt.ActionText ~= "" and prompt.ActionText) or (prompt.ObjectText ~= "" and prompt.ObjectText) or target.Name
    local itemColor = Color3.fromRGB(0, 255, 120)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Item_Highlight"
    highlight.FillColor = itemColor
    highlight.FillTransparency = 0.45
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = target
    highlight.Parent = target

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Item_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Adornee = primaryAdornee
    billboard.Parent = target

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = itemColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 13
    label.Text = itemName

    activeItemESP[target] = {
        Highlight = highlight,
        Billboard = billboard
    }
end

local function scanAndApplyItemESP()
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local validItem = resolveItemTarget(prompt)
            if validItem then
                applyItemESP(validItem)
            end
        end
    end
end

local function clearAllItemESP()
    for item, _ in pairs(activeItemESP) do
        removeItemESP(item)
    end
end

--// DYNAMIC LISTENERS
workspace.DescendantAdded:Connect(function(descendant)
    if minionEspOn and descendant:IsA("Model") and (descendant.Name == "PizzaDeliveryRig" or descendant.Name:find("PizzaDelivery")) then
        applyMinionESP(descendant)
    end

    if zombieEspOn and descendant:IsA("Model") and (descendant.Name == "1x1x1x1Zombie" or descendant.Name:find("1x1x1x1Zombie")) then
        applyZombieESP(descendant)
    end

    if generatorEspOn and descendant:IsA("Model") and (descendant.Name == "Generator" or descendant.Name:find("Generator")) then
        applyGenESP(descendant)
    end

    if crateEspOn and descendant:IsA("ProximityPrompt") then
        local p = descendant.Parent
        local name = p and p.Name:lower() or ""
        if name:find("crate") or name:find("chest") or name:find("box") then
            applyCrateESP(p:IsA("Model") and p or p.Parent)
        end
    end

    if itemEspOn and descendant:IsA("ProximityPrompt") then
        local validItem = resolveItemTarget(descendant)
        if validItem then
            applyItemESP(validItem)
        end
    end
end)

workspace.DescendantRemoving:Connect(function(descendant)
    if activeMinionESP[descendant] then removeMinionESP(descendant) end
    if activeZombieESP[descendant] then removeZombieESP(descendant) end
    if activeGenESP[descendant] then removeGenESP(descendant) end
    if activeCrateESP[descendant] then removeCrateESP(descendant) end
    if activeItemESP[descendant] then removeItemESP(descendant) end
end)

task.spawn(function()
    while true do
        task.wait(0.6)
        if minionEspOn then scanMinions() end
        if zombieEspOn then scanZombies() end
        if generatorEspOn then scanGenerators() end
        if crateEspOn then scanCrates() end
        if itemEspOn then scanAndApplyItemESP() end
    end
end)

--// UI TOGGLES
ESPTab:CreateSection("Player Visuals")

ESPTab:CreateToggle({
    Name = "Role ESP (Blue Survivor / Red Killer)",
    CurrentValue = false,
    Callback = function(value)
        espOn = value
        if espOn then
            for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
        else
            for p, _ in pairs(activeESP) do removeESP(p) end
        end
    end,
})

ESPTab:CreateSection("Minion & Objective Visuals")

ESPTab:CreateToggle({
    Name = "C00lkidd Minion ESP",
    CurrentValue = false,
    Callback = function(value)
        minionEspOn = value
        if minionEspOn then scanMinions() else clearAllMinionESP() end
    end,
})

ESPTab:CreateToggle({
    Name = "1x1x1x1 Minion ESP",
    CurrentValue = false,
    Callback = function(value)
        zombieEspOn = value
        if zombieEspOn then scanZombies() else clearAllZombieESP() end
    end,
})

ESPTab:CreateToggle({
    Name = "Generator ESP (Yellow / White)",
    CurrentValue = false,
    Callback = function(value)
        generatorEspOn = value
        if generatorEspOn then scanGenerators() else clearAllGenESP() end
    end,
})

ESPTab:CreateSection("Item & Crate Visuals")

ESPTab:CreateToggle({
    Name = "Crate ESP (Purple)",
    CurrentValue = false,
    Callback = function(value)
        crateEspOn = value
        if crateEspOn then scanCrates() else clearAllCrateESP() end
    end,
})

ESPTab:CreateToggle({
    Name = "Item ESP (Green)",
    CurrentValue = false,
    Callback = function(value)
        itemEspOn = value
        if itemEspOn then scanAndApplyItemESP() else clearAllItemESP() end
    end,
})

Players.PlayerAdded:Connect(function(p)
    if espOn then applyESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)
--------------------------------------------------------------------------------
-- PART 4: COMBAT TAB & UTILITY TAB
--------------------------------------------------------------------------------

local AIM_DISTANCE = 30 
local MAX_LOCK_DISTANCE = 30
local DROP_DISTANCE = 35
local CAMERA_OFFSET = Vector3.new(0, 4.5, 10) 
local TURN_SMOOTHNESS = 0.35

local currentTarget = nil
local isLocked = false
local lastTargetCheck = 0

local function getClosestTarget(maxDistance)
    local character = player.Character
    if not character then return nil end
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    local closestTarget = nil
    local shortestDistance = maxDistance or MAX_LOCK_DISTANCE

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local targetChar = p.Character
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
            
            if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                local distance = (myRoot.Position - targetRoot.Position).Magnitude
                if distance <= shortestDistance then
                    shortestDistance = distance
                    closestTarget = targetChar
                end
            end
        end
    end
    return closestTarget
end

--// HITBOX EXPANDER / LUNGE BOOST
local lungeBoostOn = false
local lungeRange = 9.6

RS.Heartbeat:Connect(function()
    if not lungeBoostOn then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
        local animObj = track.Animation
        local name = animObj and animObj.Name:lower() or ""

        local looksLikeAttack =
               name:find("attack")
            or name:find("slash")
            or name:find("swing")
            or (track.Length > 0.3 and track.Length <= 1.5)

        if looksLikeAttack and track.Length > 0 and (track.TimePosition / track.Length) < 0.75 then
            local oldVelocity = rootPart.Velocity
            rootPart.Velocity = oldVelocity + rootPart.CFrame.LookVector * lungeRange
            RS.RenderStepped:Wait()
            rootPart.Velocity = oldVelocity
            break
        end
    end
end)

CombatTab:CreateSection("Hitbox Expander / Lunge Boost")

CombatTab:CreateToggle({
    Name = "Hitbox Expander / Lunge Boost",
    CurrentValue = false,
    Callback = function(value)
        lungeBoostOn = value
    end,
})

CombatTab:CreateSlider({
    Name = "Lunge Range",
    Range = {1, 30},
    Increment = 0.5,
    CurrentValue = 9.6,
    Callback = function(value)
        lungeRange = tonumber(value) or 9.6
    end,
})

--// CAMLOCK TARGET FOCUS
local function isTargetValid(targetChar)
    if not targetChar or not targetChar.Parent then return false end
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHrp or not targetHumanoid or targetHumanoid.Health <= 0 then return false end

    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHrp then
        local distance = (myHrp.Position - targetHrp.Position).Magnitude
        if distance > DROP_DISTANCE then 
            return false 
        end
    end
    return true
end

local function disableLock()
    isLocked = false
    currentTarget = nil
    RS:UnbindFromRenderStep("CamAndCharLockLoop")
end

local function enableLock()
    isLocked = true
    RS:BindToRenderStep("CamAndCharLockLoop", Enum.RenderPriority.Camera.Value + 1, function()
        if not isLocked then return end
        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local now = os.clock()
        if now - lastTargetCheck > 0.1 then
            lastTargetCheck = now
            if not isTargetValid(currentTarget) then 
                currentTarget = getClosestTarget(MAX_LOCK_DISTANCE) 
            end
        end

        if currentTarget and isTargetValid(currentTarget) then
            local targetRoot = currentTarget:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local myPos = myRoot.Position
                local targetPos = targetRoot.Position
                local targetAimPos = targetPos + Vector3.new(0, 1.5, 0)
                
                local charLookTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
                myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myPos, charLookTarget), TURN_SMOOTHNESS)
                
                local flatDirection = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Unit
                if flatDirection.Magnitude == 0 then flatDirection = Vector3.new(0, 0, 1) end
                local finalCamPos = myPos - (flatDirection * CAMERA_OFFSET.Z) + Vector3.new(0, CAMERA_OFFSET.Y, 0)
                camera.CFrame = CFrame.lookAt(finalCamPos, targetAimPos)
            end
        else
            currentTarget = nil
        end
    end)
end

CombatTab:CreateSection("Combat Utility")

CombatTab:CreateToggle({
    Name = "Camlock Target Focus",
    CurrentValue = false,
    Callback = function(value)
        if value then enableLock() else disableLock() end
    end,
})

CombatTab:CreateSlider({
    Name = "Camlock Max Distance",
    Range = {10, 60},
    Increment = 1,
    CurrentValue = 30,
    Callback = function(value)
        MAX_LOCK_DISTANCE = tonumber(value) or 30
        DROP_DISTANCE = MAX_LOCK_DISTANCE + 5
    end,
})

--// TPWALK
UtilityTab:CreateSection("Movement Mods")

local tpwalkOn = false
local speed = 1

UtilityTab:CreateToggle({
    Name = "TpWalk",
    CurrentValue = false,
    Callback = function(value)
        tpwalkOn = value
    end,
})

UtilityTab:CreateSlider({
    Name = "TpWalk Speed",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Callback = function(value)
        speed = tonumber(value) or 1
    end,
})

RS.Heartbeat:Connect(function()
    if tpwalkOn and char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid then
            local move = humanoid.MoveDirection
            if move.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (move * speed)
            end
        end
    end
end)

--// INFINITE STAMINA (GETGC MAINMODULE LOCK)
UtilityTab:CreateSection("Stamina Mods")

local infStaminaOn = false
local MainModule = nil

local function locateMainModule()
    if getgenv and getgenv().MainModule and type(getgenv().MainModule) == "table" then
        MainModule = getgenv().MainModule
        return MainModule
    end

    if getgc then
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "Stamina") ~= nil and rawget(obj, "MaxStamina") ~= nil then
                MainModule = obj
                if getgenv then getgenv().MainModule = obj end
                return MainModule
            end
        end
    end

    if getloadedmodules then
        for _, mod in ipairs(getloadedmodules()) do
            if mod:IsA("ModuleScript") then
                local success, res = pcall(require, mod)
                if success and type(res) == "table" and res.MaxStamina and res.Stamina ~= nil then
                    MainModule = res
                    if getgenv then getgenv().MainModule = res end
                    return MainModule
                end
            end
        end
    end

    return MainModule
end

locateMainModule()

local function updateStaminaHUD(state)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local tempUI = playerGui:FindFirstChild("TemporaryUI")
    if not tempUI then return end

    local playerInfo = tempUI:FindFirstChild("PlayerInfo")
    local bars = playerInfo and playerInfo:FindFirstChild("Bars")
    local staminaBar = bars and bars:FindFirstChild("Stamina")
    local originalAmount = staminaBar and staminaBar:FindFirstChild("Amount")

    if originalAmount then
        local infAmount = staminaBar:FindFirstChild("InfiniteAmount")
        if not infAmount then
            infAmount = originalAmount:Clone()
            infAmount.Name = "InfiniteAmount"
            infAmount.Text = "∞"
            infAmount.Size = UDim2.new(0.225, 0, 0.7, 14)
            infAmount.Parent = staminaBar
        end
        infAmount.Visible = state
        originalAmount.Visible = not state
    end

    local centerCounter = tempUI:FindFirstChild("CenterStaminaCounter")
    if centerCounter then centerCounter.Visible = not state end

    local centerDrain = tempUI:FindFirstChild("Drain")
    if centerDrain then centerDrain.Visible = not state end
end

local function applyStaminaLock()
    if not infStaminaOn then return end

    if not MainModule then
        locateMainModule()
    end

    if MainModule and MainModule.MaxStamina then
        rawset(MainModule, "Stamina", MainModule.MaxStamina)
    end
end

UtilityTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(value)
        infStaminaOn = value
        if value then locateMainModule() end
        updateStaminaHUD(value)
    end,
})

RS.Heartbeat:Connect(applyStaminaLock)
RS.RenderStepped:Connect(applyStaminaLock)

player.CharacterAdded:Connect(function()
    task.wait(1)
    locateMainModule()
    if infStaminaOn then updateStaminaHUD(true) end
end)

--// GENERATOR AUTOMATION & SMART TELEPORT
UtilityTab:CreateSection("Generator Automation")

local AutoGenEnabled = false
local AutoGenCooldown = 1.5
local CurrentGenIndex = 1

local function GetGameMap()
    return (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") and workspace.Map.Ingame:FindFirstChild("Map"))
        or (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame"))
        or workspace:FindFirstChild("Map")
        or workspace
end

local function isGenFinished(genModel)
    if not genModel or not genModel.Parent or not genModel:IsDescendantOf(workspace) then 
        return true 
    end

    if genModel:GetAttribute("Completed") == true 
        or genModel:GetAttribute("Finished") == true 
        or genModel:GetAttribute("Done") == true then
        return true
    end

    local progressVal = genModel:FindFirstChild("Progress")
    if progressVal and (progressVal:IsA("NumberValue") or progressVal:IsA("IntValue")) then
        if progressVal.Value >= 100 then
            return true
        end
    end

    return false
end

-- Collects only incomplete or semi-completed generators
local function getIncompleteGenerators()
    local searchScope = GetGameMap()
    local incomplete = {}

    for _, obj in ipairs(searchScope:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("generator") then
            local mainPart = obj:FindFirstChild("Main") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if mainPart and not isGenFinished(obj) then
                table.insert(incomplete, {
                    Model = obj,
                    Main = mainPart
                })
            end
        end
    end

    return incomplete
end

local function TeleportToNextGen()
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local incompleteList = getIncompleteGenerators()

    if #incompleteList == 0 then
        Rayfield:Notify({
            Title = "Generators Completed",
            Content = "All of the generators are completed!",
            Duration = 3,
            Image = 4483362458,
        })
        return
    end

    if CurrentGenIndex > #incompleteList then
        CurrentGenIndex = 1
    end

    local targetGen = incompleteList[CurrentGenIndex]
    if targetGen and targetGen.Main then
        -- Positions 2.8 studs in front facing the generator safely on the ground
        local mainCFrame = targetGen.Main.CFrame
        local targetPos = (mainCFrame * CFrame.new(0, 0, -2.8)).Position
        targetPos = Vector3.new(targetPos.X, localRoot.Position.Y, targetPos.Z)

        localRoot.CFrame = CFrame.lookAt(targetPos, Vector3.new(mainCFrame.Position.X, targetPos.Y, mainCFrame.Position.Z))
        localRoot.AssemblyLinearVelocity = Vector3.zero
        localRoot.AssemblyAngularVelocity = Vector3.zero

        local prompt = targetGen.Model:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and fireproximityprompt then
            task.wait(0.15)
            pcall(fireproximityprompt, prompt)
        end

        CurrentGenIndex = CurrentGenIndex + 1
    end
end

local function RunTimedAutoGen()
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local searchScope = GetGameMap()

    if not localRoot or not searchScope then return end

    for _, object in ipairs(searchScope:GetDescendants()) do
        if object:IsA("Model") and object.Name:lower():find("generator") and not isGenFinished(object) then
            local mainPart = object:FindFirstChild("Main") or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
            if mainPart and (mainPart.Position - localRoot.Position).Magnitude <= 7.5 then
                local remotes = object:FindFirstChild("Remotes")
                local remoteEvent = remotes and remotes:FindFirstChildOfClass("RemoteEvent")

                if not remoteEvent then
                    for _, desc in ipairs(object:GetDescendants()) do
                        if desc:IsA("RemoteEvent") then
                            remoteEvent = desc
                            break
                        end
                    end
                end

                if remoteEvent then
                    remoteEvent:FireServer()
                    task.wait(AutoGenCooldown)
                end
            end
        end
    end
end

UtilityTab:CreateToggle({
    Name = "Auto Gen",
    CurrentValue = false,
    Callback = function(value)
        AutoGenEnabled = value
    end,
})

UtilityTab:CreateButton({
    Name = "TP to Next Gen",
    Callback = function()
        pcall(TeleportToNextGen)
    end,
})

UtilityTab:CreateSlider({
    Name = "Auto Gen Cooldown",
    Range = {0.5, 5},
    Increment = 0.1,
    CurrentValue = 1.5,
    Callback = function(value)
        AutoGenCooldown = tonumber(value) or 1.5
    end,
})

task.spawn(function()
    while true do
        task.wait(0.1)
        if AutoGenEnabled then
            pcall(RunTimedAutoGen)
        end
    end
end)
--------------------------------------------------------------------------------
-- PART 5: TELEPORTATION SYSTEM
--------------------------------------------------------------------------------

TeleportTab:CreateSection("Player Teleportation")

local selectedPlayerName = nil

local function getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(list, p.Name)
        end
    end
    return list
end

local PlayerDropdown = TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = getPlayerList(),
    CurrentOption = "",
    Callback = function(option)
        selectedPlayerName = typeof(option) == "table" and option[1] or option
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Selected Player",
    Callback = function()
        if not selectedPlayerName then
            Rayfield:Notify({
                Title = "Teleport Failed",
                Content = "Please select a player from the dropdown first.",
                Duration = 2,
                Image = 4483362458,
            })
            return
        end

        local targetPlr = Players:FindFirstChild(selectedPlayerName)
        if targetPlr and targetPlr.Character then
            local tRoot = targetPlr.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and myRoot then
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
            end
        else
            Rayfield:Notify({
                Title = "Player Unavailable",
                Content = "Target player is no longer alive or in the game.",
                Duration = 2,
                Image = 4483362458,
            })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        if PlayerDropdown then
            PlayerDropdown:Refresh(getPlayerList(), true)
        end
    end,
})

TeleportTab:CreateSection("Map Teleportation")

TeleportTab:CreateButton({
    Name = "Teleport to Ingame Map",
    Callback = function()
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local map = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")
        if map then
            local spawnPoint = map:FindFirstChildWhichIsA("SpawnLocation", true) or map:FindFirstChildWhichIsA("BasePart", true)
            if spawnPoint then
                myRoot.CFrame = spawnPoint.CFrame * CFrame.new(0, 4, 0)
            end
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Killer",
    Callback = function()
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local charType = p.Character:GetAttribute("Character") or p.Character.Name
                if charType and KILLER_CLASSES and KILLER_CLASSES[string.lower(tostring(charType))] then
                    local kRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    if kRoot then
                        myRoot.CFrame = kRoot.CFrame * CFrame.new(0, 0, 5)
                        return
                    end
                end
            end
        end

        Rayfield:Notify({
            Title = "Killer Not Found",
            Content = "No killer character found in the round.",
            Duration = 2.5,
            Image = 4483362458,
        })
    end,
})
--------------------------------------------------------------------------------
-- PART 6: ITEMS TAB (ITEM & CRATE TELEPORTERS)
--------------------------------------------------------------------------------

local function isItemValidAndAvailable(v)
    if not v or not v:IsDescendantOf(workspace) then return false end

    local ancestorModel = v:FindFirstAncestorOfClass("Model")
    if ancestorModel then
        if Players:GetPlayerFromCharacter(ancestorModel) or ancestorModel:FindFirstChildOfClass("Humanoid") then
            return false
        end
    end

    local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return false end

    return true
end

local function getTargetItemCFrame(matchKeywords)
    local searchRoot = (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")) or workspace

    for _, v in ipairs(searchRoot:GetDescendants()) do
        local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)

        if prompt and isItemValidAndAvailable(v) then
            local nameLower = v.Name:lower()
            local promptAction = prompt.ActionText:lower()
            local promptObject = prompt.ObjectText:lower()

            local isMatch = false
            for _, keyword in ipairs(matchKeywords) do
                local kw = keyword:lower()
                if nameLower:find(kw) or promptAction:find(kw) or promptObject:find(kw) then
                    isMatch = true
                    break
                end
            end

            if isMatch then
                if v:IsA("BasePart") then
                    return v.CFrame
                elseif v:IsA("Model") then
                    local primary = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
                    if primary then
                        return primary.CFrame
                    end
                end
            end
        end
    end

    return nil
end

local function teleportToItem(matchKeywords, itemName)
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local itemCFrame = getTargetItemCFrame(matchKeywords)
    if itemCFrame then
        myRoot.CFrame = itemCFrame * CFrame.new(0, 3, 0)
        Rayfield:Notify({
            Title = "Item Found",
            Content = "Teleported to " .. itemName .. "!",
            Duration = 2.5,
            Image = 4483362458,
        })
    else
        Rayfield:Notify({
            Title = "Item Unavailable",
            Content = "No available " .. itemName .. " found in this round.",
            Duration = 3,
            Image = 4483362458,
        })
    end
end

ItemsTab:CreateSection("Item Teleporters")

ItemsTab:CreateButton({
    Name = "Teleport to Medkit",
    Callback = function()
        teleportToItem({"medkit", "med kit", "firstaid"}, "Medkit")
    end,
})

ItemsTab:CreateButton({
    Name = "Teleport to Bloxy Cola",
    Callback = function()
        teleportToItem({"bloxycola", "bloxy cola", "cola"}, "Bloxy Cola")
    end,
})

ItemsTab:CreateSection("Special Teleporters")

ItemsTab:CreateButton({
    Name = "Teleport to Crate",
    Callback = function()
        teleportToItem({"crate", "chest", "box"}, "Crate")
    end,
})
