local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local active = false
local autoAttack = true -- Automatically swings/activates equipped tools
local targetIndex = 0
local targetPlayer = nil
local originalCameraSubject = nil
local renderConnection = nil
local attackLoop = nil
local smoothedOffset = 0

-- Offset tuning (adjusted so hitboxes actually reach)
local BASE_DEPTH = 3.5 -- Closer to feet so melee reach connects
local BASE_FORWARD = 2.0
local MAX_EXTRA_STUDS = 4
local WALK_SPEED = 12
local RUN_SPEED = 28

-- Screen GUI
local gui = Instance.new("ScreenGui")
gui.Name = "UndergroundGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.fromScale(0.2, 0.08)
button.Position = UDim2.fromScale(0.4, 0.88)
button.Text = "Activate Farm"
button.TextScaled = true
button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
button.TextColor3 = Color3.new(1, 1, 1)
button.BorderSizePixel = 0
button.Parent = gui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = button

local status = Instance.new("TextLabel")
status.Size = UDim2.fromScale(0.3, 0.05)
status.Position = UDim2.fromScale(0.35, 0.82)
status.Text = "Inactive"
status.TextScaled = true
status.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
status.TextColor3 = Color3.fromRGB(255, 100, 100)
status.BorderSizePixel = 0
status.Parent = gui

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = status

local leftBtn = Instance.new("TextButton")
leftBtn.Size = UDim2.fromScale(0.07, 0.08)
leftBtn.Position = UDim2.fromScale(0.32, 0.88)
leftBtn.Text = "◀"
leftBtn.TextScaled = true
leftBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 130)
leftBtn.TextColor3 = Color3.new(1, 1, 1)
leftBtn.BorderSizePixel = 0
leftBtn.Visible = false
leftBtn.Parent = gui

local leftCorner = Instance.new("UICorner")
leftCorner.CornerRadius = UDim.new(0, 10)
leftCorner.Parent = leftBtn

local rightBtn = Instance.new("TextButton")
rightBtn.Size = UDim2.fromScale(0.07, 0.08)
rightBtn.Position = UDim2.fromScale(0.61, 0.88)
rightBtn.Text = "▶"
rightBtn.TextScaled = true
rightBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 130)
rightBtn.TextColor3 = Color3.new(1, 1, 1)
rightBtn.BorderSizePixel = 0
rightBtn.Visible = false
rightBtn.Parent = gui

local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 10)
rightCorner.Parent = rightBtn

local function getSafeSpawn()
	local spawnCFrame = CFrame.new(0, 5, 0)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			spawnCFrame = obj.CFrame + Vector3.new(0, 5, 0)
			break
		end
	end
	return spawnCFrame
end

local function restoreCharacter()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then return end

	local spawnCFrame = getSafeSpawn()
	if originalCameraSubject then
		camera.CameraSubject = originalCameraSubject
		camera.CameraType = Enum.CameraType.Custom
	end

	rootPart.Anchored = true
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	local frames = 0
	local returnLoop
	returnLoop = RunService.RenderStepped:Connect(function()
		frames = frames + 1
		rootPart.CFrame = spawnCFrame
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		if frames >= 8 then
			rootPart.Anchored = false
			returnLoop:Disconnect()
		end
	end)
end

-- Filter only living targets
local function getTargets()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(t, p)
			end
		end
	end
	return t
end

local function updateStatus()
	local list = getTargets()
	if #list == 0 then
		targetPlayer = nil
		status.Text = "Looking for targets..."
		status.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end
	if targetIndex < 1 then targetIndex = #list end
	if targetIndex > #list then targetIndex = 1 end
	targetPlayer = list[targetIndex]
	status.Text = "[" .. targetIndex .. "/" .. #list .. "] " .. targetPlayer.Name
	status.TextColor3 = Color3.fromRGB(100, 255, 100)
end

local function goNext()
	local list = getTargets()
	if #list == 0 then targetPlayer = nil status.Text = "Looking for targets..." return end
	targetIndex = targetIndex + 1
	if targetIndex > #list then targetIndex = 1 end
	smoothedOffset = 0
	updateStatus()
end

local function goPrev()
	local list = getTargets()
	if #list == 0 then targetPlayer = nil status.Text = "Looking for targets..." return end
	targetIndex = targetIndex - 1
	if targetIndex < 1 then targetIndex = #list end
	smoothedOffset = 0
	updateStatus()
end

-- Auto-Equip & Auto-Swing routine
local function startAttacking()
	if attackLoop then task.cancel(attackLoop) end
	attackLoop = task.spawn(function()
		while active do
			task.wait(0.08)
			if not autoAttack or not targetPlayer then continue end

			local char = player.Character
			if not char then continue end

			-- 1. Look for currently equipped tool
			local tool = char:FindFirstChildOfClass("Tool")

			-- 2. If nothing equipped, equip the first tool from backpack
			if not tool and player:FindFirstChild("Backpack") then
				local bpTool = player.Backpack:FindFirstChildOfClass("Tool")
				if bpTool then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:EquipTool(bpTool)
						tool = bpTool
					end
				end
			end

			-- 3. Activate tool
			if tool then
				tool:Activate()
			end
		end
	end)
end

local function deactivate()
	active = false
	button.Text = "Activate Farm"
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	status.Text = "Inactive"
	status.TextColor3 = Color3.fromRGB(255, 100, 100)
	leftBtn.Visible = false
	rightBtn.Visible = false
	targetPlayer = nil
	smoothedOffset = 0

	if attackLoop then
		task.cancel(attackLoop)
		attackLoop = nil
	end

	local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if myHum then
		camera.CameraSubject = myHum
		camera.CameraType = Enum.CameraType.Custom
	end

	restoreCharacter()
end

button.MouseButton1Click:Connect(function()
	if not active then
		active = true
		button.Text = "Deactivate"
		button.BackgroundColor3 = Color3.fromRGB(130, 50, 50)
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			originalCameraSubject = char.Humanoid
		end
		leftBtn.Visible = true
		rightBtn.Visible = true
		targetIndex = 1
		updateStatus()
		startAttacking()
	else
		deactivate()
	end
end)

button.MouseButton2Click:Connect(function()
	if active then deactivate() end
end)

rightBtn.MouseButton1Click:Connect(function() if active then goNext() end end)
leftBtn.MouseButton1Click:Connect(function() if active then goPrev() end end)

-- Main tracking loop
renderConnection = RunService.RenderStepped:Connect(function()
	if not active then return end

	-- Check if current target died or became invalid
	if targetPlayer then
		local tChar = targetPlayer.Character
		local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
		if not tChar or not tHum or tHum.Health <= 0 or not tChar:FindFirstChild("HumanoidRootPart") then
			goNext()
			return
		end
	else
		updateStatus()
		return
	end

	local myChar = player.Character
	local targetChar = targetPlayer.Character
	if not myChar or not targetChar then return end

	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	local targetHum = targetChar:FindFirstChildOfClass("Humanoid")

	if myRoot and targetRoot and targetHum and targetHum.Health > 0 then
		-- Noclip while active so ground collision doesn't cancel attacks or fling you
		for _, part in ipairs(myChar:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end

		-- Dynamic velocity prediction
		local velocity = targetRoot.AssemblyLinearVelocity
		local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = horizontalVelocity.Magnitude
		local moveDirection = speed > 0.5 and horizontalVelocity.Unit or targetRoot.CFrame.LookVector

		local movingOffset = 0
		if speed > WALK_SPEED then
			movingOffset = math.clamp((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0, 1) * MAX_EXTRA_STUDS
		elseif speed > 0.5 then
			movingOffset = math.clamp(speed / WALK_SPEED, 0, 1) * (MAX_EXTRA_STUDS * 0.3)
		end

		local lerpSpeed = movingOffset > smoothedOffset and 0.15 or 0.05
		smoothedOffset = smoothedOffset + (movingOffset - smoothedOffset) * lerpSpeed

		-- Check ground beneath the target to handle elevated surfaces or jumping
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {targetChar, myChar}
		rayParams.FilterType = RaycastFilterType.Exclude

		local floorRay = Workspace:Raycast(targetRoot.Position, Vector3.new(0, -60, 0), rayParams)
		local effectiveFloorY = floorRay and floorRay.Position.Y or (targetRoot.Position.Y - 3)

		-- Match target altitude when elevated/airborne
		local targetElevation = targetRoot.Position.Y - effectiveFloorY
		local depth = BASE_DEPTH
		if targetElevation > 3 then
			-- Float up to stay within attack distance
			depth = math.max(0.5, BASE_DEPTH - (targetElevation * 0.8))
		end

		local pos = targetRoot.Position + (moveDirection * (BASE_FORWARD + smoothedOffset)) - Vector3.new(0, depth, 0)
		
		-- Look up directly at the target's torso/head so directional weapons connect
		local lookTarget = targetRoot.Position + Vector3.new(0, 1, 0)

		myRoot:PivotTo(CFrame.lookAt(pos, lookTarget))
		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.AssemblyAngularVelocity = Vector3.zero
	end

	if targetHum and targetHum.Health > 0 then
		camera.CameraSubject = targetHum
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if p == targetPlayer then goNext() end
end)

local function hookDeath(character)
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		if active then deactivate() end
	end)
end

if player.Character then hookDeath(player.Character) end
player.CharacterAdded:Connect(hookDeath)
