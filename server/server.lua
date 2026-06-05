-- ============================================================================
-- um_beg server
-- Validates reward requests + pays the player.
-- Prefers ox_inventory:AddItem (Config.UseOxInventory) and falls back to
-- qbx_core / QBCore bridge if unavailable.
-- ============================================================================

local lastReward    = {}
local sessionCount  = {}
local craftCooldown = {}   -- declared here so playerDropped can always reach it
QBCore = QBCore or nil

-- ============================================================================
-- Coin helpers
-- ============================================================================

-- Weighted random draw from Config.CoinPool, returns { [item] = count, ... }
local function rollCoins(count)
    local pool = Config.CoinPool or {}
    local totalWeight = 0
    for _, e in ipairs(pool) do totalWeight = totalWeight + (e.weight or 1) end
    if totalWeight == 0 then return {} end

    local result = {}
    for _ = 1, count do
        local roll = math.random(totalWeight)
        local cum  = 0
        for _, e in ipairs(pool) do
            cum = cum + (e.weight or 1)
            if roll <= cum then
                result[e.item] = (result[e.item] or 0) + 1
                break
            end
        end
    end
    return result
end

-- Give coin items to a player and return a human-readable summary string
local function giveCoins(src, coins)
    local parts = {}
    for item, qty in pairs(coins) do
        local ok = pcall(function()
            exports.ox_inventory:AddItem(src, item, qty)
        end)
        if ok then
            parts[#parts + 1] = qty == 1 and ('1 ' .. item) or (qty .. ' ' .. item .. 's')
        end
    end
    return table.concat(parts, ', ')
end

local function tryPayOx(src, amount)
    if not Config.UseOxInventory then return false end
    local ok, result = pcall(function()
        return exports.ox_inventory:AddItem(src, Config.OxMoneyItem, amount, nil, nil)
    end)
    if ok and result then return true end
    return false
end

local function tryPayQbx(src, amount)
    local player
    local okP, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if okP and p then player = p end
    if not player and QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        player = QBCore.Functions.GetPlayer(src)
    end
    if not player then return false end
    if player.Functions and player.Functions.AddMoney then
        player.Functions.AddMoney('cash', amount, 'begging')
        return true
    elseif player.AddMoney then
        player.AddMoney('cash', amount, 'begging')
        return true
    end
    return false
end

RegisterNetEvent('umw:beg:reward', function(amount, generous, sourceTag)
    local src = source
    if type(amount) ~= 'number' or amount < 1 then return end

    -- Server-side bounds.
    local maxAllowed = generous and Config.Payout.generousMax or Config.Payout.max
    if sourceTag == 'cop_nice'  then maxAllowed = Config.CopEncounter.niceCopPayout              end
    if sourceTag == 'limo_nice' then maxAllowed = Config.LimoEncounter.payoutMax                  end
    if sourceTag == 'busking'   then maxAllowed = Config.PayoutTiers.box_and_guitar.generousMax   end
    if sourceTag == 'sign_box'  then maxAllowed = Config.PayoutTiers.sign_and_box.generousMax     end
    if sourceTag == 'box_only'  then maxAllowed = Config.PayoutTiers.box_only.generousMax         end
    if amount > maxAllowed then
        print(('[um_beg] ply %d sent over-bound amount %d (tag=%s) - ignored'):format(src, amount, tostring(sourceTag)))
        return
    end

    -- Rate limit
    local now = GetGameTimer()
    if lastReward[src] and (now - lastReward[src]) < Config.RewardCooldownMs then return end
    lastReward[src] = now

    -- Session cap
    if Config.MaxBegPerSession > 0 then
        sessionCount[src] = (sessionCount[src] or 0) + 1
        if sessionCount[src] > Config.MaxBegPerSession then return end
    end

    -- Pay
    local paid = tryPayOx(src, amount) or tryPayQbx(src, amount)
    if not paid then
        print(('[um_beg] no payment backend available for ply %d (ox+qbx both failed)'):format(src))
        return
    end

    -- Bonus items for limo payout
    if sourceTag == 'limo_nice' and Config.UseOxInventory then
        local bonusItems = Config.LimoEncounter.bonusItems or {}
        for _, entry in ipairs(bonusItems) do
            if math.random(100) <= (entry.chance or 0) then
                local qty = entry.count
                if type(qty) == 'table' then
                    qty = math.random(qty[1], qty[2])
                end
                local ok, _ = pcall(function()
                    exports.ox_inventory:AddItem(src, entry.item, qty, nil, nil)
                end)
                if ok then
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'success',
                        description = ('They also handed you %dx %s.'):format(qty, entry.item),
                        duration = Config.NotifyDuration,
                    })
                end
            end
        end
    end

    -- Confirmation notify
    local desc
    if sourceTag == 'cop_nice' then
        desc = ('The officer slipped you $%d.'):format(amount)
    elseif sourceTag == 'limo_nice' then
        desc = ('The window rolls down. They press $%d into your hand.'):format(amount)
    elseif generous then
        desc = ('A generous driver hands you $%d!'):format(amount)
    else
        desc = ('You got $%d.'):format(amount)
    end
    TriggerClientEvent('ox_lib:notify', src, {
        type = generous and 'success' or 'inform',
        description = desc,
        duration = Config.NotifyDuration,
    })
end)

-- Coin give: NPC hands the player loose change instead of a bill
RegisterNetEvent('umw:beg:coinGive', function(count)
    local src = source
    count = type(count) == 'number' and math.max(1, math.min(count, 20)) or 1

    -- Reuse the same rate-limit bucket as paper money to prevent spam
    local now = GetGameTimer()
    if lastReward[src] and (now - lastReward[src]) < Config.RewardCooldownMs then return end
    lastReward[src] = now

    local coins   = rollCoins(count)
    local summary = giveCoins(src, coins)
    if summary == '' then return end

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'inform',
        description = ('You got some change: %s.'):format(summary),
        duration    = Config.NotifyDuration,
    })
end)

-- Payphone: player found coins in the coin return slot
RegisterNetEvent('um_beg:payphoneCoins', function(count)
    local src = source
    count = type(count) == 'number' and math.max(1, math.min(count, 20)) or 1

    local coins   = rollCoins(count)
    local summary = giveCoins(src, coins)
    if summary == '' then return end

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        description = ('Found some change: %s.'):format(summary),
        duration    = Config.NotifyDuration,
    })
    print(('[um_beg] ply %d found payphone coins: %s'):format(src, summary))
end)

RegisterNetEvent('umw:beg:mugged', function()
    local src = source
    local amount = math.random(Config.Mug.stealMin, Config.Mug.stealMax)
    local stolen = false
    if Config.UseOxInventory then
        local ok, res = pcall(function()
            return exports.ox_inventory:RemoveItem(src, Config.OxMoneyItem, amount)
        end)
        if ok and res then stolen = true end
    end
    if not stolen then
        local okP, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if okP and p and p.Functions and p.Functions.RemoveMoney then
            p.Functions.RemoveMoney('cash', amount, 'mugged_while_begging')
            stolen = true
        end
    end
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'error',
        description = ('A stranger robbed you for $%d!'):format(amount),
        duration    = Config.NotifyDuration,
    })
    print(('[um_beg] ply %d mugged for $%d'):format(src, amount))
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastReward[src]    = nil
    sessionCount[src]  = nil
    craftCooldown[src] = nil
end)

-- ============================================================================
-- Jail handoff (hostile cop arrest)
-- ============================================================================

local lastJailReq = {}

RegisterNetEvent('um_beg:requestJail', function(minutes)
    local src = source
    if type(minutes) ~= 'number' then minutes = 5 end
    minutes = math.max(1, math.min(30, minutes))
    local now = GetGameTimer()
    if lastJailReq[src] and (now - lastJailReq[src]) < 30000 then return end
    lastJailReq[src] = now
    if GetResourceState('rcore_prison') ~= 'started' then
        print('[um_beg] rcore_prison not started — skipping jail')
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error', description = "The officer lets you off with a warning.", duration = 5000,
        })
        return
    end
    TriggerEvent('rcore_prison:server:JailPlayer', src, minutes)
    print(('[um_beg] ply %d jailed %d min'):format(src, minutes))
end)

AddEventHandler('playerDropped', function() lastJailReq[source] = nil end)

-- ============================================================================
-- ox_inventory: item use hook + cardboard sign crafting
-- ============================================================================

-- Item use is handled via client.event = 'um_beg:useSign' in ox_inventory/data/items.lua.
-- No server hook needed — ox_inventory fires the event directly to the client.

-- Shared crafting logic — called from both the net event (bench zones) and the command (fallback)

local function handleCraftSign(src)
    if not Config.UseOxInventory then
        TriggerClientEvent('um_beg:craftResult', src, false, 'Crafting requires ox_inventory.')
        return
    end
    -- Very short server-side cooldown to prevent spam
    local now = GetGameTimer()
    if craftCooldown[src] and (now - craftCooldown[src]) < 8000 then
        TriggerClientEvent('um_beg:craftResult', src, false, 'You just made one — give it a moment.')
        return
    end
    local okB, boxes   = pcall(function() return exports.ox_inventory:Search(src, 'count', Config.Craft.boxItem)    end)
    local okM, markers = pcall(function() return exports.ox_inventory:Search(src, 'count', Config.Craft.markerItem) end)
    if not okB or (boxes   or 0) < 1 then
        TriggerClientEvent('um_beg:craftResult', src, false, ('You need 1 %s.'):format(Config.Craft.boxItem));    return
    end
    if not okM or (markers or 0) < 1 then
        TriggerClientEvent('um_beg:craftResult', src, false, ('You need 1 %s.'):format(Config.Craft.markerItem)); return
    end
    craftCooldown[src] = now
    exports.ox_inventory:RemoveItem(src, Config.Craft.boxItem,    1)
    exports.ox_inventory:RemoveItem(src, Config.Craft.markerItem, 1)
    exports.ox_inventory:AddItem(src,    Config.BegItem,          1)
    TriggerClientEvent('um_beg:craftResult', src, true, 'You scrawled something on the cardboard. Good enough.')
    print(('[um_beg] ply %d crafted %s'):format(src, Config.BegItem))
end

-- Net event: fired by the proximity bench zones in client.lua
RegisterNetEvent('um_beg:craftSign', function()
    handleCraftSign(source)
end)

-- Command fallback: /craftbegbox works anywhere, no bench required
RegisterCommand('craftbegbox', function(source)
    handleCraftSign(source)
end, false)

-- Load QBCore bridge if present (for fallback path)
CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok then QBCore = core end
    end
end)

