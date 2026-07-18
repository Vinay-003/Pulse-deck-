local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))

local CameraClient = {}

CameraClient.Mode = "TPS"
CameraClient.BaseZoom = 8
CameraClient.CameraEffects = {}
CameraClient.Spectating = false
CameraClient.SpectateTarget = nil
CameraClient.SpectateIndex = 1
CameraClient.SpectateMode = "ThirdPerson"
CameraClient.Yaw = 0
CameraClient.Pitch = -8
CameraClient.ShakeIntensity = 0
CameraClient.ShakeDuration = 0
CameraClient.ShakeElapsed = 0

local function getLookVector(yawDegrees, pitchDegrees)
	local yaw = math.rad(yawDegrees)
	local pitch = math.rad(pitchDegrees)
	local horizontal = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * horizontal, -math.sin(pitch), -math.cos(yaw) * horizontal).Unit
end

function CameraClient.EnterSpectate()
	if CameraClient.Spectating then return end
	CameraClient.Spectating = true
	CameraClient.SpectateIndex = 0
	CameraClient.SpectateMode = "ThirdPerson"
	CameraClient.FindNextSpectateTarget()
end

function CameraClient.ExitSpectate()
	CameraClient.Spectating = false
	CameraClient.SpectateTarget = nil
end

function CameraClient.FindNextSpectateTarget()
	local aliveHeroes = {}
	for _, hero in pairs(ClientCore.State.heroes or {}) do
		if hero.teamId == ClientCore.State.teamId and hero.alive then table.insert(aliveHeroes, hero) end
	end
	if #aliveHeroes == 0 then
		CameraClient.SpectateTarget = nil
		return
	end
	CameraClient.SpectateIndex = (CameraClient.SpectateIndex % #aliveHeroes) + 1
	CameraClient.SpectateTarget = aliveHeroes[CameraClient.SpectateIndex]
end

function CameraClient.ToggleSpectateMode()
	CameraClient.SpectateMode = CameraClient.SpectateMode == "ThirdPerson" and "FirstPerson" or "ThirdPerson"
end

function CameraClient.ToggleMode()
	CameraClient.Mode = CameraClient.Mode == "TPS" and "FPS" or "TPS"
end

function CameraClient.AddShake(intensity, duration)
	if not SettingsClient.CameraShake then return end
	CameraClient.ShakeIntensity = math.max(CameraClient.ShakeIntensity, intensity or 0)
	CameraClient.ShakeDuration = math.max(CameraClient.ShakeDuration, duration or 0)
	CameraClient.ShakeElapsed = 0
end

function CameraClient.ApplyEffect(effectName, intensity, duration)
	CameraClient.CameraEffects[effectName] = {intensity = intensity or 1, expireAt = os.clock() + (duration or 1)}
end

local function updateSpectatorCamera(camera, deltaTime)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local target = CameraClient.SpectateTarget
	if target then
		local targetPosition = target.position or target.rootPosition or Vector3.new(0, 5, 0)
		local lookVector = getLookVector(CameraClient.Yaw, CameraClient.Pitch)
		if CameraClient.SpectateMode == "FirstPerson" then
			local cameraPosition = targetPosition + Vector3.new(0, 1.6, 0)
			camera.CFrame = CFrame.new(cameraPosition, cameraPosition + lookVector * 100)
		else
			local desired = targetPosition - lookVector * 9 + Vector3.new(0, 3, 0)
			camera.CFrame = CFrame.new(desired, targetPosition + Vector3.new(0, 1.5, 0))
		end
		return
	end
	local direction = Vector3.new((UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0), (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0), (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0))
	if direction.Magnitude > 0 then camera.CFrame = camera.CFrame + direction.Unit * 30 * deltaTime end
end

local function resolveCameraCollision(character, origin, desired)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = {character}
	parameters.IgnoreWater = true
	local cast = workspace:Raycast(origin, desired - origin, parameters)
	if cast then return cast.Position + cast.Normal * 0.35 end
	return desired
end

function CameraClient.Init()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable

	RunService.RenderStepped:Connect(function(deltaTime)
		local matchState = ClientCore.State.matchState
		local inGameplay = matchState == "ActiveMatch" or matchState == "SuddenDeath" or matchState == "MatchCountdown"
		if CameraClient.Spectating or not inGameplay then UserInputService.MouseBehavior = Enum.MouseBehavior.Default else UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
		UserInputService.MouseIconEnabled = not inGameplay or CameraClient.Spectating

		if CameraClient.Spectating then
			updateSpectatorCamera(camera, deltaTime)
			return
		end

		local character = Players.LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then return end

		local mouseDelta = UserInputService:GetMouseDelta()
		local sensitivity = math.max(0.1, SettingsClient.Sensitivity or 1)
		local invert = SettingsClient.InvertY and -1 or 1
		CameraClient.Yaw = CameraClient.Yaw - mouseDelta.X * 0.16 * sensitivity
		CameraClient.Pitch = math.clamp(CameraClient.Pitch + mouseDelta.Y * 0.14 * sensitivity * invert, -68, 58)

		local yaw = math.rad(CameraClient.Yaw)
		local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
		local movement = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then movement = movement + forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then movement = movement - forward end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then movement = movement + right end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then movement = movement - right end

		if humanoid.Health > 0 then
			if movement.Magnitude > 0 then
				humanoid:Move(movement.Unit, false)
				root.CFrame = CFrame.new(root.Position, root.Position + movement.Unit)
			else
				humanoid:Move(Vector3.zero, false)
				root.CFrame = CFrame.new(root.Position, root.Position + forward)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then humanoid.Jump = true end
		end

		local lookVector = getLookVector(CameraClient.Yaw, CameraClient.Pitch)
		local cameraPosition
		local focusPosition
		if CameraClient.Mode == "FPS" then
			cameraPosition = root.Position + Vector3.new(0, 1.65, 0)
			focusPosition = cameraPosition + lookVector * 100
		else
			local pivot = root.Position + Vector3.new(0, 1.8, 0)
			local desired = pivot - lookVector * (CameraClient.BaseZoom or 8) + right * 1.25
			cameraPosition = resolveCameraCollision(character, pivot, desired)
			focusPosition = pivot + lookVector * 100
		end
		camera.CFrame = CFrame.new(cameraPosition, focusPosition)

		if SettingsClient.CameraShake and CameraClient.ShakeIntensity > 0 and CameraClient.ShakeElapsed < CameraClient.ShakeDuration then
			CameraClient.ShakeElapsed = CameraClient.ShakeElapsed + deltaTime
			local progress = math.clamp(CameraClient.ShakeElapsed / math.max(0.001, CameraClient.ShakeDuration), 0, 1)
			local strength = CameraClient.ShakeIntensity * (1 - progress)
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		elseif CameraClient.ShakeElapsed >= CameraClient.ShakeDuration then
			CameraClient.ShakeIntensity = 0
			CameraClient.ShakeDuration = 0
			CameraClient.ShakeElapsed = 0
		end

		for effectName, effectData in pairs(CameraClient.CameraEffects) do
			if os.clock() >= effectData.expireAt then CameraClient.CameraEffects[effectName] = nil end
		end
	end)
end

return CameraClient
