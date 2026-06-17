
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))

local CameraClient = {}

CameraClient.Mode = "TPS"
CameraClient.BaseZoom = nil
CameraClient.CameraEffects = {}

CameraClient.Spectating = false
CameraClient.SpectateTarget = nil
CameraClient.SpectateIndex = 1
CameraClient.SpectateMode = "ThirdPerson"

function CameraClient.EnterSpectate()
	CameraClient.Spectating = true
	CameraClient.SpectateIndex = 1
	CameraClient.SpectateMode = "ThirdPerson"
	CameraClient.FindNextSpectateTarget()
end

function CameraClient.ExitSpectate()
	CameraClient.Spectating = false
	CameraClient.SpectateTarget = nil
end

function CameraClient.FindNextSpectateTarget()
	local heroes = ClientCore.State.heroes or {}
	local aliveHeroes = {}
	for _, h in pairs(heroes) do
		if h.teamId == ClientCore.State.teamId and h.alive then
			table.insert(aliveHeroes, h)
		end
	end
	if #aliveHeroes == 0 then
		CameraClient.SpectateTarget = nil
		return
	end
	CameraClient.SpectateIndex = (CameraClient.SpectateIndex % #aliveHeroes) + 1
	local target = aliveHeroes[CameraClient.SpectateIndex]
	CameraClient.SpectateTarget = target
end

function CameraClient.ToggleSpectateMode()
	if CameraClient.SpectateMode == "ThirdPerson" then
		CameraClient.SpectateMode = "FirstPerson"
	else
		CameraClient.SpectateMode = "ThirdPerson"
	end
end

-- Camera shake state
CameraClient.ShakeIntensity = 0
CameraClient.ShakeDuration = 0
CameraClient.ShakeTime = 0

function CameraClient.ToggleMode()
	CameraClient.Mode = (CameraClient.Mode == "TPS") and "FPS" or "TPS"
end

function CameraClient.AddShake(intensity, duration)
	if intensity > CameraClient.ShakeIntensity then
		CameraClient.ShakeIntensity = intensity
		CameraClient.ShakeDuration = duration
		CameraClient.ShakeTime = 0
	elseif os.clock() - CameraClient.ShakeTime < CameraClient.ShakeDuration then
		CameraClient.ShakeTime = os.clock()
	end
end

function CameraClient.ApplyEffect(effectName, intensity, duration)
	CameraClient.CameraEffects[effectName] = {
		intensity = intensity or 1,
		expireAt = os.clock() + (duration or 1),
	}
end

function CameraClient.Init()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable

	CameraClient.BaseZoom = 8
	CameraClient.Yaw = 0
	CameraClient.Pitch = -15

	local aimPart = Instance.new("Part")
	aimPart.Name = "CameraAimHelper"
	aimPart.Size = Vector3.new(0.1, 0.1, 0.1)
	aimPart.Transparency = 1
	aimPart.Anchored = true
	aimPart.CanCollide = false
	aimPart.Parent = workspace

	RunService.RenderStepped:Connect(function(dt)
		-- Mouse: free in menus, locked center (with visible icon) during gameplay
		local ms = ClientCore.State.matchState
		if CameraClient.Spectating or (ms ~= "ActiveMatch" and ms ~= "SuddenDeath" and ms ~= "MatchCountdown") then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		UserInputService.MouseIconEnabled = true

		-- Spectator camera
		if CameraClient.Spectating then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			if CameraClient.SpectateTarget then
				local targetPos = CameraClient.SpectateTarget.position or CameraClient.SpectateTarget.rootPosition or Vector3.new(0, 5, 0)
				if CameraClient.SpectateMode == "FirstPerson" then
					camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0), targetPos + (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector * 10 or Vector3.new(0, 0, -10)))
				else
					local offset = Vector3.new(math.sin(tick() * 0.5) * 6, 4, math.cos(tick() * 0.5) * 6)
					camera.CFrame = CFrame.new(targetPos + offset, targetPos)
				end
			else
				local speed = 30
				local dir = Vector3.new(
					(UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
					(UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0),
					(UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
				)
				if dir.Magnitude > 0 then
					camera.CFrame = camera.CFrame + dir.Unit * speed * dt
				end
			end
			return
		end

		local character = Players.LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return end

		-- Mouse delta rotates camera (yaw + pitch)
		local mouseDelta = UserInputService:GetMouseDelta()
		local sensitivity = 0.002
		CameraClient.Yaw = CameraClient.Yaw - mouseDelta.X * sensitivity
		CameraClient.Pitch = math.clamp(CameraClient.Pitch - mouseDelta.Y * sensitivity, -80, 80)

		-- Player movement relative to camera yaw
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local yaw = CameraClient.Yaw
			local camForward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
			local camRight = Vector3.new(-math.cos(yaw), 0, math.sin(yaw))

			local moveDir = Vector3.new(0, 0, 0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camForward end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camForward end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camRight end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camRight end

			if moveDir.Magnitude > 0 then
				humanoid:Move(moveDir.Unit, false)
				-- Rotate character to face movement direction
				root.CFrame = CFrame.new(root.Position, root.Position + moveDir.Unit)
			else
				humanoid:Move(Vector3.new(0, 0, 0), false)
				-- When idle, face camera direction
				local lookDir = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
				root.CFrame = CFrame.new(root.Position, root.Position + lookDir)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				humanoid.Jump = true
			end
		end

		-- Camera positioning
		local zoom = CameraClient.BaseZoom or 8
		local yaw = CameraClient.Yaw
		local pitch = CameraClient.Pitch
		local lookAt = root.Position + Vector3.new(0, 2, 0)

		-- Calculate orbit position from yaw/pitch
		local pitchRad = math.rad(pitch)
		local yawRad = yaw
		local camX = math.sin(yawRad) * math.cos(pitchRad) * zoom
		local camY = math.sin(pitchRad) * zoom + zoom * 0.3
		local camZ = math.cos(yawRad) * math.cos(pitchRad) * zoom
		local targetPos = root.Position + Vector3.new(camX, camY, camZ)

		-- Clamp camera below ground
		if targetPos.Y < root.Position.Y + 1 then
			targetPos = Vector3.new(targetPos.X, root.Position.Y + 1, targetPos.Z)
		end

		camera.CFrame = CFrame.new(targetPos, lookAt)

		-- Screen shake
		if CameraClient.ShakeIntensity > 0 and CameraClient.ShakeTime < CameraClient.ShakeDuration then
			CameraClient.ShakeTime = CameraClient.ShakeTime + dt
			local t = 1 - (CameraClient.ShakeDuration - CameraClient.ShakeTime) / CameraClient.ShakeDuration
			local currentShake = CameraClient.ShakeIntensity * math.sin(t * 20) * t
			camera.CFrame = camera.CFrame * CFrame.new(
				(math.random() - 0.5) * currentShake,
				(math.random() - 0.5) * currentShake,
				0
			)
		elseif CameraClient.ShakeIntensity > 0 then
			CameraClient.ShakeIntensity = 0
			CameraClient.ShakeDuration = 0
			CameraClient.ShakeTime = 0
		end

		-- Camera effects
		for effectName, effectData in pairs(CameraClient.CameraEffects) do
			if os.clock() >= effectData.expireAt then
				CameraClient.CameraEffects[effectName] = nil
			end
		end
	end)
end

return CameraClient