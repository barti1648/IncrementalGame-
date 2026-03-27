# 🌿 IncrementalGame – Roblox Studio Setup Guide

A complete idle / incremental Roblox game featuring 6 currencies, 3 zones, 10 evolution tiers, prestige (rebirth) mechanics, and a deep synergy system.

---

## ⏱ Game Timeline

| Phase | Target time |
|---|---|
| Platform 1 → first Rebirth | ~8 min |
| Reach Platform 2 / Evo 1 | ~15 min |
| All 10 Evolutions | ~4 hours |
| Zone 2 (Mystic Realm) – full merchant tree | ~20 hours |
| Zone 3 (Forest) – reach 10 000 Ash | ~26 hours |
| **Total completion** | **~50 hours** |

---

## 📁 File Structure

```
src/
  shared/
    GameConfig.lua        ← all balance constants (edit here to tune)
    BalanceMath.lua       ← pure math helpers, no Roblox calls
    PlayerData.lua        ← default data template + merge/copy utils
  server/
    GameServer.server.lua ← DataStore, anti-cheat, all RemoteEvent handlers
    WorldBuilder.server.lua ← builds platforms, boards, zones in workspace
  client/
    GrassSystem.client.lua    ← client-side grass spawning & collection
    ClickerSystem.client.lua  ← Clicker board (Evo ≥ 1)
    MiningSystem.client.lua   ← Mining zone (Evo ≥ 4)
    ForestSystem.client.lua   ← Forest, tree chopping, bonfire (endgame)
    HUD.client.lua            ← dynamic HUD + board button wiring
README.md
```

---

## 🚀 Roblox Studio Import Instructions

### Step 1 – Install Rojo (recommended)

[Rojo](https://rojo.space/) lets you sync this file structure directly into Studio.

```bash
# Install Rojo CLI (requires Rust / Foreman)
rojo build --output game.rbxlx
```

Then open `game.rbxlx` in Roblox Studio.

### Step 2 – Manual import (no Rojo needed)

1. Open **Roblox Studio** and create a new **Baseplate** project.
2. In the **Explorer** panel create this structure:

```
ReplicatedStorage/
  Shared/           ← Folder
    GameConfig      ← ModuleScript  (paste src/shared/GameConfig.lua)
    BalanceMath     ← ModuleScript  (paste src/shared/BalanceMath.lua)
    PlayerData      ← ModuleScript  (paste src/shared/PlayerData.lua)

ServerScriptService/
  GameServer        ← Script        (paste src/server/GameServer.server.lua)
  WorldBuilder      ← Script        (paste src/server/WorldBuilder.server.lua)

StarterPlayer/
  StarterPlayerScripts/
    GrassSystem     ← LocalScript   (paste src/client/GrassSystem.client.lua)
    ClickerSystem   ← LocalScript   (paste src/client/ClickerSystem.client.lua)
    MiningSystem    ← LocalScript   (paste src/client/MiningSystem.client.lua)
    ForestSystem    ← LocalScript   (paste src/client/ForestSystem.client.lua)
    HUD             ← LocalScript   (paste src/client/HUD.client.lua)
```

3. **Delete the default Baseplate** (or keep it – the WorldBuilder creates its own platforms).
4. Set **SpawnLocation** Y position to `3` so players spawn above Platform 1.
5. Press **Play** (F5) to test.

### Step 3 – Enable DataStore

1. Go to **Home → Game Settings → Security**.
2. Enable **"Allow HTTP Requests"** and **"Enable Studio Access to API Services"**.
3. Under **Monetization**, make sure the game is published (DataStore requires a live game ID).

---

## 🎮 Gameplay Overview

### 💰 Currencies

| Currency | How to earn | Resets on |
|---|---|---|
| 🌿 Grass | Walk into grass blades on Platform 1 | Rebirth |
| 👆 Clicks | Click the Clicker board (Evo ≥ 1) | Rebirth |
| 🪨 Rocks/Stone | Mine the giant rock (Evo ≥ 4) | Rebirth |
| 🌱 Seeds | 0.25% drop per grass in Zone 2 | Rebirth |
| 🌲 Wood | Chop trees in Zone 3 (Forest) | Rebirth |
| ✨ Ash | Burn Wood at the Great Bonfire | **Never** |

### ♻️ Rebirth
- Every **500 Grass** = 1 Rebirth Point.
- Rebirth resets: Grass, Clicks, Rocks, Seeds, Wood, and all field/clicker/mining upgrades.
- **Rebirth Upgrades** (Board 3) survive rebirth but reset on Evolution.
- Formula: `rebirths = floor(grass / 500)` – e.g. 2000 grass → 4 rebirths.

### 🧬 Evolutions (Platform 2)

| # | Description | Cost (Rebirths) |
|---|---|---|
| 1 | 👆 Unlocks the Clicker | 3 |
| 2 | ✨ Upgraded Clicker – stronger multipliers | 8 |
| 3 | 🤖 Automation – auto grass collection | 15 |
| 4 | ⛏ Mining Zone – mine rocks! | 25 |
| 5 | 🪨 Stone boosts click strength ×3 | 40 |
| 6 | 🌿 Grass grows 5× faster | 50 |
| 7 | 💎 Chance for golden grass ×3 | 55 |
| 8 | 🌱 Seeds appear 2× in Zone 2 | 55 |
| 9 | 🌀 Portal opens the Mystic Realm | 55 |
| 10 | ⚡ All stats ×2 | 50 |

**Total rebirths needed for all evolutions: 356**
**Evolution chain target: ~4 hours**

**Evolution resets**: everything except purchased evolutions, ✨ Ash, and merchant purchases.

### 🌀 Zone 2 – Mystic Realm (after Evo 9/10 via portal)
- Grass here has a **0.25%** chance per blade to drop a 🌱 Seed.
- **Permanent Merchant** (offer rotates every 5 minutes) sells 5 upgrade types for Seeds.
- Each item can be purchased up to **10 times** at exponentially increasing seed costs.
- Seed cost model: `cost = floor(baseCost × 2^level)` – doubles each purchase.
- Total seed cost for full tree: ~31 700 seeds → **~20 hours** target.
- Completing the **entire merchant tree** unlocks Zone 3.

### 🌲 Zone 3 – The Forest (endgame)
- Click trees to chop them; each tree has **100 HP**.
- Felled trees drop **10 Wood** (+ bonuses).
- The **Great Bonfire** auto-burns Wood → **Ash** every 3 seconds (upgradeable).
- **Ash** is permanent and gives **+0.1% to ALL currencies per unit**.
- Reaching **10 000 Ash** completes the game 🏆.

### ⚡ Synergy (The Golden Rule)
| What you have | Effect |
|---|---|
| 🌲 Wood | Increases grass collection radius on Platform 1 |
| ✨ Ash | Makes grass spawn faster (approaches instant at high levels) |
| 🪨 Stone (Rocks) | Increases click power in the Clicker |

---

## ⚙️ Balancing

All tuning values live in **`src/shared/GameConfig.lua`**. Key tables:

- `EVOLUTIONS[i].rebirthCost` – rebirth cost per evolution tier
- `GRASS_UPGRADES / REBIRTH_UPGRADES / CLICKER_UPGRADES` – `baseCost`, `costMultiplier`, `maxLevel`
- `MERCHANT_ITEMS[i].baseCost` – seed cost base (doubles per purchase level)
- `FOREST.ASH_COMPLETION_GOAL` – ash required to "complete" the game (default 10 000)
- `FOREST.ASH_GLOBAL_BONUS` – % bonus per ash unit (default 0.001 = 0.1 %)

---

## 🛡 Anti-Cheat

The server validates every currency request:
- Checks that the reported amount doesn't exceed `2× expected_per_pickup + 10`.
- Hard caps per request: 500 grass, 200 clicks, 200 rocks, 50 wood.
- All currency changes happen only on the server; the client sends requests, not balances.

---

## 💾 DataStore

Saved per player (key: `player_<UserId>`):
- All currencies (except non-persistent ones are reset on rebirth/evolution as designed)
- Evolution count, Rebirth count
- All upgrade levels
- Merchant purchases (permanent)
- Ash (permanent)

Auto-save every **60 seconds**. Also saves on `PlayerRemoving`.

---

## 🔗 Rojo project.json (optional)

If you use Rojo, create `default.project.json` in the repo root:

```json
{
  "name": "IncrementalGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": {
        "$className": "Folder",
        "GameConfig":  { "$path": "src/shared/GameConfig.lua"  },
        "BalanceMath": { "$path": "src/shared/BalanceMath.lua" },
        "PlayerData":  { "$path": "src/shared/PlayerData.lua"  }
      }
    },
    "ServerScriptService": {
      "GameServer":   { "$path": "src/server/GameServer.server.lua"   },
      "WorldBuilder": { "$path": "src/server/WorldBuilder.server.lua" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "GrassSystem":   { "$path": "src/client/GrassSystem.client.lua"   },
        "ClickerSystem": { "$path": "src/client/ClickerSystem.client.lua" },
        "MiningSystem":  { "$path": "src/client/MiningSystem.client.lua"  },
        "ForestSystem":  { "$path": "src/client/ForestSystem.client.lua"  },
        "HUD":           { "$path": "src/client/HUD.client.lua"           }
      }
    }
  }
}
```

Run `rojo serve` and connect from Studio's Rojo plugin.

---

## 📝 License

MIT – free to use, modify, and publish as your own Roblox game.
