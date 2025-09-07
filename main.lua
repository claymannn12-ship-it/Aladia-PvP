--[[
    This script provides an aim-lock feature similar to one you might find in Arsenal.
    It is designed to be a self-contained, client-side script that works reliably
    when executed at any time, such as with a side script executor.
    
    This script works by:
    1. Creating a GUI to toggle the aim-lock on and off.
    2. Listening for the right mouse button to be held down.
    3. Finding the closest enemy player in range.
    4. Smoothly adjusting the camera to face the closest enemy.
    
    Key improvements for executor compatibility:
    - Robust character handling: The script correctly initializes whether your character
      is already loaded or is still spawning.
    - Connection cleanup: Event listeners are properly disconnected on each respawn
      to prevent memory leaks and ensure smooth performance.
--]]

-- SERVICES AND VARIABLES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Character
local HumanoidRootPart
local Camera = Workspace.CurrentCamera

-- Persistent variables (saved/loaded via attributes)
local isAimLockEnabled = localPlayer:GetAttribute("IsAimLockEnabled") or false

-- Temporary state variables
local isRightMouseButtonDown = false
local currentTarget = nil
local maxDistance = 150 -- Maximum distance in studs to lock onto a player
local highlightInstance = nil
local cameraSmoothness = 0.3 -- Higher value = faster camera lock

-- Global GUI element references (reset on cleanup)
local toggleButton = nil

-- Table to hold all connections for cleanup
local connections = {}

--=================================================================================--
-- CORE LOGIC
--=================================================================================--

local function cleanupConnections()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {} -- Reset the table
    
    -- Clean up GUI and highlight from old character
    if highlightInstance then
        highlightInstance:Destroy()
        highlightInstance = nil
    end
    if localPlayer.PlayerGui:FindFirstChild("AimLockGui") then
        localPlayer.PlayerGui.AimLockGui:Destroy()
    end
end

local function updateButtonState()
    if isAimLockEnabled then
        toggleButton.Text = "Aim Lock: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 50) -- Green
    else
        toggleButton.Text = "Aim Lock: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
    end
    localPlayer:SetAttribute("IsAimLockEnabled", isAimLockEnabled)
end

local function createHighlight(instanceToHighlight)
    if highlightInstance then
        highlightInstance:Destroy()
    end
    
    highlightInstance = Instance.new("Highlight")
    highlightInstance.Name = "AimLockHighlight"
    highlightInstance.FillColor = Color3.fromRGB(0, 255, 255)
    highlightInstance.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlightInstance.FillTransparency = 1
    highlightInstance.OutlineTransparency = 0
    highlightInstance.Adornee = instanceToHighlight
    
    highlightInstance.Parent = instanceToHighlight.Parent
end

local function removeHighlight()
    if highlightInstance then
        highlightInstance:Destroy()
        highlightInstance = nil
    end
end

local function getClosestValidTarget()
    if not Character or not HumanoidRootPart then
        return nil
    end
    
    local closestTarget = nil
    local closestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Team ~= localPlayer.Team then
            local targetCharacter = player.Character
            if targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") then
                local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
                if targetHumanoid and targetHumanoid.Health > 0 then
                    local targetPart = targetCharacter:FindFirstChild("Head") or targetCharacter:FindFirstChild("UpperTorso") or targetCharacter:FindFirstChild("LowerTorso") or targetCharacter:FindFirstChild("Torso")
                    
                    if targetPart then
                        local distance = (HumanoidRootPart.Position - targetPart.Position).Magnitude
                        
                        if distance < maxDistance and distance < closestDistance then
                            closestTarget = targetPart
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget
end

local function updateAimLock()
    -- Only find a new target if we don't have one or if it's no longer valid
    if not currentTarget or not currentTarget.Parent or not currentTarget.Parent:FindFirstChild("Humanoid") or currentTarget.Parent:FindFirstChild("Humanoid").Health <= 0 then
        currentTarget = getClosestValidTarget()
        -- Remove highlight if no valid target is found
        if not currentTarget then
            removeHighlight()
        end
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
-- GUI SETUP
--=================================================================================--

local function setupGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimLockGui"
    screenGui.Parent = localPlayer.PlayerGui
    
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 150, 0, 40)
    toggleButton.Position = UDim2.new(0.5, -75, 0.9, 0)
    toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 18
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    toggleButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
    toggleButton.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleButton
    
    table.insert(connections, toggleButton.MouseButton1Click:Connect(function()
        isAimLockEnabled = not isAimLockEnabled
        updateButtonState()
        if not isAimLockEnabled then
            removeHighlight()
            currentTarget = nil
        end
    end))
    
    local creditsPanel = Instance.new("Frame")
    creditsPanel.Name = "CreditsPanel"
    creditsPanel.Size = UDim2.new(0, 200, 0, 30)
    creditsPanel.Position = UDim2.new(0, 10, 1, -40)
    creditsPanel.AnchorPoint = Vector2.new(0, 1)
    creditsPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    creditsPanel.BackgroundTransparency = 0.5
    creditsPanel.BorderSizePixel = 0
    creditsPanel.Parent = screenGui
    
    local creditsCorner = Instance.new("UICorner")
    creditsCorner.CornerRadius = UDim.new(0, 8)
    creditsCorner.Parent = creditsPanel
    
    local creditsLabel = Instance.new("TextLabel")
    creditsLabel.Name = "CreditsLabel"
    creditsLabel.Size = UDim2.new(1, 0, 1, 0)
    creditsLabel.BackgroundTransparency = 1
    creditsLabel.Font = Enum.Font.SourceSansPro
    creditsLabel.TextSize = 16
    creditsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    creditsLabel.Text = "DEVELOPER: Sp3ctr@l"
    creditsLabel.Parent = creditsPanel
    
    updateButtonState()
end

--=================================================================================--
-- MAIN SCRIPT EXECUTION
--=================================================================================--

local function setupScript()
    -- This function runs every time the character is added, so clean up first.
    cleanupConnections()
    
    Character = localPlayer.Character
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    -- Set up the GUI and connect its events
    setupGui() 
    
    -- Connect to the humanoid's Died event to clean up on death
    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(connections, humanoid.Died:Connect(function()
            removeHighlight()
            currentTarget = nil
        end))
    end
end

-- Track the right mouse button state
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessedEvent then
        isRightMouseButtonDown = true
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and not gameProcessedEvent then
        isRightMouseButtonDown = false
        removeHighlight()
        currentTarget = nil
    end
end))

-- Main loop for aim-lock logic, only runs when enabled and right mouse button is down
table.insert(connections, RunService.Heartbeat:Connect(function()
    if isAimLockEnabled and isRightMouseButtonDown then
        updateAimLock()
    end
end))

-- Ensure the script is set up whether the character already exists or is added later
if localPlayer.Character then
    setupScript()
end

table.insert(connections, localPlayer.CharacterAdded:Connect(setupScript))
