-- SoundManager: Centralised sound effect management for Pulse Deck Arena
-- Place Roblox Sound objects under this module and set IDs before shipping

local SoundManager = {}

SoundManager.Sounds = {
	-- Weapon fire (free Roblox library)
	PulseRifle      = "rbxassetid://4612625985",
	Shotgun         = "rbxassetid://5801257793",
	Sniper          = "rbxassetid://2697423085",
	SMG             = "rbxassetid://4612625985",
	Flamethrower    = "rbxassetid://3035356355",
	RocketLauncher  = "rbxassetid://3935339891",
	PlasmaCaster    = "rbxassetid://4612625985",
	CryoRifle       = "rbxassetid://2697423085",
	LightningGun    = "rbxassetid://5801257793",
	RailLance       = "rbxassetid://2697423085",
	EnergySword     = "rbxassetid://3035356355",
	GravityHammer   = "rbxassetid://3935339891",
	VortexRifle     = "rbxassetid://4612625985",
	ClusterMortar   = "rbxassetid://3935339891",
	ThermalGrenade  = "rbxassetid://3935339891",
	ArcLauncher     = "rbxassetid://4612625985",
	RivetCarbine    = "rbxassetid://4612625985",
	IonBeam         = "rbxassetid://5801257793",
	PhaseSMG        = "rbxassetid://4612625985",
	NanoSMG         = "rbxassetid://4612625985",
	BioRifle        = "rbxassetid://3035356355",

	-- Abilities
	PhaseDash       = "rbxassetid://3035356355",
	ShieldDome      = "rbxassetid://4612625985",
	HealPulse       = "rbxassetid://5801257793",
	TrackerMark     = "rbxassetid://2697423085",
	ClusterCharge   = "rbxassetid://3935339891",
	SlowField       = "rbxassetid://3035356355",
	GravityWell     = "rbxassetid://3935339891",
	Blizzard        = "rbxassetid://3035356355",
	FireNova        = "rbxassetid://3035356355",
	Supernova       = "rbxassetid://3935339891",
	Berserk         = "rbxassetid://2697423085",
	CloakAndDagger  = "rbxassetid://3035356355",
	PhoenixDive     = "rbxassetid://3935339891",
	EMPBlast        = "rbxassetid://5801257793",
	SmokeScreen     = "rbxassetid://3035356355",
	SmartMine       = "rbxassetid://5801257793",
	Adrenaline      = "rbxassetid://2697423085",
	TimeDilation    = "rbxassetid://5801257793",
	Fortify         = "rbxassetid://4612625985",
	Overcharge      = "rbxassetid://2697423085",

	-- Impacts / hits
	ImpactFlesh     = "rbxassetid://5801257793",
	ImpactShield    = "rbxassetid://4612625985",
	ImpactArmor     = "rbxassetid://4612625985",
	ExplosionSmall  = "rbxassetid://3935339891",
	ExplosionLarge  = "rbxassetid://3935339891",
	Headshot        = "rbxassetid://2697423085",
	MeleeSwing      = "rbxassetid://3035356355",
	MeleeHit        = "rbxassetid://5801257793",

	-- Pickups & environment
	PickupHealth    = "rbxassetid://4612625985",
	PickupAmmo      = "rbxassetid://5801257793",
	PickupEnergy    = "rbxassetid://4612625985",
	PickupArmor     = "rbxassetid://4612625985",
	PowerUpActivate = "rbxassetid://2697423085",
	JumpPad         = "rbxassetid://3035356355",
	FlagCapture     = "rbxassetid://2697423085",
	KOTHBeacon      = "rbxassetid://4612625985",
	WindAmbience    = "rbxassetid://3035356355",
	NeonHum         = "rbxassetid://4612625985",
	BombPlant       = "rbxassetid://5801257793",
	BombBeep        = "rbxassetid://5801257793",
	BombDefuse      = "rbxassetid://4612625985",
	BombExplosion   = "rbxassetid://3935339891",
	RoundStart      = "rbxassetid://2697423085",
	RoundEnd        = "rbxassetid://2697423085",
	BuyPhaseStart   = "rbxassetid://4612625985",

	-- UI
	MenuSelect      = "rbxassetid://4612625985",
	MenuConfirm     = "rbxassetid://4612625985",
	MenuCancel      = "rbxassetid://5801257793",
	MenuHover       = "rbxassetid://5801257793",
	KillSound       = "rbxassetid://2697423085",
	KillStreak      = "rbxassetid://2697423085",
	KillStreakEnd   = "rbxassetid://5801257793",
	MatchStart      = "rbxassetid://2697423085",
	MatchEnd        = "rbxassetid://2697423085",
	AbilityReady    = "rbxassetid://4612625985",
	UltimateReady   = "rbxassetid://2697423085",
	Pickup          = "rbxassetid://4612625985",
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

function SoundManager.PlayBGM(soundId, volume)
	local sound = workspace:FindFirstChild("PDA_BGM")
	if sound then sound:Destroy() end

	local bgm = Instance.new("Sound")
	bgm.Name = "PDA_BGM"
	bgm.SoundId = soundId or "rbxassetid://1843444168" -- Free ambient music
	bgm.Volume = volume or 0.3
	bgm.Looped = true
	bgm.Parent = workspace
	bgm:Play()
	return bgm
end

function SoundManager.StopBGM()
	local bgm = workspace:FindFirstChild("PDA_BGM")
	if bgm then bgm:Destroy() end
end

return SoundManager
