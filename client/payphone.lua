-- ============================================================================
-- client/payphone.lua
-- Search payphones for loose change — $1–$5 with a 40% find chance.
-- Uses ox_target addModel on all 7 confirmed phonebox variants.
-- Per-entity cooldown so the same box can't be hit repeatedly.
-- ============================================================================

local phoneCooldowns = {}   -- [entity handle] = expireMs

-- ============================================================================
-- Search action
-- ============================================================================

local function searchPayphone(entity)
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    local now = GetGameTimer()
    if phoneCooldowns[entity] and now < phoneCooldowns[entity] then
        local remaining = math.ceil((phoneCooldowns[entity] - now) / 60000)
        lib.notify({
            type        = 'error',
            description = ('You already checked this one. Try again in ~%d min.'):format(remaining),
            duration    = 3000,
        })
        return
    end

    -- Rummage animation via progress bar
    local done = lib.progressBar({
        duration  = 2500,
        label     = 'Digging around the coin return...',
        canCancel = false,
        disable   = { move = true, car = true, combat = true },
        anim      = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop', flag = 49 },
    })

    if not done then return end

    phoneCooldowns[entity] = now + Config.Payphone.cooldownMs

    if math.random(100) > Config.Payphone.findChance then
        lib.notify({ type = 'inform', description = 'Nothing. Just gum wrappers.', duration = 3000 })
        return
    end

    local count = math.random(Config.Payphone.coinMin, Config.Payphone.coinMax)
    TriggerServerEvent('um_beg:payphoneCoins', count)
    GainXP(Config.Payphone.xpReward, 'payphone')
end

-- ============================================================================
-- ox_target — addModel on all phonebox variants
-- canInteract omitted (runs in ox_target Lua state — check done in onSelect)
-- ============================================================================

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(1000) end

    exports.ox_target:addModel(Config.Payphone.models, {
        {
            name     = 'um_hobos_payphone',
            label    = 'Search Payphone',
            icon     = 'fas fa-phone',
            distance = 1.5,
            onSelect = function(data)
                CreateThread(function()
                    searchPayphone(data.entity)
                end)
            end,
        }
    })
end)
