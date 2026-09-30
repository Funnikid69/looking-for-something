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
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/main.lua"))()

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
    OpenButton = {
        Title = "Open Hub",
        CornerRadius = UDim2.new(1, 0),
        Enabled = true,
        Draggable = true,
    }
})

--// TABS
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
-- PART 2: ANIMATION, ACTION & AUTO-FARM SYSTEM
--------------------------------------------------------------------------------

-- ANIMATION & ACTION HANDLER
local function playShedletskyAnim()
	if not char or not hum then return end
	local anim = Instance.new("Animation")
	local skin = char:GetAttribute("Skin")
	local actualSkin = char:GetAttribute("ActualSkin")

	if skin == "RetroShed" then anim.AnimationId = "rbxassetid://84906874339359"
	elseif skin == "M100Shed" or skin == "M75Shed" then anim.AnimationId = "rbxassetid://72661064392418"
	elseif skin == "BusterShedletsky" then anim.AnimationId = "rbxassetid://102735588255002"
	elseif skin == "ButcherShedletsky" then anim.AnimationId = "rbxassetid://83703568665249"
	elseif skin == "NessShedletsky" or skin == "Scout" then anim.AnimationId = "rbxassetid://117635960799966"
	elseif skin == "Targetman" then anim.AnimationId = "rbxassetid://117814766896269"
	elseif skin == "SCP" then anim.AnimationId = "rbxassetid://113516249240896"
	elseif skin == "Snyfort" or skin == "Pastelbeat" or skin == "Upbeat" or skin == "SoapyDX" or skin == "SoapyDXLegacy" or skin == "DownTunes" then anim.AnimationId = "rbxassetid://115680124099922"
	elseif skin == "Pastello" and (actualSkin ~= "Pastello3" and actualSkin ~= "Pastello4") then anim.AnimationId = "rbxassetid://79130710510782"
	elseif skin == "Pastello" and actualSkin == "Pastello3" then anim.AnimationId = "rbxassetid://99539026106525"
	elseif skin == "Pastello" and actualSkin == "Pastello4" then anim.AnimationId = "rbxassetid://115470481199645"
	elseif skin == "GoldenShedletsky" then anim.AnimationId = "rbxassetid://94865308722467"
	elseif skin == "TillDawnShedletsky" then anim.AnimationId = "rbxassetid://112474546068323"
	elseif skin == "Blega" then anim.AnimationId = "rbxassetid://74816403474613"
	elseif skin == "SoapyDX4" then anim.AnimationId = "rbxassetid://122628818808958"
	elseif skin == "VIPShed" then anim.AnimationId = "rbxassetid://80100528383027"
	else anim.AnimationId = "rbxassetid://107302018639039" end

	local track = hum:LoadAnimation(anim)
	track:Play()

	local conn
	conn = char:GetAttributeChangedSignal("HitSlash"):Connect(function()
		if char:GetAttribute("HitSlash") and skin ~= "Blega" then
			track:Stop()
			local hitAnim = Instance.new("Animation")
			hitAnim.AnimationId = "rbxassetid://104029412142861"
			hum:LoadAnimation(hitAnim):Play()
			if conn then conn:Disconnect() end
		end
	end)
end

local function playNoliAnim()
	if not char or not hum then return end
	local anim = Instance.new("Animation")
	local skin = char:GetAttribute("Skin")

	if skin == "RetroNoli" then anim.AnimationId = "rbxassetid://120515916154475"
	elseif skin == "Clockwork" then anim.AnimationId = "rbxassetid://108021827965381"
	elseif skin == "NarratorNoli" then anim.AnimationId = "rbxassetid://128744951510910"
	elseif skin == "Noli4" then anim.AnimationId = "rbxassetid://98438228576241"
	elseif skin == "EvilTeh" then anim.AnimationId = "rbxassetid://97930480559280"
	elseif skin == "AdminNoli" then anim.AnimationId = "rbxassetid://126706312443717"
	elseif skin == "Pastway" or skin == "Fleatway" then anim.AnimationId = "rbxassetid://105540391527912"
	else anim.AnimationId = "rbxassetid://133721031387826" end

	local track = hum:LoadAnimation(anim)
	track:Play()
	track:AdjustSpeed(1.5)
end

local function castCharacterAction(actionName, targetPosition)
	if not canUseCharacter() then return end
	local cType = getCurrentCharacterType()
	local abilityTable = ((cType == "Jason" or cType == "Slasher") and JasonAbilities) or (cType == "Shedletsky" and ShedletskyAbilities) or (cType == "Noli" and NoliAbilities)

	if not abilityTable then return end
	local data = abilityTable[actionName]

	if data and data.Remote then
		local now = os.clock()
		if now - data.LastUsed >= data.Cooldown then
			data.LastUsed = now

			if cType == "Shedletsky" and actionName == "Slash" then
				playShedletskyAnim()
			elseif cType == "Noli" and actionName == "MainAbility" then
				playNoliAnim()
			end

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
-- TARGET DETECTION & POSITIONING
--------------------------------------------------------------------------------
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
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	local offset = hitDistanceOffset

	if lockInFrontOn then
		myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -offset) * CFrame.Angles(0, math.pi, 0)
	else
		myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, offset)
	end
end

--------------------------------------------------------------------------------
-- UNBROKEN STICKY POSITIONING LOOP (STEPS EVERY FRAME)
--------------------------------------------------------------------------------
RS.Stepped:Connect(function()
	if not autoFarmLowHpOn and not autoFarmAllOn then return end
	if not char or not hum or hum.Health <= 0 then return end

	local activeTarget = nil

	if autoFarmLowHpOn then
		activeTarget = getLowHpTarget(targetHealthThreshold)
	elseif autoFarmAllOn then
		activeTarget = getAnyTarget()
	end

	if activeTarget and isTargetAliveAndValid(activeTarget) then
		positionAtTarget(activeTarget)
	end
end)

--------------------------------------------------------------------------------
-- AUTO FARM HEARTBEAT LOOP (FIRE ABILITIES ONLY WHEN NEARBY)
--------------------------------------------------------------------------------
RS.Heartbeat:Connect(function()
	if char and getCurrentCharacterType() == "Shedletsky" then
		char:SetAttribute("CanRun", true)
		char:SetAttribute("Slowed", false)
		if hum and hum.WalkSpeed < 16 then
			hum.WalkSpeed = 16
		end
	end

	if not autoFarmLowHpOn and not autoFarmAllOn then return end

	if hum and hum.Health <= 30 then
		if autoFarmLowHpOn and LowHpToggle then LowHpToggle:SetValue(false) end
		if autoFarmAllOn and AllPlayersToggle then AllPlayersToggle:SetValue(false) end
		autoFarmLowHpOn = false
		autoFarmAllOn = false
		currentLockedTarget = nil
		teleportToSafeSpace()
		return
	end

	local cType = getCurrentCharacterType()
	local autoList = ((cType == "Jason" or cType == "Slasher") and JASON_AUTO_ABILITIES) 
		or (cType == "Shedletsky" and SHEDLETSKY_AUTO_ABILITIES) 
		or (cType == "Noli" and NOLI_AUTO_ABILITIES) 
		or {}

	local abilityTable = ((cType == "Jason" or cType == "Slasher") and JasonAbilities) 
		or (cType == "Shedletsky" and ShedletskyAbilities) 
		or (cType == "Noli" and NoliAbilities) 
		or {}

	local targetP = currentLockedTarget
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")

	if targetP and isTargetAliveAndValid(targetP) and myRoot then
		local tRoot = targetP.Character:FindFirstChild("HumanoidRootPart")
		if tRoot then
			local distance = (tRoot.Position - myRoot.Position).Magnitude

			if distance <= MAX_ABILITY_DISTANCE and canUseCharacter() then
				for _, abilityName in ipairs(autoList) do
					local data = abilityTable[abilityName]
					if data and (os.clock() - data.LastUsed >= data.Cooldown) then
						castCharacterAction(abilityName, tRoot.Position)
					end
				end
			end
		end
	else
		currentLockedTarget = nil
		teleportToSafeSpace()
	end
end)

--------------------------------------------------------------------------------
-- AUTO FARM TAB ELEMENTS (WINDUI SYNTAX)
--------------------------------------------------------------------------------
AutoFarmTab:Section({ Title = "Targeting Options" })

AutoFarmTab:Toggle({
   Title = "Lock in Front of Person",
   Value = false,
   Callback = function(value)
      lockInFrontOn = value
   end,
})

AutoFarmTab:Toggle({
   Title = "Stick to Person?",
   Value = false,
   Callback = function(value)
      stickToPersonOn = value
      if not value then currentLockedTarget = nil end
   end,
})

AutoFarmTab:Dropdown({
   Title = "Position Offset (Hit Range)",
   Values = {"Close (~3 studs)", "Slightly Far (~5.5 studs)", "Far (~8 studs)"},
   Value = "Close (~3 studs)",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      if selected:find("Slightly Far") then
         hitDistanceOffset = 5.5
      elseif selected:find("Far") then
         hitDistanceOffset = 8
      else
         hitDistanceOffset = 3
      end
   end,
})

AutoFarmTab:Section({ Title = "Auto Farm Automation" })

LowHpToggle = AutoFarmTab:Toggle({
   Title = "Auto Farm Low Health Players",
   Value = false,
   Callback = function(value)
      autoFarmLowHpOn = value
      if value and AllPlayersToggle then AllPlayersToggle:SetValue(false) end
      if not value then currentLockedTarget = nil end
   end,
})

AllPlayersToggle = AutoFarmTab:Toggle({
   Title = "Auto Farm All Players",
   Value = false,
   Callback = function(value)
      autoFarmAllOn = value
      if value and LowHpToggle then LowHpToggle:SetValue(false) end
      if not value then currentLockedTarget = nil end
   end,
})

AutoFarmTab:Dropdown({
   Title = "Low HP Target Threshold",
   Values = {"10 HP", "20 HP", "30 HP", "50 HP"},
   Value = "20 HP",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      local val = tonumber(string.match(selected, "%d+"))
      if val then targetHealthThreshold = val end
   end,
})

AutoFarmTab:Section({ Title = "Emergency Safety" })

AutoFarmTab:Button({
   Title = "Teleport to Safe Space",
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
-- WINDUI ELEMENTS (ESP TAB)
--------------------------------------------------------------------------------
ESPTab:Section({ Title = "ESP Visuals" })

ESPTab:Toggle({
   Title = "Role ESP (Blue Survivor / Red Killer)",
   Value = false,
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
-- COMBAT TAB
--------------------------------------------------------------------------------

-- Maximum distance (in studs) required for auto-aim to trigger
local AIM_DISTANCE = 30 

-- Helper function to verify if the player's current character matches a name/type
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

-- Helper function to find the closest valid target player
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

-- Helper to make the player automatically face the target ONLY if within close distance
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

-- 1. Auto Attack (Slasher M1)
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

CombatTab:Toggle({
   Title = "Auto Attack (Slasher M1 - OP)",
   Value = false,
   Callback = function(value)
      autoAttackOn = value
      if value and not attackRemote then attackRemote = findRemote() end
   end,
})

-- 2. Jason Behead
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

CombatTab:Toggle({
   Title = "Jason Behead",
   Value = false,
   Callback = function(value)
      autoBeheadOn = value
      if value and not beheadRemote then beheadRemote = findBeheadRemote() end
   end,
})

-- 3. Subject_0 Attack
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

CombatTab:Toggle({
   Title = "Subject_0 Attack",
   Value = false,
   Callback = function(value)
      autoSubjectOn = value
      if value and not subjectRemote then subjectRemote = findSubjectRemote() end
   end,
})

-- 4. Noli Attack
local autoNoliOn = false
local function findNoliRemote()
    local remote = ReplicatedStorage:FindFirstChild("NoliAttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local noliFolder = charAbilities:FindFirstChild("Noli", true)
        if noliFolder then return noliFolder:FindFirstChild("NoliAttackRemote", true) end
    end
    return nil
end
local noliRemote = findNoliRemote()

task.spawn(function()
    while true do
        if autoNoliOn and isMatchingCharacter("Noli") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not noliRemote then noliRemote = findNoliRemote() end
            if noliRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    noliRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    noliRemote:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

CombatTab:Toggle({
   Title = "Noli Attack",
   Value = false,
   Callback = function(value)
      autoNoliOn = value
      if value and not noliRemote then noliRemote = findNoliRemote() end
   end,
})

-- 5. John Doe Attack
local autoJohnDoeOn = false
local function findJohnDoeRemote()
    local remote = ReplicatedStorage:FindFirstChild("JohnDoeAttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local johnDoeFolder = charAbilities:FindFirstChild("JohnDoe", true)
        if johnDoeFolder then return johnDoeFolder:FindFirstChild("JohnDoeAttackRemote", true) end
    end
    return nil
end
local johnDoeRemote = findJohnDoeRemote()

task.spawn(function()
    while true do
        if autoJohnDoeOn and isMatchingCharacter("JohnDoe") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not johnDoeRemote then johnDoeRemote = findJohnDoeRemote() end
            if johnDoeRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    johnDoeRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    johnDoeRemote:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

CombatTab:Toggle({
   Title = "John Doe Attack",
   Value = false,
   Callback = function(value)
      autoJohnDoeOn = value
      if value and not johnDoeRemote then johnDoeRemote = findJohnDoeRemote() end
   end,
})

-- 6. Auto 1x4 Mass Infection
local autoMassInfectionOn = false
local function findMassInfectionRemote()
    local remote = ReplicatedStorage:FindFirstChild("MassInfection", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local folder1x4 = charAbilities:FindFirstChild("1x4", true)
        if folder1x4 then return folder1x4:FindFirstChild("MassInfection", true) end
    end
    return nil
end
local massInfectionRemote = findMassInfectionRemote()

task.spawn(function()
    while true do
        if autoMassInfectionOn and isMatchingCharacter("1x4") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not massInfectionRemote then massInfectionRemote = findMassInfectionRemote() end
            if massInfectionRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    massInfectionRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    massInfectionRemote:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

CombatTab:Toggle({
   Title = "Auto 1x4 Mass Infection",
   Value = false,
   Callback = function(value)
      autoMassInfectionOn = value
      if value and not massInfectionRemote then massInfectionRemote = findMassInfectionRemote() end
   end,
})

-- 7. Camlock Target Focus
local ACTIVATION_DISTANCE = 25
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

CombatTab:Toggle({
   Title = "Camlock Target Focus",
   Value = false,
   Callback = function(value)
      if value then enableLock() else disableLock() end
   end,
})

-- 8. Additional Attack Loops (Coolkid & 1x4 Fast Cast)
CombatTab:Section({ Title = "Additional Attack Loops" })

local coolkidAutoOn = false
local auto1x4On = false

local function findCoolkidRemote()
    local remote = ReplicatedStorage:FindFirstChild("CoolkidAttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local coolkidFolder = charAbilities:FindFirstChild("Coolkid", true)
        if coolkidFolder then return coolkidFolder:FindFirstChild("CoolkidAttackRemote", true) end
    end
    return nil
end

local function find1x4Remote()
    local remote = ReplicatedStorage:FindFirstChild("1x4AttackRemote", true)
    if remote then return remote end
    local charAbilities = ReplicatedStorage:FindFirstChild("CharacterAbilities", true)
    if charAbilities then
        local folder1x4 = charAbilities:FindFirstChild("1x4", true)
        if folder1x4 then return folder1x4:FindFirstChild("1x4AttackRemote", true) end
    end
    return nil
end

local coolkidRemote = findCoolkidRemote()
local remote1x4 = find1x4Remote()

task.spawn(function()
    while true do
        if coolkidAutoOn and isMatchingCharacter("Coolkid") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)
            
            if not coolkidRemote then coolkidRemote = findCoolkidRemote() end
            if coolkidRemote then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    coolkidRemote:FireServer(target.HumanoidRootPart.Position)
                else
                    coolkidRemote:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        if auto1x4On and isMatchingCharacter("1x4") then
            local target = getClosestTarget()
            local isClose = target and aimAtTarget(target)

            if not remote1x4 then remote1x4 = find1x4Remote() end
            if remote1x4 then 
                if isClose and target:FindFirstChild("HumanoidRootPart") then
                    remote1x4:FireServer(target.HumanoidRootPart.Position)
                else
                    remote1x4:FireServer()
                end
            end
        end
        task.wait(0.2)
    end
end)

CombatTab:Toggle({
   Title = "Coolkid Fast Cast",
   Value = false,
   Callback = function(value)
      coolkidAutoOn = value
      if value and not coolkidRemote then coolkidRemote = findCoolkidRemote() end
   end,
})

CombatTab:Toggle({
   Title = "1x4 Fast Cast",
   Value = false,
   Callback = function(value)
      auto1x4On = value
      if value and not remote1x4 me remote1x4 = find1x4Remote() end
   end,
})

--------------------------------------------------------------------------------
-- UTILITY TAB
--------------------------------------------------------------------------------
local tpwalkOn = false
local speed = 1

UtilityTab:Toggle({
   Title = "TpWalk",
   Value = false,
   Callback = function(value)
      tpwalkOn = value
   end,
})

UtilityTab:Slider({
   Title = "TpWalk Speed",
   Min = 1,
   Max = 10,
   Step = 1,
   Value = 1,
   Callback = function(value)
      speed = value
   end,
})

RS.RenderStepped:Connect(function()
    if tpwalkOn and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local hrp = char.HumanoidRootPart
        local move = char.Humanoid.MoveDirection
        hrp.CFrame = hrp.CFrame + (move * speed)
    end
end)

local savedPos = Vector3.new(-1119.03076171875, 894.944580078125, -85.89985656738281)
local platform

UtilityTab:Button({
   Title = "Save Place (Platform TP)",
   Callback = function()
      local hrp = char and char:FindFirstChild("HumanoidRootPart")
      if not hrp then return end
      if not platform then
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
-- PART 5: LOW HEALTH PROTECTION & TELEPORTER TAB
--------------------------------------------------------------------------------

-- 1. LOW HEALTH PROTECTION (Movement & Misc Tab)
local lowHealthProtectionOn = false
local healthThreshold = 40
local protectionPlatform = nil
local safePosition = Vector3.new(-1119.03, 894.94, -85.90)

UtilityTab:Section({ Title = "Safety & Protection" })

UtilityTab:Toggle({
   Title = "Low Health Auto-Teleport",
   Value = false,
   Callback = function(value)
      lowHealthProtectionOn = value
   end,
})

UtilityTab:Slider({
   Title = "Health Threshold",
   Min = 10,
   Max = 80,
   Step = 5,
   Value = 40,
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
                end
            end
        end
    end
end)

-- 2. PLAYER TELEPORTER (Dedicated TeleportTab)
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

TeleportTab:Section({ Title = "Player Teleporter" })

local PlayerDropdown = TeleportTab:Dropdown({
   Title = "Select Target Player",
   Values = playerDropdownOptions,
   Value = playerDropdownOptions[1] or "No Other Players",
   Callback = function(option)
      local selected = typeof(option) == "table" and option[1] or option
      selectedPlayer = playerMap[selected]
   end,
})

local function refreshDropdown()
    updatePlayerList()
    if PlayerDropdown and PlayerDropdown.Refresh then
        PlayerDropdown:Refresh(playerDropdownOptions, playerDropdownOptions[1])
    end
end

Players.PlayerAdded:Connect(refreshDropdown)
Players.PlayerRemoving:Connect(function(p)
    if selectedPlayer == p then
        selectedPlayer = nil
        stickInFrontOn = false
    end
    refreshDropdown()
end)

TeleportTab:Button({
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

TeleportTab:Toggle({
   Title = "Stick in Front of Player",
   Value = false,
   Callback = function(value)
      stickInFrontOn = value
   end,
})

TeleportTab:Slider({
   Title = "Stick Distance Offset",
   Min = 2,
   Max = 25,
   Step = 0.5,
   Value = 5.5,
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
-- PART 6: GUEST1337 CONTROLLER (GUEST1337 TAB)
--------------------------------------------------------------------------------

-- Remote Event/Function Finder for Guest1337
local function findRemote(possibleNames)
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

local punchRemote = findRemote({"GuestAttackRemote", "PunchRemote", "Attack"})
local chargeRemote = findRemote({"ChargeRemote", "Charge"})

-- State variables
local isPunchLooping = false
local isChargeLooping = false
local isComboLooping = false
local isAimingEnabled = false
local loopDelay = 0
local targetSpeed = 16

-- Helper to find nearest player character
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

-- Aim at nearest target
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

-- Helper to execute remote safely based on class type
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

-- Movement Enforcement
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

-- Loop Tasks
task.spawn(function()
    while true do
        if isPunchLooping then
            if not punchRemote then punchRemote = findRemote({"GuestAttackRemote", "PunchRemote", "Attack"}) end
            safeTriggerRemote(punchRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

task.spawn(function()
    while true do
        if isChargeLooping then
            if not chargeRemote then chargeRemote = findRemote({"ChargeRemote", "Charge"}) end
            safeTriggerRemote(chargeRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

task.spawn(function()
    while true do
        if isComboLooping then
            if not punchRemote then punchRemote = findRemote({"GuestAttackRemote", "PunchRemote", "Attack"}) end
            if not chargeRemote then chargeRemote = findRemote({"ChargeRemote", "Charge"}) end
            
            safeTriggerRemote(chargeRemote)
            safeTriggerRemote(punchRemote)
        end
        if loopDelay > 0 then task.wait(loopDelay) else task.wait(0.05) end
    end
end)

-- UI Setup (WindUI Standard)
GuestTab:Section({ Title = "Guest Loops" })

GuestTab:Toggle({
   Title = "Punch Loop",
   Value = false,
   Callback = function(value)
      isPunchLooping = value
   end,
})

GuestTab:Toggle({
   Title = "Charge Loop",
   Value = false,
   Callback = function(value)
      isChargeLooping = value
   end,
})

GuestTab:Toggle({
   Title = "Both Loop (Combo)",
   Value = false,
   Callback = function(value)
      isComboLooping = value
   end,
})

GuestTab:Section({ Title = "Targeting & Delay" })

GuestTab:Toggle({
   Title = "Aim Nearest",
   Value = false,
   Callback = function(value)
      isAimingEnabled = value
   end,
})

GuestTab:Input({
   Title = "Loop Delay (Seconds)",
   Placeholder = "0",
   Callback = function(text)
      local newDelay = tonumber(text)
      if newDelay and newDelay >= 0 then
         loopDelay = newDelay
      end
   end,
})
