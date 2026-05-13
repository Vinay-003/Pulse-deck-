-- SoundManager: Centralised sound effect management for Pulse Deck Arena
-- Place Roblox Sound objects under this module and set IDs before shipping

local SoundManager = {}

SoundManager.Sounds = {
	-- Weapon fire (replace rbxassetid://0 with uploaded IDs)
	PulseRifle = "rbxassetid://0",
	Shotgun = "rbxassetid://0",
	Sniper = "rbxassetid://0",
	SMG = "rbxassetid://0",
	Flamethrower = "rbxassetid://0",
	RocketLauncher = "rbxassetid://0",
	PlasmaCaster = "rbxassetid://0",
	CryoRifle = "rbxassetid://0",
	LightningGun = "rbxassetid://0",
	RailLance = "rbxassetid://0",
	EnergySword = "rbxassetid://0",
	GravityHammer = "rbxassetid://0",
	VortexRifle = "rbxassetid://0",
	ClusterMortar = "rbxassetid://0",
	ThermalGrenade = "rbxassetid://0",
	ArcLauncher = "rbxassetid://0",
	RivetCarbine = "rbxassetid://0",
	IonBeam = "rbxassetid://0",
	PhaseSMG = "rbxassetid://0",
	NanoSMG = "rbxassetid://0",
	BioRifle = "rbxassetid://0",

	-- Abilities
	PhaseDash = "rbxassetid://0",
	ShieldDome = "rbxassetid://0",
	HealPulse = "rbxassetid://0",
	TrackerMark = "rbxassetid://0",
	ClusterCharge = "rbxassetid://0",
	SlowField = "rbxassetid://0",
	GravityWell = "rbxassetid://0",
	Blizzard = "rbxassetid://0",
	FireNova = "rbxassetid://0",
	Supernova = "rbxassetid://0",
	Berserk = "rbxassetid://0",
	CloakAndDagger = "rbxassetid://0",
	PhoenixDive = "rbxassetid://0",
	EMPBlast = "rbxassetid://0",
	SmokeScreen = "rbxassetid://0",
	SmartMine = "rbxassetid://0",
	Adrenaline = "rbxassetid://0",
	TimeDilation = "rbxassetid://0",
	Fortify = "rbxassetid://0",
	Overcharge = "rbxassetid://0",

	-- Impacts / hits
	ImpactFlesh = "rbxassetid://0",
	ImpactShield = "rbxassetid://0",
	ImpactArmor = "rbxassetid://0",
	ExplosionSmall = "rbxassetid://0",
	ExplosionLarge = "rbxassetid://0",
	Headshot = "rbxassetid://0",
	MeleeSwing = "rbxassetid://0",
	MeleeHit = "rbxassetid://0",

	-- Pickups & environment
	PickupHealth = "rbxassetid://0",
	PickupAmmo = "rbxassetid://0",
	PickupEnergy = "rbxassetid://0",
	PickupArmor = "rbxassetid://0",
	PowerUpActivate = "rbxassetid://0",
	JumpPad = "rbxassetid://0",
	FlagCapture = "rbxassetid://0",
	KOTHBeacon = "rbxassetid://0",
	WindAmbience = "rbxassetid://0",
	NeonHum = "rbxassetid://0",
	BombPlant = "rbxassetid://0",
	BombBeep = "rbxassetid://0",
	BombDefuse = "rbxassetid://0",
	BombExplosion = "rbxassetid://0",
	RoundStart = "rbxassetid://0",
	RoundEnd = "rbxassetid://0",
	BuyPhaseStart = "rbxassetid://0",

	-- UI
	MenuSelect = "rbxassetid://0",
	MenuConfirm = "rbxassetid://0",
	MenuCancel = "rbxassetid://0",
	MenuHover = "rbxassetid://0",
	KillSound = "rbxassetid://0",
	KillStreak = "rbxassetid://0",
	KillStreakEnd = "rbxassetid://0",
	MatchStart = "rbxassetid://0",
	MatchEnd = "rbxassetid://0",
	AbilityReady = "rbxassetid://0",
	UltimateReady = "rbxassetid://0",
	Pickup = "rbxassetid://0",
}

function SoundManager.PlaySFX(soundName, position, volume)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	local remotes = root and root:FindFirstChild("Remotes")
	if not remotes then return end
	local sfxEvent = remotes:FindFirstChild("PlaySFX")
	if not sfxEvent or not sfxEvent:IsA("RemoteEvent") then return end
	sfxEvent:FireAllClients({
		soundName = soundName,
		position = position,
		volume = volume or 1,
	})
end

function SoundManager.PlayUISound(soundName)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = game:GetService("Players").LocalPlayer
	if not player then return end
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	local remotes = root and root:FindFirstChild("Remotes")
	if not remotes then return end
	local sfxEvent = remotes:FindFirstChild("PlaySFX")
	if not sfxEvent or not sfxEvent:IsA("RemoteEvent") then return end
	sfxEvent:FireClient(player, {
		soundName = soundName,
		uiOnly = true,
		volume = 0.7,
	})
end

return SoundManager
