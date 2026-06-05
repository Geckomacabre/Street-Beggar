-- ============================================================================
-- client/scavenging.lua
-- Merged dumpster-diving + camp scavenging.
-- Prop targets (dumpsters, tents) and fixed locations use an outcome-based
-- roll (nothing / items / food / bottles / cash / hostile hobo).
-- The 'items' outcome delegates to the server for skill-based loot.
-- ============================================================================

local locationCooldowns  = {}   -- [coordKey] = expireMs  (keyed by coords, not netId)
local lastSearchMs       = 0    -- global player cooldown
local scavengeBusy       = false
local activeHobos        = {}   -- [pedHandle] = { spawnedAt }

-- ============================================================================
-- Outcome rolling
-- ============================================================================

local function getAreaType()
    local coords   = GetEntityCoords(PlayerPedId())
    local zoneName = GetNameOfZone(coords.x, coords.y, coords.z)
    return Config.ZoneAreas[zoneName] or 'normal'
end

local function rollDumpsterOutcome()
    local cfg     = Config.DumpsterDiving
    local mods    = cfg.areaModifiers[getAreaType()] or {}
    local weights = {}
    local total   = 0
    for k, base in pairs(cfg.outcomes) do
        weights[k] = math.max(0, base + (mods[k] or 0))
        total       = total + weights[k]
    end
    if total <= 0 then return 'nothing' end
    local roll  = math.random(total)
    local accum = 0
    for k, w in pairs(weights) do
        accum = accum + w
        if roll <= accum then return k end
    end
    return 'nothing'
end

-- ============================================================================
-- Hostile hobo encounter
-- ============================================================================

local function spawnHostileHobo(dumpCoords)
    local cfg   = Config.HostileHobo
    local model = cfg.pedModels[math.random(#cfg.pedModels)]
    local hash  = GetHashKey(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 2500
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(20) end
    if not HasModelLoaded(hash) then return end

    local angle    = math.rad(math.random(360))
    local spawnPos = vector3(
        dumpCoords.x + math.cos(angle) * 2.0,
        dumpCoords.y + math.sin(angle) * 2.0,
        dumpCoords.z)

    local hobo = CreatePed(4, hash, spawnPos.x, spawnPos.y, spawnPos.z, math.random(360), true, false)
    SetModelAsNoLongerNeeded(hash)
    if not hobo or not DoesEntityExist(hobo) then return end

    SetEntityAsMissionEntity(hobo, true, true)
    SetPedMaxHealth(hobo, cfg.health)
    SetEntityHealth(hobo, cfg.health)
    SetPedFleeAttributes(hobo, 0, false)
    SetPedCombatAttributes(hobo, 46, true)
    SetPedCombatMovement(hobo, 2)
    SetPedAccuracy(hobo, 20)

    local weapon = cfg.weaponPool[math.random(#cfg.weaponPool)]
    if weapon and weapon ~= 'weapon_unarmed' then
        GiveWeaponToPed(hobo, GetHashKey(weapon), 50, false, true)
    end

    local _, hoboGroup = AddRelationshipGroup('UMHOBOS_HOSTILE_' .. tostring(hobo))
    local plyGroup     = GetPedRelationshipGroupHash(PlayerPedId())
    SetPedRelationshipGroupHash(hobo, hoboGroup)
    SetRelationshipBetweenGroups(5, hoboGroup, plyGroup)
    SetRelationshipBetweenGroups(5, plyGroup, hoboGroup)

    PlayAmbientSpeech1(hobo, cfg.yellSpeeches[math.random(#cfg.yellSpeeches)], 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
    TaskCombatPed(hobo, PlayerPedId(), 0, 16)
    SetPedKeepTask(hobo, true)

    activeHobos[hobo] = { spawnedAt = GetGameTimer() }
    lib.notify({ type = 'error', description = '"Get away from my stuff!"', duration = 3000 })
end

-- Periodic cleanup of despawned / dead hobos
CreateThread(function()
    while true do
        Wait(10000)
        for hobo, data in pairs(activeHobos) do
            if not DoesEntityExist(hobo) then
                activeHobos[hobo] = nil
            elseif IsEntityDead(hobo) or (GetGameTimer() - data.spawnedAt) > Config.HostileHobo.despawnAfterMs then
                if DoesEntityExist(hobo) then
                    SetEntityAsMissionEntity(hobo, true, true)
                    DeleteEntity(hobo)
                end
                activeHobos[hobo] = nil
            end
        end
    end
end)

-- ============================================================================
-- Core scavenge action — shared by prop-targeting and fixed locations
-- ============================================================================

local function doScavenge(locationKey, entityCoords, isDumpster)
    if scavengeBusy then return end

    local now = GetGameTimer()
    -- Global player cooldown (short — prevents button-mashing)
    if (now - lastSearchMs) < Config.DumpsterDiving.playerCooldownMs then
        lib.notify({ type = 'error', description = 'Slow down.', duration = 2000 })
        return
    end
    -- Per-location cooldown
    if locationCooldowns[locationKey] and now < locationCooldowns[locationKey] then
        lib.notify({ type = 'error', description = Lang.scavenge_cooldown, duration = 3000 })
        return
    end

    -- Job check only for fixed scavenge locations; dumpsters/tents open to all
    local requireJob = not isDumpster
    if requireJob and not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    scavengeBusy = true
    lastSearchMs = now

    local cdMultiplier = 1.0
    if isOnHoboJob() then
        cdMultiplier = GetScavengeCooldownMultiplier(GetSkill('scavenging'))
    end
    local cdMs = math.floor(Config.ScavengeCooldownMs * cdMultiplier)

    local done = lib.progressBar({
        duration     = Config.ScavengeProgressMs,
        label        = isDumpster and 'Searching...' or Lang.scavenge_start,
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, combat = true, car = true },
        anim         = { dict = isDumpster and 'amb@prop_human_bum_bin@base' or 'pickup_object',
                         clip = isDumpster and 'base' or 'pickup_low', flag = 49 },
    })

    scavengeBusy = false

    if not done then return end

    locationCooldowns[locationKey] = GetGameTimer() + cdMs

    -- Roll outcome for dumpsters/tents
    if isDumpster then
        local outcome = rollDumpsterOutcome()
        if outcome == 'nothing' then
            lib.notify({ type = 'inform', description = 'Nothing useful in there.', duration = 3000 })

        elseif outcome == 'items' then
            -- Server rolls from LootTables.dumpster
            TriggerServerEvent('um_hobos:dumpsterItemRoll')

        elseif outcome == 'food' then
            TriggerServerEvent('um_hobos:dumpsterFoodFound')

        elseif outcome == 'bottles' then
            local count = math.random(1, 3)
            TriggerServerEvent('um_hobos:dumpsterBottlesFound', count)

        elseif outcome == 'cash' then
            local cfg = Config.DumpsterDiving
            local amt = math.random(cfg.cashMin, cfg.cashMax)
            TriggerServerEvent('um_hobos:dumpsterCashFound', amt)

        elseif outcome == 'hobo' then
            if entityCoords then spawnHostileHobo(entityCoords) end
        end

        -- XP / skill only if on duty
        if isOnHoboJob() then
            GainXP(Config.XPRewards.scavenge, 'scavenge')
            GainSkillXP('scavenge')
        end
        if Config.NeedsEnabled then TriggerEvent('um_hobos:moraleBump', 3) end

    else
        -- Skill-based item roll for fixed locations (existing behaviour)
        TriggerServerEvent('um_hobos:scavengeRoll', GetSkill('scavenging'))
        GainXP(Config.XPRewards.scavenge, 'scavenge')
        GainSkillXP('scavenge')
        if Config.NeedsEnabled then TriggerEvent('um_hobos:moraleBump', 5) end
    end
end

-- ============================================================================
-- ox_target on dumpster / tent prop models
-- ============================================================================

CreateThread(function()
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addModel(Config.ScavengeProps, {
        {
            name     = 'um_hobos_scavenge_search',
            label    = 'Search',
            icon     = 'fas fa-search',
            distance = 2.0,
            onSelect = function(data)
                local ent  = data.entity
                local c    = GetEntityCoords(ent)
                -- Key by coords — world props aren't networked so netId is always 0
                local key  = ('dump_%d_%d_%d'):format(math.ceil(c.x), math.ceil(c.y), math.ceil(c.z))
                local now  = GetGameTimer()
                if locationCooldowns[key] and now < locationCooldowns[key] then
                    lib.notify({ type = 'inform', description = 'Already searched this recently.', duration = 2500 })
                    return
                end
                doScavenge(key, c, true)
            end,
        }
    })
end)

-- ============================================================================
-- Fixed scavenge location zones  (lib.zones.sphere, job-gated)
-- ============================================================================

CreateThread(function()
    Wait(2000)

    for i, loc in ipairs(Config.ScavengeLocations) do
        local key = 'loc_' .. i

        if Config.ShowScavengeBlips then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip,  Config.ScavengeBlip.sprite)
            SetBlipColour(blip,  Config.ScavengeBlip.color)
            SetBlipScale(blip,   Config.ScavengeBlip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(loc.label or Config.ScavengeBlip.label)
            EndTextCommandSetBlipName(blip)
        end

        lib.zones.sphere({
            coords  = loc.coords,
            radius  = loc.radius or 2.0,
            debug   = false,
            onEnter = function()
                if not isOnHoboJob() then return end
                lib.showTextUI('[E] ' .. (loc.label or 'Scavenge'))
            end,
            onExit  = function() lib.hideTextUI() end,
            inside  = function()
                if not isOnHoboJob() then return end
                if not IsControlJustPressed(0, 38) then return end
                lib.hideTextUI()
                doScavenge(key, loc.coords, false)
            end,
        })
    end
end)

-- ============================================================================
-- Server callbacks
-- ============================================================================

RegisterNetEvent('um_hobos:client:scavengeResult', function(item, count, isRare)
    if not item then
        lib.notify({ type = 'inform', description = Lang.scavenge_empty, duration = 3000 })
        return
    end
    lib.notify({
        type        = isRare and 'success' or 'inform',
        description = string.format('%s — found %dx %s', Lang.scavenge_found, count, item),
        duration    = 4000,
    })
    if isRare then GainXP(Config.XPRewards.scavenge_rare, 'scavenge_rare') end
end)

RegisterNetEvent('um_hobos:client:dumpsterResult', function(item, count)
    if not item then
        lib.notify({ type = 'inform', description = 'Nothing useful in there.', duration = 3000 })
        return
    end
    lib.notify({
        type        = 'inform',
        description = ('Found %dx %s.'):format(count, item),
        duration    = 3500,
    })
end)

RegisterNetEvent('um_hobos:client:dumpsterCash', function(amount)
    lib.notify({
        type        = 'success',
        description = ('Someone dropped $%d in the trash!'):format(amount),
        duration    = 3500,
    })
end)

RegisterNetEvent('um_hobos:client:dumpsterFood', function(item)
    lib.notify({
        type        = 'inform',
        description = ('Found some food: %s.'):format(item),
        duration    = 3000,
    })
end)

RegisterNetEvent('um_hobos:client:dumpsterBottles', function(count)
    lib.notify({
        type        = 'inform',
        description = ('Collected %d bottle(s)/can(s).'):format(count),
        duration    = 3000,
    })
end)

-- ============================================================================
-- Cleanup on resource stop
-- ============================================================================

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for hobo in pairs(activeHobos) do
        if DoesEntityExist(hobo) then
            SetEntityAsMissionEntity(hobo, true, true)
            DeleteEntity(hobo)
        end
    end
end)
