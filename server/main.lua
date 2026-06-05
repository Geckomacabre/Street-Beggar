-- ============================================================================
-- server/main.lua
-- Hobo-job server events: duty, progression, scavenging, shelter, crafting.
-- Begging rewards are still handled in server/server.lua.
-- ============================================================================

-- Per-player in-memory state (cleared on disconnect)
local playerData  = {}   -- [src] = { citizenid, prog = {...}, scavengeCount = 0 }
local scavengeHr  = {}   -- [src] = { count, windowStart } rate-limit per hour

-- ============================================================================
-- Helpers
-- ============================================================================

local function getCitizenId(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and player then
        return player.PlayerData and player.PlayerData.citizenid
    end
    return nil
end

local function getPlayerData(src)
    if not playerData[src] then
        playerData[src] = { scavengeCount = 0 }
    end
    return playerData[src]
end

-- XP threshold to reach a given rank
local function xpForRank(rank)
    return Config.RankXP[rank] or Config.RankXP[Config.MaxRank]
end

-- Recalculate rank from raw XP
local function calcRank(xp)
    local rank = 1
    for r = Config.MaxRank, 1, -1 do
        if xp >= xpForRank(r) then rank = r; break end
    end
    return rank
end

-- ============================================================================
-- Duty toggle
-- ============================================================================

RegisterNetEvent('um_hobos:setDuty', function(state)
    local src = source
    local cid = getCitizenId(src)
    if not cid then return end

    if state then
        -- Set job via qbx_core player object
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player then
            -- qbx_core: player.Functions.SetJob(name, grade)
            local ok2 = pcall(function()
                player.Functions.SetJob(Config.JobName, 0)
            end)
            -- QBCore bridge fallback
            if not ok2 and QBCore then
                local ply = QBCore.Functions.GetPlayer(src)
                if ply then ply.Functions.SetJob(Config.JobName, 0) end
            end
        end
        -- Load progression
        DB_LoadProgression(cid, function(data)
            local pd = getPlayerData(src)
            pd.citizenid = cid
            pd.prog      = data
            TriggerClientEvent('um_hobos:client:loadProgression', src, {
                xp              = data.xp,
                rank            = data.rank,
                skills          = data.skills,
                onboarding_done = data.onboarding_done,
            })
            if data.shelter then
                TriggerClientEvent('um_hobos:client:loadShelter', src, data.shelter)
            end
        end)
    else
        -- Save on clock-off
        local pd = getPlayerData(src)
        if pd.prog then DB_SaveProgression(cid, pd.prog) end
        -- Reset to unemployed in framework
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player then
            pcall(function() player.Functions.SetJob('unemployed', 0) end)
        end
    end

    -- Echo back to client (keeps duty mirror in sync)
    TriggerClientEvent('um_hobos:client:setDuty', src, state)
end)

-- ============================================================================
-- Progression: XP gain
-- ============================================================================

RegisterNetEvent('um_hobos:gainXP', function(amount, sourceTag)
    local src = source
    if type(amount) ~= 'number' or amount < 1 or amount > 500 then return end

    local pd = getPlayerData(src)
    if not pd.prog then return end

    local prog    = pd.prog
    local oldRank = prog.rank
    prog.xp       = prog.xp + amount

    -- Check for rank-up
    local newRank = calcRank(prog.xp)
    if newRank > oldRank and newRank <= Config.MaxRank then
        prog.rank = newRank
    end

    -- Push update to client
    TriggerClientEvent('um_hobos:client:updateProgression', src, {
        xp     = prog.xp,
        rank   = prog.rank,
        skills = prog.skills,
    })

    -- Debounced DB save (every 5 XP gains or rank-up)
    pd.xpGainsSinceSave = (pd.xpGainsSinceSave or 0) + 1
    if pd.xpGainsSinceSave >= 5 or newRank > oldRank then
        pd.xpGainsSinceSave = 0
        DB_SaveProgression(pd.citizenid or getCitizenId(src), prog)
    end
end)

-- ============================================================================
-- Progression: skill XP
-- ============================================================================

RegisterNetEvent('um_hobos:gainSkillXP', function(sourceTag)
    local src = source
    local pd  = getPlayerData(src)
    if not pd.prog then return end

    for skillName, tags in pairs(Config.SkillXP) do
        local gain = tags[sourceTag]
        if gain and gain > 0 then
            local current = pd.prog.skills[skillName] or 0
            if current < Config.MaxSkillLevel then
                -- Accumulate hidden XP (1 point per relevant event, level up at 10)
                pd.skillAccum = pd.skillAccum or {}
                pd.skillAccum[skillName] = (pd.skillAccum[skillName] or 0) + gain
                if pd.skillAccum[skillName] >= 10 then
                    pd.skillAccum[skillName] = 0
                    local newLevel = current + 1
                    pd.prog.skills[skillName] = newLevel
                    TriggerClientEvent('um_hobos:client:skillUp', src, skillName, newLevel)
                end
            end
        end
    end
end)

-- ============================================================================
-- Progression: request current data (on duty start)
-- ============================================================================

RegisterNetEvent('um_hobos:requestProgression', function()
    local src = source
    local pd  = getPlayerData(src)
    if pd.prog then
        TriggerClientEvent('um_hobos:client:loadProgression', src, {
            xp     = pd.prog.xp,
            rank   = pd.prog.rank,
            skills = pd.prog.skills,
        })
    end
end)

-- ============================================================================
-- Scavenging: roll loot server-side
-- ============================================================================

RegisterNetEvent('um_hobos:scavengeRoll', function(scavengeSkill)
    local src = source
    if type(scavengeSkill) ~= 'number' then scavengeSkill = 0 end
    scavengeSkill = math.min(math.max(scavengeSkill, 0), Config.MaxSkillLevel)

    -- Hourly rate limit
    local now = os.time()
    if not scavengeHr[src] or (now - scavengeHr[src].windowStart) > 3600 then
        scavengeHr[src] = { count = 0, windowStart = now }
    end
    scavengeHr[src].count = scavengeHr[src].count + 1
    if scavengeHr[src].count > Config.ScavengeMaxPerHour then
        print(('[um_hobos] ply %d over scavenge hourly cap'):format(src))
        return
    end

    local tier   = GetLootTier(scavengeSkill)
    local result = RollLoot(tier)
    local isRare = tier >= 4

    if result then
        if Config.UseOxInventory then
            local ok = pcall(function()
                exports.ox_inventory:AddItem(src, result.item, result.count)
            end)
            if not ok then
                print(('[um_hobos] failed to give %s x%d to ply %d'):format(result.item, result.count, src))
            end
        end
        TriggerClientEvent('um_hobos:client:scavengeResult', src, result.item, result.count, isRare)
    else
        TriggerClientEvent('um_hobos:client:scavengeResult', src, nil, 0, false)
    end
end)

-- ============================================================================
-- Needs
-- ============================================================================

-- ============================================================================
-- State-bag helpers (um_hud reads hunger/thirst/stress from qbx state bags)
-- Hobo activities write here instead of maintaining a separate needs system.
-- ============================================================================

local function clampStateBag(src, key, delta)
    local current = Player(src).state[key]
    if type(current) ~= 'number' then current = 100 end
    local newVal = math.max(0, math.min(100, current + delta))
    Player(src).state:set(key, newVal, true)
end

-- Campfire warmth / morale bump → lower stress
RegisterNetEvent('um_hobos:adjustStress', function(delta)
    local src = source
    if type(delta) ~= 'number' then return end
    delta = math.max(-20, math.min(20, delta))
    clampStateBag(src, 'stress', delta)
end)

-- Campfire / shelter energy bump → nudge hunger back up slightly
RegisterNetEvent('um_hobos:adjustHunger', function(delta)
    local src = source
    if type(delta) ~= 'number' then return end
    delta = math.max(0, math.min(20, delta))
    clampStateBag(src, 'hunger', delta)
end)

-- Thirst restore (drinking water, etc.)
RegisterNetEvent('um_hobos:adjustThirst', function(delta)
    local src = source
    if type(delta) ~= 'number' then return end
    delta = math.max(0, math.min(20, delta))
    clampStateBag(src, 'thirst', delta)
end)

-- Shelter sleep — restore both hunger and thirst a bit, reduce stress
RegisterNetEvent('um_hobos:shelterSleepNeeds', function(energy, morale)
    local src = source
    clampStateBag(src, 'hunger',  (energy or 0) * 0.5)
    clampStateBag(src, 'thirst',  (energy or 0) * 0.5)
    clampStateBag(src, 'stress', -(morale or 0))
end)

-- ============================================================================
-- Shelter
-- ============================================================================

RegisterNetEvent('um_hobos:requestShelter', function()
    local src = source
    local pd  = getPlayerData(src)
    if pd.prog and pd.prog.shelter then
        TriggerClientEvent('um_hobos:client:loadShelter', src, pd.prog.shelter)
    end
end)

RegisterNetEvent('um_hobos:saveShelter', function(data)
    local src = source
    local pd  = getPlayerData(src)
    if pd.prog then pd.prog.shelter = data end
    local cid = getCitizenId(src)
    if cid then DB_SaveShelter(cid, data) end
end)

RegisterNetEvent('um_hobos:removeShelter', function()
    local src = source
    local pd  = getPlayerData(src)
    if pd.prog then pd.prog.shelter = nil end
    local cid = getCitizenId(src)
    if cid then DB_SaveShelter(cid, nil) end
end)

-- Shelter stash (uses ox_inventory stash feature)
RegisterNetEvent('um_hobos:openShelterStash', function()
    local src = source
    local cid = getCitizenId(src)
    if not cid then return end
    if Config.UseOxInventory then
        TriggerClientEvent('ox_inventory:openInventory', src, 'stash', {
            id    = 'hobo_shelter_' .. cid,
            slots = Config.ShelterStorageSlots,
            maxWeight = 30000,
        })
    end
end)

-- ============================================================================
-- Pickpocket reward
-- ============================================================================

local lastPickpocket = {}   -- [src] = ms, rate-limit

-- Build a quick lookup of valid loot pool entries for server-side validation
local function isValidPickpocketLoot(rewardType, value, itemName)
    for _, e in ipairs(Config.Pickpocket.loot) do
        if e.type == rewardType then
            if rewardType == 'cash'  and e.value == value   then return true end
            if rewardType == 'item'  and e.item  == itemName then return true end
        end
    end
    return false
end

RegisterNetEvent('um_hobos:pickpocketReward', function(rewardType, value, itemName)
    local src = source

    -- Basic type validation
    if rewardType ~= 'cash' and rewardType ~= 'item' then return end

    -- Rate limit: one reward per 8 seconds
    local now = GetGameTimer()
    if lastPickpocket[src] and (now - lastPickpocket[src]) < 8000 then return end
    lastPickpocket[src] = now

    -- Validate against loot pool (prevent spoofed items / amounts)
    if not isValidPickpocketLoot(rewardType, value, itemName) then
        print(('[um_hobos] ply %d sent invalid pickpocket reward: type=%s value=%s item=%s')
            :format(src, tostring(rewardType), tostring(value), tostring(itemName)))
        return
    end

    if rewardType == 'cash' then
        local paid = false
        if Config.UseOxInventory then
            local ok, res = pcall(function()
                return exports.ox_inventory:AddItem(src, Config.OxMoneyItem, value)
            end)
            if ok and res then paid = true end
        end
        if not paid then
            local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
            if ok and player and player.Functions then
                player.Functions.AddMoney('cash', value, 'pickpocket')
            end
        end

    elseif rewardType == 'item' then
        if Config.UseOxInventory then
            pcall(function()
                exports.ox_inventory:AddItem(src, itemName, 1)
            end)
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastPickpocket[source] = nil
end)

-- ============================================================================
-- Hobo crafting
-- ============================================================================

RegisterNetEvent('um_hobos:craftHoboItem', function(recipeLabel)
    local src = source
    if not Config.UseOxInventory then
        TriggerClientEvent('um_hobos:client:craftResult', src, false, 'Crafting requires ox_inventory.')
        return
    end

    local recipe = nil
    for _, r in ipairs(Config.HoboCrafting) do
        if r.label == recipeLabel then recipe = r; break end
    end
    if not recipe then
        TriggerClientEvent('um_hobos:client:craftResult', src, false, 'Unknown recipe.')
        return
    end

    -- Check ingredients
    for _, req in ipairs(recipe.requires) do
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(src, 'count', req.item)
        end)
        if not ok or (count or 0) < req.count then
            TriggerClientEvent('um_hobos:client:craftResult', src, false,
                string.format(Lang.craft_no_materials .. ' (need %dx %s)', req.count, req.item))
            return
        end
    end

    -- Consume
    for _, req in ipairs(recipe.requires) do
        exports.ox_inventory:RemoveItem(src, req.item, req.count)
    end

    -- Give result — weapons get low durability metadata
    local meta = nil
    if recipe.result.item == 'weapon_knife' then
        meta = { durability = 15 }   -- breaks quickly; hobo-made after all
    end
    exports.ox_inventory:AddItem(src, recipe.result.item, recipe.result.count, meta)

    TriggerClientEvent('um_hobos:client:craftResult', src, true,
        string.format(Lang.craft_success, recipe.result.count .. 'x ' .. recipe.result.item),
        recipe.xp)
end)

-- ============================================================================
-- Windshield washing reward
-- ============================================================================

local lastWash = {}   -- [src] = ms

RegisterNetEvent('um_hobos:washReward', function(amount)
    local src = source
    if type(amount) ~= 'number' or amount < 1 then return end

    local maxAmt = Config.Washing.generousMax + 5
    if amount > maxAmt then
        print(('[um_hobos] ply %d sent over-bound wash amount %d'):format(src, amount))
        return
    end

    local now = GetGameTimer()
    if lastWash[src] and (now - lastWash[src]) < 3000 then return end
    lastWash[src] = now

    local paid = false
    if Config.UseOxInventory then
        local ok, res = pcall(function()
            return exports.ox_inventory:AddItem(src, Config.OxMoneyItem, amount)
        end)
        if ok and res then paid = true end
    end
    if not paid then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player and player.Functions then
            player.Functions.AddMoney('cash', amount, 'windshield_wash')
        end
    end
end)

-- ============================================================================
-- Can / bottle collecting
-- ============================================================================

local lastCollect = {}

RegisterNetEvent('um_hobos:collectItem', function(item)
    local src = source

    -- Validate item is in the collecting items list
    local valid = false
    for _, e in ipairs(Config.Collecting.items) do
        if e.item == item then valid = true; break end
    end
    if not valid then return end

    -- Rate limit: max one item per 2 s
    local now = GetGameTimer()
    if lastCollect[src] and (now - lastCollect[src]) < 2000 then return end
    lastCollect[src] = now

    if Config.UseOxInventory then
        pcall(function() exports.ox_inventory:AddItem(src, item, 1) end)
    end
end)

RegisterNetEvent('um_hobos:sellCollectibles', function()
    local src = source
    if not Config.UseOxInventory then return end

    local totalEarned = 0
    local totalCount  = 0

    -- Sell standard collectibles (cans/bottles from collecting.lua)
    for _, e in ipairs(Config.Collecting.items) do
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(src, 'count', e.item)
        end)
        local qty = (ok and count) or 0
        qty = math.min(qty, Config.Collecting.maxPerSell)
        if qty > 0 then
            local ok2 = pcall(function() exports.ox_inventory:RemoveItem(src, e.item, qty) end)
            if ok2 then
                totalEarned = totalEarned + (e.price * qty)
                totalCount  = totalCount  + qty
            end
        end
    end

    -- Sell scrap metals from RecyclingCenter prices (open to all)
    local rc = Config.RecyclingCenter
    if rc and rc.prices then
        for item, price in pairs(rc.prices) do
            -- Skip items already handled above to avoid double-counting
            local alreadyHandled = false
            for _, e in ipairs(Config.Collecting.items) do
                if e.item == item then alreadyHandled = true; break end
            end
            if not alreadyHandled then
                local ok, count = pcall(function()
                    return exports.ox_inventory:Search(src, 'count', item)
                end)
                local qty = math.min((ok and count) or 0, rc.maxPerSell or 100)
                if qty > 0 then
                    local ok2 = pcall(function() exports.ox_inventory:RemoveItem(src, item, qty) end)
                    if ok2 then
                        totalEarned = totalEarned + (price * qty)
                        totalCount  = totalCount  + qty
                    end
                end
            end
        end
    end

    if totalEarned > 0 then
        if Config.UseOxInventory then
            pcall(function() exports.ox_inventory:AddItem(src, Config.OxMoneyItem, totalEarned) end)
        else
            local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
            if ok and player and player.Functions then
                player.Functions.AddMoney('cash', totalEarned, 'recycling')
            end
        end
    end

    TriggerClientEvent('um_hobos:client:sellResult', src, totalEarned, totalCount)
end)

-- ============================================================================
-- Odd jobs
-- ============================================================================

local oddJobState = {
    pool      = {},   -- current 3 available jobs
    lastReset = 0,
    active    = {},   -- [src] = jobId
}

local function refreshOddJobs()
    oddJobState.lastReset = os.time()
    -- Shuffle pool and pick maxSlots
    local shuffled = {}
    for _, j in ipairs(Config.OddJobs.jobPool) do shuffled[#shuffled + 1] = j end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    oddJobState.pool = {}
    for i = 1, math.min(Config.OddJobs.maxSlots, #shuffled) do
        oddJobState.pool[#oddJobState.pool + 1] = shuffled[i]
    end
end

refreshOddJobs()

RegisterNetEvent('um_hobos:requestOddJobs', function()
    local src = source
    -- Refresh if needed
    if (os.time() - oddJobState.lastReset) > (Config.OddJobs.refreshMs / 1000) then
        refreshOddJobs()
    end
    TriggerClientEvent('um_hobos:client:jobList', src, oddJobState.pool)
end)

RegisterNetEvent('um_hobos:completeOddJob', function(jobId)
    local src = source

    -- Find the job in the pool
    local job = nil
    for _, j in ipairs(oddJobState.pool) do
        if j.id == jobId then job = j; break end
    end
    if not job then
        print(('[um_hobos] ply %d claimed unknown job: %s'):format(src, tostring(jobId)))
        return
    end

    -- Pay
    if Config.UseOxInventory then
        pcall(function() exports.ox_inventory:AddItem(src, Config.OxMoneyItem, job.payout) end)
    else
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player and player.Functions then
            player.Functions.AddMoney('cash', job.payout, 'oddjob')
        end
    end

    TriggerClientEvent('um_hobos:client:jobComplete', src, job.label, job.payout, job.xp or 0)
end)

-- ============================================================================
-- Campfire cooking (light/fuel/relight handled in new sections above)
-- ============================================================================

RegisterNetEvent('um_hobos:campfireCook', function(inputItem, outputItem)
    local src = source
    if not Config.UseOxInventory then return end

    -- Validate recipe against shared cooking table
    local recipe = nil
    for _, r in ipairs(Config.CampfireCooking) do
        if r.input == inputItem and r.output == outputItem then recipe = r; break end
    end
    if not recipe then
        TriggerClientEvent('um_hobos:client:cookResult', src, false, nil)
        return
    end

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', inputItem)
    end)
    if not ok or (count or 0) < 1 then
        TriggerClientEvent('um_hobos:client:cookResult', src, false, nil)
        return
    end

    exports.ox_inventory:RemoveItem(src, inputItem, 1)
    exports.ox_inventory:AddItem(src, outputItem, 1)
    TriggerClientEvent('um_hobos:client:cookResult', src, true, outputItem)

    -- Cooking something → restore a little hunger via HUD state bag
    clampStateBag(src, 'hunger', 8)
    clampStateBag(src, 'stress', -5)
end)

-- ============================================================================
-- Stolen goods fence
-- ============================================================================

local lastFence = {}

RegisterNetEvent('um_hobos:fenceSell', function(item, clientCount)
    local src = source
    if type(item) ~= 'string' then return end

    -- Validate item is in fence list
    local entry = nil
    for _, e in ipairs(Config.Fence.items) do
        if e.item == item then entry = e; break end
    end
    if not entry then
        TriggerClientEvent('um_hobos:client:fenceDenied', src, "I don't want that.")
        return
    end

    -- Rate limit
    local now = GetGameTimer()
    if lastFence[src] and (now - lastFence[src]) < Config.Fence.cooldownMs then
        TriggerClientEvent('um_hobos:client:fenceDenied', src, 'Not right now. Come back later.')
        return
    end

    if not Config.UseOxInventory then
        TriggerClientEvent('um_hobos:client:fenceDenied', src, 'Requires ox_inventory.')
        return
    end

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', item)
    end)
    local qty = math.min((ok and count) or 0, clientCount or 99)
    if qty < 1 then
        TriggerClientEvent('um_hobos:client:fenceDenied', src, "You don't have that on you.")
        return
    end

    -- Apply charisma bonus server-side
    local pd     = getPlayerData(src)
    local charLv = (pd.prog and pd.prog.skills and pd.prog.skills.charisma) or 0
    local bonus  = 1.0 + (charLv * Config.Fence.charismaBonus)
    local price  = math.floor(entry.price * bonus)
    local total  = price * qty

    exports.ox_inventory:RemoveItem(src, item, qty)
    if Config.UseOxInventory then
        pcall(function() exports.ox_inventory:AddItem(src, Config.OxMoneyItem, total) end)
    end

    local busted = math.random(100) <= Config.Fence.bustedChance
    lastFence[src] = now
    TriggerClientEvent('um_hobos:client:fenceSold', src, entry.label, qty, total, busted)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastWash[src]     = nil
    lastCollect[src]  = nil
    lastFence[src]    = nil
end)

-- ============================================================================
-- Dumpster diving outcomes (all job-agnostic — anyone can search dumpsters)
-- ============================================================================

local lastDumpster = {}  -- [src] = ms rate-limit

local function dumpsterRateLimit(src)
    local now = GetGameTimer()
    if lastDumpster[src] and (now - lastDumpster[src]) < 4000 then return false end
    lastDumpster[src] = now
    return true
end

RegisterNetEvent('um_hobos:dumpsterItemRoll', function()
    local src = source
    if not dumpsterRateLimit(src) then return end
    if not Config.UseOxInventory then return end

    -- Use the dumpster-specific loot table (lots of filler)
    local result = RollLoot(LootTables.dumpster)
    if result and result.item then
        pcall(function() exports.ox_inventory:AddItem(src, result.item, result.count) end)
        TriggerClientEvent('um_hobos:client:dumpsterResult', src, result.item, result.count)
    else
        TriggerClientEvent('um_hobos:client:dumpsterResult', src, nil, 0)
    end
end)

RegisterNetEvent('um_hobos:dumpsterFoodFound', function()
    local src = source
    if not dumpsterRateLimit(src) then return end
    if not Config.UseOxInventory then return end
    local foods = { 'half_eaten_food', 'rotten_food', 'food_scraps' }
    local item  = foods[math.random(#foods)]
    pcall(function() exports.ox_inventory:AddItem(src, item, 1) end)
    TriggerClientEvent('um_hobos:client:dumpsterFood', src, item)
end)

RegisterNetEvent('um_hobos:dumpsterBottlesFound', function(count)
    local src = source
    if not dumpsterRateLimit(src) then return end
    if type(count) ~= 'number' then count = 1 end
    count = math.min(math.max(count, 1), 3)
    if not Config.UseOxInventory then return end
    -- Mix of cans and bottles
    local bottleItem = math.random(2) == 1 and 'bottle' or 'can'
    pcall(function() exports.ox_inventory:AddItem(src, bottleItem, count) end)
    TriggerClientEvent('um_hobos:client:dumpsterBottles', src, count)
end)

RegisterNetEvent('um_hobos:dumpsterCashFound', function(amount)
    local src = source
    if not dumpsterRateLimit(src) then return end
    if type(amount) ~= 'number' then return end
    local cfg = Config.DumpsterDiving
    amount = math.min(math.max(amount, cfg.cashMin), cfg.cashMax)
    if Config.UseOxInventory then
        pcall(function() exports.ox_inventory:AddItem(src, Config.OxMoneyItem, amount) end)
    end
    TriggerClientEvent('um_hobos:client:dumpsterCash', src, amount)
end)

AddEventHandler('playerDropped', function() lastDumpster[source] = nil end)

-- ============================================================================
-- Campfire relight (server validates lighter + fuel before telling client to relit)
-- ============================================================================

RegisterNetEvent('um_hobos:campfireRelight', function(fireType)
    local src = source
    if type(fireType) ~= 'string' then return end
    local cfg = Config.Campfires[fireType]
    if not cfg then return end
    if not Config.UseOxInventory then return end

    -- Check lighter
    local okL, lighterCount = pcall(function()
        return exports.ox_inventory:Search(src, 'count', 'lighter')
    end)
    if not okL or (lighterCount or 0) < 1 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You need a lighter to relight the fire.', duration = 3000 })
        return
    end

    -- Check fuel
    local okF, fuelCount = pcall(function()
        return exports.ox_inventory:Search(src, 'count', cfg.fuelItem)
    end)
    if not okF or (fuelCount or 0) < cfg.fuelPerLight then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('You need %dx %s to relight.'):format(cfg.fuelPerLight, cfg.fuelItem),
            duration = 3000,
        })
        return
    end

    exports.ox_inventory:RemoveItem(src, cfg.fuelItem, cfg.fuelPerLight)
    TriggerClientEvent('um_hobos:client:campfireRelit', src, fireType)
end)

-- Update campfireLight to support fire type
RegisterNetEvent('um_hobos:campfireLight', function(fireType)
    local src = source
    if not Config.UseOxInventory then return end
    local cfg = Config.Campfires[fireType or 'beach_fire']
    if not cfg then return end

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', cfg.item)
    end)
    -- Item is consumed when placed (ox_inventory handles this via use hook)
    -- Just remove fuel items
    local okF, fuelCount = pcall(function()
        return exports.ox_inventory:Search(src, 'count', cfg.fuelItem)
    end)
    if not okF or (fuelCount or 0) < cfg.fuelPerLight then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('You need %dx %s to light a fire.'):format(cfg.fuelPerLight, cfg.fuelItem),
        })
        return
    end
    exports.ox_inventory:RemoveItem(src, cfg.fuelItem, cfg.fuelPerLight)
end)

-- campfireAddFuel now accepts fireType
RegisterNetEvent('um_hobos:campfireAddFuel', function(fireType)
    local src = source
    if not Config.UseOxInventory then return end
    local cfg = Config.Campfires[fireType or 'beach_fire']
    if not cfg then return end
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', cfg.fuelItem)
    end)
    if not ok or (count or 0) < cfg.fuelPerAdd then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('You need %dx %s to add fuel.'):format(cfg.fuelPerAdd or 1, cfg.fuelItem),
        })
        return
    end
    exports.ox_inventory:RemoveItem(src, cfg.fuelItem, cfg.fuelPerAdd or 1)
    TriggerClientEvent('um_hobos:client:campfireFuelAdded', src, fireType)
end)

-- ============================================================================
-- Cooperative car wash
-- ============================================================================

local washOffers = {}   -- [washerSrc] = { expiresAt }
local washPairs  = {}   -- [washerSrc] = ownerSrc

RegisterNetEvent('um_hobos:offerWash', function()
    local src = source
    washOffers[src] = { expiresAt = GetGameTimer() + (Config.CoopWash.acceptTtlMs or 120000) }
end)

RegisterNetEvent('um_hobos:cancelWashOffer', function()
    local src = source
    washOffers[src] = nil
    washPairs[src]  = nil
end)

RegisterNetEvent('um_hobos:acceptWash', function(vehicleNetId)
    local ownerSrc = source
    if type(vehicleNetId) ~= 'number' then return end

    -- Find nearest active washer
    local ownerPos = GetEntityCoords(GetPlayerPed(ownerSrc))
    local bestWasher, bestDist = nil, Config.CoopWash.offerRadius or 40.0
    local now = GetGameTimer()

    for washerSrc, data in pairs(washOffers) do
        if now < data.expiresAt then
            local washerPos = GetEntityCoords(GetPlayerPed(washerSrc))
            local dist = #(washerPos - ownerPos)
            if dist < bestDist then
                bestDist   = dist
                bestWasher = washerSrc
            end
        else
            washOffers[washerSrc] = nil
        end
    end

    if not bestWasher then
        TriggerClientEvent('ox_lib:notify', ownerSrc, {
            type = 'error',
            description = 'No one nearby is offering car washes.',
            duration = 3000,
        })
        return
    end

    washPairs[bestWasher] = ownerSrc
    TriggerClientEvent('um_hobos:client:washApproved', bestWasher, vehicleNetId, ownerSrc)
end)

RegisterNetEvent('um_hobos:coopWashComplete', function(ownerServerId, amount)
    local washerSrc = source
    if type(amount) ~= 'number' or amount < 1 then return end

    local maxAmt = (Config.CoopWash.payoutMax or 25) + 5
    if amount > maxAmt then return end

    -- Deduct from owner
    local deducted = false
    if Config.UseOxInventory then
        local ok, ownerBalance = pcall(function()
            return exports.ox_inventory:Search(ownerServerId, 'count', Config.OxMoneyItem)
        end)
        if ok and (ownerBalance or 0) >= amount then
            local ok2 = pcall(function()
                exports.ox_inventory:RemoveItem(ownerServerId, Config.OxMoneyItem, amount)
            end)
            if ok2 then deducted = true end
        end
    end

    if deducted then
        -- Pay washer
        if Config.UseOxInventory then
            pcall(function() exports.ox_inventory:AddItem(washerSrc, Config.OxMoneyItem, amount) end)
        end
        TriggerClientEvent('um_hobos:client:coopWashDone', ownerServerId, amount)
    else
        TriggerClientEvent('ox_lib:notify', washerSrc, {
            type = 'error',
            description = 'Owner does not have enough cash.',
            duration = 3000,
        })
    end

    washOffers[washerSrc] = nil
    washPairs[washerSrc]  = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    washOffers[src] = nil
    washPairs[src]  = nil
end)

-- ============================================================================
-- Onboarding
-- ============================================================================

RegisterNetEvent('um_hobos:onboardingComplete', function()
    local src = source
    local cid = getCitizenId(src)
    if not cid then return end

    -- Mark done in DB
    DB_SaveOnboarding(cid)

    -- Update in-memory flag
    local pd = getPlayerData(src)
    if pd.prog then pd.prog.onboarding_done = true end

    -- Give starter kit
    local kit = Config.Onboarding.starterKit
    for _, entry in ipairs(kit) do
        pcall(function() exports.ox_inventory:AddItem(src, entry.item, entry.count) end)
    end

    TriggerClientEvent('um_hobos:client:onboardingComplete', src)
    print(('[um_beg] ply %d completed onboarding'):format(src))
end)

-- Check onboarding status when progression loads (sent back with duty start)
-- The setDuty handler already sends loadProgression which includes onboarding_done

-- ============================================================================
-- Cleanup on disconnect
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src    = source
    local pd     = playerData[src]
    if pd and pd.prog and pd.citizenid then
        DB_SaveProgression(pd.citizenid, pd.prog)
        if Config.NeedsEnabled and pd.prog.needs then
            DB_SaveNeeds(pd.citizenid, pd.prog.needs)
        end
    end
    playerData[src]  = nil
    scavengeHr[src]  = nil
end)

-- ============================================================================
-- Load QBCore bridge
-- ============================================================================
QBCore = nil
CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok then QBCore = core end
    end
end)
