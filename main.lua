-- This is a local script for Aladia PvP that adds an aim-lock feature
-- and a GUI button to toggle it on and off.
-- It should be placed in StarterPlayer > StarterPlayerScripts.

--=================================================================================--
-- SERVICES AND VARIABLES
--=================================================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera

local isAimLockEnabled = false
local isRightMouseButtonDown = false
local currentTarget = nil
local maxDistance = 150 -- Maximum distance in studs to lock onto a player
local highlightInstance = nil
local cameraSmoothness = 0.3 -- Higher value = faster camera lock

--=================================================================================--
-- GUI SETUP
--=================================================================================--

-- Destroy any existing GUI to prevent duplication on respawn
if LocalPlayer.PlayerGui:FindFirstChild("AimLockGui") then
	LocalPlayer.PlayerGui.AimLockGui:Destroy()
end

-- Create the main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockGui"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Create the toggle button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 150, 0, 40)
toggleButton.Position = UDim2.new(0.5, -75, 0.9, 0) -- Centered at the bottom
toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 18
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
toggleButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
toggleButton.Text = "Aim Lock: OFF"
toggleButton.Parent = screenGui

-- Add a UICorner for a rounded look
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = toggleButton

-- Update the button's appearance based on the aim lock state
local function updateButtonState()
	if isAimLockEnabled then
		toggleButton.Text = "Aim Lock: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50) -- Green
	else
		toggleButton.Text = "Aim Lock: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
	end
end

--=================================================================================--
-- HIGHLIGHTING LOGIC
--=================================================================================--

local function createHighlight(instanceToHighlight)
	if highlightInstance then
		highlightInstance:Destroy()
	end
	
	highlightInstance = Instance.new("Highlight")
	highlightInstance.Name = "AimLockHighlight"
	highlightInstance.FillColor = Color3.fromRGB(0, 255, 255)
	highlightInstance.OutlineColor = Color3.fromRGB(0, 0, 0)
	highlightInstance.FillTransparency = 1 -- Fully transparent fill
	highlightInstance.OutlineTransparency = 0 -- Fully opaque outline
	highlightInstance.Adornee = instanceToHighlight
	highlightInstance.Parent = instanceToHighlight.Parent -- Highlight must be parented to the model
end

local function removeHighlight()
	if highlightInstance then
		highlightInstance:Destroy()
		highlightInstance = nil
	end
end

--=================================================================================--
-- AIM-LOCK LOGIC
--=================================================================================--

local function getClosestValidTarget()
	local closestTarget = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		-- Skip if the player is the local player or on the same team
		if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team then
			local targetCharacter = player.Character
			if targetCharacter then
				-- Prioritize Head, then UpperTorso, then any other Torso-like part
				local targetPart = targetCharacter:FindFirstChild("Head") or targetCharacter:FindFirstChild("UpperTorso") or targetCharacter:FindFirstChild("LowerTorso") or targetCharacter:FindFirstChild("Torso")
				
				if targetPart then
					local distance = (HumanoidRootPart.Position - targetPart.Position).Magnitude
					
					-- Check if the player is within range and is the closest so far
					if distance < maxDistance and distance < closestDistance then
						closestTarget = targetPart
						closestDistance = distance
					end
				end
			end
		end
	end
	
	return closestTarget
end

local function updateAimLock()
	-- Find the closest valid target
	currentTarget = getClosestValidTarget()
	
	-- Validate that the target still exists and is not dead
	if currentTarget and (not currentTarget.Parent or not currentTarget.Parent:FindFirstChild("Humanoid") or currentTarget.Parent:FindFirstChild("Humanoid").Health <= 0) then
		currentTarget = nil
		removeHighlight()
	end
	
	if currentTarget then
		-- Update the highlight to the current target
		if highlightInstance and highlightInstance.Adornee ~= currentTarget then
			createHighlight(currentTarget)
		elseif not highlightInstance then
			createHighlight(currentTarget)
		end
		
		-- Smoothly turn the camera to face the target
		local lookAtCFrame = CFrame.lookAt(Camera.CFrame.Position, currentTarget.Position)
		Camera.CFrame = Camera.CFrame:lerp(lookAtCFrame, cameraSmoothness)
	else
		-- No valid target found, remove the highlight
		removeHighlight()
	end
end

--=================================================================================--
-- CONNECTIONS
--=================================================================================--

-- Re-assign the Character and HumanoidRootPart when the player respawns
LocalPlayer.CharacterAdded:Connect(function(newChar)
	Character = newChar
	HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Toggle the aim lock when the button is clicked
toggleButton.MouseButton1Click:Connect(function()
	isAimLockEnabled = not isAimLockEnabled
	updateButtonState()
	
	if not isAimLockEnabled then
		-- When aim lock is disabled, remove any existing highlights
		removeHighlight()
	end
end)

-- Track the right mouse button state
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessedEvent then
		isRightMouseButtonDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessedEvent then
		isRightMouseButtonDown = false
		-- Remove the highlight and stop aiming when right click is released
		removeHighlight()
	end
end)

-- Main loop for aim-lock logic, now only runs when enabled and active
RunService.Heartbeat:Connect(function()
	if isAimLockEnabled and isRightMouseButtonDown then
		updateAimLock()
	end
end)

-- Handle player and character removal
Players.PlayerRemoving:Connect(function(player)
	-- Check if the player being removed is the current target's owner
	if currentTarget and player.Character and currentTarget:IsDescendantOf(player.Character) then
		currentTarget = nil
		removeHighlight()
	end
end)

Character.Humanoid.Died:Connect(function()
	currentTarget = nil
	removeHighlight()
end)

-- Initial state update
updateButtonState()
