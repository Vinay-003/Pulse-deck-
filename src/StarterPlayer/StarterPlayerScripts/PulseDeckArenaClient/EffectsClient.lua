--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local Util = require(sharedRoot:WaitForChild("Util"))

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))

local EffectsClient = {}

local remotes
local effectsEvent
local damageNumberEvent

-----------------------------------------------------
-- HELPER: Tracer line
-----------------------------------------------------

local function tracer(startPosition, endPosition, color, thickness, duration)
	local delta = endPosition - startPosition
	local distance = delta.Magnitude
	if distance <= 0 then return end

	local part = Instance.new("Part")
	part.Name = "PDA_Tracer"
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.Size = Vector3.new(thickness or 0.08, thickness or 0.08, distance)
	part.CFrame = CFrame.new(startPosition, endPosition) * CFrame.new(0, 0, -distance / 2)
	part.Parent = workspace
	Debris:AddItem(part, duration or 0.08)
end

-----------------------------------------------------
-- HELPER: Damage number
-----------------------------------------------------

local function damageNumber(position, amount, color)
	local anchor = Instance.new("Part")
	anchor.Name = "PDA_DamageNumberAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 90, 0, 32)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(amount))
	label.TextColor3 = color or Color3.fromRGB(255, 230, 120)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.4
	uiScale.Parent = label

	Debris:AddItem(anchor, 0.8)
end

-----------------------------------------------------
-- HELPER: Explosion
-----------------------------------------------------

local function explosion(position, radius, color, duration)
	-- Shockwave ring
	local ring = Instance.new("Part")
	ring.Name = "ExpRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	ring.Position = position + Vector3.new(0, 0.2, 0)
	ring.Color = color or Color3.fromRGB(255, 120, 60)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Orientation = Vector3.new(90, 0, 0)
	ring.Parent = workspace

	Debris:AddItem(ring, duration or 0.5)

	-- Expand
	spawn(function()
		local startSize = ring.Size
		local startTime = os.clock()
		local dur = duration or 0.4
		while os.clock() - startTime < dur and ring and ring.Parent do
			local t = (os.clock() - startTime) / dur
			ring.Size = Vector3.new(startSize.X + t * radius, startSize.Y, startSize.Z + t * radius)
			ring.Transparency = 0.3 + t * 0.7
			ring.CFrame = CFrame.new(position + Vector3.new(0, t * 3, 0)) * CFrame.Angles(math.rad(90), 0, 0)
			task.wait()
		end
		if ring and ring.Parent then ring:Destroy() end
	end)

	-- Fire ball
	local fire = Instance.new("Part")
	fire.Name = "ExpFire"
	fire.Size = Vector3.new(radius * 1.5, radius * 1.5, radius * 1.5)
	fire.Position = position
	fire.Color = color or Color3.fromRGB(255, 120, 60)
	fire.Material = Enum.Material.Neon
	fire.Transparency = 0.5
	fire.Anchored = true
	fire.CanCollide = false
	fire.Shape = Enum.PartType.Ball
	fire.Parent = workspace

	Debris:AddItem(fire, (duration or 0.4) * 0.8)
end

-----------------------------------------------------
-- MAIN INIT
-----------------------------------------------------

function EffectsClient.Init()
	remotes = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Remotes")
	effectsEvent = remotes:WaitForChild("EffectsEvent")
	damageNumberEvent = remotes:WaitForChild("DamageNumberEvent")

	-- Effect handlers
	effectsEvent.OnClientEvent:Connect(function(payload)
		local etype = payload.effectType

		if etype == "Tracer" or etype == "Beam" then
			tracer(payload.startPosition, payload.endPosition, payload.color,
				payload.thickness or 0.08, payload.duration)

		elseif etype == "Explosion" then
			explosion(payload.position, payload.radius or 12,
				Color3.fromRGB(255, 120, 60), payload.duration or 0.4)

		elseif etype == "MuzzleFlash" then
			local flash = Instance.new("Part")
			flash.Size = Vector3.new(2, 2, 2)
			flash.Shape = Enum.PartType.Ball
			flash.Color = payload.color or Color3.fromRGB(255, 200, 100)
			flash.Material = Enum.Material.Neon
			flash.Transparency = 0
			flash.Anchored = true
			flash.CanCollide = false
			flash.Position = payload.position
			flash.Parent = workspace
			Debris:AddItem(flash, 0.08)

		elseif etype == "Blink" then
			-- Start flash
			local f1 = Instance.new("Part")
			f1.Size = Vector3.new(3, 3, 3)
			f1.Shape = Enum.PartType.Ball
			f1.Color = payload.color or Color3.fromRGB(200, 200, 255)
			f1.Material = Enum.Material.Neon
			f1.Transparency = 0.3
			f1.Anchored = true
			f1.CanCollide = false
			f1.Position = payload.startPosition
			f1.Parent = workspace
			Debris:AddItem(f1, 0.2)

			-- End flash
			local f2 = f1:Clone()
			f2.Position = payload.endPosition
			f2.Parent = workspace
			Debris:AddItem(f2, 0.2)

			-- Trail
			local att0 = Instance.new("Attachment")
			att0.Position = payload.startPosition
			att0.Parent = workspace
			local att1 = Instance.new("Attachment")
			att1.Position = payload.endPosition
			att1.Parent = workspace

			local trail = Instance.new("Trail")
			trail.Color = ColorSequence.new(payload.color or Color3.fromRGB(200, 200, 255))
			trail.Transparency = NumberSequence.new(0, 1)
			trail.Lifetime = payload.duration or 0.3
			trail.MinPixelWidth = 2
			trail.LightEmission = 1
			trail.Attachment0 = att0
			trail.Attachment1 = att1
			trail.Parent = workspace

			Debris:AddItem(trail, payload.duration or 0.3)
			task.delay(payload.duration or 0.3, function()
				att0:Destroy(); att1:Destroy()
			end)

		elseif etype == "ShieldDome" then
			local dome = Instance.new("Part")
			dome.Size = Vector3.new((payload.radius or 14) * 2, (payload.radius or 14) * 2, (payload.radius or 14) * 2)
			dome.Shape = Enum.PartType.Ball
			dome.Color = Color3.fromRGB(80, 180, 255)
			dome.Material = Enum.Material.ForceField
			dome.Transparency = 0.5
			dome.Anchored = true
			dome.CanCollide = false
			dome.Position = payload.position
			dome.Parent = workspace
			Debris:AddItem(dome, payload.duration or 6)

		elseif etype == "HealRing" then
			-- Ground ring + rising particles
			local ring = Instance.new("Part")
			ring.Size = Vector3.new((payload.radius or 22) * 2, 0.3, (payload.radius or 22) * 2)
			ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
			ring.Color = Color3.fromRGB(80, 255, 150)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.4
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent = workspace
			Debris:AddItem(ring, payload.duration or 0.7)

			-- Rising heal particles
			for i = 1, 8 do
				task.spawn(function()
					for j = 1, 6 do
						local p = Instance.new("Part")
						p.Size = Vector3.new(0.3, 0.3, 0.3)
						p.Shape = Enum.PartType.Ball
						p.Color = Color3.fromRGB(80, 255, 150)
						p.Material = Enum.Material.Neon
						p.Transparency = j / 6
						p.Anchored = true
						p.CanCollide = false
						p.Position = payload.position + Vector3.new(math.random(-10, 10), j * 2, math.random(-10, 10))
						p.Parent = workspace
						Debris:AddItem(p, 0.3)
					end
					task.wait(math.random() * 0.2)
				end)
			end

		elseif etype == "HealField" then
			local field = Instance.new("Part")
			field.Size = Vector3.new((payload.radius or 16) * 2, 0.3, (payload.radius or 16) * 2)
			field.CFrame = CFrame.new(payload.position) * CFrame.Angles(0, 0, math.rad(90))
			field.Color = Color3.fromRGB(100, 255, 150)
			field.Material = Enum.Material.Neon
			field.Transparency = 0.5
			field.Anchored = true
			field.CanCollide = false
			field.Parent = workspace
			Debris:AddItem(field, payload.duration or 8)

		elseif etype == "SlowField" then
			local ring = Instance.new("Part")
			ring.Size = Vector3.new((payload.radius or 18) * 2, 0.3, (payload.radius or 18) * 2)
			ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
			ring.Color = Color3.fromRGB(80, 220, 255)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.4
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent = workspace
			Debris:AddItem(ring, payload.duration or 6)

		elseif etype == "Swing" then
			-- Visual arc for melee attacks
			local arc = Instance.new("Part")
			arc.Size = Vector3.new(1, 6, 6)
			arc.Color = payload.color or Color3.fromRGB(255, 255, 255)
			arc.Material = Enum.Material.Neon
			arc.Transparency = 0.6
			arc.Anchored = true
			arc.CanCollide = false
			arc.Parent = workspace
			Debris:AddItem(arc, 0.3)

		elseif etype == "FlameSpray" then
			local flame = Instance.new("Part")
			flame.Size = Vector3.new(((payload.coneAngle or 45) * 0.1), ((payload.coneAngle or 45) * 0.1), ((payload.range or 5) * 0.5))
			flame.Color = payload.color or Color3.fromRGB(255, 100, 20)
			flame.Material = Enum.Material.Neon
			flame.Transparency = 0.6
			flame.Anchored = true
			flame.CanCollide = false
			flame.CFrame = CFrame.new(payload.position, payload.position + (payload.direction or Vector3.new(0, 0, -1)) * (payload.range or 5) * 4)
				* CFrame.new(0, 0, -(payload.range or 5) / 4)
			flame.Parent = workspace
			Debris:AddItem(flame, 0.15)

		elseif etype == "Lightning" then
			local beam = Instance.new("Part")
			beam.Anchored = true
			beam.CanCollide = false
			beam.Material = Enum.Material.Neon
			beam.Color = payload.color or Color3.fromRGB(255, 255, 100)
			beam.Transparency = 0.3
			local dist = (payload.endPosition - payload.startPosition).Magnitude
			beam.Size = Vector3.new(0.3, 0.3, dist)
			beam.CFrame = CFrame.new(payload.startPosition, payload.endPosition) * CFrame.new(0, 0, -dist / 2)
			beam.Parent = workspace
			Debris:AddItem(beam, 0.2)

		elseif etype == "ProjectileTrail" then
			local dist = (payload.endPos - payload.startPos).Magnitude
			local duration = dist / (payload.speed or 200)

			local proj = Instance.new("Part")
			proj.Shape = Enum.PartType.Ball
			proj.Size = Vector3.new(0.6, 0.6, 0.6)
			proj.Position = payload.startPos
			proj.Color = payload.color or Color3.fromRGB(255, 150, 50)
			proj.Material = Enum.Material.Neon
			proj.Transparency = 0.3
			proj.CanCollide = false
			proj.Anchored = true
			proj.Parent = workspace

			local trail = Instance.new("Trail")
			trail.Color = ColorSequence.new(payload.color or Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 50, 50))
			trail.Transparency = NumberSequence.new(0, 1)
			trail.Lifetime = 0.3
			trail.MinPixelWidth = 3
			trail.LightEmission = 1
			trail.Parent = proj

			Debris:AddItem(proj, duration)

		elseif etype == "PickupCollected" then
			local colors = {
				Health = Color3.fromRGB(40, 200, 80),
				Ammo = Color3.fromRGB(200, 160, 40),
				Energy = Color3.fromRGB(80, 120, 255),
			}
			local color = colors[payload.pickupType] or Color3.fromRGB(255, 255, 255)

			local sparkle = Instance.new("Sparkles")
			sparkle.SparkleColor = color

			local anchor = Instance.new("Part")
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.Position = payload.position
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			sparkle.Parent = anchor
			anchor.Parent = workspace
			Debris:AddItem(anchor, 0.6)

		elseif etype == "ObjectiveHit" then
			local flash = Instance.new("Part")
			flash.Size = Vector3.new(12, 12, 12)
			flash.Position = payload.position
			flash.Color = Color3.fromRGB(255, 255, 100)
			flash.Material = Enum.Material.Neon
			flash.Transparency = 0.7
			flash.Anchored = true
			flash.CanCollide = false
			flash.Parent = workspace
			Debris:AddItem(flash, 0.3)

		elseif etype == "ObjectiveDestroyed" then
			local color = payload.teamId == "Red" and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(60, 200, 255)

			for i = 1, 3 do
				local ring = Instance.new("Part")
				ring.Size = Vector3.new(10 + i * 12, 0.3, 10 + i * 12)
				ring.CFrame = CFrame.new(payload.position + Vector3.new(0, i * 2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
				ring.Color = color
				ring.Material = Enum.Material.Neon
				ring.Transparency = 0.5
				ring.Anchored = true
				ring.CanCollide = false
				ring.Parent = workspace
				Debris:AddItem(ring, 1.5 + i * 0.3)
			end

			local beam = Instance.new("Part")
			beam.Size = Vector3.new(2, 50, 2)
			beam.Position = payload.position + Vector3.new(0, 25, 0)
			beam.Color = color
			beam.Material = Enum.Material.Neon
			beam.Transparency = 0.4
			beam.Anchored = true
			beam.CanCollide = false
			beam.Parent = workspace
			Debris:AddItem(beam, 3)

		elseif etype == "OverchargeAura" then
			local glow = Instance.new("Part")
			glow.Size = Vector3.new((payload.radius or 3) * 2, (payload.radius or 3) * 2, (payload.radius or 3) * 2)
			glow.Position = payload.position
			glow.Color = payload.color
			glow.Material = Enum.Material.Neon
			glow.Transparency = 0.6
			glow.Anchored = true
			glow.CanCollide = false
			glow.Parent = workspace
			Debris:AddItem(glow, payload.duration or 5)

		elseif etype == "FortifyAura" then
			local armor = Instance.new("Part")
			armor.Size = Vector3.new(5, 6, 5)
			armor.Position = payload.position + Vector3.new(0, 3, 0)
			armor.Color = payload.color
			armor.Material = Enum.Material.ForceField
			armor.Transparency = 0.5
			armor.Anchored = true
			armor.CanCollide = false
			armor.Parent = workspace
			Debris:AddItem(armor, payload.duration or 4)

		elseif etype == "UltimateActivated" then
			local beam = Instance.new("Part")
			beam.Size = Vector3.new(3, 80, 3)
			beam.Position = payload.position + Vector3.new(0, 40, 0)
			beam.Color = payload.color
			beam.Material = Enum.Material.Neon
			beam.Transparency = 0.3
			beam.Anchored = true
			beam.CanCollide = false
			beam.Parent = workspace

			local light = Instance.new("PointLight")
			light.Color = payload.color
			light.Brightness = 5
			light.Range = 60
			light.Parent = beam

			local ring = Instance.new("Part")
			ring.Size = Vector3.new(30, 0.3, 30)
			ring.Position = payload.position + Vector3.new(0, 0.2, 0)
			ring.Color = payload.color
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.5
			ring.Anchored = true
			ring.CanCollide = false
			ring.Orientation = Vector3.new(90, 0, 0)
			ring.Parent = workspace

			Debris:AddItem(beam, payload.duration or 5)
			Debris:AddItem(ring, payload.duration or 5)

			local attach = Instance.new("Attachment")
			attach.Position = payload.position + Vector3.new(0, 3, 0)
			attach.Parent = workspace

			local particles = Instance.new("ParticleEmitter")
			particles.Color = ColorSequence.new(payload.color, Color3.fromRGB(255, 255, 255))
			particles.Size = NumberSequence.new(2, 0)
			particles.Lifetime = NumberRange.new(0.5, 1)
			particles.Rate = 30
			particles.RotSpeed = NumberRange.new(-180, 180)
			particles.Speed = NumberRange.new(5, 15)
			particles.SpreadAngle = Vector2.new(45, 45)
			particles.Transparency = NumberSequence.new(0, 1)
			particles.Parent = attach

			task.delay(payload.duration or 5, function() attach:Destroy() end)

		elseif etype == "TimeDilation" then
			local sphere = Instance.new("Part")
			sphere.Size = Vector3.new((payload.radius or 30) * 2, (payload.radius or 30) * 2, (payload.radius or 30) * 2)
			sphere.Shape = Enum.PartType.Ball
			sphere.Position = payload.position
			sphere.Color = payload.color
			sphere.Material = Enum.Material.Neon
			sphere.Transparency = 0.7
			sphere.Anchored = true
			sphere.CanCollide = false
			sphere.Parent = workspace
			Debris:AddItem(sphere, payload.duration or 4)

		elseif etype == "GravityWellPulse" then
			local ring = Instance.new("Part")
			ring.Size = Vector3.new((payload.radius or 16) * 2, 0.2, (payload.radius or 16) * 2)
			ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
			ring.Color = payload.color
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.4
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent = workspace
			Debris:AddItem(ring, 0.5)

		elseif etype == "Trail" then
			local trail = Instance.new("Trail")
			trail.Color = ColorSequence.new(payload.color)
			trail.Transparency = NumberSequence.new(0, 1)
			trail.Lifetime = payload.duration or 0.5
			trail.MinPixelWidth = 4
			trail.LightEmission = 1
			trail.Parent = workspace

			local att0 = Instance.new("Attachment")
			att0.Position = payload.startPosition
			att0.Parent = workspace
			local att1 = Instance.new("Attachment")
			att1.Position = payload.endPosition
			att1.Parent = workspace
			trail.Attachment0 = att0
			trail.Attachment1 = att1

			task.delay(payload.duration or 0.5, function()
				trail:Destroy(); att0:Destroy(); att1:Destroy()
			end)
		end
	end)

	damageNumberEvent.OnClientEvent:Connect(function(payload)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local _, onScreen = camera:WorldToScreenPoint(payload.position)
		if not onScreen then return end

		local color = payload.color
			or (payload.isHeadshot and Color3.fromRGB(255, 50, 50))
			or (payload.isCritical and Color3.fromRGB(255, 200, 50))
			or Color3.fromRGB(255, 255, 255)

		damageNumber(payload.position, payload.amount, color)

		if payload.isHeadshot then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 200, 50)
			sparkles.Parent = workspace
			local anchor = Instance.new("Part")
			anchor.Size = Vector3.new(0.5, 0.5, 0.5)
			anchor.Position = payload.position
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			sparkles.Parent = anchor
			task.delay(0.4, function() sparkles:Destroy(); anchor:Destroy() end)
		end
	end)
end

return EffectsClient