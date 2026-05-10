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

return ProgressionUtils