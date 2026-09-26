--// Version: 7

local VERSION = 7

--==================================================
-- CONFIG
--==================================================

local SCRIPT_URL = "https://github.com/Be4oe/test-shit-idk-why/blob/main/3.lua"
local BOOST_VELOCITY = Vector3.new(130, -100, 0)

local PATH_SPEED = 35

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

--==================================================
-- PERSISTENT STATE
--==================================================

getgenv().LocalItemsControllerState =
    getgenv().LocalItemsControllerState or {
        Enabled = false,
        Version = VERSION,
    }

local persistentState = getgenv().LocalItemsControllerState

--==================================================
-- VERSION REPLACEMENT
--==================================================

local oldState = getgenv().LocalItemsVelocityController

if oldState and oldState.Version >= VERSION then
    return
end

if oldState and oldState.Stop then
    oldState.Stop()
end

--==================================================
-- PATH
--==================================================

local PATH = {

    Vector3.new(-28.826235, 16.325605, 37.988842),
    Vector3.new(-28.271602, 17.341112, 97.587479),
    Vector3.new(-28.276102, 35.190304, 97.587479),
    Vector3.new(-28.901943, 37.203465, 84.988106),
    Vector3.new(-62.749859, 37.203465, 84.844328),
    Vector3.new(-62.784935, 37.203449, 124.315117),
    Vector3.new(-54.818737, 37.203465, 124.856922),
    Vector3.new(-53.584702, 54.203465, 124.849525),
    Vector3.new(-33.008224, 53.276463, 119.134033),
    Vector3.new(-27.804852, 53.276463, 125.680321),
    Vector3.new(-10.865964, 53.276463, 117.345161),
    Vector3.new(-14.636556, 51.384853, 103.527107),
    Vector3.new(-13.182974, 53.276287, 75.984589),
    Vector3.new(-34.508015, 67.141464, 79.236130),
    Vector3.new(-45.366062, 69.696518, 94.581879),
    Vector3.new(-38.955326, 73.627258, 99.606941),
    Vector3.new(-45.405811, 76.061844, 107.265396),
    Vector3.new(-44.724346, 76.582458, 123.624039),

}

--==================================================
-- STATE
--==================================================

local stopped = false
local connection = nil
local currentTween = nil
local tweening = false

local enabled = persistentState.Enabled

--==================================================
-- TELEPORT RELOAD
--==================================================

local function queueScriptAfterTeleport()

    local queueFunction =
        queue_on_teleport
        or queueonteleport
        or (syn and syn.queue_on_teleport)

    if not queueFunction then
        warn("[Controller] queue_on_teleport is not supported by this executor.")
        return
    end

    local code = [[
        task.wait(2)

        local url = "]] .. SCRIPT_URL .. [["

        local success, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)

        if not success then
            warn("[Controller] Failed to reload after teleport:", result)
        end
    ]]

    queueFunction(code)

    print("[Controller] Script queued for next teleport")

end

--==================================================
-- FIND PART
--==================================================

local function findPart(object)

    if object:IsA("BasePart") then
        return object
    end

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end

    return nil

end

--==================================================
-- VELOCITY
--==================================================

local function applyVelocity()

    local folder = workspace:FindFirstChild("LocalItems")

    if not folder then
        return
    end

    for _, item in ipairs(folder:GetChildren()) do

        local part = findPart(item)

        if part then
            part.AssemblyLinearVelocity = BOOST_VELOCITY
        end

    end

end

--==================================================
-- VELOCITY LOOP
--==================================================

local function setEnabled(value)

    enabled = value
    persistentState.Enabled = value

    if connection then
        connection:Disconnect()
        connection = nil
    end

    if enabled then

        applyVelocity()

        connection = RunService.Heartbeat:Connect(function()

            if not stopped then
                applyVelocity()
            end

        end)

        print("[Controller] Velocity loop ENABLED")

    else

        print("[Controller] Velocity loop DISABLED")

    end

end

--==================================================
-- ROOT PART
--==================================================

local function getRootPart()

    local character = player.Character

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")

end

--==================================================
-- CANCEL PATH
--==================================================

local function cancelPath()

    tweening = false

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    print("[Controller] Path cancelled")

end

--==================================================
-- PATH TWEEN
--==================================================

local function tweenPath()

    if stopped or tweening then
        return
    end

    local rootPart = getRootPart()

    if not rootPart then
        return
    end

    tweening = true

    for i, targetPosition in ipairs(PATH) do

        if stopped or not tweening then
            break
        end

        rootPart = getRootPart()

        if not rootPart then
            break
        end

        local distance =
            (rootPart.Position - targetPosition).Magnitude

        if distance > 0.05 then

            local duration = distance / PATH_SPEED

            local tweenInfo = TweenInfo.new(
                duration,
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.InOut
            )

            currentTween = TweenService:Create(
                rootPart,
                tweenInfo,
                {
                    CFrame = CFrame.new(targetPosition)
                }
            )

            local finished = false

            local completedConnection

            completedConnection =
                currentTween.Completed:Connect(function()

                    finished = true

                    if completedConnection then
                        completedConnection:Disconnect()
                    end

                end)

            currentTween:Play()

            while not finished and tweening and not stopped do
                task.wait()
            end

            if currentTween then
                currentTween:Cancel()
            end

            currentTween = nil

            if completedConnection then
                completedConnection:Disconnect()
            end

        end

    end

    tweening = false
    currentTween = nil

    if not stopped then
        print("[Controller] Path complete")
    end

end

--==================================================
-- STOP
--==================================================

local function stop()

    stopped = true
    enabled = false
    persistentState.Enabled = false

    if connection then
        connection:Disconnect()
        connection = nil
    end

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    tweening = false

end

--==================================================
-- GLOBAL CONTROLLER
--==================================================

getgenv().LocalItemsVelocityController = {
    Version = VERSION,
    Stop = stop,
    SetEnabled = setEnabled,
    TweenPath = tweenPath,
    CancelPath = cancelPath,
}

--==================================================
-- QUEUE SCRIPT FOR TELEPORT
--==================================================

queueScriptAfterTeleport()

--==================================================
-- KEYS
--==================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)

    if gameProcessed or stopped then
        return
    end

    -- F = velocity loop
    if input.KeyCode == Enum.KeyCode.F then
        setEnabled(not enabled)
    end

    -- G = path
    if input.KeyCode == Enum.KeyCode.G then
        task.spawn(tweenPath)
    end

    -- H = cancel path
    if input.KeyCode == Enum.KeyCode.H then
        cancelPath()
    end

end)

--==================================================
-- RESTORE LOOP STATE
--==================================================

if persistentState.Enabled then

    task.spawn(function()

        -- Wait for the new game's LocalItems to exist
        task.wait(2)

        if not stopped then
            setEnabled(true)
            print("[Controller] Restored velocity loop after teleport")
        end

    end)

end

print("[Controller] Version", VERSION, "loaded")
print("[Controller] F = Velocity Loop")
print("[Controller] G = Start Path")
print("[Controller] H = Cancel Path")
print("[Controller] Persistent loop state:", persistentState.Enabled)
