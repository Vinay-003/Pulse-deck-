local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local AISystem = require(script.Parent:WaitForChild("AISystem"))
local AbilitySystem = require(script.Parent:WaitForChild("AbilitySystem"))
local ProgressionSystem = require(script.Parent:WaitForChild("ProgressionSystem"))

local ALLOWED_MODES = {Standard = true, KOTH = true, FFA = true}
local ACTION_LIMITS = {
	RequestJoinQueue = 1,
	RequestDeckUpdate = 0.4,
	RequestSwitchHero = 0.2,
	RequestStartMatch = 1,
	RequestFire = 0.02,
	RequestReload = 0.25,
	RequestAbility = 0.2,
	RequestUltimate = 0.5,
	RequestPower = 0.5,
	RequestReady = 0.5,
	RequestGameMode = 0.5,
	RequestPurchase = 0.5,
	RequestPracticeDummy = 2,
	RequestScoreboard = 0.5,
}
local lastAction = {}
local initializedPlayers = {}

local function ensureWorld()
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then
		world = Instance.new("Folder")
		world.Name = "PulseDeckArenaWorld"
		world.Parent = workspace
	end
	for _, name in ipairs({"Map", "Heroes", "Objectives", "Pickups", "Projectiles", "Effects", "Waypoints", "Debris"}) do
		if not world:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = world
		end
	end
	return world
end

local function ensureTeam(name, brickColor)
	local team = Teams:FindFirstChild(name)
	if not team then
		team = Instance.new("Team")
		team.Name = name
		team.TeamColor = BrickColor.new(brickColor)
		team.AutoAssignable = false
		team.Parent = Teams
	end
	return team
end

local function ensureRemote(folder, name, className)
	local remote = folder:FindFirstChild(name)
	if remote and remote.ClassName ~= className then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function normalizeDirection(value)
	if not isFiniteVector(value) or value.Magnitude < 0.001 then return nil end
	return value.Unit
end

local function allow(player, action)
	local now = os.clock()
	local key = tostring(player.UserId) .. ":" .. action
	local interval = ACTION_LIMITS[action] or 0.1
	if lastAction[key] and now - lastAction[key] < interval then return false end
	lastAction[key] = now
	return true
end

local function validDeck(heroIds)
	if type(heroIds) ~= "table" or #heroIds ~= Config.DECK_SIZE then return nil end
	local result = {}
	local seen = {}
	for _, heroId in ipairs(heroIds) do
		if type(heroId) ~= "string" or not HeroConfig[heroId] or seen[heroId] then return nil end
		seen[heroId] = true
		table.insert(result, heroId)
	end
	return result
end

local function isAdmin(player)
	return RunService:IsStudio() or table.find(Config.ADMIN_USER_IDS or {}, player.UserId) ~= nil
end

local world = ensureWorld()
ensureTeam("Red", "Bright red")
ensureTeam("Blue", "Bright blue")
MapBuilder.BuildNeonFoundry()
CombatSystem.Init()
AbilitySystem.Init(HeroSystem, MatchSystem, CombatSystem)
if not AISystem.Initialized then
	AISystem.Init(HeroSystem, MatchSystem, CombatSystem, AbilitySystem)
	AISystem.Initialized = true
end

local objectivesFolder = world:WaitForChild("Objectives")
local function registerObjectives()
	for _, model in ipairs(objectivesFolder:GetChildren()) do
		if model.Name == "RedCore" then CombatSystem.RegisterObjective(model, Config.TEAM_RED, Config.CORE_MAX_HEALTH, "Core")
		elseif model.Name == "BlueCore" then CombatSystem.RegisterObjective(model, Config.TEAM_BLUE, Config.CORE_MAX_HEALTH, "Core")
		elseif string.find(model.Name, "RedGenerator") then CombatSystem.RegisterObjective(model, Config.TEAM_RED, Config.GENERATOR_MAX_HEALTH, "Generator")
		elseif string.find(model.Name, "BlueGenerator") then CombatSystem.RegisterObjective(model, Config.TEAM_BLUE, Config.GENERATOR_MAX_HEALTH, "Generator") end
	end
end
registerObjectives()

local root = ReplicatedStorage:WaitForChild("PulseDeckArena")
local remotes = root:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = root

local names = {
	ClientReady = "RemoteEvent", RequestJoinQueue = "RemoteEvent", RequestDeckUpdate = "RemoteEvent",
	RequestSwitchHero = "RemoteEvent", RequestStartMatch = "RemoteEvent", RequestFire = "RemoteEvent",
	RequestReload = "RemoteEvent", RequestAbility = "RemoteEvent", RequestUltimate = "RemoteEvent",
	RequestCameraMode = "RemoteEvent", RequestScoreboard = "RemoteEvent", RequestPower = "RemoteEvent",
	RequestReady = "RemoteEvent", RequestGameMode = "RemoteEvent", RequestPurchase = "RemoteEvent",
	RequestPracticeDummy = "RemoteEvent", RequestBuy = "RemoteEvent", RequestBuyMenu = "RemoteEvent",
	RequestPlant = "RemoteEvent", RequestDefuse = "RemoteEvent", CancelDefuse = "RemoteEvent",
	MatchStateChanged = "RemoteEvent", HeroControlChanged = "RemoteEvent", HeroStateSnapshot = "RemoteEvent",
	ObjectiveStateChanged = "RemoteEvent", ScoreChanged = "RemoteEvent", KillfeedEvent = "RemoteEvent",
	DamageNumberEvent = "RemoteEvent", EffectsEvent = "RemoteEvent", AnnouncementEvent = "RemoteEvent",
	ArmorPickup = "RemoteEvent", PlaySFX = "RemoteEvent", BombDefuseProgress = "RemoteEvent",
	GetInitialState = "RemoteFunction",
}
local R = {}
for name, className in pairs(names) do R[name] = ensureRemote(remotes, name, className) end

local function announce(text, duration, player)
	local payload = {text = text, duration = duration or 3}
	if player then R.AnnouncementEvent:FireClient(player, payload) else R.AnnouncementEvent:FireAllClients(payload) end
end

local function sendState(player)
	local hero = HeroSystem.GetControlledHero(player)
	R.MatchStateChanged:FireClient(player, {
		state = MatchSystem.State,
		timerRemaining = MatchSystem.Timer,
		redScore = MatchSystem.Score.Red,
		blueScore = MatchSystem.Score.Blue,
		winner = MatchSystem.Winner,
		teamId = MatchSystem.GetTeam(player.UserId),
		gameMode = MatchSystem.GameMode,
		roundNumber = MatchSystem.RoundNumber,
		roundPhase = MatchSystem.RoundPhase,
		bombState = MatchSystem.BombState,
		bombTimer = MatchSystem.BombTimer,
		roundScore = MatchSystem.RoundScore,
		hasBomb = hero and hero.HasBomb == true or false,
	})
end

R.GetInitialState.OnServerInvoke = function(player)
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
		roundNumber = MatchSystem.RoundNumber,
		roundScore = MatchSystem.RoundScore,
		roundPhase = MatchSystem.RoundPhase,
		bombState = MatchSystem.BombState,
		bombTimer = MatchSystem.BombTimer,
		hasBomb = false,
	}
end

R.ClientReady.OnServerEvent:Connect(function(player)
	if not allow(player, "ClientReady") then return end
	sendState(player)
end)

R.RequestJoinQueue.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestJoinQueue") then return end
	if MatchSystem.State ~= "Lobby" then return end
	MatchSystem.RequestJoin(player)
end)

R.RequestDeckUpdate.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestDeckUpdate") or MatchSystem.State ~= "DeckSelect" then return end
	local deck = validDeck(type(payload) == "table" and payload.heroIds or nil)
	if not deck then announce("Choose five unique heroes.", 2, player) return end
	MatchSystem.Decks[player.UserId] = deck
end)

R.RequestReady.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestReady") or MatchSystem.State ~= "DeckSelect" then return end
	MatchSystem.ReadyState = MatchSystem.ReadyState or {}
	MatchSystem.ReadyState[player.UserId] = not MatchSystem.ReadyState[player.UserId]
	announce(player.DisplayName .. (MatchSystem.ReadyState[player.UserId] and " is ready" or " is not ready"), 2)
end)

R.RequestStartMatch.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestStartMatch") or MatchSystem.State ~= "DeckSelect" then return end
	if not MatchSystem.Decks[player.UserId] then announce("Confirm your deck first.", 2, player) return end
	local humans = Players:GetPlayers()
	local permitted = isAdmin(player) or #humans == 1
	if not permitted then
		permitted = true
		for _, human in ipairs(humans) do
			if not (MatchSystem.ReadyState and MatchSystem.ReadyState[human.UserId]) then permitted = false break end
		end
	end
	if not permitted then announce("All players must ready up.", 2, player) return end
	MatchSystem.BeginMatch()
end)

R.RequestGameMode.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestGameMode") or (MatchSystem.State ~= "Lobby" and MatchSystem.State ~= "DeckSelect") then return end
	local mode = type(payload) == "table" and payload.mode or nil
	if not ALLOWED_MODES[mode] then announce("That mode is not enabled in this build.", 2, player) return end
	if not isAdmin(player) and #Players:GetPlayers() > 1 then return end
	MatchSystem.GameMode = mode
	announce("Mode: " .. mode, 2)
end)

R.RequestSwitchHero.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestSwitchHero") then return end
	local slot = type(payload) == "table" and payload.slot or nil
	if not isFiniteNumber(slot) or slot % 1 ~= 0 or slot < 1 or slot > Config.DECK_SIZE then return end
	HeroSystem.SwitchHero(player, slot)
end)

R.RequestFire.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestFire") or (MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath") then return end
	if type(payload) ~= "table" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero or not hero.Alive or hero.Stunned or not hero.Root then return end
	local direction = normalizeDirection(payload.direction)
	if not direction then return end
	if isFiniteVector(payload.origin) and (payload.origin - hero.Root.Position).Magnitude > 12 then return end
	local weapon = WeaponConfig[hero.WeaponId]
	if not weapon then return end
	local multiplier = 1
	if hero.ActiveEffects and hero.ActiveEffects.overcharge then multiplier = hero.ActiveEffects.overcharge.FireRateMultiplier or 1 end
	local minimum = math.max(0.025, (weapon.fireInterval or 0.1) / math.max(0.1, multiplier))
	local now = os.clock()
	if hero.ServerLastFireAt and now - hero.ServerLastFireAt < minimum * 0.95 then return end
	hero.ServerLastFireAt = now
	CombatSystem.FireWeapon(hero, direction)
end)

R.RequestReload.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestReload") then return end
	local hero = HeroSystem.GetControlledHero(player)
	if hero and hero.Alive then CombatSystem.RequestReload(hero) end
end)

R.RequestAbility.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestAbility") or (MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath") then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero or not hero.Alive or hero.Stunned then return end
	local direction = type(payload) == "table" and normalizeDirection(payload.direction) or nil
	AbilitySystem.UseAbility(hero, {direction = direction or hero.Root.CFrame.LookVector})
end)

R.RequestUltimate.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestUltimate") or (MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath") then return end
	local hero = HeroSystem.GetControlledHero(player)
	if hero and hero.Alive and not hero.Stunned then AbilitySystem.UseUltimate(hero) end
end)

R.RequestPower.OnServerEvent:Connect(function(player, payload)
	if not allow(player, "RequestPower") then return end
	local hero = HeroSystem.GetControlledHero(player)
	local powerId = type(payload) == "table" and payload.powerId or nil
	local definition = hero and HeroConfig[hero.HeroId]
	if not hero or not hero.Alive or type(powerId) ~= "string" or not definition or not definition.powers or not definition.powers[powerId] then return end
	local key = "power_" .. powerId
	hero.ActiveEffects = hero.ActiveEffects or {}
	if hero.ActiveEffects[key] and os.clock() < hero.ActiveEffects[key].ExpireAt then return end
	local power = definition.powers[powerId]
	hero.ActiveEffects[key] = {ExpireAt = os.clock() + (power.duration or 5), LastTick = os.clock(), PowerDef = power}
	R.EffectsEvent:FireAllClients({effectType = "PowerActivated", heroGuid = hero.Guid, powerId = powerId, duration = power.duration or 5})
end)

R.RequestPracticeDummy.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestPracticeDummy") or MatchSystem.State == "ActiveMatch" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero or not hero.Root then return end
	local existing = world.Effects:FindFirstChild("PracticeDummy_" .. player.UserId)
	if existing then existing:Destroy() end
	local dummy = Instance.new("Part")
	dummy.Name = "PracticeDummy_" .. player.UserId
	dummy.Size = Vector3.new(2, 5, 2)
	dummy.CFrame = hero.Root.CFrame * CFrame.new(0, 0, -12)
	dummy.Anchored = true
	dummy.Material = Enum.Material.SmoothPlastic
	dummy.Color = Color3.fromRGB(220, 72, 88)
	dummy.Parent = world.Effects
	task.delay(30, function() if dummy.Parent then dummy:Destroy() end end)
end)

R.RequestScoreboard.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestScoreboard") then return end
	local rows = {}
	for _, human in ipairs(Players:GetPlayers()) do
		local hero = HeroSystem.GetControlledHero(human)
		table.insert(rows, {name = human.DisplayName, teamId = MatchSystem.GetTeam(human.UserId) or "None", score = MatchSystem.Score[MatchSystem.GetTeam(human.UserId)] or 0, kills = hero and hero.KillCount or 0, deaths = hero and hero.DeathCount or 0, damage = hero and hero.DamageDealt or 0})
	end
	R.RequestScoreboard:FireClient(player, {players = rows})
end)

R.PlaySFX.OnServerEvent:Connect(function() end)
R.RequestPlant.OnServerEvent:Connect(function(player) announce("Bomb mode is disabled pending secure site validation.", 2, player) end)
R.RequestDefuse.OnServerEvent:Connect(function() end)
R.CancelDefuse.OnServerEvent:Connect(function() end)
R.RequestBuy.OnServerEvent:Connect(function() end)
R.RequestBuyMenu.OnServerEvent:Connect(function() end)

local function initializePlayer(player)
	if initializedPlayers[player] then return end
	initializedPlayers[player] = true
	MatchSystem.AssignTeam(player)
	ProgressionSystem.CreateLeaderstats(player)
	ProgressionSystem.Load(player)
	MatchSystem.Killstreaks[player.UserId] = 0
	MatchSystem.FFAKills[player.UserId] = 0
	MatchSystem.ReadyState = MatchSystem.ReadyState or {}
	MatchSystem.ReadyState[player.UserId] = false
end

Players.PlayerAdded:Connect(initializePlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(initializePlayer, player) end
Players.PlayerRemoving:Connect(function(player)
	ProgressionSystem.Save(player)
	HeroSystem.RemoveOwner(player.UserId)
	initializedPlayers[player] = nil
	for key in pairs(lastAction) do if string.find(key, "^" .. player.UserId .. ":") then lastAction[key] = nil end end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do ProgressionSystem.Save(player) end
	task.wait(1)
end)

MatchSystem.OnEnded(function(winnerTeam)
	for _, player in ipairs(Players:GetPlayers()) do
		local team = MatchSystem.GetTeam(player.UserId)
		local result = team == winnerTeam and "Win" or (winnerTeam == Config.TEAM_NONE and "Draw" or "Loss")
		ProgressionSystem.AwardMatch(player, result, (MatchSystem.Score.Red or 0) + (MatchSystem.Score.Blue or 0))
		ProgressionSystem.Save(player)
	end
end)

task.spawn(function()
	while task.wait(0.2) do
		for _, player in ipairs(Players:GetPlayers()) do sendState(player) end
		R.ScoreChanged:FireAllClients({Red = MatchSystem.Score.Red, Blue = MatchSystem.Score.Blue, coreDamage = MatchSystem.CoreDamage})
		R.HeroStateSnapshot:FireAllClients({matchId = MatchSystem.MatchId, heroes = HeroSystem.GetSnapshot()})
		R.ObjectiveStateChanged:FireAllClients({objectives = CombatSystem.GetObjectiveSnapshot()})
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		if MatchSystem.State == "ActiveMatch" and not MatchSystem.SpawnedThisMatch then
			MatchSystem.SpawnedThisMatch = true
			for _, player in ipairs(Players:GetPlayers()) do
				HeroSystem.SpawnHeroesForOwner(player.UserId, MatchSystem.GetTeam(player.UserId) or Config.TEAM_RED, MatchSystem.Decks[player.UserId] or Config.DEFAULT_DECK, player)
			end
			if MatchSystem.BotActive then HeroSystem.SpawnHeroesForOwner(MatchSystem.BotOwnerId, Config.TEAM_BLUE, Config.BOT_DECK, nil) end
			for _, hero in pairs(HeroSystem.HeroesByGuid) do if not hero.IsControlled then AISystem.EnableHeroAI(hero, true) end end
			announce("FIGHT!", 2)
		elseif MatchSystem.State == "Resetting" or (MatchSystem.State == "Lobby" and MatchSystem.NeedsWorldReset) then
			HeroSystem.ClearAll()
			AISystem.Clear()
			AbilitySystem.Clear()
			CombatSystem.Init()
			MapBuilder.BuildNeonFoundry()
			registerObjectives()
			MatchSystem.SpawnedThisMatch = false
			MatchSystem.NeedsWorldReset = false
		end
	end
end)

print(Config.GAME_NAME .. " authoritative runtime ready")
