--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

local MatchSystem = {}

MatchSystem.State = "Lobby"
MatchSystem.MatchId = "0"
MatchSystem.Timer = 0
MatchSystem.Score = { Red = 0, Blue = 0 }
MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
MatchSystem.Players = {}
MatchSystem.BotOwnerId = "__BOT_BLUE__"
MatchSystem.BotActive = false
MatchSystem.TeamAssignments = {}
MatchSystem.Decks = {}
MatchSystem.ControlledHero = {}
MatchSystem.JoinRequestedAt = {}
MatchSystem.SoloStartTask = nil
MatchSystem.SpawnedThisMatch = false
MatchSystem.NeedsWorldReset = false
MatchSystem.EndedCallbacks = {}
MatchSystem.Winner = nil
MatchSystem.GameMode = "Standard"
MatchSystem.KOTHZone = nil
MatchSystem.KOTHHolder = nil
MatchSystem.KOTHTimer = 0
MatchSystem.CTFRedFlag = nil
MatchSystem.CTFBlueFlag = nil
MatchSystem.CTFRedHeld = false
MatchSystem.CTFBlueHeld = false
MatchSystem.FFAKills = {}
MatchSystem.Killstreaks = {}

function MatchSystem.Init()
	MatchSystem.State = "Lobby"
	MatchSystem.Score = { Red = 0, Blue = 0 }
	MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
	MatchSystem.TeamAssignments = {}
	MatchSystem.Decks = {}
	MatchSystem.ControlledHero = {}
	MatchSystem.BotActive = false
	MatchSystem.Winner = nil
	MatchSystem.GameMode = "Standard"
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}
end

function MatchSystem.GetState()
	return MatchSystem.State
end

function MatchSystem.SetState(state)
	MatchSystem.State = state
end

function MatchSystem.GetTeam(userId)
	return MatchSystem.TeamAssignments[userId]
end

function MatchSystem.EnsureBotOpponent()
	if not MatchSystem.BotActive then
		MatchSystem.BotActive = true
		MatchSystem.TeamAssignments[MatchSystem.BotOwnerId] = Config.TEAM_BLUE
	end
end

function MatchSystem.RequestJoin(player)
	MatchSystem.AssignTeam(player)
	MatchSystem.JoinRequestedAt[player.UserId] = os.clock()
	MatchSystem.Killstreaks[player.UserId] = 0
	MatchSystem.FFAKills[player.UserId] = 0

	if MatchSystem.State == "Lobby" then
		if Config.FFA_ENABLED and #Players:GetPlayers() >= 3 then
			MatchSystem.GameMode = "FFA"
		elseif Config.KOTH_ENABLED then
			MatchSystem.GameMode = "KOTH"
		end

		MatchSystem.State = "DeckSelect"
		MatchSystem.Timer = 15
		MatchSystem.StartSoloCountdown()

		task.spawn(function()
			for i = 15, 1, -1 do
				task.wait(1)
				MatchSystem.Timer = i - 1
			end
			MatchSystem.BeginMatch()
		end)
	end
end

function MatchSystem.StartSoloCountdown()
	if MatchSystem.SoloStartTask then return end
	MatchSystem.SoloStartTask = task.delay(Config.SOLO_BOT_START_DELAY, function()
		if #Players:GetPlayers() == 1 then
			MatchSystem.EnsureBotOpponent()
		end
	end)
end

function MatchSystem.BeginMatch()
	if MatchSystem.State ~= "DeckSelect" then return end
	MatchSystem.State = "MatchCountdown"
	MatchSystem.MatchId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
	MatchSystem.Score = { Red = 0, Blue = 0 }
	MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
	MatchSystem.Timer = Config.MATCH_DURATION
	MatchSystem.SpawnedThisMatch = false
	MatchSystem.Winner = nil
	MatchSystem.KOTHTimer = 0
	MatchSystem.CTFRedHeld = false
	MatchSystem.CTFBlueHeld = false
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		MatchSystem.FFAKills[plr.UserId] = 0
		MatchSystem.Killstreaks[plr.UserId] = 0
	end

	task.spawn(function()
		task.wait(Config.COUNTDOWN_DURATION)
		MatchSystem.State = "ActiveMatch"

		if #Players:GetPlayers() < 2 then
			MatchSystem.EnsureBotOpponent()
		end

		task.spawn(function()
			while MatchSystem.State == "ActiveMatch" do
				task.wait(1)
				MatchSystem.Timer -= 1

				if MatchSystem.GameMode == "KOTH" then
					MatchSystem.UpdateKOTH()
				end

				if MatchSystem.Timer <= 0 then
					MatchSystem.EndByTime()
					break
				end
			end
		end)
	end)

	MapBuilder.SetupGameMode(MatchSystem.GameMode)
end

function MatchSystem.AssignTeam(player)
	if MatchSystem.GameMode == "FFA" then
		MatchSystem.TeamAssignments[player.UserId] = Config.TEAM_NONE
		return Config.TEAM_NONE
	end

	if not MatchSystem.TeamAssignments[player.UserId] then
		local redCount = 0
		local blueCount = 0
		for _, tid in pairs(MatchSystem.TeamAssignments) do
			if tid == Config.TEAM_RED then redCount += 1 end
			if tid == Config.TEAM_BLUE then blueCount += 1 end
		end
		if redCount <= blueCount then
			MatchSystem.TeamAssignments[player.UserId] = Config.TEAM_RED
		else
			MatchSystem.TeamAssignments[player.UserId] = Config.TEAM_BLUE
		end
	end
	return MatchSystem.TeamAssignments[player.UserId]
end

function MatchSystem.GetTeam(userId)
	return MatchSystem.TeamAssignments[userId]
end

function MatchSystem.RecordCoreDamage(teamId, amount)
	MatchSystem.CoreDamage[teamId] = (MatchSystem.CoreDamage[teamId] or 0) + amount
end

function MatchSystem.AddScore(teamId, amount)
	MatchSystem.Score[teamId] = (MatchSystem.Score[teamId] or 0) + amount
end

function MatchSystem.AddFFAKill(userId)
	MatchSystem.FFAKills[userId] = (MatchSystem.FFAKills[userId] or 0) + 1
	local kills = MatchSystem.FFAKills[userId]

	if kills >= Config.FFA_SCORE_LIMIT then
		local leaderUserId = nil
		local maxKills = 0
		for uid, k in pairs(MatchSystem.FFAKills) do
			if k > maxKills then
				maxKills = k
				leaderUserId = uid
			end
		end
		if leaderUserId then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.UserId == leaderUserId then
					MatchSystem.EndMatch(Config.TEAM_NONE)
					return
				end
			end
		end
	end
end

function MatchSystem.AddKillstreak(userId)
	local streak = (MatchSystem.Killstreaks[userId] or 0) + 1
	MatchSystem.Killstreaks[userId] = streak

	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	local hero = HeroSystem.GetControlledHeroByUserId(userId)
	if not hero then return end

	local player = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then player = p break end
	end

	if streak == 5 and player then
		local remotes = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
		if remotes then
			local ann = remotes:FindFirstChild("AnnouncementEvent")
			if ann then ann:FireAllClients({text = player.Name .. " is on a 5 kill streak!", duration = 4}) end
		end
	elseif streak == 10 and player then
		local remotes = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
		if remotes then
			local ann = remotes:FindFirstChild("AnnouncementEvent")
			if ann then ann:FireAllClients({text = "UNSTOPPABLE! " .. player.Name .. " has 10 kills!", duration = 5}) end
		end
	end

	if streak >= 5 then
		MatchSystem.AddScore(MatchSystem.GetTeam(userId) or Config.TEAM_RED, Config.SCORE_KILLSTREAK_BONUS)
	end
end

function MatchSystem.ResetKillstreak(userId, killerId)
	local killedStreak = MatchSystem.Killstreaks[userId] or 0
	local killerStreak = MatchSystem.Killstreaks[killerId] or 0

	if killedStreak >= 5 then
		local remotes = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
		if remotes then
			local ann = remotes:FindFirstChild("AnnouncementEvent")
			if ann then
				local killerName = ""
				for _, p in ipairs(Players:GetPlayers()) do
					if p.UserId == killerId then killerName = p.Name break end
				end
				local killedName = ""
				for _, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then killedName = p.Name break end
				end
				if killerName ~= "" then
					ann:FireAllClients({text = killerName .. " ended " .. killedName .. "'s " .. killedStreak .. " kill streak!", duration = 4})
				end
			end
		end
	end

	MatchSystem.Killstreaks[userId] = 0
	if killerId and killerId ~= userId then
		MatchSystem.AddKillstreak(killerId)
	end
end

function MatchSystem.EndByTime()
	if MatchSystem.GameMode == "FFA" then
		local leader = nil
		local maxKills = 0
		for uid, k in pairs(MatchSystem.FFAKills) do
			if k > maxKills then
				maxKills = k
				leader = uid
			end
		end
		if leader then
			MatchSystem.EndMatch(Config.TEAM_NONE, leader)
		else
			MatchSystem.EndMatch(Config.TEAM_RED)
		end
		return
	end

	if MatchSystem.Score.Red > MatchSystem.Score.Blue then
		MatchSystem.EndMatch(Config.TEAM_RED)
	elseif MatchSystem.Score.Blue > MatchSystem.Score.Red then
		MatchSystem.EndMatch(Config.TEAM_BLUE)
	else
		if MatchSystem.CoreDamage.Red > MatchSystem.CoreDamage.Blue then
			MatchSystem.EndMatch(Config.TEAM_RED)
		elseif MatchSystem.CoreDamage.Blue > MatchSystem.CoreDamage.Red then
			MatchSystem.EndMatch(Config.TEAM_BLUE)
		else
			if MatchSystem.GameMode == "KOTH" then
				local totalRed = MatchSystem.KOTHTimer
				if MatchSystem.KOTHHolder == Config.TEAM_RED then
					totalRed += MatchSystem.Timer
				end
				if totalRed > Config.KOTH_HOLD_TIME then
					MatchSystem.EndMatch(Config.TEAM_RED)
				else
					MatchSystem.EndMatch(Config.TEAM_BLUE)
				end
			else
				MatchSystem.State = "SuddenDeath"
			end
		end
	end
end

function MatchSystem.EndMatch(winnerTeam, ffaLeaderId)
	if MatchSystem.State == "PostMatch" then return end
	MatchSystem.State = "PostMatch"
	MatchSystem.Winner = winnerTeam

	for _, callback in ipairs(MatchSystem.EndedCallbacks) do
		task.spawn(callback, winnerTeam, MatchSystem.Score, ffaLeaderId)
	end
	task.delay(12, function()
		MatchSystem.Reset()
	end)
end

function MatchSystem.OnEnded(callback)
	table.insert(MatchSystem.EndedCallbacks, callback)
end

function MatchSystem.Reset()
	MatchSystem.State = "Resetting"
	MatchSystem.TeamAssignments = {}
	MatchSystem.Decks = {}
	MatchSystem.ControlledHero = {}
	MatchSystem.Score = { Red = 0, Blue = 0 }
	MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
	MatchSystem.BotActive = false
	MatchSystem.SoloStartTask = nil
	MatchSystem.SpawnedThisMatch = false
	MatchSystem.NeedsWorldReset = true
	MatchSystem.Winner = nil
	MatchSystem.GameMode = "Standard"
	MatchSystem.KOTHHolder = nil
	MatchSystem.KOTHTimer = 0
	MatchSystem.CTFRedHeld = false
	MatchSystem.CTFBlueHeld = false
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}
	MatchSystem.State = "Lobby"
end

function MatchSystem.OnCoreDestroyed(winnerTeam)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	MatchSystem.EndMatch(winnerTeam)
end

function MatchSystem.UpdateKOTH()
	-- Check which team holds the hill
	local zonePos = Config.MAP.KOTH_ZONE
	local redCount = 0
	local blueCount = 0

	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive and not hero.IsControlled then
			local dist = (hero.Root.Position - zonePos).Magnitude
			if dist <= 15 then
				if hero.TeamId == Config.TEAM_RED then redCount += 1
				elseif hero.TeamId == Config.TEAM_BLUE then blueCount += 1
				end
			end
		end
	end

	if redCount > blueCount then
		MatchSystem.KOTHHolder = Config.TEAM_RED
	elseif blueCount > redCount then
		MatchSystem.KOTHHolder = Config.TEAM_BLUE
	end

	if MatchSystem.KOTHHolder then
		MatchSystem.KOTHTimer += 1 / 60
		local scoreThreshold = 2
		if MatchSystem.KOTHTimer >= scoreThreshold then
			MatchSystem.AddScore(MatchSystem.KOTHHolder, 1)
			MatchSystem.KOTHTimer = 0
		end
	end
end

return MatchSystem