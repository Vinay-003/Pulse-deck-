--!strict

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))

local CombatClient = {}

CombatClient.HeroModels = {}
CombatClient.ProjectileTrails = {}
CombatClient.LocalPlayerEffects = {}
CombatClient.DamageGuiPool = {}

-- Remote events (initialized in Init)
local effectsEvent
local damageNumberEvent
local killfeedEvent
local announcementEvent

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroSystem
local Config
local Util
local ProgressionUtils

-----------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------

local function createWorldBillboardGui(parent, name, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Parent = parent
	return gui
end

local function spawnDamageNumber(position, amount, color, isHeadshot)
	local anchor = Instance.new("Part")
	anchor.Name = "PDA_DamageNumberAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = position + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1))
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.Size = UDim2.new(0, 80, 0, 32)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(amount))
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	if isHeadshot then
		label.TextStrokeTransparency = 0.3
		label.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.5
	uiScale.Parent = label

	-- Animate upward and fade
	spawn(function()
		local startTime = os.clock()
		local startPos = anchor.Position
		local duration = 0.8

		for i = 1, 8 do
			local t = (os.clock() - startTime) / duration
			if t >= 1 then break end
			anchor.Position = startPos + Vector3.new(0, t * 3, 0)
			label.TextTransparency = t
			uiScale.Scale = 1.5 - t * 0.5
			task.wait(0.03)
		end

		if anchor and anchor.Parent then anchor:Destroy() end
	end)
end

-----------------------------------------------------
-- RENDER FUNCTIONS
-----------------------------------------------------

function CombatClient.RenderTracer(startPos, endPos, color, thickness, isHeadshot)
	local delta = endPos - startPos
	local distance = delta.Magnitude
	if distance <= 0 then return end

	local part = Instance.new("Part")
	part.Name = "PDA_Tracer"
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 255, 100)
	part.Size = Vector3.new((thickness or 0.08) + (isHeadshot and 0.04 or 0),
		(thickness or 0.08) + (isHeadshot and 0.04 or 0), distance)
	part.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
	part.Parent = workspace
	Debris:AddItem(part, 0.15)
end

function CombatClient.RenderExplosion(position, radius, duration)
	local ring = Instance.new("Part")
	ring.Name = "ExplosionRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	ring.Position = position + Vector3.new(0, 0.2, 0)
	ring.Color = Color3.fromRGB(255, 150, 50)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Orientation = Vector3.new(90, 0, 0)
	ring.Parent = workspace
	Debris:AddItem(ring, duration)

	spawn(function()
		local startTime = os.clock()
		local startSize = ring.Size
		while os.clock() - startTime < duration and ring and ring.Parent do
			local t = (os.clock() - startTime) / duration
			ring.Size = Vector3.new(startSize.X + t * radius * 2, startSize.Y - t * 0.3, startSize.Z + t * radius * 2)
			ring.Transparency = 0.3 + t * 0.7
			ring.CFrame = CFrame.new(position + Vector3.new(0, t * 3, 0)) * CFrame.Angles(math.rad(90), 0, 0)
			task.wait()
		end
		if ring and ring.Parent then ring:Destroy() end
	end)

	local firePart = Instance.new("Part")
	firePart.Name = "ExplosionFire"
	firePart.Size = Vector3.new(radius * 1.5, radius * 1.5, radius * 1.5)
	firePart.Position = position
	firePart.Color = Color3.fromRGB(255, 120, 40)
	firePart.Material = Enum.Material.Neon
	firePart.Transparency = 0.5
	firePart.Anchored = true
	firePart.CanCollide = false
	firePart.Shape = Enum.PartType.Ball
	firePart.Parent = workspace
	Debris:AddItem(firePart, duration * 0.8)

	spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < duration * 0.8 and firePart and firePart.Parent do
			local t = (os.clock() - startTime) / (duration * 0.8)
			firePart.Size = Vector3.new(radius * 1.5 + t * radius, radius * 1.5 + t * radius, radius * 1.5 + t * radius)
			firePart.Transparency = 0.5 + t * 0.5
			firePart.Position = position + Vector3.new(0, t * 5, 0)
			task.wait()
		end
		if firePart and firePart.Parent then firePart:Destroy() end
	end)
end

function CombatClient.RenderMuzzleFlash(position, direction, color)
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.5, 1.5, 1.5)
	flash.Position = position + direction * 2
	flash.Color = color or Color3.fromRGB(255, 200, 100)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace
	Debris:AddItem(flash, 0.08)
end

function CombatClient.RenderBlinkEffect(startPos, endPos, duration, color)
	local att0 = Instance.new("Attachment")
	att0.Position = startPos
	att0.Parent = workspace

	local att1 = Instance.new("Attachment")
	att1.Position = endPos
	att1.Parent = workspace

	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(color or Color3.fromRGB(200, 200, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = duration or 0.3
	trail.MinPixelWidth = 2
	trail.LightEmission = 1
	trail.Parent = workspace
	trail.Attachment0 = att0
	trail.Attachment1 = att1

	task.delay(duration or 0.3, function()
		trail:Destroy(); att0:Destroy(); att1:Destroy()
	end)
end

function CombatClient.RenderShieldDome(position, radius, duration)
	local dome = Instance.new("Part")
	dome.Name = "ShieldDomeVisual"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	dome.Color = Color3.fromRGB(80, 180, 255)
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 0.5
	dome.Anchored = true
	dome.CanCollide = false
	dome.Position = position
	dome.Parent = workspace
	Debris:AddItem(dome, duration)
end

function CombatClient.RenderHealRing(position, radius, duration, color)
	local ring = Instance.new("Part")
	ring.Name = "HealRing"
	ring.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
	ring.Color = color or Color3.fromRGB(80, 255, 150)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Position = position
	attach.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(80, 255, 150))
	particles.Size = NumberSequence.new(1, 0)
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 20
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Parent = attach

	Debris:AddItem(ring, duration)
	task.delay(duration, function() attach:Destroy() end)
end

function CombatClient.RenderHealField(position, radius, duration)
	local field = Instance.new("Part")
	field.Name = "HealFieldVisual"
	field.Shape = Enum.PartType.Cylinder
	field.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	field.Color = Color3.fromRGB(100, 255, 150)
	field.Material = Enum.Material.Neon
	field.Transparency = 0.5
	field.Anchored = true
	field.CanCollide = false
	field.Position = position
	field.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	field.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 200))
	particles.Size = NumberSequence.new(0.5, 1.5)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 15
	particles.Speed = NumberRange.new(0.5, 2)
	particles.SpreadAngle = Vector2.new(90, 90)
	particles.Transparency = NumberSequence.new(0, 1)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Parent = field

	Debris:AddItem(field, duration)
end

function CombatClient.RenderSlowField(position, radius, duration)
	local ring = Instance.new("Part")
	ring.Name = "SlowFieldRing"
	ring.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
	ring.Color = Color3.fromRGB(80, 220, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = workspace
	Debris:AddItem(ring, duration)
end

function CombatClient.RenderSwing(position, direction, color, sweepAngle)
	local arc = Instance.new("Part")
	arc.Name = "SwingArc"
	arc.Size = Vector3.new(1, 6, 6)
	arc.Color = color or Color3.fromRGB(255, 255, 255)
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.6
	arc.Anchored = true
	arc.CanCollide = false
	arc.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Position = position + direction * 2
	attach.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color or Color3.fromRGB(200, 200, 255))
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Lifetime = NumberRange.new(0.2, 0.5)
	particles.Speed = NumberRange.new(10, 20)
	particles.SpreadAngle = Vector2.new(sweepAngle or 60, sweepAngle or 60)
	particles.Rate = 0
	particles.Transparency = NumberSequence.new(0, 1)
	particles.EmitDirection = direction
	particles.Parent = attach
	particles:Emit(15)

	task.delay(0.5, function()
		arc:Destroy(); attach:Destroy()
	end)
end

function CombatClient.RenderFlameSpray(position, direction, color, coneAngle, range)
	local flame = Instance.new("Part")
	flame.Name = "FlameSpray"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new((coneAngle or 45) * 0.1, (coneAngle or 45) * 0.1, (range or 5) * 0.5)
	flame.Color = color or Color3.fromRGB(255, 100, 20)
	flame.Material = Enum.Material.Neon
	flame.Transparency = 0.6
	flame.Anchored = true
	flame.CanCollide = false
	flame.CFrame = CFrame.new(position, position + direction * (range or 5) * 4) * CFrame.new(0, 0, -(range or 5) / 4)
	flame.Parent = workspace
	Debris:AddItem(flame, 0.05)

	if range and range > 30 then
		local endpoint = position + direction * range
		local fire = Instance.new("Part")
		fire.Name = "FlameImpact"
		fire.Size = Vector3.new(4, 4, 4)
		fire.Position = endpoint
		fire.Color = Color3.fromRGB(255, 80, 10)
		fire.Material = Enum.Material.Neon
		fire.Transparency = 0.3
		fire.Anchored = true
		fire.CanCollide = false
		fire.Parent = workspace
		Debris:AddItem(fire, 0.4)
	end
end

function CombatClient.RenderLightning(startPos, endPos, color)
	local beam = Instance.new("Part")
	beam.Name = "LightningBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = color or Color3.fromRGB(255, 255, 100)
	beam.Transparency = 0.3

	local dist = (endPos - startPos).Magnitude
	beam.Size = Vector3.new(0.3, 0.3, dist)
	beam.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.15)
end

function CombatClient.RenderProjectileTrail(startPos, endPos, speed, color)
	local dist = (endPos - startPos).Magnitude
	local duration = dist / (speed or 200)

	local projectile = Instance.new("Part")
	projectile.Name = "ProjectileTrail"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(0.6, 0.6, 0.6)
	projectile.Position = startPos
	projectile.Color = color or Color3.fromRGB(255, 150, 50)
	projectile.Material = Enum.Material.Neon
	projectile.Transparency = 0.3
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Parent = workspace

	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(color, Color3.fromRGB(255, 50, 50))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = 0.3
	trail.MinPixelWidth = 3
	trail.LightEmission = 1
	trail.Parent = projectile

	Debris:AddItem(projectile, duration)
end

function CombatClient.RenderPickupEffect(position, pickupType)
	local colors = {
		Health = Color3.fromRGB(40, 200, 80),
		Ammo = Color3.fromRGB(200, 160, 40),
		Energy = Color3.fromRGB(80, 120, 255),
	}

	local color = colors[pickupType] or Color3.fromRGB(255, 255, 255)

	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = color
	sparkle.Parent = workspace

	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Parent = workspace
	sparkle.Parent = anchor

	task.delay(0.5, function() sparkle:Destroy(); anchor:Destroy() end)
end

function CombatClient.RenderObjectiveHit(position, damageAmount)
	local flash = Instance.new("Part")
	flash.Name = "ObjectiveFlash"
	flash.Size = Vector3.new(12, 12, 12)
	flash.Position = position
	flash.Color = Color3.fromRGB(255, 255, 100)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.7
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace
	Debris:AddItem(flash, 0.3)
end

function CombatClient.RenderObjectiveDestroyed(position, teamId)
	local color = teamId == "Red" and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(60, 200, 255)

	for i = 1, 3 do
		local ring = Instance.new("Part")
		ring.Name = "ObjDestroyRing"
		ring.Size = Vector3.new(10 + i * 12, 0.3, 10 + i * 12)
		ring.CFrame = CFrame.new(position + Vector3.new(0, i * 2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = color
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.5
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 1.5 + i * 0.3)
	end

	local beam = Instance.new("Part")
	beam.Name = "ObjDestroyBeam"
	beam.Size = Vector3.new(2, 50, 2)
	beam.Position = position + Vector3.new(0, 25, 0)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.4
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = workspace
	Debris:AddItem(beam, 3)
end

function CombatClient.RenderOverchargeAura(position, color, duration, radius)
	local glow = Instance.new("Part")
	glow.Name = "OverchargeAura"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new((radius or 3) * 2, (radius or 3) * 2, (radius or 3) * 2)
	glow.Position = position
	glow.Color = color
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.6
	glow.Anchored = true
	glow.CanCollide = false
	glow.Parent = workspace
	Debris:AddItem(glow, duration or 5)
end

function CombatClient.RenderFortifyAura(position, color, duration)
	local armor = Instance.new("Part")
	armor.Name = "FortifyAura"
	armor.Size = Vector3.new(5, 6, 5)
	armor.Position = position + Vector3.new(0, 3, 0)
	armor.Color = color
	armor.Material = Enum.Material.ForceField
	armor.Transparency = 0.5
	armor.Anchored = true
	armor.CanCollide = false
	armor.Parent = workspace
	Debris:AddItem(armor, duration or 4)
end

function CombatClient.RenderUltimateEffect(position, color, duration, heroGuid)
	local beam = Instance.new("Part")
	beam.Name = "UltimateBeam"
	beam.Size = Vector3.new(3, 80, 3)
	beam.Position = position + Vector3.new(0, 40, 0)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.3
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 5
	light.Range = 60
	light.Parent = beam

	local ring = Instance.new("Part")
	ring.Name = "UltimateRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(30, 0.3, 30)
	ring.Position = position + Vector3.new(0, 0.2, 0)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.5
	ring.Anchored = true
	ring.CanCollide = false
	ring.Orientation = Vector3.new(90, 0, 0)
	ring.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Position = position + Vector3.new(0, 3, 0)
	attach.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	particles.Size = NumberSequence.new(2, 0)
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 30
	particles.RotSpeed = NumberRange.new(-180, 180)
	particles.Speed = NumberRange.new(5, 15)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Parent = attach

	Debris:AddItem(beam, duration or 5)
	Debris:AddItem(ring, duration or 5)
	task.delay(duration or 5, function() attach:Destroy() end)
end

function CombatClient.RenderTimeDilation(position, radius, duration, color)
	local sphere = Instance.new("Part")
	sphere.Name = "TimeDilationField"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = position
	sphere.Color = color
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 0.7
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.Parent = workspace
	Debris:AddItem(sphere, duration or 4)
end

function CombatClient.RenderGravityWellPulse(position, radius, color)
	local ring = Instance.new("Part")
	ring.Name = "GravityPulse"
	ring.Size = Vector3.new(radius * 2, 0.2, radius * 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.4
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = workspace
	Debris:AddItem(ring, 0.5)
end

function CombatClient.RenderTrail(startPos, endPos, color, duration)
	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Color = ColorSequence.new(color, Color3.fromRGB(0, 0, 0))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = duration or 0.5
	trail.MinPixelWidth = 4
	trail.LightEmission = 1
	trail.Parent = workspace

	local att0 = Instance.new("Attachment")
	att0.Position = startPos
	att0.Parent = workspace

	local att1 = Instance.new("Attachment")
	att1.Position = endPos
	att1.Parent = workspace

	trail.Attachment0 = att0
	trail.Attachment1 = att1

	task.delay(duration or 0.5, function()
		trail:Destroy(); att0:Destroy(); att1:Destroy()
	end)
end

local function createProgressBar(parent, size, pos, color, bgColor)
	local bg = Instance.new("Frame")
	bg.Size = size
	bg.Position = pos
	bg.BackgroundColor3 = bgColor or Color3.fromRGB(20, 20, 30, 180)
	bg.BorderSizePixel = 0
	bg.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	container.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color or Color3.fromRGB(80, 200, 120)
	fill.BorderSizePixel = 0
	fill.Parent = container

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color, Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7))
	grad.Rotation = 90
	grad.Parent = fill

	return bg, fill
end

-----------------------------------------------------
-- INIT
-----------------------------------------------------

function CombatClient.Init()
	effectsEvent = ReplicatedStorage:FindFirstChild("PulseDeckArena") and
		ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes") and
		ReplicatedStorage.PulseDeckArena.Remotes:FindFirstChild("EffectsEvent")

	damageNumberEvent = ReplicatedStorage:FindFirstChild("PulseDeckArena") and
		ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes") and
		ReplicatedStorage.PulseDeckArena.Remotes:FindFirstChild("DamageNumberEvent")

	killfeedEvent = ReplicatedStorage:FindFirstChild("PulseDeckArena") and
		ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes") and
		ReplicatedStorage.PulseDeckArena.Remotes:FindFirstChild("KillfeedEvent")

	announcementEvent = ReplicatedStorage:FindFirstChild("PulseDeckArena") and
		ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes") and
		ReplicatedStorage.PulseDeckArena.Remotes:FindFirstChild("AnnouncementEvent")

	local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
	Config = require(sharedRoot:WaitForChild("Config"))
	Util = require(sharedRoot:WaitForChild("Util"))
	ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))

	effectsEvent.OnClientEvent:Connect(function(payload)
		if payload.effectType == "Tracer" or payload.effectType == "Beam" then
			CombatClient.RenderTracer(payload.startPosition, payload.endPosition, payload.color, payload.thickness, payload.isHeadshot)
		elseif payload.effectType == "Explosion" then
			CombatClient.RenderExplosion(payload.position, payload.radius or 12, payload.duration or 0.4)
		elseif payload.effectType == "MuzzleFlash" then
			CombatClient.RenderMuzzleFlash(payload.position, payload.direction, payload.color)
		elseif payload.effectType == "Blink" then
			CombatClient.RenderBlinkEffect(payload.startPosition, payload.endPosition, payload.duration, payload.color)
		elseif payload.effectType == "ShieldDome" then
			CombatClient.RenderShieldDome(payload.position, payload.radius, payload.duration)
		elseif payload.effectType == "HealRing" then
			CombatClient.RenderHealRing(payload.position, payload.radius, payload.duration, payload.color)
		elseif payload.effectType == "HealField" then
			CombatClient.RenderHealField(payload.position, payload.radius, payload.duration)
		elseif payload.effectType == "SlowField" then
			CombatClient.RenderSlowField(payload.position, payload.radius, payload.duration)
		elseif payload.effectType == "Swing" then
			CombatClient.RenderSwing(payload.position, payload.direction, payload.color, payload.sweepAngle)
		elseif payload.effectType == "FlameSpray" then
			CombatClient.RenderFlameSpray(payload.position, payload.direction, payload.color, payload.coneAngle, payload.range)
		elseif payload.effectType == "Lightning" then
			CombatClient.RenderLightning(payload.startPosition, payload.endPosition, payload.color)
		elseif payload.effectType == "ProjectileTrail" then
			CombatClient.RenderProjectileTrail(payload.startPos, payload.endPos, payload.speed, payload.color)
		elseif payload.effectType == "PickupCollected" then
			CombatClient.RenderPickupEffect(payload.position, payload.pickupType)
		elseif payload.effectType == "ObjectiveHit" then
			CombatClient.RenderObjectiveHit(payload.position, payload.damageAmount)
		elseif payload.effectType == "ObjectiveDestroyed" then
			CombatClient.RenderObjectiveDestroyed(payload.position, payload.teamId)
		elseif payload.effectType == "OverchargeAura" then
			CombatClient.RenderOverchargeAura(payload.position, payload.color, payload.duration, payload.radius)
		elseif payload.effectType == "FortifyAura" then
			CombatClient.RenderFortifyAura(payload.position, payload.color, payload.duration)
		elseif payload.effectType == "UltimateActivated" then
			CombatClient.RenderUltimateEffect(payload.position, payload.color, payload.duration, payload.heroGuid)
		elseif payload.effectType == "TimeDilation" then
			CombatClient.RenderTimeDilation(payload.position, payload.radius, payload.duration, payload.color)
		elseif payload.effectType == "GravityWellPulse" then
			CombatClient.RenderGravityWellPulse(payload.position, payload.radius, payload.color)
		elseif payload.effectType == "TrackerMark" then
			-- Target marked indicator (reuses objective hit visual)
			CombatClient.RenderObjectiveHit(payload.position, 0)

		elseif payload.effectType == "MineDeployed" then
			-- Small pulsing indicator for mine placement
			local mine = Instance.new("Part")
			mine.Name = "SmartMineIndicator"
			mine.Size = Vector3.new(1.5, 0.2, 1.5)
			mine.Position = payload.position
			mine.Color = Color3.fromRGB(255, 50, 50)
			mine.Material = Enum.Material.Neon
			mine.Transparency = 0.5
			mine.Anchored = true
			mine.CanCollide = false
			mine.Parent = workspace
			Debris:AddItem(mine, payload.duration or 30)

		elseif payload.effectType == "EnergyShield" then
			local shield = Instance.new("Part")
			shield.Name = "EnergyShield"
			shield.Size = Vector3.new((payload.width or 5), (payload.height or 6), 0.3)
			shield.Position = payload.position
			shield.Color = payload.color or Color3.fromRGB(100, 200, 255)
			shield.Material = Enum.Material.ForceField
			shield.Transparency = 0.4
			shield.Anchored = true
			shield.CanCollide = false
			shield.Parent = workspace
			Debris:AddItem(shield, payload.duration or 5)

		elseif payload.effectType == "Trail" then
			CombatClient.RenderTrail(payload.startPosition, payload.endPosition, payload.color, payload.duration)
		end
	end)

	damageNumberEvent.OnClientEvent:Connect(function(payload)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local screenPos, onScreen = camera:WorldToScreenPoint(payload.position)
		if not onScreen then return end

		local color = payload.color or Color3.fromRGB(255, 255, 255)
		spawnDamageNumber(payload.position, payload.amount, color, payload.isHeadshot)
	end)

	killfeedEvent.OnClientEvent:Connect(function(payload)
		-- Dispatch killfeed through ClientCore event system
		local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
		if ClientCore and ClientCore.Events and ClientCore.Events.Killfeed then
			ClientCore.Events.Killfeed:Fire(payload)
		end
	end)

	announcementEvent.OnClientEvent:Connect(function(payload)
		if UIClient and UIClient.ShowAnnouncement then
			UIClient:ShowAnnouncement(payload)
		end
	end)
end

return CombatClient