-- src/shared/BalanceMath.lua
-- Pure math helpers shared between server and client.
-- No Roblox service calls; safe to require anywhere.

local GameConfig = require(script.Parent.GameConfig)

local BalanceMath = {}

-- ────────────────────────────────────────────────────────────
--  Upgrade costs
-- ────────────────────────────────────────────────────────────

--- Cost to buy the NEXT level of an upgrade.
--- cost(L) = floor( baseCost * multiplier ^ currentLevel )
function BalanceMath.upgradeCost(upgradeDef, currentLevel)
    return math.floor(upgradeDef.baseCost * (upgradeDef.costMultiplier ^ currentLevel))
end

--- Total cost to buy `count` levels starting at `fromLevel`.
function BalanceMath.bulkCost(upgradeDef, fromLevel, count)
    local total = 0
    for i = 0, count - 1 do
        total = total + BalanceMath.upgradeCost(upgradeDef, fromLevel + i)
    end
    return total
end

-- ────────────────────────────────────────────────────────────
--  Grass Stats  (derived from player data each frame / request)
-- ────────────────────────────────────────────────────────────

--- Returns the final grass-per-pickup value.
function BalanceMath.grassPerPickup(data)
    local base   = GameConfig.GRASS.BASE_GRASS_PER_PICKUP
    local bonus  = (data.grassUpgrades.bonusGrass or 0)       -- Board 1
               + (data.rebirthUpgrades.bonusGrass or 0)       -- Board 3
    -- Merchant permanent bonus
    local mBonus = (data.merchantPurchases.mGrassBoost or 0) * 5
    -- Ash global %
    local ashMult = 1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS
    -- Evolution 10: x2
    local evoMult = (data.evolutions >= 10) and 2 or 1
    return math.max(1, (base + bonus + mBonus) * ashMult * evoMult)
end

--- Returns grass spawn interval in seconds.
function BalanceMath.grassSpawnInterval(data)
    local base = GameConfig.GRASS.BASE_SPAWN_INTERVAL
    -- Board 1 upgrade: each level * 0.9
    local lvl1 = data.grassUpgrades.spawnSpeed or 0
    base = base * (0.9 ^ lvl1)
    -- Board 3 upgrade: each level * 0.9
    local lvl3 = data.rebirthUpgrades.fasterSpawn or 0
    base = base * (0.9 ^ lvl3)
    -- Merchant spawn bonus
    local mSpawn = data.merchantPurchases.mSpawnBoost or 0
    base = base * (0.9 ^ mSpawn)
    -- Evolution 6: x5 faster (interval /5)
    if data.evolutions >= 6 then base = base / 5 end
    -- Ash synergy: approaching instant at high ash
    local ashFactor = math.max(0.05, 1 - (data.ash or 0) * GameConfig.SYNERGY.ASH_SPAWN_SPEED_PER)
    base = base * ashFactor
    -- Evolution 10: x2 faster
    if data.evolutions >= 10 then base = base / 2 end
    return math.max(0.05, base)
end

--- Returns collection radius in studs.
function BalanceMath.collectionRadius(data)
    local base  = GameConfig.GRASS.BASE_COLLECTION_RADIUS
    local lvl   = data.grassUpgrades.radius or 0
    base = base + lvl * 0.5
    -- Merchant
    local mRad  = (data.merchantPurchases.mRadiusBoost or 0) * 2
    base = base + mRad
    -- Wood synergy
    local wood  = data.wood or 0
    base = base + wood * GameConfig.SYNERGY.WOOD_RADIUS_PER_UNIT
    -- Evolution 10
    if data.evolutions >= 10 then base = base * 2 end
    return math.max(1, base)
end

--- Returns auto-grass (grass per second from Board 3 auto-collect).
function BalanceMath.autoGrassRate(data)
    local lvl  = data.rebirthUpgrades.autoCollect or 0
    local rate = lvl * 0.5
    -- Evolution 3 doubles auto rate
    if data.evolutions >= 3 then rate = rate * 2 end
    -- Evolution 10
    if data.evolutions >= 10 then rate = rate * 2 end
    -- Ash global
    rate = rate * (1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS)
    return rate
end

--- Returns golden-grass chance (0–1).
function BalanceMath.goldenGrassChance(data)
    local chance = GameConfig.GRASS.GOLDEN_GRASS_BASE_CHANCE
    if data.evolutions >= 7 then chance = chance * 3 end
    if data.evolutions >= 10 then chance = math.min(0.5, chance * 2) end
    return chance
end

--- Returns seed drop chance per grass blade (Zone 2 only).
function BalanceMath.seedDropChance(data)
    local chance = GameConfig.GRASS.SEED_CHANCE_ZONE2
    if data.evolutions >= 8 then chance = chance * 2 end
    return chance
end

-- ────────────────────────────────────────────────────────────
--  Click Stats
-- ────────────────────────────────────────────────────────────

--- Returns clicks per manual click.
function BalanceMath.clicksPerClick(data)
    local base  = 1
    local lvl   = data.clickerUpgrades.clickPower or 0
    base = base + lvl
    -- Evo 2: double strength
    if data.evolutions >= 2 then base = base * 2 end
    -- Stone synergy
    local stone = data.rocks or 0
    local stoneMult = 1 + stone * GameConfig.SYNERGY.STONE_CLICK_BONUS_PER
    -- Evo 5: Stone x3
    if data.evolutions >= 5 then stoneMult = stoneMult * 3 end
    base = base * stoneMult
    -- Evo 10
    if data.evolutions >= 10 then base = base * 2 end
    -- Ash global
    base = base * (1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS)
    return math.max(1, math.floor(base))
end

--- Returns auto-click rate (clicks per second), scaled by clickPower.
function BalanceMath.autoClickRate(data)
    local lvl  = data.clickerUpgrades.autoClick or 0
    local rate = lvl * 0.5
    if data.evolutions >= 2 then rate = rate * 2 end
    if data.evolutions >= 10 then rate = rate * 2 end
    -- Each auto-click produces as many clicks as a manual click
    rate = rate * BalanceMath.clicksPerClick(data)
    return rate
end

--- Returns grass earned per click.
function BalanceMath.grassPerClick(data)
    local lvl = data.clickerUpgrades.bonusGrass or 0
    local g   = lvl
    if data.evolutions >= 10 then g = g * 2 end
    g = g * (1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS)
    return math.floor(g)
end

-- ────────────────────────────────────────────────────────────
--  Mining Stats
-- ────────────────────────────────────────────────────────────

--- Returns rocks per swing.
function BalanceMath.rocksPerSwing(data)
    local base = 1
    local lvl  = data.miningUpgrades.pickaxePower or 0
    base = base + lvl
    if data.evolutions >= 10 then base = base * 2 end
    base = base * (1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS)
    return math.max(1, math.floor(base))
end

--- Returns auto-mining rate (rocks per second).
function BalanceMath.autoMineRate(data)
    local lvl  = data.miningUpgrades.autoMine or 0
    local rate = lvl * 0.5
    if data.evolutions >= 10 then rate = rate * 2 end
    return rate
end

-- ────────────────────────────────────────────────────────────
--  Forest / Bonfire Stats
-- ────────────────────────────────────────────────────────────

--- Returns burn interval in seconds.
function BalanceMath.burnInterval(data)
    local base = GameConfig.FOREST.BASE_BURN_INTERVAL
    local lvl  = (data.bonfireUpgrades and data.bonfireUpgrades.burnSpeed) or 0
    base = base * (0.9 ^ lvl)
    return math.max(0.2, base)
end

--- Returns ash earned per burn action.
function BalanceMath.ashPerBurn(data)
    local base = GameConfig.FOREST.ASH_PER_BURN
    local lvl  = (data.bonfireUpgrades and data.bonfireUpgrades.ashPerBurn) or 0
    base = base + lvl
    return base
end

-- ────────────────────────────────────────────────────────────
--  Rebirth helpers
-- ────────────────────────────────────────────────────────────

--- How many rebirths can be bought with `grass` grass?
function BalanceMath.rebirthsFromGrass(grass)
    return math.floor(grass / GameConfig.REBIRTH.GRASS_PER_REBIRTH)
end

--- Grass cost to buy exactly `count` rebirths.
function BalanceMath.grassForRebirths(count)
    return count * GameConfig.REBIRTH.GRASS_PER_REBIRTH
end

-- ────────────────────────────────────────────────────────────
--  Merchant helpers
-- ────────────────────────────────────────────────────────────

--- Cost of the NEXT merchant item purchase.
--- cost(level) = floor( baseCost * 2^currentBought )
function BalanceMath.merchantCost(item, currentBought)
    return math.floor(item.baseCost * (2 ^ currentBought))
end

--- Is a merchant item fully purchased?
function BalanceMath.merchantMaxed(data, itemId, maxBuys)
    local bought = (data.merchantPurchases and data.merchantPurchases[itemId]) or 0
    return bought >= maxBuys
end

-- ────────────────────────────────────────────────────────────
--  Forest / Axe Stats
-- ────────────────────────────────────────────────────────────

--- Returns damage per axe swing.
function BalanceMath.axePower(data)
    local base = GameConfig.FOREST.BASE_AXE_POWER
    local lvl  = (data.axeUpgrades and data.axeUpgrades.axePower) or 0
    base = base + lvl
    if data.evolutions >= 10 then base = base * 2 end
    base = base * (1 + (data.ash or 0) * GameConfig.FOREST.ASH_GLOBAL_BONUS)
    return math.max(1, math.floor(base))
end

--- Returns auto-chop rate (swings per second).
function BalanceMath.autoChopRate(data)
    local lvl  = (data.axeUpgrades and data.axeUpgrades.autoChop) or 0
    local rate = lvl * 0.5
    if data.evolutions >= 10 then rate = rate * 2 end
    return rate
end

--- Returns bonus wood per tree felled.
function BalanceMath.woodBonusPerTree(data)
    local lvl = (data.axeUpgrades and data.axeUpgrades.woodBonus) or 0
    return lvl
end

return BalanceMath
