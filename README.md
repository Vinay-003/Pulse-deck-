# PULSE DECK ARENA v2

Hero-deck arena shooter for Roblox — 20 heroes, 38 weapons, 36 abilities, 3 game modes (Standard/FFA/KOTH/CTF), AI bots, progression, and cosmetics. Built entirely in code as a Rojo project (no Studio building).

## What You Need to Install

1. **Roblox Studio** — https://create.roblox.com/landing
2. **Rojo** — https://rojo.space
   - On Windows: download the `.exe` from GitHub releases
   - On macOS/Linux: `cargo install rojo` (requires Rust) or download the binary
   - Alternatively use **foreman**: `foreman install rojo-rbx/rojo`

## How to Test

```bash
# Terminal 1: start Rojo sync server
rojo serve
```

In Roblox Studio:
1. File → New → **Baseplate** (discard everything)
2. **Rojo** tab → click **Connect**
3. The project syncs into Studio automatically
4. Press **Play**

The map generates on first run. Click **PLAY** on the menu, confirm your 5-hero deck, and bots spawn automatically if solo.

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Aim |
| LMB | Fire |
| R | Reload |
| Q | Ability |
| E | Ultimate |
| F | Hero Power |
| 1-5 | Switch hero |
| V | Toggle camera |
| Tab | Scoreboard |
| P | Pause |

## Admin Commands (chat, Studio-only)

| Command | Effect |
|---------|--------|
| `/pda_start` | Start match immediately |
| `/pda_bots` | Fill enemy team with AI bots |
| `/pda_reset` | Full match reset |
| `/pda_winred` | End match, red wins |
| `/pda_winblue` | End match, blue wins |
| `/pda_mode ffa` | Switch to FFA mode |
| `/pda_mode koth` | Switch to KOTH mode |
| `/pda_mode ctf` | Switch to CTF mode |
| `/pda_mode standard` | Switch to Standard mode |
| `/pda_givexp` | +1000 XP |
| `/pda_givecoins` | +1000 coins |

## Project Stats

- 22 Lua files, ~14,600+ lines
- 20 heroes with unique stats, skins, and AI profiles
- 38 weapons across 15+ behavior types, WEAPON_PRICES economy table
- 36 abilities across 7 kinds
- 5 game modes: Standard, FFA, KOTH, CTF, **Bomb Defuse**
- **Bomb Defuse mode**: 15-round CT vs T, plant/defuse mechanics, buy zones, team swap at round 8
- **Economy System**: per-round money tracking, buy menu with 22 weapon prices, kill/plant/defuse/win rewards
- **Lobby + Matchmaking**: ready-up system, auto-start when all ready, U key to toggle
- **Kill Cam + Spectate**: auto-spectate on death, G to cycle targets, H toggle FP/TP, Y enter/exit spectate, free fly when no targets
- **Battle Pass**: 50 tiers with XP requirements, free + premium rewards, shop with 6 categories
- **Shop**: skin bundles, coin packs, hero unlocks with purchasable items
- **Emotes**: T key to open emote wheel (8 reactions), expandable
- **Practice Range**: M key to open, spawn practice dummies to test weapons
- **Hero Powers**: F key to activate hero-specific powers (speed boost, damage resistance, team heal, energy drain, ground slam, blast wave)
- Full progression system with skins, achievements, leaderstats
- Part-based rigs with skin system (helmet, visor, cape, shoulder armor, emissive glow)
- All effects and animations are procedural (no uploaded assets needed)

## File Structure

```
src/
├── ReplicatedStorage/PulseDeckArena/Shared/
│   ├── Config.lua          — game constants, map data, presets
│   ├── HeroConfig.lua      — 20 hero definitions
│   ├── WeaponConfig.lua    — 38 weapon definitions
│   ├── AbilityConfig.lua   — 36 ability definitions
│   ├── Util.lua            — shared helpers
│   ├── SoundManager.lua    — sound ID registry (+ expanded)
│   └── ProgressionUtils.lua
├── ServerScriptService/PulseDeckArenaServer/
│   ├── Main.server.lua     — remotes, game loop, admin commands
│   ├── HeroSystem.lua      — spawn, rig builder, skin system
│   ├── CombatSystem.lua    — weapons, projectiles, damage, pickups
│   ├── AbilitySystem.lua   — 36 ability handlers
│   ├── MatchSystem.lua     — match lifecycle, KOTH, CTF
│   ├── AISystem.lua        — pathfinding, profiles, difficulty (+ expanded)
│   ├── MapBuilder.lua      — arena generator
│   └── ProgressionSystem.lua
└── StarterPlayer/StarterPlayerScripts/PulseDeckArenaClient/
    ├── Main.client.lua     — client init
    ├── ClientCore.lua      — state, remotes, events
    ├── UIClient.lua        — full UI (+ animated, HUD lerp)
    ├── CombatClient.lua    — damage numbers, effects, tracers
    ├── EffectsClient.lua   — 15+ VFX types + 15 kill effects
    ├── InputClient.lua     — keyboard + mobile (+ power key)
    ├── CameraClient.lua    — TPS camera, bloom, DoF
    └── AnimationClient.lua — procedural Part animation
```

## Notes

- No custom meshes or uploaded assets required — everything is Part-based
- Sound IDs need real Roblox asset IDs before shipping (currently `rbxassetid://0`)
- Map generated entirely by code — Neon Foundry with walkways, sniper platforms, jump pads
- DataStore progression falls back to in-memory if unavailable

You need two things:

Roblox Studio — https://create.roblox.com/landing
Rojo — https://github.com/rojo-rbx/rojo/releases (grab the binary for your OS)
Then open a terminal in this directory, run rojo serve, open Roblox Studio → new Baseplate → Rojo tab → Connect → Play.


Then in Roblox Studio:

New Baseplate project
Install the Rojo plugin (if you don't have it)
Click Connect in the Rojo plugin tab
Hit Play in Studio
The map generates automatically. Click PLAY MATCH -> confirm deck -> bots spawn on blue team. Solo testing works because bots auto-fill after a few seconds.

Admin chat commands in Studio: /pda_start, /pda_bots, /pda_winred, /pda_mode ff a, etc.