--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local AISystem = {}

AISystem.Enabled = {}
AISystem.HeroSystem = nil
AISystem.MatchSystem = nil
AISystem.CombatSystem = nil
AISystem.AbilitySystem = nil
AISystem.WaypointCache = {}

-- AI difficulty profiles
AISystem.AIProfiles = {
	Flanker = {
		aggressiveness = 0.8,
		preferCloseRange = true,
		strafeChance = 0.6,
		abilityUsageChance = 0.5,
		retreatHealthThreshold = 0.3,
	},
	Frontline = {
		aggressiveness = 0.6,
		preferCloseRange = false,
		strafeChance = 0.3,
		abilityUsageChance = 0.4,
		retreatHealthThreshold = 0.2,
	},
	Backline = {
		aggressiveness = 0.4,
		preferCloseRange = false,
		strafeChance = 0.2,
		abilityUsageChance = 0.6,
		retreatHealthThreshold = 0.25,
	},
	Support = {
		aggressiveness = 0.2,
		preferCloseRange = false,
		strafeChance = 0.3,
		abilityUsageChance = 0.8,
		retreatHealthThreshold = 0.4,
	},
	Siege = {
		aggressiveness = 0.5,
		preferCloseRange = false,
		strafeChance = 0.2,
		abilityUsageChance = 0.7,
		retreatHealthThreshold = 0.25,
	},
	Assassin = {
		aggressiveness = 0.9,
		preferCloseRange = true,
		strafeChance = 0.8,
		abilityUsageChance = 0.7,
		retreatHealthThreshold = 0.2,
	},
	Controller = {
		aggressiveness = 0.4,
		preferCloseRange = false,
		strafeChance = 0.3,
		abilityUsageChance = 0.6,
		retreatHealthThreshold = 0.3,
	},
	Defender = {
		aggressiveness = 0.3,
		preferCloseRange = false,
		strafeChance = 0.15,
		abilityUsageChance = 0.5,
		retreatHealthThreshold = 0.15,
	},
}

local function getLanePoints(laneName)
	if AISystem.WaypointCache[laneName] then
		return AISystem.WaypointCache[laneName]
	end
	local waypointsFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:WaitForChild("Waypoints")
	if not waypointsFolder then return {} end
	local laneFolder = waypointsFolder:FindFirstChild(laneName)
	local points = {}
	if laneFolder then
		for _, child in ipairs(laneFolder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(points, child.Position)
			end
		end
		table.sort(points, function(a, b)
			return a.X < b.X
		end)
	end
	AISystem.WaypointCache[laneName] = points
	return points
end

local function reverseList(list)
	local out = {}
	for i = #list, 1, -1 do
		table.insert(out, list[i])
	end
	return out
end

local function getRandomPointInRadius(center, radius)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	return center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function isBehindCover(hero, enemy)
	-- Check if there are cover objects between hero and enemy
	local direction = (enemy.Root.Position - hero.Root.Position).Unit
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {hero.Model, enemy.Model}

	local ray = workspace:Raycast(hero.Root.Position + Vector3.new(0, 1, 0), direction * 50, rayParams)
	if ray then
		-- Check if it hit a map object (cover)
		if ray.Instance and ray.Instance.Parent and ray.Instance.Parent.Name == "Map" then
			return true, ray.Position
		end
	end
	return false, nil
end

local function findCoverPosition(hero, enemy)
	-- Try to find cover relative to enemy
	local enemyPos = enemy.Root.Position
	local heroPos = hero.Root.Position
	local dirAway = (heroPos - enemyPos).Unit

	-- Look for cover objects
	local mapFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Map")
	if not mapFolder then return nil end

	local bestCover = nil
	local bestCoverScore = -1

	for _, part in ipairs(mapFolder:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:find("Cover") then
			local coverPos = part.Position
			local distToCover = (heroPos - coverPos).Magnitude
			local distFromEnemy = (enemyPos - coverPos).Magnitude

			if distToCover < 30 and distFromEnemy < 20 then
				-- Check if cover actually blocks line of sight
				local toCover = (coverPos - heroPos).Unit
				local dot = toCover:Dot(dirAway)
				if dot > 0.3 then
					local score = distFromEnemy - distToCover
					if score > bestCoverScore then
						bestCoverScore = score
						bestCover = coverPos + Vector3.new(0, 2, 0)
					end
				end
			end
		end
	end

	return bestCover
end

local function getTeammatePositions(hero)
	local positions = {}
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId == hero.TeamId and h ~= hero and not h.IsControlled then
			table.insert(positions, h.Root.Position)
		end
	end
	return positions
end

local function getEnemiesInRadius(hero, radius)
	local enemies = {}
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= radius then
				table.insert(enemies, {hero = h, distance = d})
			end
		end
	end
	table.sort(enemies, function(a, b) return a.distance < b.distance end)
	return enemies
end

local function getNearbyAllies(hero, radius)
	local allies = {}
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId == hero.TeamId and h ~= hero then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= radius then
				table.insert(allies, h)
			end
		end
	end
	return allies
end

local function getNearestEnemyObjective(hero, range)
	local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
	if not objectivesFolder then return nil end
	local best = nil
	local bestDist = math.huge
	for _, objective in ipairs(objectivesFolder:GetChildren()) do
		if objective:IsA("Model") and objective.PrimaryPart then
			local teamId = objective:GetAttribute("ObjectiveTeam")
			local destroyed = objective:GetAttribute("Destroyed")
			if teamId ~= hero.TeamId and not destroyed then
				local d = (objective.PrimaryPart.Position - hero.Root.Position).Magnitude
				if d < bestDist and d <= range then
					best = objective
					bestDist = d
				end
			end
		end
	end
	return best
end

local function getLowestHealthEnemy(hero, range)
	local best = nil
	local bestHealth = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= range and h.Health < bestHealth then
				best = h
				bestHealth = h.Health
			end
		end
	end
	return best
end

local function findFleePosition(hero)
	-- Find direction away from nearest enemy
	local nearestEnemy = nil
	local nearestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearestEnemy = h
			end
		end
	end

	if nearestEnemy then
		local fleeDir = (hero.Root.Position - nearestEnemy.Root.Position).Unit
		local targetPos = hero.Root.Position + fleeDir * 20
		-- Clamp to arena bounds
		targetPos = Vector3.new(
			Util.Clamp(targetPos.X, -140, 140),
			targetPos.Y,
			Util.Clamp(targetPos.Z, -95, 95)
		)
		return targetPos
	end

	-- Fallback: retreat to spawn
	local spawnPoints = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
	return spawnPoints[1]
end

local function shouldUseAbility(hero, profile)
	if not AISystem.AbilitySystem then return false end
	if os.clock() < hero.AbilityReadyAt then return false end
	local chance = AISystem.AIProfiles[profile] and AISystem.AIProfiles[profile].abilityUsageChance or 0.4
	return math.random() < chance
end

local function shouldUseUltimate(hero)
	if hero.UltimateCharge < hero.UltimateChargeMax then return false end
	return math.random() < 0.3
end

function AISystem.Init(heroSystem, matchSystem, combatSystem, abilitySystem)
	AISystem.HeroSystem = heroSystem
	AISystem.MatchSystem = matchSystem
	AISystem.CombatSystem = combatSystem
	AISystem.AbilitySystem = abilitySystem

	RunService.Heartbeat:Connect(function()
		if not AISystem.MatchSystem then return end
		local state = AISystem.MatchSystem.State
		if state ~= "ActiveMatch" and state ~= "SuddenDeath" then return end

		for hero, enabled in pairs(AISystem.Enabled) do
			if enabled and hero.Alive and not hero.IsControlled then
				AISystem.Think(hero)
			end
		end

		-- Update AI-controlled heroes' movement smoothing
		for _, hero in pairs(AISystem.HeroSystem.HeroesByGuid) do
			if not hero.IsControlled and hero.Alive then
				-- Update LastKnownPosition for tracking
				hero.LastKnownPosition = hero.Root.Position

				-- Apply overcharge speed boost
				if hero.ActiveEffects and hero.ActiveEffects.overcharge then
					local heroDef = HeroConfig[hero.HeroId]
					hero.Humanoid.WalkSpeed = heroDef.walkSpeed * hero.ActiveEffects.overcharge.SpeedMultiplier
				end

				-- Apply fortify (cannot move)
				if hero.ActiveEffects and hero.ActiveEffects.fortify then
					hero.Humanoid.WalkSpeed = 0.01
				end
			end
		end
	end)

	-- AI damage assist tracking
	AISystem.LastHitMemory = {}
end

function AISystem.EnableHeroAI(hero, enabled)
	AISystem.Enabled[hero] = enabled
	if enabled then
		hero.AILastThink = 0
		hero.AILane = nil
		hero.AIWaypointIndex = nil
		hero.AILastPos = nil
		hero.AIStuckCounter = 0
		hero.AIAttackTarget = nil
		hero.AILastSwitchCover = 0
	end
end

function AISystem.Clear()
	AISystem.Enabled = {}
	AISystem.WaypointCache = {}
end

function AISystem.FindNearestEnemy(hero, range)
	local best = nil
	local bestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.TeamId ~= hero.TeamId and h.Alive and not h.IsStealthed then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < bestDist and d <= range then
				best = h
				bestDist = d
			end
		end
	end
	return best, bestDist
end

function AISystem.FindNearestEnemyObjective(hero, range)
	local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
	if not objectivesFolder then return nil end
	local best = nil
	local bestDist = math.huge
	for _, objective in ipairs(objectivesFolder:GetChildren()) do
		if objective:IsA("Model") and objective.PrimaryPart then
			local teamId = objective:GetAttribute("ObjectiveTeam")
			local destroyed = objective:GetAttribute("Destroyed")
			if teamId ~= hero.TeamId and not destroyed then
				local d = (objective.PrimaryPart.Position - hero.Root.Position).Magnitude
				if d < bestDist and d <= range then
					best = objective
					bestDist = d
				end
			end
		end
	end
	return best
end

function AISystem.FindNearestAlly(hero)
	local best = nil
	local bestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.TeamId == hero.TeamId and h.Alive and h ~= hero then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < bestDist then
				best = h
				bestDist = d
			end
		end
	end
	return best, bestDist
end

function AISystem.GetLaneForHero(hero)
	if hero.AILane then return hero.AILane end

	local profile = HeroConfig[hero.HeroId].aiProfile
	if profile == "Flanker" or profile == "Assassin" then
		hero.AILane = math.random() > 0.5 and "Lane_Upper" or "Lane_Lower"
	elseif profile == "Backline" then
		hero.AILane = "Lane_Main"
	else
		hero.AILane = "Lane_Main"
	end
	return hero.AILane
end

function AISystem.AdvanceLane(hero)
	local laneName = AISystem.GetLaneForHero(hero)
	local points = getLanePoints(laneName)
	if #points == 0 then return end

	local ordered = points
	if hero.TeamId == Config.TEAM_BLUE then
		ordered = reverseList(points)
	end

	if not hero.AIWaypointIndex then
		hero.AIWaypointIndex = 1
	end

	local idx = hero.AIWaypointIndex
	local target = ordered[idx]
	hero.Humanoid:MoveTo(target)

	if (hero.Root.Position - target).Magnitude < 5 then
		hero.AIWaypointIndex = math.clamp(idx + 1, 1, #ordered)
	end
end

function AISystem.RetreatToBase(hero)
	local points = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
	local nearest = points[1]
	local best = math.huge
	for _, pos in ipairs(points) do
		local d = (hero.Root.Position - pos).Magnitude
		if d < best then
			best = d
			nearest = pos
		end
	end

	-- Add some randomness to retreat position
	local retreatPos = nearest + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	hero.Humanoid:MoveTo(retreatPos)
end

function AISystem.SeekCover(hero, enemy)
	local coverPos = findCoverPosition(hero, enemy)
	if coverPos then
		hero.Humanoid:MoveTo(coverPos)
		return true
	end
	return false
end

function AISystem.StrafeCombat(hero, enemy)
	-- Strafe perpendicular to the enemy direction
	local dirToEnemy = (hero.Root.Position - enemy.Root.Position).Unit
	local perp = Vector3.new(-dirToEnemy.Z, 0, dirToEnemy.X)

	-- Alternate strafe direction
	if not hero.AIStrafeDir or math.random() < 0.05 then
		hero.AIStrafeDir = math.random() > 0.5 and 1 or -1
	end

	local strafeTarget = hero.Root.Position + perp * hero.AIStrafeDir * 8

	-- Keep in bounds
	strafeTarget = Vector3.new(
		Util.Clamp(strafeTarget.X, -135, 135),
		strafeTarget.Y,
		Util.Clamp(strafeTarget.Z, -92, 92)
	)

	hero.Humanoid:MoveTo(strafeTarget)
end

function AISystem.Think(hero)
	if hero.AILastThink and (os.clock() - hero.AILastThink) < 0.3 then
		return
	end
	hero.AILastThink = os.clock()

	local profile = HeroConfig[hero.HeroId].aiProfile
	local aiProfile = AISystem.AIProfiles[profile]
	local aggressiveness = aiProfile and aiProfile.aggressiveness or 0.5

	local weapon = WeaponConfig[hero.WeaponId]
	local range = weapon and weapon.range or 150

	-- Check health and retreat if needed
	local healthPercent = hero.Health / hero.MaxHealth
	if healthPercent < (aiProfile and aiProfile.retreatHealthThreshold or 0.25) then
		-- Use defensive ability if available
		if shouldUseAbility(hero, profile) and hero.AbilityId then
			local abilityCfg = AbilityConfig[hero.AbilityId]
			if abilityCfg and (abilityCfg.kind == "DefensiveDeployable" or abilityCfg.kind == "DefensiveSelf") then
				AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			end
		end

		-- Retreat
		if math.random() < aggressiveness * 0.5 then
			-- Try to strafe while retreating
			if math.random() < 0.4 and aiProfile and aiProfile.strafeChance > 0.5 then
				AISystem.StrafeCombat(hero, AISystem.FindNearestEnemy(hero, 100))
			else
				AISystem.RetreatToBase(hero)
			end
		else
			AISystem.RetreatToBase(hero)
		end
		return
	end

	-- Support heroes: prioritize healing allies
	if profile == "Support" then
		local allies = getNearbyAllies(hero, 25)
		local needsHeal = false
		for _, ally in ipairs(allies) do
			if ally.Health / ally.MaxHealth < 0.6 then
				needsHeal = true
				break
			end
		end

		if needsHeal and shouldUseAbility(hero, profile) then
			AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			hero.Humanoid:MoveTo(hero.Root.Position) -- Stay in place while healing
			return
		end

		-- Follow nearest low-health ally
		local nearestLowAlly = nil
		local bestDist = math.huge
		for _, ally in ipairs(allies) do
			if ally.Health / ally.MaxHealth < 0.75 then
				local d = (ally.Root.Position - hero.Root.Position).Magnitude
				if d < bestDist then
					bestDist = d
					nearestLowAlly = ally
				end
			end
		end

		if nearestLowAlly and bestDist > 8 then
			hero.Humanoid:MoveTo(nearestLowAlly.Root.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
			return
		end
	end

	-- Try to use ultimate when ready and in combat
	if shouldUseUltimate(hero) then
		local nearestEnemy = AISystem.FindNearestEnemy(hero, range)
		if nearestEnemy then
			AISystem.AbilitySystem.UseUltimate(hero)
		end
	end

	-- Try to use ability
	if shouldUseAbility(hero, profile) then
		local nearestEnemy = AISystem.FindNearestEnemy(hero, range)
		if nearestEnemy and hero.AbilityId then
			local abilityCfg = AbilityConfig[hero.AbilityId]
			if abilityCfg then
				if abilityCfg.kind == "Teleport" then
					-- Blink to behind enemy
					AISystem.AbilitySystem.UseAbility(hero, {direction = (hero.Root.Position - nearestEnemy.Root.Position).Unit})
				elseif abilityCfg.kind == "Mobility" and (aiProfile and aiProfile.preferCloseRange) then
					-- Close gap
					local dist = (hero.Root.Position - nearestEnemy.Root.Position).Magnitude
					if dist > 15 then
						AISystem.AbilitySystem.UseAbility(hero, {direction = (nearestEnemy.Root.Position - hero.Root.Position).Unit})
					end
				elseif abilityCfg.kind == "AreaBurst" then
					-- Use AOE when multiple enemies nearby
					local enemies = getEnemiesInRadius(hero, 15)
					if #enemies >= 2 then
						AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
					end
				else
					AISystem.AbilitySystem.UseAbility(hero, {direction = (nearestEnemy.Root.Position - hero.Root.Position).Unit})
				end
			end
		elseif hero.AbilityId and math.random() < 0.3 then
			-- Occasionally use ability on objectives
			local objective = getNearestEnemyObjective(hero, 50)
			if objective then
				AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			end
		end
	end

	-- Find target
	local target, targetDist = AISystem.FindNearestEnemy(hero, range * 1.2)

	if target then
		-- Seek cover when under fire
		local hasCover, coverPos = isBehindCover(hero, target)
		if not hasCover and aiProfile and aiProfile.strafeChance > math.random() and targetDist < 30 then
			-- Strafe in combat
			AISystem.StrafeCombat(hero, target)
		elseif hasCover and targetDist > 10 then
			-- Use cover - peek and shoot
			hero.Humanoid:MoveTo(coverPos)
		elseif targetDist > (range * 0.6) then
			-- Move closer to target
			local moveTarget = target.Root.Position + (hero.Root.Position - target.Root.Position).Unit * 8
			hero.Humanoid:MoveTo(moveTarget)
		elseif targetDist < 8 and (aiProfile and aiProfile.preferCloseRange) then
			-- Circle strafe at close range
			AISystem.StrafeCombat(hero, target)
		else
			-- Hold position and shoot
			hero.Humanoid:MoveTo(hero.Root.Position + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
		end

		-- Fire at target
		local dir = (target.Root.Position - hero.Root.Position).Unit
		AISystem.CombatSystem.FireWeapon(hero, dir)
		hero.AIAttackTarget = target.Guid
	else
		hero.AIAttackTarget = nil

		-- No visible enemy - advance on objective or lane
		local objective = getNearestEnemyObjective(hero, 80)
		if objective and math.random() < aggressiveness then
			-- Move toward objective
			local objectivePos = objective.PrimaryPart.Position
			-- Add slight randomness
			local targetPos = objectivePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			hero.Humanoid:MoveTo(targetPos)

			-- Fire toward objective if in range
			local dist = (hero.Root.Position - objectivePos).Magnitude
			if dist < range then
				local dir = (objectivePos - hero.Root.Position).Unit
				AISystem.CombatSystem.FireWeapon(hero, dir)
			end
		else
			-- Follow lane waypoints
			AISystem.AdvanceLane(hero)
		end
	end

	-- Defend generators when low health
	if profile == "Defender" or (profile == "Frontline" and math.random() < 0.3) then
		local myGenerators = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_GENERATORS or Config.MAP.BLUE_GENERATORS
		if myGenerators then
			for _, genPos in ipairs(myGenerators) do
				local dist = (hero.Root.Position - genPos).Magnitude
				if dist > 20 and dist < 40 and math.random() < 0.3 then
					hero.Humanoid:MoveTo(genPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
					break
				end
			end
		end
	end
end

return AISystem