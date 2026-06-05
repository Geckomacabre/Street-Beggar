-- ============================================================================
-- client/washing.lua
-- Windshield washing — ox_target option on all stopped vehicles.
-- No commands or [E] prompts; just aim at a stopped car and select.
-- ============================================================================

local washBusy     = false
local carCooldowns = {}   -- [driver entity] = expireMs

-- ============================================================================
-- Core wash action (called from ox_target onSelect)
-- ============================================================================

local function doWash(veh, driver)
    if washBusy then return end
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    local now = GetGameTimer()
    local cd  = carCooldowns[driver]
    if cd and now < cd then
        lib.notify({ type = 'error', description = "You already washed this one recently.", duration = 3000 })
        return
    end

    if GetEntitySpeed(veh) > Config.MaxVehicleSpeedToTarget then
        lib.notify({ type = 'error', description = "The car needs to be stopped first.", duration = 3000 })
        return
    end

    washBusy = true
    local cfg  = Config.Washing
    local roll = math.random(100)

    if roll <= cfg.refuseChance then
        PlayAmbientSpeech1(driver, 'GENERIC_CURSE_MED', 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
        lib.notify({ type = 'error', description = 'They waved you off.', duration = 3000 })
        carCooldowns[driver] = now + 30000

    elseif roll <= (cfg.refuseChance + cfg.yellChance) then
        StartVehicleHorn(veh, 900, GetHashKey('NORMAL'), false)
        PlayAmbientSpeech1(driver, 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
        lib.notify({ type = 'error', description = '"Get away from my car!"', duration = 3000 })
        carCooldowns[driver] = now + cfg.carCooldownMs

    else
        -- Attach sponge prop before the progress bar starts
        local washProp = nil
        local propHash = GetHashKey(cfg.animProp)
        RequestModel(propHash)
        local propDeadline = GetGameTimer() + 2000
        while not HasModelLoaded(propHash) and GetGameTimer() < propDeadline do Wait(15) end
        if HasModelLoaded(propHash) then
            local ped = PlayerPedId()
            washProp = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, false)
            AttachEntityToEntity(
                washProp, ped, GetPedBoneIndex(ped, cfg.animPropBone),
                cfg.animPropOffset.x, cfg.animPropOffset.y, cfg.animPropOffset.z,
                cfg.animPropRot.x,    cfg.animPropRot.y,    cfg.animPropRot.z,
                true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(propHash)
        end

        local done = lib.progressBar({
            duration  = cfg.durationMs,
            label     = 'Washing windshield...',
            canCancel = false,
            disable   = { move = true, car = true, combat = true },
            anim      = { dict = cfg.animDict, clip = cfg.animClip, flag = 49 },
        })

        -- Always remove prop whether done or cancelled
        if washProp and DoesEntityExist(washProp) then
            DetachEntity(washProp, false, false)
            DeleteObject(washProp)
        end

        if done then
            local generous = math.random(100) <= cfg.generousChance
            local amount   = generous
                and math.random(cfg.generousMin, cfg.generousMax)
                or  math.random(cfg.payoutMin,   cfg.payoutMax)

            PlayAmbientSpeech1(driver, 'GENERIC_THANKS', 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
            TriggerServerEvent('um_hobos:washReward', amount)

            lib.notify({
                type        = 'success',
                description = generous
                    and ('They tipped you! $%d total.'):format(amount)
                    or  ('$%d for a clean windshield.'):format(amount),
                duration    = 4000,
            })
            GainXP(cfg.xpReward, 'wash')
            carCooldowns[driver] = now + cfg.carCooldownMs
        end
    end

    washBusy = false
end

-- ============================================================================
-- ox_target — "Wash Windshield" on occupied vehicles (NPC-driven)
-- Player-driven occupied cars are skipped to avoid griefing.
-- Empty cars only allowed via /carwashaccept flow (see below).
-- ============================================================================

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(1000) end

    exports.ox_target:addGlobalVehicle({
        {
            name     = 'um_hobos_wash',
            label    = 'Wash Windshield',
            icon     = 'fas fa-car-side',
            distance = 3.0,
            canInteract = function(entity)
                if not isOnHoboJob() then return false end
                local driver = GetPedInVehicleSeat(entity, -1)
                -- Only show on NPC-driven cars via the normal target
                return driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver)
            end,
            onSelect = function(data)
                local veh    = data.entity
                if not veh or not DoesEntityExist(veh) then return end
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver == 0 or not DoesEntityExist(driver) then return end
                if IsPedAPlayer(driver) then return end
                CreateThread(function() doWash(veh, driver) end)
            end,
        }
    })
end)

-- ============================================================================
-- Cooperative car wash — /offercarwash and /carwashaccept
-- ============================================================================

local coopOffer    = false      -- true while this player is offering washes
local coopVehicle  = nil        -- vehicle net ID authorised by an accepting owner

-- Wash an empty parked car in coop mode
local function doCoopWash(veh, ownerServerId)
    if washBusy then return end
    if not coopOffer then return end

    washBusy = true
    local cfg = Config.Washing

    -- Attach sponge prop
    local washProp  = nil
    local propHash  = GetHashKey(cfg.animProp)
    RequestModel(propHash)
    local propDeadline = GetGameTimer() + 2000
    while not HasModelLoaded(propHash) and GetGameTimer() < propDeadline do Wait(15) end
    if HasModelLoaded(propHash) then
        local ped = PlayerPedId()
        washProp = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(
            washProp, ped, GetPedBoneIndex(ped, cfg.animPropBone),
            cfg.animPropOffset.x, cfg.animPropOffset.y, cfg.animPropOffset.z,
            cfg.animPropRot.x,    cfg.animPropRot.y,    cfg.animPropRot.z,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(propHash)
    end

    local done = lib.progressBar({
        duration  = Config.CoopWash.durationMs,
        label     = 'Washing car...',
        canCancel = false,
        disable   = { move = true, car = true, combat = true },
        anim      = { dict = cfg.animDict, clip = cfg.animClip, flag = 49 },
    })

    if washProp and DoesEntityExist(washProp) then
        DetachEntity(washProp, false, false)
        DeleteObject(washProp)
    end

    if done then
        local amount = math.random(Config.CoopWash.payoutMin, Config.CoopWash.payoutMax)
        TriggerServerEvent('um_hobos:coopWashComplete', ownerServerId, amount)
        GainXP(cfg.xpReward, 'wash')
        coopVehicle = nil
        -- Remove the target we added
        exports.ox_target:removeLocalEntity(veh)
        lib.notify({
            type        = 'success',
            description = ('Car washed! $%d earned.'):format(amount),
            duration    = 4000,
        })
    end

    washBusy = false
end

RegisterCommand('offercarwash', function()
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end
    coopOffer = not coopOffer
    if coopOffer then
        TriggerServerEvent('um_hobos:offerWash')
        lib.notify({ type = 'inform', description = 'Offering car washes. Nearby players can type /carwashaccept.', duration = 5000 })
    else
        TriggerServerEvent('um_hobos:cancelWashOffer')
        coopVehicle = nil
        lib.notify({ type = 'inform', description = 'No longer offering car washes.', duration = 3000 })
    end
end, false)

RegisterCommand('carwashaccept', function()
    -- Owner: find nearest empty vehicle and send its net ID to server
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local maxRange = Config.CoopWash.vehicleRadius
    local nearest, nearestDist = nil, maxRange

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver == 0 or not DoesEntityExist(driver) then
                local dist = #(GetEntityCoords(veh) - coords)
                if dist < nearestDist then
                    nearestDist = dist
                    nearest     = veh
                end
            end
        end
    end

    if not nearest then
        lib.notify({ type = 'error', description = 'No empty vehicle nearby (within ' .. maxRange .. 'm).', duration = 3000 })
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(nearest)
    TriggerServerEvent('um_hobos:acceptWash', netId)
    lib.notify({ type = 'inform', description = 'Wash requested — a washer will come to your car.', duration = 4000 })
end, false)

-- Server tells washer which vehicle is approved
RegisterNetEvent('um_hobos:client:washApproved')
AddEventHandler('um_hobos:client:washApproved', function(vehicleNetId, ownerServerId)
    if not coopOffer then return end
    coopVehicle = vehicleNetId

    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not veh or not DoesEntityExist(veh) then
        lib.notify({ type = 'error', description = 'Could not find the vehicle.', duration = 3000 })
        return
    end

    -- Add a one-shot target on this specific vehicle
    exports.ox_target:addLocalEntity(veh, {
        {
            name     = 'um_coop_wash',
            label    = 'Wash This Car',
            icon     = 'fas fa-car-side',
            distance = 3.5,
            onSelect = function()
                CreateThread(function() doCoopWash(veh, ownerServerId) end)
            end,
        }
    })

    -- Waypoint to the vehicle
    SetNewWaypoint(GetEntityCoords(veh).x, GetEntityCoords(veh).y)
    lib.notify({ type = 'success', description = 'Car accepted! Head to the waypoint.', duration = 5000 })
end)

-- Owner notification after wash
RegisterNetEvent('um_hobos:client:coopWashDone')
AddEventHandler('um_hobos:client:coopWashDone', function(amount)
    lib.notify({
        type        = 'inform',
        description = ('Your car was washed! $%d deducted.'):format(amount),
        duration    = 4000,
    })
end)
