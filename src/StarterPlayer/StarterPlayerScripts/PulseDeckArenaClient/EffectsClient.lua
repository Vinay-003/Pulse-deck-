
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
			CombatClient.RenderTrail(payload.startPosition, payload.endPosition, payload.color, payload.duration)

			-- === NEW EFFECTS BELOW ===

	elseif etype == "FireNova" then
		-- Expanding fire ring + ground scatter
		local ring = Instance.new("Part")
		ring.Name = "FireNovaRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new((payload.radius or 14) * 2, 0.4, (payload.radius or 14) * 2)
		ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = payload.color or Color3.fromRGB(255, 80, 20)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.3
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 1)

		-- Expand fire ring
		spawn(function()
			local startSize = ring.Size
			local startTime = os.clock()
			local dur = 0.6
			while os.clock() - startTime < dur and ring and ring.Parent do
				local t = (os.clock() - startTime) / dur
				ring.Size = Vector3.new(startSize.X + t * (payload.radius or 14), startSize.Y, startSize.Z + t * (payload.radius or 14))
				ring.Transparency = 0.3 + t * 0.7
				ring.CFrame = CFrame.new(payload.position + Vector3.new(0, t * 2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
				task.wait()
			end
			if ring and ring.Parent then ring:Destroy() end
		end)

		-- Fire particles
		for i = 1, 12 do
			task.spawn(function()
				local p = Instance.new("Part")
				p.Name = "FireNovaParticle"
				p.Size = Vector3.new(0.5, 0.5, 0.5)
				p.Shape = Enum.PartType.Ball
				p.Color = Color3.fromRGB(255, math.random(60, 120), 10)
				p.Material = Enum.Material.Neon
				p.Transparency = 0.3
				p.Anchored = false
				p.CanCollide = false
				p.Position = payload.position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				p.Parent = workspace
				Debris:AddItem(p, 1.2)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-20, 20), math.random(10, 30), math.random(-20, 20))
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bv.Parent = p
				game:GetService("Debris"):AddItem(bv, 0.5)
			end)
		end

	elseif etype == "FreezeNova" then
		-- Ice burst ring
		local ring = Instance.new("Part")
		ring.Name = "FreezeNovaRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new((payload.radius or 14) * 2, 0.4, (payload.radius or 14) * 2)
		ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = payload.color or Color3.fromRGB(100, 200, 255)
		ring.Material = Enum.Material.SmoothPlastic
		ring.Transparency = 0.2
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 1.5)

		-- Expanding ice crystals
		spawn(function()
			local startTime = os.clock()
			local dur = 1
			while os.clock() - startTime < dur and ring and ring.Parent do
				local t = (os.clock() - startTime) / dur
				ring.Size = Vector3.new(ring.Size.X + t * 5, ring.Size.Y, ring.Size.Z + t * 5)
				ring.Transparency = 0.2 + t * 0.6
				task.wait()
			end
		end)

		-- Frost particles
		for i = 1, 16 do
			task.spawn(function()
				local p = Instance.new("Part")
				p.Name = "FreezeParticle"
				p.Size = Vector3.new(0.3, 0.3, 0.3)
				p.Shape = Enum.PartType.Ball
				p.Color = Color3.fromRGB(150, 220, 255)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0.4
				p.Anchored = false
				p.CanCollide = false
				p.Position = payload.position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
				p.Parent = workspace
				Debris:AddItem(p, 1.5)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-8, 8), math.random(5, 15), math.random(-8, 8))
				bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
				bv.Parent = p
				game:GetService("Debris"):AddItem(bv, 0.8)
			end)
		end

	elseif etype == "Blizzard" then
		-- Blizzard zone effect — swirling snow ground + overhead cloud
		local groundRing = Instance.new("Part")
		groundRing.Name = "BlizzardGround"
		groundRing.Shape = Enum.PartType.Cylinder
		groundRing.Size = Vector3.new((payload.radius or 20) * 2, 0.3, (payload.radius or 20) * 2)
		groundRing.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		groundRing.Color = Color3.fromRGB(180, 210, 240)
		groundRing.Material = Enum.Material.SmoothPlastic
		groundRing.Transparency = 0.7
		groundRing.Anchored = true
		groundRing.CanCollide = false
		groundRing.Parent = workspace
		Debris:AddItem(groundRing, payload.duration or 8)

		-- Overhead cloud
		local cloud = Instance.new("Part")
		cloud.Name = "BlizzardCloud"
		cloud.Size = Vector3.new(payload.radius or 20, 3, payload.radius or 20)
		cloud.Position = payload.position + Vector3.new(0, 25, 0)
		cloud.Color = Color3.fromRGB(200, 220, 240)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Transparency = 0.6
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Parent = workspace
		Debris:AddItem(cloud, payload.duration or 8)

		-- Falling snow visual (sparks)
		for i = 1, 20 do
			task.spawn(function()
				local spark = Instance.new("Part")
				spark.Size = Vector3.new(0.2, 0.2, 0.2)
				spark.Shape = Enum.PartType.Ball
				spark.Color = Color3.fromRGB(220, 235, 255)
				spark.Material = Enum.Material.SmoothPlastic
				spark.Transparency = 0.3
				spark.Anchored = false
				spark.CanCollide = false
				spark.Position = payload.position + Vector3.new(math.random(-(payload.radius or 20), payload.radius or 20), math.random(10, 25), math.random(-(payload.radius or 20), payload.radius or 20))
				spark.Parent = workspace
				Debris:AddItem(spark, 2)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-2, 2), -math.random(8, 15), math.random(-2, 2))
				bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
				bv.Parent = spark
				game:GetService("Debris"):AddItem(bv, 1.5)
			end)
		end

	elseif etype == "SupernovaCharge" then
		-- Charging sphere — pulsing glow
		local sphere = Instance.new("Part")
		sphere.Name = "SupernovaChargeSphere"
		sphere.Size = Vector3.new((payload.radius or 8) * 2, (payload.radius or 8) * 2, (payload.radius or 8) * 2)
		sphere.Position = payload.position
		sphere.Color = payload.color or Color3.fromRGB(255, 200, 50)
		sphere.Material = Enum.Material.Neon
		sphere.Transparency = 0.3
		sphere.Anchored = true
		sphere.CanCollide = false
		sphere.Shape = Enum.PartType.Ball
		sphere.Parent = workspace

		-- Pulsing animation
		spawn(function()
			local startTime = os.clock()
			while os.clock() - startTime < 3 and sphere and sphere.Parent do
				local t = (os.clock() - startTime)
				local pulse = 1 + math.sin(t * 8) * 0.3
				sphere.Size = Vector3.new((payload.radius or 8) * 2 * pulse, (payload.radius or 8) * 2 * pulse, (payload.radius or 8) * 2 * pulse)
				sphere.Transparency = 0.3 + math.sin(t * 6) * 0.15
				task.wait()
			end
			if sphere and sphere.Parent then sphere:Destroy() end
		end)
		Debris:AddItem(sphere, 4)

	elseif etype == "SupernovaExplosion" then
		-- Massive explosion with shockwave
		local shockwave = Instance.new("Part")
		shockwave.Name = "SupernovaShockwave"
		shockwave.Size = Vector3.new((payload.radius or 16) * 2, 0.5, (payload.radius or 16) * 2)
		shockwave.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		shockwave.Color = payload.color or Color3.fromRGB(255, 200, 50)
		shockwave.Material = Enum.Material.Neon
		shockwave.Transparency = 0.2
		shockwave.Anchored = true
		shockwave.CanCollide = false
		shockwave.Parent = workspace

		-- Expand shockwave
		spawn(function()
			local startTime = os.clock()
			local dur = 1.5
			while os.clock() - startTime < dur and shockwave and shockwave.Parent do
				local t = (os.clock() - startTime) / dur
				local s = (payload.radius or 16) * 4
				shockwave.Size = Vector3.new(s + t * s, 0.5, s + t * s)
				shockwave.Transparency = 0.2 + t * 0.8
				task.wait()
			end
			if shockwave and shockwave.Parent then shockwave:Destroy() end
		end)

		-- Central fireball
		local fireball = Instance.new("Part")
		fireball.Name = "SupernovaFireball"
		fireball.Size = Vector3.new(8, 8, 8)
		fireball.Position = payload.position
		fireball.Color = Color3.fromRGB(255, 255, 150)
		fireball.Material = Enum.Material.Neon
		fireball.Transparency = 0.2
		fireball.Anchored = true
		fireball.CanCollide = false
		fireball.Shape = Enum.PartType.Ball
		fireball.Parent = workspace
		Debris:AddItem(fireball, 2)

		-- Light flash
		local flash = Instance.new("Part")
		flash.Size = Vector3.new(20, 20, 20)
		flash.Position = payload.position
		flash.Color = Color3.fromRGB(255, 255, 200)
		flash.Material = Enum.Material.Neon
		flash.Transparency = 0.8
		flash.Anchored = true
		flash.CanCollide = false
		flash.Shape = Enum.PartType.Ball
		flash.Parent = workspace
		Debris:AddItem(flash, 0.3)

		-- Rising embers
		for i = 1, 25 do
			task.spawn(function()
				local e = Instance.new("Part")
				e.Size = Vector3.new(0.4, 0.4, 0.4)
				e.Shape = Enum.PartType.Ball
				e.Color = Color3.fromRGB(255, math.random(100, 200), 50)
				e.Material = Enum.Material.Neon
				e.Transparency = 0.5
				e.Anchored = false
				e.CanCollide = false
				e.Position = payload.position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
				e.Parent = workspace
				Debris:AddItem(e, 2)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-15, 15), math.random(20, 50), math.random(-15, 15))
				bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
				bv.Parent = e
				game:GetService("Debris"):AddItem(bv, 1)
			end)
		end

	elseif etype == "BlackHole" then
		-- Dark swirling vortex
		local vortex = Instance.new("Part")
		vortex.Name = "BlackHoleVortex"
		vortex.Size = Vector3.new((payload.radius or 12) * 2, 8, (payload.radius or 12) * 2)
		vortex.Position = payload.position
		vortex.Color = Color3.fromRGB(5, 5, 15)
		vortex.Material = Enum.Material.Neon
		vortex.Transparency = 0.6
		vortex.Anchored = true
		vortex.CanCollide = false
		vortex.Shape = Enum.PartType.Cylinder
		vortex.Parent = workspace
		Debris:AddItem(vortex, payload.duration or 6)

		-- Spinning ring
		local spinRing = Instance.new("Part")
		spinRing.Name = "BHSpinRing"
		spinRing.Size = Vector3.new(0.3, (payload.radius or 12) * 2, (payload.radius or 12) * 2)
		spinRing.Position = payload.position
		spinRing.Color = Color3.fromRGB(40, 10, 80)
		spinRing.Material = Enum.Material.Neon
		spinRing.Transparency = 0.5
		spinRing.Anchored = true
		spinRing.CanCollide = false
		spinRing.Parent = workspace
		Debris:AddItem(spinRing, payload.duration or 6)

		-- Accretion disk glow
		local glow = Instance.new("Part")
		glow.Name = "BHGlow"
		glow.Size = Vector3.new((payload.radius or 12) * 1.5, 0.2, (payload.radius or 12) * 1.5)
		glow.Position = payload.position + Vector3.new(0, 0.5, 0)
		glow.Color = Color3.fromRGB(100, 50, 150)
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.7
		glow.Anchored = true
		glow.CanCollide = false
		glow.Parent = workspace
		Debris:AddItem(glow, payload.duration or 6)

	elseif etype == "EMPBlast" then
		-- Electric pulse ring
		local ring = Instance.new("Part")
		ring.Name = "EMPRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, (payload.radius or 10) * 2, (payload.radius or 10) * 2)
		ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = Color3.fromRGB(0, 200, 255)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace

		-- Expand and fade
		spawn(function()
			local startTime = os.clock()
			local dur = 0.8
			while os.clock() - startTime < dur and ring and ring.Parent do
				local t = (os.clock() - startTime) / dur
				ring.Size = Vector3.new(t * 2, (payload.radius or 10) * 2 * t, (payload.radius or 10) * 2 * t)
				ring.Transparency = t
				task.wait()
			end
			if ring and ring.Parent then ring:Destroy() end
		end)

		-- Sparks
		for i = 1, 16 do
			task.spawn(function()
				local s = Instance.new("Part")
				s.Size = Vector3.new(0.2, 0.8, 0.2)
				s.Color = Color3.fromRGB(0, 255, 255)
				s.Material = Enum.Material.Neon
				s.Transparency = 0.5
				s.Anchored = false
				s.CanCollide = false
				s.Position = payload.position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
				s.Parent = workspace
				Debris:AddItem(s, 0.6)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-10, 10), math.random(5, 20), math.random(-10, 10))
				bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
				bv.Parent = s
				game:GetService("Debris"):AddItem(bv, 0.4)
			end)
		end

	elseif etype == "SmokeScreen" then
		-- Gray smoke cloud
		local smoke = Instance.new("Part")
		smoke.Name = "SmokeCloud"
		smoke.Size = Vector3.new((payload.radius or 12) * 2, 6, (payload.radius or 12) * 2)
		smoke.Position = payload.position
		smoke.Color = Color3.fromRGB(150, 150, 150)
		smoke.Material = Enum.Material.SmoothPlastic
		smoke.Transparency = 0.3
		smoke.Anchored = true
		smoke.CanCollide = false
		smoke.Parent = workspace
		Debris:AddItem(smoke, payload.duration or 6)

		-- Drifting smoke particles
		for i = 1, 12 do
			task.spawn(function()
				local p = Instance.new("Part")
				p.Size = Vector3.new(math.random(20, 40) / 10, math.random(20, 40) / 10, math.random(20, 40) / 10)
				p.Color = Color3.fromRGB(160, 160, 170)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0.4
				p.Anchored = false
				p.CanCollide = false
				p.Position = payload.position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
				p.Parent = workspace
				Debris:AddItem(p, 3)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-3, 3), math.random(1, 4), math.random(-3, 3))
				bv.MaxForce = Vector3.new(1e2, 1e2, 1e2)
				bv.Parent = p
				game:GetService("Debris"):AddItem(bv, 2)
			end)
		end

	elseif etype == "Cloak" then
		-- Stealth shimmer effect at hero location
		local shimmer = Instance.new("Part")
		shimmer.Name = "CloakShimmer"
		shimmer.Size = Vector3.new(3, 5, 3)
		shimmer.Position = payload.position or Vector3.new(0, 5, 0)
		shimmer.Color = Color3.fromRGB(40, 40, 50)
		shimmer.Material = Enum.Material.Neon
		shimmer.Transparency = 0.5
		shimmer.Anchored = true
		shimmer.CanCollide = false
		shimmer.Parent = workspace
		Debris:AddItem(shimmer, payload.duration or 8)

	elseif etype == "TacticalOverlay" then
		-- Mini-map style ping at hero location
		local ping = Instance.new("Part")
		ping.Name = "TactPing"
		ping.Size = Vector3.new(1, 0.1, 1)
		ping.Position = payload.position or Vector3.new(0, 0.5, 0)
		ping.Color = Color3.fromRGB(0, 255, 100)
		ping.Material = Enum.Material.Neon
		ping.Transparency = 0.3
		ping.Anchored = true
		ping.CanCollide = false
		ping.Parent = workspace
		Debris:AddItem(ping, payload.duration or 6)

	elseif etype == "PhoenixDive" then
		-- Sky dive trail from above
		local beam = Instance.new("Part")
		beam.Name = "DiveBeam"
		beam.Size = Vector3.new(3, 80, 3)
		beam.Position = payload.position + Vector3.new(0, 40, 0)
		beam.Color = Color3.fromRGB(255, 100, 0)
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.4
		beam.Anchored = true
		beam.CanCollide = false
		beam.Parent = workspace
		Debris:AddItem(beam, 1)

	elseif etype == "PhoenixDiveImpact" then
		-- Ground impact crater + fire
		local crater = Instance.new("Part")
		crater.Name = "ImpactCrater"
		crater.Shape = Enum.PartType.Cylinder
		crater.Size = Vector3.new((payload.radius or 15) * 2, 0.5, (payload.radius or 15) * 2)
		crater.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		crater.Color = Color3.fromRGB(40, 20, 10)
		crater.Material = Enum.Material.Concrete
		crater.Anchored = true
		crater.CanCollide = false
		crater.Parent = workspace
		Debris:AddItem(crater, 5)

		local fireRing = Instance.new("Part")
		fireRing.Name = "ImpactFireRing"
		fireRing.Shape = Enum.PartType.Cylinder
		fireRing.Size = Vector3.new((payload.radius or 15) * 2, 0.3, (payload.radius or 15) * 2)
		fireRing.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		fireRing.Color = Color3.fromRGB(255, 100, 0)
		fireRing.Material = Enum.Material.Neon
		fireRing.Transparency = 0.4
		fireRing.Anchored = true
		fireRing.CanCollide = false
		fireRing.Parent = workspace
		Debris:AddItem(fireRing, 2)

	elseif etype == "ArmorPickup" then
		local shieldGlow = Instance.new("Part")
		shieldGlow.Size = Vector3.new(4, 0.2, 4)
		shieldGlow.Position = payload.position + Vector3.new(0, 0.5, 0)
		shieldGlow.Color = Color3.fromRGB(200, 200, 100)
		shieldGlow.Material = Enum.Material.Neon
		shieldGlow.Transparency = 0.4
		shieldGlow.Anchored = true
		shieldGlow.CanCollide = false
		shieldGlow.Parent = workspace
		Debris:AddItem(shieldGlow, 0.8)

	elseif etype == "PowerPickup" then
		local powerType = payload.powerType or "Health"
		local colorMap = {
			SpeedBoost = Color3.fromRGB(255, 200, 50),
			DamageBoost = Color3.fromRGB(255, 50, 50),
			Shield = Color3.fromRGB(50, 150, 255),
			Health = Color3.fromRGB(50, 255, 100),
		}
		local color = colorMap[powerType] or Color3.fromRGB(255, 255, 255)

		-- Burst particles
		for i = 1, 10 do
			task.spawn(function()
				local p = Instance.new("Part")
				p.Size = Vector3.new(0.3, 0.3, 0.3)
				p.Shape = Enum.PartType.Ball
				p.Color = color
				p.Material = Enum.Material.Neon
				p.Transparency = 0.4
				p.Anchored = false
				p.CanCollide = false
				p.Position = (payload.position or Vector3.new(0, 1, 0)) + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
				p.Parent = workspace
				Debris:AddItem(p, 1)

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-10, 10), math.random(3, 10), math.random(-10, 10))
				bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
				bv.Parent = p
				game:GetService("Debris"):AddItem(bv, 0.6)
			end)
		end

	elseif etype == "BombPlant" then
		local beacon = Instance.new("Part")
		beacon.Name = "BombBeacon"
		beacon.Size = Vector3.new(6, 0.3, 6)
		beacon.Position = payload.position + Vector3.new(0, 0.2, 0)
		beacon.Color = Color3.fromRGB(255, 100, 50)
		beacon.Material = Enum.Material.Neon
		beacon.Transparency = 0.3
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.Parent = workspace
		Debris:AddItem(beacon, payload.duration or 40)

		local beam = Instance.new("Part")
		beam.Name = "BombBeam"
		beam.Size = Vector3.new(0.5, 60, 0.5)
		beam.Position = payload.position + Vector3.new(0, 30, 0)
		beam.Color = Color3.fromRGB(255, 80, 30)
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.5
		beam.Anchored = true
		beam.CanCollide = false
		beam.Parent = workspace
		Debris:AddItem(beam, payload.duration or 40)

	elseif etype == "BombDefusing" then
		local ring = Instance.new("Part")
		ring.Name = "DefuseRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(6, 0.2, 6)
		ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = Color3.fromRGB(50, 150, 255)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.5
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 0.3)

	elseif etype == "BombExplosion" then
		local bigRing = Instance.new("Part")
		bigRing.Name = "BombExpRing"
		bigRing.Shape = Enum.PartType.Cylinder
		bigRing.Size = Vector3.new(40, 0.5, 40)
		bigRing.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		bigRing.Color = Color3.fromRGB(255, 200, 50)
		bigRing.Material = Enum.Material.Neon
		bigRing.Transparency = 0.2
		bigRing.Anchored = true
		bigRing.CanCollide = false
		bigRing.Parent = workspace
		Debris:AddItem(bigRing, 1)

		local fireball = Instance.new("Part")
		fireball.Name = "BombFireball"
		fireball.Shape = Enum.PartType.Ball
		fireball.Size = Vector3.new(20, 20, 20)
		fireball.Position = payload.position
		fireball.Color = Color3.fromRGB(255, 150, 30)
		fireball.Material = Enum.Material.Neon
		fireball.Transparency = 0.3
		fireball.Anchored = true
		fireball.CanCollide = false
		fireball.Parent = workspace
		Debris:AddItem(fireball, 2)

		for i = 1, 30 do
			task.spawn(function()
				local p = Instance.new("Part")
				p.Size = Vector3.new(0.5, 0.5, 0.5)
				p.Shape = Enum.PartType.Ball
				p.Color = Color3.fromRGB(255, math.random(80, 200), 30)
				p.Material = Enum.Material.Neon
				p.Transparency = 0.4
				p.Anchored = false
				p.CanCollide = false
				p.Position = payload.position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				p.Parent = workspace
				Debris:AddItem(p, 2)
				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-25, 25), math.random(15, 40), math.random(-25, 25))
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bv.Parent = p
				game:GetService("Debris"):AddItem(bv, 1)
			end)
		end

	elseif etype == "CTFFlagCapture" then
		-- Flag capture celebration
		local color = payload.teamColor or Color3.fromRGB(255, 255, 255)
		for i = 1, 4 do
			local ring = Instance.new("Part")
			ring.Name = "FlagCaptureRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.2, (payload.radius or 10) * i * 2, (payload.radius or 10) * i * 2)
			ring.CFrame = CFrame.new(payload.position + Vector3.new(0, i * 1.5, 0)) * CFrame.Angles(math.rad(90), 0, 0)
			ring.Color = color
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.5
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent = workspace
			Debris:AddItem(ring, 2 + i * 0.5)
end

	elseif etype == "KOTHZoneActive" then
		-- Hill control beam
		local beam = Instance.new("Part")
		beam.Name = "KOTHBeam"
		beam.Size = Vector3.new(0.5, 60, 0.5)
		beam.Position = payload.position + Vector3.new(0, 30, 0)
		beam.Color = payload.color or Color3.fromRGB(255, 215, 0)
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.6
		beam.Anchored = true
		beam.CanCollide = false
		beam.Parent = workspace
		Debris:AddItem(beam, payload.duration or 3)

	-- === KILL EFFECTS ===

	elseif etype == "ElectricShock" then
		-- Electric burst at kill position
		for i = 1, 6 do
			local bolt = Instance.new("Part")
			bolt.Size = Vector3.new(0.2, math.random(3, 8), 0.2)
			bolt.Position = payload.position + Vector3.new(math.random(-4, 4), math.random(0, 6), math.random(-4, 4))
			bolt.Color = Color3.fromRGB(255, 255, 100)
			bolt.Material = Enum.Material.Neon
			bolt.Transparency = 0.3
			bolt.Anchored = true
			bolt.CanCollide = false
			bolt.Parent = workspace
			Debris:AddItem(bolt, 0.4)
		end

	elseif etype == "GroundSlam" then
		-- Shockwave on ground
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 20, 20)
		ring.CFrame = CFrame.new(payload.position) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = Color3.fromRGB(200, 100, 50)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.4
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 0.5)

	elseif etype == "Disintegration" then
		-- Fading particle burst
		for i = 1, 16 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.3, 0.3, 0.3)
			p.Color = Color3.fromRGB(100, 150, 255)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.5
			p.Anchored = false
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-3, 3), math.random(-2, 2), math.random(-3, 3))
			p.Parent = workspace
			Debris:AddItem(p, 1)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-10, 10), math.random(5, 15), math.random(-10, 10))
			bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
			bv.Parent = p
			game:GetService("Debris"):AddItem(bv, 0.8)
		end

	elseif etype == "HealBurst" then
		-- Green healing burst
		for i = 1, 12 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.4, 0.4)
			p.Shape = Enum.PartType.Ball
			p.Color = Color3.fromRGB(50, 255, 120)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Anchored = false
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-3, 3), math.random(0, 4), math.random(-3, 3))
			p.Parent = workspace
			Debris:AddItem(p, 0.8)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-8, 8), math.random(5, 15), math.random(-8, 8))
			bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
			bv.Parent = p
			game:GetService("Debris"):AddItem(bv, 0.6)
		end

	elseif etype == "BigExplosion" then
		-- Large explosion effect
		explosion(payload.position, 16, Color3.fromRGB(255, 120, 30), 0.8)

	elseif etype == "GlitchExplode" then
		-- Digital glitch burst
		for i = 1, 10 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(math.random(5, 15) / 10, math.random(5, 15) / 10, 1)
			p.Color = Color3.fromRGB(math.random(150, 255), 0, math.random(150, 255))
			p.Material = Enum.Material.Neon
			p.Transparency = 0.3
			p.Anchored = true
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-5, 5), math.random(-3, 3), math.random(-5, 5))
			p.CFrame = CFrame.Angles(0, 0, math.rad(math.random(0, 360)))
			p.Parent = workspace
			Debris:AddItem(p, 0.5)
		end

	elseif etype == "TurretKill" then
		-- Mechanical burst
		for i = 1, 8 do
			local spark = Instance.new("Part")
			spark.Size = Vector3.new(0.2, 0.8, 0.2)
			spark.Color = Color3.fromRGB(255, 200, 50)
			spark.Material = Enum.Material.Neon
			spark.Transparency = 0.5
			spark.Anchored = false
			spark.CanCollide = false
			spark.Position = payload.position + Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
			spark.Parent = workspace
			Debris:AddItem(spark, 0.5)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-8, 8), math.random(2, 10), math.random(-8, 8))
			bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
			bv.Parent = spark
			game:GetService("Debris"):AddItem(bv, 0.4)
		end

	elseif etype == "EnergyBurst" then
		-- Cyan energy burst
		for i = 1, 14 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.3, 0.3, 0.3)
			p.Shape = Enum.PartType.Ball
			p.Color = Color3.fromRGB(0, 200, 255)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Anchored = false
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-4, 4), math.random(0, 5), math.random(-4, 4))
			p.Parent = workspace
			Debris:AddItem(p, 1)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-12, 12), math.random(5, 15), math.random(-12, 12))
			bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
			bv.Parent = p
			game:GetService("Debris"):AddItem(bv, 0.8)
		end

	elseif etype == "ShadowKill" then
		-- Dark shadow burst
		for i = 1, 8 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.4, 0.4)
			p.Color = Color3.fromRGB(20, 20, 30)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.3
			p.Anchored = false
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-3, 3), math.random(-1, 3), math.random(-3, 3))
			p.Parent = workspace
			Debris:AddItem(p, 0.8)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-8, 8), math.random(3, 10), math.random(-8, 8))
			bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
			bv.Parent = p
			game:GetService("Debris"):AddItem(bv, 0.6)
		end

	elseif etype == "TimeSnap" then
		-- Time fracture effect
		for i = 1, 6 do
			local shard = Instance.new("Part")
			shard.Size = Vector3.new(math.random(30, 60) / 10, 0.2, math.random(30, 60) / 10)
			shard.Color = Color3.fromRGB(100, 180, 255)
			shard.Material = Enum.Material.SmoothPlastic
			shard.Transparency = 0.4
			shard.Anchored = true
			shard.CanCollide = false
			shard.Position = payload.position + Vector3.new(math.random(-4, 4), math.random(0, 3), math.random(-4, 4))
			shard.CFrame = CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), 0)
			shard.Parent = workspace
			Debris:AddItem(shard, 0.6)
		end

	elseif etype == "PlasmaExplode" then
		-- Magenta plasma burst
		explosion(payload.position, 14, Color3.fromRGB(255, 50, 200), 0.6)
		for i = 1, 12 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.4, 0.4)
			p.Shape = Enum.PartType.Ball
			p.Color = Color3.fromRGB(255, 100, 220)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Anchored = false
			p.CanCollide = false
			p.Position = payload.position + Vector3.new(math.random(-4, 4), math.random(0, 5), math.random(-4, 4))
			p.Parent = workspace
			Debris:AddItem(p, 0.8)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-12, 12), math.random(5, 15), math.random(-12, 12))
			bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
			bv.Parent = p
			game:GetService("Debris"):AddItem(bv, 0.6)
		end

	elseif etype == "HammerSlam" then
		-- Ground pound shockwave
		explosion(payload.position, 18, Color3.fromRGB(200, 100, 50), 0.7)
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 28, 28)
		ring.CFrame = CFrame.new(payload.position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
		ring.Color = Color3.fromRGB(180, 80, 30)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.3
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = workspace
		Debris:AddItem(ring, 0.6)

	elseif etype == "Burning" then
		-- Burn death effect
		for i = 1, 14 do
			local flame = Instance.new("Part")
			flame.Size = Vector3.new(math.random(20, 50) / 10, math.random(20, 50) / 10, math.random(20, 50) / 10)
			flame.Color = Color3.fromRGB(255, math.random(60, 140), 0)
			flame.Material = Enum.Material.Neon
			flame.Transparency = 0.4
			flame.Anchored = false
			flame.CanCollide = false
			flame.Position = payload.position + Vector3.new(math.random(-3, 3), math.random(0, 4), math.random(-3, 3))
			flame.Parent = workspace
			Debris:AddItem(flame, 0.6)
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(math.random(-6, 6), math.random(3, 10), math.random(-6, 6))
			bv.MaxForce = Vector3.new(1e3, 1e3, 1e3)
			bv.Parent = flame
			game:GetService("Debris"):AddItem(bv, 0.5)
		end

	elseif etype == "SparkBurst" then
		-- Golden spark burst
		for i = 1, 18 do
			local spark = Instance.new("Part")
			spark.Size = Vector3.new(0.15, 0.15, math.random(30, 80) / 10)
			spark.Color = Color3.fromRGB(255, 220, 50)
			spark.Material = Enum.Material.Neon
			spark.Transparency = 0.3
			spark.Anchored = true
			spark.CanCollide = false
			spark.Position = payload.position + Vector3.new(math.random(-3, 3), math.random(-2, 3), math.random(-3, 3))
			spark.CFrame = CFrame.new(spark.Position, spark.Position + Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5)))
			spark.Parent = workspace
			Debris:AddItem(spark, 0.4)
		end

	elseif etype == "FreezeShatter" then
		-- Ice shatter effect
		for i = 1, 16 do
			local shard = Instance.new("Part")
			shard.Size = Vector3.new(math.random(20, 40) / 10, 0.15, math.random(20, 40) / 10)
			shard.Color = Color3.fromRGB(150, 220, 255)
			shard.Material = Enum.Material.SmoothPlastic
			shard.Transparency = 0.3
			shard.Anchored = true
			shard.CanCollide = false
			shard.Position = payload.position + Vector3.new(math.random(-4, 4), math.random(-2, 2), math.random(-4, 4))
			shard.CFrame = CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), 0)
			shard.Parent = workspace
Debris:AddItem(shard, 0.6)
		end

	end
end

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