--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local CameraClient = {}

CameraClient.Mode = "TPS"
CameraClient.BaseZoom = nil
CameraClient.CameraEffects = {}

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

	CameraClient.BaseZoom = 7

	local aimPart = Instance.new("Part")
	aimPart.Name = "CameraAimHelper"
	aimPart.Size = Vector3.new(0.1, 0.1, 0.1)
	aimPart.Transparency = 1
	aimPart.Anchored = true
	aimPart.CanCollide = false
	aimPart.Parent = workspace

	RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return end

		if CameraClient.Mode == "FPS" then
			local pos = root.Position + Vector3.new(0, 1.6, 0)
			camera.CFrame = CFrame.new(pos, pos + root.CFrame.LookVector)
		else
			-- TPS with smooth following and slight zoom
			local zoom = CameraClient.BaseZoom or 7
			local cameraPos = root.CFrame:PointToWorldSpace(Vector3.new(zoom, 3, zoom * 1.5))
			local lookAt = root.Position + Vector3.new(0, 2.5, 0) + root.CFrame.LookVector * zoom * 0.5

			-- Smooth interpolation
			local currentPos = camera.CFrame.Position
			local targetPos = cameraPos
			local newPos = currentPos:Lerp(targetPos, 0.1)
			camera.CFrame = CFrame.new(newPos, lookAt)
		end

		-- Screen shake
		if CameraClient.ShakeIntensity > 0 and CameraClient.ShakeTime < CameraClient.ShakeDuration then
			CameraClient.ShakeTime += RunService.RenderStepped:Wait()
			local t = 1 - (CameraClient.ShakeDuration - CameraClient.ShakeTime) / CameraClient.ShakeDuration
			local currentShake = CameraClient.ShakeIntensity * math.sin(t * 20) * t
			local currentCFrame = camera.CFrame
			local offset = CFrame.new(
			 	math.random() * currentShake - currentShake * 0.5,
			 	math.random() * currentShake - currentShake * 0.5,
			 	0
			)
			camera.CFrame = currentCFrame * offset
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

	-- Post-processing effects
	local lighting = Lighting
	lighting.Ambient = Color3.fromRGB(55, 60, 80)
	lighting.OutdoorAmbient = Color3.fromRGB(30, 35, 50)
	lighting.Brightness = 2
	lighting.ClockTime = 20
	lighting.EnvironmentDiffuseScale = 0.4
	lighting.EnvironmentSpecularScale = 0.6
	lighting.FogColor = Color3.fromRGB(15, 18, 25)
	lighting.FogEnd = 400

	-- Bloom for neon aesthetic
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = lighting

	-- Color correction
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.1
	cc.Parent = lighting

	-- SunRays
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0
	sunRays.Spread = 0.5
	sunRays.Parent = lighting
end

return CameraClient