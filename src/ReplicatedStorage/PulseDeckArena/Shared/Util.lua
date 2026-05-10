--!strict

local RunService = game:GetService("RunService")

local Util = {}

function Util.Clamp(v: number, minv: number, maxv: number): number
	if v < minv then
		return minv
	end
	if v > maxv then
		return maxv
	end
	return v
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.InverseLerp(a: number, b: number, v: number): number
	if b == a then return 0 end
	return (v - a) / (b - a)
end

function Util.MapRange(v, a, b, c, d)
	return c + (d - c) * Util.InverseLerp(a, b, v)
end

function Util.RandomVectorInCone(dir: Vector3, spreadDegrees: number): Vector3
	local theta = math.rad(spreadDegrees)
	local u = math.random()
	local v = math.random()
	local angle = math.acos(1 - u + u * math.cos(theta))
	local phi = 2 * math.pi * v
	local axis1 = dir:Cross(Vector3.new(0, 1, 0))
	if axis1.Magnitude < 0.01 then
		axis1 = dir:Cross(Vector3.new(1, 0, 0))
	end
	axis1 = axis1.Unit
	local axis2 = dir:Cross(axis1).Unit
	local offset = axis1 * math.sin(angle) * math.cos(phi) + axis2 * math.sin(angle) * math.sin(phi) + dir * math.cos(angle)
	return offset.Unit
end

function Util.MakePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, anchored: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = (anchored == nil) and true or anchored
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function Util.CreateBillboardGui(parent: Instance, name: string, size: UDim2, offset: Vector3, alwaysOnTop: boolean?)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = alwaysOnTop or false
	gui.Adornee = parent
	gui.Parent = parent
	return gui
end

function Util.AddCorner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

function Util.AddStroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(100, 100, 120)
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

function Util.AddPadding(parent: Instance, padding: number?)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, padding or 4)
	pad.PaddingBottom = UDim.new(0, padding or 4)
	pad.PaddingLeft = UDim.new(0, padding or 4)
	pad.PaddingRight = UDim.new(0, padding or 4)
	pad.Parent = parent
	return pad
end

function Util.AddGradient(parent: Instance, color0: Color3, color1: Color3, rot: number?)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color0, color1)
	grad.Rotation = rot or 0
	grad.Parent = parent
	return grad
end

function Util.Tween(instance, props, duration, style, dir, repeatCount)
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(
		duration or 0.3,
		style or Enum.EasingStyle.Quad,
		dir or Enum.EasingDirection.Out,
		repeatCount or 0,
		false,
		0
	)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function Util.Debounce(func, cooldown)
	local lastCall = 0
	return function(...)
		local now = os.clock()
		if now - lastCall < cooldown then return end
		lastCall = now
		return func(...)
	end
end

function Util.TagHumanoid(humanoid: Humanoid, tag: string)
	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Name = "creator"
	creatorTag.Value = tag
	creatorTag.Parent = humanoid
	game:GetService("Debris"):AddItem(creatorTag, 2)
end

function Util.HSVToRGB(h, s, v)
	local r, g, b
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	elseif i == 5 then r, g, b = v, p, q
	end
	return Color3.new(r, g, b)
end

function Util.ColorLerp(c1: Color3, c2: Color3, t: number): Color3
	return Color3.new(
		Util.Lerp(c1.R, c2.R, t),
		Util.Lerp(c1.G, c2.G, t),
		Util.Lerp(c1.B, c2.B, t)
	)
end

function Util.WorldToScreen(camera: Camera, worldPos: Vector3)
	local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

function Util.GetClosestPlayerToPoint(point: Vector3, ignorePlayer)
	local Players = game:GetService("Players")
	local closest, minDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= ignorePlayer and plr.Character then
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - point).Magnitude
				if d < minDist then
					minDist = d
					closest = plr
				end
			end
		end
	end
	return closest, minDist
end

function Util.CreateParticle(parent, name, textureId, color, size, lifetime, emitRate, speed, spreadAngle)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = parent

	local particles = Instance.new("ParticleEmitter")
	particles.Name = name or "Particles"
	particles.Texture = textureId or "rbxassetid://243098098"
	particles.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
	particles.Size = NumberSequence.new(size or 1, 0)
	particles.Lifetime = NumberRange.new(lifetime or 0.5, lifetime or 1)
	particles.Rate = emitRate or 30
	particles.Speed = NumberRange.new(speed or 5, speed or 15)
	particles.SpreadAngle = Vector2.new(spreadAngle or 30, spreadAngle or 30)
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Parent = attachment
	return particles, attachment
end

function Util.CreateMeshPart(name, shape, size, color, position, anchored, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = anchored or false
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

return Util