-- src/client/MiningSystem.client.lua
-- Handles the Mining Zone (Evo ≥ 4).
-- Client generates rock-hit visuals; server validates rock income.

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
local RE_Mine       = Remotes:WaitForChild("MineRock")
local RE_Upgrade    = Remotes:WaitForChild("PurchaseUpgrade")
local RE_UpdateData = Remotes:WaitForChild("UpdateData")

local localData = PlayerData.default()
RE_UpdateData.OnClientEvent:Connect(function(data) localData = data end)

-- ────────────────────────────────────────────────────────────
--  References
-- ────────────────────────────────────────────────────────────
local giantRock   = workspace:WaitForChild("GiantRock",  10)
local mineBoard   = workspace:WaitForChild("Board_Mining", 10)

local MINE_RANGE  = 10  -- studs to interact with the rock

local function nearRock()
    if not giantRock then return false end
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return (rootPart.Position - giantRock.Position).Magnitude <= MINE_RANGE
end

-- ────────────────────────────────────────────────────────────
--  Swing cooldown  (client-side rate limiting)
-- ────────────────────────────────────────────────────────────
local swingCooldown = 0
local SWING_INTERVAL = 0.35  -- seconds between swings

local function doSwing()
    if not nearRock() then return end
    local rocks = BalanceMath.rocksPerSwing(localData)
    RE_Mine:FireServer(rocks)

    -- Visual: flash rock white briefly
    if giantRock then
        local orig = giantRock.Color
        giantRock.Color = Color3.new(1, 1, 1)
        task.delay(0.08, function()
            if giantRock and giantRock.Parent then
                giantRock.Color = orig
            end
        end)

        -- Floating number
        local billboard = Instance.new("BillboardGui")
        billboard.Size        = UDim2.new(0, 70, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent      = giantRock
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(180, 160, 100)
        lbl.Text = "+" .. rocks .. " 🪨"
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = billboard
        game:GetService("Debris"):AddItem(billboard, 0.8)
    end
end

-- ────────────────────────────────────────────────────────────
--  Click-to-mine
-- ────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if localData.evolutions < 4 then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Check if clicking on the rock
        local camera = workspace.CurrentCamera
        local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 50)
        if result and result.Instance == giantRock then
            if swingCooldown <= 0 then
                doSwing()
                swingCooldown = SWING_INTERVAL
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
--  Mining Board button wiring
-- ────────────────────────────────────────────────────────────
local boardWired = false
local BOARD_RANGE = 12

local function nearBoard()
    if not mineBoard then return false end
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return (rootPart.Position - mineBoard.Position).Magnitude <= BOARD_RANGE
end

local function wireBoard()
    if not mineBoard then return end
    local sg = mineBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local btnPickaxe = frame:FindFirstChild("BuyPickaxePower")
    local btnAuto    = frame:FindFirstChild("BuyAutoMine")

    if btnPickaxe then
        btnPickaxe.MouseButton1Click:Connect(function()
            if nearBoard() then RE_Upgrade:FireServer("mining", "pickaxePower") end
        end)
    end
    if btnAuto then
        btnAuto.MouseButton1Click:Connect(function()
            if nearBoard() then RE_Upgrade:FireServer("mining", "autoMine") end
        end)
    end
end

-- ────────────────────────────────────────────────────────────
--  Update loop
-- ────────────────────────────────────────────────────────────
local function updateBoardLabels()
    if not mineBoard then return end
    local sg = mineBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuyPickaxePower", key = "pickaxePower" },
        { btn = "BuyAutoMine",     key = "autoMine" },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.MINING_UPGRADES[u.key]
            local level = localData.miningUpgrades[u.key] or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.rocks or 0)
            local maxed = level >= def.maxLevel
            local aff   = have >= cost
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " rocks]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80, 80, 80)
                                or (aff   and Color3.fromRGB(140, 100, 40))
                                or Color3.fromRGB(80, 60, 20)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    swingCooldown = swingCooldown - dt

    local miningUnlocked = localData.evolutions >= 4
    if not miningUnlocked then return end

    -- Reveal zone
    if giantRock then
        giantRock.Transparency = 0
        giantRock.CanCollide   = true
    end
    if mineBoard then
        mineBoard.Transparency = 0
        mineBoard.CanCollide   = true
    end

    if not boardWired then
        wireBoard()
        boardWired = true
    end

    updateBoardLabels()
end)

player.CharacterAdded:Connect(function(char)
    character = char
end)
