-- GOJO DUELS
-- Eclipse Aura Edition - Animated Duel UI

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Player = Players.LocalPlayer

-- ============================================================
-- SERVICES & SAFE CHARACTER WAIT
-- ============================================================
local function waitForCharacter()
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
        return char
    end
    return Player.CharacterAdded:Wait()
end
task.spawn(waitForCharacter)

if not getgenv then getgenv = function() return _G end end

-- ============================================================
-- STATE
-- ============================================================
local Enabled = {
    SpeedBoost        = false,
    LaggerCounter     = false,
    AntiRagdoll       = false,
    AutoMedusa        = false,
    Float             = false,
    SpeedWhileStealing= false,
    AutoSteal         = false,
    Unwalk            = false,
    OptimizerXRay     = false,
    SpamBat           = false,
    Helicopter        = false,
    Vibrance          = false,
    AutoRight         = false,
    AutoLeft          = false,
    GalaxyMode        = false,
    BatAimbot         = false,
    InfiniteJump      = false,
    SafeConfig        = false,
    LockFloatPosition = false,
    Taunt             = false,
    TPLeft            = false,
    TPRight           = false,
    Tracers           = false,
    WaypointESP       = false,
    MobileButtons     = true,
    BoxMobileButtons  = false,
    CountdownAutoPlay = false,
    Platform          = false,
    RainbowMode       = false,
    AutoColorMode     = false,
}

local Values = {
    BoostSpeed           = 60,
    SpinSpeed            = 30,
    StealingSpeedValue   = 29,
    STEAL_RADIUS         = 20,
    STEAL_DURATION       = 1.3,
    DEFAULT_GRAVITY      = 196.2,
    GalaxyGravityPercent = 70,
    HOP_POWER            = 35,
    HOP_COOLDOWN         = 0.08,
    BatAimbotSpeed       = 60,
    StealPathSpeed       = 60,
    StealPathReturnSpeed = 29,
    TracerThickness      = 2,
    PlatformHeight       = 14,
    ThemePreset          = "Blue",
    GuiScale             = 1.0,
}

local Settings = {
    AutoStealEnabled = false,
    StealRadius = 20,
    StealDuration = 1.3,
}

local KEYBINDS = {
    SPEED     = Enum.KeyCode.V,
    FLOAT     = Enum.KeyCode.F,
    AUTORIGHT = Enum.KeyCode.E,
    AUTOLEFT  = Enum.KeyCode.Q,
    BATAIMBOT = Enum.KeyCode.X,
    TOGGLEUI  = Enum.KeyCode.U,
    CLOSEUI   = Enum.KeyCode.Delete,
    TPDOWN    = Enum.KeyCode.C,
    PLATFORM  = Enum.KeyCode.R,
}

local Connections   = {}
local isStealing    = false
local stealStartTime = nil
local StealData = {}
local lastStealTick = 0
local plotCache = {}
local plotCacheTime = {}
local cachedPrompts = {}
local promptCacheTime = 0
local lastBatSwing  = 0
local BAT_SWING_COOLDOWN = 0.12
local activeRebindAction = nil
local KeybindDisplayCallbacks = {}
local SliderDisplayCallbacks = {}
local LAGGER_COUNTER_SPEED = 15
local LaggerCounterSnapshot = nil
local autoStealSpeedHandoff = false
local speedBoostPulseState = false
local ThemeCallbacks = {}
local countdownAutoEnabled = false
local countdownAutoActive = false
local countdownPreferredSide = "right"
local wpOffsets = {
    Left = {Vector3.zero, Vector3.zero, Vector3.zero},
    Right = {Vector3.zero, Vector3.zero, Vector3.zero},
}
local waypointRowBindings = {}
local refreshWaypointESPVisuals = function() end
local THEME_PRESETS = {
    Blue = {
        accent = Color3.fromRGB(100, 180, 255),
        light = Color3.fromRGB(110, 220, 255),
        dark = Color3.fromRGB(14, 42, 110),
        starlight = Color3.fromRGB(60, 140, 245),
        sunset = Color3.fromRGB(30, 90, 200),
    },
    Yellow = {
        accent = Color3.fromRGB(0, 255, 150),
        light = Color3.fromRGB(70, 255, 210),
        dark = Color3.fromRGB(0, 80, 45),
        starlight = Color3.fromRGB(0, 220, 120),
        sunset = Color3.fromRGB(0, 165, 82),
    },
    Purple = {
        accent = Color3.fromRGB(255, 90, 90),
        light = Color3.fromRGB(255, 170, 110),
        dark = Color3.fromRGB(100, 14, 14),
        starlight = Color3.fromRGB(230, 55, 55),
        sunset = Color3.fromRGB(185, 28, 28),
    },
}

-- Config System
local CONFIG_KEY = "ECLIPSE_DUELS_CONFIG_V2"
local LEGACY_CONFIG_KEY = "ZERO_HUB_CONFIG_V1"
local floatButtonPositions = {}
local floatButtonReferences = {}
local mobileButtonFrames = {}
local boxMobileButtonFrames = {}
local boxMobileButtonReferences = {}
local refreshBoxButtonState = function() end
local refreshAllBoxButtonStates = function() end

-- Forward declarations for startup/reset logic
local startSpeedBoost, stopSpeedBoost
local startLaggerCounter, stopLaggerCounter
local startFloat, stopFloat
local startSpamBat, stopSpamBat
local startHelicopter, stopHelicopter
local startAutoMedusa, stopAutoMedusa
local startBatAimbot, stopBatAimbot
local startInfiniteJump, stopInfiniteJump
local startAutoSteal, stopAutoSteal
local startUnwalk, stopUnwalk
local enablePurpleMoon, disablePurpleMoon
local startAntiRagdoll, stopAntiRagdoll
local enableOptimizer, disableOptimizer
local enableXRay, disableXRay
local startGalaxyMode, stopGalaxyMode
local startSpeedWhileStealing, stopSpeedWhileStealing
local startStealPath, stopStealPath
local startWaypointESP, stopWaypointESP
local startTracers, stopTracers
local startPlatform, stopPlatform
local setMobileButtonsVisible

local function mergeTable(defaults, saved)
    if type(saved) ~= "table" then return defaults end
    for key, value in pairs(saved) do
        defaults[key] = value
    end
    return defaults
end

local function serializeKeybinds()
    local serialized = {}
    for action, keyCode in pairs(KEYBINDS) do
        serialized[action] = typeof(keyCode) == "EnumItem" and keyCode.Name or tostring(keyCode)
    end
    return serialized
end

local function serializeFloatPositions()
    local serialized = {}
    for buttonName, buttonPos in pairs(floatButtonPositions) do
        if typeof(buttonPos) == "UDim2" then
            serialized[buttonName] = {
                xScale = buttonPos.X.Scale,
                xOffset = buttonPos.X.Offset,
                yScale = buttonPos.Y.Scale,
                yOffset = buttonPos.Y.Offset,
            }
        end
    end
    return serialized
end

local function serializeWaypointOffsets()
    local serialized = {}
    for groupName, offsets in pairs(wpOffsets) do
        serialized[groupName] = {}
        for index, offset in ipairs(offsets) do
            serialized[groupName][index] = {
                x = offset.X,
                y = offset.Y,
                z = offset.Z,
            }
        end
    end
    return serialized
end

local function deserializeWaypointOffsets(saved)
    if type(saved) ~= "table" then return end
    for groupName, offsets in pairs(saved) do
        if wpOffsets[groupName] and type(offsets) == "table" then
            for index, offset in ipairs(offsets) do
                if type(offset) == "table" then
                    wpOffsets[groupName][index] = Vector3.new(
                        tonumber(offset.x) or 0,
                        tonumber(offset.y) or 0,
                        tonumber(offset.z) or 0
                    )
                end
            end
        end
    end
end

local function deserializeFloatPositions(savedPositions)
    local positions = {}
    if type(savedPositions) ~= "table" then
        return positions
    end
    for buttonName, buttonPos in pairs(savedPositions) do
        if type(buttonPos) == "table" then
            positions[buttonName] = UDim2.new(
                tonumber(buttonPos.xScale) or 0,
                tonumber(buttonPos.xOffset) or 0,
                tonumber(buttonPos.yScale) or 0,
                tonumber(buttonPos.yOffset) or 0
            )
        end
    end
    return positions
end

local function deserializeKeybinds(saved)
    if type(saved) ~= "table" then return end
    for action, keyName in pairs(saved) do
        local parsed = Enum.KeyCode[keyName]
        if parsed then
            KEYBINDS[action] = parsed
        end
    end
end

local function readConfigBlob(configName)
    local configData = nil
    pcall(function()
        if getgenv and getgenv()[configName] then
            configData = getgenv()[configName]
        end
    end)
    if not configData then
        pcall(function()
            if readfile then
                local json = readfile(configName .. ".json")
                configData = HttpService:JSONDecode(json)
            end
        end)
    end
    return configData
end

local function saveConfig()
    local configData = {
        enabled = Enabled,
        values = Values,
        floatPositions = serializeFloatPositions(),
        waypointOffsets = serializeWaypointOffsets(),
        keybinds = serializeKeybinds(),
    }
    pcall(function()
        if writefile then
            writefile(CONFIG_KEY .. ".json", HttpService:JSONEncode(configData))
        end
    end)
    pcall(function()
        if setgenv then
            getgenv()[CONFIG_KEY] = configData
        end
    end)
end

local function loadConfig()
    local configData = readConfigBlob(CONFIG_KEY) or readConfigBlob(LEGACY_CONFIG_KEY)
    if configData then
        mergeTable(Enabled, configData.enabled)
        mergeTable(Values, configData.values)
        floatButtonPositions = deserializeFloatPositions(configData.floatPositions)
        deserializeWaypointOffsets(configData.waypointOffsets)
        deserializeKeybinds(configData.keybinds)
    end
end

loadConfig()
Enabled.HitCircle = nil
countdownAutoEnabled = Enabled.CountdownAutoPlay or false
if Values.BoostSpeed == 30 then Values.BoostSpeed = 60 end
if Values.BatAimbotSpeed == 55 then Values.BatAimbotSpeed = 60 end
if Values.StealPathReturnSpeed == 30 then Values.StealPathReturnSpeed = 29 end
Values.GuiScale = math.clamp(tonumber(Values.GuiScale) or 1, 0.6, 1)

local function clearThemeCallbacks()
    ThemeCallbacks = {}
end

local function registerThemeCallback(callback)
    table.insert(ThemeCallbacks, callback)
end

local function lerpColor3(fromColor, toColor, alpha)
    return Color3.new(
        fromColor.R + (toColor.R - fromColor.R) * alpha,
        fromColor.G + (toColor.G - fromColor.G) * alpha,
        fromColor.B + (toColor.B - fromColor.B) * alpha
    )
end

local function buildRainbowPalette()
    local hue = (tick() * 0.12) % 1
    return {
        accent = Color3.fromHSV(hue, 0.82, 1),
        light = Color3.fromHSV(hue, 0.42, 1),
        dark = Color3.fromHSV(hue, 0.7, 0.72),
        starlight = Color3.fromHSV((hue + 0.04) % 1, 0.72, 1),
        sunset = Color3.fromHSV((hue + 0.08) % 1, 0.84, 1),
    }
end

local function blendPalettes(firstPalette, secondPalette, alpha)
    return {
        accent = lerpColor3(firstPalette.accent, secondPalette.accent, alpha),
        light = lerpColor3(firstPalette.light, secondPalette.light, alpha),
        dark = lerpColor3(firstPalette.dark, secondPalette.dark, alpha),
        starlight = lerpColor3(firstPalette.starlight, secondPalette.starlight, alpha),
        sunset = lerpColor3(firstPalette.sunset, secondPalette.sunset, alpha),
    }
end

local function getThemePalette()
    if Enabled.RainbowMode then
        return buildRainbowPalette()
    end
    if Enabled.AutoColorMode then
        local order = {"Blue", "Yellow", "Purple"}
        local cycle = tick() * 0.22
        local index = (math.floor(cycle) % #order) + 1
        local nextIndex = (index % #order) + 1
        local alpha = cycle - math.floor(cycle)
        return blendPalettes(THEME_PRESETS[order[index]], THEME_PRESETS[order[nextIndex]], alpha)
    end
    return THEME_PRESETS[Values.ThemePreset] or THEME_PRESETS.Blue
end

local function refreshThemeMode()
    if Connections.theme then
        Connections.theme:Disconnect()
        Connections.theme = nil
    end
    local palette = getThemePalette()
    for _, callback in ipairs(ThemeCallbacks) do
        pcall(callback, palette)
    end
    if Enabled.RainbowMode or Enabled.AutoColorMode then
        Connections.theme = RunService.RenderStepped:Connect(function()
            local animatedPalette = getThemePalette()
            for _, callback in ipairs(ThemeCallbacks) do
                pcall(callback, animatedPalette)
            end
        end)
    end
end

local function setThemePreset(presetName)
    Values.ThemePreset = presetName
    Enabled.AutoColorMode = false
    Enabled.RainbowMode = false
    if VisualSetters.AutoColorMode then
        VisualSetters.AutoColorMode(false, true)
    end
    if VisualSetters.RainbowMode then
        VisualSetters.RainbowMode(false, true)
    end
    refreshThemeMode()
end

-- ============================================================
-- FIXED SAFE CONFIG LOGIC (Boot Effect)
-- ============================================================
local VisualSetters = {}

local function applyBootEffect()
    task.spawn(function()
        local savedEnabled = {}
        for key, value in pairs(Enabled) do
            savedEnabled[key] = value
        end

        -- SHUTDOWN EVERYTHING
        stopSpeedBoost()
        stopLaggerCounter()
        stopFloat()
        stopSpamBat()
        stopHelicopter()
        stopAutoMedusa()
        stopBatAimbot()
        stopInfiniteJump()
        stopAutoSteal()
        stopUnwalk()
        disablePurpleMoon()
        stopAntiRagdoll()
        disableOptimizer()
        disableXRay()
        stopGalaxyMode()
        stopSpeedWhileStealing()
        stopStealPath()
        stopWaypointESP()
        stopTracers()
        stopPlatform()

        -- Reset Visuals to OFF
        for key, setterFunc in pairs(VisualSetters) do
            pcall(function() setterFunc(false, true) end)
        end
        for key, updateFunc in pairs(floatButtonReferences) do
            pcall(function() updateFunc(false) end)
        end

        task.wait(2)

        -- RESTORE EVERYTHING
        for key, value in pairs(savedEnabled) do
            Enabled[key] = value
            if value == true then
                if key == "SpeedBoost" then startSpeedBoost() end
                if key == "LaggerCounter" then startLaggerCounter() end
                if key == "Float" then startFloat() end
                if key == "SpamBat" then startSpamBat() end
                if key == "Helicopter" then startHelicopter() end
                if key == "AutoMedusa" then startAutoMedusa() end
                if key == "BatAimbot" then startBatAimbot() end
                if key == "InfiniteJump" then startInfiniteJump() end
                if key == "AutoSteal" then startAutoSteal() end
                if key == "Unwalk" then startUnwalk() end
                if key == "Vibrance" then enablePurpleMoon() end
                if key == "AntiRagdoll" then startAntiRagdoll() end
                if key == "OptimizerXRay" then enableOptimizer() enableXRay() end
                if key == "GalaxyMode" then startGalaxyMode() end
                if key == "SpeedWhileStealing" then startSpeedWhileStealing() end
                if key == "WaypointESP" then startWaypointESP() end
                if key == "Tracers" then startTracers() end
                if key == "Platform" then startPlatform() end

                -- Update Visuals to ON
                if VisualSetters[key] then VisualSetters[key](true, true) end
                if floatButtonReferences[key] then floatButtonReferences[key](true) end
            end
        end
        if setMobileButtonsVisible then setMobileButtonsVisible(Enabled.MobileButtons) end
    end)
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getMovementDirection()
    local c = Player.Character
    if not c then return Vector3.zero end
    local hum = c:FindFirstChildOfClass("Humanoid")
    return hum and hum.MoveDirection or Vector3.zero
end

local function createHeadDiscordLabel()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
    if not head then return end

    local existing = head:FindFirstChild("GojoDiscordBillboard")
    if existing then
        existing:Destroy()
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GojoDiscordBillboard"
    billboard.Size = UDim2.new(0, 320, 0, 54)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 28)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = "discord.gg/fzfKYgPH3Q"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.45
    label.TextSize = 16
    label.Parent = billboard

    local speedLabel = Instance.new("TextLabel")
    speedLabel.BackgroundTransparency = 1
    speedLabel.Size = UDim2.new(1, 0, 0, 22)
    speedLabel.Position = UDim2.new(0, 0, 0, 28)
    speedLabel.Font = Enum.Font.GothamBlack
    speedLabel.Text = "Speed: 0"
    speedLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    speedLabel.TextStrokeTransparency = 0.35
    speedLabel.TextSize = 14
    speedLabel.Parent = billboard

    local speedConn
    speedConn = RunService.Heartbeat:Connect(function()
        if not billboard.Parent then
            if speedConn then speedConn:Disconnect() speedConn = nil end
            return
        end
        local c = Player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then
            speedLabel.Text = "Speed: 0"
            return
        end
        local vel = hrp.AssemblyLinearVelocity
        local horizontalSpeed = math.floor(Vector3.new(vel.X, 0, vel.Z).Magnitude + 0.5)
        speedLabel.Text = "Speed: " .. tostring(horizontalSpeed)
    end)
end

task.spawn(createHeadDiscordLabel)
Player.CharacterAdded:Connect(function()
    task.wait(1)
    createHeadDiscordLabel()
end)

local SlapList = {
    {1,"Bat"},{2,"Slap"},{3,"Iron Slap"},{4,"Gold Slap"},
    {5,"Diamond Slap"},{6,"Emerald Slap"},{7,"Ruby Slap"},
    {8,"Dark Matter Slap"},{9,"Flame Slap"},{10,"Nuclear Slap"},
    {11,"Galaxy Slap"},{12,"Glitched Slap"}
}

local function findBat()
    local c = Player.Character
    if not c then return nil end
    local bp = Player:FindFirstChildOfClass("Backpack")
    for _, ch in ipairs(c:GetChildren()) do
        if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
    end
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
        end
    end
    for _, i in ipairs(SlapList) do
        local t = c:FindFirstChild(i[2]) or (bp and bp:FindFirstChild(i[2]))
        if t then return t end
    end
    return nil
end

local function isBatTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local loweredName = tool.Name:lower()
    if loweredName:find("bat") or loweredName:find("slap") then
        return true
    end
    for _, item in ipairs(SlapList) do
        if loweredName == item[2]:lower() then
            return true
        end
    end
    return false
end

local function isCarryingBrainrot()
    if Player:GetAttribute("Stealing") then
        return true
    end
    local c = Player.Character
    if not c then
        return false
    end
    for _, child in ipairs(c:GetChildren()) do
        if child:IsA("Tool") and not isBatTool(child) then
            return true
        end
    end
    return false
end

local function sendLegitTaunt()
    local message = "/GOJO on top"
    local sent = false
    pcall(function()
        local textChannels = TextChatService:FindFirstChild("TextChannels")
        local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
        if generalChannel then
            generalChannel:SendAsync(message)
            sent = true
        end
    end)
    if sent then return end
    pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local sayMessageRequest = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
        if sayMessageRequest then
            sayMessageRequest:FireServer(message, "All")
        end
    end)
end

-- ============================================================
-- FEATURE LOGIC
-- ============================================================

local function getEclipseSpeed(baseSpeed, minSpeed, maxSpeed)
    baseSpeed = tonumber(baseSpeed) or 16
    minSpeed = minSpeed or 1
    maxSpeed = maxSpeed or 500
    speedBoostPulseState = not speedBoostPulseState
    return math.clamp(baseSpeed + (speedBoostPulseState and 1 or -1), minSpeed, maxSpeed)
end

-- Speed Boost
function startSpeedBoost()
    if Connections.speed then return end
    Connections.speed = RunService.Heartbeat:Connect(function()
        if not Enabled.SpeedBoost then return end
        pcall(function()
            if isCarryingBrainrot() then
                autoStealSpeedHandoff = true
                Enabled.SpeedBoost = false
                if VisualSetters.SpeedBoost then VisualSetters.SpeedBoost(false, true) end
                if floatButtonReferences.SpeedBoost then floatButtonReferences.SpeedBoost(false) end
                stopSpeedBoost()
                startSpeedWhileStealing()
                return
            end
            local c = Player.Character
            if not c then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            local md = getMovementDirection()
            if md.Magnitude > 0.1 then
                local eclipseSpeed = getEclipseSpeed(Values.BoostSpeed, 1, 90)
                h.AssemblyLinearVelocity = Vector3.new(md.X * eclipseSpeed, h.AssemblyLinearVelocity.Y, md.Z * eclipseSpeed)
            end
        end)
    end)
end
function stopSpeedBoost()
    if Connections.speed then Connections.speed:Disconnect() Connections.speed = nil end
    speedBoostPulseState = false
end

-- Speed While Stealing
function startSpeedWhileStealing()
    if Connections.speedWhileStealing then return end
    Connections.speedWhileStealing = RunService.Heartbeat:Connect(function()
        if not isCarryingBrainrot() then return end
        if not Enabled.SpeedWhileStealing and not autoStealSpeedHandoff then return end
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local md = getMovementDirection()
        if md.Magnitude > 0.1 then
            local eclipseSpeed = getEclipseSpeed(Values.StealingSpeedValue, 1, 90)
            h.AssemblyLinearVelocity = Vector3.new(md.X * eclipseSpeed, h.AssemblyLinearVelocity.Y, md.Z * eclipseSpeed)
        end
    end)
end
function stopSpeedWhileStealing()
    if Connections.speedWhileStealing then Connections.speedWhileStealing:Disconnect() Connections.speedWhileStealing = nil end
end

local function syncStealSpeedHandoff()
    local stealing = isCarryingBrainrot()
    if stealing and Enabled.SpeedBoost then
        autoStealSpeedHandoff = true
        Enabled.SpeedBoost = false
        if VisualSetters.SpeedBoost then VisualSetters.SpeedBoost(false, true) end
        if floatButtonReferences.SpeedBoost then floatButtonReferences.SpeedBoost(false) end
        stopSpeedBoost()
    elseif not stealing then
        autoStealSpeedHandoff = false
    end

    if stealing and (Enabled.SpeedWhileStealing or autoStealSpeedHandoff) then
        startSpeedWhileStealing()
    elseif not Enabled.SpeedWhileStealing then
        stopSpeedWhileStealing()
    end
end

Player:GetAttributeChangedSignal("Stealing"):Connect(syncStealSpeedHandoff)
Player.CharacterAdded:Connect(function(character)
    character.ChildAdded:Connect(syncStealSpeedHandoff)
    character.ChildRemoved:Connect(syncStealSpeedHandoff)
end)
if Player.Character then
    Player.Character.ChildAdded:Connect(syncStealSpeedHandoff)
    Player.Character.ChildRemoved:Connect(syncStealSpeedHandoff)
end

-- Anti Ragdoll (v2)
local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}
local isBoosting = false
local AR_BOOST_SPEED = 400
local AR_DEFAULT_SPEED = 16

local function arCacheCharacterData()
    local char = Player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    return true
end

local function arDisconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    if state == Enum.HumanoidStateType.Physics or
       state == Enum.HumanoidStateType.Ragdoll or
       state == Enum.HumanoidStateType.FallingDown then return true end
    local endTime = Player:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

local function arForceExit()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function()
        Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, d in ipairs(cachedCharData.character:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
            d:Destroy()
        end
    end
    if not isBoosting then
        isBoosting = true
        cachedCharData.humanoid.WalkSpeed = AR_BOOST_SPEED
    end
    if cachedCharData.humanoid.Health > 0 then
        cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        if not Enabled.AntiRagdoll then break end
        local ragdolled = arIsRagdolled()
        if ragdolled then
            arForceExit()
        elseif isBoosting and not ragdolled then
            isBoosting = false
            if cachedCharData.humanoid then
                cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
            end
        end
    end
end

function startAntiRagdoll()
    if Connections.antiRagdoll then return end
    Connections.antiRagdoll = RunService.Heartbeat:Connect(function()
        if not Enabled.AntiRagdoll then return end
        local char = Player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                if workspace.CurrentCamera then
                    workspace.CurrentCamera.CameraSubject = hum
                end
                pcall(function()
                    local pm = Player.PlayerScripts and Player.PlayerScripts:FindFirstChild("PlayerModule")
                    if pm then
                        local controlModule = pm:FindFirstChild("ControlModule")
                        if controlModule then
                            require(controlModule):Enable()
                        end
                    end
                end)
                if root then
                    root.Velocity = Vector3.zero
                    root.RotVelocity = Vector3.zero
                end
            end
        end

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") and not obj.Enabled then
                obj.Enabled = true
            end
        end
    end)
end

function stopAntiRagdoll()
    if Connections.antiRagdoll then
        Connections.antiRagdoll:Disconnect()
        Connections.antiRagdoll = nil
    end
end

-- Tracers
local tracerConnection = nil
local tracerCache = {}
local tracerSupported = type(Drawing) == "table" and type(Drawing.new) == "function"

local function destroyTracer(playerObj)
    local tracer = tracerCache[playerObj]
    if tracer then
        pcall(function()
            tracer.Visible = false
            tracer:Remove()
        end)
        tracerCache[playerObj] = nil
    end
end

local function ensureTracer(playerObj)
    if not tracerSupported then return nil end
    if tracerCache[playerObj] then return tracerCache[playerObj] end
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Transparency = 1
    tracer.Thickness = Values.TracerThickness
    tracer.ZIndex = 2
    tracerCache[playerObj] = tracer
    return tracer
end

function startTracers()
    if tracerConnection then return end
    if not tracerSupported then
        Enabled.Tracers = false
        if VisualSetters.Tracers then VisualSetters.Tracers(false, true) end
        return
    end
    tracerConnection = RunService.RenderStepped:Connect(function()
        if not Enabled.Tracers then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local viewport = cam.ViewportSize
        local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        local origin = Vector2.new(viewport.X * 0.5, viewport.Y - 42)

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= Player then
                local tracer = ensureTracer(otherPlayer)
                if tracer then
                    local char = otherPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and root then
                        local point, onScreen = cam:WorldToViewportPoint(root.Position)
                        if onScreen and point.Z > 0 then
                            local distance = myRoot and (myRoot.Position - root.Position).Magnitude or 0
                            local fade = math.clamp(distance / 240, 0, 1)
                            tracer.From = origin
                            tracer.To = Vector2.new(point.X, point.Y)
                            tracer.Thickness = Values.TracerThickness
                            tracer.Color = Color3.fromRGB(
                                255,
                                math.floor(220 - (fade * 110)),
                                math.floor(120 + ((1 - fade) * 90))
                            )
                            tracer.Visible = true
                        else
                            tracer.Visible = false
                        end
                    else
                        tracer.Visible = false
                    end
                end
            end
        end
    end)
end

function stopTracers()
    if tracerConnection then
        tracerConnection:Disconnect()
        tracerConnection = nil
    end
    for playerObj in pairs(tracerCache) do
        destroyTracer(playerObj)
    end
end

Players.PlayerRemoving:Connect(destroyTracer)

-- Spam Bat
function startSpamBat()
    if Connections.spamBat then return end
    Connections.spamBat = RunService.Heartbeat:Connect(function()
        if not Enabled.SpamBat then return end
        local c = Player.Character
        if not c then return end
        local bat = findBat()
        if not bat then return end
        if bat.Parent ~= c then bat.Parent = c end
        local now = tick()
        if now - lastBatSwing < BAT_SWING_COOLDOWN then return end
        lastBatSwing = now
        pcall(function() bat:Activate() end)
    end)
end
function stopSpamBat()
    if Connections.spamBat then Connections.spamBat:Disconnect() Connections.spamBat = nil end
end

-- Helicopter
local helicopterBAV = nil
function startHelicopter()
    local c = Player.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if helicopterBAV then helicopterBAV:Destroy() helicopterBAV = nil end
    helicopterBAV = Instance.new("BodyAngularVelocity")
    helicopterBAV.Name = "HelicopterBAV"
    helicopterBAV.MaxTorque = Vector3.new(0, math.huge, 0)
    helicopterBAV.AngularVelocity = Vector3.new(0, Values.SpinSpeed, 0)
    helicopterBAV.Parent = hrp
end
function stopHelicopter()
    if helicopterBAV then helicopterBAV:Destroy() helicopterBAV = nil end
    local c = Player.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v.Name == "HelicopterBAV" then v:Destroy() end
            end
        end
    end
end

-- Float
local floatConn = nil
local floatHeight = 9.5
local harderHitAnimConn = nil
local originalHitAnims = nil
local HarderHitAnims = {
    idle1 = "rbxassetid://133806214992291",
    idle2 = "rbxassetid://94970088341563",
    walk = "rbxassetid://707897309",
    run = "rbxassetid://707861613",
    jump = "rbxassetid://116936326516985",
    fall = "rbxassetid://116936326516985",
    climb = "rbxassetid://116936326516985",
    swim = "rbxassetid://116936326516985",
    swimidle = "rbxassetid://116936326516985",
}
local function teleportDownNow(dropDistance)
    local wasFloating = Enabled.Float
    if wasFloating then stopFloat() end
    task.spawn(function()
        pcall(function()
            local c = Player.Character; if not c then return end
            local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {c}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(dropDistance or 500), 0), rp)
            if hit then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                local hh = hum.HipHeight or 2
                local hy = hrp.Size.Y / 2
                hrp.CFrame = CFrame.new(hit.Position.X, hit.Position.Y + hh + hy + 0.1, hit.Position.Z)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        task.wait(0.1)
        if wasFloating then startFloat() end
        if VisualSetters and VisualSetters.TPDownReset then
            VisualSetters.TPDownReset()
        end
    end)
end

local function syncStealSettings()
    Settings.AutoStealEnabled = Enabled.AutoSteal
    Settings.StealRadius = Values.STEAL_RADIUS
    Settings.StealDuration = Values.STEAL_DURATION
end
syncStealSettings()

function startFloat()
    if floatConn then
        floatConn:Disconnect()
        floatConn = nil
    end
    floatConn = RunService.Heartbeat:Connect(function()
        if not Enabled.Float then return end
        local char = Player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local rr = workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rp)
        if rr then
            local diff = (rr.Position.Y + floatHeight) - root.Position.Y
            if math.abs(diff) > 0.3 then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, diff * 15, root.AssemblyLinearVelocity.Z)
            else
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            end
        end
    end)
end
function stopFloat()
    if floatConn then floatConn:Disconnect() floatConn = nil end
    local c = Player.Character
    if c then
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
    end
end

-- Harder Hit Anim (replaces Platform)
function startPlatform()
    local function saveOriginalAnims(char)
        local animate = char:FindFirstChild("Animate")
        if not animate then return end
        local function getAnimId(obj) return obj and obj.AnimationId or nil end
        originalHitAnims = {
            idle1 = getAnimId(animate.idle and animate.idle.Animation1),
            idle2 = getAnimId(animate.idle and animate.idle.Animation2),
            walk = getAnimId(animate.walk and animate.walk.WalkAnim),
            run = getAnimId(animate.run and animate.run.RunAnim),
            jump = getAnimId(animate.jump and animate.jump.JumpAnim),
            fall = getAnimId(animate.fall and animate.fall.FallAnim),
            climb = getAnimId(animate.climb and animate.climb.ClimbAnim),
            swim = getAnimId(animate.swim and animate.swim.Swim),
            swimidle = getAnimId(animate.swimidle and animate.swimidle.SwimIdle),
        }
    end
    local function applyAnimPack(char)
        local animate = char:FindFirstChild("Animate")
        if not animate then return end
        local function setAnim(obj, id) if obj then obj.AnimationId = id end end
        setAnim(animate.idle and animate.idle.Animation1, HarderHitAnims.idle1)
        setAnim(animate.idle and animate.idle.Animation2, HarderHitAnims.idle2)
        setAnim(animate.walk and animate.walk.WalkAnim, HarderHitAnims.walk)
        setAnim(animate.run and animate.run.RunAnim, HarderHitAnims.run)
        setAnim(animate.jump and animate.jump.JumpAnim, HarderHitAnims.jump)
        setAnim(animate.fall and animate.fall.FallAnim, HarderHitAnims.fall)
        setAnim(animate.climb and animate.climb.ClimbAnim, HarderHitAnims.climb)
        setAnim(animate.swim and animate.swim.Swim, HarderHitAnims.swim)
        setAnim(animate.swimidle and animate.swimidle.SwimIdle, HarderHitAnims.swimidle)
    end
    if harderHitAnimConn then harderHitAnimConn:Disconnect() harderHitAnimConn = nil end
    local char = Player.Character
    if char then
        saveOriginalAnims(char)
        applyAnimPack(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
    end
    harderHitAnimConn = RunService.Heartbeat:Connect(function()
        if not Enabled.Platform then return end
        local c = Player.Character
        if c then
            applyAnimPack(c)
        end
    end)
end
function stopPlatform()
    if harderHitAnimConn then
        harderHitAnimConn:Disconnect()
        harderHitAnimConn = nil
    end
    if not originalHitAnims then return end
    local char = Player.Character
    if char then
        local animate = char:FindFirstChild("Animate")
        if animate then
            local function setAnim(obj, id) if obj and id then obj.AnimationId = id end end
            setAnim(animate.idle and animate.idle.Animation1, originalHitAnims.idle1)
            setAnim(animate.idle and animate.idle.Animation2, originalHitAnims.idle2)
            setAnim(animate.walk and animate.walk.WalkAnim, originalHitAnims.walk)
            setAnim(animate.run and animate.run.RunAnim, originalHitAnims.run)
            setAnim(animate.jump and animate.jump.JumpAnim, originalHitAnims.jump)
            setAnim(animate.fall and animate.fall.FallAnim, originalHitAnims.fall)
            setAnim(animate.climb and animate.climb.ClimbAnim, originalHitAnims.climb)
            setAnim(animate.swim and animate.swim.Swim, originalHitAnims.swim)
            setAnim(animate.swimidle and animate.swimidle.SwimIdle, originalHitAnims.swimidle)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
    end
end

-- Unwalk
local savedAnimations = {}
function startUnwalk()
    local c = Player.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim = c:FindFirstChild("Animate")
    if anim then savedAnimations.Animate = anim:Clone() anim:Destroy() end
end
function stopUnwalk()
    local c = Player.Character
    if c and savedAnimations.Animate then
        savedAnimations.Animate:Clone().Parent = c
        savedAnimations.Animate = nil
    end
end

-- Auto Medusa (K7)
local MEDUSA_COOLDOWN = 25
local medusaLastUsed = 0
local medusaDebounce = false
local medusaAnchorConns = {}

local function findMedusa()
    local char = Player.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("medusa") or name:find("head") or name:find("stone") then
                return tool
            end
        end
    end
    local backpack = Player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                if name:find("medusa") or name:find("head") or name:find("stone") then
                    return tool
                end
            end
        end
    end
    return nil
end

local function useMedusaCounter()
    if medusaDebounce then return end
    if tick() - medusaLastUsed < MEDUSA_COOLDOWN then return end
    local char = Player.Character
    if not char then return end
    medusaDebounce = true
    local medusa = findMedusa()
    if not medusa then
        medusaDebounce = false
        return
    end
    if medusa.Parent ~= char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(medusa) end
    end
    pcall(function() medusa:Activate() end)
    medusaLastUsed = tick()
    medusaDebounce = false
end

function stopAutoMedusa()
    for _, conn in pairs(medusaAnchorConns) do
        pcall(function() conn:Disconnect() end)
    end
    medusaAnchorConns = {}
end

local function setupAutoMedusa(char)
    stopAutoMedusa()
    if not char then return end
    local function onAnchorChanged(part)
        return part:GetPropertyChangedSignal("Anchored"):Connect(function()
            if Enabled.AutoMedusa and part.Anchored and part.Transparency == 1 then
                useMedusaCounter()
            end
        end)
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(medusaAnchorConns, onAnchorChanged(part))
        end
    end
    table.insert(medusaAnchorConns, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then
            table.insert(medusaAnchorConns, onAnchorChanged(part))
        end
    end))
end

function startAutoMedusa()
    setupAutoMedusa(Player.Character)
end

-- Bat Aimbot
local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local eh  = p.Character:FindFirstChild("HumanoidRootPart")
            local torso = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health > 0 then
                local d = (eh.Position - myHRP.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest     = eh
                    nearestTorso = torso or eh
                end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end

function startBatAimbot()
    if Connections.batAimbot then return end
    Connections.batAimbot = RunService.Heartbeat:Connect(function()
        if not Enabled.BatAimbot then return end
        local c = Player.Character
        if not c then return end
        local h   = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local bat = findBat()
        if bat and bat.Parent ~= c then
            pcall(function() hum:EquipTool(bat) end)
        end
        local target, _, torso = findNearestEnemy(h)
        if target and torso then
            local targetPoint = torso.Position + Vector3.new(0, torso == target and 1.5 or 0.6, 0)
            local dir = targetPoint - h.Position
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatDist = flatDir.Magnitude
            local spd = getEclipseSpeed(Values.BatAimbotSpeed, 10, 140)
            if flatDist > 1.5 then
                local moveDir = flatDir.Unit
                local verticalSpeed = math.clamp(dir.Y * 6, -spd, spd)
                h.AssemblyLinearVelocity = Vector3.new(moveDir.X * spd, verticalSpeed, moveDir.Z * spd)
            else
                local tv = target.AssemblyLinearVelocity
                local verticalSpeed = math.clamp(dir.Y * 6, -spd, spd)
                h.AssemblyLinearVelocity = Vector3.new(tv.X, verticalSpeed, tv.Z)
            end
        end
    end)
end
function stopBatAimbot()
    if Connections.batAimbot then
        Connections.batAimbot:Disconnect()
        Connections.batAimbot = nil
    end
end

-- Galaxy Mode
local galaxyModeEnabled = false
local galaxyHopsEnabled = false
local galaxyLastHopTime = 0
local galaxySpaceHeld   = false
local galaxyOriginalJump = 50
local galaxyVectorForce = nil
local galaxyAttachment  = nil

local function galaxyCaptureJumpPower()
    local c = Player.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum and hum.JumpPower > 0 then galaxyOriginalJump = hum.JumpPower end
    end
end
task.spawn(function() task.wait(1) galaxyCaptureJumpPower() end)
Player.CharacterAdded:Connect(function() task.wait(1) galaxyCaptureJumpPower() end)

local function galaxySetupForce()
    pcall(function()
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        if galaxyVectorForce then galaxyVectorForce:Destroy() end
        if galaxyAttachment  then galaxyAttachment:Destroy()  end
        galaxyAttachment = Instance.new("Attachment")
        galaxyAttachment.Parent = h
        galaxyVectorForce = Instance.new("VectorForce")
        galaxyVectorForce.Attachment0 = galaxyAttachment
        galaxyVectorForce.ApplyAtCenterOfMass = true
        galaxyVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        galaxyVectorForce.Force = Vector3.zero
        galaxyVectorForce.Parent = h
    end)
end
local function galaxyUpdateForce()
    if not galaxyModeEnabled or not galaxyVectorForce then return end
    local c = Player.Character
    if not c then return end
    local mass = 0
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then mass += p:GetMass() end
    end
    local tg = Values.DEFAULT_GRAVITY * (Values.GalaxyGravityPercent / 100)
    galaxyVectorForce.Force = Vector3.new(0, mass * (Values.DEFAULT_GRAVITY - tg) * 0.95, 0)
end
function galaxyAdjustJump()
    pcall(function()
        local c = Player.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if not galaxyModeEnabled then hum.JumpPower = galaxyOriginalJump return end
        local ratio = math.sqrt((Values.DEFAULT_GRAVITY * (Values.GalaxyGravityPercent / 100)) / Values.DEFAULT_GRAVITY)
        hum.JumpPower = galaxyOriginalJump * ratio
    end)
end
local function galaxyDoMiniHop()
    if not galaxyHopsEnabled then return end
    pcall(function()
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        if tick() - galaxyLastHopTime < Values.HOP_COOLDOWN then return end
        galaxyLastHopTime = tick()
        if hum.FloorMaterial == Enum.Material.Air then
            h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, Values.HOP_POWER, h.AssemblyLinearVelocity.Z)
        end
    end)
end
function startGalaxyMode()
    galaxyModeEnabled = true
    galaxyHopsEnabled = true
    galaxySetupForce()
    galaxyAdjustJump()
end
function stopGalaxyMode()
    galaxyModeEnabled = false
    galaxyHopsEnabled = false
    if galaxyVectorForce then galaxyVectorForce:Destroy() galaxyVectorForce = nil end
    if galaxyAttachment  then galaxyAttachment:Destroy()  galaxyAttachment  = nil end
    galaxyAdjustJump()
end

RunService.Heartbeat:Connect(function()
    if galaxyHopsEnabled and galaxySpaceHeld then galaxyDoMiniHop() end
    if galaxyModeEnabled then galaxyUpdateForce() end
end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space then galaxySpaceHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then galaxySpaceHeld = false end
end)
Player.CharacterAdded:Connect(function()
    task.wait(1)
    if galaxyModeEnabled then galaxySetupForce() galaxyAdjustJump() end
end)

-- Infinite Jump
local IJ_JumpConn = nil
local IJ_FallConn = nil

function startInfiniteJump()
    if IJ_JumpConn then IJ_JumpConn:Disconnect() end
    if IJ_FallConn then IJ_FallConn:Disconnect() end
    IJ_JumpConn = UserInputService.JumpRequest:Connect(function()
        if not Enabled.InfiniteJump then return end
        local char = Player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z)
        end
    end)
    IJ_FallConn = RunService.Heartbeat:Connect(function()
        if not Enabled.InfiniteJump then return end
        local char = Player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root.Velocity.Y < -120 then
            root.Velocity = Vector3.new(root.Velocity.X, -120, root.Velocity.Z)
        end
    end)
end

function stopInfiniteJump()
    if IJ_JumpConn then IJ_JumpConn:Disconnect(); IJ_JumpConn = nil end
    if IJ_FallConn then IJ_FallConn:Disconnect(); IJ_FallConn = nil end
end

-- Optimizer + XRay
local originalTransparency = {}
function enableOptimizer()
    if getgenv and getgenv().OPTIMIZER_ACTIVE then return end
    if getgenv then getgenv().OPTIMIZER_ACTIVE = true end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.Brightness = 3
        Lighting.FogEnd = 9e9
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    obj:Destroy()
                elseif obj:IsA("BasePart") then
                    obj.CastShadow = false
                    obj.Material = Enum.Material.Plastic
                end
            end)
        end
    end)
end
function disableOptimizer()
    if getgenv then getgenv().OPTIMIZER_ACTIVE = false end
end
function enableXRay()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and
               (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                originalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.85
            end
        end
    end)
end
function disableXRay()
    for part, value in pairs(originalTransparency) do
        if part then part.LocalTransparencyModifier = value end
    end
    originalTransparency = {}
end

-- Disable Player Collision
local playerCollisionConn = nil

function enablePurpleMoon()
    if playerCollisionConn then return end
    playerCollisionConn = RunService.Stepped:Connect(function()
        if not Enabled.Vibrance then return end
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= Player and otherPlayer.Character then
                for _, part in ipairs(otherPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

function disablePurpleMoon()
    if playerCollisionConn then
        playerCollisionConn:Disconnect()
        playerCollisionConn = nil
    end
end

-- Teleport Functions
local function teleportToPositions(pos1, pos2)
    local c = Player.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Teleport to first position
    hrp.CFrame = CFrame.new(pos1)
    task.wait(0.1)

    -- Teleport to second position
    hrp.CFrame = CFrame.new(pos2)
end

function teleportLeft()
    teleportToPositions(Vector3.new(-474.15, -7.09, 95.27), Vector3.new(-483.20, -5.13, 96.17))
end

function teleportRight()
    teleportToPositions(Vector3.new(-474.87, -7.09, 24.62), Vector3.new(-482.25, -5.13, 24.59))
end

-- Auto Steal (Insta Grab Logic)
local STEAL_COOLDOWN = 0.1
local PLOT_CACHE_DURATION = 2
local PROMPT_CACHE_REFRESH = 0.15
local ProgressLabel, ProgressPercentLabel, ProgressBarFill, RadiusInput, DurationInput

local function resetStealProgressBar()
    if ProgressLabel then ProgressLabel.Text = "READY" end
    if ProgressPercentLabel then ProgressPercentLabel.Text = "" end
    if ProgressBarFill then ProgressBarFill.Size = UDim2.new(0, 0, 1, 0) end
end

local function isMyBase(plotName)
    local currentTime = tick()
    if plotCache[plotName] and (currentTime - (plotCacheTime[plotName] or 0)) < PLOT_CACHE_DURATION then
        return plotCache[plotName]
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        plotCache[plotName] = false
        plotCacheTime[plotName] = currentTime
        return false
    end
    local plot = plots:FindFirstChild(plotName)
    if not plot then
        plotCache[plotName] = false
        plotCacheTime[plotName] = currentTime
        return false
    end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            local result = yourBase.Enabled == true
            plotCache[plotName] = result
            plotCacheTime[plotName] = currentTime
            return result
        end
    end
    plotCache[plotName] = false
    plotCacheTime[plotName] = currentTime
    return false
end

local function findNearestPrompt()
    local c = Player.Character
    if not c then return nil end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local currentTime = tick()
    if currentTime - promptCacheTime < PROMPT_CACHE_REFRESH and #cachedPrompts > 0 then
        local nearestPrompt, nearestDist, nearestName = nil, math.huge, nil
        for _, data in ipairs(cachedPrompts) do
            if data.spawn then
                local dist = (data.spawn.Position - root.Position).Magnitude
                if dist <= Settings.StealRadius and dist < nearestDist then
                    nearestPrompt = data.prompt
                    nearestDist = dist
                    nearestName = data.name
                end
            end
        end
        if nearestPrompt then
            return nearestPrompt, nearestDist, nearestName
        end
    end

    cachedPrompts = {}
    promptCacheTime = currentTime

    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    local nearestPrompt, nearestDist, nearestName = nil, math.huge, nil
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyBase(plot.Name) then continue end
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end
        for _, podium in ipairs(podiums:GetChildren()) do
            pcall(function()
                local base = podium:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local dist = (spawn.Position - root.Position).Magnitude
                    local att = spawn:FindFirstChild("PromptAttachment")
                    if att then
                        for _, ch in ipairs(att:GetChildren()) do
                            if ch:IsA("ProximityPrompt") then
                                table.insert(cachedPrompts, {prompt = ch, spawn = spawn, name = podium.Name})
                                if dist <= Settings.StealRadius and dist < nearestDist then
                                    nearestPrompt = ch
                                    nearestDist = dist
                                    nearestName = podium.Name
                                end
                                break
                            end
                        end
                    end
                end
            end)
        end
    end
    return nearestPrompt, nearestDist, nearestName
end

local function executeSteal(prompt, name)
    local currentTime = tick()
    if currentTime - lastStealTick < STEAL_COOLDOWN then return end
    if isStealing then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        pcall(function()
            if getconnections then
                for _, connection in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if connection.Function then table.insert(StealData[prompt].hold, connection.Function) end
                end
                for _, connection in ipairs(getconnections(prompt.Triggered)) do
                    if connection.Function then table.insert(StealData[prompt].trigger, connection.Function) end
                end
            else
                StealData[prompt].useFallback = true
            end
        end)
    end

    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    stealStartTime = currentTime
    lastStealTick = currentTime

    if ProgressLabel then ProgressLabel.Text = name or "STEALING..." end
    if Connections.stealProgress then Connections.stealProgress:Disconnect() end
    Connections.stealProgress = RunService.Heartbeat:Connect(function()
        if not isStealing then
            Connections.stealProgress:Disconnect()
            Connections.stealProgress = nil
            return
        end
        local progress = math.clamp((tick() - stealStartTime) / Settings.StealDuration, 0, 1)
        if ProgressBarFill then ProgressBarFill.Size = UDim2.new(progress, 0, 1, 0) end
        if ProgressPercentLabel then ProgressPercentLabel.Text = math.floor(progress * 100) .. "%" end
    end)

    task.spawn(function()
        local ok = false
        pcall(function()
            if not data.useFallback then
                for _, func in ipairs(data.hold) do task.spawn(func) end
                task.wait(Settings.StealDuration)
                for _, func in ipairs(data.trigger) do task.spawn(func) end
                ok = true
            end
        end)
        if not ok and fireproximityprompt then
            pcall(function()
                fireproximityprompt(prompt)
                ok = true
            end)
        end
        if not ok then
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(Settings.StealDuration)
                prompt:InputHoldEnd()
                ok = true
            end)
        end
        task.wait(Settings.StealDuration * 0.3)
        if Connections.stealProgress then
            Connections.stealProgress:Disconnect()
            Connections.stealProgress = nil
        end
        resetStealProgressBar()
        task.wait(0.05)
        data.ready = true
        isStealing = false
    end)
end

function startAutoSteal()
    if Connections.autoSteal then return end
    Settings.AutoStealEnabled = true
    Connections.autoSteal = RunService.Heartbeat:Connect(function()
        if not Enabled.AutoSteal or isStealing then return end
        local prompt, _, name = findNearestPrompt()
        if prompt then
            local c = Player.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
            executeSteal(prompt, name)
        end
    end)
end

function stopAutoSteal()
    if Connections.autoSteal then Connections.autoSteal:Disconnect() Connections.autoSteal = nil end
    if Connections.stealProgress then Connections.stealProgress:Disconnect() Connections.stealProgress = nil end
    Settings.AutoStealEnabled = false
    isStealing = false
    lastStealTick = 0
    plotCache = {}
    plotCacheTime = {}
    cachedPrompts = {}
    resetStealProgressBar()
end

local function enableSpamBatFromAimbot()
    if Enabled.SpamBat then return end
    Enabled.SpamBat = true
    if VisualSetters.SpamBat then VisualSetters.SpamBat(true, true) end
    if floatButtonReferences.SpamBat then floatButtonReferences.SpamBat(true) end
    startSpamBat()
end

local function disableSpamBatFromAimbot()
    if not Enabled.SpamBat then return end
    Enabled.SpamBat = false
    if VisualSetters.SpamBat then VisualSetters.SpamBat(false, true) end
    if floatButtonReferences.SpamBat then floatButtonReferences.SpamBat(false) end
    stopSpamBat()
end

local function isCountdownLabelText(text)
    local n = tonumber(text)
    return n and n >= 1 and n <= 5
end

local function getCountdownLabel()
    local playerGui = Player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end

    local paths = {
        {"DuelsMachineTopFrame", "DuelsMachineTopFrame", "Timer", "Label"},
        {"DuelsMachineTopFrame", "Timer", "Label"},
    }

    for _, path in ipairs(paths) do
        local node = playerGui
        local ok = true
        for _, part in ipairs(path) do
            node = node and node:FindFirstChild(part)
            if not node then
                ok = false
                break
            end
        end
        if ok and node and node:IsA("TextLabel") then
            return node
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "Label" and desc.Parent and desc.Parent.Name == "Timer" then
            return desc
        end
    end
    return nil
end

local function triggerCountdownAutoPlay()
    local side = countdownPreferredSide
    if not side then
        side = "right"
    end
    if side == "left" then
        Enabled.AutoLeft = true
        Enabled.AutoRight = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(true, true) end
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
        stopStealPath()
        startStealPath(stealPath_Left)
    else
        Enabled.AutoRight = true
        Enabled.AutoLeft = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(true, true) end
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
        stopStealPath()
        startStealPath(stealPath_Right)
    end
end

local function monitorCountdownSound(sound)
    if countdownAutoActive or not countdownAutoEnabled then return end
    if not sound or sound.Name ~= "Countdown" or not sound:IsA("Sound") then return end
    countdownAutoActive = true
    local triggered = false
    local conn
    local function cleanup()
        countdownAutoActive = false
        if conn then conn:Disconnect() conn = nil end
    end
    local function maybeTrigger()
        if not countdownAutoEnabled then
            cleanup()
            return
        end
        local t = sound.TimePosition
        if t >= 4.9 and not triggered then
            triggered = true
            cleanup()
            triggerCountdownAutoPlay()
        elseif t > 6.9 then
            cleanup()
        end
    end
    conn = sound:GetPropertyChangedSignal("TimePosition"):Connect(function()
        maybeTrigger()
    end)
    task.spawn(function()
        while countdownAutoEnabled and sound.Parent and not triggered do
            maybeTrigger()
            task.wait(0.03)
        end
        if not triggered then
            cleanup()
        end
    end)
end

local function monitorCountdownLabel(label)
    if not label or not label:IsA("TextLabel") then return end
    local fired = false
    local function handleText()
        if not countdownAutoEnabled then
            fired = false
            return
        end
        local text = tostring(label.Text or ""):gsub("%s+", "")
        if isCountdownLabelText(text) and tonumber(text) == 1 and not fired then
            fired = true
            task.delay(0.65, function()
                if countdownAutoEnabled then
                    triggerCountdownAutoPlay()
                end
            end)
        elseif not isCountdownLabelText(text) then
            fired = false
        end
    end
    handleText()
    label:GetPropertyChangedSignal("Text"):Connect(handleText)
end

workspace.DescendantAdded:Connect(function(child)
    if child.Name == "Countdown" and child:IsA("Sound") then
        monitorCountdownSound(child)
    end
end)

do
    for _, existingCountdown in ipairs(workspace:GetDescendants()) do
        if existingCountdown.Name == "Countdown" and existingCountdown:IsA("Sound") then
            monitorCountdownSound(existingCountdown)
        end
    end
end

task.spawn(function()
    local label = getCountdownLabel()
    if label then
        monitorCountdownLabel(label)
    end
end)

Player.CharacterAdded:Connect(function()
    task.delay(1, function()
        local label = getCountdownLabel()
        if label then
            monitorCountdownLabel(label)
        end
    end)
end)

local walkFlingConnections = {}
local walkFlingActive = false

local function startWalkFling()
    walkFlingActive = true
    table.insert(walkFlingConnections, RunService.Stepped:Connect(function()
        if not walkFlingActive then return end
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= Player and otherPlayer.Character then
                for _, part in ipairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end))
    local flingThread = task.spawn(function()
        while walkFlingActive do
            RunService.Heartbeat:Wait()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                RunService.Heartbeat:Wait()
                continue
            end
            local velocity = hrp.Velocity
            hrp.Velocity = velocity * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()
            if hrp and hrp.Parent then
                hrp.Velocity = velocity
            end
            RunService.Stepped:Wait()
            if hrp and hrp.Parent then
                hrp.Velocity = velocity + Vector3.new(0, 0.1, 0)
            end
        end
    end)
    table.insert(walkFlingConnections, flingThread)
end

local function stopWalkFling()
    walkFlingActive = false
    for _, connection in ipairs(walkFlingConnections) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        elseif typeof(connection) == "thread" then
            pcall(task.cancel, connection)
        end
    end
    walkFlingConnections = {}
end

-- Lazy Auto Play
local STEAL_PATH_VELOCITY_SPEED = 60
local STEAL_PATH_SECOND_SPEED = 29

local stealPath_Right = { side = "right" }
local stealPath_Left = { side = "left" }

local lazyAutoPlayConnectionLeft = nil
local lazyAutoPlayConnectionRight = nil
local lazyAutoPlayPhaseLeft = 1
local lazyAutoPlayPhaseRight = 1

local lazyAutoPlayWaypoints = {
    Left = {
        Vector3.new(-476.2, -6.5, 94.8),
        Vector3.new(-484.1, -4.7, 94.7),
        Vector3.new(-476.5, -6.1, 7.5),
    },
    Right = {
        Vector3.new(-476.2, -6.1, 25.8),
        Vector3.new(-484.1, -4.7, 25.9),
        Vector3.new(-476.2, -6.2, 113.5),
    },
}
local lazyAutoPlayBaseWaypoints = {
    Left = {
        Vector3.new(-476.2, -6.5, 94.8),
        Vector3.new(-484.1, -4.7, 94.7),
        Vector3.new(-476.5, -6.1, 7.5),
    },
    Right = {
        Vector3.new(-476.2, -6.1, 25.8),
        Vector3.new(-484.1, -4.7, 25.9),
        Vector3.new(-476.2, -6.2, 113.5),
    },
}
local function rebuildLazyWaypointPositions()
    for groupName, points in pairs(lazyAutoPlayBaseWaypoints) do
        for index, basePoint in ipairs(points) do
            lazyAutoPlayWaypoints[groupName][index] = basePoint + (wpOffsets[groupName][index] or Vector3.zero)
        end
    end
    refreshWaypointESPVisuals()
end

local function formatWaypointNumber(value)
    local rounded = math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
    return string.format("%.2f", rounded)
end

local function refreshWaypointEditorRows()
    for _, binding in ipairs(waypointRowBindings) do
        local point = lazyAutoPlayWaypoints[binding.group][binding.idx] or Vector3.zero
        binding.boxes[1].Text = formatWaypointNumber(point.X)
        binding.boxes[2].Text = formatWaypointNumber(point.Y)
        binding.boxes[3].Text = formatWaypointNumber(point.Z)
    end
end

rebuildLazyWaypointPositions()

local function updateStealPathProgress(stage, progress)
    if ProgressLabel then
        ProgressLabel.Text = stage or "READY"
    end
    if ProgressPercentLabel then
        ProgressPercentLabel.Text = (progress and progress > 0) and (tostring(math.floor(progress * 100 + 0.5)) .. "%") or ""
    end
    if ProgressBarFill then
        ProgressBarFill.Size = UDim2.new(math.clamp(progress or 0, 0, 1), 0, 1, 0)
    end
end

local function faceAutoPlayYaw(yawDegrees)
    if Enabled.Helicopter then return end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(yawDegrees), 0)
    end
end

local function disconnectLazyAutoPlay(side)
    local connection = side == "left" and lazyAutoPlayConnectionLeft or lazyAutoPlayConnectionRight
    if connection then
        connection:Disconnect()
    end
    if side == "left" then
        lazyAutoPlayConnectionLeft = nil
        lazyAutoPlayPhaseLeft = 1
    else
        lazyAutoPlayConnectionRight = nil
        lazyAutoPlayPhaseRight = 1
    end
end

local function stopLazyAutoPlaySide(side, keepState)
    disconnectLazyAutoPlay(side)
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum then
        hum:Move(Vector3.zero, false)
    end
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if keepState then return end

    if side == "left" then
        Enabled.AutoLeft = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
    else
        Enabled.AutoRight = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
    end
    refreshAllBoxButtonStates()
    updateStealPathProgress("READY", 0)
end

local function getLazyAutoPlaySpeed(carryPhase)
    if carryPhase then
        return getEclipseSpeed(Values.StealPathReturnSpeed, 1, 90)
    end
    return getEclipseSpeed(Values.StealPathSpeed, 1, 120)
end

function startStealPath(path)
    local side = (path == stealPath_Left or (type(path) == "table" and path.side == "left")) and "left" or "right"
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    STEAL_PATH_VELOCITY_SPEED = Values.StealPathSpeed
    STEAL_PATH_SECOND_SPEED = Values.StealPathReturnSpeed

    disconnectLazyAutoPlay("left")
    disconnectLazyAutoPlay("right")

    if side == "left" then
        countdownPreferredSide = "left"
        Enabled.AutoLeft = true
        Enabled.AutoRight = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(true, true) end
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
        lazyAutoPlayPhaseLeft = 1
    else
        countdownPreferredSide = "right"
        Enabled.AutoRight = true
        Enabled.AutoLeft = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(true, true) end
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
        lazyAutoPlayPhaseRight = 1
    end
    refreshAllBoxButtonStates()
    updateStealPathProgress(side == "left" and "LAZY AUTO PLAY LEFT" or "LAZY AUTO PLAY RIGHT", 0.08)

    local stuckTimer = 0
    local lastPos = nil
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        local c = Player.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or not hrp.Parent then return end

        local enabled = side == "left" and Enabled.AutoLeft or Enabled.AutoRight
        if not enabled then
            stopLazyAutoPlaySide(side)
            return
        end

        local points = side == "left" and lazyAutoPlayWaypoints.Left or lazyAutoPlayWaypoints.Right
        local phase = side == "left" and lazyAutoPlayPhaseLeft or lazyAutoPlayPhaseRight
        local targetIndex = phase == 4 and 3 or math.min(phase, 2)
        local target = points[targetIndex]
        local planarTarget = Vector3.new(target.X, hrp.Position.Y, target.Z)
        local delta = planarTarget - hrp.Position
        local dist = delta.Magnitude

        if side == "right" then
            local curPos = hrp.Position
            if lastPos then
                if (curPos - lastPos).Magnitude < 0.05 then
                    stuckTimer += dt
                else
                    stuckTimer = 0
                end
            end
            lastPos = curPos
        end

        if phase == 1 then
            if dist < 1.5 then
                if side == "left" then lazyAutoPlayPhaseLeft = 2 else lazyAutoPlayPhaseRight = 2 end
                updateStealPathProgress("PICKUP", 0.25)
                stuckTimer = 0
                return
            end
            local dir = Vector3.new(delta.X, 0, delta.Z).Unit
            local speed = getLazyAutoPlaySpeed(false)
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Z * speed)
        elseif phase == 2 then
            if dist < 1.5 then
                if side == "left" then lazyAutoPlayPhaseLeft = 3 else lazyAutoPlayPhaseRight = 3 end
                updateStealPathProgress("CARRY", 0.5)
                stuckTimer = 0
                return
            end
            if side == "right" and stuckTimer > 0.4 then
                stuckTimer = 0
                local snap = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
                if snap.Magnitude > 0 then
                    hrp.CFrame = CFrame.new(hrp.Position + snap.Unit * math.min(4, snap.Magnitude))
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
                return
            end
            local dir = Vector3.new(delta.X, 0, delta.Z).Unit
            local speed = getLazyAutoPlaySpeed(true)
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Z * speed)
        elseif phase == 3 then
            local returnTarget = points[1]
            local returnDelta = Vector3.new(returnTarget.X, hrp.Position.Y, returnTarget.Z) - hrp.Position
            if returnDelta.Magnitude < 1.5 then
                if side == "left" then lazyAutoPlayPhaseLeft = 4 else lazyAutoPlayPhaseRight = 4 end
                updateStealPathProgress("RETURN", 0.75)
                return
            end
            local dir = Vector3.new(returnDelta.X, 0, returnDelta.Z).Unit
            local speed = getLazyAutoPlaySpeed(true)
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Z * speed)
        elseif phase == 4 then
            if dist < 1.5 then
                hum:Move(Vector3.zero, false)
                hrp.AssemblyLinearVelocity = Vector3.zero
                faceAutoPlayYaw(side == "left" and 0 or 180)
                stopLazyAutoPlaySide(side)
                return
            end
            local dir = Vector3.new(delta.X, 0, delta.Z).Unit
            local speed = getLazyAutoPlaySpeed(true)
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Z * speed)
        end
    end)

    if side == "left" then
        lazyAutoPlayConnectionLeft = connection
    else
        lazyAutoPlayConnectionRight = connection
    end
end

function stopStealPath()
    stopLazyAutoPlaySide("left")
    stopLazyAutoPlaySide("right")
end

local waypointESPFolder = nil

refreshWaypointESPVisuals = function()
    if waypointESPFolder then
        waypointESPFolder:Destroy()
        waypointESPFolder = nil
    end
    if not Enabled.WaypointESP then return end

    waypointESPFolder = Instance.new("Folder")
    waypointESPFolder.Name = "F7WaypointESP"
    waypointESPFolder.Parent = workspace

    local pointColors = {
        Left = PURPLE_LIGHT,
        Right = STARLIGHT,
    }

    for groupName, points in pairs(lazyAutoPlayWaypoints) do
        for index, point in ipairs(points) do
            local anchor = Instance.new("Part")
            anchor.Name = groupName .. "Waypoint" .. tostring(index)
            anchor.Anchored = true
            anchor.CanCollide = false
            anchor.CanQuery = false
            anchor.CanTouch = false
            anchor.Material = Enum.Material.Neon
            anchor.Shape = Enum.PartType.Ball
            anchor.Size = Vector3.new(0.9, 0.9, 0.9)
            anchor.Color = pointColors[groupName] or SOFT_PINK
            anchor.Transparency = 0.15
            anchor.Position = point
            anchor.Parent = waypointESPFolder

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "Label"
            billboard.Size = UDim2.new(0, 90, 0, 24)
            billboard.StudsOffset = Vector3.new(0, 1.4, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = anchor

            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 11
            label.TextStrokeTransparency = 0.35
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Text = string.format("%s%d", groupName == "Left" and "L" or "R", index)
            label.Parent = billboard
        end
    end
end

function startWaypointESP()
    Enabled.WaypointESP = true
    refreshWaypointESPVisuals()
end

function stopWaypointESP()
    Enabled.WaypointESP = false
    refreshWaypointESPVisuals()
end

-- ============================================================
-- UI CONSTRUCTION – SINGLE VERTICAL COLUMN
-- ============================================================
local function refreshSliderValue(valueKey)
    local callbacks = SliderDisplayCallbacks[valueKey]
    if not callbacks then return end
    for _, callback in ipairs(callbacks) do
        pcall(callback, Values[valueKey])
    end
end

local function getCurrentHumanoid()
    local character = Player.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function startLaggerCounter()
    if not LaggerCounterSnapshot then
        local hum = getCurrentHumanoid()
        LaggerCounterSnapshot = {
            BoostSpeed = Values.BoostSpeed,
            StealingSpeedValue = Values.StealingSpeedValue,
            StealPathSpeed = Values.StealPathSpeed,
            StealPathReturnSpeed = Values.StealPathReturnSpeed,
            WalkSpeed = hum and hum.WalkSpeed or 16,
        }
    end

    Values.BoostSpeed = LAGGER_COUNTER_SPEED
    Values.StealingSpeedValue = LAGGER_COUNTER_SPEED
    Values.StealPathSpeed = LAGGER_COUNTER_SPEED
    Values.StealPathReturnSpeed = LAGGER_COUNTER_SPEED
    STEAL_PATH_SECOND_SPEED = LAGGER_COUNTER_SPEED
    STEAL_PATH_VELOCITY_SPEED = LAGGER_COUNTER_SPEED

    refreshSliderValue("BoostSpeed")
    refreshSliderValue("StealingSpeedValue")
    refreshSliderValue("StealPathSpeed")

    if Connections.laggerCounter then
        Connections.laggerCounter:Disconnect()
        Connections.laggerCounter = nil
    end

    Connections.laggerCounter = RunService.Heartbeat:Connect(function()
        if not Enabled.LaggerCounter then return end
        local hum = getCurrentHumanoid()
        if hum and hum.WalkSpeed ~= LAGGER_COUNTER_SPEED then
            hum.WalkSpeed = LAGGER_COUNTER_SPEED
        end
    end)
end

function stopLaggerCounter()
    if Connections.laggerCounter then
        Connections.laggerCounter:Disconnect()
        Connections.laggerCounter = nil
    end

    local snapshot = LaggerCounterSnapshot
    if snapshot then
        Values.BoostSpeed = snapshot.BoostSpeed or Values.BoostSpeed
        Values.StealingSpeedValue = snapshot.StealingSpeedValue or Values.StealingSpeedValue
        Values.StealPathSpeed = snapshot.StealPathSpeed or Values.StealPathSpeed
        Values.StealPathReturnSpeed = snapshot.StealPathReturnSpeed or Values.StealingSpeedValue

        STEAL_PATH_SECOND_SPEED = Values.StealingSpeedValue
        STEAL_PATH_VELOCITY_SPEED = Values.StealPathSpeed

        refreshSliderValue("BoostSpeed")
        refreshSliderValue("StealingSpeedValue")
        refreshSliderValue("StealPathSpeed")

        local hum = getCurrentHumanoid()
        if hum then
            hum.WalkSpeed = snapshot.WalkSpeed or 16
        end
    end

    LaggerCounterSnapshot = nil
end

local GuiParent = CoreGui
pcall(function()
    if type(gethui) == "function" then
        local candidate = gethui()
        if candidate and typeof(candidate) == "Instance" then
            GuiParent = candidate
        end
    end
end)
pcall(function()
    if (not GuiParent) or typeof(GuiParent) ~= "Instance" then
        local playerGui = Player:FindFirstChildOfClass("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
        if playerGui then
            GuiParent = playerGui
        else
            GuiParent = CoreGui
        end
    end
end)
if (not GuiParent) or typeof(GuiParent) ~= "Instance" then
    GuiParent = CoreGui
end

local function destroyExistingGui(guiName)
    local coreGuiMatch = CoreGui:FindFirstChild(guiName)
    if coreGuiMatch then
        coreGuiMatch:Destroy()
    end
    if GuiParent and GuiParent ~= CoreGui then
        local altMatch = GuiParent:FindFirstChild(guiName)
        if altMatch then
            altMatch:Destroy()
        end
    end
end

local function buildGui()
destroyExistingGui("LegitsDuels")
destroyExistingGui("EcpliseDuels")
destroyExistingGui("ZeroHub")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LegitsDuels"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

clearThemeCallbacks()
local palette = getThemePalette()

-- Colors
local PURPLE       = palette.accent
local PURPLE_LIGHT = palette.light
local PURPLE_DARK  = palette.dark
local BG_DARK      = lerpColor3(palette.dark, Color3.fromRGB(4, 5, 7), 0.55)
local SECTION_BG   = lerpColor3(palette.dark, Color3.fromRGB(18, 20, 24), 0.35)
local STARLIGHT    = palette.starlight
local SUNSET       = palette.sunset
local SOFT_PINK    = lerpColor3(palette.accent, palette.light, 0.18)
local SOFT_PINK_2  = lerpColor3(palette.light, Color3.fromRGB(255, 255, 255), 0.22)
local SHELL_TEXT   = lerpColor3(Color3.fromRGB(255, 255, 255), palette.light, 0.18)
local SHELL_SUB    = lerpColor3(Color3.fromRGB(172, 178, 190), palette.accent, 0.3)

local function syncThemeLocals(themePalette)
    PURPLE = themePalette.accent
    PURPLE_LIGHT = themePalette.light
    PURPLE_DARK = themePalette.dark
    STARLIGHT = themePalette.starlight
    SUNSET = themePalette.sunset
    BG_DARK = lerpColor3(themePalette.dark, Color3.fromRGB(4, 5, 7), 0.55)
    SECTION_BG = lerpColor3(themePalette.dark, Color3.fromRGB(18, 20, 24), 0.35)
    SOFT_PINK = lerpColor3(themePalette.accent, themePalette.light, 0.18)
    SOFT_PINK_2 = lerpColor3(themePalette.light, Color3.fromRGB(255, 255, 255), 0.22)
    SHELL_TEXT = lerpColor3(Color3.fromRGB(255, 255, 255), themePalette.light, 0.18)
    SHELL_SUB = lerpColor3(Color3.fromRGB(172, 178, 190), themePalette.accent, 0.3)
end

local PANEL_W      = 340
local PANEL_H      = 340
local BANNER_H     = 96
local TOGGLE_H     = 32
local SLIDER_H     = 44
local SECTION_H    = 22
local FONT_TITLE   = 18
local FONT_SECTION = 11
local FONT_TOGGLE  = 10
local FONT_SLIDER  = 9
local TOGGLE_W     = 32
local TOGGLE_H2    = 16
local DOT_S        = 11
local PBAR_W       = 320
local PBAR_H       = 42

local function Create(className, properties, children)
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do inst[k] = v end
    for _, child in pairs(children or {}) do child.Parent = inst end
    return inst
end

local MainContainer = Create("Frame", {
    Name = "MainContainer",
    BackgroundTransparency = 1,
    Position = UDim2.new(0.5, -(PANEL_W / 2), 0.5, -(PANEL_H / 2)),
    Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
    Parent = ScreenGui
})
local MainGuiScale = Create("UIScale", {
    Scale = math.clamp(Values.GuiScale or 1, 0.6, 1),
    Parent = MainContainer
})

Create("Frame", {
    BackgroundColor3 = Color3.fromRGB(130, 96, 116),
    BackgroundTransparency = 0.82,
    Position = UDim2.new(0, 12, 0, 16),
    Size = UDim2.new(1, 0, 1, 0),
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = MainContainer
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 18)})
})

Create("Frame", {
    BackgroundColor3 = SOFT_PINK,
    BackgroundTransparency = 0.88,
    Position = UDim2.new(0, -10, 0, -10),
    Size = UDim2.new(1, 20, 1, 20),
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = MainContainer
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 24)}),
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, SOFT_PINK),
            ColorSequenceKeypoint.new(0.45, SOFT_PINK_2),
            ColorSequenceKeypoint.new(1, SOFT_PINK),
        }),
        Rotation = 35
    })
})

local PanelFrame = Create("Frame", {
    Name = "PanelFrame",
    BackgroundColor3 = BG_DARK,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    ClipsDescendants = true,
    Parent = MainContainer
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 18)})
})

local panelStroke = Create("UIStroke", {
    Color = PURPLE,
    Thickness = 2.5,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Transparency = 0.08,
    Parent = PanelFrame
})
local panelStrokeGradient = Create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, PURPLE_LIGHT),
        ColorSequenceKeypoint.new(0.45, STARLIGHT),
        ColorSequenceKeypoint.new(1, PURPLE),
    }),
    Rotation = 0,
    Parent = panelStroke
})
registerThemeCallback(function(themePalette)
    syncThemeLocals(themePalette)
    panelStroke.Color = PURPLE
    panelStrokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, SOFT_PINK_2),
        ColorSequenceKeypoint.new(0.45, SOFT_PINK),
        ColorSequenceKeypoint.new(1, SOFT_PINK_2),
    })
end)

Create("Frame", {
    BackgroundColor3 = BG_DARK,
    Size = UDim2.new(1, 0, 1, 0),
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = PanelFrame
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 18)}),
    Create("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 17, 30)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(18, 28, 48)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(13, 21, 38)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 16, 30))
        },
        Rotation = 145
    })
})

Create("Frame", {
    BackgroundColor3 = PURPLE,
    BackgroundTransparency = 0.9,
    Position = UDim2.new(0, -12, 0, -24),
    Size = UDim2.new(1, 24, 0, 84),
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = PanelFrame
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, PURPLE),
            ColorSequenceKeypoint.new(0.7, STARLIGHT),
            ColorSequenceKeypoint.new(1, SUNSET),
        }),
        Rotation = 25
    })
})

local particleBg = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), ZIndex=1, Parent=PanelFrame})
for i = 1, 26 do
    local sz = math.random(2, 5)
    local p = Create("Frame", {
        BackgroundColor3 = math.random(1,3) == 1 and STARLIGHT or (math.random(1,2)==1 and PURPLE or PURPLE_LIGHT),
        BorderSizePixel = 0,
        Size = UDim2.new(0, sz, 0, sz),
        Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0),
        BackgroundTransparency = math.random(40,75)/100,
        ZIndex = 1,
        Parent = particleBg
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})
    task.spawn(function()
        while p and p.Parent do
            TweenService:Create(p, TweenInfo.new(math.random(15,35)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = math.random(20,80)/100,
                Size = UDim2.new(0, math.random(2,6), 0, math.random(2,6))
            }):Play()
            task.wait(math.random(15,35)/10)
        end
    end)
end

task.spawn(function()
    local r = 0
    while PanelFrame.Parent do
        r = (r + 1) % 360
        panelStrokeGradient.Rotation = r
        task.wait(0.03)
    end
end)

local chSize = 56
local chCircle = Instance.new("Frame")
chCircle.Name = "ED_Logo"
chCircle.Size = UDim2.new(0, chSize, 0, chSize)
chCircle.Position = UDim2.new(0.5, (PANEL_W / 2) + 14, 0.5, -(PANEL_H / 2) + 6)
chCircle.BackgroundColor3 = Color3.fromRGB(11, 13, 24)
chCircle.BorderSizePixel = 0
chCircle.ZIndex = 50
chCircle.Parent = ScreenGui
Instance.new("UICorner", chCircle).CornerRadius = UDim.new(1, 0)
local chCore = Create("Frame", {
    BackgroundColor3 = Color3.fromRGB(4, 5, 10),
    BackgroundTransparency = 0.08,
    Size = UDim2.new(1, -10, 1, -10),
    Position = UDim2.new(0, 5, 0, 5),
    BorderSizePixel = 0,
    ZIndex = 50,
    Parent = chCircle
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)})
})
local chStroke = Instance.new("UIStroke", chCircle)
chStroke.Thickness = 2.5
chStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local chGrad = Instance.new("UIGradient", chStroke)
chGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    PURPLE_LIGHT),
    ColorSequenceKeypoint.new(0.4,  STARLIGHT),
    ColorSequenceKeypoint.new(1,    PURPLE),
})
registerThemeCallback(function(themePalette)
    syncThemeLocals(themePalette)
    chGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, PURPLE_LIGHT),
        ColorSequenceKeypoint.new(0.4, STARLIGHT),
        ColorSequenceKeypoint.new(1, PURPLE),
    })
    chStroke.Color = PURPLE
end)
task.spawn(function()
    local r = 0
    while chCircle.Parent do
        r = (r + 2) % 360
        chGrad.Rotation = r
        task.wait(0.02)
    end
end)
local chText = Instance.new("TextLabel", chCircle)
chText.BackgroundTransparency = 1
chText.Size = UDim2.new(1, 0, 1, 0)
chText.Font = Enum.Font.GothamBlack
chText.Text = "F7"
chText.TextColor3 = Color3.fromRGB(255, 255, 255)
chText.TextSize = 20
chText.ZIndex = 51
local chBtn = Instance.new("TextButton", chCircle)
chBtn.Size = UDim2.new(1, 0, 1, 0)
chBtn.BackgroundTransparency = 1
chBtn.Text = ""
chBtn.ZIndex = 52
local uiVisible = true
chBtn.MouseButton1Click:Connect(function()
    if cMoved then cMoved = false return end
    uiVisible = not uiVisible
    MainContainer.Visible = uiVisible
    TweenService:Create(chCircle, TweenInfo.new(0.2), {
        BackgroundColor3 = uiVisible and Color3.fromRGB(11, 13, 24) or Color3.fromRGB(34, 20, 16)
    }):Play()
    TweenService:Create(chCore, TweenInfo.new(0.2), {
        BackgroundTransparency = uiVisible and 0.08 or 0.25
    }):Play()
end)

local cDrag, cDragStart, cDragPos, cMoved = false, nil, nil, false
chBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        cDrag = true
        cMoved = false
        cDragStart = input.Position
        cDragPos = chCircle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then cDrag = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if cDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - cDragStart
        if delta.Magnitude > 4 then
            cMoved = true
            chCircle.Position = UDim2.new(cDragPos.X.Scale, cDragPos.X.Offset + delta.X, cDragPos.Y.Scale, cDragPos.Y.Offset + delta.Y)
        end
    end
end)

local TitleBar = Create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, BANNER_H),
    ZIndex = 10,
    Parent = PanelFrame
})
local TitleLabel = Create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -128, 0, 24),
    Position = UDim2.new(0, 14, 0, 8),
    Font = Enum.Font.GothamBlack,
    Text = "F7 DUELS",
    TextColor3 = PURPLE,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 11,
    Parent = TitleBar
})
local SubtitleLabel = Create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -128, 0, 14),
    Position = UDim2.new(0, 14, 0, 30),
    Font = Enum.Font.GothamBold,
    Text = "made by GOJO",
    TextColor3 = Color3.fromRGB(173, 200, 230),
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 11,
    Parent = TitleBar
})
local PremiumLabel = Create("TextLabel", {
    BackgroundColor3 = Color3.fromRGB(12, 21, 42),
    Size = UDim2.new(0, 54, 0, 18),
    Position = UDim2.new(1, -92, 0, 10),
    Font = Enum.Font.GothamBold,
    Text = "PREMIUM",
    TextColor3 = PURPLE_LIGHT,
    TextSize = 8,
    ZIndex = 12,
    Parent = TitleBar
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
    Create("UIStroke", {Color = STARLIGHT, Thickness = 1.25, Transparency = 0.25})
})
local CloseBtn = Create("TextButton", {
    BackgroundColor3 = Color3.fromRGB(16, 31, 54),
    Position = UDim2.new(1, -32, 0, 10),
    Size = UDim2.new(0, 20, 0, 20),
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Color3.new(1,1,1),
    TextSize = 10,
    ZIndex = 12,
    Parent = TitleBar
}, {
    Create("UICorner", {CornerRadius=UDim.new(1,0)}),
    Create("UIStroke", {Color=SUNSET, Thickness=1.75})
})
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
local TitleDivider = Create("Frame", {
    BackgroundColor3 = PURPLE,
    BackgroundTransparency = 0.2,
    Position = UDim2.new(0, 12, 0, 48),
    Size = UDim2.new(1, -24, 0, 2),
    ZIndex = 10,
    Parent = PanelFrame
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, PURPLE),
            ColorSequenceKeypoint.new(0.55, STARLIGHT),
            ColorSequenceKeypoint.new(1, PURPLE_LIGHT),
        }),
        Rotation = 0
    })
})

local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainContainer.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local currentTab = "FEATURES"
local TabFrames = {}
local TabButtons = {}

local TabBar = Create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 58),
    Size = UDim2.new(1, -24, 0, 28),
    ZIndex = 12,
    Parent = TitleBar
}, {
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
})

local WaveHolder = Create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 16, 0, 88),
    Size = UDim2.new(1, -32, 0, 12),
    ClipsDescendants = true,
    ZIndex = 11,
    Parent = TitleBar
})
local waveBars = {}
for i = 1, 18 do
    local bar = Create("Frame", {
        BackgroundColor3 = i % 2 == 0 and PURPLE or STARLIGHT,
        BackgroundTransparency = 0.18,
        Size = UDim2.new(0, 10, 0, 4),
        Position = UDim2.new(0, (i - 1) * 13, 0.5, -2),
        BorderSizePixel = 0,
        ZIndex = 11,
        Parent = WaveHolder
    }, {
        Create("UICorner", {CornerRadius = UDim.new(1, 0)})
    })
    table.insert(waveBars, bar)
end
registerThemeCallback(function(themePalette)
    syncThemeLocals(themePalette)
    TitleLabel.TextColor3 = PURPLE
    SubtitleLabel.TextColor3 = Color3.fromRGB(173, 200, 230)
    PremiumLabel.TextColor3 = PURPLE_LIGHT
    local premiumStroke = PremiumLabel:FindFirstChildOfClass("UIStroke")
    if premiumStroke then
        premiumStroke.Color = STARLIGHT
    end
    TitleDivider.BackgroundColor3 = PURPLE
    local dividerGradient = TitleDivider:FindFirstChildOfClass("UIGradient")
    if dividerGradient then
        dividerGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, PURPLE),
            ColorSequenceKeypoint.new(0.55, STARLIGHT),
            ColorSequenceKeypoint.new(1, PURPLE_LIGHT),
        })
    end
    for index, bar in ipairs(waveBars) do
        bar.BackgroundColor3 = index % 2 == 0 and PURPLE or STARLIGHT
    end
end)
task.spawn(function()
    while WaveHolder.Parent do
        local t = tick() * 2.4
        for index, bar in ipairs(waveBars) do
            local wave = math.sin(t + index * 0.55)
            bar.Position = UDim2.new(0, (index - 1) * 13, 0.5, math.floor(wave * 3))
            bar.Size = UDim2.new(0, 10, 0, 4 + math.abs(wave) * 5)
            bar.BackgroundTransparency = 0.12 + (math.abs(wave) * 0.18)
        end
        task.wait(0.03)
    end
end)

local function CreateTabScrollFrame()
    local scroll = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0, BANNER_H + 2),
        Size = UDim2.new(1, -12, 1, -(BANNER_H + 8)),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = PURPLE,
        BorderSizePixel = 0,
        ZIndex = 5,
        Visible = false,
        Parent = PanelFrame
    }, {
        Create("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center
        })
    })
    local layout = scroll:FindFirstChildOfClass("UIListLayout")
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)
    return scroll
end

local function setTab(tabName)
    currentTab = tabName
    for name, frame in pairs(TabFrames) do
        frame.Visible = name == tabName
    end
    for name, buttonFrame in pairs(TabButtons) do
        local active = name == tabName
        TweenService:Create(buttonFrame, TweenInfo.new(0.15), {
            BackgroundColor3 = active and PURPLE or Color3.fromRGB(18, 29, 50)
        }):Play()
        local stroke = buttonFrame:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = PURPLE
            TweenService:Create(stroke, TweenInfo.new(0.15), {
                Transparency = active and 0 or 0.35
            }):Play()
        end
        local label = buttonFrame:FindFirstChild("Label")
        if label then
            label.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(154, 171, 204)
        end
    end
end

local function CreateTabButton(tabName, order, width, textSize)
    local button = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(18, 29, 50),
        Size = UDim2.new(0, width, 1, 0),
        LayoutOrder = order,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 13,
        Parent = TabBar
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 8)}),
        Create("UIStroke", {Color = PURPLE, Thickness = 1.15, Transparency = 0.35})
    })
    Create("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = tabName,
        TextColor3 = Color3.fromRGB(154, 171, 204),
        TextSize = textSize or 8,
        ZIndex = 14,
        Parent = button
    })
    button.MouseButton1Click:Connect(function()
        setTab(tabName)
    end)
    TabButtons[tabName] = button
end

TabFrames.FEATURES = CreateTabScrollFrame()
TabFrames.KEYBINDS = CreateTabScrollFrame()
TabFrames.SETTINGS = CreateTabScrollFrame()
TabFrames.MOBILE = CreateTabScrollFrame()
TabFrames.AUTOPLAY = CreateTabScrollFrame()

CreateTabButton("FEATURES", 1, 70)
CreateTabButton("KEYBINDS", 2, 70)
CreateTabButton("SETTINGS", 3, 70)
CreateTabButton("MOBILE", 4, 58)
CreateTabButton("AUTOPLAY", 5, 64, 7)
setTab("FEATURES")
registerThemeCallback(function(themePalette)
    syncThemeLocals(themePalette)
    setTab(currentTab)
end)

local FeatureFrame = TabFrames.FEATURES
local KeybindFrame = TabFrames.KEYBINDS
local SettingsFrame = TabFrames.SETTINGS
local MobileFrame = TabFrames.MOBILE
local AutoPlayFrame = TabFrames.AUTOPLAY
local ScrollFrame = FeatureFrame

local function keyCodeToDisplay(keyCode)
    if not keyCode then return "--" end
    local aliases = {
        LeftControl = "LCtrl",
        RightControl = "RCtrl",
        LeftShift = "LShift",
        RightShift = "RShift",
        LeftAlt = "LAlt",
        RightAlt = "RAlt",
        Delete = "Del",
        Backspace = "Bksp",
        Space = "Space",
        One = "1",
        Two = "2",
        Three = "3",
        Four = "4",
        Five = "5",
        Six = "6",
        Seven = "7",
        Eight = "8",
        Nine = "9",
        Zero = "0",
    }
    return aliases[keyCode.Name] or keyCode.Name
end

local function registerKeybindDisplay(action, callback)
    KeybindDisplayCallbacks[action] = KeybindDisplayCallbacks[action] or {}
    table.insert(KeybindDisplayCallbacks[action], callback)
end

local function registerSliderDisplay(valueKey, callback)
    SliderDisplayCallbacks[valueKey] = SliderDisplayCallbacks[valueKey] or {}
    table.insert(SliderDisplayCallbacks[valueKey], callback)
end

local function refreshKeybindDisplays()
    for action, callbacks in pairs(KeybindDisplayCallbacks) do
        local waiting = activeRebindAction == action
        local displayText = waiting and "PRESS" or keyCodeToDisplay(KEYBINDS[action])
        for _, callback in ipairs(callbacks) do
            pcall(callback, displayText, waiting)
        end
    end
end

local function beginKeybindCapture(action)
    activeRebindAction = action
    refreshKeybindDisplays()
end

local function finishKeybindCapture(action, keyCode)
    KEYBINDS[action] = keyCode
    activeRebindAction = nil
    refreshKeybindDisplays()
    saveConfig()
end

local function cancelKeybindCapture()
    activeRebindAction = nil
    refreshKeybindDisplays()
end

local function CreateSection(parent, title, order)
    local sec = Create("Frame", {
        BackgroundColor3 = SECTION_BG,
        Size = UDim2.new(1, -4, 0, SECTION_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,12)}),
        Create("UIStroke", {Color=SOFT_PINK, Thickness=1.6, Transparency=0.08}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 251)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 238, 244)),
            }),
            Rotation = 0
        })
    })
    local secStroke = sec:FindFirstChildOfClass("UIStroke")
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-12,1,0),
        Position = UDim2.new(0,10,0,0),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = SHELL_TEXT,
        TextSize = FONT_SECTION,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = sec
    })
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        if secStroke then
            secStroke.Color = SOFT_PINK
        end
    end)
    return sec
end

local function CreateToggle(parent, labelText, enabledKey, callback, order, keybindAction)
    local offColor = Color3.fromRGB(251, 245, 248)
    local onColor = Color3.fromRGB(255, 236, 243)
    local row = Create("Frame", {
        BackgroundColor3 = Enabled[enabledKey] and onColor or offColor,
        Size = UDim2.new(1, -4, 0, TOGGLE_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,14)}),
        Create("UIStroke", {Color=SOFT_PINK, Thickness=1.6}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 20, 17)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 12, 10)),
            }),
            Rotation = 180
        })
    })
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(keybindAction and 0.5 or 0.65, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = SHELL_TEXT,
        TextSize = FONT_TOGGLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = row
    })

    if keybindAction then
        local keyBadge = Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(12, 18, 15),
            Size = UDim2.new(0, 48, 0, 18),
            Position = UDim2.new(1, -(TOGGLE_W + 60), 0.5, -9),
            BorderSizePixel = 0,
            ZIndex = 7,
            Parent = row
        }, {
            Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Create("UIStroke", {Color = SOFT_PINK, Thickness = 1.1, Transparency = 0.1})
        })
        local keyBadgeLabel = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = "",
            TextColor3 = SHELL_TEXT,
            TextSize = 8,
            ZIndex = 8,
            Parent = keyBadge
        })
        registerKeybindDisplay(keybindAction, function(displayText, waiting)
            keyBadgeLabel.Text = displayText
            TweenService:Create(keyBadge, TweenInfo.new(0.15), {
                BackgroundColor3 = waiting and SOFT_PINK_2 or Color3.fromRGB(12, 18, 15)
            }):Play()
        end)
    end

    local isOn = Enabled[enabledKey] or false
    local toggleBg = Create("Frame", {
        Size = UDim2.new(0, TOGGLE_W, 0, TOGGLE_H2),
        Position = UDim2.new(1, -(TOGGLE_W + 8), 0.5, -TOGGLE_H2/2),
        BackgroundColor3 = isOn and SOFT_PINK or Color3.fromRGB(229, 221, 228),
        ZIndex = 7,
        Parent = row
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})
    local toggleDot = Create("Frame", {
        Size = UDim2.new(0, DOT_S, 0, DOT_S),
        Position = isOn and UDim2.new(1,-(DOT_S+3),0.5,-DOT_S/2) or UDim2.new(0,3,0.5,-DOT_S/2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 8,
        Parent = toggleBg
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 9,
        Parent = row
    })
    local function setVisual(state, skipCb)
        isOn = state
        TweenService:Create(row, TweenInfo.new(0.2), {
            BackgroundColor3 = isOn and onColor or offColor
        }):Play()
        TweenService:Create(toggleBg, TweenInfo.new(0.25), {
            BackgroundColor3 = isOn and SOFT_PINK or Color3.fromRGB(229, 221, 228)
        }):Play()
        TweenService:Create(toggleDot, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Position = isOn and UDim2.new(1,-(DOT_S+3),0.5,-DOT_S/2) or UDim2.new(0,3,0.5,-DOT_S/2)
        }):Play()
        label.TextColor3 = SHELL_TEXT
        if boxMobileButtonReferences[enabledKey] then
            boxMobileButtonReferences[enabledKey](isOn)
        end
        if not skipCb then callback(isOn) end
    end
    VisualSetters[enabledKey] = setVisual
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        onColor = Color3.fromRGB(255, 236, 243)
        if rowStroke then
            rowStroke.Color = SOFT_PINK
        end
        setVisual(isOn, true)
    end)
    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        Enabled[enabledKey] = isOn
        setVisual(isOn)
    end)
    return row
end

local function CreateSlider(parent, labelText, minVal, maxVal, valueKey, callback, order)
    local enforcedByLaggerCounter = {
        BoostSpeed = true,
        StealingSpeedValue = true,
        StealPathSpeed = true,
    }
    local allowsDecimals = math.abs(minVal - math.floor(minVal)) > 0 or math.abs(maxVal - math.floor(maxVal)) > 0
    local container = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(251, 245, 248),
        Size = UDim2.new(1, -4, 0, SLIDER_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,14)}),
        Create("UIStroke", {Color=SOFT_PINK, Thickness=1.5}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 20, 17)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 12, 10)),
            }),
            Rotation = 180
        })
    })
    local containerStroke = container:FindFirstChildOfClass("UIStroke")
    local labelFrame = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.85, 0, 0, 16),
        Position = UDim2.new(0, 10, 0, 5),
        Font = Enum.Font.GothamBold,
        Text = labelText .. ": " .. tostring(Values[valueKey]),
        TextColor3 = SHELL_TEXT,
        TextSize = FONT_SLIDER,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = container
    })
    local sliderBg = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(235, 226, 232),
        Position = UDim2.new(0, 10, 0, 27),
        Size = UDim2.new(1, -20, 0, 10),
        ZIndex = 7,
        Parent = container
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})
    local pct = math.clamp((Values[valueKey] - minVal) / (maxVal - minVal), 0, 1)
    local fill = Create("Frame", {
        BackgroundColor3 = PURPLE,
        Size = UDim2.new(pct, 0, 1, 0),
        ZIndex = 8,
        Parent = sliderBg
    }, {
        Create("UICorner", {CornerRadius=UDim.new(1,0)}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, PURPLE),
                ColorSequenceKeypoint.new(1, STARLIGHT),
            }),
            Rotation = 0
        })
    })
    local fillGradient = fill:FindFirstChildOfClass("UIGradient")
    local knob = Create("Frame", {
        BackgroundColor3 = Color3.new(1,1,1),
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(pct, -6, 0.5, -6),
        ZIndex = 9,
        Parent = sliderBg
    }, {
        Create("UICorner", {CornerRadius=UDim.new(1,0)}),
        Create("UIStroke", {Color=SOFT_PINK, Thickness=2})
    })
    local knobStroke = knob:FindFirstChildOfClass("UIStroke")
    local sliderBtn = Create("TextButton", {
        Size = UDim2.new(1, 0, 3, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 10,
        Parent = sliderBg
    })
    local function setSliderValue(rawValue)
        local value = rawValue
        if Enabled.LaggerCounter and enforcedByLaggerCounter[valueKey] then
            value = LAGGER_COUNTER_SPEED
        end
        if allowsDecimals then
            value = math.clamp(math.floor(value * 100 + 0.5) / 100, minVal, maxVal)
        else
            value = math.clamp(math.floor(value + 0.5), minVal, maxVal)
        end
        local rel = math.clamp((value - minVal) / (maxVal - minVal), 0, 1)
        Values[valueKey] = value
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
        labelFrame.Text = labelText .. ": " .. (allowsDecimals and string.format("%.2f", value) or tostring(value))
        callback(value)
    end
    registerSliderDisplay(valueKey, setSliderValue)
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        if containerStroke then
            containerStroke.Color = SOFT_PINK
        end
        fill.BackgroundColor3 = SOFT_PINK
        if fillGradient then
            fillGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, SOFT_PINK),
                ColorSequenceKeypoint.new(1, SOFT_PINK_2),
            })
        end
        if knobStroke then
            knobStroke.Color = SOFT_PINK
        end
    end)
    local draggingSlider = false
    sliderBtn.MouseButton1Down:Connect(function() draggingSlider = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((inp.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            setSliderValue(minVal + (maxVal - minVal) * rel)
        end
    end)
    return container
end

local function CreateKeybindRow(parent, labelText, actionKey, order)
    local row = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(16, 18, 30),
        Size = UDim2.new(1, -4, 0, TOGGLE_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,10)}),
        Create("UIStroke", {Color=Color3.fromRGB(43, 48, 72), Thickness=1.4}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 22, 38)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 15, 26)),
            }),
            Rotation = 180
        })
    })
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = Color3.fromRGB(244, 233, 255),
        TextSize = FONT_TOGGLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = row
    })
    local bindStroke = Create("UIStroke", {
        Color = STARLIGHT,
        Thickness = 1.2,
        Transparency = 0.35
    })
    local bindButton = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(24, 27, 44),
        Size = UDim2.new(0, 76, 0, 22),
        Position = UDim2.new(1, -84, 0.5, -11),
        Font = Enum.Font.GothamBold,
        Text = "",
        TextColor3 = Color3.fromRGB(245, 247, 255),
        TextSize = 9,
        ZIndex = 8,
        Parent = row
    }, {
        Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
        bindStroke
    })
    bindButton.MouseButton1Click:Connect(function()
        beginKeybindCapture(actionKey)
    end)
    registerKeybindDisplay(actionKey, function(displayText, waiting)
        bindButton.Text = displayText
        TweenService:Create(bindButton, TweenInfo.new(0.15), {
            BackgroundColor3 = waiting and STARLIGHT or Color3.fromRGB(24, 27, 44)
        }):Play()
        TweenService:Create(bindStroke, TweenInfo.new(0.15), {
            Transparency = waiting and 0 or 0.35
        }):Play()
    end)
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        if rowStroke then
            rowStroke.Color = PURPLE_DARK
        end
        bindStroke.Color = STARLIGHT
    end)
    return row
end

local function CreateActionButton(parent, labelText, callback, order)
    local row = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(16, 18, 30),
        Size = UDim2.new(1, -4, 0, TOGGLE_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
        Create("UIStroke", {Color = PURPLE_DARK, Thickness = 1.4}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(21, 29, 47)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 18, 31)),
            }),
            Rotation = 180
        })
    })
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = Color3.fromRGB(244, 233, 255),
        TextSize = FONT_TOGGLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = row
    })
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 9,
        Parent = row
    })
    btn.MouseButton1Click:Connect(callback)
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        if rowStroke then
            rowStroke.Color = PURPLE_DARK
        end
        label.TextColor3 = Color3.fromRGB(244, 233, 255)
    end)
    return row
end

local pbar = Instance.new("Frame")
pbar.Size = UDim2.new(0, PBAR_W, 0, 44)
pbar.Position = UDim2.new(0.5, -PBAR_W/2, 1, -110)
pbar.BackgroundColor3 = Color3.fromRGB(10, 17, 14)
pbar.BorderSizePixel = 0
pbar.ZIndex = 10
pbar.Parent = ScreenGui
Instance.new("UICorner", pbar).CornerRadius = UDim.new(0, 14)
local pStroke = Instance.new("UIStroke", pbar)
pStroke.Thickness = 2.5
pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local pGrad = Instance.new("UIGradient", pStroke)
pGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, SOFT_PINK_2),
    ColorSequenceKeypoint.new(0.3, SOFT_PINK),
    ColorSequenceKeypoint.new(0.7, SOFT_PINK_2),
    ColorSequenceKeypoint.new(1, SOFT_PINK),
})
task.spawn(function()
    local r = 0
    while pbar.Parent do
        r = (r + 2) % 360
        pGrad.Rotation = r
    task.wait(0.02)
    end
end)
registerThemeCallback(function(themePalette)
    syncThemeLocals(themePalette)
    pStroke.Color = SOFT_PINK
    pGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, SOFT_PINK_2),
        ColorSequenceKeypoint.new(0.3, SOFT_PINK),
        ColorSequenceKeypoint.new(0.7, SOFT_PINK_2),
        ColorSequenceKeypoint.new(1, SOFT_PINK),
    })
    if ProgressBarFill then
        ProgressBarFill.BackgroundColor3 = SOFT_PINK
    end
end)
ProgressLabel = Instance.new("TextLabel", pbar)
ProgressLabel.Size = UDim2.new(0.55, 0, 1, 0)
ProgressLabel.Position = UDim2.new(0, 14, 0, 0)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "READY"
ProgressLabel.TextColor3 = SHELL_TEXT
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextSize = 14
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.ZIndex = 12
ProgressPercentLabel = Instance.new("TextLabel", pbar)
ProgressPercentLabel.Size = UDim2.new(0.4, 0, 1, 0)
ProgressPercentLabel.Position = UDim2.new(0.3, 0, 0, 0)
ProgressPercentLabel.BackgroundTransparency = 1
ProgressPercentLabel.Text = ""
ProgressPercentLabel.TextColor3 = SHELL_TEXT
ProgressPercentLabel.Font = Enum.Font.GothamBlack
ProgressPercentLabel.TextSize = 13
ProgressPercentLabel.ZIndex = 12
local radiusLabel = Instance.new("TextLabel", pbar)
radiusLabel.Size = UDim2.new(0, 40, 0, 12)
radiusLabel.Position = UDim2.new(0, 14, 0, 23)
radiusLabel.BackgroundTransparency = 1
radiusLabel.Text = "Radius:"
radiusLabel.TextColor3 = SHELL_SUB
radiusLabel.Font = Enum.Font.Gotham
radiusLabel.TextSize = 9
radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
radiusLabel.ZIndex = 12
RadiusInput = Instance.new("TextBox", pbar)
RadiusInput.Size = UDim2.new(0, 42, 0, 16)
RadiusInput.Position = UDim2.new(0, 54, 0, 21)
RadiusInput.BackgroundColor3 = Color3.fromRGB(11, 18, 15)
RadiusInput.BorderSizePixel = 0
RadiusInput.Text = tostring(Settings.StealRadius)
RadiusInput.TextColor3 = SHELL_TEXT
RadiusInput.Font = Enum.Font.GothamBold
RadiusInput.TextSize = 9
RadiusInput.ClearTextOnFocus = false
RadiusInput.ZIndex = 12
Instance.new("UICorner", RadiusInput).CornerRadius = UDim.new(0, 5)
local radiusStroke = Instance.new("UIStroke", RadiusInput)
radiusStroke.Color = SOFT_PINK
radiusStroke.Thickness = 1
radiusStroke.Transparency = 0.45
RadiusInput.FocusLost:Connect(function()
    local n = tonumber(RadiusInput.Text)
    if n then
        Settings.StealRadius = math.clamp(math.floor(n), 1, 500)
        Values.STEAL_RADIUS = Settings.StealRadius
        refreshSliderValue("STEAL_RADIUS")
    end
    RadiusInput.Text = tostring(Settings.StealRadius)
end)
local durationLabel = Instance.new("TextLabel", pbar)
durationLabel.Size = UDim2.new(0, 52, 0, 12)
durationLabel.Position = UDim2.new(0, 102, 0, 23)
durationLabel.BackgroundTransparency = 1
durationLabel.Text = "Duration:"
durationLabel.TextColor3 = SHELL_SUB
durationLabel.Font = Enum.Font.Gotham
durationLabel.TextSize = 9
durationLabel.TextXAlignment = Enum.TextXAlignment.Left
durationLabel.ZIndex = 12
DurationInput = Instance.new("TextBox", pbar)
DurationInput.Size = UDim2.new(0, 48, 0, 16)
DurationInput.Position = UDim2.new(0, 156, 0, 21)
DurationInput.BackgroundColor3 = Color3.fromRGB(11, 18, 15)
DurationInput.BorderSizePixel = 0
DurationInput.Text = string.format("%.2f", Settings.StealDuration)
DurationInput.TextColor3 = SHELL_TEXT
DurationInput.Font = Enum.Font.GothamBold
DurationInput.TextSize = 9
DurationInput.ClearTextOnFocus = false
DurationInput.ZIndex = 12
Instance.new("UICorner", DurationInput).CornerRadius = UDim.new(0, 5)
local durationStroke = Instance.new("UIStroke", DurationInput)
durationStroke.Color = SOFT_PINK
durationStroke.Thickness = 1
durationStroke.Transparency = 0.45
DurationInput.FocusLost:Connect(function()
    local n = tonumber(DurationInput.Text)
    if n then
        Settings.StealDuration = math.clamp(n, 0.05, 5)
        Values.STEAL_DURATION = Settings.StealDuration
        refreshSliderValue("STEAL_DURATION")
    end
    DurationInput.Text = string.format("%.2f", Settings.StealDuration)
end)
local pTrack = Instance.new("Frame", pbar)
pTrack.Size = UDim2.new(1, -16, 0, 4)
pTrack.Position = UDim2.new(0, 8, 1, -7)
pTrack.BackgroundColor3 = Color3.fromRGB(235, 226, 232)
pTrack.ZIndex = 11
Instance.new("UICorner", pTrack).CornerRadius = UDim.new(1, 0)
ProgressBarFill = Instance.new("Frame", pTrack)
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = SOFT_PINK
ProgressBarFill.ZIndex = 12
Instance.new("UICorner", ProgressBarFill).CornerRadius = UDim.new(1, 0)
RunService.Heartbeat:Connect(function()
    if RadiusInput and not RadiusInput:IsFocused() then
        RadiusInput.Text = tostring(Settings.StealRadius)
    end
    if DurationInput and not DurationInput:IsFocused() then
        DurationInput.Text = string.format("%.2f", Settings.StealDuration)
    end
end)

local order = 1
CreateSection(ScrollFrame, "MOVEMENT", order) order += 1
CreateToggle(ScrollFrame, "Speed Boost", "SpeedBoost", function(s)
    Enabled.SpeedBoost = s
    if s then startSpeedBoost() else stopSpeedBoost() end
end, order, "SPEED") order += 1
CreateToggle(ScrollFrame, "Lagger Counter Mode", "LaggerCounter", function(s)
    Enabled.LaggerCounter = s
    if s then startLaggerCounter() else stopLaggerCounter() end
end, order) order += 1
CreateSlider(ScrollFrame, "Boost Speed", 1, 70, "BoostSpeed", function(v)
    Values.BoostSpeed = v
end, order) order += 1
CreateToggle(ScrollFrame, "Float", "Float", function(s)
    Enabled.Float = s
    if s then startFloat() else stopFloat() end
end, order, "FLOAT") order += 1
CreateToggle(ScrollFrame, "Harder Hit Anim", "Platform", function(s)
    Enabled.Platform = s
    if s then startPlatform() else stopPlatform() end
end, order, "PLATFORM") order += 1
CreateToggle(ScrollFrame, "Gravity Mode", "GalaxyMode", function(s)
    Enabled.GalaxyMode = s
    if s then startGalaxyMode() else stopGalaxyMode() end
end, order) order += 1
CreateSlider(ScrollFrame, "Gravity %", 25, 130, "GalaxyGravityPercent", function(v)
    Values.GalaxyGravityPercent = v
    if galaxyModeEnabled then galaxyAdjustJump() end
end, order) order += 1
CreateToggle(ScrollFrame, "Infinite Jump", "InfiniteJump", function(s)
    Enabled.InfiniteJump = s
    if s then startInfiniteJump() else stopInfiniteJump() end
end, order) order += 1

CreateSection(ScrollFrame, "STEALING", order) order += 1
CreateToggle(ScrollFrame, "Auto Grab", "AutoSteal", function(s)
    Enabled.AutoSteal = s
    Settings.AutoStealEnabled = s
    if s then startAutoSteal() else stopAutoSteal() end
end, order) order += 1
CreateSlider(ScrollFrame, "Steal Radius", 5, 100, "STEAL_RADIUS", function(v)
    Values.STEAL_RADIUS = v
    Settings.StealRadius = v
    if RadiusInput then RadiusInput.Text = tostring(math.floor(v + 0.5)) end
end, order) order += 1
CreateSlider(ScrollFrame, "Steal Duration", 0.05, 1.5, "STEAL_DURATION", function(v)
    Values.STEAL_DURATION = v
    Settings.StealDuration = v
    if DurationInput then DurationInput.Text = string.format("%.2f", v) end
end, order) order += 1
CreateToggle(ScrollFrame, "Speed While Stealing", "SpeedWhileStealing", function(s)
    Enabled.SpeedWhileStealing = s
    if s then
        startSpeedWhileStealing()
    else
        syncStealSpeedHandoff()
    end
end, order) order += 1
CreateSlider(ScrollFrame, "Steal Speed", 10, 35, "StealingSpeedValue", function(v)
    Values.StealingSpeedValue = v
    Values.StealPathReturnSpeed = v
    STEAL_PATH_SECOND_SPEED = v
end, order) order += 1

CreateSection(ScrollFrame, "COMBAT", order) order += 1
CreateToggle(ScrollFrame, "Auto Medusa", "AutoMedusa", function(s)
    Enabled.AutoMedusa = s
    if s then startAutoMedusa() else stopAutoMedusa() end
end, order) order += 1
CreateToggle(ScrollFrame, "Anti Ragdoll", "AntiRagdoll", function(s)
    Enabled.AntiRagdoll = s
    if s then startAntiRagdoll() else stopAntiRagdoll() end
end, order) order += 1
CreateToggle(ScrollFrame, "Spam Bat", "SpamBat", function(s)
    Enabled.SpamBat = s
    if s then startSpamBat() else stopSpamBat() end
end, order) order += 1
CreateToggle(ScrollFrame, "Bat Aimbot", "BatAimbot", function(s)
    Enabled.BatAimbot = s
    if s then
        enableSpamBatFromAimbot()
        startBatAimbot()
    else
        stopBatAimbot()
        disableSpamBatFromAimbot()
    end
end, order, "BATAIMBOT") order += 1
CreateSlider(ScrollFrame, "Aimbot Speed", 10, 120, "BatAimbotSpeed", function(v)
    Values.BatAimbotSpeed = v
end, order) order += 1
CreateToggle(ScrollFrame, "Spin Bot", "Helicopter", function(s)
    Enabled.Helicopter = s
    if s then startHelicopter() else stopHelicopter() end
end, order) order += 1
CreateSlider(ScrollFrame, "Spin Speed", 5, 80, "SpinSpeed", function(v)
    Values.SpinSpeed = v
    if helicopterBAV then helicopterBAV.AngularVelocity = Vector3.new(0, v, 0) end
end, order) order += 1
CreateToggle(ScrollFrame, "Unwalk", "Unwalk", function(s)
    Enabled.Unwalk = s
    if s then startUnwalk() else stopUnwalk() end
end, order) order += 1
CreateActionButton(ScrollFrame, 'Taunt: "/GOJO on top"', function()
    sendLegitTaunt()
end, order) order += 1

CreateSection(ScrollFrame, "VISUALS", order) order += 1
CreateToggle(ScrollFrame, "Disable Player Collision", "Vibrance", function(s)
    Enabled.Vibrance = s
    if s then enablePurpleMoon() else disablePurpleMoon() end
end, order) order += 1
CreateToggle(ScrollFrame, "Optimizer + XRay", "OptimizerXRay", function(s)
    Enabled.OptimizerXRay = s
    if s then enableOptimizer() enableXRay() else disableOptimizer() disableXRay() end
end, order) order += 1
CreateToggle(ScrollFrame, "Player Tracers", "Tracers", function(s)
    Enabled.Tracers = s
    if s then startTracers() else stopTracers() end
end, order) order += 1
CreateSlider(ScrollFrame, "Tracer Thickness", 1, 5, "TracerThickness", function(v)
    Values.TracerThickness = v
end, order) order += 1
CreateSection(KeybindFrame, "KEYBINDS (ESC CANCELS)", order) order += 1
CreateKeybindRow(KeybindFrame, "Speed Boost", "SPEED", order) order += 1
CreateKeybindRow(KeybindFrame, "Float", "FLOAT", order) order += 1
CreateKeybindRow(KeybindFrame, "Auto Right", "AUTORIGHT", order) order += 1
CreateKeybindRow(KeybindFrame, "Auto Left", "AUTOLEFT", order) order += 1
CreateKeybindRow(KeybindFrame, "Bat Aimbot", "BATAIMBOT", order) order += 1
CreateKeybindRow(KeybindFrame, "TP Down", "TPDOWN", order) order += 1
CreateKeybindRow(KeybindFrame, "Harder Hit Anim", "PLATFORM", order) order += 1
CreateKeybindRow(KeybindFrame, "Toggle UI", "TOGGLEUI", order) order += 1
CreateKeybindRow(KeybindFrame, "Close UI", "CLOSEUI", order) order += 1

CreateSection(SettingsFrame, "COLOR THEMES", order) order += 1
CreateActionButton(SettingsFrame, "Blue Theme", function()
    setThemePreset("Blue")
end, order) order += 1
CreateActionButton(SettingsFrame, "Yellow Theme", function()
    setThemePreset("Yellow")
end, order) order += 1
CreateActionButton(SettingsFrame, "Purple Theme", function()
    setThemePreset("Purple")
end, order) order += 1
CreateToggle(SettingsFrame, "Auto Color Mode", "AutoColorMode", function(s)
    Enabled.AutoColorMode = s
    if s then
        Enabled.RainbowMode = false
        if VisualSetters.RainbowMode then VisualSetters.RainbowMode(false, true) end
    end
    refreshThemeMode()
end, order) order += 1
CreateToggle(SettingsFrame, "Rainbow Mode", "RainbowMode", function(s)
    Enabled.RainbowMode = s
    if s then
        Enabled.AutoColorMode = false
        if VisualSetters.AutoColorMode then VisualSetters.AutoColorMode(false, true) end
    end
    refreshThemeMode()
end, order) order += 1

CreateSection(SettingsFrame, "UI SIZE", order) order += 1
CreateSlider(SettingsFrame, "UI Scale", 0.6, 1.0, "GuiScale", function(v)
    Values.GuiScale = math.clamp(v, 0.6, 1)
    if MainGuiScale then
        TweenService:Create(MainGuiScale, TweenInfo.new(0.15), {Scale = Values.GuiScale}):Play()
    end
end, order) order += 1

CreateSection(SettingsFrame, "CONFIGS", order) order += 1
local saveConfigBtn = Create("Frame", {
    BackgroundColor3 = Color3.fromRGB(16, 18, 30),
    Size = UDim2.new(1, -4, 0, 28),
    LayoutOrder = order,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = SettingsFrame
}, {
    Create("UICorner", {CornerRadius=UDim.new(0,8)}),
    Create("UIStroke", {Color=Color3.fromRGB(43, 48, 72), Thickness=1.5})
})
order += 1
Create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    Font = Enum.Font.GothamBold,
    Text = "Save Config",
    TextColor3 = Color3.fromRGB(245, 236, 255),
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = saveConfigBtn
})
local saveConfigClickBtn = Create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 9,
    Parent = saveConfigBtn
})

saveConfigClickBtn.MouseButton1Click:Connect(function()
    saveConfig()
    TweenService:Create(saveConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 32, 52)}):Play()
    task.delay(2, function()
        TweenService:Create(saveConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(16, 18, 30)}):Play()
    end)
end)

local useConfigBtn = Create("Frame", {
    BackgroundColor3 = Color3.fromRGB(16, 18, 30),
    Size = UDim2.new(1, -4, 0, 28),
    LayoutOrder = order,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = SettingsFrame
}, {
    Create("UICorner", {CornerRadius=UDim.new(0,8)}),
    Create("UIStroke", {Color=Color3.fromRGB(43, 48, 72), Thickness=1.5})
})
order += 1
Create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    Font = Enum.Font.GothamBold,
    Text = "Use Config",
    TextColor3 = Color3.fromRGB(245, 236, 255),
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = useConfigBtn
})
local useConfigClickBtn = Create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 9,
    Parent = useConfigBtn
})

useConfigClickBtn.MouseButton1Click:Connect(function()
    TweenService:Create(useConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 32, 52)}):Play()
    applyBootEffect()
    task.delay(2, function()
        TweenService:Create(useConfigBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(16, 18, 30)}):Play()
    end)
end)

CreateSection(MobileFrame, "MOBILE BUTTONS", order) order += 1
CreateToggle(MobileFrame, "Show Mobile Buttons", "MobileButtons", function(s)
    Enabled.MobileButtons = s
    if setMobileButtonsVisible then setMobileButtonsVisible(s) end
end, order) order += 1
CreateToggle(MobileFrame, "Use Box Mobile Buttons", "BoxMobileButtons", function(s)
    Enabled.BoxMobileButtons = s
    if setMobileButtonsVisible then setMobileButtonsVisible(Enabled.MobileButtons) end
end, order) order += 1
CreateToggle(MobileFrame, "Lock Mobile Buttons", "LockFloatPosition", function(s)
    Enabled.LockFloatPosition = s
end, order) order += 1

CreateSection(AutoPlayFrame, "LAZY AUTO PLAY", order) order += 1
CreateToggle(AutoPlayFrame, "Auto Right Play", "AutoRight", function(s)
    Enabled.AutoRight = s
    if s then
        countdownPreferredSide = "right"
        Enabled.AutoLeft = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
        refreshAllBoxButtonStates()
        stopStealPath()
        startStealPath(stealPath_Right)
    else
        stopStealPath()
    end
end, order, "AUTORIGHT") order += 1
CreateToggle(AutoPlayFrame, "Auto Left Play", "AutoLeft", function(s)
    Enabled.AutoLeft = s
    if s then
        countdownPreferredSide = "left"
        Enabled.AutoRight = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
        refreshAllBoxButtonStates()
        stopStealPath()
        startStealPath(stealPath_Left)
    else
        stopStealPath()
    end
end, order, "AUTOLEFT") order += 1
CreateToggle(AutoPlayFrame, "Auto Play After Countdown", "CountdownAutoPlay", function(s)
    Enabled.CountdownAutoPlay = s
    countdownAutoEnabled = s
end, order) order += 1
CreateToggle(AutoPlayFrame, "ESP All Points", "WaypointESP", function(s)
    Enabled.WaypointESP = s
    if s then startWaypointESP() else stopWaypointESP() end
end, order) order += 1
CreateSlider(AutoPlayFrame, "Auto Play Speed", 20, 80, "StealPathSpeed", function(v)
    Values.StealPathSpeed = v
    STEAL_PATH_VELOCITY_SPEED = v
end, order) order += 1
CreateSlider(AutoPlayFrame, "Carry Return Speed", 10, 35, "StealPathReturnSpeed", function(v)
    Values.StealPathReturnSpeed = v
    Values.StealingSpeedValue = v
    STEAL_PATH_SECOND_SPEED = v
end, order) order += 1

CreateSection(AutoPlayFrame, "WAYPOINT OFFSETS", order) order += 1

local waypointDefinitions = {
    { label = "Left WP1", group = "Left", idx = 1 },
    { label = "Left WP2", group = "Left", idx = 2 },
    { label = "Left WP3", group = "Left", idx = 3 },
    { label = "Right WP1", group = "Right", idx = 1 },
    { label = "Right WP2", group = "Right", idx = 2 },
    { label = "Right WP3", group = "Right", idx = 3 },
}

local WAYPOINT_ROW_H = 44
local WAYPOINT_BOX_W = 54
local WAYPOINT_BOX_H = 22

local function applyWaypointOffset(groupName, index, x, y, z)
    wpOffsets[groupName][index] = Vector3.new(x or 0, y or 0, z or 0)
    rebuildLazyWaypointPositions()
    saveConfig()
end

local function applyWaypointAbsolutePosition(groupName, index, worldPosition)
    local basePoint = lazyAutoPlayBaseWaypoints[groupName] and lazyAutoPlayBaseWaypoints[groupName][index]
    if not basePoint or not worldPosition then return end
    local offset = worldPosition - basePoint
    applyWaypointOffset(groupName, index, offset.X, offset.Y, offset.Z)
end

local function CreateWaypointRow(parent, definition, rowOrder)
    local row = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(16, 18, 30),
        Size = UDim2.new(1, -4, 0, WAYPOINT_ROW_H),
        LayoutOrder = rowOrder,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
        Create("UIStroke", { Color = Color3.fromRGB(43, 48, 72), Thickness = 1.4 }),
    })

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 58, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = definition.label,
        TextColor3 = Color3.fromRGB(180, 190, 220),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = row,
    })

    local boxes = {}
    local axisKeys = {"X", "Y", "Z"}

    for axisIndex, axisLabel in ipairs(axisKeys) do
        local xOffset = 72 + (axisIndex - 1) * (WAYPOINT_BOX_W + 4)

        Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, WAYPOINT_BOX_W, 0, 12),
            Position = UDim2.new(0, xOffset, 0, 3),
            Font = Enum.Font.GothamBold,
            Text = axisLabel,
            TextColor3 = Color3.fromRGB(120, 130, 160),
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 7,
            Parent = row,
        })

        local point = lazyAutoPlayWaypoints[definition.group][definition.idx] or Vector3.zero
        local initialValue = axisIndex == 1 and point.X or (axisIndex == 2 and point.Y or point.Z)
        local box = Create("TextBox", {
            BackgroundColor3 = Color3.fromRGB(22, 25, 42),
            Size = UDim2.new(0, WAYPOINT_BOX_W, 0, WAYPOINT_BOX_H),
            Position = UDim2.new(0, xOffset, 0, 15),
            Font = Enum.Font.GothamBold,
            TextSize = 8,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = formatWaypointNumber(initialValue),
            ClearTextOnFocus = false,
            BorderSizePixel = 0,
            ZIndex = 7,
            Parent = row,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
            Create("UIStroke", { Color = PURPLE, Thickness = 1 }),
        })

        box.FocusLost:Connect(function()
            local parsed = tonumber(box.Text)
            local currentPoint = lazyAutoPlayWaypoints[definition.group][definition.idx] or Vector3.zero
            if parsed then
                local x = axisIndex == 1 and parsed or currentPoint.X
                local y = axisIndex == 2 and parsed or currentPoint.Y
                local z = axisIndex == 3 and parsed or currentPoint.Z
                applyWaypointAbsolutePosition(definition.group, definition.idx, Vector3.new(x, y, z))
                refreshWaypointEditorRows()
            else
                box.Text = formatWaypointNumber(axisIndex == 1 and currentPoint.X or (axisIndex == 2 and currentPoint.Y or currentPoint.Z))
            end
        end)

        table.insert(boxes, box)
    end

    local resetButton = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(28, 32, 55),
        Size = UDim2.new(0, 24, 0, WAYPOINT_BOX_H),
        Position = UDim2.new(1, -28, 0, 15),
        Font = Enum.Font.GothamBold,
        Text = "R",
        TextColor3 = SOFT_PINK,
        TextSize = 11,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 7,
        Parent = row,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
        Create("UIStroke", { Color = PURPLE, Thickness = 1 }),
    })

    local pickButton = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(28, 32, 55),
        Size = UDim2.new(0, 24, 0, WAYPOINT_BOX_H),
        Position = UDim2.new(1, -56, 0, 15),
        Font = Enum.Font.GothamBold,
        Text = "P",
        TextColor3 = SOFT_PINK,
        TextSize = 11,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 7,
        Parent = row,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
        Create("UIStroke", { Color = PURPLE, Thickness = 1 }),
    })

    pickButton.MouseButton1Click:Connect(function()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        applyWaypointAbsolutePosition(definition.group, definition.idx, root.Position)
        refreshWaypointEditorRows()
    end)
    pickButton.MouseEnter:Connect(function()
        TweenService:Create(pickButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 55, 90) }):Play()
    end)
    pickButton.MouseLeave:Connect(function()
        TweenService:Create(pickButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28, 32, 55) }):Play()
    end)

    resetButton.MouseButton1Click:Connect(function()
        applyWaypointOffset(definition.group, definition.idx, 0, 0, 0)
        refreshWaypointEditorRows()
    end)
    resetButton.MouseEnter:Connect(function()
        TweenService:Create(resetButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 55, 90) }):Play()
    end)
    resetButton.MouseLeave:Connect(function()
        TweenService:Create(resetButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28, 32, 55) }):Play()
    end)

    table.insert(waypointRowBindings, {
        group = definition.group,
        idx = definition.idx,
        boxes = boxes,
    })

    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        for _, box in ipairs(boxes) do
            box.TextColor3 = Color3.fromRGB(255, 255, 255)
            local stroke = box:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = PURPLE
            end
        end
        pickButton.TextColor3 = SOFT_PINK
        local pickStroke = pickButton:FindFirstChildOfClass("UIStroke")
        if pickStroke then
            pickStroke.Color = PURPLE
        end
        resetButton.TextColor3 = SOFT_PINK
        local stroke = resetButton:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = PURPLE
        end
    end)

    return row
end

for _, definition in ipairs(waypointDefinitions) do
    CreateWaypointRow(AutoPlayFrame, definition, order)
    order += 1
end

refreshWaypointEditorRows()

local resetAllWaypointsRow = Create("Frame", {
    BackgroundColor3 = Color3.fromRGB(16, 18, 30),
    Size = UDim2.new(1, -4, 0, 28),
    LayoutOrder = order,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = AutoPlayFrame,
}, {
    Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
    Create("UIStroke", { Color = Color3.fromRGB(43, 48, 72), Thickness = 1.4 }),
})
order += 1

local resetAllWaypointsButton = Create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Reset All Waypoints",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = SOFT_PINK,
    ZIndex = 9,
    Parent = resetAllWaypointsRow,
})

resetAllWaypointsButton.MouseButton1Click:Connect(function()
    wpOffsets.Left = {Vector3.zero, Vector3.zero, Vector3.zero}
    wpOffsets.Right = {Vector3.zero, Vector3.zero, Vector3.zero}
    rebuildLazyWaypointPositions()
    refreshWaypointEditorRows()
    saveConfig()
end)

setMobileButtonsVisible = function(state)
    refreshAllBoxButtonStates()
    for _, buttonFrame in ipairs(mobileButtonFrames) do
        if buttonFrame and buttonFrame.Parent then
            buttonFrame.Visible = state and not Enabled.BoxMobileButtons
        end
    end
    for _, buttonFrame in ipairs(boxMobileButtonFrames) do
        if buttonFrame and buttonFrame.Parent then
            buttonFrame.Visible = state and Enabled.BoxMobileButtons
        end
    end
end

local function CreateFloatingButton(labelText, icon, defaultPos, enabledKey, onToggle, isToggle, keybindAction)
    if isToggle == nil then isToggle = true end

    local buttonPos = floatButtonPositions[enabledKey] or defaultPos
    local btnFrame = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 17, 14),
        Position = buttonPos,
        Size = UDim2.new(0, 156, 0, 50),
        BorderSizePixel = 0,
        ZIndex = 20,
        Parent = ScreenGui
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 16)}),
        Create("UIStroke", {Color = SOFT_PINK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 20, 17)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 12, 10)),
            }),
            Rotation = 180
        })
    })
    local btnStroke = btnFrame:FindFirstChildOfClass("UIStroke")
    btnFrame.Visible = Enabled.MobileButtons
    table.insert(mobileButtonFrames, btnFrame)
    local glowFrame = Create("Frame", {
        BackgroundColor3 = SOFT_PINK,
        BackgroundTransparency = 0.92,
        Size = UDim2.new(1, 6, 1, 6),
        Position = UDim2.new(0, -3, 0, -3),
        ZIndex = 19,
        Parent = btnFrame
    }, {Create("UICorner", {CornerRadius = UDim.new(0, 16)})})
    local textLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, keybindAction and -72 or -28, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = SHELL_TEXT,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
        Parent = btnFrame
    })

    if keybindAction then
        local keyPill = Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(12, 18, 15),
            Size = UDim2.new(0, 38, 0, 18),
            Position = UDim2.new(1, isToggle and -68 or -50, 0.5, -9),
            BorderSizePixel = 0,
            ZIndex = 22,
            Parent = btnFrame
        }, {
            Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Create("UIStroke", {Color = SOFT_PINK, Thickness = 1.1, Transparency = 0.15})
        })
        local keyPillLabel = Create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = "",
            TextColor3 = SHELL_TEXT,
            TextSize = 9,
            ZIndex = 23,
            Parent = keyPill
        })
        registerKeybindDisplay(keybindAction, function(displayText, waiting)
            keyPillLabel.Text = displayText
            TweenService:Create(keyPill, TweenInfo.new(0.15), {
                BackgroundColor3 = waiting and SOFT_PINK_2 or Color3.fromRGB(12, 18, 15)
            }):Play()
        end)
    end

    local statusDot = nil
    if isToggle then
        statusDot = Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(217, 197, 208),
            Size = UDim2.new(0, 9, 0, 9),
            Position = UDim2.new(1, -16, 0.5, -4.5),
            ZIndex = 22,
            Parent = btnFrame
        }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    end

    local isActive = Enabled[enabledKey] or false
    local function updateVisual(state)
        isActive = state
        if isToggle then
            if statusDot then
                TweenService:Create(statusDot, TweenInfo.new(0.2), {BackgroundColor3 = state and SOFT_PINK or Color3.fromRGB(217, 197, 208)}):Play()
            end
            TweenService:Create(btnFrame, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(16, 31, 24) or Color3.fromRGB(10, 17, 14)}):Play()
            TweenService:Create(glowFrame, TweenInfo.new(0.2), {BackgroundTransparency = state and 0.78 or 0.92}):Play()
        end
    end
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        if btnStroke then
            btnStroke.Color = SOFT_PINK
        end
        glowFrame.BackgroundColor3 = SOFT_PINK
        updateVisual(isActive)
    end)

    local clickBtn = Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 23,
        Parent = btnFrame
    })
    local fDragging, fDragStart, fStartPos, fMoved = false, nil, nil, false
    clickBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not Enabled.LockFloatPosition then
                fDragging = true
                fMoved = false
                fDragStart = input.Position
                fStartPos = btnFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then fDragging = false end
                end)
            else
                fDragging = false
                fMoved = false
            end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if fDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - fDragStart
            if delta.Magnitude > 5 then
                fMoved = true
                btnFrame.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
                floatButtonPositions[enabledKey] = btnFrame.Position
            end
        end
    end)
    clickBtn.MouseButton1Click:Connect(function()
        if Enabled.LockFloatPosition or not fMoved then
            if isToggle then
                isActive = not isActive
                Enabled[enabledKey] = isActive
                updateVisual(isActive)
                onToggle(isActive, updateVisual)
            else
                onToggle(isActive, updateVisual)
            end
        end
    end)
    return updateVisual
end

local boxPanel = Create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -190, 0.5, -136),
    Size = UDim2.new(0, 172, 0, 272),
    BorderSizePixel = 0,
    Visible = Enabled.MobileButtons and Enabled.BoxMobileButtons,
    ZIndex = 24,
    Parent = ScreenGui
})
table.insert(boxMobileButtonFrames, boxPanel)

local boxGrid = Create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(1, -20, 1, -20),
    ZIndex = 25,
    Parent = boxPanel
})

refreshBoxButtonState = function(enabledKey)
    local updater = boxMobileButtonReferences[enabledKey]
    if updater then
        updater(Enabled[enabledKey] or false)
    end
end

refreshAllBoxButtonStates = function()
    for enabledKey, updater in pairs(boxMobileButtonReferences) do
        if updater then
            updater(Enabled[enabledKey] or false)
        end
    end
end

local function CreateBoxMobileButton(labelText, enabledKey, col, row, onToggle, isToggle)
    if isToggle == nil then isToggle = true end
    local cellW, cellH, gap = 76, 76, 10
    local box = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(13, 20, 17),
        Position = UDim2.new(0, (col - 1) * (cellW + gap), 0, (row - 1) * (cellH + gap)),
        Size = UDim2.new(0, cellW, 0, cellH),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 26,
        Parent = boxGrid
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
        Create("UIStroke", {Color = SOFT_PINK, Thickness = 1.6, Transparency = 0.18})
    })
    local stroke = box:FindFirstChildOfClass("UIStroke")
    local buttonGlow = Create("Frame", {
        BackgroundColor3 = SOFT_PINK,
        BackgroundTransparency = 0.9,
        Position = UDim2.new(0, -2, 0, -2),
        Size = UDim2.new(1, 4, 1, 4),
        BorderSizePixel = 0,
        ZIndex = 25,
        Parent = box
    }, {Create("UICorner", {CornerRadius = UDim.new(0, 14)})})
    local title = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0.5, -18),
        Size = UDim2.new(1, -12, 0, 36),
        Font = Enum.Font.GothamBlack,
        Text = labelText,
        TextColor3 = SOFT_PINK,
        TextSize = 10,
        TextWrapped = true,
        ZIndex = 27,
        Parent = box
    })
    local mode = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 1, -18),
        Size = UDim2.new(1, -12, 0, 10),
        Font = Enum.Font.GothamBold,
        Text = isToggle and "MODE" or "TAP",
        TextColor3 = SHELL_SUB,
        TextSize = 7,
        ZIndex = 27,
        Parent = box
    })
    local statusBar = Create("Frame", {
        BackgroundColor3 = SOFT_PINK,
        BackgroundTransparency = isToggle and 0.72 or 0.45,
        Position = UDim2.new(0.5, -15, 0, 10),
        Size = UDim2.new(0, 30, 0, 4),
        BorderSizePixel = 0,
        ZIndex = 27,
        Parent = box
    }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
    local function updateVisual(state)
        title.TextColor3 = SOFT_PINK
        statusBar.BackgroundColor3 = SOFT_PINK
        buttonGlow.BackgroundColor3 = SOFT_PINK
        if isToggle then
            TweenService:Create(box, TweenInfo.new(0.15), {
                BackgroundColor3 = state and Color3.fromRGB(22, 34, 28) or Color3.fromRGB(13, 20, 17)
            }):Play()
            if stroke then
                TweenService:Create(stroke, TweenInfo.new(0.15), {
                    Color = SOFT_PINK,
                    Transparency = state and 0.02 or 0.18
                }):Play()
            end
            TweenService:Create(statusBar, TweenInfo.new(0.15), {BackgroundTransparency = state and 0.02 or 0.72}):Play()
            TweenService:Create(buttonGlow, TweenInfo.new(0.15), {BackgroundTransparency = state and 0.76 or 0.9}):Play()
        end
    end
    boxMobileButtonReferences[enabledKey] = updateVisual
    registerThemeCallback(function(themePalette)
        syncThemeLocals(themePalette)
        title.TextColor3 = SOFT_PINK
        mode.TextColor3 = SHELL_SUB
        if stroke then stroke.Color = SOFT_PINK end
        statusBar.BackgroundColor3 = SOFT_PINK
        buttonGlow.BackgroundColor3 = SOFT_PINK
        updateVisual(Enabled[enabledKey] or false)
    end)
    updateVisual(Enabled[enabledKey] or false)

    local dragging, dragStart, startPos, moved = false, nil, nil, false
    box.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = box.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then
                moved = true
                box.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    box.MouseButton1Click:Connect(function()
        if moved then return end
        if isToggle then
            local nextState = not Enabled[enabledKey]
            Enabled[enabledKey] = nextState
            updateVisual(nextState)
            onToggle(nextState)
        else
            onToggle()
            TweenService:Create(box, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(22, 34, 28)}):Play()
            task.delay(0.18, function()
                if box and box.Parent then
                    TweenService:Create(box, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(13, 20, 17)}):Play()
                end
            end)
        end
    end)
    return updateVisual
end

CreateBoxMobileButton("DROP", "Drop", 1, 1, function()
    startWalkFling()
    task.delay(0.4, stopWalkFling)
end, false)

CreateBoxMobileButton("AUTO\nLEFT", "AutoLeft", 2, 1, function(state)
    Enabled.AutoLeft = state
    if VisualSetters.AutoLeft then VisualSetters.AutoLeft(state, true) end
    if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(state) end
    refreshBoxButtonState("AutoLeft")
    if state then
        countdownPreferredSide = "left"
        Enabled.AutoRight = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
        refreshBoxButtonState("AutoRight")
        stopStealPath()
        startStealPath(stealPath_Left)
    else
        stopStealPath()
    end
end)

CreateBoxMobileButton("AUTO\nBAT", "BatAimbot", 1, 2, function(state)
    Enabled.BatAimbot = state
    if VisualSetters.BatAimbot then VisualSetters.BatAimbot(state, true) end
    if floatButtonReferences.BatAimbot then floatButtonReferences.BatAimbot(state) end
    if state then
        enableSpamBatFromAimbot()
        startBatAimbot()
    else
        stopBatAimbot()
        disableSpamBatFromAimbot()
    end
end)

CreateBoxMobileButton("AUTO\nRIGHT", "AutoRight", 2, 2, function(state)
    Enabled.AutoRight = state
    if VisualSetters.AutoRight then VisualSetters.AutoRight(state, true) end
    if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(state) end
    refreshBoxButtonState("AutoRight")
    if state then
        countdownPreferredSide = "right"
        Enabled.AutoLeft = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
        refreshBoxButtonState("AutoLeft")
        stopStealPath()
        startStealPath(stealPath_Right)
    else
        stopStealPath()
    end
end)

CreateBoxMobileButton("TP\nDOWN", "TPDown", 1, 3, function()
    teleportDownNow()
end, false)

floatButtonReferences.AutoRight = CreateFloatingButton("Auto Right", "⚙️", UDim2.new(1, -144, 0.5, -64), "AutoRight", function(state)
    if state then
        countdownPreferredSide = "right"
        Enabled.AutoLeft = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
        stopStealPath() startStealPath(stealPath_Right)
    else
        stopStealPath()
    end
end, true, "AUTORIGHT")
floatButtonReferences.AutoLeft = CreateFloatingButton("Auto Left", "⚙️", UDim2.new(1, -144, 0.5, -22), "AutoLeft", function(state)
    if state then
        countdownPreferredSide = "left"
        Enabled.AutoRight = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
        stopStealPath() startStealPath(stealPath_Left)
    else
        stopStealPath()
    end
end, true, "AUTOLEFT")
floatButtonReferences.Float = CreateFloatingButton("Float", "⚙️", UDim2.new(1, -144, 0.5, 20), "Float", function(state)
    Enabled.Float = state
    if VisualSetters.Float then VisualSetters.Float(state, true) end
    if state then startFloat() else stopFloat() end
end, true, "FLOAT")
floatButtonReferences.Platform = CreateFloatingButton("Harder Hit", "⚙️", UDim2.new(1, -144, 0.5, 104), "Platform", function(state)
    Enabled.Platform = state
    if VisualSetters.Platform then VisualSetters.Platform(state, true) end
    if state then startPlatform() else stopPlatform() end
end, true, "PLATFORM")
floatButtonReferences.BatAimbot = CreateFloatingButton("Bat Aimbot", "⚙️", UDim2.new(1, -144, 0.5, 62), "BatAimbot", function(state)
    Enabled.BatAimbot = state
    if VisualSetters.BatAimbot then VisualSetters.BatAimbot(state, true) end
    if state then
        enableSpamBatFromAimbot()
        startBatAimbot()
    else
        stopBatAimbot()
        disableSpamBatFromAimbot()
    end
end, true, "BATAIMBOT")
floatButtonReferences.TPDown = CreateFloatingButton("TP Down", "⚙️", UDim2.new(1, -144, 0.5, -232), "TPDown", function(state)
    teleportDownNow()
end, false, "TPDOWN")
floatButtonReferences.TPLeft = CreateFloatingButton("TP (left)", "⚙️", UDim2.new(1, -144, 0.5, -148), "TPLeft", function(state)
    teleportLeft()
end, false)

floatButtonReferences.TPRight = CreateFloatingButton("TP (right)", "⚙️", UDim2.new(1, -144, 0.5, -106), "TPRight", function(state)
    teleportRight()
end, false)

floatButtonReferences.Drop = CreateFloatingButton("Drop", "⚙️", UDim2.new(1, -144, 0.5, -190), "Drop", function(state)
    startWalkFling()
    task.delay(0.4, stopWalkFling)
end, false)

floatButtonReferences.Taunt = CreateFloatingButton("Taunt", "T", UDim2.new(1, -144, 0.5, -274), "Taunt", function(state)
    sendLegitTaunt()
end, false)

local function applySavedState()
    syncStealSettings()
    if Enabled.LaggerCounter then
        startLaggerCounter()
    else
        stopLaggerCounter()
        Values.StealPathReturnSpeed = Values.StealingSpeedValue
    end
    STEAL_PATH_SECOND_SPEED = Values.StealPathReturnSpeed
    STEAL_PATH_VELOCITY_SPEED = Values.StealPathSpeed

    for key, setter in pairs(VisualSetters) do
        if setter then
            setter(Enabled[key] or false, true)
        end
    end

    if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(Enabled.AutoRight or false) end
    if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(Enabled.AutoLeft or false) end
    if floatButtonReferences.Float then floatButtonReferences.Float(Enabled.Float or false) end
    if floatButtonReferences.Platform then floatButtonReferences.Platform(Enabled.Platform or false) end
    if floatButtonReferences.BatAimbot then floatButtonReferences.BatAimbot(Enabled.BatAimbot or false) end
    refreshAllBoxButtonStates()

    if Enabled.SpeedBoost then startSpeedBoost() else stopSpeedBoost() end
    if Enabled.AutoSteal then startAutoSteal() else stopAutoSteal() end
    if Enabled.SpeedWhileStealing then startSpeedWhileStealing() else stopSpeedWhileStealing() end
    if Enabled.AntiRagdoll then startAntiRagdoll() else stopAntiRagdoll() end
    if Enabled.AutoMedusa then startAutoMedusa() else stopAutoMedusa() end
    if Enabled.SpamBat then startSpamBat() else stopSpamBat() end
    if Enabled.Helicopter then startHelicopter() else stopHelicopter() end
    if Enabled.BatAimbot then
        enableSpamBatFromAimbot()
        startBatAimbot()
    else
        stopBatAimbot()
        disableSpamBatFromAimbot()
    end
    if Enabled.InfiniteJump then startInfiniteJump() else stopInfiniteJump() end
    if Enabled.Unwalk then startUnwalk() else stopUnwalk() end
    if Enabled.Vibrance then enablePurpleMoon() else disablePurpleMoon() end
    if Enabled.OptimizerXRay then enableOptimizer() enableXRay() else disableOptimizer() disableXRay() end
    if Enabled.GalaxyMode then startGalaxyMode() else stopGalaxyMode() end
    if Enabled.WaypointESP then startWaypointESP() else stopWaypointESP() end
    if Enabled.Tracers then startTracers() else stopTracers() end
    if Enabled.Platform then startPlatform() else stopPlatform() end
    if Enabled.AutoRight then stopStealPath() startStealPath(stealPath_Right) end
    if Enabled.AutoLeft then stopStealPath() startStealPath(stealPath_Left) end
    if Enabled.AutoRight then countdownPreferredSide = "right" end
    if Enabled.AutoLeft then countdownPreferredSide = "left" end
    if setMobileButtonsVisible then setMobileButtonsVisible(Enabled.MobileButtons) end
    syncStealSpeedHandoff()
end

refreshThemeMode()
applySavedState()
setMobileButtonsVisible(Enabled.MobileButtons)
refreshKeybindDisplays()

UserInputService.InputBegan:Connect(function(input, gpe)
    if activeRebindAction then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                cancelKeybindCapture()
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                finishKeybindCapture(activeRebindAction, input.KeyCode)
            end
        end
        return
    end
    if gpe then return end
    if input.KeyCode == KEYBINDS.CLOSEUI then
        ScreenGui:Destroy()
    elseif input.KeyCode == KEYBINDS.TOGGLEUI then
        uiVisible = not uiVisible
        MainContainer.Visible = uiVisible
    elseif input.KeyCode == KEYBINDS.SPEED then
        Enabled.SpeedBoost = not Enabled.SpeedBoost
        if VisualSetters.SpeedBoost then VisualSetters.SpeedBoost(Enabled.SpeedBoost) end
        if floatButtonReferences.SpeedBoost then floatButtonReferences.SpeedBoost(Enabled.SpeedBoost) end
        if Enabled.SpeedBoost then startSpeedBoost() else stopSpeedBoost() end
    elseif input.KeyCode == KEYBINDS.FLOAT then
        Enabled.Float = not Enabled.Float
        if VisualSetters.Float then VisualSetters.Float(Enabled.Float) end
        if floatButtonReferences.Float then floatButtonReferences.Float(Enabled.Float) end
        if Enabled.Float then startFloat() else stopFloat() end
    elseif input.KeyCode == KEYBINDS.PLATFORM then
        Enabled.Platform = not Enabled.Platform
        if VisualSetters.Platform then VisualSetters.Platform(Enabled.Platform) end
        if floatButtonReferences.Platform then floatButtonReferences.Platform(Enabled.Platform) end
        if Enabled.Platform then startPlatform() else stopPlatform() end
    elseif input.KeyCode == KEYBINDS.BATAIMBOT then
        Enabled.BatAimbot = not Enabled.BatAimbot
        if VisualSetters.BatAimbot then VisualSetters.BatAimbot(Enabled.BatAimbot) end
        if floatButtonReferences.BatAimbot then floatButtonReferences.BatAimbot(Enabled.BatAimbot) end
        if Enabled.BatAimbot then
            enableSpamBatFromAimbot()
            startBatAimbot()
        else
            stopBatAimbot()
            disableSpamBatFromAimbot()
        end
    elseif input.KeyCode == KEYBINDS.TPDOWN then
        teleportDownNow()
    elseif input.KeyCode == KEYBINDS.AUTORIGHT then
        Enabled.AutoRight = not Enabled.AutoRight
        if VisualSetters.AutoRight then VisualSetters.AutoRight(Enabled.AutoRight) end
        if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(Enabled.AutoRight) end
        if Enabled.AutoRight then
            countdownPreferredSide = "right"
            Enabled.AutoLeft = false
            if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
            if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(false) end
            stopStealPath() startStealPath(stealPath_Right)
        else
            stopStealPath()
        end
    elseif input.KeyCode == KEYBINDS.AUTOLEFT then
        Enabled.AutoLeft = not Enabled.AutoLeft
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(Enabled.AutoLeft) end
        if floatButtonReferences.AutoLeft then floatButtonReferences.AutoLeft(Enabled.AutoLeft) end
        if Enabled.AutoLeft then
            countdownPreferredSide = "left"
            Enabled.AutoRight = false
            if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
            if floatButtonReferences.AutoRight then floatButtonReferences.AutoRight(false) end
            stopStealPath() startStealPath(stealPath_Left)
        else
            stopStealPath()
        end
    end
end)

end

buildGui()

Player.CharacterAdded:Connect(function()
    task.wait(1)
    syncStealSpeedHandoff()
    if Enabled.LaggerCounter then startLaggerCounter() end
    if Enabled.SpeedBoost then startSpeedBoost() end
    if Enabled.AutoSteal then startAutoSteal() end
    if Enabled.SpeedWhileStealing then startSpeedWhileStealing() end
    if Enabled.AntiRagdoll then startAntiRagdoll() end
    if Enabled.AutoMedusa then stopAutoMedusa() task.wait(0.1) startAutoMedusa() end
    if Enabled.SpamBat then startSpamBat() end
    if Enabled.Helicopter then startHelicopter() end
    if Enabled.BatAimbot then stopBatAimbot() task.wait(0.1) startBatAimbot() end
    if Enabled.InfiniteJump then stopInfiniteJump() task.wait(0.1) startInfiniteJump() end
    if Enabled.WaypointESP then stopWaypointESP() task.wait(0.1) startWaypointESP() end
    if Enabled.Tracers then startTracers() end
    if Enabled.Platform then stopPlatform() task.wait(0.1) startPlatform() end
end)

if Enabled.Tracers then
    startTracers()
end

