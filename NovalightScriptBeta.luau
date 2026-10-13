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
local GuestTab = Window:CreateTab("Guest1337", 4483362458)

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
-- SAFE SPACE SETUP
--------------------------------------------------------------------------------
local SAFE_SPACE_CFRAME = CFrame.new(0, 5000, 0)
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
end

local function teleportToSafeSpace()
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if myRoot then
        myRoot.CFrame = SAFE_SPACE_CFRAME * CFrame.new(0, 5, 0)
    end
end

--------------------------------------------------------------------------------
-- ANTI-VOID SYSTEM
--------------------------------------------------------------------------------
local ANTI_VOID_HEIGHT = -150
local antiVoidPart = workspace:FindFirstChild("AntiVoidPlate")

if not antiVoidPart then
    antiVoidPart = Instance.new("Part")
    antiVoidPart.Name = "AntiVoidPlate"
    antiVoidPart.Size = Vector3.new(10000, 10, 10000)
    antiVoidPart.CFrame = CFrame.new(0, ANTI_VOID_HEIGHT, 0)
    antiVoidPart.Anchored = true
    antiVoidPart.CanCollide = true
    antiVoidPart.Transparency = 0.6
    antiVoidPart.Material = Enum.Material.ForceField
    antiVoidPart.Color = Color3.fromRGB(255, 0, 80)
    antiVoidPart.Parent = workspace
end

antiVoidPart.Touched:Connect(function(hit)
    if char and hit:IsDescendantOf(char) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(0, 50, 0)
        end
    end
end)

--------------------------------------------------------------------------------
-- CHARACTER ABILITY CONFIGURATIONS (JASON, SHEDLETSKY & NOLI)
--------------------------------------------------------------------------------
local charAbilitiesFolder = ReplicatedStorage:WaitForChild("CharacterAbilities", 5)
local jasonFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Jason")
local shedFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Shedletsky")
local noliFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Noli")

local JasonAbilities = {
    ["MainAbility"] = {
        ["Cooldown"] = 1.9,
        ["LastUsed"] = 0,
        ["Remote"] = jasonFolder and jasonFolder:FindFirstChild("JasonAttackRemote")
    },
    ["AltAbility1"] = {
        ["Cooldown"] = 15,
        ["LastUsed"] = 0,
        ["Remote"] = jasonFolder and jasonFolder:FindFirstChild("Behead")
    },
    ["AltAbility2"] = {
        ["Cooldown"] = 25,
        ["LastUsed"] = 0,
        ["Remote"] = jasonFolder and jasonFolder:FindFirstChild("GashingWound")
    },
    ["AltAbility3"] = {
        ["Cooldown"] = 20,
        ["LastUsed"] = 0,
        ["Remote"] = jasonFolder and jasonFolder:FindFirstChild("Enraged")
    }
}

local ShedletskyAbilities = {
    ["Slash"] = {
        ["Cooldown"] = 15,
        ["LastUsed"] = 0,
        ["Remote"] = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote")
    },
    ["Fried Chicken"] = {
        ["Cooldown"] = 15,
        ["LastUsed"] = 0,
        ["Remote"] = shedFolder and shedFolder:FindFirstChild("ShedletskyChickenRemote")
    }
}

local NoliAbilities = {
    ["MainAbility"] = { -- Slash
        ["Cooldown"] = 1.8,
        ["LastUsed"] = 0,
        ["Remote"] = noliFolder and noliFolder:FindFirstChild("NoliAttackRemote")
    },
    ["AltAbility2"] = { -- Nova
        ["Cooldown"] = 0,
        ["LastUsed"] = 0,
        ["Remote"] = noliFolder and noliFolder:FindFirstChild("NoliNova")
    }
}

local JASON_AUTO_ABILITIES = { "MainAbility", "AltAbility1", "AltAbility2" }
local SHEDLETSKY_AUTO_ABILITIES = { "Slash", "Fried Chicken" }
local NOLI_AUTO_ABILITIES = { "MainAbility", "AltAbility2" }

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

    if cType == "Jason" or cType == "Slasher" or cType == "Noli" then
        return char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    elseif cType == "Shedletsky" then
        return char:GetAttribute("CanRun") ~= false and char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    end
    return true
end
--------------------------------------------------------------------------------
-- PART 2: ACTION & AUTO-FARM SYSTEM (IDLE SAFE SPACE TELEPORT)
--------------------------------------------------------------------------------

local shedletskyRemote = ReplicatedStorage:WaitForChild("CharacterAbilities", 5) 
    and ReplicatedStorage.CharacterAbilities:WaitForChild("Shedletsky", 5) 
    and ReplicatedStorage.CharacterAbilities.Shedletsky:WaitForChild("ShedletskyAttackRemote", 5)

local function castCharacterAction(actionName, targetPosition)
    if not canUseCharacter() then return end
    local cType = getCurrentCharacterType()

    -- Direct Shedletsky Slash logic
    if cType and cType:lower():find("shedletsky") and actionName == "Slash" then
        if not shedletskyRemote then
            local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
            local shedFolder = charAbilities and charAbilities:FindFirstChild("Shedletsky", true)
            shedletskyRemote = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote", true)
        end

        if shedletskyRemote then
            local data = ShedletskyAbilities["Slash"]
            local now = os.clock()
            
            if data and (now - data.LastUsed >= data.Cooldown) then
                data.LastUsed = now

                -- Turn character toward target
                if targetPosition and char and char:FindFirstChild("HumanoidRootPart") then
                    local myRoot = char.HumanoidRootPart
                    myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPosition.X, myRoot.Position.Y, targetPosition.Z))
                end

                -- Execute ability via RemoteFunction / RemoteEvent safely
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

    -- Logic for Jason / Slasher / Noli
    local abilityTable = ((cType == "Jason" or cType == "Slasher") and JasonAbilities) or (cType == "Noli" and NoliAbilities)
    if not abilityTable then return end

    local data = abilityTable[actionName]
    if data and data.Remote then
        local now = os.clock()
        if now - data.LastUsed >= data.Cooldown then
            data.LastUsed = now

            if cType == "Noli" and actionName == "AltAbility2" then
                local aimPos = targetPosition or (workspace.Camera.CFrame * CFrame.new(0, 0, -500)).Position
                data.Remote:FireServer(aimPos, true)
            else
                data.Remote:FireServer()
            end
        end
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

    -- STRICT LOW HP CHECK
    if maxHpConstraint and tHum.Health > maxHpConstraint then
        return false
    end

    return true
end

local function getLowHpTarget(maxHp)
    local limitHp = maxHp or targetHealthThreshold

    -- Validate existing locked target strictly against threshold
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
        
        -- If Auto-Farm Low HP is active but no targets exist, stay parked at Safe Space
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

    -- Emergency Health Protection Threshold
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

    if targetP and isTargetAliveAndValid(targetP, maxHpConstraint) then
        local autoList = ((cType == "Jason" or cType == "Slasher") and JASON_AUTO_ABILITIES) 
            or (cType and cType:lower():find("shedletsky") and {"Slash"}) 
            or (cType == "Noli" and NOLI_AUTO_ABILITIES) or {}

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
    ["guest1337"] = true, ["shedletsky"] = true, ["dusekkar"] = true,
    ["martialartist"] = true, ["chance"] = true, ["twotime"] = true,
    ["007n7"] = true, ["elliot"] = true, ["veeronica"] = true,
    ["janedoe"] = true, ["messi"] = true, ["noob"] = true
}

local KILLER_CLASSES = {
    ["slasher"] = true, ["jason"] = true, ["coolkid"] = true,
    ["1x4"] = true, ["noli"] = true, ["swordsmaster"] = true,
    ["guest666"] = true, ["2011x"] = true, ["johndoe"] = true,
    ["azure"] = true
}

-- Determine Role Colors (Blue = Survivor, Red = Killer)
local function getRoleColor(targetChar)
    if not targetChar then return Color3.fromRGB(0, 150, 255), "Survivor" end

    local rawCharType = targetChar:GetAttribute("Character") or targetChar.Name
    local charType = string.lower(tostring(rawCharType))

    if SURVIVOR_CLASSES[charType] then
        return Color3.fromRGB(0, 150, 255), "Survivor" -- Blue
    elseif KILLER_CLASSES[charType] then
        return Color3.fromRGB(255, 35, 35), "Killer"   -- Red
    end

    return Color3.fromRGB(0, 150, 255), "Survivor" -- Default Fallback
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

        local roleColor, roleName = getRoleColor(targetChar)

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
        billboard.Size = UDim2.new(0, 200, 0, 30)
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
                local updatedColor, updatedRole = getRoleColor(targetChar)
                highlight.FillColor = updatedColor
                label.TextColor3 = updatedColor

                highlight.Enabled = true
                billboard.Enabled = true
                label.Text = string.format("%s [%s] | %d HP", plr.Name, updatedRole, math.floor(targetHum.Health))
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
-- PART 4: COMBAT TAB & UTILITY TAB (PERFORMANCE OPTIMIZED & CLEANED)
--------------------------------------------------------------------------------

local AIM_DISTANCE = 30 

-- Helper: Fast character matching check
local function isMatchingCharacter(charName)
    local character = player.Character
    if not character then return false end
    
    local currentName = character.Name
    local charAttr = character:GetAttribute("Character") or character:GetAttribute("CharacterType")
    
    if type(charName) == "table" then
        for _, name in ipairs(charName) do
            if currentName:find(name) or (charAttr and tostring(charAttr):find(name)) then
                return true
            end
        end
        return false
    end
    return currentName:find(charName) or (charAttr and tostring(charAttr):find(charName))
end

-- Helper: Target selection cached by distance
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

local function aimAtTarget(targetChar)
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        local myRoot = character.HumanoidRootPart
        local targetPos = targetChar.HumanoidRootPart.Position
        local distance = (myRoot.Position - targetPos).Magnitude

        if distance <= AIM_DISTANCE then
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
            return true
        end
    end
    return false
end

CombatTab:CreateSection("Main Attacks")

--------------------------------------------------------------------------------
-- AUTOMATED ATTACKS (REMOTE CACHED & THROTTLED)
--------------------------------------------------------------------------------

-- Remote Cache Function
local function findRemoteByName(remoteName, folderName)
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities and folderName then
        local folder = charAbilities:FindFirstChild(folderName, true)
        if folder then
            local obj = folder:FindFirstChild(remoteName, true)
            if obj then return obj end
        end
    end
    return ReplicatedStorage:FindFirstChild(remoteName, true)
end

-- 1. Auto Attack (Slasher M1)
local autoAttackOn = false
local attackRemote = nil

task.spawn(function()
    while true do
        if autoAttackOn then
            if isMatchingCharacter({"Jason", "Slasher"}) then
                if not attackRemote then attackRemote = findRemoteByName("JasonAttackRemote", "Jason") end
                if attackRemote then
                    local target = getClosestTarget()
                    local isClose = target and aimAtTarget(target)
                    if isClose and target:FindFirstChild("HumanoidRootPart") then
                        attackRemote:FireServer(target.HumanoidRootPart.Position)
                    else
                        attackRemote:FireServer()
                    end
                end
            end
            task.wait(0.12) -- Throttled delay to eliminate loop spam
        else
            task.wait(0.3) -- Slow wait when disabled
        end
    end
end)

CombatTab:CreateToggle({
    Name = "Auto Attack (Slasher M1)",
    CurrentValue = false,
    Callback = function(value)
        autoAttackOn = value
        if value and not attackRemote then attackRemote = findRemoteByName("JasonAttackRemote", "Jason") end
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

CombatTab:CreateToggle({
    Name = "Camlock Target Focus",
    CurrentValue = false,
    Callback = function(value)
        if value then enableLock() else disableLock() end
    end,
})

--------------------------------------------------------------------------------
-- UTILITY TAB ELEMENTS (LIGHTWEIGHT TPWALK)
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
-- PART 5: PROTECTION & TELEPORTER
--------------------------------------------------------------------------------

local lowHealthProtectionOn, healthThreshold, protectionPlatform = false, 40, nil

UtilityTab:CreateSection("Safety & Protection")

UtilityTab:CreateToggle({
    Name = "Low Health Auto-Teleport",
    CurrentValue = false,
    Callback = function(value)
        lowHealthProtectionOn = value
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

task.spawn(function()
    while true do
        task.wait(0.2)
        if lowHealthProtectionOn and char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp and humanoid.Health > 0 and humanoid.Health <= healthThreshold then
                if not protectionPlatform or not protectionPlatform.Parent then
                    protectionPlatform = Instance.new("Part", workspace)
                    protectionPlatform.Size = Vector3.new(60, 5, 60)
                    protectionPlatform.Position = savedPos
                    protectionPlatform.Anchored = true
                    protectionPlatform.Color = Color3.fromRGB(0, 200, 100)
                    protectionPlatform.Material = Enum.Material.SmoothPlastic
                    protectionPlatform.Name = "AutoProtectionBaseplate"
                end
                hrp.CFrame = CFrame.new(savedPos + Vector3.new(0, 6, 0))
                lowHealthProtectionOn = false
            end
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
-- PART 6: GUEST1337 AUTO FARM (STRICT SURVIVOR WHITELIST)
--------------------------------------------------------------------------------

local guestAutoLowHp, guestAutoAll, stickToTargetOn, guestThreshold, guestHitOffset, guestSpeed = false, false, true, 20, 5.5, 16
local currentHardLockedTarget = nil

local SURVIVOR_CLASSES = {
    ["guest1337"]     = true,
    ["guest"]         = true,
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
}

local function isAllowedCharacter(playerTarget)
    if not playerTarget or not playerTarget.Parent or not playerTarget.Character then return false end
    local char = playerTarget.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hum or not hrp or hum.Health <= 0 then return false end

    -- Check character name or attributes against survivor list strictly
    local charType = string.lower(tostring(char:GetAttribute("Character") or char:GetAttribute("CharacterType") or char.Name))
    if SURVIVOR_CLASSES[charType] or SURVIVOR_CLASSES[string.lower(playerTarget.Name)] then 
        return true 
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("StringValue") and SURVIVOR_CLASSES[string.lower(child.Value)] then return true end
    end

    return false
end

local function findGuestRemote(possibleNames)
    for _, name in ipairs(possibleNames) do
        local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
        if charAbilities then
            local guestFolder = charAbilities:FindFirstChild("Guest1337", true)
            if guestFolder then
                local obj = guestFolder:FindFirstChild(name, true)
                if obj then return obj end
            end
        end

        local obj = ReplicatedStorage:FindFirstChild(name, true)
        if obj then return obj end
    end
    return nil
end

local punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack", "Punch"})
local chargeRemote = findGuestRemote({"ChargeRemote", "Charge"})

local function safeTriggerRemote(remoteObj, targetChar, targetHrp)
    if not remoteObj then return end
    pcall(function()
        if remoteObj:IsA("RemoteEvent") then
            remoteObj:FireServer()
            if targetChar then remoteObj:FireServer(targetChar) end
            if targetHrp then remoteObj:FireServer(targetHrp.Position) end
        elseif remoteObj:IsA("RemoteFunction") then
            task.spawn(function()
                remoteObj:InvokeServer()
            end)
        end
    end)
end

local function executeGuestAbilities(targetChar, targetHrp)
    if not punchRemote then punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack", "Punch"}) end
    if not chargeRemote then chargeRemote = findGuestRemote({"ChargeRemote", "Charge"}) end

    safeTriggerRemote(chargeRemote, targetChar, targetHrp)
    safeTriggerRemote(punchRemote, targetChar, targetHrp)
end

RS.RenderStepped:Connect(function(deltaTime)
    if not (guestAutoLowHp or guestAutoAll) then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp then return end

    humanoid.WalkSpeed = guestSpeed

    for _, attr in ipairs({"SpeedMultiplier", "Slowed", "WalkSpeedModifier", "DisableMovement"}) do
        if character:GetAttribute(attr) ~= nil then character:SetAttribute(attr, nil) end
        if humanoid:GetAttribute(attr) ~= nil then humanoid:SetAttribute(attr, nil) end
    end

    if humanoid.MoveDirection.Magnitude > 0 then
        local moveVector = humanoid.MoveDirection * guestSpeed * deltaTime
        hrp.CFrame = hrp.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
    end
end)

local function isTargetValid(targetPlayer, lowHpOnly)
    if not targetPlayer or not targetPlayer.Parent or not targetPlayer.Character then return false end

    local targetChar = targetPlayer.Character
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    local hum = targetChar:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 then
        return false
    end

    if not isAllowedCharacter(targetPlayer) then
        return false
    end

    if lowHpOnly and hum.Health > guestThreshold then
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

task.spawn(function()
    while true do
        task.wait(0.03)

        if guestAutoLowHp or guestAutoAll then
            local lowHpOnly = guestAutoLowHp and not guestAutoAll
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
                    local lookAtPos = Vector3.new(targetHrp.Position.X, myHrp.Position.Y, targetHrp.Position.Z)
                    local offsetPos = targetHrp.CFrame * CFrame.new(0, 0, -guestHitOffset)
                    myHrp.CFrame = CFrame.lookAt(offsetPos.Position, lookAtPos)

                    executeGuestAbilities(targetChar, targetHrp)
                end
            end
        else
            currentHardLockedTarget = nil
        end
    end
end)

GuestTab:CreateSection("Guest Auto Farm")

local GuestLowHpToggle, GuestAllToggle

GuestLowHpToggle = GuestTab:CreateToggle({
    Name = "Auto Farm Low HP Survivors",
    CurrentValue = false,
    Callback = function(value)
        guestAutoLowHp = value
        currentHardLockedTarget = nil
        if value and GuestAllToggle then GuestAllToggle:Set(false) end
    end,
})

GuestAllToggle = GuestTab:CreateToggle({
    Name = "Auto Farm All Survivors",
    CurrentValue = false,
    Callback = function(value)
        guestAutoAll = value
        currentHardLockedTarget = nil
        if value and GuestLowHpToggle then GuestLowHpToggle:Set(false) end
    end,
})

GuestTab:CreateToggle({
    Name = "Lock to Target",
    CurrentValue = true,
    Callback = function(value)
        stickToTargetOn = value
        currentHardLockedTarget = nil
    end,
})

GuestTab:CreateSection("Guest Parameters")

GuestTab:CreateInput({
    Name = "Low HP Threshold",
    PlaceholderText = "20",
    Callback = function(text)
        local v = tonumber(text)
        if v then guestThreshold = v end
    end,
})

GuestTab:CreateInput({
    Name = "Hit Distance Offset",
    PlaceholderText = "5.5",
    Callback = function(text)
        local v = tonumber(text)
        if v then guestHitOffset = v end
    end,
})

GuestTab:CreateInput({
    Name = "Target Walk Speed",
    PlaceholderText = "16",
    Callback = function(text)
        local v = tonumber(text)
        if v then guestSpeed = v end
    end,
})
