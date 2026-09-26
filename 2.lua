--// UnitOutline Close Path + Portal Teleport
--// Version: 3.8.0
local SCRIPT_URL = "https://raw.githubusercontent.com/Be4oe/test-shit-idk-why/refs/heads/main/2.lua"

--==================================================
-- INTERNAL SETTINGS
--==================================================

local VERSION = "3.8.0"
local CONTROLLER_NAME = "UnitOutlineController"
local STATE_KEY = "UnitOutlineTeleportState"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

--==================================================
-- SHARED ENVIRONMENT
--==================================================

local sharedEnvironment

pcall(function()
    sharedEnvironment = getgenv()
end)

if not sharedEnvironment then
    sharedEnvironment = _G
end

--==================================================
-- CLEAN UP PREVIOUS VERSIONS
--==================================================

local oldV2 = _G["UnitOutlineGroupOrbit"]

if oldV2 then
    if oldV2.Stop then
        oldV2.Stop()
    end

    if oldV2.InputConnection then
        oldV2.InputConnection:Disconnect()
        oldV2.InputConnection = nil
    end
end

local oldV3 = _G["UnitOutlineClosePath"]

if oldV3 then
    if oldV3.Stop then
        oldV3.Stop()
    end

    if oldV3.InputConnection then
        oldV3.InputConnection:Disconnect()
        oldV3.InputConnection = nil
    end
end

local oldController = _G[CONTROLLER_NAME]

if oldController then
    if oldController.Stop then
        oldController.Stop()
    else
        oldController.Running = false
    end

    if oldController.InputConnection then
        oldController.InputConnection:Disconnect()
        oldController.InputConnection = nil
    end
end

--==================================================
-- CONTROLLER
--==================================================

local controller = {
    Running = false,
    InputConnection = nil,
    Version = VERSION
}

_G[CONTROLLER_NAME] = controller

--==================================================
-- MOVEMENT SETTINGS
--==================================================

local HEIGHT = 12
local SPEED = 80

local MIN_TARGET_Y = -50
local MAX_DISTANCE_FROM_PLAYER = 3000
local RESCAN_INTERVAL = 0.5

local ZIGZAG_WIDTH = 12
local ZIGZAG_SWEEPS = 6

local PORTAL_HEIGHT = 10

--==================================================
-- SAVE LOOP STATE
--==================================================

local function saveLoopState()
    sharedEnvironment[STATE_KEY] = {
        Running = controller.Running
    }
end

--==================================================
-- RESTORE LOOP STATE
--==================================================

local function restoreLoopState()
    local savedState =
        sharedEnvironment[STATE_KEY]

    if not savedState then
        return false
    end

    local shouldRun =
        savedState.Running == true

    sharedEnvironment[STATE_KEY] = nil

    return shouldRun
end

--==================================================
-- QUEUE SCRIPT ON TELEPORT
--==================================================

local function queueScriptOnTeleport()
    local queueFunction =
        queue_on_teleport
        or queueonteleport
        or (syn and syn.queue_on_teleport)

    if not queueFunction then
        warn(
            "[UnitOutline] queue_on_teleport is not available."
        )

        return
    end

    saveLoopState()

    local code =
        "loadstring(game:HttpGet("
        .. string.format("%q", SCRIPT_URL)
        .. "))()"

    queueFunction(code)

    print(
        "[UnitOutline] Queued script for next teleport."
    )
end

--==================================================
-- PLAYER ROOT
--==================================================

local function getRoot()
    local character =
        player.Character

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

--==================================================
-- OBJECT POSITION
--==================================================

local function getPosition(object)
    if object:IsA("Model") then
        return object:GetPivot().Position
    end

    if object:IsA("BasePart") then
        return object.Position
    end

    return nil
end

--==================================================
-- TARGET VALIDATION
--==================================================

local function isValidTarget(position)
    if position.Y < MIN_TARGET_Y then
        return false
    end

    local root =
        getRoot()

    if root then
        local distance =
            (position - root.Position).Magnitude

        if distance > MAX_DISTANCE_FROM_PLAYER then
            return false
        end
    end

    return true
end

--==================================================
-- FIND TARGETS
--==================================================

local function getTargets()
    local targets = {}

    for _, object in ipairs(
        workspace:GetChildren()
    ) do
        local outline =
            object:FindFirstChild(
                "UnitOutline"
            )

        if outline
            and outline:IsA("Highlight") then

            local position =
                getPosition(object)

            if position
                and isValidTarget(position) then

                table.insert(targets, {
                    Object = object,
                    Position = position
                })
            end
        end
    end

    return targets
end

--==================================================
-- FIND NEAREST TARGET
--==================================================

local function findNearest(
    currentPosition,
    targets,
    used
)
    local closestIndex = nil
    local closestDistance = math.huge

    for index, target in ipairs(targets) do
        if not used[index] then
            local distance =
                (target.Position - currentPosition).Magnitude

            if distance < closestDistance then
                closestDistance = distance
                closestIndex = index
            end
        end
    end

    return closestIndex
end

--==================================================
-- BUILD ROUTE
--==================================================

local function buildRoute(targets)
    if #targets <= 1 then
        return targets
    end

    local root =
        getRoot()

    if not root then
        return targets
    end

    local route = {}
    local used = {}

    local currentPosition =
        root.Position

    for _ = 1, #targets do
        local nextIndex =
            findNearest(
                currentPosition,
                targets,
                used
            )

        if not nextIndex then
            break
        end

        used[nextIndex] = true

        local target =
            targets[nextIndex]

        table.insert(
            route,
            target
        )

        currentPosition =
            target.Position
    end

    return route
end

--==================================================
-- ZIG-ZAG MOVEMENT
--==================================================

local function moveToPoint(
    startPosition,
    endPosition
)
    local direction =
        endPosition - startPosition

    local distance =
        direction.Magnitude

    if distance < 0.1 then
        return
    end

    local forward =
        direction.Unit

    local horizontalForward =
        Vector3.new(
            forward.X,
            0,
            forward.Z
        )

    local side

    if horizontalForward.Magnitude > 0.001 then
        horizontalForward =
            horizontalForward.Unit

        side =
            Vector3.new(
                -horizontalForward.Z,
                0,
                horizontalForward.X
            )
    else
        side =
            Vector3.new(
                1,
                0,
                0
            )
    end

    local duration =
        distance / SPEED

    local startTime =
        os.clock()

    while controller.Running do
        local root =
            getRoot()

        if not root then
            return
        end

        local elapsed =
            os.clock() - startTime

        local alpha =
            math.clamp(
                elapsed / duration,
                0,
                1
            )

        local forwardPosition =
            startPosition:Lerp(
                endPosition,
                alpha
            )

        local zigzagAmount =
            math.sin(
                alpha
                * math.pi
                * 2
                * ZIGZAG_SWEEPS
            )

        local sidewaysOffset =
            side
            * zigzagAmount
            * ZIGZAG_WIDTH

        local position =
            forwardPosition
            + sidewaysOffset

        root.CFrame =
            CFrame.lookAt(
                position,
                position + forward
            )

        if alpha >= 1 then
            break
        end

        RunService.Heartbeat:Wait()
    end
end

--==================================================
-- MAIN LOOP
--==================================================

local function runLoop()
    while controller.Running do
        local targets =
            getTargets()

        if #targets == 0 then
            task.wait(
                RESCAN_INTERVAL
            )
            continue
        end

        local route =
            buildRoute(targets)

        if #route == 0 then
            task.wait(
                RESCAN_INTERVAL
            )
            continue
        end

        for _, target in ipairs(route) do
            if not controller.Running then
                break
            end

            if target.Object.Parent then
                local root =
                    getRoot()

                if not root then
                    break
                end

                local targetPosition =
                    getPosition(
                        target.Object
                    )

                if targetPosition
                    and isValidTarget(
                        targetPosition
                    ) then

                    local destination =
                        targetPosition
                        + Vector3.new(
                            0,
                            HEIGHT,
                            0
                        )

                    moveToPoint(
                        root.Position,
                        destination
                    )
                end
            end
        end

        task.wait(
            RESCAN_INTERVAL
        )
    end
end

--==================================================
-- START / STOP
--==================================================

function controller.Start()
    if controller.Running then
        return
    end

    controller.Running = true

    saveLoopState()

    task.spawn(runLoop)

    print(
        "[UnitOutline] ENABLED | Version "
        .. VERSION
    )
end

function controller.Stop()
    controller.Running = false

    saveLoopState()

    print(
        "[UnitOutline] PAUSED"
    )
end

--==================================================
-- PORTAL
--==================================================

local function getPortalBase()
    local portal =
        workspace:FindFirstChild(
            "Portal"
        )

    if not portal then
        return nil
    end

    local base =
        portal:FindFirstChild(
            "Base"
        )

    if not base then
        return nil
    end

    if not base:IsA("BasePart") then
        return nil
    end

    return base
end

local function teleportToPortal()
    local root =
        getRoot()

    if not root then
        warn(
            "[Portal] HumanoidRootPart not found."
        )
        return
    end

    local base =
        getPortalBase()

    if not base then
        warn(
            "[Portal] workspace.Portal.Base was not found."
        )
        return
    end

    root.CFrame =
        CFrame.new(
            base.Position
            + Vector3.new(
                0,
                PORTAL_HEIGHT,
                0
            )
        )

    print(
        "[Portal] Teleported 10 studs above Portal.Base."
    )
end

--==================================================
-- KEYBOARD CONTROLS
--==================================================

controller.InputConnection =
    UserInputService.InputBegan:Connect(
        function(input, gameProcessed)
            if gameProcessed then
                return
            end

            -- K = Toggle loop
            if input.KeyCode ==
                Enum.KeyCode.K then

                if controller.Running then
                    controller.Stop()
                else
                    controller.Start()
                end

                return
            end

            -- L = Pause + teleport
            if input.KeyCode ==
                Enum.KeyCode.L then

                controller.Stop()

                teleportToPortal()

                return
            end
        end
    )

--==================================================
-- INITIALIZE
--==================================================

queueScriptOnTeleport()

local shouldResume =
    restoreLoopState()

print(
    "[UnitOutline] Loaded Version "
    .. VERSION
)

print(
    "[UnitOutline] K = Toggle movement"
)

print(
    "[UnitOutline] L = Pause + teleport above Portal.Base"
)

if shouldResume then
    task.defer(function()
        controller.Start()

        print(
            "[UnitOutline] Restored previous loop state: ENABLED"
        )
    end)
else
    print(
        "[UnitOutline] Restored previous loop state: PAUSED"
    )
end
