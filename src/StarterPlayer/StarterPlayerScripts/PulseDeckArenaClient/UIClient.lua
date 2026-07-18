local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local Config = require(sharedRoot:WaitForChild("Config"))
local ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local Theme = require(script.Parent:WaitForChild("UITheme"))

local UIClient = {
	Gui = nil,
	Root = nil,
	Screens = {},
	SelectedDeck = {},
	HeroButtons = {},
	HUDTargets = {health = 1, shield = 0, ability = 0, ultimate = 0},
	HUDSmoothing = {health = 1, shield = 0, ability = 0, ultimate = 0},
}

local C = Theme.Colors

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color or C.BorderSoft
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0
	item.Parent = parent
	return item
end

local function frame(parent, name, size, position, color, transparency)
	local item = Instance.new("Frame")
	item.Name = name
	item.Size = size
	item.Position = position or UDim2.fromOffset(0, 0)
	item.BackgroundColor3 = color or C.Surface
	item.BackgroundTransparency = transparency or 0
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end

local function label(parent, name, text, size, position, textSize, color, font)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Text = text
	item.Size = size
	item.Position = position or UDim2.fromOffset(0, 0)
	item.BackgroundTransparency = 1
	item.TextColor3 = color or C.Text
	item.Font = font or Enum.Font.Gotham
	item.TextSize = textSize or 14
	item.TextWrapped = true
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Text = text
	item.Size = size
	item.Position = position or UDim2.fromOffset(0, 0)
	item.BackgroundColor3 = color or C.SurfaceStrong
	item.BorderSizePixel = 0
	item.AutoButtonColor = false
	item.TextColor3 = C.Text
	item.Font = Enum.Font.GothamBold
	item.TextSize = 14
	item.Parent = parent
	corner(item, Theme.Radius.Medium)
	local outline = stroke(item, C.BorderSoft, 1, 0.1)
	local base = item.BackgroundColor3
	item.MouseEnter:Connect(function()
		item.BackgroundColor3 = C.SurfaceHover
		outline.Color = C.Accent
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundColor3 = base
		outline.Color = C.BorderSoft
	end)
	return item
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function setOnlyScreen(name)
	for screenName, screen in pairs(UIClient.Screens) do
		screen.Visible = screenName == name
	end
end

local function buildBackdrop(parent)
	local bg = frame(parent, "Backdrop", UDim2.fromScale(1, 1), nil, C.Background)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Background),
		ColorSequenceKeypoint.new(0.55, C.BackgroundRaised),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 29, 39)),
	})
	gradient.Rotation = 25
	gradient.Parent = bg
	local glow = frame(bg, "Glow", UDim2.fromScale(0.55, 0.8), UDim2.fromScale(0.55, 0.08), C.Accent, 0.9)
	corner(glow, Theme.Radius.Pill)
	return bg
end

local function makeScreen(name)
	local screen = frame(UIClient.Root, name, UDim2.fromScale(1, 1), nil, C.Background, 1)
	screen.Visible = false
	UIClient.Screens[name] = screen
	UIClient[name] = screen
	return screen
end

function UIClient.Show(screenName)
	if UIClient.SettingsFrame then UIClient.SettingsFrame:Destroy(); UIClient.SettingsFrame = nil end
	if UIClient.PauseMenu then UIClient.PauseMenu:Destroy(); UIClient.PauseMenu = nil end
	setOnlyScreen(screenName)
end

function UIClient.BuildMainMenu()
	local screen = UIClient.MainMenu
	buildBackdrop(screen)

	local shell = frame(screen, "Shell", UDim2.new(0.9, 0, 0.82, 0), UDim2.new(0.05, 0, 0.09, 0), C.Surface, 0.16)
	corner(shell, Theme.Radius.Large)
	stroke(shell, C.Border, 1.5, 0.2)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(1100, 720)
	constraint.MinSize = Vector2.new(640, 440)
	constraint.Parent = shell

	local brand = label(shell, "Brand", "PULSE DECK", UDim2.new(0.52, 0, 0, 68), UDim2.new(0.06, 0, 0.08, 0), 44, C.Text, Enum.Font.GothamBlack)
	brand.TextXAlignment = Enum.TextXAlignment.Left
	local arena = label(shell, "Arena", "ARENA", UDim2.new(0.4, 0, 0, 34), UDim2.new(0.06, 0, 0.19, 0), 21, C.Accent, Enum.Font.GothamBlack)
	arena.TextXAlignment = Enum.TextXAlignment.Left
	local subtitle = label(shell, "Subtitle", "Build your squad. Break the enemy core.", UDim2.new(0.48, 0, 0, 54), UDim2.new(0.06, 0, 0.29, 0), 17, C.TextMuted, Enum.Font.GothamMedium)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left

	local stats = frame(shell, "Stats", UDim2.new(0.46, 0, 0, 96), UDim2.new(0.06, 0, 0.43, 0), C.BackgroundRaised, 0.1)
	corner(stats, Theme.Radius.Medium)
	stroke(stats, C.BorderSoft, 1, 0.2)
	local progression = ClientCore.State.progression or {}
	local level = ProgressionUtils.GetLevel(progression.XP or 0)
	local statsText = string.format("LEVEL %d    WINS %d    COINS %d", level, progression.Wins or 0, progression.Coins or 0)
	local statsLabel = label(stats, "StatsText", statsText, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 15, C.Text, Enum.Font.GothamBold)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left

	local actions = frame(shell, "Actions", UDim2.new(0.34, 0, 0.7, 0), UDim2.new(0.61, 0, 0.15, 0), C.BackgroundRaised, 0.05)
	corner(actions, Theme.Radius.Large)
	stroke(actions, C.Border, 1.5, 0.2)
	local title = label(actions, "Title", "ENTER THE ARENA", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 18), 20, C.Text, Enum.Font.GothamBlack)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local play = button(actions, "Play", "PLAY", UDim2.new(1, -32, 0, 58), UDim2.fromOffset(16, 72), C.AccentDark)
	play.TextSize = 20
	play.Activated:Connect(function() ClientCore.Fire("RequestJoinQueue", {}) end)
	local ready = button(actions, "Ready", "READY UP", UDim2.new(1, -32, 0, 46), UDim2.fromOffset(16, 144), C.SurfaceStrong)
	ready.Activated:Connect(function() ClientCore.Fire("RequestReady", {}) end)
	local settings = button(actions, "Settings", "SETTINGS", UDim2.new(1, -32, 0, 42), UDim2.fromOffset(16, 204), C.SurfaceStrong)
	settings.Activated:Connect(function() UIClient.ShowSettings() end)
	label(actions, "Mode", "CORE ASSAULT  •  SOLO + BOTS READY", UDim2.new(1, -32, 0, 44), UDim2.fromOffset(16, 270), 12, C.TextDim, Enum.Font.GothamBold)

	local footer = label(shell, "Footer", "WASD MOVE   •   MOUSE AIM   •   LMB FIRE   •   Q ABILITY   •   E ULTIMATE", UDim2.new(0.9, 0, 0, 24), UDim2.new(0.05, 0, 1, -36), 11, C.TextDim, Enum.Font.GothamBold)
	footer.TextXAlignment = Enum.TextXAlignment.Left
end

function UIClient.UpdateDeckGrid()
	if not UIClient.DeckSelect then return end
	for heroId, data in pairs(UIClient.DeckCards or {}) do
		local selected = table.find(UIClient.SelectedDeck, heroId) ~= nil
		data.Overlay.Visible = selected
		data.Stroke.Color = selected and C.Accent or C.BorderSoft
	end
	local count = #UIClient.SelectedDeck
	if UIClient.DeckCountLabel then UIClient.DeckCountLabel.Text = string.format("%d / %d SELECTED", count, Config.DECK_SIZE) end
	if UIClient.DeckConfirmButton then
		UIClient.DeckConfirmButton.Text = count == Config.DECK_SIZE and "CONFIRM & START" or string.format("SELECT %d MORE", Config.DECK_SIZE - count)
		UIClient.DeckConfirmButton.BackgroundColor3 = count == Config.DECK_SIZE and C.AccentDark or C.SurfaceStrong
	end
end

function UIClient.BuildDeckSelect()
	local screen = UIClient.DeckSelect
	buildBackdrop(screen)
	label(screen, "Title", "BUILD YOUR DECK", UDim2.new(0.7, 0, 0, 50), UDim2.new(0.05, 0, 0.04, 0), 30, C.Text, Enum.Font.GothamBlack).TextXAlignment = Enum.TextXAlignment.Left
	UIClient.DeckCountLabel = label(screen, "Count", "0 / 5 SELECTED", UDim2.new(0.25, 0, 0, 36), UDim2.new(0.7, 0, 0.055, 0), 15, C.Accent, Enum.Font.GothamBold)

	local holder = frame(screen, "GridHolder", UDim2.new(0.9, 0, 0.7, 0), UDim2.new(0.05, 0, 0.14, 0), C.Surface, 0.12)
	corner(holder, Theme.Radius.Large)
	stroke(holder, C.Border, 1, 0.2)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "HeroGrid"
	grid.Size = UDim2.new(1, -24, 1, -24)
	grid.Position = UDim2.fromOffset(12, 12)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = C.Accent
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.fromOffset(0, 0)
	grid.Parent = holder
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(196, 126)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	UIClient.DeckCards = {}
	local ids = {}
	for heroId in pairs(HeroConfig) do table.insert(ids, heroId) end
	table.sort(ids)
	for index, heroId in ipairs(ids) do
		local def = HeroConfig[heroId]
		local card = frame(grid, heroId, UDim2.fromOffset(196, 126), nil, C.BackgroundRaised, 0.02)
		card.LayoutOrder = index
		corner(card, Theme.Radius.Medium)
		local outline = stroke(card, C.BorderSoft, 1.5, 0.1)
		label(card, "Name", def.displayName or heroId, UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 8), 14, C.Text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		label(card, "Role", string.upper(def.role or "HERO"), UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 34), 10, Theme.GetRoleColor(def.role), Enum.Font.GothamBlack).TextXAlignment = Enum.TextXAlignment.Left
		local weapon = WeaponConfig[def.weaponId]
		label(card, "Weapon", weapon and weapon.displayName or "Unknown weapon", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 59), 11, C.TextMuted, Enum.Font.GothamMedium).TextXAlignment = Enum.TextXAlignment.Left
		label(card, "Stats", string.format("HP %d   SPD %d", def.maxHealth or 0, def.walkSpeed or 0), UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 84), 10, C.TextDim, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local overlay = frame(card, "Selected", UDim2.fromScale(1, 1), nil, C.AccentDark, 0.24)
		overlay.Visible = false
		corner(overlay, Theme.Radius.Medium)
		label(overlay, "SelectedText", "SELECTED", UDim2.fromScale(1, 1), nil, 15, C.Text, Enum.Font.GothamBlack)
		local hit = Instance.new("TextButton")
		hit.Name = "HitTarget"
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 5
		hit.Parent = card
		hit.Activated:Connect(function()
			local existing = table.find(UIClient.SelectedDeck, heroId)
			if existing then table.remove(UIClient.SelectedDeck, existing)
			elseif #UIClient.SelectedDeck < Config.DECK_SIZE then table.insert(UIClient.SelectedDeck, heroId) end
			UIClient.UpdateDeckGrid()
		end)
		UIClient.DeckCards[heroId] = {Overlay = overlay, Stroke = outline}
	end

	local back = button(screen, "Back", "BACK", UDim2.fromOffset(120, 44), UDim2.new(0.05, 0, 0.87, 0), C.SurfaceStrong)
	back.Activated:Connect(function() UIClient.Show("MainMenu") end)
	UIClient.DeckConfirmButton = button(screen, "Confirm", "SELECT 5 MORE", UDim2.fromOffset(240, 48), UDim2.new(1, -290, 0.865, 0), C.SurfaceStrong)
	UIClient.DeckConfirmButton.Activated:Connect(function()
		if #UIClient.SelectedDeck ~= Config.DECK_SIZE then return end
		ClientCore.Fire("RequestDeckUpdate", {heroIds = table.clone(UIClient.SelectedDeck)})
		ClientCore.Fire("RequestStartMatch", {})
	end)
	UIClient.UpdateDeckGrid()
end

local function progressBar(parent, name, y, color)
	local bg = frame(parent, name .. "BG", UDim2.new(1, -28, 0, 10), UDim2.fromOffset(14, y), C.Background, 0.15)
	corner(bg, Theme.Radius.Pill)
	local fill = frame(bg, name .. "Fill", UDim2.fromScale(1, 1), nil, color)
	corner(fill, Theme.Radius.Pill)
	return fill
end

function UIClient.BuildHUD()
	local screen = UIClient.HUD
	local top = frame(screen, "TopBar", UDim2.fromOffset(430, 62), UDim2.new(0.5, -215, 0, 14), C.BackgroundRaised, 0.08)
	corner(top, Theme.Radius.Large); stroke(top, C.BorderSoft, 1, 0.15)
	UIClient.ModeLabel = label(top, "Mode", "STANDARD", UDim2.fromOffset(110, 22), UDim2.fromOffset(14, 8), 11, C.TextMuted, Enum.Font.GothamBlack)
	UIClient.ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
	UIClient.ScoreLabel = label(top, "Score", "RED 0   :   0 BLUE", UDim2.fromOffset(250, 30), UDim2.new(0.5, -125, 0, 24), 18, C.Text, Enum.Font.GothamBlack)
	UIClient.ScoreLabel.RichText = true
	UIClient.TimerLabel = label(top, "Timer", "5:00", UDim2.fromOffset(80, 28), UDim2.new(1, -92, 0, 8), 20, C.Warning, Enum.Font.GothamBlack)

	local vitals = frame(screen, "Vitals", UDim2.fromOffset(300, 92), UDim2.new(0, 18, 1, -112), C.BackgroundRaised, 0.08)
	corner(vitals, Theme.Radius.Large); stroke(vitals, C.BorderSoft, 1, 0.15)
	label(vitals, "VitalsTitle", "COMBAT STATUS", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 8), 10, C.TextMuted, Enum.Font.GothamBlack).TextXAlignment = Enum.TextXAlignment.Left
	UIClient.HealthBarFill = progressBar(vitals, "Health", 34, C.Health)
	UIClient.ShieldBarFill = progressBar(vitals, "Shield", 54, C.Shield)
	UIClient.AbilityBarFill = progressBar(vitals, "Ability", 74, C.Accent)

	local ammo = frame(screen, "Ammo", UDim2.fromOffset(190, 78), UDim2.new(1, -208, 1, -98), C.BackgroundRaised, 0.08)
	corner(ammo, Theme.Radius.Large); stroke(ammo, C.BorderSoft, 1, 0.15)
	UIClient.AmmoLabel = label(ammo, "AmmoLabel", "-- / --", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 8), 25, C.Text, Enum.Font.GothamBlack)
	UIClient.WeaponNameLabel = label(ammo, "WeaponName", "NO WEAPON", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 49), 10, C.TextMuted, Enum.Font.GothamBlack)

	local heroes = frame(screen, "HeroBar", UDim2.fromOffset(360, 48), UDim2.new(0.5, -180, 1, -62), C.BackgroundRaised, 0.08)
	corner(heroes, Theme.Radius.Large)
	for i = 1, Config.DECK_SIZE do
		local heroButton = button(heroes, "Hero" .. i, tostring(i), UDim2.fromOffset(62, 34), UDim2.fromOffset(8 + (i - 1) * 70, 7), C.SurfaceStrong)
		heroButton.TextSize = 11
		heroButton.Activated:Connect(function() ClientCore.Fire("RequestSwitchHero", {slot = i}) end)
		UIClient.HeroButtons[i] = heroButton
	end

	UIClient.KillfeedContainer = frame(screen, "Killfeed", UDim2.fromOffset(340, 180), UDim2.new(1, -356, 0, 90), C.Background, 1)
	local killLayout = Instance.new("UIListLayout"); killLayout.Padding = UDim.new(0, 5); killLayout.Parent = UIClient.KillfeedContainer
	UIClient.NotificationArea = frame(screen, "Notifications", UDim2.fromOffset(320, 150), UDim2.new(0, 18, 0, 92), C.Background, 1)
	local notificationLayout = Instance.new("UIListLayout"); notificationLayout.Padding = UDim.new(0, 4); notificationLayout.Parent = UIClient.NotificationArea

	UIClient.DefuseBar = frame(screen, "DefuseBar", UDim2.fromOffset(320, 36), UDim2.new(0.5, -160, 0.72, 0), C.BackgroundRaised, 0.05)
	UIClient.DefuseBar.Visible = false
	corner(UIClient.DefuseBar, Theme.Radius.Medium)
	UIClient.DefuseBarFill = frame(UIClient.DefuseBar, "Fill", UDim2.fromScale(0, 1), nil, C.AccentDark)
	corner(UIClient.DefuseBarFill, Theme.Radius.Medium)
	label(UIClient.DefuseBar, "Text", "DEFUSING", UDim2.fromScale(1, 1), nil, 12, C.Text, Enum.Font.GothamBlack).ZIndex = 2
end

function UIClient.BuildScoreboard()
	local screen = UIClient.Scoreboard
	screen.BackgroundColor3 = C.Overlay
	screen.BackgroundTransparency = 0.25
	local panel = frame(screen, "Panel", UDim2.new(0.72, 0, 0.72, 0), UDim2.new(0.14, 0, 0.14, 0), C.BackgroundRaised, 0.02)
	corner(panel, Theme.Radius.Large); stroke(panel, C.Border, 1.5, 0.15)
	label(panel, "Title", "MATCH SCOREBOARD", UDim2.new(1, -30, 0, 54), UDim2.fromOffset(15, 8), 24, C.Text, Enum.Font.GothamBlack)
	local list = frame(panel, "Rows", UDim2.new(1, -30, 1, -80), UDim2.fromOffset(15, 68), C.Background, 1)
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = list
end

function UIClient.UpdateScoreboard(players)
	local rows = UIClient.Scoreboard and UIClient.Scoreboard:FindFirstChild("Panel") and UIClient.Scoreboard.Panel:FindFirstChild("Rows")
	if not rows then return end
	clear(rows)
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = rows
	table.sort(players, function(a, b) return (a.score or 0) > (b.score or 0) end)
	for _, row in ipairs(players) do
		local entry = frame(rows, "Player", UDim2.new(1, 0, 0, 42), nil, C.Surface, 0.05)
		corner(entry, Theme.Radius.Small)
		local text = string.format("%-18s   K %d   D %d   SCORE %d", tostring(row.name), row.kills or 0, row.deaths or 0, row.score or 0)
		local item = label(entry, "Text", text, UDim2.new(1, -18, 1, 0), UDim2.fromOffset(9, 0), 13, Theme.GetTeamColor(row.teamId), Enum.Font.GothamBold)
		item.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function UIClient.BuildPostMatch()
	local screen = UIClient.PostMatch
	buildBackdrop(screen)
	UIClient.ResultLabel = label(screen, "Result", "MATCH COMPLETE", UDim2.new(0.8, 0, 0, 80), UDim2.new(0.1, 0, 0.28, 0), 40, C.Text, Enum.Font.GothamBlack)
	local home = button(screen, "Home", "RETURN TO MENU", UDim2.fromOffset(260, 52), UDim2.new(0.5, -130, 0.58, 0), C.AccentDark)
	home.Activated:Connect(function() UIClient.Show("MainMenu") end)
end

function UIClient.ShowSettings()
	if UIClient.SettingsFrame then UIClient.SettingsFrame:Destroy() end
	local overlay = frame(UIClient.Root, "SettingsPanel", UDim2.fromScale(1, 1), nil, C.Overlay, 0.22)
	overlay.ZIndex = 80
	UIClient.SettingsFrame = overlay
	local panel = frame(overlay, "Panel", UDim2.fromOffset(480, 420), UDim2.new(0.5, -240, 0.5, -210), C.BackgroundRaised, 0.02)
	panel.ZIndex = 81; corner(panel, Theme.Radius.Large); stroke(panel, C.Border, 1.5, 0.1)
	label(panel, "Title", "SETTINGS", UDim2.new(1, -32, 0, 52), UDim2.fromOffset(16, 10), 24, C.Text, Enum.Font.GothamBlack).ZIndex = 82
	local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))
	local values = {
		{"MASTER VOLUME", function() return SettingsClient.MasterVolume end, function(v) SettingsClient.MasterVolume = v end},
		{"SFX VOLUME", function() return SettingsClient.SFXVolume end, function(v) SettingsClient.SFXVolume = v end},
		{"MUSIC VOLUME", function() return SettingsClient.MusicVolume end, function(v) SettingsClient.MusicVolume = v end},
		{"SENSITIVITY", function() return math.clamp(SettingsClient.Sensitivity / 3, 0, 1) end, function(v) SettingsClient.Sensitivity = v * 3 end},
	}
	for index, data in ipairs(values) do
		local y = 72 + (index - 1) * 62
		local text = label(panel, "Setting", data[1], UDim2.fromOffset(170, 24), UDim2.fromOffset(20, y), 12, C.TextMuted, Enum.Font.GothamBold); text.ZIndex = 82; text.TextXAlignment = Enum.TextXAlignment.Left
		local minus = button(panel, "Minus", "-", UDim2.fromOffset(42, 34), UDim2.fromOffset(205, y - 5), C.SurfaceStrong); minus.ZIndex = 82
		local value = label(panel, "Value", tostring(math.floor(data[2]() * 100)) .. "%", UDim2.fromOffset(90, 34), UDim2.fromOffset(255, y - 5), 13, C.Text, Enum.Font.GothamBold); value.ZIndex = 82
		local plus = button(panel, "Plus", "+", UDim2.fromOffset(42, 34), UDim2.fromOffset(352, y - 5), C.SurfaceStrong); plus.ZIndex = 82
		local function change(delta)
			local nextValue = math.clamp(data[2]() + delta, 0, 1)
			data[3](nextValue)
			value.Text = tostring(math.floor(nextValue * 100)) .. "%"
		end
		minus.Activated:Connect(function() change(-0.1) end)
		plus.Activated:Connect(function() change(0.1) end)
	end
	local save = button(panel, "Save", "SAVE & CLOSE", UDim2.new(1, -40, 0, 46), UDim2.new(0, 20, 1, -66), C.AccentDark); save.ZIndex = 82
	save.Activated:Connect(function() SettingsClient.Save(); overlay:Destroy(); UIClient.SettingsFrame = nil end)
end

function UIClient:ShowPauseMenu()
	if self.PauseMenu then self.PauseMenu:Destroy(); self.PauseMenu = nil; return end
	local overlay = frame(self.Root, "PauseMenu", UDim2.fromScale(1, 1), nil, C.Overlay, 0.22)
	overlay.ZIndex = 90
	self.PauseMenu = overlay
	local panel = frame(overlay, "Panel", UDim2.fromOffset(380, 320), UDim2.new(0.5, -190, 0.5, -160), C.BackgroundRaised, 0.02)
	panel.ZIndex = 91; corner(panel, Theme.Radius.Large); stroke(panel, C.Border, 1.5, 0.1)
	label(panel, "Title", "PAUSED", UDim2.new(1, -30, 0, 60), UDim2.fromOffset(15, 10), 28, C.Text, Enum.Font.GothamBlack).ZIndex = 92
	local resume = button(panel, "Resume", "RESUME", UDim2.new(1, -40, 0, 48), UDim2.fromOffset(20, 82), C.AccentDark); resume.ZIndex = 92
	resume.Activated:Connect(function() overlay:Destroy(); self.PauseMenu = nil end)
	local settings = button(panel, "Settings", "SETTINGS", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 146), C.SurfaceStrong); settings.ZIndex = 92
	settings.Activated:Connect(function() overlay:Destroy(); self.PauseMenu = nil; self.ShowSettings() end)
	local leave = button(panel, "Leave", "LEAVE MATCH", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 206), C.Danger); leave.ZIndex = 92
	leave.Activated:Connect(function() ClientCore.Fire("RequestLeave", {}) end)
end

function UIClient:ShowNotification(text, duration)
	if not self.NotificationArea then return end
	local item = frame(self.NotificationArea, "Notice", UDim2.new(1, 0, 0, 36), nil, C.BackgroundRaised, 0.04)
	corner(item, Theme.Radius.Small); stroke(item, C.BorderSoft, 1, 0.2)
	local message = label(item, "Text", tostring(text), UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 12, C.Accent, Enum.Font.GothamBold)
	message.TextXAlignment = Enum.TextXAlignment.Left
	task.delay(duration or 3, function() if item.Parent then item:Destroy() end end)
end

function UIClient.ShowAnnouncement(payload)
	UIClient:ShowNotification(payload.text or "", payload.duration or 3)
end

function UIClient.BindState()
	ClientCore.Events.MatchStateChanged.Event:Connect(function(payload)
		local state = payload.state
		if state == "Lobby" then UIClient.Show("MainMenu")
		elseif state == "DeckSelect" then UIClient.Show("DeckSelect")
		elseif state == "MatchCountdown" or state == "ActiveMatch" or state == "SuddenDeath" then UIClient.Show("HUD")
		elseif state == "PostMatch" then
			UIClient.ResultLabel.Text = payload.winner == Config.TEAM_RED and "RED TEAM WINS" or payload.winner == Config.TEAM_BLUE and "BLUE TEAM WINS" or "DRAW"
			UIClient.Show("PostMatch")
		end
		if UIClient.TimerLabel then
			local timer = math.max(0, math.floor(payload.timerRemaining or 0))
			UIClient.TimerLabel.Text = string.format("%d:%02d", math.floor(timer / 60), timer % 60)
		end
		if UIClient.ModeLabel then UIClient.ModeLabel.Text = string.upper(payload.gameMode or "STANDARD") end
	end)

	ClientCore.Events.ScoreChanged.Event:Connect(function(payload)
		if UIClient.ScoreLabel then UIClient.ScoreLabel.Text = string.format("<font color='#FF4F5C'>RED %d</font>   :   <font color='#45ADFF'>%d BLUE</font>", math.floor(payload.Red or 0), math.floor(payload.Blue or 0)) end
	end)

	ClientCore.Events.HeroStateChanged.Event:Connect(function(payload)
		for _, hero in pairs(payload.heroes or {}) do
			if hero.ownerUserId == Players.LocalPlayer.UserId then
				local heroButton = UIClient.HeroButtons[hero.slot]
				if heroButton then heroButton.Text = tostring(hero.slot) .. "  " .. tostring(hero.heroId):gsub("_", " ") end
				if hero.isControlled then
					UIClient.HUDTargets.health = (hero.health or 0) / math.max(1, hero.maxHealth or 1)
					UIClient.HUDTargets.shield = (hero.shieldHealth or 0) / math.max(1, hero.maxShield or 1)
					UIClient.HUDTargets.ability = 1 - ((hero.abilityCooldownRemaining or 0) / 10)
					if UIClient.AmmoLabel then UIClient.AmmoLabel.Text = string.format("%s / %s", hero.ammo or 0, hero.reserveAmmo or 0) end
					local weapon = WeaponConfig[hero.weaponId]
					if UIClient.WeaponNameLabel then UIClient.WeaponNameLabel.Text = weapon and string.upper(weapon.displayName) or "UNKNOWN" end
				end
			end
		end
	end)

	ClientCore.Events.Scoreboard.Event:Connect(function(payload)
		UIClient.UpdateScoreboard(payload.players or {})
		UIClient.Scoreboard.Visible = true
		task.delay(5, function() if UIClient.Scoreboard then UIClient.Scoreboard.Visible = false end end)
	end)

	ClientCore.Events.BombDefuseProgress.Event:Connect(function(payload)
		local progress = tonumber(payload.progress) or -1
		UIClient.DefuseBar.Visible = progress >= 0
		UIClient.DefuseBarFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
	end)

	ClientCore.Events.Killfeed.Event:Connect(function(payload)
		if not UIClient.KillfeedContainer then return end
		local item = frame(UIClient.KillfeedContainer, "Kill", UDim2.new(1, 0, 0, 34), nil, C.BackgroundRaised, 0.08)
		corner(item, Theme.Radius.Small)
		local message = string.format("%s  >  %s", tostring(payload.killerName or "?"), tostring(payload.victimName or "?"))
		label(item, "Text", message, UDim2.new(1, -14, 1, 0), UDim2.fromOffset(7, 0), 12, C.Text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Right
		task.delay(5, function() if item.Parent then item:Destroy() end end)
	end)
end

function UIClient.BuildAuxiliaryPanels()
	UIClient.ShopFrame = frame(UIClient.HUD, "ShopFrame", UDim2.fromOffset(340, 180), UDim2.new(0.5, -170, 0.5, -90), C.BackgroundRaised, 0.02)
	UIClient.ShopFrame.Visible = false; corner(UIClient.ShopFrame, Theme.Radius.Large)
	label(UIClient.ShopFrame, "Text", "SHOP COMING AFTER COMBAT FOUNDATION", UDim2.new(1, -24, 1, -24), UDim2.fromOffset(12, 12), 14, C.TextMuted, Enum.Font.GothamBold)
	UIClient.EmoteFrame = frame(UIClient.HUD, "EmoteFrame", UDim2.fromOffset(280, 150), UDim2.new(0.5, -140, 0.7, -75), C.BackgroundRaised, 0.02)
	UIClient.EmoteFrame.Visible = false; corner(UIClient.EmoteFrame, Theme.Radius.Large)
	label(UIClient.EmoteFrame, "Text", "EMOTES", UDim2.fromScale(1, 1), nil, 18, C.Text, Enum.Font.GothamBlack)
	UIClient.PracticeFrame = frame(UIClient.HUD, "PracticeFrame", UDim2.fromOffset(300, 170), UDim2.new(0.5, -150, 0.5, -85), C.BackgroundRaised, 0.02)
	UIClient.PracticeFrame.Visible = false; corner(UIClient.PracticeFrame, Theme.Radius.Large)
	label(UIClient.PracticeFrame, "Title", "PRACTICE TARGET", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 12), 18, C.Text, Enum.Font.GothamBlack)
	local spawn = button(UIClient.PracticeFrame, "Spawn", "SPAWN DUMMY", UDim2.new(1, -40, 0, 46), UDim2.fromOffset(20, 82), C.AccentDark)
	spawn.Activated:Connect(function() ClientCore.Fire("RequestPracticeDummy", {}) end)
end

function UIClient.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("PulseDeckArenaGui")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PulseDeckArenaGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	UIClient.Gui = gui
	UIClient.Root = frame(gui, "Root", UDim2.fromScale(1, 1), nil, C.Background, 1)
	makeScreen("MainMenu")
	makeScreen("DeckSelect")
	makeScreen("HUD")
	makeScreen("Scoreboard")
	makeScreen("PostMatch")
	UIClient.SelectedDeck = table.clone(ClientCore.State.selectedDeck or Config.DEFAULT_DECK)
	UIClient.BuildMainMenu()
	UIClient.BuildDeckSelect()
	UIClient.BuildHUD()
	UIClient.BuildScoreboard()
	UIClient.BuildPostMatch()
	UIClient.BuildAuxiliaryPanels()
	UIClient.BindState()
	UIClient.Show(ClientCore.State.matchState == "DeckSelect" and "DeckSelect" or ClientCore.State.matchState == "ActiveMatch" and "HUD" or "MainMenu")
	RunService.RenderStepped:Connect(function()
		for key, target in pairs(UIClient.HUDTargets) do
			UIClient.HUDSmoothing[key] = UIClient.HUDSmoothing[key] + (math.clamp(target, 0, 1) - UIClient.HUDSmoothing[key]) * 0.14
		end
		if UIClient.HealthBarFill then UIClient.HealthBarFill.Size = UDim2.new(UIClient.HUDSmoothing.health, 0, 1, 0) end
		if UIClient.ShieldBarFill then UIClient.ShieldBarFill.Size = UDim2.new(UIClient.HUDSmoothing.shield, 0, 1, 0) end
		if UIClient.AbilityBarFill then UIClient.AbilityBarFill.Size = UDim2.new(UIClient.HUDSmoothing.ability, 0, 1, 0) end
	end)
end

return UIClient
