--!strict

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))
local InputClient = require(script.Parent:WaitForChild("InputClient"))
local CombatClient = require(script.Parent:WaitForChild("CombatClient"))

-- Initialize in correct dependency order:
-- 1. ClientCore first (sets up remotes and state)
-- 2. UIClient second (builds UI, binds to ClientCore events)
-- 3. CameraClient (sets up camera, no dependencies on combat/UI state)
-- 4. InputClient (references UIClient.ShowPauseMenu and CameraClient)
-- 5. CombatClient last (references UIClient for killfeed/announcements)
ClientCore.Init()
UIClient.Init()
CameraClient.Init()
InputClient.Init()
CombatClient.Init()

print("PULSE DECK ARENA v2 client ready - All systems operational")