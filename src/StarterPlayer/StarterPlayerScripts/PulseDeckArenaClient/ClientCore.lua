local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientCore = {}

ClientCore.Remotes = {}
ClientCore.State = {
	matchState = "Lobby",
	timerRemaining = 0,
	teamId = nil,
	gameMode = "Standard",
	roundPhase = "Buy",
	bombState = "None",
	bombTimer = 0,
	bombSite = nil,
	defusingProgress = 0,
	isDefusing = false,
	roundNumber = 0,
	roundScore = {Red = 0, Blue = 0},
	hasBomb = false,
	heroes = {},
	objectives = {},
	score = {Red = 0, Blue = 0},
	selectedDeck = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"},
	progression = {Wins = 0, Coins = 0, XP = 0, Level = 1, EquippedSkin = "default", UnlockedHeroes = {}},
	killfeed = {},
	matchResults = nil,
}

ClientCore.Events = {
	MatchStateChanged = Instance.new("BindableEvent"),
	HeroStateChanged = Instance.new("BindableEvent"),
	ObjectiveStateChanged = Instance.new("BindableEvent"),
	ScoreChanged = Instance.new("BindableEvent"),
	DamageNumber = Instance.new("BindableEvent"),
	Effects = Instance.new("BindableEvent"),
	Killfeed = Instance.new("BindableEvent"),
	BuyMenuResponse = Instance.new("BindableEvent"),
	BombDefuseProgress = Instance.new("BindableEvent"),
	Scoreboard = Instance.new("BindableEvent"),
}

function ClientCore.Init()
	local remotes = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Remotes")
	ClientCore.Remotes = {
		ClientReady = remotes:WaitForChild("ClientReady"),
		RequestJoinQueue = remotes:WaitForChild("RequestJoinQueue"),
		RequestDeckUpdate = remotes:WaitForChild("RequestDeckUpdate"),
		RequestSwitchHero = remotes:WaitForChild("RequestSwitchHero"),
		RequestStartMatch = remotes:WaitForChild("RequestStartMatch"),
		RequestFire = remotes:WaitForChild("RequestFire"),
		RequestReload = remotes:WaitForChild("RequestReload"),
		RequestAbility = remotes:WaitForChild("RequestAbility"),
		RequestCameraMode = remotes:WaitForChild("RequestCameraMode"),
		RequestScoreboard = remotes:WaitForChild("RequestScoreboard"),
		RequestUltimate = remotes:WaitForChild("RequestUltimate"),
		RequestPower = remotes:WaitForChild("RequestPower"),
		RequestReady = remotes:WaitForChild("RequestReady"),
		RequestGameMode = remotes:WaitForChild("RequestGameMode"),
		RequestPurchase = remotes:WaitForChild("RequestPurchase"),
		RequestPracticeDummy = remotes:WaitForChild("RequestPracticeDummy"),
		RequestBuy = remotes:WaitForChild("RequestBuy"),
		RequestBuyMenu = remotes:WaitForChild("RequestBuyMenu"),
		RequestPlant = remotes:WaitForChild("RequestPlant"),
		RequestDefuse = remotes:WaitForChild("RequestDefuse"),
		CancelDefuse = remotes:WaitForChild("CancelDefuse"),
		BombDefuseProgress = remotes:WaitForChild("BombDefuseProgress"),
		MatchStateChanged = remotes:WaitForChild("MatchStateChanged"),
		HeroStateSnapshot = remotes:WaitForChild("HeroStateSnapshot"),
		ObjectiveStateChanged = remotes:WaitForChild("ObjectiveStateChanged"),
		ScoreChanged = remotes:WaitForChild("ScoreChanged"),
		DamageNumberEvent = remotes:WaitForChild("DamageNumberEvent"),
		EffectsEvent = remotes:WaitForChild("EffectsEvent"),
		KillfeedEvent = remotes:WaitForChild("KillfeedEvent"),
		GetInitialState = remotes:WaitForChild("GetInitialState"),
	}

	local initial = ClientCore.Remotes.GetInitialState:InvokeServer()
	if type(initial) == "table" then
		ClientCore.State.matchState = initial.matchState or "Lobby"
		ClientCore.State.timerRemaining = initial.timerRemaining or 0
		ClientCore.State.teamId = initial.teamId
		ClientCore.State.gameMode = initial.gameMode or "Standard"
		ClientCore.State.roundNumber = initial.roundNumber or 0
		ClientCore.State.roundPhase = initial.roundPhase or "Buy"
		ClientCore.State.bombState = initial.bombState or "None"
		ClientCore.State.bombTimer = initial.bombTimer or 0
		ClientCore.State.roundScore = initial.roundScore or {Red = 0, Blue = 0}
		ClientCore.State.hasBomb = initial.hasBomb == true
		ClientCore.State.selectedDeck = initial.selectedDeck or ClientCore.State.selectedDeck
		ClientCore.State.score = initial.score or ClientCore.State.score
		ClientCore.State.progression = initial.progression or ClientCore.State.progression
	end

	ClientCore.Remotes.MatchStateChanged.OnClientEvent:Connect(function(payload)
		ClientCore.State.matchState = payload.state or ClientCore.State.matchState
		ClientCore.State.timerRemaining = payload.timerRemaining or ClientCore.State.timerRemaining
		if payload.teamId ~= nil then ClientCore.State.teamId = payload.teamId end
		ClientCore.State.gameMode = payload.gameMode or ClientCore.State.gameMode
		ClientCore.State.roundNumber = payload.roundNumber or ClientCore.State.roundNumber
		ClientCore.State.roundPhase = payload.roundPhase or ClientCore.State.roundPhase
		ClientCore.State.bombState = payload.bombState or ClientCore.State.bombState
		ClientCore.State.bombTimer = payload.bombTimer or ClientCore.State.bombTimer
		ClientCore.State.roundScore = payload.roundScore or ClientCore.State.roundScore
		if payload.hasBomb ~= nil then ClientCore.State.hasBomb = payload.hasBomb == true end
		ClientCore.Events.MatchStateChanged:Fire(payload)
	end)

	ClientCore.Remotes.HeroStateSnapshot.OnClientEvent:Connect(function(payload)
		ClientCore.State.heroes = payload.heroes or {}
		ClientCore.Events.HeroStateChanged:Fire(payload)

		local ok, CameraClient = pcall(function()
			return require(script.Parent:WaitForChild("CameraClient"))
		end)
		if ok and CameraClient and CameraClient.EnterSpectate then
			local localUserId = game:GetService("Players").LocalPlayer.UserId
			for _, hero in pairs(payload.heroes or {}) do
				if hero.ownerUserId == localUserId and not hero.alive and hero.isControlled == false then
					CameraClient.EnterSpectate()
				elseif hero.ownerUserId == localUserId and hero.alive and hero.isControlled then
					CameraClient.ExitSpectate()
				end
			end
		end
	end)

	ClientCore.Remotes.ObjectiveStateChanged.OnClientEvent:Connect(function(payload)
		ClientCore.State.objectives = payload.objectives or {}
		ClientCore.Events.ObjectiveStateChanged:Fire(payload)
	end)

	ClientCore.Remotes.ScoreChanged.OnClientEvent:Connect(function(payload)
		ClientCore.State.score = payload
		ClientCore.Events.ScoreChanged:Fire(payload)
	end)

	ClientCore.Remotes.DamageNumberEvent.OnClientEvent:Connect(function(payload)
		ClientCore.Events.DamageNumber:Fire(payload)
	end)

	ClientCore.Remotes.EffectsEvent.OnClientEvent:Connect(function(payload)
		ClientCore.Events.Effects:Fire(payload)
	end)

	ClientCore.Remotes.KillfeedEvent.OnClientEvent:Connect(function(payload)
		ClientCore.Events.Killfeed:Fire(payload)
	end)

	ClientCore.Remotes.RequestBuyMenu.OnClientEvent:Connect(function(payload)
		ClientCore.Events.BuyMenuResponse:Fire(payload)
	end)

	ClientCore.Remotes.RequestScoreboard.OnClientEvent:Connect(function(payload)
		ClientCore.Events.Scoreboard:Fire(payload)
	end)

	ClientCore.Remotes.BombDefuseProgress.OnClientEvent:Connect(function(payload)
		local progress = tonumber(payload.progress) or -1
		ClientCore.State.defusingProgress = math.max(0, progress)
		ClientCore.State.isDefusing = progress >= 0
		ClientCore.Events.BombDefuseProgress:Fire(payload)
	end)

	ClientCore.Fire("ClientReady", {})
end

function ClientCore.Fire(remoteName, payload)
	local remote = ClientCore.Remotes[remoteName]
	if remote then
		remote:FireServer(payload)
	end
end

return ClientCore
