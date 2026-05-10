--!strict

local DataStoreService = game:GetService("DataStoreService")

local sharedRoot = script.Parent.Parent:WaitForChild("Shared")
local ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local ProgressionSystem = {}

ProgressionSystem.Profiles = {}
ProgressionSystem.DataStoreAvailable = true
ProgressionSystem.WarnedFallback = false

local store = DataStoreService:GetDataStore("PulseDeckArenaProfiles_v2")

local function defaultProfile()
	return {
		Wins = 0,
		Losses = 0,
		Coins = 0,
		XP = 0,
		Level = 1,
		TotalKills = 0,
		TotalDeaths = 0,
		TotalDamage = 0,
		FavoriteHero = nil,
		UnlockedHeroes = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"},
		OwnedSkins = {},
		EquippedSkin = "default",
		LastPlayed = 0,
		Achievements = {},
		PrestigeLevel = 0,
	}
end

local function warnFallbackOnce()
	if ProgressionSystem.WarnedFallback then return end
	ProgressionSystem.WarnedFallback = true
	warn("PulseDeckArena: DataStore unavailable, using in-memory progression fallback.")
end

function ProgressionSystem.Init()
	ProgressionSystem.Profiles = {}
end

function ProgressionSystem.Load(player)
	if not ProgressionSystem.DataStoreAvailable then
		local profile = defaultProfile()
		ProgressionSystem.Profiles[player.UserId] = profile
		return profile
	end

	local ok, data = pcall(function()
		return store:GetAsync("user_" .. tostring(player.UserId))
	end)

	if not ok then
		ProgressionSystem.DataStoreAvailable = false
		warnFallbackOnce()
		local profile = defaultProfile()
		ProgressionSystem.Profiles[player.UserId] = profile
		return profile
	end

	if type(data) ~= "table" then
		data = defaultProfile()
	end

	-- Migrate / validate
	if not data.UnlockedHeroes then
		data.UnlockedHeroes = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"}
	end

	ProgressionSystem.Profiles[player.UserId] = data
	return data
end

function ProgressionSystem.Save(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile or not ProgressionSystem.DataStoreAvailable then return end

	profile.LastPlayed = os.time()

	local ok = pcall(function()
		store:SetAsync("user_" .. tostring(player.UserId), profile)
	end)

	if not ok then
		ProgressionSystem.DataStoreAvailable = false
		warnFallbackOnce()
	end
end

function ProgressionSystem.CreateLeaderstats(player)
	local profile = ProgressionSystem.Load(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = profile.Wins
	wins.Parent = leaderstats

	local losses = Instance.new("IntValue")
	losses.Name = "Losses"
	losses.Value = profile.Losses or 0
	losses.Parent = leaderstats

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = profile.TotalKills or 0
	kills.Parent = leaderstats

	local kd = Instance.new("StringValue")
	kd.Name = "K/D"
	local deaths = profile.TotalDeaths or 0
	local kc = profile.TotalKills or 0
	kd.Value = string.format("%.2f", kc / math.max(1, deaths))
	kd.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = leaderstats

	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Value = profile.XP
	xp.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = ProgressionUtils.GetLevel(profile.XP)
	level.Parent = leaderstats
end

function ProgressionSystem.SyncLeaderstats(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then return end

	local wins = leaderstats:FindFirstChild("Wins")
	local losses = leaderstats:FindFirstChild("Losses")
	local kills = leaderstats:FindFirstChild("Kills")
	local kd = leaderstats:FindFirstChild("K/D")
	local coins = leaderstats:FindFirstChild("Coins")
	local xp = leaderstats:FindFirstChild("XP")
	local level = leaderstats:FindFirstChild("Level")

	if wins then wins.Value = profile.Wins end
	if losses then losses.Value = profile.Losses or 0 end
	if kills then kills.Value = profile.TotalKills or 0 end
	if kd then
		local d = profile.TotalDeaths or 0
		local k = profile.TotalKills or 0
		kd.Value = string.format("%.2f", k / math.max(1, d))
	end
	if coins then coins.Value = profile.Coins end
	if xp then xp.Value = profile.XP end
	if level then level.Value = ProgressionUtils.GetLevel(profile.XP) end
end

function ProgressionSystem.GetLevel(xp)
	return ProgressionUtils.GetLevel(xp)
end

function ProgressionSystem.GetXpNeededForLevel(level)
	return ProgressionUtils.GetXpNeededForLevel(level)
end

function ProgressionSystem.AwardMatch(player, result, teamScore)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then
		profile = ProgressionSystem.Load(player)
	end

	local coins = 40
	local xp = 90

	if result == "Win" then
		coins = 75
		xp = 140
		profile.Wins = (profile.Wins or 0) + 1
	elseif result == "Loss" then
		coins = 25
		xp = 50
		profile.Losses = (profile.Losses or 0) + 1
	elseif result == "Draw" then
		coins = 20
		xp = 30
	end

	-- Bonus based on team contribution
	coins += math.floor((teamScore or 0) / 25)
	xp += math.floor((teamScore or 0) / 50)

	profile.Coins += coins
	profile.XP += xp

	-- Update stats
	local hero = HeroSystem.GetControlledHero(player)
	if hero then
		profile.TotalKills = (profile.TotalKills or 0) + (hero.KillCount or 0)
		profile.TotalDeaths = (profile.TotalDeaths or 0) + (hero.DeathCount or 0)
		profile.TotalDamage = (profile.TotalDamage or 0) + math.floor(hero.DamageDealt or 0)
	end

	ProgressionSystem.SyncLeaderstats(player)
end

function ProgressionSystem.GetProfile(player)
	return ProgressionSystem.Profiles[player.UserId]
end

function ProgressionSystem.UnlockHero(player, heroId)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return false end

	if table.find(profile.UnlockedHeroes, heroId) then return true end

	-- Cost to unlock varies by hero rarity
	local heroDef = HeroConfig[heroId]
	local cost = 500
	if heroDef then
		-- Based on role difficulty or rarity
		cost = 300 + (#HeroConfig[heroId] and 50 or 0)
	end

	if profile.Coins >= cost then
		profile.Coins -= cost
		table.insert(profile.UnlockedHeroes, heroId)
		ProgressionSystem.SyncLeaderstats(player)
		return true
	end
	return false
end

return ProgressionSystem