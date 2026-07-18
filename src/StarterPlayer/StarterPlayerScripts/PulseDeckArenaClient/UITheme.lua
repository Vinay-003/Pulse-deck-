local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(5, 8, 16),
	BackgroundRaised = Color3.fromRGB(10, 15, 28),
	Surface = Color3.fromRGB(15, 22, 38),
	SurfaceHover = Color3.fromRGB(23, 33, 54),
	SurfaceStrong = Color3.fromRGB(28, 39, 62),
	Border = Color3.fromRGB(60, 78, 112),
	BorderSoft = Color3.fromRGB(38, 50, 75),
	Text = Color3.fromRGB(241, 246, 255),
	TextMuted = Color3.fromRGB(151, 166, 193),
	TextDim = Color3.fromRGB(101, 116, 143),
	Accent = Color3.fromRGB(61, 225, 190),
	AccentBright = Color3.fromRGB(103, 255, 220),
	AccentDark = Color3.fromRGB(19, 118, 106),
	Warning = Color3.fromRGB(255, 190, 71),
	Danger = Color3.fromRGB(255, 85, 103),
	Red = Color3.fromRGB(255, 79, 92),
	Blue = Color3.fromRGB(69, 173, 255),
	Health = Color3.fromRGB(71, 222, 139),
	Shield = Color3.fromRGB(83, 164, 255),
	Ultimate = Color3.fromRGB(255, 193, 75),
	Overlay = Color3.fromRGB(2, 4, 10),
}

Theme.RoleColors = {
	Assault = Color3.fromRGB(255, 93, 106),
	Tank = Color3.fromRGB(77, 147, 255),
	Sniper = Color3.fromRGB(174, 104, 255),
	Support = Color3.fromRGB(66, 221, 147),
	Demolition = Color3.fromRGB(255, 159, 67),
	Skirmisher = Color3.fromRGB(255, 91, 210),
	Engineer = Color3.fromRGB(224, 185, 76),
	Controller = Color3.fromRGB(65, 199, 232),
	Flanker = Color3.fromRGB(222, 126, 78),
	Mage = Color3.fromRGB(222, 91, 177),
	Defender = Color3.fromRGB(137, 151, 181),
}

Theme.Radius = {
	Small = 6,
	Medium = 10,
	Large = 16,
	Pill = 999,
}

function Theme.GetRoleColor(role)
	return Theme.RoleColors[role] or Theme.Colors.TextMuted
end

function Theme.GetTeamColor(teamId)
	if teamId == "Red" then
		return Theme.Colors.Red
	elseif teamId == "Blue" then
		return Theme.Colors.Blue
	end
	return Theme.Colors.TextMuted
end

return Theme
