local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local AbilitySystem = require(script.Parent:WaitForChild("AbilitySystem"))

-- The legacy ultimate path consumed charge and then executed AbilityId again.
-- Route the ultimate through the existing executor while temporarily selecting UltimateId.
local originalUseAbility = AbilitySystem.UseAbility
AbilitySystem.UseUltimate = function(hero)
	if not hero or not hero.Alive or not hero.UltimateId then return false end
	local maximum = hero.UltimateChargeMax or 100
	if (hero.UltimateCharge or 0) < maximum then return false end
	local originalAbilityId = hero.AbilityId
	local originalReadyAt = hero.AbilityReadyAt
	hero.AbilityId = hero.UltimateId
	hero.AbilityReadyAt = 0
	local ok, err = pcall(originalUseAbility, hero, {direction = hero.Root and hero.Root.CFrame.LookVector or Vector3.new(0, 0, -1)})
	hero.AbilityId = originalAbilityId
	hero.AbilityReadyAt = originalReadyAt
	if not ok then
		warn("[PDA] Ultimate execution failed: " .. tostring(err))
		return false
	end
	hero.UltimateCharge = 0
	return true
end

-- Process the time-dilation collection that the legacy updater never reads.
task.spawn(function()
	while task.wait(0.2) do
		local now = os.clock()
		for index = #AbilitySystem.ActiveSlowFields, 1, -1 do
			local field = AbilitySystem.ActiveSlowFields[index]
			if not field or now >= field.ExpireAt then
				table.remove(AbilitySystem.ActiveSlowFields, index)
			else
				for _, hero in pairs(AbilitySystem.HeroSystem and AbilitySystem.HeroSystem.HeroesByGuid or {}) do
					if hero.Alive and hero.Root and hero.Humanoid then
						local definition = HeroConfig[hero.HeroId]
						local baseSpeed = definition and definition.walkSpeed or 16
						local inside = (hero.Root.Position - field.Position).Magnitude <= field.Radius
						if inside and hero == field.OwnerHero then
							hero.Humanoid.WalkSpeed = baseSpeed * (field.SelfSpeed or 1)
						elseif inside and hero.TeamId ~= field.OwnerHero.TeamId then
							hero.Humanoid.WalkSpeed = baseSpeed * (field.EnemySlow or 0.65)
						elseif not hero.ActiveEffects or not hero.ActiveEffects.overcharge then
							hero.Humanoid.WalkSpeed = baseSpeed
						end
					end
				end
			end
		end
	end
end)

-- Apply gravity wells with physical velocity rather than Humanoid:Move(worldPosition).
task.spawn(function()
	while task.wait(0.1) do
		local now = os.clock()
		for index = #AbilitySystem.GravityWells, 1, -1 do
			local well = AbilitySystem.GravityWells[index]
			if not well or now >= well.ExpireAt then
				table.remove(AbilitySystem.GravityWells, index)
			else
				for _, hero in pairs(AbilitySystem.HeroSystem and AbilitySystem.HeroSystem.HeroesByGuid or {}) do
					if hero.Alive and hero.Root and hero.TeamId ~= well.OwnerHero.TeamId then
						local offset = well.Position - hero.Root.Position
						local distance = offset.Magnitude
						if distance > 0.1 and distance <= well.Radius then
							local acceleration = offset.Unit * math.min(well.PullStrength or 40, 80)
							hero.Root.AssemblyLinearVelocity += acceleration * 0.1
							if AbilitySystem.CombatSystem then
								AbilitySystem.CombatSystem.ApplyDamage(well.OwnerHero, hero, (well.DamagePerSecond or 10) * 0.1, "gravity_well")
							end
						end
					end
				end
			end
		end
	end
end)

print("[PDA] Ability runtime patches active")
