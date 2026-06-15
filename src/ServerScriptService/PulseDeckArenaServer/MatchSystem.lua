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
-- Bomb defuse mode fields
MatchSystem.RoundNumber = 0
MatchSystem.RoundPhase = "Buy" -- Buy, Active, PostRound
MatchSystem.BombState = "None" -- None, Planted
MatchSystem.BombSite = nil
MatchSystem.BombTimer = 0
MatchSystem.BombPlantedBy = nil
MatchSystem.IsDefusing = {}
MatchSystem.DefuseProgress = {}
MatchSystem.RoundScore = { Red = 0, Blue = 0 }
MatchSystem.BombTicking = false

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
	MatchSystem.RoundNumber = 0
	MatchSystem.RoundPhase = "Buy"
	MatchSystem.BombState = "None"
	MatchSystem.BombTimer = 0
	MatchSystem.RoundScore = { Red = 0, Blue = 0 }
	MatchSystem.BombTicking = false
	MatchSystem.IsDefusing = {}
	MatchSystem.DefuseProgress = {}
end

function MatchSystem.GetState()
	return MatchSystem.State
end

function MatchSystem.SetState(state)
	MatchSystem.State = state
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
	MatchSystem.IsDefusing[player.UserId] = false
	MatchSystem.DefuseProgress[player.UserId] = 0

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

local function getRemotes()
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	return root and root:FindFirstChild("Remotes")
end

local function fireEffectsEvent(payload)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("EffectsEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients(payload)
	end
end

local function fireAnnouncement(text, duration)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("AnnouncementEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients({text = text, duration = duration or 4})
	end
end

function MatchSystem.BeginMatch()
	if MatchSystem.State ~= "DeckSelect" then return end
	MatchSystem.State = "MatchCountdown"
	MatchSystem.MatchId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
	MatchSystem.Score = { Red = 0, Blue = 0 }
	MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
	MatchSystem.RoundScore = { Red = 0, Blue = 0 }
	MatchSystem.Winner = nil
	MatchSystem.KOTHTimer = 0
	MatchSystem.CTFRedHeld = false
	MatchSystem.CTFBlueHeld = false
	MatchSystem.FFAKills = {}
	MatchSystem.Killstreaks = {}
	MatchSystem.RoundNumber = 0
	MatchSystem.BombState = "None"
	MatchSystem.BombTicking = false

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

		if MatchSystem.GameMode == "Bomb" then
			task.spawn(function() MatchSystem.StartBombRound() end)
		else
			task.spawn(function()
				while MatchSystem.State == "ActiveMatch" do
					task.wait(1)
					MatchSystem.Timer -= 1
					if MatchSystem.GameMode == "KOTH" then MatchSystem.UpdateKOTH() end
					MatchSystem.UpdateCTF()
					if MatchSystem.GameMode ~= "FFA" then MatchSystem.TrySpawnBotWave() end
					if MatchSystem.Timer <= 0 then MatchSystem.EndByTime() break end
				end
			end)
		end
	end)

	-- Setup game mode objects on map (lazy require to avoid circular dependency)
	local ok, MapBuilder = pcall(function()
		return require(script.Parent:WaitForChild("MapBuilder"))
	end)
	if ok and MapBuilder and MapBuilder.SetupGameMode then
		MapBuilder.SetupGameMode(MatchSystem.GameMode)
	end
end

-- === BOMB DEFUSE MODE ===

function MatchSystem.StartBombRound()
	MatchSystem.RoundNumber += 1
	if MatchSystem.RoundNumber > Config.BOMB_MAX_ROUNDS then
		MatchSystem.EndMatch(MatchSystem.RoundScore.Red > MatchSystem.RoundScore.Blue and Config.TEAM_RED or Config.TEAM_BLUE)
		return
	end

	MatchSystem.RoundPhase = "Buy"
	MatchSystem.BombState = "None"
	MatchSystem.BombTimer = 0
	MatchSystem.BombTicking = false
	MatchSystem.BombSite = nil
	MatchSystem.IsDefusing = {}
	MatchSystem.DefuseProgress = {}

	local isSecondHalf = MatchSystem.RoundNumber >= Config.BOMB_SWAP_ROUND

	local ctTeam = Config.TEAM_RED
	local tTeam = Config.TEAM_BLUE
	if isSecondHalf then
		ctTeam, tTeam = tTeam, ctTeam
	end

	fireAnnouncement(string.format("Round %d/%d — BUY PHASE (20s)", MatchSystem.RoundNumber, Config.BOMB_MAX_ROUNDS), 3)
	MatchSystem.Timer = Config.BOMB_BUY_TIME

	-- Respawn all heroes at their spawns
	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.OwnerId ~= MatchSystem.BotOwnerId then
			HeroSystem.RespawnHero(hero)
			if not hero.Alive then
				hero.Health = hero.MaxHealth
				hero.Humanoid.Health = hero.MaxHealth
				hero.Alive = true
			end
		end
	end
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.OwnerId == MatchSystem.BotOwnerId then
			HeroSystem.RespawnHero(hero)
		end
	end

	-- Give bomb to a T bot
	local tBombCarrier = nil
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive and hero.TeamId == tTeam then
			tBombCarrier = hero
			break
		end
	end
	if tBombCarrier then
		tBombCarrier.HasBomb = true
		MatchSystem.BombCarrier = tBombCarrier.Guid
	end

	-- Buy phase countdown
	task.wait(Config.BOMB_BUY_TIME)

	if MatchSystem.State ~= "ActiveMatch" then return end

	MatchSystem.RoundPhase = "Active"
	MatchSystem.Timer = Config.BOMB_ROUND_TIME
	fireAnnouncement("FIGHT!", 2)

	-- Bomb mode 1-second tick loop
	while MatchSystem.State == "ActiveMatch" and MatchSystem.RoundPhase == "Active" do
		task.wait(1)
		MatchSystem.Timer -= 1

		if MatchSystem.BombTicking then
			MatchSystem.BombTimer -= 1
			if MatchSystem.BombTimer <= 0 then
				MatchSystem.BombExplode(Config.TEAM_BLUE)
				return
			end
			-- Beep sound every 5 seconds, rapid at < 10
			if MatchSystem.BombTimer % 5 == 0 or MatchSystem.BombTimer <= 10 then
				fireEffectsEvent({effectType = "BombBeep", position = MatchSystem.BombSite, timer = MatchSystem.BombTimer})
			end
		end

		-- Check win conditions
		local aliveCT = 0
		local aliveT = 0
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, hero in pairs(HeroSystem.HeroesByGuid) do
			if hero.Alive then
				if hero.TeamId == ctTeam then aliveCT += 1 end
				if hero.TeamId == tTeam then aliveT += 1 end
			end
		end

		if aliveCT == 0 and not MatchSystem.BombTicking then
			MatchSystem.EndBombRound(tTeam, "All CT eliminated")
			return
		end
		if aliveT == 0 then
			MatchSystem.EndBombRound(ctTeam, "All T eliminated")
			return
		end

		if MatchSystem.Timer <= 0 then
			if MatchSystem.BombTicking then
				MatchSystem.BombExplode(tTeam)
				return
			else
				MatchSystem.EndBombRound(ctTeam, "Time ran out")
				return
			end
		end
	end
end

function MatchSystem.PlantBomb(hero, sitePos)
	if MatchSystem.GameMode ~= "Bomb" then return false end
	if MatchSystem.RoundPhase ~= "Active" then return false end
	if MatchSystem.BombState == "Planted" then return false end
	if not hero.HasBomb then return false end
	if not hero.Alive then return false end

	MatchSystem.BombState = "Planted"
	MatchSystem.BombSite = sitePos
	MatchSystem.BombTimer = Config.BOMB_EXPLODE_TIME
	MatchSystem.BombTicking = true
	MatchSystem.BombPlantedBy = hero.Guid
	hero.HasBomb = false

	fireAnnouncement("BOMB PLANTED! Defuse or explode in " .. Config.BOMB_EXPLODE_TIME .. "s", 3)
	fireEffectsEvent({effectType = "BombPlant", position = sitePos, duration = Config.BOMB_EXPLODE_TIME})
	return true
end

function MatchSystem.StartDefuse(defuser)
	if MatchSystem.GameMode ~= "Bomb" then return false end
	if MatchSystem.RoundPhase ~= "Active" then return false end
	if MatchSystem.BombState ~= "Planted" then return false end
	if MatchSystem.IsDefusing[defuser.OwnerId] then return false end

	MatchSystem.IsDefusing[defuser.OwnerId] = true
	MatchSystem.DefuseProgress[defuser.OwnerId] = 0

	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("BombDefuseProgress")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients({defuserGuid = defuser.Guid, progress = 0})
	end

	task.spawn(function()
		while MatchSystem.IsDefusing[defuser.OwnerId] and MatchSystem.BombState == "Planted" do
			task.wait(0.1)
			MatchSystem.DefuseProgress[defuser.OwnerId] = (MatchSystem.DefuseProgress[defuser.OwnerId] or 0) + 0.1

			local progressEvent = remotes and remotes:FindFirstChild("BombDefuseProgress")
			if progressEvent and progressEvent:IsA("RemoteEvent") then
				progressEvent:FireAllClients({defuserGuid = defuser.Guid, progress = MatchSystem.DefuseProgress[defuser.OwnerId] / Config.BOMB_DEFUSE_TIME})
			end

			if MatchSystem.DefuseProgress[defuser.OwnerId] >= Config.BOMB_DEFUSE_TIME then
				MatchSystem.EndBombRound(Config.TEAM_RED, "Bomb defused!")
				return
			end

			if not defuser.Alive or not defuser then
				MatchSystem.IsDefusing[defuser.OwnerId] = false
				local cancelEvent = remotes and remotes:FindFirstChild("BombDefuseProgress")
				if cancelEvent and cancelEvent:IsA("RemoteEvent") then
					cancelEvent:FireAllClients({defuserGuid = defuser.Guid, progress = -1})
				end
				return
			end
		end
	end)

	return true
end

function MatchSystem.CancelDefuse(defuser)
	MatchSystem.IsDefusing[defuser.OwnerId] = false
	MatchSystem.DefuseProgress[defuser.OwnerId] = 0
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("BombDefuseProgress")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients({defuserGuid = defuser.Guid, progress = -1})
	end
end

function MatchSystem.BombExplode(tTeam)
	if MatchSystem.GameMode ~= "Bomb" then return end
	if MatchSystem.BombState ~= "Planted" then return end
	MatchSystem.BombState = "Exploded"
	MatchSystem.BombTicking = false

	fireEffectsEvent({effectType = "BombExplosion", position = MatchSystem.BombSite})
	fireAnnouncement("💥 BOMB EXPLODED!", 4)

	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive then
			local dist = (hero.Root.Position - MatchSystem.BombSite).Magnitude
			if dist < 50 then
				local dmg = math.floor(200 * (1 - dist / 50))
				if dmg > 0 then
					CombatSystem.ApplyDamage({Guid = "bomb", TeamId = -1}, hero, dmg, "bomb")
				end
			end
		end
	end

	MatchSystem.EndBombRound(tTeam, "Bomb exploded")
end

function MatchSystem.EndBombRound(winnerTeam, reasonText)
	if MatchSystem.RoundPhase == "PostRound" then return end
	MatchSystem.RoundPhase = "PostRound"

	local loserTeam = winnerTeam == Config.TEAM_RED and Config.TEAM_BLUE or Config.TEAM_RED
	MatchSystem.RoundScore[winnerTeam] = (MatchSystem.RoundScore[winnerTeam] or 0) + 1
	MatchSystem.Score[winnerTeam] = (MatchSystem.Score[winnerTeam] or 0) + 1

	local winnerName = winnerTeam == Config.TEAM_RED and "RED (CT)" or "BLUE (T)"
	fireAnnouncement(string.format("%s win — %s (%d-%d)", winnerName, reasonText or "", MatchSystem.RoundScore.Red, MatchSystem.RoundScore.Blue), 5)

	task.wait(5)

	if MatchSystem.RoundNumber >= Config.BOMB_MAX_ROUNDS then
		MatchSystem.EndMatch(MatchSystem.RoundScore.Red > MatchSystem.RoundScore.Blue and Config.TEAM_RED or Config.TEAM_BLUE)
	else
		task.spawn(function() MatchSystem.StartBombRound() end)
	end
end

-- === END BOMB MODE ===

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
		local remotes = getRemotes()
		local ann = remotes and remotes:FindFirstChild("AnnouncementEvent")
		if ann then ann:FireAllClients({text = player.Name .. " is on a 5 kill streak!", duration = 4}) end
	elseif streak == 10 and player then
		local remotes = getRemotes()
		local ann = remotes and remotes:FindFirstChild("AnnouncementEvent")
		if ann then ann:FireAllClients({text = "UNSTOPPABLE! " .. player.Name .. " has 10 kills!", duration = 5}) end
	end

	if streak >= 5 then
		MatchSystem.AddScore(MatchSystem.GetTeam(userId) or Config.TEAM_RED, Config.SCORE_KILLSTREAK_BONUS)
	end
end

function MatchSystem.ResetKillstreak(userId, killerId)
	local killedStreak = MatchSystem.Killstreaks[userId] or 0

	if killedStreak >= 5 then
		local remotes = getRemotes()
		local ann = remotes and remotes:FindFirstChild("AnnouncementEvent")
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
	MatchSystem.BombTicking = false

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
	MatchSystem.RoundScore = { Red = 0, Blue = 0 }
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
	MatchSystem.RoundNumber = 0
	MatchSystem.BombState = "None"
	MatchSystem.BombTicking = false
	MatchSystem.IsDefusing = {}
	MatchSystem.DefuseProgress = {}
	MatchSystem.State = "Lobby"
end

function MatchSystem.UpdateCTF()
	if MatchSystem.CTFRedFlag and MatchSystem.CTFRedFlag.PrimaryPart then
		local redFlagPos = MatchSystem.CTFRedFlag.PrimaryPart.Position
		local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
		if not objectivesFolder then return end
		local blueCore = objectivesFolder:FindFirstChild("BlueCore")
		if blueCore and blueCore.PrimaryPart and (redFlagPos - blueCore.PrimaryPart.Position).Magnitude <= 16 then
			if not MatchSystem.CTFRedHeld then
				MatchSystem.CTFRedHeld = true
				MatchSystem.AddScore(Config.TEAM_RED, Config.SCORE_FLAG_CAPTURE)
				local ann = getRemotes() and getRemotes():FindFirstChild("AnnouncementEvent")
				if ann then ann:FireAllClients({text = "RED captured the flag!", duration = 5}) end
				task.delay(10, function()
					if MatchSystem.CTFRedFlag and MatchSystem.CTFRedFlag.PrimaryPart then
						MatchSystem.CTFRedFlag:PivotTo(CFrame.new(Config.MAP.CtfFlagRed))
						MatchSystem.CTFRedHeld = false
					end
				end)
			end
		end
	end

	if MatchSystem.CTFBlueFlag and MatchSystem.CTFBlueFlag.PrimaryPart then
		local blueFlagPos = MatchSystem.CTFBlueFlag.PrimaryPart.Position
		local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
		if not objectivesFolder then return end
		local redCore = objectivesFolder:FindFirstChild("RedCore")
		if redCore and redCore.PrimaryPart and (blueFlagPos - redCore.PrimaryPart.Position).Magnitude <= 16 then
			if not MatchSystem.CTFBlueHeld then
				MatchSystem.CTFBlueHeld = true
				MatchSystem.AddScore(Config.TEAM_BLUE, Config.SCORE_FLAG_CAPTURE)
				local ann = getRemotes() and getRemotes():FindFirstChild("AnnouncementEvent")
				if ann then ann:FireAllClients({text = "BLUE captured the flag!", duration = 5}) end
				task.delay(10, function()
					if MatchSystem.CTFBlueFlag and MatchSystem.CTFBlueFlag.PrimaryPart then
						MatchSystem.CTFBlueFlag:PivotTo(CFrame.new(Config.MAP.CtfFlagBlue))
						MatchSystem.CTFBlueHeld = false
					end
				end)
			end
		end
	end
end

function MatchSystem.TrySpawnBotWave()
	if not MatchSystem.BotActive then return end
	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	local botCount = 0
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.OwnerId == MatchSystem.BotOwnerId and hero.Alive then
			botCount += 1
		end
	end
	if botCount == 0 and MatchSystem.State == "ActiveMatch" then
		local botDeck = Config.BOT_DECK
		if #botDeck > 0 then
			HeroSystem.SpawnHeroesForOwner(MatchSystem.BotOwnerId, Config.TEAM_BLUE, botDeck, nil)
			for _, hero in pairs(HeroSystem.HeroesByGuid) do
				if hero.OwnerId == MatchSystem.BotOwnerId and not hero.IsControlled then
					local AISystem = require(script.Parent:WaitForChild("AISystem"))
					AISystem.EnableHeroAI(hero, true)
				end
			end
		end
	end
end

function MatchSystem.OnCoreDestroyed(winnerTeam)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	MatchSystem.EndMatch(winnerTeam)
end

function MatchSystem.UpdateKOTH()
	local zonePos = Config.MAP.KOTH_ZONE
	local redCount = 0
	local blueCount = 0
	local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive then
			local dist = (hero.Root.Position - zonePos).Magnitude
			if dist <= 15 then
				if hero.TeamId == Config.TEAM_RED then redCount += 1
				elseif hero.TeamId == Config.TEAM_BLUE then blueCount += 1 end
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
		if MatchSystem.KOTHTimer >= 2 then
			MatchSystem.AddScore(MatchSystem.KOTHHolder, 1)
			MatchSystem.KOTHTimer = 0
		end
	end
end

return MatchSystem
