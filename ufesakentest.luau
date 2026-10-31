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
local Lighting = game:GetService("Lighting")
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

--// 8 MAIN TABS
local CombatTab = Window:CreateTab("Combat", 4483362458)
local AutoFarmTab = Window:CreateTab("Auto Farm", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local UtilityTab = Window:CreateTab("Movement & Misc", 4483362458)
local TeleportTab = Window:CreateTab("Teleporter", 4483362458)
local ItemsTab = Window:CreateTab("Items", 4483362458)
local AntiTab = Window:CreateTab("Anti", 4483362458)
local AimTab = Window:CreateTab("Aim", 4483362458)

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

--// 5/5 GENERATOR COMPLETION LISTENER
local allGensNotified = false

local function isGenComplete(genModel)
    if not genModel or not genModel.Parent or not genModel:IsDescendantOf(workspace) then 
        return false 
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

local function getGeneratorSearchScope()
    return (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") and workspace.Map.Ingame:FindFirstChild("Map"))
        or (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame"))
        or workspace:FindFirstChild("Map")
        or workspace
end

task.spawn(function()
    while true do
        task.wait(1)
        local scope = getGeneratorSearchScope()
        local completedGens = 0
        local countedModels = {}

        for _, obj in ipairs(scope:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("generator") and not countedModels[obj] then
                if obj:FindFirstChild("Main") or obj:FindFirstChild("Progress") or obj:GetAttribute("Completed") ~= nil then
                    countedModels[obj] = true
                    if isGenComplete(obj) then
                        completedGens = completedGens + 1
                    end
                end
            end
        end

        if completedGens >= 5 then
            if not allGensNotified then
                allGensNotified = true
                Rayfield:Notify({
                    Title = "Generators Finished",
                    Content = "All of the generators are finished! (5/5)",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        else
            allGensNotified = false
        end
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
-- PART 2: AUTO-FARM SYSTEM (WHITELISTED SURVIVORS & KILLER VERIFICATION)
--------------------------------------------------------------------------------

local SURVIVOR_WHITELIST = {
    ["guest1337"]     = "Guest 1337",
    ["shedletsky"]    = "Shedletsky",
    ["dusekkar"]      = "Dusekkar",
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
    ["helperbot"]     = "Helperbot",
    ["torchwood"]     = "Torchwood",
}

local KILLER_CLASSES = {
    ["slasher"]         = true,
    ["jason"]           = true,
    ["c00lkidd"]        = true,
    ["1x1x1x1"]         = true,
    ["noli"]            = true,
    ["swordsmaster"]    = true,
    ["guest666"]        = true,
    ["2011x"]           = true,
    ["johndoe"]         = true,
    ["azure"]           = true,
    ["shedletskyfunny"] = true,
    ["doombringer"]     = "Doombringer",
}

local function isLocalPlayerKiller()
    local myChar = player.Character
    if not myChar then return false end
    local charType = myChar:GetAttribute("Character") 
        or myChar:GetAttribute("CharacterType") 
        or myChar.Name
    local key = string.lower(tostring(charType))
    if key == "coolkid" then key = "c00lkidd" end
    if key == "1x4" then key = "1x1x1x1" end
    return KILLER_CLASSES[key] == true
end

local function isTargetWhitelistedSurvivor(targetChar)
    if not targetChar then return false end
    local charType = targetChar:GetAttribute("Character") 
        or targetChar:GetAttribute("CharacterType") 
        or targetChar.Name
    local key = string.lower(tostring(charType))
    return SURVIVOR_WHITELIST[key] ~= nil
end

local function isTargetAliveAndValid(p, maxHpConstraint)
    if not p or not p.Parent or not p.Character or p == player then return false end
    local tChar = p.Character
    local tHum = tChar:FindFirstChild("Humanoid")
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    
    if not tHum or not tRoot or tHum.Health <= 0 or not tChar:IsDescendantOf(workspace) then
        return false
    end

    if not isTargetWhitelistedSurvivor(tChar) then
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
    if not isLocalPlayerKiller() then
        autoFarmLowHpOn = false
        autoFarmAllOn = false
        currentLockedTarget = nil
        return
    end

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
        if value then
            if not isLocalPlayerKiller() then
                task.spawn(function()
                    if LowHpToggle then LowHpToggle:Set(false) end
                end)
                Rayfield:Notify({
                    Title = "Auto Farm Error",
                    Content = "Your Currently a Survivor And not a killer!",
                    Duration = 3,
                    Image = 4483362458,
                })
                return
            end

            if hum and hum.Health <= 30 then
                autoFarmLowHpOn = false
                task.spawn(function() if LowHpToggle then LowHpToggle:Set(false) end end)
                return
            end

            autoFarmLowHpOn = true
            if AllPlayersToggle then AllPlayersToggle:Set(false) end
        else
            autoFarmLowHpOn = false
            currentLockedTarget = nil
        end
    end,
})

AllPlayersToggle = AutoFarmTab:CreateToggle({
    Name = "Auto Farm All Players",
    CurrentValue = false,
    Callback = function(value)
        if value then
            if not isLocalPlayerKiller() then
                task.spawn(function()
                    if AllPlayersToggle then AllPlayersToggle:Set(false) end
                end)
                Rayfield:Notify({
                    Title = "Auto Farm Error",
                    Content = "Your Currently a Survivor And not a killer!",
                    Duration = 3,
                    Image = 4483362458,
                })
                return
            end

            if hum and hum.Health <= 30 then
                autoFarmAllOn = false
                task.spawn(function() if AllPlayersToggle then AllPlayersToggle:Set(false) end end)
                return
            end

            autoFarmAllOn = true
            if LowHpToggle then LowHpToggle:Set(false) end
        else
            autoFarmAllOn = false
            currentLockedTarget = nil
        end
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
-- PART 3 (SECTION 1): SURVIVOR & KILLER ESP
--------------------------------------------------------------------------------

local survivorEspOn = false
local killerEspOn = false

local SURVIVOR_DATA = {
    ["guest1337"]     = "Guest 1337",
    ["shedletsky"]    = "Shedletsky",
    ["dusekkar"]      = "Dusekkar",
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
    ["helperbot"]     = "Helperbot",
    ["torchwood"]     = "Torchwood",
}

local KILLER_DATA = {
    ["slasher"]         = "Slasher",
    ["jason"]           = "Jason",
    ["coolkid"]         = "c00lkidd",
    ["c00lkidd"]        = "c00lkidd",
    ["coolkidrework"]   = "c00lkidd",
    ["1x4"]             = "1x1x1x1",
    ["1x1x1x1"]         = "1x1x1x1",
    ["noli"]            = "Noli",
    ["swordsmaster"]    = "Swordsmaster",
    ["guest666"]        = "Guest 666",
    ["2011x"]           = "2011x",
    ["johndoe"]         = "John Doe",
    ["azure"]           = "Azure",
    ["shedletskyfunny"] = "Shedletsky (Killer)",
    ["doombringer"]     = "Doombringer",
}

local function getCharacterRoleInfo(char)
    if not char then return "Survivor", "Unknown" end
    local raw = char:GetAttribute("Character")
        or char:GetAttribute("CharacterType")
        or char:GetAttribute("Role")
        or char.Name
    local key = string.lower(tostring(raw))

    if key == "c00lkidd" or key == "coolkidd" then key = "coolkid" end
    if key == "1x1x1x1" then key = "1x4" end

    if KILLER_DATA[key] then
        return "Killer", KILLER_DATA[key]
    elseif SURVIVOR_DATA[key] then
        return "Survivor", SURVIVOR_DATA[key]
    end

    return "Survivor", (raw ~= "" and tostring(raw) or "Survivor")
end

local function cleanEspFromCharacter(char)
    if not char then return end
    local hl = char:FindFirstChild("ESPHighlight")
    if hl then hl:Destroy() end

    local head = char:FindFirstChild("Head")
    if head then
        local bb = head:FindFirstChild("ESPBillboard")
        if bb then bb:Destroy() end
    end
end

local function applyEspToCharacter(plr)
    if plr == player or not plr.Character then return end
    local char = plr.Character
    local head = char:WaitForChild("Head", 3)
    local root = char:WaitForChild("HumanoidRootPart", 3)
    local hum = char:WaitForChild("Humanoid", 3)
    if not head or not root or not hum then return end

    local role, displayName = getCharacterRoleInfo(char)
    local isKiller = (role == "Killer")

    if isKiller and not killerEspOn then
        cleanEspFromCharacter(char)
        return
    end
    if not isKiller and not survivorEspOn then
        cleanEspFromCharacter(char)
        return
    end

    local themeColor = isKiller and Color3.fromRGB(255, 35, 35) or Color3.fromRGB(0, 255, 140)

    -- Highlight
    local hl = char:FindFirstChild("ESPHighlight") or Instance.new("Highlight")
    hl.Name = "ESPHighlight"
    hl.Adornee = char
    hl.FillColor = themeColor
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    -- Billboard Tag
    local bb = head:FindFirstChild("ESPBillboard") or Instance.new("BillboardGui")
    bb.Name = "ESPBillboard"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 160, 0, 45)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local label = bb:FindFirstChild("InfoLabel") or Instance.new("TextLabel")
    label.Name = "InfoLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = themeColor
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = bb
end

local function updateEspLoop()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local c = p.Character
            local hum = c:FindFirstChildOfClass("Humanoid")
            local root = c:FindFirstChild("HumanoidRootPart")
            local head = c:FindFirstChild("Head")

            if hum and root and head and hum.Health > 0 then
                local role, disp = getCharacterRoleInfo(c)
                local isKiller = (role == "Killer")

                if (isKiller and killerEspOn) or (not isKiller and survivorEspOn) then
                    applyEspToCharacter(p)
                    local bb = head:FindFirstChild("ESPBillboard")
                    local lbl = bb and bb:FindFirstChild("InfoLabel")
                    if lbl and myRoot then
                        local dist = math.floor((myRoot.Position - root.Position).Magnitude)
                        lbl.Text = string.format("%s\n[%s] - %d HP\n%dm", p.DisplayName, disp, math.floor(hum.Health), dist)
                    end
                else
                    cleanEspFromCharacter(c)
                end
            else
                cleanEspFromCharacter(c)
            end
        end
    end
end

RS.Heartbeat:Connect(updateEspLoop)

ESPTab:CreateSection("Player ESP")

ESPTab:CreateToggle({
    Name = "Survivors ESP",
    CurrentValue = false,
    Callback = function(value)
        survivorEspOn = value
        if not value then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local role = getCharacterRoleInfo(p.Character)
                    if role ~= "Killer" then cleanEspFromCharacter(p.Character) end
                end
            end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Killers ESP",
    CurrentValue = false,
    Callback = function(value)
        killerEspOn = value
        if not value then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local role = getCharacterRoleInfo(p.Character)
                    if role == "Killer" then cleanEspFromCharacter(p.Character) end
                end
            end
        end
    end,
})
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
-- PART 4 (SECTION 1): COMBAT TAB (KILLER CAMLOCK GUI), MOVEMENT & STEALTH MODS
--------------------------------------------------------------------------------

local CoreGui = game:GetService("CoreGui")

--// CONFIGURATION
local MAX_SURVIVOR_DISTANCE = 85
local CAM_SMOOTHNESS = 0.22      -- Camera aim tracking speed
local CHAR_SMOOTHNESS = 0.28     -- Character rotation speed
local PREDICTION_FACTOR = 0.055  -- Velocity lead prediction
local AIM_HEIGHT_OFFSET = 0.5    -- Torso / upper chest

local SURVIVOR_WHITELIST = {
    ["guest1337"]     = "Guest 1337",
    ["shedletsky"]    = "Shedletsky",
    ["dusekkar"]      = "Dusekkar",
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
    ["helperbot"]     = "Helperbot",
    ["torchwood"]     = "Torchwood",
}

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
    ["shedletskyfunny"] = true,
    ["doombringer"]     = true,
}

--// STATE
local isLocked = false
local currentLockedSurvivor = nil

--// CLEANUP PREVIOUS INSTANCES
local GUI_NAME = "KillerCamlockUI"
local oldGui = CoreGui:FindFirstChild(GUI_NAME) or (player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild(GUI_NAME))
if oldGui then
    oldGui:Destroy()
end

--// GUI CREATION
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Enabled = false

pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 200, 0, 95)
mainFrame.Position = UDim2.new(0.08, 0, 0.45, 0)
mainFrame.BackgroundTransparency = 1
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 32)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(150, 15, 15)
header.BorderSizePixel = 0
header.Font = Enum.Font.GothamBold
header.Text = "Killers Aimbot"
header.TextColor3 = Color3.fromRGB(245, 245, 245)
header.TextSize = 14
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
toggleButton.Position = UDim2.new(0, 0, 0, 38)
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

--// HELPER FUNCTIONS
local function getCharacterKey(targetChar)
    if not targetChar then return "" end
    local charType = targetChar:GetAttribute("Character")
        or targetChar:GetAttribute("CharacterType")
        or targetChar:GetAttribute("Role")
        or targetChar.Name
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

local function isSurvivorAliveAndValid(p)
    if not p or not p.Parent or not p.Character or p == player then return false end
    local tChar = p.Character
    if not tChar:IsDescendantOf(workspace) then return false end

    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tHum or not tRoot or tHum.Health <= 0 then return false end

    local key = getCharacterKey(tChar)
    if not SURVIVOR_WHITELIST[key] then return false end
    if KILLER_CLASSES[key] then return false end

    return true
end

local function getLockedOrClosestSurvivor()
    if currentLockedSurvivor and isSurvivorAliveAndValid(currentLockedSurvivor) then
        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tRoot = currentLockedSurvivor.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and tRoot then
            local dist = (myRoot.Position - tRoot.Position).Magnitude
            if dist <= MAX_SURVIVOR_DISTANCE then
                return currentLockedSurvivor.Character
            end
        end
    end

    currentLockedSurvivor = nil

    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local shortestDist = MAX_SURVIVOR_DISTANCE

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isSurvivorAliveAndValid(p) then
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

    currentLockedSurvivor = closest
    return closest and closest.Character or nil
end

Players.PlayerRemoving:Connect(function(leavingPlayer)
    if currentLockedSurvivor == leavingPlayer then
        currentLockedSurvivor = nil
    end
end)

--// CAMLOCK LOGIC
local function disableLock()
    isLocked = false
    currentLockedSurvivor = nil
    pcall(function() RS:UnbindFromRenderStep("KillerCamlockLoop") end)
    toggleButton.Text = "Aimbot : Off"
end

local function enableLock()
    isLocked = true
    pcall(function() RS:UnbindFromRenderStep("KillerCamlockLoop") end)
    RS:BindToRenderStep("KillerCamlockLoop", Enum.RenderPriority.Camera.Value + 1, function()
        if not isLocked then return end

        if not isLocalPlayerKiller() then
            toggleButton.Text = "Not a Killer"
            currentLockedSurvivor = nil
            return
        end

        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not myRoot or not myHum or myHum.Health <= 0 then return end

        local targetChar = getLockedOrClosestSurvivor()
        if not targetChar then
            toggleButton.Text = "No players nearby"
            return
        end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not targetHum or targetHum.Health <= 0 then
            currentLockedSurvivor = nil
            toggleButton.Text = "No players nearby"
            return
        end

        toggleButton.Text = "Aimbot : On"

        local myPos = myRoot.Position
        local targetPos = targetRoot.Position

        local targetVelocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
        local aimTarget = targetPos + Vector3.new(0, AIM_HEIGHT_OFFSET, 0) + (targetVelocity * PREDICTION_FACTOR)

        local currentCamPos = camera.CFrame.Position
        local aimDir = (aimTarget - currentCamPos)

        if aimDir.Magnitude > 0.1 then
            local targetCamCF = CFrame.lookAt(currentCamPos, aimTarget)
            camera.CFrame = camera.CFrame:Lerp(targetCamCF, CAM_SMOOTHNESS)

            local flatDiff = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
            if flatDiff.Magnitude > 0.5 then
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
    Range = {1, 200},
    Increment = 0.5,
    CurrentValue = 9.6,
    Callback = function(value)
        lungeRange = tonumber(value) or 9.6
    end,
})

CombatTab:CreateSection("Combat Utility")

CombatTab:CreateToggle({
    Name = "Killer Camlock",
    CurrentValue = false,
    Callback = function(value)
        if value then
            if not isLocalPlayerKiller() then
                task.spawn(function()
                    Rayfield:Notify({
                        Title = "Camlock Error",
                        Content = "You're not a killer!",
                        Duration = 3,
                        Image = 4483362458,
                    })
                end)
            end
            screenGui.Enabled = true
            enableLock()
        else
            disableLock()
            screenGui.Enabled = false
        end
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

--// INVISIBILITY
UtilityTab:CreateSection("Stealth Mods")

local invisOn = false
local invisNoclipConn = nil
local invisCamConn = nil
local invisAnimTrack = nil
local invisAnimObj = Instance.new("Animation")
invisAnimObj.AnimationId = "rbxassetid://105781160624925"

local function playInvisAnim(h)
    if not h then return end
    pcall(function()
        invisAnimTrack = h:LoadAnimation(invisAnimObj)
        invisAnimTrack.Priority = Enum.AnimationPriority.Action4

        local t = 0
        while invisAnimTrack.Length <= 0 and t < 1 do
            t = t + task.wait(0.05)
        end

        invisAnimTrack:Play()
        t = 0
        while not invisAnimTrack.IsPlaying and t < 1 do
            t = t + task.wait(0.05)
        end

        invisAnimTrack:AdjustSpeed(0)
        invisAnimTrack.TimePosition = 0
    end)
end

local function applyInvisState(state)
    local myChar = player.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if not state then
        if invisNoclipConn then invisNoclipConn:Disconnect() invisNoclipConn = nil end
        if invisCamConn then invisCamConn:Disconnect() invisCamConn = nil end

        if invisAnimTrack then
            pcall(function()
                invisAnimTrack:Stop(0)
                invisAnimTrack:Destroy()
            end)
            invisAnimTrack = nil
        end

        pcall(function()
            if myHum then workspace.CurrentCamera.CameraSubject = myHum end
        end)
    else
        local function noclipStep()
            local c = player.Character
            if not c then return end
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = false
                end
            end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = true end
        end

        if invisNoclipConn then invisNoclipConn:Disconnect() end
        invisNoclipConn = RS.Stepped:Connect(noclipStep)

        if myRoot then
            workspace.CurrentCamera.CameraSubject = myRoot
            if invisCamConn then invisCamConn:Disconnect() end
            invisCamConn = workspace.CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
                if invisOn and myRoot then
                    workspace.CurrentCamera.CameraSubject = myRoot
                end
            end)
        end

        if myHum then
            for _, trk in ipairs(myHum:GetPlayingAnimationTracks()) do
                pcall(function()
                    trk.Priority = Enum.AnimationPriority.Core
                    trk:AdjustSpeed(0)
                    trk:Stop(0)
                end)
            end
            playInvisAnim(myHum)
        end
    end
end

RS.Heartbeat:Connect(function()
    if not invisOn then return end
    local myChar = player.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHum then return end

    if not invisAnimTrack or not invisAnimTrack.IsPlaying then
        playInvisAnim(myHum)
    end

    for _, trk in ipairs(myHum:GetPlayingAnimationTracks()) do
        if trk ~= invisAnimTrack then
            pcall(function()
                trk.Priority = Enum.AnimationPriority.Core
                trk:AdjustSpeed(0)
                trk:Stop(0)
            end)
        end
    end
end)

UtilityTab:CreateToggle({
    Name = "Invisibility",
    CurrentValue = false,
    Callback = function(value)
        invisOn = value
        applyInvisState(value)
    end,
})

player.CharacterAdded:Connect(function()
    task.wait(0.3)
    if invisOn then applyInvisState(true) end
end)
--------------------------------------------------------------------------------
-- PART 4 (SECTION 2): STAMINA, DISRUPTION & FIXED AUTO GENERATOR
--------------------------------------------------------------------------------

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

--// LOOP PLAYERS TP (ITEM VELOCITY DISRUPTION)
UtilityTab:CreateSection("Disruption Mods")

local loopTpActive = false
local loopTpConn = nil

local function runLoopTP(state)
    loopTpActive = state
    if not state then
        if loopTpConn then
            loopTpConn:Disconnect()
            loopTpConn = nil
        end
        return
    end

    task.spawn(function()
        local targetNames = {
            "BloxyCola",
            "Medkit"
        }

        local function isValidItem(obj)
            if obj:IsA("BasePart") and not obj.Anchored then
                for _, name in ipairs(targetNames) do
                    if obj.Name:lower():find(name:lower()) then
                        return true
                    end
                end
            end
            return false
        end

        local itemsToTarget = {}
        for _, obj in pairs(workspace:GetDescendants()) do
            if isValidItem(obj) then
                table.insert(itemsToTarget, obj)
            end
        end

        if #itemsToTarget > 0 and loopTpActive then
            local character = player.Character or player.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            if not hrp then return end

            local activeItems = {}

            for _, item in ipairs(itemsToTarget) do
                if not loopTpActive then break end
                if item and item.Parent and not item.Anchored then
                    hrp.CFrame = item.CFrame * CFrame.new(0, 1.5, 0)
                    task.wait(0.3)
                    table.insert(activeItems, item)
                end
            end

            if loopTpConn then
                loopTpConn:Disconnect()
                loopTpConn = nil
            end

            loopTpConn = RS.Heartbeat:Connect(function()
                if not loopTpActive then
                    if loopTpConn then
                        loopTpConn:Disconnect()
                        loopTpConn = nil
                    end
                    return
                end
                for _, item in ipairs(activeItems) do
                    if item and item.Parent and not item.Anchored then
                        item.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
                        item.AssemblyAngularVelocity = Vector3.new(99999, 99999, 99999)
                    end
                end
            end)
        end
    end)
end

UtilityTab:CreateToggle({
    Name = "Loop Players TP (This may Not Work)",
    CurrentValue = false,
    Callback = function(value)
        runLoopTP(value)
    end,
})

--// MULTI-PUZZLE CONTINUOUS AUTO GENERATOR
UtilityTab:CreateSection("Generator Automation")

local AutoGenEnabled = false
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

-- Solves and pumps the puzzle continuously until complete
local function solveActivePuzzles()
    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local searchScope = GetGameMap()
    if not localRoot or not searchScope then return end

    for _, object in ipairs(searchScope:GetDescendants()) do
        if object:IsA("Model") and object.Name:lower():find("generator") and not isGenFinished(object) then
            local mainPart = object:FindFirstChild("Main") or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
            if mainPart and (mainPart.Position - localRoot.Position).Magnitude <= 8.5 then
                
                -- 1. Trigger interaction prompt if not seated / working
                local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and prompt.Enabled and fireproximityprompt then
                    pcall(fireproximityprompt, prompt)
                end

                -- 2. Fire generator event remotes
                local remotes = object:FindFirstChild("Remotes")
                if remotes then
                    for _, rem in ipairs(remotes:GetChildren()) do
                        if rem:IsA("RemoteEvent") then
                            pcall(function() rem:FireServer() end)
                            pcall(function() rem:FireServer(true) end)
                            pcall(function() rem:FireServer("Progress") end)
                        elseif rem:IsA("RemoteFunction") then
                            pcall(function() rem:InvokeServer() end)
                        end
                    end
                end

                -- 3. Fallback scan for any deep RemoteEvent inside the generator model
                for _, desc in ipairs(object:GetDescendants()) do
                    if desc:IsA("RemoteEvent") and desc.Parent ~= remotes then
                        pcall(function() desc:FireServer() end)
                    end
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

task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoGenEnabled then
            pcall(solveActivePuzzles)
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
--------------------------------------------------------------------------------
-- PART 7: ANTI TAB (ANTI-SLOWNESS, NOLI NPC, JOHN DOE FOOTPRINTS & SPIKES)
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")

-- Environment Dynamic Resolvers
local function getInGameFolder()
    return (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame"))
        or workspace:FindFirstChild("Ingame")
        or workspace
end

local function getKillersFolder()
    local ingame = getInGameFolder()
    return (ingame and ingame:FindFirstChild("Killers"))
        or workspace:FindFirstChild("Killers")
end

local function getSpeedMultipliers()
    local myChar = player.Character
    return myChar and myChar:FindFirstChild("SpeedMultipliers")
end

--------------------------------------------------------------------------------
-- 1. ANTI SLOWNESS
--------------------------------------------------------------------------------
local antiSlownessEnabled = false

local function checkSlownessInstance(valueInst)
    if not antiSlownessEnabled or not valueInst then return end
    if valueInst.Name == "Sprinting" or valueInst.Name:lower() == "emoting" then return end

    if valueInst.Name == "DirectionalMovement" or valueInst.Name == "FixingGenerator" or valueInst.Name:upper() == "ENRAGED" then
        if valueInst.Value < 1 then
            valueInst.Value = 1
        end
        valueInst:GetPropertyChangedSignal("Value"):Connect(function()
            if antiSlownessEnabled and valueInst.Value < 1 then
                valueInst.Value = 1
            end
        end)
    elseif valueInst.Value > 0.03 and valueInst.Value < 1 then
        valueInst:Destroy()
    else
        valueInst:GetPropertyChangedSignal("Value"):Connect(function()
            if antiSlownessEnabled and valueInst.Value > 0.03 and valueInst.Value < 1 then
                valueInst:Destroy()
            end
        end)
    end
end

local function applyAntiSlowness()
    local sm = getSpeedMultipliers()
    if sm then
        for _, child in ipairs(sm:GetChildren()) do
            checkSlownessInstance(child)
        end
    end
end

local function hookSpeedMultipliers(targetChar)
    if not targetChar then return end
    local sm = targetChar:WaitForChild("SpeedMultipliers", 5)
    if sm then
        sm.ChildAdded:Connect(function(child)
            if not child:IsA("NumberValue") or child.Name == "Sprinting" or child.Name:lower() == "emoting" then
                return
            end
            checkSlownessInstance(child)
        end)
        if antiSlownessEnabled then
            applyAntiSlowness()
        end
    end
end

player.CharacterAdded:Connect(hookSpeedMultipliers)
if player.Character then
    task.spawn(function()
        hookSpeedMultipliers(player.Character)
    end)
end

--------------------------------------------------------------------------------
-- 2. DISABLE NOLI NPC
--------------------------------------------------------------------------------
local disableNoliNPC = false

local function handleNoliNPC(state)
    local killers = getKillersFolder()
    local ingame = getInGameFolder()

    if state then
        if killers then
            for _, v in ipairs(killers:GetChildren()) do
                if v.Name:lower() == "noli" and not Players:GetPlayerFromCharacter(v) then
                    v.Parent = Lighting
                    if v:IsA("Model") then
                        v:PivotTo(v:GetPivot() * CFrame.new(0, -100, 0))
                    end
                end
            end
        end

        if workspace:FindFirstChild("Themes") then
            for _, v in ipairs(workspace.Themes:GetChildren()) do
                if v.Name:find("FakeLayer") and v:IsA("Sound") then
                    v:Destroy()
                end
            end
        end
    else
        for _, v in ipairs(Lighting:GetChildren()) do
            if v.Name:lower() == "noli" then
                v.Parent = ingame or workspace
                if v:IsA("Model") then
                    v:PivotTo(v:GetPivot() * CFrame.new(0, 100, 0))
                end
            end
        end
    end
end

local function hookKillersFolder()
    local killers = getKillersFolder()
    if killers then
        killers.ChildAdded:Connect(function(child)
            task.wait(0.5)
            if disableNoliNPC then
                handleNoliNPC(true)
            end
        end)
    end
end

hookKillersFolder()

--------------------------------------------------------------------------------
-- 3. DISABLE JOHN DOE FOOTPRINTS
--------------------------------------------------------------------------------
local disableFootprints = false

local function handleFootprints(state)
    local ingame = getInGameFolder()
    if not ingame then return end

    for _, v in ipairs(ingame:GetChildren()) do
        if v:IsA("Folder") and v.Name:find("Shadows") then
            for _, part in ipairs(v:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanTouch = not state
                end
            end
            if not v:GetAttribute("Checked") then
                v:SetAttribute("Checked", true)
                v.ChildAdded:Connect(function(grandChild)
                    if grandChild:IsA("BasePart") then
                        grandChild.CanTouch = not disableFootprints
                    end
                end)
            end
        end
    end
end

local function hookFootprintsFolder()
    local ingame = getInGameFolder()
    if ingame then
        ingame.ChildAdded:Connect(function(child)
            if child:IsA("Folder") and child.Name:find("Shadows") then
                task.wait()
                for _, part in ipairs(child:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanTouch = not disableFootprints
                    end
                end
                if not child:GetAttribute("Checked") then
                    child:SetAttribute("Checked", true)
                    child.ChildAdded:Connect(function(v)
                        if v:IsA("BasePart") then
                            v.CanTouch = not disableFootprints
                        end
                    end)
                end
            end
        end)
    end
end

hookFootprintsFolder()

--------------------------------------------------------------------------------
-- 4. SMALLER JOHN DOE SPIKE COLLISIONS
--------------------------------------------------------------------------------
local smallerSpikesEnabled = false

local function updateSpikeCollisions(state)
    local ingame = getInGameFolder()
    if not ingame then return end

    for _, v in ipairs(ingame:GetChildren()) do
        if v.Name == "SpikeCollision" and v:IsA("Part") then
            v.Size = state and Vector3.new(11, 3.5, 3.5) or Vector3.new(11, 5, 5)
            v.Shape = state and Enum.PartType.Cylinder or Enum.PartType.Block
        end
    end
end

local function hookSpikeCollisions()
    local ingame = getInGameFolder()
    if ingame then
        ingame.ChildAdded:Connect(function(child)
            if child.Name == "SpikeCollision" and child:IsA("Part") then
                task.delay(3.5, function()
                    if child and child.Parent then
                        child.Size = smallerSpikesEnabled and Vector3.new(11, 3.5, 3.5) or Vector3.new(11, 5, 5)
                        child.Shape = smallerSpikesEnabled and Enum.PartType.Cylinder or Enum.PartType.Block
                    end
                end)
            end
        end)
    end
end

hookSpikeCollisions()

--------------------------------------------------------------------------------
-- ANTI TAB RAYFIELD ELEMENTS
--------------------------------------------------------------------------------

AntiTab:CreateSection("Movement & Debuffs")

AntiTab:CreateToggle({
    Name = "Anti Slowness",
    CurrentValue = false,
    Callback = function(value)
        antiSlownessEnabled = value
        if value then
            applyAntiSlowness()
        end
    end,
})

AntiTab:CreateSection("Killer Countermeasures")

AntiTab:CreateToggle({
    Name = "Disable Noli's NPC",
    CurrentValue = false,
    Callback = function(value)
        disableNoliNPC = value
        handleNoliNPC(value)
    end,
})

AntiTab:CreateToggle({
    Name = "Disable John Doe's Footprints",
    CurrentValue = false,
    Callback = function(value)
        disableFootprints = value
        handleFootprints(value)
    end,
})

AntiTab:CreateToggle({
    Name = "Smaller Spike Collisions",
    CurrentValue = false,
    Callback = function(value)
        smallerSpikesEnabled = value
        updateSpikeCollisions(value)
    end,
})
--------------------------------------------------------------------------------
-- PART 8: AIM TAB (EVENT-DRIVEN INSTANT AIMBOT, ZERO MISS)
--------------------------------------------------------------------------------

local slasherAimbotOn = false
local shedletskyAimbotOn = false

-- Animation ID Lookup Sets (Cleaned Numeric IDs)
local SLASHER_ANIM_IDS = {
    ["114384283102737"] = true, -- Slasher Behead
    ["98906674546879"]  = true, -- Slasher Slash
    ["120537271555083"] = true, -- Slasher Behead (Alt)
}

local SHEDLETSKY_ANIM_IDS = {
    ["106976963660502"] = true, -- Shedletsky Slash
}

local KILLER_CLASSES = {
    ["slasher"]         = true,
    ["jason"]           = true,
    ["c00lkidd"]        = true,
    ["coolkid"]         = true,
    ["1x1x1x1"]         = true,
    ["1x4"]             = true,
    ["noli"]            = true,
    ["swordsmaster"]    = true,
    ["guest666"]        = true,
    ["2011x"]           = true,
    ["johndoe"]         = true,
    ["azure"]           = true,
    ["shedletskyfunny"] = true,
}

local function extractNumericId(rawAnimId)
    if not rawAnimId then return "" end
    return tostring(rawAnimId):match("%d+") or ""
end

local function isPlayerAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0 and plr.Character:IsDescendantOf(workspace)
end

local function isPlayerKiller(plr)
    if not plr or not plr.Character then return false end
    local charType = plr.Character:GetAttribute("Character") 
        or plr.Character:GetAttribute("CharacterType") 
        or plr.Character.Name
    local key = string.lower(tostring(charType))
    if key == "coolkid" then key = "c00lkidd" end
    if key == "1x4" then key = "1x1x1x1" end
    return KILLER_CLASSES[key] == true
end

local function getClosestSurvivor()
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local shortestDist = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isPlayerAlive(p) and not isPlayerKiller(p) then
            local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local dist = (myRoot.Position - tRoot.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = p.Character
                end
            end
        end
    end
    return closest
end

local function getActiveKiller()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isPlayerAlive(p) and isPlayerKiller(p) then
            return p.Character
        end
    end
    return nil
end

-- Active Snap & Track Loop (Locks for 0.45s so the attack connects reliably)
local activeSnapThread = nil

local function lockOntoTargetForDuration(targetChar, duration)
    if not targetChar then return end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head") or targetRoot
    if not myRoot or not targetRoot then return end

    if activeSnapThread then
        task.cancel(activeSnapThread)
        activeSnapThread = nil
    end

    activeSnapThread = task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime < (duration or 0.45) do
            if not targetChar:IsDescendantOf(workspace) or not myChar:IsDescendantOf(workspace) then break end
            local myPos = myRoot.Position
            local targetPos = targetRoot.Position

            -- Instant snap orientation
            myRoot.CFrame = CFrame.lookAt(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))

            -- Direct lock camera center mass
            if camera then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetHead.Position)
            end

            RS.RenderStepped:Wait()
        end
        activeSnapThread = nil
    end)
end

-- Event-driven animation hooking: Triggers instantly on frame 1 of the attack
local function hookHumanoidAnimations(humanoid)
    if not humanoid then return end

    humanoid.AnimationPlayed:Connect(function(track)
        local animObj = track.Animation
        local rawId = animObj and animObj.AnimationId or ""
        local numericId = extractNumericId(rawId)

        if slasherAimbotOn and SLASHER_ANIM_IDS[numericId] then
            local target = getClosestSurvivor()
            if target then
                lockOntoTargetForDuration(target, 0.45)
            end
        elseif shedletskyAimbotOn and SHEDLETSKY_ANIM_IDS[numericId] then
            local target = getActiveKiller()
            if target then
                lockOntoTargetForDuration(target, 0.45)
            end
        end
    end)
end

-- Hook current and respawned character
if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
    hookHumanoidAnimations(player.Character:FindFirstChildOfClass("Humanoid"))
end

player.CharacterAdded:Connect(function(c)
    local hum = c:WaitForChild("Humanoid", 5)
    if hum then
        hookHumanoidAnimations(hum)
    end
end)

-- Background scan fallback in case an animation track starts silently
RS.Heartbeat:Connect(function()
    if not slasherAimbotOn and not shedletskyAimbotOn then return end
    if activeSnapThread then return end -- already tracking

    local myChar = player.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHum or myHum.Health <= 0 then return end

    for _, track in ipairs(myHum:GetPlayingAnimationTracks()) do
        local animObj = track.Animation
        local rawId = animObj and animObj.AnimationId or ""
        local numericId = extractNumericId(rawId)

        if slasherAimbotOn and SLASHER_ANIM_IDS[numericId] and track.TimePosition < 0.3 then
            local target = getClosestSurvivor()
            if target then
                lockOntoTargetForDuration(target, 0.4)
            end
            break
        elseif shedletskyAimbotOn and SHEDLETSKY_ANIM_IDS[numericId] and track.TimePosition < 0.3 then
            local target = getActiveKiller()
            if target then
                lockOntoTargetForDuration(target, 0.4)
            end
            break
        end
    end
end)

--------------------------------------------------------------------------------
-- RAYFIELD AIM TAB INTERFACE
--------------------------------------------------------------------------------

AimTab:CreateSection("Killer Combat")

AimTab:CreateToggle({
    Name = "Slasher Aimbot",
    CurrentValue = false,
    Callback = function(value)
        slasherAimbotOn = value
        if value and shedletskyAimbotOn then
            shedletskyAimbotOn = false
        end
    end,
})

AimTab:CreateSection("Survivor Combat")

AimTab:CreateToggle({
    Name = "Shedletsky Slash Aimbot",
    CurrentValue = false,
    Callback = function(value)
        shedletskyAimbotOn = value
        if value and slasherAimbotOn then
            slasherAimbotOn = false
        end
    end,
})
