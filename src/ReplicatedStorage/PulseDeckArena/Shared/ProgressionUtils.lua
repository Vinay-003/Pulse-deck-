--!strict

local XP_LEVELS = {
	0, 500, 1200, 2200, 3500, 5000, 7000, 9500, 12500, 16000,
	20000, 25000, 30000, 36000, 42000, 50000, 60000, 70000, 85000, 100000,
}

local ProgressionUtils = {}

function ProgressionUtils.GetLevel(xp: number): number
	local level = 1
	for i, threshold in ipairs(XP_LEVELS) do
		if xp >= threshold then
			level = i + 1
		else
			break
		end
	end
	return math.min(level, 20)
end

function ProgressionUtils.GetXpNeededForLevel(level: number): number
	if level <= 1 then return 0 end
	if level - 1 <= #XP_LEVELS then
		return XP_LEVELS[level - 1]
	end
	return XP_LEVELS[#XP_LEVELS] + (level - 1 - #XP_LEVELS) * 25000
end

ProgressionUtils.BATTLE_PASS_TIERS = {}
for i = 1, 50 do
	ProgressionUtils.BATTLE_PASS_TIERS[i] = {
		xpRequired = 500 + (i - 1) * 150,
		freeReward = (i % 5 == 0) and {type = "coins", amount = 100} or (i % 3 == 0) and {type = "skin_token", id = nil} or nil,
		premiumReward = (i % 10 == 0) and {type = "skin_chest", rarity = "Epic"} or {type = "coins", amount = 200},
	}
end

function ProgressionUtils.GetBattlePassTier(xp)
	local tier = 0
	local accumulated = 0
	for i = 1, 50 do
		local needed = 500 + (i - 1) * 150
		if accumulated + needed > xp then
			return i, accumulated, xp - accumulated
		end
		accumulated += needed
		tier = i
	end
	return 50, accumulated, 0
end

function ProgressionUtils.GetBattlePassProgress(xp)
	local tier, used, remainder = ProgressionUtils.GetBattlePassTier(xp)
	local nextNeeded = 500 + (tier) * 150
	local progress = remainder / nextNeeded
	return tier, progress, nextNeeded
end

return ProgressionUtils