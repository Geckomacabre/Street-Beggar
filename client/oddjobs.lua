-- ============================================================================
-- client/oddjobs.lua
-- Odd jobs board — rotating small tasks posted at the hobo camp.
-- Types: 'collect' (pick up trash props) | 'delivery' (A → B)
-- ============================================================================

local boardProp    = nil
local boardBlip    = nil
local activeJob    = nil   -- currently accepted job data
local jobWaypoint  = nil
local trashProps   = {}    -- spawned trash props for collect-type jobs
local trashCount   = 0     -- how many trash piles collected so far
local packageProp  = nil   -- spawned package prop for delivery jobs
local packagePicked = false

-- ============================================================================
-- Waypoint helpers
-- ============================================================================

local function setWaypoint(coords)
    if jobWaypoint then RemoveWaypoint() end
    SetNewWaypoint(coords.x, coords.y)
    jobWaypoint = coords
end

local function clearWaypoint()
    RemoveWaypoint()
    jobWaypoint = nil
end

-- ============================================================================
-- Job cancellation / completion
-- ============================================================================

local function cleanupActiveJob()
    -- Remove trash props
    for _, e in ipairs(trashProps) do
        if DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteObject(e)
        end
    end
    trashProps   = {}
    trashCount   = 0

    -- Remove package prop
    if packageProp and DoesEntityExist(packageProp) then
        SetEntityAsMissionEntity(packageProp, true, true)
        DeleteObject(packageProp)
    end
    packageProp   = nil
    packagePicked = false

    clearWaypoint()
    activeJob = nil
end

local function failJob(reason)
    lib.notify({ type = 'error', description = reason or 'Job failed.', duration = 4000 })
    cleanupActiveJob()
end

local function completeJob()
    if not activeJob then return end
    local job = activeJob
    cleanupActiveJob()

    -- Progress bar: brief handover animation
    lib.progressBar({
        duration  = 2000,
        label     = 'Finishing up...',
        canCancel = false,
        disable   = { move = true, combat = true },
        anim      = { dict = 'random@domestic', clip = 'pickup_low', flag = 49 },
    })

    TriggerServerEvent('um_hobos:completeOddJob', job.id)
end

-- ============================================================================
-- Collect-type job: spawn trash piles in zone, player walks near to collect
-- ============================================================================

-- Confirmed in ObjectList.ini: prop_rub_binbag_01
local trashModels = { 'prop_rub_binbag_01' }

local function spawnTrash(job)
    trashProps  = {}
    trashCount  = 0
    local center = job.zone
    local r      = (job.zoneRadius or 20.0) * 0.8

    for i = 1, job.count do
        local angle = math.rad((360 / job.count) * i + math.random(-20, 20))
        local dist  = math.random(4, math.floor(r))
        local tx    = center.x + math.cos(angle) * dist
        local ty    = center.y + math.sin(angle) * dist
        local _, tz = GetGroundZFor_3dCoord(tx, ty, center.z + 5.0, false)
        tz = tz or center.z

        local model = trashModels[math.random(#trashModels)]
        local hash  = GetHashKey(model)
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
    lib.notify({ type = 'inform', description = ('Collect %d trash piles. They are marked on your map.'):format(job.count), duration = 5000 })
end

-- ============================================================================
-- Delivery-type job: spawn package at pickup, player carries it to dropoff
-- ============================================================================

local function spawnPackage(job)
    packagePicked = false
    local hash    = GetHashKey('prop_paper_bag_01a')  -- confirmed in ObjectList.ini
    RequestModel(hash)
    local deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if HasModelLoaded(hash) then
        packageProp = CreateObject(hash, job.pickup.x, job.pickup.y, job.pickup.z, false, false, false)
        PlaceObjectOnGroundProperly(packageProp)
        SetEntityAsMissionEntity(packageProp, true, true)
        FreezeEntityPosition(packageProp, true)
        SetModelAsNoLongerNeeded(hash)
    end
    setWaypoint(job.pickup)
    lib.notify({ type = 'inform', description = 'Pick up the package from the marked location.', duration = 5000 })
end

-- ============================================================================
-- Start a job
-- ============================================================================

local function startJob(job)
    if activeJob then
        lib.notify({ type = 'error', description = 'You already have an active job. Finish or abandon it first.', duration = 4000 })
        return
    end

    activeJob = job

    if job.type == 'collect' then
        spawnTrash(job)
    elseif job.type == 'delivery' then
        spawnPackage(job)
    end

    -- Job timer
    local deadline = GetGameTimer() + job.timeMs
    CreateThread(function()
        while activeJob and activeJob.id == job.id do
            if GetGameTimer() > deadline then
                failJob('You ran out of time on the job.')
                return
            end
            Wait(5000)
        end
    end)
end

-- ============================================================================
-- Job board interaction
-- ============================================================================

local function openJobBoard()
    TriggerServerEvent('um_hobos:requestOddJobs')
end

RegisterNetEvent('um_hobos:client:jobList')
AddEventHandler('um_hobos:client:jobList', function(jobs)
    if not jobs or #jobs == 0 then
        lib.notify({ type = 'inform', description = 'No jobs posted right now. Check back later.', duration = 4000 })
        return
    end

    local options = {}
    for _, job in ipairs(jobs) do
        options[#options + 1] = {
            title       = job.label,
            description = ('%s\nPayout: $%d'):format(job.description, job.payout),
            onSelect    = function()
                lib.alertDialog({
                    header  = job.label,
                    content = ('%s\n\n**Payout:** $%d | **Time:** %d min'):format(
                        job.description, job.payout, math.floor(job.timeMs / 60000)),
                    centered = true,
                    cancel   = true,
                    labels   = { confirm = 'Take Job', cancel = 'Pass' },
                }, function(confirmed)
                    if confirmed == 'confirm' then
                        startJob(job)
                    end
                end)
            end,
        }
    end

    if activeJob then
        options[#options + 1] = {
            title       = '~r~Abandon Current Job',
            description = ('Active: %s'):format(activeJob.label),
            onSelect    = function()
                failJob('You abandoned the job.')
            end,
        }
    end

    lib.registerContext({ id = 'um_oddjobs_menu', title = 'Job Board', options = options })
    lib.showContext('um_oddjobs_menu')
end)

-- ============================================================================
-- Board prop setup
-- ============================================================================

local function spawnBoard()
    local cfg  = Config.OddJobs.board
    local hash = GetHashKey(cfg.model)

    -- Load model + collision
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then
        print('[um_beg] job board model failed to load: ' .. tostring(cfg.model))
        return
    end

    -- Resolve ground Z at the target coords — more reliable than PlaceObjectOnGroundProperly
    local x, y = cfg.coords.x, cfg.coords.y
    local groundFound, gz = GetGroundZFor_3dCoord(x, y, cfg.coords.z + 5.0, false)
    local z = groundFound and gz or cfg.coords.z

    boardProp = CreateObject(hash, x, y, z, false, false, false)

    -- Wait a couple frames for streaming to settle before doing anything to the entity
    Wait(100)

    if not boardProp or not DoesEntityExist(boardProp) then
        print('[um_beg] job board entity failed to create')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityHeading(boardProp, cfg.heading)
    SetEntityAsMissionEntity(boardProp, true, true)
    FreezeEntityPosition(boardProp, true)
    SetModelAsNoLongerNeeded(hash)

    -- ox_target
    exports.ox_target:addLocalEntity(boardProp, {
        {
            name     = 'um_hobos_jobboard',
            label    = 'Check Job Board',
            icon     = 'fas fa-clipboard-list',
            distance = cfg.radius,
            onSelect = function() openJobBoard() end,
        }
    })

    -- Blip (shortRange so it only shows nearby)
    boardBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(boardBlip, 357)
    SetBlipColour(boardBlip, 2)
    SetBlipScale(boardBlip, 0.8)
    SetBlipAsShortRange(boardBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Job Board')
    EndTextCommandSetBlipName(boardBlip)
end

local function cleanupBoard()
    if boardProp and DoesEntityExist(boardProp) then
        exports.ox_target:removeLocalEntity(boardProp)
        SetEntityAsMissionEntity(boardProp, true, true)
        DeleteObject(boardProp)
        boardProp = nil
    end
    if boardBlip and DoesBlipExist(boardBlip) then RemoveBlip(boardBlip); boardBlip = nil end
    cleanupActiveJob()
end

-- ============================================================================
-- Active job progress thread
-- ============================================================================

CreateThread(function()
    while true do
        if activeJob then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local job    = activeJob

            if job.type == 'collect' then
                -- Check proximity to each uncollected trash prop
                for i = #trashProps, 1, -1 do
                    local prop = trashProps[i]
                    if DoesEntityExist(prop) then
                        if #(GetEntityCoords(prop) - coords) <= 2.5 then
                            SetEntityAsMissionEntity(prop, true, true)
                            DeleteObject(prop)
                            table.remove(trashProps, i)
                            trashCount = trashCount + 1
                            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                            lib.notify({ type = 'inform', description = ('%d / %d trash collected.'):format(trashCount, job.count), duration = 2000 })
                        end
                    else
                        table.remove(trashProps, i)
                    end
                end
                if trashCount >= job.count then
                    completeJob()
                end

            elseif job.type == 'delivery' then
                if not packagePicked then
                    -- Phase 1: pick up package
                    if packageProp and DoesEntityExist(packageProp) then
                        if #(GetEntityCoords(packageProp) - coords) <= 2.5 then
                            -- Attach package to player hand
                            AttachEntityToEntity(packageProp, ped, GetPedBoneIndex(ped, 28422),
                                0.12, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                            FreezeEntityPosition(packageProp, false)
                            packagePicked = true
                            setWaypoint(job.dropoff)
                            lib.notify({ type = 'success', description = 'Package picked up. Deliver it to the marked spot.', duration = 4000 })
                        end
                    end
                else
                    -- Phase 2: deliver to dropoff
                    if #(job.dropoff - coords) <= 3.0 then
                        completeJob()
                    end
                end
            end

            Wait(200)
        else
            Wait(1000)
        end
    end
end)

-- ============================================================================
-- Server: job complete reward notification
-- ============================================================================

RegisterNetEvent('um_hobos:client:jobComplete')
AddEventHandler('um_hobos:client:jobComplete', function(label, payout, xp)
    lib.notify({
        type        = 'success',
        description = ('Job done: %s\n+$%d  +%d XP'):format(label, payout, xp),
        duration    = 6000,
    })
    GainXP(xp, 'oddjob')
end)

AddEventHandler('um_hobos:onDuty', function()
    -- Must spawn in a thread — Wait() inside a plain event handler doesn't yield
    CreateThread(function()
        Wait(2000)
        spawnBoard()
    end)
end)
AddEventHandler('um_hobos:offDuty', cleanupBoard)
