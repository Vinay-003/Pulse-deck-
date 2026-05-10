--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local AISystem = require(script.Parent:WaitForChild("AISystem"))
local AbilitySystem = require(script.Parent:WaitForChild("AbilitySystem"))
local ProgressionSystem = require(script.Parent:WaitForChild("ProgressionSystem"))

local function ensureWorld()
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then
		world = Instance.new("Folder")
		world.Name = "PulseDeckArenaWorld"
		world.Parent = workspace
	end
	for _, name in ipairs({"Map", "Heroes", "Objectives", "Pickups", "Projectiles", "Effects", "Waypoints", "Debris"}) do
		if not world:FindFirstChild(name) then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = world
		end
	end
end

ensureWorld()

-- Create remote folder
local remotesFolder = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	if not root then
		root = Instance.new("Folder")
		root.Name = "PulseDeckArena"
		root.Parent = ReplicatedStorage
	end
	remotesFolder.Parent = root
end

local function ensureRemote(name, className)
	local r = remotesFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end

local requestJoin = ensureRemote("RequestJoinQueue", "RemoteEvent")
local requestDeck = ensureRemote("RequestDeckUpdate", "RemoteEvent")
local requestSwitch = ensureRemote("RequestSwitchHero", "RemoteEvent")
local requestStart = ensureRemote("RequestStartMatch", "RemoteEvent")
local requestFire = ensureRemote("RequestFire", "RemoteEvent")
local requestReload = ensureRemote("RequestReload", "RemoteEvent")
local requestAbility = ensureRemote("RequestAbility", "RemoteEvent")
local requestUltimate = ensureRemote("RequestUltimate", "RemoteEvent")
local requestCamera = ensureRemote("RequestCameraMode", "RemoteEvent")
local requestScoreboard = ensureRemote("RequestScoreboard", "RemoteEvent")
local clientReady = ensureRemote("ClientReady", "RemoteEvent")
local matchStateChanged = ensureRemote("MatchStateChanged", "RemoteEvent")
local heroControlChanged = ensureRemote("HeroControlChanged", "RemoteEvent")
local heroStateSnapshot = ensureRemote("HeroStateSnapshot", "RemoteEvent")
local objectiveStateChanged = ensureRemote("ObjectiveStateChanged", "RemoteEvent")
local scoreChanged = ensureRemote("ScoreChanged", "RemoteEvent")
local killfeedEvent = ensureRemote("KillfeedEvent", "RemoteEvent")
local damageNumberEvent = ensureRemote("DamageNumberEvent", "RemoteEvent")
local effectsEvent = ensureRemote("EffectsEvent", "RemoteEvent")
local announcementEvent = ensureRemote("AnnouncementEvent", "RemoteEvent")
local getInitialState = ensureRemote("GetInitialState", "RemoteFunction")

-- Request handlers
requestJoin.OnServerEvent:Connect(function(player)
	MatchSystem.RequestJoin(player)
end)

requestDeck.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "DeckSelect" then return end
	if type(payload) ~= "table" or type(payload.heroIds) ~= "table" then return end
	-- Validate hero IDs
	local validIds = {}
	for _, id in ipairs(payload.heroIds) do
		if HeroConfig[id] then
			table.insert(validIds, id)
		end
	end
	if #validIds == 5 then
		MatchSystem.Decks[player.UserId] = validIds
	end
end)

requestSwitch.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" or type(payload.slot) ~= "number" then return end
	HeroSystem.SwitchHero(player, payload.slot)
end)

requestStart.OnServerEvent:Connect(function(_player)
	if MatchSystem.State == "DeckSelect" then
		MatchSystem.BeginMatch()
	end
end)

requestFire.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	if type(payload) ~= "table" then return end
	if typeof(payload.direction) ~= "Vector3" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	if hero.Stunned then return end
	if typeof(payload.origin) == "Vector3" and (payload.origin - hero.Root.Position).Magnitude > 35 then return end

	-- Rapid fire check
	local weapon = WeaponConfig[hero.WeaponId]
	if weapon then
		local minInterval = weapon.fireInterval or 0.1
		if os.clock() - hero.LastFireAt < minInterval * 0.8 then return end
		hero.LastFireAt = os.clock()
	end

	CombatSystem.FireWeapon(hero, payload.direction)
end)

requestReload.OnServerEvent:Connect(function(player)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	CombatSystem.RequestReload(hero)
end)

requestAbility.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	if MatchSystem.State == "SuddenDeath" then
		local hero = HeroSystem.GetControlledHero(player)
		if hero and hero.UltimateId then
			AbilitySystem.UseUltimate(hero)
			return
		end
	end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	AbilitySystem.UseAbility(hero, payload or {})
end)

requestUltimate.OnServerEvent:Connect(function(player)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	if not hero.UltimateId then return end
	AbilitySystem.UseUltimate(hero)
end)

requestCamera.OnServerEvent:Connect(function(_player, _payload)
	-- Camera is client-owned.
end)

requestScoreboard.OnServerEvent:Connect(function(player)
	local rows = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local teamId = MatchSystem.GetTeam(plr.UserId) or "None"
		local hero = HeroSystem.GetControlledHero(plr)
		local kills = 0
		local deaths = 0
		local damage = 0
		if hero then
			kills = hero.KillCount or 0
			deaths = hero.DeathCount or 0
			damage = hero.DamageDealt or 0
		end
		table.insert(rows, {
			name = plr.Name,
			teamId = teamId,
			score = MatchSystem.Score[teamId] or 0,
			kills = kills,
			deaths = deaths,
			damage = damage,
			kd = kills / math.max(1, deaths),
		})
	end
	requestScoreboard:FireClient(player, { players = rows })
end)

clientReady.OnServerEvent:Connect(function(player)
	local prof = ProgressionSystem.Profiles[player.UserId]
	local progression = prof or {Wins = 0, Coins = 0, XP = 0}

	matchStateChanged:FireClient(player, {
		state = MatchSystem.State,
		timerRemaining = MatchSystem.Timer,
		redScore = MatchSystem.Score.Red,
		blueScore = MatchSystem.Score.Blue,
		teamId = MatchSystem.GetTeam(player.UserId),
		gameMode = MatchSystem.GameMode,
	})

	requestScoreboard:FireClient(player, {
		players = {},
		matchMode = MatchSystem.GameMode,
	})
end)

getInitialState.OnServerInvoke = function(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	return {
		gameName = Config.GAME_NAME,
		matchState = MatchSystem.State,
		timerRemaining = MatchSystem.Timer,
		teamId = MatchSystem.GetTeam(player.UserId),
		selectedDeck = MatchSystem.Decks[player.UserId] or Config.DEFAULT_DECK,
		score = MatchSystem.Score,
		progression = profile or {Wins = 0, Coins = 0, XP = 0},
		gameMode = MatchSystem.GameMode,
	}
end

Players.PlayerAdded:Connect(function(player)
	MatchSystem.AssignTeam(player)
	ProgressionSystem.CreateLeaderstats(player)
	ProgressionSystem.Load(player)

	MatchSystem.Killstreaks[player.UserId] = 0
	MatchSystem.FFAKills[player.UserId] = 0

	player.Chatted:Connect(function(message)
		local isAdmin = RunService:IsStudio() or table.find(Config.ADMIN_USER_IDS, player.UserId) ~= nil
		if not isAdmin then return end

		local args = string.split(message:lower(), " ")
		if args[1] == "/pda_reset" then
			MatchSystem.Reset()
		elseif args[1] == "/pda_start" then
			if MatchSystem.State == "Lobby" then
				MatchSystem.RequestJoin(player)
			end
			if MatchSystem.State == "DeckSelect" then
				MatchSystem.BeginMatch()
			end
		elseif args[1] == "/pda_bots" then
			MatchSystem.EnsureBotOpponent()
		elseif args[1] == "/pda_winred" then
			MatchSystem.EndMatch(Config.TEAM_RED)
		elseif args[1] == "/pda_winblue" then
			MatchSystem.EndMatch(Config.TEAM_BLUE)
		elseif args[1] == "/pda_mode" then
			if args[2] == "ffa" then
				MatchSystem.GameMode = "FFA"
			elseif args[2] == "koth" then
				MatchSystem.GameMode = "KOTH"
			elseif args[2] == "ctf" then
				MatchSystem.GameMode = "CTF"
			elseif args[2] == "standard" then
				MatchSystem.GameMode = "Standard"
			end
			announcementEvent:FireAllClients({text = "Game mode changed to " .. tostring(MatchSystem.GameMode), duration = 5})
		elseif args[1] == "/pda_givexp" then
			local prof = ProgressionSystem.Profiles[player.UserId]
			if prof then
				prof.XP = (prof.XP or 0) + 1000
				ProgressionSystem.SyncLeaderstats(player)
			end
		elseif args[1] == "/pda_givecoins" then
			local prof = ProgressionSystem.Profiles[player.UserId]
			if prof then
				prof.Coins = (prof.Coins or 0) + 1000
				ProgressionSystem.SyncLeaderstats(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ProgressionSystem.Save(player)
	HeroSystem.RemoveOwner(player.UserId)
	MatchSystem.Killstreaks[player.UserId] = nil
	MatchSystem.FFAKills[player.UserId] = nil
end)

MatchSystem.OnEnded(function(winnerTeam)
	for _, player in ipairs(Players:GetPlayers()) do
		local teamId = MatchSystem.GetTeam(player.UserId)
		local result = "Draw"
		if teamId == winnerTeam then
			result = "Win"
		elseif teamId ~= nil and winnerTeam ~= Config.TEAM_NONE then
			result = "Loss"
		end

		-- Award extra XP based on performance
		local hero = HeroSystem.GetControlledHero(player)
		local extraXP = 0
		if hero then
			extraXP = (hero.KillCount or 0) * 15 + math.floor((hero.DamageDealt or 0) / 10)
		end

		local profile = ProgressionSystem.Profiles[player.UserId]
		if profile then
			profile.XP = (profile.XP or 0) + extraXP
			ProgressionSystem.SyncLeaderstats(player)
		end

		ProgressionSystem.AwardMatch(player, result, MatchSystem.Score or 0)
		ProgressionSystem.Save(player)
	end

	-- Announce winner
	local winText = "DRAW"
	if winnerTeam == Config.TEAM_RED then
		winText = "RED TEAM WINS!"
	elseif winnerTeam == Config.TEAM_BLUE then
		winText = "BLUE TEAM WINS!"
	end
	announcementEvent:FireAllClients({text = winText, duration = 7})
end)

-- Update XP and ultimate charge every frame
task.spawn(function()
	while true do
		task.wait(0.25)

		if MatchSystem.State == "ActiveMatch" or MatchSystem.State == "SuddenDeath" then
			for _, hero in pairs(HeroSystem.HeroesByGuid) do
				if hero.ActiveEffects and hero.ActiveEffects.overcharge then
					local oc = hero.ActiveEffects.overcharge
					if os.clock() >= oc.ExpireAt then
						hero.ActiveEffects.overcharge = nil
						local heroDef = HeroConfig[hero.HeroId]
						if heroDef then
							hero.Humanoid.WalkSpeed = heroDef.walkSpeed
						end
					end
				end

				if hero.ActiveEffects and hero.ActiveEffects.fortify then
					if os.clock() >= hero.ActiveEffects.fortify.ExpireAt then
						hero.ActiveEffects.fortify = nil
					end
				end

				if hero.ActiveEffects and hero.ActiveEffects.healOverTime then
					local hot = hero.ActiveEffects.healOverTime
					if os.clock() >= hot.ExpireAt then
						hero.ActiveEffects.healOverTime = nil
					elseif os.clock() - hot.LastTick >= 1 then
						hot.LastTick = os.clock()
						AbilitySystem.Heal(hero, hot.HealPerTick)
					end
				end

				if hero.ActiveEffects and hero.ActiveEffects.markedByVesper then
					if os.clock() >= hero.MarkedUntil then
						hero.ActiveEffects.markedByVesper = nil
					end
				end

				if hero.ActiveEffects and hero.ActiveEffects.ultimate then
					local ult = hero.ActiveEffects.ultimate
					if os.clock() >= ult.ExpireAt then
						hero.ActiveEffects.ultimate = nil
					elseif os.clock() - ult.LastShotAt >= (1 / ult.ShotsPerSecond) then
						ult.LastShotAt = os.clock()
						local dir = hero.Root.CFrame.LookVector
						local spreadDir = Util.RandomVectorInCone(dir, ult.SpreadDegrees or 5)
						local aimPoint = hero.Root.Position + spreadDir * (ult.Range or 500)
						CombatSystem.FireWeapon(hero, aimPoint - hero.Root.Position)
					end
				end
			end
		end
	end
end)

-- Update match state broadcasting and spawning
task.spawn(function()
	while true do
		task.wait(0.2)
		matchStateChanged:FireAllClients({
			state = MatchSystem.State,
			timerRemaining = MatchSystem.Timer,
			redScore = MatchSystem.Score.Red,
			blueScore = MatchSystem.Score.Blue,
			winner = MatchSystem.Winner,
			gameMode = MatchSystem.GameMode,
			kothHolder = MatchSystem.KOTHHolder,
		})
		scoreChanged:FireAllClients({
			Red = MatchSystem.Score.Red,
			Blue = MatchSystem.Score.Blue,
			coreDamage = MatchSystem.CoreDamage,
		})
		heroStateSnapshot:FireAllClients({
			matchId = MatchSystem.MatchId,
			heroes = HeroSystem.GetSnapshot(),
		})
		objectiveStateChanged:FireAllClients({
			objectives = CombatSystem.GetObjectiveSnapshot(),
		})
	end
end)

-- Spawn heroes and start AI
task.spawn(function()
	while true do
		task.wait(1)
		if MatchSystem.State == "MatchCountdown" then
			-- do nothing during countdown
		elseif MatchSystem.State == "ActiveMatch" then
			if not MatchSystem.SpawnedThisMatch then
				MatchSystem.SpawnedThisMatch = true
				for _, plr in ipairs(Players:GetPlayers()) do
					local deck = MatchSystem.Decks[plr.UserId] or Config.DEFAULT_DECK
					local teamId = MatchSystem.GetTeam(plr.UserId) or Config.TEAM_RED
					HeroSystem.SpawnHeroesForOwner(plr.UserId, teamId, deck, plr)
				end
				if MatchSystem.BotActive then
					local botDeck = Config.BOT_DECK
					HeroSystem.SpawnHeroesForOwner(MatchSystem.BotOwnerId, Config.TEAM_BLUE, botDeck, nil)
				end

				-- Enable AI for non-controlled heroes
				for _, hero in pairs(HeroSystem.HeroesByGuid) do
					if not hero.IsControlled then
						AISystem.EnableHeroAI(hero, true)
					end
				end

				-- Spawn pickups
				for _, pos in ipairs(Config.MAP.POWERUP_SPAWNS) do
					local types = {"Health", "Ammo", "Energy"}
					local ptype = types[math.random(1, #types)]
					CombatSystem.CreatePickup(ptype, pos)
				end

				announcementEvent:FireAllClients({text = "⚔️ FIGHT! ⚔️", duration = 3})
			end
		elseif MatchSystem.State == "PostMatch" then
			-- waiting for reset
		elseif MatchSystem.State == "Resetting" then
			HeroSystem.ClearAll()
			MatchSystem.SpawnedThisMatch = false
			AISystem.Clear()
			AbilitySystem.Clear()
			MapBuilder.BuildNeonFoundry()
			CombatSystem.Init()
			local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
			for _, child in ipairs(objectivesFolder:GetChildren()) do
				if child.Name == "RedCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.CORE_MAX_HEALTH, "Core")
				elseif child.Name == "BlueCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.CORE_MAX_HEALTH, "Core")
				elseif string.find(child.Name, "RedGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.GENERATOR_MAX_HEALTH, "Generator")
				elseif string.find(child.Name, "BlueGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.GENERATOR_MAX_HEALTH, "Generator")
				end
			end
			MatchSystem.NeedsWorldReset = false
		elseif MatchSystem.State == "Lobby" and MatchSystem.NeedsWorldReset then
			HeroSystem.ClearAll()
			AISystem.Clear()
			AbilitySystem.Clear()
			CombatSystem.Init()
			MapBuilder.BuildNeonFoundry()
			local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
			for _, child in ipairs(objectivesFolder:GetChildren()) do
				if child.Name == "RedCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.CORE_MAX_HEALTH, "Core")
				elseif child.Name == "BlueCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.CORE_MAX_HEALTH, "Core")
				elseif string.find(child.Name, "RedGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.GENERATOR_MAX_HEALTH, "Generator")
				elseif string.find(child.Name, "BlueGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.GENERATOR_MAX_HEALTH, "Generator")
				end
			end
			MatchSystem.NeedsWorldReset = false
		end
	end
end)

print(Config.GAME_NAME .. " Stage 7 boot complete - All systems online")