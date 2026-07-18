local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local AISystem = {
	Enabled = {},
	Brains = {},
	HeroSystem = nil,
	MatchSystem = nil,
	CombatSystem = nil,
	AbilitySystem = nil,
	Initialized = false,
	Difficulty = "Normal",
}

local DIFFICULTY = {
	Easy = {reaction = 0.65, aimError = 5.5, abilityChance = 0.15},
	Normal = {reaction = 0.4, aimError = 3.0, abilityChance = 0.3},
	Hard = {reaction = 0.25, aimError = 1.5, abilityChance = 0.45},
}

local function worldFolder(name)
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	return world and world:FindFirstChild(name)
end

local function lineOfSight(observer, target)
	if not observer.Root or not target.Root then return false end
	local origin = observer.Root.Position + Vector3.new(0, 1.5, 0)
	local direction = target.Root.Position + Vector3.new(0, 1.2, 0) - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {observer.Model}
	params.IgnoreWater = true
	local result = workspace:Raycast(origin, direction, params)
	if not result then return true end
	return result.Instance and result.Instance:IsDescendantOf(target.Model)
end

local function nearestObjective(hero)
	local objectives = worldFolder("Objectives")
	if not objectives then return nil end
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(objectives:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("Destroyed") ~= true and model:GetAttribute("ObjectiveTeam") ~= hero.TeamId then
			local distance = (model.PrimaryPart.Position - hero.Root.Position).Magnitude
			if distance < bestDistance then best, bestDistance = model.PrimaryPart, distance end
		end
	end
	return best
end

local function nearestAlly(hero)
	local best, bestDistance = nil, math.huge
	for _, candidate in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if candidate ~= hero and candidate.Alive and candidate.TeamId == hero.TeamId and candidate.Root then
			local distance = (candidate.Root.Position - hero.Root.Position).Magnitude
			if distance < bestDistance then best, bestDistance = candidate, distance end
		end
	end
	return best
end

local function threatScore(hero, target)
	if not target.Alive or target.TeamId == hero.TeamId or not target.Root then return -math.huge end
	local distance = (target.Root.Position - hero.Root.Position).Magnitude
	local score = 1000 / math.max(8, distance)
	local healthRatio = (target.Health or 0) / math.max(1, target.MaxHealth or 1)
	score += (1 - healthRatio) * 20
	if target.IsControlled then score += 8 end
	if target.MarkedUntil and os.clock() < target.MarkedUntil then score += 12 end
	if lineOfSight(hero, target) then score += 25 else score -= 15 end
	return score
end

local function chooseTarget(hero, brain)
	local best, bestScore = nil, -math.huge
	for _, candidate in pairs(AISystem.HeroSystem.HeroesByGuid) do
		local score = threatScore(hero, candidate)
		if score > bestScore then best, bestScore = candidate, score end
	end
	if best then
		brain.LastSeenTarget = best
		brain.LastSeenPosition = best.Root.Position
		brain.LastSeenAt = os.clock()
	end
	return best
end

local function moveTo(hero, brain, destination)
	if not destination or not hero.Humanoid or not hero.Root then return end
	if os.clock() - brain.LastPathAt < 0.8 and brain.MoveDestination and (brain.MoveDestination - destination).Magnitude < 6 then return end
	brain.LastPathAt = os.clock()
	brain.MoveDestination = destination
	local distance = (destination - hero.Root.Position).Magnitude
	if distance < 35 then
		hero.Humanoid:MoveTo(destination)
		return
	end
	local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8})
	local success = pcall(function() path:ComputeAsync(hero.Root.Position, destination) end)
	if not success or path.Status ~= Enum.PathStatus.Success then hero.Humanoid:MoveTo(destination) return end
	local waypoints = path:GetWaypoints()
	local waypoint = waypoints[math.min(2, #waypoints)]
	if waypoint then
		if waypoint.Action == Enum.PathWaypointAction.Jump then hero.Humanoid.Jump = true end
		hero.Humanoid:MoveTo(waypoint.Position)
	end
end

local function aimDirection(hero, target, profile)
	local origin = hero.Root.Position + Vector3.new(0, 1.4, 0)
	local targetPosition = target.Root.Position + Vector3.new(0, 1.2, 0)
	local velocity = target.Root.AssemblyLinearVelocity or Vector3.zero
	local weapon = WeaponConfig[hero.WeaponId] or {}
	local distance = (targetPosition - origin).Magnitude
	local leadTime = math.clamp(distance / (weapon.projectileSpeed or 700), 0, 0.35)
	targetPosition += velocity * leadTime
	local errorDegrees = profile.aimError
	local yaw = math.rad((math.random() - 0.5) * errorDegrees)
	local pitch = math.rad((math.random() - 0.5) * errorDegrees)
	return (CFrame.lookAt(origin, targetPosition) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function updateHero(hero, brain, dt)
	if not hero.Alive or not hero.Root or not hero.Humanoid then return end
	if AISystem.MatchSystem.State ~= "ActiveMatch" and AISystem.MatchSystem.State ~= "SuddenDeath" then return end
	local profile = DIFFICULTY[AISystem.Difficulty] or DIFFICULTY.Normal
	local target = chooseTarget(hero, brain)
	local healthRatio = (hero.Health or 0) / math.max(1, hero.MaxHealth or 1)
	if healthRatio < 0.28 then
		local ally = nearestAlly(hero)
		if ally then
			local away = hero.Root.Position - (target and target.Root.Position or ally.Root.Position)
			if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
			moveTo(hero, brain, ally.Root.Position + away.Unit * 10)
		else
			moveTo(hero, brain, hero.Root.Position - hero.Root.CFrame.LookVector * 18)
		end
		return
	end
	if not target then
		local objective = nearestObjective(hero)
		if objective then moveTo(hero, brain, objective.Position) end
		return
	end
	local distance = (target.Root.Position - hero.Root.Position).Magnitude
	local weapon = WeaponConfig[hero.WeaponId] or {}
	local preferred = math.clamp((weapon.range or 250) * 0.35, 18, 90)
	local visible = lineOfSight(hero, target)
	if not visible then
		if os.clock() - brain.LastSeenAt < 3 and brain.LastSeenPosition then moveTo(hero, brain, brain.LastSeenPosition)
		else moveTo(hero, brain, target.Root.Position) end
		return
	end
	if distance > preferred * 1.25 then
		moveTo(hero, brain, target.Root.Position)
	elseif distance < preferred * 0.45 then
		local retreat = (hero.Root.Position - target.Root.Position)
		if retreat.Magnitude > 0.1 then moveTo(hero, brain, hero.Root.Position + retreat.Unit * 14) end
	else
		local side = hero.Root.CFrame.RightVector * (brain.StrafeDirection or 1) * 8
		moveTo(hero, brain, hero.Root.Position + side)
		if math.random() < 0.08 then brain.StrafeDirection = -(brain.StrafeDirection or 1) end
	end
	if os.clock() >= brain.NextFireAt then
		brain.NextFireAt = os.clock() + math.max(profile.reaction, weapon.fireInterval or 0.1)
		AISystem.CombatSystem.FireWeapon(hero, aimDirection(hero, target, profile))
	end
	if AISystem.AbilitySystem and os.clock() >= brain.NextAbilityAt and math.random() < profile.abilityChance then
		brain.NextAbilityAt = os.clock() + 7 + math.random() * 5
		AISystem.AbilitySystem.UseAbility(hero, {direction = (target.Root.Position - hero.Root.Position).Unit})
	end
	if AISystem.AbilitySystem and (hero.UltimateCharge or 0) >= (hero.UltimateChargeMax or 100) and distance < preferred then
		AISystem.AbilitySystem.UseUltimate(hero)
	end
end

function AISystem.Init(heroSystem, matchSystem, combatSystem, abilitySystem)
	AISystem.HeroSystem = heroSystem
	AISystem.MatchSystem = matchSystem
	AISystem.CombatSystem = combatSystem
	AISystem.AbilitySystem = abilitySystem
	if AISystem.Initialized then return end
	AISystem.Initialized = true
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then return end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for guid, enabled in pairs(AISystem.Enabled) do
			if enabled then
				local hero = AISystem.HeroSystem.HeroesByGuid[guid]
				local brain = AISystem.Brains[guid]
				if hero and brain and now >= brain.NextThinkAt then
					brain.NextThinkAt = now + 0.1 + (brain.Offset or 0)
					updateHero(hero, brain, step)
				elseif not hero then
					AISystem.Enabled[guid] = nil
					AISystem.Brains[guid] = nil
				end
			end
		end
	end)
end

function AISystem.EnableHeroAI(hero, enabled)
	if not hero or not hero.Guid then return end
	AISystem.Enabled[hero.Guid] = enabled == true
	if enabled then
		AISystem.Brains[hero.Guid] = AISystem.Brains[hero.Guid] or {
			NextThinkAt = os.clock() + math.random() * 0.2,
			NextFireAt = os.clock() + 0.5,
			NextAbilityAt = os.clock() + 3 + math.random() * 4,
			LastPathAt = 0,
			LastSeenAt = 0,
			StrafeDirection = math.random() < 0.5 and -1 or 1,
			Offset = math.random() * 0.04,
		}
	else
		AISystem.Brains[hero.Guid] = nil
	end
end

function AISystem.Clear()
	AISystem.Enabled = {}
	AISystem.Brains = {}
end

return AISystem
