-- ============================================================================
-- client/church.lua
-- Church Sister NPC — slightly better rotating jobs + 1 free meal every 12 hrs.
-- Available to all players (not job-locked).
-- ============================================================================

local sisterPed   = nil
local sisterBlip  = nil
local activeJob   = nil
local jobWaypoint = nil
local trashProps  = {}
local trashCount  = 0
local packageProp = nil
local packagePicked = false

-- ============================================================================
-- Waypoint helpers
-- ============================================================================

local function setWaypoint(coords)
    SetNewWaypoint(coords.x, coords.y)
    jobWaypoint = coords
end

local function clearWaypoint()
    RemoveWaypoint()
    jobWaypoint = nil
end

-- ============================================================================
-- Job cleanup / completion (mirrors oddjobs.lua pattern)
-- ============================================================================

local function cleanupJob()
    for _, e in ipairs(trashProps) do
        if DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteObject(e)
        end
    end
    trashProps    = {}
    trashCount    = 0
    if packageProp and DoesEntityExist(packageProp) then
        SetEntityAsMissionEntity(packageProp, true, true)
        DeleteObject(packageProp)
    end
    packageProp    = nil
    packagePicked  = false
    clearWaypoint()
    activeJob = nil
end

local function failJob(reason)
    lib.notify({ type = 'error', description = reason or 'Job failed.', duration = 4000 })
    cleanupJob()
end

local function completeJob()
    if not activeJob then return end
    local job = activeJob
    cleanupJob()
    lib.progressBar({
        duration  = 2000,
        label     = 'Finishing up...',
        canCancel = false,
        disable   = { move = true, combat = true },
        anim      = { dict = 'random@domestic', clip = 'pickup_low', flag = 49 },
    })
    TriggerServerEvent('um_hobos:completeChurchJob', job.id)
end

-- ============================================================================
-- Collect-type: spawn trash in zone
-- ============================================================================

local function spawnChurchTrash(job)
    trashProps = {}
    trashCount = 0
    local center = job.zone
    local r      = (job.zoneRadius or 15.0) * 0.8
    for i = 1, job.count do
        local angle = math.rad((360 / job.count) * i + math.random(-20, 20))
        local dist  = math.random(3, math.floor(r))
        local tx    = center.x + math.cos(angle) * dist
        local ty    = center.y + math.sin(angle) * dist
        local _, tz = GetGroundZFor_3dCoord(tx, ty, center.z + 5.0, false)
        tz = tz or center.z
        local hash = GetHashKey('prop_rub_binbag_01')
        RequestModel(hash)
        local deadline = GetGameTimer() + 2000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
        if HasModelLoaded(hash) then
            local prop = CreateObject(hash, tx, ty, tz, false, false, false)
            PlaceObjectOnGroundProperly(prop)
            SetEntityAsMissionEntity(prop, true, true)
            SetModelAsNoLongerNeeded(hash)
            trashProps[#trashProps + 1] = prop
        end
    end
    setWaypoint(center)
    lib.notify({ type = 'inform', description = ('Collect %d piles near the church.'):format(job.count), duration = 5000 })
end

-- ============================================================================
-- Delivery-type: spawn package
-- ============================================================================

local function spawnChurchPackage(job)
    packagePicked = false
    local hash    = GetHashKey('prop_paper_bag_01a')
    RequestModel(hash)
    local deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if HasModelLoaded(hash) then
        packageProp = CreateObject(hash, job.pickup.x, job.pickup.y, job.pickup.z, false, false, false)
        PlaceObjectOnGroundProperly(packageProp)
        FreezeEntityPosition(packageProp, true)
        SetEntityAsMissionEntity(packageProp, true, true)
        SetModelAsNoLongerNeeded(hash)
    end
    setWaypoint(job.pickup)
    lib.notify({ type = 'inform', description = 'Pick up the parcel from the marked spot.', duration = 5000 })
end

-- ============================================================================
-- Start a church job
-- ============================================================================

local function startChurchJob(job)
    if activeJob then
        lib.notify({ type = 'error', description = 'Finish your current job first.', duration = 3000 })
        return
    end
    activeJob = job
    if job.type == 'collect'  then spawnChurchTrash(job)   end
    if job.type == 'delivery' then spawnChurchPackage(job)  end

    local deadline = GetGameTimer() + job.timeMs
    CreateThread(function()
        while activeJob and activeJob.id == job.id do
            if GetGameTimer() > deadline then
                failJob('You ran out of time.')
                return
            end
            Wait(5000)
        end
    end)
end

-- ============================================================================
-- Job board menu
-- ============================================================================

RegisterNetEvent('um_hobos:client:churchJobList')
AddEventHandler('um_hobos:client:churchJobList', function(jobs, foodCooldownLeft)
    local options = {}

    -- Food option at the top
    local foodReady = foodCooldownLeft <= 0
    options[#options + 1] = {
        title       = 'Ask for a Meal',
        description = foodReady
            and 'Sister Agnes will give you something to eat.'
            or  ('Come back in %d min.'):format(math.ceil(foodCooldownLeft / 60000)),
        icon        = 'fas fa-bowl-food',
        disabled    = not foodReady,
        onSelect    = function()
            TriggerServerEvent('um_hobos:churchRequestFood')
        end,
    }

    -- Job listings
    for _, job in ipairs(jobs) do
        options[#options + 1] = {
            title       = job.label,
            description = ('%s\nPayout: $%d'):format(job.description, job.payout),
            onSelect    = function()
                lib.alertDialog({
                    header   = job.label,
                    content  = ('%s\n\n**Payout:** $%d | **Time:** %d min'):format(
                        job.description, job.payout, math.floor(job.timeMs / 60000)),
                    centered = true,
                    cancel   = true,
                    labels   = { confirm = 'Accept', cancel = 'No thanks' },
                }, function(confirmed)
                    if confirmed == 'confirm' then startChurchJob(job) end
                end)
            end,
        }
    end

    if activeJob then
        options[#options + 1] = {
            title       = '~r~Abandon Current Job',
            description = ('Active: %s'):format(activeJob.label),
            onSelect    = function() failJob('You walked away from the job.') end,
        }
    end

    lib.registerContext({ id = 'um_church_menu', title = 'Sister Agnes', options = options })
    lib.showContext('um_church_menu')
end)

-- ============================================================================
-- Active job proximity thread
-- ============================================================================

CreateThread(function()
    while true do
        if activeJob then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local job    = activeJob

            if job.type == 'collect' then
                for i = #trashProps, 1, -1 do
                    local prop = trashProps[i]
                    if DoesEntityExist(prop) then
                        if #(GetEntityCoords(prop) - coords) <= 2.5 then
                            SetEntityAsMissionEntity(prop, true, true)
                            DeleteObject(prop)
                            table.remove(trashProps, i)
                            trashCount = trashCount + 1
                            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                            lib.notify({ type = 'inform', description = ('%d / %d collected.'):format(trashCount, job.count), duration = 2000 })
                        end
                    else
                        table.remove(trashProps, i)
                    end
                end
                if trashCount >= job.count then completeJob() end

            elseif job.type == 'delivery' then
                if not packagePicked then
                    if packageProp and DoesEntityExist(packageProp) then
                        if #(GetEntityCoords(packageProp) - coords) <= 2.5 then
                            AttachEntityToEntity(packageProp, ped, GetPedBoneIndex(ped, 28422),
                                0.12, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                            FreezeEntityPosition(packageProp, false)
                            packagePicked = true
                            setWaypoint(job.dropoff)
                            lib.notify({ type = 'success', description = 'Parcel picked up. Deliver it.', duration = 4000 })
                        end
                    end
                else
                    if #(job.dropoff - coords) <= 3.0 then completeJob() end
                end
            end
            Wait(200)
        else
            Wait(1000)
        end
    end
end)

-- ============================================================================
-- Server result events
-- ============================================================================

RegisterNetEvent('um_hobos:client:churchJobDone')
AddEventHandler('um_hobos:client:churchJobDone', function(label, payout, xp)
    lib.notify({
        type        = 'success',
        description = ('Job done: %s\n+$%d  +%d XP'):format(label, payout, xp),
        duration    = 6000,
    })
    if isOnHoboJob and isOnHoboJob() then GainXP(xp, 'oddjob') end
end)

RegisterNetEvent('um_hobos:client:churchFoodGiven')
AddEventHandler('um_hobos:client:churchFoodGiven', function(item)
    lib.notify({
        type        = 'success',
        description = ('"God bless you, child." — Sister Agnes hands you a %s.'):format(item),
        duration    = 5000,
    })
end)

-- ============================================================================
-- Suppress Agnes' normal menu during onboarding (onboarding.lua takes over)
-- ============================================================================

local _agnesReady = false   -- true once onboarding is resolved

RegisterNetEvent('um_hobos:client:loadProgression')
AddEventHandler('um_hobos:client:loadProgression', function(data)
    _agnesReady = data.onboarding_done == true
end)

RegisterNetEvent('um_hobos:client:onboardingComplete')
AddEventHandler('um_hobos:client:onboardingComplete', function()
    _agnesReady = true
end)

-- ============================================================================
-- Spawn Sister Agnes
-- ============================================================================

CreateThread(function()
    Wait(3000)

    local cfg  = Config.ChurchSister
    local hash = GetHashKey(cfg.pedModel)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then
        print('[um_beg] church sister model failed to load: ' .. cfg.pedModel)
        return
    end

    sisterPed = CreatePed(4, hash, cfg.location.x, cfg.location.y, cfg.location.z, cfg.heading, false, false)
    SetEntityAsMissionEntity(sisterPed, true, true)
    SetPedCanRagdoll(sisterPed, false)
    SetBlockingOfNonTemporaryEvents(sisterPed, true)
    FreezeEntityPosition(sisterPed, true)
    local anim = cfg.animation
    if type(anim) == 'table' then
        RequestAnimDict(anim.dict)
        local deadline = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do Wait(10) end
        TaskPlayAnim(sisterPed, anim.dict, anim.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
    else
        TaskStartScenarioInPlace(sisterPed, anim or 'WORLD_HUMAN_PRAY', 0, true)
    end
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(sisterPed, {
        {
            name     = 'um_church_sister',
            label    = 'Talk to Sister Agnes',
            icon     = 'fas fa-hands-praying',
            distance = 2.5,
            onSelect = function()
                if not _agnesReady then
                    -- Onboarding chain hasn't completed — soft block
                    lib.notify({ type = 'inform', description = 'Sister Agnes smiles and gestures for you to wait a moment.', duration = 3000 })
                    return
                end
                TriggerServerEvent('um_hobos:requestChurchJobs')
            end,
        }
    })

    -- Short-range blip
    sisterBlip = AddBlipForCoord(cfg.location.x, cfg.location.y, cfg.location.z)
    SetBlipSprite(sisterBlip, 311)   -- cross/church sprite
    SetBlipColour(sisterBlip, 3)     -- blue
    SetBlipScale(sisterBlip, 0.8)
    SetBlipAsShortRange(sisterBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Sister Agnes')
    EndTextCommandSetBlipName(sisterBlip)
end)
