--------------------------------------------------------------------------------
-- GAME ID CHECKER
--------------------------------------------------------------------------------
local ALLOWED_PLACE_IDS = {
    [100039707794702] = true,
    [99585784721880]  = true,
    [99055603649009]  = true,
    [70444122688316]  = true,
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

--// ORIGINAL RAYFIELD WINDOW
local Window = Rayfield:CreateWindow({
    Name = "Novalight Beta",
    LoadingTitle = "Novalight Beta",
    LoadingSubtitle = "by Chwaa",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "NovalightBeta"
    }
})

--// TABS (ORIGINAL SYNTAX)
local CombatTab = Window:CreateTab("Combat", 4483362458)
local AutoFarmTab = Window:CreateTab("Auto Farm", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local UtilityTab = Window:CreateTab("Movement & Misc", 4483362458)
local TeleportTab = Window:CreateTab("Teleporter", 4483362458)
local SonicEXEtab = Window:CreateTab("2011X", 4483362458)

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
-- SAFE SPACE SETUP (CENTERED AT NEW MAP COORDS)
--------------------------------------------------------------------------------
local MAP_CENTER = Vector3.new(-1487.63, -2.90, -11347.20)
local SAFE_SPACE_CFRAME = CFrame.new(MAP_CENTER.X, 5000, MAP_CENTER.Z)
local safeSpacePart = workspace:FindFirstChild("SafeSpaceBaseplate")

if not safeSpacePart then
    safeSpacePart = Instance.new("Part")
    safeSpacePart.Name = "SafeSpaceBaseplate"
    safeSpacePart.Size = Vector3.new(200, 5, 200)
    safeSpacePart.CFrame = SAFE_SPACE_CFRAME
    safeSpacePart.Anchored = true
    safeSpacePart.Material = Enum.Material.SmoothPlastic
    safeSpacePart.Color = Color3.fromRGB(40, 40, 45)
    safeSpacePart.Parent = workspace
else
    safeSpacePart.CFrame = SAFE_SPACE_CFRAME
end

local function teleportToSafeSpace()
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if myRoot then
        myRoot.CFrame = SAFE_SPACE_CFRAME * CFrame.new(0, 5, 0)
    end
end

--------------------------------------------------------------------------------
-- ANTI-VOID SYSTEM (CENTERED AT NEW MAP COORDS)
--------------------------------------------------------------------------------
local ANTI_VOID_HEIGHT = -150
local antiVoidPart = workspace:FindFirstChild("AntiVoidPlate")

if not antiVoidPart then
    antiVoidPart = Instance.new("Part")
    antiVoidPart.Name = "AntiVoidPlate"
    antiVoidPart.Size = Vector3.new(10000, 10, 10000)
    antiVoidPart.CFrame = CFrame.new(MAP_CENTER.X, ANTI_VOID_HEIGHT, MAP_CENTER.Z)
    antiVoidPart.Anchored = true
    antiVoidPart.CanCollide = true
    antiVoidPart.Transparency = 0.6
    antiVoidPart.Material = Enum.Material.ForceField
    antiVoidPart.Color = Color3.fromRGB(255, 0, 80)
    antiVoidPart.Parent = workspace
else
    antiVoidPart.CFrame = CFrame.new(MAP_CENTER.X, ANTI_VOID_HEIGHT, MAP_CENTER.Z)
end

antiVoidPart.Touched:Connect(function(hit)
    if char and hit:IsDescendantOf(char) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(MAP_CENTER.X, 50, MAP_CENTER.Z)
        end
    end
end)

--------------------------------------------------------------------------------
-- CHARACTER ABILITY CONFIGURATIONS (SHEDLETSKY, NOLI & C00LKIDD)
--------------------------------------------------------------------------------
local charRemotesFolder = ReplicatedStorage:WaitForChild("CharacterRemotes", 5)
local shedFolder = charRemotesFolder and charRemotesFolder:FindFirstChild("Shedletsky")
local noliFolder = charRemotesFolder and charRemotesFolder:FindFirstChild("Noli")
local coolkidFolder = charRemotesFolder and (charRemotesFolder:FindFirstChild("Coolkid") or charRemotesFolder:FindFirstChild("c00lkidd"))

local ShedletskyAbilities = {
    ["Slash"] = {
        ["Cooldown"] = 15,
        ["LastUsed"] = 0,
        ["Remote"] = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote")
    }
}

local NoliAbilities = {
    ["AltAbility2"] = {
        ["Cooldown"] = 0,
        ["LastUsed"] = 0,
        ["Remote"] = noliFolder and noliFolder:FindFirstChild("NoliNova")
    }
}

local CoolkidAbilities = {
    ["Walkspeed"] = {
        ["Cooldown"] = 1,
        ["LastUsed"] = 0,
        ["Remote"] = coolkidFolder and coolkidFolder:FindFirstChild("Walkspeed")
    }
}

local SHEDLETSKY_AUTO_ABILITIES = { "Slash" }
local NOLI_AUTO_ABILITIES = { "AltAbility2" }
local COOLKID_AUTO_ABILITIES = { "Walkspeed" }

local autoFarmLowHpOn = false
local autoFarmAllOn = false
local lockInFrontOn = false
local stickToPersonOn = false
local targetHealthThreshold = 20
local hitDistanceOffset = 3
local MAX_ABILITY_DISTANCE = 15

local currentLockedTarget = nil

local LowHpToggle
local AllPlayersToggle

--------------------------------------------------------------------------------
-- CHARACTER STATE CHECKS
--------------------------------------------------------------------------------
local function getCurrentCharacterType()
    if not char then return nil end
    return char:GetAttribute("Character")
end

local function canUseCharacter()
    if not char or not hum or hum.Health <= 0 then return false end
    local cType = getCurrentCharacterType()

    if cType == "Noli" or cType == "Coolkid" or cType == "c00lkidd" or cType == "2011X" then
        return char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    elseif cType == "Shedletsky" then
        return char:GetAttribute("CanRun") ~= false and char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    end
    return true
end
--------------------------------------------------------------------------------
-- PART 2: ACTION & AUTO-FARM SYSTEM (IDLE SAFE SPACE TELEPORT)
--------------------------------------------------------------------------------

local MAP_CENTER = Vector3.new(-1487.63, -2.90, -11347.20)
local SAFE_SPACE_CFRAME = CFrame.new(MAP_CENTER.X, 5000, MAP_CENTER.Z)

local safeSpacePart = workspace:FindFirstChild("SafeSpaceBaseplate")
if not safeSpacePart then
    safeSpacePart = Instance.new("Part")
    safeSpacePart.Name = "SafeSpaceBaseplate"
    safeSpacePart.Size = Vector3.new(200, 5, 200)
    safeSpacePart.CFrame = SAFE_SPACE_CFRAME
    safeSpacePart.Anchored = true
    safeSpacePart.Material = Enum.Material.SmoothPlastic
    safeSpacePart.Color = Color3.fromRGB(40, 40, 45)
    safeSpacePart.Parent = workspace
else
    safeSpacePart.CFrame = SAFE_SPACE_CFRAME
end

local function teleportToSafeSpace()
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if myRoot then
        myRoot.CFrame = SAFE_SPACE_CFRAME * CFrame.new(0, 5, 0)
    end
end

-- Remote Cache References (CharacterRemotes)
local charRemotes = ReplicatedStorage:WaitForChild("CharacterRemotes", 5)

local shedletskyRemote = charRemotes and charRemotes:FindFirstChild("Shedletsky") and charRemotes.Shedletsky:FindFirstChild("ShedletskyAttackRemote")
local noliNovaRemote = charRemotes and charRemotes:FindFirstChild("Noli") and charRemotes.Noli:FindFirstChild("NoliNova")
local coolkidRemote = charRemotes and (charRemotes:FindFirstChild("Coolkid") or charRemotes:FindFirstChild("c00lkidd")) and (charRemotes:FindFirstChild("Coolkid") or charRemotes:FindFirstChild("c00lkidd")):FindFirstChild("Walkspeed")

local function castCharacterAction(actionName, targetPosition)
    if not canUseCharacter() then return end
    local cType = getCurrentCharacterType()

    -- 1. Shedletsky Slash
    if cType and cType:lower():find("shedletsky") and actionName == "Slash" then
        if not shedletskyRemote then
            local remotesFolder = ReplicatedStorage:FindFirstChild("CharacterRemotes")
            local shedFolder = remotesFolder and remotesFolder:FindFirstChild("Shedletsky")
            shedletskyRemote = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote")
        end

        if shedletskyRemote then
            local data = ShedletskyAbilities and ShedletskyAbilities["Slash"]
            local now = os.clock()
            
            if (not data) or (now - data.LastUsed >= data.Cooldown) then
                if data then data.LastUsed = now end

                if targetPosition and char and char:FindFirstChild("HumanoidRootPart") then
                    local myRoot = char.HumanoidRootPart
                    myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPosition.X, myRoot.Position.Y, targetPosition.Z))
                end

                task.spawn(function()
                    pcall(function()
                        if shedletskyRemote:IsA("RemoteFunction") then
                            shedletskyRemote:InvokeServer()
                        elseif shedletskyRemote:IsA("RemoteEvent") then
                            shedletskyRemote:FireServer()
                        end
                    end)
                end)
            end
        end
        return
    end

    -- 2. Noli Nova
    if cType and cType == "Noli" and actionName == "AltAbility2" then
        if not noliNovaRemote then
            local remotesFolder = ReplicatedStorage:FindFirstChild("CharacterRemotes")
            local nFolder = remotesFolder and remotesFolder:FindFirstChild("Noli")
            noliNovaRemote = nFolder and nFolder:FindFirstChild("NoliNova")
        end

        if noliNovaRemote then
            local data = NoliAbilities and NoliAbilities["AltAbility2"]
            local now = os.clock()

            if (not data) or (now - data.LastUsed >= data.Cooldown) then
                if data then data.LastUsed = now end

                task.spawn(function()
                    pcall(function()
                        noliNovaRemote:FireServer()
                    end)
                end)
            end
        end
        return
    end

    -- 3. c00lkidd Walkspeed
    if cType and (cType:lower():find("coolkid") or cType:lower():find("c00lkidd")) and actionName == "Walkspeed" then
        if not coolkidRemote then
            local remotesFolder = ReplicatedStorage:FindFirstChild("CharacterRemotes")
            local ckFolder = remotesFolder and (remotesFolder:FindFirstChild("Coolkid") or remotesFolder:FindFirstChild("c00lkidd"))
            coolkidRemote = ckFolder and ckFolder:FindFirstChild("Walkspeed")
        end

        if coolkidRemote then
            local data = CoolkidAbilities and CoolkidAbilities["Walkspeed"]
            local now = os.clock()

            if (not data) or (now - data.LastUsed >= data.Cooldown) then
                if data then data.LastUsed = now end

                task.spawn(function()
                    pcall(function()
                        coolkidRemote:FireServer()
                    end)
                end)
            end
        end
        return
    end
end

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
-- POSITIONING & ATTACK LOOPS WITH IDLE SAFE SPACE TELEPORT
--------------------------------------------------------------------------------

local isCurrentlyWaitingInSafeSpace = false

RS.Stepped:Connect(function()
    if not autoFarmLowHpOn and not autoFarmAllOn then 
        isCurrentlyWaitingInSafeSpace = false
        return 
    end
    if not char or not hum or hum.Health <= 0 then return end

    local activeTarget = autoFarmLowHpOn and getLowHpTarget(targetHealthThreshold) or getAnyTarget()
    local maxHpConstraint = autoFarmLowHpOn and targetHealthThreshold or nil

    if activeTarget and isTargetAliveAndValid(activeTarget, maxHpConstraint) then
        isCurrentlyWaitingInSafeSpace = false
        positionAtTarget(activeTarget)
    else
        currentLockedTarget = nil
        
        if autoFarmLowHpOn and not isCurrentlyWaitingInSafeSpace then
            isCurrentlyWaitingInSafeSpace = true
            teleportToSafeSpace()
        end
    end
end)

RS.Heartbeat:Connect(function()
    local cType = getCurrentCharacterType()
    if cType and cType:lower():find("shedletsky") then
        char:SetAttribute("CanRun", true)
        char:SetAttribute("Slowed", false)
        if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
    end

    if not autoFarmLowHpOn and not autoFarmAllOn then return end

    if hum and hum.Health <= 30 then
        if autoFarmLowHpOn and LowHpToggle then LowHpToggle:Set(false) end
        if autoFarmAllOn and AllPlayersToggle then AllPlayersToggle:Set(false) end
        autoFarmLowHpOn = false
        autoFarmAllOn = false
        currentLockedTarget = nil
        isCurrentlyWaitingInSafeSpace = false
        teleportToSafeSpace()
        return
    end

    local maxHpConstraint = autoFarmLowHpOn and targetHealthThreshold or nil
    local targetP = currentLockedTarget

    -- Executes ability remotes when auto-farming an alive, valid player
    if targetP and isTargetAliveAndValid(targetP, maxHpConstraint) then
        local autoList = (cType and cType:lower():find("shedletsky") and SHEDLETSKY_AUTO_ABILITIES) 
            or (cType == "Noli" and NOLI_AUTO_ABILITIES) 
            or (cType and (cType:lower():find("coolkid") or cType:lower():find("c00lkidd")) and COOLKID_AUTO_ABILITIES)
            or {}

        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local tRoot = targetP.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and (tRoot.Position - myRoot.Position).Magnitude <= MAX_ABILITY_DISTANCE then
                for _, abilityName in ipairs(autoList) do
                    castCharacterAction(abilityName, tRoot.Position)
                end
            end
        end
    else
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
            teleportToSafeSpace()
            return
        end
        autoFarmLowHpOn = value
        isCurrentlyWaitingInSafeSpace = false
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
            teleportToSafeSpace()
            return
        end
        autoFarmAllOn = value
        isCurrentlyWaitingInSafeSpace = false
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
            isCurrentlyWaitingInSafeSpace = false
        end
    end,
})

AutoFarmTab:CreateSection("Emergency Safety")

AutoFarmTab:CreateButton({
    Name = "Teleport to Safe Space",
    Callback = function()
        teleportToSafeSpace()
    end,
})
--------------------------------------------------------------------------------
-- PART 3: ROLE-BASED DYNAMIC ESP (SURVIVORS & KILLERS)
--------------------------------------------------------------------------------

local espOn = false
local activeESP = {}

-- Character Role Sets
local SURVIVOR_CLASSES = {
    ["guest1337"]     = true,
    ["shedletsky"]    = true,
    ["dusekkar"]      = true,
    ["martialartist"] = true,
    ["chance"]        = true,
    ["twotime"]       = true,
    ["007n7"]         = true,
    ["elliot"]        = true,
    ["veeronica"]     = true,
    ["janedoe"]       = true,
    ["messi"]         = true,
    ["noob"]          = true,
    ["taph"]          = true,
    ["builderman"]    = true,
    ["torchwood"]     = true
}

local KILLER_CLASSES = {
    ["slasher"]       = true,
    ["jason"]         = true,
    ["coolkid"]       = true,
    ["c00lkidd"]      = true,
    ["coolkidrework"] = true,
    ["1x4"]           = true,
    ["1x1x1x1"]       = true,
    ["noli"]          = true,
    ["swordsmaster"]  = true,
    ["guest666"]      = true,
    ["2011x"]         = true,
    ["johndoe"]       = true,
    ["azure"]         = true,
    ["doombringer"]   = true
}

-- Determine Role Color, Role Name, and Character Name
local function getCharacterInfo(targetChar)
    if not targetChar then 
        return Color3.fromRGB(0, 150, 255), "Survivor", "Unknown" 
    end

    local rawCharType = targetChar:GetAttribute("Character") or targetChar:GetAttribute("CharacterType")
    
    if not rawCharType then
        for _, child in ipairs(targetChar:GetChildren()) do
            if child:IsA("StringValue") and (SURVIVOR_CLASSES[string.lower(child.Value)] or KILLER_CLASSES[string.lower(child.Value)]) then
                rawCharType = child.Value
                break
            end
        end
    end

    rawCharType = rawCharType or targetChar.Name
    local charType = string.lower(tostring(rawCharType))
    local charDisplay = tostring(rawCharType)

    if KILLER_CLASSES[charType] then
        return Color3.fromRGB(255, 35, 35), "Killer", charDisplay
    elseif SURVIVOR_CLASSES[charType] then
        return Color3.fromRGB(0, 150, 255), "Survivor", charDisplay
    end

    return Color3.fromRGB(0, 150, 255), "Survivor", charDisplay
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

        local roleColor, roleName, charName = getCharacterInfo(targetChar)

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = roleColor
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = targetChar
        highlight.Parent = targetChar

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Billboard"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 250, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Adornee = head
        billboard.Parent = targetChar

        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = roleColor
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 14

        local conn = RS.RenderStepped:Connect(function()
            if not espOn or not targetChar:IsDescendantOf(workspace) or targetHum.Health <= 0 then
                highlight.Enabled = false
                billboard.Enabled = false
            else
                local updatedColor, updatedRole, updatedCharName = getCharacterInfo(targetChar)
                highlight.FillColor = updatedColor
                label.TextColor3 = updatedColor

                highlight.Enabled = true
                billboard.Enabled = true
                label.Text = string.format("%s [%s - %s] | %d HP", plr.Name, updatedCharName, updatedRole, math.floor(targetHum.Health))
            end
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
-- ESP TAB ELEMENTS (ORIGINAL RAYFIELD)
--------------------------------------------------------------------------------
ESPTab:CreateSection("ESP Visuals")

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

Players.PlayerAdded:Connect(function(p)
    if espOn then applyESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)
--------------------------------------------------------------------------------
-- PART 4: COMBAT TAB & UTILITY TAB (INFINITE STAMINA INTEGRATED)
--------------------------------------------------------------------------------

local CoreGui = game:GetService("CoreGui")

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
    Range = {1, 250},
    Increment = 0.5,
    CurrentValue = 9.6,
    Callback = function(value)
        lungeRange = tonumber(value) or 9.6
    end,
})

--------------------------------------------------------------------------------
-- KILLER CAMLOCK SYSTEM (ALL-PLAYER TARGETING & DYNAMIC GUI)
--------------------------------------------------------------------------------
CombatTab:CreateSection("Killer Camlock")

local CAMERA_OFFSET = Vector3.new(0, 4.5, 10)
local TURN_SMOOTHNESS = 0.35
local MAX_TARGET_DISTANCE = 75

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
}

local isLocked = false
local currentLockedTarget = nil

-- GUI Instance References
local GUI_NAME = "KillerCamlockUI"
local oldGui = CoreGui:FindFirstChild(GUI_NAME) or (player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild(GUI_NAME))
if oldGui then oldGui:Destroy() end

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

local function getCharacterKey(characterModel)
    if not characterModel then return "" end
    local charType = characterModel:GetAttribute("Character")
        or characterModel:GetAttribute("CharacterType")
        or characterModel:GetAttribute("Role")
        or characterModel.Name
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
    if currentLockedTarget then
        if isTargetAliveAndValid(currentLockedTarget) then
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
    end

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

Players.PlayerRemoving:Connect(function(leavingPlayer)
    if currentLockedTarget == leavingPlayer then
        currentLockedTarget = nil
    end
end)

local function disableLock()
    isLocked = false
    currentLockedTarget = nil
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
            currentLockedTarget = nil
            return
        end

        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

        if not myRoot or not myHum or myHum.Health <= 0 then
            return
        end

        local targetChar = getLockedOrClosestTarget()

        if not targetChar then
            toggleButton.Text = "No players nearby"
            return
        end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")

        if not targetRoot or not targetHum or targetHum.Health <= 0 then
            currentLockedTarget = nil
            toggleButton.Text = "No players nearby"
            return
        end

        toggleButton.Text = "Aimbot : On"

        local myPos = myRoot.Position
        local targetPos = targetRoot.Position
        local targetAimPos = targetPos + Vector3.new(0, 1.5, 0)

        local horizontalDiff = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
        if horizontalDiff.Magnitude < 0.1 then
            return
        end

        local charLookTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
        myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myPos, charLookTarget), TURN_SMOOTHNESS)

        local flatDirection = horizontalDiff.Unit
        local finalCamPos = myPos - (flatDirection * CAMERA_OFFSET.Z) + Vector3.new(0, CAMERA_OFFSET.Y, 0)
        camera.CFrame = CFrame.lookAt(finalCamPos, targetAimPos)
    end)
end

toggleButton.MouseButton1Click:Connect(function()
    if isLocked then
        disableLock()
    else
        enableLock()
    end
end)

CombatTab:CreateToggle({
    Name = "Killer Camlock",
    CurrentValue = false,
    Callback = function(value)
        if value then
            screenGui.Enabled = true
            enableLock()
        else
            disableLock()
            screenGui.Enabled = false
        end
    end,
})

--------------------------------------------------------------------------------
-- UTILITY TAB (MOVEMENT & MISC)
--------------------------------------------------------------------------------
UtilityTab:CreateSection("Movement Mods")

-- Infinite Stamina Engine
local infiniteStaminaOn = false
local staminaConnections = {}
local staminaCharAddedConn = nil

local function disconnectStamina()
    for _, conn in ipairs(staminaConnections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    table.clear(staminaConnections)
end

local function updateStaminaVisuals()
    local character = player.Character
    if not character then return end

    character:SetAttribute("StaminaDisabled", true)

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local coreHud = playerGui and playerGui:FindFirstChild("CoreHud")
    local playerInfo = coreHud and coreHud:FindFirstChild("PlayerInfo")
    local bars = playerInfo and playerInfo:FindFirstChild("Bars")
    local stamina = bars and bars:FindFirstChild("Stamina")

    if not stamina then return end

    local amount = stamina:FindFirstChild("Amount")
    if amount and amount:IsA("TextLabel") then
        amount.Text = "100/100"
    end

    local bar = stamina:FindFirstChild("Bar")
    local clipping = bar and bar:FindFirstChild("Clipping")

    if clipping then
        clipping.Size = UDim2.fromScale(1, 1)

        local top = clipping:FindFirstChild("Top")
        if top then
            top.Size = UDim2.fromScale(1, 1)
        end
    end
end

local function bindStaminaCharacter(character)
    disconnectStamina()
    if not infiniteStaminaOn or not character then return end

    character:SetAttribute("StaminaDisabled", true)

    table.insert(staminaConnections, character.AttributeChanged:Connect(function(attribute)
        if infiniteStaminaOn and attribute == "StaminaDisabled" and character:GetAttribute("StaminaDisabled") ~= true then
            character:SetAttribute("StaminaDisabled", true)
        end
    end))

    task.spawn(function()
        while infiniteStaminaOn and character.Parent and player.Character == character do
            updateStaminaVisuals()
            task.wait(0.1)
        end
    end)
end

local function enableInfiniteStamina()
    if player.Character then
        bindStaminaCharacter(player.Character)
    end
    if not staminaCharAddedConn then
        staminaCharAddedConn = player.CharacterAdded:Connect(function(newChar)
            if infiniteStaminaOn then
                bindStaminaCharacter(newChar)
            end
        end)
    end
end

local function disableInfiniteStamina()
    disconnectStamina()
    if staminaCharAddedConn then
        staminaCharAddedConn:Disconnect()
        staminaCharAddedConn = nil
    end
    local character = player.Character
    if character then
        character:SetAttribute("StaminaDisabled", nil)
    end
end

UtilityTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(value)
        infiniteStaminaOn = value
        if value then
            enableInfiniteStamina()
        else
            disableInfiniteStamina()
        end
    end,
})

-- TpWalk
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

-- Safe Platform TP
local savedPos = Vector3.new(-1119.03, 894.94, -85.90)
local platform

UtilityTab:CreateButton({
    Name = "Save Place (Platform TP)",
    Callback = function()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not platform or not platform.Parent then
            platform = Instance.new("Part")
            platform.Size = Vector3.new(60, 5, 60)
            platform.Position = savedPos
            platform.Anchored = true
            platform.Color = Color3.fromRGB(120, 120, 120)
            platform.Material = Enum.Material.SmoothPlastic
            platform.Name = "SafePlatform"
            platform.Parent = workspace
        end
        hrp.CFrame = CFrame.new(savedPos + Vector3.new(0, 6, 0))
    end,
})
--------------------------------------------------------------------------------
-- PART 5: PROTECTION & TELEPORTER (REUSABLE AUTO-PROTECTION PINNING)
--------------------------------------------------------------------------------

local lowHealthProtectionOn = false
local healthThreshold = 40
local protectionPlatform = nil
local savedPos = Vector3.new(-1119.03, 894.94, -85.90)
local isCurrentlyProtected = false

UtilityTab:CreateSection("Safety & Protection")

UtilityTab:CreateToggle({
    Name = "Low Health Auto-Teleport",
    CurrentValue = false,
    Callback = function(value)
        lowHealthProtectionOn = value
        if not value then
            isCurrentlyProtected = false
        end
    end,
})

UtilityTab:CreateSlider({
    Name = "Health Threshold",
    Range = {10, 80},
    Increment = 5,
    CurrentValue = 40,
    Callback = function(value)
        healthThreshold = value
    end,
})

-- Reusable Auto-Protection Loop with Return-to-Platform Enforcer
task.spawn(function()
    while true do
        task.wait(0.2)
        if lowHealthProtectionOn and char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            
            if humanoid and hrp and humanoid.Health > 0 then
                if humanoid.Health <= healthThreshold then
                    -- Ensure platform exists
                    if not protectionPlatform or not protectionPlatform.Parent then
                        protectionPlatform = Instance.new("Part", workspace)
                        protectionPlatform.Size = Vector3.new(60, 5, 60)
                        protectionPlatform.Position = savedPos
                        protectionPlatform.Anchored = true
                        protectionPlatform.Color = Color3.fromRGB(0, 200, 100)
                        protectionPlatform.Material = Enum.Material.SmoothPlastic
                        protectionPlatform.Name = "AutoProtectionBaseplate"
                    end

                    local targetPlatformPos = savedPos + Vector3.new(0, 6, 0)
                    local dist = (hrp.Position - targetPlatformPos).Magnitude
                    
                    -- Initial trigger or return if fallen off / teleported away
                    if not isCurrentlyProtected or dist > 25 then
                        hrp.CFrame = CFrame.new(targetPlatformPos)
                        isCurrentlyProtected = true
                    end
                else
                    -- Reset condition: if health recovers above threshold, stop pinning to platform
                    if isCurrentlyProtected then
                        isCurrentlyProtected = false
                    end
                end
            end
        else
            isCurrentlyProtected = false
        end
    end
end)

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
-- PART 6: 2011X (SONIC.EXE) AUTO FARM (NO COOLDOWN CHECKS / DUAL ABILITY CAST)
--------------------------------------------------------------------------------

local sonicAutoLowHp = false
local sonicAutoAll = false
local stickToTargetOn = true
local sonicThreshold = 20
local sonicHitOffset = 5.5

local currentHardLockedTarget = nil
local SonicLowHpToggle, SonicAllToggle
local SonicLowHealthToggle

-- Low Health Safety & Platform Pinning State
local sonicLowHealthProtectionOn = false
local sonicHealthThreshold = 30
local sonicProtectionPlatform = nil
local savedPos = Vector3.new(-1119.03, 894.94, -85.90)
local isSonicProtected = false

--------------------------------------------------------------------------------
-- 2011X DIRECT REMOTE FIRING (UNRESTRICTED DUAL CAST)
--------------------------------------------------------------------------------
local function findSonicRemote(name)
    local charRemotes = ReplicatedStorage:FindFirstChild("CharacterRemotes")
    if charRemotes then
        local sonicFolder = charRemotes:FindFirstChild("2011X") or charRemotes:FindFirstChild("Sonic")
        if sonicFolder then
            local obj = sonicFolder:FindFirstChild(name)
            if obj then return obj end
        end
    end
    return ReplicatedStorage:FindFirstChild(name, true)
end

local attackRemote = findSonicRemote("Attack")
local godspeedRemote = findSonicRemote("Godspeed")

local function fireAttack()
    if not attackRemote then attackRemote = findSonicRemote("Attack") end
    if attackRemote then
        pcall(function()
            attackRemote:FireServer()
        end)
    end
end

local function fireGodspeed()
    if not godspeedRemote then godspeedRemote = findSonicRemote("Godspeed") end
    if godspeedRemote then
        pcall(function()
            godspeedRemote:FireServer()
        end)
    end
end

--------------------------------------------------------------------------------
-- TARGET DETECTION (ALL PLAYERS - NO WHITELIST)
--------------------------------------------------------------------------------
local function isTargetValid(targetPlayer, lowHpOnly)
    if not targetPlayer or not targetPlayer.Parent or not targetPlayer.Character or targetPlayer == player then 
        return false 
    end

    local targetChar = targetPlayer.Character
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    local hum = targetChar:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 or not targetChar:IsDescendantOf(workspace) then
        return false
    end

    if lowHpOnly and hum.Health > sonicThreshold then
        return false
    end

    return true
end

local function getClosestValidPlayer(lowHpOnly)
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closestPlayer = nil
    local shortestDist = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isTargetValid(p, lowHpOnly) then
            local tChar = p.Character
            local tHrp = tChar:FindFirstChild("HumanoidRootPart")
            local dist = (tHrp.Position - myRoot.Position).Magnitude

            if dist < shortestDist then
                shortestDist = dist
                closestPlayer = p
            end
        end
    end

    return closestPlayer
end

--------------------------------------------------------------------------------
-- REUSABLE LOW HEALTH PROTECTION LOOP
--------------------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.2)
        if sonicLowHealthProtectionOn then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local hrp = character:FindFirstChild("HumanoidRootPart")

                if humanoid and hrp and humanoid.Health > 0 then
                    if humanoid.Health <= sonicHealthThreshold then
                        if sonicAutoLowHp then
                            sonicAutoLowHp = false
                            if SonicLowHpToggle then SonicLowHpToggle:Set(false) end
                        end
                        if sonicAutoAll then
                            sonicAutoAll = false
                            if SonicAllToggle then SonicAllToggle:Set(false) end
                        end
                        currentHardLockedTarget = nil

                        if not sonicProtectionPlatform or not sonicProtectionPlatform.Parent then
                            sonicProtectionPlatform = Instance.new("Part", workspace)
                            sonicProtectionPlatform.Size = Vector3.new(60, 5, 60)
                            sonicProtectionPlatform.Position = savedPos
                            sonicProtectionPlatform.Anchored = true
                            sonicProtectionPlatform.Color = Color3.fromRGB(0, 200, 100)
                            sonicProtectionPlatform.Material = Enum.Material.SmoothPlastic
                            sonicProtectionPlatform.Name = "SonicProtectionBaseplate"
                        end

                        local targetPlatformPos = savedPos + Vector3.new(0, 6, 0)
                        local dist = (hrp.Position - targetPlatformPos).Magnitude

                        if not isSonicProtected or dist > 25 then
                            hrp.CFrame = CFrame.new(targetPlatformPos)
                            isSonicProtected = true
                        end
                    else
                        if isSonicProtected then
                            isSonicProtected = false
                        end
                    end
                end
            end
        else
            isSonicProtected = false
        end
    end
end)

--------------------------------------------------------------------------------
-- MAIN AUTO FARM LOOP (SIMULTANEOUS DUAL ABILITY CAST)
--------------------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.03)

        if sonicAutoLowHp or sonicAutoAll then
            local lowHpOnly = sonicAutoLowHp and not sonicAutoAll
            local targetPlayer = nil

            if stickToTargetOn then
                if currentHardLockedTarget and isTargetValid(currentHardLockedTarget, lowHpOnly) then
                    targetPlayer = currentHardLockedTarget
                else
                    currentHardLockedTarget = getClosestValidPlayer(lowHpOnly)
                    targetPlayer = currentHardLockedTarget
                end
            else
                currentHardLockedTarget = nil
                targetPlayer = getClosestValidPlayer(lowHpOnly)
            end

            if targetPlayer and targetPlayer.Character then
                local targetChar = targetPlayer.Character
                local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

                if targetHrp and targetHum and targetHum.Health > 0 and myHrp then
                    for _, part in ipairs(myChar:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end

                    local lookAtPos = Vector3.new(targetHrp.Position.X, myHrp.Position.Y, targetHrp.Position.Z)
                    local offsetPos = targetHrp.CFrame * CFrame.new(0, 0, -sonicHitOffset)
                    myHrp.CFrame = CFrame.lookAt(offsetPos.Position, lookAtPos)

                    -- Fire both abilities directly and simultaneously
                    task.spawn(fireAttack)
                    task.spawn(fireGodspeed)
                end
            end
        else
            currentHardLockedTarget = nil
        end
    end
end)

--------------------------------------------------------------------------------
-- TAB UI ELEMENTS
--------------------------------------------------------------------------------
SonicEXEtab:CreateSection("Standalone Actions")

SonicEXEtab:CreateButton({
    Name = "Attack (M1)",
    Callback = function()
        fireAttack()
    end,
})

SonicEXEtab:CreateButton({
    Name = "Godspeed",
    Callback = function()
        fireGodspeed()
    end,
})

SonicEXEtab:CreateSection("2011X Safety & Protection")

SonicLowHealthToggle = SonicEXEtab:CreateToggle({
    Name = "Low Health Auto-Teleport",
    CurrentValue = false,
    Callback = function(value)
        sonicLowHealthProtectionOn = value
        if not value then
            isSonicProtected = false
        end
    end,
})

SonicEXEtab:CreateSlider({
    Name = "Health Threshold",
    Range = {10, 50},
    Increment = 5,
    CurrentValue = 30,
    Callback = function(value)
        sonicHealthThreshold = value
    end,
})

SonicEXEtab:CreateSection("2011X Auto Farm (All Players)")

SonicLowHpToggle = SonicEXEtab:CreateToggle({
    Name = "Auto Farm Low HP Players",
    CurrentValue = false,
    Callback = function(value)
        sonicAutoLowHp = value
        currentHardLockedTarget = nil
        if value and SonicAllToggle then SonicAllToggle:Set(false) end
    end,
})

SonicAllToggle = SonicEXEtab:CreateToggle({
    Name = "Auto Farm All Players",
    CurrentValue = false,
    Callback = function(value)
        sonicAutoAll = value
        currentHardLockedTarget = nil
        if value and SonicLowHpToggle then SonicLowHpToggle:Set(false) end
    end,
})

SonicEXEtab:CreateToggle({
    Name = "Lock to Target",
    CurrentValue = true,
    Callback = function(value)
        stickToTargetOn = value
        currentHardLockedTarget = nil
    end,
})

SonicEXEtab:CreateSection("Targeting Parameters")

SonicEXEtab:CreateInput({
    Name = "Low HP Threshold",
    PlaceholderText = "20",
    Callback = function(text)
        local v = tonumber(text)
        if v then sonicThreshold = v end
    end,
})

SonicEXEtab:CreateInput({
    Name = "Hit Distance Offset",
    PlaceholderText = "5.5",
    Callback = function(text)
        local v = tonumber(text)
        if v then sonicHitOffset = v end
    end,
})
