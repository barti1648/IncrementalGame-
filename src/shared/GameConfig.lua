-- src/shared/GameConfig.lua
-- Central balance configuration for the Incremental Game
-- All numeric tuning lives here to keep adjustments easy.

local GameConfig = {}

-- ────────────────────────────────────────────────────────────
--  Platform / Zone positions
-- ────────────────────────────────────────────────────────────
GameConfig.PLATFORM1_POS    = Vector3.new(0,   0,  0)
GameConfig.PLATFORM2_POS    = Vector3.new(40,  0,  0)
GameConfig.MINING_ZONE_POS  = Vector3.new(100, 0,  0)
GameConfig.PORTAL_POS       = Vector3.new(40,  0, -30)  -- on Platform 2
GameConfig.MYSTIC_REALM_POS = Vector3.new(0,   0,  200)
GameConfig.FOREST_POS       = Vector3.new(0,   0,  400)

-- ────────────────────────────────────────────────────────────
--  Grass system
-- ────────────────────────────────────────────────────────────
GameConfig.GRASS = {
    BASE_SPAWN_INTERVAL    = 1.0,   -- seconds between each new blade
    BASE_COLLECTION_RADIUS = 3.5,   -- studs (player touch radius)
    BASE_GRASS_PER_PICKUP  = 1,     -- how much grass per blade
    MAX_BLADES_ON_FIELD    = 60,    -- cap to keep client smooth
    GOLDEN_GRASS_BASE_CHANCE = 0.05, -- 5 % base; boosted by Evo 7
    GOLDEN_GRASS_MULTIPLIER  = 5,   -- golden blade gives 5× grass
    SEED_CHANCE              = 0.0025, -- 0.25 % per blade (any zone)
}

-- ────────────────────────────────────────────────────────────
--  Rebirth system
-- ────────────────────────────────────────────────────────────
GameConfig.REBIRTH = {
    GRASS_PER_REBIRTH = 500,  -- 500 grass = 1 rebirth; 2000 = 4, etc.
}

-- ────────────────────────────────────────────────────────────
--  Evolution definitions  (sequential, buy once each)
--
--  Balance target: all 10 evolutions ≈ 4 hours total.
--
--  Evo 1 → 15 min   (3  rebirths, bare grass loop)
--  Evo 2 → 20 min   (8  rebirths, clicker available)
--  Evo 3 → 25 min   (15 rebirths, better clicker)
--  Evo 4 → 30 min   (25 rebirths, auto-collect)
--  Evo 5 → 35 min   (40 rebirths, mining unlocked)
--  Evo 6 → 20 min   (50 rebirths, stone x3 + 5× faster grass)
--  Evo 7 → 18 min   (55 rebirths, golden grass x3)
--  Evo 8 → 15 min   (55 rebirths, seed 2× in Zone 2)
--  Evo 9 → 12 min   (55 rebirths, portal)
--  Evo10 → 10 min   (50 rebirths, all ×2)
--  Total ≈ 200 min + overhead ≈ 4 hours
-- ────────────────────────────────────────────────────────────
GameConfig.EVOLUTIONS = {
    { description = "👆 Unlocks the Clicker! Earn Clicks by clicking.",  rebirthCost =  3 },
    { description = "✨ Upgraded Clicker – stronger multipliers ++",      rebirthCost =  8 },
    { description = "🤖 Automation! auto collect grass.",                 rebirthCost = 15 },
    { description = "⛏ Mining Zone – mine rocks!",                       rebirthCost = 25 },
    { description = "🪨 Stone boosts click strength x3",                  rebirthCost = 40 },
    { description = "🌿 Grass grows 5x faster",                           rebirthCost = 50 },
    { description = "💎 Chance for golden grass x3",                      rebirthCost = 55 },
    { description = "🌱 Seeds appear 2x more often in Zone 2",            rebirthCost = 55 },
    { description = "🌀 The PORTAL opens the Mystic Realm!",              rebirthCost = 55 },
    { description = "⚡ All stats x2",                                    rebirthCost = 50 },
}

-- ────────────────────────────────────────────────────────────
--  Upgrade definitions
--  Each entry: { baseCost, costMultiplier, maxLevel }
--  Upgrade cost at level L = floor(baseCost * costMultiplier^L)
-- ────────────────────────────────────────────────────────────

-- Board 1 – Grass Upgrades  (paid with Grass; reset on Rebirth)
GameConfig.GRASS_UPGRADES = {
    spawnSpeed = { baseCost = 10,  costMultiplier = 1.5, maxLevel = 50,
                   label = "⚡ Spawn Speed",     desc = "Grass spawns faster" },
    bonusGrass = { baseCost = 25,  costMultiplier = 1.6, maxLevel = 50,
                   label = "🌿 +1 Grass/Pick",   desc = "+1 grass per pickup" },
    radius     = { baseCost = 50,  costMultiplier = 1.7, maxLevel = 30,
                   label = "🔵 Wider Radius",    desc = "+0.5 collection radius" },
}

-- Board 3 – Rebirth Upgrades  (paid with Rebirths; survive Rebirth, reset on Evolution)
GameConfig.REBIRTH_UPGRADES = {
    bonusGrass  = { baseCost = 1, costMultiplier = 1.4, maxLevel = 100,
                    label = "🌱 +1 Grass",       desc = "+1 grass per pickup" },
    autoCollect = { baseCost = 2, costMultiplier = 1.5, maxLevel =  50,
                    label = "🤖 Auto-Collect",   desc = "+0.5 grass/sec auto" },
    fasterSpawn = { baseCost = 3, costMultiplier = 1.5, maxLevel =  30,
                    label = "🚀 Spawn Rate",     desc = "Grass spawns 10% faster" },
}

-- Clicker Upgrades  (paid with Clicks; reset on Rebirth; unlocked by Evo 1)
GameConfig.CLICKER_UPGRADES = {
    clickPower    = { baseCost = 10,  costMultiplier = 1.5, maxLevel = 100,
                      label = "👆 +1 Click Power",    desc = "+1 click per click" },
    autoClick     = { baseCost = 50,  costMultiplier = 1.6, maxLevel =  50,
                      label = "🤖 Auto-Click",        desc = "+0.5 clicks/sec" },
    bonusGrass    = { baseCost = 100, costMultiplier = 1.8, maxLevel =  50,
                      label = "🌿 Bonus Grass",        desc = "+1 grass per click" },
}

-- Mining Upgrades  (paid with Rocks; reset on Rebirth; unlocked by Evo 4)
GameConfig.MINING_UPGRADES = {
    pickaxePower = { baseCost = 100, costMultiplier = 1.5, maxLevel = 100,
                     label = "⛏ Pickaxe Power",  desc = "+1 rocks per swing" },
    autoMine     = { baseCost = 500, costMultiplier = 1.6, maxLevel =  50,
                     label = "🤖 Auto-Mine",      desc = "+0.5 rocks/sec" },
}

-- ────────────────────────────────────────────────────────────
--  Forest / Trees / Bonfire
--
--  Balance target Zone 3 ≈ 26 hours of play.
--  Base ash rate: ~20/hr.  Full upgrades: ~2 000/hr.
--  To "complete" the game, accumulate ASH_COMPLETION_GOAL ash.
--  10 000 ash at average ~400/hr ≈ 25 hours ✓
-- ────────────────────────────────────────────────────────────
GameConfig.FOREST = {
    TREE_HP             = 100,   -- axe hits to fell a tree
    BASE_AXE_POWER      = 1,
    WOOD_PER_TREE       = 10,
    BASE_BURN_INTERVAL  = 3.0,   -- seconds between automatic burns
    WOOD_PER_BURN       = 5,
    ASH_PER_BURN        = 1,
    ASH_GLOBAL_BONUS    = 0.001, -- +0.1 % to ALL currencies per Ash owned
    ASH_COMPLETION_GOAL = 10000, -- reaching this "completes" the game
}

-- Axe Upgrades  (paid with Wood; Zone 3)
GameConfig.AXE_UPGRADES = {
    axePower  = { baseCost = 50,   costMultiplier = 1.6, maxLevel = 100,
                  label = "🪓 Axe Power",   desc = "+1 damage per swing" },
    autoChop  = { baseCost = 500,  costMultiplier = 1.7, maxLevel =  50,
                  label = "🤖 Auto-Chop",   desc = "+0.5 swings/sec" },
    woodBonus = { baseCost = 2000, costMultiplier = 1.8, maxLevel =  50,
                  label = "🌲 +1 Wood/Tree", desc = "+1 wood when tree falls" },
}

-- Bonfire Upgrades  (paid with Wood; permanent; Zone 3)
GameConfig.BONFIRE_UPGRADES = {
    burnSpeed  = { baseCost = 1000, costMultiplier = 1.5, maxLevel = 50,
                   label = "🔥 Burn Speed",   desc = "Burn wood 10% faster" },
    ashPerBurn = { baseCost = 5000, costMultiplier = 1.7, maxLevel = 50,
                   label = "✨ +1 Ash/Burn",  desc = "+1 ash per burn action" },
}

-- ────────────────────────────────────────────────────────────
--  Merchant  (Zone 2; permanent purchases, paid with Seeds)
--
--  Cost model: cost(level) = floor(baseCost * 2^level)
--  so each successive purchase doubles in price.
--
--  Balance target Zone 2 ≈ 20 hours of play.
--  After Evo 10 seed rate ≈ 50 seeds/hour → rises to ~3 000/hr
--  with upgrades.  Total tree cost ≈ 30 000 seeds → ~20 hours avg.
--
--  5 item types × 10 purchase levels each = 50 permanent upgrades.
--  Total seed cost per item: baseCost*(2^10 - 1) = 1023*baseCost
--    Item 1 (baseCost 1):  1 023 seeds
--    Item 2 (baseCost 2):  2 046 seeds
--    Item 3 (baseCost 4):  4 092 seeds
--    Item 4 (baseCost 8):  8 184 seeds
--    Item 5 (baseCost 16): 16 368 seeds
--  Grand total ≈ 31 713 seeds
-- ────────────────────────────────────────────────────────────
GameConfig.MERCHANT_ITEMS = {
    { id = "mRadiusBoost", name = "Mystic Reach",    desc = "+2 collection radius per level",      baseCost =  1, maxBuys = 10 },
    { id = "mGrassBoost",  name = "Mystic Harvest",  desc = "+5 grass per pickup per level",       baseCost =  2, maxBuys = 10 },
    { id = "mSpawnBoost",  name = "Mystic Growth",   desc = "Grass spawns 10% faster per level",   baseCost =  4, maxBuys = 10 },
    { id = "mAshBonus",    name = "Mystic Ash",      desc = "+1% Ash bonus per level (permanent)", baseCost =  8, maxBuys = 10 },
    { id = "mAllBoost",    name = "Mystic Surge",    desc = "+10% all currencies per level",       baseCost = 16, maxBuys = 10 },
}
GameConfig.MERCHANT_ROTATION_SECONDS = 300  -- 5 minutes per rotation

-- ────────────────────────────────────────────────────────────
--  Golden Rule of Synergy
-- ────────────────────────────────────────────────────────────
GameConfig.SYNERGY = {
    WOOD_RADIUS_PER_UNIT   = 0.005,  -- +0.005 collection radius per Wood owned
    ASH_SPAWN_SPEED_PER    = 0.001,  -- spawn interval *= max(0.05, 1 - ash*0.001)
    STONE_CLICK_BONUS_PER  = 0.01,   -- +1 % click power per Stone owned
}

-- ────────────────────────────────────────────────────────────
--  Anti-cheat limits  (per second, server-validated)
-- ────────────────────────────────────────────────────────────
GameConfig.ANTICHEAT = {
    MAX_GRASS_PER_REQUEST  = 500,
    MAX_CLICKS_PER_REQUEST = 200,
    MAX_ROCKS_PER_REQUEST  = 200,
    MAX_WOOD_PER_REQUEST   = 50,
}

-- ────────────────────────────────────────────────────────────
--  DataStore key
-- ────────────────────────────────────────────────────────────
GameConfig.DATASTORE_KEY = "IncrementalGame_v1"

return GameConfig
