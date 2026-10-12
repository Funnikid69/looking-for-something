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
		return char:GetAttribute("CanRun") ~= false and char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= 
true
	end
	return true
end
--------------------------------------------------------------------------------
-- PART 2: ACTION & AUTO-FARM SYSTEM (IDLE SAFE SPACE TELEPORT) [OPTIMIZED]
--------------------------------------------------------------------------------

local function setNoCollide(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Call once when enabling farm or character respawns
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
local SCAN_INTERVAL = 0.15 -- scan players only every 150ms instead of every frame

RS.Stepped:Connect(function()
    if not autoFarmLowHpOn and not autoFarmAllOn then
        isCurrentlyWaitingInSafeSpace = false
        return
    end
    if not char or not hum or hum.Health <= 0 then return end

    local now = os.clock()
    local activeTarget = currentLockedTarget

    -- Only rescan players every SCAN_INTERVAL
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

-- Also call setNoCollide when the toggles are turned on
-- (add this inside the existing Toggle callbacks for LowHp and AllPlayers)
-- Example inside the Callback:
-- if value then setNoCollide(char) end
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

        -- Throttled update loop (runs at ~10 FPS to eliminate heavy RenderStepped overhead)
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

local SectionCombat1 = CombatTab:Section({ Title = "Main Attacks" })

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

SectionCombat1:Toggle({
   Title = "Auto Attack (Slasher M1)",
   Default = false,
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

SectionCombat1:Toggle({
   Title = "Camlock Target Focus",
   Default = false,
   Callback = function(value)
      if value then enableLock() else disableLock() end
   end,
})

--------------------------------------------------------------------------------
-- UTILITY TAB ELEMENTS (LIGHTWEIGHT TPWALK)
--------------------------------------------------------------------------------
local SectionMovement = UtilityTab:Section({ Title = "Movement Mods" })

local tpwalkOn = false
local speed = 1

SectionMovement:Toggle({
   Title = "TpWalk",
   Default = false,
   Callback = function(value)
      tpwalkOn = value
   end,
})

SectionMovement:Slider({
   Title = "TpWalk Speed",
   Value = { Min = 1, Max = 10, Default = 1, Step = 1 },
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

SectionMovement:Button({
   Title = "Save Place (Platform TP)",
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
                    protectionPlatform.Size, protectionPlatform.Position, protectionPlatform.Anchored, protectionPlatform.Color, protectionPlatform.Material, protectionPlatform.Name = Vector3.new(60, 5, 60), savedPos, true, Color3.fromRGB(0, 200, 100), Enum.Material.SmoothPlastic, "AutoProtectionBaseplate"
                end
                hrp.CFrame = CFrame.new(savedPos + Vector3.new(0, 6, 0))
                lowHealthProtectionOn = false
            end
        end
    end
end)

local SectionTeleport = TeleportTab:Section({ Title = "Player Teleporter" })
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
    if #playerDropdownOptions == 0 then playerDropdownOptions = {"No Players Found"} end
    if PlayerDropdown then PlayerDropdown:Refresh(playerDropdownOptions) end
end

SectionTeleport:Input({ Title = "Search Player", Placeholder = "Type to filter...", Callback = function(text) searchQuery = text or "" refreshPlayerDropdown() end })
PlayerDropdown = SectionTeleport:Dropdown({
   Title = "Select Target Player",
   Values = {"Loading..."},
   Default = "Loading...",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      selectedPlayer = playerMap[selected]
   end,
})

task.defer(function() refreshPlayerDropdown() end)
Players.PlayerAdded:Connect(function() task.wait(0.5) refreshPlayerDropdown() end)
Players.PlayerRemoving:Connect(function(p) if selectedPlayer == p then selectedPlayer = nil stickInFrontOn = false end refreshPlayerDropdown() end)

SectionTeleport:Button({
   Title = "Teleport to Player",
   Callback = function()
      if selectedPlayer and selectedPlayer.Character then
         local targetHrp, myHrp = selectedPlayer.Character:FindFirstChild("HumanoidRootPart"), player.Character and player.Character:FindFirstChild("HumanoidRootPart")
         if targetHrp and myHrp then myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -3) end
      end
   end,
})
SectionTeleport:Toggle({ Title = "Stick in Front of Player", Default = false, Callback = function(v) stickInFrontOn = v end })
SectionTeleport:Slider({ Title = "Stick Distance Offset", Value = { Min = 2, Max = 25, Default = 5.5, Step = 0.5 }, Callback = function(v) stickOffset = v end })

RS.RenderStepped:Connect(function()
    if stickInFrontOn and selectedPlayer and selectedPlayer.Character then
        local targetChar = selectedPlayer.Character
        local targetHrp, targetHum = targetChar:FindFirstChild("HumanoidRootPart"), targetChar:FindFirstChildOfClass("Humanoid")
        local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp or not targetHum or targetHum.Health <= 0 then stickInFrontOn, selectedPlayer = false, nil return end
        if myHrp then
            local pos = targetHrp.CFrame * CFrame.new(0, 0, -stickOffset)
            myHrp.CFrame = CFrame.lookAt(pos.Position, targetHrp.Position)
        end
    end
end)
--------------------------------------------------------------------------------
-- PART 6: GUEST1337 AUTO FARM (REMOTES & HITBOX FIXED + OPTIMIZED)
--------------------------------------------------------------------------------

-- ... (keep the existing isAllowedCharacter, findRemote, safeTriggerRemote, executeGuestAbilities as-is)

-- Movement enforcement — still on RenderStepped but only when farming
RS.RenderStepped:Connect(function(deltaTime)
    if not (guestAutoLowHp or guestAutoAll) then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    humanoid.WalkSpeed = guestSpeed

    -- Clear slowing attributes less aggressively (only if they exist)
    for _, attr in ipairs({"SpeedMultiplier", "Slowed", "WalkSpeedModifier", "DisableMovement"}) do
        if character:GetAttribute(attr) ~= nil then character:SetAttribute(attr, nil) end
        if humanoid:GetAttribute(attr) ~= nil then humanoid:SetAttribute(attr, nil) end
    end

    if humanoid.MoveDirection.Magnitude > 0 then
        local moveVector = humanoid.MoveDirection * guestSpeed * deltaTime
        hrp.CFrame = hrp.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
    end
end)

-- Optimized Execution Loop (was 0.05s, now 0.12s)
task.spawn(function()
    while true do
        task.wait(0.12) -- reduced frequency to cut CPU usage

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
