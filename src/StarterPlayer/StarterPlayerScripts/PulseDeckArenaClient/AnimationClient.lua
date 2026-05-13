local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationClient = {}

local ANIM = {
	IDLE = "Idle", WALK = "Walk", RUN = "Run", JUMP = "Jump",
	DEATH = "Death", SHOOT = "Shoot", MELEE = "Melee", RELOAD = "Reload",
}

local function getJoint(model, name)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return nil end
	if name == "RootJoint" then return root:FindFirstChild("RootJoint") end
	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
	if not torso then return nil end
	return torso:FindFirstChild(name)
end

local function animateJoint(hero, jointName, goalC0, duration, revert)
	local model = hero.Model
	if not model then return end
	local joint = getJoint(model, jointName)
	if not joint then return end
	local origC0 = joint.C0
	local tween = TweenService:Create(joint, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = goalC0})
	tween:Play()
	if revert then
		tween.Completed:Wait()
		task.spawn(function()
			local rev = TweenService:Create(joint, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {C0 = origC0})
			rev:Play()
		end)
	end
end

function AnimationClient.PlayAnimation(hero, animName)
	local model = hero.Model
	if not model then return end

	if animName == ANIM.SHOOT then
		local arm = model:FindFirstChild("Right Arm")
		if arm then
			local shoulder = getJoint(model, "RightShoulder")
			if shoulder then
				local origC0 = shoulder.C0
				shoulder.C0 = origC0 * CFrame.Angles(math.rad(-25), 0, 0)
				task.delay(0.08, function()
					if shoulder then shoulder.C0 = origC0 end
				end)
			end
		end
	elseif animName == ANIM.MELEE then
		local arm = model:FindFirstChild("Right Arm")
		if arm then
			local shoulder = getJoint(model, "RightShoulder")
			if shoulder then
				local origC0 = shoulder.C0
				shoulder.C0 = origC0 * CFrame.Angles(math.rad(-45), 0, math.rad(30))
				task.delay(0.15, function()
					if shoulder then shoulder.C0 = origC0 end
				end)
			end
		end
		local torso = model:FindFirstChild("Torso")
		if torso then
			local rootJ = getJoint(model, "RootJoint")
			if rootJ then
				local origC0 = rootJ.C0
				rootJ.C0 = origC0 * CFrame.Angles(0, 0, math.rad(-15))
				task.delay(0.2, function()
					if rootJ then rootJ.C0 = origC0 end
				end)
			end
		end
	elseif animName == ANIM.RELOAD then
		local arm = model:FindFirstChild("Right Arm")
		if arm then
			local shoulder = getJoint(model, "RightShoulder")
			if shoulder then
				local origC0 = shoulder.C0
				shoulder.C0 = origC0 * CFrame.Angles(math.rad(35), 0, math.rad(-15))
				task.delay(1.2, function()
					if shoulder then shoulder.C0 = origC0 end
				end)
			end
		end
		local weapon = model:FindFirstChild("Weapon")
		if weapon then
			local weld = weapon:FindFirstChild("WeaponWeld")
			if weld then
				local origC0 = weld.C0
				weld.C0 = origC0 * CFrame.Angles(math.rad(30), 0, 0)
				task.delay(1.0, function()
					if weld then weld.C0 = origC0 end
				end)
			end
		end
	elseif animName == ANIM.JUMP then
		for _, legName in ipairs({"Right Leg", "Left Leg"}) do
			local leg = model:FindFirstChild(legName)
			if leg then
				local hip = getJoint(model, legName:gsub("Leg", "Hip"))
				if hip then
					local origC0 = hip.C0
					hip.C0 = origC0 * CFrame.Angles(math.rad(-15), 0, 0)
					task.delay(0.4, function()
						if hip then hip.C0 = origC0 end
					end)
				end
			end
		end
	elseif animName == ANIM.DEATH then
		for _, joint in ipairs(model:GetDescendants()) do
			if joint:IsA("Motor6D") then
				joint.Part1 = nil
			end
		end
	end
end

function AnimationClient.ApplyMovementAnimation(hero, dt)
	local model = hero.Model
	if not model then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid:GetState() == Enum.HumanoidStateType.Dead then return end
	local torso = model:FindFirstChild("Torso")
	if not torso then return end

	local moveDir = humanoid.MoveDirection
	local isMoving = moveDir.Magnitude > 0.1
	if not isMoving then return end

	local time = tick()
	local bobHeight = math.sin(time * 10) * 0.06
	local bobSway = math.sin(time * 5) * 0.02
	torso.CFrame = torso.CFrame * CFrame.new(bobSway, bobHeight, 0)
end

function AnimationClient.UpdateAnimationState(hero)
	local model = hero.Model
	if not model then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local moveDir = humanoid.MoveDirection
	local isMoving = moveDir.Magnitude > 0.1
	local state = humanoid:GetState()
	local lastState = model:GetAttribute("AnimState") or ANIM.IDLE

	local newState = ANIM.IDLE
	if not hero.Alive then
		newState = ANIM.DEATH
	elseif state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		newState = ANIM.JUMP
	elseif isMoving then
		newState = moveDir.Magnitude > 20 and ANIM.RUN or ANIM.WALK
	end

	if newState ~= lastState then
		model:SetAttribute("AnimState", newState)
		if newState ~= ANIM.IDLE and newState ~= ANIM.WALK and newState ~= ANIM.RUN then
			AnimationClient.PlayAnimation(hero, newState)
		end
	end
end

return AnimationClient
