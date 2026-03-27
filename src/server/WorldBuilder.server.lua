-- src/server/WorldBuilder.server.lua
-- Builds the physical world: platforms, boards, zones, portals.
-- All geometry is server-side (shared for all players).
-- Board GUIs use SurfaceGui so clients can click buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

-- ────────────────────────────────────────────────────────────
--  Utility helpers
-- ────────────────────────────────────────────────────────────
local function part(props)
    local p = Instance.new("Part")
    p.Anchored    = true
    p.CanCollide  = true
    p.CastShadow  = false
    for k, v in pairs(props) do p[k] = v end
    p.Parent = workspace
    return p
end

local function weld(a, b)
    local w = Instance.new("WeldConstraint")
    w.Part0  = a
    w.Part1  = b
    w.Parent = a
    return w
end

-- Creates a SurfaceGui with a header label on a Part's front face.
local function makeBoardGui(boardPart, title, bgColor)
    local sg = Instance.new("SurfaceGui")
    sg.Face             = Enum.NormalId.Front
    sg.SizingMode       = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud    = 50
    sg.AlwaysOnTop      = false
    sg.CanvasSize       = Vector2.new(500, 700)
    sg.Parent           = boardPart

    local bg = Instance.new("Frame")
    bg.Size            = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = bgColor or Color3.fromRGB(30, 30, 40)
    bg.Parent           = sg

    local title_lbl = Instance.new("TextLabel")
    title_lbl.Size              = UDim2.new(1, 0, 0, 60)
    title_lbl.Position          = UDim2.new(0, 0, 0, 0)
    title_lbl.BackgroundColor3  = Color3.fromRGB(20, 120, 20)
    title_lbl.TextColor3        = Color3.new(1, 1, 1)
    title_lbl.TextScaled        = true
    title_lbl.Font              = Enum.Font.GothamBold
    title_lbl.Text              = title
    title_lbl.Parent            = bg

    return bg  -- return the frame so callers can add rows
end

local function addButton(parent, yOffset, text, bgColor, name)
    local btn = Instance.new("TextButton")
    btn.Name              = name or text
    btn.Size              = UDim2.new(0.9, 0, 0, 55)
    btn.Position          = UDim2.new(0.05, 0, 0, yOffset)
    btn.BackgroundColor3  = bgColor or Color3.fromRGB(50, 160, 50)
    btn.TextColor3        = Color3.new(1, 1, 1)
    btn.TextScaled        = true
    btn.Font              = Enum.Font.Gotham
    btn.Text              = text
    btn.Parent            = parent
    return btn
end

local function addLabel(parent, yOffset, text, bgColor)
    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0.9, 0, 0, 48)
    lbl.Position          = UDim2.new(0.05, 0, 0, yOffset)
    lbl.BackgroundColor3  = bgColor or Color3.fromRGB(40, 40, 55)
    lbl.TextColor3        = Color3.new(1, 1, 1)
    lbl.TextScaled        = true
    lbl.Font              = Enum.Font.Gotham
    lbl.Text              = text
    lbl.Parent            = parent
    return lbl
end

-- ────────────────────────────────────────────────────────────
--  Platform 1  (0,0,0)  40×1×40
-- ────────────────────────────────────────────────────────────
local plat1 = part({
    Name     = "Platform1",
    Size     = Vector3.new(40, 1, 40),
    Position = Vector3.new(0, -0.5, 0),
    Material = Enum.Material.Grass,
    Color    = Color3.fromRGB(106, 127, 63),
})

-- Board 1 – Grass Upgrades
local board1 = part({
    Name     = "Board_GrassUpgrades",
    Size     = Vector3.new(0.5, 8, 5),
    Position = Vector3.new(-18, 3.5, -10),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(120, 80, 40),
})
do
    local frame = makeBoardGui(board1, "🌿 Grass Upgrades", Color3.fromRGB(30, 60, 20))
    addButton(frame,  70, "⚡ Spawn Speed  [cost: grass]",    Color3.fromRGB(40, 100, 40), "BuySpawnSpeed")
    addButton(frame, 135, "🌿 +1 Grass/Pick [cost: grass]",   Color3.fromRGB(40, 100, 40), "BuyBonusGrass")
    addButton(frame, 200, "🔵 Wider Radius  [cost: grass]",   Color3.fromRGB(40, 100, 40), "BuyRadius")
    addLabel (frame, 270, "Costs shown in HUD when near board")
end

-- Board 2 – Rebirth Board
local board2 = part({
    Name     = "Board_Rebirth",
    Size     = Vector3.new(0.5, 6, 4),
    Position = Vector3.new(-18, 2.5, 0),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(80, 50, 150),
})
do
    local frame = makeBoardGui(board2, "♻️ Rebirth", Color3.fromRGB(40, 20, 80))
    addLabel (frame,  70, "500 Grass = 1 Rebirth Point")
    addLabel (frame, 125, "Wipes: Grass, Clicks, Rocks,")
    addLabel (frame, 173, "Seeds, Wood & Field Upgrades")
    addButton(frame, 240, "♻️ REBIRTH", Color3.fromRGB(120, 40, 180), "DoRebirth")
end

-- Board 3 – Rebirth Upgrades
local board3 = part({
    Name     = "Board_RebirthUpgrades",
    Size     = Vector3.new(0.5, 8, 5),
    Position = Vector3.new(-18, 3.5, 10),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(100, 60, 160),
})
do
    local frame = makeBoardGui(board3, "⭐ Rebirth Upgrades", Color3.fromRGB(40, 20, 70))
    addLabel (frame,  70, "Paid with Rebirth Points")
    addLabel (frame, 118, "Survive Rebirth  (reset on Evo)")
    addButton(frame, 180, "🌱 +1 Grass  [cost: rebirths]",    Color3.fromRGB(80, 30, 140), "BuyRBGrass")
    addButton(frame, 245, "🤖 Auto-Collect [cost: rebirths]", Color3.fromRGB(80, 30, 140), "BuyAutoCollect")
    addButton(frame, 310, "🚀 Spawn Rate   [cost: rebirths]", Color3.fromRGB(80, 30, 140), "BuyFasterSpawn")
end

-- ────────────────────────────────────────────────────────────
--  Platform 2  (40,0,0)  40×1×40
-- ────────────────────────────────────────────────────────────
local plat2 = part({
    Name     = "Platform2",
    Size     = Vector3.new(40, 1, 40),
    Position = Vector3.new(40, -0.5, 0),
    Material = Enum.Material.SmoothPlastic,
    Color    = Color3.fromRGB(163, 162, 165),
})

-- Evolution Board  (tall, fits 10 entries)
local evoBoard = part({
    Name     = "Board_Evolutions",
    Size     = Vector3.new(0.5, 14, 7),
    Position = Vector3.new(22, 6.5, 0),
    Material = Enum.Material.Neon,
    Color    = Color3.fromRGB(0, 80, 200),
})
do
    local frame = makeBoardGui(evoBoard, "🧬 Evolutions", Color3.fromRGB(10, 20, 60))
    frame.Parent.CanvasSize = Vector2.new(500, 900)
    -- Evolve button at top
    addButton(frame, 70, "⚡ EVOLVE (costs Rebirths)", Color3.fromRGB(0, 100, 220), "DoEvolution")
    -- List the 10 evolutions
    for i, evo in ipairs(GameConfig.EVOLUTIONS) do
        local yOff = 140 + (i - 1) * 70
        addLabel(frame, yOff, i .. ". " .. evo.description .. "  [" .. evo.rebirthCost .. " RB]",
                 Color3.fromRGB(15, 30, 80))
    end
end

-- ────────────────────────────────────────────────────────────
--  Clicker Board  (appears after Evo ≥ 1, on Platform 2)
-- ────────────────────────────────────────────────────────────
local clickerBoard = part({
    Name     = "Board_Clicker",
    Size     = Vector3.new(0.5, 8, 5),
    Position = Vector3.new(58, 3.5, -10),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(180, 120, 30),
})
clickerBoard.Transparency = 1
clickerBoard.CanCollide   = false
do
    local frame = makeBoardGui(clickerBoard, "👆 Clicker", Color3.fromRGB(60, 40, 10))
    -- Big clickable square
    addButton(frame,  70, "👆 CLICK!", Color3.fromRGB(220, 140, 20), "ClickButton")
    addLabel (frame, 140, "Earn Clicks → buy upgrades")
    addButton(frame, 200, "👆 +1 Click Power [clicks]",   Color3.fromRGB(160, 100, 20), "BuyClickPower")
    addButton(frame, 265, "🤖 Auto-Click     [clicks]",   Color3.fromRGB(160, 100, 20), "BuyAutoClick")
    addButton(frame, 330, "🌿 Grass/Click    [clicks]",   Color3.fromRGB(160, 100, 20), "BuyGrassPerClick")
end

-- ────────────────────────────────────────────────────────────
--  Mining Zone  (Position: 100,0,0;  appears after Evo ≥ 4)
-- ────────────────────────────────────────────────────────────
local miningPlatform = part({
    Name     = "MiningPlatform",
    Size     = Vector3.new(40, 1, 40),
    Position = Vector3.new(100, -0.5, 0),
    Material = Enum.Material.Rock,
    Color    = Color3.fromRGB(100, 90, 80),
})
miningPlatform.Transparency = 1
miningPlatform.CanCollide   = false

-- Giant Rock
local giantRock = part({
    Name     = "GiantRock",
    Size     = Vector3.new(8, 8, 8),
    Position = Vector3.new(100, 3.5, 0),
    Material = Enum.Material.Rock,
    Color    = Color3.fromRGB(130, 110, 90),
    Shape    = Enum.PartType.Ball,
})
giantRock.Transparency = 1
giantRock.CanCollide   = false

-- Mining Upgrade Board
local mineBoard = part({
    Name     = "Board_Mining",
    Size     = Vector3.new(0.5, 8, 5),
    Position = Vector3.new(82, 3.5, 0),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(100, 80, 60),
})
mineBoard.Transparency = 1
mineBoard.CanCollide   = false
do
    local frame = makeBoardGui(mineBoard, "⛏ Mining Upgrades", Color3.fromRGB(50, 40, 30))
    addButton(frame,  70, "⛏ Pickaxe Power [rocks]",  Color3.fromRGB(140, 100, 40), "BuyPickaxePower")
    addButton(frame, 135, "🤖 Auto-Mine     [rocks]",  Color3.fromRGB(140, 100, 40), "BuyAutoMine")
end

-- ────────────────────────────────────────────────────────────
--  Portal  (on Platform 2 rear; appears after Evo 9)
-- ────────────────────────────────────────────────────────────
local portal = part({
    Name      = "Portal_MysticRealm",
    Size      = Vector3.new(6, 8, 1),
    Position  = Vector3.new(40, 3.5, -22),
    Material  = Enum.Material.Neon,
    Color     = Color3.fromRGB(100, 0, 200),
    Transparency = 0.4,
    CanCollide   = false,
})
portal.Transparency = 1

-- Portal touch → teleport to Mystic Realm
portal.Touched:Connect(function(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    -- Only teleport if Evo ≥ 9 (portal evolution)
    local data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))
    -- We just teleport; GameServer handles zone access
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(GameConfig.MYSTIC_REALM_POS + Vector3.new(0, 3, 0))
    end
end)

-- ────────────────────────────────────────────────────────────
--  Zone 2 – Mystic Realm  (200,0,200)
-- ────────────────────────────────────────────────────────────
local mysticPlatform = part({
    Name     = "MysticPlatform",
    Size     = Vector3.new(60, 1, 60),
    Position = GameConfig.MYSTIC_REALM_POS + Vector3.new(0, -0.5, 0),
    Material = Enum.Material.Neon,
    Color    = Color3.fromRGB(80, 0, 140),
})
mysticPlatform.Transparency = 1

-- Permanent Merchant Board
local merchantBoard = part({
    Name     = "Board_Merchant",
    Size     = Vector3.new(0.5, 10, 6),
    Position = GameConfig.MYSTIC_REALM_POS + Vector3.new(0, 4.5, -25),
    Material = Enum.Material.Neon,
    Color    = Color3.fromRGB(160, 0, 255),
})
merchantBoard.Transparency = 1
do
    local frame = makeBoardGui(merchantBoard, "🏪 Mystic Merchant", Color3.fromRGB(40, 0, 80))
    frame.Parent.CanvasSize = Vector2.new(500, 800)
    addLabel(frame, 70, "Offer rotates every 5 minutes")
    addLabel(frame, 118, "Paid with 🌱 Seeds (permanent!)")
    for i, item in ipairs(GameConfig.MERCHANT_ITEMS) do
        local yOff = 180 + (i - 1) * 100
        addLabel (frame, yOff,      item.name .. ": " .. item.desc,     Color3.fromRGB(50, 10, 90))
        addButton(frame, yOff + 52, "Buy " .. item.name,                Color3.fromRGB(120, 0, 200),  "Buy_" .. item.id)
    end
end

-- Return portal from Mystic Realm
local portalBack = part({
    Name      = "Portal_Back",
    Size      = Vector3.new(5, 7, 1),
    Position  = GameConfig.MYSTIC_REALM_POS + Vector3.new(25, 3, 0),
    Material  = Enum.Material.Neon,
    Color     = Color3.fromRGB(0, 150, 200),
    CanCollide = false,
    Transparency = 0.4,
})
portalBack.Transparency = 1

portalBack.Touched:Connect(function(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(40, 3, 0)
    end
end)

-- ────────────────────────────────────────────────────────────
--  Zone 3 – The Forest  (0,0,400)
-- ────────────────────────────────────────────────────────────
local forestPlatform = part({
    Name     = "ForestPlatform",
    Size     = Vector3.new(80, 1, 80),
    Position = GameConfig.FOREST_POS + Vector3.new(0, -0.5, 0),
    Material = Enum.Material.Grass,
    Color    = Color3.fromRGB(50, 80, 30),
})
forestPlatform.Transparency = 1

-- Great Bonfire
local bonfire = part({
    Name      = "GreatBonfire",
    Size      = Vector3.new(5, 5, 5),
    Position  = GameConfig.FOREST_POS + Vector3.new(0, 2, 0),
    Material  = Enum.Material.Neon,
    Color     = Color3.fromRGB(255, 80, 0),
    Shape     = Enum.PartType.Ball,
    CanCollide = false,
})
bonfire.Transparency = 1

-- Bonfire board
local bonfireBoard = part({
    Name     = "Board_Bonfire",
    Size     = Vector3.new(0.5, 8, 5),
    Position = GameConfig.FOREST_POS + Vector3.new(15, 3.5, 0),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(120, 60, 20),
})
bonfireBoard.Transparency = 1
do
    local frame = makeBoardGui(bonfireBoard, "🔥 Great Bonfire", Color3.fromRGB(60, 20, 0))
    addLabel (frame,  70, "Burn Wood → earn Ash")
    addLabel (frame, 118, "Each Ash: +0.1% ALL currencies")
    addButton(frame, 175, "🔥 Burn Wood",                        Color3.fromRGB(200, 80, 0),   "BurnWood")
    addButton(frame, 240, "🔥 Burn Speed  [wood]",               Color3.fromRGB(160, 60, 0),   "BuyBurnSpeed")
    addButton(frame, 305, "✨ +1 Ash/Burn [wood]",               Color3.fromRGB(160, 60, 0),   "BuyAshPerBurn")
end

-- Forest axe board
local axeBoard = part({
    Name     = "Board_Axe",
    Size     = Vector3.new(0.5, 8, 5),
    Position = GameConfig.FOREST_POS + Vector3.new(-15, 3.5, 0),
    Material = Enum.Material.Wood,
    Color    = Color3.fromRGB(80, 60, 40),
})
axeBoard.Transparency = 1
do
    local frame = makeBoardGui(axeBoard, "🪓 Axe Upgrades", Color3.fromRGB(30, 20, 10))
    addButton(frame,  70, "🪓 Axe Power    [wood]",  Color3.fromRGB(100, 70, 30), "BuyAxePower")
    addButton(frame, 135, "🤖 Auto-Chop    [wood]",  Color3.fromRGB(100, 70, 30), "BuyAutoChop")
    addButton(frame, 200, "🌲 +1 Wood/Tree [wood]",  Color3.fromRGB(100, 70, 30), "BuyWoodBonus")
end

-- ────────────────────────────────────────────────────────────
--  Zone unlock function  (called by WorldBuilder when needed)
--  Client scripts listen to player data updates and call
--  their own reveal logic; server makes the Parts visible here.
-- ────────────────────────────────────────────────────────────
local function setVisible(p, v)
    p.Transparency = v and 0 or 1
    p.CanCollide   = v
end

-- Store references so the unlock logic can reach them
local zoneObjects = {
    clicker       = { clickerBoard },
    mining        = { miningPlatform, giantRock, mineBoard },
    portal        = { portal },
    mystic        = { mysticPlatform, merchantBoard, portalBack },
    forest        = { forestPlatform, bonfire, bonfireBoard, axeBoard },
}

-- Shared folder so GameServer can signal WorldBuilder to reveal zones
local ZoneSignals = Instance.new("Folder")
ZoneSignals.Name   = "ZoneSignals"
ZoneSignals.Parent = ReplicatedStorage

local function makeSignal(name)
    local e = Instance.new("RemoteEvent")
    e.Name   = name
    e.Parent = ZoneSignals
    return e
end

local RS_RevealZone = makeSignal("RevealZone")
RS_RevealZone.OnServerEvent:Connect(function(_, zone)
    -- Only server itself should call this; ignore client fires
end)

-- Listen for data updates broadcast and reveal zones accordingly
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if Remotes then
    local RE_UpdateData = Remotes:WaitForChild("UpdateData", 10)
    if RE_UpdateData then
        -- We can't listen to OnServerEvent for UpdateData (it's S→C).
        -- Instead, use PlayerAdded to check on join and hook into
        -- Heartbeat for live reveal as evolutions are bought.
        game:GetService("RunService").Heartbeat:Connect(function()
            for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
                local ls = player:FindFirstChild("leaderstats")
                if ls then
                    local evoVal = ls:FindFirstChild("Evolutions")
                    if evoVal then
                        local evo = evoVal.Value
                        if evo >= 1  then for _, p in ipairs(zoneObjects.clicker) do setVisible(p, true) end end
                        if evo >= 4  then for _, p in ipairs(zoneObjects.mining)  do setVisible(p, true) end end
                        if evo >= 9  then for _, p in ipairs(zoneObjects.portal)  do setVisible(p, true) end end
                        if evo >= 10 then for _, p in ipairs(zoneObjects.mystic)  do setVisible(p, true) end end
                        -- Forest unlocks when merchant tree is complete (handled differently)
                    end
                end
            end
        end)
    end
end

-- Forest unlock signal from GameServer when merchant tree complete
local RE_UnlockForest = makeSignal("UnlockForest")
RE_UnlockForest.OnServerEvent:Connect(function(_)
    for _, p in ipairs(zoneObjects.forest) do setVisible(p, true) end
end)

print("[WorldBuilder] World built successfully.")
