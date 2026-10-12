--------------------------------------------------------------------------------
-- PART 1: CORE SETUP, WINDOW & STATE MANAGEMENT
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

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera

local player = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Novalight Beta",
    Author = "by Chwaa",
    Folder = "NovalightConfig",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    Transparent = false
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if Window then Window:Toggle() end
    end
end)

local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
local AutoFarmTab = Window:Tab({ Title = "Auto Farm", Icon = "crosshair" })
local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local UtilityTab = Window:Tab({ Title = "Movement & Misc", Icon = "zap" })
local TeleportTab = Window:Tab({ Title = "Teleporter", Icon = "map-pin" })
local GuestTab = Window:Tab({ Title = "Guest1337", Icon = "user" })

local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

player.CharacterAdded:Connect(function(c)
    char = c
    hum = c:WaitForChild("Humanoid")
end)

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

local charAbilitiesFolder = ReplicatedStorage:WaitForChild("CharacterAbilities", 5)
local jasonFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Jason")
local shedFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Shedletsky")
local noliFolder = charAbilitiesFolder and charAbilitiesFolder:FindFirstChild("Noli")

local JasonAbilities = {
    ["MainAbility"] = { Cooldown = 1.9, LastUsed = 0, Remote = jasonFolder and jasonFolder:FindFirstChild("JasonAttackRemote") },
    ["AltAbility1"] = { Cooldown = 15, LastUsed = 0, Remote = jasonFolder and jasonFolder:FindFirstChild("Behead") },
    ["AltAbility2"] = { Cooldown = 25, LastUsed = 0, Remote = jasonFolder and jasonFolder:FindFirstChild("GashingWound") },
    ["AltAbility3"] = { Cooldown = 20, LastUsed = 0, Remote = jasonFolder and jasonFolder:FindFirstChild("Enraged") }
}

local ShedletskyAbilities = {
    ["Slash"] = { Cooldown = 15, LastUsed = 0, Remote = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote") }
}

local NoliAbilities = {
    ["MainAbility"] = { Cooldown = 1.8, LastUsed = 0, Remote = noliFolder and noliFolder:FindFirstChild("NoliAttackRemote") },
    ["AltAbility2"] = { Cooldown = 0, LastUsed = 0, Remote = noliFolder and noliFolder:FindFirstChild("NoliNova") }
}

local JASON_AUTO_ABILITIES = { "MainAbility", "AltAbility1", "AltAbility2" }
local NOLI_AUTO_ABILITIES = { "MainAbility", "AltAbility2" }

local autoFarmLowHpOn = false
local autoFarmAllOn = false
local lockInFrontOn = false
local stickToPersonOn = false
local targetHealthThreshold = 20
local hitDistanceOffset = 3
local MAX_ABILITY_DISTANCE = 15

local currentLockedTarget = nil
local LowHpToggle, AllPlayersToggle

local function getCurrentCharacterType()
    if not char then return nil end
    return char:GetAttribute("Character")
end

local function canUseCharacter()
    if not char or not hum or hum.Health <= 0 then return false end
    local cType = getCurrentCharacterType()

    if cType == "Jason" or cType == "Slasher" or cType == "Noli" then
        return char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    elseif cType and cType:lower():find("shedletsky") then
        return char:GetAttribute("CanRun") ~= false and char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= true
    end
    return true
end
--------------------------------------------------------------------------------
-- PART 2: ACTION & AUTO-FARM SYSTEM (OPTIMIZED)
--------------------------------------------------------------------------------

local function setNoCollide(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

player.CharacterAdded:Connect(function(c)
    char = c
    hum = c:WaitForChild("Humanoid")
    if autoFarmLowHpOn or autoFarmAllOn then
        setNoCollide(c)
    end
end)

local function positionAtTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    local offset = hitDistanceOffset
    if lockInFrontOn then
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -offset) * CFrame.Angles(0, math.pi, 0)
    else
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, offset)
    end
end

local lastTargetScan = 0
local SCAN_INTERVAL = 0.15

RS.Stepped:Connect(function()
    if not autoFarmLowHpOn and not autoFarmAllOn then
        isCurrentlyWaitingInSafeSpace = false
        return
    end
    if not char or not hum or hum.Health <= 0 then return end

    local now = os.clock()
    local activeTarget = currentLockedTarget

    if now - lastTargetScan >= SCAN_INTERVAL then
        lastTargetScan = now
        activeTarget = autoFarmLowHpOn and getLowHpTarget(targetHealthThreshold) or getAnyTarget()
    end

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

-- (Keep the original getLowHpTarget, getAnyTarget, isTargetAliveAndValid, castCharacterAction functions here)

--------------------------------------------------------------------------------
-- AUTO FARM TAB ELEMENTS
--------------------------------------------------------------------------------

local SectionTarget = AutoFarmTab:Section({ Title = "Targeting Options" })
SectionTarget:Toggle({ Title = "Lock in Front of Person", Default = false, Callback = function(v) lockInFrontOn = v end })
SectionTarget:Toggle({ Title = "Stick to Person?", Default = false, Callback = function(v) stickToPersonOn = v if not v then currentLockedTarget = nil end end })
SectionTarget:Dropdown({
   Title = "Position Offset (Hit Range)",
   Values = {"Close (~3 studs)", "Slightly Far (~5.5 studs)", "Far (~8 studs)"},
   Default = "Close (~3 studs)",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      hitDistanceOffset = selected:find("Slightly Far") and 5.5 or (selected:find("Far") and 8 or 3)
   end,
})

local SectionAuto = AutoFarmTab:Section({ Title = "Auto Farm Automation" })
LowHpToggle = SectionAuto:Toggle({
   Title = "Auto Farm Low Health Players",
   Default = false,
   Callback = function(value)
      if value and hum and hum.Health <= 30 then
         autoFarmLowHpOn = false
         task.spawn(function() if LowHpToggle then LowHpToggle:SetValue(false) end end)
         teleportToSafeSpace()
         return
      end
      autoFarmLowHpOn = value
      isCurrentlyWaitingInSafeSpace = false
      if value then setNoCollide(char) end
      if value and AllPlayersToggle then AllPlayersToggle:SetValue(false) end
      if not value then currentLockedTarget = nil end
   end,
})

AllPlayersToggle = SectionAuto:Toggle({
   Title = "Auto Farm All Players",
   Default = false,
   Callback = function(value)
      if value and hum and hum.Health <= 30 then
         autoFarmAllOn = false
         task.spawn(function() if AllPlayersToggle then AllPlayersToggle:SetValue(false) end end)
         teleportToSafeSpace()
         return
      end
      autoFarmAllOn = value
      isCurrentlyWaitingInSafeSpace = false
      if value then setNoCollide(char) end
      if value and LowHpToggle then LowHpToggle:SetValue(false) end
      if not value then currentLockedTarget = nil end
   end,
})

SectionAuto:Dropdown({
   Title = "Low HP Target Threshold",
   Values = {"10 HP", "20 HP", "30 HP", "50 HP"},
   Default = "20 HP",
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

local SectionSafety = AutoFarmTab:Section({ Title = "Emergency Safety" })
SectionSafety:Button({ Title = "Teleport to Safe Space", Callback = function() teleportToSafeSpace() end })
--------------------------------------------------------------------------------
-- PART 3: ROLE-BASED DYNAMIC ESP (OPTIMIZED)
--------------------------------------------------------------------------------

local espOn = false
local activeESP = {}

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

local function getRoleColor(targetChar)
    if not targetChar then return Color3.fromRGB(0, 150, 255), "Survivor" end
    local rawCharType = targetChar:GetAttribute("Character") or targetChar.Name
    local charType = string.lower(tostring(rawCharType))
    if SURVIVOR_CLASSES[charType] then
        return Color3.fromRGB(0, 150, 255), "Survivor"
    elseif KILLER_CLASSES[charType] then
        return Color3.fromRGB(255, 35, 35), "Killer"
    end
    return Color3.fromRGB(0, 150, 255), "Survivor"
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

        local elapsed = 0
        local conn = RS.RenderStepped:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0

            if not espOn or not targetChar or not targetChar.Parent or not targetChar:IsDescendantOf(workspace) or targetHum.Health <= 0 then
                if highlight then highlight.Enabled = false end
                if billboard then billboard.Enabled = false end
            else
                local updatedColor, updatedRole = getRoleColor(targetChar)
                highlight.FillColor = updatedColor
                label.TextColor3 = updatedColor
                highlight.Enabled = true
                billboard.Enabled = true
                label.Text = string.format("%s [%s] | %d HP", plr.Name, updatedRole, math.floor(targetHum.Health))
            end
        end)

        activeESP[plr] = { Highlight = highlight, Billboard = billboard, Connection = conn }
    end

    if plr.Character then setupChar(plr.Character) end
    plr.CharacterAdded:Connect(setupChar)
end

--------------------------------------------------------------------------------
-- ESP TAB ELEMENTS
--------------------------------------------------------------------------------
local SectionESP = ESPTab:Section({ Title = "ESP Visuals" })

SectionESP:Toggle({
   Title = "Role ESP (Blue Survivor / Red Killer)",
   Default = false,
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
-- PART 4: COMBAT TAB & UTILITY TAB
--------------------------------------------------------------------------------

-- (Include the original combat functions: isMatchingCharacter, getClosestTarget, aimAtTarget,
--  findRemote, autoAttack loop, findBeheadRemote, autoBehead loop, Subject loop, Camlock, etc.)

local SectionCombat1 = CombatTab:Section({ Title = "Main Attacks" })
-- ... original toggles for Auto Attack, Behead, Subject, Camlock ...

local SectionMovement = UtilityTab:Section({ Title = "Movement Mods" })
local tpwalkOn, speed = false, 1
SectionMovement:Toggle({ Title = "TpWalk", Default = false, Callback = function(v) tpwalkOn = v end })
SectionMovement:Slider({ Title = "TpWalk Speed", Value = { Min = 1, Max = 10, Default = 1, Step = 1 }, Callback = function(v) speed = tonumber(v) or 1 end })
RS.Heartbeat:Connect(function()
    if tpwalkOn and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local move = char.Humanoid.MoveDirection
        if move.Magnitude > 0 then char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + (move * speed) end
    end
end)

-- ... original Save Place button ...
--------------------------------------------------------------------------------
-- PART 5: PROTECTION & TELEPORTER
--------------------------------------------------------------------------------

local lowHealthProtectionOn, healthThreshold, protectionPlatform = false, 40, nil
local SectionSafety = UtilityTab:Section({ Title = "Safety & Protection" })
SectionSafety:Toggle({ Title = "Low Health Auto-Teleport", Default = false, Callback = function(v) lowHealthProtectionOn = v end })
SectionSafety:Slider({ Title = "Health Threshold", Value = { Min = 10, Max = 80, Default = 40, Step = 5 }, Callback = function(v) healthThreshold = v end })

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

-- ... original Teleporter section (search, dropdown, teleport button, stick toggle, RenderStepped stick) ...
--------------------------------------------------------------------------------
-- PART 6: GUEST1337 AUTO FARM (OPTIMIZED)
--------------------------------------------------------------------------------

-- (Keep original isAllowedCharacter, findRemote, safeTriggerRemote, executeGuestAbilities, isTargetValid, getClosestValidPlayer)

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

task.spawn(function()
    while true do
        task.wait(0.12)
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

--------------------------------------------------------------------------------
-- GUEST TAB ELEMENTS
--------------------------------------------------------------------------------

local SectionGuestAutomation = GuestTab:Section({ Title = "Guest Auto Farm" })
local GuestLowHpToggle, GuestAllToggle

GuestLowHpToggle = SectionGuestAutomation:Toggle({
   Title = "Auto Farm Low HP Survivors",
   Default = false,
   Callback = function(v)
      guestAutoLowHp = v
      currentHardLockedTarget = nil
      if v and GuestAllToggle then GuestAllToggle:SetValue(false) end
   end,
})

GuestAllToggle = SectionGuestAutomation:Toggle({
   Title = "Auto Farm All Survivors",
   Default = false,
   Callback = function(v)
      guestAutoAll = v
      currentHardLockedTarget = nil
      if v and GuestLowHpToggle then GuestLowHpToggle:SetValue(false) end
   end,
})

SectionGuestAutomation:Toggle({
   Title = "Lock to Target",
   Default = true,
   Callback = function(v)
      stickToTargetOn = v
      currentHardLockedTarget = nil
   end,
})

local SectionGuestSettings = GuestTab:Section({ Title = "Guest Parameters" })
SectionGuestSettings:Input({ Title = "Low HP Threshold", Placeholder = "20", Callback = function(t) local v = tonumber(t) if v then guestThreshold = v end end })
SectionGuestSettings:Input({ Title = "Hit Distance Offset", Placeholder = "5.5", Callback = function(t) local v = tonumber(t) if v then guestHitOffset = v end end })
SectionGuestSettings:Input({ Title = "Target Walk Speed", Placeholder = "16", Callback = function(t) local v = tonumber(t) if v then guestSpeed = v end end })
