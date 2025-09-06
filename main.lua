--=================================================================================--
-- SERVICES AND VARIABLES
-- This script adds an aim-lock feature to a local player with a GUI to toggle it.
-- It should be placed in StarterPlayer > StarterPlayerScripts.
--=================================================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Character = localPlayer.Character
local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

local isAimLockEnabled = false
local isRightMouseButtonDown = false
local currentTarget = nil
local maxDistance = 150 -- Maximum distance in studs to lock onto a player
local highlightInstance = nil
local cameraSmoothness = 0.3 -- Higher value = faster camera lock

--=================================================================================--
-- GUI SETUP
--=================================================================================--

-- Ensure a clean slate on respawn by destroying any existing GUI.
local function setupGui()
	if localPlayer.PlayerGui:FindFirstChild("AimLockGui") then
		localPlayer.PlayerGui.AimLockGui:Destroy()
	end
	
	-- Create the main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AimLockGui"
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	
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
	
	-- Toggle the aim lock when the button is clicked
	toggleButton.MouseButton1Click:Connect(function()
		isAimLockEnabled = not isAimLockEnabled
		updateButtonState()
		
		if not isAimLockEnabled then
			-- When aim lock is disabled, remove any existing highlights
			removeHighlight()
		end
	end)
	
	-- Initial state update
	updateButtonState()

	---
	
	-- Create the credits panel
	local creditsPanel = Instance.new("Frame")
	creditsPanel.Name = "CreditsPanel"
	creditsPanel.Size = UDim2.new(0, 200, 0, 30)
	creditsPanel.Position = UDim2.new(0, 10, 1, -40) -- Position at the bottom left
	creditsPanel.AnchorPoint = Vector2.new(0, 1)
	creditsPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	creditsPanel.BackgroundTransparency = 0.5
	creditsPanel.BorderSizePixel = 0
	creditsPanel.Parent = screenGui
	
	-- Add a UICorner for a rounded look
	local creditsCorner = Instance.new("UICorner")
	creditsCorner.CornerRadius = UDim.new(0, 8)
	creditsCorner.Parent = creditsPanel
	
	-- Create the credits label
	local creditsLabel = Instance.new("TextLabel")
	creditsLabel.Name = "CreditsLabel"
	creditsLabel.Size = UDim2.new(1, 0, 1, 0)
	creditsLabel.Position = UDim2.new(0, 0, 0, 0)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Font = Enum.Font.SourceSansPro
	creditsLabel.TextSize = 16
	creditsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	creditsLabel.Text = "DEVELOPER: Sp3ctr@l"
	creditsLabel.Parent = creditsPanel
end

--=================================================================================--
-- HIGHLIGHTING LOGIC
--=================================================================================--

local function createHighlight(instanceToHighlight)
	-- Destroy any existing highlight before creating a new one
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
	
	-- Highlight must be parented to the model it's adorning for proper functionality
	highlightInstance.Parent = instanceToHighlight.Parent
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
	-- Exit early if the local character or root part is not available
	if not Character or not HumanoidRootPart then
		return nil
	end
	
	local closestTarget = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		-- Skip the local player and teammates
		if player ~= localPlayer and player.Team ~= localPlayer.Team then
			local targetCharacter = player.Character
			if targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") then
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
	
	if currentTarget and HumanoidRootPart then
		-- Update the highlight to the current target
		if highlightInstance and highlightInstance.Adornee ~= currentTarget then
			createHighlight(currentTarget)
		elseif not highlightInstance then
			createHighlight(currentTarget)
		end
		
		-- Smoothly turn the camera to face the target's position
		local lookAtCFrame = CFrame.lookAt(Camera.CFrame.Position, currentTarget.Position)
		Camera.CFrame = Camera.CFrame:lerp(lookAtCFrame, cameraSmoothness)
	else
		-- No valid target found, remove the highlight
		removeHighlight()
	end
end

--=================================================================================--
-- CONNECTIONS AND MAIN LOGIC
--=================================================================================--

-- Re-assign the Character and HumanoidRootPart when the player respawns
localPlayer.CharacterAdded:Connect(function(newChar)
	Character = newChar
	HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
	-- Re-run GUI setup in case it was destroyed on respawn
	setupGui() 
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
		-- When right click is released, remove the highlight and reset target
		removeHighlight()
		currentTarget = nil
	end
end)

-- Main loop for aim-lock logic, only runs when enabled and right mouse button is down
RunService.Heartbeat:Connect(function()
	if isAimLockEnabled and isRightMouseButtonDown then
		updateAimLock()
	end
end)

-- Clean up when the local character dies
if Character then
	Character.Humanoid.Died:Connect(function()
		removeHighlight()
		currentTarget = nil
	end)
end

-- Initial GUI setup
setupGui()
