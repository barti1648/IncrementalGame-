-- src/client/HUD.client.lua
-- Dynamic HUD: shows relevant currencies + board upgrade costs.
-- Color scheme and displayed stats change depending on which
-- platform/zone the player is currently standing on.
-- Also wires ALL board buttons that aren't handled by other scripts.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local GameConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BalanceMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceMath"))
local PlayerData  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local RE_UpdateData = Remotes:WaitForChild("UpdateData")
local RE_Upgrade    = Remotes:WaitForChild("PurchaseUpgrade")
local RE_Rebirth    = Remotes:WaitForChild("DoRebirth")
local RE_Evolution  = Remotes:WaitForChild("DoEvolution")
local RE_Merchant   = Remotes:WaitForChild("PurchaseMerchant")

local localData = PlayerData.default()
RE_UpdateData.OnClientEvent:Connect(function(data) localData = data end)

-- ────────────────────────────────────────────────────────────
--  Zone detection
-- ────────────────────────────────────────────────────────────
local ZONES = {
    platform1 = { xMin=-20, xMax=20,  zMin=-20, zMax=20,  label="🌿 Grassland",    bg=Color3.fromRGB(30,60,20),  accent=Color3.fromRGB(80,180,60)  },
    platform2 = { xMin=20,  xMax=60,  zMin=-20, zMax=20,  label="🧬 Evolution Hub", bg=Color3.fromRGB(10,20,60),  accent=Color3.fromRGB(50,120,255) },
    mining    = { xMin=80,  xMax=120, zMin=-20, zMax=20,  label="⛏ Mining Zone",   bg=Color3.fromRGB(40,30,20),  accent=Color3.fromRGB(180,140,80) },
    mystic    = { xMin=-30, xMax=30,  zMin=170, zMax=230, label="🌀 Mystic Realm",  bg=Color3.fromRGB(40,0,80),   accent=Color3.fromRGB(180,0,255)  },
    forest    = { xMin=-40, xMax=40,  zMin=360, zMax=440, label="🌲 The Forest",    bg=Color3.fromRGB(20,40,10),  accent=Color3.fromRGB(120,80,30)  },
}

local function detectZone(pos)
    for name, z in pairs(ZONES) do
        if pos.X >= z.xMin and pos.X <= z.xMax
        and pos.Z >= z.zMin and pos.Z <= z.zMax then
            return name, z
        end
    end
    return "platform1", ZONES.platform1
end

-- ────────────────────────────────────────────────────────────
--  HUD construction  (ScreenGui)
-- ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "IncrementalHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Main panel (top-left)
local panel = Instance.new("Frame")
panel.Name              = "MainPanel"
panel.Size              = UDim2.new(0, 260, 0, 320)
panel.Position          = UDim2.new(0, 10, 0, 10)
panel.BackgroundColor3  = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel   = 0
panel.Parent            = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

-- Zone label at top of panel
local zoneLabel = Instance.new("TextLabel")
zoneLabel.Name           = "ZoneLabel"
zoneLabel.Size           = UDim2.new(1, 0, 0, 36)
zoneLabel.Position       = UDim2.new(0, 0, 0, 0)
zoneLabel.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
zoneLabel.TextColor3     = Color3.new(1,1,1)
zoneLabel.TextScaled     = true
zoneLabel.Font           = Enum.Font.GothamBold
zoneLabel.Text           = "🌿 Grassland"
zoneLabel.Parent         = panel

local zoneCorner = Instance.new("UICorner")
zoneCorner.CornerRadius = UDim.new(0, 8)
zoneCorner.Parent = zoneLabel

-- Currency rows
local currencies = {
    { key = "grass",    icon = "🌿", label = "Grass",     color = Color3.fromRGB(80, 200, 80)  },
    { key = "clicks",   icon = "👆", label = "Clicks",    color = Color3.fromRGB(255, 200, 50) },
    { key = "rocks",    icon = "🪨", label = "Rocks",     color = Color3.fromRGB(180, 150, 100)},
    { key = "seed",     icon = "🌱", label = "Seeds",     color = Color3.fromRGB(120, 220, 120)},
    { key = "wood",     icon = "🌲", label = "Wood",      color = Color3.fromRGB(160, 110, 50) },
    { key = "ash",      icon = "✨", label = "Ash",       color = Color3.fromRGB(200, 180, 255)},
    { key = "rebirths", icon = "♻️", label = "Rebirths",  color = Color3.fromRGB(180, 80, 255) },
}

local currencyLabels = {}
for i, c in ipairs(currencies) do
    local lbl = Instance.new("TextLabel")
    lbl.Name             = "Currency_" .. c.key
    lbl.Size             = UDim2.new(1, -10, 0, 30)
    lbl.Position         = UDim2.new(0, 5, 0, 36 + (i - 1) * 32)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = c.color
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Text             = c.icon .. " " .. c.label .. ": 0"
    lbl.Visible          = false
    lbl.Parent           = panel
    currencyLabels[c.key] = lbl
end

-- Tip label at bottom
local tipLabel = Instance.new("TextLabel")
tipLabel.Name              = "TipLabel"
tipLabel.Size              = UDim2.new(1, -10, 0, 28)
tipLabel.Position          = UDim2.new(0, 5, 1, -32)
tipLabel.BackgroundTransparency = 1
tipLabel.TextColor3        = Color3.fromRGB(200, 200, 200)
tipLabel.TextScaled        = true
tipLabel.Font              = Enum.Font.Gotham
tipLabel.Text              = "Walk into grass to collect!"
tipLabel.Parent            = panel

-- Ash completion bar (bottom of screen)
local ashBarBg = Instance.new("Frame")
ashBarBg.Name             = "AshBarBg"
ashBarBg.Size             = UDim2.new(0, 400, 0, 20)
ashBarBg.Position         = UDim2.new(0.5, -200, 1, -35)
ashBarBg.BackgroundColor3 = Color3.fromRGB(50, 30, 70)
ashBarBg.Visible          = false
ashBarBg.Parent           = screenGui

local ashBarFill = Instance.new("Frame")
ashBarFill.Name             = "AshBarFill"
ashBarFill.Size             = UDim2.new(0, 0, 1, 0)
ashBarFill.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
ashBarFill.Parent           = ashBarBg

local ashBarLabel = Instance.new("TextLabel")
ashBarLabel.Size              = UDim2.new(1, 0, 1, 0)
ashBarLabel.BackgroundTransparency = 1
ashBarLabel.TextColor3        = Color3.new(1,1,1)
ashBarLabel.TextScaled        = true
ashBarLabel.Font              = Enum.Font.Gotham
ashBarLabel.Text              = "Ash: 0 / 10000"
ashBarLabel.Parent            = ashBarBg

-- ────────────────────────────────────────────────────────────
--  Which currencies to show per zone
-- ────────────────────────────────────────────────────────────
local ZONE_CURRENCIES = {
    platform1 = { "grass", "rebirths" },
    platform2 = { "grass", "clicks",  "rebirths" },
    mining    = { "grass", "rocks",   "clicks", "rebirths" },
    mystic    = { "grass", "seed",    "rebirths" },
    forest    = { "wood",  "ash",     "grass" },
}

local ZONE_TIPS = {
    platform1 = "Walk into grass to collect! Buy upgrades on the boards.",
    platform2 = "Click the Evolve board! Need Rebirths to evolve.",
    mining    = "Click the giant rock to mine! Stone boosts clicks.",
    mystic    = "Collect grass for Seeds (0.25%)! Buy from the Merchant.",
    forest    = "Click trees to chop! Burn wood at the Bonfire for Ash.",
}

-- ────────────────────────────────────────────────────────────
--  Number formatting
-- ────────────────────────────────────────────────────────────
local function fmt(n)
    n = math.floor(n or 0)
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(n) end
end

-- ────────────────────────────────────────────────────────────
--  Board UI wiring  (Boards 1, 2, 3 and Evolution board)
-- ────────────────────────────────────────────────────────────
local boardsWired = false

local function wireAllBoards()
    -- Board 1 – Grass Upgrades
    local board1 = workspace:FindFirstChild("Board_GrassUpgrades")
    if board1 then
        local sg = board1:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if frame then
                local B_RANGE = 10
                local nearB1 = function()
                    local rp = character and character:FindFirstChild("HumanoidRootPart")
                    return rp and (rp.Position - board1.Position).Magnitude <= B_RANGE
                end
                local btnSS = frame:FindFirstChild("BuySpawnSpeed")
                local btnBG = frame:FindFirstChild("BuyBonusGrass")
                local btnR  = frame:FindFirstChild("BuyRadius")
                if btnSS then btnSS.MouseButton1Click:Connect(function() if nearB1() then RE_Upgrade:FireServer("grass","spawnSpeed") end end) end
                if btnBG then btnBG.MouseButton1Click:Connect(function() if nearB1() then RE_Upgrade:FireServer("grass","bonusGrass") end end) end
                if btnR  then btnR.MouseButton1Click:Connect(function()  if nearB1() then RE_Upgrade:FireServer("grass","radius")     end end) end
            end
        end
    end

    -- Board 2 – Rebirth
    local board2 = workspace:FindFirstChild("Board_Rebirth")
    if board2 then
        local sg = board2:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if frame then
                local B_RANGE = 10
                local nearB2 = function()
                    local rp = character and character:FindFirstChild("HumanoidRootPart")
                    return rp and (rp.Position - board2.Position).Magnitude <= B_RANGE
                end
                local btnRb = frame:FindFirstChild("DoRebirth")
                if btnRb then
                    btnRb.MouseButton1Click:Connect(function()
                        if nearB2() then RE_Rebirth:FireServer() end
                    end)
                end
            end
        end
    end

    -- Board 3 – Rebirth Upgrades
    local board3 = workspace:FindFirstChild("Board_RebirthUpgrades")
    if board3 then
        local sg = board3:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if frame then
                local B_RANGE = 10
                local nearB3 = function()
                    local rp = character and character:FindFirstChild("HumanoidRootPart")
                    return rp and (rp.Position - board3.Position).Magnitude <= B_RANGE
                end
                local btnRBG = frame:FindFirstChild("BuyRBGrass")
                local btnAC  = frame:FindFirstChild("BuyAutoCollect")
                local btnFS  = frame:FindFirstChild("BuyFasterSpawn")
                if btnRBG then btnRBG.MouseButton1Click:Connect(function() if nearB3() then RE_Upgrade:FireServer("rebirth","bonusGrass")  end end) end
                if btnAC  then btnAC.MouseButton1Click:Connect(function()  if nearB3() then RE_Upgrade:FireServer("rebirth","autoCollect") end end) end
                if btnFS  then btnFS.MouseButton1Click:Connect(function()  if nearB3() then RE_Upgrade:FireServer("rebirth","fasterSpawn") end end) end
            end
        end
    end

    -- Evolution Board
    local evoBoard = workspace:FindFirstChild("Board_Evolutions")
    if evoBoard then
        local sg = evoBoard:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if frame then
                local B_RANGE = 12
                local nearEvo = function()
                    local rp = character and character:FindFirstChild("HumanoidRootPart")
                    return rp and (rp.Position - evoBoard.Position).Magnitude <= B_RANGE
                end
                local btnEvo = frame:FindFirstChild("DoEvolution")
                if btnEvo then
                    btnEvo.MouseButton1Click:Connect(function()
                        if nearEvo() then RE_Evolution:FireServer() end
                    end)
                end
            end
        end
    end

    -- Merchant Board
    local merchantBoard = workspace:FindFirstChild("Board_Merchant")
    if merchantBoard then
        local sg = merchantBoard:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if frame then
                local B_RANGE = 15
                local nearM = function()
                    local rp = character and character:FindFirstChild("HumanoidRootPart")
                    return rp and (rp.Position - merchantBoard.Position).Magnitude <= B_RANGE
                end
                for _, item in ipairs(GameConfig.MERCHANT_ITEMS) do
                    local btnName = "Buy_" .. item.id
                    local btn = frame:FindFirstChild(btnName)
                    if btn then
                        local id = item.id
                        btn.MouseButton1Click:Connect(function()
                            if nearM() then RE_Merchant:FireServer(id) end
                        end)
                    end
                end
            end
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  Board label updates
-- ────────────────────────────────────────────────────────────
local function updateBoard1Labels()
    local board1 = workspace:FindFirstChild("Board_GrassUpgrades")
    if not board1 then return end
    local sg = board1:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuySpawnSpeed", key = "spawnSpeed" },
        { btn = "BuyBonusGrass", key = "bonusGrass" },
        { btn = "BuyRadius",     key = "radius"     },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.GRASS_UPGRADES[u.key]
            local level = (localData.grassUpgrades and localData.grassUpgrades[u.key]) or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.grass or 0)
            local maxed = level >= def.maxLevel
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " 🌿]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80,80,80)
                                or (have >= cost and Color3.fromRGB(40,120,40))
                                or Color3.fromRGB(80,80,80)
        end
    end
end

local function updateBoard3Labels()
    local board3 = workspace:FindFirstChild("Board_RebirthUpgrades")
    if not board3 then return end
    local sg = board3:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuyRBGrass",    key = "bonusGrass"  },
        { btn = "BuyAutoCollect",key = "autoCollect" },
        { btn = "BuyFasterSpawn",key = "fasterSpawn" },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.REBIRTH_UPGRADES[u.key]
            local level = (localData.rebirthUpgrades and localData.rebirthUpgrades[u.key]) or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.rebirths or 0)
            local maxed = level >= def.maxLevel
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " ♻️]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80,80,80)
                                or (have >= cost and Color3.fromRGB(80,30,140))
                                or Color3.fromRGB(50,20,90)
        end
    end
end

local function updateEvoBoardLabels()
    local evoBoard = workspace:FindFirstChild("Board_Evolutions")
    if not evoBoard then return end
    local sg = evoBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local btn = frame:FindFirstChild("DoEvolution")
    if not btn then return end

    local nextEvo = (localData.evolutions or 0) + 1
    local evoDef  = GameConfig.EVOLUTIONS[nextEvo]
    if evoDef then
        local have  = math.floor(localData.rebirths or 0)
        local aff   = have >= evoDef.rebirthCost
        btn.Text = "⚡ EVOLVE  [Need " .. evoDef.rebirthCost .. " ♻️  Have: " .. have .. "]"
        btn.BackgroundColor3 = aff and Color3.fromRGB(0,100,220) or Color3.fromRGB(40,40,80)
    else
        btn.Text = "✅ All Evolutions Complete!"
        btn.BackgroundColor3 = Color3.fromRGB(0, 160, 0)
    end
end

local function updateMerchantLabels()
    local merchantBoard = workspace:FindFirstChild("Board_Merchant")
    if not merchantBoard then return end
    local sg = merchantBoard:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    for _, item in ipairs(GameConfig.MERCHANT_ITEMS) do
        local btn = frame:FindFirstChild("Buy_" .. item.id)
        if btn then
            local bought = (localData.merchantPurchases and localData.merchantPurchases[item.id]) or 0
            local cost   = BalanceMath.merchantCost(item, bought)
            local have   = math.floor(localData.seed or 0)
            local maxed  = bought >= item.maxBuys
            btn.Text = item.name .. "  [" .. bought .. "/" .. item.maxBuys
                    .. "  Cost: " .. cost .. " 🌱  Have: " .. have .. "]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80,80,80)
                                or (have >= cost and Color3.fromRGB(120,0,200))
                                or Color3.fromRGB(70,0,130)
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  Main HUD update loop
-- ────────────────────────────────────────────────────────────
local currentZoneName = "platform1"

RunService.Heartbeat:Connect(function()
    -- Get player position
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local pos = rootPart.Position

    local zoneName, zoneDef = detectZone(pos)
    currentZoneName = zoneName

    -- Update panel colors
    panel.BackgroundColor3 = zoneDef.bg
    zoneLabel.Text = zoneDef.label
    zoneLabel.BackgroundColor3 = zoneDef.accent

    -- Show/hide currencies for this zone
    local visibleSet = {}
    for _, key in ipairs(ZONE_CURRENCIES[zoneName] or {}) do
        visibleSet[key] = true
    end
    for _, c in ipairs(currencies) do
        local lbl = currencyLabels[c.key]
        if lbl then
            local show = visibleSet[c.key] or false
            lbl.Visible = show
            if show then
                local val = math.floor(localData[c.key] or 0)
                lbl.Text = c.icon .. " " .. c.label .. ": " .. fmt(val)
            end
        end
    end

    -- Resize panel height to fit visible currencies
    local count = 0
    for _, v in pairs(visibleSet) do if v then count = count + 1 end end
    panel.Size = UDim2.new(0, 260, 0, 40 + count * 32 + 36)

    -- Tip
    tipLabel.Text = ZONE_TIPS[zoneName] or ""

    -- Ash completion bar (visible in Forest)
    local ashGoal = GameConfig.FOREST.ASH_COMPLETION_GOAL
    local ashHave = localData.ash or 0
    ashBarBg.Visible = (zoneName == "forest" or ashHave > 0)
    if ashBarBg.Visible then
        local pct = math.min(1, ashHave / ashGoal)
        ashBarFill.Size = UDim2.new(pct, 0, 1, 0)
        ashBarLabel.Text = "✨ Ash: " .. fmt(ashHave) .. " / " .. fmt(ashGoal)
                        .. "  (" .. string.format("%.1f", pct * 100) .. "%)"
        if pct >= 1 then
            ashBarFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            ashBarLabel.Text = "🏆 GAME COMPLETE! " .. fmt(ashHave) .. " Ash!"
        end
    end

    -- Wire boards once
    if not boardsWired then
        wireAllBoards()
        boardsWired = true
    end

    -- Update board labels
    updateBoard1Labels()
    updateBoard3Labels()
    updateEvoBoardLabels()
    updateMerchantLabels()
end)

player.CharacterAdded:Connect(function(char)
    character = char
    boardsWired = false  -- re-wire after respawn
end)
