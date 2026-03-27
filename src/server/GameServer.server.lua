-- src/server/GameServer.server.lua
-- Main server-side game handler.
-- Responsibilities:
--   • Create RemoteEvents in ReplicatedStorage
--   • Load / save player data via DataStore
--   • Validate every currency change (anti-cheat)
--   • Handle: CollectGrass, Click, Mine, ChopTree, BurnWood,
--             PurchaseUpgrade, DoRebirth, DoEvolution, PurchaseMerchant

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

local GameConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BalanceMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceMath"))
local PlayerData  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

-- ────────────────────────────────────────────────────────────
--  DataStore
-- ────────────────────────────────────────────────────────────
local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_KEY)

-- ────────────────────────────────────────────────────────────
--  RemoteEvent / RemoteFunction setup
-- ────────────────────────────────────────────────────────────
local Remotes = Instance.new("Folder")
Remotes.Name  = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeEvent(name)
    local e = Instance.new("RemoteEvent")
    e.Name   = name
    e.Parent = Remotes
    return e
end
local function makeFunc(name)
    local f = Instance.new("RemoteFunction")
    f.Name   = name
    f.Parent = Remotes
    return f
end

local RE_CollectGrass    = makeEvent("CollectGrass")
local RE_Click           = makeEvent("ClickClicker")
local RE_MineRock        = makeEvent("MineRock")
local RE_ChopTree        = makeEvent("ChopTree")
local RE_BurnWood        = makeEvent("BurnWood")
local RE_PurchaseUpgrade = makeEvent("PurchaseUpgrade")
local RE_DoRebirth       = makeEvent("DoRebirth")
local RE_DoEvolution     = makeEvent("DoEvolution")
local RE_PurchaseMerchant= makeEvent("PurchaseMerchant")
local RE_UpdateData      = makeEvent("UpdateData")   -- server → client push

local RF_GetPlayerData   = makeFunc("GetPlayerData")

-- ────────────────────────────────────────────────────────────
--  In-memory player data cache
-- ────────────────────────────────────────────────────────────
local playerCache = {}   -- [userId] = data table

local function getCache(player)
    return playerCache[player.UserId]
end

local function pushUpdate(player)
    local data = getCache(player)
    if data then
        RE_UpdateData:FireClient(player, data)
    end
end

-- ────────────────────────────────────────────────────────────
--  Leaderstats
-- ────────────────────────────────────────────────────────────
local function updateLeaderstats(player, data)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then
        ls = Instance.new("Folder")
        ls.Name   = "leaderstats"
        ls.Parent = player
    end
    local function stat(name, val)
        local v = ls:FindFirstChild(name)
        if not v then
            v = Instance.new("IntValue")
            v.Name   = name
            v.Parent = ls
        end
        v.Value = val
    end
    stat("Rebirths",   data.rebirths or 0)
    stat("Evolutions", data.evolutions or 0)
end

-- ────────────────────────────────────────────────────────────
--  DataStore load / save
-- ────────────────────────────────────────────────────────────
local function loadPlayer(player)
    local ok, result = pcall(function()
        return store:GetAsync("player_" .. player.UserId)
    end)
    local data
    if ok and result then
        data = PlayerData.merge(result)
    else
        data = PlayerData.default()
    end
    playerCache[player.UserId] = data
    updateLeaderstats(player, data)
    pushUpdate(player)
end

local function savePlayer(player)
    local data = getCache(player)
    if not data then return end
    local ok, err = pcall(function()
        store:SetAsync("player_" .. player.UserId, data)
    end)
    if not ok then
        warn("[DataStore] Save failed for", player.Name, err)
    end
end

-- Auto-save every 60 seconds
local saveTimer = 0
RunService.Heartbeat:Connect(function(dt)
    saveTimer = saveTimer + dt
    if saveTimer >= 60 then
        saveTimer = 0
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayer(player)
        end
    end
end)

-- ────────────────────────────────────────────────────────────
--  Anti-cheat helpers
-- ────────────────────────────────────────────────────────────
local function clamp(value, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, value))
end

-- Rate-limit table: [userId][currency] = {total, lastReset}
local rateTracker = {}

local function checkRate(player, currency, amount, maxPerRequest)
    if amount <= 0 then return false end
    if amount > maxPerRequest then
        warn("[AntiCheat] Player", player.Name, "sent", amount, currency, "(max", maxPerRequest .. ")")
        return false
    end
    return true
end

-- ────────────────────────────────────────────────────────────
--  Rebirth helpers
-- ────────────────────────────────────────────────────────────
local function doReset_Rebirth(data)
    -- Wipe: grass, clicks, rocks, seed, wood and grass upgrades
    data.grass  = 0
    data.clicks = 0
    data.rocks  = 0
    data.seed   = 0
    data.wood   = 0
    -- grass upgrades reset
    data.grassUpgrades   = { spawnSpeed = 0, bonusGrass = 0, radius = 0 }
    data.clickerUpgrades = { clickPower = 0, autoClick  = 0, bonusGrass = 0 }
    data.miningUpgrades  = { pickaxePower = 0, autoMine = 0 }
    -- axeUpgrades and bonfireUpgrades stay (Zone 3 is permanent)
    -- rebirthUpgrades STAY
end

local function doReset_Evolution(data)
    doReset_Rebirth(data)
    data.rebirths = 0
    data.rebirthUpgrades = { bonusGrass = 0, autoCollect = 0, fasterSpawn = 0 }
    -- evolutions count stays, ash stays, merchantPurchases stays, bonfireUpgrades stay
end

-- ────────────────────────────────────────────────────────────
--  Remote handlers
-- ────────────────────────────────────────────────────────────

-- CollectGrass(amount, isGolden, isSeed)
RE_CollectGrass.OnServerEvent:Connect(function(player, amount, isGolden, dropSeed)
    local data = getCache(player)
    if not data then return end
    amount = math.floor(tonumber(amount) or 0)
    if not checkRate(player, "grass", amount, GameConfig.ANTICHEAT.MAX_GRASS_PER_REQUEST) then return end

    -- Validate: amount should be ≤ computed grass-per-pickup (with generous tolerance)
    local expected = BalanceMath.grassPerPickup(data)
    if isGolden then expected = expected * GameConfig.GRASS.GOLDEN_GRASS_MULTIPLIER end
    -- Allow up to 2× expected (auto-collect batching can increase this)
    if amount > expected * 2 + 10 then
        warn("[AntiCheat] Grass amount", amount, "exceeds expected", expected, "for", player.Name)
        amount = expected
    end

    data.grass = data.grass + amount

    -- Seed drop (Zone 2 only — client passes dropSeed flag but we re-roll on server)
    if dropSeed then
        local seedChance = BalanceMath.seedDropChance(data)
        if math.random() < seedChance then
            data.seed = data.seed + 1
        end
    end

    updateLeaderstats(player, data)
    pushUpdate(player)
end)

-- ClickClicker(clicks)
RE_Click.OnServerEvent:Connect(function(player, clicks)
    local data = getCache(player)
    if not data then return end
    if data.evolutions < 1 then return end
    clicks = math.floor(tonumber(clicks) or 0)
    if not checkRate(player, "clicks", clicks, GameConfig.ANTICHEAT.MAX_CLICKS_PER_REQUEST) then return end

    local expected = BalanceMath.clicksPerClick(data)
    if clicks > expected * 2 then
        clicks = expected
    end

    data.clicks = data.clicks + clicks
    -- Also give grass-per-click bonus
    local grassGain = BalanceMath.grassPerClick(data)
    if grassGain > 0 then
        data.grass = data.grass + grassGain
    end

    pushUpdate(player)
end)

-- MineRock(rocks)
RE_MineRock.OnServerEvent:Connect(function(player, rocks)
    local data = getCache(player)
    if not data then return end
    if data.evolutions < 4 then return end
    rocks = math.floor(tonumber(rocks) or 0)
    if not checkRate(player, "rocks", rocks, GameConfig.ANTICHEAT.MAX_ROCKS_PER_REQUEST) then return end

    local expected = BalanceMath.rocksPerSwing(data)
    if rocks > expected * 2 then rocks = expected end
    data.rocks = data.rocks + rocks

    pushUpdate(player)
end)

-- ChopTree(wood)
RE_ChopTree.OnServerEvent:Connect(function(player, wood)
    local data = getCache(player)
    if not data then return end
    if data.evolutions < 10 then return end  -- Forest is post-Evo 10 via merchant
    wood = math.floor(tonumber(wood) or 0)
    if not checkRate(player, "wood", wood, GameConfig.ANTICHEAT.MAX_WOOD_PER_REQUEST) then return end

    local expected = GameConfig.FOREST.WOOD_PER_TREE + BalanceMath.woodBonusPerTree(data)
    if wood > expected + 5 then wood = expected end
    data.wood = data.wood + wood

    pushUpdate(player)
end)

-- BurnWood()  — server-driven burn tick; client just requests it
RE_BurnWood.OnServerEvent:Connect(function(player)
    local data = getCache(player)
    if not data then return end
    if data.evolutions < 10 then return end
    local woodCost = GameConfig.FOREST.WOOD_PER_BURN
    if data.wood < woodCost then return end
    data.wood = data.wood - woodCost
    local ashGain = BalanceMath.ashPerBurn(data)
    data.ash = data.ash + ashGain

    pushUpdate(player)
end)

-- PurchaseUpgrade(category, upgradeKey)
RE_PurchaseUpgrade.OnServerEvent:Connect(function(player, category, upgradeKey)
    local data = getCache(player)
    if not data then return end

    local function tryBuy(upgradeDef, upgradeTable, currency)
        local level = upgradeTable[upgradeKey] or 0
        if level >= upgradeDef.maxLevel then return false end
        local cost = BalanceMath.upgradeCost(upgradeDef, level)
        if (data[currency] or 0) < cost then return false end
        data[currency] = data[currency] - cost
        upgradeTable[upgradeKey] = level + 1
        return true
    end

    local bought = false
    if category == "grass" and data.grassUpgrades[upgradeKey] ~= nil then
        local def = GameConfig.GRASS_UPGRADES[upgradeKey]
        if def then bought = tryBuy(def, data.grassUpgrades, "grass") end

    elseif category == "rebirth" and data.rebirthUpgrades[upgradeKey] ~= nil then
        local def = GameConfig.REBIRTH_UPGRADES[upgradeKey]
        if def then bought = tryBuy(def, data.rebirthUpgrades, "rebirths") end

    elseif category == "clicker" and data.evolutions >= 1 and data.clickerUpgrades[upgradeKey] ~= nil then
        local def = GameConfig.CLICKER_UPGRADES[upgradeKey]
        if def then bought = tryBuy(def, data.clickerUpgrades, "clicks") end

    elseif category == "mining" and data.evolutions >= 4 and data.miningUpgrades[upgradeKey] ~= nil then
        local def = GameConfig.MINING_UPGRADES[upgradeKey]
        if def then bought = tryBuy(def, data.miningUpgrades, "rocks") end

    elseif category == "axe" and data.evolutions >= 10 then
        data.axeUpgrades = data.axeUpgrades or {}
        if data.axeUpgrades[upgradeKey] ~= nil then
            local def = GameConfig.AXE_UPGRADES[upgradeKey]
            if def then bought = tryBuy(def, data.axeUpgrades, "wood") end
        end

    elseif category == "bonfire" and data.evolutions >= 10 then
        data.bonfireUpgrades = data.bonfireUpgrades or {}
        if data.bonfireUpgrades[upgradeKey] ~= nil then
            local def = GameConfig.BONFIRE_UPGRADES[upgradeKey]
            if def then bought = tryBuy(def, data.bonfireUpgrades, "wood") end
        end
    end

    if bought then
        updateLeaderstats(player, data)
        pushUpdate(player)
    end
end)

-- DoRebirth()
RE_DoRebirth.OnServerEvent:Connect(function(player)
    local data = getCache(player)
    if not data then return end
    local rebirthsEarned = BalanceMath.rebirthsFromGrass(data.grass)
    if rebirthsEarned < 1 then return end
    local grassCost = BalanceMath.grassForRebirths(rebirthsEarned)
    data.grass = data.grass - grassCost
    data.rebirths = (data.rebirths or 0) + rebirthsEarned
    doReset_Rebirth(data)
    data.grass = 0  -- ensure clean reset
    updateLeaderstats(player, data)
    pushUpdate(player)
end)

-- DoEvolution()
RE_DoEvolution.OnServerEvent:Connect(function(player)
    local data = getCache(player)
    if not data then return end
    local nextEvo = (data.evolutions or 0) + 1
    local evoDef  = GameConfig.EVOLUTIONS[nextEvo]
    if not evoDef then return end  -- all 10 bought
    if (data.rebirths or 0) < evoDef.rebirthCost then return end

    data.evolutions = nextEvo
    doReset_Evolution(data)

    updateLeaderstats(player, data)
    pushUpdate(player)
end)

-- PurchaseMerchant(itemId)
RE_PurchaseMerchant.OnServerEvent:Connect(function(player, itemId)
    local data = getCache(player)
    if not data then return end
    if data.evolutions < 10 then return end  -- Zone 2 unlocked after Evo 10 via portal

    -- Find item definition
    local itemDef
    for _, item in ipairs(GameConfig.MERCHANT_ITEMS) do
        if item.id == itemId then itemDef = item break end
    end
    if not itemDef then return end

    data.merchantPurchases = data.merchantPurchases or {}
    local bought = data.merchantPurchases[itemId] or 0
    if bought >= itemDef.maxBuys then return end

    local cost = BalanceMath.merchantCost(itemDef, bought)
    if (data.seed or 0) < cost then return end

    data.seed = data.seed - cost
    data.merchantPurchases[itemId] = bought + 1

    pushUpdate(player)
end)

-- GetPlayerData (RemoteFunction – client pull)
RF_GetPlayerData.OnServerInvoke = function(player)
    return getCache(player) or PlayerData.default()
end

-- ────────────────────────────────────────────────────────────
--  Auto-rates (grass, clicks, mining) server-side ticks
-- ────────────────────────────────────────────────────────────
local AUTO_TICK = 1.0  -- seconds between auto-income ticks
local autoTimer = 0

RunService.Heartbeat:Connect(function(dt)
    autoTimer = autoTimer + dt
    if autoTimer < AUTO_TICK then return end
    autoTimer = 0

    for _, player in ipairs(Players:GetPlayers()) do
        local data = getCache(player)
        if data then
            local changed = false

            -- Auto grass (Board 3 rebirth upgrade)
            local autoGrass = BalanceMath.autoGrassRate(data) * AUTO_TICK
            if autoGrass > 0 then
                data.grass = data.grass + autoGrass
                changed = true
            end

            -- Auto click (Clicker upgrade; Evo ≥ 1)
            if data.evolutions >= 1 then
                local autoClicks = BalanceMath.autoClickRate(data) * AUTO_TICK
                if autoClicks > 0 then
                    data.clicks = data.clicks + autoClicks
                    -- Also grass-per-click bonus from auto-clicks
                    local gpc = BalanceMath.grassPerClick(data)
                    if gpc > 0 then
                        data.grass = data.grass + gpc * autoClicks
                    end
                    changed = true
                end
            end

            -- Auto mine (Mining upgrade; Evo ≥ 4)
            if data.evolutions >= 4 then
                local autoRocks = BalanceMath.autoMineRate(data) * AUTO_TICK
                if autoRocks > 0 then
                    data.rocks = data.rocks + autoRocks
                    changed = true
                end
            end

            -- Auto burn / bonfire (Zone 3; Evo ≥ 10)
            if data.evolutions >= 10 and (data.wood or 0) >= GameConfig.FOREST.WOOD_PER_BURN then
                -- Auto-burn is client-requested; server just ticks if player has wood
                -- (client calls BurnWood; server does the actual transaction)
            end

            -- Auto chop (Zone 3; Evo ≥ 10)
            if data.evolutions >= 10 then
                local autoSwings = BalanceMath.autoChopRate(data) * AUTO_TICK
                if autoSwings > 0 then
                    -- Simplified: each AUTO_TICK auto-chop grants fractional wood
                    local woodRate = autoSwings * BalanceMath.axePower(data) / GameConfig.FOREST.TREE_HP
                                     * (GameConfig.FOREST.WOOD_PER_TREE + BalanceMath.woodBonusPerTree(data))
                    if woodRate > 0 then
                        data.wood = (data.wood or 0) + woodRate
                        changed = true
                    end
                end
            end

            if changed then
                updateLeaderstats(player, data)
                pushUpdate(player)
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
--  Merchant rotation  (server-side timer)
-- ────────────────────────────────────────────────────────────
-- The rotation index is broadcast to all clients so they show
-- the current offer.  We just fire an event each rotation.
local RE_MerchantRotation = makeEvent("MerchantRotation")
local merchantIndex   = 1
local merchantTimer   = 0

RunService.Heartbeat:Connect(function(dt)
    merchantTimer = merchantTimer + dt
    if merchantTimer >= GameConfig.MERCHANT_ROTATION_SECONDS then
        merchantTimer = 0
        merchantIndex = (merchantIndex % #GameConfig.MERCHANT_ITEMS) + 1
        RE_MerchantRotation:FireAllClients(merchantIndex)
    end
end)

-- ────────────────────────────────────────────────────────────
--  Player lifecycle
-- ────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    loadPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayer(player)
    playerCache[player.UserId] = nil
end)

-- Handle players already in game (Studio test)
for _, player in ipairs(Players:GetPlayers()) do
    loadPlayer(player)
end

print("[GameServer] Initialized.")
