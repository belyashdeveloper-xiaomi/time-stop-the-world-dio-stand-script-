-- Time Stop (Local visual freeze, FE damage still applies)
-- Toggle: press E
-- Freezes all other players client-side; you keep moving and damaging.
-- While active, your character becomes invisible to server & other clients (transparency replicates via network ownership), but hitboxes stay intact so damage still applies.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local active = false
local frozenChars = {}

-- saved visual state for the local character so we can restore exactly
local savedTransparency = {}
local savedGuiEnabled = {}

local function setLocalVisible(visible)
    if not character then return end
    if visible then
        -- restore
        for part, t in pairs(savedTransparency) do
            if part and part.Parent then
                part.Transparency = t
            end
        end
        savedTransparency = {}
        for gui, v in pairs(savedGuiEnabled) do
            if gui and gui.Parent then
                gui.Enabled = v
            end
        end
        savedGuiEnabled = {}
    else
        -- hide: store originals, then make everything invisible
        savedTransparency = {}
        savedGuiEnabled = {}
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                savedTransparency[obj] = obj.Transparency
                obj.Transparency = 1
                obj.CastShadow = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                savedTransparency[obj] = obj.Transparency
                obj.Transparency = 1
            elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                savedGuiEnabled[obj] = obj.Enabled
                obj.Enabled = false
            end
        end
        -- top-level character parts (in case GetDescendants misses direct)
        for _, obj in ipairs(character:GetChildren()) do
            if obj:IsA("BasePart") then
                if savedTransparency[obj] == nil then
                    savedTransparency[obj] = obj.Transparency
                end
                obj.Transparency = 1
                obj.CastShadow = false
            end
        end
    end
end

local function freezeChar(char)
    if not char or char == character then return end
    if frozenChars[char] then return end
    frozenChars[char] = true

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum.JumpHeight = 0
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            track:AdjustSpeed(0)
        end
    end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = true
            obj.Velocity = Vector3.zero
            obj.RotVelocity = Vector3.zero
        end
    end
end

local function unfreezeChar(char)
    if not char or not frozenChars[char] then return end
    frozenChars[char] = nil

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum.JumpHeight = 7.2
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            track:AdjustSpeed(1)
        end
    end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = false
        end
    end
end

local function freezeAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            freezeChar(p.Character)
        end
    end
end

local function unfreezeAll()
    for char in pairs(frozenChars) do
        unfreezeChar(char)
    end
    frozenChars = {}
end

local function toggle()
    active = not active
    if active then
        freezeAll()
        setLocalVisible(false)
    else
        unfreezeAll()
        setLocalVisible(true)
    end
end

-- On-screen button for mobile
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimeStopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local Button = Instance.new("TextButton")
Button.Size = UDim2.new(0, 120, 0, 50)
Button.Position = UDim2.new(0, 20, 0.5, -25)
Button.Text = "Time Stop: OFF"
Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.TextScaled = true
Button.Parent = ScreenGui

local function updateButton()
    Button.Text = active and "Time Stop: ON" or "Time Stop: OFF"
    Button.BackgroundColor3 = active and Color3.fromRGB(180, 30, 30) or Color3.fromRGB(40, 40, 40)
end

Button.Activated:Connect(function()
    toggle()
    updateButton()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.E then
        toggle()
        updateButton()
    end
end)

-- Keep new spawns frozen while active
local function watchPlayer(p)
    if p == player then return end
    p.CharacterAdded:Connect(function(char)
        char:WaitForChild("Humanoid", 10)
        if active then
            freezeChar(char)
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

-- Re-freeze any character that slips (e.g. respawned parts)
RunService.Heartbeat:Connect(function()
    if not active then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local char = p.Character
            if not frozenChars[char] then
                freezeChar(char)
            end
        end
    end
    -- keep local character hidden (transparency may be reset by engine/respawn)
    if character and character.Parent then
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
                if obj.Transparency ~= 1 then
                    obj.Transparency = 1
                end
                if obj:IsA("BasePart") then
                    obj.CastShadow = false
                end
            elseif (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) and obj.Enabled then
                obj.Enabled = false
            end
        end
    end
end)

-- Cleanup on character respawn of local player
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    if active then
        active = false
        unfreezeAll()
        setLocalVisible(true)
    end
end)