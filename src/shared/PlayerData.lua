-- src/shared/PlayerData.lua
-- Default player-data template.
-- Deep-copy this for each new player; never mutate the original.

local PlayerData = {}

function PlayerData.default()
    return {
        -- ── Currencies ────────────────────────────────────────────
        grass  = 0,   -- reset on rebirth
        clicks = 0,   -- reset on rebirth
        rocks  = 0,   -- reset on rebirth  (aka Stone)
        seed   = 0,   -- reset on rebirth  (Zone 2)
        wood   = 0,   -- reset on rebirth  (Zone 3)
        ash    = 0,   -- NEVER reset (permanent global bonus)

        -- ── Prestige layers ───────────────────────────────────────
        rebirths   = 0,  -- current rebirth points (reset on evolution)
        evolutions = 0,  -- purchased evolutions count (never reset)

        -- ── Grass Upgrades  (Board 1 – reset on rebirth) ──────────
        grassUpgrades = {
            spawnSpeed = 0,
            bonusGrass = 0,
            radius     = 0,
        },

        -- ── Rebirth Upgrades  (Board 3 – reset on evolution) ──────
        rebirthUpgrades = {
            bonusGrass  = 0,
            autoCollect = 0,
            fasterSpawn = 0,
        },

        -- ── Clicker Upgrades  (reset on rebirth; needs Evo ≥ 1) ───
        clickerUpgrades = {
            clickPower    = 0,
            autoClick     = 0,
            grassPerClick = 0,
        },

        -- ── Mining Upgrades  (reset on rebirth; needs Evo ≥ 4) ────
        miningUpgrades = {
            pickaxePower = 0,
            autoMine     = 0,
        },

        -- ── Bonfire Upgrades  (Zone 3; permanent) ─────────────────
        bonfireUpgrades = {
            burnSpeed  = 0,
            ashPerBurn = 0,
        },

        -- ── Merchant purchases  (permanent, never reset) ──────────
        -- keys are item IDs from GameConfig.MERCHANT_ITEMS
        merchantPurchases = {},

        -- ── Merchant state ────────────────────────────────────────
        merchantRotationTime = 0,   -- os.time() of last rotation
    }
end

--- Deep-copy a player data table (for clean serialisation/load).
function PlayerData.deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = PlayerData.deepCopy(v)
    end
    return copy
end

--- Merge loaded data into the default so missing keys get defaults.
function PlayerData.merge(loaded)
    local default = PlayerData.default()
    -- Top-level keys
    for k, v in pairs(default) do
        if loaded[k] == nil then
            loaded[k] = v
        elseif type(v) == "table" then
            for k2, v2 in pairs(v) do
                if loaded[k][k2] == nil then
                    loaded[k][k2] = v2
                end
            end
        end
    end
    return loaded
end

return PlayerData
