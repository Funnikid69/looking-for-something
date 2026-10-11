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
-- PART 2: ACTION & AUTO-FARM SYSTEM (FIXED SHEDLETSKY ATTACHMENT)
--------------------------------------------------------------------------------

local function findShedletskyRemote()
	local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
	if charAbilities then
		local shedFolder = charAbilities:FindFirstChild("Shedletsky", true)
		if shedFolder then
			return shedFolder:FindFirstChild("ShedletskyAttackRemote", true)
		end
	end
	return ReplicatedStorage:FindFirstChild("ShedletskyAttackRemote", true)
end

local shedRemote = findShedletskyRemote()

local function castCharacterAction(actionName, targetPosition)
	local cType = getCurrentCharacterType()
	
	-- Shedletsky Slash Logic
	if cType and cType:lower():find("shedletsky") and actionName == "Slash" then
		if not shedRemote then shedRemote = findShedletskyRemote() end
		local data = ShedletskyAbilities["Slash"]
		
		if data then
			local now = os.clock()
			if now - data.LastUsed >= data.Cooldown then
				data.LastUsed = now
				
				-- Ensure character states allow attack execution
				if char then
					char:SetAttribute("CanAttack", true)
					char:SetAttribute("CanRun", true)
				end

				if shedRemote then
					pcall(function()
						-- Fire remote with position and empty fallback
						if targetPosition then
							shedRemote:FireServer(targetPosition)
						else
							shedRemote:FireServer()
						end
					end)
				end
			end
		end
		return
	end

	-- Fallback for Jason / Slasher / Noli
	if not canUseCharacter() then return end
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

local function isTargetAliveAndValid(p)
	if not p or not p.Parent or not p.Character or p == player then return false end
	local tHum = p.Character:FindFirstChild("Humanoid")
	local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
	return tHum and tRoot and tHum.Health > 0 and p.Character:IsDescendantOf(workspace)
end

local function getLowHpTarget(maxHp)
	if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget) then
		return currentLockedTarget
	end

	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local lowestHp = maxHp or targetHealthThreshold
	local targetPlayer = nil

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and isTargetAliveAndValid(p) then
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
	if stickToPersonOn and isTargetAliveAndValid(currentLockedTarget) then
		return currentLockedTarget
	end

	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local closestDist = math.huge
	local targetPlayer = nil

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and isTargetAliveAndValid(p) then
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

local function triggerEmergencySafety()
	if autoFarmLowHpOn or autoFarmAllOn then
		autoFarmLowHpOn = false
		autoFarmAllOn = false
		currentLockedTarget = nil

		if LowHpToggle then LowHpToggle:SetValue(false) end
		if AllPlayersToggle then AllPlayersToggle:SetValue(false) end

		teleportToSafeSpace()
	end
end

local function hookCharacterHealth(characterInstance)
	local humanoid = characterInstance:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.HealthChanged:Connect(function(health)
			if health <= 30 and health > 0 then
				triggerEmergencySafety()
			end
		end)
		if humanoid.Health <= 30 and humanoid.Health > 0 then
			triggerEmergencySafety()
		end
	end
end

if char then hookCharacterHealth(char) end
player.CharacterAdded:Connect(hookCharacterHealth)

RS.Stepped:Connect(function()
	if hum and hum.Health <= 30 then return end
	if not autoFarmLowHpOn and not autoFarmAllOn then return end
	if not char or not hum or hum.Health <= 0 then return end

	local activeTarget = autoFarmLowHpOn and getLowHpTarget(targetHealthThreshold) or getAnyTarget()
	if activeTarget and isTargetAliveAndValid(activeTarget) then
		positionAtTarget(activeTarget)
	end
end)

RS.Heartbeat:Connect(function()
	if hum and hum.Health <= 30 then return end
	if not autoFarmLowHpOn and not autoFarmAllOn then return end

	local cType = getCurrentCharacterType()
	local autoList, abilityTable = {}, {}

	if cType == "Jason" or cType == "Slasher" then
		autoList, abilityTable = JASON_AUTO_ABILITIES, JasonAbilities
	elseif cType and cType:lower():find("shedletsky") then
		autoList = {"Slash"}
		abilityTable = ShedletskyAbilities
	elseif cType == "Noli" then
		autoList, abilityTable = NOLI_AUTO_ABILITIES, NoliAbilities
	end

	local targetP = currentLockedTarget
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")

	if targetP and isTargetAliveAndValid(targetP) and myRoot then
		local tRoot = targetP.Character:FindFirstChild("HumanoidRootPart")
		if tRoot and (tRoot.Position - myRoot.Position).Magnitude <= MAX_ABILITY_DISTANCE then
			for _, abilityName in ipairs(autoList) do
				castCharacterAction(abilityName, tRoot.Position)
			end
		end
	else
		currentLockedTarget = nil
	end
end)

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
      if val then targetHealthThreshold = val end
   end,
})

local SectionSafety = AutoFarmTab:Section({ Title = "Emergency Safety" })
SectionSafety:Button({ Title = "Teleport to Safe Space", Callback = function() teleportToSafeSpace() end })
--------------------------------------------------------------------------------
-- PART 3: DYNAMIC ROLE ESP
--------------------------------------------------------------------------------

local espOn = false
local activeESP = {}
local SURVIVOR_CLASSES = { ["guest1337"] = true, ["shedletsky"] = true, ["dusekkar"] = true, ["martialartist"] = true, ["chance"] = true, ["twotime"] = true, ["007n7"] = true, ["elliot"] = true, ["veeronica"] = true, ["janedoe"] = true, ["messi"] = true, ["noob"] = true }
local KILLER_CLASSES = { ["slasher"] = true, ["jason"] = true, ["coolkid"] = true, ["1x4"] = true, ["noli"] = true, ["swordsmaster"] = true, ["guest666"] = true, ["2011x"] = true, ["johndoe"] = true, ["azure"] = true }

local function getRoleColor(targetChar)
    if not targetChar then return Color3.fromRGB(0, 150, 255), "Survivor" end
    local charType = string.lower(tostring(targetChar:GetAttribute("Character") or targetChar.Name))
    if SURVIVOR_CLASSES[charType] then return Color3.fromRGB(0, 150, 255), "Survivor" end
    if KILLER_CLASSES[charType] then return Color3.fromRGB(255, 35, 35), "Killer" end
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

        local roleColor = getRoleColor(targetChar)
        local highlight = Instance.new("Highlight", targetChar)
        highlight.Name, highlight.FillColor, highlight.FillTransparency, highlight.Adornee = "ESP_Highlight", roleColor, 0.5, targetChar

        local billboard = Instance.new("BillboardGui", targetChar)
        billboard.Name, billboard.AlwaysOnTop, billboard.Size, billboard.StudsOffset, billboard.Adornee = "ESP_Billboard", true, UDim2.new(0, 200, 0, 30), Vector3.new(0, 3, 0), head

        local label = Instance.new("TextLabel", billboard)
        label.Size, label.BackgroundTransparency, label.TextColor3, label.TextStrokeTransparency, label.Font, label.TextSize = UDim2.new(1, 0, 1, 0), 1, roleColor, 0, Enum.Font.SourceSansBold, 14

        local conn = RS.RenderStepped:Connect(function()
            if not espOn or not targetChar or not targetChar.Parent or not targetChar:IsDescendantOf(workspace) or targetHum.Health <= 0 then
                if highlight then highlight.Enabled = false end
                if billboard then billboard.Enabled = false end
            else
                local updatedColor, updatedRole = getRoleColor(targetChar)
                highlight.FillColor, label.TextColor3 = updatedColor, updatedColor
                highlight.Enabled, billboard.Enabled = true, true
                label.Text = string.format("%s [%s] | %d HP", plr.Name, updatedRole, math.floor(targetHum.Health))
            end
        end)
        activeESP[plr] = { Highlight = highlight, Billboard = billboard, Connection = conn }
    end
    if plr.Character then setupChar(plr.Character) end
    plr.CharacterAdded:Connect(setupChar)
end

local SectionESP = ESPTab:Section({ Title = "ESP Visuals" })
SectionESP:Toggle({
   Title = "Role ESP (Blue Survivor / Red Killer)",
   Default = false,
   Callback = function(value)
      espOn = value
      if espOn then for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
      else for p, _ in pairs(activeESP) do removeESP(p) end end
   end,
})
Players.PlayerAdded:Connect(function(p) if espOn then applyESP(p) end end)
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)
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
            if currentName:find(name) or (charAttr and tostring(charAttr):find(name)) then return true end
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
    local closestTarget, shortestDistance = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local targetChar, targetRoot, targetHumanoid = p.Character, p.Character:FindFirstChild("HumanoidRootPart"), p.Character:FindFirstChildOfClass("Humanoid")
            if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                local distance = (myRoot.Position - targetRoot.Position).Magnitude
                if distance < shortestDistance then shortestDistance, closestTarget = distance, targetChar end
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
        if (myRoot.Position - targetPos).Magnitude <= AIM_DISTANCE then
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
            return true
        end
    end
    return false
end

local SectionCombat1 = CombatTab:Section({ Title = "Main Attacks" })

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
                if isClose and target:FindFirstChild("HumanoidRootPart") then attackRemote:FireServer(target.HumanoidRootPart.Position)
                else attackRemote:FireServer() end
            end
        end
        task.wait(0.1)
    end
end)
SectionCombat1:Toggle({ Title = "Auto Attack (Slasher M1)", Default = false, Callback = function(v) autoAttackOn = v if v and not attackRemote then attackRemote = findRemote() end end })

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
                if isClose and target:FindFirstChild("HumanoidRootPart") then beheadRemote:FireServer(target.HumanoidRootPart.Position)
                else beheadRemote:FireServer() end
            end
        end
        task.wait(0.1)
    end
end)
SectionCombat1:Toggle({ Title = "Jason Behead", Default = false, Callback = function(v) autoBeheadOn = v if v and not beheadRemote then beheadRemote = findBeheadRemote() end end })

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
                if isClose and target:FindFirstChild("HumanoidRootPart") then subjectRemote:FireServer(target.HumanoidRootPart.Position)
                else subjectRemote:FireServer() end
            end
        end
        task.wait(0.2)
    end
end)
SectionCombat1:Toggle({ Title = "Subject_0 Attack", Default = false, Callback = function(v) autoSubjectOn = v if v and not subjectRemote then subjectRemote = findSubjectRemote() end end })

local DROP_DISTANCE = 35
local CAMERA_OFFSET = Vector3.new(0, 4.5, 10)
local TURN_SMOOTHNESS = 0.35
local currentTarget, isLocked = nil, false

local function isTargetValid(targetChar)
	if not targetChar or not targetChar.Parent or not targetChar:FindFirstChild("HumanoidRootPart") then return false end
	local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end
	local myChar = player.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		if (myChar.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude > DROP_DISTANCE then return false end
	end
	return true
end

local function disableLock() isLocked, currentTarget = false, nil RS:UnbindFromRenderStep("CamAndCharLockLoop") end
local function enableLock()
	isLocked = true
	RS:BindToRenderStep("CamAndCharLockLoop", Enum.RenderPriority.Camera.Value + 1, function()
		if not isLocked then return end
		local myChar = player.Character
		if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
		if not isTargetValid(currentTarget) then currentTarget = getClosestTarget() end
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local myRoot = myChar.HumanoidRootPart
			local myPos, targetPos = myRoot.Position, currentTarget.HumanoidRootPart.Position
			myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.lookAt(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z)), TURN_SMOOTHNESS)
			local flatDirection = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Unit
			if flatDirection.Magnitude == 0 then flatDirection = Vector3.new(0, 0, 1) end
			camera.CFrame = CFrame.lookAt(myPos - (flatDirection * CAMERA_OFFSET.Z) + Vector3.new(0, CAMERA_OFFSET.Y, 0), targetPos + Vector3.new(0, 1.5, 0))
		end
	end)
end
SectionCombat1:Toggle({ Title = "Camlock Target Focus", Default = false, Callback = function(v) if v then enableLock() else disableLock() end end })

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

local savedPos = Vector3.new(-1119.03, 894.94, -85.90)
local platform
SectionMovement:Button({
   Title = "Save Place (Platform TP)",
   Callback = function()
      local hrp = char and char:FindFirstChild("HumanoidRootPart")
      if not hrp then return end
      if not platform or not platform.Parent then
          platform = Instance.new("Part", workspace)
          platform.Size, platform.Position, platform.Anchored, platform.Color, platform.Material, platform.Name = Vector3.new(60, 5, 60), savedPos, true, Color3.fromRGB(120, 120, 120), Enum.Material.SmoothPlastic, "SafePlatform"
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
-- PART 6: GUEST1337 AUTO FARM (REMOTES & TARGET FIX)
--------------------------------------------------------------------------------

local guestAutoLowHp, guestAutoAll, stickToTargetOn, guestThreshold, guestHitOffset, guestSpeed = false, false, true, 20, 5.5, 16
local currentHardLockedTarget = nil

local function isAllowedCharacter(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")

    -- Check if target is alive and valid
    if not targetHum or not targetHrp or targetHum.Health <= 0 then
        return false
    end

    -- Allow all enemy players in workspace (bypasses restrictive whitelist errors)
    return true
end

local function findGuestRemote(possibleNames)
    for _, name in ipairs(possibleNames) do
        local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
        if charAbilities then
            local guestFolder = charAbilities:FindFirstChild("Guest1337", true) or charAbilities:FindFirstChild("Guest", true)
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

local punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack", "Punch", "MainAbility"})
local chargeRemote = findGuestRemote({"ChargeRemote", "Charge", "AltAbility1"})

RS.RenderStepped:Connect(function(deltaTime)
    if not (guestAutoLowHp or guestAutoAll) then return end
    local c = player.Character
    if not c then return end
    local h, hrp = c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
    if not h or not hrp then return end
    h.WalkSpeed = guestSpeed
    if h.MoveDirection.Magnitude > 0 then
        local move = h.MoveDirection * guestSpeed * deltaTime
        hrp.CFrame = hrp.CFrame + Vector3.new(move.X, 0, move.Z)
    end
end)

local function getClosestGuestTarget(lowHpOnly)
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local closest, shortest = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isAllowedCharacter(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                if not lowHpOnly or hum.Health <= guestThreshold then
                    local dist = (hrp.Position - myRoot.Position).Magnitude
                    if dist < shortest then 
                        shortest = dist
                        closest = p 
                    end
                end
            end
        end
    end
    return closest
end

task.spawn(function()
    while true do
        task.wait(0.03)
        if guestAutoLowHp or guestAutoAll then
            local lowHpOnly = guestAutoLowHp and not guestAutoAll
            local target = nil

            if stickToTargetOn then
                if currentHardLockedTarget and isAllowedCharacter(currentHardLockedTarget) then
                    target = currentHardLockedTarget
                else
                    currentHardLockedTarget = getClosestGuestTarget(lowHpOnly)
                    target = currentHardLockedTarget
                end
            else
                currentHardLockedTarget = nil
                target = getClosestGuestTarget(lowHpOnly)
            end

            if target and target.Character then
                local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

                if hrp and myHrp then
                    -- Position & Facing
                    local targetPos = hrp.Position
                    local lookAtPos = Vector3.new(targetPos.X, myHrp.Position.Y, targetPos.Z)
                    local offsetPos = hrp.CFrame * CFrame.new(0, 0, -guestHitOffset)
                    myHrp.CFrame = CFrame.lookAt(offsetPos.Position, lookAtPos)

                    -- Fire Remotes with multi-argument fallback
                    if not punchRemote then punchRemote = findGuestRemote({"GuestAttackRemote", "PunchRemote", "Attack", "Punch", "MainAbility"}) end
                    if not chargeRemote then chargeRemote = findGuestRemote({"ChargeRemote", "Charge", "AltAbility1"}) end

                    pcall(function()
                        if chargeRemote then
                            if chargeRemote:IsA("RemoteEvent") then
                                chargeRemote:FireServer(targetPos)
                                chargeRemote:FireServer()
                            end
                        end
                        if punchRemote then
                            if punchRemote:IsA("RemoteEvent") then
                                punchRemote:FireServer(targetPos)
                                punchRemote:FireServer()
                            end
                        end
                    end)
                end
            end
        else
            currentHardLockedTarget = nil
        end
    end
end)

local SectionGuestAutomation = GuestTab:Section({ Title = "Guest Auto Farm" })
local GuestLowHpToggle, GuestAllToggle

GuestLowHpToggle = SectionGuestAutomation:Toggle({
   Title = "Auto Farm Low HP Players",
   Default = false,
   Callback = function(v)
      guestAutoLowHp = v
      currentHardLockedTarget = nil
      if v and GuestAllToggle then GuestAllToggle:SetValue(false) end
   end,
})

GuestAllToggle = SectionGuestAutomation:Toggle({
   Title = "Auto Farm All Players",
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
