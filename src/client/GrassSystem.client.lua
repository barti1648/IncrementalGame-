-- src/client/GrassSystem.client.lua
-- Client-side grass spawning and collection for Platform 1.
-- Grass blades are LocalParts (only visible to this player).
-- Synergy: Wood increases collection radius; Ash accelerates spawn.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart  = character:WaitForChild("HumanoidRootPart")

-- Shared modules
local GameConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BalanceMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceMath"))

-- Remotes
local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local RE_Collect    = Remotes:WaitForChild("CollectGrass")
local RE_UpdateData = Remotes:WaitForChild("UpdateData")

-- ────────────────────────────────────────────────────────────
--  Local player data cache  (updated by server push)
-- ────────────────────────────────────────────────────────────
local localData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData")).default()

RE_UpdateData.OnClientEvent:Connect(function(data)
    localData = data
end)

-- ────────────────────────────────────────────────────────────
--  Platform 1 bounds  (center 0,0,0  size 40×40)
-- ────────────────────────────────────────────────────────────
local PLATFORM_MIN_X = -19
local PLATFORM_MAX_X =  19
local PLATFORM_MIN_Z = -19
local PLATFORM_MAX_Z =  19
local GRASS_Y        =  0.75  -- height above platform surface

-- Folder to hold all grass blades for this client
local grassFolder = Instance.new("Folder")
grassFolder.Name   = "ClientGrass"
grassFolder.Parent = workspace

-- ────────────────────────────────────────────────────────────
--  Grass blade pool
-- ────────────────────────────────────────────────────────────
local activeBlade = {}   -- array of Parts currently on the field

local GOLDEN_COLOR  = Color3.fromRGB(255, 215, 0)
local NORMAL_COLORS = {
    Color3.fromRGB(56,  142, 60),
    Color3.fromRGB(76,  175, 80),
    Color3.fromRGB(100, 200, 90),
    Color3.fromRGB(46,  120, 50),
}

local function randomPlatformPos()
    return Vector3.new(
        math.random() * (PLATFORM_MAX_X - PLATFORM_MIN_X) + PLATFORM_MIN_X,
        GRASS_Y,
        math.random() * (PLATFORM_MAX_Z - PLATFORM_MIN_Z) + PLATFORM_MIN_Z
    )
end

local function spawnBlade()
    local maxBlades = GameConfig.GRASS.MAX_BLADES_ON_FIELD
    if #activeBlade >= maxBlades then return end

    local isGolden = (math.random() < BalanceMath.goldenGrassChance(localData))
    local height   = math.random() * 0.6 + 0.4
    local blade    = Instance.new("Part")
    blade.Anchored    = true
    blade.CanCollide  = false
    blade.CastShadow  = false
    blade.Size        = Vector3.new(0.4, height, 0.4)
    blade.Position    = randomPlatformPos() + Vector3.new(0, height / 2, 0)
    blade.Color       = isGolden and GOLDEN_COLOR or NORMAL_COLORS[math.random(#NORMAL_COLORS)]
    blade.Material    = Enum.Material.Grass

    -- Tag the blade
    blade:SetAttribute("IsGolden", isGolden)
    blade:SetAttribute("Collected", false)

    -- Sparkle effect on golden grass
    if isGolden then
        local sparkle = Instance.new("Sparkles")
        sparkle.SparkleColor = Color3.fromRGB(255, 220, 50)
        sparkle.Parent       = blade
    end

    blade.Parent = grassFolder
    table.insert(activeBlade, blade)
end

local function removeBlade(blade, index)
    blade:Destroy()
    table.remove(activeBlade, index)
end

-- ────────────────────────────────────────────────────────────
--  Zone 2 – Zone detection for seed drops
-- ────────────────────────────────────────────────────────────
local function isInZone2()
    local pos = rootPart.Position
    local z2  = GameConfig.MYSTIC_REALM_POS
    return (math.abs(pos.X - z2.X) < 35) and (math.abs(pos.Z - z2.Z) < 35)
end

local function isOnPlatform1()
    local pos = rootPart.Position
    return (pos.X >= PLATFORM_MIN_X - 2) and (pos.X <= PLATFORM_MAX_X + 2)
       and (pos.Z >= PLATFORM_MIN_Z - 2) and (pos.Z <= PLATFORM_MAX_Z + 2)
end

-- ────────────────────────────────────────────────────────────
--  Spawn timer
-- ────────────────────────────────────────────────────────────
local spawnTimer = 0

-- ────────────────────────────────────────────────────────────
--  Collection loop
-- ────────────────────────────────────────────────────────────
local collectCooldown = 0   -- small server-request cooldown

RunService.Heartbeat:Connect(function(dt)
    -- Update character reference (respawn)
    if not character or not character.Parent then
        character = player.Character
        if not character then return end
        rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
    end

    local playerPos = rootPart.Position

    -- ── Spawn new blades on Platform 1 (or Zone 2 mystic grass) ──
    local interval = BalanceMath.grassSpawnInterval(localData)
    spawnTimer = spawnTimer + dt
    if spawnTimer >= interval then
        spawnTimer = 0
        if isOnPlatform1() or isInZone2() then
            spawnBlade()
        end
    end

    -- ── Collect nearby blades ────────────────────────────────────
    local radius = BalanceMath.collectionRadius(localData)
    local radiusSq = radius * radius

    collectCooldown = collectCooldown - dt

    local toRemove = {}
    for i, blade in ipairs(activeBlade) do
        if not blade:GetAttribute("Collected") then
            local diff = (blade.Position - playerPos)
            -- Only check XZ distance (ignore Y)
            local distSq = diff.X * diff.X + diff.Z * diff.Z
            if distSq <= radiusSq then
                blade:SetAttribute("Collected", true)
                table.insert(toRemove, i)

                -- Calculate grass amount
                local grassAmount = BalanceMath.grassPerPickup(localData)
                local isGolden    = blade:GetAttribute("IsGolden") or false
                if isGolden then
                    grassAmount = grassAmount * GameConfig.GRASS.GOLDEN_GRASS_MULTIPLIER
                end
                grassAmount = math.floor(grassAmount)

                -- Seed drop check (Zone 2 only)
                local dropSeed = isInZone2()

                -- Send to server (batched: send each collected blade)
                if collectCooldown <= 0 then
                    RE_Collect:FireServer(grassAmount, isGolden, dropSeed)
                    collectCooldown = 0.05  -- 50ms cooldown between fires

                    -- Visual feedback: float-up label
                    local billboard = Instance.new("BillboardGui")
                    billboard.Size           = UDim2.new(0, 60, 0, 30)
                    billboard.StudsOffset    = Vector3.new(0, 2, 0)
                    billboard.AlwaysOnTop    = true
                    billboard.Parent         = blade
                    local lbl = Instance.new("TextLabel")
                    lbl.Size              = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3        = isGolden and GOLDEN_COLOR or Color3.new(1, 1, 1)
                    lbl.TextStrokeTransparency = 0
                    lbl.Text              = "+" .. tostring(grassAmount)
                    lbl.Font              = Enum.Font.GothamBold
                    lbl.TextScaled        = true
                    lbl.Parent            = billboard
                end
            end
        end
    end

    -- Remove collected (reverse order to avoid index shift)
    for i = #toRemove, 1, -1 do
        removeBlade(activeBlade[toRemove[i]], toRemove[i])
    end
end)

-- ────────────────────────────────────────────────────────────
--  Character re-spawn handling
-- ────────────────────────────────────────────────────────────
player.CharacterAdded:Connect(function(char)
    character = char
    rootPart  = char:WaitForChild("HumanoidRootPart")
    -- Clear all blades on death (they're client-local anyway)
    for _, blade in ipairs(activeBlade) do blade:Destroy() end
    activeBlade = {}
end)
