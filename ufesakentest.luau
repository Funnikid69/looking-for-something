--------------------------------------------------------------------------------
-- GAME ID CHECKER
--------------------------------------------------------------------------------
local ALLOWED_PLACE_IDS = {
    [99585784721880] = true,
}

if not ALLOWED_PLACE_IDS[game.PlaceId] then
    game:GetService("Players").LocalPlayer:Kick("Incorrect Game! Current Place ID (" .. tostring(game.PlaceId) .. ") is not authorized.")
    return
end

--------------------------------------------------------------------------------
-- ORIGINAL RAYFIELD SETUP
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player = game.Players.LocalPlayer
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera

--// ORIGINAL RAYFIELD WINDOW (NOVASAKEN)
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

--// TABS (7 ACTIVE TABS)
local CombatTab = Window:CreateTab("Combat", 4483362458)
local AutoFarmTab = Window:CreateTab("Auto Farm", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local UtilityTab = Window:CreateTab("Movement & Misc", 4483362458)
local TeleportTab = Window:CreateTab("Teleporter", 4483362458)
local ItemsTab = Window:CreateTab("Items", 4483362458)
local AutoGenTab = Window:CreateTab("Auto Gen", 4483362458)

--------------------------------------------------------------------------------
-- CHARACTER & STATE TRACKING
--------------------------------------------------------------------------------
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    char = c
    hum = c:WaitForChild("Humanoid")
end)

--------------------------------------------------------------------------------
-- AUTO FARM STATE TRACKERS
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- STRICT TARGET VALIDATION & SELECTION
--------------------------------------------------------------------------------

local function isTargetAliveAndValid(p, maxHpConstraint)
    if not p or not p.Parent or not p.Character or p == player then return false end
    local tHum = p.Character:FindFirstChild("Humanoid")
    local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
    
    if not tHum or not tRoot or tHum.Health <= 0 or not p.Character:IsDescendantOf(workspace) then
        return false
    end

    -- STRICT LOW HP CHECK
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

--------------------------------------------------------------------------------
-- POSITIONING & LOOP LOGIC
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- AUTO FARM TAB ELEMENTS (RAYFIELD)
--------------------------------------------------------------------------------

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
-- PART 3: ROLE-BASED, MINION, GENERATOR & ITEM DYNAMIC ESP
--------------------------------------------------------------------------------

local espOn = false
local minionEspOn = false
local generatorEspOn = false
local itemEspOn = false

local activeESP = {}
local activeMinionESP = {}
local activeGenESP = {}
local activeItemESP = {}

-- Character Role Sets
local SURVIVOR_CLASSES = {
    ["guest1337"] = "Guest 1337", ["shedletsky"] = "Shedletsky", ["dusekkar"] = "Dusekkar",
    ["martialartist"] = "Martial Artist", ["chance"] = "Chance", ["twotime"] = "TwoTime",
    ["007n7"] = "007n7", ["elliot"] = "Elliot", ["veeronica"] = "Veeronica",
    ["janedoe"] = "Jane Doe", ["messi"] = "Messi", ["noob"] = "Noob"
}

local KILLER_CLASSES = {
    ["slasher"] = "Slasher", ["jason"] = "Jason", ["c00lkidd"] = "c00lkidd",
    ["1x1x1x1"] = "1x1x1x1", ["noli"] = "Noli", ["swordsmaster"] = "Swordsmaster",
    ["guest666"] = "Guest 666", ["2011x"] = "2011x", ["johndoe"] = "John Doe",
    ["azure"] = "Azure"
}

local MAP_BLACKLIST = {
    ["map"] = true,
    ["ingame"] = true,
    ["workspace"] = true,
    ["generators"] = true,
    ["generator"] = true,
    ["spawns"] = true,
    ["lobby"] = true,
    ["terrain"] = true,
}

--------------------------------------------------------------------------------
-- 1. PLAYER ROLE ESP
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- 2. C00LKIDD MINION ESP (ORANGE HIGHLIGHT & TEXT)
--------------------------------------------------------------------------------

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

    local minionColor = Color3.fromRGB(255, 130, 0) -- Pure Orange

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
            highlight.Enabled = false
            billboard.Enabled = false
        else
            highlight.Enabled = true
            billboard.Enabled = true
            if hum then
                label.Text = string.format("c00lkidd Minion | %d HP", math.floor(hum.Health))
            else
                label.Text = "c00lkidd Minion"
            end
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

--------------------------------------------------------------------------------
-- 3. GENERATOR ESP (YELLOW = IN PROGRESS, WHITE = DONE)
--------------------------------------------------------------------------------

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
    if progress then
        if progress:IsA("NumberValue") or progress:IsA("IntValue") then
            if progress.Value >= 100 then return true end
        end
    end
    local prompt = genModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and not prompt.Enabled then
        return true
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
-- 4. ITEM ESP (MAP EXCLUSION FILTER)
--------------------------------------------------------------------------------

local function resolveItemTarget(prompt)
    if not prompt or not prompt.Enabled then return nil end

    local parentObj = prompt.Parent
    if not parentObj or not parentObj:IsDescendantOf(workspace) then return nil end

    -- Ignore Generators completely
    local actionText = prompt.ActionText:lower()
    local objectText = prompt.ObjectText:lower()
    if actionText:find("repair") or objectText:find("generator") or parentObj.Name:lower():find("generator") then
        return nil
    end

    -- Ignore Player Characters
    local charModel = prompt:FindFirstAncestorOfClass("Model")
    if charModel then
        if Players:GetPlayerFromCharacter(charModel) or charModel:FindFirstChildOfClass("Humanoid") then
            return nil
        end
    end

    -- Prevent Map Selection
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

--------------------------------------------------------------------------------
-- DYNAMIC WORKSPACE MONITORING & CLEANUP
--------------------------------------------------------------------------------

workspace.DescendantAdded:Connect(function(descendant)
    if minionEspOn and descendant:IsA("Model") and (descendant.Name == "PizzaDeliveryRig" or descendant.Name:find("PizzaDelivery")) then
        applyMinionESP(descendant)
    end

    if generatorEspOn and descendant:IsA("Model") and (descendant.Name == "Generator" or descendant.Name:find("Generator")) then
        applyGenESP(descendant)
    end

    if itemEspOn and descendant:IsA("ProximityPrompt") then
        local validItem = resolveItemTarget(descendant)
        if validItem then
            applyItemESP(validItem)
        end
    end
end)

workspace.DescendantRemoving:Connect(function(descendant)
    if activeMinionESP[descendant] then
        removeMinionESP(descendant)
    end
    if activeGenESP[descendant] then
        removeGenESP(descendant)
    end
    if activeItemESP[descendant] then
        removeItemESP(descendant)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.6)
        if minionEspOn then
            for minion, _ in pairs(activeMinionESP) do
                if not minion or not minion:IsDescendantOf(workspace) then
                    removeMinionESP(minion)
                end
            end
            scanMinions()
        end
        if generatorEspOn then
            for gen, _ in pairs(activeGenESP) do
                if not gen or not gen:IsDescendantOf(workspace) then
                    removeGenESP(gen)
                end
            end
            scanGenerators()
        end
        if itemEspOn then
            for item, _ in pairs(activeItemESP) do
                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                if not prompt or not prompt.Enabled or not item:IsDescendantOf(workspace) then
                    removeItemESP(item)
                end
            end
            scanAndApplyItemESP()
        end
    end
end)

--------------------------------------------------------------------------------
-- ESP TAB ELEMENTS (ORIGINAL RAYFIELD)
--------------------------------------------------------------------------------

ESPTab:CreateSection("Player Visuals")

ESPTab:CreateToggle({
    Name = "Role ESP (Blue Survivor / Red Killer)",
    CurrentValue = false,
    Callback = function(value)
        espOn = value
        if espOn then
            for _, p in ipairs(Players:GetPlayers()) do
                applyESP(p)
            end
        else
            for p, _ in pairs(activeESP) do
                removeESP(p)
            end
        end
    end,
})

ESPTab:CreateSection("Minion Visuals")

ESPTab:CreateToggle({
    Name = "C00lkidd Minion ESP",
    CurrentValue = false,
    Callback = function(value)
        minionEspOn = value
        if minionEspOn then
            scanMinions()
        else
            clearAllMinionESP()
        end
    end,
})

ESPTab:CreateSection("Objective Visuals")

ESPTab:CreateToggle({
    Name = "Generator ESP (Yellow / White)",
    CurrentValue = false,
    Callback = function(value)
        generatorEspOn = value
        if generatorEspOn then
            scanGenerators()
        else
            clearAllGenESP()
        end
    end,
})

ESPTab:CreateSection("Item Visuals")

ESPTab:CreateToggle({
    Name = "Item ESP (Green)",
    CurrentValue = false,
    Callback = function(value)
        itemEspOn = value
        if itemEspOn then
            scanAndApplyItemESP()
        else
            clearAllItemESP()
        end
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

local function getClosestTarget()
    local character = player.Character
    if not character then return nil end
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    local closestTarget = nil
    local shortestDistance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local targetChar = p.Character
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
            
            if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                local distance = (myRoot.Position - targetRoot.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestTarget = targetChar
                end
            end
        end
    end
    return closestTarget
end

--------------------------------------------------------------------------------
-- HITBOX EXPANDER / LUNGE BOOST SYSTEM
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- CAMLOCK TARGET FOCUS (OPTIMIZED RENDERSTEP)
--------------------------------------------------------------------------------
local DROP_DISTANCE = 35
local CAMERA_OFFSET = Vector3.new(0, 4.5, 10) 
local TURN_SMOOTHNESS = 0.35
local currentTarget = nil
local isLocked = false
local lastTargetCheck = 0

local function isTargetValid(targetChar)
    if not targetChar or not targetChar.Parent then return false end
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHrp or not targetHumanoid or targetHumanoid.Health <= 0 then return false end

    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHrp then
        if (myHrp.Position - targetHrp.Position).Magnitude > DROP_DISTANCE then return false end
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
                currentTarget = getClosestTarget() 
            end
        end

        if currentTarget then
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

--------------------------------------------------------------------------------
-- UTILITY TAB: MOVEMENT MODS
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- UTILITY TAB: INFINITE STAMINA
--------------------------------------------------------------------------------
UtilityTab:CreateSection("Stamina Mods")

local staminaModule = nil
if getloadedmodules then
    for _, mod in ipairs(getloadedmodules()) do
        if mod.Name == "Main" or mod.Name == "PlayerModule" or mod.Name == "Stamina" then
            local success, res = pcall(require, mod)
            if success and type(res) == "table" and (res.Stamina ~= nil or res.MaxStamina ~= nil) then
                staminaModule = res
                break
            end
        end
    end
end

if not staminaModule and getgenv and getgenv().MainModule then
    staminaModule = getgenv().MainModule
end

local infStaminaOn = false

local function updateStaminaHUD(state)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local tempUI = playerGui:FindFirstChild("TemporaryUI")
    if not tempUI then return end

    local bars = tempUI:FindFirstChild("PlayerInfo") and tempUI.PlayerInfo:FindFirstChild("Bars")
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
    if centerCounter then
        centerCounter.Visible = not state
    end

    local centerDrain = tempUI:FindFirstChild("Drain")
    if centerDrain then
        centerDrain.Visible = not state
    end
end

UtilityTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(value)
        infStaminaOn = value
        updateStaminaHUD(value)
    end,
})

RS.Heartbeat:Connect(function()
    if infStaminaOn and staminaModule and staminaModule.MaxStamina then
        rawset(staminaModule, "Stamina", staminaModule.MaxStamina)
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(1)
    if infStaminaOn then
        updateStaminaHUD(true)
    end
end)

--------------------------------------------------------------------------------
-- UTILITY TAB: GENERATOR AUTOMATION
--------------------------------------------------------------------------------
UtilityTab:CreateSection("Generator Automation")

local AutoGenEnabled = false
local CurrentGenIndex = 1
local AutoGenCooldown = 1.5

local function GetGameMap()
    return workspace:FindFirstChild("Map") 
        and workspace.Map:FindFirstChild("Ingame") 
        and workspace.Map.Ingame:FindFirstChild("Map")
end

local function TeleportToNextGen()
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local gameMap = GetGameMap()

    if not localRoot or not gameMap then return end

    local generators = {}
    for _, object in ipairs(gameMap:QueryDescendants("Model#Generator:has(#Main)")) do
        local mainPart = object:FindFirstChild("Main")
        if mainPart then
            table.insert(generators, mainPart)
        end
    end

    if #generators == 0 then return end

    if CurrentGenIndex > #generators then
        CurrentGenIndex = 1
    end

    local targetGen = generators[CurrentGenIndex]
    if targetGen then
        localRoot.CFrame = targetGen.CFrame * CFrame.new(0, 3, -4)
        CurrentGenIndex = CurrentGenIndex + 1
    end
end

local function RunTimedAutoGen()
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local gameMap = GetGameMap()

    if not localRoot or not gameMap then return end

    for _, object in ipairs(gameMap:QueryDescendants("Model#Generator:has(#Main)")) do
        local mainPart = object:FindFirstChild("Main")
        if mainPart and (mainPart.Position - localRoot.Position).Magnitude < 7 then
            local remotes = object:FindFirstChild("Remotes")
            local progress = object:FindFirstChild("Progress")
            local remoteEvent = progress and remotes and remotes:FindFirstChildOfClass("RemoteEvent")

            if remoteEvent then
                remoteEvent:FireServer()
                task.wait(AutoGenCooldown)
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
-- PART 5: PLAYER TELEPORTER
--------------------------------------------------------------------------------

TeleportTab:CreateSection("Player Teleporter")

local selectedPlayer, stickInFrontOn, stickOffset, searchQuery = nil, false, 5.5, ""
local playerDropdownOptions, playerMap, PlayerDropdown = {}, {}, nil

local function refreshPlayerDropdown()
    playerDropdownOptions, playerMap = {}, {}
    local queryLower = string.lower(searchQuery)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local displayName, username = p.DisplayName, p.Name
            if queryLower == "" or string.find(string.lower(displayName), queryLower, 1, true) or string.find(string.lower(username), queryLower, 1, true) then
                local formattedName = displayName .. " (@" .. username .. ")"
                table.insert(playerDropdownOptions, formattedName)
                playerMap[formattedName] = p
            end
        end
    end
    if #playerDropdownOptions == 0 then
        playerDropdownOptions = {"No Players Found"}
    end
    if PlayerDropdown and PlayerDropdown.Refresh then
        PlayerDropdown:Refresh(playerDropdownOptions)
    end
end

TeleportTab:CreateInput({
    Name = "Search Player",
    PlaceholderText = "Type to filter...",
    Callback = function(text)
        searchQuery = text or ""
        refreshPlayerDropdown()
    end,
})

PlayerDropdown = TeleportTab:CreateDropdown({
    Name = "Select Target Player",
    Options = {"Loading..."},
    CurrentOption = "Loading...",
    Callback = function(option)
        local selected = typeof(option) == "table" and option[1] or option
        selectedPlayer = playerMap[selected]
    end,
})

task.defer(function()
    refreshPlayerDropdown()
end)

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    refreshPlayerDropdown()
end)

Players.PlayerRemoving:Connect(function(p)
    if selectedPlayer == p then
        selectedPlayer = nil
        stickInFrontOn = false
    end
    refreshPlayerDropdown()
end)

TeleportTab:CreateButton({
    Name = "Teleport to Player",
    Callback = function()
        if selectedPlayer and selectedPlayer.Character then
            local targetHrp = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp and myHrp then
                myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -3)
            end
        end
    end,
})

TeleportTab:CreateToggle({
    Name = "Stick in Front of Player",
    CurrentValue = false,
    Callback = function(value)
        stickInFrontOn = value
    end,
})

TeleportTab:CreateSlider({
    Name = "Stick Distance Offset",
    Range = {2, 25},
    Increment = 0.5,
    CurrentValue = 5.5,
    Callback = function(value)
        stickOffset = value
    end,
})

RS.RenderStepped:Connect(function()
    if stickInFrontOn and selectedPlayer and selectedPlayer.Character then
        local targetChar = selectedPlayer.Character
        local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

        if not targetHrp or not targetHum or targetHum.Health <= 0 then
            stickInFrontOn = false
            selectedPlayer = nil
            return
        end

        if myHrp then
            local pos = targetHrp.CFrame * CFrame.new(0, 0, -stickOffset)
            myHrp.CFrame = CFrame.lookAt(pos.Position, targetHrp.Position)
        end
    end
end)
--------------------------------------------------------------------------------
-- PART 6: ITEMS TAB (ITEM TELEPORTERS)
--------------------------------------------------------------------------------

local function isItemValidAndAvailable(v)
    if not v or not v:IsDescendantOf(workspace) then return false end

    -- Check if held by another player or inside a character
    local ancestorModel = v:FindFirstAncestorOfClass("Model")
    if ancestorModel then
        if Players:GetPlayerFromCharacter(ancestorModel) or ancestorModel:FindFirstChildOfClass("Humanoid") then
            return false
        end
    end

    -- Confirm presence of an enabled ProximityPrompt
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
            Content = "No available " .. itemName .. " found (it may be used or taken).",
            Duration = 3,
            Image = 4483362458,
        })
    end
end

--------------------------------------------------------------------------------
-- RAYFIELD ITEMS TAB BUTTONS
--------------------------------------------------------------------------------

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
--------------------------------------------------------------------------------
-- PART 7: FULLY AUTOMATED GENERATOR ROUTE (WITH 3-PLAYER DETECTOR)
--------------------------------------------------------------------------------

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local fullAutoGenActive = false
local autoGenFullToggle = nil
local FIXED_GEN_COOLDOWN = 1.5
local MAX_REPAIR_DISTANCE = 9
local MAX_OCCUPANTS = 3

local function getActiveMap()
    return workspace:FindFirstChild("Map") 
        and workspace.Map:FindFirstChild("Ingame") 
        and workspace.Map.Ingame:FindFirstChild("Map")
end

local function isGeneratorCompleted(genModel)
    if not genModel or not genModel.Parent then return true end

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

    local prompt = genModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and not prompt.Enabled then
        return true
    end

    return false
end

-- Counts how many other players are currently at/repairing the generator
local function getOccupantCount(mainPart)
    local count = 0
    if not mainPart then return count end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                if (hrp.Position - mainPart.Position).Magnitude <= MAX_REPAIR_DISTANCE then
                    count = count + 1
                end
            end
        end
    end

    return count
end

local function getIncompleteGenerators()
    local gameMap = getActiveMap()
    local searchScope = gameMap or workspace
    local incompleteGens = {}

    for _, obj in ipairs(searchScope:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "Generator" or obj.Name:find("Generator")) then
            local mainPart = obj:FindFirstChild("Main") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if mainPart and not isGeneratorCompleted(obj) then
                local occupants = getOccupantCount(mainPart)
                -- Only queue generators that do not already have 3 players
                if occupants < MAX_OCCUPANTS then
                    table.insert(incompleteGens, {
                        Model = obj,
                        Main = mainPart,
                        Occupants = occupants
                    })
                end
            end
        end
    end

    return incompleteGens
end

task.spawn(function()
    while true do
        task.wait(0.2)

        if fullAutoGenActive then
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if myRoot then
                local incompleteList = getIncompleteGenerators()

                if #incompleteList == 0 then
                    -- Check if any generators remain in the match at all
                    local anyLeft = false
                    local gameMap = getActiveMap()
                    local searchScope = gameMap or workspace

                    for _, obj in ipairs(searchScope:GetDescendants()) do
                        if obj:IsA("Model") and (obj.Name == "Generator" or obj.Name:find("Generator")) then
                            if not isGeneratorCompleted(obj) then
                                anyLeft = true
                                break
                            end
                        end
                    end

                    if not anyLeft then
                        -- All generators on the map are fully finished
                        fullAutoGenActive = false
                        if autoGenFullToggle then
                            autoGenFullToggle:Set(false)
                        end

                        Rayfield:Notify({
                            Title = "Auto Gen Finished",
                            Content = "All generators in this round are completed!",
                            Duration = 3.5,
                            Image = 4483362458,
                        })
                    else
                        -- Incomplete generators exist, but all are occupied by 3 players
                        task.wait(0.5)
                    end
                else
                    -- Pick the first generator with fewer than 3 players
                    local targetGenData = incompleteList[1]
                    local genModel = targetGenData.Model
                    local mainPart = targetGenData.Main

                    -- Position character directly in repair range
                    myRoot.CFrame = mainPart.CFrame * CFrame.new(0, 3, -4)

                    -- Stay on this generator until completed, disabled, or 3 other players arrive
                    while fullAutoGenActive and not isGeneratorCompleted(genModel) and genModel:IsDescendantOf(workspace) do
                        -- If 3 other players are now at this generator, abandon and find another
                        if getOccupantCount(mainPart) >= MAX_OCCUPANTS then
                            break
                        end

                        local remotes = genModel:FindFirstChild("Remotes")
                        local progress = genModel:FindFirstChild("Progress")
                        local remoteEvent = progress and remotes and remotes:FindFirstChildOfClass("RemoteEvent")

                        local prompt = genModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and prompt.Enabled and fireproximityprompt then
                            fireproximityprompt(prompt)
                        end

                        if remoteEvent then
                            remoteEvent:FireServer()
                        end

                        task.wait(FIXED_GEN_COOLDOWN)

                        -- Keep character pinned in position against knockback
                        if myRoot and mainPart and mainPart.Parent then
                            myRoot.CFrame = mainPart.CFrame * CFrame.new(0, 3, -4)
                        end
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- AUTO GEN TAB ELEMENTS
--------------------------------------------------------------------------------

AutoGenTab:CreateSection("Automated Route System")

autoGenFullToggle = AutoGenTab:CreateToggle({
    Name = "Smart Auto Gen (Auto-Route)",
    CurrentValue = false,
    Callback = function(value)
        fullAutoGenActive = value
        if value then
            local pending = getIncompleteGenerators()
            if #pending == 0 then
                Rayfield:Notify({
                    Title = "Auto Gen Waiting",
                    Content = "Searching for available generators with < 3 players...",
                    Duration = 2.5,
                    Image = 4483362458,
                })
            end
        end
    end,
})
