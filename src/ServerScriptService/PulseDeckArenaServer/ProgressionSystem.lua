local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local ProgressionSystem = {Profiles = {}, DataStoreAvailable = true, Loaded = {}, Saving = {}}
local STORE_NAME = "PulseDeckArenaProfiles_v3"
local SCHEMA_VERSION = 3
local store
local ok, err = pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
if not ok then ProgressionSystem.DataStoreAvailable = false; warn("[PDA] DataStore unavailable: " .. tostring(err)) end

local function defaults()
	return {
		SchemaVersion = SCHEMA_VERSION,
		Wins = 0, Losses = 0, Coins = 0, XP = 0,
		TotalKills = 0, TotalDeaths = 0, TotalDamage = 0,
		UnlockedHeroes = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"},
		OwnedSkins = {}, EquippedSkin = "default", PurchasedItems = {},
		Achievements = {}, HeroStats = {}, FavoriteHero = nil,
		LastPlayed = 0, CreatedAt = os.time(), UpdatedAt = os.time(),
	}
end

local function mergeProfile(data)
	local profile = defaults()
	if type(data) == "table" then
		for key, value in pairs(data) do profile[key] = value end
	end
	profile.SchemaVersion = SCHEMA_VERSION
	profile.UnlockedHeroes = type(profile.UnlockedHeroes) == "table" and profile.UnlockedHeroes or defaults().UnlockedHeroes
	profile.OwnedSkins = type(profile.OwnedSkins) == "table" and profile.OwnedSkins or {}
	profile.PurchasedItems = type(profile.PurchasedItems) == "table" and profile.PurchasedItems or {}
	profile.Achievements = type(profile.Achievements) == "table" and profile.Achievements or {}
	profile.HeroStats = type(profile.HeroStats) == "table" and profile.HeroStats or {}
	return profile
end

function ProgressionSystem.Init()
	ProgressionSystem.Profiles = {}
	ProgressionSystem.Loaded = {}
	ProgressionSystem.Saving = {}
end

function ProgressionSystem.Load(player)
	if ProgressionSystem.Loaded[player.UserId] and ProgressionSystem.Profiles[player.UserId] then return ProgressionSystem.Profiles[player.UserId] end
	local profile = defaults()
	if ProgressionSystem.DataStoreAvailable and store then
		local success, data = pcall(function() return store:GetAsync("user_" .. player.UserId) end)
		if success then profile = mergeProfile(data) else warn("[PDA] Profile load failed for " .. player.UserId .. ": " .. tostring(data)) end
	end
	ProgressionSystem.Profiles[player.UserId] = profile
	ProgressionSystem.Loaded[player.UserId] = true
	return profile
end

function ProgressionSystem.Save(player)
	local userId = player.UserId
	local profile = ProgressionSystem.Profiles[userId]
	if not profile or ProgressionSystem.Saving[userId] or not ProgressionSystem.DataStoreAvailable or not store then return false end
	ProgressionSystem.Saving[userId] = true
	profile.UpdatedAt = os.time()
	profile.LastPlayed = os.time()
	local snapshot = table.clone(profile)
	local success, saveError = pcall(function()
		store:UpdateAsync("user_" .. userId, function(existing)
			local result = mergeProfile(existing)
			for key, value in pairs(snapshot) do result[key] = value end
			result.SchemaVersion = SCHEMA_VERSION
			result.UpdatedAt = os.time()
			return result
		end)
	end)
	ProgressionSystem.Saving[userId] = nil
	if not success then warn("[PDA] Profile save failed for " .. userId .. ": " .. tostring(saveError)) end
	return success
end

local function intValue(folder, name)
	local value = folder:FindFirstChild(name) or Instance.new("IntValue")
	value.Name = name
	value.Parent = folder
	return value
end

function ProgressionSystem.CreateLeaderstats(player)
	local profile = ProgressionSystem.Load(player)
	local folder = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	intValue(folder, "Wins").Value = profile.Wins or 0
	intValue(folder, "Losses").Value = profile.Losses or 0
	intValue(folder, "Kills").Value = profile.TotalKills or 0
	intValue(folder, "Coins").Value = profile.Coins or 0
	intValue(folder, "XP").Value = profile.XP or 0
	intValue(folder, "Level").Value = ProgressionUtils.GetLevel(profile.XP or 0)
	local kd = folder:FindFirstChild("K/D") or Instance.new("StringValue")
	kd.Name = "K/D"
	kd.Value = string.format("%.2f", (profile.TotalKills or 0) / math.max(1, profile.TotalDeaths or 0))
	kd.Parent = folder
	return profile
end

function ProgressionSystem.SyncLeaderstats(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	local folder = player:FindFirstChild("leaderstats")
	if not profile or not folder then return end
	for name, value in pairs({Wins = profile.Wins or 0, Losses = profile.Losses or 0, Kills = profile.TotalKills or 0, Coins = profile.Coins or 0, XP = profile.XP or 0, Level = ProgressionUtils.GetLevel(profile.XP or 0)}) do
		local object = folder:FindFirstChild(name)
		if object then object.Value = value end
	end
	local kd = folder:FindFirstChild("K/D")
	if kd then kd.Value = string.format("%.2f", (profile.TotalKills or 0) / math.max(1, profile.TotalDeaths or 0)) end
end

function ProgressionSystem.GetLevel(xp) return ProgressionUtils.GetLevel(xp) end
function ProgressionSystem.GetXpNeededForLevel(level) return ProgressionUtils.GetXpNeededForLevel(level) end
function ProgressionSystem.GetProfile(player) return ProgressionSystem.Profiles[player.UserId] end

function ProgressionSystem.AwardMatch(player, result, teamScore)
	local profile = ProgressionSystem.Load(player)
	local coins, xp = 20, 35
	if result == "Win" then coins, xp = 75, 140; profile.Wins += 1
	elseif result == "Loss" then coins, xp = 25, 55; profile.Losses += 1 end
	coins += math.clamp(math.floor((tonumber(teamScore) or 0) / 100), 0, 25)
	xp += math.clamp(math.floor((tonumber(teamScore) or 0) / 50), 0, 50)
	profile.Coins += coins
	profile.XP += xp
	local okHero, HeroSystem = pcall(require, script.Parent:WaitForChild("HeroSystem"))
	local hero = okHero and HeroSystem.GetControlledHero(player) or nil
	if hero then
		profile.TotalKills += hero.KillCount or 0
		profile.TotalDeaths += hero.DeathCount or 0
		profile.TotalDamage += math.floor(hero.DamageDealt or 0)
	end
	ProgressionSystem.SyncLeaderstats(player)
	return {coins = coins, xp = xp}
end

function ProgressionSystem.UnlockHero(player, heroId)
	local profile = ProgressionSystem.Load(player)
	if type(heroId) ~= "string" or not HeroConfig[heroId] then return false end
	if table.find(profile.UnlockedHeroes, heroId) then return true end
	local cost = 500
	if profile.Coins < cost then return false end
	profile.Coins -= cost
	table.insert(profile.UnlockedHeroes, heroId)
	ProgressionSystem.SyncLeaderstats(player)
	return true
end

function ProgressionSystem.UnlockSkin(player, heroId, skinId)
	local profile = ProgressionSystem.Load(player)
	local hero = HeroConfig[heroId]
	local skin = hero and hero.skins and hero.skins[skinId]
	if not skin or not table.find(profile.UnlockedHeroes, heroId) then return false end
	local key = heroId .. "_" .. skinId
	if table.find(profile.OwnedSkins, key) then profile.EquippedSkin = key; return true end
	local costs = {Common = 50, Rare = 200, Epic = 500, Legendary = 1500}
	local cost = costs[skin.rarity] or 100
	if profile.Coins < cost then return false end
	profile.Coins -= cost
	table.insert(profile.OwnedSkins, key)
	profile.EquippedSkin = key
	ProgressionSystem.SyncLeaderstats(player)
	return true
end

function ProgressionSystem.EquipSkin(player, heroId, skinId)
	local profile = ProgressionSystem.Load(player)
	if skinId == "default" then profile.EquippedSkin = "default" return true end
	local key = heroId .. "_" .. skinId
	if not table.find(profile.OwnedSkins, key) then return false end
	profile.EquippedSkin = key
	return true
end

function ProgressionSystem.RecordKill(player, heroId, kills, deaths)
	local profile = ProgressionSystem.Load(player)
	kills, deaths = math.max(0, tonumber(kills) or 0), math.max(0, tonumber(deaths) or 0)
	profile.TotalKills += kills
	profile.TotalDeaths += deaths
	profile.HeroStats[heroId] = profile.HeroStats[heroId] or {kills = 0, deaths = 0, damage = 0}
	profile.HeroStats[heroId].kills += kills
	profile.HeroStats[heroId].deaths += deaths
	ProgressionSystem.SyncLeaderstats(player)
end

function ProgressionSystem.GetSkinList(heroId)
	local hero = HeroConfig[heroId]
	local result = {"default"}
	if hero and hero.skins then for id in pairs(hero.skins) do if id ~= "default" then table.insert(result, id) end end end
	return result
end

function ProgressionSystem.GetSkinRarity(heroId, skinId)
	local hero = HeroConfig[heroId]
	return hero and hero.skins and hero.skins[skinId] and hero.skins[skinId].rarity or "Default"
end

function ProgressionSystem.PurchaseShopItem(player, itemId)
	local profile = ProgressionSystem.Load(player)
	local item
	for _, candidate in ipairs(Config.SHOP_ITEMS or {}) do if candidate.id == itemId then item = candidate break end end
	if not item then return false, "Item not found" end
	if item.category == "Currency" or string.find(item.id or "", "^coins_") then return false, "Currency packs require a verified developer-product receipt" end
	if table.find(profile.PurchasedItems, itemId) then return false, "Already owned" end
	local price = math.max(0, tonumber(item.price) or 0)
	if profile.Coins < price then return false, "Not enough coins" end
	profile.Coins -= price
	table.insert(profile.PurchasedItems, itemId)
	for _, skinKey in ipairs(item.items or {}) do if not table.find(profile.OwnedSkins, skinKey) then table.insert(profile.OwnedSkins, skinKey) end end
	ProgressionSystem.SyncLeaderstats(player)
	return true, "Purchased"
end

function ProgressionSystem.GetBattlePassRewards() return nil end
function ProgressionSystem.ClaimBattlePassReward() return false, "Battle pass disabled until reward receipts are production-ready" end

return ProgressionSystem
