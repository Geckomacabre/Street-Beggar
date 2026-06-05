-- ============================================================================
-- server/worldinteractions.lua
-- Server-side for world interactions port (porta potty, dumpster hiding,
-- chairs, toilets, vending machines, parking meters).
-- ============================================================================

-- ============================================================================
-- Shared ox_inventory helpers
-- ============================================================================

local function addItem(src, item, amt)
    pcall(function() exports.ox_inventory:AddItem(src, item, amt) end)
end

local function removeItem(src, item, amt)
    local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, item, amt) end)
    return ok and res
end

local function getItemCount(src, item)
    local ok, cnt = pcall(function() return exports.ox_inventory:Search(src, 'count', item) end)
    return (ok and cnt) or 0
end

local function getCash(src)
    return getItemCount(src, Config.OxMoneyItem)
end

local function removeCash(src, amt)
    return removeItem(src, Config.OxMoneyItem, amt)
end

local function addCash(src, amt)
    addItem(src, Config.OxMoneyItem, amt)
end

-- ============================================================================
-- Update loop (clears expired meter records and search cooldowns)
-- ============================================================================

local meterRecords   = {}   -- [key] = { timeStart, slottedTime }
local robbedMeters   = {}   -- [key] = os.time() of robbery
local dumpsterInUse  = {}   -- [key] = src
local portaInUse     = {}   -- [key] = src
local chairInUse     = {}   -- [key] = { user = src, model = hash }
local toiletInUse    = {}   -- [key] = { user = src }
local vendStock      = {}   -- [key][itemName] = { stock, price, label }
local robInProgress  = {}   -- [src] = true (prevents double-rob)

CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        -- expire paid meter records
        for k, v in pairs(meterRecords) do
            if math.abs(os.difftime(v.timeStart, now)) > (v.slottedTime * 60) then
                meterRecords[k] = nil
            end
        end
        -- expire robbery cooldowns
        local cooldownSecs = (Config.ParkingMeters.robbery.cooldownMins or 10) * 60
        for k, t in pairs(robbedMeters) do
            if math.abs(os.difftime(t, now)) > cooldownSecs then
                robbedMeters[k] = nil
            end
        end
    end
end)

-- ============================================================================
-- Porta Potty
-- ============================================================================

RegisterNetEvent('um_worldint:server:usePorta', function(key)
    local src = source
    if portaInUse[key] then
        TriggerClientEvent('um_worldint:client:portaInUse', src)
        return
    end
    portaInUse[key] = src
    TriggerClientEvent('um_worldint:client:startPorta', src)
end)

RegisterNetEvent('um_worldint:server:exitPorta', function(key)
    local src = source
    if portaInUse[key] == src then portaInUse[key] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(portaInUse) do
        if v == src then portaInUse[k] = nil end
    end
end)

-- ============================================================================
-- Dumpster Hiding
-- ============================================================================

RegisterNetEvent('um_worldint:server:useDump', function(key)
    local src = source
    if dumpsterInUse[key] then
        TriggerClientEvent('um_worldint:client:dumpInUse', src)
        return
    end
    dumpsterInUse[key] = src
    TriggerClientEvent('um_worldint:client:startDumpHide', src)
end)

RegisterNetEvent('um_worldint:server:exitDump', function(key)
    local src = source
    if dumpsterInUse[key] == src then dumpsterInUse[key] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(dumpsterInUse) do
        if v == src then dumpsterInUse[k] = nil end
    end
end)

-- ============================================================================
-- Chairs
-- ============================================================================

RegisterNetEvent('um_worldint:server:useChair', function(key, modelHash)
    local src = source
    if chairInUse[key] then
        TriggerClientEvent('um_worldint:client:chairInUse', src)
        return
    end
    chairInUse[key] = { user = src, model = modelHash }
    TriggerClientEvent('um_worldint:client:startChair', src, modelHash)
end)

RegisterNetEvent('um_worldint:server:leaveChair', function(key)
    local src = source
    if chairInUse[key] and chairInUse[key].user == src then
        chairInUse[key] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(chairInUse) do
        if v.user == src then chairInUse[k] = nil end
    end
end)

-- ============================================================================
-- Toilets
-- ============================================================================

RegisterNetEvent('um_worldint:server:useToilet', function(key, standing, modelHash)
    local src = source
    if toiletInUse[key] then
        TriggerClientEvent('um_worldint:client:toiletInUse', src)
        return
    end
    toiletInUse[key] = { user = src }
    TriggerClientEvent('um_worldint:client:startToilet', src, standing, modelHash)
end)

RegisterNetEvent('um_worldint:server:leaveToilet', function(key)
    local src = source
    if toiletInUse[key] and toiletInUse[key].user == src then
        toiletInUse[key] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(toiletInUse) do
        if v.user == src then toiletInUse[k] = nil end
    end
end)

-- ============================================================================
-- Vending Machines
-- ============================================================================

local function getOrInitVend(key, machineIdx)
    if vendStock[key] then return vendStock[key] end
    local machine = Config.VendingMachines.machines[machineIdx]
    if not machine then return nil end
    local t = {}
    for _, item in ipairs(machine.items) do
        t[item.name] = { stock = item.stock, price = item.price, label = item.label }
    end
    vendStock[key] = t
    return t
end

RegisterNetEvent('um_worldint:server:openVend', function(key, machineIdx)
    local src  = source
    local data = getOrInitVend(key, machineIdx)
    if not data then return end
    TriggerClientEvent('um_worldint:client:openVend', src, key, machineIdx, data)
end)

RegisterNetEvent('um_worldint:server:buyVend', function(key, machineIdx, itemName)
    local src  = source
    local data = vendStock[key]
    if not data or not data[itemName] or data[itemName].stock <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Out of stock.', duration = 3000 })
        return
    end

    local price = data[itemName].price
    if getCash(src) < price then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = ("You need $%d."):format(price), duration = 3000 })
        return
    end

    removeCash(src, price)
    addItem(src, itemName, 1)
    data[itemName].stock = data[itemName].stock - 1

    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        description = ('Purchased 1x %s for $%d.'):format(data[itemName].label, price),
        duration    = 3000,
    })
end)

-- ============================================================================
-- Parking Meters
-- ============================================================================

RegisterNetEvent('um_worldint:server:payMeter', function(key, hours, mins)
    local src       = source
    local totalMins = (tonumber(hours) or 0) * 60 + (tonumber(mins) or 0)
    if totalMins <= 0 then return end

    local cost = math.floor(totalMins * Config.ParkingMeters.pricePerMinute)
    if getCash(src) < cost then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error', description = ("Not enough cash. Need $%d."):format(cost), duration = 3000,
        })
        return
    end

    removeCash(src, cost)
    if meterRecords[key] then
        meterRecords[key].slottedTime = meterRecords[key].slottedTime + totalMins
    else
        meterRecords[key] = { timeStart = os.time(), slottedTime = totalMins }
    end

    local displayHrs  = math.floor(totalMins / 60)
    local displayMins = totalMins % 60
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        description = ('Paid $%d for %dh %dm.'):format(cost, displayHrs, displayMins),
        duration    = 4000,
    })
end)

RegisterNetEvent('um_worldint:server:checkMeter', function(key)
    local src   = source
    local isPaid = meterRecords[key] ~= nil
    TriggerClientEvent('um_worldint:client:doMeterCheck', src, isPaid)
end)

RegisterNetEvent('um_worldint:server:robMeter', function(key, coords)
    local src = source
    if type(key) ~= 'string' then return end

    -- Already being robbed?
    if robbedMeters[key] then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = "This meter was recently robbed.", duration = 3000 })
        return
    end

    -- Prevent double-trigger
    if robInProgress[src] then return end
    robInProgress[src] = true

    -- Check lockpick
    local required = Config.ParkingMeters.robbery.requiredItem
    if required and required ~= '' and getItemCount(src, required) < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error', description = ('You need a %s.'):format(required), duration = 3000,
        })
        robInProgress[src] = nil
        return
    end

    -- Remove lockpick on use
    if required and required ~= '' then removeItem(src, required, 1) end

    -- Alert police
    TriggerClientEvent('um_worldint:client:meterAlert', -1, coords)

    -- Tell client to play animation (client fires back meterRobComplete when done)
    TriggerClientEvent('um_worldint:client:doMeterRob', src)
    robbedMeters[key] = os.time()
end)

-- Distribute a cent amount into realistic coin denominations
local coinDenoms = {
    { item = 'quarter', value = 25 },
    { item = 'dime',    value = 10 },
    { item = 'nickel',  value =  5 },
    { item = 'penny',   value =  1 },
}

local function giveCoins(src, totalCents)
    local remaining = totalCents
    for _, denom in ipairs(coinDenoms) do
        if remaining >= denom.value then
            local maxCount = math.floor(remaining / denom.value)
            -- Randomise — use between 0 and max of this denomination
            local count = math.random(0, maxCount)
            if denom.item == 'penny' then
                count = remaining  -- dump the remainder into pennies
            end
            if count > 0 then
                addItem(src, denom.item, count)
                remaining = remaining - (count * denom.value)
            end
        end
    end
end

RegisterNetEvent('um_worldint:server:meterRobComplete', function()
    local src  = source
    local rob  = Config.ParkingMeters.robbery
    local cents = math.random(rob.payoutMinCents or 100, rob.payoutMaxCents or 500)
    giveCoins(src, cents)

    local dollars  = math.floor(cents / 100)
    local leftover = cents % 100
    TriggerClientEvent('ox_lib:notify', src, {
        type        = 'success',
        description = ('Meter cracked — $%d.%02d in coins spills out.'):format(dollars, leftover),
        duration    = 4000,
    })
    robInProgress[src] = nil
end)

AddEventHandler('playerDropped', function()
    robInProgress[source] = nil
end)

-- ============================================================================
-- Cash in coins — triggered by using any coin item from inventory
-- Totals all coin types, converts complete dollars to cash, keeps the leftover
-- ============================================================================

RegisterNetEvent('um_worldint:server:cashInChange', function()
    local src = source

    -- Count every coin type
    local totalCents = 0
    local counts = {}
    for _, denom in ipairs(coinDenoms) do
        local n = getItemCount(src, denom.item)
        counts[denom.item] = n
        totalCents = totalCents + (n * denom.value)
    end

    if totalCents < 100 then
        local dollars  = math.floor(totalCents / 100)
        local leftover = totalCents % 100
        TriggerClientEvent('ox_lib:notify', src, {
            type        = 'error',
            description = ('Not enough — you have $%d.%02d. Need at least $1.00 to cash in.'):format(dollars, leftover),
            duration    = 3500,
        })
        return
    end

    local dollars       = math.floor(totalCents / 100)
    local remainCents   = totalCents % 100

    -- Remove all coins
    for _, denom in ipairs(coinDenoms) do
        if counts[denom.item] > 0 then
            removeItem(src, denom.item, counts[denom.item])
        end
    end

    -- Give back the leftover as coins (largest denominations first)
    local rem = remainCents
    for _, denom in ipairs(coinDenoms) do
        if rem >= denom.value then
            local n = math.floor(rem / denom.value)
            if n > 0 then
                addItem(src, denom.item, n)
                rem = rem - (n * denom.value)
            end
        end
    end

    -- Pay out complete dollars
    addCash(src, dollars)

    local msg = ('Cashed in — got $%d.'):format(dollars)
    if remainCents > 0 then
        msg = msg .. (' Kept $0.%02d in change.'):format(remainCents)
    end
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = msg, duration = 4000 })
end)
