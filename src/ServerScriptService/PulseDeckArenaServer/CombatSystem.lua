local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local CombatSystem = {Objectives = {}, ActivePickups = {}}

local function getRemotes()
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	return root and root:FindFirstChild("Remotes")
end

local function effect(payload)
	local folder = getRemotes()
	local remote = folder and folder:FindFirstChild("EffectsEvent")
	if remote then remote:FireAllClients(payload) end
end

local function damageNumber(player, payload)
	local folder = getRemotes()
	local remote = folder and folder:FindFirstChild("DamageNumberEvent")
	if remote and player then remote:FireClient(player, payload) end
end

local function rayParams(hero)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = hero and hero.Model and {hero.Model} or {}
	return params
end

local function fireOrigin(hero)
	return hero.Root.Position + Vector3.new(0, 1.45, 0)
end

local function falloff(weapon, distance)
	local startDistance = weapon.falloffStart
	local endDistance = weapon.falloffEnd
	if not startDistance or not endDistance or distance <= startDistance then return 1 end
	if distance >= endDistance then return weapon.falloffMultiplierAtEnd or 1 end
	local alpha = (distance - startDistance) / math.max(1, endDistance - startDistance)
	return 1 - (1 - (weapon.falloffMultiplierAtEnd or 1)) * alpha
end

local function spreadDirection(direction, degrees)
	local spread = math.rad(math.max(0, degrees or 0))
	if spread <= 0 then return direction.Unit end
	local yaw = (math.random() - 0.5) * spread
	local pitch = (math.random() - 0.5) * spread
	return (CFrame.lookAt(Vector3.zero, direction.Unit) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function attackerPlayer(hero)
	if not hero or type(hero.OwnerId) ~= "number" then return nil end
	return game:GetService("Players"):GetPlayerByUserId(hero.OwnerId)
end

function CombatSystem.Init()
	CombatSystem.Objectives = {}
	CombatSystem.ActivePickups = {}
end

function CombatSystem.RegisterObjective(model, teamId, health, objectiveType)
	if not model or not model:IsA("Model") then return end
	CombatSystem.Objectives[model] = {TeamId = teamId, Name = objectiveType, Health = health, MaxHealth = health, Model = model}
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("ObjectiveTeam", teamId)
	model:SetAttribute("ObjectiveType", objectiveType)
end

function CombatSystem.CreateObjective(name, teamId, health, position)
	local model = Instance.new("Model")
	model.Name = name
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(8, 8, 8)
	core.Position = position
	core.Anchored = true
	core.Material = Enum.Material.Neon
	core.Color = teamId == Config.TEAM_RED and Config.RED_COLOR or Config.BLUE_COLOR
	core.Parent = model
	model.PrimaryPart = core
	model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
	CombatSystem.RegisterObjective(model, teamId, health, name)
	return model
end

function CombatSystem.GetObjectiveFromPart(part)
	local current = part
	while current and current ~= workspace do
		if CombatSystem.Objectives[current] then return current, CombatSystem.Objectives[current] end
		current = current.Parent
	end
	return nil
end

function CombatSystem.GetObjectiveSnapshot()
	local snapshot = {}
	for model, objective in pairs(CombatSystem.Objectives) do
		snapshot[model.Name] = {
			objectiveType = objective.Name,
			teamId = objective.TeamId,
			health = objective.Health,
			maxHealth = objective.MaxHealth,
			alive = objective.Health > 0,
			position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
		}
	end
	return snapshot
end

function CombatSystem.DamageObjective(model, amount, attackingTeam)
	local objective = CombatSystem.Objectives[model]
	if not objective or objective.Health <= 0 or objective.TeamId == attackingTeam then return 0 end
	local applied = math.max(0, tonumber(amount) or 0)
	if objective.Name == "Core" then
		local aliveGenerators = 0
		for _, other in pairs(CombatSystem.Objectives) do
			if other.TeamId == objective.TeamId and other.Name == "Generator" and other.Health > 0 then aliveGenerators += 1 end
		end
		if aliveGenerators >= 2 then applied *= 0.4 elseif aliveGenerators == 1 then applied *= 0.65 end
	end
	objective.Health = math.max(0, objective.Health - applied)
	model:SetAttribute("Health", objective.Health)
	effect({effectType = "ObjectiveHit", position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero, damageAmount = applied})
	local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
	if objective.Name == "Core" then MatchSystem.RecordCoreDamage(attackingTeam, applied) end
	if objective.Health <= 0 then
		model:SetAttribute("Destroyed", true)
		effect({effectType = "ObjectiveDestroyed", position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero, teamId = attackingTeam})
		if objective.Name == "Generator" then MatchSystem.AddScore(attackingTeam, Config.SCORE_GENERATOR_DESTROY or 100)
		elseif objective.Name == "Core" then MatchSystem.OnCoreDestroyed(attackingTeam) end
	end
	return applied
end

function CombatSystem.ApplyDamage(attacker, target, amount, damageType, isHeadshot, options)
	options = options or {}
	if not target or not target.Alive or not target.Humanoid then return 0 end
	if target.InvulnerableUntil and os.clock() < target.InvulnerableUntil then return 0 end
	local selfDamage = attacker == target
	if attacker and attacker.TeamId == target.TeamId and not selfDamage and not options.allowFriendlyFire then return 0 end
	local value = math.max(0, tonumber(amount) or 0)
	if value <= 0 then return 0 end
	local ok, AbilitySystem = pcall(require, script.Parent:WaitForChild("AbilitySystem"))
	if ok then
		value *= 1 - math.clamp(AbilitySystem.GetDamageReduction(target) or 0, 0, 0.9)
		if attacker and AbilitySystem.IsMarked(target, attacker) then value *= 1.2 end
	end
	if target.ActiveEffects and target.ActiveEffects.fortify then
		value *= 1 - math.clamp(target.ActiveEffects.fortify.DamageReduction or 0, 0, 0.9)
	end
	local shield = math.min(target.ShieldHealth or 0, value)
	target.ShieldHealth = math.max(0, (target.ShieldHealth or 0) - shield)
	value -= shield
	local healthDamage = math.min(target.Health or target.Humanoid.Health, value)
	target.Health = math.max(0, (target.Health or target.Humanoid.Health) - healthDamage)
	target.Humanoid.Health = target.Health
	if attacker then attacker.DamageDealt = (attacker.DamageDealt or 0) + healthDamage end
	local player = attackerPlayer(attacker)
	if player and healthDamage > 0 then damageNumber(player, {amount = healthDamage, position = target.Root and target.Root.Position or Vector3.zero, isHeadshot = isHeadshot == true}) end
	if target.Health <= 0 and target.Alive then
		target.Alive = false
		target.DeathCount = (target.DeathCount or 0) + 1
		if attacker and attacker ~= target then attacker.KillCount = (attacker.KillCount or 0) + 1 end
		local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
		if attacker and MatchSystem.GameMode == "FFA" and type(attacker.OwnerId) == "number" then MatchSystem.AddFFAKill(attacker.OwnerId)
		elseif attacker and attacker.TeamId and attacker.TeamId ~= Config.TEAM_NONE then MatchSystem.AddScore(attacker.TeamId, Config.SCORE_KILL or 10) end
		if type(target.OwnerId) == "number" then MatchSystem.ResetKillstreak(target.OwnerId, attacker and attacker.OwnerId or nil) end
		local folder = getRemotes()
		local killfeed = folder and folder:FindFirstChild("KillfeedEvent")
		if killfeed then killfeed:FireAllClients({killerName = attacker and attacker.DisplayName or "Arena", victimName = target.DisplayName or target.HeroId, weaponId = attacker and attacker.WeaponId or damageType, isHeadshot = isHeadshot == true, killCount = attacker and attacker.KillCount or 0}) end
	end
	return healthDamage + shield
end

local function resolveHit(attacker, result, weapon, damage, isHeadshot)
	if not result then return end
	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	local target = HeroSystem.GetHeroFromPart(result.Instance)
	if target then
		CombatSystem.ApplyDamage(attacker, target, damage, weapon.id, isHeadshot)
		return
	end
	local objectiveModel = CombatSystem.GetObjectiveFromPart(result.Instance)
	if objectiveModel then CombatSystem.DamageObjective(objectiveModel, damage, attacker.TeamId) end
end

local function fireRay(hero, weapon, direction, damage)
	local origin = fireOrigin(hero)
	local castDirection = spreadDirection(direction, weapon.spreadDegrees) * (weapon.range or 400)
	local result = workspace:Raycast(origin, castDirection, rayParams(hero))
	local endpoint = result and result.Position or origin + castDirection
	local distance = (endpoint - origin).Magnitude
	local isHeadshot = result and result.Instance and result.Instance.Name == "Head" or false
	local finalDamage = damage * falloff(weapon, distance) * (isHeadshot and (weapon.headMultiplier or 1) or 1)
	resolveHit(hero, result, weapon, finalDamage, isHeadshot)
	effect({effectType = "Tracer", position = origin, endPosition = endpoint, color = weapon.tracerColor, duration = 0.08, heroGuid = hero.Guid})
end

function CombatSystem.FireWeapon(hero, direction)
	if not hero or not hero.Alive or not hero.Root or hero.IsReloading or hero.Stunned then return false end
	local weapon = WeaponConfig[hero.WeaponId]
	if not weapon or not hero.Ammo or hero.Ammo <= 0 then return false end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.001 then return false end
	hero.Ammo -= 1
	hero.IsStealthed = false
	local behavior = weapon.behavior or "HitscanAuto"
	if behavior == "Shotgun" then
		for _ = 1, weapon.pellets or 8 do fireRay(hero, weapon, direction.Unit, weapon.damagePerPellet or weapon.damage or 8) end
	elseif behavior == "Beam" then
		fireRay(hero, weapon, direction.Unit, (weapon.damagePerTick or weapon.damage or 10))
	elseif behavior == "Melee" then
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, target in pairs(HeroSystem.HeroesByGuid) do
			if target.Alive and target ~= hero and target.TeamId ~= hero.TeamId and (target.Root.Position - hero.Root.Position).Magnitude <= (weapon.range or 8) then CombatSystem.ApplyDamage(hero, target, weapon.damage or 35, weapon.id) end
		end
	else
		fireRay(hero, weapon, direction.Unit, weapon.damage or weapon.maxDamage or 10)
	end
	effect({effectType = "MuzzleFlash", position = fireOrigin(hero), color = weapon.muzzleFlashColor, heroGuid = hero.Guid})
	if hero.Ammo <= 0 and (hero.ReserveAmmo or 0) > 0 then CombatSystem.RequestReload(hero) end
	return true
end

function CombatSystem.RequestReload(hero)
	if not hero or not hero.Alive or hero.IsReloading then return false end
	local weapon = WeaponConfig[hero.WeaponId]
	if not weapon or hero.Ammo >= (weapon.magazineSize or 1) or (hero.ReserveAmmo or 0) <= 0 then return false end
	hero.IsReloading = true
	local weaponId = hero.WeaponId
	local duration = math.max(0.1, weapon.reloadTime or 1.5)
	effect({effectType = "Reload", heroGuid = hero.Guid, position = hero.Root.Position, duration = duration})
	task.delay(duration, function()
		if not hero.Alive or hero.WeaponId ~= weaponId then hero.IsReloading = false return end
		local current = WeaponConfig[hero.WeaponId]
		if not current then hero.IsReloading = false return end
		local needed = math.max(0, (current.magazineSize or 1) - hero.Ammo)
		local taken = math.min(needed, hero.ReserveAmmo or 0)
		hero.Ammo += taken
		hero.ReserveAmmo -= taken
		hero.IsReloading = false
		effect({effectType = "ReloadComplete", heroGuid = hero.Guid, position = hero.Root.Position})
	end)
	return true
end

function CombatSystem.DamageRadius(ownerHero, position, radius, damage, objectiveMultiplier)
	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	for _, target in pairs(HeroSystem.HeroesByGuid) do
		if target.Alive and target.Root and (target.Root.Position - position).Magnitude <= radius then
			local same = target.TeamId == ownerHero.TeamId
			if not same or target == ownerHero then CombatSystem.ApplyDamage(ownerHero, target, damage, "explosive", false, {allowFriendlyFire = target == ownerHero}) end
		end
	end
	for model, objective in pairs(CombatSystem.Objectives) do
		if objective.TeamId ~= ownerHero.TeamId and model.PrimaryPart and (model.PrimaryPart.Position - position).Magnitude <= radius then CombatSystem.DamageObjective(model, damage * (objectiveMultiplier or 1), ownerHero.TeamId) end
	end
end

function CombatSystem.CreatePickup(pickupType, position)
	local folder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Pickups")
	local part = Instance.new("Part")
	part.Name = pickupType .. "Pickup"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = pickupType == "Health" and Color3.fromRGB(70, 220, 110) or pickupType == "Ammo" and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(80, 160, 255)
	part.Parent = folder
	CombatSystem.ActivePickups[part] = pickupType
	part.Touched:Connect(function(hit)
		if not part.Parent then return end
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		local hero = HeroSystem.GetHeroFromPart(hit)
		if not hero or not hero.Alive then return end
		if pickupType == "Health" then hero.Health = math.min(hero.MaxHealth, hero.Health + 50); hero.Humanoid.Health = hero.Health
		elseif pickupType == "Ammo" then hero.ReserveAmmo = (hero.ReserveAmmo or 0) + 60
		else hero.UltimateCharge = math.min(hero.UltimateChargeMax or 100, (hero.UltimateCharge or 0) + 25) end
		CombatSystem.ActivePickups[part] = nil
		part:Destroy()
	end)
	return part
end

return CombatSystem
