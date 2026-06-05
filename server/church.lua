-- ============================================================================
-- server/church.lua
-- Church Sister — rotating better-than-board jobs + free meal every 12 hrs.
-- ============================================================================

local churchJobState = {
    pool      = {},
    lastReset = 0,
}
local foodCooldowns  = {}   -- [citizenid] = os.time() of last food
local activeJobs     = {}   -- [src]       = jobId

-- ============================================================================
-- Helpers (reuse ox_inventory pattern from rest of script)
-- ============================================================================

local function getCitizenId(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and player then
        return player.PlayerData and player.PlayerData.citizenid
    end
    return nil
end

local function addItem(src, item, amt)
    pcall(function() exports.ox_inventory:AddItem(src, item, amt) end)
end

local function addCash(src, amt)
    pcall(function() exports.ox_inventory:AddItem(src, Config.OxMoneyItem, amt) end)
end

-- ============================================================================
-- Job pool refresh
-- ============================================================================

local function refreshChurchJobs()
    churchJobState.lastReset = os.time()
    local shuffled = {}
    for _, j in ipairs(Config.ChurchSister.jobPool) do
        shuffled[#shuffled + 1] = j
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    churchJobState.pool = {}
    for i = 1, math.min(Config.ChurchSister.maxJobs, #shuffled) do
        churchJobState.pool[#churchJobState.pool + 1] = shuffled[i]
    end
end

refreshChurchJobs()

-- ============================================================================
-- Request jobs + food status
-- ============================================================================

RegisterNetEvent('um_hobos:requestChurchJobs', function()
    local src = source
    local cid = getCitizenId(src)

    -- Refresh if past interval
    if (os.time() - churchJobState.lastReset) > (Config.ChurchSister.refreshMs / 1000) then
        refreshChurchJobs()
    end

    -- Calculate food cooldown remaining (ms, 0 if ready)
    local foodCooldownLeft = 0
    if cid and foodCooldowns[cid] then
        local elapsed  = os.time() - foodCooldowns[cid]
        local cooldownSecs = Config.ChurchSister.foodCooldownMs / 1000
        if elapsed < cooldownSecs then
            foodCooldownLeft = (cooldownSecs - elapsed) * 1000
        end
    end

    TriggerClientEvent('um_hobos:client:churchJobList', src, churchJobState.pool, foodCooldownLeft)
end)

-- ============================================================================
-- Free food
-- ============================================================================

RegisterNetEvent('um_hobos:churchRequestFood', function()
    local src = source
    local cid = getCitizenId(src)
    if not cid then return end

    local cooldownSecs = Config.ChurchSister.foodCooldownMs / 1000
    if foodCooldowns[cid] and (os.time() - foodCooldowns[cid]) < cooldownSecs then
        local remaining = math.ceil(cooldownSecs - (os.time() - foodCooldowns[cid]))
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Come back in %d min.'):format(math.ceil(remaining / 60)),
            duration = 3000,
        })
        return
    end

    local item = Config.ChurchSister.foodItem
    foodCooldowns[cid] = os.time()
    addItem(src, item, 1)
    TriggerClientEvent('um_hobos:client:churchFoodGiven', src, item)
end)

-- ============================================================================
-- Job completion
-- ============================================================================

RegisterNetEvent('um_hobos:completeChurchJob', function(jobId)
    local src = source

    local job = nil
    for _, j in ipairs(churchJobState.pool) do
        if j.id == jobId then job = j; break end
    end
    if not job then
        print(('[um_beg] church job not in pool: %s (ply %d)'):format(tostring(jobId), src))
        return
    end

    addCash(src, job.payout)
    TriggerClientEvent('um_hobos:client:churchJobDone', src, job.label, job.payout, job.xp or 0)
end)

AddEventHandler('playerDropped', function()
    activeJobs[source] = nil
end)
