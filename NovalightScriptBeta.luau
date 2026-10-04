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
-- WINDUI SETUP
--------------------------------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local player = game.Players.LocalPlayer
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera

--// WINDUI WINDOW SETUP
local Window = WindUI:CreateWindow({
    Title = "Novalight Beta",
    Author = "by Chwaa",
    Folder = "NovalightConfig",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    Transparent = false
})

--// TABS SETUP
local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
local AutoFarmTab = Window:Tab({ Title = "Auto Farm", Icon = "crosshair" })
local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local UtilityTab = Window:Tab({ Title = "Movement & Misc", Icon = "zap" })
local TeleportTab = Window:Tab({ Title = "Teleporter", Icon = "map-pin" })
local GuestTab = Window:Tab({ Title = "Guest1337", Icon = "user" })

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
-- CHARACTER ABILITY CONFIGURATIONS
--------------------------------------------------------------------------------
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
	["Slash"] = { Cooldown = 15, LastUsed = 0, Remote = shedFolder and shedFolder:FindFirstChild("ShedletskyAttackRemote") },
	["Fried Chicken"] = { Cooldown = 15, LastUsed = 0, Remote = shedFolder and shedFolder:FindFirstChild("ShedletskyChickenRemote") }
}

local NoliAbilities = {
	["MainAbility"] = { Cooldown = 1.8, LastUsed = 0, Remote = noliFolder and noliFolder:FindFirstChild("NoliAttackRemote") },
	["AltAbility2"] = { Cooldown = 0, LastUsed = 0, Remote = noliFolder and noliFolder:FindFirstChild("NoliNova") }
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
	elseif cType == "Shedletsky" then
		return char:GetAttribute("CanRun") ~= false and char:GetAttribute("CanAttack") ~= false and char:GetAttribute("Emoting") ~= true and char:GetAttribute("AbilitiesDisabled") ~= tru
e
	end
	return true
end
--------------------------------------------------------------------------------
-- PART 2: AUTO FARM & TARGETING SYSTEM
--------------------------------------------------------------------------------

local function isTargetAliveAndValid(target)
	if not target or target == player then return false end
	local targetChar = target.Character
	if not targetChar then return false end

	local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
	local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")

	if not targetHum or not targetHrp or targetHum.Health <= 0 then
		return false
	end

	return true
end

--// LOW HP TARGET SELECTOR (With Safe Space Wait Logic)
local function getLowHpTarget(maxHp)
	-- If locking onto a specific person, keep target if still valid
	if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget) then
		return currentLockedTarget
	end

	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local lowestHp = maxHp or targetHealthThreshold
	local targetPlayer = nil

	-- Search for players at or below health threshold
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and isTargetAliveAndValid(p) then
			local tHum = p.Character.Humanoid
			if tHum.Health <= lowestHp then
				lowestHp = tHum.Health
				targetPlayer = p
			end
		end
	end

	-- IF NO LOW-HP TARGET IS FOUND: Teleport to Safe Space and wait
	if not targetPlayer and autoFarmLowHpOn then
		teleportToSafeSpace()
	end

	currentLockedTarget = targetPlayer
	return targetPlayer
end

--// ALL PLAYERS TARGET SELECTOR
local function getAllPlayersTarget()
	if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget) then
		return currentLockedTarget
	end

	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local closestDist = math.huge
	local targetPlayer = nil

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and isTargetAliveAndValid(p) then
			local tHrp = p.Character.HumanoidRootPart
			local dist = (myRoot.Position - tHrp.Position).Magnitude
			if dist < closestDist then
				closestDist = dist
				targetPlayer = p
			end
		end
	end

	currentLockedTarget = targetPlayer
	return targetPlayer
end

--------------------------------------------------------------------------------
-- AUTO FARM TAB ELEMENTS
--------------------------------------------------------------------------------
local SectionAutoFarm = AutoFarmTab:Section({ Title = "Auto Farm Controls" })

LowHpToggle = SectionAutoFarm:Toggle({
   Title = "Auto Farm Low HP Players",
   Default = false,
   Callback = function(value)
      autoFarmLowHpOn = value
      if value and AllPlayersToggle then
         autoFarmAllOn = false
         AllPlayersToggle:SetValue(false)
      end
   end,
})

AllPlayersToggle = SectionAutoFarm:Toggle({
   Title = "Auto Farm All Players",
   Default = false,
   Callback = function(value)
      autoFarmAllOn = value
      if value and LowHpToggle then
         autoFarmLowHpOn = false
         LowHpToggle:SetValue(false)
      end
   end,
})

SectionAutoFarm:Slider({
   Title = "Low HP Threshold",
   Value = { Min = 5, Max = 100, Default = 20, Step = 1 },
   Callback = function(value)
      targetHealthThreshold = value
   end,
})

SectionAutoFarm:Slider({
   Title = "Hit Distance Offset",
   Value = { Min = 1, Max = 15, Default = 3, Step = 0.5 },
   Callback = function(value)
      hitDistanceOffset = value
   end,
})

SectionAutoFarm:Toggle({
   Title = "Lock Target in Front",
   Default = false,
   Callback = function(value)
      lockInFrontOn = value
   end,
})

SectionAutoFarm:Toggle({
   Title = "Stick to Current Target",
   Default = false,
   Callback = function(value)
      stickToPersonOn = value
   end,
})

--------------------------------------------------------------------------------
-- ABILITY EXECUTION LOOP
--------------------------------------------------------------------------------
local function useAbility(abilityData)
	if not abilityData or not abilityData.Remote then return end
	local now = tick()
	if now - abilityData.LastUsed >= abilityData.Cooldown then
		abilityData.LastUsed = now
		task.spawn(function()
			abilityData.Remote:FireServer()
		end)
	end
end

RS.Heartbeat:Connect(function()
	if not canUseCharacter() then return end

	local cType = getCurrentCharacterType()
	local activeTarget = nil

	if autoFarmLowHpOn then
		activeTarget = getLowHpTarget(targetHealthThreshold)
	elseif autoFarmAllOn then
		activeTarget = getAllPlayersTarget()
	end

	if not activeTarget or not isTargetAliveAndValid(activeTarget) then return end

	local myHrp = char:FindFirstChild("HumanoidRootPart")
	local targetHrp = activeTarget.Character:FindFirstChild("HumanoidRootPart")
	if not myHrp or not targetHrp then return end

	-- Position positioning/sticking
	if lockInFrontOn then
		local targetCFrame = targetHrp.CFrame
		local posInFront = targetCFrame * CFrame.new(0, 0, -hitDistanceOffset)
		myHrp.CFrame = CFrame.lookAt(posInFront.Position, targetHrp.Position)
	end

	local dist = (myHrp.Position - targetHrp.Position).Magnitude
	if dist <= MAX_ABILITY_DISTANCE then
		if cType == "Jason" or cType == "Slasher" then
			for _, name in ipairs(JASON_AUTO_ABILITIES) do
				useAbility(JasonAbilities[name])
			end
		elseif cType == "Shedletsky" then
			for _, name in ipairs(SHEDLETSKY_AUTO_ABILITIES) do
				useAbility(ShedletskyAbilities[name])
			end
		elseif cType == "Noli" then
			for _, name in ipairs(NOLI_AUTO_ABILITIES) do
				useAbility(NoliAbilities[name])
			end
		end
	end
end)
--------------------------------------------------------------------------------
-- PART 3: ROLE-BASED DYNAMIC ESP
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

local AIM_DISTANCE = 30 

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
    else
        return currentName:find(charName) or (charAttr and tostring(charAttr):find(charName))
    end
end

local function getClosestTarget()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local myRoot = character.HumanoidRootPart
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

-- Auto Attack
local autoAttackOn = false
local function findRemote()
    local remote = ReplicatedStorage:FindFirstChild("JasonAttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local jasonFolder = charAbilities:FindFirstChild("Jason", true)
        if jasonFolder then return jasonFolder:FindFirstChild("JasonAttackRemote", true) end
    end
    return nil
end
local attackRemote = findRemote()

task.spawn(function()
    while true do
        if autoAttackOn and isMatchingCharacter({"Jason", "Slasher"}) then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)
            
            if not attackRemote then attackRemote = findRemote() end
            if attackRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    attackRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    attackRemote:FireServer()
                end
            end
        end
        task.wait(0.1)
    end
end)

SectionCombat1:Toggle({
   Title = "Auto Attack (Slasher M1)",
   Default = false,
   Callback = function(value)
      autoAttackOn = value
      if value and not attackRemote then attackRemote = findRemote() end
   end,
})

-- Jason Behead
local autoBeheadOn = false
local function findBeheadRemote()
    local remote = ReplicatedStorage:FindFirstChild("Behead", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local jasonFolder = charAbilities:FindFirstChild("Jason", true)
        if jasonFolder then return jasonFolder:FindFirstChild("Behead", true) end
    end
    return nil
end
local beheadRemote = findBeheadRemote()

task.spawn(function()
    while true do
        if autoBeheadOn and isMatchingCharacter({"Jason", "Slasher"}) then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not beheadRemote then beheadRemote = findBeheadRemote() end
            if beheadRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    beheadRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    beheadRemote:FireServer()
                end
            end
        end
        task.wait(0.1)
    end
end)

SectionCombat1:Toggle({
   Title = "Jason Behead",
   Default = false,
   Callback = function(value)
      autoBeheadOn = value
      if value and not beheadRemote then beheadRemote = findBeheadRemote() end
   end,
})

-- Subject_0 Attack
local autoSubjectOn = false
local function findSubjectRemote()
    local remote = ReplicatedStorage:FindFirstChild("SubjectAttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local subjectFolder = charAbilities:FindFirstChild("Subject", true)
        if subjectFolder then return subjectFolder:FindFirstChild("SubjectAttackRemote", true) end
    end
    return nil
end
local subjectRemote = findSubjectRemote()

task.spawn(function()
    while true do
        if autoSubjectOn and isMatchingCharacter("Subject") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not subjectRemote then subjectRemote = findSubjectRemote() end
            if subjectRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    subjectRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    subjectRemote:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

SectionCombat1:Toggle({
   Title = "Subject_0 Attack",
   Default = false,
   Callback = function(value)
      autoSubjectOn = value
      if value and not subjectRemote then subjectRemote = findSubjectRemote() end
   end,
})

-- Camlock
local DROP_DISTANCE = 35
local CAMERA_OFFSET = Vector3.new(0, 4.5, 10) 
local TURN_SMOOTHNESS = 0.35
local currentTarget = nil
local isLocked = false

local function isTargetValid(targetChar)
	if not targetChar or not targetChar.Parent or not targetChar:FindFirstChild("HumanoidRootPart") then return false end
	local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end
	local myChar = player.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		local distance = (myChar.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude
		if distance > DROP_DISTANCE then return false end
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
		if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
		if not isTargetValid(currentTarget) then currentTarget = getClosestTarget() end
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local myRoot = myChar.HumanoidRootPart
			local myPos = myRoot.Position
			local targetPos = currentTarget.HumanoidRootPart.Position
			local targetAimPos = targetPos + Vector3.new(0, 1.5, 0)
			local charLookTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
			local charTargetCFrame = CFrame.lookAt(myPos, charLookTarget)
			myRoot.CFrame = myRoot.CFrame:Lerp(charTargetCFrame, TURN_SMOOTHNESS)
			local flatDirection = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Unit
			if flatDirection.Magnitude == 0 then flatDirection = Vector3.new(0, 0, 1) end
			local finalCamPos = myPos - (flatDirection * CAMERA_OFFSET.Z) + Vector3.new(0, CAMERA_OFFSET.Y, 0)
			camera.CFrame = CFrame.lookAt(finalCamPos, targetAimPos)
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
-- UTILITY TAB ELEMENTS (FIXED FOR WINDUI)
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

-- Fixed WindUI Slider format
SectionMovement:Slider({
   Title = "TpWalk Speed",
   Value = { Min = 1, Max = 10, Default = 1, Step = 1 },
   Callback = function(value)
      speed = tonumber(value) or 1
   end,
})

RS.Heartbeat:Connect(function()
    if tpwalkOn and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local hrp = char.HumanoidRootPart
        local move = char.Humanoid.MoveDirection
        if move.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (move * speed)
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

local lowHealthProtectionOn = false
local healthThreshold = 40
local protectionPlatform = nil
local safePosition = Vector3.new(-1119.03, 894.94, -85.90)

local SectionSafety = UtilityTab:Section({ Title = "Safety & Protection" })

local ProtectionToggle = SectionSafety:Toggle({
   Title = "Low Health Auto-Teleport",
   Default = false,
   Callback = function(value)
      lowHealthProtectionOn = value
   end,
})

SectionSafety:Slider({
   Title = "Health Threshold",
   Value = { Min = 10, Max = 80, Default = 40, Step = 5 },
   Callback = function(value)
      healthThreshold = value
   end,
})

task.spawn(function()
    while true do
        task.wait(0.2)
        if lowHealthProtectionOn then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local hrp = character:FindFirstChild("HumanoidRootPart")

                if humanoid and hrp and humanoid.Health > 0 and humanoid.Health <= healthThreshold then
                    if not protectionPlatform or not protectionPlatform.Parent then
                        protectionPlatform = Instance.new("Part")
                        protectionPlatform.Size = Vector3.new(60, 5, 60)
                        protectionPlatform.Position = safePosition
                        protectionPlatform.Anchored = true
                        protectionPlatform.Color = Color3.fromRGB(0, 200, 100)
                        protectionPlatform.Material = Enum.Material.SmoothPlastic
                        protectionPlatform.Name = "AutoProtectionBaseplate"
                        protectionPlatform.Parent = workspace
                    end

                    hrp.CFrame = CFrame.new(safePosition + Vector3.new(0, 6, 0))
                    lowHealthProtectionOn = false
                    if ProtectionToggle then ProtectionToggle:SetValue(false) end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- TELEPORT TAB ELEMENTS
--------------------------------------------------------------------------------
local SectionTeleport = TeleportTab:Section({ Title = "Player Teleporter" })

local selectedPlayer = nil
local stickInFrontOn = false
local stickOffset = 5.5

local playerDropdownOptions = {}
local playerMap = {}

local function updatePlayerList()
    playerDropdownOptions = {}
    playerMap = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local displayNameFormat = p.DisplayName .. " (@" .. p.Name .. ")"
            table.insert(playerDropdownOptions, displayNameFormat)
            playerMap[displayNameFormat] = p
        end
    end

    if #playerDropdownOptions == 0 then
        playerDropdownOptions = {"No Other Players"}
    end
end

updatePlayerList()

local PlayerDropdown = SectionTeleport:Dropdown({
   Title = "Select Target Player",
   Values = playerDropdownOptions,
   Default = playerDropdownOptions[1] or "No Other Players",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      selectedPlayer = playerMap[selected]
   end,
})

SectionTeleport:Button({
   Title = "Teleport to Player",
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

SectionTeleport:Toggle({
   Title = "Stick in Front of Player",
   Default = false,
   Callback = function(value)
      stickInFrontOn = value
   end,
})

SectionTeleport:Slider({
   Title = "Stick Distance Offset",
   Value = { Min = 2, Max = 25, Default = 5.5, Step = 0.5 },
   Callback = function(value)
      stickOffset = value
   end,
})

RS.RenderStepped:Connect(function()
    if stickInFrontOn and selectedPlayer and selectedPlayer.Character then
        local targetChar = selectedPlayer.Character
        local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        
        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

        if not targetHrp or not targetHum or targetHum.Health <= 0 then
            stickInFrontOn = false
            selectedPlayer = nil
            return
        end

        if myHrp then
            local targetCFrame = targetHrp.CFrame
            local inFrontPosition = targetCFrame * CFrame.new(0, 0, -stickOffset)
            myHrp.CFrame = CFrame.lookAt(inFrontPosition.Position, targetHrp.Position)
        end
    else
        if stickInFrontOn and not selectedPlayer then
            stickInFrontOn = false
        end
    end
end)
--------------------------------------------------------------------------------
-- PART 6: GUEST1337 CONTROLLER
--------------------------------------------------------------------------------

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

local punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack"})
local chargeRemote = findGuestRemote({"ChargeRemote", "Charge"})

local isPunchLooping = false
local isChargeLooping = false
local isComboLooping = false
local isAimingEnabled = false
local loopDelay = 0
local targetSpeed = 16

local function getNearestPlayer()
    local myChar = player.Character
    if not myChar then return nil end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local nearestTarget = nil
    local shortestDistance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = p.Character:FindFirstChildOfClass("Humanoid")
            
            if targetHrp and targetHumanoid and targetHumanoid.Health > 0 then
                local distance = (targetHrp.Position - myHrp.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestTarget = targetHrp
                end
            end
        end
    end

    return nearestTarget
end

local function faceNearestPlayer()
    if not isAimingEnabled then return end
    if not (isPunchLooping or isChargeLooping or isComboLooping) then return end
    
    local myChar = player.Character
    if not myChar then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    local targetHrp = getNearestPlayer()

    if myHrp and targetHrp then
        local lookPos = Vector3.new(targetHrp.Position.X, myHrp.Position.Y, targetHrp.Position.Z)
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookPos)
    end
end

local function safeTriggerRemote(remoteObj)
    if not remoteObj then return end
    faceNearestPlayer()

    if remoteObj:IsA("RemoteEvent") then
        remoteObj:FireServer()
    elseif remoteObj:IsA("RemoteFunction") then
        task.spawn(function()
            remoteObj:InvokeServer()
        end)
    end
end

RS.RenderStepped:Connect(function(deltaTime)
    if not (isPunchLooping or isComboLooping) then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp then return end

    humanoid.WalkSpeed = targetSpeed

    for _, attr in ipairs({"SpeedMultiplier", "Slowed", "WalkSpeedModifier", "DisableMovement"}) do
        if character:GetAttribute(attr) ~= nil then
            character:SetAttribute(attr, nil)
        end
        if humanoid:GetAttribute(attr) ~= nil then
            humanoid:SetAttribute(attr, nil)
        end
    end

    if humanoid.MoveDirection.Magnitude > 0 then
        local moveVector = humanoid.MoveDirection * targetSpeed * deltaTime
        hrp.CFrame = hrp.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
    end
end)

task.spawn(function()
    while true do
        if isPunchLooping then
            if not punchRemote then punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack"}) end
            safeTriggerRemote(punchRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

task.spawn(function()
    while true do
        if isChargeLooping then
            if not chargeRemote then chargeRemote = findGuestRemote({"ChargeRemote", "Charge"}) end
            safeTriggerRemote(chargeRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

task.spawn(function()
    while true do
        if isComboLooping then
            if not punchRemote then punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack"}) end
            if not chargeRemote then chargeRemote = findGuestRemote({"ChargeRemote", "Charge"}) end
            
            safeTriggerRemote(chargeRemote)
            safeTriggerRemote(punchRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

--------------------------------------------------------------------------------
-- GUEST TAB ELEMENTS
--------------------------------------------------------------------------------
local SectionLoops = GuestTab:Section({ Title = "Guest Loops" })

SectionLoops:Toggle({
   Title = "Punch Loop",
   Default = false,
   Callback = function(value)
      isPunchLooping = value
   end,
})

SectionLoops:Toggle({
   Title = "Charge Loop",
   Default = false,
   Callback = function(value)
      isChargeLooping = value
   end,
})

SectionLoops:Toggle({
   Title = "Both Loop (Combo)",
   Default = false,
   Callback = function(value)
      isComboLooping = value
   end,
})

local SectionTargeting = GuestTab:Section({ Title = "Targeting & Delay" })

SectionTargeting:Toggle({
   Title = "Aim Nearest",
   Default = false,
   Callback = function(value)
      isAimingEnabled = value
   end,
})

SectionTargeting:Input({
   Title = "Loop Delay (Seconds)",
   Placeholder = "0",
   Callback = function(text)
      local newDelay = tonumber(text)
      if newDelay and newDelay >= 0 then
         loopDelay = newDelay
      end
   end,
})
