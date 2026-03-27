-- src/client/ForestSystem.client.lua
-- Zone 3 – The Forest (endgame, unlocked when Zone 2 merchant tree complete).
-- Handles: tree generation, axe chopping, Great Bonfire, ash accumulation.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local GameConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BalanceMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceMath"))
local PlayerData  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local RE_ChopTree   = Remotes:WaitForChild("ChopTree")
local RE_BurnWood   = Remotes:WaitForChild("BurnWood")
local RE_Upgrade    = Remotes:WaitForChild("PurchaseUpgrade")
local RE_UpdateData = Remotes:WaitForChild("UpdateData")

local localData = PlayerData.default()
RE_UpdateData.OnClientEvent:Connect(function(data) localData = data end)

-- ────────────────────────────────────────────────────────────
--  Zone references
-- ────────────────────────────────────────────────────────────
local forestPlatform = workspace:WaitForChild("ForestPlatform",  10)
local bonfire        = workspace:WaitForChild("GreatBonfire",     10)
local bonfireBoard   = workspace:WaitForChild("Board_Bonfire",    10)
local axeBoard       = workspace:WaitForChild("Board_Axe",        10)

local FOREST_CENTER  = GameConfig.FOREST_POS
local CHOP_RANGE     = 8   -- studs to chop a tree
local BOARD_RANGE    = 12

-- ────────────────────────────────────────────────────────────
--  Client-side tree pool
-- ────────────────────────────────────────────────────────────
local treeFolder = Instance.new("Folder")
treeFolder.Name   = "ClientTrees"
treeFolder.Parent = workspace

local trees = {}   -- array of { part, hp }

local TREE_COLORS = {
    Color3.fromRGB(60, 40, 20),   -- trunk
}
local LEAF_COLORS = {
    Color3.fromRGB(30, 100, 30),
    Color3.fromRGB(40, 130, 40),
    Color3.fromRGB(20, 80, 20),
}

local MAX_TREES = 12

local function spawnTree()
    if #trees >= MAX_TREES then return end
    local angle  = math.random() * math.pi * 2
    local dist   = math.random() * 30 + 5
    local pos    = FOREST_CENTER + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

    -- Trunk
    local trunk = Instance.new("Part")
    trunk.Anchored   = true
    trunk.CanCollide = true
    trunk.Size       = Vector3.new(1.5, 8, 1.5)
    trunk.Position   = pos + Vector3.new(0, 4, 0)
    trunk.Color      = TREE_COLORS[1]
    trunk.Material   = Enum.Material.Wood
    trunk.Parent     = treeFolder

    -- Leaves
    local leaves = Instance.new("Part")
    leaves.Anchored   = true
    leaves.CanCollide = false
    leaves.Size       = Vector3.new(6, 6, 6)
    leaves.Position   = pos + Vector3.new(0, 10, 0)
    leaves.Color      = LEAF_COLORS[math.random(#LEAF_COLORS)]
    leaves.Material   = Enum.Material.Grass
    leaves.Shape      = Enum.PartType.Ball
    leaves.Parent     = treeFolder

    table.insert(trees, { trunk = trunk, leaves = leaves, hp = GameConfig.FOREST.TREE_HP })
end

-- Initial tree population
for _ = 1, MAX_TREES do spawnTree() end

-- ────────────────────────────────────────────────────────────
--  Chopping logic
-- ────────────────────────────────────────────────────────────
local chopCooldown = 0
local CHOP_INTERVAL = 0.4

local function nearestTree()
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, nil end
    local bestDist = CHOP_RANGE
    local bestTree = nil
    local bestIdx  = nil
    for i, tree in ipairs(trees) do
        if tree.trunk and tree.trunk.Parent then
            local d = (rootPart.Position - tree.trunk.Position).Magnitude
            if d < bestDist then
                bestDist = d
                bestTree = tree
                bestIdx  = i
            end
        end
    end
    return bestTree, bestIdx
end

local function chopTree()
    local tree, idx = nearestTree()
    if not tree then return end
    local power = BalanceMath.axePower(localData)
    tree.hp = tree.hp - power

    -- Visual damage flash
    if tree.trunk then
        local orig = tree.trunk.Color
        tree.trunk.Color = Color3.new(1, 0.5, 0.2)
        task.delay(0.08, function()
            if tree.trunk and tree.trunk.Parent then
                tree.trunk.Color = orig
            end
        end)
    end

    if tree.hp <= 0 then
        -- Tree felled
        local wood = GameConfig.FOREST.WOOD_PER_TREE + BalanceMath.woodBonusPerTree(localData)
        RE_ChopTree:FireServer(wood)

        -- Animate fall: just destroy and respawn
        if tree.trunk  then tree.trunk:Destroy()  end
        if tree.leaves then tree.leaves:Destroy() end
        table.remove(trees, idx)

        -- Floating wood label
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local billboard = Instance.new("BillboardGui")
            billboard.Size        = UDim2.new(0, 80, 0, 35)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee     = rootPart
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(180, 130, 60)
            lbl.Text = "+" .. wood .. " 🌲"
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = billboard
            billboard.Parent = workspace
            game:GetService("Debris"):AddItem(billboard, 1.0)
        end

        -- Respawn after delay
        task.delay(8, spawnTree)
    end
end

-- ────────────────────────────────────────────────────────────
--  Click to chop
-- ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if localData.evolutions < 10 then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local camera = workspace.CurrentCamera
        local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 50)
        if result and result.Instance then
            -- Check if it's a tree part
            for i, tree in ipairs(trees) do
                if result.Instance == tree.trunk or result.Instance == tree.leaves then
                    if chopCooldown <= 0 then
                        chopTree()
                        chopCooldown = CHOP_INTERVAL
                    end
                    break
                end
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
--  Bonfire auto-burn  (client requests burn each interval)
-- ────────────────────────────────────────────────────────────
local burnTimer = 0

-- ────────────────────────────────────────────────────────────
--  Board wiring
-- ────────────────────────────────────────────────────────────
local bonfireBoardWired = false
local axeBoardWired     = false

local function wireBonfireBoard()
    if not bonfireBoard then return end
    local sg = bonfireBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local btnBurn      = frame:FindFirstChild("BurnWood")
    local btnBurnSpeed = frame:FindFirstChild("BuyBurnSpeed")
    local btnAshPBurn  = frame:FindFirstChild("BuyAshPerBurn")

    local nearBonfire = function()
        if not bonfire then return false end
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return false end
        return (rootPart.Position - bonfire.Position).Magnitude <= BOARD_RANGE
    end

    if btnBurn then
        btnBurn.MouseButton1Click:Connect(function()
            if nearBonfire() then RE_BurnWood:FireServer() end
        end)
    end
    if btnBurnSpeed then
        btnBurnSpeed.MouseButton1Click:Connect(function()
            if nearBonfire() then RE_Upgrade:FireServer("bonfire", "burnSpeed") end
        end)
    end
    if btnAshPBurn then
        btnAshPBurn.MouseButton1Click:Connect(function()
            if nearBonfire() then RE_Upgrade:FireServer("bonfire", "ashPerBurn") end
        end)
    end
end

local function wireAxeBoard()
    if not axeBoard then return end
    local sg = axeBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local nearAxe = function()
        if not axeBoard then return false end
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return false end
        return (rootPart.Position - axeBoard.Position).Magnitude <= BOARD_RANGE
    end

    local btnPower = frame:FindFirstChild("BuyAxePower")
    local btnAuto  = frame:FindFirstChild("BuyAutoChop")
    local btnWood  = frame:FindFirstChild("BuyWoodBonus")

    if btnPower then btnPower.MouseButton1Click:Connect(function() if nearAxe() then RE_Upgrade:FireServer("axe","axePower")  end end) end
    if btnAuto  then btnAuto.MouseButton1Click:Connect(function()  if nearAxe() then RE_Upgrade:FireServer("axe","autoChop")  end end) end
    if btnWood  then btnWood.MouseButton1Click:Connect(function()  if nearAxe() then RE_Upgrade:FireServer("axe","woodBonus") end end) end
end

-- ────────────────────────────────────────────────────────────
--  Label updates
-- ────────────────────────────────────────────────────────────
local function updateBonfireLabels()
    if not bonfireBoard then return end
    local sg = bonfireBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuyBurnSpeed",  key = "burnSpeed"  },
        { btn = "BuyAshPerBurn", key = "ashPerBurn" },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.BONFIRE_UPGRADES[u.key]
            local level = (localData.bonfireUpgrades and localData.bonfireUpgrades[u.key]) or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.wood or 0)
            local maxed = level >= def.maxLevel
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " wood]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80,80,80)
                                or (have >= cost and Color3.fromRGB(180,70,0))
                                or Color3.fromRGB(120,50,0)
        end
    end
end

local function updateAxeLabels()
    if not axeBoard then return end
    local sg = axeBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuyAxePower",  key = "axePower"  },
        { btn = "BuyAutoChop",  key = "autoChop"  },
        { btn = "BuyWoodBonus", key = "woodBonus" },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.AXE_UPGRADES[u.key]
            local level = (localData.axeUpgrades and localData.axeUpgrades[u.key]) or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.wood or 0)
            local maxed = level >= def.maxLevel
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " wood]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80,80,80)
                                or (have >= cost and Color3.fromRGB(90,60,30))
                                or Color3.fromRGB(60,40,20)
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  Main loop
-- ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    chopCooldown = chopCooldown - dt
    burnTimer    = burnTimer    + dt

    local forestUnlocked = localData.evolutions >= 10
    -- Forest is actually gated by merchant completion; GameServer and
    -- WorldBuilder handle the visibility reveal via ZoneSignals.
    -- Here we just check if the platform is visible.
    if forestPlatform and forestPlatform.Transparency == 0 then
        forestUnlocked = true
    end

    if not forestUnlocked then return end

    -- Wire boards once
    if not bonfireBoardWired then
        wireBonfireBoard()
        bonfireBoardWired = true
    end
    if not axeBoardWired then
        wireAxeBoard()
        axeBoardWired = true
    end

    -- Auto-burn tick
    local burnInterval = BalanceMath.burnInterval(localData)
    if burnTimer >= burnInterval then
        burnTimer = 0
        if (localData.wood or 0) >= GameConfig.FOREST.WOOD_PER_BURN then
            RE_BurnWood:FireServer()
        end
    end

    updateBonfireLabels()
    updateAxeLabels()
end)

player.CharacterAdded:Connect(function(char)
    character = char
end)
