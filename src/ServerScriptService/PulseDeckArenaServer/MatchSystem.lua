local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

local MatchSystem = {
	State = "Lobby",
	MatchId = "0",
	Timer = 0,
	Score = {Red = 0, Blue = 0},
	CoreDamage = {Red = 0, Blue = 0},
	Players = {},
	BotOwnerId = "__BOT_BLUE__",
	BotActive = false,
	TeamAssignments = {},
	Decks = {},
	ControlledHero = {},
	JoinRequestedAt = {},
	SpawnedThisMatch = false,
	NeedsWorldReset = false,
	EndedCallbacks = {},
	Winner = nil,
	GameMode = "Standard",
	KOTHZone = nil,
	KOTHHolder = nil,
	KOTHProgress = {Red = 0, Blue = 0},
	KOTHTimer = 0,
	FFAKills = {},
	Killstreaks = {},
	ReadyState = {},
	RoundNumber = 0,
	RoundPhase = "Disabled",
	BombState = "Disabled",
	BombSite = nil,
	BombTimer = 0,
	RoundScore = {Red = 0, Blue = 0},
	IsDefusing = {},
	DefuseProgress = {},
}

local generation = 0

local function remotes()
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	return root and root:FindFirstChild("Remotes")
end

local function announce(text, duration)
	local folder = remotes()
	local event = folder and folder:FindFirstChild("AnnouncementEvent")
	if event then event:FireAllClients({text = text, duration = duration or 3}) end
end

local function setState(state)
	MatchSystem.State = state
end

function MatchSystem.Init()
	generation += 1
	setState("Lobby")
	MatchSystem.Timer = 0
	MatchSystem.Score = {Red = 0, Blue = 0}
	MatchSystem.CoreDamage = {Red = 0, Blue = 0}
	MatchSystem.TeamAssignments = {}
	MatchSystem.Decks = {}
	MatchSystem.ControlledHero = {}
	MatchSystem.BotActive = false
	MatchSystem.Winner = nil
	MatchSystem.GameMode = "Standard"
	MatchSystem.KOTHHolder = nil
	MatchSystem.KOTHProgress = {Red = 0, Blue = 0}
	MatchSystem.KOTHTimer = 0
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}
	MatchSystem.ReadyState = {}
	MatchSystem.SpawnedThisMatch = false
	MatchSystem.NeedsWorldReset = false
end

function MatchSystem.GetState() return MatchSystem.State end
function MatchSystem.SetState(state) setState(state) end

function MatchSystem.EnsureBotOpponent()
	if MatchSystem.BotActive then return end
	MatchSystem.BotActive = true
	MatchSystem.TeamAssignments[MatchSystem.BotOwnerId] = Config.TEAM_BLUE
end

function MatchSystem.AssignTeam(player)
	if MatchSystem.GameMode == "FFA" then
		MatchSystem.TeamAssignments[player.UserId] = Config.TEAM_NONE
		return Config.TEAM_NONE
	end
	local existing = MatchSystem.TeamAssignments[player.UserId]
	if existing then return existing end
	local red, blue = 0, 0
	for ownerId, teamId in pairs(MatchSystem.TeamAssignments) do
		if ownerId ~= MatchSystem.BotOwnerId then
			if teamId == Config.TEAM_RED then red += 1 elseif teamId == Config.TEAM_BLUE then blue += 1 end
		end
	end
	local assigned = red <= blue and Config.TEAM_RED or Config.TEAM_BLUE
	MatchSystem.TeamAssignments[player.UserId] = assigned
	return assigned
end

function MatchSystem.GetTeam(userId) return MatchSystem.TeamAssignments[userId] end

function MatchSystem.RequestJoin(player)
	if MatchSystem.State ~= "Lobby" then return false end
	MatchSystem.AssignTeam(player)
	MatchSystem.JoinRequestedAt[player.UserId] = os.clock()
	MatchSystem.Killstreaks[player.UserId] = 0
	MatchSystem.FFAKills[player.UserId] = 0
	MatchSystem.ReadyState[player.UserId] = false
	setState("DeckSelect")
	return true
end

local function runTimer(myGeneration)
	local previous = os.clock()
	while generation == myGeneration and MatchSystem.State == "ActiveMatch" do
		task.wait(0.1)
		local now = os.clock()
		local dt = math.clamp(now - previous, 0, 0.5)
		previous = now
		MatchSystem.Timer = math.max(0, MatchSystem.Timer - dt)
		if MatchSystem.GameMode == "KOTH" then MatchSystem.UpdateKOTH(dt) end
		if MatchSystem.Timer <= 0 then MatchSystem.EndByTime() break end
	end
end

function MatchSystem.BeginMatch()
	if MatchSystem.State ~= "DeckSelect" then return false end
	generation += 1
	local myGeneration = generation
	setState("MatchCountdown")
	MatchSystem.MatchId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
	MatchSystem.Score = {Red = 0, Blue = 0}
	MatchSystem.CoreDamage = {Red = 0, Blue = 0}
	MatchSystem.Winner = nil
	MatchSystem.KOTHHolder = nil
	MatchSystem.KOTHProgress = {Red = 0, Blue = 0}
	MatchSystem.KOTHTimer = 0
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}
	MatchSystem.SpawnedThisMatch = false
	for _, player in ipairs(Players:GetPlayers()) do
		MatchSystem.FFAKills[player.UserId] = 0
		MatchSystem.Killstreaks[player.UserId] = 0
	end
	if #Players:GetPlayers() < 2 then MatchSystem.EnsureBotOpponent() end
	task.spawn(function()
		local countdown = tonumber(Config.COUNTDOWN_DURATION) or 3
		MatchSystem.Timer = countdown
		while generation == myGeneration and MatchSystem.State == "MatchCountdown" and MatchSystem.Timer > 0 do
			task.wait(0.1)
			MatchSystem.Timer = math.max(0, MatchSystem.Timer - 0.1)
		end
		if generation ~= myGeneration or MatchSystem.State ~= "MatchCountdown" then return end
		setState("ActiveMatch")
		MatchSystem.Timer = tonumber(Config.MATCH_DURATION) or 300
		announce("Match started", 2)
		runTimer(myGeneration)
	end)
	local ok, MapBuilder = pcall(require, script.Parent:WaitForChild("MapBuilder"))
	if ok and MapBuilder.SetupGameMode then MapBuilder.SetupGameMode(MatchSystem.GameMode) end
	return true
end

function MatchSystem.RecordCoreDamage(teamId, amount)
	if not MatchSystem.CoreDamage[teamId] then return end
	MatchSystem.CoreDamage[teamId] += math.max(0, tonumber(amount) or 0)
end

function MatchSystem.AddScore(teamId, amount)
	if not MatchSystem.Score[teamId] then return end
	MatchSystem.Score[teamId] += math.max(0, tonumber(amount) or 0)
end

function MatchSystem.AddFFAKill(userId)
	MatchSystem.FFAKills[userId] = (MatchSystem.FFAKills[userId] or 0) + 1
	if MatchSystem.FFAKills[userId] >= (Config.FFA_SCORE_LIMIT or 20) then MatchSystem.EndMatch(Config.TEAM_NONE, userId) end
end

function MatchSystem.AddKillstreak(userId)
	local streak = (MatchSystem.Killstreaks[userId] or 0) + 1
	MatchSystem.Killstreaks[userId] = streak
	if streak == 5 then
		local player = Players:GetPlayerByUserId(userId)
		if player then announce(player.DisplayName .. " is on a 5 elimination streak", 3) end
	elseif streak == 10 then
		local player = Players:GetPlayerByUserId(userId)
		if player then announce(player.DisplayName .. " is unstoppable", 4) end
	end
end

function MatchSystem.ResetKillstreak(userId, killerId)
	MatchSystem.Killstreaks[userId] = 0
	if killerId and killerId ~= userId then MatchSystem.AddKillstreak(killerId) end
end

function MatchSystem.UpdateKOTH(dt)
	local zone = MatchSystem.KOTHZone
	if not zone or not zone.Parent then return end
	local ok, HeroSystem = pcall(require, script.Parent:WaitForChild("HeroSystem"))
	if not ok then return end
	local counts = {Red = 0, Blue = 0}
	local radius = zone:GetAttribute("Radius") or 18
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive and hero.Root and (hero.Root.Position - zone.Position).Magnitude <= radius then
			if counts[hero.TeamId] ~= nil then counts[hero.TeamId] += 1 end
		end
	end
	local holder = nil
	if counts.Red > 0 and counts.Blue == 0 then holder = Config.TEAM_RED
	elseif counts.Blue > 0 and counts.Red == 0 then holder = Config.TEAM_BLUE end
	MatchSystem.KOTHHolder = holder
	if holder then
		MatchSystem.KOTHProgress[holder] = (MatchSystem.KOTHProgress[holder] or 0) + dt
		MatchSystem.KOTHTimer = MatchSystem.KOTHProgress[holder]
		if MatchSystem.KOTHProgress[holder] >= (Config.KOTH_HOLD_TIME or 90) then MatchSystem.EndMatch(holder) end
	end
end

function MatchSystem.UpdateCTF() end
function MatchSystem.TrySpawnBotWave() end

function MatchSystem.EndByTime()
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	if MatchSystem.GameMode == "FFA" then
		local leader, best = nil, -1
		for userId, kills in pairs(MatchSystem.FFAKills) do if kills > best then leader, best = userId, kills end end
		MatchSystem.EndMatch(Config.TEAM_NONE, leader)
		return
	end
	if MatchSystem.GameMode == "KOTH" then
		local red = MatchSystem.KOTHProgress.Red or 0
		local blue = MatchSystem.KOTHProgress.Blue or 0
		MatchSystem.EndMatch(red == blue and Config.TEAM_NONE or (red > blue and Config.TEAM_RED or Config.TEAM_BLUE))
		return
	end
	if MatchSystem.Score.Red ~= MatchSystem.Score.Blue then
		MatchSystem.EndMatch(MatchSystem.Score.Red > MatchSystem.Score.Blue and Config.TEAM_RED or Config.TEAM_BLUE)
	elseif MatchSystem.CoreDamage.Red ~= MatchSystem.CoreDamage.Blue then
		MatchSystem.EndMatch(MatchSystem.CoreDamage.Red > MatchSystem.CoreDamage.Blue and Config.TEAM_RED or Config.TEAM_BLUE)
	else
		setState("SuddenDeath")
		MatchSystem.Timer = 60
		task.spawn(function()
			local myGeneration = generation
			local previous = os.clock()
			while generation == myGeneration and MatchSystem.State == "SuddenDeath" do
				task.wait(0.1)
				local now = os.clock()
				MatchSystem.Timer = math.max(0, MatchSystem.Timer - (now - previous))
				previous = now
				if MatchSystem.Timer <= 0 then MatchSystem.EndMatch(Config.TEAM_NONE) break end
			end
		end)
	end
end

function MatchSystem.OnCoreDestroyed(attackingTeam)
	if MatchSystem.State == "ActiveMatch" or MatchSystem.State == "SuddenDeath" then MatchSystem.EndMatch(attackingTeam) end
end

function MatchSystem.EndMatch(winnerTeam, ffaLeaderId)
	if MatchSystem.State == "PostMatch" or MatchSystem.State == "Resetting" then return end
	generation += 1
	setState("PostMatch")
	MatchSystem.Winner = winnerTeam
	MatchSystem.Timer = 12
	for _, callback in ipairs(MatchSystem.EndedCallbacks) do task.spawn(callback, winnerTeam, MatchSystem.Score, ffaLeaderId) end
	task.delay(12, function() if MatchSystem.State == "PostMatch" then MatchSystem.Reset() end end)
end

function MatchSystem.OnEnded(callback) table.insert(MatchSystem.EndedCallbacks, callback) end

function MatchSystem.Reset()
	generation += 1
	setState("Resetting")
	MatchSystem.TeamAssignments = {}
	MatchSystem.Decks = {}
	MatchSystem.ControlledHero = {}
	MatchSystem.Score = {Red = 0, Blue = 0}
	MatchSystem.CoreDamage = {Red = 0, Blue = 0}
	MatchSystem.RoundScore = {Red = 0, Blue = 0}
	MatchSystem.BotActive = false
	MatchSystem.SpawnedThisMatch = false
	MatchSystem.NeedsWorldReset = true
	MatchSystem.Winner = nil
	MatchSystem.KOTHHolder = nil
	MatchSystem.KOTHProgress = {Red = 0, Blue = 0}
	MatchSystem.ReadyState = {}
	task.delay(0.5, function()
		if MatchSystem.State ~= "Resetting" then return end
		for _, player in ipairs(Players:GetPlayers()) do MatchSystem.AssignTeam(player) end
		setState("Lobby")
		MatchSystem.Timer = 0
	end)
end

function MatchSystem.PlantBomb() return false end
function MatchSystem.StartDefuse() return false end
function MatchSystem.CancelDefuse() return false end
function MatchSystem.BombExplode() return false end
function MatchSystem.EndBombRound() return false end
function MatchSystem.StartBombRound() return false end

return MatchSystem
