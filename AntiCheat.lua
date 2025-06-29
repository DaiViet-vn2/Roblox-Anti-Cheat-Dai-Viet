local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ADMIN_NAMES = {  
	["your username"] = true,
}   --Enter your admin or dev

local MAX_WALK_SPEED = 32
local MAX_JUMP_POWER = 70
local MAX_Y_POSITION = 1000
local MAX_TELEPORT_DISTANCE = 100

local function isSuspiciousChat(msg)
	msg = msg:lower()
	return msg:find(";fly") or msg:find(":fly") or msg:find(";tp") or msg:find(":tp")
end

local function kickPlayer(player, reason)
	player:Kick("Anti-Cheat: " .. reason)
	warn("Kicked " .. player.Name .. " for: " .. reason)
end

local function isBacon(player)
	local nameLower = player.Name:lower()
	local displayLower = player.DisplayName:lower()
	return nameLower == displayLower
end

local function monitorInactivity(player)
	local active = false
	local function markActive()
		active = true
	end

	player.Chatted:Connect(markActive)

	local function setupHumanoid(humanoid)
		humanoid.Running:Connect(markActive)
		humanoid.Jumping:Connect(markActive)
	end

	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then setupHumanoid(hum) end
	end

	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		setupHumanoid(hum)
	end)

	task.delay(60, function()
		if not active then
			kickPlayer(player, "Inactive / Bot suspected")
		end
	end)
end

local function detectLoopBehavior(player)
	player.CharacterAdded:Connect(function(char)
		local humanoid = char:WaitForChild("Humanoid")
		local lastTime = tick()
		local jumpCount = 0

		humanoid.Jumping:Connect(function()
			local now = tick()
			if now - lastTime < 1 then
				jumpCount += 1
			else
				jumpCount = 0
			end
			lastTime = now

			if jumpCount >= 10 then
				kickPlayer(player, "Jumping loop detected (bot-like)")
			end
		end)
	end)
end

local function setupCharacter(player, char)
	local humanoid = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")
	local lastPos = hrp.Position

	RunService.Heartbeat:Connect(function()
		if not player.Parent or not player.Character then return end

		local allowedSpeed = humanoid:GetAttribute("AllowedSpeed") or MAX_WALK_SPEED
		if humanoid.WalkSpeed > allowedSpeed then
			kickPlayer(player, "WalkSpeed too high: " .. humanoid.WalkSpeed)
		end

		local allowedJump = humanoid:GetAttribute("AllowedJump") or MAX_JUMP_POWER
		if humanoid.JumpPower > allowedJump then
			kickPlayer(player, "JumpPower too high: " .. humanoid.JumpPower)
		end

		local allowedY = humanoid:GetAttribute("AllowedMaxY") or MAX_Y_POSITION
		if hrp.Position.Y > allowedY then
			kickPlayer(player, "Flying too high: Y = " .. math.floor(hrp.Position.Y))
		end

		local distanceMoved = (hrp.Position - lastPos).Magnitude
		if distanceMoved > MAX_TELEPORT_DISTANCE then
			kickPlayer(player, "Teleport detected (" .. math.floor(distanceMoved) .. " studs)")
		end

		lastPos = hrp.Position
	end)
end

local function monitorPlayer(player)
	if ADMIN_NAMES[player.Name] then return end

	if player.Name == player.DisplayName then
		kickPlayer(player, "Suspicious: DisplayName == Username")
	end

	if isBacon(player) then
		kickPlayer(player, "Suspicious avatar (bacon)")
	end

	monitorInactivity(player)
	detectLoopBehavior(player)

	player.Chatted:Connect(function(msg)
		if isSuspiciousChat(msg) then
			kickPlayer(player, "Suspicious chat command: " .. msg)
		end
	end)

	if player.Character then
		setupCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
end

Players.PlayerAdded:Connect(monitorPlayer)
