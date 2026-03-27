-- src/client/ClickerSystem.client.lua
-- Handles the Clicker board UI (Platform 2; unlocked after Evo ≥ 1).
-- Clicking the board fires a RemoteEvent; upgrades are purchased here.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local GameConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BalanceMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceMath"))
local PlayerData  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local RE_Click      = Remotes:WaitForChild("ClickClicker")
local RE_Upgrade    = Remotes:WaitForChild("PurchaseUpgrade")
local RE_UpdateData = Remotes:WaitForChild("UpdateData")

local localData = PlayerData.default()
RE_UpdateData.OnClientEvent:Connect(function(data) localData = data end)

-- ────────────────────────────────────────────────────────────
--  Board reference
-- ────────────────────────────────────────────────────────────
local clickerBoard = workspace:WaitForChild("Board_Clicker", 10)

local function getGui()
    if not clickerBoard then return nil end
    local sg = clickerBoard:FindFirstChildWhichIsA("SurfaceGui")
    return sg
end

-- ────────────────────────────────────────────────────────────
--  Click proximity  (within 12 studs of the board)
-- ────────────────────────────────────────────────────────────
local CLICK_RANGE = 12

local function nearBoard()
    if not clickerBoard then return false end
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return (rootPart.Position - clickerBoard.Position).Magnitude <= CLICK_RANGE
end

-- ────────────────────────────────────────────────────────────
--  Wire up buttons inside the board's SurfaceGui
-- ────────────────────────────────────────────────────────────
local function wireButtons(sg)
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local btnClick    = frame:FindFirstChild("ClickButton")
    local btnPower    = frame:FindFirstChild("BuyClickPower")
    local btnAuto     = frame:FindFirstChild("BuyAutoClick")
    local btnGPC      = frame:FindFirstChild("BuyGrassPerClick")

    if btnClick then
        btnClick.MouseButton1Click:Connect(function()
            if not nearBoard() then return end
            if localData.evolutions < 1 then return end
            local clicks = BalanceMath.clicksPerClick(localData)
            RE_Click:FireServer(clicks)
            -- Visual click burst
            btnClick.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            task.delay(0.1, function()
                if btnClick and btnClick.Parent then
                    btnClick.BackgroundColor3 = Color3.fromRGB(220, 140, 20)
                end
            end)
        end)
    end

    if btnPower then
        btnPower.MouseButton1Click:Connect(function()
            if not nearBoard() then return end
            RE_Upgrade:FireServer("clicker", "clickPower")
        end)
    end
    if btnAuto then
        btnAuto.MouseButton1Click:Connect(function()
            if not nearBoard() then return end
            RE_Upgrade:FireServer("clicker", "autoClick")
        end)
    end
    if btnGPC then
        btnGPC.MouseButton1Click:Connect(function()
            if not nearBoard() then return end
            RE_Upgrade:FireServer("clicker", "grassPerClick")
        end)
    end
end

-- ────────────────────────────────────────────────────────────
--  Update button labels with live costs
-- ────────────────────────────────────────────────────────────
local function updateLabels()
    local sg = getGui()
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end

    local upgrades = {
        { btn = "BuyClickPower",   key = "clickPower",    cur = "clicks", cat = "clicker" },
        { btn = "BuyAutoClick",    key = "autoClick",     cur = "clicks", cat = "clicker" },
        { btn = "BuyGrassPerClick",key = "grassPerClick", cur = "clicks", cat = "clicker" },
    }
    for _, u in ipairs(upgrades) do
        local btn = frame:FindFirstChild(u.btn)
        if btn then
            local def   = GameConfig.CLICKER_UPGRADES[u.key]
            local level = localData.clickerUpgrades[u.key] or 0
            local cost  = BalanceMath.upgradeCost(def, level)
            local have  = math.floor(localData.clicks or 0)
            local maxed = level >= def.maxLevel
            local affordable = have >= cost
            btn.Text = def.label .. "  [Lv" .. level .. "  Cost: " .. cost .. " clicks]"
            btn.BackgroundColor3 = maxed and Color3.fromRGB(80, 80, 80)
                                or (affordable and Color3.fromRGB(160, 100, 20))
                                or Color3.fromRGB(100, 60, 10)
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  Visibility: only show clicker board when Evo ≥ 1
-- ────────────────────────────────────────────────────────────
local buttonsWired = false

RunService.Heartbeat:Connect(function()
    if not clickerBoard then return end
    local visible = localData.evolutions >= 1
    clickerBoard.Transparency = visible and 0 or 1
    clickerBoard.CanCollide   = visible

    if visible and not buttonsWired then
        local sg = getGui()
        wireButtons(sg)
        buttonsWired = true
    end

    if visible then
        updateLabels()
    end
end)

player.CharacterAdded:Connect(function(char)
    character = char
end)
