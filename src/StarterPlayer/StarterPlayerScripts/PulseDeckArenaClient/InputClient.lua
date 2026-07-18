local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))
local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))
local Theme = require(script.Parent:WaitForChild("UITheme"))

local InputClient = {}

local firing = false
local lastFireSent = 0
local ultimateRequested = 0

local function sendFire()
	local camera = workspace.CurrentCamera
	if not camera then return end
	ClientCore.Fire("RequestFire", {
		origin = camera.CFrame.Position,
		direction = camera.CFrame.LookVector,
		clientTime = os.clock(),
	})
end

local function isChatFocused()
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function makeMobileButton(parent, name, text, size, position, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.TextColor3 = Theme.Colors.Text
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 13
	button.TextWrapped = true
	button.ZIndex = 40
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Border
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.Parent = button

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			button.BackgroundTransparency = 0
			stroke.Color = Theme.Colors.AccentBright
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			button.BackgroundTransparency = 0.12
			stroke.Color = Theme.Colors.Border
		end
	end)

	return button
end

local function buildMobileControls()
	if not UserInputService.TouchEnabled then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("PulseDeckArenaGui")
	local root = gui:WaitForChild("Root")
	local hud = root:WaitForChild("HUD")

	local controls = Instance.new("Frame")
	controls.Name = "MobileControls"
	controls.Size = UDim2.fromScale(1, 1)
	controls.BackgroundTransparency = 1
	controls.ZIndex = 39
	controls.Parent = hud

	local fireButton = makeMobileButton(controls, "Fire", "FIRE", UDim2.fromOffset(96, 78), UDim2.new(1, -70, 1, -88), Color3.fromRGB(183, 55, 70))
	fireButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
			sendFire()
		end
	end)
	fireButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then firing = false end
	end)

	local abilityButton = makeMobileButton(controls, "Ability", "ABILITY\nQ", UDim2.fromOffset(78, 68), UDim2.new(1, -166, 1, -62), Color3.fromRGB(42, 118, 174))
	abilityButton.Activated:Connect(function()
		local camera = workspace.CurrentCamera
		ClientCore.Fire("RequestAbility", {direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)})
	end)

	local ultimateButton = makeMobileButton(controls, "Ultimate", "ULT\nE", UDim2.fromOffset(78, 68), UDim2.new(1, -70, 1, -184), Color3.fromRGB(132, 62, 179))
	ultimateButton.Activated:Connect(function() ClientCore.Fire("RequestUltimate", {}) end)

	local reloadButton = makeMobileButton(controls, "Reload", "RELOAD\nR", UDim2.fromOffset(72, 60), UDim2.new(1, -156, 1, -158), Color3.fromRGB(63, 75, 106))
	reloadButton.Activated:Connect(function() ClientCore.Fire("RequestReload", {}) end)

	local cameraButton = makeMobileButton(controls, "Camera", "VIEW", UDim2.fromOffset(64, 52), UDim2.new(1, -232, 1, -126), Color3.fromRGB(38, 120, 112))
	cameraButton.Activated:Connect(function() CameraClient.ToggleMode() end)
end

function InputClient.Init()
	buildMobileControls()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or isChatFocused() then return end

		local function isAction(name)
			return SettingsClient.Bindings[name] == input.KeyCode or SettingsClient.Bindings[name] == input.UserInputType
		end

		if isAction("Fire") then
			firing = true
			sendFire()
		elseif isAction("Reload") then
			ClientCore.Fire("RequestReload", {})
		elseif isAction("Ability") then
			local camera = workspace.CurrentCamera
			ClientCore.Fire("RequestAbility", {direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)})
		elseif isAction("Ultimate") then
			if ClientCore.State.gameMode == "Bomb" then
				ClientCore.Fire("RequestPlant", {sitePosition = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new(0, 0, 0)})
			else
				local currentTime = os.clock()
				if currentTime - ultimateRequested > 1 then
					ultimateRequested = currentTime
					ClientCore.Fire("RequestUltimate", {})
				end
			end
		elseif isAction("Power") then
			ClientCore.Fire("RequestPower", {powerId = "speedBoost"})
		elseif isAction("Switch1") then
			ClientCore.Fire("RequestSwitchHero", {slot = 1})
		elseif isAction("Switch2") then
			ClientCore.Fire("RequestSwitchHero", {slot = 2})
		elseif isAction("Switch3") then
			ClientCore.Fire("RequestSwitchHero", {slot = 3})
		elseif isAction("Switch4") then
			ClientCore.Fire("RequestSwitchHero", {slot = 4})
		elseif isAction("Switch5") then
			ClientCore.Fire("RequestSwitchHero", {slot = 5})
		elseif isAction("Camera") then
			CameraClient.ToggleMode()
		elseif isAction("Scoreboard") then
			ClientCore.Fire("RequestScoreboard", {})
		elseif isAction("Pause") then
			UIClient:ShowPauseMenu()
		elseif isAction("Ready") then
			ClientCore.Fire("RequestReady", {})
		elseif isAction("SpectateNext") then
			CameraClient.FindNextSpectateTarget()
		elseif isAction("SpectateMode") then
			CameraClient.ToggleSpectateMode()
		elseif isAction("SpectateToggle") then
			if CameraClient.Spectating then CameraClient.ExitSpectate() else CameraClient.EnterSpectate() end
		elseif isAction("Emote") then
			if UIClient.EmoteFrame then UIClient.EmoteFrame.Visible = not UIClient.EmoteFrame.Visible end
		elseif isAction("Practice") then
			if UIClient.PracticeFrame then UIClient.PracticeFrame.Visible = not UIClient.PracticeFrame.Visible end
		elseif isAction("Shop") then
			if ClientCore.State.gameMode == "Bomb" then
				ClientCore.Fire("RequestBuyMenu", {})
			elseif UIClient.ShopFrame then
				UIClient.ShopFrame.Visible = not UIClient.ShopFrame.Visible
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then firing = false end
	end)

	RunService.RenderStepped:Connect(function()
		if firing and os.clock() - lastFireSent >= 0.05 then
			lastFireSent = os.clock()
			sendFire()
		end
	end)
end

return InputClient
