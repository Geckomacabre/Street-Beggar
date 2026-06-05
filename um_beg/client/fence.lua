-- ============================================================================
-- client/fence.lua
-- Stolen goods fence — shady NPC in a back alley who buys pickpocketed items.
-- Higher charisma = better prices. Risk of police attention after a sale.
-- ============================================================================

local fenceNpc  = nil
local fenceBlip = nil
local lastSale  = 0   -- GetGameTimer()

-- ============================================================================
-- Sell menu
-- ============================================================================

local function openFenceMenu()
    local now = GetGameTimer()
    if (now - lastSale) < Config.Fence.cooldownMs then
        local remaining = math.ceil((Config.Fence.cooldownMs - (now - lastSale)) / 1000)
        lib.notify({ type = 'error', description = ('Lay low for %d more seconds.'):format(remaining), duration = 3000 })
        return
    end

    -- Build list of items the player currently has
    local charisma   = GetSkill and GetSkill('charisma') or 0
    local bonus      = 1.0 + (charisma * Config.Fence.charismaBonus)
    local options    = {}
    local hasAnything = false

    for _, entry in ipairs(Config.Fence.items) do
        local count = 0
        if Config.UseOxInventory then
            local ok, c = pcall(function()
                return exports.ox_inventory:Search('count', entry.item)
            end)
            count = (ok and c) or 0
        end

        if count > 0 then
            hasAnything = true
            local price = math.floor(entry.price * bonus)
            options[#options + 1] = {
                title       = entry.label,
                description = ('In pocket: %d  |  Fence pays: $%d each'):format(count, price),
                onSelect    = function()
                    TriggerServerEvent('um_hobos:fenceSell', entry.item, count)
                    lastSale = GetGameTimer()
                end,
            }
        end
    end

    if not hasAnything then
        lib.notify({ type = 'error', description = "You don't have anything worth fencing.", duration = 3000 })
        return
    end

    lib.registerContext({
        id      = 'um_fence_menu',
        title   = '"What you got for me?"',
        options = options,
    })
    lib.showContext('um_fence_menu')
end

-- ============================================================================
-- Spawn / despawn NPC
-- ============================================================================

local function spawnFence()
    local cfg  = Config.Fence
    local hash = GetHashKey(cfg.pedModel)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then
        print('[um_hobos] fence: model ' .. cfg.pedModel .. ' failed to load')
        return
    end

    fenceNpc = CreatePed(4, hash, cfg.location.x, cfg.location.y, cfg.location.z, cfg.heading, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not fenceNpc or fenceNpc == 0 or not DoesEntityExist(fenceNpc) then
        print('[um_hobos] fence: CreatePed returned invalid entity')
        fenceNpc = nil
        return
    end

    SetEntityAsMissionEntity(fenceNpc, true, true)
    SetBlockingOfNonTemporaryEvents(fenceNpc, true)
    SetPedFleeAttributes(fenceNpc, 0, false)
    SetPedCombatAttributes(fenceNpc, 46, true)

    -- Give the ped a moment to fully exist before assigning a scenario/target
    Wait(500)

    if not DoesEntityExist(fenceNpc) then return end
    local anim = cfg.animation
    if type(anim) == 'table' then
        RequestAnimDict(anim.dict)
        local deadline = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do Wait(10) end
        TaskPlayAnim(fenceNpc, anim.dict, anim.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
    else
        TaskStartScenarioInPlace(fenceNpc, anim or 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end

    Wait(100)

    exports.ox_target:addLocalEntity(fenceNpc, {
        {
            name     = 'um_hobos_fence',
            label    = 'Sell Stolen Goods',
            icon     = 'fas fa-box-open',
            distance = 2.5,
            onSelect = function()
                CreateThread(function() openFenceMenu() end)
            end,
        }
    })

    -- Nearby blip (only shows when close)
    fenceBlip = AddBlipForCoord(cfg.location.x, cfg.location.y, cfg.location.z)
    SetBlipSprite(fenceBlip, 110)
    SetBlipColour(fenceBlip, 1)   -- red
    SetBlipScale(fenceBlip, 0.7)
    SetBlipAsShortRange(fenceBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Shady Dealer')
    EndTextCommandSetBlipName(fenceBlip)
end

local function despawnFence()
    if fenceNpc and DoesEntityExist(fenceNpc) then
        exports.ox_target:removeLocalEntity(fenceNpc)
        SetEntityAsMissionEntity(fenceNpc, true, true)
        DeleteEntity(fenceNpc)
        fenceNpc = nil
    end
    if fenceBlip and DoesBlipExist(fenceBlip) then
        RemoveBlip(fenceBlip)
        fenceBlip = nil
    end
end

-- ============================================================================
-- Server callbacks
-- ============================================================================

RegisterNetEvent('um_hobos:client:fenceSold')
AddEventHandler('um_hobos:client:fenceSold', function(itemLabel, count, total, busted)
    lib.notify({
        type        = 'success',
        description = ('Sold %dx %s for $%d.'):format(count, itemLabel, total),
        duration    = 4000,
    })
    if busted then
        Citizen.SetTimeout(2500, function()
            SetPlayerWantedLevel(PlayerId(), Config.Fence.wantedLevel, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
            lib.notify({ type = 'error', description = 'Someone tipped off the cops!', duration = 5000 })
        end)
    end
end)

RegisterNetEvent('um_hobos:client:fenceDenied')
AddEventHandler('um_hobos:client:fenceDenied', function(reason)
    lib.notify({ type = 'error', description = reason or 'Deal fell through.', duration = 3000 })
end)

AddEventHandler('um_hobos:onDuty', function()
    Wait(3000)  -- give ox_target and the game time to settle before spawning
    spawnFence()
end)
AddEventHandler('um_hobos:offDuty', despawnFence)
